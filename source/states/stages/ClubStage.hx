package states.stages;

import objects.Character;
import objects.Note;
import openfl.filters.ShaderFilter;
import psychlua.LuaUtils;
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;
import states.stages.objects.DokiHUD;
import substates.GameOverCustom;
import substates.GameOverSubstate;
import substates.WoCPauseSubState;

/**
 * World of Chaos (mod "ClubP Literature", hecho en Codename Engine; carpeta clubpe), escenario "club".
 * Port de su stage (club.hx), los scripts de la cancion (Script.hx, modchart.hx) y los globales
 * (CameraMovement.hx, animFix.hx, Shaders.hx, camHUD.hx), los eventos de Codename y los del mod:
 *  - Fondo por capas en tres fases (cambia en los pasos 446 y 1786) con gotas que suben en la ultima,
 *    y un panel negro sobre el juego al principio y al final.
 *  - Camara de Codename: sigue al personaje que diga "Camera Movement" (centro + offsets de su XML y del
 *    escenario, guardados en camera_position), se asoma 15 px hacia la flecha que canta y
 *    "Camera Position" la fija en un punto. Zoom por eventos y "bops" cada N pulsos.
 *  - Shaders adjustColor (juego y HUD: Saturation/Hue/Brightness/Contrast Effect) y distortion (juego).
 *  - Barras de cine (evento "bar"), flash/fundido de camara, velocidad de las notas, animaciones alt y
 *    "Play Animation" (LOCK: las notas no la cortan).
 *  - La jugadora (Saori) a la izquierda con flechas mas pequenas; las del rival no se ven.
 *  - HUD (DokiHUD), pausa (WoCPauseSubState) y game over (WoCGameOver) del mod.
 * Los eventos de Codename llegan como "WoC <nombre>" con sus parametros en JSON (tools/ports/world_of_chaos.py).
 * Nada de campos con valor inicial: create() se llama desde el constructor de BaseStage.
 */
@:access(states.PlayState)
@:access(backend.MusicBeatState)
@:access(flixel.FlxCamera)
class ClubStage extends BaseStage
{
	static final BG1:Array<String> = ['1', '2', '3'];
	static final BG2:Array<String> = ['0', '1', '2', '3', '7', '5', '4', '8', '6'];
	static final BG3:Array<String> = ['0', '1', '2'];
	static final SCROLL1:Array<Float> = [0.6, 1.2, 1.3];
	static final SCROLL2:Array<Float> = [0.6, 0.7, 0.85, 1.1, 1.2, 1.3, 1.35, 1.0, 1.0];
	/** Zoom del escenario en el XML del mod (los "Camera Zoom" en modo "stage" lo multiplican). */
	static inline final STAGE_ZOOM:Float = 0.7;
	/** Strums de la jugadora (chart del mod): al 25 % del ancho, escala 0.9 y separacion 1.1. */
	static inline final STRUM_SCALE:Float = 0.9;
	static inline final STRUM_SPACING:Float = 1.1;
	/**
	 * Calificaciones en el mundo, como Codename (nodo "ratings" del escenario en (200, 700)): el grupo
	 * de Psych se pasa a la camara del juego y se desplaza para que caigan ahi.
	 */
	static inline final RATINGS_X:Float = -248;
	static inline final RATINGS_Y:Float = 416;

	var play(get, never):PlayState;
	inline function get_play():PlayState return PlayState.instance;

	// fondo
	var layers1:Array<FlxSprite>;
	var layers2:Array<FlxSprite>;
	var layers3:Array<FlxSprite>;
	var drops:Array<FlxSprite>;
	var dropSpeeds:Array<FlxPoint>;
	var panel:FlxSprite;
	var camBars:FlxCamera;
	var upperBar:FlxSprite;
	var lowerBar:FlxSprite;
	var timeline:Array<{step:Int, run:Void->Void}>;

	// camara
	var cameraTarget:Int; // 0 rival, 1 jugadora, -1 fija ("Camera Position")
	var focusOffset:FlxPoint;
	var cameraTween:FlxTween;
	var zoomTween:FlxTween;
	var tweenZoom:Bool;
	var swaying:Bool;
	var swayTween:FlxTween;
	var bopInterval:Int;
	var bopStrength:Float;
	var speedTween:FlxTween;

	// shaders
	var colorShader:ErrorHandledRuntimeShader;
	var distortion:ErrorHandledRuntimeShader;
	var colorValues:Map<String, Float>;
	var colorTweens:Map<String, FlxTween>;
	var distortionTime:Float;
	var distortionStrength:Float;
	var distortionTween:FlxTween;
	var impactTween:FlxTween;

	// HUD, flechas y animaciones
	var hud:DokiHUD;
	var floatStrums:Bool;
	var strumBaseY:Array<Float>;
	var altAnims:Array<Bool>; // [rival, jugadora]
	var lockedChars:Array<Character>;

	override function create()
	{
		GameOverSubstate.custom = new WoCGameOver();
		// el game over del mod no tiene personaje, sonido de muerte ni musica de Psych
		GameOverSubstate.deathSoundName = GameOverSubstate.loopSoundName = GameOverSubstate.endSoundName = '';
		cameraTarget = 1;
		focusOffset = FlxPoint.get();
		tweenZoom = swaying = floatStrums = false;
		bopInterval = 4;
		bopStrength = 1;
		colorValues = ['hue' => 0.0, 'saturation' => 0.0, 'brightness' => 0.0, 'contrast' => 0.0];
		colorTweens = new Map();
		distortionTime = distortionStrength = 0;
		strumBaseY = [];
		altAnims = [false, false];
		lockedChars = [];

		buildBackground();
		buildTimeline();
	}

	// ------------------------------------------------------------------ fondo (club.hx)
	function bgLayer(folder:Int, file:String, x:Float, scroll:Float):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(x, 120).loadGraphic(Paths.image('woc/bg/$folder/$file'));
		spr.scrollFactor.set(scroll, scroll);
		spr.scale.set(2.5, 2.5); // sin updateHitbox: escala desde el centro, como en el mod
		spr.antialiasing = ClientPrefs.data.antialiasing;
		return spr;
	}

	function buildBackground()
	{
		layers1 = [for (i => file in BG1) bgLayer(1, file, -250, SCROLL1[i])];
		layers2 = [for (i => file in BG2) bgLayer(2, file, -250, SCROLL2[i])];
		layers3 = [for (file in BG3) bgLayer(3, file, -150, 1.2)];
		layers1[0].y = -120;
		layers1[1].y = layers1[2].y = -50;
		layers1[1].scale.set(3, 3);
		layers1[2].scale.set(3, 3);
		layers2[4].y = 100;
		layers2[0].y = layers2[1].y = -100;
		layers2[2].y = 0;
		layers2[6].scale.set(2.7, 2.7);
		for (spr in layers2.concat(layers3)) spr.visible = false;

		// detras de los personajes (postCreate de club.hx los metia justo antes de Monika, en este orden)
		for (spr in [layers3[0], layers2[0], layers2[1], layers2[2], layers1[0]]) add(spr);

		// gotas que suben (fase 3), tambien detras de los personajes
		drops = [];
		dropSpeeds = [];
		var frames = Paths.getSparrowAtlas('woc/bg/3/drops');
		for (i in 0...20)
		{
			var drop:FlxSprite = new FlxSprite(250, 1200);
			drop.frames = frames;
			for (j in 1...10) drop.animation.addByPrefix(Std.string(j), 'drops ' + j + '0000', 24, true);
			drop.animation.play(Std.string(FlxG.random.int(1, 9)));
			var scale:Float = FlxG.random.float(0.5, 1.5);
			drop.scale.set(scale, scale);
			drop.angle = FlxG.random.int(-30, 30);
			drop.antialiasing = ClientPrefs.data.antialiasing;
			drop.visible = false;
			add(drop);
			drops.push(drop);
			dropSpeeds.push(FlxPoint.get(FlxG.random.float(-300, 100), FlxG.random.float(50, 300)));
		}
	}

	function updateDrops(elapsed:Float)
	{
		if (!drops[0].visible) return;
		for (i => drop in drops)
		{
			var speed:FlxPoint = dropSpeeds[i];
			drop.y -= speed.y * elapsed;
			drop.x += speed.x * elapsed;
			drop.x += Math.sin(drop.y * 0.02) * 0.5;
			if (drop.y < -1300 || drop.x < -2000)
			{
				drop.setPosition(250, 1200);
				drop.animation.play(Std.string(FlxG.random.int(1, 9)));
				speed.set(FlxG.random.float(-300, 100), FlxG.random.float(50, 300));
			}
		}
	}

	function buildTimeline()
	{
		timeline = [
			{step: 1, run: function() FlxTween.tween(panel, {alpha: 0}, 8)},
			{step: 311, run: startSway},
			{step: 416, run: function() FlxTween.tween(camHUD, {alpha: 0}, 1)},
			{step: 446, run: function()
			{
				for (spr in layers1) spr.visible = false;
				for (spr in layers2) spr.visible = true;
			}},
			{step: 480, run: function() FlxTween.tween(camHUD, {alpha: 1}, 1)},
			{step: 1500, run: function() floatStrums = true}, // modchart.hx
			{step: 1755, run: function()
			{
				stopSway();
				moveDad(-250, -250, 1.5);
				FlxTween.tween(camHUD, {alpha: 0.25}, 1);
			}},
			{step: 1786, run: function()
			{
				for (spr in layers2) spr.visible = false;
				for (spr in layers3) spr.visible = true;
				for (drop in drops) drop.visible = true;
			}},
			{step: 1787, run: function()
			{
				moveDad(250, 150, 0.1);
				FlxTween.tween(camHUD, {alpha: 1}, 1);
			}},
			{step: 2299, run: function()
			{
				FlxTween.tween(panel, {alpha: 1}, 5);
				FlxTween.tween(camHUD, {alpha: 0}, 1);
			}},
		];
	}

	/** Script.hx movia a Monika a una posicion del escenario (sin contar su x/y del XML). */
	function moveDad(x:Float, y:Float, time:Float)
	{
		FlxTween.cancelTweensOf(dad, ['x', 'y']);
		FlxTween.tween(dad, {x: x + dad.positionArray[0], y: y + dad.positionArray[1]}, time / play.playbackRate);
	}

	/** Script.hx: la camara se balancea (+-2.5 grados) entre los pasos 311 y 1755. */
	function startSway()
	{
		swaying = true;
		function swing(angle:Float)
		{
			swayTween = FlxTween.tween(camGame, {angle: angle}, 4, {ease: FlxEase.quadInOut, onComplete: function(_)
			{
				if (swaying) swing(-angle);
			}});
		}
		swing(-2.5);
	}

	function stopSway()
	{
		swaying = false;
		if (swayTween != null) swayTween.cancel();
		FlxTween.tween(camGame, {angle: 0}, 0.5, {ease: FlxEase.quadOut});
	}

	override function createPost()
	{
		// delante de los personajes: el resto de capas, en el orden en que las anadia el mod
		for (spr in [layers1[1], layers1[2]].concat(layers2.slice(3)).concat([layers3[1], layers3[2]])) add(spr);

		// Script.hx: un panel negro tapa el juego al principio (se va en 8 s) y al final
		panel = new FlxSprite().makeGraphic(1280, 750, FlxColor.BLACK);
		panel.scale.set(3.5, 3.5);
		add(panel);

		buildBars();
		buildShaders();
		hud = new DokiHUD(play);
		setupStrums();
		play.comboGroup.cameras = [camGame];
		play.comboGroup.setPosition(RATINGS_X, RATINGS_Y);
		play.camZoomingMult = 0; // los "bops" van en beatHit, cada N pulsos como en Codename
		play.pauseMenuFactory = function() return new WoCPauseSubState();
		GameOverSubstate.characterName = boyfriend.curCharacter; // reusa a BF (no hay personaje muerto)

		// animFix.hx: los trozos de nota larga no repiten la animacion; se congela hasta el final
		for (note in play.unspawnNotes)
			if (note.isSustainNote) note.noAnimation = true;

		// camara: punto de inicio del escenario del mod; luego la mueven los eventos
		play.isCameraOnForcedPos = true;
		camFollow.setPosition(500, 350);
		camGame.snapToTarget();
	}

	/** bar.hx: barras negras de cine en una camara entre el juego y el HUD. */
	function buildBars()
	{
		camBars = new FlxCamera();
		camBars.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.remove(camHUD, false);
		FlxG.cameras.remove(camOther, false);
		FlxG.cameras.add(camBars, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		upperBar = new FlxSprite(-110, -350).makeGraphic(1500, 350, FlxColor.BLACK);
		lowerBar = new FlxSprite(-110, 720).makeGraphic(1500, 350, FlxColor.BLACK);
		for (bar in [upperBar, lowerBar])
		{
			bar.cameras = [camBars];
			add(bar);
		}
	}

	function buildShaders()
	{
		if (!ClientPrefs.data.shaders) return;
		colorShader = play.createRuntimeShader('woc-adjustColor');
		for (name => value in colorValues) colorShader.setFloat(name, value);
		distortion = play.createRuntimeShader('woc-distortion');
		distortion.setFloat('time', 0);
		distortion.setFloat('strength', 0);
		camGame.filters = [new ShaderFilter(colorShader), new ShaderFilter(distortion)];
		camHUD.filters = [new ShaderFilter(colorShader)];
	}

	function setupStrums()
	{
		var swag:Float = Note.swagWidth;
		var startX:Float = FlxG.width * 0.25 - (swag * STRUM_SCALE * 1.5 * STRUM_SPACING + swag * 0.5 * STRUM_SCALE);
		var y:Float = (ClientPrefs.data.downScroll ? FlxG.height - 50 - swag : 50) + swag * 0.5 - swag * STRUM_SCALE * 0.5;
		for (i => strum in play.playerStrums.members)
		{
			strum.scale.set(strum.scale.x * STRUM_SCALE, strum.scale.y * STRUM_SCALE);
			strum.updateHitbox();
			strum.x = startX + swag * STRUM_SCALE * STRUM_SPACING * i;
			strum.y = y;
			strumBaseY.push(y);
		}
		for (strum in play.opponentStrums.members)
		{
			FlxTween.cancelTweensOf(strum);
			strum.alpha = 0; // el chart del mod las tiene ocultas (sus notas copian la transparencia)
		}
		for (note in play.unspawnNotes)
		{
			if (!note.mustPress) continue;
			note.scale.x *= STRUM_SCALE;
			if (!note.isSustainNote) note.scale.y *= STRUM_SCALE;
			note.updateHitbox();
			if (note.isSustainNote) note.offsetX *= STRUM_SCALE;
		}
	}

	// ------------------------------------------------------------------ bucle
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		updateDrops(elapsed);
		if (distortion != null)
		{
			distortionTime += elapsed * 0.25;
			distortion.setFloat('time', distortionTime);
		}
	}

	override function updatePost(elapsed:Float)
	{
		if (tweenZoom) play.defaultCamZoom = camGame.zoom;
		updateCamera();
		updateNotes();
		if (floatStrums)
		{
			// modchart.hx: las flechas flotan desde el paso 1500
			var beat:Float = Conductor.songPosition / 1000 * (Conductor.bpm / 60);
			for (i => strum in play.playerStrums.members)
				strum.y = strumBaseY[i] + Math.sin(beat * Math.PI + i * 0.35) * 30;
		}
		if (hud != null) hud.update(elapsed);
	}

	/** moveCamera() de Codename y CameraMovement.hx. */
	function updateCamera()
	{
		if (cameraTarget < 0) return;
		var char:Character = cameraTarget == 0 ? dad : boyfriend;
		if (char == null) return;
		var x:Float = char.x - char.positionArray[0] + char.cameraPosition[0] + focusOffset.x;
		var y:Float = char.y - char.positionArray[1] + char.cameraPosition[1] + focusOffset.y;
		switch (char.getAnimationName())
		{
			case 'singLEFT' | 'singLEFT-alt': x -= 15;
			case 'singDOWN' | 'singDOWN-alt': y += 15;
			case 'singUP' | 'singUP-alt': y -= 15;
			case 'singRIGHT' | 'singRIGHT-alt': x += 15;
		}
		camFollow.setPosition(x, y);
	}

	/** Sufijo -alt de cada lado ("Alt Animation Toggle") y notas que no cortan una animacion LOCK. */
	function updateNotes()
	{
		var i:Int = lockedChars.length;
		while (i-- > 0)
		{
			var char:Character = lockedChars[i];
			if (char == null || !char.specialAnim || char.isAnimationFinished()) lockedChars.splice(i, 1);
		}
		for (note in play.notes.members)
		{
			if (note == null || !note.alive) continue;
			var line:Int = note.mustPress ? 1 : 0;
			note.animSuffix = altAnims[line] ? '-alt' : '';
			if (!note.extraData.exists('wocNoAnim')) note.extraData.set('wocNoAnim', note.noAnimation);
			note.noAnimation = note.extraData.get('wocNoAnim') || lockedChars.contains(line == 1 ? boyfriend : dad);
		}
	}

	override function beatHit()
	{
		// Codename: "bop" cada bopInterval pulsos con la fuerza de "Camera Modulo Change"
		if (!play.camZooming || !ClientPrefs.data.camZooms || camGame.zoom >= 1.35) return;
		if (bopInterval <= 0 || curBeat % bopInterval != 0) return;
		camGame.zoom += 0.015 * bopStrength;
		camHUD.zoom += 0.03 * bopStrength;
	}

	override function stepHit()
	{
		while (timeline.length > 0 && curStep >= timeline[0].step) timeline.shift().run();
	}

	// ------------------------------------------------------------------ notas (animFix.hx)
	override function goodNoteHit(note:Note)
	{
		play.camZooming = true; // en Codename cualquier nota activa los "bops"
		holdAnimation(boyfriend, note);
	}

	override function opponentNoteHit(note:Note)
	{
		holdAnimation(dad, note);
	}

	override function noteMiss(note:Note)
	{
		if (boyfriend != null && boyfriend.animation.curAnim != null) boyfriend.animation.curAnim.paused = false;
	}

	/** Mientras dura una nota larga la animacion de cantar se queda quieta; al acabar sigue. */
	function holdAnimation(char:Character, note:Note)
	{
		if (char == null || !note.isSustainNote || lockedChars.contains(char)) return;
		char.holdTimer = 0;
		var parent:Note = note.parent;
		var isEnd:Bool = parent == null || parent.tail.length == 0 || note == parent.tail[parent.tail.length - 1];
		if (char.animation.curAnim != null && char.getAnimationName().startsWith('sing'))
			char.animation.curAnim.paused = !isEnd;
	}

	// ------------------------------------------------------------------ eventos
	static function num(value:Dynamic, ?fallback:Float = 0):Float
	{
		if (value == null) return fallback;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	/** Duracion de N pasos (los tweens de Codename se miden en pasos). */
	function stepTime(steps:Dynamic):Float
		return Conductor.stepCrochet / 1000 * num(steps, 4) / play.playbackRate;

	/** CoolUtil.flxeaseFromString de Codename: "circ" + "Out" = circOut. */
	static function easeOf(name:Dynamic, type:Dynamic):Float->Float
	{
		var ease:String = name == null ? 'linear' : Std.string(name);
		if (ease.toLowerCase() == 'linear') return FlxEase.linear;
		return LuaUtils.getTweenEaseByString(ease + (type == null ? '' : Std.string(type)));
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		if (eventName == 'Change Character')
		{
			GameOverSubstate.characterName = boyfriend.curCharacter;
			lockedChars = [];
			return;
		}
		if (!eventName.startsWith('WoC ')) return;
		var params:Array<Dynamic> = try haxe.Json.parse(value1) catch (e:Dynamic) null;
		if (params == null) return;

		switch (eventName.substr(4))
		{
			case 'Camera Movement':
				stopCameraTween();
				cameraTarget = Std.int(num(params[0], 1));
				focusOffset.set(num(params[5]), num(params[6]));
				updateCamera();
				if (params[1] == false) camGame.snapToTarget();
				else if (params[3] != null && params[3] != 'CLASSIC') tweenCamera(params[2], params[3], params[4]);

			case 'Camera Position':
				stopCameraTween();
				cameraTarget = -1;
				var x:Float = num(params[0]);
				var y:Float = num(params[1]);
				if (params[6] == true)
				{
					x += camFollow.x;
					y += camFollow.y;
				}
				camFollow.setPosition(x, y);
				if (params[2] == false) camGame.snapToTarget();
				else if (params[4] != null && params[4] != 'CLASSIC') tweenCamera(params[3], params[4], params[5]);

			case 'Camera Zoom':
				cameraZoom(params);

			case 'Add Camera Zoom':
				if (ClientPrefs.data.camZooms) (params[1] == 'camHUD' ? camHUD : camGame).zoom += num(params[0]);

			case 'Camera Modulo Change':
				bopInterval = Std.int(Math.max(1, Math.round(num(params[0], 4))));
				bopStrength = num(params[1], 1);

			case 'Camera Flash':
				var cam:FlxCamera = params[3] == 'camHUD' ? camHUD : camGame;
				var color:FlxColor = Std.int(num(params[1], -1));
				if (params[0] == true) // al reves: fundido a ese color y, al acabar, de golpe fuera
					cam.fade(color, stepTime(params[2]), false, function() cam._fxFadeAlpha = 0, true);
				else if (ClientPrefs.data.flashing)
					cam.flash(color, stepTime(params[2]), null, true);

			case 'Scroll Speed Change':
				if (play.songSpeedType == 'constant') return;
				if (speedTween != null) speedTween.cancel();
				speedTween = null;
				var speed:Float = num(params[1], 1) * ClientPrefs.getGameplaySetting('scrollspeed');
				if (params[5] == true) speed *= play.songSpeed;
				if (params[0] == false) play.songSpeed = speed;
				else speedTween = FlxTween.num(play.songSpeed, speed, stepTime(params[2]), {ease: easeOf(params[3], params[4])},
					function(v:Float) play.songSpeed = v);

			case 'Alt Animation Toggle':
				var line:Int = Std.int(num(params[2]));
				if (line < 0 || line > 1) return;
				altAnims[line] = params[0] == true;
				var char:Character = line == 0 ? dad : boyfriend;
				char.idleSuffix = params[1] == true ? '-alt' : '';
				char.recalculateDanceIdle();

			case 'Play Animation':
				var line:Int = Std.int(num(params[0]));
				var char:Character = line == 0 ? dad : (line == 1 ? boyfriend : null);
				var anim:String = Std.string(params[1]);
				if (char == null || !char.hasAnimation(anim)) return;
				char.playAnim(anim, params[2] == true);
				char.specialAnim = true; // NONE: dura hasta acabar (las notas si la cortan)
				if (params[3] == 'LOCK' && !lockedChars.contains(char)) lockedChars.push(char);

			case 'bar':
				var speed:Float = num(params[0], 1) / play.playbackRate;
				var distance:Float = num(params[1]);
				FlxTween.cancelTweensOf(upperBar);
				FlxTween.cancelTweensOf(lowerBar);
				if (distance > 0)
				{
					FlxTween.tween(upperBar, {y: -350 + distance}, speed, {ease: FlxEase.quadOut});
					FlxTween.tween(lowerBar, {y: 720 - distance}, speed, {ease: FlxEase.quadOut});
				}
				else
				{
					FlxTween.tween(upperBar, {y: -350}, speed, {ease: FlxEase.quadIn});
					FlxTween.tween(lowerBar, {y: 720}, speed, {ease: FlxEase.quadIn});
				}

			case 'Saturation Effect': colorEffect('saturation', params);
			case 'Hue Effect': colorEffect('hue', params);
			case 'Brightness Effect': colorEffect('brightness', params);
			case 'Contrast Effect': colorEffect('contrast', params);

			case 'Distortion Effect':
				if (params[0] == true) distortionImpact();
				else
				{
					if (distortionTween != null) distortionTween.cancel();
					distortionTween = FlxTween.num(distortionStrength, num(params[1]), stepTime(params[2]), {ease: easeOf(params[3], params[4])},
						function(v:Float)
						{
							distortionStrength = v;
							if (distortion != null) distortion.setFloat('strength', v);
						});
				}
		}
	}

	function tweenCamera(steps:Dynamic, ease:Dynamic, type:Dynamic)
	{
		camGame.target = null; // followEnabled = false mientras dura
		cameraTween = FlxTween.tween(camGame.scroll, {x: camFollow.x - camGame.width * 0.5, y: camFollow.y - camGame.height * 0.5}, stepTime(steps),
			{ease: easeOf(ease, type), onComplete: function(_)
			{
				camGame.target = camFollow;
				cameraTween = null;
			}});
	}

	function stopCameraTween()
	{
		if (cameraTween == null) return;
		cameraTween.cancel();
		cameraTween = null;
		camGame.target = camFollow;
	}

	function cameraZoom(params:Array<Dynamic>)
	{
		var hudCam:Bool = params[2] == 'camHUD';
		var cam:FlxCamera = hudCam ? camHUD : camGame;
		var zoom:Float = num(params[1], 1) * (params[6] == 'direct' ? 1 : STAGE_ZOOM);
		if (params[7] == true) zoom *= cam.zoom;
		if (hudCam)
		{
			// Psych devuelve el HUD a 1 por su cuenta: solo el cambio inmediato o el tween
			if (params[0] == false || params[4] == 'CLASSIC') camHUD.zoom = zoom;
			else FlxTween.tween(camHUD, {zoom: zoom}, stepTime(params[3]), {ease: easeOf(params[4], params[5])});
			return;
		}
		if (zoomTween != null) zoomTween.cancel();
		zoomTween = null;
		tweenZoom = false;
		if (params[0] == false)
		{
			camGame.zoom = zoom;
			play.defaultCamZoom = zoom;
		}
		else if (params[4] == 'CLASSIC') play.defaultCamZoom = zoom;
		else
		{
			tweenZoom = true;
			zoomTween = FlxTween.tween(camGame, {zoom: zoom}, stepTime(params[3]), {ease: easeOf(params[4], params[5]), onComplete: function(_)
			{
				play.defaultCamZoom = zoom;
				tweenZoom = false;
				zoomTween = null;
			}});
		}
	}

	/** Saturation/Hue/Brightness/Contrast Effect: [tween?, valor, pasos, ease, tipo]. */
	function colorEffect(uniform:String, params:Array<Dynamic>)
	{
		if (colorTweens.exists(uniform)) colorTweens.get(uniform).cancel();
		var target:Float = num(params[1]);
		if (params[0] == false)
			setColor(uniform, target);
		else
			colorTweens.set(uniform, FlxTween.num(colorValues.get(uniform), target, stepTime(params[2]), {ease: easeOf(params[3], params[4])},
				function(v:Float) setColor(uniform, v)));
	}

	function setColor(uniform:String, value:Float)
	{
		colorValues.set(uniform, value);
		if (colorShader != null) colorShader.setFloat(uniform, value);
	}

	/** "Distortion Effect" con true: golpe de distorsion (0.9 en 0.1 s y vuelta a 0 en 1 s). */
	function distortionImpact()
	{
		if (distortion == null) return;
		if (impactTween != null) impactTween.cancel();
		impactTween = FlxTween.num(0, 0.9, 0.1, null, function(v:Float) distortion.setFloat('strength', v));
		impactTween.onComplete = function(_)
		{
			impactTween = FlxTween.num(0.9, 0, 1, null, function(v:Float) distortion.setFloat('strength', v));
		};
	}

	override function openSubState(SubState:flixel.FlxSubState)
	{
		if (Std.isOfType(SubState, GameOverSubstate))
		{
			camBars.visible = false;
			camGame.filters = camHUD.filters = null;
		}
	}

	override function destroy()
	{
		if (focusOffset != null) focusOffset.put();
		if (dropSpeeds != null) for (point in dropSpeeds) point.put();
		if (hud != null) hud.destroy();
		super.destroy();
	}
}

/**
 * Game over del mod (data/scripts/Gameover.hx): sin personaje muerto, Saori cayendo en bucle aparece
 * en 9 s con su musica. Reintentar: sonido "reset", destello rojo y se va en 1 s.
 */
@:access(substates.GameOverSubstate)
class WoCGameOver extends GameOverCustom
{
	var overlayCam:FlxCamera;
	var art:FlxSprite;
	var music:FlxSound;

	override function create()
	{
		autoLoop = false;
		endFadeDelay = 0.5;
		endFadeTime = 0.5;
		sub.boyfriend.visible = false;

		overlayCam = new FlxCamera();
		overlayCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overlayCam, false);

		art = new FlxSprite();
		art.frames = Paths.getSparrowAtlas('woc/saoriGameover');
		art.animation.addByPrefix('idle', 'Dead Loop0', 24, true);
		art.animation.play('idle');
		art.scale.set(0.8, 0.8);
		art.screenCenter();
		art.alpha = 0;
		art.antialiasing = ClientPrefs.data.antialiasing;
		art.cameras = [overlayCam];
		sub.add(art);
		FlxTween.tween(art, {alpha: 1}, 9);

		music = FlxG.sound.play(Paths.sound('woc/gameover_music'));
	}

	override function confirm()
	{
		FlxG.sound.play(Paths.sound('woc/reset'));
		if (music != null) music.volume = 0;
		overlayCam.flash(0xFFFF0000, 0.15);
		FlxTween.cancelTweensOf(art);
		FlxTween.tween(art, {alpha: 0}, 1, {ease: FlxEase.quintOut});
	}

	override function leave()
	{
		if (music != null) music.stop();
	}
}
