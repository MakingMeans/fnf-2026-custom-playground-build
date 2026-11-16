package substates;

import flixel.effects.FlxFlicker;
import openfl.utils.AssetType;

/**
 * Menu de pausa de Vs Sonic.EXE. El del mod va compilado en su exe (sin script ni codigo publico), asi que
 * esta rehecho con sus piezas (tools/ports/sonic_exe.py --pause): pixel art a x3, el panel negro con borde en
 * sierra (`separator`, 136x241 -> la altura de la pantalla) entra por la derecha con el titulo PAUSE, las
 * cuatro opciones, la raya bajo la elegida y el Sonic en miniatura de la cancion a su lado. Su musica y sus
 * sonidos de menu. Lo abren chaos y endless-us (SonicStage).
 */
class SonicPauseSubState extends MusicBeatSubstate
{
	static final PIXEL:Float = 3;
	static final ITEMS:Array<String> = ['continue', 'restart', 'options', 'exit'];
	static final PANEL_X:Float = 872;  // 1280 - 136 * 3
	static final TEXT_X:Float = 952;   // pasado el borde en sierra
	static final FIRST_Y:Float = 250;
	static final STEP_Y:Float = 96;

	var bg:FlxSprite;
	var panel:FlxSprite;
	var title:FlxSprite;
	var options:Array<FlxSprite> = [];
	var underline:FlxSprite;
	var mini:FlxSprite;
	var parts:Array<FlxSprite> = [];
	var music:FlxSound;
	var curSelected:Int = 0;
	var leaving:Bool = false;

	override function create()
	{
		super.create();
		music = new FlxSound().loadEmbedded(Paths.music('sonic_exe/pause'), true, true);
		music.volume = 0;
		music.play();
		FlxG.sound.list.add(music);
		music.fadeIn(1, 0, 0.6);

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);
		FlxTween.tween(bg, {alpha: 0.5}, 0.3);

		panel = pixelSprite('separator', PANEL_X, (FlxG.height - 241 * PIXEL) / 2);
		title = pixelSprite('pauseText', 0, 70);
		title.x = TEXT_X + (FlxG.width - TEXT_X - title.width) / 2;
		for (i => item in ITEMS) options.push(pixelSprite(item, TEXT_X, FIRST_Y + i * STEP_Y));
		underline = pixelSprite('selected', TEXT_X - 12, 0);

		var miniKey:String = 'sonic_exe/pause/mini/' + PlayState.instance.songName;
		if (Paths.fileExists('images/$miniKey.png', IMAGE))
		{
			mini = new FlxSprite().loadGraphic(Paths.image(miniKey));
			mini.scale.set(PIXEL, PIXEL);
			mini.updateHitbox();
			mini.antialiasing = false;
			mini.scrollFactor.set();
			mini.x = FlxG.width - mini.width - 8;
			add(mini);
			parts.push(mini);
		}

		// todo entra desde la derecha
		for (spr in parts)
		{
			var x:Float = spr.x;
			spr.x += FlxG.width - PANEL_X;
			FlxTween.tween(spr, {x: x}, 0.35, {ease: FlxEase.quintOut});
		}
		changeSelection(0, false);
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	function pixelSprite(name:String, x:Float, y:Float):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(x, y).loadGraphic(Paths.image('sonic_exe/pause/' + name));
		spr.scale.set(PIXEL, PIXEL);
		spr.updateHitbox();
		spr.antialiasing = false;
		spr.scrollFactor.set();
		add(spr);
		parts.push(spr);
		return spr;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (mini != null && !leaving) // el Sonic flota un poco al lado de la opcion elegida
			mini.offset.y = Math.round(Math.sin(FlxG.game.ticks / 250) * 2) * PIXEL;
		if (leaving) return;

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('sonic_exe/cancelMenu'), 0.6);
			resume();
			return;
		}
		if (!controls.ACCEPT) return;

		var item:String = ITEMS[curSelected];
		if (item == 'continue')
		{
			resume();
			return;
		}
		leaving = true;
		FlxG.sound.play(Paths.sound('sonic_exe/confirmMenu'), 0.6);
		FlxFlicker.flicker(options[curSelected], 0.6, 0.06, true);
		new FlxTimer().start(0.6, function(_)
		{
			switch (item)
			{
				case 'restart': PauseSubState.restartSong();
				case 'options': PauseSubState.openOptions();
				default: PauseSubState.exitToMenu();
			}
		});
	}

	/** Seguir: el panel vuelve a salir por la derecha y se cierra la pausa. */
	function resume()
	{
		leaving = true;
		music.fadeOut(0.2, 0);
		FlxTween.tween(bg, {alpha: 0}, 0.2);
		for (spr in parts)
			FlxTween.tween(spr, {x: spr.x + FlxG.width - PANEL_X}, 0.2, {ease: FlxEase.quintIn});
		new FlxTimer().start(0.21, function(_) close());
	}

	function changeSelection(change:Int, sound:Bool = true)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, ITEMS.length - 1);
		if (sound) FlxG.sound.play(Paths.sound('sonic_exe/scrollMenu'), 0.6);
		for (i => option in options) option.alpha = i == curSelected ? 1 : 0.45;
		var chosen:FlxSprite = options[curSelected];
		underline.y = chosen.y + chosen.height + PIXEL * 3;
		if (mini != null) mini.y = chosen.y + (chosen.height - mini.height) / 2;
	}

	override function destroy()
	{
		music.destroy();
		super.destroy();
	}
}
