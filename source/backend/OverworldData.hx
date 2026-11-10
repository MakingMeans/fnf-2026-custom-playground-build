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
	var type:String;        // 'level' | 'world' | 'empty'
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
	public static final DEFAULT_WORLD:String = 'draft_world';
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

	public static function applyDefaults(file:OverworldFile)
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

		var spriteBase:OverworldSpriteFile = createSprite('', 0, 0);
		for (spr in file.sprites)
			for (field in Reflect.fields(spriteBase))
				if (Reflect.field(spr, field) == null)
					Reflect.setField(spr, field, Reflect.field(spriteBase, field));

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

	/** Un nodo esta accesible si empieza desbloqueado o si algo ya completado lo desbloquea. */
	public static function isUnlocked(world:String, file:OverworldFile, node:OverworldNodeFile):Bool
	{
		if (node == null) return false;
		if (node.unlocked) return true;

		for (other in file.nodes)
			if (other.unlocks != null && other.unlocks.contains(node.id) && isCompleted(world, other.id))
				return true;

		return false;
	}

	// ------------------------------------------------------------- revision del grafo

	/** Algun nodo lista este id en sus `unlocks`. */
	public static function anyoneUnlocks(file:OverworldFile, id:String):Bool
	{
		for (other in file.nodes)
			if (other.unlocks != null && other.unlocks.contains(id)) return true;
		return false;
	}

	/** Solo los niveles se completan (al acabar su cancion); 'world' y 'empty' nunca. */
	public static inline function canBeCompleted(node:OverworldNodeFile):Bool
		return node.type == 'level' && node.song != null && node.song.length > 0;

	/** Un ID valido para un nodo: no vacio, sin comas (separan la lista de unlocks) y sin '::' (clave del progreso). */
	public static function isValidNodeId(id:String):Bool
		return id != null && id.length > 0 && id.indexOf(',') < 0 && id.indexOf('::') < 0;

	/** El nodo donde aparece BF con el progreso a cero (misma regla que OverworldState). */
	public static function firstStartNode(file:OverworldFile):OverworldNodeFile
	{
		var start:OverworldNodeFile = findNode(file, file.startNode);
		if (start != null && start.unlocked) return start;

		for (node in file.nodes)
			if (node.unlocked) return node;
		return null;
	}

	/**
	 * Simula una partida completa desde cero: BF sale del nodo inicial, recorre todo lo que
	 * tiene accesible, completa cada nivel al que llega y aplica sus desbloqueos, hasta que ya
	 * no se abre nada nuevo. Devuelve los ids de los nodos a los que se acaba pudiendo llegar.
	 */
	public static function simulateReachable(file:OverworldFile):Map<String, Bool>
	{
		var reached:Map<String, Bool> = new Map<String, Bool>();
		var start:OverworldNodeFile = firstStartNode(file);
		if (start == null) return reached;

		var open:Map<String, Bool> = new Map<String, Bool>();
		for (node in file.nodes)
			if (node.unlocked) open.set(node.id, true);

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

	/**
	 * Revisa el mundo y devuelve los avisos en texto legible (lista vacia = todo correcto).
	 * Mira referencias rotas e IDs repetidos, y con simulateReachable() detecta nodos a los
	 * que nunca se puede llegar aunque tengan a alguien que los desbloquee.
	 */
	public static function checkWorld(file:OverworldFile):Array<String>
	{
		var problems:Array<String> = [];
		if (file == null || file.nodes.length < 1)
		{
			problems.push('El mundo no tiene ningun nodo.');
			return problems;
		}

		// nodos que ya tienen un aviso concreto: no se repiten como "inalcanzable"
		var flagged:Map<String, Bool> = new Map<String, Bool>();
		inline function warn(id:String, text:String)
		{
			problems.push(text);
			if (id != null) flagged.set(id, true);
		}

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
				warn(null, 'Camino ${pth.a} <-> ${pth.b}: apunta a un nodo que no existe.');
				continue;
			}
			if (pth.a == pth.b)
			{
				warn(pth.a, 'Camino de "${pth.a}" a si mismo.');
				continue;
			}

			var key:String = pth.a < pth.b ? '${pth.a}|${pth.b}' : '${pth.b}|${pth.a}';
			if (pairs.exists(key)) warn(null, 'Camino ${pth.a} <-> ${pth.b} repetido.');
			pairs.set(key, true);
			linked.set(pth.a, true);
			linked.set(pth.b, true);
		}

		for (node in file.nodes)
		{
			if (!linked.exists(node.id) && file.nodes.length > 1)
				warn(node.id, '"${node.id}": sin caminos, BF no puede llegar ni salir.');

			if (!node.unlocked && !anyoneUnlocks(file, node.id))
				warn(node.id, '"${node.id}": bloqueado y nadie lo desbloquea.');

			if (node.type == 'level' && (node.song == null || node.song.length < 1))
				warn(node.id, '"${node.id}": es un nivel sin cancion.');

			if (node.type == 'world' && (node.world == null || node.world.length < 1 || !exists(node.world)))
				warn(node.id, '"${node.id}": apunta a un mundo que no existe.');

			if (node.unlocks == null || node.unlocks.length < 1) continue;

			for (target in node.unlocks)
			{
				if (target == node.id) warn(node.id, '"${node.id}": se desbloquea a si mismo.');
				else if (!counts.exists(target)) warn(node.id, '"${node.id}": desbloquea "$target", que no existe.');
			}

			if (!canBeCompleted(node))
				warn(node.id, '"${node.id}": es "${node.type}" y nunca se completa, asi que no desbloquea nada.');
		}

		var start:OverworldNodeFile = findNode(file, file.startNode);
		if (start == null) warn(null, 'El nodo inicial "${file.startNode}" no existe.');
		else if (!start.unlocked) warn(start.id, 'El nodo inicial "${start.id}" no esta desbloqueado al empezar.');

		if (firstStartNode(file) == null)
		{
			warn(null, 'Ningun nodo esta desbloqueado al empezar: BF no tiene donde aparecer.');
			return problems;
		}

		var reached:Map<String, Bool> = simulateReachable(file);
		for (node in file.nodes)
			if (!reached.exists(node.id) && !flagged.exists(node.id))
				problems.push('"${node.id}": inalcanzable aunque completes todo lo que se puede.');

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

	/** Prefijos de animacion de un atlas Sparrow (quita los digitos del final). */
	public static function listAnimations(image:String):Array<String>
	{
		var list:Array<String> = [];
		if (image == null || image.length < 1) return list;

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
		infoCache.clear();

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
