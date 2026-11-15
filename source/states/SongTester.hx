package states;

#if debug
import flixel.FlxBasic;
import substates.GameOverSubstate;

/**
 * Prueba automatica de una cancion (solo debug):
 *   FNF2026Playground.exe -song <cancion> -test [-shots 10,45.5,90]
 *
 * La juega en botplay (sin teclas simuladas y sin necesitar el foco de la ventana), guarda una
 * captura en song_shots/<cancion>-<segundo>.png en cada segundo de cancion pedido y, al terminar la
 * cancion (o si BF muere), escribe song_test.txt y cierra el juego. Los errores de los scripts
 * salen por consola (en debug, FunkinLua.luaTrace los imprime aunque el script no tenga
 * luaDebugMode).
 *
 * -wallshots 4,6.5 pide capturas de ventana en esos segundos de reloj desde que arranca el juego (para
 * lo que pasa antes de la cancion, como una intro).
 *
 * Para probar un game over: -die <segundo> deja la vida a 0 en ese segundo de cancion;
 * -deathshots 0.5,3 pide capturas de ventana en esos segundos desde que se abre el game over, y
 * -deathconfirm <segundo> pulsa "reintentar" (si el game over ya lo permite).
 */
@:access(states.PlayState)
@:access(backend.MusicBeatState)
@:access(substates.GameOverSubstate)
class SongTester extends FlxBasic
{
	public static var running:Bool = false;

	var song:String;
	var shots:Array<Float> = []; // ms de cancion
	var winShots:Array<Float> = []; // ms de cancion: avisos para capturar la ventana desde fuera
	var wallShots:Array<Float> = []; // -wallshots: s de reloj desde el arranque (intros antes de la cancion)
	var dieAt:Float = Math.NaN; // ms de cancion (negativo = durante la cuenta atras); NaN = no
	var deathShots:Array<Float> = []; // ms desde que se abre el game over (ventana real)
	var confirmAt:Float = -1; // s desde que se abre el game over
	var confirmed:Bool = false;
	var deathTime:Float = -1; // s desde que se abre el game over
	var hitTypes:Array<String> = []; // -hit: tipos de nota que el bot tambien pulsa
	var skipTypes:Array<String> = []; // -skip: tipos de nota que el bot deja pasar (p. ej. "emerald")
	var pauseAt:Float = -1; // -pause: ms de cancion en que se abre el menu de pausa (se captura y se acaba)
	var pauseTime:Float = -1;
	var taken:Array<String> = [];
	var log:Array<String> = [];
	var started:Bool = false;
	var finished:Bool = false;
	var wallTime:Float = 0;
	var lastPos:Float = 0;

	// rendimiento mientras suena la cancion
	var frames:Int = 0;
	var frameTime:Float = 0;
	var worstFrame:Float = 0;

	static inline final TIMEOUT:Float = 900; // s de reloj

	public static function start(song:String, args:Array<String>)
	{
		running = true;
		FlxG.autoPause = false; // sin foco, flixel pausaria la cancion
		ClientPrefs.data.gameplaySettings.set('botplay', true); // no se guarda: solo esta partida

		// -noshaders: la captura (BitmapData.draw del escenario) no dibuja las camaras con un filtro
		// de shader, que salen en negro; asi se ve el escenario y los personajes
		if (args.contains('-noshaders')) ClientPrefs.data.shaders = false;

		var tester:SongTester = new SongTester(song);
		readTimes(args, '-shots', tester.shots);
		// -winshots: en esos segundos escribe song_winshot.txt para que un script capture la ventana
		// real (PrintWindow), que si incluye videos y shaders
		readTimes(args, '-winshots', tester.winShots);
		readTimes(args, '-wallshots', tester.wallShots);
		readTimes(args, '-deathshots', tester.deathShots);
		var times:Array<Float> = [];
		readTimes(args, '-die', times);
		if (times.length > 0) tester.dieAt = times[0];
		times = [];
		readTimes(args, '-deathconfirm', times);
		if (times.length > 0) tester.confirmAt = times[0] / 1000;
		var hitIndex:Int = args.indexOf('-hit');
		if (hitIndex > -1 && hitIndex + 1 < args.length)
			tester.hitTypes = [for (type in args[hitIndex + 1].split(',')) type.trim()];
		var skipIndex:Int = args.indexOf('-skip');
		if (skipIndex > -1 && skipIndex + 1 < args.length)
			tester.skipTypes = [for (type in args[skipIndex + 1].split(',')) type.trim()];
		times = [];
		readTimes(args, '-pause', times);
		if (times.length > 0) tester.pauseAt = times[0];
		FlxG.plugins.addPlugin(tester);
	}

	static function readTimes(args:Array<String>, flag:String, into:Array<Float>)
	{
		var index:Int = args.indexOf(flag);
		if (index < 0 || index + 1 >= args.length) return;
		for (part in args[index + 1].split(','))
		{
			var seconds:Float = Std.parseFloat(part);
			if (!Math.isNaN(seconds)) into.push(seconds * 1000);
		}
		into.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
	}

	public function new(song:String)
	{
		super();
		this.song = Paths.formatToSongPath(song);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (finished) return;

		// la consola de flixel se abre sola con los avisos de debug y taparia las capturas
		if (FlxG.debugger.visible) FlxG.debugger.visible = false;

		wallTime += elapsed;
		if (wallTime > TIMEOUT)
		{
			log.push('TIMEOUT: la cancion no termino en ${TIMEOUT}s');
			finish();
			return;
		}

		// -wallshots: capturas de la ventana por tiempo real desde el arranque (lo que pasa antes de
		// que empiece la cancion, como la intro de chaos)
		if (wallShots.length > 0 && wallTime * 1000 >= wallShots[0] && !FileSystem.exists('song_winshot.txt'))
		{
			var seconds:String = Std.string(Math.round(wallShots.shift() / 100) / 10);
			File.saveContent('song_winshot.txt', '$song-wall-$seconds');
		}

		if (deathTime >= 0)
		{
			updateDeath(elapsed);
			return;
		}

		// -pause: menu de pausa abierto; a los 1.5 s se pide la captura de la ventana y se acaba
		if (pauseTime >= 0)
		{
			pauseTime += elapsed;
			if (pauseTime >= 1.5 && pauseTime < 100 && !FileSystem.exists('song_winshot.txt'))
			{
				File.saveContent('song_winshot.txt', '$song-pause');
				pauseTime = 100;
			}
			else if (pauseTime >= 100 && !FileSystem.exists('song_winshot.txt'))
			{
				log.push('Menu de pausa abierto: ${Type.getClassName(Type.getClass(FlxG.state.subState))}');
				finish();
			}
			return;
		}

		var play:PlayState = Std.downcast(FlxG.state, PlayState);
		if (play == null)
		{
			if (started)
			{
				log.push('Cancion terminada: ahora en ${Type.getClassName(Type.getClass(FlxG.state))}');
				finish();
			}
			return;
		}

		if (!started && play.startedCountdown)
		{
			started = true;
			log.push('Cancion "${PlayState.SONG.song}" empezada: escenario ${PlayState.SONG.stage}, ${play.boyfriend.curCharacter} vs ${play.dad.curCharacter}');
		}
		if (!started) return;

		if (Std.isOfType(FlxG.state.subState, GameOverSubstate))
		{
			log.push('GAME OVER en el segundo ${Math.round(lastPos / 100) / 10}');
			if (deathShots.length > 0 || confirmAt >= 0) deathTime = 0;
			else finish();
			return;
		}

		lastPos = Conductor.songPosition;
		if (hitTypes.length > 0)
		{
			// -hit <tipos>: el bot tambien pulsa esas notas (normalmente las ignora), p. ej. "Bad Poison"
			play.notes.forEachAlive(function(note:objects.Note)
			{
				if (note.mustPress && !note.wasGoodHit && hitTypes.contains(note.noteType) && note.strumTime <= Conductor.songPosition)
				{
					note.ignoreNote = false;
					play.goodNoteHit(note);
				}
			});
		}
		if (skipTypes.length > 0)
		{
			// -skip <tipos>: el bot no las toca (con botplay, PlayState no pulsa las notas ignoreNote)
			for (note in play.unspawnNotes) if (skipTypes.contains(note.noteType)) note.ignoreNote = true;
			for (note in play.notes.members) if (note != null && skipTypes.contains(note.noteType)) note.ignoreNote = true;
		}
		if (pauseAt >= 0 && lastPos >= pauseAt && FlxG.state.subState == null)
		{
			pauseAt = -1;
			pauseTime = 0;
			log.push('Pausa abierta en el segundo ${Math.round(lastPos / 100) / 10}');
			play.openPauseMenu();
			return;
		}
		if (!Math.isNaN(dieAt) && lastPos >= dieAt)
		{
			dieAt = Math.NaN;
			log.push('Vida a 0 (forzado) en el segundo ${Math.round(lastPos / 100) / 10}');
			play.health = 0;
		}
		if (play.startedCountdown && !play.paused)
		{
			frames++;
			frameTime += elapsed;
			if (elapsed > worstFrame) worstFrame = elapsed;
		}

		while (shots.length > 0 && lastPos >= shots[0])
			capture(shots.shift(), play);

		if (winShots.length > 0 && lastPos >= winShots[0] && !FileSystem.exists('song_winshot.txt'))
		{
			var seconds:String = Std.string(Math.round(winShots.shift() / 100) / 10);
			File.saveContent('song_winshot.txt', '$song-$seconds');
		}
	}

	/** Game over abierto: capturas de ventana por tiempo real y, si se pidió, reintentar. */
	function updateDeath(elapsed:Float)
	{
		deathTime += elapsed;
		if (deathShots.length > 0 && deathTime * 1000 >= deathShots[0] && !FileSystem.exists('song_winshot.txt'))
		{
			var seconds:String = Std.string(Math.round(deathShots.shift() / 100) / 10);
			File.saveContent('song_winshot.txt', '$song-death-$seconds');
		}

		var sub:GameOverSubstate = GameOverSubstate.instance;
		if (!confirmed && confirmAt >= 0 && deathTime >= confirmAt && sub != null)
		{
			if (GameOverSubstate.custom == null || GameOverSubstate.custom.canConfirm())
			{
				confirmed = true;
				log.push('Reintentar pulsado a los ${Math.round(deathTime * 10) / 10} s del game over');
				sub.endBullshit();
			}
			else if (deathTime >= confirmAt + 15)
			{
				confirmed = true;
				log.push('El game over no dejaba reintentar 15 s despues de pedirlo');
			}
		}

		var endAt:Float = confirmAt >= 0 ? (confirmed ? confirmAt + 4.5 : 1e9) : 0;
		if (deathShots.length == 0 && !FileSystem.exists('song_winshot.txt') && deathTime >= endAt)
		{
			if (confirmed) log.push('Despues de reintentar: ahora en ${Type.getClassName(Type.getClass(FlxG.state))}');
			finish();
		}
	}

	function capture(time:Float, play:PlayState)
	{
		var seconds:String = Std.string(Math.round(time / 100) / 10);
		var name:String = '$song-$seconds';
		try
		{
			var bmp:openfl.display.BitmapData = new openfl.display.BitmapData(FlxG.stage.stageWidth, FlxG.stage.stageHeight, false, 0xFF000000);
			bmp.draw(FlxG.stage);
			var png = bmp.encode(bmp.rect, new openfl.display.PNGEncoderOptions());
			if (!FileSystem.exists('song_shots')) FileSystem.createDirectory('song_shots');
			File.saveBytes('song_shots/$name.png', png);
			bmp.dispose();
			taken.push(name);
			log.push('Captura $name (paso ${play.curStep}, ${play.boyfriend.curCharacter} vs ${play.dad.curCharacter}, vida ${Math.round(play.health * 100) / 100}, '
				+ 'anim rival ${play.dad.getAnimationName()}, voz rival ${play.opponentVocals.length > 0 ? Std.string(play.opponentVocals.volume) : "-"})');
		}
		catch (e:Dynamic)
		{
			log.push('No se pudo guardar la captura $name: $e');
		}
	}

	function finish()
	{
		if (finished) return;
		finished = true;

		var play:PlayState = PlayState.instance;
		if (play != null) log.push('Final: segundo ${Math.round(lastPos / 100) / 10}, puntos ${play.songScore}, fallos ${play.songMisses}, vida ${Math.round(play.health * 100) / 100}');
		if (frames > 0)
			log.push('Rendimiento: ${Math.round(frames / frameTime)} FPS de media, peor fotograma ${Math.round(worstFrame * 1000)} ms');
		if (shots.length > 0) log.push('Capturas sin hacer (la cancion acabo antes): ${shots.length}');

		File.saveContent('song_test.txt', log.join('\n') + '\n');
		trace('SONGTEST FIN');
		Sys.exit(0);
	}
}
#end
