package states.stages.objects;

import flixel.util.FlxStringUtil;
import objects.Character;
import objects.HealthIcon;

/**
 * La barra de vida de Vs Sonic.exe (port de su scripts/customHealthBar.lua): un rectangulo negro con
 * el color de BF de fondo, el del rival creciendo desde la izquierda y un separador blanco entre los
 * dos; encima, el marco de la cancion (su imagen hud/hud_<...>), los iconos (botan en cada pulso) y
 * "Score | Misses" (en botplay, "SUNKY IS PLAYING" con los colores del arcoiris).
 * Los tamanos y desplazamientos salen de data/<cancion>/healthProps.json, como en el mod.
 * Sustituye a la barra, los iconos, la puntuacion y el rotulo de botplay de Psych.
 */
@:access(states.PlayState)
class SonicHUD
{
	public var bg:FlxSprite;
	/** hbHealth: el color de BF, todo el ancho. */
	public var playerFill:FlxSprite;
	/** hbHealth2: el color del rival, crece desde la izquierda. */
	public var opponentFill:FlxSprite;
	public var separator:FlxSprite;
	public var frame:FlxSprite;
	public var iconBF:HealthIcon;
	public var iconOpp:HealthIcon;
	public var scoreText:FlxText;

	var play:PlayState;
	var frameOffset:FlxPoint;
	var lerpHealth:Float = 1;
	var sine:Float = 0;
	var oldText:String = '';

	// healthProps.json (valores por defecto de customHealthBar.lua)
	var barWidth:Int = 601;
	var barHeight:Int = 25;
	var gapSize:Int = 5;
	var separatorWidth:Int = 4;
	var textBopAmount:Float = 1.1;
	var hideScore:Bool = false;
	var barOffset:FlxPoint = FlxPoint.get();
	var playerScale:Float = 1;
	var playerOffset:FlxPoint = FlxPoint.get();
	var playerBop:Float = 1.2;
	var opponentScale:Float = 1;
	var opponentOffset:FlxPoint = FlxPoint.get();
	var opponentBop:Float = 1.2;

	/**
	 * @param frameImage   el marco (imagen de 3118x564 que se reduce a 0.32x0.3)
	 * @param frameX/Y     su posicion respecto al rectangulo negro (healthBarsBG del script)
	 */
	public function new(play:PlayState, frameImage:String, frameX:Float, frameY:Float)
	{
		this.play = play;
		frameOffset = FlxPoint.get(frameX, frameY);
		loadProps('data/${play.songName}/healthProps.json');

		var y:Float = FlxG.height * (ClientPrefs.data.downScroll ? 0.11 : 0.89) + barOffset.y;
		bg = new FlxSprite(0, y).makeGraphic(barWidth, barHeight, FlxColor.WHITE);
		bg.color = FlxColor.BLACK;
		bg.screenCenter(X);
		bg.x += barOffset.x;

		var innerHeight:Int = barHeight - gapSize * 2;
		playerFill = new FlxSprite(bg.x + separatorWidth, y + gapSize).makeGraphic(barWidth - gapSize * 2, innerHeight, FlxColor.WHITE);
		// 1 px de ancho: cada fotograma se estira al ancho que toca
		opponentFill = new FlxSprite(bg.x + separatorWidth, y + gapSize).makeGraphic(1, innerHeight, FlxColor.WHITE);
		separator = new FlxSprite(0, y + gapSize).makeGraphic(separatorWidth, innerHeight, FlxColor.WHITE);

		frame = new FlxSprite(bg.x + frameOffset.x, bg.y + frameOffset.y).loadGraphic(Paths.image(frameImage));
		frame.scale.set(0.32, 0.3);
		frame.updateHitbox();

		iconBF = new HealthIcon(play.boyfriend.healthIcon, true);
		iconBF.scale.set(playerScale, playerScale);
		iconOpp = new HealthIcon(play.dad.healthIcon, false);
		iconOpp.scale.set(opponentScale, opponentScale);
		updateColors();

		scoreText = new FlxText(0, bg.y + 40, FlxG.width / 0.75, Language.getPhrase('sonic_score_text', 'Score: {1} | Misses: {2}', ['0', '0']));
		scoreText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreText.borderSize = 1;
		scoreText.screenCenter(X);
		scoreText.x = Math.floor(scoreText.x + barOffset.x);

		var parts:Array<FlxSprite> = [bg, playerFill, opponentFill, separator, frame, iconBF, iconOpp];
		if (!hideScore) parts.push(scoreText);
		// detras de las notas y del resto del HUD de Psych (el script los metia detras de los personajes)
		for (part in parts)
		{
			part.cameras = [play.camHUD];
			if (ClientPrefs.data.hideHud) part.visible = false;
			play.insert(play.members.indexOf(play.comboGroup), part);
		}
		for (part in [bg, playerFill, opponentFill, separator, frame]) part.antialiasing = ClientPrefs.data.antialiasing;

		play.healthBar.visible = play.scoreTxt.visible = play.iconP1.visible = play.iconP2.visible = false;
		play.botplayTxt.kill(); // el mod no lo tenia: su rotulo de botplay es la puntuacion
		update(0);
	}

	function loadProps(path:String)
	{
		if (!Paths.fileExists(path, TEXT)) return;
		var json:Dynamic = haxe.Json.parse(Paths.getTextFromFile(path));
		inline function num(obj:Dynamic, field:String, fallback:Float):Float
		{
			var value:Dynamic = obj != null ? Reflect.field(obj, field) : null;
			return value != null ? value : fallback;
		}
		var bar:Dynamic = json.healthBar;
		barWidth = Std.int(num(bar, 'width', barWidth));
		barHeight = Std.int(num(bar, 'height', barHeight));
		gapSize = Std.int(num(bar, 'gapSize', gapSize));
		separatorWidth = Std.int(num(bar, 'separatorWidth', separatorWidth));
		textBopAmount = num(bar, 'textBopAmount', textBopAmount);
		hideScore = bar != null && bar.hideScore == true;
		barOffset.set(num(bar, 'offsetX', 0), num(bar, 'offsetY', 0));
		var icon:Dynamic = json.playerIcon;
		playerScale = num(icon, 'scale', playerScale);
		playerOffset.set(num(icon, 'offsetX', 0), num(icon, 'offsetY', 0));
		playerBop = num(icon, 'bopAmount', playerBop);
		icon = json.opponentIcon;
		opponentScale = num(icon, 'scale', opponentScale);
		opponentOffset.set(num(icon, 'offsetX', 0), num(icon, 'offsetY', 0));
		opponentBop = num(icon, 'bopAmount', opponentBop);
	}

	static function healthColor(char:Character):FlxColor
		return FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);

	/** Colores e iconos de los personajes actuales (tras "Change Character"). */
	public function updateColors()
	{
		playerFill.color = healthColor(play.boyfriend);
		opponentFill.color = healthColor(play.dad);
		if (iconBF.getCharacter() != play.boyfriend.healthIcon) iconBF.changeIcon(play.boyfriend.healthIcon);
		if (iconOpp.getCharacter() != play.dad.healthIcon) iconOpp.changeIcon(play.dad.healthIcon);
	}

	public function update(elapsed:Float)
	{
		var rate:Float = play.playbackRate;
		lerpHealth = FlxMath.lerp(play.health, lerpHealth, Math.exp(-elapsed * 12 * rate));

		iconOpp.x = bg.x - 75 + opponentOffset.x;
		iconOpp.y = bg.y + bg.height / 2 - 75 + opponentOffset.y;
		iconBF.x = bg.x + bg.width - 75 + playerOffset.x;
		iconBF.y = bg.y + bg.height / 2 - 75 + playerOffset.y;

		var inner:Float = bg.width - gapSize * 2;
		opponentFill.setGraphicSize(FlxMath.bound(FlxMath.lerp(inner, 1, Math.abs(lerpHealth / 2)), 1, inner), bg.height - gapSize * 2);
		opponentFill.updateHitbox();
		var room:Float = playerFill.width - separatorWidth;
		separator.x = playerFill.x + FlxMath.bound(FlxMath.lerp(room, 0, Math.abs(lerpHealth / 2)), 0, room);
		frame.setPosition(bg.x + frameOffset.x, bg.y + frameOffset.y);
		frame.alpha = bg.alpha;

		if (!hideScore)
		{
			var text:String = Language.getPhrase('sonic_score_text', 'Score: {1} | Misses: {2}',
				[FlxStringUtil.formatMoney(play.songScore, false), play.songMisses]);
			if (play.cpuControlled) text = Language.getPhrase('sunky_is_playing', 'SUNKY IS PLAYING').toUpperCase();
			else scoreText.color = FlxColor.WHITE;
			if (text != oldText)
			{
				scoreText.text = text;
				if (elapsed > 0) scoreText.scale.set(textBopAmount, textBopAmount);
				oldText = text;
			}
			var textScale:Float = FlxMath.lerp(scoreText.scale.x, 1, Math.min(elapsed * 10, 1));
			scoreText.scale.set(textScale, textScale);

			if (play.cpuControlled && scoreText.visible)
			{
				sine = (sine + 90 * elapsed) % 360;
				scoreText.color = FlxColor.fromHSB(sine, 1, 1);
			}
		}

		if (iconBF.animation.curAnim != null) iconBF.animation.curAnim.curFrame = play.health < 0.4 ? 1 : 0;
		if (iconOpp.animation.curAnim != null) iconOpp.animation.curAnim.curFrame = play.health > 1.6 ? 1 : 0;
		var mult:Float = FlxMath.lerp(opponentScale, iconOpp.scale.x, Math.exp(-elapsed * 9 * rate));
		iconOpp.scale.set(mult, mult);
		mult = FlxMath.lerp(playerScale, iconBF.scale.x, Math.exp(-elapsed * 9 * rate));
		iconBF.scale.set(mult, mult);
	}

	public function beatHit()
	{
		iconBF.scale.set(playerScale * playerBop, playerScale * playerBop);
		iconOpp.scale.set(opponentScale * opponentBop, opponentScale * opponentBop);
	}

	public function destroy()
	{
		for (point in [frameOffset, barOffset, playerOffset, opponentOffset]) point.put();
	}
}
