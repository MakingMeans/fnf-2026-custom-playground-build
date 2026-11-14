package states;

import backend.Highscore;
import backend.Song;
import backend.WeekData;

/**
 * Arranque directo a una cancion: `FNF2026Playground.exe -song <cancion>`.
 * La prepara como lo hace Freeplay (su semana, la dificultad del juego, el chart) y abre PlayState;
 * al acabar se vuelve a Freeplay. Sirve para probar una cancion sin pasar por menus ni por el mapa.
 */
class QuickSongState extends MusicBeatState
{
	var song:String;

	public function new(song:String)
	{
		super();
		this.song = Paths.formatToSongPath(song);
	}

	override function create()
	{
		super.create();

		// la semana de la cancion: su carpeta (si viene de un mod) y su posicion para PlayState
		WeekData.reloadWeekFiles(false);
		for (i in 0...WeekData.weeksList.length)
		{
			var week:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var songs:Array<Dynamic> = week.songs;
			if (!Lambda.exists(songs, entry -> Paths.formatToSongPath(entry[0]) == song)) continue;

			PlayState.storyWeek = i;
			WeekData.setDirectoryFromWeek(week);
			break;
		}
		Difficulty.resetList();

		try
		{
			Song.loadFromJson(Highscore.formatSong(song, 0), song);
		}
		catch (e:haxe.Exception)
		{
			trace('No se pudo cargar la cancion "$song": ${e.message}');
			FlxTransitionableState.skipNextTransIn = true;
			MusicBeatState.switchState(new MainMenuState());
			return;
		}

		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = 0;

		// PlayState (y sus scripts) dan por hecho que ya existe FlxG.sound.music, que normalmente
		// crea la musica de los menus; entrando directo hay que crearla (parada)
		if (FlxG.sound.music == null)
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			FlxG.sound.music.stop();
		}

		LoadingState.prepareToSong();
		FlxTransitionableState.skipNextTransIn = true;
		LoadingState.loadAndSwitchState(new PlayState());
	}
}
