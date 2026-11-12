package states;

import backend.OverworldData;
import backend.Song;
import backend.Highscore;
import backend.WeekData;

import flixel.FlxObject;
import flixel.addons.display.FlxBackdrop;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText.FlxTextFormat;
import flixel.text.FlxText.FlxTextFormatMarkerPair;

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

	/**
	 * [mundo, nodo] completado por primera vez en la ultima cancion. Al volver al mapa, los
	 * caminos que ha abierto aparecen puntito a puntito en vez de estar ya dibujados.
	 */
	static var pendingReveal:Array<String> = null;

	/**
	 * Mundo del que viene BF por una salida con destino: aqui entra andando por la de vuelta.
	 * Publico para que Main pueda simularlo con `-from <mundo>`.
	 */
	public static var arrivingFrom:String = null;

	// ------------------------------------------------------------- posicion guardada
	/**
	 * Guarda donde esta BF (mundo, nodo y pila de submundos) en la partida, para seguir ahi la
	 * proxima vez que se abra el juego. No guarda mientras se prueba desde el editor, ni encima
	 * de una salida (solo se pisa de paso al entrar andando a un mundo).
	 */
	function savePosition()
	{
		if (returnToEditor || curNodeId == null) return;

		var node:OverworldNodeFile = OverworldData.findNode(worldFile, curNodeId);
		if (node == null || node.type == 'exit') return;

		FlxG.save.data.overworldPosition = {world: curWorld, node: curNodeId, stack: [for (entry in worldStack) entry.copy()]};
		FlxG.save.flush();
	}

	/**
	 * Vuelve a la ultima posicion guardada (llamar despues de reset()). false si no hay ninguna
	 * o su mundo ya no existe: entonces se empieza como siempre, en el nodo inicial.
	 */
	public static function restorePosition():Bool
	{
		var pos:Dynamic = FlxG.save.data.overworldPosition;
		if (pos == null || pos.world == null || !OverworldData.exists(pos.world)) return false;

		var stack:Array<Array<String>> = [];
		var saved:Array<Dynamic> = pos.stack;
		if (saved != null)
		{
			for (entry in saved)
			{
				var pair:Array<String> = entry;
				if (pair != null && pair.length > 1 && OverworldData.exists(pair[0])) stack.push([pair[0], pair[1]]);
			}
		}

		curWorld = pos.world;
		curNodeId = pos.node;
		worldStack = stack;
		return true;
	}

	/**
	 * true cuando el menu principal se abrio con ESC desde un mapa: su BACK devuelve a ese mismo
	 * mapa y nodo (con la pila de submundos intacta) en vez de ir a la pantalla de titulo.
	 */
	public static var menuFromMap:Bool = false;

	public static function reset()
	{
		curWorld = OverworldData.DEFAULT_WORLD;
		curNodeId = null;
		fromOverworld = false;
		returnToEditor = false;
		menuFromMap = false;
		lastLevelNode = null;
		pendingReveal = null;
		arrivingFrom = null;
		arrivingByWarp = null;
		worldStack = [];
	}

	/** Mundo del que viene BF por un warp: aqui aparece encima de su pareja. Main lo usa con -warp-from. */
	public static var arrivingByWarp:String = null;

	/** Llamado al terminar una cancion lanzada desde el overworld. */
	public static function completeCurrentNode()
	{
		if (!fromOverworld || lastLevelNode == null) return;

		// repetir un nivel ya superado no abre nada nuevo: solo se anima la primera vez
		if (!OverworldData.isCompleted(curWorld, lastLevelNode)) pendingReveal = [curWorld, lastLevelNode];
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
	var marksGroup:FlxTypedGroup<FlxSprite>;
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

		OverworldData.clearWarpCache(); // las parejas de warp se leen de nuevo en cada mapa
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
		for (problem in OverworldData.checkWorld(worldFile, curWorld)) trace('Overworld "$curWorld": $problem');
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

		// si BF esta entrando andando por una salida, se guarda al llegar al primer nodo
		if (!walking) savePosition();

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

		var size:Array<Float> = tiledMapSize(file, first.width, first.height);
		var columns:Int = Std.int(Math.min(12, Math.round(size[0] / first.width)));
		var rows:Int = Std.int(Math.min(12, Math.round(size[1] / first.height)));

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

	/**
	 * Tamaño del mapa cuando el fondo va en mosaico: lo que ocupan nodos y decorados (y como
	 * minimo un tile), redondeado a tiles enteros. Devuelve [ancho, alto].
	 */
	public static function tiledMapSize(file:OverworldFile, tileWidth:Float, tileHeight:Float):Array<Float>
	{
		var targetWidth:Float = tileWidth;
		var targetHeight:Float = tileHeight;

		for (node in file.nodes)
		{
			// las salidas pueden quedar fuera del mapa a proposito: BF se va andando de la pantalla
			if (node.type == 'exit') continue;
			if (node.x + 32 > targetWidth) targetWidth = node.x + 32;
			if (node.y + 32 > targetHeight) targetHeight = node.y + 32;
		}
		for (spr in file.sprites)
		{
			if (spr.x + 64 > targetWidth) targetWidth = spr.x + 64;
			if (spr.y + 64 > targetHeight) targetHeight = spr.y + 64;
		}

		return [Math.ceil(targetWidth / tileWidth) * tileWidth, Math.ceil(targetHeight / tileHeight) * tileHeight];
	}

	function buildMap()
	{
		var bgWidth:Float = FlxG.width;
		var bgHeight:Float = FlxG.height;

		if (worldFile.bgTile && OverworldData.imageExists(worldFile.bg))
		{
			// Mosaico infinito: si el mapa es mas pequeño que la pantalla, la camara lo centra
			// y el fondo sigue llenando los lados en vez de dejar bandas negras.
			var backdrop:FlxBackdrop = new FlxBackdrop();
			buildSprite(worldFile.bg, worldFile.bgAnim, worldFile.bgFps, true, backdrop);
			add(backdrop);

			var size:Array<Float> = tiledMapSize(worldFile, backdrop.width, backdrop.height);
			bgWidth = size[0];
			bgHeight = size[1];
		}
		else
		{
			var bgTiles:Array<FlxSprite> = buildBackgroundSprites(worldFile);
			for (tile in bgTiles) add(tile);

			if (bgTiles.length > 0)
			{
				var last:FlxSprite = bgTiles[bgTiles.length - 1];
				bgWidth = last.x + last.width;
				bgHeight = last.y + last.height;
			}
		}

		spritesBack = new FlxTypedGroup<FlxSprite>();
		dotsGroup = new FlxTypedGroup<FlxSprite>();
		nodesGroup = new FlxTypedGroup<FlxSprite>();
		spritesFront = new FlxTypedGroup<FlxSprite>();

		marksGroup = new FlxTypedGroup<FlxSprite>();

		add(spritesBack);
		add(dotsGroup);
		add(nodesGroup);
		add(marksGroup);

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

		// antes de dibujar nodos y caminos: un nodo 'world' recien superado cambia los dos
		buildPaths(collectRevealNodes());

		// Los nodos se dibujan siempre, estén o no accesibles: lo que se revela al
		// desbloquear es el camino, igual que en Super Mario World.
		for (node in worldFile.nodes)
		{
			var completed:Bool = OverworldData.isCompleted(curWorld, node.id);
			var hasDoneAnim:Bool = node.animDone != null && node.animDone.length > 0;
			var anim:String = (completed && hasDoneAnim) ? node.animDone : node.anim;

			var spr:FlxSprite = buildSprite(node.image, anim, node.fps);
			spr.setPosition(node.x - spr.width * 0.5, node.y - spr.height * 0.5);
			// una salida sin sprite no se ve: solo se ve el camino que se va de la pantalla
			if (node.type == 'exit' && (node.image == null || node.image.length < 1)) spr.visible = false;
			nodesGroup.add(spr);
			nodeSprites.set(node.id, spr);

			// un nivel superado sin animacion de completado propia lleva un check encima
			if (completed && !hasDoneAnim && OverworldData.canBeCompleted(node))
			{
				var mark:FlxSprite = buildDoneMark();
				mark.setPosition(Math.round(spr.x + spr.width - mark.width * 0.5 - 1), Math.round(spr.y - mark.height * 0.5 + 1));
				marksGroup.add(mark);
			}
		}

		// jugador
		player = new FlxSprite();
		loadPlayerGraphic();
		add(player);
		add(spritesFront);

		// llegando por un warp: BF aparece directamente encima de su pareja
		var warpDoor:OverworldNodeFile = warpArrival();
		if (warpDoor != null) curNodeId = warpDoor.id;

		// llegando por una transicion: BF aparece en la salida de vuelta (fuera de la pantalla)
		var arrival:Array<Dynamic> = arrivalPlan();
		if (arrival != null)
		{
			var door:OverworldNodeFile = arrival[0];
			curNodeId = door.id;
		}

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

		// ...y entra andando hasta el primer nodo en cuanto termina la transicion de pantalla
		if (arrival != null && start != null && start.id == curNodeId)
		{
			walkQueue = arrival[2];
			walkTarget = arrival[1];
			walking = true;
		}

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

		var area:Array<Float> = cameraArea(mapWidth, mapHeight, camGame.zoom);
		camGame.setScrollBoundsRect(area[0], area[1], area[2], area[3]);
	}

	/**
	 * Zona del mundo que la camara puede llegar a enseñar: [x, y, ancho, alto]. Lo que quede fuera
	 * no se ve nunca (ahi van las salidas "fuera de pantalla"). Si el mapa cabe en pantalla por un
	 * eje, ese eje se centra y la zona sobresale del mapa por los dos lados.
	 */
	public static function cameraArea(mapWidth:Float, mapHeight:Float, zoom:Float):Array<Float>
	{
		var viewWidth:Float = FlxG.width / zoom;
		var viewHeight:Float = FlxG.height / zoom;

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

		return [rectX, rectY, rectWidth, rectHeight];
	}

	/**
	 * Tamaño del mapa calculado como lo hace el juego, pero sin crear sprites (para el editor):
	 * el fondo, o con fondo en mosaico, lo que ocupan nodos y decorados en tiles enteros.
	 */
	public static function mapSize(file:OverworldFile):Array<Float>
	{
		if (file.bg == null || file.bg.length < 1 || !OverworldData.imageExists(file.bg)) return [FlxG.width, FlxG.height];

		var info:OverworldImageInfo = OverworldData.imageInfo(file.bg);
		if (file.bgTile) return tiledMapSize(file, info.frameWidth, info.frameHeight);
		return [info.frameWidth, info.frameHeight];
	}

	/**
	 * Dibuja los caminos abiertos. Si se acaba de completar un nivel por primera vez, los caminos
	 * que ha abierto se crean ocultos y prepareReveal() los hace aparecer puntito a puntito.
	 */
	function buildPaths(revealNodes:Array<String>)
	{
		var newPaths:Array<OverworldPathFile> = [];
		for (pth in worldFile.paths)
		{
			if (!isPathOpen(pth)) continue;

			if (revealNodes.length > 0 && !isPathOpen(pth, revealNodes)) newPaths.push(pth);
			else buildPathDots(pth);
		}

		if (newPaths.length > 0) prepareReveal(newPaths, revealNodes);
	}

	/**
	 * Lo que se acaba de superar y cuyos caminos hay que animar: el nivel de la ultima cancion
	 * y los nodos 'world' cuyo mundo ha quedado superado (lo normal: BF acaba de volver de el).
	 */
	function collectRevealNodes():Array<String>
	{
		var result:Array<String> = syncWorldNodes();
		if (pendingReveal != null && pendingReveal[0] == curWorld && !result.contains(pendingReveal[1]))
			result.push(pendingReveal[1]);
		pendingReveal = null;
		return result;
	}

	/** Los mundos por encima del actual en la pila: un nodo que lleve a ellos es una salida. */
	function parentWorlds():Array<String>
		return [for (entry in worldStack) entry[0]];

	/** Marca como superados los nodos 'world' cuyo mundo ya esta completo y devuelve sus ids. */
	function syncWorldNodes():Array<String>
	{
		var chain:Array<String> = parentWorlds().concat([curWorld]);
		var newly:Array<String> = [];
		for (node in worldFile.nodes)
		{
			if (node.type != 'world' || !OverworldData.canBeCompleted(node)) continue;
			if (OverworldData.isCompleted(curWorld, node.id)) continue;
			if (!OverworldData.isWorldCleared(node.world, chain)) continue;

			OverworldData.setCompleted(curWorld, node.id);
			newly.push(node.id);
		}
		return newly;
	}

	/** Un camino se ve (y se puede andar) cuando sus dos extremos estan accesibles. */
	function isPathOpen(pth:OverworldPathFile, ?ignoreCompleted:Array<String>):Bool
	{
		var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
		var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
		if (nodeA == null || nodeB == null) return false;

		return OverworldData.isUnlocked(curWorld, worldFile, nodeA, ignoreCompleted)
			&& OverworldData.isUnlocked(curWorld, worldFile, nodeB, ignoreCompleted);
	}

	/** Crea los puntitos de un camino, de `a` hacia `b`, y los devuelve en ese orden. */
	function buildPathDots(pth:OverworldPathFile, ?hidden:Bool = false):Array<FlxSprite>
	{
		var result:Array<FlxSprite> = [];
		if (pth.dots == null || pth.dots.length < 1) return result;

		var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
		var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
		if (nodeA == null || nodeB == null) return result;

		for (point in getDotPositions(pth, nodeA, nodeB))
		{
			var dot:FlxSprite = buildSprite(pth.dots, pth.dotAnim, 6);
			dot.setPosition(point[0] - dot.width * 0.5, point[1] - dot.height * 0.5);
			dot.visible = !hidden;
			dotsGroup.add(dot);
			result.push(dot);
		}
		return result;
	}

	// ------------------------------------------------------------- revelar caminos
	static inline final REVEAL_DELAY:Float = 0.4;     // pausa al volver al mapa antes de empezar
	static inline final REVEAL_DOT_TIME:Float = 0.07; // segundos entre puntito y puntito

	/** Oleadas de caminos por revelar; cada camino es su lista de puntitos en orden de aparicion. */
	var revealWaves:Array<Array<Array<FlxSprite>>> = [];
	var revealStep:Int = 0;
	var revealTimer:Float = 0;
	var revealing:Bool = false;

	/**
	 * Ordena los caminos nuevos para que crezcan desde lo que ya estaba abierto: primero los que
	 * salen de un nodo accesible, despues los que continuan desde esos, etc. Los caminos de una
	 * misma oleada crecen a la vez (una bifurcacion se abre por los dos lados).
	 */
	function prepareReveal(newPaths:Array<OverworldPathFile>, revealNodes:Array<String>)
	{
		var known:Map<String, Bool> = new Map<String, Bool>();
		for (node in worldFile.nodes)
			if (OverworldData.isUnlocked(curWorld, worldFile, node, revealNodes)) known.set(node.id, true);

		var pending:Array<OverworldPathFile> = newPaths.copy();
		while (pending.length > 0)
		{
			var wave:Array<Array<FlxSprite>> = [];
			var reachedNow:Array<String> = [];

			for (pth in pending.copy())
			{
				var fromA:Bool = known.exists(pth.a);
				if (!fromA && !known.exists(pth.b)) continue;

				pending.remove(pth);
				var dots:Array<FlxSprite> = buildPathDots(pth, true);
				if (!fromA) dots.reverse(); // que crezca desde el extremo que ya estaba abierto
				wave.push(dots);
				reachedNow.push(fromA ? pth.b : pth.a);
			}

			// caminos sin contacto con nada abierto (desbloqueos a distancia): todos a la vez
			if (wave.length < 1)
			{
				for (pth in pending) wave.push(buildPathDots(pth, true));
				pending = [];
			}

			for (id in reachedNow) known.set(id, true);
			revealWaves.push(wave);
		}

		revealing = true;
		revealStep = 0;
		revealTimer = REVEAL_DELAY;
	}

	function updateReveal(elapsed:Float)
	{
		if (controls.ACCEPT || controls.BACK)
		{
			finishReveal(); // saltarse la animacion
			return;
		}

		revealTimer -= elapsed;
		while (revealing && revealTimer <= 0)
		{
			var shown:Bool = false;
			for (dots in revealWaves[0])
			{
				if (revealStep >= dots.length) continue;
				popDot(dots[revealStep]);
				shown = true;
			}

			if (shown)
			{
				revealStep++;
				revealTimer += REVEAL_DOT_TIME;
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
				continue;
			}

			// oleada terminada: la siguiente sale tras una pausa de un puntito
			revealWaves.shift();
			revealStep = 0;
			revealTimer += REVEAL_DOT_TIME;
			if (revealWaves.length < 1) revealing = false;
		}
	}

	function popDot(dot:FlxSprite)
	{
		dot.visible = true;
		dot.scale.set(0.2, 0.2);
		FlxTween.tween(dot.scale, {x: 1, y: 1}, 0.2, {ease: FlxEase.backOut});
	}

	function finishReveal()
	{
		for (wave in revealWaves)
			for (dots in wave)
				for (dot in dots) dot.visible = true;

		revealWaves = [];
		revealing = false;
	}

	// ------------------------------------------------------------- marca de superado
	/** Check verde (G) de 2 px de grosor; el contorno negro se calcula solo. */
	static final DONE_MARK:Array<String> = [
		'......GG',
		'.....GG.',
		'GG..GG..',
		'.GGGG...',
		'..GG....'
	];

	static function buildDoneMark():FlxSprite
	{
		var rows:Array<String> = DONE_MARK;
		inline function isGreen(x:Int, y:Int):Bool
			return y >= 0 && y < rows.length && x >= 0 && x < rows[y].length && rows[y].charAt(x) == 'G';

		var width:Int = rows[0].length + 2;
		var height:Int = rows.length + 2;

		var mark:FlxSprite = new FlxSprite();
		mark.makeGraphic(width, height, FlxColor.TRANSPARENT, true);
		mark.antialiasing = false;

		for (y in 0...height)
		{
			for (x in 0...width)
			{
				var gx:Int = x - 1;
				var gy:Int = y - 1;
				if (isGreen(gx, gy)) mark.pixels.setPixel32(x, y, 0xFF4CD94C);
				else if (isGreen(gx - 1, gy) || isGreen(gx + 1, gy) || isGreen(gx, gy - 1) || isGreen(gx, gy + 1))
					mark.pixels.setPixel32(x, y, FlxColor.BLACK);
			}
		}
		mark.dirty = true;
		return mark;
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
	public static function buildSprite(image:String, anim:String, fps:Int, ?loop:Bool = true, ?target:FlxSprite):FlxSprite
	{
		// `target` permite cargar la imagen en un sprite ya creado (por ejemplo un FlxBackdrop)
		var spr:FlxSprite = target != null ? target : new FlxSprite();
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
		addPlayerAnim('warp', anims, 'warp');

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

		var backHint:String = returnToEditor ? 'BACK: volver al editor' : 'BACK: menu';
		hintTxt = new FlxText(10, FlxG.height - 22, FlxG.width - 20, 'ACCEPT: entrar    $backHint    R: reiniciar este mundo y sus submundos', 14);
		hintTxt.setFormat(Paths.font('vcr.ttf'), 14, 0xFFCCCCCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hintTxt.cameras = [camHUD];
		add(hintTxt);

		// progreso del mundo, a la derecha de la barra
		var count:Array<Int> = OverworldData.levelCount(curWorld, worldFile, parentWorlds());
		if (count[1] > 0)
		{
			var progressTxt:FlxText = new FlxText(10, FlxG.height - 44, FlxG.width - 20, 'Superados: ${count[0]}/${count[1]}', 18);
			progressTxt.setFormat(Paths.font('vcr.ttf'), 18, count[0] >= count[1] ? DONE_COLOR : FlxColor.WHITE, RIGHT,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			progressTxt.cameras = [camHUD];
			add(progressTxt);
		}

		updateNameText();
	}

	static inline final DONE_COLOR:FlxColor = 0xFF66FF66;
	static final DONE_MARKUP:Array<FlxTextFormatMarkerPair> = [new FlxTextFormatMarkerPair(new FlxTextFormat(DONE_COLOR), '<g>')];

	// ------------------------------------------------------------- bucle
	override function update(elapsed:Float)
	{
		if (worldFile == null)
		{
			super.update(elapsed);
			return;
		}

		if (revealing) updateReveal(elapsed);
		else if (walking) updateWalk(elapsed);
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
			// tambien los submundos: si no, un submundo ya superado volveria a marcar su nodo al momento
			for (world in OverworldData.worldTree(curWorld, parentWorlds())) OverworldData.resetProgress(world);
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

	/**
	 * ESC nunca saca de un submundo (para eso estan los nodos 'exit'): abre el menu principal,
	 * y al salir de el se vuelve a este mismo sitio. Probando desde el editor, vuelve al editor.
	 */
	function goBack()
	{
		if (returnToEditor)
		{
			// el editor tenia abierto el mundo de la base de la pila, no el submundo actual
			var edited:String = worldStack.length > 0 ? worldStack[0][0] : curWorld;
			returnToEditor = false;
			worldStack = [];
			MusicBeatState.switchState(new states.editors.OverworldEditorState(edited));
			return;
		}

		menuFromMap = true;
		MusicBeatState.switchState(new MainMenuState());
	}

	/**
	 * BF ha llegado a un nodo 'exit'.
	 * - Con "Mundo destino": pasa a ese mundo de lado (una transicion, no un submundo: la pila no
	 *   cambia) y alli entra andando desde la salida que apunta de vuelta a este.
	 * - Sin destino: vuelve al mapa del que se entro a este submundo, encima de su nodo 'world'.
	 */
	function leaveWorld(exit:OverworldNodeFile)
	{
		busy = true;

		if (exit.world != null && exit.world.length > 0)
		{
			if (!OverworldData.exists(exit.world))
			{
				failExit('Esta salida lleva a "${exit.world}", que no existe');
				return;
			}

			arrivingFrom = curWorld;
			curWorld = exit.world;
			curNodeId = null;
			MusicBeatState.switchState(new OverworldState());
			return;
		}

		var target:Array<String> = worldStack.length > 0 ? worldStack.pop() : OverworldData.findParentWorld(curWorld);
		if (target == null)
		{
			failExit('Esta salida no lleva a ningun mapa:\nponle un "Mundo destino" o haz que un nodo "world" lleve aqui');
			return;
		}

		// si se llego aqui de lado desde otro submundo, la puerta correcta es la que lleva a este
		var parentFile:OverworldFile = OverworldData.load(target[0]);
		var door:OverworldNodeFile = parentFile == null ? null : Lambda.find(parentFile.nodes, n -> n.type == 'world' && n.world == curWorld);

		curWorld = target[0];
		curNodeId = door != null ? door.id : target[1];
		MusicBeatState.switchState(new OverworldState());
	}

	function failExit(message:String)
	{
		busy = false;
		FlxG.sound.play(Paths.sound('cancelMenu'));
		showError(message);
	}

	/**
	 * Al llegar por una transicion desde `arrivingFrom`, BF aparece en la salida de este mundo que
	 * apunta de vuelta y entra andando por su camino hasta el primer nodo. Devuelve el plan
	 * [salida, nodo al que llega, linea a recorrer], o null si no hay por donde entrar (entonces
	 * BF aparece en el nodo inicial de siempre).
	 */
	function arrivalPlan():Array<Dynamic>
	{
		var from:String = arrivingFrom;
		arrivingFrom = null;
		if (from == null) return null;

		for (door in worldFile.nodes)
		{
			if (door.type != 'exit' || door.world != from || !OverworldData.isUnlocked(curWorld, worldFile, door)) continue;

			for (pth in worldFile.paths)
			{
				if (pth.a != door.id && pth.b != door.id) continue;

				var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
				var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
				if (nodeA == null || nodeB == null || nodeA == nodeB) continue;

				var other:OverworldNodeFile = (pth.a == door.id) ? nodeB : nodeA;
				if (other.type == 'exit' || !OverworldData.isUnlocked(curWorld, worldFile, other)) continue;

				var line:Array<Array<Float>> = buildLine(pth, nodeA, nodeB);
				if (pth.b == door.id) line.reverse();
				line.shift();
				return [door, other, line];
			}
		}
		return null;
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
			var arrived:OverworldNodeFile = walkTarget;
			if (arrived != null) curNodeId = arrived.id;
			walkTarget = null;
			idleAnim();

			if (arrived != null && arrived.type == 'exit')
			{
				leaveWorld(arrived);
				return;
			}

			savePosition();
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

	/** Parado en un nodo, BF mira a camara y camina en el sitio, como Mario en el mapa de SMW. */
	function idleAnim()
	{
		facing = 'down';
		playAnim('walk_down');
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

		// BF solo pisa una salida al entrar andando por ella: su nombre confundiria ("Hacia X" viniendo de X)
		if (node.type == 'exit')
		{
			nameTxt.text = '';
			return;
		}

		var text:String = node.name != null && node.name.length > 0 ? node.name : node.id;
		if (node.type == 'world') text += '  >>';
		if (node.type == 'warp') text += '  (ENTER: viajar)';
		if (OverworldData.canBeCompleted(node) && OverworldData.isCompleted(curWorld, node.id)) text += '  <g>SUPERADO<g>';

		nameTxt.applyMarkup(text, DONE_MARKUP);
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

			case 'warp':
				warpTo(node);

			default:
				FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	/**
	 * Warp (con ENTER): como una tuberia. BF desaparece con su animacion "warp" y aparece encima
	 * del warp del otro mundo que apunta de vuelta a este (o en su nodo inicial si no hay). Es un
	 * paso de lado, no un submundo: la pila no cambia.
	 */
	function warpTo(node:OverworldNodeFile)
	{
		if (node.world == null || node.world.length < 1 || !OverworldData.exists(node.world))
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			showError('Este warp no lleva a ningun mundo');
			return;
		}

		busy = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		playAnim('warp');

		var from:String = curWorld;
		var target:String = node.world;
		new FlxTimer().start(0.5, function(_:FlxTimer)
		{
			arrivingByWarp = from;
			curWorld = target;
			curNodeId = null;
			MusicBeatState.switchState(new OverworldState());
		});
	}

	/** Llegando por un warp: el warp de este mundo que apunta de vuelta (su pareja), o null. */
	function warpArrival():OverworldNodeFile
	{
		var from:String = arrivingByWarp;
		arrivingByWarp = null;
		if (from == null) return null;

		for (node in worldFile.nodes)
			if (node.type == 'warp' && node.world == from && OverworldData.isUnlocked(curWorld, worldFile, node)) return node;
		return null;
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
