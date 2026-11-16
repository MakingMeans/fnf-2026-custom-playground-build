package substates;

import flixel.addons.display.FlxBackdrop;
import options.ControlsSubState;

/**
 * Menu de pausa de World of Chaos (data/scripts/Pausemenu.hx del mod): fondo que se desplaza, una barra,
 * el dibujo de la fase de Monika en la que se va y cinco botones (seguir, reiniciar, opciones,
 * controles y salir) que entran desde la izquierda. Se maneja con arriba/abajo, la rueda y aceptar.
 * Reiniciar, opciones y salir hacen lo mismo que la pausa de Psych (salir vuelve al mapa o a Freeplay).
 */
@:access(states.PlayState)
class WoCPauseSubState extends MusicBeatSubstate
{
	static final BUTTONS:Array<String> = ['resume', 'reset', 'options', 'controls', 'exit'];

	var pauseCam:FlxCamera;
	var buttons:Array<FlxSprite> = [];
	var curSelected:Int = 0;
	var canSelect:Bool = true;
	var opening:Bool = true;
	var music:FlxSound;
	var controlsCam:FlxCamera;
	var mouseWasVisible:Bool;

	override function create()
	{
		super.create();
		mouseWasVisible = FlxG.mouse.visible;
		FlxG.mouse.visible = true;
		FlxG.sound.play(Paths.sound('woc/open'), 0.3);

		music = new FlxSound().loadEmbedded(Paths.music('woc/pausa_music'), true, true);
		music.play();
		FlxG.sound.list.add(music);

		pauseCam = new FlxCamera();
		pauseCam.bgColor = FlxColor.TRANSPARENT;
		pauseCam.alpha = 0;
		FlxG.cameras.add(pauseCam, false);

		var bg:FlxBackdrop = new FlxBackdrop(Paths.image('woc/pause/pausebg'));
		bg.scale.set(0.8, 0.8);
		bg.velocity.set(-100, -50);
		bg.alpha = 0.6;
		addToPause(bg);

		var bar:FlxSprite = new FlxSprite(-300, -90).loadGraphic(Paths.image('woc/pause/pausebar'));
		bar.scale.set(0.8, 0.8);
		addToPause(bar);
		FlxTween.tween(bar, {x: -160}, 1.2, {ease: FlxEase.cubeOut});

		for (i => name in BUTTONS)
		{
			var button:FlxSprite = new FlxSprite(-500, -100 + i * -10);
			button.frames = Paths.getSparrowAtlas('woc/pause/' + name);
			button.animation.addByPrefix('selected', 'white', 12);
			button.animation.addByPrefix('idle', 'basic', 12);
			button.scale.set(0.7, 0.7);
			button.animation.play('idle');
			addToPause(button);
			buttons.push(button);
			FlxTween.tween(button, {x: -200}, 1.2, {ease: FlxEase.cubeOut, startDelay: i * 0.07});
		}
		buttons[2].y = -230;
		buttons[3].y = -45;
		buttons[4].y = -180;

		// el dibujo de la fase actual (Monika falsa, Monika, Big Monika)
		var phase:Int = switch (PlayState.instance.dad.curCharacter)
		{
			case 'woc-monica': 2;
			case 'woc-big-monica': 3;
			default: 1;
		}
		var art:FlxSprite = new FlxSprite(-200, -80).loadGraphic(Paths.image('woc/pause/fase$phase'));
		art.scale.set(0.8, 0.8);
		addToPause(art);

		for (spr in members) if (Std.isOfType(spr, FlxSprite)) cast(spr, FlxSprite).antialiasing = ClientPrefs.data.antialiasing;
		changeSelection(0);
	}

	function addToPause(spr:FlxSprite)
	{
		spr.scrollFactor.set();
		spr.cameras = [pauseCam];
		add(spr);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (opening) pauseCam.alpha = FlxMath.lerp(pauseCam.alpha, 1, Math.min(1, elapsed * 6));
		if (!canSelect || subState != null) return;

		if (controls.UI_DOWN_P || FlxG.mouse.wheel < 0) changeSelection(1);
		else if (controls.UI_UP_P || FlxG.mouse.wheel > 0) changeSelection(-1);
		if (!controls.ACCEPT) return;

		canSelect = false;
		switch (BUTTONS[curSelected])
		{
			case 'resume':
				opening = false;
				FlxG.sound.play(Paths.sound('woc/confirmMenu'), 0.3);
				FlxTween.cancelTweensOf(pauseCam);
				FlxTween.tween(pauseCam, {alpha: 0, zoom: 1.15}, 1, {ease: FlxEase.cubeOut, onComplete: function(_) close()});
			case 'controls':
				openControls();
			default:
				exitPause(0.25);
		}
	}

	function changeSelection(change:Int)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, buttons.length - 1);
		for (i => button in buttons) button.animation.play(i == curSelected ? 'selected' : 'idle');
		if (change != 0) FlxG.sound.play(Paths.sound('woc/scrollMenu'), 0.3);
	}

	/** Reiniciar, opciones y salir: zoom y fundido a negro, y a los 0.25 s se hace. */
	function exitPause(delay:Float)
	{
		opening = false;
		FlxG.sound.play(Paths.sound('woc/confirmMenu'), 0.3);
		FlxTween.cancelTweensOf(pauseCam);
		FlxTween.tween(pauseCam, {zoom: 1.15}, 1, {ease: FlxEase.cubeOut});
		pauseCam.fade(FlxColor.BLACK, 0.5);
		new FlxTimer().start(delay, function(_) selectOption());
	}

	function selectOption()
	{
		switch (BUTTONS[curSelected])
		{
			case 'reset':
				PauseSubState.restartSong();
			case 'options':
				PauseSubState.openOptions();
			case 'exit':
				PauseSubState.exitToMenu();
		}
	}

	/** Los controles de Psych, encima de la pausa. */
	function openControls()
	{
		controlsCam = new FlxCamera();
		controlsCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(controlsCam, false);
		var controlsMenu:ControlsSubState = new ControlsSubState();
		controlsMenu.cameras = [controlsCam];
		subStateClosed.addOnce(function(_)
		{
			FlxG.cameras.remove(controlsCam);
			controlsCam = null;
			canSelect = true;
		});
		openSubState(controlsMenu);
	}

	override function destroy()
	{
		FlxG.mouse.visible = mouseWasVisible;
		if (music != null) music.destroy();
		if (pauseCam != null) FlxG.cameras.remove(pauseCam);
		super.destroy();
	}
}
