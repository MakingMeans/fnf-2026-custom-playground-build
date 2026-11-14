package states.stages;

import objects.Note;
import openfl.filters.ShaderFilter;
import shaders.RippleShader;
import states.stages.MarioStage.MarioGameOver;
import substates.GameOverSubstate;

/**
 * Bad Day (Mario's Madness V2), escenario "superbad". Port de su PlayState.hx ("Triggers Bad Day"):
 *  - Mario entra de un salto con todo a oscuras y el HUD oculto.
 *  - Caparazones: Mario los patea y quitan 0.25 de vida (0.1 con botplay); no se pueden evitar.
 *  - Setas venenosas: anuncian las notas "Bad Poison" (acertarlas cuenta como fallo y sube una
 *    viñeta morada que distorsiona la pantalla con RippleShader).
 *  - Un Mario pixel salta a las flechas, las hunde a pisotones (las sube en downscroll), las cruza
 *    y tira la barra de vida, que cae fuera de la pantalla hasta el "YAHOO" del paso 1312. En
 *    downscroll la coreografía es otra, como en el mod.
 *  - Degradados laterales del color de cada nota, icono de Mario que salta y se gira con el pulso.
 *  - Game over: Mario azul pisotea a BF tres veces y le dice algo antes de irse.
 */
@:access(states.PlayState)
@:access(backend.MusicBeatState)
class SuperBad extends MarioStage
{
	var badGrad1:FlxSprite;
	var badGrad2:FlxSprite;
	var badPoisonVG:FlxSprite;
	var badHUDMario:BGSprite;
	var blackBar:FlxSprite;
	var byecirc:FlxSprite;
	var ripple:RippleShader;
	var rippleFilter:ShaderFilter;
	var rippleOn:Bool;
	var stompsDone:Int;

	override function create()
	{
		super.create();
		stompsDone = 0;
		// stages/superbad.json del mod: boyfriend [570, 50, 650, 380, 1.1, 20], opponent [90, -190, 520, 380, 1.4, 10]
		setCameraPoints([650, 380, 1.1, 20], [520, 380, 1.4, 10]);
		songAuthor = 'RedTV53';
		rippleOn = false;
		GameOverSubstate.custom = new BadDayGameOver(this);

		camHUD.visible = false;

		var lumpy:BGSprite = new BGSprite('bad-day/lumpy', -570, -265, 1, 1);
		lumpy.setGraphicSize(Std.int(lumpy.width * 0.65));
		add(lumpy);
		add(new BGSprite('bad-day/couch', -700, -350, 1, 1));

		badGrad1 = new FlxSprite(0, 0).loadGraphic(Paths.image('bad-day/sideBar'));
		badGrad1.antialiasing = ClientPrefs.data.antialiasing;
		badGrad1.cameras = [camOther];
		badGrad1.visible = false;
		add(badGrad1);

		badGrad2 = new FlxSprite(600, 0).loadGraphic(Paths.image('bad-day/sideBar'));
		badGrad2.antialiasing = ClientPrefs.data.antialiasing;
		badGrad2.cameras = [camOther];
		badGrad2.visible = false;
		badGrad2.flipX = true;
		add(badGrad2);

		badPoisonVG = new FlxSprite().loadGraphic(Paths.image('bad-day/poisonVG'));
		badPoisonVG.scale.set(1.4, 1.4);
		badPoisonVG.screenCenter();
		badPoisonVG.antialiasing = ClientPrefs.data.antialiasing;
		badPoisonVG.cameras = [camOther];
		badPoisonVG.alpha = 0;

		badHUDMario = new BGSprite('bad-day/HUD_Mario', 0, 0, 1, 1, ['mario spin jump'], true);
		badHUDMario.animation.addByPrefix('walk', 'mario walk', 12, true);
		badHUDMario.animation.addByPrefix('spin', 'mario spin jump', 18, true);
		badHUDMario.animation.addByPrefix('jump', 'jump', 12, true);
		badHUDMario.animation.addByPrefix('fall', 'fall', 12, true);
		badHUDMario.antialiasing = false;
		badHUDMario.scale.set(5, 5);
		badHUDMario.cameras = [camHUD];

		blackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		blackBar.setGraphicSize(Std.int(blackBar.width * 10));

		for (sound in ['smw_shell_kick', 'smw_stomp', 'smw_stomp2', 'smw_jump', 'smw_spinjump', 'smw_thud', 'smw_break_block', 'smw_scroll'])
			Paths.sound('bad-day/' + sound);
	}

	override function createPost()
	{
		// Mario va delante de una pantalla negra que tapa el escenario hasta que entra
		remove(dadGroup, true);
		insert(members.indexOf(boyfriendGroup) + 1, blackBar);
		insert(members.indexOf(blackBar) + 1, dadGroup);
		dadGroup.setPosition(-50, 400);

		byecirc = new FlxSprite();
		byecirc.frames = Paths.getSparrowAtlas('bad-day/bye');
		byecirc.animation.addByPrefix('p1', 'goodbye', 15, false);
		byecirc.animation.addByPrefix('p2', 'bye bye', 15, false);
		byecirc.animation.addByPrefix('p3', 'hello', 24, false);
		byecirc.antialiasing = ClientPrefs.data.antialiasing;
		byecirc.screenCenter();
		byecirc.cameras = [camEst];
		byecirc.alpha = 0.0000001;
		byecirc.y -= 2;
		byecirc.x -= 2;
		add(byecirc);
		add(badPoisonVG);

		if (ClientPrefs.data.shaders && !ClientPrefs.data.lowQuality)
		{
			ripple = new RippleShader();
			rippleFilter = new ShaderFilter(ripple);
		}

		for (note in unspawnNotes)
		{
			// el mod: 0.023 de vida por acierto y 0.0475 por fallo
			note.hitHealth = 0.023;
			note.missHealth = 0.0475;
			if (note.noteType == 'Bad Poison')
			{
				note.texture = 'mario_madness/badMario_NOTE_assets';
				note.ignoreNote = note.mustPress;
				note.noAnimation = true;
				note.hitCausesMiss = true;
			}
		}

		super.createPost();

		followChars = false;
		zoomChars = false;
		camGame.zoom = 1.6;
		snapCamPos(280, 400);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		updateStomps();

		// el mod restaba por fotograma, a 60 FPS
		var frames:Float = elapsed * 60;
		var gradMin:Float = ClientPrefs.data.flashing ? 0.15 : 0.1;
		if (badGrad1.alpha >= gradMin) badGrad1.alpha -= 0.01 * frames;
		if (badGrad2.alpha >= gradMin) badGrad2.alpha -= 0.01 * frames;
		badPoisonVG.alpha -= 0.0005 * frames;

		if (ripple != null)
		{
			ripple.iTime.value[0] += elapsed;
			ripple.max_po.value[0] = badPoisonVG.alpha * 45;
			// sin veneno la distorsión es nula: el filtro solo se pone mientras hace algo
			var on:Bool = badPoisonVG.alpha > 0;
			if (on != rippleOn) setRipple(on);
		}
	}

	function setRipple(on:Bool)
	{
		rippleOn = on;
		if (rippleFilter == null) return;
		for (cam in [camGame, camHUD, camEst])
			MarioStage.setCameraFilter(cam, rippleFilter, on);
	}

	/** Lo llama el game over: las otras cámaras ya no se dibujan. */
	public function clearRipple()
	{
		if (rippleOn) setRipple(false);
	}

	static final NOTE_COLORS:Array<FlxColor> = [FlxColor.MAGENTA, FlxColor.CYAN, FlxColor.LIME, FlxColor.RED];

	override function opponentNoteHit(note:Note)
	{
		super.opponentNoteHit(note);
		badGrad1.alpha = ClientPrefs.data.flashing ? 0.4 : 0.2;
		badGrad1.color = NOTE_COLORS[note.noteData % 4];
	}

	override function goodNoteHit(note:Note)
	{
		super.goodNoteHit(note);
		badGrad2.alpha = ClientPrefs.data.flashing ? 0.4 : 0.2;
		badGrad2.color = NOTE_COLORS[note.noteData % 4];
	}

	override function noteMiss(note:Note)
	{
		if (note.noteType == 'Bad Poison')
		{
			FlxG.sound.play(Paths.sound('bad-day/smw_scroll'), 0.8);
			eventTweens.push(FlxTween.tween(badPoisonVG, {alpha: badPoisonVG.alpha + 0.15}, 0.1, {ease: FlxEase.quadOut}));
		}
	}

	/**
	 * El icono de Mario salta y se gira con cada pulso; cuando va perdiendo (su icono de perder) se
	 * queda quieto mirando al frente. El mod además movía el offset de ese icono a un lado, pero como
	 * recolocaba los iconos en cada fotograma no llegaba a verse: aquí no se hace.
	 */
	override function iconBop()
	{
		var beat:Float = Conductor.crochet / 1000;
		var p1 = play.iconP1;
		var p2 = play.iconP2;
		p1.scale.set(1.1, 1.1);
		p2.scale.set(1.1, 1.1); // en el mod el de Mario no volvía a 1

		for (tween in extraTween) tween.cancel();
		if (play.healthBar.percent > 80)
			p2.flipX = false;
		else
		{
			p2.flipX = !p2.flipX;
			p2.y -= 20;
			extraTween.push(FlxTween.tween(p2, {y: p1.y}, 0.5 * beat, {ease: FlxEase.cubeOut}));
		}
		eventTweens.push(FlxTween.tween(p1.scale, {x: 1, y: 1}, 0.5 * beat, {ease: FlxEase.cubeOut}));
	}

	/**
	 * Pisotones del Mario pixel (el modchart del mod): en los pasos 560, 564, 568 y 572 cada flecha
	 * del jugador, de derecha a izquierda, baja 70 px en 2 pasos; con downscroll suben 70 px dos pasos
	 * más tarde (cuando Mario las golpea desde abajo). Se quedan así el resto de la canción.
	 */
	function updateStomps()
	{
		var downScroll:Bool = ClientPrefs.data.downScroll;
		while (stompsDone < 4 && play.curDecStep >= (downScroll ? 562 : 560) + 4 * stompsDone)
		{
			var strum = play.playerStrums.members[3 - stompsDone];
			if (strum != null)
				FlxTween.tween(strum, {y: strum.y + (downScroll ? -70 : 70)}, 2 * Conductor.stepCrochet / 1000, {ease: FlxEase.cubeOut});
			stompsDone++;
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		super.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime);
		if (eventName == 'Triggers Bad Day')
			triggers(Std.int(MarioStage.parseNum(value1)), Std.int(MarioStage.parseNum(value2)));
	}

	/** "Triggers Bad Day" del mod. */
	override function triggers(value:Int, value2:Int)
	{
		var beat:Float = Conductor.crochet / 1000;
		var downScroll:Bool = ClientPrefs.data.downScroll;
		switch (value)
		{
			case 0: // final: "goodbye"
				dadCam.set(500, 390);
				eventTweens.push(FlxTween.tween(badPoisonVG, {alpha: 0}, 0.2, {ease: FlxEase.quadInOut}));
				eventTweens.push(FlxTween.tween(badGrad1, {alpha: 0}, 0.2, {ease: FlxEase.quadInOut}));
				eventTweens.push(FlxTween.tween(badGrad2, {alpha: 0}, 0.2, {ease: FlxEase.quadInOut}));
				eventTweens.push(FlxTween.tween(camHUD, {alpha: 0}, 0.75, {ease: FlxEase.quadInOut}));
				byecirc.alpha = 1;
				byecirc.animation.play('p1');

			case 1:
				byecirc.animation.play('p2');
				byecirc.alpha = 1;

			case 2: // Mario entra de un salto
				eventTweens.push(FlxTween.tween(dadGroup, {x: 90}, 0.8, {}));
				playAnimOn(dad, 'jump1');
				eventTweens.push(FlxTween.tween(dadGroup, {y: -350}, 0.55, {ease: FlxEase.quadOut, onComplete: function(_)
				{
					playAnimOn(dad, 'jump2');
					eventTweens.push(FlxTween.tween(dadGroup, {y: -180}, 0.25, {ease: FlxEase.quadIn}));
				}}));

			case 3: // aterriza: se enciende todo
				blackBar.visible = false;
				playAnimOn(dad, 'singDOWN');
				camHUD.visible = true;
				followChars = true;
				zoomChars = true;
				dadZoom = 1.4;
				FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : FlxColor.BLACK, 0.8);

			case 4: // "lets a go"
				dadCam.set(380, 410);
				dadZoom = 1.7;

			case 5:
				dadCam.set(520, 380);
				dadZoom = 1.4;

			case 6:
				if (value2 == 0) kickShell();
				else kickShroom();

			case 7: // Mario se va corriendo y rebota en GF
				dad.flipX = true;
				playAnimOn(dad, 'walk');
				eventTweens.push(FlxTween.tween(dadGroup, {x: -230}, 1.5 * beat, {ease: FlxEase.quadIn, onComplete: function(_)
				{
					eventTimers.push(new FlxTimer().start(1.5 * beat, function(_)
					{
						playAnimOn(dad, 'run');
						dad.flipX = false;
						eventTweens.push(FlxTween.tween(dadGroup, {x: 90}, 0.6 * beat));
					}));
				}}));
				eventTimers.push(new FlxTimer().start(3.6 * beat, function(_)
				{
					eventTweens.push(FlxTween.tween(dadGroup, {x: 1200}, 2 * beat));
					// el 0.5 % de las veces, la animación secreta del mod
					playAnimOn(dad, FlxG.random.bool(0.5) ? 'vile creature' : 'jump3');
					FlxG.sound.play(Paths.sound('bad-day/smw_jump'), 0.7);
					eventTweens.push(FlxTween.tween(dadGroup, {y: -400}, 0.8 * beat, {ease: FlxEase.quadOut, onComplete: function(_)
					{
						eventTweens.push(FlxTween.tween(dadGroup, {y: -280}, 0.6 * beat, {ease: FlxEase.quadIn, onComplete: function(_)
						{
							FlxG.sound.play(Paths.sound('bad-day/smw_stomp2'), 0.5);
							playAnimOn(gf, 'hit');
							eventTweens.push(FlxTween.tween(dadGroup, {y: -360}, 0.3 * beat, {ease: FlxEase.quadOut, onComplete: function(_)
							{
								eventTweens.push(FlxTween.tween(dadGroup, {y: -120}, 0.3 * beat, {ease: FlxEase.quadIn}));
							}}));
						}}));
					}}));
				}));

			case 8: // Mario vuelve
				badHUDMario.visible = false;
				bfCam.set(650, 380);
				bfZoom = 1.1;
				dadGroup.setPosition(-70, -540);
				eventTweens.push(FlxTween.tween(dadGroup, {x: 90}, beat));
				eventTweens.push(FlxTween.tween(dadGroup, {y: -180}, beat, {ease: FlxEase.quadIn, onComplete: function(_) playAnimOn(dad, 'singDOWN')}));

			case 9: // cámara más cerca de BF
				bfCam.set(730, 420);
				bfZoom = 1.3;

			case 10: // el Mario pixel salta a las flechas y las cruza
				if (gf != null) gf.specialAnim = false;
				add(badHUDMario);
				var strums = play.playerStrums.members;
				if (!downScroll)
				{
					badHUDMario.setPosition(1280, 100);
					badHUDMario.animation.play('spin', true);
					FlxG.sound.play(Paths.sound('bad-day/smw_spinjump'), 0.6);
					eventTweens.push(FlxTween.tween(badHUDMario, {x: strums[3].x + 35}, 1.5 * beat));
					eventTweens.push(FlxTween.tween(badHUDMario, {y: -110}, 0.9 * beat, {ease: FlxEase.quadOut, onComplete: function(_)
					{
						eventTweens.push(FlxTween.tween(badHUDMario, {y: -10}, 0.6 * beat, {ease: FlxEase.quadIn, onComplete: function(_)
						{
							eventTweens.push(FlxTween.tween(badHUDMario, {x: strums[0].x - 110 - 400}, 7.5 * beat));
						}}));
					}}));
				}
				else
					badHUDMario.setPosition(strums[3].x + 105, 800);

			case 11: // saltitos
				if (!downScroll)
				{
					triggers(13, 0);
					eventTweens.push(FlxTween.tween(badHUDMario, {y: -80}, 0.5 * beat, {ease: FlxEase.quadOut, onComplete: function(_)
					{
						eventTweens.push(FlxTween.tween(badHUDMario, {y: -10}, 0.5 * beat, {ease: FlxEase.quadIn}));
					}}));
				}
				else
				{
					badHUDMario.x -= 80;
					badHUDMario.animation.play('jump', true);
					FlxG.sound.play(Paths.sound('bad-day/smw_jump'), 0.7);
					eventTweens.push(FlxTween.tween(badHUDMario, {x: badHUDMario.x - 45}, 0.8 * beat, {startDelay: 0.1, ease: FlxEase.quadIn}));
					eventTweens.push(FlxTween.tween(badHUDMario, {y: 660}, 0.4 * beat, {startDelay: 0.1, ease: FlxEase.quadOut, onComplete: function(_)
					{
						badHUDMario.animation.play('fall', true);
						FlxG.sound.play(Paths.sound('bad-day/smw_stomp2'), 0.5);
						eventTweens.push(FlxTween.tween(badHUDMario, {y: 800}, 0.4 * beat, {ease: FlxEase.linear}));
					}}));
				}

			case 12: // último salto: cae sobre la barra de vida
				if (!downScroll)
				{
					triggers(13, 0);
					eventTweens.push(FlxTween.tween(badHUDMario, {y: -80}, 0.5 * beat, {ease: FlxEase.quadOut, onComplete: function(_)
					{
						eventTweens.push(FlxTween.tween(badHUDMario, {y: 575}, 2 * beat, {ease: FlxEase.quadIn}));
					}}));
				}
				else
				{
					triggers(11, 0);
					eventTimers.push(new FlxTimer().start(1.5 * beat, function(_)
					{
						FlxG.sound.play(Paths.sound('bad-day/smw_shell_kick'), 0.5);
						var shell:FlxSprite = new FlxSprite().loadGraphic(Paths.image('bad-day/shell'));
						shell.scale.set(5, 5);
						shell.screenCenter(X);
						shell.y = 710;
						shell.angle -= 30;
						shell.cameras = [camHUD];
						insert(members.indexOf(badHUDMario) + 1, shell);
						triggers(13, 0);
						eventTweens.push(FlxTween.tween(shell, {angle: 30}, beat));
						eventTweens.push(FlxTween.tween(shell, {y: 60}, beat, {onComplete: function(_)
						{
							eventTweens.push(FlxTween.tween(shell, {angle: 360}, 0.2, {type: LOOPING}));
							eventTweens.push(FlxTween.tween(shell, {x: shell.x + 90}, 1.5));
							eventTweens.push(FlxTween.tween(shell, {y: 900}, 1.5, {ease: FlxEase.backIn, onComplete: function(_) shell.kill()}));
						}}));
					}));
				}

			case 13: // destellito del pisotón
				var flash:FlxSprite = new FlxSprite(badHUDMario.x + 70, badHUDMario.y + 150);
				flash.frames = Paths.getSparrowAtlas('bad-day/HUD_Mario');
				flash.animation.addByPrefix('idle', 'flash', 10, false);
				flash.antialiasing = false;
				flash.cameras = [camHUD];
				flash.scale.set(5, 5);
				if (!downScroll)
					FlxG.sound.play(Paths.sound('bad-day/smw_stomp2'), 0.5);
				else
				{
					flash.screenCenter(X);
					flash.y = 730;
					flash.x += 80;
				}
				insert(members.indexOf(badHUDMario) + 1, flash);
				flash.animation.play('idle', true);

			case 14: // la barra de vida se cae
				moveHealthBar(camEst);
				if (!downScroll)
				{
					for (tween in eventTweens) tween.cancel();
					eventTweens.push(FlxTween.tween(camEst, {y: 500}, 0.8, {ease: FlxEase.backIn}));
					eventTweens.push(FlxTween.tween(camEst, {angle: 20}, 0.8, {ease: FlxEase.cubeIn}));
					camGame.shake(0.03, 0.15);
					camHUD.shake(0.05, 0.1);
					FlxG.sound.play(Paths.sound('bad-day/smw_thud'), 1);
					// Mario rebota en la barra y se cae
					eventTweens.push(FlxTween.tween(badHUDMario, {x: badHUDMario.x - 70}, 1.2 * beat));
					eventTweens.push(FlxTween.tween(badHUDMario, {y: badHUDMario.y - 100}, 0.5 * beat, {ease: FlxEase.quadOut, onComplete: function(_)
					{
						eventTweens.push(FlxTween.tween(badHUDMario, {y: 800}, 0.7 * beat, {ease: FlxEase.quadIn}));
					}}));
				}
				else
				{
					FlxG.sound.play(Paths.sound('bad-day/smw_break_block'), 0.5);
					camEst.shake(0.07, 0.2);
					eventTimers.push(new FlxTimer().start(0.5 * beat, function(_)
					{
						eventTweens.push(FlxTween.tween(camEst, {y: 800}, 1, {ease: FlxEase.quadIn}));
						eventTweens.push(FlxTween.tween(camEst, {x: -80}, 1, {ease: FlxEase.quadIn}));
						eventTweens.push(FlxTween.tween(camEst, {angle: 15}, 1, {ease: FlxEase.quadIn}));
					}));
				}

			case 15: // "YAHOO": vuelve la barra
				camEst.setPosition(0, 0);
				camEst.angle = 0;
				moveHealthBar(camHUD);
				badGrad1.visible = true;
				badGrad2.visible = true;
				FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : FlxColor.BLACK, 1.5);
		}
	}

	function moveHealthBar(cam:FlxCamera)
	{
		play.healthBar.cameras = [cam];
		healthFrame.cameras = [cam];
		play.iconP1.cameras = [cam];
		play.iconP2.cameras = [cam];
	}

	/** Caparazón: Mario lo patea contra BF (no se puede esquivar). */
	function kickShell()
	{
		var beat:Float = Conductor.crochet / 1000;
		playAnimOn(dad, 'shell');
		extraTimers.push(new FlxTimer().start(0.4, function(_)
		{
			FlxG.sound.play(Paths.sound('bad-day/smw_shell_kick'), 0.5);
			var shell:FlxSprite = new FlxSprite().loadGraphic(Paths.image('bad-day/shell'));
			shell.scale.set(4, 4);
			shell.setPosition(dad.x + 140, dad.y + 80);
			add(shell);
			eventTweens.push(FlxTween.tween(shell, {y: shell.y + 40}, 0.5 * beat, {ease: FlxEase.quadIn}));
			eventTweens.push(FlxTween.tween(shell, {x: shell.x + 360}, 0.5 * beat, {onComplete: function(_)
			{
				playAnimOn(boyfriend, 'hit');
				eventTweens.push(FlxTween.tween(play, {health: play.health - (!play.cpuControlled ? 0.25 : 0.1)}, 0.2, {ease: FlxEase.quadOut}));
				FlxG.sound.play(Paths.sound('bad-day/smw_stomp'), 0.5);
				eventTweens.push(FlxTween.tween(shell, {angle: 360}, 0.2, {type: LOOPING}));
				eventTweens.push(FlxTween.tween(shell, {x: shell.x - 90}, 0.8));
				eventTweens.push(FlxTween.tween(shell, {y: 900}, 0.8, {ease: FlxEase.backIn, onComplete: function(_) shell.kill()}));
			}}));
		}));
	}

	/** Seta venenosa: solo anuncia las notas veneno. */
	function kickShroom()
	{
		var beat:Float = Conductor.crochet / 1000;
		playAnimOn(dad, 'shroom');
		extraTimers.push(new FlxTimer().start(0.4, function(_)
		{
			FlxG.sound.play(Paths.sound('bad-day/smw_shell_kick'), 0.5);
			var shroom:FlxSprite = new FlxSprite().loadGraphic(Paths.image('bad-day/shroom'));
			shroom.scale.set(4, 4);
			shroom.setPosition(dad.x + 140, dad.y + 80);
			add(shroom);
			eventTweens.push(FlxTween.tween(shroom, {y: 900}, beat, {ease: FlxEase.quadIn}));
			eventTweens.push(FlxTween.tween(shroom, {x: shroom.x + 200}, beat, {onComplete: function(_) shroom.kill()}));
		}));
	}
}

/** Game over de Bad Day: Mario azul salta tres veces sobre BF y se despide con una frase. */
@:access(substates.GameOverSubstate)
class BadDayGameOver extends MarioGameOver
{
	var stage:SuperBad;
	var badMario:BGSprite;
	var badPoof:BGSprite;
	var followStarted:Bool = false;

	public function new(stage:SuperBad)
	{
		super(2); // el mod ponía 75 BPM: deathLoop cada floor(1 + 75/60) = 2 s
		this.stage = stage;
		autoLoop = false;
		endFadeDelay = 1.4; // endFadeTime 4 del mod: 35 % de espera y 65 % de fundido
		endFadeTime = 2.6;
	}

	override function create()
	{
		stage.clearRipple();

		// El mod lo ponía 85 px a la izquierda y arriba de donde estaba BF en pantalla
		var bf = sub.boyfriend;
		var playBf = PlayState.instance.boyfriend;
		bf.x += -85 - (bf.positionArray[0] - playBf.positionArray[0]);
		bf.y += -85 - (bf.positionArray[1] - playBf.positionArray[1]);
		super.create();
		// la cámara empieza a seguirle en el fotograma 12 de 'firstDeath'
		FlxG.camera.target = null;

		badMario = new BGSprite('bad-day/HUD_Mario_Blue', bf.x - 270, bf.y + 70, 1, 1, ['mario walk'], true);
		badMario.animation.addByIndices('stand', 'mario walk', [0], '', 12, true);
		badMario.animation.addByPrefix('walk', 'mario walk', 12, true);
		badMario.animation.addByPrefix('run', 'mario run', 12, true);
		badMario.animation.addByPrefix('jump', 'jump', 12, true);
		badMario.animation.addByPrefix('fall', 'fall', 12, true);
		badMario.animation.addByPrefix('spin', 'mario spin jump', 18, true);
		badMario.animation.addByPrefix('peace', 'peace', 12, true);
		badMario.antialiasing = false;
		badMario.scale.set(4, 4);
		sub.add(badMario);
		badMario.animation.play('stand');

		badPoof = new BGSprite('bad-day/HUD_Mario_Blue', badMario.x + 60, badMario.y + 130, 1, 1, ['dust cloud'], false);
		badPoof.animation.addByPrefix('poof', 'dust cloud', 12, false);
		badPoof.antialiasing = false;
		badPoof.visible = false;
		badPoof.scale.set(6, 6);
		sub.add(badPoof);
		badPoof.animation.play('poof');

		new FlxTimer().start(1, function(_) stomps());
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		var bf = sub.boyfriend;
		if (!followStarted && bf.getAnimationName() == 'firstDeath' && bf.animation.curAnim != null && bf.animation.curAnim.curFrame >= 12)
		{
			followStarted = true;
			FlxG.camera.follow(sub.camFollow, LOCKON, 0.01);
		}
	}

	override function confirm()
	{
		badMario.visible = false;
	}

	function playIfAlive(sound:String, volume:Float)
	{
		if (!sub.isEnding) FlxG.sound.play(Paths.sound(sound), volume);
	}

	/** Pisotón, pisotón, pisotón y despedida (doCustomGameOver del mod). */
	function stomps()
	{
		var bf = sub.boyfriend;
		badMario.animation.play('walk', true);
		FlxTween.tween(badMario, {x: badMario.x + 30}, 0.15, {ease: FlxEase.quadIn, onComplete: function(_)
		{
			if (!sub.isEnding)
			{
				badMario.animation.play('spin', true);
				playIfAlive('bad-day/smw_spinjump', 0.8);
			}
			FlxTween.tween(badMario, {x: badMario.x + 300}, 0.6, {ease: FlxEase.linear});
			FlxTween.tween(badMario, {y: badMario.y - 100}, 0.25, {ease: FlxEase.quadOut, onComplete: function(_)
			{
				FlxTween.tween(badMario, {y: badMario.y + 150}, 0.35, {ease: FlxEase.quadIn, onComplete: function(_)
				{
					if (!sub.isEnding)
					{
						playIfAlive('bad-day/smw_shell_kick', 0.8);
						playIfAlive('bad-day/fnf_loss_sfx3', 0.4);
						bf.playAnim('secondDeath');
						badPoof.setPosition(badMario.x + 70, badMario.y + 145);
						badPoof.animation.play('poof');
						badPoof.visible = true;
					}
					// salto hacia las pelotas
					FlxTween.tween(badMario, {x: badMario.x + 180}, 0.55, {ease: FlxEase.linear});
					FlxTween.tween(badMario, {y: badMario.y - 40}, 0.15, {ease: FlxEase.quadOut, onComplete: function(_)
					{
						FlxTween.tween(badMario, {y: badMario.y + 160}, 0.4, {ease: FlxEase.quadIn, onComplete: function(_)
						{
							if (!sub.isEnding)
							{
								playIfAlive('bad-day/smw_break_block', 0.8);
								bf.playAnim('thirdDeath');
								badPoof.setPosition(badMario.x + 65, badMario.y + 130);
								badPoof.animation.play('poof');
							}
							// salto al suelo
							FlxTween.tween(badMario, {x: badMario.x + 130}, 0.45, {ease: FlxEase.linear});
							FlxTween.tween(badMario, {y: badMario.y - 40}, 0.15, {ease: FlxEase.quadOut, onComplete: function(_)
							{
								FlxTween.tween(badMario, {y: badMario.y + 160}, 0.3, {ease: FlxEase.quadIn, onComplete: function(_)
								{
									badMario.animation.play('walk', true);
									FlxTween.tween(badMario, {x: badMario.x + 130}, 0.6, {ease: FlxEase.quadIn, onComplete: function(_)
									{
										badMario.animation.play('peace', true);
										if (!sub.isEnding)
										{
											playIfAlive('bad-day/smw_item_reserve', 0.4);
											playIfAlive('bad-day/line' + FlxG.random.int(1, 6), 0.7);
											bf.playAnim('fourthDeath');
										}
										new FlxTimer().start(0.75, function(_)
										{
											badMario.animation.play('walk', true);
											if (!sub.isEnding) startLoop();
											FlxTween.tween(badMario, {x: badMario.x + 240}, 1, {ease: FlxEase.linear});
											FlxTween.tween(badMario, {alpha: 0}, 1, {ease: FlxEase.quadIn});
										});
									}});
								}});
							}});
						}});
					}});
				}});
			}});
		}});
	}
}
