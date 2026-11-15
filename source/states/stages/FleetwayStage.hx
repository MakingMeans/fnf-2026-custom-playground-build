package states.stages;

import flixel.FlxBasic;
import flixel.FlxObject;
import objects.Character;
import objects.Note;
import psychlua.LuaUtils;
import shaders.ColorSwap;
import substates.GameOverCustom;
import substates.GameOverSubstate;

/**
 * chaos (Vs Sonic.exe, carpeta FLEETWAY), escenario "fleetw". Port de stages/fleetw.hx,
 * data/chaos/emeralds.hx, custom_events/chaosEvent.lua y FlashCamera.lua del mod:
 *  - Fondo por capas (su makeBackground), con la intro de Sonic cayendo a la fuente.
 *  - Una ventanita con Fleetway (camOpp) en los pasos 464-529 y 1600. Como en el mod, es una camara
 *    "por defecto" mas: dentro se ve el escenario entero desde su encuadre, no solo a Fleetway.
 *  - 7 notas "emerald" opcionales: cada una que se coge vuela hacia BF y se ilumina abajo en el
 *    HUD. Con las 7, BF se transforma en Super (paso 1008) y Fleetway cambia sus frases.
 *  - Laser ("eatthis"): hay que pulsar la tecla de esquivar (ESPACIO por defecto) en el ultimo
 *    segundo antes del disparo, o BF muere.
 * Cambios a proposito (decisiones del usuario):
 *  - Sin las 7 esmeraldas la cancion se puede pasar (el mod mataba a BF en el paso 1999 y en el laser
 *    despues del pulso 252) y Fleetway hace lo mismo que con ellas (frases, animaciones, letras, zoom
 *    y el fundido final): solo se salta su "What?" (pasos 1034-1039), que reacciona al Super BF. Lo
 *    que si cambia es lo de BF: transformarse, sus notas -alt y las esmeraldas que absorbe.
 *    Conseguirlas es la salida secreta del nivel en el mapa (OverworldState.songSecret).
 *  - La intro se ve cada vez que se empieza o se reintenta la cancion (el mod, solo la primera).
 */
@:access(states.PlayState)
@:access(backend.MusicBeatState)
class FleetwayStage extends SonicStage
{
	static final COLORS:Array<String> = ['green', 'yellow', 'blue', 'purple', 'gray', 'cyan', 'red'];
	/**
	 * Tamano de Fleetway y de BF en el motor del mod (flixel-animate: el recuadro del timeline principal
	 * de su atlas), que sus scripts usaban con getMidpoint() y height. Aqui los atlas miden 0x0.
	 */
	static final FLEETWAY_SIZE:Array<Float> = [1601, 1475];
	static inline final BF_HEIGHT:Float = 895;
	static final COLORS_HEX:Array<FlxColor> = [0xFF00FF44, 0xFFFFFF00, 0xFF2736FF, 0xFFFF35E4, 0xFFCECECE, 0xFF32FFFF, 0xFFFF0000];

	// ---- fondo (chaosBG de fleetw.hx)
	var bgBack:Array<FlxSprite>;
	var bgTop:Array<FlxSprite>;
	var fuentes:Array<FlxSprite>; // el rayo y su copia aditiva (tag 'fuente')
	var shaded:Array<FlxSprite>;  // '4', '3', '2' y las columnas: con el ColorSwap durante la intro
	var floor2:FlxSprite;
	var statue:FlxAnimate;         // 'sonic'
	var porker:FlxSprite;          // 'cochinito'
	var colorShader:ColorSwap;

	// ---- ventanita de Fleetway
	var camOpp:FlxCamera;
	var bgCam:FlxCamera;
	var black:FlxSprite;
	var camOppBG:FlxSprite;
	/** A donde mira la ventanita: el punto de camara de Fleetway (DADx/DADy) mas lo que se mueva el. */
	var oppFocus:FlxObject;
	var timeline:Array<{step:Int, run:Void->Void}>;

	// ---- esmeraldas (emeralds.hx)
	var masterEmerald:FlxSprite;
	var emeralds:Array<EmeraldOrbit>;
	var emeraldNotes:Array<Note>;
	var resolvedNotes:Array<Note>;
	var spawnedNotes:Array<Note>;
	var collectedEmeralds:Int;
	var missedEmeralds:Int;
	var canTransform:Bool;
	var muteOpponentVocals:Bool;
	var scaleMult:Float;
	var velocityMult:Float;
	var radiusMult:Float;
	var time:Float;
	var masterTime:Float;
	var gradient:FlxSprite;
	var hudEmeralds:FlxSpriteGroup;

	// ---- laser (chaosEvent.lua)
	var eatThis:FlxSprite;
	var spacebar:FlxSprite;
	var attacking:Bool;
	var attackBeats:Int;
	var firstAttack:Bool;
	var dodgeHold:Float;
	var dadFloat:Bool;
	var bfFloat:Bool;
	var dadHome:FlxPoint;
	var floatTime:Float;
	var bfFloatTime:Float;
	var flash:FlxSprite;

	static inline final INITIAL_SCALE:Float = 0.3;
	static inline final WAVE_AMPLITUDE:Float = 30;
	static inline final WAVE_FREQUENCY:Float = 3;
	static inline final WAVE_PHASE:Float = 0.6;

	override function create()
	{
		super.create();
		hudFrame = 'chaos/hud/hud_chaos';
		hudFrameOffset.set(-190, -75);
		GameOverSubstate.custom = new ChaosGameOver();
		canTransform = false;
		muteOpponentVocals = false;
		collectedEmeralds = missedEmeralds = 0;
		scaleMult = 1;
		velocityMult = 0.5;
		radiusMult = 1;
		time = masterTime = 0;
		attacking = false;
		attackBeats = 0;
		firstAttack = false;
		dodgeHold = 0;
		dadFloat = bfFloat = false;
		floatTime = bfFloatTime = 0;
		emeralds = [];
		emeraldNotes = [];
		resolvedNotes = [];
		spawnedNotes = [];

		buildCameras();
		buildBackground();
		buildTimeline();
		setStartCallback(introCutscene);
	}

	// ------------------------------------------------------------------ fondo
	function bgSprite(path:String, x:Float, y:Float, scaleX:Float, scaleY:Float, ?scrollX:Float = 1, ?scrollY:Float = 1, ?anims:Array<{name:String, looped:Bool}>):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(x, y);
		if (anims != null)
		{
			spr.frames = Paths.getSparrowAtlas(path);
			for (anim in anims) spr.animation.addByPrefix(anim.name, anim.name, 24, anim.looped);
			spr.animation.play(anims[0].name);
		}
		else spr.loadGraphic(Paths.image(path));
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.scale.set(scaleX, scaleY);
		spr.updateHitbox();
		spr.scrollFactor.set(scrollX, scrollY);
		return spr;
	}

	/**
	 * Las capas de fleetw.hx. En su makeBackground, las normales van detras de los personajes, las de
	 * layer 'top' delante de ellos y las de 'front' delante de todo.
	 */
	function buildBackground()
	{
		var rayoAnims = [{name: 'ramaquin instancia', looped: true}, {name: 'ramaquintranqui', looped: true}];
		var bg4 = bgSprite('chaos/bg/4', 200, 300, 1, 1, 0.7, 0.9);
		var bg3 = bgSprite('chaos/bg/3', 720, 600, 0.9, 0.9);
		var rayo = bgSprite('chaos/bg/rayo', 1840, -180, 0.85, 0.8, 1, 1, rayoAnims);
		rayo.color = 0xFFCCCCCC;
		var rayoGlow = bgSprite('chaos/bg/rayo', 1840, -180, 0.9, 0.8, 1, 1, rayoAnims);
		rayoGlow.alpha = 0.35;
		rayoGlow.blend = ADD;
		bgBack = [bg4, bg3, rayo, rayoGlow];
		fuentes = [rayo, rayoGlow];

		floor2 = bgSprite('chaos/bg/2', 720, 600, 0.9, 0.9);
		statue = new FlxAnimate(2255, 1640);
		Paths.loadAnimateAtlas(statue, 'chaos/bg/sonic');
		statue.anim.addBySymbol('intro', 'intro', 24, false);
		statue.anim.addBySymbolIndices('fuentes', 'fuentes', [92, 92], 24, false);
		statue.anim.play('intro');
		statue.antialiasing = ClientPrefs.data.antialiasing;
		statue.scale.set(0.545, 0.545);
		statue.updateHitbox();
		// flixel-animate (el del mod) dibuja la animacion desde la esquina del recuadro de su timeline;
		// nuestro flxanimate, desde el (0, 0) del simbolo. El recuadro de 'intro' empieza en
		// (922.4, -56.15) (AnimateBounds de tools/ports/sonic_exe.py): sin esto Sonic caia 500 px a la
		// derecha de la fuente, fuera del plano de la intro. Se suma al offset de updateHitbox, que se
		// compensa con el origen (cambiarlo por este lo bajaba 360 px).
		statue.offset.add(922.4 * 0.545, -56.15 * 0.545);
		var pillars = bgSprite('chaos/bg/1', 1400, 500, 0.9, 1.1, 1.3, 1.1);
		bgTop = [floor2, statue, pillars];
		porker = bgSprite('chaos/bg/puelco', 3900, 2150, 1.2, 1.2, 1.3, 1.3, [{name: 'Porker Lewis', looped: false}]);
		shaded = [bg4, bg3, floor2, pillars];

		for (spr in bgBack) add(spr);

		// como antes de la intro: Sonic quieto arriba, la fuente apagada y el fondo con otro tono
		statue.anim.play('intro', true);
		statue.anim.pause();
		for (spr in fuentes)
		{
			spr.animation.play('ramaquintranqui', true);
			spr.offset.set(0, 0);
		}
		colorShader = new ColorSwap();
		colorShader.hue = Math.abs(182 - 48) / 180;
		colorShader.saturation = -0.2;
		colorShader.brightness = -0.2;
		for (spr in shaded) spr.shader = colorShader.shader;
	}

	override function createPost()
	{
		super.createPost();

		// capas de delante (despues de los personajes)
		for (spr in bgTop) add(spr);
		add(porker);

		// Fleetway entra flotando: empieza desplazado y "tweendad" lo devuelve a su sitio
		dad.alpha = 0;
		dadHome = FlxPoint.get(dad.x, dad.y);
		dadGroup.setPosition(dadGroup.x + 200, dadGroup.y - 162);
		dad.cameras = [camGame, camOpp];

		buildEmeralds();
		buildHUDEmeralds();
		buildLaser();

		// el mod: con las esmeraldas, las notas "Alt Animation" de BF solo cantan con -alt despues
		// de transformarse
		for (note in unspawnNotes)
			if (note.mustPress && note.animSuffix == '-alt') note.extraData.set('altSuffix', true);
		updateAltNotes();
	}

	// ------------------------------------------------------------------ camaras extra
	function buildCameras()
	{
		camOpp = new FlxCamera();
		camOpp.width = Std.int(FlxG.width / 2 - 80);
		camOpp.height = 200;
		camOpp.x = -camOpp.width;
		camOpp.y = 40;
		camOpp.scroll.set(600, 500);
		camOpp.followLerp = 0.07;
		oppFocus = new FlxObject(0, 0, 1, 1);
		camOpp.zoom = 0.7;
		camOpp.alpha = 0;
		camOpp.active = false;
		camOpp.visible = false; // updateCamOpp la enseña solo mientras esta abierta

		bgCam = new FlxCamera();
		bgCam.bgColor = 0x0;

		// orden del mod (lo metia en la posicion 2, y su motor tenia una camara mas debajo del HUD):
		// juego, bgCam, camOpp, HUD y camOther. Por eso las flechas del rival, que quedan encima de la
		// ventanita, se apagan mientras esta abierta.
		// camOpp es una camara "por defecto", como en el mod (FlxG.cameras.insert(camOpp, 2) sin el
		// tercer argumento): todo lo del escenario se dibuja tambien en ella, y la ventanita ensena el
		// fondo detras de Fleetway. Sin eso salia negra.
		FlxG.cameras.remove(camHUD, false);
		FlxG.cameras.remove(camOther, false);
		FlxG.cameras.add(bgCam, false);
		FlxG.cameras.add(camOpp, true);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		black = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		black.cameras = [bgCam];
		black.alpha = 0;
		add(black);

		camOppBG = new FlxSprite().makeGraphic(Std.int(camOpp.width + 20), Std.int(camOpp.height + 20), FlxColor.WHITE);
		camOppBG.cameras = [bgCam];
		camOppBG.alpha = 0;
		camOppBG.color = FlxColor.BLACK;
		add(camOppBG);
	}

	function buildTimeline()
	{
		function grow()
		{
			FlxTween.tween(camOpp, {width: camOpp.width * 1.1, height: camOpp.height * 1.175}, 0.2, {ease: FlxEase.cubeOut});
			FlxTween.tween(black, {alpha: black.alpha + 0.25}, 0.2);
		}
		timeline = [
			{step: 464, run: function()
			{
				camOpp.active = true;
				camOpp.target = oppFocus; // sin follow(): con LOCKON flixel le pondria una zona muerta
				FlxTween.tween(camOpp, {x: 40, alpha: 1}, 0.25, {ease: FlxEase.cubeInOut});
				for (strum in play.opponentStrums.members) FlxTween.tween(strum, {alpha: 0.25}, 0.5);
			}},
			{step: 512, run: grow},
			{step: 516, run: grow},
			{step: 520, run: grow},
			{step: 524, run: grow},
			{step: 529, run: function()
			{
				camOpp.target = null;
				FlxTween.tween(camOpp, {x: camGame.x, y: camGame.y, width: camGame.width, height: camGame.height}, 0.2, {ease: FlxEase.cubeInOut});
				FlxTween.tween(camOpp, {"scroll.x": camGame.scroll.x, "scroll.y": camGame.scroll.y, zoom: camGame.zoom,
					"targetOffset.x": camGame.targetOffset.x, "targetOffset.y": camGame.targetOffset.y}, 0.2, {ease: FlxEase.cubeInOut});
				new FlxTimer().start(0.2, function(_)
				{
					camOpp.active = false;
					camOpp.alpha = 0;
					black.alpha = 0;
				});
				for (strum in play.opponentStrums.members) FlxTween.tween(strum, {alpha: 1}, 0.5);
			}},
			{step: 1600, run: function()
			{
				camOpp.active = true;
				camOpp.width = Std.int(FlxG.width / 2 - 80);
				camOpp.height = 200;
				camOpp.x = -camOpp.width;
				camOpp.y = 40;
				camOpp.target = oppFocus;
				camOpp.followLerp = 0.07;
				camOpp.zoom = 0.7;
				camOpp.alpha = 0;
				for (strum in play.opponentStrums.members) FlxTween.tween(strum, {alpha: 0.1}, 0.2);
				for (strum in play.opponentStrums.members) FlxTween.tween(strum, {alpha: 1}, 0.5, {startDelay: 1});
				FlxTween.tween(camOpp, {x: 40, alpha: 1}, 0.25, {ease: FlxEase.cubeInOut});
				FlxTween.tween(camOpp, {x: -camOpp.width, alpha: 0}, 0.5, {ease: FlxEase.cubeInOut, startDelay: 0.75, onComplete: function(_) camOpp.active = false});
			}}
		];
	}

	function updateCamOpp()
	{
		// cerrada no se dibuja: si no, todo el escenario se pintaria dos veces en cada fotograma
		camOpp.visible = camOpp.active || camOpp.alpha > 0;
		if (!camOpp.active)
		{
			camOppBG.alpha = 0;
			return;
		}
		camOppBG.setPosition(camOpp.x - 10, camOpp.y - 10);
		camOppBG.setGraphicSize(Std.int(camOpp.width + 20), Std.int(camOpp.height + 20));
		camOppBG.updateHitbox();
		camOppBG.alpha = camOpp.alpha;

		// El mod seguia a Fleetway (su centro) mas (-400, -500). Su centro sale de su tamano en el motor
		// del mod (FLEETWAY_SIZE); aqui los personajes atlas miden 0x0.
		var x:Float = dad.x + FLEETWAY_SIZE[0] / 2 - 400;
		var y:Float = dad.y + FLEETWAY_SIZE[1] / 2 - 500;
		switch (dad.getAnimationName())
		{
			case 'singLEFT': x -= 75;
			case 'singDOWN': y += 150;
			case 'singUP': y -= 130;
			case 'singRIGHT': x += 100; y += 60;
		}
		oppFocus.setPosition(x, y);
	}

	// ------------------------------------------------------------------ intro (cada vez)
	function introCutscene()
	{
		// la intro mira a la fuente donde cae Sonic: el punto medio de cameraSettings.json (MiddleX y
		// MiddleY, debajo de la esmeralda maestra). Sin esto miraba al punto de Fleetway, que aun no esta
		cameraCenter = true;
		updateCameraTarget();
		camGame.snapToTarget();
		play.cameraSpeed = 9999;
		boyfriend.visible = false;
		camHUD.alpha = 0;
		camGame.zoom = 1;

		new FlxTimer().start(0.4, function(_)
		{
			play.cameraSpeed = 1;
			FlxTween.tween(camGame, {zoom: 1.2}, 1.2, {ease: FlxEase.circInOut});
			FlxTween.tween(camGame.targetOffset, {y: 20}, 1.2, {ease: FlxEase.circInOut});
			statue.anim.play('intro', true);
			FlxG.sound.play(Paths.sound('chaos/robot'));
			camGame.flash(0xFFFF0000, 0.7, null, true);

			new FlxTimer().start(0.95, function(_)
			{
				FlxG.sound.play(Paths.sound('chaos/sonicscream'), 0.85);

				// la estatua pasa detras del suelo de la fuente
				new FlxTimer().start(1.22, function(_)
				{
					remove(statue, true);
					insert(members.indexOf(floor2), statue);
				});

				new FlxTimer().start(4, function(_)
				{
					cameraCenter = false; // y la camara pasa a seguir a quien canta
					startCountdown();
					FlxG.sound.play(Paths.sound('chaos/beam'), 0.6);
					camGame.flash(0xFFFFFFBB, 1, null, true);
					FlxTween.num(0.05, 0.0, 0.75, null, function(v:Float) camGame.shake(v, 0.025));
					FlxTween.tween(camHUD, {alpha: 1}, 0.5, {startDelay: 6.5});
					boyfriend.visible = true;
					FlxTween.tween(camGame, {zoom: 0.6}, 0.6, {ease: FlxEase.circOut});
					for (spr in shaded) spr.shader = null;
					for (spr in fuentes)
					{
						spr.animation.play('ramaquin instancia', true);
						spr.offset.set(75, -25);
					}
				});
			});
		});
	}

	// ------------------------------------------------------------------ esmeraldas
	function buildEmeralds()
	{
		var odd:Bool = FlxG.random.bool(1); // el 1 % de las veces giran en otro sitio, como en el mod
		masterEmerald = new FlxSprite(1925, 1050);
		masterEmerald.frames = Paths.getSparrowAtlas('chaos/bg/emerals/master');
		masterEmerald.animation.addByPrefix('anim', 'Símbolo', 24, true);
		masterEmerald.animation.play('anim');
		masterEmerald.scale.set(0.5, 0.5);
		masterEmerald.antialiasing = ClientPrefs.data.antialiasing;
		// delante del rayo y detras de su copia brillante
		insert(members.indexOf(fuentes[1]), masterEmerald);

		for (i in 0...7)
		{
			var spr:FlxSprite = new FlxSprite(0, 1450);
			spr.frames = Paths.getSparrowAtlas('chaos/bg/emerals/' + COLORS[i]);
			spr.animation.addByPrefix('anim', 'Símbolo', 24, true);
			spr.animation.play('anim');
			spr.scale.set(INITIAL_SCALE, INITIAL_SCALE);
			spr.updateHitbox();
			spr.antialiasing = ClientPrefs.data.antialiasing;
			insert(members.indexOf(boyfriendGroup) - 1, spr);
			emeralds.push({sprite: spr, moving: true, radius: 275, target: masterEmerald, targetRef: masterEmerald, xOffset: odd ? -25 : 475});
		}

		var count:Int = 0;
		for (note in unspawnNotes)
		{
			if (note.noteType != 'emerald') continue;
			var index:Int = count++;
			note.texture = 'chaos/bg/emerals/' + COLORS[index % 7];
			note.animation.addByPrefix('emerald', 'Símbolo', 24, true);
			note.animation.play('emerald');
			note.extraData.set('emeraldIndex', index);
			note.scale.set(0.45, 0.45);
			note.updateHitbox();
			note.ratingDisabled = true;
			note.noAnimation = true;
			note.ignoreNote = !play.cpuControlled; // con botplay el bot las coge
			note.hitHealth = 0;
			note.missHealth = 0;
			emeraldNotes.push(note);
		}

		gradient = new FlxSprite().loadGraphic(Paths.image('chaos/grad'));
		gradient.cameras = [camHUD];
		gradient.alpha = 0;
		gradient.y = ClientPrefs.data.downScroll ? -gradient.height / 2 : FlxG.height - gradient.height / 2;
		insert(0, gradient);
	}

	function buildHUDEmeralds()
	{
		hudEmeralds = new FlxSpriteGroup();
		hudEmeralds.cameras = [camHUD];
		insert(0, hudEmeralds);
		for (i in 0...7)
		{
			var spr:FlxSprite = new FlxSprite(i * 60, 0).loadGraphic(Paths.image('chaos/hud/emerald'));
			spr.active = false;
			spr.scale.set(0.09, 0.09);
			spr.updateHitbox();
			spr.color = 0xFF111111;
			spr.antialiasing = ClientPrefs.data.antialiasing;
			hudEmeralds.add(spr);
		}
		hudEmeralds.setPosition((FlxG.width - hudEmeralds.width) / 2, ClientPrefs.data.downScroll ? 160 : 590);
		new FlxTimer().start(5, function(_) bumpHUDEmeralds(), 0);
	}

	function bumpHUDEmeralds()
	{
		var index:Int = 0;
		new FlxTimer().start(0.3, function(_)
		{
			var spr:FlxSprite = hudEmeralds.members[index];
			if (spr == null || spr.scale.x < 0.15) return;
			FlxTween.tween(spr, {y: spr.y - 10}, 0.25);
			FlxTween.tween(spr, {y: spr.y}, 0.25, {startDelay: 0.25});
			index++;
		}, 7);
	}

	function collectEmerald(note:Note)
	{
		var index:Int = note.extraData.get('emeraldIndex');
		var orbit:EmeraldOrbit = emeralds[index];
		if (orbit == null || !orbit.moving || orbit.targetRef != masterEmerald) return;

		FlxG.sound.play(Paths.sound('chaos/emerald'));
		orbit.moving = false;
		FlxTween.tween(orbit.sprite, {x: boyfriend.x, y: boyfriend.y + BF_HEIGHT / 6}, 2, {ease: FlxEase.cubeInOut, onComplete: function(_)
		{
			orbit.target = boyfriend;
			orbit.targetRef = boyfriendGroup;
			orbit.moving = true;
			orbit.radius = 190;
			orbit.xOffset = 100;
		}});
		collectedEmeralds++;

		var hud:FlxSprite = hudEmeralds.members[index];
		hud.color = COLORS_HEX[index];
		FlxTween.tween(hud, {"scale.x": 0.22, "scale.y": 0.22}, 0.25, {ease: FlxEase.cubeOut});
		FlxTween.tween(hud, {"scale.x": 0.18, "scale.y": 0.18}, 0.3, {ease: FlxEase.cubeIn, startDelay: 0.3});
		if (index == 6 && missedEmeralds == 0) FlxTween.tween(hudEmeralds, {alpha: 0}, 2);

		FlxTween.cancelTweensOf(gradient);
		gradient.alpha = 1;
		FlxTween.tween(gradient, {alpha: 0}, 0.4);

		if (collectedEmeralds >= 7 && !canTransform)
		{
			canTransform = true;
			states.OverworldState.songSecret = true; // salida secreta del nivel en el mapa
			updateAltNotes();
		}
	}

	function missEmerald()
	{
		missedEmeralds++;
		FlxTween.cancelTweensOf(gradient);
		FlxTween.tween(gradient, {alpha: 0}, 0.25);
	}

	/** Sin transformarse, BF canta sus notas "Alt Animation" sin el -alt (onSpawnNote del mod). */
	function updateAltNotes()
	{
		for (note in unspawnNotes)
			if (note.extraData.exists('altSuffix')) note.animSuffix = canTransform ? '-alt' : '';
		for (note in play.notes.members)
			if (note != null && note.extraData.exists('altSuffix')) note.animSuffix = canTransform ? '-alt' : '';
	}

	function updateEmeralds(elapsed:Float)
	{
		time += elapsed * velocityMult;
		masterTime += elapsed * velocityMult * 0.4;
		masterEmerald.offset.y = -FlxMath.fastSin(Math.PI * masterTime) * 80;

		for (index in 0...emeralds.length)
		{
			var orbit:EmeraldOrbit = emeralds[index];
			if (!orbit.moving) continue;

			var sine:Float = FlxMath.fastSin(Math.PI * (time - (index + 1) / emeralds.length) * 2);
			var circular:Float = sine * orbit.radius * radiusMult;

			// ilusion 3D: mas grande delante, mas pequena detras, y cambia de capa en los extremos
			var isBehind:Bool = members.indexOf(orbit.sprite) < members.indexOf(orbit.targetRef);
			var scaleFactor:Float = INITIAL_SCALE + (isBehind ? -(1 - Math.abs(sine)) : 1 - Math.abs(sine)) * 0.175;
			orbit.sprite.scale.set(scaleFactor * scaleMult, scaleFactor * scaleMult);
			if (isBehind && sine >= 0.95)
			{
				remove(orbit.sprite, true);
				insert(members.indexOf(orbit.targetRef) + 1, orbit.sprite);
			}
			else if (!isBehind && sine <= -0.95)
			{
				remove(orbit.sprite, true);
				insert(members.indexOf(orbit.targetRef), orbit.sprite);
			}
			orbit.sprite.x = orbit.xOffset + orbit.target.x + circular;
			orbit.sprite.offset.y = FlxMath.fastSin(time * WAVE_FREQUENCY + index * WAVE_PHASE) * WAVE_AMPLITUDE + 50;
		}

		// emeraldas que aparecen (gradiente de su color) y las que se escapan sin cogerlas
		for (note in emeraldNotes)
		{
			if (resolvedNotes.contains(note)) continue;
			if (!spawnedNotes.contains(note) && play.notes.members.contains(note))
			{
				spawnedNotes.push(note);
				var index:Int = note.extraData.get('emeraldIndex');
				gradient.color = COLORS_HEX[index];
				gradient.scale.set(1, 1);
				gradient.x = note.x - 25;
				FlxTween.tween(gradient, {alpha: 0.6, "scale.y": 8}, 1.75);
			}
			if (note.wasGoodHit) resolvedNotes.push(note);
			else if (Conductor.songPosition - note.strumTime > play.noteKillOffset)
			{
				resolvedNotes.push(note);
				missEmerald();
			}
		}
	}

	// ------------------------------------------------------------------ laser
	function buildLaser()
	{
		eatThis = new FlxSprite();
		eatThis.frames = Paths.getSparrowAtlas('chaos/bg/eat');
		eatThis.animation.addByPrefix('idle', 'eat this', 24, false);
		eatThis.cameras = [camHUD];
		eatThis.scale.set(1.3, 1.3);
		eatThis.updateHitbox();
		eatThis.screenCenter();
		eatThis.visible = false;
		add(eatThis);

		spacebar = new FlxSprite(0, FlxG.height * (ClientPrefs.data.downScroll ? 0.6 : 0.2));
		spacebar.frames = Paths.getSparrowAtlas('chaos/spacebar');
		spacebar.animation.addByPrefix('idle', 'Símbolo 8', 48, false);
		spacebar.animation.play('idle', true);
		spacebar.scale.set(0.6, 0.6);
		spacebar.updateHitbox();
		spacebar.cameras = [camHUD];
		spacebar.screenCenter(X);
		spacebar.visible = false;
		add(spacebar);

		for (sound in ['laser_moment', 'emerald', 'SUPERBF', 'beam', 'robot', 'sonicscream']) Paths.sound('chaos/' + sound);
	}

	function startLaser()
	{
		attacking = true;
		attackBeats = 0;
		play.canPause = false;
		spacebar.visible = true;
		new FlxTimer().start(Conductor.crochet / (1000 / 3) / play.playbackRate, function(_) fireLaser());
	}

	function fireLaser()
	{
		attacking = false;
		play.canPause = true;
		spacebar.visible = false;

		var dodged:Bool = dodgeHold > 0 || play.cpuControlled;
		if (!dodged)
		{
			camGame.shake(0.01, 0.1);
			play.health -= 10;
		}
		else FlxG.sound.play(Paths.sound('chaos/laser_moment'), 1);

		// el Super BF tiene su propio esquive
		boyfriend.playAnim('dodge' + (canTransform && curBeat > 252 ? '-alt' : ''), true);
		boyfriend.specialAnim = true;
		attackBeats = 0;
		dodgeHold = 0;
	}

	// ------------------------------------------------------------------ bucle
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		updateCamOpp();
		if (emeralds.length > 0) updateEmeralds(elapsed);
		if (muteOpponentVocals) play.opponentVocals.volume = 0;

		// esquivar: la tecla da 1 s de proteccion (el mod la tenia fija en ESPACIO)
		if (dodgeHold > 0) dodgeHold -= elapsed;
		if (Controls.instance.justPressed('dodge') && !play.cpuControlled)
		{
			dodgeHold = 1;
			spacebar.visible = false;
		}
		if (eatThis.visible && eatThis.animation.finished) eatThis.visible = false;

		// Fleetway (y el Super BF) flotan
		if (dadFloat)
		{
			floatTime += elapsed;
			dad.setPosition(dadHome.x + Math.cos(floatTime * 0.5) * 100, dadHome.y + Math.sin(floatTime) * 50);
		}
		if (bfFloat)
		{
			bfFloatTime += elapsed;
			boyfriend.setPosition(2910 + Math.cos(bfFloatTime * 0.5 + 0.5) * 100, 1100 + Math.sin(bfFloatTime + 0.5) * 50);
		}

		// que una nota no corte el "eat" de Fleetway ni el esquive de BF (opponentNoteHitPre / goodNoteHitPre)
		var dadEating:Bool = dad.getAnimationName() == 'eat';
		var bfDodging:Bool = boyfriend.getAnimationName().indexOf('dodge') > -1;
		for (note in play.notes.members)
		{
			if (note == null || !note.alive || note.noteType == 'emerald') continue;
			if (!note.extraData.exists('baseNoAnim')) note.extraData.set('baseNoAnim', note.noAnimation);
			note.noAnimation = note.extraData.get('baseNoAnim') || (note.mustPress ? bfDodging : dadEating);
		}
	}

	override function beatHit()
	{
		super.beatHit();
		if (curBeat % 2 == 0) porker.animation.play('Porker Lewis', true);

		if (attacking)
		{
			spacebar.animation.play('idle', true);
			attackBeats++;
			// el mod pedia 'eat', pero Fleetway no tiene esa animacion: alli no hacia nada
			if (attackBeats == 3 && firstAttack && dad.hasAnimation('eat'))
			{
				dad.playAnim('eat', true);
				dad.specialAnim = true;
			}
			if (attackBeats == 2 && !firstAttack && ClientPrefs.data.flashing)
			{
				firstAttack = true;
				eatThis.visible = true;
				eatThis.animation.play('idle', true);
			}
		}
	}

	override function stepHit()
	{
		super.stepHit();
		while (timeline.length > 0 && curStep >= timeline[0].step) timeline.shift().run();

		switch (curStep)
		{
			case 26:
				FlxTween.num(velocityMult, 2.5, 0.5, null, function(v:Float) velocityMult = v);
				FlxTween.num(2.5, 0.55, 1, {startDelay: 2.5}, function(v:Float) velocityMult = v);
			case 954:
				if (canTransform)
				{
					FlxTween.num(radiusMult, 0.1, 4, {ease: FlxEase.backIn}, function(v:Float) radiusMult = v);
					FlxTween.num(velocityMult, 3.5, 4, {onComplete: function(_) FlxTween.num(velocityMult, 0.1, 1, null, function(v:Float) velocityMult = v)},
						function(v:Float) velocityMult = v);
					FlxTween.num(scaleMult, 0, 0.5, {startDelay: 3.5}, function(v:Float) scaleMult = v);
					for (orbit in emeralds)
					{
						var spr:FlxSprite = orbit.sprite;
						FlxTween.num(0, 255, 4, null, function(v:Float) spr.setColorTransform(1, 1, 1, 1, Std.int(v), Std.int(v), Std.int(v), 0));
					}
				}
				else
					FlxTween.num(velocityMult, 3.5, 3, {onComplete: function(_) FlxTween.num(velocityMult, 0.1, 1, null, function(v:Float) velocityMult = v)},
						function(v:Float) velocityMult = v);
			// Decision del usuario: con o sin las esmeraldas, Fleetway hace lo mismo que en la version Super
			// (frases, animaciones, letras, zoom y el fundido final). Lo unico que se salta sin ellas es su
			// "What?" (pasos 1034-1039: audio, animacion y letra), que reacciona a la transformacion de BF.
			// El mod, sin ellas, cambiaba "again" por "2again", se saltaba el resto de frases callando su
			// voz (y como nada le devolvia el volumen, se quedaba muda hasta el final) y subia el dano.
			case 1034:
				if (canTransform)
				{
					playAnimOn(dad, 'what');
					lyric('lyrics.chaos.6', 1);
				}
				else muteOpponentVocals = true;
			case 1039:
				if (muteOpponentVocals)
				{
					muteOpponentVocals = false;
					play.opponentVocals.volume = 1; // PlayState no la vuelve a subir
				}
			case 1040:
				playAnimOn(dad, 'again');
			case 1070:
				play.triggerEvent('Alt Idle Animation', 'dad', '-alt', Conductor.songPosition);
			case 1216:
				playAnimOn(dad, 'grrr');
				lyric('lyrics.chaos.16', 1);
				tweenCameraZoom('0.8, true', '0.75, sineInOut');
			case 1322:
				playAnimOn(dad, 'showyou');
				lyric('lyrics.chaos.8', 1);
				tweenCameraZoom('1, true', '0.9, smootherStepInOut');
			case 1345: lyric('lyrics.chaos.8', 2);
			case 1347: lyric('lyrics.chaos.8', 3);
			case 1352: lyric('lyrics.chaos.8', 4);
			case 1356: lyric('lyrics.chaos.8', 5);
		}
	}

	function playAnimOn(char:Character, anim:String)
	{
		char.playAnim(anim, true);
		char.specialAnim = true;
	}

	/** Letra en pantalla (evento "Normal Lyrics"): lo pinta SonicStage. */
	function lyric(key:String, index:Int)
	{
		play.triggerEvent('Normal Lyrics', key, Std.string(index), Conductor.songPosition);
	}

	override function countdownTick(count:Countdown, num:Int)
	{
		// onCountdownStarted del mod: las esmeraldas arrancan girando deprisa
		if (num == 0) FlxTween.num(4, 0.55, 1.5, null, function(v:Float) velocityMult = v);
	}

	override function goodNoteHit(note:Note)
	{
		super.goodNoteHit(note);
		if (note.noteType == 'emerald') collectEmerald(note);
	}

	override function noteMissPress(direction:Int)
	{
		if (curBeat > 252 && canTransform)
			boyfriend.playAnim(play.singAnimations[direction] + 'miss-alt', true);
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		super.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime);
		switch (eventName)
		{
			case 'chaosEvent':
				switch (value1)
				{
					case 'tweendad':
						FlxTween.tween(dad, {x: dadHome.x}, 1 / play.playbackRate, {ease: FlxEase.smoothStepInOut, onComplete: function(_) dadFloat = true});
						FlxTween.tween(dad, {y: dadHome.y}, 1 / play.playbackRate, {ease: FlxEase.cubeInOut});
					case 'eatthis':
						startLaser();
					case 'superanim':
						if (canTransform) playAnimOn(boyfriend, 'super');
					case 'bftransform':
						if (canTransform) transform();
					case 'getblacklmao': // el final: tambien sin las esmeraldas (el mod solo con ellas)
						camGame.alpha = 0;
						new FlxTimer().start(3, function(_) FlxTween.tween(camHUD, {alpha: 0}, 2));
				}

			case 'FlashCamera':
				if (!ClientPrefs.data.flashing) return;
				var a:Array<String> = value1.split(',');
				var b:Array<String> = value2.split(',');
				if (flash == null)
				{
					flash = new FlxSprite().makeGraphic(1980, 720, FlxColor.WHITE);
					flash.cameras = [camOther];
					add(flash);
				}
				FlxTween.cancelTweensOf(flash);
				flash.color = FlxColor.fromString('#' + a[0].trim());
				flash.alpha = a.length > 1 ? Std.parseFloat(a[1]) : 1;
				flash.blend = b.length > 1 ? LuaUtils.blendModeFromString(b[1].trim()) : NORMAL;
				FlxTween.tween(flash, {alpha: 0}, Std.parseFloat(b[0]));
		}
	}

	/** "bftransform": BF se vuelve Super, sube flotando y la camara le sigue arriba. */
	function transform()
	{
		if (hud != null)
		{
			hud.iconBF.changeIcon('chaos-bf-super');
			hud.playerFill.color = 0xFFFED14F;
		}
		FlxTween.tween(boyfriendGroup, {x: 2910 - boyfriend.positionArray[0], y: 1100 - boyfriend.positionArray[1]}, 1, {ease: FlxEase.cubeOut, onComplete: function(_) bfFloat = true});
		FlxG.sound.play(Paths.sound('chaos/SUPERBF'), 0.8);
		camGame.flash(0xFFFFFF00, 1, null, true);
		play.triggerEvent('Alt Idle Animation', 'bf', '-alt', Conductor.songPosition);
		bfCam.set(2900, 1400);
	}

	override function openSubState(SubState:flixel.FlxSubState)
	{
		// onGameOver del mod: fuera la ventanita de Fleetway
		if (Std.isOfType(SubState, GameOverSubstate)) camOpp.visible = bgCam.visible = false;
	}

	override function destroy()
	{
		if (oppFocus != null) oppFocus.destroy();
		if (dadHome != null) dadHome.put();
		super.destroy();
	}
}

/**
 * Game over de chaos (data/chaos/gameOver.hx del mod): BF muerto quieto en pantalla y, al empezar el
 * bucle, Fleetway dice una de sus 12 frases (con subtitulo de lyrics.json) mientras la musica baja;
 * al acabar la frase la musica vuelve a subir. Reintentar: destello rojo.
 * En el mod la frase se cargaba en bucle (load(..., true)); aqui suena una vez.
 */
@:access(substates.GameOverSubstate)
class ChaosGameOver extends GameOverCustom
{
	static final FALLBACK:Array<String> = [
		"That was almost too easy!",
		"Let's do that again some time! When you are little less... death.",
		"I was a little bit skeptical the whole singing thing earlier, but... That was actually kinda fun! Specially considering that I won, Heh.",
		"Who's god now?!",
		"It's all about speed, pal.",
		"That was way past cool! And you are way past death.",
		"That blood crying fakers got nothing on me!",
		"What does 'hyperrealistic' even mean? Like, it's the Super Emeralds involved or...?",
		"If little dolls and hedgehogs covered in blood gives you nightmares, you ain't ready to fight with me.",
		"Looks like fun wasn't so endless after all! Heh?",
		"No, I'm not making an Eggman pisses on the moon joke. Find new material.",
		"Imagine being in an executable file... Heh.. couldn't be me."
	];

	var subtitleCam:FlxCamera;
	var subtitle:FlxText;
	var subtitleBG:FlxSprite;
	var voice:FlxSound;
	var started:Bool = false;

	override function create()
	{
		var bf:Character = sub.boyfriend;
		bf.scrollFactor.set();
		bf.setPosition(500, 300);
		FlxG.camera.target = null;
		FlxG.camera.scroll.set();
		FlxG.camera.zoom = 0.7;

		subtitleCam = new FlxCamera();
		subtitleCam.bgColor = FlxColor.TRANSPARENT;
		subtitleCam.alpha = 0;
		FlxG.cameras.add(subtitleCam, false);

		var line:Int = FlxG.random.int(1, 12);
		var text:String = states.stages.objects.SonicLyrics.phrase(states.stages.objects.SonicLyrics.loadPhrases('chaos'), 'gameover.chaos.$line');
		if (text == null) text = FALLBACK[line - 1];
		subtitle = new FlxText(0, Std.int(FlxG.height * 0.8), Std.int(FlxG.width * 0.75), text);
		subtitle.setFormat(Paths.font('vcr.ttf'), 25, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		subtitle.borderSize = 2;
		subtitle.cameras = [subtitleCam];
		subtitle.screenCenter(X);
		subtitleBG = new FlxSprite(0, subtitle.y).makeGraphic(Std.int(subtitle.textField.textWidth + 8), Std.int(subtitle.height + 2), FlxColor.BLACK);
		subtitleBG.screenCenter(X);
		subtitleBG.alpha = 0.6;
		subtitleBG.cameras = [subtitleCam];
		sub.add(subtitleBG);
		sub.add(subtitle);

		voice = FlxG.sound.load(Paths.sound('chaos/voicelines/$line'));
		voice.onComplete = function()
		{
			if (!sub.isEnding) FlxG.sound.music.fadeIn(1, 0.5, 1);
			hideSubtitle();
		};
	}

	override function update(elapsed:Float)
	{
		if (started || sub.isEnding || sub.boyfriend.getAnimationName() != 'deathLoop') return;
		started = true;
		FlxG.sound.music.fadeOut(1, 0.3);
		voice.play();
		subtitleCam.alpha = 1;
	}

	function hideSubtitle()
	{
		subtitle.visible = subtitleBG.visible = false;
	}

	override function confirm()
	{
		voice.stop();
		hideSubtitle();
		FlxG.camera.flash(0xFFFF0000, 1, null, true);
	}

	override function leave()
	{
		voice.stop();
		hideSubtitle();
	}
}

typedef EmeraldOrbit =
{
	var sprite:FlxSprite;
	var moving:Bool;
	var radius:Float;
	var target:FlxObject;
	var targetRef:FlxBasic;
	var xOffset:Float;
}
