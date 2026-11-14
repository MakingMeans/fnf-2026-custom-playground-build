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
 */
@:access(states.PlayState)
@:access(backend.MusicBeatState)
class SongTester extends FlxBasic
{
	public static var running:Bool = false;

	var song:String;
	var shots:Array<Float> = []; // ms de cancion
	var winShots:Array<Float> = []; // ms de cancion: avisos para capturar la ventana desde fuera
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
			finish();
			return;
		}

		lastPos = Conductor.songPosition;
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
			log.push('Captura $name (paso ${play.curStep}, ${play.boyfriend.curCharacter} vs ${play.dad.curCharacter}, vida ${Math.round(play.health * 100) / 100})');
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
