package backend;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import openfl.display.BitmapData;
import openfl.geom.Point;

/**
 * Lo que hay bajo cada pixel del mapa, segun el color del terreno (los tiles sueltos de la capa TILES):
 * suelo (hierba, arena...), acantilado (marron, el "color piel" de los riscos de SMW) o nada (agua o
 * aire: transparente o azul). El contorno negro es la raya entre dos cosas y cuenta como lo de al lado.
 *
 * Las carreteras lo usan para ponerse solas: franja beis sobre el suelo, escalera sobre el acantilado y,
 * sobre el agua, puntitos (a nado) o un puente. BF anda, trepa o nada segun lo que pisa.
 */
class OverworldTerrain
{
	public static inline final NONE:Int = 0;
	public static inline final GROUND:Int = 1;
	public static inline final CLIFF:Int = 2;
	/** Contorno (negro) o espuma: no decide nada por si mismo. */
	public static inline final EDGE:Int = 3;

	var bitmap:BitmapData;
	var left:Int = 0;
	var top:Int = 0;
	var width:Int = 0;
	var height:Int = 0;

	/** Pinta los sprites del terreno (en su orden de dibujo) en un solo mapa de pixeles. */
	public function new(sprites:Array<FlxSprite>)
	{
		var minX:Float = Math.POSITIVE_INFINITY;
		var minY:Float = Math.POSITIVE_INFINITY;
		var maxX:Float = Math.NEGATIVE_INFINITY;
		var maxY:Float = Math.NEGATIVE_INFINITY;
		var usable:Array<FlxSprite> = [];
		for (spr in sprites)
		{
			if (spr == null || spr.frame == null || spr.frame.angle != FlxFrameAngle.ANGLE_0) continue;
			usable.push(spr);
			minX = Math.min(minX, Math.floor(spr.x));
			minY = Math.min(minY, Math.floor(spr.y));
			maxX = Math.max(maxX, spr.x + spr.frameWidth);
			maxY = Math.max(maxY, spr.y + spr.frameHeight);
		}
		if (usable.length < 1) return;

		left = Std.int(minX);
		top = Std.int(minY);
		width = Std.int(Math.ceil(maxX - minX));
		height = Std.int(Math.ceil(maxY - minY));
		bitmap = new BitmapData(width, height, true, 0);
		var point:Point = new Point();
		for (spr in usable)
		{
			point.setTo(Math.floor(spr.x) - left, Math.floor(spr.y) - top);
			if (spr.flipX || spr.flipY) spr.frame.paintRotatedAndFlipped(bitmap, point, FlxFrameAngle.ANGLE_0, spr.flipX, spr.flipY, true);
			else spr.frame.paint(bitmap, point, true);
		}
	}

	/** No hay terreno pintado (un mapa sin tiles): quien lo use hace como antes. */
	public var empty(get, never):Bool;

	inline function get_empty():Bool
		return bitmap == null;

	/** Lo que hay en ese pixel tal cual (NONE, GROUND, CLIFF o EDGE). */
	public function rawAt(x:Float, y:Float):Int
	{
		if (bitmap == null) return NONE;
		var px:Int = Math.floor(x) - left;
		var py:Int = Math.floor(y) - top;
		if (px < 0 || py < 0 || px >= width || py >= height) return NONE;
		return classify(bitmap.getPixel32(px, py));
	}

	/** Como rawAt, pero un pixel de contorno toma lo que mas haya a su alrededor (hasta 2 px). */
	public function kindAt(x:Float, y:Float):Int
	{
		var kind:Int = rawAt(x, y);
		if (kind != EDGE) return kind;

		var counts:Array<Int> = [0, 0, 0];
		for (radius in 1...3)
		{
			for (offset in [[radius, 0], [-radius, 0], [0, radius], [0, -radius]])
			{
				var other:Int = rawAt(x + offset[0], y + offset[1]);
				if (other != EDGE) counts[other]++;
			}
			if (counts[0] + counts[1] + counts[2] > 0) break;
		}
		if (counts[CLIFF] > counts[GROUND] && counts[CLIFF] >= counts[NONE]) return CLIFF;
		if (counts[GROUND] >= counts[NONE] && counts[GROUND] > 0) return GROUND;
		return counts[NONE] > 0 ? NONE : GROUND;
	}

	/**
	 * El tipo de un color: transparente o azul = NONE; marron (rojo > verde > azul, bien separados) =
	 * CLIFF; casi negro, casi blanco (espuma) y la onda verde de la espuma de SMW = EDGE; lo demas, GROUND.
	 */
	public static function classify(argb:Int):Int
	{
		var a:Int = (argb >>> 24) & 0xFF;
		if (a < 0x80) return NONE;
		var r:Int = (argb >> 16) & 0xFF;
		var g:Int = (argb >> 8) & 0xFF;
		var b:Int = argb & 0xFF;
		if (r < 48 && g < 48 && b < 48) return EDGE;
		if (r > 224 && g > 224 && b > 224) return EDGE;
		if (r == 64 && g == 208 && b == 33) return EDGE; // la onda de la espuma (un verde casi como la hierba)
		if (b > r + 30 && b > g) return NONE; // agua
		if (r > g && g > b && r - g >= 40 && g - b >= 30) return CLIFF;
		return GROUND;
	}

	/**
	 * Lo que hay bajo cada punto de una lista (a 1 px uno de otro), sin contornos: un contorno toma lo de
	 * antes (o lo de despues, al principio), y los tramos de 1-2 puntos entre dos iguales se igualan
	 * (rayitas sueltas del dibujo).
	 */
	public function kindsAlong(samples:Array<Array<Float>>):Array<Int>
	{
		var kinds:Array<Int> = [for (s in samples) kindAt(s[0], s[1])];
		var last:Int = -1;
		for (i in 0...kinds.length)
		{
			if (kinds[i] == EDGE) kinds[i] = last;
			else last = kinds[i];
		}
		var next:Int = GROUND;
		var i:Int = kinds.length - 1;
		while (i >= 0)
		{
			if (kinds[i] < 0) kinds[i] = next;
			else next = kinds[i];
			i--;
		}

		var start:Int = 0;
		while (start < kinds.length)
		{
			var end:Int = start;
			while (end + 1 < kinds.length && kinds[end + 1] == kinds[start]) end++;
			var length:Int = end - start + 1;
			if (length <= 2 && start > 0 && end < kinds.length - 1 && kinds[start - 1] == kinds[end + 1])
				for (k in start...end + 1) kinds[k] = kinds[start - 1];
			start = end + 1;
		}
		return kinds;
	}

	public function destroy()
	{
		if (bitmap != null) bitmap.dispose();
		bitmap = null;
	}
}
