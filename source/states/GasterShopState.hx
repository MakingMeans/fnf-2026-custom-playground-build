package states;

import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import backend.OverworldData;
import openfl.display.BlendMode;

/** Una linea de Gaster: el texto y la cara con la que la dice. */
typedef GasterLine =
{
	var text:String;
	var face:String;
}

/**
 * La tienda de Gaster, de Friday Night Dustin' (su data/states/ShopState.hx de Codename Engine, rehecha
 * aqui): el fondo, la luz, Gaster con sus caras, su musica y un cuadro de dialogo con el texto letra a
 * letra, con su eco en wingdings detras y sus susurros. Cada mundo tiene la suya: lo que dice esta en
 * data/gaster_shop/<tienda>.json ("first" la primera vez y "return" las siguientes; los copia
 * tools/ports/gaster_shop.py). La del mundo 1 solo es charla: todavia no vende nada. Al acabar (o con BACK)
 * Gaster se desvanece y se vuelve al mapa, al mismo nodo.
 */
@:access(flixel.text.FlxText)
class GasterShopState extends MusicBeatState
{
	/** Las caras de su atlas (todas en bucle, a 12 fps como en el mod). */
	static final FACES:Array<String> = ['idle', 'talk', 'focus', 'surprised', 'scary', 'goofy'];
	/** Segundos por letra (la velocidad de sus dialogos en el mod). */
	static inline final LETTER_TIME:Float = 0.08;

	var shopId:String;
	var lines:Array<GasterLine> = [];
	var lineIndex:Int = -1;

	var gaster:FlxSprite;
	var boxBorder:FlxSprite;
	var boxFill:FlxSprite;
	var text:FlxText;
	var echo:FlxText;

	var fullText:String = '';
	var shown:Int = 0;
	var letterTimer:Float = 0;
	var leaving:Bool = false;

	/** Apuntar en la partida que ya se ha visitado (las pruebas con -gaster-shop no lo apuntan). */
	var remember:Bool;

	public function new(shopId:String, ?remember:Bool = true)
	{
		super();
		this.shopId = shopId;
		this.remember = remember;
	}

	/** Olvida que se visito una tienda (la siguiente vez Gaster vuelve a decir lo de la primera). */
	public static function forgetVisit(shopId:String)
	{
		var visited:Dynamic = FlxG.save.data.gasterShops;
		if (visited == null || !Reflect.hasField(visited, shopId)) return;
		Reflect.deleteField(visited, shopId);
		FlxG.save.flush();
	}

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('gaster_shop/background_gaster'));
		bg.scrollFactor.set();
		bg.screenCenter();
		add(bg);

		var light:FlxSprite = new FlxSprite(485, -100).loadGraphic(Paths.image('gaster_shop/light'));
		light.alpha = 0.75;
		light.blend = BlendMode.ADD;
		add(light);

		gaster = new FlxSprite(650, 85);
		gaster.frames = Paths.getSparrowAtlas('gaster_shop/gaster');
		for (face in FACES) gaster.animation.addByPrefix(face, face, 12, true);
		gaster.animation.play('idle');
		add(gaster);


		// cuadro de dialogo de Undertale: negro con borde blanco de 5 px
		boxBorder = new FlxSprite(515, 470).makeGraphic(700, 210, FlxColor.WHITE);
		add(boxBorder);
		boxFill = new FlxSprite(520, 475).makeGraphic(690, 200, FlxColor.BLACK);
		add(boxFill);

		echo = new FlxText(550, 510, 670, '', 32);
		echo.setFormat(Paths.font('pixel-wingdings.otf'), 32, FlxColor.WHITE, LEFT);
		spaceLetters(echo, 8);
		echo.alpha = 0.2;
		add(echo);

		text = new FlxText(540, 490, 670, '', 40);
		text.setFormat(Paths.font('8bit-jve.ttf'), 40, FlxColor.WHITE, LEFT);
		spaceLetters(text, 8);
		add(text);

		addExpBox();
		loadLines();
		FlxG.sound.playMusic(Paths.music('gaster_shop'), 0.7);
		super.create();
		nextLine();
	}

	var expParts:Array<FlxSprite> = [];

	/**
	 * La EXP que se tiene (la moneda de la tienda; se gana superando niveles), en su cuadro encima del de
	 * dialogo como el "EXP:" del mod. El cuadro crece hacia la izquierda si el numero no cabe.
	 */
	function addExpBox()
	{
		var expText:FlxText = new FlxText(0, 0, 0, 'EXP: ' + OverworldData.getXP(), 40);
		expText.setFormat(Paths.font('8bit-jve.ttf'), 40, FlxColor.WHITE, LEFT);
		var width:Int = Std.int(Math.max(200, expText.width + 40));
		var right:Int = 515 + 700; // el borde derecho del cuadro de dialogo
		var border:FlxSprite = new FlxSprite(right - width, 405).makeGraphic(width, 55, FlxColor.WHITE);
		var fill:FlxSprite = new FlxSprite(border.x + 5, border.y + 5).makeGraphic(width - 10, 45, FlxColor.BLACK);
		expText.setPosition(Math.floor(border.x + (width - expText.width) / 2), Math.floor(border.y + (55 - expText.height) / 2));
		for (spr in [border, fill, expText])
		{
			add(spr);
			expParts.push(spr);
		}
	}

	/** Separacion entre letras, como en el mod (FlxText de esta version de flixel no la tiene a mano). */
	static function spaceLetters(txt:FlxText, spacing:Float)
	{
		txt._defaultFormat.letterSpacing = spacing;
		txt.updateDefaultFormat();
	}

	/** Lo que dice esta tienda: "first" la primera vez, "return" despues (se apunta en la partida). */
	function loadLines()
	{
		var data:Dynamic = null;
		try
		{
			data = haxe.Json.parse(Paths.getTextFromFile('data/gaster_shop/$shopId.json'));
		}
		catch (e:Dynamic) {}
		if (data == null)
		{
			lines = [{text: '...', face: 'idle'}];
			return;
		}

		var visited:Dynamic = FlxG.save.data.gasterShops;
		var seen:Bool = visited != null && Reflect.field(visited, shopId) == true;
		var key:String = (seen && Reflect.hasField(data, 'return')) ? 'return' : 'first';
		var list:Array<Dynamic> = Reflect.field(data, key);
		lines = [for (line in (list != null ? list : [])) {text: Std.string(line.text), face: line.face != null ? Std.string(line.face) : 'talk'}];
		if (lines.length < 1) lines = [{text: '...', face: 'idle'}];

		if (!seen && remember)
		{
			if (FlxG.save.data.gasterShops == null) FlxG.save.data.gasterShops = {};
			Reflect.setField(FlxG.save.data.gasterShops, shopId, true);
			FlxG.save.flush();
		}
	}

	function nextLine()
	{
		lineIndex++;
		if (lineIndex >= lines.length)
		{
			leave();
			return;
		}
		var line:GasterLine = lines[lineIndex];
		if (gaster.animation.getByName(line.face) != null) gaster.animation.play(line.face, true);
		fullText = line.text;
		shown = 0;
		letterTimer = 0;
		text.text = '';
		echo.text = '';
	}

	inline function typing():Bool
		return shown < fullText.length;

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		// la camara centrada en Gaster, como en el mod mientras habla (Psych la recoloca al crear el estado)
		FlxG.camera.scroll.set(gaster.x + gaster.frameWidth * 0.5 - FlxG.width * 0.5, 0);
		if (leaving) return;

		if (typing())
		{
			letterTimer += elapsed;
			while (letterTimer >= LETTER_TIME && typing())
			{
				letterTimer -= LETTER_TIME;
				shown++;
				var letter:String = fullText.charAt(shown - 1);
				if (letter != ' ' && letter != '\n') whisper();
			}
			text.text = fullText.substr(0, shown);
			echo.text = text.text;
		}
		// el eco en wingdings tiembla un poco, como el del mod
		echo.offset.set(FlxG.random.int(-1, 1), FlxG.random.int(-1, 1));

		if (controls.BACK)
		{
			leave();
			return;
		}
		if (controls.ACCEPT)
		{
			if (typing())
			{
				shown = fullText.length;
				text.text = echo.text = fullText;
			}
			else nextLine();
		}
	}

	/** La voz de Gaster: uno de sus siete "wingdings" por cada letra que aparece (no en espacios ni saltos), a 0,7,
	 * como su ShopState.hx en Friday Night Dustin'. */
	function whisper()
		FlxG.sound.play(Paths.sound('gaster_shop/wingding' + FlxG.random.int(1, 7)), 0.7);

	/** Gaster se desvanece y se vuelve al mapa. */
	function leave()
	{
		if (leaving) return;
		leaving = true;
		gaster.animation.play('idle', true);
		FlxG.sound.play(Paths.sound('gaster_shop/vanish'), 0.5);
		if (FlxG.sound.music != null) FlxG.sound.music.fadeOut(1.2, 0);
		for (spr in [boxBorder, boxFill, text, echo].concat(expParts)) FlxTween.tween(spr, {alpha: 0}, 0.4);
		FlxTween.tween(gaster, {alpha: 0}, 1.2, {ease: FlxEase.quadIn, onComplete: function(_) OverworldState.backFromShop()});
	}
}
