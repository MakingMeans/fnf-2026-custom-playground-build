package states;

import backend.OverworldData;
import backend.Song;
import backend.Highscore;
import backend.WeekData;

import flixel.FlxObject;
import flixel.group.FlxGroup.FlxTypedGroup;

/**
 * Mapa estilo Super Mario World: BF camina de nodo en nodo por caminos y entra a los niveles.
 * Los mundos se editan con OverworldEditorState y se guardan en assets/shared/overworlds/.
 */
class OverworldState extends MusicBeatState
{
	// ------------------------------------------------------------- estado global
	public static var curWorld:String = OverworldData.DEFAULT_WORLD;
	public static var curNodeId:String = null;

	/** true mientras una cancion lanzada desde aqui esta en marcha. */
	public static var fromOverworld:Bool = false;
	public static var lastLevelNode:String = null;

	/** true cuando se entra desde el editor: BACK devuelve al editor en vez de al menu. */
	public static var returnToEditor:Bool = false;

	static var worldStack:Array<Array<String>> = [];
	static var lastMusic:String = null;

	public static function reset()
	{
		curWorld = OverworldData.DEFAULT_WORLD;
		curNodeId = null;
		fromOverworld = false;
		returnToEditor = false;
		lastLevelNode = null;
		worldStack = [];
	}

	/** Llamado al terminar una cancion lanzada desde el overworld. */
	public static function completeCurrentNode()
	{
		if (!fromOverworld || lastLevelNode == null) return;
		OverworldData.setCompleted(curWorld, lastLevelNode);
	}

	/** Vuelve al mapa (usado por PlayState, pausa y game over). */
	public static function backToOverworld()
	{
		fromOverworld = false;
		MusicBeatState.switchState(new OverworldState());
	}

	// ------------------------------------------------------------- construccion
	var worldFile:OverworldFile;

	var camGame:FlxCamera;
	var camHUD:FlxCamera;
	var camFollow:FlxObject;

	var spritesBack:FlxTypedGroup<FlxSprite>;
	var dotsGroup:FlxTypedGroup<FlxSprite>;
	var nodesGroup:FlxTypedGroup<FlxSprite>;
	var spritesFront:FlxTypedGroup<FlxSprite>;

	var player:FlxSprite;
	var nodeSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();

	var nameTxt:FlxText;
	var hintTxt:FlxText;
	var errorTxt:FlxText;

	var mapWidth:Float = 0;
	var mapHeight:Float = 0;

	var playerX:Float = 0;
	var playerY:Float = 0;
	var facing:String = 'down';

	var walking:Bool = false;
	var walkQueue:Array<Array<Float>> = [];
	var walkTarget:OverworldNodeFile = null;

	var busy:Bool = false;

	public function new(?world:String = null, ?node:String = null)
	{
		if (world != null) curWorld = world;
		if (node != null) curNodeId = node;
		super();
	}

	override function create()
	{
		fromOverworld = false;

		worldFile = OverworldData.load(curWorld);
		if (worldFile == null)
		{
			var msg:String = 'NO SE PUDO CARGAR EL MUNDO "$curWorld"\n\nassets/shared/overworlds/$curWorld.json\n\nACCEPT: abrir el editor de mundos\nBACK: menu principal';
			FlxTransitionableState.skipNextTransIn = true;
			MusicBeatState.switchState(new ErrorState(msg,
				function() MusicBeatState.switchState(new states.editors.OverworldEditorState(curWorld)),
				function() MusicBeatState.switchState(new MainMenuState())));
			return;
		}

		#if debug
		// en debug los avisos del grafo salen por consola cada vez que se carga un mundo
		for (problem in OverworldData.checkWorld(worldFile)) trace('Overworld "$curWorld": $problem');
		#end

		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		persistentUpdate = false;
		FlxG.mouse.visible = false;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Overworld', worldFile.displayName);
		#end

		buildMap();
		buildHUD();

		camGame.zoom = worldFile.zoom;
		applyCameraBounds();
		camGame.follow(camFollow, LOCKON, 0.12);
		camGame.snapToTarget();

		if (worldFile.music != null && worldFile.music.length > 0)
		{
			if (lastMusic != worldFile.music || FlxG.sound.music == null || !FlxG.sound.music.playing)
			{
				FlxG.sound.playMusic(Paths.music(worldFile.music));
				lastMusic = worldFile.music;
			}
		}

		super.create();
	}

	/**
	 * Sprites del fondo ya colocados. Si el mundo tiene bgTile, se repite en mosaico hasta
	 * cubrir todo lo que ocupen nodos y decorados (util para un fondo de mar).
	 */
	public static function buildBackgroundSprites(file:OverworldFile):Array<FlxSprite>
	{
		var result:Array<FlxSprite> = [];
		if (file.bg == null || file.bg.length < 1) return result;

		var first:FlxSprite = buildSprite(file.bg, file.bgAnim, file.bgFps);
		first.setPosition(0, 0);
		result.push(first);

		if (!file.bgTile || first.width < 8 || first.height < 8) return result;

		var targetWidth:Float = first.width;
		var targetHeight:Float = first.height;

		for (node in file.nodes)
		{
			if (node.x + 32 > targetWidth) targetWidth = node.x + 32;
			if (node.y + 32 > targetHeight) targetHeight = node.y + 32;
		}
		for (spr in file.sprites)
		{
			if (spr.x + 64 > targetWidth) targetWidth = spr.x + 64;
			if (spr.y + 64 > targetHeight) targetHeight = spr.y + 64;
		}

		var columns:Int = Std.int(Math.min(12, Math.ceil(targetWidth / first.width)));
		var rows:Int = Std.int(Math.min(12, Math.ceil(targetHeight / first.height)));

		for (row in 0...rows)
		{
			for (column in 0...columns)
			{
				if (row == 0 && column == 0) continue;

				var tile:FlxSprite = buildSprite(file.bg, file.bgAnim, file.bgFps);
				tile.setPosition(column * first.width, row * first.height);
				result.push(tile);
			}
		}
		return result;
	}

	function buildMap()
	{
		var bgWidth:Float = FlxG.width;
		var bgHeight:Float = FlxG.height;

		var bgTiles:Array<FlxSprite> = buildBackgroundSprites(worldFile);
		for (tile in bgTiles) add(tile);

		if (bgTiles.length > 0)
		{
			var last:FlxSprite = bgTiles[bgTiles.length - 1];
			bgWidth = last.x + last.width;
			bgHeight = last.y + last.height;
		}

		spritesBack = new FlxTypedGroup<FlxSprite>();
		dotsGroup = new FlxTypedGroup<FlxSprite>();
		nodesGroup = new FlxTypedGroup<FlxSprite>();
		spritesFront = new FlxTypedGroup<FlxSprite>();

		add(spritesBack);
		add(dotsGroup);
		add(nodesGroup);

		for (data in worldFile.sprites)
		{
			var spr:FlxSprite = buildSprite(data.image, data.anim, data.fps);
			spr.setPosition(data.x, data.y);
			spr.flipX = data.flipX;
			spr.flipY = data.flipY;
			spr.alpha = data.alpha;
			if (data.scale != 1)
			{
				spr.scale.set(data.scale, data.scale);
				spr.updateHitbox();
				spr.setPosition(data.x, data.y);
			}

			if (data.front) spritesFront.add(spr);
			else spritesBack.add(spr);
		}

		for (pth in worldFile.paths) buildPathDots(pth);

		// Los nodos se dibujan siempre, estén o no accesibles: lo que se revela al
		// desbloquear es el camino, igual que en Super Mario World.
		for (node in worldFile.nodes)
		{
			var completed:Bool = OverworldData.isCompleted(curWorld, node.id);
			var anim:String = (completed && node.animDone != null && node.animDone.length > 0) ? node.animDone : node.anim;

			var spr:FlxSprite = buildSprite(node.image, anim, node.fps);
			spr.setPosition(node.x - spr.width * 0.5, node.y - spr.height * 0.5);
			nodesGroup.add(spr);
			nodeSprites.set(node.id, spr);
		}

		// jugador
		player = new FlxSprite();
		loadPlayerGraphic();
		add(player);
		add(spritesFront);

		var start:OverworldNodeFile = getCurrentNode();
		if (start == null)
		{
			errorTxt = new FlxText(0, 0, FlxG.width, 'Este mundo no tiene ningun nodo desbloqueado', 20);
			errorTxt.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			errorTxt.screenCenter();
			errorTxt.cameras = [camHUD];
			add(errorTxt);
		}
		else
		{
			curNodeId = start.id;
			playerX = start.x;
			playerY = start.y;
		}

		updatePlayerPosition();
		idleAnim();

		camFollow = new FlxObject(playerX, playerY, 1, 1);
		add(camFollow);

		mapWidth = bgWidth;
		mapHeight = bgHeight;
	}

	/**
	 * Limita el scroll al mapa. Si el mapa cabe entero en pantalla por un eje, ese eje se centra
	 * (con los limites "normales" flixel lo empujaria a una esquina).
	 */
	function applyCameraBounds()
	{
		if (mapWidth <= 0 || mapHeight <= 0) return;

		var viewWidth:Float = FlxG.width / camGame.zoom;
		var viewHeight:Float = FlxG.height / camGame.zoom;

		var rectX:Float = 0;
		var rectWidth:Float = mapWidth;
		if (mapWidth < viewWidth)
		{
			rectX = mapWidth * 0.5 - viewWidth * 0.5;
			rectWidth = viewWidth;
		}

		var rectY:Float = 0;
		var rectHeight:Float = mapHeight;
		if (mapHeight < viewHeight)
		{
			rectY = mapHeight * 0.5 - viewHeight * 0.5;
			rectHeight = viewHeight;
		}

		camGame.setScrollBoundsRect(rectX, rectY, rectWidth, rectHeight);
	}

	function buildPathDots(pth:OverworldPathFile)
	{
		if (pth.dots == null || pth.dots.length < 1) return;

		var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
		var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
		if (nodeA == null || nodeB == null) return;

		if (!OverworldData.isUnlocked(curWorld, worldFile, nodeA) || !OverworldData.isUnlocked(curWorld, worldFile, nodeB))
			return;

		for (point in getDotPositions(pth, nodeA, nodeB))
		{
			var dot:FlxSprite = buildSprite(pth.dots, pth.dotAnim, 6);
			dot.setPosition(point[0] - dot.width * 0.5, point[1] - dot.height * 0.5);
			dotsGroup.add(dot);
		}
	}

	/** Posiciones de los puntitos repartidos a lo largo de la polilinea del camino. */
	public static function getDotPositions(pth:OverworldPathFile, nodeA:OverworldNodeFile, nodeB:OverworldNodeFile):Array<Array<Float>>
	{
		var result:Array<Array<Float>> = [];
		var spacing:Float = pth.dotSpacing;
		if (spacing < 2) spacing = 16;

		var line:Array<Array<Float>> = buildLine(pth, nodeA, nodeB);
		var total:Float = 0;
		for (i in 0...line.length - 1)
			total += distance(line[i], line[i + 1]);

		if (total <= spacing) return result;

		var travelled:Float = spacing;
		var segment:Int = 0;
		var segmentStart:Float = 0;

		while (travelled < total - spacing * 0.5 && segment < line.length - 1)
		{
			var segLength:Float = distance(line[segment], line[segment + 1]);
			if (travelled > segmentStart + segLength)
			{
				segmentStart += segLength;
				segment++;
				continue;
			}

			var ratio:Float = segLength > 0 ? (travelled - segmentStart) / segLength : 0;
			result.push([
				line[segment][0] + (line[segment + 1][0] - line[segment][0]) * ratio,
				line[segment][1] + (line[segment + 1][1] - line[segment][1]) * ratio
			]);
			travelled += spacing;
		}
		return result;
	}

	public static function buildLine(pth:OverworldPathFile, nodeA:OverworldNodeFile, nodeB:OverworldNodeFile):Array<Array<Float>>
	{
		var line:Array<Array<Float>> = [[nodeA.x, nodeA.y]];
		if (pth.points != null)
			for (point in pth.points)
				if (point != null && point.length > 1) line.push([point[0], point[1]]);
		line.push([nodeB.x, nodeB.y]);
		return line;
	}

	static function distance(a:Array<Float>, b:Array<Float>):Float
	{
		var dx:Float = b[0] - a[0];
		var dy:Float = b[1] - a[1];
		return Math.sqrt(dx * dx + dy * dy);
	}

	/** Crea un sprite a partir de una clave de imagen y (opcionalmente) un prefijo de animacion. */
	public static function buildSprite(image:String, anim:String, fps:Int, ?loop:Bool = true):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite();
		spr.antialiasing = false;

		if (image == null || image.length < 1 || !OverworldData.imageExists(image))
		{
			spr.makeGraphic(16, 16, FlxColor.MAGENTA);
			return spr;
		}

		if (anim != null && anim.length > 0 && OverworldData.hasAtlas(image))
		{
			spr.frames = Paths.getSparrowAtlas(image);
			spr.animation.addByPrefix('idle', anim, fps > 0 ? fps : 6, loop);
			if (spr.animation.getByName('idle') != null) spr.animation.play('idle');
			else spr.loadGraphic(Paths.image(image));
		}
		else spr.loadGraphic(Paths.image(image));

		spr.antialiasing = false;
		spr.updateHitbox();
		return spr;
	}

	function loadPlayerGraphic()
	{
		var key:String = worldFile.player;
		if (key == null || key.length < 1 || !OverworldData.imageExists(key))
		{
			player.makeGraphic(16, 20, FlxColor.LIME);
			return;
		}

		if (!OverworldData.hasAtlas(key))
		{
			player.loadGraphic(Paths.image(key));
			player.antialiasing = false;
			return;
		}

		player.frames = Paths.getSparrowAtlas(key);
		player.antialiasing = false;

		var anims:Array<String> = OverworldData.listAnimations(key);
		addPlayerAnim('walk_down', anims, 'walk down');
		addPlayerAnim('walk_up', anims, 'walk up');
		addPlayerAnim('walk_left', anims, 'walk left');
		addPlayerAnim('walk_right', anims, 'walk right');
		addPlayerAnim('enter', anims, 'level start');

		if (player.animation.getByName('walk_down') == null && anims.length > 0)
			player.animation.addByPrefix('walk_down', anims[0], 8, true);

		player.animation.play('walk_down');
		player.animation.pause();
		player.updateHitbox();
	}

	function addPlayerAnim(name:String, anims:Array<String>, needle:String)
	{
		var lower:String = needle.toLowerCase();
		for (anim in anims)
		{
			if (anim.toLowerCase().indexOf(lower) < 0) continue;
			player.animation.addByPrefix(name, anim, 8, true);
			return;
		}
	}

	function buildHUD()
	{
		var bar:FlxSprite = new FlxSprite(0, FlxG.height - 52).makeGraphic(FlxG.width, 52, FlxColor.BLACK);
		bar.alpha = 0.55;
		bar.cameras = [camHUD];
		add(bar);

		nameTxt = new FlxText(10, FlxG.height - 48, FlxG.width - 20, '', 24);
		nameTxt.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		nameTxt.cameras = [camHUD];
		add(nameTxt);

		hintTxt = new FlxText(10, FlxG.height - 22, FlxG.width - 20, 'ACCEPT: entrar    BACK: menu    R: reiniciar progreso de este mundo', 14);
		hintTxt.setFormat(Paths.font('vcr.ttf'), 14, 0xFFCCCCCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hintTxt.cameras = [camHUD];
		add(hintTxt);

		updateNameText();
	}

	// ------------------------------------------------------------- bucle
	override function update(elapsed:Float)
	{
		if (worldFile == null)
		{
			super.update(elapsed);
			return;
		}

		if (walking) updateWalk(elapsed);
		else if (!busy) updateInput();

		if (camFollow != null) camFollow.setPosition(playerX, playerY);

		super.update(elapsed);
	}

	function updateInput()
	{
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			goBack();
			return;
		}

		if (controls.ACCEPT)
		{
			enterNode();
			return;
		}

		if (FlxG.keys.justPressed.R)
		{
			OverworldData.resetProgress(curWorld);
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.resetState();
			return;
		}

		var dirX:Float = 0;
		var dirY:Float = 0;
		if (controls.UI_LEFT_P) dirX = -1;
		else if (controls.UI_RIGHT_P) dirX = 1;
		else if (controls.UI_UP_P) dirY = -1;
		else if (controls.UI_DOWN_P) dirY = 1;

		if (dirX != 0 || dirY != 0) tryWalk(dirX, dirY);
	}

	function goBack()
	{
		if (worldStack.length > 0)
		{
			var entry:Array<String> = worldStack.pop();
			curWorld = entry[0];
			curNodeId = entry[1];
			MusicBeatState.switchState(new OverworldState());
			return;
		}

		if (returnToEditor)
		{
			returnToEditor = false;
			MusicBeatState.switchState(new states.editors.OverworldEditorState(curWorld));
			return;
		}

		MusicBeatState.switchState(new MainMenuState());
	}

	function tryWalk(dirX:Float, dirY:Float)
	{
		var current:OverworldNodeFile = getCurrentNode();
		if (current == null) return;

		// Los caminos bloqueados estan ocultos, asi que no pueden quitarle la direccion a uno
		// visible: primero se busca entre los accesibles y solo si no hay ninguno suena el cancel.
		var bestLine:Array<Array<Float>> = null;
		var bestTarget:OverworldNodeFile = null;
		var bestScore:Float = MIN_DIRECTION_SCORE;
		var lockedAhead:Bool = false;

		for (pth in worldFile.paths)
		{
			if (pth.a != current.id && pth.b != current.id) continue;

			var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
			var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
			if (nodeA == null || nodeB == null || nodeA == nodeB) continue;

			var line:Array<Array<Float>> = buildLine(pth, nodeA, nodeB);
			if (pth.b == current.id) line.reverse();
			var other:OverworldNodeFile = (pth.a == current.id) ? nodeB : nodeA;

			var score:Float = directionScore(line, dirX, dirY);
			if (score <= MIN_DIRECTION_SCORE) continue;

			if (!OverworldData.isUnlocked(curWorld, worldFile, other))
			{
				lockedAhead = true;
				continue;
			}
			if (score <= bestScore) continue;

			bestScore = score;
			bestLine = line;
			bestTarget = other;
		}

		if (bestLine == null)
		{
			if (lockedAhead) FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		bestLine.shift(); // el primer punto es donde ya esta el jugador
		walkQueue = bestLine;
		walkTarget = bestTarget;
		walking = true;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
	}

	/** Minimo parecido (producto escalar) entre la direccion pulsada y la salida del camino. */
	static inline final MIN_DIRECTION_SCORE:Float = 0.35;

	/**
	 * Cuanto se parece la salida de un camino a la direccion pulsada (1 = identica).
	 * La salida es el primer punto que de verdad se separa del nodo: un punto de curva
	 * puesto encima del propio nodo no cuenta, o el camino quedaria sin direccion.
	 */
	static function directionScore(line:Array<Array<Float>>, dirX:Float, dirY:Float):Float
	{
		var origin:Array<Float> = line[0];
		for (i in 1...line.length)
		{
			var dx:Float = line[i][0] - origin[0];
			var dy:Float = line[i][1] - origin[1];
			var length:Float = Math.sqrt(dx * dx + dy * dy);
			if (length < 1) continue;

			return (dx / length) * dirX + (dy / length) * dirY;
		}
		return -1;
	}

	function updateWalk(elapsed:Float)
	{
		var budget:Float = worldFile.walkSpeed * elapsed;

		while (budget > 0 && walkQueue.length > 0)
		{
			var point:Array<Float> = walkQueue[0];
			var dx:Float = point[0] - playerX;
			var dy:Float = point[1] - playerY;
			var dist:Float = Math.sqrt(dx * dx + dy * dy);

			if (dist > 0.001) updateFacing(dx, dy);

			if (dist <= budget)
			{
				playerX = point[0];
				playerY = point[1];
				budget -= dist;
				walkQueue.shift();
			}
			else
			{
				playerX += (dx / dist) * budget;
				playerY += (dy / dist) * budget;
				budget = 0;
			}
		}

		updatePlayerPosition();

		if (walkQueue.length < 1)
		{
			walking = false;
			if (walkTarget != null) curNodeId = walkTarget.id;
			walkTarget = null;
			idleAnim();
			updateNameText();
		}
	}

	function updateFacing(dx:Float, dy:Float)
	{
		var newFacing:String = facing;
		if (Math.abs(dx) >= Math.abs(dy)) newFacing = dx < 0 ? 'left' : 'right';
		else newFacing = dy < 0 ? 'up' : 'down';

		facing = newFacing;
		playAnim('walk_$facing');
	}

	function playAnim(name:String)
	{
		if (player.animation.getByName(name) == null) return;
		player.animation.play(name);
		player.animation.resume();
	}

	function idleAnim()
	{
		playAnim('walk_$facing');
		if (player.animation.curAnim != null)
		{
			player.animation.curAnim.curFrame = 0;
			player.animation.pause();
		}
	}

	function updatePlayerPosition()
	{
		player.setPosition(playerX - player.width * 0.5, playerY - player.height + 4);
	}

	function getCurrentNode():OverworldNodeFile
	{
		var node:OverworldNodeFile = OverworldData.findNode(worldFile, curNodeId);
		if (node != null && OverworldData.isUnlocked(curWorld, worldFile, node)) return node;

		node = OverworldData.findNode(worldFile, worldFile.startNode);
		if (node != null && OverworldData.isUnlocked(curWorld, worldFile, node)) return node;

		for (other in worldFile.nodes)
			if (OverworldData.isUnlocked(curWorld, worldFile, other)) return other;

		return null;
	}

	function updateNameText()
	{
		if (nameTxt == null) return;

		var node:OverworldNodeFile = getCurrentNode();
		if (node == null)
		{
			nameTxt.text = '';
			return;
		}

		var text:String = node.name != null && node.name.length > 0 ? node.name : node.id;
		if (node.type == 'level' && OverworldData.isCompleted(curWorld, node.id)) text += '  *';
		else if (node.type == 'world') text += '  >>';

		nameTxt.text = text;
	}

	// ------------------------------------------------------------- entrar
	function enterNode()
	{
		var node:OverworldNodeFile = getCurrentNode();
		if (node == null) return;

		switch (node.type)
		{
			case 'world':
				if (node.world == null || node.world.length < 1 || !OverworldData.exists(node.world))
				{
					FlxG.sound.play(Paths.sound('cancelMenu'));
					showError('El mundo "${node.world}" no existe');
					return;
				}

				busy = true;
				FlxG.sound.play(Paths.sound('confirmMenu'));
				worldStack.push([curWorld, curNodeId]);
				curWorld = node.world;
				curNodeId = null;
				MusicBeatState.switchState(new OverworldState());

			case 'level':
				if (node.song == null || node.song.length < 1)
				{
					FlxG.sound.play(Paths.sound('cancelMenu'));
					showError('Este nodo no tiene cancion asignada');
					return;
				}
				startLevel(node);

			default:
				FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	function startLevel(node:OverworldNodeFile)
	{
		var songName:String = Paths.formatToSongPath(node.song);

		WeekData.reloadWeekFiles(false);
		var weekIndex:Int = (node.week != null) ? WeekData.weeksList.indexOf(node.week) : -1;
		if (weekIndex > -1)
		{
			var week:WeekData = WeekData.weeksLoaded.get(node.week);
			PlayState.storyWeek = weekIndex;
			WeekData.setDirectoryFromWeek(week);
			Difficulty.loadFromWeek(week);
		}
		else
		{
			Mods.currentModDirectory = '';
			Difficulty.resetList();
		}

		// Esta build tiene una sola dificultad global, asi que siempre es la primera de la lista.
		Difficulty.resetList();
		var diff:Int = 0;

		try
		{
			Song.loadFromJson(Highscore.formatSong(songName, diff), songName);
		}
		catch (e:haxe.Exception)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			showError('No se pudo cargar "$songName":\n${e.message}');
			return;
		}

		busy = true;
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = diff;
		fromOverworld = true;
		lastLevelNode = node.id;
		curNodeId = node.id;

		FlxG.sound.play(Paths.sound('confirmMenu'));
		playAnim('enter');

		new FlxTimer().start(0.6, function(_:FlxTimer)
		{
			@:privateAccess
			if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory) Paths.freeGraphicsFromMemory();

			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			lastMusic = null;
			FreeplayState.destroyFreeplayVocals();

			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		});
	}

	var errorTimer:FlxTimer;

	function showError(text:String)
	{
		if (errorTxt == null)
		{
			errorTxt = new FlxText(0, 60, FlxG.width, '', 20);
			errorTxt.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.RED, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			errorTxt.cameras = [camHUD];
			add(errorTxt);
		}

		errorTxt.text = text;
		errorTxt.visible = true;

		if (errorTimer != null) errorTimer.cancel();
		errorTimer = new FlxTimer().start(4, function(_:FlxTimer) if (errorTxt != null) errorTxt.visible = false);
	}
}
