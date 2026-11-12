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

		if (file.nodes == null) file.nodes = [];
		if (file.sprites == null) file.sprites = [];
		if (file.paths == null) file.paths = [];

		var nodeBase:OverworldNodeFile = createNode('', 0, 0);
		for (node in file.nodes)
		{
			for (field in Reflect.fields(nodeBase))
				if (Reflect.field(node, field) == null)
					Reflect.setField(node, field, Reflect.field(nodeBase, field));
			if (node.unlocks == null) node.unlocks = [];
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
			if (pth.points == null) pth.points = [];
		}

		if (file.gridSize < 1) file.gridSize = 16;
		if (file.zoom <= 0) file.zoom = 3;
		if (file.walkSpeed <= 0) file.walkSpeed = 60;
	}

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
		if (FlxG.save.data.overworldProgress == null)
			FlxG.save.data.overworldProgress = new Map<String, Bool>();
		return FlxG.save.data.overworldProgress;
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

	/**
	 * Olvida los mundos leidos de disco para consultar otros mundos (parejas, castillos, padres).
	 * Llamar al entrar a un mapa y despues de guardar: un mundo pintado son cientos de KB, y
	 * releerlos todos en cada comprobacion se notaba.
	 */
	public static function clearWorldCache()
		worldCache.clear();

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
		for (world in listWorlds())
		{
			if (world == name) continue;
			var file:OverworldFile = loadCached(world);
			if (file == null) continue;

			for (node in file.nodes)
				if (node.type == 'world' && node.world == name) return [world, node.id];
		}
		return null;
	}

	/** Al renombrar un nodo, su progreso pasa al ID nuevo (y un nodo futuro con el viejo no lo hereda). */
	public static function renameProgress(world:String, oldId:String, newId:String)
	{
		if (world == null || !isCompleted(world, oldId)) return;
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
	 * (en un mundo central todos los warps son asi y ninguno empieza abierto).
	 */
	static inline function openAtStart(name:String, node:OverworldNodeFile):Bool
		return node.unlocked || (opensByPartner(name, node) && node.type == 'warp');

	/** El nodo donde aparece BF con el progreso a cero (misma regla que OverworldState). */
	public static function firstStartNode(file:OverworldFile, ?name:String):OverworldNodeFile
	{
		var start:OverworldNodeFile = findNode(file, file.startNode);
		if (start != null && openAtStart(name, start)) return start;

		for (node in file.nodes)
			if (openAtStart(name, node)) return node;
		return null;
	}

	/**
	 * Simula una partida completa desde cero: BF sale del nodo inicial, recorre todo lo que
	 * tiene accesible, completa cada nivel al que llega y aplica sus desbloqueos, hasta que ya
	 * no se abre nada nuevo. Devuelve los ids de los nodos a los que se acaba pudiendo llegar.
	 */
	public static function simulateReachable(file:OverworldFile, ?name:String):Map<String, Bool>
	{
		var reached:Map<String, Bool> = new Map<String, Bool>();
		var start:OverworldNodeFile = firstStartNode(file, name);
		if (start == null) return reached;

		// los warps que solo se abren por su pareja se dan por abiertos: depende de otro mundo
		var open:Map<String, Bool> = new Map<String, Bool>();
		for (node in file.nodes)
			if (node.unlocked || (node.type == 'warp' && opensByPartner(name, node) && !anyoneUnlocks(file, node.id)))
				open.set(node.id, true);

		var changed:Bool = true;
		while (changed)
		{
			changed = false;

			// recorrido por caminos pisando solo nodos accesibles; en cada vuelta se sigue
			// desde todo lo ya alcanzado, que es donde pueden haber aparecido caminos nuevos
			reached.set(start.id, true);
			var pending:Array<String> = [for (id in reached.keys()) id];
			while (pending.length > 0)
			{
				var id:String = pending.pop();

				// pisar una salida saca del mapa: no se sigue andando a traves de ella
				var here:OverworldNodeFile = findNode(file, id);
				if (here != null && here.type == 'exit' && id != start.id) continue;

				for (pth in file.paths)
				{
					var other:String = (pth.a == id) ? pth.b : ((pth.b == id) ? pth.a : null);
					if (other == null || reached.exists(other) || !open.exists(other)) continue;
					if (findNode(file, other) == null) continue;

					reached.set(other, true);
					pending.push(other);
				}
			}

			// completar todos los niveles alcanzados abre sus desbloqueos
			for (node in file.nodes)
			{
				if (!reached.exists(node.id) || !canBeCompleted(node) || node.unlocks == null) continue;
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
				else if (!Lambda.exists(target.nodes, n -> canBeCompleted(n)))
					warn(node.id, '"${node.id}": el mundo "${node.world}" no tiene nada que superar, asi que este nodo nunca se completa.');
				// dos nodos 'world' que se apuntan entre si: el padre pareceria hijo de su hijo
				else if (name != null && Lambda.exists(target.nodes, n -> n.type == 'world' && n.world == name))
					warn(node.id, '"${node.id}": "${node.world}" tiene a su vez un nodo "world" que vuelve aqui. Para volver de un submundo usa una salida "exit" sin destino.');
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
				if (dest == null) warn(node.id, '"${node.id}": la salida lleva a "${node.world}", que no existe.');
				else if (name != null && !Lambda.exists(dest.nodes, n -> n.type == 'exit' && n.world == name))
					warn(node.id, '"${node.id}": "${node.world}" no tiene ninguna salida de vuelta hacia aqui, asi que BF aparecera alli en su nodo inicial.');
			}

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

		var start:OverworldNodeFile = findNode(file, file.startNode);
		if (start == null) warn(null, 'El nodo inicial "${file.startNode}" no existe.');
		else if (!openAtStart(name, start)) warn(start.id, 'El nodo inicial "${start.id}" no esta desbloqueado al empezar.');

		if (firstStartNode(file, name) == null)
		{
			warn(null, 'Ningun nodo esta desbloqueado al empezar: BF no tiene donde aparecer.');
			return problems;
		}

		var reached:Map<String, Bool> = simulateReachable(file, name);
		for (node in file.nodes)
			if (!reached.exists(node.id) && !flagged.exists(node.id))
				problems.push({node: node.id, text: '"${node.id}": inalcanzable aunque completes todo lo que se puede.'});

		return problems;
	}

	// ------------------------------------------------------------------ listados

	public static function listWorlds():Array<String>
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

	public static function hasAtlas(image:String):Bool
	{
		if (image == null || image.length < 1) return false;

		#if sys
		if (FileSystem.exists(Paths.getPath('images/$image.xml', TEXT))) return true;
		#end
		return Paths.fileExists('images/$image.xml', TEXT);
	}

	public static function imageExists(image:String):Bool
	{
		if (image == null || image.length < 1) return false;

		#if sys
		if (FileSystem.exists(Paths.getPath('images/$image.png', IMAGE))) return true;
		#end
		return Paths.fileExists('images/$image.png', IMAGE);
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
	public static function listSongsOfWeek(week:String):Array<String>
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
