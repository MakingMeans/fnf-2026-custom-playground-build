package states.stages.objects;

/**
 * Las letras de Vs Sonic.exe (port de su custom_events/Normal Lyrics.lua): una frase partida en trozos
 * con ";" sobre un fondo negro semitransparente, con el trozo que se canta resaltado (mas arriba y en
 * el color de la barra del rival, o en el que diga el evento) en camOther.
 *  - Evento "Normal Lyrics": v1 = frase o clave de data/<cancion>/lyrics.json ("lyrics.chaos.1"),
 *    v2 = "trozo[, color]" (el trozo cuenta desde 1). v1 vacio borra la frase.
 *  - lyrics.json trae la frase en cada idioma: se usa el del juego, o uno de la misma lengua, o
 *    en-US. `line()` sirve tambien para los subtitulos del game over ("gameover.chaos.3").
 */
@:access(states.PlayState)
class SonicLyrics
{
	var play:PlayState;
	var phrases:Dynamic;
	var pieces:Array<FlxText> = [];
	var bg:FlxSprite;
	var current:String = '';

	public function new(play:PlayState)
	{
		this.play = play;
		phrases = loadPhrases(play.songName);
	}

	/** Las frases de data/<cancion>/lyrics.json en el idioma del juego (null si no hay archivo). */
	public static function loadPhrases(song:String):Dynamic
	{
		var path:String = 'data/$song/lyrics.json';
		if (!Paths.fileExists(path, TEXT)) return null;
		var json:Dynamic = haxe.Json.parse(Paths.getTextFromFile(path));
		var lang:String = ClientPrefs.data.language;
		if (Reflect.hasField(json, lang)) return Reflect.field(json, lang);
		var prefix:String = lang.split('-')[0] + '-';
		for (field in Reflect.fields(json))
			if (field.startsWith(prefix)) return Reflect.field(json, field);
		return Reflect.field(json, 'en-US');
	}

	public static function phrase(phrases:Dynamic, key:String):String
	{
		if (phrases == null || key.indexOf('.') < 0) return null;
		var value:Dynamic = Reflect.field(phrases, key);
		return value != null ? Std.string(value) : null;
	}

	public function line(key:String):String
	{
		var value:String = phrase(phrases, key);
		return value != null ? value : key;
	}

	public function event(value1:String, value2:String)
	{
		if (value1 == '')
		{
			clear();
			return;
		}

		var text:String = line(value1);
		var options:Array<String> = value2.split(',');
		if (text != current)
		{
			clear();
			for (word in text.split(';'))
			{
				if (word.length == 0) continue;
				var piece:FlxText = new FlxText(0, 0, 0, word, 25);
				piece.setFormat(Paths.font('vcr.ttf'), 25, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				piece.borderSize = 2;
				piece.antialiasing = false;
				piece.cameras = [play.camOther];
				pieces.push(piece);
			}
			if (pieces.length == 0) return;

			var totalWidth:Float = 0;
			for (piece in pieces) totalWidth += piece.width - 2;
			var totalHeight:Float = pieces[pieces.length - 1].height + 8;
			var x:Float = FlxG.width / 2 - totalWidth / 2;

			bg = new FlxSprite(x, Math.floor(FlxG.height * 0.73)).makeGraphic(Std.int(totalWidth), Std.int(totalHeight), FlxColor.BLACK);
			bg.alpha = 0.6;
			bg.cameras = [play.camOther];
			play.add(bg);
			for (piece in pieces)
			{
				piece.x = Math.floor(x);
				x += piece.width - 2;
				play.add(piece);
			}
		}
		current = text;

		var highlight:Null<Int> = Std.parseInt(options[0].trim());
		var dadColor:FlxColor = FlxColor.fromRGB(play.dad.healthColorArray[0], play.dad.healthColorArray[1], play.dad.healthColorArray[2]);
		var dark:Bool = 0.299 * dadColor.red + 0.587 * dadColor.green + 0.114 * dadColor.blue < 128;
		for (i => piece in pieces)
		{
			if (highlight != null && i + 1 == highlight)
			{
				var custom:String = options.length > 1 ? options[1].trim() : '';
				piece.color = custom.length > 0 ? CoolUtil.colorFromString(custom) : dadColor;
				piece.borderColor = dark ? FlxColor.WHITE : FlxColor.BLACK;
				piece.y = Math.floor(FlxG.height * 0.73);
			}
			else
			{
				piece.color = FlxColor.WHITE;
				piece.borderColor = FlxColor.BLACK;
				piece.y = Math.floor(FlxG.height * 0.74);
			}
		}
	}

	public function clear()
	{
		for (piece in pieces)
		{
			play.remove(piece, true);
			piece.destroy();
		}
		pieces = [];
		if (bg != null)
		{
			play.remove(bg, true);
			bg.destroy();
			bg = null;
		}
		current = '';
	}
}
