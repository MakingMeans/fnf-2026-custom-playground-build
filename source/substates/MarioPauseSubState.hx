package substates;

import shaders.TVStaticShader;

/**
 * Menu de pausa de Mario's Madness V2 (su `source/PauseSubState.hx`, version normal, no la "retro"): a la
 * izquierda un panel con estatica de TV y los botones de Mario; a la derecha el modo, la cancion, su autor,
 * los creditos y la descripcion (`data/<cancion>/desc.txt` del mod: linea 1 descripcion, linea 2 creditos).
 * Musica breakfast 1-3 al azar. Como en el mod: sin "Options", y "Botplay" solo fuera del modo historia
 * (aqui: solo si no se viene del mapa). Lo abren Last Course y Bad Day (MarioStage).
 */
class MarioPauseSubState extends MusicBeatSubstate
{
	static final TEXT_X:Float = 566;

	var author:String;
	var items:Array<String>;
	var buttons:Array<FlxSprite> = [];
	var curSelected:Int = 0;
	var selected:Bool = false;

	var bg:FlxSprite;
	var panel:FlxSprite;
	var staticShader:TVStaticShader;
	var texts:Array<FlxSprite> = [];
	var descAll:FlxText;
	var botplayText:FlxText;
	var pauseMusic:FlxSound;
	var tweens:Array<FlxTween> = [];

	public function new(author:String)
	{
		super();
		this.author = author;
	}

	override function create()
	{
		super.create();
		// Botplay solo en Freeplay: en el mapa contaria como superar el nivel sin jugarlo
		items = states.OverworldState.fromOverworld ? ['resume', 'restart', 'exit'] : ['resume', 'restart', 'botplay', 'exit'];

		pauseMusic = new FlxSound().loadEmbedded(Paths.music('mario_madness/breakfast' + FlxG.random.int(1, 3)), true, true);
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
		FlxG.sound.list.add(pauseMusic);

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		// lo de la derecha
		var lines:Array<String> = CoolUtil.listFromString(Paths.getTextFromFile('data/${PlayState.instance.songName}/desc.txt') ?? '');
		var modeText:FlxText = addText(31, 0, PlayState.isStoryMode || states.OverworldState.fromOverworld ? 'Story Mode' : 'Freeplay', 17);
		var line1:FlxSprite = new FlxSprite(TEXT_X, modeText.y + 30).makeGraphic(630, 3, FlxColor.WHITE);
		addFaded(line1, 0.3);
		var songText:FlxText = addText(modeText.y + 40, 0, PlayState.SONG.song, 22);
		var authorText:FlxText = addText(modeText.y + 80, 700, author.replace('\n', ' '), 17);
		var creditsText:FlxText = addText(authorText.y + 40, 700, lines.length > 1 ? lines[1] : '', 17, 0.6);
		var descTitle:FlxText = addText(creditsText.y + creditsText.height + 20, 0, 'Description', 17, 0.6);
		var line2:FlxSprite = new FlxSprite(TEXT_X, descTitle.y + 30).makeGraphic(630, 3, FlxColor.WHITE);
		addFaded(line2, 0.6);
		descAll = addText(descTitle.y + 40, 700, lines.length > 0 ? lines[0] : '', 17, 0.6);

		botplayText = new FlxText(20, FlxG.height - 40, 0, 'BOTPLAY', 32);
		botplayText.setFormat(Paths.font('vcr.ttf'), 32);
		botplayText.x = FlxG.width - (botplayText.width + 20);
		botplayText.scrollFactor.set();
		botplayText.visible = PlayState.instance.cpuControlled;
		add(botplayText);

		// el panel de la izquierda entra deslizandose, con su estatica
		panel = new FlxSprite(-550).loadGraphic(Paths.image('mario_madness/pause/momichi'));
		panel.screenCenter(Y);
		panel.scrollFactor.set();
		staticShader = new TVStaticShader();
		panel.shader = staticShader;
		add(panel);
		FlxTween.tween(panel, {x: -200}, 0.2, {ease: FlxEase.backOut});
		tweens.push(FlxTween.tween(bg, {alpha: 0.7}, 0.4, {ease: FlxEase.quartOut}));

		// cada boton es un atlas con dos animaciones; el mod las llamaba por nombres de otro menu
		var spacing:Float = items.length > 3 ? 150 : 215;
		for (i => item in items)
		{
			var anim:String = switch (item)
			{
				case 'resume': 'credits';
				case 'restart': 'freeplay';
				case 'botplay': 'options';
				default: 'Exit';
			}
			var button:FlxSprite = new FlxSprite(0, 88 + i * spacing);
			button.frames = Paths.getSparrowAtlas('mario_madness/pause/' + item);
			button.animation.addByPrefix('idle', anim + ' white', 24);
			button.animation.addByPrefix('selected', anim + ' basic', 24);
			button.animation.play('idle');
			button.setGraphicSize(Std.int(button.width * 0.5));
			button.updateHitbox();
			button.antialiasing = ClientPrefs.data.antialiasing;
			button.scrollFactor.set();
			button.x = panel.x + 220;
			add(button);
			buttons.push(button);
			FlxTween.tween(button, {x: 20}, 0.2, {ease: FlxEase.backOut});
		}
		changeSelection(0);

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	function addText(y:Float, width:Float, text:String, size:Int, delay:Float = 0.3):FlxText
	{
		var txt:FlxText = new FlxText(TEXT_X, y, width, text);
		txt.setFormat(Paths.font('mariones.ttf'), size);
		addFaded(txt, delay);
		return txt;
	}

	function addFaded(spr:FlxSprite, delay:Float)
	{
		spr.scrollFactor.set();
		spr.alpha = 0;
		add(spr);
		texts.push(spr);
		tweens.push(FlxTween.tween(spr, {alpha: 1}, 0.4, {ease: FlxEase.quartOut, startDelay: delay}));
	}

	override function update(elapsed:Float)
	{
		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;
		super.update(elapsed);
		staticShader.update(elapsed);
		if (selected) return;

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);
		if (controls.BACK)
		{
			close();
			return;
		}
		if (!controls.ACCEPT) return;

		switch (items[curSelected])
		{
			case 'resume':
				close();
			case 'botplay':
				var play:PlayState = PlayState.instance;
				play.cpuControlled = !play.cpuControlled;
				PlayState.changedDifficulty = true;
				play.botplayTxt.visible = play.cpuControlled;
				play.botplayTxt.alpha = 1;
				play.botplaySine = 0;
				botplayText.visible = play.cpuControlled;
			case 'restart':
				selected = true;
				hideAll();
				FlxG.sound.play(Paths.sound('mario_madness/restart'));
				FlxTween.tween(bg, {alpha: 0}, 0.4, {ease: FlxEase.quartOut, onComplete: function(_) PauseSubState.restartSong()});
			case 'exit':
				selected = true;
				hideAll();
				FlxTween.tween(bg, {alpha: 0}, 0.4, {ease: FlxEase.quartOut, onComplete: function(_) PauseSubState.exitToMenu()});
		}
	}

	/** Todo sale: los textos se desvanecen y el panel y los botones se van por la izquierda. */
	function hideAll()
	{
		for (tween in tweens) tween.cancel();
		for (spr in texts) FlxTween.tween(spr, {alpha: 0}, 0.4, {ease: FlxEase.quartOut});
		for (button in buttons) FlxTween.tween(button, {x: -550}, 0.2, {ease: FlxEase.backOut});
		FlxTween.tween(panel, {x: -750}, 0.2, {ease: FlxEase.backOut});
	}

	function changeSelection(change:Int)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, items.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		for (i => button in buttons)
		{
			var on:Bool = i == curSelected;
			button.animation.play(on ? 'selected' : 'idle');
			button.alpha = on ? 1 : 0.9;
			button.color = on ? FlxColor.WHITE : 0xFF878282;
		}
	}

	override function destroy()
	{
		pauseMusic.destroy();
		super.destroy();
	}
}
