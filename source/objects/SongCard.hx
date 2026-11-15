package objects;

import flixel.util.FlxSpriteUtil;

/**
 * Rotulo con el nombre de la cancion al empezar, en lugar de la cuenta atras (que ya no se ve ni
 * suena): lo pone PlayState al arrancar la cuenta atras si `PlayState.songCard` sigue a true (las
 * canciones con rotulo propio, como las de Mario's Madness y endless, lo quitan).
 *
 * Cada cancion elige su estilo en data/<cancion>/songcard.json:
 *   title      texto grande (por defecto, el nombre de la cancion)
 *   subtitle   texto pequeno de debajo (por defecto, nada)
 *   style      "banner" (franja desde la izquierda), "circle" (circulo dibujado desde la derecha y
 *              titulo desde la izquierda), "panel" (tarjeta redondeada que baja desde arriba) o
 *              "slide" (las pantallas de inicio de Vs Sonic.exe con sus imagenes: ver abajo)
 *   slide:     circleImage y textImage, imagenes a pantalla completa (1280x720) que entran por la
 *              derecha y por la izquierda en 1 s, se quedan `hold` s (0.5) y se funden en 1 s, como
 *              StartScreen.lua de MAJIN; background, color del fondo (por defecto, ninguno: con la
 *              cancion empezando detras se veria negro)
 *   font       fuente de assets/fonts (por defecto vcr.ttf)
 *   color      color principal (la franja, el circulo o el fondo de la tarjeta)
 *   accent     color de los bordes y detalles
 *   textColor  color del titulo; subtitleColor, el del subtitulo (por defecto, el del titulo)
 *   titleSize  tamano del titulo (por defecto 52)
 *   delay      segundos antes de entrar (0.15) y hold, segundos que se queda (2.2)
 *   at         segundo de cancion en que sale (por defecto, al empezar la entrada de la cancion)
 */
class SongCard extends FlxSpriteGroup
{
	var style:String;
	var delay:Float;
	var hold:Float;
	var done:Void->Void;

	public function new(song:String, displayName:String, onDone:Void->Void)
	{
		super();
		done = onDone;
		scrollFactor.set();

		var data:Dynamic = null;
		var file:String = 'data/${Paths.formatToSongPath(song)}/songcard.json';
		try
		{
			if (Paths.fileExists(file, openfl.utils.AssetType.TEXT)) data = haxe.Json.parse(Paths.getTextFromFile(file));
		}
		catch (e:Dynamic)
		{
			trace('songcard.json de $song no se pudo leer: $e');
		}

		inline function text(field:String, fallback:String):String
		{
			var value:Dynamic = data != null ? Reflect.field(data, field) : null;
			return value != null ? Std.string(value) : fallback;
		}
		inline function num(field:String, fallback:Float):Float
		{
			var value:Dynamic = data != null ? Reflect.field(data, field) : null;
			return value != null ? value : fallback;
		}
		inline function color(field:String, fallback:String):FlxColor
		{
			var parsed:Null<FlxColor> = FlxColor.fromString(text(field, fallback));
			return parsed != null ? parsed : FlxColor.fromString(fallback);
		}

		style = text('style', 'banner');
		delay = num('delay', 0.15);
		hold = num('hold', 2.2);
		var title:String = text('title', displayName);
		var subtitle:String = text('subtitle', '');
		var font:String = Paths.font(text('font', 'vcr.ttf'));
		var main:FlxColor = color('color', '#101010');
		var accent:FlxColor = color('accent', '#A15EFF');
		var textColor:FlxColor = color('textColor', '#FFFFFF');
		var subColor:FlxColor = color('subtitleColor', text('textColor', '#FFFFFF'));
		var size:Int = Std.int(num('titleSize', 52));

		var build:Void->Void = function()
		{
			switch (style)
			{
				case 'circle': buildCircle(title, subtitle, font, main, accent, textColor, subColor, size);
				case 'slide': buildSlide(text('circleImage', ''), text('textImage', ''), text('background', ''));
				case 'panel': buildPanel(title, subtitle, font, main, accent, textColor, subColor, size);
				default: buildBanner(title, subtitle, font, main, accent, textColor, subColor, size);
			}
			// en una camara propia, creada al aparecer: por encima de todo, tambien de un video que ya
			// este sonando (VideoSprite se pone en la ultima camara que haya al crearse)
			cam = new FlxCamera();
			cam.bgColor = FlxColor.TRANSPARENT;
			FlxG.cameras.add(cam, false);
			cameras = [cam];
		};
		// "at": segundo de cancion en que sale (p. ej. despues del video de entrada de yararara)
		var at:Float = num('at', -1);
		if (at < 0) build();
		else
		{
			showAt = at * 1000;
			pendingBuild = build;
		}
	}

	var showAt:Float = 0;
	var pendingBuild:Void->Void = null;

	override function update(elapsed:Float)
	{
		if (pendingBuild != null && Conductor.songPosition >= showAt)
		{
			var build:Void->Void = pendingBuild;
			pendingBuild = null;
			build();
		}
		super.update(elapsed);
	}

	function label(content:String, font:String, size:Int, color:FlxColor, ?width:Float = 0, ?align:FlxTextAlign = LEFT, ?border:FlxColor = FlxColor.BLACK):FlxText
	{
		var txt:FlxText = new FlxText(0, 0, width, content, size);
		txt.setFormat(font, size, color, align, FlxTextBorderStyle.OUTLINE, border);
		txt.borderSize = Math.max(2, size / 16);
		txt.antialiasing = ClientPrefs.data.antialiasing;
		return txt;
	}

	// ------------------------------------------------------------------ franja
	var band:FlxSpriteGroup;

	function buildBanner(title:String, subtitle:String, font:String, main:FlxColor, accent:FlxColor, textColor:FlxColor, subColor:FlxColor, size:Int)
	{
		band = new FlxSpriteGroup();
		var titleTxt:FlxText = label(title, font, size, textColor);
		var subTxt:FlxText = subtitle.length > 0 ? label(subtitle, font, Std.int(size * 0.42), subColor) : null;
		var width:Int = Std.int(Math.max(titleTxt.width, subTxt != null ? subTxt.width : 0) + 140);
		var height:Int = Std.int(titleTxt.height + (subTxt != null ? subTxt.height : 0) + 26);

		// franja con el extremo derecho en diagonal y una raya de color debajo
		var slant:Int = Std.int(height * 0.6);
		var shape:FlxSprite = new FlxSprite().makeGraphic(width + slant, height + 8, FlxColor.TRANSPARENT, true);
		for (y in 0...height)
			shape.pixels.fillRect(new openfl.geom.Rectangle(0, y, width + slant * (1 - y / height), 1), main);
		shape.pixels.fillRect(new openfl.geom.Rectangle(0, height, width + 6, 8), accent);
		shape.dirty = true;
		band.add(shape);

		titleTxt.setPosition(40, 10);
		band.add(titleTxt);
		if (subTxt != null)
		{
			subTxt.setPosition(44, titleTxt.y + titleTxt.height - 4);
			band.add(subTxt);
		}
		band.y = FlxG.height * 0.36;
		band.x = -band.width - 40;
		add(band);

		FlxTween.tween(band, {x: 0}, 0.5, {ease: FlxEase.expoOut, startDelay: delay});
		FlxTween.tween(band, {x: -band.width - 40}, 0.45, {ease: FlxEase.expoIn, startDelay: delay + 0.5 + hold, onComplete: function(_) finish()});
	}

	// ------------------------------------------------------------------ circulo (Vs Sonic.exe)
	function buildCircle(title:String, subtitle:String, font:String, main:FlxColor, accent:FlxColor, textColor:FlxColor, subColor:FlxColor, size:Int)
	{
		var radius:Int = 190;
		var circle:FlxSprite = new FlxSprite().makeGraphic(radius * 2 + 16, radius * 2 + 16, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(circle, radius + 8, radius + 8, radius + 8, accent);
		FlxSpriteUtil.drawCircle(circle, radius + 8, radius + 8, radius, main);
		FlxSpriteUtil.drawCircle(circle, radius + 8, radius + 8, radius * 0.62, accent.getDarkened(0.2));
		circle.antialiasing = ClientPrefs.data.antialiasing;
		circle.y = FlxG.height * 0.5 - radius - 8;
		var circleX:Float = FlxG.width - radius * 2 - 60;
		circle.x = FlxG.width;
		add(circle);

		var words:FlxSpriteGroup = new FlxSpriteGroup();
		var titleTxt:FlxText = label(title, font, size, textColor, 0, LEFT, accent);
		words.add(titleTxt);
		if (subtitle.length > 0)
		{
			var subTxt:FlxText = label(subtitle, font, Std.int(size * 0.38), subColor, 0, LEFT, accent);
			subTxt.setPosition(6, titleTxt.height + 2);
			words.add(subTxt);
		}
		words.y = FlxG.height * 0.5 - words.height * 0.5;
		var wordsX:Float = 70;
		words.x = -words.width - 40;
		add(words);

		FlxTween.tween(circle, {x: circleX}, 0.55, {ease: FlxEase.quintOut, startDelay: delay});
		FlxTween.tween(words, {x: wordsX}, 0.55, {ease: FlxEase.quintOut, startDelay: delay});
		var out:Float = delay + 0.55 + hold;
		FlxTween.tween(circle, {x: FlxG.width, alpha: 0}, 0.5, {ease: FlxEase.quintIn, startDelay: out});
		FlxTween.tween(words, {x: -words.width - 40, alpha: 0}, 0.5, {ease: FlxEase.quintIn, startDelay: out, onComplete: function(_) finish()});
	}

	// ------------------------------------------------------------------ pantalla de inicio (Vs Sonic.exe)
	function buildSlide(circleKey:String, textKey:String, background:String)
	{
		var parts:Array<FlxSprite> = [];
		if (background.length > 0)
		{
			var bgColor:Null<FlxColor> = FlxColor.fromString(background);
			if (bgColor != null) parts.push(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, bgColor));
		}
		var circle:FlxSprite = new FlxSprite(FlxG.width, 0);
		if (circleKey.length > 0) circle.loadGraphic(Paths.image(circleKey));
		else circle.visible = false;
		var title:FlxSprite = new FlxSprite(-FlxG.width, 0);
		if (textKey.length > 0) title.loadGraphic(Paths.image(textKey));
		else title.visible = false;
		parts.push(circle);
		parts.push(title);
		for (part in parts)
		{
			part.antialiasing = ClientPrefs.data.antialiasing;
			add(part);
		}

		var holdTime:Float = hold;
		FlxTween.tween(title, {x: 0}, 1, {ease: FlxEase.quintOut, startDelay: delay});
		FlxTween.tween(circle, {x: 0}, 1, {ease: FlxEase.quintOut, startDelay: delay});
		for (i in 0...parts.length)
			FlxTween.tween(parts[i], {alpha: 0}, 1, {startDelay: delay + 1 + holdTime, onComplete: i == parts.length - 1 ? function(_) finish() : null});
	}

	// ------------------------------------------------------------------ tarjeta (Doki Doki)
	function buildPanel(title:String, subtitle:String, font:String, main:FlxColor, accent:FlxColor, textColor:FlxColor, subColor:FlxColor, size:Int)
	{
		var titleTxt:FlxText = label(title, font, size, textColor, 0, CENTER, FlxColor.WHITE);
		var subTxt:FlxText = subtitle.length > 0 ? label(subtitle, font, Std.int(size * 0.45), subColor, 0, CENTER, FlxColor.WHITE) : null;
		var width:Int = Std.int(Math.max(titleTxt.width, subTxt != null ? subTxt.width : 0) + 90);
		var height:Int = Std.int(titleTxt.height + (subTxt != null ? subTxt.height : 0) + 40);

		var panel:FlxSprite = new FlxSprite().makeGraphic(width, height, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(panel, 0, 0, width, height, 34, 34, accent);
		FlxSpriteUtil.drawRoundRect(panel, 5, 5, width - 10, height - 10, 28, 28, main);
		// lunares, como los fondos de los menus de Doki Doki
		var dots:flixel.math.FlxRandom = new flixel.math.FlxRandom(Std.int(title.length * 977));
		for (i in 0...10)
			FlxSpriteUtil.drawCircle(panel, dots.float(20, width - 20), dots.float(16, height - 16), dots.float(3, 7), accent.getLightened(0.55));
		panel.antialiasing = ClientPrefs.data.antialiasing;

		var card:FlxSpriteGroup = new FlxSpriteGroup();
		card.add(panel);
		titleTxt.setPosition((width - titleTxt.width) / 2, 16);
		card.add(titleTxt);
		if (subTxt != null)
		{
			subTxt.setPosition((width - subTxt.width) / 2, titleTxt.y + titleTxt.height);
			card.add(subTxt);
		}
		card.x = (FlxG.width - width) / 2;
		var cardY:Float = FlxG.height * 0.28;
		card.y = -height - 20;
		add(card);

		FlxTween.tween(card, {y: cardY}, 0.6, {ease: FlxEase.backOut, startDelay: delay});
		FlxTween.tween(card, {y: -height - 20}, 0.45, {ease: FlxEase.backIn, startDelay: delay + 0.6 + hold, onComplete: function(_) finish()});
	}

	var cam:FlxCamera;

	function finish()
	{
		if (cam != null && FlxG.cameras.list.contains(cam)) FlxG.cameras.remove(cam);
		cam = null;
		if (done != null) done();
		done = null;
	}
}
