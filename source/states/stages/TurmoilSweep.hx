package states.stages;

import objects.Note;
import states.stages.MarioStage.MarioGameOver;
import substates.GameOverSubstate;

/**
 * Last Course (Mario's Madness V2), escenario "turmoilsweep". Port de su PlayState.hx:
 *  - Sin cuenta atrás ni HUD al principio (aparece en el paso 128) y fundido desde negro.
 *  - "Turmoil Attack": tres avisos y, al tercer pulso, el lengüetazo. Se esquiva con la tecla de
 *    esquivar (ESPACIO por defecto; 0,4 s de protección y 1 s de espera). Si pilla, quita 1.2 de vida.
 *  - Cada nota de Turmoil quita 0.015 de vida mientras quede al menos 0.4.
 *  - Game over: el BF goomba reaparece poco a poco antes de poder reintentar.
 */
@:access(states.PlayState)
class TurmoilSweep extends MarioStage
{
	var warning:FlxSprite;
	var button:BGSprite;
	var blackBar:FlxSprite;
	var isDodging:Bool;
	var dodgeCooldown:Bool;

	override function create()
	{
		super.create();
		// stages/turmoilsweep.json del mod: boyfriend [870, 120, 970, 550, 0.9, 30], opponent [-100, 130, 420, 500, 0.9, 30]
		setCameraPoints([970, 550, 0.9, 30], [420, 500, 0.9, 30]);
		songAuthor = 'FriedFrick ft. Sandi';
		isDodging = dodgeCooldown = false;
		play.skipCountdown = true; // la canción empieza sin cuenta atrás
		GameOverSubstate.custom = new TurmoilGameOver();

		add(new BGSprite('last-course/ThirdBGTrees', -1300, -750, 0.5, 0.5));
		add(new BGSprite('last-course/SecondBGTrees', -1300, -750, 0.8, 0.8));
		add(new BGSprite('last-course/MainFloorAndTrees', -1300, -750, 1, 1));
		// en el mod también iban detrás de los personajes
		add(new BGSprite('last-course/TreeLeaves', -1300, -350, 1.9, 1.9));
		add(new BGSprite('last-course/TreesForeground', -1300, -350, 1.4, 1.4));

		warning = new BGSprite('last-course/warning', -1300, -350, 1.4, 1.4);
		warning.cameras = [camEst];
		warning.alpha = 0;
		warning.screenCenter();
		add(warning);

		var vignette:FlxSprite = new FlxSprite().loadGraphic(Paths.image('last-course/vignette'));
		vignette.antialiasing = ClientPrefs.data.antialiasing;
		vignette.cameras = [camEst];
		vignette.screenCenter();
		add(vignette);

		button = new BGSprite('last-course/button', 30, 550, 1, 1, ['button no press'], false);
		button.animation.addByPrefix('nopress', 'button no press', 12, false);
		button.animation.addByPrefix('press', 'button press', 12, false);
		button.cameras = [camEst];
		button.scale.set(0.25, 0.25);
		button.updateHitbox();
		add(button);

		Paths.sound('last-course/warningT2');
		Paths.sound('last-course/TURMOIL-LENGUETAZO');
	}

	override function createPost()
	{
		// Turmoil va delante de BF
		remove(dadGroup, true);
		insert(members.indexOf(boyfriendGroup) + 1, dadGroup);

		blackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		blackBar.setGraphicSize(Std.int(blackBar.width * 10));
		blackBar.cameras = [camEst];
		add(blackBar);

		camHUD.alpha = 0; // el evento "Ocultar HUD" lo saca en el paso 128

		// el mod: 0.023 de vida por acierto y 0.0475 por fallo
		for (note in unspawnNotes)
		{
			note.hitHealth = 0.023;
			note.missHealth = 0.0475;
		}
		super.createPost();
	}

	override function startSong()
	{
		eventTweens.push(FlxTween.tween(blackBar, {alpha: 0}, 4, {startDelay: 1, ease: FlxEase.quadInOut}));
		eventTweens.push(FlxTween.tween(button, {alpha: 0}, 2, {startDelay: 3, ease: FlxEase.quadInOut}));
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (Controls.instance.justPressed('dodge') && !play.inCutscene && !play.endingSong && !isDodging && !dodgeCooldown
			&& !play.cpuControlled && !play.startingSong)
		{
			boyfriend.playAnim('dodge', true);
			button.animation.play('press');
			isDodging = true;
			dodgeCooldown = true;
			boyfriend.specialAnim = true;
			eventTimers.push(new FlxTimer().start(0.4, function(_)
			{
				isDodging = false;
				boyfriend.specialAnim = false;
			}));
			eventTimers.push(new FlxTimer().start(1, function(_) { dodgeCooldown = false; }));
		}
	}

	override function opponentNoteHit(note:Note)
	{
		super.opponentNoteHit(note);
		if (play.health >= 0.4) play.health -= 0.015;
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		super.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime);
		switch (eventName)
		{
			case 'Turmoil Attack' | 'Char Attack':
				attack();
		}
	}

	/** "Turmoil Attack": avisos en los pulsos 0, 1 y 2, y el lengüetazo en el 3. */
	function attack()
	{
		var beat:Float = Conductor.crochet / 1000;

		FlxG.sound.play(Paths.sound('last-course/warningT2'));
		warning.alpha = 1;
		var wary:Float = warning.y;
		warning.y = wary - 50;
		warning.scale.set(0.7, 0.7);
		eventTweens.push(FlxTween.tween(warning, {y: wary, alpha: 0.2}, 0.5 * beat, {ease: FlxEase.expoOut}));
		eventTweens.push(FlxTween.tween(button, {alpha: 1}, 0.2, {ease: FlxEase.quadOut}));

		eventTimers.push(new FlxTimer().start(beat, function(_)
		{
			FlxG.sound.play(Paths.sound('last-course/warningT2'));
			warning.alpha = 1;
			eventTweens.push(FlxTween.tween(warning.scale, {y: 0.8, x: 0.8}, 0.5 * beat, {ease: FlxEase.elasticOut}));
			eventTweens.push(FlxTween.tween(warning, {alpha: 0.2}, 0.5 * beat, {ease: FlxEase.quadOut}));
		}));

		eventTimers.push(new FlxTimer().start(2 * beat, function(_)
		{
			FlxG.sound.play(Paths.sound('last-course/warningT2'));
			warning.alpha = 1;
			eventTweens.push(FlxTween.tween(warning.scale, {y: 1, x: 1}, 0.5 * beat, {ease: FlxEase.elasticOut}));
			eventTweens.push(FlxTween.tween(warning, {alpha: 0}, 0.5 * beat, {ease: FlxEase.quadOut}));
		}));

		// El mod pedía 0.2083 - 3 pulsos (negativo); FlxTimer usa el valor absoluto, así que Turmoil
		// prepara la lengua 0.2083 s antes del golpe.
		eventTimers.push(new FlxTimer().start(Math.abs(0.2083 - 3 * beat), function(_) playAnimOn(dad, 'preattack')));

		eventTimers.push(new FlxTimer().start(3 * beat, function(_)
		{
			playAnimOn(dad, 'attack');
			FlxG.sound.play(Paths.sound('last-course/TURMOIL-LENGUETAZO'));
			camGame.shake(0.007, 0.15);
			camHUD.shake(0.007, 0.15);

			eventTimers.push(new FlxTimer().start(0.0483, function(_)
			{
				// el último ataque ("Char Attack", paso 1752) llega 0.4 s después de que acabe la música:
				// con la canción ya terminada no quita vida (si no, BF podía morir camino del mapa)
				if (!isDodging && !play.cpuControlled && !play.endingSong)
				{
					boyfriend.playAnim('singRIGHTmiss', true);
					eventTweens.push(FlxTween.tween(play, {health: play.health - 1.2}, 0.2, {ease: FlxEase.quadOut}));
				}
				if (play.cpuControlled)
				{
					button.animation.play('press');
					boyfriend.playAnim('dodge', true);
				}
			}));

			eventTweens.push(FlxTween.tween(button, {alpha: 0}, 0.5 * beat, {startDelay: 0.5, ease: FlxEase.quadOut}));
		}));
	}

	/** "Triggers Last Course" del mod. */
	override function triggers(value:Int, value2:Int)
	{
		switch (value)
		{
			case 0:
				zoomChars = false;
				play.defaultCamZoom = 1.2;
				camGame.zoom = 1.2;
				eventTweens.push(FlxTween.tween(camGame, {zoom: 1}, 5, {ease: FlxEase.cubeInOut}));
			case 2:
				followChars = false;
				play.defaultCamZoom = 0.9;
				eventTweens.push(FlxTween.tween(camGame, {zoom: 0.9}, 6.4, {ease: FlxEase.cubeInOut}));
				eventTweens.push(FlxTween.tween(camPos, {x: 420}, 5, {ease: FlxEase.cubeInOut}));
				eventTweens.push(FlxTween.tween(camPos, {y: 500}, 5, {ease: FlxEase.cubeInOut}));
			case 3:
				followChars = true;
			case 4:
				bfCam.x = 600;
			case 5:
				bfCam.x = 970;
			case 6:
				followChars = false;
				eventTweens.push(FlxTween.tween(camPos, {x: 720}, 0.42, {ease: FlxEase.cubeIn}));
				eventTweens.push(FlxTween.tween(camPos, {y: 500}, 0.42, {ease: FlxEase.cubeIn}));
			case 7:
				bfZoom = dadZoom = 0.75; // "Set Cam Zoom" 0.75
				play.defaultCamZoom = 0.75;
				eventTweens.push(FlxTween.tween(camGame, {zoom: 0.75}, 0.4, {ease: FlxEase.cubeOut}));
			case 8:
				followChars = true;
		}
	}
}

/** Game over de Last Course: tras caer, el BF goomba se desvanece y reaparece en 7 s; hasta entonces no se puede reintentar. */
@:access(substates.GameOverSubstate)
class TurmoilGameOver extends MarioGameOver
{
	var waiting:Bool = false;
	var ready:Bool = false;

	public function new()
	{
		super(1); // el mod ponía 50 BPM: deathLoop cada floor(1 + 50/60) = 1 s
		autoLoop = false;
		endFadeDelay = 0.7; // endFadeTime 2 del mod: 35 % de espera y 65 % de fundido
		endFadeTime = 1.3;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		var bf = sub.boyfriend;
		if (!waiting && bf.getAnimationName() == 'firstDeath' && bf.isAnimationFinished())
		{
			waiting = true;
			new FlxTimer().start(1, function(_)
			{
				bf.alpha = 0;
				FlxTween.tween(bf, {alpha: 1}, 7, {ease: FlxEase.quadInOut});
				ready = true;
				startLoop();
			});
		}
	}

	override function canConfirm():Bool return ready;
}
