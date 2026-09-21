package backend;

class Difficulty
{
	// Esta build maneja UNA sola dificultad global: Hard.
	public static final defaultList:Array<String> = [
		'Hard'
	];
	// Sigue siendo 'Normal' a proposito: es el nombre de la dificultad cuyo chart va SIN sufijo.
	// Al no estar en la lista, todas las canciones cargan su chart "-hard".
	private static final defaultDifficulty:String = 'Normal';

	public static var list:Array<String> = [];

	inline public static function getFilePath(num:Null<Int> = null)
	{
		if(num == null) num = PlayState.storyDifficulty;

		var filePostfix:String = list[num];
		if(filePostfix != null && Paths.formatToSongPath(filePostfix) != Paths.formatToSongPath(defaultDifficulty))
			filePostfix = '-' + filePostfix;
		else
			filePostfix = '';
		return Paths.formatToSongPath(filePostfix);
	}

	/**
	 * La dificultad es global en esta build: se ignora lo que declare cada semana en su JSON
	 * para que no puedan reaparecer Easy ni Normal.
	 */
	inline public static function loadFromWeek(week:WeekData = null)
	{
		resetList();
	}

	inline public static function resetList()
	{
		list = defaultList.copy();
	}

	inline public static function copyFrom(diffs:Array<String>)
	{
		list = diffs.copy();
	}

	inline public static function getString(?num:Null<Int> = null, ?canTranslate:Bool = true):String
	{
		var diffName:String = list[num == null ? PlayState.storyDifficulty : num];
		if(diffName == null) diffName = defaultDifficulty;
		return canTranslate ? Language.getPhrase('difficulty_$diffName', diffName) : diffName;
	}

	inline public static function getDefault():String
	{
		return defaultDifficulty;
	}
}