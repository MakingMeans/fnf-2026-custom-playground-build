package states.stages.objects;

import flixel.math.FlxRect;
import objects.Character;

/**
 * HUD de World of Chaos (songs/camHUD.hx del mod, que era de Codename Engine):
 *  - La barra "Doki": un marco (otro con Big Monika) y dos rellenos teñidos con el color de cada
 *    personaje y recortados segun la vida. La jugadora (Saori) esta a la izquierda, asi que su color
 *    llena desde la izquierda.
 *  - Los iconos encima de la barra, moviendose con la vida, los dos volteados.
 *  - Los tres textos del HUD de Codename (Score / Misses / Accuracy, la letra de la nota en su color)
 *    con la fuente doki y el rosa del mod.
 * Sustituye a la barra de vida, la puntuacion y la barra de tiempo de Psych (Codename no tiene).
 */
@:access(states.PlayState)
class DokiHUD
{
	/** Letras de la precision de Codename (comboRatings): [minimo, letra, color]. */
	static final RATINGS:Array<Array<Dynamic>> = [
		[0, 'F', 0xFFFF4444], [0.5, 'E', 0xFFFF8844], [0.7, 'D', 0xFFFFAA44], [0.8, 'C', 0xFFFFFF44],
		[0.85, 'B', 0xFFAAFF44], [0.9, 'A', 0xFF88FF44], [0.95, 'S', 0xFF44FFFF], [1, 'S++', 0xFF44FFFF]
	];

	var play:PlayState;
	var frame:FlxSprite;
	var frameBig:FlxSprite;
	var dadFill:FlxSprite;
	var bfFill:FlxSprite;
	var dadClip:FlxRect = FlxRect.get();
	var bfClip:FlxRect = FlxRect.get();
	var scoreText:FlxText;
	var missesText:FlxText;
	var accuracyText:FlxText;
	var lastAccuracy:String = '';
	var downScroll:Bool;

	public function new(play:PlayState)
	{
		this.play = play;
		downScroll = ClientPrefs.data.downScroll;

		// el mod las ponia en (-1138, 270) a escala 0.25 sin updateHitbox (escalan desde su centro):
		// la barra queda abajo, de x 197 a 1087. En downscroll Codename volteaba la camara del HUD.
		var y:Float = downScroll ? -300 : 270;
		frameBig = bar('woc/hud/healthBarBG2', y);
		frameBig.visible = false;
		frame = bar('woc/hud/healthBarBG', y);
		dadFill = bar('woc/hud/healthBar', y);
		bfFill = bar('woc/hud/healthBar', y);

		// textos de Codename: dentro de su barra por defecto (601 px, centrada a 0.9 de alto) + 30 + 10
		var textY:Float = downScroll ? 12 : FlxG.height * 0.9 + 40;
		scoreText = text(RIGHT, textY);
		missesText = text(CENTER, textY);
		accuracyText = text(LEFT, textY);

		for (part in [frameBig, frame, dadFill, bfFill])
			play.insert(play.members.indexOf(play.uiGroup), part);
		for (part in [scoreText, missesText, accuracyText])
			play.insert(play.members.indexOf(play.uiGroup), part);

		play.healthBar.visible = play.scoreTxt.visible = false;
		play.timeBar.visible = play.timeTxt.visible = false;
		play.updateIconsPosition = updateIcons;
		if (ClientPrefs.data.hideHud)
			for (part in [frameBig, frame, dadFill, bfFill, scoreText, missesText, accuracyText]) part.alpha = 0;
		update(0);
	}

	function bar(image:String, y:Float):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(-1138, y).loadGraphic(Paths.image(image));
		spr.scale.set(0.25, 0.25);
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.cameras = [play.camHUD];
		return spr;
	}

	function text(align:FlxTextAlign, y:Float):FlxText
	{
		var barX:Float = (FlxG.width - 601) / 2;
		var txt:FlxText = new FlxText(barX + 50, y, 601 - 100, '', 17);
		txt.setFormat(Paths.font('doki.ttf'), 17, 0xFFF79EEA, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.borderSize = 2.5;
		txt.borderQuality = 1;
		txt.antialiasing = ClientPrefs.data.antialiasing;
		txt.cameras = [play.camHUD];
		return txt;
	}

	static function healthColor(char:Character):FlxColor
		return FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);

	/** Iconos (postUpdate de camHUD.hx): sobre la barra, de x 200 a 800 segun la vida. */
	function updateIcons()
	{
		var percent:Float = FlxMath.bound(play.health / 2, 0, 1);
		var x:Float = 200 + percent * 600;
		var y:Float = downScroll ? -10 : 550;
		var p1 = play.iconP1;
		var p2 = play.iconP2;
		p2.y = p1.y = y;
		p2.x = x - p2.width + 275;
		p1.x = x + 15;
		p1.flipX = p2.flipX = true;
		p1.origin.x = p1.width / 2;
		p2.origin.x = p2.width / 2;
	}

	public function update(elapsed:Float)
	{
		var big:Bool = play.dad != null && play.dad.curCharacter == 'woc-big-monica';
		frame.visible = !big;
		frameBig.visible = big;

		dadFill.color = healthColor(play.dad);
		bfFill.color = healthColor(play.boyfriend);
		var percent:Float = FlxMath.bound(play.health / 2, 0, 1);
		var width:Float = dadFill.frameWidth;
		var height:Float = dadFill.frameHeight;
		var dadWidth:Float = width * (1 - percent);
		dadClip.set(width - dadWidth, 0, dadWidth, height);
		dadFill.clipRect = dadClip;
		bfClip.set(0, 0, width * percent, height);
		bfFill.clipRect = bfClip;

		scoreText.text = 'Score:${play.songScore}';
		missesText.text = 'Misses:${play.songMisses}';

		// Codename: "Accuracy:<precision> - <letra>", con la letra en su color ("-%" y "[N/A]" sin notas)
		var accuracy:String;
		var letter:String;
		var color:FlxColor;
		if (play.totalPlayed <= 0)
		{
			accuracy = '-%';
			letter = '[N/A]';
			color = 0xFF888888;
		}
		else
		{
			var percentHit:Float = play.ratingPercent;
			accuracy = '${Math.round(percentHit * 10000) / 100}%';
			var rating:Array<Dynamic> = RATINGS[0];
			for (entry in RATINGS)
				if (percentHit >= entry[0]) rating = entry;
			letter = rating[1];
			color = rating[2];
		}
		var full:String = 'Accuracy:$accuracy - $letter';
		if (full != lastAccuracy)
		{
			lastAccuracy = full;
			accuracyText.text = full;
			accuracyText.clearFormats();
			accuracyText.addFormat(new FlxTextFormat(color), full.length - letter.length, full.length);
		}
	}

	public function destroy()
	{
		dadClip.put();
		bfClip.put();
	}
}
