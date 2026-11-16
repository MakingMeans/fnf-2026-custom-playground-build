package states.stages;

import objects.Note;
import openfl.filters.BitmapFilter;
import substates.GameOverCustom;
import substates.GameOverSubstate;

/**
 * Lo común de las canciones de Mario's Madness V2. El mod (Psych 0.4.2) tenía toda su lógica en su
 * PlayState.hx; esto es el port de la parte que comparten sus canciones:
 *  - Cámara: puntos fijos por lado (BF_CAM / DAD_CAM del mod) con su zoom, y un empujón en la
 *    dirección de cada nota ("extend"). `followChars` / `zoomChars` los apagan los eventos, que
 *    también mueven `camPos` (el camFollowPos del mod) a mano.
 *  - camEst: cámara entre la del juego y la del HUD (rótulo, avisos, fundidos...).
 *  - HUD: fuente mario2, tiempo en rojo (verde con botplay), marco healthBarNEW, bote de iconos.
 *  - Eventos comunes: Triggers Universal, Show Song, Set Cam Zoom, Set Cam Pos, Camera Zoom Chain y
 *    Ocultar HUD. Cada canción añade los suyos (ver TurmoilSweep y SuperBad).
 * Nada de campos con valor inicial: create() se llama desde el constructor de BaseStage.
 */
@:access(states.PlayState)
@:access(backend.MusicBeatState)
class MarioStage extends BaseStage
{
	public static inline var HUD_RED:FlxColor = 0xFFF42626;
	public static inline var HUD_BOTPLAY:FlxColor = 0xFF25CD49;

	public var camEst:FlxCamera;
	var hudColor:FlxColor;

	// Cámara (en el mod: BF_CAM_X, DAD_ZOOM, BF_CAM_EXTEND... y camFollow / camFollowPos)
	public var followChars:Bool;
	public var zoomChars:Bool;
	public var bfCam:FlxPoint;
	public var dadCam:FlxPoint;
	public var bfZoom:Float;
	public var dadZoom:Float;
	public var bfExtend:Float;
	public var dadExtend:Float;
	/** Hacia donde va la cámara (camFollow del mod). */
	public var camTarget:FlxPoint;
	/** Donde está la cámara (camFollowPos del mod): los eventos la mueven con tweens. */
	public var camPos:FlxPoint;
	var camDisplaceX:Float;
	var camDisplaceY:Float;

	// Igual que en el mod: hay eventos que cancelan todos los tweens de una lista
	public var eventTweens:Array<FlxTween>;
	public var eventTimers:Array<FlxTimer>;
	public var extraTween:Array<FlxTween>;
	public var extraTimers:Array<FlxTimer>;

	// Rótulo con el nombre y el autor (evento Show Song)
	var songAuthor:String;
	var titleText:FlxText;
	var autorText:FlxText;
	var line1:FlxSprite;
	var line2:FlxSprite;

	var healthFrame:FlxSprite;
	var zoomChainBeats:Int;
	var zoomChainEvery:Float;

	var play(get, never):PlayState;
	inline function get_play():PlayState return PlayState.instance;

	override function create()
	{
		play.songCard = false; // tienen su propio rotulo (evento Show Song)
		play.pauseMenuFactory = function() return new substates.MarioPauseSubState(songAuthor);
		eventTweens = [];
		eventTimers = [];
		extraTween = [];
		extraTimers = [];
		followChars = true;
		zoomChars = true;
		bfCam = FlxPoint.get(770, 100);
		dadCam = FlxPoint.get(100, 100);
		bfZoom = dadZoom = defaultCamZoom;
		bfExtend = dadExtend = 15;
		camTarget = FlxPoint.get();
		camPos = FlxPoint.get();
		camDisplaceX = camDisplaceY = 0;
		zoomChainBeats = 0;
		zoomChainEvery = 1;
		songAuthor = '';
		hudColor = play.cpuControlled ? HUD_BOTPLAY : HUD_RED;

		// camEst va entre la cámara del juego y la del HUD
		camEst = new FlxCamera();
		camEst.bgColor.alpha = 0;
		FlxG.cameras.remove(camHUD, false);
		FlxG.cameras.remove(camOther, false);
		FlxG.cameras.add(camEst, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		// La cámara la lleva esta clase, no moveCameraSection()
		play.isCameraOnForcedPos = true;
	}

	/** Valores de cámara del JSON del escenario en el mod: [x, y, camX, camY, zoom, extend]. */
	function setCameraPoints(bf:Array<Float>, dad:Array<Float>)
	{
		bfCam.set(bf[0], bf[1]);
		bfZoom = bf[2];
		bfExtend = bf[3];
		dadCam.set(dad[0], dad[1]);
		dadZoom = dad[2];
		dadExtend = dad[3];
	}

	override function createPost()
	{
		styleHud();
		createTitleCard();

		// Iconos como en el mod: sin el bote suave de Psych 1.0 (ver iconBop) y recolocados en cada
		// fotograma con updateHitbox(), que además anula cualquier desplazamiento de su offset
		play.updateIconsScale = function(elapsed:Float)
		{
			play.iconP1.updateHitbox();
			play.iconP2.updateHitbox();
		};

		// Cámara colocada desde el principio en su sitio
		var section = currentSection();
		var target:FlxPoint = (section == null || section.mustHitSection) ? bfCam : dadCam;
		snapCamPos(target.x, target.y);
	}

	function styleHud()
	{
		var marioFont:String = Paths.font('mario2.ttf');

		play.timeTxt.setFormat(marioFont, 22, hudColor, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		play.timeTxt.borderSize = 2;
		play.timeTxt.y = ClientPrefs.data.downScroll ? FlxG.height - 45 : 20;
		play.timeBar.y = play.timeTxt.y + play.timeTxt.height / 4;
		play.timeBar.setColors(hudColor, FlxColor.BLACK);
		play.timeBar.bg.color = FlxColor.BLACK;

		play.scoreTxt.setFormat(marioFont, 15, hudColor, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		play.scoreTxt.borderSize = 1.25;
		play.scoreTxt.y = play.healthBar.y + 36;

		// Barra de vida: la del mod mide 4 px menos por cada lado y lleva el marco healthBarNEW encima
		var bar = play.healthBar;
		bar.bg.visible = false;
		bar.barOffset.set(4, 4);
		bar.barWidth = Std.int(bar.bg.width - 8);
		bar.barHeight = Std.int(bar.bg.height - 8);
		healthFrame = new FlxSprite().loadGraphic(Paths.image('mario_madness/healthBarNEW'));
		healthFrame.antialiasing = ClientPrefs.data.antialiasing;
		healthFrame.screenCenter(X);
		healthFrame.y = bar.y - 5;
		healthFrame.visible = !ClientPrefs.data.hideHud;
		healthFrame.alpha = ClientPrefs.data.healthBarAlpha;
		play.uiGroup.insert(play.uiGroup.members.indexOf(bar) + 1, healthFrame);
	}

	function createTitleCard()
	{
		var font:String = Paths.font('mariones.ttf');
		titleText = new FlxText(400, 304.5, 0, PlayState.SONG.song, 42);
		titleText.setFormat(font, 42, FlxColor.BLACK, CENTER, FlxTextBorderStyle.OUTLINE, hudColor);
		titleText.borderSize = 3;
		titleText.screenCenter(X);
		titleText.alpha = 0;
		titleText.cameras = [camEst];
		add(titleText);

		autorText = new FlxText(400, titleText.y + 70, 0, songAuthor, 35);
		autorText.setFormat(font, 35, FlxColor.BLACK, CENTER, FlxTextBorderStyle.OUTLINE, hudColor);
		autorText.borderSize += 2;
		autorText.screenCenter(X);
		autorText.alpha = 0;
		autorText.cameras = [camEst];
		add(autorText);

		var width:Float = Math.max(titleText.width, autorText.width);
		line2 = new FlxSprite(566, titleText.y + 57).makeGraphic(Std.int(width), 5, FlxColor.BLACK);
		line2.cameras = [camEst];
		line2.screenCenter(X);
		line2.alpha = 0;

		line1 = new FlxSprite(line2.x - 5, line2.y - 2).makeGraphic(Std.int(width + 10), 8, hudColor);
		line1.cameras = [camEst];
		line1.alpha = 0;
		add(line1);
		add(line2);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		updateCamera(elapsed);
	}

	inline function currentSection():backend.Song.SwagSection
		return PlayState.SONG.notes[Std.int(play.curStep / 16)];

	/** El update de cámara del mod (FOLLOWCHARS / ZOOMCHARS). */
	function updateCamera(elapsed:Float)
	{
		if (!play.inCutscene)
		{
			var section = currentSection();
			if (play.generatedMusic && section != null && !play.endingSong)
			{
				if (zoomChars) play.defaultCamZoom = section.mustHitSection ? bfZoom : dadZoom;
				if (followChars) camTarget.copyFrom(section.mustHitSection ? bfCam : dadCam);
			}
			if (followChars)
			{
				var lerpVal:Float = FlxMath.bound(elapsed * 2.4 * play.cameraSpeed, 0, 1);
				camPos.set(FlxMath.lerp(camPos.x, camTarget.x + camDisplaceX, lerpVal), FlxMath.lerp(camPos.y, camTarget.y + camDisplaceY, lerpVal));
			}
		}
		play.camFollow.setPosition(camPos.x, camPos.y);
		if (FlxG.camera.target != null) FlxG.camera.snapToTarget();
	}

	function snapCamPos(x:Float, y:Float)
	{
		camTarget.set(x, y);
		camPos.set(x, y);
		play.camFollow.setPosition(x, y);
		if (FlxG.camera.target != null) FlxG.camera.snapToTarget();
	}

	/** strumCameraRoll() del mod: la cámara se asoma hacia la flecha que canta quien tiene la sección. */
	function cameraRoll(noteData:Int, singer:Bool)
	{
		var section = currentSection();
		if (section == null || section.mustHitSection != singer) return;

		var extend:Float = singer ? bfExtend : dadExtend;
		camDisplaceX = camDisplaceY = 0;
		switch (noteData % 4)
		{
			case 0: camDisplaceX = -extend;
			case 1: camDisplaceY = extend;
			case 2: camDisplaceY = -extend;
			case 3: camDisplaceX = extend;
		}
	}

	override function goodNoteHit(note:Note) cameraRoll(note.noteData, true);
	override function opponentNoteHit(note:Note) cameraRoll(note.noteData, false);

	override function beatHit()
	{
		if (zoomChainBeats > 0 && curBeat % zoomChainEvery == 0)
		{
			// el mod leía los valores del evento pero luego usaba siempre 0.015 / 0.03
			addCameraZoom(0.015, 0.03);
			zoomChainBeats--;
		}
		iconBop();
	}

	/** El bote de iconos del mod: a 1.1 y vuelta a 1 en medio pulso. */
	function iconBop()
	{
		var beat:Float = Conductor.crochet / 1000;
		for (icon in [play.iconP1, play.iconP2])
		{
			icon.scale.set(1.1, 1.1);
			eventTweens.push(FlxTween.tween(icon.scale, {x: 1, y: 1}, 0.5 * beat, {ease: FlxEase.cubeOut}));
		}
	}

	/** "Add Camera Zoom" del mod: sin el tope de 1.35 del de Psych 1.0. */
	function addCameraZoom(game:Float, hud:Float)
	{
		if (!ClientPrefs.data.camZooms) return;
		FlxG.camera.zoom += game;
		camHUD.zoom += hud;
	}

	/** "Play Animation" del mod. */
	function playAnimOn(char:objects.Character, anim:String)
	{
		if (char == null) return;
		char.playAnim(anim, true);
		char.specialAnim = true;
	}

	static function parseNum(value:String):Float
	{
		var num:Float = Std.parseFloat(value);
		return Math.isNaN(num) ? 0 : num;
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch (eventName)
		{
			case 'Triggers Universal':
				triggers(Std.int(parseNum(value1)), Std.int(parseNum(value2)));

			case 'Show Song':
				showSong(parseNum(value1) != 1);

			case 'Set Cam Zoom':
				var zoom:Float = Std.parseFloat(value1);
				switch (value2)
				{
					case 'bf' | 'boyfriend': bfZoom = zoom;
					case 'gf' | 'girlfriend': // sin GF que siga la cámara en estas canciones
					case 'dad' | 'opponent': dadZoom = zoom;
					default:
						bfZoom = dadZoom = zoom;
						play.defaultCamZoom = zoom;
				}

			case 'Set Cam Pos':
				var split:Array<String> = value1.split(',');
				var x:Float = parseNum(split[0] != null ? split[0].trim() : '');
				var y:Float = parseNum(split[1] != null ? split[1].trim() : '');
				switch (value2)
				{
					case 'bf' | 'boyfriend': bfCam.set(x, y);
					case 'dad' | 'opponent': dadCam.set(x, y);
				}

			case 'Camera Zoom Chain':
				var split:Array<String> = value2.split(',');
				var beats:Null<Int> = Std.parseInt(split[0].trim());
				var every:Float = split.length > 1 ? Std.parseFloat(split[1].trim()) : Math.NaN;
				zoomChainBeats = beats != null ? beats : 4;
				zoomChainEvery = Math.isNaN(every) ? 1 : every;

			case 'Ocultar HUD':
				switch (Std.int(parseNum(value1)))
				{
					case 0: eventTweens.push(FlxTween.tween(camHUD, {alpha: 0}, 0.5, {ease: FlxEase.quadInOut}));
					case 1: eventTweens.push(FlxTween.tween(camHUD, {alpha: 1}, 0.001, {ease: FlxEase.quadInOut}));
					case 2: eventTweens.push(FlxTween.tween(camHUD, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut}));
				}
		}
	}

	/** "Triggers <canción>" del mod. */
	function triggers(value:Int, value2:Int) {}

	function showSong(show:Bool)
	{
		if (show)
		{
			for (spr in [titleText, autorText, line1, line2]) spr.visible = true;
			titleText.y = 304.5;
			autorText.y = titleText.y + 70;
			line2.y = titleText.y + 57;
			line1.y = line2.y - 2;
			autorText.screenCenter(X);
			titleText.screenCenter(X);
			for (spr in [titleText, autorText, line1, line2])
				eventTweens.push(FlxTween.tween(spr, {alpha: 1, y: spr.y + 30}, 0.5, {ease: FlxEase.cubeOut}));
		}
		else
		{
			for (spr in [titleText, autorText, line1, line2])
				eventTweens.push(FlxTween.tween(spr, {alpha: 0}, 0.5, {ease: FlxEase.cubeOut}));
			eventTimers.push(new FlxTimer().start(0.5, function(_)
			{
				for (spr in [titleText, autorText, line1, line2]) spr.visible = false;
			}));
		}
	}

	/** Pone o quita un filtro en una cámara sin tocar los demás. */
	static function setCameraFilter(cam:FlxCamera, filter:BitmapFilter, on:Bool)
	{
		var list:Array<BitmapFilter> = cam.filters != null ? cam.filters.copy() : [];
		var has:Bool = list.contains(filter);
		if (on == has) return;
		if (on) list.push(filter);
		else list.remove(filter);
		cam.filters = list.length > 0 ? list : null;
	}

	override function destroy()
	{
		for (point in [bfCam, dadCam, camTarget, camPos])
			if (point != null) point.put();
		super.destroy();
	}
}

/**
 * Game over de Mario's Madness: la cámara apunta al centro del personaje (sin su camera_position) y
 * 'deathLoop' se repite cada `loopEvery` segundos, como en el mod.
 */
@:access(substates.GameOverSubstate)
class MarioGameOver extends GameOverCustom
{
	var loopEvery:Float;
	var loopTime:Float = -1;

	public function new(loopEvery:Float)
	{
		super();
		this.loopEvery = loopEvery;
	}

	override function create()
	{
		centerCamera();
	}

	function centerCamera()
	{
		var mid:FlxPoint = sub.boyfriend.getGraphicMidpoint();
		sub.camFollow.setPosition(mid.x, mid.y);
		mid.put();
	}

	/** coolStartDeath() del mod. */
	function startLoop()
	{
		sub.startDeathLoop();
		loopTime = 0;
	}

	override function update(elapsed:Float)
	{
		if (loopTime < 0 || sub.isEnding) return;
		loopTime += elapsed;
		if (loopTime >= loopEvery)
		{
			loopTime -= loopEvery;
			if (sub.boyfriend.hasAnimation('deathLoop')) sub.boyfriend.playAnim('deathLoop', true);
		}
	}
}
