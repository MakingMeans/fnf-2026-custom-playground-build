package states;

import backend.OverworldData;
import backend.OverworldTerrain;
import backend.Song;
import backend.Highscore;
import backend.WeekData;

import flixel.FlxObject;
import flixel.addons.display.FlxBackdrop;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText.FlxTextFormat;
import flixel.text.FlxText.FlxTextFormatMarkerPair;
import shaders.IrisShader;

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

	/** El mundo que estaba abierto en el editor al pulsar CTRL+T: BACK vuelve a el. */
	public static var editorWorld:String = null;

	/**
	 * "Probar desde aqui" del editor: BF aparece en ese nodo aunque con la partida actual aun este
	 * cerrado (solo probando desde el editor).
	 */
	public static var testStartWorld:String = null;
	public static var testStartNode:String = null;

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
	/** R: reinicia el progreso de este mundo y de sus submundos (no el de los mapas de los que vienes). */
	function resetWorldProgress()
	{
		// tambien los submundos: si no, un submundo ya superado volveria a marcar su nodo al momento
		for (world in OverworldData.worldTree(curWorld, parentWorlds()))
		{
			OverworldData.resetProgress(world);
			// y como nuevo del todo: fuera las llaves que abren algo aqui (la de Bad Day vuelve a salir en la
			// cancion) y Gaster vuelve a saludar como la primera vez. La EXP no se toca (no se vuelve a dar)
			var file:OverworldFile = OverworldData.loadCached(world);
			if (file == null) continue;
			for (node in file.nodes)
			{
				if (node.key != null && node.key.length > 0) OverworldData.takeKey(node.key);
				if (node.type == 'shop' && node.shop != null && node.shop.length > 0) GasterShopState.forgetVisit(node.shop);
			}
		}
		sfx(SFX_BACK);
		// switchState y no resetState: el primer mapa lo crea Main con los argumentos de arranque,
		// y resetState los volveria a aplicar (-from, -warp-from o la posicion guardada)
		MusicBeatState.switchState(new OverworldState());
	}

	/** Momento del primer R: el progreso solo se borra si se vuelve a pulsar enseguida. */
	var resetAskedAt:Float = -100;

	// Sonidos del mapa: los del mapa de Mario's Madness (los copia tools/build_world1.py)
	static inline final SFX_MOVE:String = 'overworld/move';     // BF llega a un nodo
	static inline final SFX_UNLOCK:String = 'overworld/unlock'; // se abre un camino
	static inline final SFX_ENTER:String = 'overworld/enter';   // entrar a un nivel o a un castillo
	static inline final SFX_WRONG:String = 'overworld/wrong';   // no se puede: cerrado o sin destino
	static inline final SFX_BACK:String = 'overworld/back';     // salir del mapa

	static inline function sfx(key:String, ?volume:Float = 1)
		FlxG.sound.play(Paths.sound(key), volume);

	function savePosition()
	{
		if (returnToEditor || curNodeId == null) return;
		#if debug
		// la prueba automatica y las capturas (-shot) no pisan la posicion de la partida
		if (OverworldPlaytest.running || Sys.args().contains('-shot')) return;
		#end

		// un nodo cerrado no se guarda: al volver, BF apareceria en un mapa sin sitio donde estar
		var node:OverworldNodeFile = OverworldData.findNode(worldFile, curNodeId);
		if (node == null || node.type == 'exit' || !OverworldData.isUnlocked(curWorld, worldFile, node)) return;

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
		OverworldData.clearWorldCache(); // empieza una partida: los mundos se leen de nuevo
		clearSpriteCache();
		curWorld = OverworldData.DEFAULT_WORLD;
		curNodeId = null;
		fromOverworld = false;
		returnToEditor = false;
		menuFromMap = false;
		lastLevelNode = null;
		pendingReveal = null;
		arrivingFrom = null;
		arrivingByWarp = null;
		editorWorld = null;
		testStartWorld = null;
		testStartNode = null;
		worldStack = [];
	}

	/** Mundo del que viene BF por un warp: aqui aparece encima de su pareja. Main lo usa con -warp-from. */
	public static var arrivingByWarp:String = null;

	/**
	 * Llamado al terminar una cancion lanzada desde el overworld. Con `misses` y `accuracy` (0-1) de
	 * la partida se mira tambien la salida secreta del nivel (sin fallos o con precision minima).
	 */
	/** Marca el nivel jugado como superado. Devuelve la EXP ganada: solo la primera vez que se supera (0 si no). */
	public static function completeCurrentNode(?misses:Int = -1, ?accuracy:Float = 0):Int
	{
		if (!fromOverworld || lastLevelNode == null) return 0;

		var firstTime:Bool = !OverworldData.isCompleted(curWorld, lastLevelNode);
		OverworldData.setCompleted(curWorld, lastLevelNode);

		var file:OverworldFile = OverworldData.loadCached(curWorld);
		var node:OverworldNodeFile = OverworldData.findNode(file, lastLevelNode);
		var secretNow:Bool = misses >= 0 && node != null && OverworldData.hasSecret(file, node)
			&& !OverworldData.isSecretCompleted(curWorld, node.id) && OverworldData.secretAchieved(node, misses, accuracy, songSecret);
		if (secretNow)
		{
			OverworldData.setCompleted(curWorld, node.id + OverworldData.SECRET);
			secretMessage = true;
		}

		// repetir un nivel ya superado no abre nada nuevo: solo se anima la primera vez (o la
		// primera vez que se saca su salida secreta, y entonces solo lo que abre ella)
		if (firstTime) pendingReveal = [curWorld, lastLevelNode];
		else if (secretNow) pendingReveal = [curWorld, lastLevelNode + OverworldData.SECRET];

		// EXP (la moneda de las tiendas de Gaster): una vez por nivel, aunque luego se reinicie el mundo con R
		return (firstTime && node != null && node.type == 'level') ? OverworldData.awardLevelXP(curWorld, node.id) : 0;
	}

	/** Al volver al mapa se avisa de que se acaba de sacar una salida secreta. */
	static var secretMessage:Bool = false;

	/**
	 * Salida secreta en modo 'song': la pone a true la cancion (su escenario) cuando el jugador la
	 * consigue, p. ej. chaos al reunir las 7 esmeraldas. PlayState la vuelve a false al empezar.
	 */
	public static var songSecret:Bool = false;

	/** Llaves recogidas en la cancion que se esta jugando (p. ej. la de Bad Day): se dan al acabarla. */
	public static var songKeys:Array<String> = [];

	/**
	 * Vuelve al mapa (usado por PlayState, pausa y game over): el mapa se abre con el iris y pone su
	 * propia musica. Quien llama NO debe poner la del menu despues (sonaba unos segundos, mientras
	 * se cargaba el mapa).
	 */
	public static function backToOverworld()
	{
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		fromOverworld = false;
		irisOpenNext = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.switchState(new OverworldState());
	}

	/** El siguiente mapa se abre con el iris desde BF en vez del fundido de Psych. */
	public static var irisOpenNext:Bool = false;
	/** El siguiente mapa se abre con el fundido a saltos de SMW (despues de viajar en una estrella). */
	public static var fadeOpenNext:Bool = false;

	// ------------------------------------------------------------- construccion
	var worldFile:OverworldFile;

	var camGame:FlxCamera;
	var camHUD:FlxCamera;
	var camFollow:FlxObject;

	var spritesBack:FlxTypedGroup<FlxSprite>;
	var roadsGroup:FlxTypedGroup<FlxSprite>;
	var dotsGroup:FlxTypedGroup<FlxSprite>;
	var nodesGroup:FlxTypedGroup<FlxSprite>;
	var marksGroup:FlxTypedGroup<FlxSprite>;
	var spritesFront:FlxTypedGroup<FlxSprite>;

	// ---------------------------------------------------------------- orden por altura (eje Y)
	/** Lo que se ordena por altura: caminos, puntitos, nodos, decorados "por altura" y BF (sortDepth). */
	var depthGroup:FlxTypedGroup<FlxSprite>;
	/** Los decorados "por altura" (OverworldData.depthOf) y su base (la de toda su pieza, si son de una). */
	var sortedDecor:Array<FlxSprite> = [];
	var decorKeys:Map<FlxSprite, Float> = new Map<FlxSprite, Float>();
	var pieceOf:Map<FlxSprite, String> = new Map<FlxSprite, String>();
	/** Nodos que van encima de los decorados (OverworldData.isOverlayNodeImage: el vacio de la tienda). */
	var overlayNodes:Array<FlxSprite> = [];

	static inline final OVERLAY_KEY:Float = 1e6;
	/** Un nodo gana a los trozos de camino que lo tocan (estan en el suelo, el nodo encima). */
	static inline final NODE_BIAS:Float = 6;

	/**
	 * Ordena depthGroup por la base de cada cosa: lo de mas abajo en el mapa se dibuja despues y tapa a lo de mas
	 * arriba (BF pasa por detras de un monticulo si va por encima de el y por delante si va por debajo). Los
	 * caminos cuentan por su centro, los nodos por su base (+NODE_BIAS) y BF por sus pies; encima de un nodo, BF
	 * siempre por delante de el. Lo marcado "delante" va aparte, encima de todo.
	 */
	function sortDepth()
	{
		var items:Array<FlxSprite> = [];
		var keys:Map<FlxSprite, Float> = new Map<FlxSprite, Float>();
		inline function put(spr:FlxSprite, key:Float)
		{
			if (spr == null || !spr.exists) return;
			items.push(spr);
			keys.set(spr, key);
		}
		for (spr in sortedDecor) put(spr, decorKeys.get(spr));
		for (spr in roadsGroup.members) if (spr != null) put(spr, spr.y + spr.height * 0.5);
		for (spr in dotsGroup.members) if (spr != null) put(spr, spr.y + spr.height * 0.5);
		for (spr in nodesGroup.members)
			if (spr != null) put(spr, overlayNodes.contains(spr) ? OVERLAY_KEY : spr.y + spr.height + NODE_BIAS);
		if (player != null)
		{
			var feet:Float = player.y + player.height;
			for (spr in nodesGroup.members)
				if (spr != null && spr.visible && keys.exists(spr) && playerX >= spr.x && playerX < spr.x + spr.width
					&& playerY >= spr.y && playerY < spr.y + spr.height)
					feet = Math.max(feet, keys.get(spr) + 0.5);
			put(player, feet);
		}
		haxe.ds.ArraySort.sort(items, function(a:FlxSprite, b:FlxSprite):Int
		{
			var ka:Float = keys.get(a);
			var kb:Float = keys.get(b);
			return ka < kb ? -1 : (ka > kb ? 1 : 0);
		});
		// sin add(): con cientos de trozos de camino, add() busca repetidos en cada uno y en cada fotograma
		@:privateAccess
		{
			depthGroup.members = items;
			depthGroup.length = items.length;
		}
	}

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
	/** Como recorre BF el camino por el que va: 'walk', 'swim' o 'climb' (campo `move` del camino). */
	var walkMove:String = 'walk';
	/** El camino por el que va es una carretera: anda, trepa o nada segun el terreno que pisa. */
	var walkRoad:Bool = false;
	/** Lo que hay bajo cada pixel del mapa (ver OverworldTerrain); vacio en un mapa sin tiles. */
	var terrain:OverworldTerrain;
	/** El nodo del que salio BF en su ultimo paseo (para volver de una salida que aun no lleva a nada). */
	var walkFrom:String = null;
	/** Camino recien abierto por el que BF ira solo cuando acabe de revelarse (ver buildPaths). */
	var autoWalkPath:OverworldPathFile = null;

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

		// la pila nunca puede contener el mapa actual (p. ej. una partida guardada con una pila
		// corrupta de versiones anteriores): se recorta desde donde aparezca
		var self:Int = stackIndexOf(curWorld);
		if (self > -1) worldStack = worldStack.slice(0, self);

		// de cache: los archivos solo cambian al guardar en el editor (que la vacia), y un mundo
		// pintado tarda en leerse cada vez que BF vuelve de una cancion
		worldFile = OverworldData.loadCached(curWorld);
		if (worldFile != null && !returnToEditor) escapeClosedWorld();
		if (worldFile == null)
		{
			irisOpenNext = false;
			fadeOpenNext = false;
			FlxTransitionableState.skipNextTransOut = false;
			var msg:String = 'COULD NOT LOAD WORLD "$curWorld"\n\nassets/shared/overworlds/$curWorld.json\n\nACCEPT: open the world editor\nBACK: main menu';
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
		buildIris();

		// si BF esta entrando andando por una salida, se guarda al llegar al primer nodo
		if (!walking) savePosition();

		camGame.zoom = worldFile.zoom;
		// dibujo ajustado al pixel: con la camara en una posicion fraccionaria, entre tile y tile
		// pintado se veian rayitas del fondo
		camGame.pixelPerfectRender = true;
		applyCameraBounds();
		camGame.follow(camFollow, LOCKON, 0.12);
		camGame.snapToTarget();

		// Llegando por un warp: de una estrella BF baja volando mientras se abre la pantalla; de una
		// tuberia sale con la pantalla ya abierta
		var entrance:Void->Void = null;
		if (warpEntrance == 'star') starArrival();
		else if (warpEntrance == 'pipe') entrance = pipeArrival;

		if (fadeOpenNext)
		{
			fadeOpenNext = false;
			irisOpenNext = false;
			fadeOpen(entrance);
			if (revealing) revealTimer += FADE_STEPS * FADE_STEP_TIME;
		}
		else if (irisOpenNext)
		{
			irisOpenNext = false;
			irisOpen(entrance);
			if (revealing) revealTimer += IRIS_OPEN_TIME; // los caminos nuevos salen con el iris ya abierto
		}
		else if (entrance != null) entrance();

		if (secretMessage)
		{
			secretMessage = false;
			showError('Secret exit!', 0xFFFFD84A);
		}

		if (worldFile.music != null && worldFile.music.length > 0)
		{
			// se sigue con la que suena solo si es de verdad la del mapa: el menu, Freeplay o el
			// menu de editores la cambian o la bajan a 0 sin que este mapa se entere
			var current:FlxSound = FlxG.sound.music;
			var same:Bool = lastMusic == worldFile.music && current != null && current.playing
				&& lastMusicSound != null && @:privateAccess current._sound == lastMusicSound;
			if (!same)
			{
				FlxG.sound.playMusic(Paths.music(worldFile.music));
				lastMusic = worldFile.music;
				lastMusicSound = @:privateAccess FlxG.sound.music._sound;
			}
			FlxG.sound.music.volume = 1;
		}

		super.create();
	}

	static var lastMusicSound:openfl.media.Sound = null;

	/**
	 * Un mapa sin ningun nodo abierto dejaria a BF atrapado para siempre (p. ej. la posicion
	 * guardada en el mundo central despues de reiniciar el mundo que abria su tuberia): se vuelve
	 * al mapa de fuera o, si no hay, al mundo por defecto. Probando desde el editor no, alli se
	 * quiere ver el aviso.
	 */
	function escapeClosedWorld()
	{
		var tries:Int = 0;
		while (worldFile != null && !Lambda.exists(worldFile.nodes, n -> OverworldData.isUnlocked(curWorld, worldFile, n)) && tries++ < 8)
		{
			if (worldStack.length > 0)
			{
				var parent:Array<String> = worldStack.pop();
				curWorld = parent[0];
				curNodeId = parent[1];
			}
			else if (curWorld != OverworldData.DEFAULT_WORLD && OverworldData.exists(OverworldData.DEFAULT_WORLD))
			{
				curWorld = OverworldData.DEFAULT_WORLD;
				curNodeId = null;
			}
			else return;

			arrivingFrom = null;
			arrivingByWarp = null;
			worldFile = OverworldData.loadCached(curWorld);
		}
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
			// lo que ocupa el dibujo: su fotograma por la escala (64 si la imagen no se puede leer).
			// Antes se suponian siempre 64 px, y un mapa de tiles de 8 pintado hasta el borde crecia
			// un fondo entero de mar vacio por la derecha y por abajo
			var info:OverworldImageInfo = (spr.image != null && spr.image.length > 0) ? OverworldData.imageInfo(spr.image) : null;
			var scale:Float = spr.scale > 0 ? spr.scale : 1;
			var right:Float = spr.x + ((info != null && info.frameWidth > 0) ? info.frameWidth * scale : 64);
			var bottom:Float = spr.y + ((info != null && info.frameHeight > 0) ? info.frameHeight * scale : 64);
			if (right > targetWidth) targetWidth = right;
			if (bottom > targetHeight) targetHeight = bottom;
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
		roadsGroup = new FlxTypedGroup<FlxSprite>();
		dotsGroup = new FlxTypedGroup<FlxSprite>();
		nodesGroup = new FlxTypedGroup<FlxSprite>();
		spritesFront = new FlxTypedGroup<FlxSprite>();

		marksGroup = new FlxTypedGroup<FlxSprite>();
		depthGroup = new FlxTypedGroup<FlxSprite>();
		sortedDecor = [];
		decorKeys = new Map<FlxSprite, Float>();
		overlayNodes = [];

		// el suelo (tiles del terreno) debajo de todo; luego, ordenado por altura cada fotograma (sortDepth), lo
		// que se tapa entre si: caminos, puntitos, nodos, los decorados "por altura" y BF. roadsGroup, dotsGroup y
		// nodesGroup no se anaden: solo los guardan (y depthGroup los dibuja y actualiza una vez)
		add(spritesBack);
		add(depthGroup);
		add(marksGroup);

		var terrainSprites:Array<FlxSprite> = [];
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

			switch (OverworldData.depthOf(data))
			{
				case 'front': spritesFront.add(spr);
				case 'ground': spritesBack.add(spr);
				default:
					sortedDecor.push(spr);
					decorKeys.set(spr, spr.y + spr.height);
					if (data.piece != null && data.piece.length > 0) pieceOf.set(spr, data.piece);
			}
			if (!data.front && OverworldData.isLooseTile(data)) terrainSprites.push(spr);
		}
		// una pieza (una montana hecha de tiles...) se ordena entera, por la base de su trozo mas bajo
		var pieceBottom:Map<String, Float> = new Map<String, Float>();
		for (spr => piece in pieceOf)
			pieceBottom.set(piece, Math.max(pieceBottom.exists(piece) ? pieceBottom.get(piece) : -1e9, decorKeys.get(spr)));
		for (spr => piece in pieceOf) decorKeys.set(spr, pieceBottom.get(piece));
		// lo que hay bajo cada pixel (suelo, acantilado, agua), antes de juntar los tiles en imagenes
		terrain = new OverworldTerrain(terrainSprites);
		bakeStillSprites(spritesBack);
		bakeStillSprites(spritesFront);

		// antes de dibujar nodos y caminos: un nodo 'world' recien superado cambia los dos
		revealList = collectRevealNodes();
		buildPaths(revealList);

		// Los nodos se dibujan siempre, estén o no accesibles: lo que se revela al
		// desbloquear es el camino, igual que en Super Mario World.
		for (node in worldFile.nodes)
		{
			var completed:Bool = OverworldData.isCompleted(curWorld, node.id);
			var hasDoneAnim:Bool = node.animDone != null && node.animDone.length > 0;
			// una puerta que se acaba de abrir sale cerrada y hace su animacion 'unlock' (si su imagen la tiene)
			var opening:Bool = hasDoneAnim && doorsOpening.contains(node.id) && hasUnlockAnim(node.image);
			var onArrival:Bool = false;
			if (OverworldData.isKeyed(node))
			{
				// un nodo con llave se ve abierto (animDone) cuando, ademas de tener la llave, ya se ve un camino
				// hasta el; si eso pasa ahora, hace 'unlock' cuando el camino que se revela llega a el
				var before:Bool = keyedOpen(node, revealList);
				var now:Bool = keyedOpen(node, null);
				opening = hasDoneAnim && now && !before && hasUnlockAnim(node.image);
				onArrival = opening;
				completed = before || (now && !opening);
			}
			var anim:String = (completed && hasDoneAnim && !opening) ? node.animDone : node.anim;

			var spr:FlxSprite = buildSprite(node.image, anim, node.fps);
			placeNodeSprite(spr, node);
			// un nodo sin sprite no se ve (una salida fuera de la pantalla, un cruce de caminos): solo su camino
			if (node.image == null || node.image.length < 1) spr.visible = false;
			nodesGroup.add(spr);
			nodeSprites.set(node.id, spr);
			if (OverworldData.isOverlayNodeImage(node.image)) overlayNodes.push(spr);
			if (opening) doorUnlocks.push({sprite: spr, node: node, onArrival: onArrival});
			// un nivel superado sin animDone se queda igual, como en SMW (el usuario no quiere
			// marcas encima): lo dicen los caminos abiertos y el HUD (SUPERADO)
		}
		// nada que revelar: se abren en cuanto se abre el iris (si no, la animacion pasaria sin verse)
		if (!revealing && doorUnlocks.length > 0)
			new FlxTimer().start(IRIS_OPEN_TIME + REVEAL_DELAY, function(_) playDoorUnlocks(true));

		// jugador
		player = new FlxSprite();
		loadPlayerGraphic();
		add(spritesFront);

		// llegando por un warp: BF aparece encima de su pareja (ver starArrival / pipeArrival)
		var warpDoor:OverworldNodeFile = warpArrival();
		if (warpDoor != null)
		{
			curNodeId = warpDoor.id;
			warpEntrance = OverworldData.isStarWarp(warpDoor) ? 'star' : 'pipe';
		}

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
			errorTxt = new FlxText(0, 0, FlxG.width, 'This world has no unlocked nodes', 20);
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
		sortDepth();
		// sale con su animacion al abrirse la pantalla (si no, se le veria de pie antes de tiempo)
		if (warpEntrance != null && start != null && start.id == warpDoor.id) player.visible = false;
		else warpEntrance = null;

		// ...y entra andando hasta el primer nodo en cuanto termina la transicion de pantalla
		if (arrival != null && start != null && start.id == curNodeId)
		{
			walkQueue = arrival[2];
			walkTarget = arrival[1];
			var arrivalTarget:OverworldNodeFile = arrival[1];
			var arrivalPath:OverworldPathFile = pathBetween(curNodeId, arrivalTarget == null ? null : arrivalTarget.id);
			walkMove = arrivalPath != null ? arrivalPath.move : 'walk';
			walkRoad = arrivalPath != null && arrivalPath.road;
			walking = true;
		}

		camFollow = new FlxObject(playerX, playerY, 1, 1);
		add(camFollow);

		mapWidth = bgWidth;
		mapHeight = bgHeight;
	}

	/** Tramos de menos decorados quietos que esto se quedan como sprites sueltos. */
	static inline final BAKE_MIN:Int = 8;

	/**
	 * Junta en una sola imagen cada tramo seguido de decorados quietos (un fotograma, sin escala,
	 * giro ni transparencia: los tiles pintados). Un mapa pintado entero son miles de sprites de 8x8
	 * y actualizarlos y dibujarlos uno a uno bajaba los FPS. Los animados se quedan como sprites
	 * entre los tramos, asi que el orden de dibujo no cambia. Solo en el juego: el editor necesita
	 * los sprites sueltos para editarlos.
	 */
	/** Cuanto se suben las tuberias, castillos y estrellas: BF tapa la mitad de arriba de su dibujo, y asi el
	 * medio de lo que se ve queda en sus pies (en el centro del nodo). */
	public static inline final STAND_ON_RAISE:Float = 3;

	/**
	 * Pone el sprite de un nodo en su sitio: centrado en el nodo. Las tuberias, castillos y estrellas (BF se
	 * pone encima, como en SMW) van con su cuerpo, sin la sombra negra de la derecha, centrado bajo BF y
	 * STAND_ON_RAISE px mas arriba (15/11/2026, a peticion del usuario). Lo usan el juego y el editor.
	 */
	public static function placeNodeSprite(spr:FlxSprite, node:OverworldNodeFile)
	{
		var x:Float = node.x - spr.width * 0.5;
		var y:Float = node.y - spr.height * 0.5;
		if (isStandOnImage(node.image))
		{
			x += bodyShiftX(spr);
			y -= STAND_ON_RAISE;
		}
		spr.setPosition(x, y);
	}

	/** Las imagenes de nodo sobre las que BF se pone de pie: tuberias, castillos, fortalezas, casas, interruptores,
	 * estrellas y puertas (las de overworld/ y las de SMW de overworld/nodes/). */
	public static function isStandOnImage(image:String):Bool
	{
		if (image == null) return false;
		var lower:String = image.toLowerCase();
		for (word in ['pipe', 'castle', 'fortress', 'house', 'switch', 'star', 'door'])
			if (lower.indexOf(word) > -1) return true;
		return false;
	}

	static var bodyShiftCache:Map<String, Float> = new Map<String, Float>();

	/**
	 * Cuanto hay que mover en horizontal el sprite para que el objeto en si (lo opaco que no es casi negro: sin
	 * la sombra de la derecha) quede centrado en el nodo, bajo BF. Se calcula una vez por fotograma.
	 */
	static function bodyShiftX(spr:FlxSprite):Float
	{
		if (spr.frame == null || spr.frame.parent == null) return 0;
		var key:String = spr.frame.parent.key + ':' + spr.frame.name;
		if (bodyShiftCache.exists(key)) return bodyShiftCache.get(key);

		var pixels:openfl.display.BitmapData = spr.updateFramePixels();
		var minX:Int = pixels.width;
		var maxX:Int = -1;
		for (py in 0...pixels.height)
			for (px in 0...pixels.width)
			{
				var argb:Int = pixels.getPixel32(px, py);
				var bright:Int = Std.int(Math.max(Math.max((argb >> 16) & 0xFF, (argb >> 8) & 0xFF), argb & 0xFF));
				if (((argb >>> 24) & 0xFF) >= 128 && bright >= 60)
				{
					if (px < minX) minX = px;
					if (px > maxX) maxX = px;
				}
			}
		var shift:Float = maxX < 0 ? 0 : Math.round(spr.frameWidth * 0.5 - (minX + maxX + 1) * 0.5);
		bodyShiftCache.set(key, shift);
		return shift;
	}

	override function destroy()
	{
		if (terrain != null) terrain.destroy();
		terrain = null;
		super.destroy();
	}

	static function bakeStillSprites(group:FlxTypedGroup<FlxSprite>)
	{
		var result:Array<FlxSprite> = [];
		var run:Array<FlxSprite> = [];

		function flush()
		{
			if (run.length >= BAKE_MIN)
			{
				result.push(bakeRun(run));
				for (spr in run) spr.destroy();
			}
			else
				for (spr in run) result.push(spr);
			run = [];
		}

		for (spr in group.members)
		{
			if (spr == null) continue;
			if (isStill(spr)) run.push(spr);
			else
			{
				flush();
				result.push(spr);
			}
		}
		flush();

		group.clear();
		for (spr in result) group.add(spr);
	}

	static function isStill(spr:FlxSprite):Bool
	{
		if (spr.frame == null || spr.frame.angle != FlxFrameAngle.ANGLE_0) return false;
		if (spr.alpha != 1 || spr.scale.x != 1 || spr.scale.y != 1 || spr.angle != 0) return false;
		return spr.animation.curAnim == null || spr.animation.curAnim.numFrames < 2;
	}

	static function bakeRun(run:Array<FlxSprite>):FlxSprite
	{
		var minX:Float = Math.POSITIVE_INFINITY;
		var minY:Float = Math.POSITIVE_INFINITY;
		var maxX:Float = Math.NEGATIVE_INFINITY;
		var maxY:Float = Math.NEGATIVE_INFINITY;
		for (spr in run)
		{
			minX = Math.min(minX, Math.floor(spr.x));
			minY = Math.min(minY, Math.floor(spr.y));
			maxX = Math.max(maxX, spr.x + spr.frameWidth);
			maxY = Math.max(maxY, spr.y + spr.frameHeight);
		}

		var bitmap:openfl.display.BitmapData = new openfl.display.BitmapData(Math.ceil(maxX - minX), Math.ceil(maxY - minY), true, 0);
		var point:openfl.geom.Point = new openfl.geom.Point();
		for (spr in run)
		{
			point.setTo(Math.floor(spr.x) - minX, Math.floor(spr.y) - minY);
			if (spr.flipX || spr.flipY) spr.frame.paintRotatedAndFlipped(bitmap, point, FlxFrameAngle.ANGLE_0, spr.flipX, spr.flipY, true);
			else spr.frame.paint(bitmap, point, true);
		}

		// sin cache: es de este mapa y se libera con el sprite al salir
		var baked:FlxSprite = new FlxSprite(minX, minY);
		baked.loadGraphic(flixel.graphics.FlxGraphic.fromBitmapData(bitmap, false, null, false));
		baked.antialiasing = false;
		return baked;
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

		if (newPaths.length > 0)
		{
			prepareReveal(newPaths, revealNodes);
			autoWalkPath = pickAutoWalk(newPaths);
		}
	}

	/**
	 * Al superar un nivel, BF va solo por el camino que se acaba de abrir desde el (como en Mario's
	 * Madness). Si se abren varios, el de su salida normal antes que el de la secreta.
	 */
	function pickAutoWalk(newPaths:Array<OverworldPathFile>):OverworldPathFile
	{
		var here:OverworldNodeFile = OverworldData.findNode(worldFile, curNodeId);
		if (here == null) return null;

		var best:OverworldPathFile = null;
		var bestRank:Int = 99;
		for (pth in newPaths)
		{
			if (pth.a != here.id && pth.b != here.id) continue;
			var other:String = pth.a == here.id ? pth.b : pth.a;
			var otherNode:OverworldNodeFile = OverworldData.findNode(worldFile, other);
			if (otherNode == null || otherNode.type == 'exit') continue; // una salida se coge a mano
			var rank:Int = here.unlocks.contains(other) ? 0 : (here.secretUnlocks.contains(other) ? 1 : 2);
			if (rank < bestRank)
			{
				bestRank = rank;
				best = pth;
			}
		}
		return best;
	}

	/** El paseo automatico tras superar un nivel (la prueba jugable lo apaga salvo en su paso propio). */
	public static var autoWalk:Bool = true;

	/** Lanza el paseo automatico pendiente (al acabar de revelarse los caminos nuevos). */
	function startAutoWalk()
	{
		var pth:OverworldPathFile = autoWalkPath;
		autoWalkPath = null;
		if (pth == null || busy || !autoWalk) return;
		walkAlong(pth, OverworldData.findNode(worldFile, curNodeId));
	}

	/**
	 * Lo que se acaba de superar y cuyos caminos hay que animar: el nivel de la ultima cancion
	 * y los nodos 'world' cuyo mundo ha quedado superado (lo normal: BF acaba de volver de el).
	 */
	function collectRevealNodes():Array<String>
	{
		doorsOpening = syncDoorNodes();
		var keyed:Array<String> = syncKeyNodes();
		// "id#key": isUnlocked lo ignora para saber como estaba antes de tener la llave
		var result:Array<String> = syncWorldNodes().concat(doorsOpening).concat([for (id in keyed) id + OverworldData.KEYED]);
		if (pendingReveal != null && pendingReveal[0] == curWorld && !result.contains(pendingReveal[1]))
			result.push(pendingReveal[1]);
		pendingReveal = null;
		return result;
	}

	/** Posicion de un mundo en la pila de submundos, o -1 si no esta. */
	static function stackIndexOf(world:String):Int
	{
		for (i in 0...worldStack.length)
			if (worldStack[i][0] == world) return i;
		return -1;
	}

	/** Los mundos por encima del actual en la pila: un nodo que lleve a ellos es una salida. */
	function parentWorlds():Array<String>
		return [for (entry in worldStack) entry[0]];

	/**
	 * Abre las puertas cuya llave ya se tiene (se ha ganado en una cancion): las marca como completadas y
	 * devuelve sus ids, asi lo que abren se revela como al superar un nivel y la puerta sale abierta.
	 */
	function syncDoorNodes():Array<String>
	{
		var newly:Array<String> = [];
		for (node in worldFile.nodes)
		{
			if (node.type != 'door' || !OverworldData.hasKey(node.key) || OverworldData.isCompleted(curWorld, node.id)) continue;
			OverworldData.setCompleted(curWorld, node.id);
			newly.push(node.id);
		}
		return newly;
	}

	/**
	 * Abre los nodos con llave (que no son puertas, p. ej. la tienda de Gaster del mundo 1) cuya llave ya se tiene:
	 * los apunta como "id#key" y devuelve sus ids, asi sus caminos se revelan y su sprite hace 'unlock'.
	 */
	function syncKeyNodes():Array<String>
	{
		var newly:Array<String> = [];
		for (node in worldFile.nodes)
		{
			if (!OverworldData.isKeyed(node) || !OverworldData.hasKey(node.key)) continue;
			if (OverworldData.isCompleted(curWorld, node.id + OverworldData.KEYED)) continue;
			OverworldData.setCompleted(curWorld, node.id + OverworldData.KEYED);
			newly.push(node.id);
		}
		return newly;
	}

	/**
	 * Las puertas abiertas al volver al mapa y los nodos con llave que se acaban de ver abiertos, con sus sprites:
	 * hacen su animacion 'unlock' al revelarse (las puertas con el primer "boom"; los nodos con llave, `onArrival`,
	 * cuando el camino que se revela llega a ellos).
	 */
	var doorsOpening:Array<String> = [];
	var doorUnlocks:Array<{sprite:FlxSprite, node:OverworldNodeFile, onArrival:Bool}> = [];

	/** Lo que se ha superado o abierto al volver al mapa (collectRevealNodes): "como estaba antes" para isUnlocked. */
	var revealList:Array<String> = [];

	/** Un nodo con llave se ve abierto si se tiene su llave (ya apuntada) y se ve algun camino hasta el. */
	function keyedOpen(node:OverworldNodeFile, ignore:Array<String>):Bool
	{
		if (!OverworldData.isUnlocked(curWorld, worldFile, node, ignore)) return false;
		for (pth in worldFile.paths)
			if ((pth.a == node.id || pth.b == node.id) && isPathOpen(pth, ignore)) return true;
		return false;
	}

	/** Si la imagen tiene la animacion de abrirse ("unlock0000"...; p. ej. overworld/gb_void). */
	static function hasUnlockAnim(image:String):Bool
		return image != null && image.length > 0 && OverworldData.hasAtlas(image) && atlasFrames(image).getByName('unlock0000') != null;

	/**
	 * Las puertas recien abiertas pasan de cerradas a abiertas con su animacion 'unlock' (una vez). `all`: tambien
	 * los nodos con llave que esperan a su camino (al saltarse el revelado o si no hay nada que revelar).
	 */
	function playDoorUnlocks(?all:Bool = false)
	{
		for (entry in doorUnlocks.copy())
			if (all || !entry.onArrival) startUnlock(entry);
	}

	/** Los nodos con llave a los que acaba de llegar un camino revelado (ids de la oleada terminada). */
	function playArrivalUnlocks(ids:Array<String>)
	{
		for (entry in doorUnlocks.copy())
			if (entry.onArrival && ids.contains(entry.node.id)) startUnlock(entry);
	}

	function startUnlock(entry:{sprite:FlxSprite, node:OverworldNodeFile, onArrival:Bool})
	{
		doorUnlocks.remove(entry);
		var spr:FlxSprite = entry.sprite;
		var fps:Int = entry.node.fps > 0 ? entry.node.fps : 6;
		spr.animation.addByPrefix('unlock', 'unlock', fps, false);
		spr.animation.addByPrefix('open', entry.node.animDone, fps, true);
		spr.animation.finishCallback = function(name:String) if (name == 'unlock') spr.animation.play('open');
		spr.animation.play('unlock');
	}

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
			&& OverworldData.isUnlocked(curWorld, worldFile, nodeB, ignoreCompleted)
			&& OverworldData.isPathUnlocked(curWorld, worldFile, pth, ignoreCompleted);
	}

	/**
	 * Crea los puntitos de un camino, de `a` hacia `b`, y los devuelve en ese orden. Un camino con
	 * `road` se dibuja como carretera: sus trozos van en roadsGroup y se revelan igual.
	 */
	function buildPathDots(pth:OverworldPathFile, ?hidden:Bool = false):Array<FlxSprite>
	{
		var result:Array<FlxSprite> = [];

		var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
		var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
		if (nodeA == null || nodeB == null) return result;

		if (pth.road)
		{
			for (piece in buildRoadPieces(pth, nodeA, nodeB, isLandAt, terrain))
			{
				piece.visible = !hidden;
				roadsGroup.add(piece);
				result.push(piece);
			}
			return result;
		}
		if (pth.dots == null || pth.dots.length < 1) return result;

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
	/** Los nodos a los que llega cada oleada (para los nodos con llave que se abren al llegarles su camino). */
	var waveTargets:Array<Array<String>> = [];
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
			// un nodo con llave solo cuenta si ya se veia abierto: asi su camino crece hacia el, no desde el
			if (OverworldData.isKeyed(node) ? keyedOpen(node, revealNodes) : OverworldData.isUnlocked(curWorld, worldFile, node, revealNodes))
				known.set(node.id, true);

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
				for (pth in pending)
				{
					wave.push(buildPathDots(pth, true));
					reachedNow.push(pth.a);
					reachedNow.push(pth.b);
				}
				pending = [];
			}

			for (id in reachedNow) known.set(id, true);
			revealWaves.push(wave);
			waveTargets.push(reachedNow);
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
				// como en Mario's Madness: un "boom" al abrirse cada tanda de caminos
				if (revealStep == 0)
				{
					sfx(SFX_UNLOCK);
					playDoorUnlocks(); // la puerta se abre con el primer "boom"
				}
				revealStep++;
				revealTimer += REVEAL_DOT_TIME;
				continue;
			}

			// oleada terminada: la siguiente sale tras una pausa de un puntito
			revealWaves.shift();
			var arrived:Array<String> = waveTargets.shift();
			if (arrived != null) playArrivalUnlocks(arrived);
			revealStep = 0;
			revealTimer += REVEAL_DOT_TIME;
			if (revealWaves.length < 1)
			{
				revealing = false;
				playDoorUnlocks(true); // lo que quedara por abrir
				endRevealFocus();
				startAutoWalk();
			}
		}
	}

	/** Cuantos trozos se han revelado: cada pocos sale una nubecita de humo, como en Mario's Madness. */
	var revealPuffs:Int = 0;

	function popDot(dot:FlxSprite)
	{
		dot.visible = true;
		// la carretera crece trozo a trozo; los puntitos salen con un saltito
		if (!Std.isOfType(dot, RoadPiece))
		{
			dot.scale.set(0.2, 0.2);
			FlxTween.tween(dot.scale, {x: 1, y: 1}, 0.2, {ease: FlxEase.backOut});
		}
		if (revealPuffs++ % 2 == 0) puff(dot.x + dot.width * 0.5, dot.y + dot.height * 0.5);

		// un puntito que no se veria con la camara sobre BF: la camara va a el (y despues vuelve).
		// Se mide desde BF y no desde la camara, para que dos caminos de la misma oleada no se la
		// disputen; y uno fuera de lo que la camara puede ensenar (camino de una salida) no cuenta.
		var x:Float = dot.x + dot.width * 0.5;
		var y:Float = dot.y + dot.height * 0.5;
		var halfW:Float = camGame.width / camGame.zoom * 0.5 - 24;
		var halfH:Float = camGame.height / camGame.zoom * 0.5 - 24;
		var area:Array<Float> = cameraArea(mapWidth, mapHeight, camGame.zoom);
		var showable:Bool = x >= area[0] && x <= area[0] + area[2] && y >= area[1] && y <= area[1] + area[3];
		if (showable && (Math.abs(x - playerX) > halfW || Math.abs(y - playerY) > halfH))
		{
			revealFocus = [x, y];
			revealFollowed = true;
		}
	}

	/** Una nubecita de humo que se deshace (overworld/smoke_overworld, del mapa de Mario's Madness). */
	function puff(x:Float, y:Float)
	{
		if (!OverworldData.imageExists('overworld/smoke_overworld')) return;
		var smoke:FlxSprite = buildSprite('overworld/smoke_overworld', 'idle', 12, false);
		smoke.setPosition(x - smoke.width * 0.5, y - smoke.height * 0.5);
		smoke.animation.finishCallback = function(_) smoke.kill();
		marksGroup.add(smoke);
	}

	#if debug
	var shotTimer:Float = 0;
	var shotWalked:Bool = false;
	#end

	/** Punto que mira la camara mientras se revela un camino que se sale de la pantalla. */
	var revealFocus:Array<Float> = null;

	/** La camara ha ido a mirar algun camino revelado fuera de pantalla (lo comprueba la prueba automatica). */
	var revealFollowed:Bool = false;

	function finishReveal()
	{
		for (wave in revealWaves)
			for (dots in wave)
				for (dot in dots) dot.visible = true;

		revealWaves = [];
		waveTargets = [];
		revealing = false;
		playDoorUnlocks(true); // si se salto el revelado antes de que llegaran
		endRevealFocus();
		startAutoWalk();
	}

	/** Al acabar el revelado, la camara se queda un momento mirando y vuelve a BF. */
	function endRevealFocus()
	{
		if (revealFocus == null) return;
		new FlxTimer().start(0.5, function(_:FlxTimer) revealFocus = null);
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

	// ------------------------------------------------------------- carreteras (caminos de SMW)
	/** El color de las carreteras de los mapas de Mario's Madness (beis liso, sin contorno). */
	public static inline final ROAD_COLOR:FlxColor = 0xFFF8E8B0;
	/** Media anchura de la carretera (8 px de ancho) y radio de la plataforma de cada nodo. */
	static inline final ROAD_RADIUS:Float = 4;
	static inline final ROAD_PAD_RADIUS:Float = 7;
	/** Largo de cada trozo: al revelarse, la carretera crece de trozo en trozo. */
	static inline final ROAD_PIECE:Float = 8;

	/** En el agua la carretera es una fila de puntitos blancos (por ahi se va nadando). */
	public static inline final ROAD_WATER_COLOR:FlxColor = 0xFFF0F0F0;
	static inline final ROAD_WATER_SPACING:Int = 6;

	/** La escalera (en el acantilado) y el puente (en el aire o sobre el agua): largueros y peldanos. */
	static inline final LADDER_DARK:FlxColor = 0xFF0D0C0D;
	static inline final LADDER_RAIL:FlxColor = 0xFFD89860;
	static inline final LADDER_RUNG:FlxColor = 0xFFF8E8B0;
	static inline final LADDER_SHADE:FlxColor = 0xFFB87848;
	/** Cada cuantos pixeles hay un peldano. */
	static inline final LADDER_PERIOD:Int = 6;

	/**
	 * Una carretera de `a` hacia `b` en trozos de ROAD_PIECE px, en ese orden, como los caminos de Mario's
	 * Madness (y de SMW). Con `terrain` (el del mapa) cada tramo se pone solo segun lo que tiene debajo:
	 * - suelo: franja beis de 8 px con los extremos redondos y una plataforma en cada nodo, recortada a
	 *   la hierba (no se sale por el borde);
	 * - acantilado: una escalera (BF trepa por ella);
	 * - nada (agua o aire): puntitos blancos si el camino es a nado (`move: 'swim'`) y, si no, un puente.
	 * Sin `terrain` (un mapa sin tiles) hace como antes: `isLand` dice que es tierra (franja) y que agua
	 * (puntitos); sin ninguno de los dos, todo es franja.
	 */
	public static function buildRoadPieces(pth:OverworldPathFile, nodeA:OverworldNodeFile, nodeB:OverworldNodeFile, ?isLand:Float->Float->Bool,
			?terrain:OverworldTerrain):Array<FlxSprite>
	{
		var line:Array<Array<Float>> = buildLine(pth, nodeA, nodeB);
		var total:Float = 0;
		for (i in 0...line.length - 1) total += distance(line[i], line[i + 1]);

		// puntos de la linea cada 1 px, para pintar circulos seguidos
		var samples:Array<Array<Float>> = [];
		for (i in 0...line.length - 1)
		{
			var length:Float = distance(line[i], line[i + 1]);
			var steps:Int = Std.int(Math.max(1, Math.ceil(length)));
			for (s in 0...steps)
			{
				var t:Float = s / steps;
				samples.push([line[i][0] + (line[i + 1][0] - line[i][0]) * t, line[i][1] + (line[i + 1][1] - line[i][1]) * t]);
			}
		}
		samples.push(line[line.length - 1]);

		// lo que hay bajo cada muestra
		var useTerrain:Bool = terrain != null && !terrain.empty;
		var kinds:Array<Int> = useTerrain ? terrain.kindsAlong(samples)
			: [for (s in samples) (isLand == null || isLand(s[0], s[1])) ? OverworldTerrain.GROUND : OverworldTerrain.NONE];
		var swim:Bool = pth.move == 'swim';
		var ladder:Array<Bool> = [for (k in kinds) k == OverworldTerrain.CLIFF || (k == OverworldTerrain.NONE && !swim && useTerrain)];

		// peldano de cada muestra de escalera (cuenta desde el principio de su tramo) y puntitos del agua
		var phase:Array<Int> = [];
		var dot:Array<Bool> = [];
		var run:Int = 0;
		var waterRun:Int = 0;
		for (i in 0...samples.length)
		{
			run = (i > 0 && ladder[i - 1] && ladder[i]) ? run + 1 : 0;
			phase.push(run);
			var water:Bool = kinds[i] == OverworldTerrain.NONE && !ladder[i];
			dot.push(water && waterRun++ % ROAD_WATER_SPACING == 0);
			if (!water) waterRun = 0;
		}

		// arcoiris (la Star Road de Mario's Madness): franjas de colores por todo el camino, sin mirar el terreno
		var rainbow:Bool = pth.style == 'rainbow';

		var first:Array<Float> = line[0];
		var last:Array<Float> = line[line.length - 1];
		var pieces:Array<FlxSprite> = [];
		var count:Int = Std.int(Math.max(1, Math.ceil(total / ROAD_PIECE)));
		var perPiece:Int = Std.int(Math.ceil(samples.length / count));
		var start:Int = 0;
		while (start < samples.length)
		{
			var end:Int = Std.int(Math.min(samples.length - 1, start + perPiece));
			var circles:Array<RoadCircle> = [];
			for (i in start...end + 1)
			{
				var s:Array<Float> = samples[i];
				if (rainbow) addRainbowSlice(circles, samples, i);
				else if (kinds[i] == OverworldTerrain.GROUND) circles.push({x: s[0], y: s[1], r: ROAD_RADIUS, color: ROAD_COLOR, mask: useTerrain});
				else if (ladder[i]) addLadderSlice(circles, samples, i, phase[i]);
				else if (dot[i]) circles.push({x: s[0], y: s[1], r: 1.2, color: ROAD_WATER_COLOR});
			}
			if (start == 0 && kinds[0] == OverworldTerrain.GROUND && !rainbow)
				circles.push({x: first[0], y: first[1], r: ROAD_PAD_RADIUS, color: ROAD_COLOR, mask: useTerrain});
			if (end == samples.length - 1 && kinds[samples.length - 1] == OverworldTerrain.GROUND && !rainbow)
				circles.push({x: last[0], y: last[1], r: ROAD_PAD_RADIUS, color: ROAD_COLOR, mask: useTerrain});
			if (circles.length > 0) pieces.push(drawRoadPiece(circles, useTerrain ? terrain : null));
			if (end >= samples.length - 1) break;
			start = end + 1;
		}
		return pieces;
	}

	/**
	 * Una fila de escalera (o de puente) en la muestra `i`: dos largueros negros con su marron y, cada
	 * LADDER_PERIOD px, un peldano (raya negra, beis y sombra), como la escalera del mundo 1. Va de lado
	 * si el camino va mas en horizontal (un puente).
	 */
	static function addLadderSlice(circles:Array<RoadCircle>, samples:Array<Array<Float>>, i:Int, step:Int)
	{
		var a:Array<Float> = samples[i > 0 ? i - 1 : i];
		var b:Array<Float> = samples[i < samples.length - 1 ? i + 1 : i];
		var across:Bool = Math.abs(b[0] - a[0]) > Math.abs(b[1] - a[1]); // camino en horizontal: puente
		var cx:Int = Math.floor(samples[i][0]);
		var cy:Int = Math.floor(samples[i][1]);
		function px(offset:Int, color:FlxColor)
		{
			var x:Int = across ? cx : cx + offset;
			var y:Int = across ? cy + offset : cy;
			circles.push({x: x + 0.5, y: y + 0.5, r: 0.5, color: color});
		}
		px(-7, LADDER_DARK);
		px(-6, LADDER_RAIL);
		px(5, LADDER_RAIL);
		px(6, LADDER_DARK);
		var rung:Null<FlxColor> = switch (step % LADDER_PERIOD)
		{
			case 2: LADDER_DARK;
			case 3: LADDER_RUNG;
			case 4: LADDER_SHADE;
			default: null;
		}
		if (rung != null) for (offset in -5...5) px(offset, rung);
	}

	/** Los colores del arcoiris de la Star Road de Mario's Madness, de un borde al otro (2 px cada uno) y su sombra. */
	static final RAINBOW_COLORS:Array<FlxColor> = [0xFFFF2626, 0xFFFF2626, 0xFFF8D800, 0xFFF8D800, 0xFF00C800, 0xFF00C800, 0xFF00D8F8, 0xFF00D8F8];
	static inline final RAINBOW_SHADOW:FlxColor = 0xFF8078D0;

	/** Una fila del arcoiris en la muestra `i`: rojo, amarillo, verde y cian de lado a lado, y la sombra debajo. */
	static function addRainbowSlice(circles:Array<RoadCircle>, samples:Array<Array<Float>>, i:Int)
	{
		var a:Array<Float> = samples[i > 0 ? i - 1 : i];
		var b:Array<Float> = samples[i < samples.length - 1 ? i + 1 : i];
		var across:Bool = Math.abs(b[0] - a[0]) > Math.abs(b[1] - a[1]); // en horizontal: franjas una encima de otra
		var cx:Int = Math.floor(samples[i][0]);
		var cy:Int = Math.floor(samples[i][1]);
		for (k in 0...RAINBOW_COLORS.length + 1)
		{
			var offset:Int = k - 4;
			var color:FlxColor = k < RAINBOW_COLORS.length ? RAINBOW_COLORS[k] : RAINBOW_SHADOW;
			var x:Int = across ? cx : cx + offset;
			var y:Int = across ? cy + offset : cy;
			circles.push({x: x + 0.5, y: y + 0.5, r: 0.5, color: color});
		}
	}

	/** Pinta circulos pixelados en un sprite del tamano justo (los de `mask`, solo sobre el suelo de `terrain`). */
	static function drawRoadPiece(circles:Array<RoadCircle>, ?terrain:OverworldTerrain):FlxSprite
	{
		var minX:Float = Math.POSITIVE_INFINITY;
		var minY:Float = Math.POSITIVE_INFINITY;
		var maxX:Float = Math.NEGATIVE_INFINITY;
		var maxY:Float = Math.NEGATIVE_INFINITY;
		for (c in circles)
		{
			minX = Math.min(minX, Math.floor(c.x - c.r));
			minY = Math.min(minY, Math.floor(c.y - c.r));
			maxX = Math.max(maxX, Math.ceil(c.x + c.r));
			maxY = Math.max(maxY, Math.ceil(c.y + c.r));
		}
		var width:Int = Std.int(maxX - minX) + 1;
		var height:Int = Std.int(maxY - minY) + 1;
		var bitmap:openfl.display.BitmapData = new openfl.display.BitmapData(width, height, true, 0);
		bitmap.lock();
		for (c in circles)
		{
			// circulo pixelado: los pixeles cuyo centro cae dentro del radio
			var cx:Float = c.x - minX;
			var cy:Float = c.y - minY;
			var r:Float = c.r;
			var color:FlxColor = c.color;
			var masked:Bool = c.mask == true && terrain != null;
			for (py in Std.int(Math.floor(cy - r))...Std.int(Math.ceil(cy + r)) + 1)
				for (px in Std.int(Math.floor(cx - r))...Std.int(Math.ceil(cx + r)) + 1)
				{
					var dx:Float = px + 0.5 - cx;
					var dy:Float = py + 0.5 - cy;
					if (dx * dx + dy * dy > r * r || px < 0 || py < 0 || px >= width || py >= height) continue;
					if (masked && terrain.rawAt(px + minX, py + minY) != OverworldTerrain.GROUND) continue;
					bitmap.setPixel32(px, py, color);
				}
		}
		bitmap.unlock();

		var piece:RoadPiece = new RoadPiece(minX, minY);
		piece.loadGraphic(flixel.graphics.FlxGraphic.fromBitmapData(bitmap, false, null, false));
		piece.antialiasing = false;
		return piece;
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
			var atlas:FlxAtlasFrames = atlasFrames(image);
			spr.frames = atlas;

			// un fotograma concreto ("tile0042", lo que pinta la paleta): se coge directamente.
			// addByPrefix recorreria todos los fotogramas del atlas (2188) por cada tile.
			var exact:FlxFrame = atlas.getByName(anim);
			if (exact != null && !hasLongerName(atlas, anim)) spr.frame = exact;
			else
			{
				spr.animation.addByPrefix('idle', anim, fps > 0 ? fps : 6, loop);
				if (spr.animation.getByName('idle') != null) spr.animation.play('idle');
				else spr.loadGraphic(Paths.image(image));
			}
		}
		else spr.loadGraphic(Paths.image(image));

		spr.antialiasing = false;
		spr.updateHitbox();
		return spr;
	}

	/**
	 * Fotogramas de cada atlas, leidos una vez por pantalla (el grafico vive mientras dure la
	 * pantalla; Psych lo libera al cambiar). Paths.getSparrowAtlas comprueba el disco en cada
	 * llamada, y con miles de tiles se notaba al volver al mapa y en el editor.
	 */
	static var framesCache:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();

	/** Olvida los atlas guardados: llamar al crear cada pantalla que use buildSprite. */
	public static function clearSpriteCache()
		framesCache.clear();

	static function atlasFrames(image:String):FlxAtlasFrames
	{
		// PlayState libera las imagenes del mapa al empezar cada cancion. Una imagen destruida
		// conserva su `bitmap` (flixel ignora el null), asi que se mira que siga registrada en
		// FlxG.bitmap con su clave y sin destruir; si no, se vuelve a cargar.
		var cached:FlxAtlasFrames = framesCache.get(image);
		if (cached != null && cached.frames != null && cached.parent != null && !cached.parent.isDestroyed
			&& cached.parent.key != null && FlxG.bitmap.get(cached.parent.key) == cached.parent)
			return cached;

		var atlas:FlxAtlasFrames = Paths.getSparrowAtlas(image);
		framesCache.set(image, atlas);
		return atlas;
	}

	/** Hay otro fotograma cuyo nombre empieza por `name` (entonces `name` es un prefijo, no un tile suelto). */
	static function hasLongerName(atlas:FlxAtlasFrames, name:String):Bool
	{
		// los tiles van numerados con 4 cifras: basta con mirar si existe "name0" .. "name9"
		for (digit in 0...10)
			if (atlas.getByName(name + digit) != null) return true;
		return false;
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
		// caminos para nadar (move: 'swim') y para trepar (move: 'climb')
		addPlayerAnim('swim_down', anims, 'swim down');
		addPlayerAnim('swim_up', anims, 'swim up');
		addPlayerAnim('swim_left', anims, 'swim left');
		addPlayerAnim('swim_right', anims, 'swim right');
		addPlayerAnim('enter_swim', anims, 'enter level swim');
		addPlayerAnim('climb', anims, 'climb');

		if (player.animation.getByName('walk_down') == null && anims.length > 0)
			player.animation.addByPrefix('walk_down', anims[0], 8, true);

		// un jugador sin animacion de warp propia (dead_overworld_bf): gira sobre si mismo con el
		// primer fotograma de cada direccion, que es lo que hace la de overworld_bf
		if (player.animation.getByName('warp') == null)
		{
			var spin:Array<Int> = [];
			for (dir in ['walk_down', 'walk_right', 'walk_up', 'walk_left'])
			{
				var walk = player.animation.getByName(dir);
				if (walk != null && walk.frames.length > 0) spin.push(walk.frames[0]);
			}
			if (spin.length == 4) player.animation.add('warp', spin, 8, true);
		}

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

		var backHint:String = returnToEditor ? 'BACK: back to the editor' : 'BACK: menu';
		hintTxt = new FlxText(10, FlxG.height - 22, FlxG.width - 20, 'ACCEPT: enter    $backHint    R twice: reset this world and its subworlds', 14);
		hintTxt.setFormat(Paths.font('vcr.ttf'), 14, 0xFFCCCCCC, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hintTxt.cameras = [camHUD];
		add(hintTxt);

		// progreso del mundo, a la derecha de la barra
		var count:Array<Int> = OverworldData.levelCount(curWorld, worldFile, parentWorlds());
		if (count[1] > 0)
		{
			var progressTxt:FlxText = new FlxText(10, FlxG.height - 44, FlxG.width - 20, 'Cleared: ${count[0]}/${count[1]}', 18);
			progressTxt.setFormat(Paths.font('vcr.ttf'), 18, count[0] >= count[1] ? DONE_COLOR : FlxColor.WHITE, RIGHT,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			progressTxt.cameras = [camHUD];
			add(progressTxt);
		}

		// salidas secretas del mundo, si tiene
		var secrets:Array<Int> = OverworldData.secretCount(curWorld, worldFile);
		if (secrets[1] > 0)
		{
			var secretTxt:FlxText = new FlxText(10, FlxG.height - 22, FlxG.width - 20, 'Secrets: ${secrets[0]}/${secrets[1]}', 14);
			secretTxt.setFormat(Paths.font('vcr.ttf'), 14, secrets[0] >= secrets[1] ? SECRET_COLOR : 0xFFCCCCCC, RIGHT,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			secretTxt.cameras = [camHUD];
			add(secretTxt);
		}

		updateNameText();
	}

	static inline final SECRET_COLOR:FlxColor = 0xFFFFD84A;

	static inline final DONE_COLOR:FlxColor = 0xFF66FF66;
	static final DONE_MARKUP:Array<FlxTextFormatMarkerPair> = [
		new FlxTextFormatMarkerPair(new FlxTextFormat(DONE_COLOR), '<g>'),
		new FlxTextFormatMarkerPair(new FlxTextFormat(SECRET_COLOR), '<y>')
	];

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
		else if (!busy && !entering) updateInput();

		// mientras se revela un camino fuera de pantalla, la camara va a mirarlo
		if (camFollow != null)
		{
			if (revealFocus != null) camFollow.setPosition(revealFocus[0], revealFocus[1]);
			else camFollow.setPosition(playerX, playerY);
		}

		super.update(elapsed);
		sortDepth();

		#if debug
		// -shot: a los 3 s (o a los de -shotat) guarda una captura del mapa en world_shot.png y cierra
		// (para revisar un mundo sin depender de capturar la ventana desde fuera). Con -walk <direccion>,
		// a los 0,5 s BF echa a andar por codigo (para ver como nada o trepa sin simular teclas).
		if (shotTimer >= 0 && Sys.args().contains('-shot'))
		{
			var args:Array<String> = Sys.args();
			shotTimer += elapsed;
			var walkArg:Int = args.indexOf('-walk');
			if (!shotWalked && shotTimer >= 0.5 && walkArg > -1 && walkArg + 1 < args.length)
			{
				shotWalked = true;
				switch (args[walkArg + 1])
				{
					case 'left': tryWalk(-1, 0);
					case 'right': tryWalk(1, 0);
					case 'up': tryWalk(0, -1);
					default: tryWalk(0, 1);
				}
			}
			var atArg:Int = args.indexOf('-shotat');
			var at:Float = atArg > -1 && atArg + 1 < args.length ? Std.parseFloat(args[atArg + 1]) : 3;
			if (shotTimer > (Math.isNaN(at) ? 3 : at))
			{
				shotTimer = -1;
				var bmp:openfl.display.BitmapData = new openfl.display.BitmapData(FlxG.stage.stageWidth, FlxG.stage.stageHeight, false, 0xFF000000);
				bmp.draw(FlxG.stage);
				sys.io.File.saveBytes('world_shot.png', bmp.encode(bmp.rect, new openfl.display.PNGEncoderOptions()));
				// con -test-key, lo que se ha abierto en este mundo (de prueba) no se queda en la partida
				if (OverworldData.testKeys.length > 0) OverworldData.resetProgress(curWorld);
				Sys.exit(0);
			}
		}
		#end

		if (iris != null && iris.visible)
		{
			var center:Array<Float> = irisCenter();
			irisShader.setIris(center[0], center[1], irisRadius);
		}
	}

	function updateInput()
	{
		// tras un revelado, cualquier tecla devuelve la camara a BF sin esperar
		if (revealFocus != null && (controls.ACCEPT || controls.BACK || controls.UI_LEFT_P || controls.UI_RIGHT_P || controls.UI_UP_P || controls.UI_DOWN_P))
			revealFocus = null;

		if (controls.BACK)
		{
			sfx(SFX_BACK);
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
			// borra el progreso de verdad: se pide confirmacion pulsando R otra vez
			var now:Float = haxe.Timer.stamp();
			if (now - resetAskedAt < 3)
			{
				resetWorldProgress();
				return;
			}
			resetAskedAt = now;
			sfx(SFX_WRONG);
			showError('Press R again to erase the progress of this world and its subworlds');
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
			// vuelve al mundo que se estaba editando, aunque se haya pasado a otro por el camino
			var edited:String = editorWorld != null ? editorWorld : (worldStack.length > 0 ? worldStack[0][0] : curWorld);
			editorWorld = null;
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
				failExit('This way leads to another world ("${exit.world}") that does not exist yet');
				return;
			}

			arrivingFrom = curWorld;

			// de lado hacia un mapa de mas arriba en la cadena: lo de debajo de el ya no vale
			var ancestor:Int = stackIndexOf(exit.world);
			if (ancestor > -1) worldStack = worldStack.slice(0, ancestor);
			else
			{
				// de lado hacia un submundo de otro mapa: la pila de aqui no vale alli, y su salida
				// sin destino llevaria al castillo equivocado. Se rehace desde sus castillos.
				var parents:Array<Array<String>> = OverworldData.parentsOf(exit.world);
				var top:String = worldStack.length > 0 ? worldStack[worldStack.length - 1][0] : null;
				if (parents.length > 0 && !Lambda.exists(parents, p -> p[0] == top))
					worldStack = OverworldData.parentChain(exit.world);
			}

			var lateral:String = exit.world;
			irisClose(function()
			{
				curWorld = lateral;
				curNodeId = null;
				switchToMap();
			});
			return;
		}

		var target:Array<String> = worldStack.length > 0 ? worldStack.pop() : OverworldData.findParentWorld(curWorld);
		if (target == null)
		{
			failExit('This exit does not lead to any map:\nset its target world in the editor or make a "world" node lead here');
			return;
		}

		// se vuelve encima del castillo por el que se entro; si se llego aqui de lado desde otro
		// submundo, ese castillo lleva al otro, y la puerta correcta es la que lleva a este
		var parentFile:OverworldFile = OverworldData.loadCached(target[0]);
		var door:OverworldNodeFile = null;
		if (parentFile != null)
		{
			var entered:OverworldNodeFile = OverworldData.findNode(parentFile, target[1]);
			if (entered != null && entered.type == 'world' && entered.world == curWorld) door = entered;
			else door = Lambda.find(parentFile.nodes, n -> n.type == 'world' && n.world == curWorld);
		}

		var backNode:String = door != null ? door.id : target[1];
		irisClose(function()
		{
			curWorld = target[0];
			curNodeId = backNode;
			switchToMap();
		});
	}

	function failExit(message:String)
	{
		busy = false;
		sfx(SFX_WRONG);
		showError(message);
		updateNameText();

		// una salida que aun no lleva a ningun sitio (suele estar fuera de la pantalla): BF vuelve por
		// donde ha venido en vez de quedarse alli
		var here:OverworldNodeFile = OverworldData.findNode(worldFile, curNodeId);
		var back:OverworldNodeFile = OverworldData.findNode(worldFile, walkFrom);
		if (here != null && here.type == 'exit' && back != null) walkAlong(pathBetween(here.id, back.id), here);
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
				if (!OverworldData.isPathUnlocked(curWorld, worldFile, pth)) continue;

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
		var bestPath:OverworldPathFile = null;
		var bestScore:Float = MIN_DIRECTION_SCORE;
		var lockedAhead:Bool = false;
		var needAhead:OverworldNodeFile = null;

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

			// un camino con condicion propia que aun no se ha abierto no se ve: es como si no estuviera
			if (!OverworldData.isPathUnlocked(curWorld, worldFile, pth)) continue;

			if (!OverworldData.isUnlocked(curWorld, worldFile, other))
			{
				lockedAhead = true;
				if (other.needLevels > 0) needAhead = other;
				continue;
			}
			if (score <= bestScore) continue;

			bestScore = score;
			bestLine = line;
			bestTarget = other;
			bestPath = pth;
		}

		if (bestLine == null)
		{
			if (lockedAhead) sfx(SFX_WRONG);
			// un nodo de "N superados": se dice cuantos faltan
			if (needAhead != null)
				showError('You need ${needAhead.needLevels} cleared levels in this world (you have ${OverworldData.completedCount(curWorld, worldFile)})');
			return;
		}

		bestLine.shift(); // el primer punto es donde ya esta el jugador
		walkFrom = current.id;
		walkQueue = bestLine;
		walkTarget = bestTarget;
		walkMove = bestPath.move;
		walkRoad = bestPath.road;
		walking = true;
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
			sfx(SFX_MOVE);

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
		playAnim(moveAnim());
	}

	/**
	 * La animacion de ir por el camino actual: trepa en uno de 'climb' y, en uno de 'swim', nada
	 * donde no hay suelo debajo (y anda en lo que pisa de tierra), como BF en los mapas de Mario's
	 * Madness. Si el sprite no trae esa animacion, anda.
	 */
	function moveAnim():String
	{
		if (walkMove == 'climb' && player.animation.getByName('climb') != null) return 'climb';
		// por una carretera, segun lo que pisa: trepa por la escalera del acantilado y nada en el agua
		if (walkRoad && terrain != null && !terrain.empty)
		{
			var kind:Int = terrain.kindAt(playerX, playerY);
			if (kind == OverworldTerrain.CLIFF && player.animation.getByName('climb') != null) return 'climb';
			if (kind == OverworldTerrain.NONE && walkMove == 'swim' && player.animation.getByName('swim_$facing') != null) return 'swim_$facing';
			return 'walk_$facing';
		}
		if (walkMove == 'swim' && player.animation.getByName('swim_$facing') != null && !isLandAt(playerX, playerY)) return 'swim_$facing';
		return 'walk_$facing';
	}

	/**
	 * Hay suelo en ese punto si algun decorado de detras (los tiles del terreno) tiene ahi un pixel
	 * visible. Lo transparente es el fondo: el mar.
	 */
	function isLandAt(x:Float, y:Float):Bool
	{
		// con terreno de tiles: el suelo y el acantilado son tierra (los decorados no cuentan)
		if (terrain != null && !terrain.empty) return terrain.kindAt(x, y) != OverworldTerrain.NONE;
		if (spritesBack == null) return true;
		var point:FlxPoint = FlxPoint.get(x, y);
		var land:Bool = false;
		for (spr in spritesBack.members)
		{
			if (spr == null || !spr.visible || !spr.overlapsPoint(point)) continue;
			if (spr.pixelsOverlapPoint(point, 0x80, camGame))
			{
				land = true;
				break;
			}
		}
		point.put();
		return land;
	}

	/** BF echa a andar solo por un camino, desde `from` hasta su otro extremo. */
	function walkAlong(pth:OverworldPathFile, from:OverworldNodeFile):Bool
	{
		if (pth == null || from == null || walking) return false;
		var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
		var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
		if (nodeA == null || nodeB == null) return false;

		var line:Array<Array<Float>> = buildLine(pth, nodeA, nodeB);
		if (pth.b == from.id) line.reverse();
		line.shift(); // el primer punto es donde ya esta el jugador
		walkFrom = from.id;
		walkQueue = line;
		walkTarget = (pth.a == from.id) ? nodeB : nodeA;
		walkMove = pth.move;
		walkRoad = pth.road;
		walking = true;
		return true;
	}

	/** El camino que une dos nodos, si lo hay. */
	function pathBetween(a:String, b:String):OverworldPathFile
	{
		if (a == null || b == null) return null;
		for (pth in worldFile.paths)
			if ((pth.a == a && pth.b == b) || (pth.a == b && pth.b == a)) return pth;
		return null;
	}

	/** BF esta en el agua: en un nodo al que se llega nadando y que no tiene suelo debajo. */
	function inWater(node:OverworldNodeFile):Bool
	{
		if (node == null) return false;
		for (pth in worldFile.paths)
			if ((pth.a == node.id || pth.b == node.id) && pth.move == 'swim') return !isLandAt(node.x, node.y);
		return false;
	}

	/** La animacion de entrar a un nivel (o a una tuberia): nadando si el nodo esta en el agua. */
	function enterAnim():String
	{
		var node:OverworldNodeFile = OverworldData.findNode(worldFile, curNodeId);
		return (inWater(node) && player.animation.getByName('enter_swim') != null) ? 'enter_swim' : 'enter';
	}

	function playAnim(name:String)
	{
		if (player.animation.getByName(name) == null) return;
		player.animation.play(name);
		player.animation.resume();
	}

	/**
	 * Parado en un nodo, BF mira a camara y camina en el sitio, como Mario en el mapa de SMW (o nada en
	 * el sitio, si el nodo esta en el agua).
	 */
	function idleAnim()
	{
		facing = 'down';
		var node:OverworldNodeFile = OverworldData.findNode(worldFile, curNodeId);
		playAnim((inWater(node) && player.animation.getByName('swim_down') != null) ? 'swim_down' : 'walk_down');
	}

	function updatePlayerPosition()
	{
		player.setPosition(playerX - player.width * 0.5, playerY - player.height + 4);
	}

	function getCurrentNode():OverworldNodeFile
	{
		var node:OverworldNodeFile = OverworldData.findNode(worldFile, curNodeId);
		if (node != null && OverworldData.isUnlocked(curWorld, worldFile, node)) return node;
		if (node != null && returnToEditor && curWorld == testStartWorld && node.id == testStartNode) return node;

		node = OverworldData.findNode(worldFile, worldFile.startNode);
		if (node != null && OverworldData.isUnlocked(curWorld, worldFile, node)) return node;

		// mejor no en una salida: suelen estar fuera de pantalla (y una invisible ni se ve)
		for (other in worldFile.nodes)
			if (other.type != 'exit' && OverworldData.isUnlocked(curWorld, worldFile, other)) return other;
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
		if (node.type == 'warp') text += '  (ENTER: travel)';
		if (node.type == 'shop') text += '  (ENTER: enter)';
		if (node.type == 'door')
			text += OverworldData.isCompleted(curWorld, node.id) ? '  <g>OPEN<g>' : '  (locked: needs a key)';
		else if (OverworldData.canBeCompleted(node) && OverworldData.isCompleted(curWorld, node.id)) text += '  <g>CLEARED<g>';
		if (OverworldData.hasSecret(worldFile, node))
			text += OverworldData.isSecretCompleted(curWorld, node.id) ? '  <y>SECRET<y>' : '  <y>?<y>';

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
					sfx(SFX_WRONG);
					showError('World "${node.world}" does not exist');
					return;
				}

				busy = true;
				sfx(SFX_ENTER);

				// Si el destino ya esta en la cadena (un nodo que vuelve a un mapa de mas arriba),
				// se vuelve a el recortando la pila: apilarlo otra vez la corrompia (el castillo
				// dejaba de superarse y R dejaba de reiniciar).
				var target:String = node.world;
				irisClose(function()
				{
					var ancestor:Int = stackIndexOf(target);
					if (ancestor > -1)
					{
						curNodeId = worldStack[ancestor][1];
						worldStack = worldStack.slice(0, ancestor);
					}
					else
					{
						worldStack.push([curWorld, curNodeId]);
						curNodeId = null;
					}
					curWorld = target;
					switchToMap();
				});

			case 'level':
				if (node.song == null || node.song.length < 1)
				{
					sfx(SFX_WRONG);
					showError('This level has no song assigned');
					return;
				}
				startLevel(node);

			case 'warp':
				warpTo(node);

			case 'door':
				if (!OverworldData.isCompleted(curWorld, node.id))
				{
					sfx(SFX_WRONG);
					showError('The door is locked: you need a key');
				}

			case 'shop':
				enterShop(node);

			default:
				sfx(SFX_WRONG);
		}
	}

	/** Tienda (con ENTER): se cierra el iris y se abre la tienda; al salir se vuelve aqui. */
	function enterShop(node:OverworldNodeFile)
	{
		if (node.shop == null || node.shop.length < 1)
		{
			sfx(SFX_WRONG);
			showError('This shop node has no shop assigned');
			return;
		}
		busy = true;
		sfx(SFX_ENTER);
		savePosition();
		if (FlxG.sound.music != null && FlxG.sound.music.playing) FlxG.sound.music.fadeOut(0.7, 0);
		var shop:String = node.shop;
		irisClose(function()
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new GasterShopState(shop));
		});
	}

	/** Vuelve al mapa desde una tienda (al mismo nodo), abriendo con el iris. */
	public static function backFromShop()
	{
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		switchToMap();
	}

	/**
	 * Warp (con ENTER): BF viaja al warp del otro mundo que apunta de vuelta a este (o a su nodo
	 * inicial si no hay). Es un paso de lado, no un submundo: la pila no cambia. Como en el mapa de
	 * Mario's Madness: en una estrella BF gira y sale volando (y la pantalla se funde a saltos); en
	 * una tuberia salta y se mete dentro (y se cierra el iris).
	 */
	function warpTo(node:OverworldNodeFile)
	{
		if (node.world == null || node.world.length < 1 || !OverworldData.exists(node.world))
		{
			sfx(SFX_WRONG);
			showError(node.world != null && node.world.length > 0 ? 'This world does not exist yet' : 'This warp does not lead anywhere');
			return;
		}

		busy = true;
		var from:String = curWorld;
		var target:String = node.world;
		var star:Bool = OverworldData.isStarWarp(node);
		var go:Void->Void = function()
		{
			arrivingByWarp = from;
			curWorld = target;
			curNodeId = null;
			// un warp es un salto global (p. ej. al mundo central): la pila de submundos de donde
			// se venia ya no vale. Las salidas sin pila encuentran su mapa de fuera solas.
			worldStack = [];
			switchToMap(star);
		};
		if (star) starExit(go);
		else pipeExit(go);
	}

	// ------------------------------------------------------------- viajes: estrella y tuberia
	/** Como ha llegado BF por un warp ('star' o 'pipe'; null = no ha llegado por uno). */
	var warpEntrance:String = null;
	/** Mientras BF sale de su warp no se le puede mover. */
	var entering:Bool = false;
	var playerClip:flixel.math.FlxRect;

	static inline final STAR_SOUND:String = 'overworld/smw_feather_get';
	/** Opcional: si existe un sonido con este nombre, suena al entrar y salir de una tuberia. */
	static inline final PIPE_SOUND:String = 'overworld/pipe';

	function playWarpSound(star:Bool, ?orConfirm:Bool = false)
	{
		var key:String = star ? STAR_SOUND : PIPE_SOUND;
		if (Paths.fileExists('sounds/$key.${Paths.SOUND_EXT}', openfl.utils.AssetType.SOUND)) FlxG.sound.play(Paths.sound(key));
		else if (orConfirm) sfx(SFX_ENTER);
	}

	/** Estrella (como en Mario's Madness): BF gira con el sonido de la pluma, sale volando hacia arriba y la pantalla se funde. */
	function starExit(onGone:Void->Void)
	{
		playAnim('warp');
		playWarpSound(true, true);
		FlxTween.tween(player, {y: camGame.viewTop - player.height - 8}, 0.5, {startDelay: 0.5, ease: FlxEase.quadIn});
		new FlxTimer().start(2, function(_:FlxTimer) fadeClose(onGone));
	}

	/** Llegando por una estrella: BF baja girando desde lo alto y se posa en ella. */
	function starArrival()
	{
		entering = true;
		var standY:Float = player.y;
		player.y = camGame.viewTop - player.height - 8;
		player.visible = true;
		playAnim('warp');
		FlxTween.tween(player, {y: standY}, 0.6, {startDelay: 0.2, ease: FlxEase.quadOut, onComplete: function(_:FlxTween)
		{
			new FlxTimer().start(0.25, function(_:FlxTimer)
			{
				idleAnim();
				entering = false;
			});
		}});
	}

	/**
	 * La boca de la tuberia del nodo actual: la raya del borde de delante del agujero negro (a un tercio
	 * de su alto, como la de overworld/pipe). Lo que queda de BF por debajo se recorta: asi parece que se
	 * mete por el agujero y no por delante de la tuberia. Sin sprite, a la altura de los pies.
	 */
	function pipeMouthY():Float
	{
		var pipe:FlxSprite = nodeSprites.get(curNodeId);
		if (pipe == null || !pipe.visible) return player.y + player.height;
		return pipe.y + Math.round(pipe.height * PIPE_MOUTH);
	}

	/** Donde esta el borde de delante del agujero, en fraccion del alto del sprite de la tuberia. */
	static inline final PIPE_MOUTH:Float = 0.32;

	/**
	 * Tuberia (como la de vuelta de Mario's Madness): BF salta encima, cae en el agujero y se hunde en el
	 * (recortado por el borde de delante); despues se cierra el iris.
	 */
	function pipeExit(onGone:Void->Void)
	{
		playAnim('enter');
		playWarpSound(false, true);
		var mouthY:Float = pipeMouthY();
		var inHoleY:Float = mouthY - player.height + 2; // de pie dentro del agujero: los pies, bajo el borde
		FlxTween.tween(player, {y: inHoleY - 8}, 0.16, {ease: FlxEase.quadOut, onComplete: function(_:FlxTween)
		{
			FlxTween.tween(player, {y: inHoleY}, 0.12, {
				ease: FlxEase.quadIn,
				onUpdate: function(_:FlxTween) clipPlayerAbove(mouthY),
				onComplete: function(_:FlxTween)
				{
					FlxTween.tween(player, {y: mouthY}, 0.5, {
						startDelay: 0.12,
						ease: FlxEase.quadIn,
						onUpdate: function(_:FlxTween) clipPlayerAbove(mouthY),
						onComplete: function(_:FlxTween)
						{
							player.visible = false;
							new FlxTimer().start(0.15, function(_:FlxTimer) irisClose(onGone));
						}
					});
				}
			});
		}});
	}

	/** Llegando por una tuberia: BF sale del agujero (recortado por su borde) y salta delante de ella. */
	function pipeArrival()
	{
		entering = true;
		var standY:Float = player.y;
		var mouthY:Float = pipeMouthY();
		var inHoleY:Float = mouthY - player.height + 2;
		player.y = mouthY;
		clipPlayerAbove(mouthY);
		player.visible = true;
		playAnim('enter');
		playWarpSound(false);
		FlxTween.tween(player, {y: inHoleY}, 0.5, {
			ease: FlxEase.quadOut,
			onUpdate: function(_:FlxTween) clipPlayerAbove(mouthY),
			onComplete: function(_:FlxTween)
			{
				// del agujero, de un saltito, a su sitio delante de la tuberia
				FlxTween.tween(player, {y: inHoleY - 8}, 0.16, {
					startDelay: 0.1,
					ease: FlxEase.quadOut,
					onUpdate: function(_:FlxTween) clipPlayerAbove(mouthY),
					onComplete: function(_:FlxTween)
					{
						player.clipRect = null;
						FlxTween.tween(player, {y: standY}, 0.16, {ease: FlxEase.quadIn, onComplete: function(_:FlxTween)
						{
							idleAnim();
							entering = false;
						}});
					}
				});
			}
		});
	}

	/** Recorta a BF por debajo de `lineY` (la boca de la tuberia): asi parece que entra o sale de ella. */
	function clipPlayerAbove(lineY:Float)
	{
		if (playerClip == null) playerClip = flixel.math.FlxRect.get();
		var visible:Float = Math.max(0, Math.min(player.frameHeight, (lineY - player.y) / player.scale.y));
		player.clipRect = playerClip.set(0, 0, player.frameWidth, visible);
	}

	// ------------------------------------------------------------- fundido a saltos (estrellas)
	static inline final FADE_STEPS:Int = 5;
	static inline final FADE_STEP_TIME:Float = 0.1;

	var fade:FlxSprite;

	/** Fundido a negro en 5 saltos, como en SMW y en el mapa de Mario's Madness; despues `onDone`. */
	function fadeClose(onDone:Void->Void)
	{
		busy = true;
		fade.visible = true;
		fade.alpha = 0;
		new FlxTimer().start(FADE_STEP_TIME, function(tmr:FlxTimer)
		{
			fade.alpha = tmr.elapsedLoops / FADE_STEPS;
			if (tmr.loopsLeft == 0) new FlxTimer().start(0.12, function(_:FlxTimer) onDone());
		}, FADE_STEPS);
	}

	function fadeOpen(?onDone:Void->Void)
	{
		busy = true;
		fade.visible = true;
		fade.alpha = 1;
		new FlxTimer().start(FADE_STEP_TIME, function(tmr:FlxTimer)
		{
			fade.alpha = 1 - tmr.elapsedLoops / FADE_STEPS;
			if (tmr.loopsLeft == 0)
			{
				fade.visible = false;
				busy = false;
				if (onDone != null) onDone();
			}
		}, FADE_STEPS);
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
			sfx(SFX_WRONG);
			showError('Could not load "$songName":\n${e.message}');
			return;
		}

		busy = true;
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = diff;
		fromOverworld = true;
		lastLevelNode = node.id;
		curNodeId = node.id;

		sfx(SFX_ENTER);
		playAnim(enterAnim());
		// la musica del mapa se apaga mientras se cierra el iris, como en Mario's Madness
		if (FlxG.sound.music != null && FlxG.sound.music.playing) FlxG.sound.music.fadeOut(0.7, 0);

		new FlxTimer().start(0.3, function(_:FlxTimer) irisClose(function()
		{
			@:privateAccess
			if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory) Paths.freeGraphicsFromMemory();

			FlxTransitionableState.skipNextTransIn = true; // ya se ha cerrado con el iris
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			lastMusic = null;
			FreeplayState.destroyFreeplayVocals();

			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}));
	}

	// ------------------------------------------------------------- iris (transicion de SMW)
	static inline final IRIS_CLOSE_TIME:Float = 0.5;
	static inline final IRIS_OPEN_TIME:Float = 0.6;
	static inline final IRIS_MAX_RADIUS:Float = 1500; // mas que la diagonal de la pantalla

	var iris:FlxSprite;
	var irisShader:IrisShader;
	var irisRadius:Float = 0;

	function buildIris()
	{
		irisShader = new IrisShader();
		iris = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		iris.scrollFactor.set();
		iris.cameras = [camHUD];
		iris.shader = irisShader;
		iris.visible = false;
		add(iris);

		fade = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		fade.scrollFactor.set();
		fade.cameras = [camHUD];
		fade.visible = false;
		add(fade);
	}

	/** Donde esta BF en la pantalla (el centro del circulo), dentro de los bordes. */
	function irisCenter():Array<Float>
	{
		var x:Float = (playerX - camGame.viewLeft) * camGame.zoom;
		var y:Float = (playerY - 8 - camGame.viewTop) * camGame.zoom;
		return [Math.max(0, Math.min(FlxG.width, x)), Math.max(0, Math.min(FlxG.height, y))];
	}

	/** El circulo se cierra sobre BF y despues se ejecuta `onDone` (el cambio de pantalla). */
	function irisClose(onDone:Void->Void)
	{
		busy = true;
		if (revealFocus != null)
		{
			// el circulo se cierra sobre BF: la camara tiene que estar mirandole
			revealFocus = null;
			camFollow.setPosition(playerX, playerY);
			camGame.snapToTarget();
		}
		iris.visible = true;
		irisRadius = IRIS_MAX_RADIUS;
		FlxTween.num(IRIS_MAX_RADIUS, 0, IRIS_CLOSE_TIME, {
			ease: FlxEase.quadIn,
			onComplete: function(_:FlxTween) new FlxTimer().start(0.12, function(_:FlxTimer) onDone())
		}, function(value:Float) irisRadius = value);
	}

	function irisOpen(?onDone:Void->Void)
	{
		busy = true;
		iris.visible = true;
		irisRadius = 0;
		FlxTween.num(0, IRIS_MAX_RADIUS, IRIS_OPEN_TIME, {
			ease: FlxEase.quadOut,
			startDelay: 0.1,
			onComplete: function(_:FlxTween)
			{
				iris.visible = false;
				busy = false;
				if (onDone != null) onDone();
			}
		}, function(value:Float) irisRadius = value);
	}

	/**
	 * Cambia a otro mapa sin el fundido de Psych: este se ha cerrado con el iris y el otro se abre
	 * igual (o con el fundido a saltos, si `fade`: viajando en estrella).
	 */
	static function switchToMap(?fade:Bool = false)
	{
		if (fade) fadeOpenNext = true;
		else irisOpenNext = true;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.switchState(new OverworldState());
	}

	var errorTimer:FlxTimer;

	function showError(text:String, ?color:FlxColor = FlxColor.RED)
	{
		if (errorTxt == null)
		{
			errorTxt = new FlxText(0, 60, FlxG.width, '', 20);
			errorTxt.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.RED, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			errorTxt.cameras = [camHUD];
			add(errorTxt);
		}

		errorTxt.color = color;
		errorTxt.text = text;
		errorTxt.visible = true;

		if (errorTimer != null) errorTimer.cancel();
		errorTimer = new FlxTimer().start(4, function(_:FlxTimer) if (errorTxt != null) errorTxt.visible = false);
	}
}

/** Un trozo de carretera (camino con `road`): se revela sin el saltito de los puntitos. */
class RoadPiece extends FlxSprite {}

/** Un circulo de una carretera: centro, radio y color. */
typedef RoadCircle =
{
	var x:Float;
	var y:Float;
	var r:Float;
	var color:FlxColor;
	/** Solo se pinta sobre el suelo del terreno (la franja no se sale por el borde de la hierba). */
	@:optional var mask:Bool;
}
