package backend;

import states.editors.content.PsychJsonPrinter;

/**
 * Un nodo del mapa: un nivel (cancion), una entrada a otro mundo, o un punto de paso.
 */
typedef OverworldNodeFile =
{
	var id:String;          // identificador unico dentro del mundo
	var x:Float;            // posicion en pixeles del mundo
	var y:Float;
	var type:String;        // 'level' | 'world' | 'empty' | 'exit' (al pisarlo) | 'warp' (con ENTER, en pareja)
	var image:String;       // clave de imagen, ej: 'overworld/dot'
	var anim:String;        // prefijo de animacion (vacio = imagen estatica)
	var animDone:String;    // animacion al estar completado (vacio = la misma)
	var fps:Int;
	var name:String;        // nombre visible
	var song:String;        // type 'level': cancion a cargar
	var week:String;        // type 'level': semana de la que hereda dificultades
	var difficulty:String;  // type 'level': dificultad fija (vacio = Normal)
	var world:String;       // type 'world': mundo al que lleva
	var unlocked:Bool;      // desbloqueado desde el principio
	var unlocks:Array<String>; // ids que se desbloquean al completarlo
}

/**
 * Sprite decorativo (caminos, castillos de adorno, overlays animados...).
 */
typedef OverworldSpriteFile =
{
	var image:String;
	var anim:String;
	var fps:Int;
	var x:Float;
	var y:Float;
	var flipX:Bool;
	var flipY:Bool;
	var scale:Float;
	var alpha:Float;
	var front:Bool;         // true = se dibuja por encima de nodos y jugador
}

/**
 * Conexion entre dos nodos. Los puntos intermedios permiten curvas.
 */
typedef OverworldPathFile =
{
	var a:String;
	var b:String;
	var points:Array<Array<Float>>; // waypoints en pixeles del mundo
	var dots:String;                // imagen de los puntitos ('' = sin puntitos)
	var dotAnim:String;
	var dotSpacing:Float;
}

/** Un aviso de checkWorldProblems(): el texto y el nodo al que se refiere (null = todo el mundo). */
typedef OverworldProblem =
{
	var node:Null<String>;
	var text:String;
}

typedef OverworldImageInfo =
{
	var width:Int;
	var height:Int;
	var frameWidth:Int;
	var frameHeight:Int;
	var frameCount:Int;
	var anims:Array<String>;
}

typedef OverworldFile =
{
	var displayName:String;
	var bg:String;
	var bgAnim:String;
	var bgFps:Int;
	var bgTile:Bool;   // repetir el fondo hasta cubrir todo el mapa
	var music:String;
	var zoom:Float;
	var gridSize:Int;
	var startNode:String;
	var player:String;
	var walkSpeed:Float;
	var nodes:Array<OverworldNodeFile>;
	var sprites:Array<OverworldSpriteFile>;
	var paths:Array<OverworldPathFile>;
}

class OverworldData
{
	// El mundo que abre TitleState y con el que arranca el editor si no le pasas otro.
	public static final DEFAULT_WORLD:String = 'test_graph';
	public static final DEFAULT_BG:String = 'overworld/backgrounds/sea';
	public static final DEFAULT_SONG:String = 'tutorial';
	public static final DEFAULT_WEEK:String = 'tutorial';
	public static final FOLDER:String = 'overworlds';

	// ------------------------------------------------------------------ archivos

	public static function load(name:String):OverworldFile
	{
		var raw:String = Paths.getTextFromFile('$FOLDER/$name.json');
		if (raw == null || raw.trim().length < 1) return null;

		try
		{
			var file:OverworldFile = cast tjson.TJSON.parse(raw);
			applyDefaults(file);
			return file;
		}
		catch (e:Dynamic)
		{
			trace('OverworldData: error cargando "$name" -> $e');
			return null;
		}
	}

	public static function exists(name:String):Bool
	{
		if (name == null || name.length < 1) return false;

		// FileSystem primero: los mundos guardados desde el editor no estan en el manifest de OpenFL
		#if sys
		if (FileSystem.exists(Paths.getPath('$FOLDER/$name.json', TEXT))) return true;
		#end
		return Paths.fileExists('$FOLDER/$name.json', TEXT);
	}

	public static function stringify(file:OverworldFile):String
		return PsychJsonPrinter.print(file, ['nodes', 'sprites', 'paths', 'points', 'unlocks']);

	/**
	 * Guarda un mundo en la build (lo que lee el juego) y, si el juego corre desde
	 * export/.../bin, tambien en el repo (lo que se commitea). Devuelve las rutas escritas.
	 */
	public static function saveWorldFiles(name:String, file:OverworldFile):Array<String>
	{
		var saved:Array<String> = [];
		#if sys
		var data:String = stringify(file);
		var folders:Array<String> = [Paths.getSharedPath('$FOLDER/')];
		if (FileSystem.exists('../../../../Project.xml')) folders.push('../../../../assets/shared/$FOLDER/');

		for (folder in folders)
		{
			try
			{
				if (!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
				File.saveContent('$folder$name.json', data);
				saved.push('$folder$name.json');
			}
			catch (e:Dynamic)
			{
				trace('OverworldData: no se pudo guardar en $folder -> $e');
			}
		}
		#end
		clearWorldCache(); // las parejas de warp se leen de disco: que vean lo recien guardado
		return saved;
	}

	/** Nombre de archivo valido para un mundo: minusculas, cifras y guiones bajos. */
	public static function toWorldFileName(text:String):String
	{
		var clean:String = ~/[^a-z0-9_]+/g.replace(text.toLowerCase(), '_');
		clean = ~/_+/g.replace(clean, '_');
		while (clean.startsWith('_')) clean = clean.substr(1);
		while (clean.endsWith('_')) clean = clean.substr(0, clean.length - 1);
		return clean.length > 0 ? clean : 'mundo';
	}

	public static function createEmpty():OverworldFile
	{
		var file:OverworldFile = {
			displayName: 'Nuevo mundo',
			bg: DEFAULT_BG,
			bgAnim: 'idle',
			bgFps: 6,
			bgTile: true,
			music: 'freakyMenu',
			zoom: 3,
			gridSize: 16,
			startNode: 'node0',
			player: 'overworld/overworld_bf',
			walkSpeed: 60,
			nodes: [],
			sprites: [],
			paths: []
		};
		var first:OverworldNodeFile = createNode('node0', 128, 124);
		first.unlocked = true;
		file.nodes.push(first);
		return file;
	}

	public static function createNode(id:String, x:Float, y:Float):OverworldNodeFile
	{
		return {
			id: id,
			x: x,
			y: y,
			type: 'level',
			image: 'overworld/dot',
			anim: 'idle',
			animDone: '',
			fps: 6,
			name: 'Tutorial',
			song: DEFAULT_SONG,
			week: DEFAULT_WEEK,
			difficulty: '',
			world: '',
			unlocked: true, // los nodos nuevos nacen accesibles; bloquear es algo que se elige
			unlocks: []
		};
	}

	public static function createSprite(image:String, x:Float, y:Float):OverworldSpriteFile
	{
		return {
			image: image,
			anim: '',
			fps: 8,
			x: x,
			y: y,
			flipX: false,
			flipY: false,
			scale: 1,
			alpha: 1,
			front: false
		};
	}

	public static function createPath(a:String, b:String):OverworldPathFile
	{
		return {
			a: a,
			b: b,
			points: [],
			dots: 'overworld/dot',
			dotAnim: 'idle',
			dotSpacing: 16
		};
	}

	/**
	 * Rellena los campos que falten con sus valores por defecto. `includeSprites` a false se salta
	 * los decorados: con miles de tiles pintados es lo caro, y no cambian al editar el grafo.
	 */
	public static function applyDefaults(file:OverworldFile, ?includeSprites:Bool = true)
	{
		if (file == null) return;

		var base:OverworldFile = createEmpty();
		base.nodes = [];
		for (field in Reflect.fields(base))
			if (Reflect.field(file, field) == null)
				Reflect.setField(file, field, Reflect.field(base, field));

		// un JSON editado a mano puede traer cualquier cosa: listas que no son listas o huecos null
		// fallarian luego en juego, fuera del try/catch de load()
		if (!isArray(file.nodes)) file.nodes = [];
		if (!isArray(file.sprites)) file.sprites = [];
		if (!isArray(file.paths)) file.paths = [];
		if (file.nodes.contains(null)) file.nodes = [for (node in file.nodes) if (node != null) node];
		if (file.sprites.contains(null)) file.sprites = [for (spr in file.sprites) if (spr != null) spr];
		if (file.paths.contains(null)) file.paths = [for (pth in file.paths) if (pth != null) pth];

		var nodeBase:OverworldNodeFile = createNode('', 0, 0);
		for (node in file.nodes)
		{
			for (field in Reflect.fields(nodeBase))
				if (Reflect.field(node, field) == null)
					Reflect.setField(node, field, Reflect.field(nodeBase, field));
			if (!isArray(node.unlocks)) node.unlocks = [];
			if (!Std.isOfType(node.id, String)) node.id = Std.string(node.id);
		}

		if (includeSprites)
		{
			var spriteBase:OverworldSpriteFile = createSprite('', 0, 0);
			for (spr in file.sprites)
				for (field in Reflect.fields(spriteBase))
					if (Reflect.field(spr, field) == null)
						Reflect.setField(spr, field, Reflect.field(spriteBase, field));
		}

		var pathBase:OverworldPathFile = createPath('', '');
		for (pth in file.paths)
		{
			for (field in Reflect.fields(pathBase))
				if (Reflect.field(pth, field) == null)
					Reflect.setField(pth, field, Reflect.field(pathBase, field));
			if (!isArray(pth.points)) pth.points = [];
		}

		if (file.gridSize < 1) file.gridSize = 16;
		if (file.zoom <= 0) file.zoom = 3;
		if (file.walkSpeed <= 0) file.walkSpeed = 60;
	}

	static inline function isArray(value:Dynamic):Bool
		return value != null && Std.isOfType(value, Array);

	public static function findNode(file:OverworldFile, id:String):OverworldNodeFile
	{
		if (file == null || id == null) return null;
		for (node in file.nodes)
			if (node.id == id) return node;
		return null;
	}

	public static function uniqueNodeId(file:OverworldFile, ?prefix:String = 'node'):String
	{
		var i:Int = 0;
		while (findNode(file, '$prefix$i') != null) i++;
		return '$prefix$i';
	}

	// ------------------------------------------------------------------ progreso

	public static function getProgress():Map<String, Bool>
	{
		// una partida rota (otro tipo guardado ahi) haria crashear el juego en el primer .exists()
		var data:Dynamic = FlxG.save.data.overworldProgress;
		if (data == null || !Std.isOfType(data, haxe.ds.StringMap))
			FlxG.save.data.overworldProgress = new Map<String, Bool>();
		return FlxG.save.data.overworldProgress;
	}

	/** Borra el progreso de un ID que se reutiliza (un nodo nuevo no hereda el de uno borrado). */
	public static function clearStaleProgress(world:String, id:String)
	{
		if (isCompleted(world, id)) setCompleted(world, id, false);
	}

	public static function isCompleted(world:String, id:String):Bool
	{
		if (world == null || id == null) return false;
		return getProgress().exists('$world::$id');
	}

	public static function setCompleted(world:String, id:String, ?value:Bool = true)
	{
		if (world == null || id == null) return;

		var progress:Map<String, Bool> = getProgress();
		if (value) progress.set('$world::$id', true);
		else progress.remove('$world::$id');

		FlxG.save.data.overworldProgress = progress;
		FlxG.save.flush();
	}

	public static function resetProgress(?world:String = null)
	{
		var progress:Map<String, Bool> = getProgress();
		if (world == null) progress.clear();
		else
		{
			for (key in progress.keys())
				if (key.startsWith('$world::')) progress.remove(key);
		}

		FlxG.save.data.overworldProgress = progress;
		FlxG.save.flush();
	}

	/**
	 * Un nodo esta accesible si empieza desbloqueado o si algo ya completado lo desbloquea.
	 * `ignoreCompleted` hace como si ese nodo aun no se hubiera completado: sirve para saber
	 * que estaba abierto justo antes de ganarlo (y asi animar solo los caminos nuevos).
	 */
	public static function isUnlocked(world:String, file:OverworldFile, node:OverworldNodeFile, ?ignoreCompleted:Array<String>):Bool
	{
		if (node == null) return false;
		if (node.unlocked) return true;

		for (other in file.nodes)
		{
			if (ignoreCompleted != null && ignoreCompleted.contains(other.id)) continue;
			if (other.unlocks != null && other.unlocks.contains(node.id) && isNodeCompleted(world, other))
				return true;
		}

		// un warp tambien se abre si su pareja del otro mundo esta abierta (p. ej. el del mundo
		// central hacia un mundo, en cuanto el castillo de ese mundo abre su warp de vuelta)
		if (node.type == 'warp' && partnerOpen(world, node)) return true;

		return false;
	}

	/**
	 * Completado guardado o, para un nodo 'world', que su mundo ya este superado aunque BF no haya
	 * vuelto todavia al mapa de fuera (quien lo guarda en la partida es syncWorldNodes al volver).
	 * Asi, salir de un castillo superado por un warp ya abre la tuberia del mundo central.
	 */
	public static function isNodeCompleted(world:String, node:OverworldNodeFile):Bool
	{
		if (isCompleted(world, node.id)) return true;
		return node.type == 'world' && node.world != null && node.world.length > 0 && node.world != world
			&& isWorldCleared(node.world, [world]);
	}

	// ------------------------------------------------------------- mundos leidos de disco
	static var worldCache:Map<String, OverworldFile> = new Map<String, OverworldFile>();
	static var worldListCache:Array<String> = null;
	static var clearableCache:Map<String, Bool> = new Map<String, Bool>();

	/**
	 * Olvida los mundos leidos de disco (parejas, castillos, padres, el propio mapa del juego) y la
	 * lista de mundos. Se llama al guardar desde el editor, al abrirlo y al empezar partida: entre
	 * medias los archivos no cambian, y un mundo pintado son cientos de KB que no hay que releer
	 * cada vez que BF vuelve de una cancion.
	 */
	public static function clearWorldCache()
	{
		worldCache.clear();
		worldListCache = null;
		clearableCache.clear();
		songsCache.clear();
	}

	/** Un mundo de disco, leido una sola vez hasta el siguiente clearWorldCache(). No modificarlo. */
	public static function loadCached(name:String):OverworldFile
	{
		if (name == null) return null;
		if (!worldCache.exists(name)) worldCache.set(name, load(name));
		return worldCache.get(name);
	}

	/**
	 * La pareja de un warp: el warp del mundo destino que apunta de vuelta a `world`, como los
	 * dos extremos de una tuberia (por donde se entra se sale). null si no hay.
	 */
	public static function warpPartner(world:String, node:OverworldNodeFile):OverworldNodeFile
	{
		if (node == null || node.type != 'warp' || world == null || node.world == null || node.world.length < 1) return null;

		var dest:OverworldFile = loadCached(node.world);
		if (dest == null) return null;

		for (other in dest.nodes)
			if (other.type == 'warp' && other.world == world) return other;
		return null;
	}

	/** Un warp que tiene pareja: puede abrirse desde el otro mundo aunque aqui nadie lo desbloquee. */
	public static inline function opensByPartner(world:String, node:OverworldNodeFile):Bool
		return world != null && warpPartner(world, node) != null;

	/** Si la pareja de un warp esta abierta en su mundo (sin seguir la cadena: evita el bucle). */
	static function partnerOpen(world:String, node:OverworldNodeFile):Bool
	{
		var partner:OverworldNodeFile = warpPartner(world, node);
		if (partner == null) return false;
		if (partner.unlocked) return true;

		var destFile:OverworldFile = loadCached(node.world);
		for (other in destFile.nodes)
			if (other.unlocks != null && other.unlocks.contains(partner.id) && isNodeCompleted(node.world, other))
				return true;
		return false;
	}

	/**
	 * Un mundo esta superado cuando todo lo completable que tiene lo esta: sus niveles y sus
	 * nodos 'world' (estos, guardados o porque su propio mundo ya este superado).
	 * Un nodo que lleva a un mundo de mas arriba en la cadena (una "salida" de vuelta) no cuenta,
	 * o padre e hijo se esperarian el uno al otro y ninguno se superaria nunca.
	 */
	public static function isWorldCleared(name:String, ?visiting:Array<String>):Bool
	{
		if (visiting == null) visiting = [];
		if (visiting.contains(name)) return false;

		var file:OverworldFile = loadCached(name);
		if (file == null) return false;

		visiting = visiting.concat([name]);
		var required:Int = 0;
		for (node in file.nodes)
		{
			if (!canBeCompleted(node)) continue;

			if (node.type == 'world')
			{
				if (visiting.contains(node.world)) continue; // salida hacia un mundo padre
				required++;
				if (!isCompleted(name, node.id) && !isWorldCleared(node.world, visiting)) return false;
			}
			else
			{
				required++;
				if (!isCompleted(name, node.id)) return false;
			}
		}
		return required > 0;
	}

	/**
	 * El mundo desde el que se entra a `name` por un nodo 'world': [mundo, id del nodo].
	 * Sirve para saber a donde lleva una salida cuando no hay pila (p. ej. si el submundo
	 * se abrio directamente con run-world.bat). null si nadie lleva a el.
	 */
	public static function findParentWorld(name:String):Array<String>
	{
		var parents:Array<Array<String>> = parentsOf(name);
		return parents.length > 0 ? parents[0] : null;
	}

	/** Todas las entradas a `name` desde otros mundos por nodos 'world': [mundo, id del nodo]. */
	public static function parentsOf(name:String):Array<Array<String>>
		return nodesInto(name, 'world');

	/** Los nodos de otros mundos de tipo `type` cuyo destino es `name`: [mundo, id del nodo]. */
	public static function nodesInto(name:String, type:String):Array<Array<String>>
	{
		var result:Array<Array<String>> = [];
		if (name == null) return result;
		for (world in listWorlds())
		{
			if (world == name) continue;
			var file:OverworldFile = loadCached(world);
			if (file == null) continue;

			for (node in file.nodes)
				if (node.type == type && node.world == name) result.push([world, node.id]);
		}
		return result;
	}

	/**
	 * Los mapas de fuera de `name` siguiendo sus padres, del de mas arriba al mas cercano: la pila
	 * de submundos que tendria BF si hubiera entrado por sus castillos. Sin padres, vacia.
	 */
	public static function parentChain(name:String):Array<Array<String>>
	{
		var chain:Array<Array<String>> = [];
		var visited:Array<String> = [name];
		var parent:Array<String> = findParentWorld(name);
		while (parent != null && !visited.contains(parent[0]))
		{
			chain.unshift(parent);
			visited.push(parent[0]);
			parent = findParentWorld(parent[0]);
		}
		return chain;
	}

	/** Al renombrar un nodo, su progreso pasa al ID nuevo (y un nodo futuro con el viejo no lo hereda). */
	public static function renameProgress(world:String, oldId:String, newId:String)
	{
		if (world == null) return;
		// se renombra tecla a tecla: pasar por un ID con progreso viejo no debe quedarselo
		if (!isCompleted(world, oldId))
		{
			clearStaleProgress(world, newId);
			return;
		}
		var progress:Map<String, Bool> = getProgress();
		progress.remove('$world::$oldId');
		progress.set('$world::$newId', true);
		FlxG.save.data.overworldProgress = progress;
		FlxG.save.flush();
	}

	/**
	 * Este mundo y todos los que cuelgan de el por nodos 'world' (sin repetir). No entra en
	 * `exclude`: asi, reiniciar un submundo no reinicia tambien el mapa del que se vino.
	 */
	public static function worldTree(name:String, ?exclude:Array<String>):Array<String>
	{
		var result:Array<String> = [];
		var pending:Array<String> = [name];
		while (pending.length > 0)
		{
			var current:String = pending.shift();
			if (result.contains(current) || (exclude != null && exclude.contains(current))) continue;
			result.push(current);

			var file:OverworldFile = loadCached(current);
			if (file == null) continue;
			for (node in file.nodes)
				if (node.type == 'world' && node.world != null && node.world.length > 0 && !result.contains(node.world))
					pending.push(node.world);
		}
		return result;
	}

	/**
	 * Cuantos nodos completables tiene el mundo y cuantos estan completados: [completados, total].
	 * Los nodos que llevan a `parentWorlds` son salidas de vuelta y no cuentan.
	 */
	public static function levelCount(world:String, file:OverworldFile, ?parentWorlds:Array<String>):Array<Int>
	{
		var done:Int = 0;
		var total:Int = 0;
		for (node in file.nodes)
		{
			if (!canBeCompleted(node)) continue;
			if (node.type == 'world' && (node.world == world || (parentWorlds != null && parentWorlds.contains(node.world)))) continue;
			total++;
			if (isCompleted(world, node.id)) done++;
		}
		return [done, total];
	}

	// ------------------------------------------------------------- revision del grafo

	/** Algun nodo lista este id en sus `unlocks`. */
	public static function anyoneUnlocks(file:OverworldFile, id:String):Bool
	{
		for (other in file.nodes)
			if (other.unlocks != null && other.unlocks.contains(id)) return true;
		return false;
	}

	/**
	 * Un 'level' se completa al acabar su cancion; un 'world', cuando su mundo queda superado
	 * (ver isWorldCleared). Un 'empty' es solo un punto de paso y nunca se completa.
	 */
	public static function canBeCompleted(node:OverworldNodeFile):Bool
	{
		return switch (node.type)
		{
			case 'level': node.song != null && node.song.length > 0;
			case 'world': node.world != null && node.world.length > 0;
			default: false;
		}
	}

	/** Un ID valido para un nodo: no vacio, sin comas (separan la lista de unlocks) y sin '::' (clave del progreso). */
	public static function isValidNodeId(id:String):Bool
		return id != null && id.length > 0 && id.indexOf(',') < 0 && id.indexOf('::') < 0;

	/**
	 * Abierto "en principio": desbloqueado al empezar, o un warp que puede abrirse por su pareja
	 * (en un mundo central todos los warps son asi y ninguno empieza abierto). Si de verdad se
	 * abre depende del otro mundo: eso lo comprueba simulateGame().
	 */
	static inline function openAtStart(name:String, node:OverworldNodeFile):Bool
		return node.unlocked || (node.type == 'warp' && opensByPartner(name, node));

	/**
	 * El nodo donde aparece BF con el progreso a cero (misma regla que OverworldState): el inicial
	 * si esta abierto y si no, el primero abierto, mejor si no es una salida (suelen estar fuera
	 * de la pantalla).
	 */
	public static function firstStartNode(file:OverworldFile, ?name:String):OverworldNodeFile
	{
		var start:OverworldNodeFile = findNode(file, file.startNode);
		if (start != null && openAtStart(name, start)) return start;

		for (node in file.nodes)
			if (node.type != 'exit' && openAtStart(name, node)) return node;
		for (node in file.nodes)
			if (openAtStart(name, node)) return node;
		return null;
	}

	/**
	 * Por donde puede aparecer BF en este mundo: el nodo inicial, los warps con pareja (se sale
	 * encima de ellos) y las salidas por las que se llega de lado (el otro mundo tiene una que
	 * apunta aqui). Las que de verdad se usan en una partida las mira simulateGame().
	 */
	public static function entryNodes(file:OverworldFile, ?name:String):Array<OverworldNodeFile>
	{
		var result:Array<OverworldNodeFile> = [];
		var start:OverworldNodeFile = firstStartNode(file, name);
		if (start != null) result.push(start);
		if (name == null) return result;

		for (node in file.nodes)
		{
			if (result.contains(node) || !openAtStart(name, node)) continue;
			if (node.type == 'warp' && opensByPartner(name, node)) result.push(node);
			else if (isArrivalDoor(name, node)) result.push(node);
		}
		return result;
	}

	/** Una salida con destino por la que tambien se llega: el mundo destino tiene una que vuelve aqui. */
	static function isArrivalDoor(name:String, node:OverworldNodeFile):Bool
	{
		if (node.type != 'exit' || node.world == null || node.world.length < 1 || node.world == name) return false;
		var dest:OverworldFile = loadCached(node.world);
		return dest != null && Lambda.exists(dest.nodes, n -> n.type == 'exit' && n.world == name);
	}

	/**
	 * Si un nodo cuenta como completado en la simulacion de un solo mundo: un nivel con cancion,
	 * o un 'world' cuyo mundo se puede superar entero (y que no vuelva a un mapa de la cadena).
	 */
	static function simCompletable(node:OverworldNodeFile, chain:Array<String>):Bool
	{
		if (!canBeCompleted(node)) return false;
		if (node.type != 'world') return true;
		return !chain.contains(node.world) && worldClearable(node.world, chain);
	}

	/**
	 * Simula una partida desde cero dentro de este mundo: BF sale de sus entradas (entryNodes),
	 * recorre todo lo que tiene accesible, completa lo que se puede completar y aplica sus
	 * desbloqueos, hasta que ya no se abre nada nuevo. Devuelve los ids de los nodos a los que se
	 * acaba pudiendo llegar. `visiting` son los mapas de fuera (para los castillos de dentro).
	 */
	public static function simulateReachable(file:OverworldFile, ?name:String, ?visiting:Array<String>):Map<String, Bool>
	{
		var reached:Map<String, Bool> = new Map<String, Bool>();
		var seeds:Array<OverworldNodeFile> = entryNodes(file, name);
		if (seeds.length < 1) return reached;

		var chain:Array<String> = visiting == null ? [] : visiting.copy();
		if (name != null) chain.push(name);

		var open:Map<String, Bool> = new Map<String, Bool>();
		for (node in file.nodes)
			if (openAtStart(name, node)) open.set(node.id, true);

		var completable:Map<String, Bool> = new Map<String, Bool>();
		var changed:Bool = true;
		while (changed)
		{
			changed = false;

			// recorrido por caminos pisando solo nodos accesibles; en cada vuelta se sigue
			// desde todo lo ya alcanzado, que es donde pueden haber aparecido caminos nuevos
			for (seed in seeds) reached.set(seed.id, true);
			var pending:Array<String> = [for (id in reached.keys()) id];
			while (pending.length > 0)
			{
				var id:String = pending.pop();

				// pisar una salida saca del mapa: solo se anda desde las puertas por las que se llega
				var here:OverworldNodeFile = findNode(file, id);
				if (here != null && here.type == 'exit' && !seeds.contains(here)) continue;

				for (pth in file.paths)
				{
					var other:String = (pth.a == id) ? pth.b : ((pth.b == id) ? pth.a : null);
					if (other == null || reached.exists(other) || !open.exists(other)) continue;
					if (findNode(file, other) == null) continue;

					reached.set(other, true);
					pending.push(other);
				}
			}

			// completar todo lo alcanzado abre sus desbloqueos
			for (node in file.nodes)
			{
				if (!reached.exists(node.id) || node.unlocks == null || node.unlocks.length < 1) continue;
				if (!completable.exists(node.id)) completable.set(node.id, simCompletable(node, chain));
				if (!completable.get(node.id)) continue;

				for (target in node.unlocks)
				{
					if (open.exists(target)) continue;
					open.set(target, true);
					changed = true;
				}
			}
		}
		return reached;
	}

	/**
	 * Si un mundo se puede superar entero empezando de cero: se llega a todo lo completable que
	 * tiene y sus castillos de dentro tambien se pueden superar. Los nodos que vuelven a un mapa
	 * de `visiting` son salidas y no cuentan (como en isWorldCleared).
	 */
	public static function worldClearable(name:String, ?visiting:Array<String>):Bool
	{
		if (visiting == null) visiting = [];
		if (visiting.contains(name)) return false;

		var key:String = '$name<${visiting.join(',')}';
		if (clearableCache.exists(key)) return clearableCache.get(key);
		clearableCache.set(key, false); // un ciclo raro (A dentro de B dentro de A) cuenta como no superable

		var file:OverworldFile = loadCached(name);
		var result:Bool = false;
		if (file != null)
		{
			var chain:Array<String> = visiting.concat([name]);
			var reached:Map<String, Bool> = simulateReachable(file, name, visiting);
			var required:Int = 0;
			result = true;
			for (node in file.nodes)
			{
				if (!canBeCompleted(node)) continue;
				if (node.type == 'world' && chain.contains(node.world)) continue;

				required++;
				if (!reached.exists(node.id) || (node.type == 'world' && !worldClearable(node.world, chain)))
				{
					result = false;
					break;
				}
			}
			if (required < 1) result = false;
		}
		clearableCache.set(key, result);
		return result;
	}

	/**
	 * Simula la partida entera desde el mundo por defecto, pasando de un mundo a otro igual que el
	 * juego (castillos, salidas de lado, salidas de vuelta y warps con su pareja), hasta que ya no se
	 * abre nada nuevo. Devuelve "mundo::nodo" de todo lo que BF llega a pisar.
	 * Encuentra los bloqueos entre mundos que la revision de un solo mundo da por resueltos, como
	 * un warp que solo abre un nivel al que solo se llega por ese mismo warp. `editedName` y
	 * `editedFile` sustituyen a la version de disco de ese mundo (lo que hay abierto en el editor).
	 */
	/** Mundo donde empieza la partida para simulateGame(). Las pruebas automaticas lo cambian por el suyo. */
	public static var simStartWorld:String = null;

	public static inline function gameStartWorld():String
		return simStartWorld != null ? simStartWorld : DEFAULT_WORLD;

	public static function simulateGame(?editedName:String, ?editedFile:OverworldFile, ?closedDoors:Array<String>):Map<String, Bool>
	{
		var reached:Map<String, Bool> = new Map<String, Bool>();
		var seenExits:Map<String, Bool> = new Map<String, Bool>();
		var done:Map<String, Bool> = new Map<String, Bool>();
		var reachedList:Array<Array<String>> = [];

		function fileOf(world:String):OverworldFile
		{
			if (world == null || world.length < 1) return null;
			return (editedName != null && world == editedName) ? editedFile : loadCached(world);
		}

		// completado en la simulacion: un nivel pisado, o un 'world' con su mundo superado
		function clearedSim(world:String, visiting:Array<String>):Bool
		{
			if (visiting.contains(world)) return false;
			var file:OverworldFile = fileOf(world);
			if (file == null) return false;

			var chain:Array<String> = visiting.concat([world]);
			var required:Int = 0;
			for (node in file.nodes)
			{
				if (!canBeCompleted(node)) continue;
				if (node.type == 'world' && chain.contains(node.world)) continue;
				required++;
				if (done.exists('$world::${node.id}')) continue;
				if (node.type != 'world' || !clearedSim(node.world, chain)) return false;
			}
			return required > 0;
		}

		function isDone(world:String, node:OverworldNodeFile):Bool
		{
			if (done.exists('$world::${node.id}')) return true;
			return node.type == 'world' && node.world != null && node.world.length > 0 && node.world != world && clearedSim(node.world, [world]);
		}

		// misma regla que isUnlocked(), pero con lo completado en la simulacion
		function opened(world:String, file:OverworldFile, node:OverworldNodeFile, ?viaPartner:Bool = true):Bool
		{
			if (node == null) return false;
			if (node.unlocked) return true;
			for (other in file.nodes)
				if (other.unlocks != null && other.unlocks.contains(node.id) && isDone(world, other)) return true;

			if (viaPartner && node.type == 'warp')
			{
				var dest:OverworldFile = fileOf(node.world);
				var partner:OverworldNodeFile = dest == null ? null : Lambda.find(dest.nodes, n -> n.type == 'warp' && n.world == world);
				if (partner != null && opened(node.world, dest, partner, false)) return true;
			}
			return false;
		}

		function reach(world:String, id:String):Bool
		{
			var key:String = '$world::$id';
			if (reached.exists(key)) return false;
			reached.set(key, true);
			reachedList.push([world, id]);
			return true;
		}

		// entrar a un mundo "desde cero" (castillo, o warp/salida sin pareja): getCurrentNode()
		function enterFresh(world:String):Bool
		{
			var file:OverworldFile = fileOf(world);
			if (file == null) return false;

			var start:OverworldNodeFile = findNode(file, file.startNode);
			if (start == null || !opened(world, file, start))
			{
				start = Lambda.find(file.nodes, n -> n.type != 'exit' && opened(world, file, n));
				if (start == null) start = Lambda.find(file.nodes, n -> opened(world, file, n));
			}
			return start != null && reach(world, start.id);
		}

		// los mapas con un castillo que lleva a `world` (con la version del editor si es uno de ellos)
		var allWorlds:Array<String> = listWorlds().copy();
		if (editedName != null && !allWorlds.contains(editedName)) allWorlds.push(editedName);
		function parentsSim(world:String):Array<Array<String>>
		{
			var result:Array<Array<String>> = [];
			for (name in allWorlds)
			{
				var file:OverworldFile = name == world ? null : fileOf(name);
				if (file == null) continue;
				for (node in file.nodes)
					if (node.type == 'world' && node.world == world) result.push([name, node.id]);
			}
			return result;
		}

		var first:String = gameStartWorld();
		if (fileOf(first) == null) return reached;
		enterFresh(first);

		var changed:Bool = true;
		while (changed)
		{
			changed = false;

			// andar por cada mundo desde todo lo alcanzado (sin atravesar salidas)
			var index:Int = 0;
			while (index < reachedList.length)
			{
				var world:String = reachedList[index][0];
				var id:String = reachedList[index][1];
				index++;

				var file:OverworldFile = fileOf(world);
				var here:OverworldNodeFile = findNode(file, id);
				if (here == null) continue;

				// de una salida solo se sale andando si es la puerta por la que se ha llegado
				if (here.type == 'exit' && !reached.exists('$world::${id}::door')) continue;

				for (pth in file.paths)
				{
					var otherId:String = (pth.a == id) ? pth.b : ((pth.b == id) ? pth.a : null);
					if (otherId == null || reached.exists('$world::$otherId')) continue;
					var other:OverworldNodeFile = findNode(file, otherId);
					if (other != null && opened(world, file, other) && reach(world, otherId)) changed = true;
				}
			}

			// lo pisado se completa (todo antes de cruzar ninguna puerta: un jugador puede hacerlo)
			for (entry in reachedList)
			{
				var node:OverworldNodeFile = findNode(fileOf(entry[0]), entry[1]);
				if (node != null && node.type == 'level' && canBeCompleted(node) && !done.exists('${entry[0]}::${node.id}'))
				{
					done.set('${entry[0]}::${node.id}', true);
					changed = true;
				}
			}

			// y cada puerta lleva a otro mundo
			for (entry in reachedList.copy())
			{
				var world:String = entry[0];
				var file:OverworldFile = fileOf(world);
				var node:OverworldNodeFile = findNode(file, entry[1]);
				if (node == null) continue;

				var target:String = node.world;
				var hasTarget:Bool = target != null && target.length > 0 && target != world && fileOf(target) != null;
				if (node.type == 'world' && hasTarget)
				{
					if (enterFresh(target)) changed = true;
				}
				else if (node.type == 'warp' && hasTarget)
				{
					// como una tuberia: se sale encima de su pareja si esta abierta
					var dest:OverworldFile = fileOf(target);
					var partner:OverworldNodeFile = Lambda.find(dest.nodes, n -> n.type == 'warp' && n.world == world);
					if (partner != null && opened(target, dest, partner))
					{
						if (reach(target, partner.id)) changed = true;
					}
					else if (enterFresh(target)) changed = true;
				}
				else if (node.type == 'exit' && hasTarget)
				{
					// de lado: se entra andando por la salida de alli que apunta de vuelta
					var dest:OverworldFile = fileOf(target);
					var door:OverworldNodeFile = Lambda.find(dest.nodes, n -> n.type == 'exit' && n.world == world && opened(target, dest, n));

					// la primera vez que se puede pisar esta salida, aunque se haya completado todo lo
					// alcanzable, su puerta de vuelta sigue cerrada: BF llegaria alli a su nodo inicial
					var exitKey:String = '$world::${node.id}';
					if (!seenExits.exists(exitKey))
					{
						seenExits.set(exitKey, true);
						if (door == null && closedDoors != null && Lambda.exists(dest.nodes, n -> n.type == 'exit' && n.world == world))
							closedDoors.push(exitKey);
					}
					if (door != null)
					{
						if (reach(target, door.id)) changed = true;
						reached.set('$target::${door.id}::door', true);
					}
					else if (enterFresh(target)) changed = true;
				}
				else if (node.type == 'exit')
				{
					// sin destino: de vuelta al mapa de fuera, encima de su castillo (si no esta
					// abierto, BF aparece en el nodo inicial de alli, como en getCurrentNode)
					for (parent in parentsSim(world))
					{
						var parentFile:OverworldFile = fileOf(parent[0]);
						var castle:OverworldNodeFile = findNode(parentFile, parent[1]);
						if (opened(parent[0], parentFile, castle)) { if (reach(parent[0], parent[1])) changed = true; }
						else if (enterFresh(parent[0])) changed = true;
					}
				}
			}
		}

		// fuera las marcas auxiliares de puertas
		for (key in [for (key in reached.keys()) key])
			if (key.endsWith('::door')) reached.remove(key);
		return reached;
	}

	/** Los avisos en texto legible (lista vacia = todo correcto). Ver checkWorldProblems(). */
	public static function checkWorld(file:OverworldFile, ?name:String):Array<String>
		return [for (problem in checkWorldProblems(file, name)) problem.text];

	/**
	 * Revisa el mundo y devuelve sus avisos, cada uno con el nodo al que se refiere (null si es
	 * del mundo entero), para que el editor pueda marcarlos en el mapa.
	 * Mira referencias rotas e IDs repetidos, y con simulateReachable() detecta nodos a los
	 * que nunca se puede llegar aunque tengan a alguien que los desbloquee. Con `name`, ademas
	 * avisa si es un submundo sin ninguna salida.
	 */
	public static function checkWorldProblems(file:OverworldFile, ?name:String):Array<OverworldProblem>
	{
		var problems:Array<OverworldProblem> = [];
		if (file == null || file.nodes.length < 1)
		{
			problems.push({node: null, text: 'El mundo no tiene ningun nodo.'});
			return problems;
		}

		// nodos que ya tienen un aviso concreto: no se repiten como "inalcanzable"
		var flagged:Map<String, Bool> = new Map<String, Bool>();
		inline function warn(id:String, text:String)
		{
			problems.push({node: id, text: text});
			if (id != null) flagged.set(id, true);
		}

		// aviso que se marca en un nodo pero no le quita el de "inalcanzable" (es de un camino suyo)
		inline function note(id:String, text:String)
			problems.push({node: id, text: text});

		var counts:Map<String, Int> = new Map<String, Int>();
		for (node in file.nodes)
		{
			if (!isValidNodeId(node.id))
			{
				warn(node.id, 'Hay un nodo con un ID no valido ("${node.id}").');
				continue;
			}
			counts.set(node.id, counts.exists(node.id) ? counts.get(node.id) + 1 : 1);
		}
		for (id => count in counts)
			if (count > 1) warn(id, '"$id": ID repetido en $count nodos.');

		var linked:Map<String, Bool> = new Map<String, Bool>();
		var pairs:Map<String, Bool> = new Map<String, Bool>();
		for (pth in file.paths)
		{
			if (!counts.exists(pth.a) || !counts.exists(pth.b))
			{
				note(counts.exists(pth.a) ? pth.a : (counts.exists(pth.b) ? pth.b : null), 'Camino ${pth.a} <-> ${pth.b}: apunta a un nodo que no existe.');
				continue;
			}
			if (pth.a == pth.b)
			{
				warn(pth.a, 'Camino de "${pth.a}" a si mismo.');
				continue;
			}

			var key:String = pth.a < pth.b ? '${pth.a}|${pth.b}' : '${pth.b}|${pth.a}';
			if (pairs.exists(key)) note(pth.a, 'Camino ${pth.a} <-> ${pth.b} repetido.');
			pairs.set(key, true);
			linked.set(pth.a, true);
			linked.set(pth.b, true);
		}

		for (node in file.nodes)
		{
			if (!linked.exists(node.id) && file.nodes.length > 1)
				warn(node.id, '"${node.id}": sin caminos, BF no puede llegar ni salir.');

			if (!node.unlocked && !anyoneUnlocks(file, node.id) && !opensByPartner(name, node))
				warn(node.id, '"${node.id}": bloqueado y nadie lo desbloquea.');

			// warp: tuberia de ida y vuelta con un warp del mundo destino que apunte aqui
			if (node.type == 'warp')
			{
				var dest:OverworldFile = (node.world != null && node.world.length > 0) ? loadCached(node.world) : null;
				var partner:OverworldNodeFile = (dest != null && name != null) ? warpPartner(name, node) : null;
				if (dest == null) warn(node.id, '"${node.id}": el warp no tiene mundo destino o ese mundo no existe.');
				else if (name != null && partner == null)
					warn(node.id, '"${node.id}": "${node.world}" no tiene ningun warp que vuelva aqui, asi que BF aparecera alli en su nodo inicial.');
				// los dos extremos esperando al otro: ninguno se abre nunca
				else if (partner != null && !node.unlocked && !anyoneUnlocks(file, node.id) && !partner.unlocked && !anyoneUnlocks(dest, partner.id))
					warn(node.id, '"${node.id}": ni este warp ni su pareja de "${node.world}" se abren nunca: que algo desbloquee uno de los dos (p. ej. el castillo).');
			}

			if (node.type == 'level' && (node.song == null || node.song.length < 1))
				warn(node.id, '"${node.id}": es un nivel sin cancion.');

			if (node.type == 'world')
			{
				var target:OverworldFile = (node.world != null && node.world.length > 0) ? loadCached(node.world) : null;
				if (target == null) warn(node.id, '"${node.id}": apunta a un mundo que no existe.');
				else if (name != null && node.world == name)
					warn(node.id, '"${node.id}": lleva a este mismo mundo, asi que nunca se completa.');
				else if (!Lambda.exists(target.nodes, n -> canBeCompleted(n)))
					warn(node.id, '"${node.id}": el mundo "${node.world}" no tiene nada que superar, asi que este nodo nunca se completa.');
				// dos nodos 'world' que se apuntan entre si: el padre pareceria hijo de su hijo
				else if (name != null && Lambda.exists(target.nodes, n -> n.type == 'world' && n.world == name))
					warn(node.id, '"${node.id}": "${node.world}" tiene a su vez un nodo "world" que vuelve aqui. Para volver de un submundo usa una salida "exit" sin destino.');
				// el castillo solo se completa si se puede superar todo lo de dentro
				else if (!worldClearable(node.world, name != null ? [name] : []))
					warn(node.id, '"${node.id}": "${node.world}" no se puede superar entero (tiene algo inalcanzable dentro), asi que este nodo nunca se completa ni abre lo suyo.');
			}

			// dos warps (o dos salidas con destino) hacia el mismo mundo: las parejas y las
			// llegadas se buscan por mundo, asi que siempre ganaria el primero
			if ((node.type == 'warp' || node.type == 'exit') && node.world != null && node.world.length > 0)
			{
				var first:OverworldNodeFile = Lambda.find(file.nodes, n -> n.type == node.type && n.world == node.world);
				if (first != null && first != node)
					warn(node.id, '"${node.id}": ya hay otro ${node.type} hacia "${node.world}" ("${first.id}"). Solo se empareja el primero: usa uno por mundo.');
			}

			// salida con destino: transicion de lado a otro mundo
			if (node.type == 'exit' && node.world != null && node.world.length > 0)
			{
				var dest:OverworldFile = loadCached(node.world);
				var back:OverworldNodeFile = (dest != null && name != null) ? Lambda.find(dest.nodes, n -> n.type == 'exit' && n.world == name) : null;
				if (dest == null) warn(node.id, '"${node.id}": la salida lleva a "${node.world}", que no existe.');
				else if (name != null && back == null)
					warn(node.id, '"${node.id}": "${node.world}" no tiene ninguna salida de vuelta hacia aqui, asi que BF aparecera alli en su nodo inicial.');
			}

			// salida sin destino: vuelve al mapa de fuera, que sale de la pila o del castillo que lleva
			// aqui. Si no hay castillo ni se llega de lado desde otro mapa, no tiene a donde volver.
			if (node.type == 'exit' && (node.world == null || node.world.length < 1) && name != null
				&& parentsOf(name).length < 1 && nodesInto(name, 'exit').length < 1)
				warn(node.id, '"${node.id}": salida sin "Mundo destino", pero ningun castillo lleva a este mundo: no sabria a donde volver.');

			if (node.unlocks == null || node.unlocks.length < 1) continue;

			for (target in node.unlocks)
			{
				if (target == node.id) warn(node.id, '"${node.id}": se desbloquea a si mismo.');
				else if (!counts.exists(target)) warn(node.id, '"${node.id}": desbloquea "$target", que no existe.');
			}

			if (!canBeCompleted(node))
				warn(node.id, '"${node.id}": es "${node.type}" y nunca se completa, asi que no desbloquea nada.');
		}

		// un submundo sin salida deja a BF encerrado: ESC ya no saca de el
		if (name != null && !Lambda.exists(file.nodes, n -> n.type == 'exit'))
		{
			var parent:Array<String> = findParentWorld(name);
			if (parent != null)
				warn(null, 'Es un submundo (se entra desde "${parent[0]}") y no tiene ningun nodo "exit": BF no podria salir.');
		}

		// un submundo con castillos en varios mapas: superarlo completa todos, y una salida sin
		// pila (tras llegar por un warp) vuelve siempre al primero
		if (name != null)
		{
			var parentNames:Array<String> = [];
			for (parent in parentsOf(name))
				if (!parentNames.contains(parent[0])) parentNames.push(parent[0]);
			if (parentNames.length > 1)
				warn(null, 'Se entra a este mundo desde varios mapas (${parentNames.join(', ')}): superarlo completa los castillos de todos, y una salida sin destino vuelve a "${parentNames[0]}" si no se entro por un castillo.');
		}

		var start:OverworldNodeFile = findNode(file, file.startNode);
		if (start == null) warn(null, 'El nodo inicial "${file.startNode}" no existe.');
		else if (!openAtStart(name, start)) warn(start.id, 'El nodo inicial "${start.id}" no esta desbloqueado al empezar.');
		else if (start.type == 'exit') warn(start.id, 'El nodo inicial "${start.id}" es una salida: BF apareceria en ella (suelen estar fuera de pantalla).');

		if (firstStartNode(file, name) == null)
		{
			warn(null, 'Ningun nodo esta desbloqueado al empezar: BF no tiene donde aparecer.');
			return problems;
		}

		clearableCache.clear(); // los submundos se miran de nuevo en cada revision
		var reached:Map<String, Bool> = simulateReachable(file, name);
		for (node in file.nodes)
			if (!reached.exists(node.id) && !flagged.exists(node.id))
			{
				problems.push({node: node.id, text: '"${node.id}": inalcanzable aunque completes todo lo que se puede.'});
				flagged.set(node.id, true);
			}

		// la partida entera, mundo a mundo: encuentra lo que solo se abre desde otro mundo al que
		// no se llega antes (p. ej. un warp que solo abre un nivel al que solo se llega por el)
		var first:String = gameStartWorld();
		if (name != null && (name == first || exists(first)))
		{
			var closedDoors:Array<String> = [];
			var game:Map<String, Bool> = simulateGame(name, file, closedDoors);
			for (node in file.nodes)
			{
				if (!closedDoors.contains('$name::${node.id}')) continue;
				var dest:OverworldFile = loadCached(node.world);
				var back:OverworldNodeFile = dest == null ? null : Lambda.find(dest.nodes, n -> n.type == 'exit' && n.world == name);
				note(node.id, '"${node.id}": se puede pisar antes de que se abra su salida de vuelta en "${node.world}"'
					+ (back != null ? ' ("${back.id}")' : '') + ': BF llegaria alli a su nodo inicial.');
			}
			if (!Lambda.exists(file.nodes, n -> game.exists('$name::${n.id}')))
				note(null, 'Jugando desde el principio (desde "$first") nunca se llega a este mundo: enlazalo con un castillo, una salida o un warp.');
			else
			{
				for (node in file.nodes)
					if (!flagged.exists(node.id) && !game.exists('$name::${node.id}'))
						problems.push({node: node.id, text: '"${node.id}": jugando desde el principio nunca se llega (lo que lo abre esta en otro mundo al que no se llega antes, o se espera a si mismo).'});
			}
		}

		return problems;
	}

	// ------------------------------------------------------------------ listados

	/** Los mundos que hay en disco (en cache hasta el siguiente clearWorldCache). No modificar la lista. */
	public static function listWorlds():Array<String>
	{
		if (worldListCache == null) worldListCache = readWorldList();
		return worldListCache;
	}

	static function readWorldList():Array<String>
	{
		var list:Array<String> = [];
		#if sys
		for (dir in Mods.directoriesWithFile(Paths.getSharedPath(), '$FOLDER/'))
		{
			for (file in FileSystem.readDirectory(dir))
			{
				if (!file.toLowerCase().endsWith('.json')) continue;

				var name:String = file.substr(0, file.length - 5);
				if (!list.contains(name)) list.push(name);
			}
		}
		#end
		sortStrings(list);
		return list;
	}

	public static function listImages(?folder:String = 'overworld'):Array<String>
	{
		var list:Array<String> = [];
		#if sys
		for (dir in Mods.directoriesWithFile(Paths.getSharedPath(), 'images/$folder/'))
			scanImages(dir, folder, list);
		#end
		sortStrings(list);
		return list;
	}

	#if sys
	static function scanImages(dir:String, prefix:String, list:Array<String>)
	{
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return;

		for (file in FileSystem.readDirectory(dir))
		{
			var full:String = dir + file;
			if (FileSystem.isDirectory(full)) scanImages(full + '/', '$prefix/$file', list);
			else if (file.toLowerCase().endsWith('.png'))
			{
				var key:String = '$prefix/' + file.substr(0, file.length - 4);
				if (!list.contains(key)) list.push(key);
			}
		}
	}
	#end

	static var animCache:Map<String, Array<String>> = new Map<String, Array<String>>();

	/**
	 * Prefijos de animacion de un atlas Sparrow (quita los digitos del final). Va en cache: el
	 * editor lo pide en cada seleccion, y un atlas de 2000 tiles es un XML grande de analizar.
	 * Se devuelve una copia para que quien la reciba pueda modificarla.
	 */
	public static function listAnimations(image:String):Array<String>
	{
		if (image == null || image.length < 1) return [];
		if (!animCache.exists(image)) animCache.set(image, readAnimations(image));
		return animCache.get(image).copy();
	}

	static function readAnimations(image:String):Array<String>
	{
		var list:Array<String> = [];
		var txt:String = Paths.getTextFromFile('images/$image.xml');
		if (txt == null) return list;

		var reg:EReg = ~/name="([^"]*)"/;
		var pos:Int = 0;
		while (pos < txt.length && reg.matchSub(txt, pos))
		{
			var matched:String = reg.matched(1);
			var found = reg.matchedPos();
			pos = found.pos + found.len;

			var end:Int = matched.length;
			while (end > 0)
			{
				var code:Null<Int> = matched.charCodeAt(end - 1);
				if (code != null && code >= 48 && code <= 57) end--;
				else break;
			}

			var prefix:String = matched.substr(0, end);
			if (prefix.length > 0 && !list.contains(prefix)) list.push(prefix);
		}
		return list;
	}

	// ------------------------------------------------- info y categoria de imagen

	static var infoCache:Map<String, OverworldImageInfo> = new Map<String, OverworldImageInfo>();

	public static function clearImageCache()
	{
		infoCache.clear();
		animCache.clear();
		atlasCache.clear();
		imageCache.clear();
	}

	/** Tamaño, numero de frames y animaciones de una imagen (con o sin atlas). */
	public static function imageInfo(key:String):OverworldImageInfo
	{
		if (infoCache.exists(key)) return infoCache.get(key);

		var info:OverworldImageInfo = {width: 0, height: 0, frameWidth: 0, frameHeight: 0, frameCount: 0, anims: []};

		var xml:String = Paths.getTextFromFile('images/$key.xml');
		if (xml != null && xml.length > 0)
		{
			info.anims = listAnimations(key);

			// el frame sin recortar manda: es el tamaño "real" del dibujo
			var frameReg:EReg = ~/frameWidth="(-?[0-9]+)"[^>]*frameHeight="(-?[0-9]+)"/;
			if (frameReg.match(xml))
			{
				info.frameWidth = Std.parseInt(frameReg.matched(1));
				info.frameHeight = Std.parseInt(frameReg.matched(2));
			}

			if (info.frameWidth <= 0 || info.frameHeight <= 0)
			{
				var sizeReg:EReg = ~/ width="([0-9]+)"[^>]*height="([0-9]+)"/;
				if (sizeReg.match(xml))
				{
					info.frameWidth = Std.parseInt(sizeReg.matched(1));
					info.frameHeight = Std.parseInt(sizeReg.matched(2));
				}
			}

			var subReg:EReg = ~/<SubTexture/;
			var pos:Int = 0;
			while (pos < xml.length && subReg.matchSub(xml, pos))
			{
				info.frameCount++;
				var found = subReg.matchedPos();
				pos = found.pos + found.len;
			}
		}

		readPngSize(key, info);

		if (info.frameWidth <= 0 || info.frameHeight <= 0)
		{
			info.frameWidth = info.width;
			info.frameHeight = info.height;
		}
		if (info.frameCount < 1) info.frameCount = 1;

		infoCache.set(key, info);
		return info;
	}

	static function readPngSize(key:String, info:OverworldImageInfo)
	{
		#if sys
		var path:String = Paths.getPath('images/$key.png', IMAGE);
		if (!FileSystem.exists(path)) return;

		try
		{
			var bytes:haxe.io.Bytes = File.getBytes(path);
			if (bytes.length < 24) return;

			// cabecera IHDR de PNG: ancho y alto en big endian
			info.width = (bytes.get(16) << 24) | (bytes.get(17) << 16) | (bytes.get(18) << 8) | bytes.get(19);
			info.height = (bytes.get(20) << 24) | (bytes.get(21) << 16) | (bytes.get(22) << 8) | bytes.get(23);
		}
		catch (e:Dynamic) {}
		#end
	}

	/**
	 * Clasifica una imagen para poder filtrar los desplegables del editor:
	 * 'player' (tiene animaciones de andar), 'bg' (dibujo grande) o 'node' (el resto).
	 */
	public static function categoryOf(key:String):String
	{
		var info:OverworldImageInfo = imageInfo(key);

		for (anim in info.anims)
			if (anim.toLowerCase().indexOf('walk') > -1) return 'player';

		if (info.frameWidth >= 120 && info.frameHeight >= 90) return 'bg';
		return 'node';
	}

	public static function filterImages(images:Array<String>, category:String):Array<String>
	{
		var result:Array<String> = [];
		for (image in images)
			if (categoryOf(image) == category) result.push(image);
		return result;
	}

	// Si existe la imagen / su atlas, por clave. buildSprite lo pregunta por cada sprite, y con
	// miles de tiles pintados las comprobaciones de disco eran la mayor parte de cargar un mapa.
	static var atlasCache:Map<String, Bool> = new Map<String, Bool>();
	static var imageCache:Map<String, Bool> = new Map<String, Bool>();

	public static function hasAtlas(image:String):Bool
	{
		if (image == null || image.length < 1) return false;
		if (atlasCache.exists(image)) return atlasCache.get(image);

		var found:Bool = false;
		#if sys
		found = FileSystem.exists(Paths.getPath('images/$image.xml', TEXT));
		#end
		if (!found) found = Paths.fileExists('images/$image.xml', TEXT);
		atlasCache.set(image, found);
		return found;
	}

	public static function imageExists(image:String):Bool
	{
		if (image == null || image.length < 1) return false;
		if (imageCache.exists(image)) return imageCache.get(image);

		var found:Bool = false;
		#if sys
		found = FileSystem.exists(Paths.getPath('images/$image.png', IMAGE));
		#end
		if (!found) found = Paths.fileExists('images/$image.png', IMAGE);
		imageCache.set(image, found);
		return found;
	}

	public static function listSongs():Array<String>
	{
		var list:Array<String> = [];

		WeekData.reloadWeekFiles(null);
		for (weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if (week == null || week.songs == null) continue;

			for (raw in week.songs)
			{
				var songData:Array<Dynamic> = cast raw;
				if (songData == null || songData.length < 1) continue;

				var name:String = Paths.formatToSongPath(Std.string(songData[0]));
				if (name.length > 0 && !list.contains(name)) list.push(name);
			}
		}

		#if sys
		for (dir in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/'))
		{
			for (file in FileSystem.readDirectory(dir))
			{
				var full:String = dir + file;
				if (!FileSystem.isDirectory(full)) continue;
				if (list.contains(file)) continue;

				// vale cualquier chart de la cancion, lleve sufijo de dificultad o no
				var lowerName:String = file.toLowerCase();
				for (chart in FileSystem.readDirectory(full))
				{
					var lowerChart:String = chart.toLowerCase();
					if (lowerChart.endsWith('.json') && lowerChart.startsWith(lowerName))
					{
						list.push(file);
						break;
					}
				}
			}
		}
		#end

		sortStrings(list);
		return list;
	}

	/** Solo las canciones que declara esa semana, en su orden. Sin semana, todas las de la build. */
	/**
	 * Canciones de una semana (sin semana: todas las de la build). En cache hasta el siguiente
	 * clearWorldCache(): el editor la pide en cada nodo que se elige, y leer todas las semanas y
	 * carpetas de charts cada vez se notaba.
	 */
	public static function listSongsOfWeek(week:String):Array<String>
	{
		var key:String = week == null ? '' : week;
		if (!songsCache.exists(key)) songsCache.set(key, readSongsOfWeek(week));
		return songsCache.get(key).copy();
	}

	static var songsCache:Map<String, Array<String>> = new Map<String, Array<String>>();

	static function readSongsOfWeek(week:String):Array<String>
	{
		if (week == null || week.length < 1) return listSongs();

		WeekData.reloadWeekFiles(null);

		var data:WeekData = WeekData.weeksLoaded.get(week);
		if (data == null || data.songs == null) return [];

		var list:Array<String> = [];
		for (raw in data.songs)
		{
			var songData:Array<Dynamic> = cast raw;
			if (songData == null || songData.length < 1) continue;

			var name:String = Paths.formatToSongPath(Std.string(songData[0]));
			if (name.length > 0 && !list.contains(name)) list.push(name);
		}

		return list;
	}

	public static function listWeeks():Array<String>
	{
		WeekData.reloadWeekFiles(null);
		return WeekData.weeksList.copy();
	}

	static function sortStrings(list:Array<String>)
		list.sort(function(a:String, b:String):Int return a < b ? -1 : (a > b ? 1 : 0));
}
