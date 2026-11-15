package states.stages;

import objects.Character;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import psychlua.LuaUtils;
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;
import states.stages.objects.SonicSplashes;
import substates.GameOverCustom;
import substates.GameOverSubstate;

/**
 * endless-us (Vs Sonic.exe, carpeta MAJIN), escenario "majin". El escenario es el JSON de Psych con
 * sus objetos, y stages/majin.lua, data/endless-us/script.lua y el evento changenoteSkin siguen en Lua
 * (solo usan funciones normales). Aqui va el port de data/endless-us/shaders.lua, que dependia de
 * funciones del motor del mod (addPrunedFilter / addStaticFilter):
 *  - Cuatro sombreadores en la camara del juego: chrom (aberracion), shine (brillo/contraste), bw
 *    (blanco y negro) y color (DropShadowShader). Los tres primeros solo se ponen mientras no estan
 *    en su valor neutro, como hacia el mod; color va siempre.
 *  - Eventos bloomFlash, chromFlash, bwFlash y colorFlash: tween de "v1 = desde, hasta" en
 *    "v2 = segundos, ease" (solo con flashes activados). Sin sombreadores, script.lua oscurece la
 *    pantalla con un sprite en el colorFlash final.
 * Ademas: la pantalla de inicio (StartScreen.lua, solo la primera vez: al reintentar no hay ni cuenta
 * atras), los splashes de endless al cambiar la skin de las notas y su game over (MajinGameOver).
 */
@:access(states.PlayState)
class MajinStage extends SonicStage
{
	var chrom:ErrorHandledRuntimeShader;
	var shine:ErrorHandledRuntimeShader;
	var bw:ErrorHandledRuntimeShader;
	var color:ErrorHandledRuntimeShader;
	var filters:Map<ErrorHandledRuntimeShader, ShaderFilter>;
	var flashValues:Map<String, Float>;
	var flashTweens:Map<String, FlxTween>;
	var shadersOn:Bool;
	var firstPlay:Bool;

	override function create()
	{
		super.create();
		hudFrame = 'endless-us/hud/hud_majin';
		hudFrameOffset.set(-190, -70);
		play.songCard = false; // tiene su propia pantalla de inicio (StartScreen)
		GameOverSubstate.custom = new MajinGameOver();
		// startCountdown() (antes de createPost) ya marca seenCutscene: se mira aqui
		firstPlay = !PlayState.seenCutscene;
		if (!firstPlay) play.skipCountdown = true;
		filters = new Map();
		flashValues = ['shine' => 0, 'chrom' => 0, 'bw' => 0, 'color' => 0];
		flashTweens = new Map();
		shadersOn = ClientPrefs.data.shaders;
	}

	override function createPost()
	{
		super.createPost();
		SonicSplashes.precache('noteSplashes-endless-us', 'noteSplashesHOLD-endless-us');
		startScreen();
		if (!shadersOn) return;

		chrom = play.createRuntimeShader('endless-us-chromabber');
		chrom.setFloat('amount', 0);
		shine = play.createRuntimeShader('endless-us-brightness');
		shine.setFloat('brightness', 0);
		shine.setFloat('contrast', 1);
		shine.setFloat('saturation', 1);
		bw = play.createRuntimeShader('endless-us-blackwhite');
		bw.setFloat('grayness', 0);
		color = play.createRuntimeShader('endless-us-DropShadowShader');
		for (uniform => value in ['ang' => 90.0, 'thr' => 1.0, 'hue' => 1.0, 'contrast' => 0.0, 'saturation' => 0.0, 'brightness' => 0.0])
			color.setFloat(uniform, value);

		if (!ClientPrefs.data.lowQuality)
		{
			for (shader in [chrom, shine, bw, color]) filters.set(shader, new ShaderFilter(shader));
			syncFilters();
		}
	}

	/** Pone cada filtro solo mientras hace algo (el "pruned" del mod); color va siempre. */
	function syncFilters()
	{
		if (!filters.exists(color)) return;
		var list:Array<BitmapFilter> = [];
		if (flashValues['chrom'] != 0) list.push(filters[chrom]);
		if (flashValues['shine'] != 0) list.push(filters[shine]);
		if (flashValues['bw'] != 0) list.push(filters[bw]);
		list.push(filters[color]);
		camGame.filters = list;
	}

	/**
	 * StartScreen.lua (tipo "slide" de MAJIN): la primera vez, fondo negro con el circulo entrando por
	 * la derecha y el titulo por la izquierda; se van fundiendo a los 1,5 s. La cuenta atras va debajo.
	 */
	function startScreen()
	{
		new FlxTimer().start(0.1, function(_) camGame.snapToTarget());
		if (!firstPlay) return;

		var black:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		var circle:FlxSprite = new FlxSprite(FlxG.width, 0).loadGraphic(Paths.image('endless-us/StartScreen/circle'));
		var title:FlxSprite = new FlxSprite(-FlxG.width, 0).loadGraphic(Paths.image('endless-us/StartScreen/text'));
		var parts:Array<FlxSprite> = [black, circle, title];
		for (part in parts)
		{
			part.antialiasing = ClientPrefs.data.antialiasing;
			part.cameras = [camOther];
			add(part);
		}
		FlxTween.tween(title, {x: 0}, 1, {ease: FlxEase.quintOut});
		FlxTween.tween(circle, {x: 0}, 1, {ease: FlxEase.quintOut, onComplete: function(_)
		{
			new FlxTimer().start(0.5, function(_)
			{
				for (part in parts)
					FlxTween.tween(part, {alpha: 0}, 1, {onComplete: function(_)
					{
						remove(part, true);
						part.destroy();
					}});
			});
		}});
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		super.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime);
		// noteSplashGlobal.lua: con la skin de endless, sus splashes
		if (eventName == 'changenoteSkin' && value1 == 'NOTE_assets_ENDLESS' && splashes != null)
			splashes.changeSkin('noteSplashes-endless-us', 'noteSplashesHOLD-endless-us');

		var key:String = switch (eventName)
		{
			case 'bloomFlash': 'shine';
			case 'chromFlash': 'chrom';
			case 'bwFlash': 'bw';
			case 'colorFlash': 'color';
			default: null;
		}
		if (key == null || !shadersOn || !ClientPrefs.data.flashing) return;

		var values:Array<String> = value1.split(',');
		var opts:Array<String> = value2.split(',');
		var from:Float = Std.parseFloat(values[0]);
		var to:Float = values.length > 1 ? Std.parseFloat(values[1]) : Math.NaN;
		var time:Float = Std.parseFloat(opts[0]);
		if (Math.isNaN(from) || Math.isNaN(to) || Math.isNaN(time)) return;

		if (flashTweens.exists(key)) flashTweens[key].cancel();
		setFlash(key, from);
		flashTweens[key] = FlxTween.num(from, to, time / play.playbackRate,
			{ease: LuaUtils.getTweenEaseByString(opts.length > 1 ? opts[1] : '')}, function(v:Float) setFlash(key, v));
	}

	function setFlash(key:String, value:Float)
	{
		flashValues[key] = value;
		switch (key)
		{
			case 'shine':
				shine.setFloat('brightness', value * 2);
				shine.setFloat('contrast', 1 + value * 4);
			case 'chrom':
				chrom.setFloat('amount', value);
			case 'bw':
				bw.setFloat('grayness', value);
			case 'color':
				color.setFloat('brightness', value);
		}
		syncFilters();
	}

	override function openSubState(SubState:flixel.FlxSubState)
	{
		// el game over limpia los filtros de la camara del juego
		if (Std.isOfType(SubState, GameOverSubstate))
		{
			filters.clear();
			camGame.filters = null;
		}
	}
}

/**
 * Game over de endless-us (la parte de endless-us de scripts/raimbow death screens.hx del mod): BF
 * muerto quieto en pantalla; al empezar el bucle salen majins a los lados y una cuenta atras de 10 s
 * mientras la camara se acerca. Si llega a 0 sin reintentar, Majin se lleva a BF (animacion
 * 'majinbf', destello azul y dos sonidos) y se vuelve al mapa (o a Freeplay): en el mod se cerraba la
 * ventana del juego, y eso se cambio a proposito.
 */
@:access(substates.GameOverSubstate)
class MajinGameOver extends GameOverCustom
{
	static inline final ZOOM:Float = 0.85;
	/**
	 * Donde sale la animacion de Majin (fija en pantalla): centrada, para que el zoom final (x1.75 y
	 * luego x1.55) la encuadre entera. En el mod iba en (BF + 190, BF - 700) sin fijar a la pantalla,
	 * y su sitio dependia de por donde iba la camara.
	 */
	static inline final MAJIN_X:Float = 451;
	static inline final MAJIN_Y:Float = 135;

	var started:Bool = false;
	var caught:Bool = false;
	var stopped:Bool = false;
	var secondsLeft:Int = 10;
	var countdown:FlxTimer;
	var countdownText:FlxText;
	var majins:Array<FlxSprite> = [];
	var majinBF:FlxAnimate;
	var blueVG:FlxSprite;
	var timers:Array<FlxTimer> = [];

	override function create()
	{
		var bf:Character = sub.boyfriend;
		bf.scrollFactor.set();
		bf.setPosition(320, 80);
		FlxG.camera.targetOffset.set();
		FlxG.camera.zoom = ZOOM;
	}

	override function update(elapsed:Float)
	{
		if (started || sub.isEnding || sub.boyfriend.getAnimationName() != 'deathLoop') return;
		started = true;
		startCountdown();
	}

	override function canConfirm():Bool return !caught;

	function makeMajin(x:Float, y:Float, flip:Bool, scale:Float):FlxSprite
	{
		var majin:FlxSprite = new FlxSprite(x, y).loadGraphic(Paths.image('endless-us/gameover/evil majin'));
		majin.flipX = flip;
		majin.scrollFactor.set();
		majin.scale.set(scale, scale);
		majin.alpha = 0;
		majin.antialiasing = ClientPrefs.data.antialiasing;
		majins.push(majin);
		return majin;
	}

	function startCountdown()
	{
		var bf:Character = sub.boyfriend;
		majinBF = new FlxAnimate(MAJIN_X, MAJIN_Y);
		Paths.loadAnimateAtlas(majinBF, 'endless-us/gameover/us');
		majinBF.anim.addBySymbol('dying', 'majinbf', 24, false);
		majinBF.scale.set(0.7, 0.7);
		majinBF.scrollFactor.set();
		majinBF.alpha = 0;
		majinBF.antialiasing = ClientPrefs.data.antialiasing;
		sub.add(majinBF);

		blueVG = new FlxSprite().loadGraphic(Paths.image('endless-us/hud/blueVg'));
		blueVG.scrollFactor.set();
		blueVG.alpha = 0;
		sub.add(blueVG);

		// cinco parejas a los lados (las 3 de fuera, detras de BF) y una delante, mas cerca
		var baseLeft:Float = 100;
		var baseRight:Float = 750;
		var spacing:Float = 50;
		for (i in [5, 4, 3, 2, 1])
		{
			var scale:Float = 1 - i * 0.05;
			var bell:Float = 1 - Math.abs(i - 3) * 0.2;
			var dynamicSpacing:Float = spacing * (1 + bell);
			var y:Float = bf.y + (i == 1 ? 70 : 65);
			var leftX:Float = i >= 3 ? baseLeft + (i - 3) * (i - 3) * 30 : baseLeft - i * dynamicSpacing;
			var rightX:Float = i >= 3 ? baseRight - (i - 3) * (i - 3) * 30 : baseRight + i * dynamicSpacing;
			var targetAlpha:Float = Math.max(0.5, 1 - i * 0.08);
			for (majin in [makeMajin(leftX, y, true, scale), makeMajin(rightX, y, false, scale)])
			{
				if (i >= 3) sub.insert(0, majin);
				else sub.add(majin);
				FlxTween.tween(majin, {alpha: targetAlpha}, 2 + i * 0.3);
			}
		}
		for (majin in [makeMajin(baseLeft, bf.y + 70, true, 1), makeMajin(baseRight, bf.y + 70, false, 1)])
		{
			sub.add(majin);
			FlxTween.tween(majin, {alpha: 1}, 1.5);
		}

		countdownText = new FlxText(FlxG.width / 2 - 20, FlxG.height / 2 - 280, 0, '10', 36);
		countdownText.font = Paths.font('SonicCD.ttf');
		countdownText.color = FlxColor.WHITE;
		countdownText.scrollFactor.set();
		sub.add(countdownText);

		FlxTween.tween(FlxG.camera, {zoom: ZOOM + 0.3}, 10, {ease: FlxEase.sineIn});
		countdown = new FlxTimer().start(1, tick);
	}

	function tick(timer:FlxTimer)
	{
		secondsLeft--;
		if (countdownText != null)
		{
			countdownText.text = Std.string(secondsLeft);
			countdownText.x = FlxG.width / 2 - 20;
			var left:Float = secondsLeft / 10; // de blanco a rojo
			countdownText.color = FlxColor.fromRGB(255, Std.int(255 * left), Std.int(255 * left));
		}
		if (secondsLeft > 0) timer.reset(1);
		else if (!stopped) caughtByMajin();
	}

	function clearCountdown()
	{
		if (countdown != null) countdown.cancel();
		if (countdownText != null)
		{
			sub.remove(countdownText, true);
			countdownText.destroy();
			countdownText = null;
		}
		for (majin in majins)
		{
			FlxTween.cancelTweensOf(majin);
			sub.remove(majin, true);
			majin.destroy();
		}
		majins = [];
	}

	/** youFuckedUp() del mod. */
	function caughtByMajin()
	{
		caught = true;
		FlxG.sound.music.stop();
		clearCountdown();
		sub.boyfriend.visible = false;
		majinBF.alpha = 1;
		majinBF.anim.play('dying', true);
		blueVG.alpha = 1;
		FlxTween.tween(blueVG, {alpha: 0}, 1);
		for (sound in FlxG.sound.list)
			if (sound != null && sound.playing) sound.volume = 0;

		FlxTween.cancelTweensOf(FlxG.camera);
		FlxTween.tween(FlxG.camera, {zoom: FlxG.camera.zoom + 0.6}, 1, {ease: FlxEase.circOut});
		FlxG.sound.play(Paths.sound('endless-us/firstLOOK'));
		timers.push(new FlxTimer().start(2.45, function(_)
		{
			FlxG.sound.play(Paths.sound('endless-us/secondLOOK'));
			FlxTween.tween(FlxG.camera, {zoom: FlxG.camera.zoom - 0.2}, 0.5, {ease: FlxEase.circOut});
			// en el mod: Application.current.window.close()
			timers.push(new FlxTimer().start(6, function(_) sub.exitToMenu()));
		}));
	}

	override function confirm()
	{
		stopped = true;
		clearCountdown();
	}

	override function leave()
	{
		stopped = true;
		clearCountdown();
		for (timer in timers) timer.cancel();
	}
}
