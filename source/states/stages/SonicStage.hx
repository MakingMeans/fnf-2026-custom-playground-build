package states.stages;

import objects.Character;
import objects.Note;
import psychlua.LuaUtils;
import states.stages.objects.SonicHUD;
import states.stages.objects.SonicLyrics;
import states.stages.objects.SonicSplashes;

/**
 * Lo comun de las canciones de Vs Sonic.exe (carpeta sanic: un Psych 1.0.4 modificado y compilado).
 * Es el port de lo que su motor hacia por dentro y de sus scripts globales:
 *  - GameplayCamera: data/<cancion>/cameraSettings.json da el punto de camara de cada lado
 *    (BFx/BFy, DADx/DADy, GFx/GFy), un punto medio (MiddleX/MiddleY con MiddleZoom) que enciende el
 *    evento "cameracenter", y cuanto se asoma la camara hacia la flecha que canta cada uno
 *    (OffsetsBF/OffsetsDAD/OffsetsGF; los cambia "Set Character Offset").
 *  - "Tween Camera Zoom" (contents/custom_events): con "zoom, true" hace un tween del zoom y el zoom
 *    por defecto lo sigue; sin "true", cambia el zoom por defecto.
 *  - "Tweening Camera": tween del desplazamiento de la camara (camGame.targetOffset).
 *  - HealthStuff.lua: cada nota (no sostenida) del rival quita vida mientras quede el doble de ese
 *    dano; "Change Health Damage" lo cambia (por defecto 0.007).
 *  - customHealthBar.lua (SonicHUD), "Normal Lyrics" (SonicLyrics) y noteSplashGlobal.lua
 *    (SonicSplashes). Cada cancion elige su marco de la barra con hudFrame/hudFrameOffset. * Nada de campos con valor inicial: create() se llama desde el constructor de BaseStage.
 */
@:access(states.PlayState)
@:access(backend.MusicBeatState)
class SonicStage extends BaseStage
{
	var play(get, never):PlayState;
	inline function get_play():PlayState return PlayState.instance;

	// HUD, letras y splashes (se crean en createPost)
	var hud:SonicHUD;
	var lyrics:SonicLyrics;
	var splashes:SonicSplashes;
	/** Marco de la barra de vida (hud/hud_<...> del mod) y su posicion respecto a ella. */
	var hudFrame:String;
	var hudFrameOffset:FlxPoint;

	// GameplayCamera
	var bfCam:FlxPoint;
	var dadCam:FlxPoint;
	var gfCam:FlxPoint;
	var middleCam:FlxPoint;
	var middleZoom:Float;
	var cameraCenter:Bool;
	var offsetBF:Float;
	var offsetDad:Float;
	var offsetGF:Float;

	// Tween Camera Zoom / Tweening Camera
	var tweenCamZoom:Bool;
	var zoomTween:FlxTween;
	var offsetTween:FlxTween;

	// HealthStuff.lua
	var healthDamage:Float;

	override function create()
	{
		bfCam = FlxPoint.get();
		dadCam = FlxPoint.get();
		gfCam = FlxPoint.get();
		middleCam = FlxPoint.get();
		middleZoom = defaultCamZoom;
		cameraCenter = false;
		offsetBF = offsetDad = offsetGF = 25;
		tweenCamZoom = false;
		healthDamage = 0.007;
		hasCameraSettings = false;
		hudFrame = null;
		hudFrameOffset = FlxPoint.get(-190, -75);
		loadCameraSettings();
	}

	function loadCameraSettings()
	{
		var path:String = 'data/${songName}/cameraSettings.json';
		if (!Paths.fileExists(path, openfl.utils.AssetType.TEXT)) return;
		var json:Dynamic = haxe.Json.parse(Paths.getTextFromFile(path));
		inline function num(field:String, fallback:Float):Float
		{
			var value:Dynamic = Reflect.field(json, field);
			return value != null ? value : fallback;
		}
		bfCam.set(num('BFx', 0), num('BFy', 0));
		dadCam.set(num('DADx', 0), num('DADy', 0));
		gfCam.set(num('GFx', 0), num('GFy', 0));
		middleCam.set(num('MiddleX', 0), num('MiddleY', 0));
		middleZoom = num('MiddleZoom', defaultCamZoom);
		offsetBF = num('OffsetsBF', 25);
		offsetDad = num('OffsetsDAD', 25);
		offsetGF = num('OffsetsGF', 25);
		if (Reflect.field(json, 'OverrideZoom') == true) play.defaultCamZoom = num('OGZoom', defaultCamZoom);
		camGame.angle = num('Angle', 0);
		hasCameraSettings = true;
	}

	var hasCameraSettings:Bool;

	override function createPost()
	{
		if (hudFrame != null) hud = new SonicHUD(play, hudFrame, hudFrameOffset.x, hudFrameOffset.y);
		lyrics = new SonicLyrics(play);
		splashes = new SonicSplashes(play, 'noteSplashes', 'noteSplashesHOLD');

		// camFollow ya existe aqui (no en create): desde ahora la camara la lleva esta clase
		if (!hasCameraSettings) return;
		play.isCameraOnForcedPos = true;
		updateCameraTarget();
		camGame.snapToTarget();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (hasCameraSettings && play.isCameraOnForcedPos) updateCameraTarget();
		if (tweenCamZoom) play.defaultCamZoom = camGame.zoom;
	}

	override function updatePost(elapsed:Float)
	{
		if (hud != null) hud.update(elapsed);
		if (splashes != null) splashes.update(elapsed);
	}

	override function beatHit()
	{
		if (hud != null) hud.beatHit();
	}

	override function goodNoteHit(note:Note)
	{
		if (splashes != null) splashes.noteHit(note);
	}

	override function noteMiss(note:Note)
	{
		if (splashes != null) splashes.noteMiss(note);
	}

	/** El punto al que mira la camara: el del lado que canta (o el medio) mas lo que se asoma hacia su flecha. */
	function updateCameraTarget()
	{
		var section = PlayState.SONG.notes[play.curSection];
		var target:FlxPoint;
		var singer:Character = null;
		var offset:Float = 0;
		if (cameraCenter)
			target = middleCam;
		else if (section != null && section.gfSection && gf != null)
		{
			target = gfCam;
			singer = gf;
			offset = offsetGF;
		}
		else if (section == null || section.mustHitSection)
		{
			target = bfCam;
			singer = boyfriend;
			offset = offsetBF;
		}
		else
		{
			target = dadCam;
			singer = dad;
			offset = offsetDad;
		}

		var x:Float = target.x;
		var y:Float = target.y;
		if (singer != null && offset != 0)
		{
			var anim:String = singer.getAnimationName();
			if (anim.startsWith('singLEFT')) x -= offset;
			else if (anim.startsWith('singDOWN')) y += offset;
			else if (anim.startsWith('singUP')) y -= offset;
			else if (anim.startsWith('singRIGHT')) x += offset;
		}
		camFollow.setPosition(x, y);
	}

	override function opponentNoteHit(note:Note)
	{
		if (!note.isSustainNote && play.health >= healthDamage * 2) play.health -= healthDamage;
		if (splashes != null) splashes.noteHit(note);
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch (eventName)
		{
			case 'Normal Lyrics':
				if (lyrics != null) lyrics.event(value1, value2);

			case 'Change Character':
				if (hud != null) hud.updateColors();

			case 'Tween Camera Zoom':
				tweenCameraZoom(value1, value2);

			case 'Tweening Camera':
				var pos:Array<String> = value1.split(',');
				var opts:Array<String> = value2.split(',');
				var x:Float = Std.parseFloat(pos[0]);
				var y:Float = pos.length > 1 ? Std.parseFloat(pos[1]) : Math.NaN;
				var time:Float = Std.parseFloat(opts[0]);
				if (Math.isNaN(x) || Math.isNaN(y) || Math.isNaN(time)) return;
				if (offsetTween != null) offsetTween.cancel();
				offsetTween = FlxTween.tween(camGame.targetOffset, {x: x, y: y}, time / play.playbackRate,
					{ease: LuaUtils.getTweenEaseByString(opts.length > 1 ? opts[1] : '')});

			case 'cameracenter':
				cameraCenter = value1.trim() == 'true';
				if (cameraCenter) play.defaultCamZoom = middleZoom;

			case 'Set Character Offset':
				var value:Float = Std.parseFloat(value2.split(',')[0]);
				if (Math.isNaN(value)) return;
				switch (value1.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend': offsetBF = value;
					case 'dad' | 'opponent': offsetDad = value;
					case 'gf' | 'girlfriend': offsetGF = value;
				}

			case 'Change Health Damage':
				var value:Float = Std.parseFloat(value1);
				if (!Math.isNaN(value)) healthDamage = value;
		}
	}

	/** "Tween Camera Zoom": v1 = "zoom" o "zoom, true" (con tween); v2 = "segundos, ease". */
	function tweenCameraZoom(value1:String, value2:String)
	{
		var parts:Array<String> = value1.split(',');
		var zoom:Float = Std.parseFloat(parts[0]);
		if (Math.isNaN(zoom)) return; // el chart de chaos tiene alguno con el texto de una letra: el mod no hacia nada
		if (zoomTween != null) zoomTween.cancel();
		zoomTween = null;
		if (parts.length > 1 && parts[1].trim().length > 0)
		{
			var opts:Array<String> = value2.split(',');
			var time:Float = Std.parseFloat(opts[0]);
			if (Math.isNaN(time)) time = 0.001;
			tweenCamZoom = true;
			zoomTween = FlxTween.tween(camGame, {zoom: zoom}, time / play.playbackRate, {
				ease: LuaUtils.getTweenEaseByString(opts.length > 1 ? opts[1] : ''),
				onComplete: function(_)
				{
					play.defaultCamZoom = camGame.zoom;
					tweenCamZoom = false;
					zoomTween = null;
				}
			});
		}
		else
		{
			play.defaultCamZoom = zoom;
			tweenCamZoom = false;
		}
	}

	override function destroy()
	{
		for (point in [bfCam, dadCam, gfCam, middleCam, hudFrameOffset])
			if (point != null) point.put();
		if (hud != null) hud.destroy();
		super.destroy();
	}
}
