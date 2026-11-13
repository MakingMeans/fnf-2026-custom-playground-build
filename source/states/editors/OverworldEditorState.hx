package states.editors;

import backend.OverworldData;
import backend.WeekData;

import states.OverworldState;
import states.editors.content.FileDialogHandler;

import flixel.FlxObject;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSpriteUtil;
import openfl.display.BitmapData;

import flash.net.FileFilter;

/**
 * Editor de mundos estilo Super Mario World.
 * Dibuja el mapa, coloca nodos (niveles / entradas a otros mundos), los une con caminos
 * y guarda todo en assets/shared/overworlds/<mundo>.json
 */
class OverworldEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	static inline var MODE_SELECT:Int = 0;
	static inline var MODE_NODE:Int = 1;
	static inline var MODE_DECOR:Int = 2;
	static inline var MODE_PATH:Int = 3;
	static inline var MODE_TILE:Int = 4;
	static inline var MODE_LINK:Int = 5;

	static final MODE_NAMES:Array<String> = ['SELECCIONAR (V)', 'NODO (N)', 'DECORADO (B)', 'CAMINO (C)', 'PINTAR TILES (T)', 'ENLAZAR DESBLOQUEOS (L)'];

	static inline var PALETTE_WIDTH:Int = 300;

	var worldName:String = 'nuevo_mundo';

	/** El archivo del que salio el mundo abierto: guardar con otro nombre que ya exista pide confirmacion. */
	var loadedName:String = null;
	var worldFile:OverworldFile;

	var camGame:FlxCamera;
	var camHUD:FlxCamera;

	var bgSprite:FlxSprite;
	var bgSprites:Array<FlxSprite> = [];
	var gridSprite:FlxSprite;
	var linesSprite:FlxSprite;
	var dotsGroup:FlxTypedGroup<FlxSprite>;
	var spritesBack:FlxTypedGroup<FlxSprite>;
	var spritesFront:FlxTypedGroup<FlxSprite>;
	var nodesGroup:FlxTypedGroup<FlxSprite>;
	var labelsGroup:FlxTypedGroup<FlxText>;
	var selectionBox:FlxSprite;
	var playerMarker:FlxSprite;

	var mapWidth:Float = 800;
	var mapHeight:Float = 600;

	var curMode:Int = MODE_SELECT;
	var selectedNode:OverworldNodeFile;
	var selectedSprite:OverworldSpriteFile;
	var selectedPath:OverworldPathFile;
	var pathStart:OverworldNodeFile;
	var dragging:Bool = false;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;
	var unsavedProgress:Bool = false;

	// valores que heredan los objetos nuevos
	var lastNodeImage:String = 'overworld/dot';
	var lastNodeAnim:String = 'idle';
	var lastNodeFps:Int = 6;
	var lastNodeType:String = 'level';
	var lastDecorImage:String = '';
	var lastDecorAnim:String = '';

	var fileDialog:FileDialogHandler;

	// deshacer / rehacer
	var undoStack:Array<String> = [];
	var redoStack:Array<String> = [];
	var dragSnapshot:String = null;
	static inline var MAX_UNDO:Int = 40;

	// deshacer en la UI: un campo de texto da un paso por cada vez que se entra en el; los clics
	// seguidos en desplegables / casillas / botones +- sobre lo mismo se juntan en un paso
	var lastFocus:PsychUIInputText = null;
	var focusBefore:String = null;
	var focusRecorded:Bool = false;
	var lastUIEditTime:Float = -999;
	var lastUITarget:Dynamic = null;
	static inline final UI_EDIT_GAP:Float = 1.2;

	// modo enlazar (L): el nodo que desbloquea
	var linkStart:OverworldNodeFile = null;

	// punto de curva que se esta arrastrando: [camino, indice]
	var dragPointPath:OverworldPathFile = null;
	var dragPointIndex:Int = -1;

	// avisos de checkWorld marcados sobre el mapa
	var problems:Array<OverworldProblem> = [];
	var problemsDirty:Bool = true;
	var problemsTimer:Float = 0;
	var problemCursor:Int = -1;
	var problemGroup:FlxTypedGroup<FlxSprite>;

	// desplegables: el que se abre pasa al frente para que no lo tape nada
	var dropDowns:Array<PsychUIDropDownMenu> = [];
	var dropDownGroups:Array<FlxSpriteGroup> = [];
	var lastFocused:Dynamic = null;

	// paleta de tiles
	var camPalette:FlxCamera;
	var paletteGroup:FlxSpriteGroup;
	var paletteCursor:FlxSprite;
	var paletteFrames:Array<String> = [];
	var paletteImage:String = '';
	var paletteTileSize:Int = 16;
	var paletteCell:Int = 34;
	var paletteColumns:Int = 8;
	var paletteSelected:Int = -1;
	var paletteScrollMax:Float = 0;
	var paletteShown:Bool = true;
	var paintFront:Bool = false;

	// seleccion en grupo (SHIFT+clic o un rectangulo arrastrando en el vacio, modo V): se mueven,
	// duplican (CTRL+D) y borran (SUPR) a la vez. Con un solo elemento no hay grupo.
	var groupNodes:Array<OverworldNodeFile> = [];
	var groupSprites:Array<OverworldSpriteFile> = [];
	var groupBoxes:FlxTypedGroup<FlxSprite>;
	var bandSprite:FlxSprite;
	var bandStart:Array<Float> = null;
	var groupDragLast:Array<Float> = null; // posicion (ajustada) del elemento agarrado
	var groupDragSprites:haxe.ds.ObjectMap<Dynamic, FlxSprite> = null;

	// al unir dos nodos que no estan alineados, el camino se hace en L
	var lPaths:Bool = true;

	// progreso de los nodos que han desaparecido en esta sesion: deshacer se lo devuelve
	var removedProgress:Map<String, Bool> = new Map<String, Bool>();

	// submundos creados con "Crear submundo" en esta sesion: [nombre => contenido al crearlo]
	var createdWorlds:Map<String, String> = new Map<String, String>();

	public function new(?world:String = null)
	{
		if (world != null && world.length > 0) worldName = world;
		super();
	}

	// ------------------------------------------------------------------ create
	override function create()
	{
		camGame = initPsychCamera();

		camPalette = new FlxCamera(0, 96, PALETTE_WIDTH, FlxG.height - 156);
		camPalette.bgColor = 0xEE14141E;
		FlxG.cameras.add(camPalette, false);

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		FlxG.mouse.visible = true;
		FlxG.camera.bgColor = 0xFF1A1A28;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Editor de Mundos', worldName);
		#end

		fileDialog = new FileDialogHandler();
		add(fileDialog);

		OverworldData.clearWorldCache();
		OverworldState.clearSpriteCache();
		worldFile = OverworldData.load(worldName);
		if (worldFile != null) loadedName = worldName;
		else worldFile = OverworldData.createEmpty();

		spritesBack = new FlxTypedGroup<FlxSprite>();
		dotsGroup = new FlxTypedGroup<FlxSprite>();
		nodesGroup = new FlxTypedGroup<FlxSprite>();
		spritesFront = new FlxTypedGroup<FlxSprite>();
		labelsGroup = new FlxTypedGroup<FlxText>();

		problemGroup = new FlxTypedGroup<FlxSprite>();

		add(spritesBack);
		add(dotsGroup);
		add(nodesGroup);
		add(problemGroup);
		add(spritesFront);
		add(labelsGroup);

		selectionBox = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		selectionBox.color = FlxColor.YELLOW;
		selectionBox.alpha = 0.35;
		selectionBox.visible = false;
		add(selectionBox);

		groupBoxes = new FlxTypedGroup<FlxSprite>();
		add(groupBoxes);

		bandSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		bandSprite.color = 0xFF66CCFF;
		bandSprite.alpha = 0.25;
		bandSprite.visible = false;
		add(bandSprite);

		paletteGroup = new FlxSpriteGroup();
		paletteGroup.cameras = [camPalette];
		add(paletteGroup);

		paletteCursor = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		paletteCursor.color = FlxColor.YELLOW;
		paletteCursor.alpha = 0.4;
		paletteCursor.visible = false;
		paletteCursor.cameras = [camPalette];
		add(paletteCursor);

		buildUI();
		reloadMap();
		updateUI();
		pickDefaultTileset();

		camGame.zoom = worldFile.zoom;
		camGame.scroll.set(mapWidth * 0.5 - FlxG.width * 0.5, mapHeight * 0.5 - FlxG.height * 0.5);

		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.4);

		#if debug // autoprueba de "unir mundos" (-selftest): crea mundos zz_*, los comprueba y los borra
		if (Sys.args().contains('-selftest')) runSelfTest();
		#end

		super.create();
	}

	// ------------------------------------------------------------------ mapa
	/**
	 * Vuelve a crear lo que se ve del mapa a partir de `worldFile`.
	 * `graphOnly` rehace solo nodos, etiquetas, caminos y avisos: es lo que cambia al arrastrar,
	 * enlazar o crear caminos, y no toca los decorados (un mapa pintado puede tener miles de
	 * tiles; rehacerlos en cada pixel de un arrastre lo volvia injugable). El fondo y la rejilla
	 * solo se rehacen si el mapa ha cambiado de tamaño.
	 */
	function reloadMap(?graphOnly:Bool = false)
	{
		OverworldData.applyDefaults(worldFile, !graphOnly);

		var oldWidth:Float = mapWidth;
		var oldHeight:Float = mapHeight;
		if (!graphOnly) rebuildBackground();

		calcMapSize();
		var resized:Bool = mapWidth != oldWidth || mapHeight != oldHeight;
		if (graphOnly && resized)
		{
			rebuildBackground();
			calcMapSize();
		}
		if (!graphOnly || resized) buildGrid();

		if (!graphOnly) rebuildDecor();
		rebuildGraph();
	}

	function rebuildBackground()
	{
		for (old in bgSprites)
		{
			remove(old, true);
			old.destroy();
		}
		bgSprites = OverworldState.buildBackgroundSprites(worldFile);
		for (i in 0...bgSprites.length) insert(i, bgSprites[i]);
		bgSprite = bgSprites.length > 0 ? bgSprites[bgSprites.length - 1] : null;
	}

	function rebuildDecor()
	{
		spritesBack.forEachAlive(function(spr:FlxSprite) spr.destroy());
		spritesFront.forEachAlive(function(spr:FlxSprite) spr.destroy());
		spritesBack.clear();
		spritesFront.clear();

		for (data in worldFile.sprites) addDecorSprite(data);
	}

	/** Nodos, etiquetas, caminos, seleccion y avisos. */
	function rebuildGraph()
	{
		nodesGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
		dotsGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
		labelsGroup.forEachAlive(function(txt:FlxText) txt.destroy());
		nodesGroup.clear();
		dotsGroup.clear();
		labelsGroup.clear();

		for (node in worldFile.nodes)
		{
			var spr:FlxSprite = OverworldState.buildSprite(node.image, node.anim, node.fps);
			spr.setPosition(node.x - spr.width * 0.5, node.y - spr.height * 0.5);
			nodesGroup.add(spr);

			var label:FlxText = new FlxText(node.x - 60, node.y + spr.height * 0.5 + 1, 120, nodeLabel(node), 8);
			label.setFormat(Paths.font('vcr.ttf'), 8, labelColor(node), CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 1;
			labelsGroup.add(label);
		}

		buildPathLines();
		updateSelectionBox();

		// los avisos se recalculan un momento despues (no en cada pixel de un arrastre)
		problemGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
		problemGroup.clear();
		problemsDirty = true;
		problemsTimer = 0;

		// las cajas del grupo siguen a sus nodos (durante un arrastre ya se mueven solas)
		if (hasGroup() && groupDragLast == null) refreshGroupBoxes();
	}

	/** La etiqueta de un nodo: su ID y, si lleva a otro mundo, a cual. */
	function nodeLabel(node:OverworldNodeFile):String
	{
		var target:String = node.world != null ? node.world : '';
		var text:String = switch (node.type)
		{
			case 'world' | 'warp': node.id + '\n> ' + (target.length > 0 ? target : '(sin destino)');
			case 'exit': node.id + '\n> ' + (target.length > 0 ? target : 'mapa de fuera');
			default: node.id;
		}
		if (OverworldData.hasSecret(worldFile, node)) text += ' *'; // tiene salida secreta
		if (node.needLevels > 0) text += '\n(${node.needLevels} sup.)';
		return text;
	}

	function labelColor(node:OverworldNodeFile):FlxColor
	{
		return switch (node.type)
		{
			case 'world': 0xFF7FD4FF;
			case 'empty': 0xFFBBBBBB;
			case 'exit': 0xFFFFA040;
			case 'warp': 0xFF66FF99;
			default: node.unlocked ? 0xFFFFE066 : 0xFFFF8080;
		}
	}

	function calcMapSize()
	{
		mapWidth = bgSprite != null ? bgSprite.x + bgSprite.width : 0;
		mapHeight = bgSprite != null ? bgSprite.y + bgSprite.height : 0;

		for (node in worldFile.nodes)
		{
			if (node.x + 64 > mapWidth) mapWidth = node.x + 64;
			if (node.y + 64 > mapHeight) mapHeight = node.y + 64;
		}
		for (spr in worldFile.sprites)
		{
			if (spr.x + 64 > mapWidth) mapWidth = spr.x + 64;
			if (spr.y + 64 > mapHeight) mapHeight = spr.y + 64;
		}

		if (mapWidth < 320) mapWidth = 320;
		if (mapHeight < 240) mapHeight = 240;
	}

	function buildGrid()
	{
		if (gridSprite != null)
		{
			remove(gridSprite, true); // sin compactar, cada recarga dejaba un hueco en `members`
			gridSprite.destroy();
		}

		var wid:Int = Std.int(mapWidth);
		var hei:Int = Std.int(mapHeight);
		gridSprite = new FlxSprite().makeGraphic(wid, hei, FlxColor.TRANSPARENT, true);
		var bmp:BitmapData = gridSprite.pixels;

		var grid:Int = worldFile.gridSize;
		if (grid < 2) grid = 16;

		var x:Int = 0;
		while (x <= wid)
		{
			plotLine(bmp, x, 0, x, hei, 0x33FFFFFF);
			x += grid;
		}

		var y:Int = 0;
		while (y <= hei)
		{
			plotLine(bmp, 0, y, wid, y, 0x33FFFFFF);
			y += grid;
		}

		plotLine(bmp, 0, 0, wid - 1, 0, 0x66FF00FF);
		plotLine(bmp, wid - 1, 0, wid - 1, hei - 1, 0x66FF00FF);
		plotLine(bmp, wid - 1, hei - 1, 0, hei - 1, 0x66FF00FF);
		plotLine(bmp, 0, hei - 1, 0, 0, 0x66FF00FF);
		gridSprite.dirty = true;

		gridSprite.visible = showGrid;
		insert(members.indexOf(spritesBack), gridSprite);
	}

	var showGrid:Bool = true;

	/** Flechas de "quien desbloquea a quien" (tecla U). */
	var showUnlocks:Bool = true;
	var viewLabel:FlxText;

	static inline final VIEW_COLOR:FlxColor = 0xCCFFFFFF;
	static inline final UNLOCK_COLOR:FlxColor = 0xFFFF66FF;
	static inline final SECRET_COLOR:FlxColor = 0xFFFFD84A; // salida secreta
	static inline final COND_COLOR:FlxColor = 0xFFFF9933;   // camino con condicion propia

	/** Lo que la camara del juego puede llegar a enseñar: [x, y, ancho, alto]. */
	function viewArea():Array<Float>
	{
		var size:Array<Float> = OverworldState.mapSize(worldFile);
		return OverworldState.cameraArea(size[0], size[1], worldFile.zoom);
	}

	/**
	 * Rectangulo que cubre todo lo que se dibuja encima del mapa, aunque se salga de el (salidas
	 * fuera de pantalla, la vista del juego centrada...): [minX, minY, maxX, maxY].
	 */
	function overlayBounds(area:Array<Float>):Array<Float>
	{
		var minX:Float = Math.min(0, area[0]) - 4;
		var minY:Float = Math.min(0, area[1]) - 4;
		var maxX:Float = Math.max(mapWidth, area[0] + area[2]) + 4;
		var maxY:Float = Math.max(mapHeight, area[1] + area[3]) + 4;

		for (node in worldFile.nodes)
		{
			minX = Math.min(minX, node.x - 32);
			minY = Math.min(minY, node.y - 32);
			maxX = Math.max(maxX, node.x + 32);
			maxY = Math.max(maxY, node.y + 32);
		}
		for (pth in worldFile.paths)
		{
			if (pth.points == null) continue;
			for (point in pth.points)
			{
				minX = Math.min(minX, point[0] - 8);
				minY = Math.min(minY, point[1] - 8);
				maxX = Math.max(maxX, point[0] + 8);
				maxY = Math.max(maxY, point[1] + 8);
			}
		}
		return [Math.floor(minX), Math.floor(minY), Math.ceil(maxX), Math.ceil(maxY)];
	}

	/**
	 * Linea de 1 px pintada pixel a pixel (Bresenham). FlxSpriteUtil.drawLine hace un dibujo
	 * vectorial entero por linea; con la rejilla, el rectangulo discontinuo y las flechas eran
	 * cientos por recarga, y la recarga se repite en cada pixel de un arrastre.
	 */
	static function plotLine(bmp:BitmapData, x1:Float, y1:Float, x2:Float, y2:Float, color:FlxColor)
	{
		var x:Int = Math.round(x1);
		var y:Int = Math.round(y1);
		var endX:Int = Math.round(x2);
		var endY:Int = Math.round(y2);
		var dx:Int = Std.int(Math.abs(endX - x));
		var dy:Int = -Std.int(Math.abs(endY - y));
		var stepX:Int = x < endX ? 1 : -1;
		var stepY:Int = y < endY ? 1 : -1;
		var err:Int = dx + dy;
		var width:Int = bmp.width;
		var height:Int = bmp.height;

		while (true)
		{
			if (x >= 0 && y >= 0 && x < width && y < height) bmp.setPixel32(x, y, color);
			if (x == endX && y == endY) break;

			var e2:Int = 2 * err;
			if (e2 >= dy)
			{
				err += dy;
				x += stepX;
			}
			if (e2 <= dx)
			{
				err += dx;
				y += stepY;
			}
		}
	}

	function dashedLine(target:FlxSprite, x1:Float, y1:Float, x2:Float, y2:Float, color:FlxColor, ?dash:Float = 4, ?gap:Float = 3)
	{
		var dx:Float = x2 - x1;
		var dy:Float = y2 - y1;
		var length:Float = Math.sqrt(dx * dx + dy * dy);
		if (length <= 0) return;

		var ux:Float = dx / length;
		var uy:Float = dy / length;
		var pos:Float = 0;
		var bmp:BitmapData = target.pixels;
		while (pos < length)
		{
			var end:Float = Math.min(pos + dash, length);
			plotLine(bmp, x1 + ux * pos, y1 + uy * pos, x1 + ux * end, y1 + uy * end, color);
			pos += dash + gap;
		}
	}

	/**
	 * Flecha discontinua de cada nodo a los que desbloquea. Va desplazada a un lado para no tapar
	 * el camino cuando los dos nodos estan unidos.
	 */
	function drawUnlockArrows(ox:Float, oy:Float)
	{
		for (node in worldFile.nodes)
		{
			// rosa: lo que abre al completarlo; amarillo: lo que abre su salida secreta
			for (list in [node.unlocks, node.secretUnlocks])
			{
				if (list == null) continue;
				var color:FlxColor = (list == node.secretUnlocks) ? SECRET_COLOR : UNLOCK_COLOR;
				for (id in list)
				{
					var target:OverworldNodeFile = OverworldData.findNode(worldFile, id);
					if (target == null || target == node) continue;
					drawArrow(node.x, node.y, target.x, target.y, color, ox, oy, 9);
				}
			}
		}

		// caminos con condicion propia: flecha del nodo que los abre a la mitad del camino
		for (pth in worldFile.paths)
		{
			if (pth.unlockedBy == null || pth.unlockedBy.length < 1) continue;
			var by:OverworldNodeFile = OverworldData.findNode(worldFile, pth.unlockedBy);
			var middle:Array<Float> = pathMiddle(pth);
			if (by == null || middle == null) continue;
			drawArrow(by.x, by.y, middle[0], middle[1], pth.secret ? SECRET_COLOR : COND_COLOR, ox, oy, 4);
		}
	}

	/** Flecha discontinua de un punto a otro, separada `gap` px de los dos extremos. */
	function drawArrow(fromX:Float, fromY:Float, toX:Float, toY:Float, color:FlxColor, ox:Float, oy:Float, gap:Float)
	{
		var dx:Float = toX - fromX;
		var dy:Float = toY - fromY;
		var length:Float = Math.sqrt(dx * dx + dy * dy);
		if (length < gap * 2 + 2) return;

		var ux:Float = dx / length;
		var uy:Float = dy / length;
		var sideX:Float = -uy * 3;
		var sideY:Float = ux * 3;

		var x1:Float = fromX + ux * 9 + sideX - ox;
		var y1:Float = fromY + uy * 9 + sideY - oy;
		var x2:Float = toX - ux * gap + sideX - ox;
		var y2:Float = toY - uy * gap + sideY - oy;
		dashedLine(linesSprite, x1, y1, x2, y2, color);

		// punta de flecha
		plotLine(linesSprite.pixels, x2, y2, x2 - ux * 5 - uy * 3, y2 - uy * 5 + ux * 3, color);
		plotLine(linesSprite.pixels, x2, y2, x2 - ux * 5 + uy * 3, y2 - uy * 5 - ux * 3, color);
	}

	/** El punto que queda a mitad de recorrido de un camino. */
	function pathMiddle(pth:OverworldPathFile):Array<Float>
	{
		var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
		var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
		if (nodeA == null || nodeB == null) return null;

		var line:Array<Array<Float>> = OverworldState.buildLine(pth, nodeA, nodeB);
		var total:Float = 0;
		for (i in 0...line.length - 1) total += segmentLength(line[i], line[i + 1]);

		var half:Float = total * 0.5;
		for (i in 0...line.length - 1)
		{
			var length:Float = segmentLength(line[i], line[i + 1]);
			if (half <= length && length > 0)
			{
				var ratio:Float = half / length;
				return [line[i][0] + (line[i + 1][0] - line[i][0]) * ratio, line[i][1] + (line[i + 1][1] - line[i][1]) * ratio];
			}
			half -= length;
		}
		return [nodeA.x, nodeA.y];
	}

	static inline function segmentLength(a:Array<Float>, b:Array<Float>):Float
		return Math.sqrt((b[0] - a[0]) * (b[0] - a[0]) + (b[1] - a[1]) * (b[1] - a[1]));

	/** El camino que pasa a menos de 4 px del raton, o null. */
	function pathUnderMouse(mouseX:Float, mouseY:Float):OverworldPathFile
	{
		var best:OverworldPathFile = null;
		var bestDist:Float = 4;
		for (pth in worldFile.paths)
		{
			var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
			var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
			if (nodeA == null || nodeB == null) continue;

			var line:Array<Array<Float>> = OverworldState.buildLine(pth, nodeA, nodeB);
			for (i in 0...line.length - 1)
			{
				var ax:Float = line[i][0];
				var ay:Float = line[i][1];
				var bx:Float = line[i + 1][0];
				var by:Float = line[i + 1][1];
				var lengthSq:Float = (bx - ax) * (bx - ax) + (by - ay) * (by - ay);
				var t:Float = lengthSq > 0 ? ((mouseX - ax) * (bx - ax) + (mouseY - ay) * (by - ay)) / lengthSq : 0;
				t = Math.max(0, Math.min(1, t));
				var px:Float = ax + (bx - ax) * t - mouseX;
				var py:Float = ay + (by - ay) * t - mouseY;
				var dist:Float = Math.sqrt(px * px + py * py);
				if (dist < bestDist)
				{
					bestDist = dist;
					best = pth;
				}
			}
		}
		return best;
	}

	function buildPathLines()
	{
		if (linesSprite != null)
		{
			remove(linesSprite, true); // sin compactar, cada recarga dejaba un hueco en `members`
			linesSprite.destroy();
		}

		// el lienzo empieza donde haga falta (puede ser en negativo) y todo se dibuja desplazado
		var area:Array<Float> = viewArea();
		var bounds:Array<Float> = overlayBounds(area);
		var ox:Float = bounds[0];
		var oy:Float = bounds[1];
		linesSprite = new FlxSprite(ox, oy).makeGraphic(Std.int(bounds[2] - ox), Std.int(bounds[3] - oy), FlxColor.TRANSPARENT, true);
		insert(members.indexOf(nodesGroup), linesSprite);

		// lo que se ve en el juego: fuera de este rectangulo, BF desaparece de la pantalla
		var ax:Float = area[0] - ox;
		var ay:Float = area[1] - oy;
		dashedLine(linesSprite, ax, ay, ax + area[2], ay, VIEW_COLOR, 6, 4);
		dashedLine(linesSprite, ax + area[2], ay, ax + area[2], ay + area[3], VIEW_COLOR, 6, 4);
		dashedLine(linesSprite, ax + area[2], ay + area[3], ax, ay + area[3], VIEW_COLOR, 6, 4);
		dashedLine(linesSprite, ax, ay + area[3], ax, ay, VIEW_COLOR, 6, 4);

		if (viewLabel == null)
		{
			viewLabel = new FlxText(0, 0, 200, 'LO QUE SE VE EN EL JUEGO', 8);
			viewLabel.setFormat(Paths.font('vcr.ttf'), 8, VIEW_COLOR, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			viewLabel.borderSize = 1;
			add(viewLabel);
		}
		viewLabel.setPosition(area[0] + 3, area[1] + 2);

		for (pth in worldFile.paths)
		{
			var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
			var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
			if (nodeA == null || nodeB == null) continue;

			// un camino con condicion propia (lo abre un nodo, o su salida secreta) va discontinuo
			var conditional:Bool = pth.unlockedBy != null && pth.unlockedBy.length > 0;
			var color:FlxColor = (pth == selectedPath) ? 0xFFFFFF00 : (conditional ? (pth.secret ? SECRET_COLOR : COND_COLOR) : 0xFF00FF88);
			var line:Array<Array<Float>> = OverworldState.buildLine(pth, nodeA, nodeB);

			for (i in 0...line.length - 1)
			{
				if (conditional) dashedLine(linesSprite, line[i][0] - ox, line[i][1] - oy, line[i + 1][0] - ox, line[i + 1][1] - oy, color, 3, 2);
				else plotLine(linesSprite.pixels, line[i][0] - ox, line[i][1] - oy, line[i + 1][0] - ox, line[i + 1][1] - oy, color);
			}

			// puntos de curva: un cuadradito de 4x4
			if (pth.points != null)
				for (point in pth.points)
					for (row in 0...4)
						plotLine(linesSprite.pixels, point[0] - 2 - ox, point[1] - 2 + row - oy, point[0] + 1 - ox, point[1] - 2 + row - oy, color);

			// vista previa de los puntitos del camino
			for (point in OverworldState.getDotPositions(pth, nodeA, nodeB))
			{
				var dot:FlxSprite = OverworldState.buildSprite(pth.dots, pth.dotAnim, 6);
				dot.setPosition(point[0] - dot.width * 0.5, point[1] - dot.height * 0.5);
				dot.alpha = 0.8;
				dotsGroup.add(dot);
			}
		}

		if (showUnlocks) drawUnlockArrows(ox, oy);
		linesSprite.dirty = true;
	}

	function updateSelectionBox()
	{
		var target:FlxSprite = null;

		if (selectedNode != null)
		{
			var index:Int = worldFile.nodes.indexOf(selectedNode);
			if (index > -1 && index < nodesGroup.length) target = nodesGroup.members[index];
		}
		else if (selectedSprite != null)
		{
			var index:Int = worldFile.sprites.indexOf(selectedSprite);
			if (index > -1)
			{
				var group = selectedSprite.front ? spritesFront : spritesBack;
				var localIndex:Int = 0;
				for (i in 0...worldFile.sprites.length)
				{
					if (i == index) break;
					if (worldFile.sprites[i].front == selectedSprite.front) localIndex++;
				}
				if (localIndex < group.length) target = group.members[localIndex];
			}
		}

		if (target == null)
		{
			selectionBox.visible = false;
			return;
		}

		selectionBox.visible = true;
		selectionBox.setPosition(target.x - 2, target.y - 2);
		selectionBox.setGraphicSize(Std.int(target.width + 4), Std.int(target.height + 4));
		selectionBox.updateHitbox();
		selectionBox.setPosition(target.x - 2, target.y - 2);
	}

	// ------------------------------------------------------------------ interfaz
	var UI_box:PsychUIBox;

	var displayNameInput:PsychUIInputText;
	var worldNameInput:PsychUIInputText;
	var bgDropDown:PsychUIDropDownMenu;
	var bgAnimDropDown:PsychUIDropDownMenu;
	var bgFpsStepper:PsychUINumericStepper;
	var bgTileCheck:PsychUICheckBox;
	var musicInput:PsychUIInputText;
	var zoomStepper:PsychUINumericStepper;
	var gridStepper:PsychUINumericStepper;
	var walkStepper:PsychUINumericStepper;
	var startDropDown:PsychUIDropDownMenu;
	var playerDropDown:PsychUIDropDownMenu;
	var worldsDropDown:PsychUIDropDownMenu;
	var showAllCheck:PsychUICheckBox;

	var nodeIdInput:PsychUIInputText;
	var nodeTypeDropDown:PsychUIDropDownMenu;
	var nodeNameInput:PsychUIInputText;
	var nodeSongDropDown:PsychUIDropDownMenu;
	var nodeSongLabel:FlxText;
	var nodeWeekDropDown:PsychUIDropDownMenu;
	var nodeWorldDropDown:PsychUIDropDownMenu;
	var nodeImageDropDown:PsychUIDropDownMenu;
	var nodeAnimDropDown:PsychUIDropDownMenu;
	var nodeDoneDropDown:PsychUIDropDownMenu;
	var nodeFpsStepper:PsychUINumericStepper;
	var nodeUnlockedCheck:PsychUICheckBox;
	var nodeUnlocksInput:PsychUIInputText;
	var nodeXStepper:PsychUINumericStepper;
	var nodeYStepper:PsychUINumericStepper;

	var decorImageDropDown:PsychUIDropDownMenu;
	var decorAnimDropDown:PsychUIDropDownMenu;
	var decorFpsStepper:PsychUINumericStepper;
	var decorXStepper:PsychUINumericStepper;
	var decorYStepper:PsychUINumericStepper;
	var decorScaleStepper:PsychUINumericStepper;
	var decorAlphaStepper:PsychUINumericStepper;
	var decorFlipXCheck:PsychUICheckBox;
	var decorFlipYCheck:PsychUICheckBox;
	var decorFrontCheck:PsychUICheckBox;

	var pathInfoTxt:FlxText;
	var pathDotsDropDown:PsychUIDropDownMenu;
	var pathDotAnimDropDown:PsychUIDropDownMenu;
	var pathSpacingStepper:PsychUINumericStepper;

	var modeTxt:FlxText;
	var outputTxt:FlxText;
	var helpBg:FlxSprite;
	var helpTxt:FlxText;

	var imageList:Array<String> = [];
	var songList:Array<String> = [];
	var weekList:Array<String> = [];
	var worldList:Array<String> = [];

	function buildUI()
	{
		imageList = OverworldData.listImages();
		if (imageList.length < 1) imageList = [''];
		computeImageLists();
		songList = OverworldData.listSongs();
		if (songList.length < 1) songList = [''];
		weekList = [''].concat(OverworldData.listWeeks());
		worldList = OverworldData.listWorlds().copy();
		if (worldList.length < 1) worldList = [''];

		UI_box = new PsychUIBox(FlxG.width - 380, 10, 370, 600, ['Mundo', 'Nodo', 'Deco', 'Camino', 'Tiles']);
		UI_box.cameras = [camHUD];
		UI_box.scrollFactor.set();
		add(UI_box);

		addWorldTab();
		addNodeTab();
		addDecorTab();
		addPathTab();
		addTilesTab();
		UI_box.selectedName = 'Mundo';
		collectDropDowns();
		for (dropDown in dropDowns) dropDown.showDropDown(false);

		modeTxt = new FlxText(10, 42, 885, '', 16); // hasta el panel de la derecha, para que no se parta
		modeTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		modeTxt.cameras = [camHUD];
		modeTxt.scrollFactor.set();
		add(modeTxt);

		outputTxt = new FlxText(10, FlxG.height - 160, FlxG.width - 400, '', 16);
		outputTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.LIME, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		outputTxt.cameras = [camHUD];
		outputTxt.scrollFactor.set();
		add(outputTxt);

		buildHelp();
	}

	function buildHelp()
	{
		helpBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		helpBg.alpha = 0.8;
		helpBg.cameras = [camHUD];
		helpBg.scrollFactor.set();
		helpBg.visible = false;
		add(helpBg);

		var text:String = 'EDITOR DE MUNDOS - ATAJOS\n\n'
			+ 'V  seleccionar: arrastra nodos y decorados. SHIFT+clic suma o quita del grupo; arrastrar\n'
			+ '   en el vacio dibuja un rectangulo que selecciona lo de dentro (+SHIFT: lo anade)\n'
			+ 'N  modo nodo: clic para crear un nivel\n'
			+ 'B  modo decorado: clic para colocar el sprite elegido\n'
			+ 'C  modo camino: clic en nodo A y luego en B. Si no estan alineados, sale en L\n'
			+ '   (SHIFT al hacer el segundo clic: primero vertical). Con un camino elegido,\n'
			+ '   clic en el vacio anade un punto de curva\n'
			+ 'T  modo pintar tiles: elige un tile en la paleta y pinta arrastrando\n'
			+ 'L  modo enlazar: clic en el nodo que desbloquea y luego en los que abre. SHIFT+clic: los\n'
			+ '   abre su salida secreta. Clic en un camino: ese camino solo se abre al completarlo\n'
			+ '   (+SHIFT: con su salida secreta). Otro clic quita el enlace; L, V o ESC salen\n'
			+ 'P  paleta de tiles     CTRL+clic en la paleta: tile como aspecto del nodo (+SHIFT: completado)\n'
			+ 'E  siguiente aviso     U  flechas de desbloqueo (rosa normal, amarillo secreta, naranja camino)\n'
			+ 'G  rejilla             Rueda: zoom      Raton central / flechas: mover la camara\n\n'
			+ 'Clic derecho          borrar lo que hay bajo el raton (sobre un punto de curva, ese punto)\n'
			+ 'SUPR                  borrar la seleccion (o el grupo)\n'
			+ 'CTRL+D                duplicar la seleccion (o el grupo, con sus caminos de dentro)\n'
			+ 'ALT (mantener)        colocar sin ajustar a la rejilla\n'
			+ 'CTRL+Z / CTRL+Y       deshacer / rehacer\n'
			+ 'CTRL+S                guardar\n'
			+ 'CTRL+T                probar el mundo   (CTRL+SHIFT+T: probar desde el nodo elegido)\n'
			+ 'Rectangulo blanco     lo que se ve en el juego (fuera = fuera de pantalla)\n'
			+ 'F1                    esta ayuda\n'
			+ 'ESC                   soltar el grupo, salir del modo actual; en SELECCIONAR, volver al menu';

		helpTxt = new FlxText(40, 50, FlxG.width - 80, text, 15);
		helpTxt.setFormat(Paths.font('vcr.ttf'), 15, FlxColor.WHITE, LEFT);
		helpTxt.cameras = [camHUD];
		helpTxt.scrollFactor.set();
		helpTxt.visible = false;
		add(helpTxt);
	}

	function label(group:FlxSpriteGroup, x:Float, y:Float, text:String):FlxText
	{
		var txt:FlxText = new FlxText(x, y, 260, text, 12);
		group.add(txt);
		return txt;
	}

	function addWorldTab()
	{
		var tab:FlxSpriteGroup = UI_box.getTab('Mundo').menu;
		var x:Int = 10;
		var y:Int = 20;

		label(tab, x, y - 17, 'Archivo:');
		worldNameInput = new PsychUIInputText(x, y, 120, worldName, 10);
		worldNameInput.onChange = function(old:String, cur:String) worldName = cur.trim();
		tab.add(worldNameInput);

		label(tab, x + 130, y - 17, 'Nombre visible:');
		displayNameInput = new PsychUIInputText(x + 130, y, 150, worldFile.displayName, 10);
		displayNameInput.onChange = function(old:String, cur:String) worldFile.displayName = cur;
		tab.add(displayNameInput);

		y += 42;
		label(tab, x, y - 17, 'Fondo:');
		bgDropDown = new PsychUIDropDownMenu(x, y, [''].concat(imagesFor('bg')), function(sel:Int, value:String)
		{
			worldFile.bg = value;
			bgAnimDropDown.list = [''].concat(OverworldData.listAnimations(value));
			bgAnimDropDown.selectedLabel = '';
			worldFile.bgAnim = '';
			reloadMap();
		}, 150);
		tab.add(bgDropDown);

		label(tab, x + 160, y - 17, 'FPS:');
		bgFpsStepper = new PsychUINumericStepper(x + 160, y, 1, worldFile.bgFps, 0, 60, 0, 50);
		bgFpsStepper.onValueChange = function()
		{
			worldFile.bgFps = Std.int(bgFpsStepper.value);
			reloadMap();
		};
		tab.add(bgFpsStepper);

		y += 42;
		label(tab, x, y - 17, 'Animacion del fondo:');
		bgAnimDropDown = new PsychUIDropDownMenu(x, y, [''].concat(OverworldData.listAnimations(worldFile.bg)), function(sel:Int, value:String)
		{
			worldFile.bgAnim = value;
			reloadMap();
		}, 150);
		tab.add(bgAnimDropDown);

		bgTileCheck = new PsychUICheckBox(x + 170, y, 'Repetir el fondo (mosaico)', 180, function()
		{
			worldFile.bgTile = bgTileCheck.checked;
			reloadMap();
		});
		tab.add(bgTileCheck);

		y += 42;
		label(tab, x, y - 17, 'Musica:');
		musicInput = new PsychUIInputText(x, y, 120, worldFile.music, 10);
		musicInput.onChange = function(old:String, cur:String) worldFile.music = cur.trim();
		tab.add(musicInput);

		label(tab, x + 130, y - 17, 'Zoom:');
		zoomStepper = new PsychUINumericStepper(x + 130, y, 0.5, worldFile.zoom, 0.5, 10, 1, 60);
		zoomStepper.onValueChange = function()
		{
			worldFile.zoom = zoomStepper.value;
			reloadMap(true); // el rectangulo "LO QUE SE VE" depende del zoom
		};
		tab.add(zoomStepper);

		label(tab, x + 200, y - 17, 'Rejilla:');
		gridStepper = new PsychUINumericStepper(x + 200, y, 2, worldFile.gridSize, 2, 128, 0, 60);
		gridStepper.onValueChange = function()
		{
			worldFile.gridSize = Std.int(gridStepper.value);
			buildGrid();
		};
		tab.add(gridStepper);

		y += 42;
		label(tab, x, y - 17, 'Jugador:');
		playerDropDown = new PsychUIDropDownMenu(x, y, imagesFor('player'), function(sel:Int, value:String) worldFile.player = value, 150);
		tab.add(playerDropDown);

		label(tab, x + 160, y - 17, 'Velocidad:');
		walkStepper = new PsychUINumericStepper(x + 160, y, 5, worldFile.walkSpeed, 5, 600, 0, 60);
		walkStepper.onValueChange = function() worldFile.walkSpeed = walkStepper.value;
		tab.add(walkStepper);

		y += 42;
		label(tab, x, y - 17, 'Nodo inicial:');
		startDropDown = new PsychUIDropDownMenu(x, y, nodeIdList(), function(sel:Int, value:String)
		{
			worldFile.startNode = value;
			reloadMap(true); // cambia los avisos
		}, 150);
		tab.add(startDropDown);

		y += 46;
		tab.add(new PsychUIButton(x, y, 'Guardar', function() saveWorld(), 90));
		tab.add(new PsychUIButton(x + 100, y, 'Guardar como...', function() saveWorldAs(), 110));
		tab.add(new PsychUIButton(x + 220, y, 'Probar', function() testWorld(), 70));

		y += 32;
		tab.add(new PsychUIButton(x, y, 'Deshacer (Ctrl+Z)', function() undo(), 155));
		tab.add(new PsychUIButton(x + 165, y, 'Rehacer (Ctrl+Y)', function() redo(), 155));

		y += 32;
		tab.add(new PsychUIButton(x, y, 'Comprobar mundo', function()
		{
			if (reportProblems()) showOutput('Todo correcto: el mundo se puede recorrer entero.');
		}, 155));

		y += 32;
		tab.add(new PsychUIButton(x, y, 'Desbloquear todos', function()
		{
			if (!Lambda.exists(worldFile.nodes, n -> !n.unlocked))
			{
				showOutput('Ya estan todos desbloqueados');
				return;
			}
			pushUndo();
			for (node in worldFile.nodes) node.unlocked = true;
			reloadMap(true);
			updateUI();
			showOutput('Todos los nodos quedan accesibles desde el principio');
		}, 155));
		tab.add(new PsychUIButton(x + 165, y, 'Probar desde el nodo', function() testWorld(true), 155));

		showAllCheck = new PsychUICheckBox(x + 165, y - 32, 'Ver todos los sprites', 160, function()
		{
			showAllImages = showAllCheck.checked;
			refreshImageLists();
		});
		tab.add(showAllCheck);

		y += 36;
		tab.add(new PsychUIButton(x, y, 'Mundo nuevo', function()
		{
			if (!confirmDiscard('Mundo nuevo')) return;

			// nombre de archivo libre: si conservara el del mundo abierto, CTRL+S lo machacaria
			worldName = uniqueWorldName('mundo_nuevo');
			loadedName = null; // no viene de ningun archivo: guardarlo encima de otro pide confirmacion
			worldFile = OverworldData.createEmpty();
			selectedNode = null;
			selectedSprite = null;
			selectedPath = null;
			resetHistory();
			unsavedProgress = true;
			reloadMap();
			updateUI();
			showOutput('Mundo nuevo "$worldName" creado (sin guardar)');
		}, 100));

		worldsDropDown = new PsychUIDropDownMenu(x + 110, y, worldList, function(sel:Int, value:String)
		{
			if (value == null || value.length < 1) return;
			if (!openWorld(value, 'cargar "$value"')) worldsDropDown.selectedLabel = worldName;
		}, 170);
		tab.add(worldsDropDown);
	}

	function addNodeTab()
	{
		var tab:FlxSpriteGroup = UI_box.getTab('Nodo').menu;
		var x:Int = 10;
		var y:Int = 20;

		label(tab, x, y - 17, 'ID:');
		nodeIdInput = new PsychUIInputText(x, y, 110, '', 10);
		nodeIdInput.onChange = function(old:String, cur:String)
		{
			if (selectedNode == null) return;

			var newId:String = cur.trim();
			var oldId:String = selectedNode.id;
			if (newId.length < 1 || newId == oldId) return;

			// Se renombra tecla a tecla, asi que un ID intermedio puede coincidir con otro nodo
			// (de "node0" a "n10" se pasa por "n1"). Solo se aplica si el ID queda libre: si no,
			// los caminos y desbloqueos de los dos nodos se mezclarian sin avisar.
			if (!OverworldData.isValidNodeId(newId))
			{
				showOutput('"$newId" no vale como ID (sin comas ni "::"). El nodo sigue siendo "$oldId"', true);
				return;
			}
			var other:OverworldNodeFile = OverworldData.findNode(worldFile, newId);
			if (other != null && other != selectedNode)
			{
				showOutput('El ID "$newId" ya lo usa otro nodo. Este sigue siendo "$oldId"', true);
				return;
			}

			for (pth in worldFile.paths)
			{
				if (pth.a == oldId) pth.a = newId;
				if (pth.b == oldId) pth.b = newId;
			}
			for (node in worldFile.nodes)
				if (node.unlocks != null)
					node.unlocks = [for (target in node.unlocks) target == oldId ? newId : target];
			for (node in worldFile.nodes)
				if (node.secretUnlocks != null)
					node.secretUnlocks = [for (target in node.secretUnlocks) target == oldId ? newId : target];
			for (pth in worldFile.paths)
				if (pth.unlockedBy == oldId) pth.unlockedBy = newId;

			if (worldFile.startNode == oldId) worldFile.startNode = newId;
			OverworldData.renameProgress(worldName, oldId, newId); // el progreso va con el nodo
			unsavedProgress = true;
			showOutput('Nodo "$oldId" renombrado a "$newId"');
			selectedNode.id = newId;
			reloadMap(true);
			refreshNodeIdLists();
		};
		tab.add(nodeIdInput);

		label(tab, x + 120, y - 17, 'Tipo:');
		nodeTypeDropDown = new PsychUIDropDownMenu(x + 120, y, ['level', 'world', 'empty', 'exit', 'warp'], function(sel:Int, value:String)
		{
			if (selectedNode == null) return;
			pushUndo();
			selectedNode.type = value;
			lastNodeType = value;

			// Por defecto una salida es invisible: se coloca fuera de la pantalla y BF se va
			// andando por su camino. Si se quiere una salida visible (un tubo), se le pone sprite.
			var defaultImage:String = OverworldData.createNode('', 0, 0).image;
			if (value == 'exit' && selectedNode.image == defaultImage)
			{
				selectedNode.image = '';
				selectedNode.anim = '';
				showOutput('Salida invisible: colocala fuera de la pantalla o ponle un sprite (un tubo...)');
			}

			// un warp sin sprite propio se ve como una tuberia
			if (value == 'warp' && (selectedNode.image == defaultImage || selectedNode.image == '') && OverworldData.imageExists('overworld/pipe'))
			{
				selectedNode.image = 'overworld/pipe';
				selectedNode.anim = 'idle';
				selectedNode.animDone = '';
				showOutput('Warp: elige su Mundo destino y pulsa "Crear pareja" para poner la tuberia de vuelta');
			}

			unsavedProgress = true;
			reloadMap(true);
			updateUI();
		}, 100);
		tab.add(nodeTypeDropDown);

		y += 40;
		label(tab, x, y - 17, 'Nombre visible:');
		nodeNameInput = new PsychUIInputText(x, y, 150, '', 10);
		nodeNameInput.onChange = function(old:String, cur:String) if (selectedNode != null) selectedNode.name = cur;
		tab.add(nodeNameInput);

		label(tab, x + 160, y - 17, 'X / Y:');
		nodeXStepper = new PsychUINumericStepper(x + 160, y, 1, 0, -9999, 9999, 0, 55);
		nodeXStepper.onValueChange = function()
		{
			if (selectedNode == null) return;
			moveNodeTo(selectedNode, nodeXStepper.value, selectedNode.y);
			reloadMap(true);
		};
		tab.add(nodeXStepper);

		nodeYStepper = new PsychUINumericStepper(x + 225, y, 1, 0, -9999, 9999, 0, 55);
		nodeYStepper.onValueChange = function()
		{
			if (selectedNode == null) return;
			moveNodeTo(selectedNode, selectedNode.x, nodeYStepper.value);
			reloadMap(true);
		};
		tab.add(nodeYStepper);

		y += 40;
		nodeSongLabel = label(tab, x, y - 17, 'Cancion (todas las de la build):');
		nodeSongDropDown = new PsychUIDropDownMenu(x, y, [''].concat(songList), function(sel:Int, value:String)
		{
			setNodeSong(value);
		}, 340);
		tab.add(nodeSongDropDown);

		y += 40;
		label(tab, x, y - 17, 'Semana:');
		nodeWeekDropDown = new PsychUIDropDownMenu(x, y, weekList, function(sel:Int, value:String)
		{
			if (selectedNode == null) return;

			selectedNode.week = value;
			unsavedProgress = true;
			refreshSongList();
		}, 150);
		tab.add(nodeWeekDropDown);

		label(tab, x + 160, y - 17, 'Mundo destino:');
		nodeWorldDropDown = new PsychUIDropDownMenu(x + 160, y, [''].concat(worldList), function(sel:Int, value:String)
		{
			if (selectedNode == null) return;
			selectedNode.world = value;
			unsavedProgress = true;
			reloadMap(true); // la etiqueta del nodo muestra su destino
			updateNodeButtons();
		}, 180);
		tab.add(nodeWorldDropDown);

		y += 40;
		label(tab, x, y - 17, 'Sprite:');
		nodeImageDropDown = new PsychUIDropDownMenu(x, y, imagesFor('node'), function(sel:Int, value:String)
		{
			if (selectedNode == null) return;

			selectedNode.image = value;
			lastNodeImage = value;

			var anims:Array<String> = OverworldData.listAnimations(value);
			nodeAnimDropDown.list = [''].concat(anims);
			nodeDoneDropDown.list = [''].concat(anims);
			selectedNode.anim = anims.length > 0 ? anims[0] : '';
			selectedNode.animDone = '';
			nodeAnimDropDown.selectedLabel = selectedNode.anim;
			nodeDoneDropDown.selectedLabel = '';
			lastNodeAnim = selectedNode.anim;
			reloadMap(true);
		}, 150);
		tab.add(nodeImageDropDown);

		label(tab, x + 160, y - 17, 'FPS:');
		nodeFpsStepper = new PsychUINumericStepper(x + 160, y, 1, 6, 0, 60, 0, 50);
		nodeFpsStepper.onValueChange = function()
		{
			if (selectedNode == null) return;
			selectedNode.fps = Std.int(nodeFpsStepper.value);
			lastNodeFps = selectedNode.fps;
			reloadMap(true);
		};
		tab.add(nodeFpsStepper);

		y += 40;
		label(tab, x, y - 17, 'Animacion:');
		nodeAnimDropDown = new PsychUIDropDownMenu(x, y, [''], function(sel:Int, value:String)
		{
			if (selectedNode == null) return;
			selectedNode.anim = value;
			lastNodeAnim = value;
			reloadMap(true);
		}, 130);
		tab.add(nodeAnimDropDown);

		label(tab, x + 140, y - 17, 'Anim. completado:');
		nodeDoneDropDown = new PsychUIDropDownMenu(x + 140, y, [''], function(sel:Int, value:String)
		{
			if (selectedNode != null) selectedNode.animDone = value;
		}, 140);
		tab.add(nodeDoneDropDown);

		y += 42;
		nodeUnlockedCheck = new PsychUICheckBox(x, y, 'Desbloqueado al empezar', 160, function()
		{
			if (selectedNode == null) return;
			selectedNode.unlocked = nodeUnlockedCheck.checked;
			reloadMap(true);
		});
		tab.add(nodeUnlockedCheck);

		y += 36;
		label(tab, x, y - 17, 'Desbloquea al completarlo (ids separados por coma):');
		nodeUnlocksInput = new PsychUIInputText(x, y + 2, 280, '', 10);
		nodeUnlocksInput.onChange = function(old:String, cur:String)
		{
			if (selectedNode == null) return;

			var list:Array<String> = [];
			var unknown:Array<String> = [];
			for (part in cur.split(','))
			{
				var trimmed:String = part.trim();
				if (trimmed.length < 1 || list.contains(trimmed)) continue;

				list.push(trimmed);
				if (OverworldData.findNode(worldFile, trimmed) == null) unknown.push(trimmed);
			}
			selectedNode.unlocks = list;
			unsavedProgress = true;
			reloadMap(true); // flechas de desbloqueo y avisos

			// aviso en vivo: una errata en un ID deja ese nodo bloqueado para siempre
			if (unknown.length > 0) showOutput('No existe ningun nodo: ' + unknown.join(', '), true);
			else if (list.length > 0) showOutput('"${selectedNode.id}" desbloquea: ' + list.join(', '));
		};
		tab.add(nodeUnlocksInput);

		y += 40;
		tab.add(new PsychUIButton(x, y, 'Borrar nodo', function() deleteSelectedNode(), 100));

		// unir mundos: el texto y si se ven dependen del nodo (updateNodeButtons)
		nodeLinkButton = new PsychUIButton(x + 108, y, 'Crear submundo', function() linkNodeWorld(), 120);
		tab.add(nodeLinkButton);
		nodeGotoButton = new PsychUIButton(x + 236, y, 'Ir al destino', function() gotoDestination(), 104);
		tab.add(nodeGotoButton);

		y += 40;
		label(tab, x, y - 17, 'N superados:');
		nodeNeedStepper = new PsychUINumericStepper(x, y, 1, 0, 0, 99, 0, 50);
		nodeNeedStepper.onValueChange = function()
		{
			if (selectedNode == null) return;
			var before:Int = selectedNode.needLevels;
			selectedNode.needLevels = Std.int(nodeNeedStepper.value);

			// como enlazar: con la regla puesta empieza cerrado (si no, no haria nada), y al quitarla
			// vuelve a abrirse si nada mas lo abre
			if (before <= 0 && selectedNode.needLevels > 0 && selectedNode.unlocked && selectedNode.id != worldFile.startNode)
			{
				selectedNode.unlocked = false;
				showOutput('"${selectedNode.id}" empieza cerrado: se abre con ${selectedNode.needLevels} superados');
			}
			else if (selectedNode.needLevels <= 0 && !selectedNode.unlocked && !OverworldData.hasOpener(worldFile, selectedNode, worldName))
				selectedNode.unlocked = true;
			reloadMap(true);
			updateUI();
		};
		tab.add(nodeNeedStepper);

		label(tab, x + 90, y - 17, 'Salida secreta:');
		nodeSecretModeDropDown = new PsychUIDropDownMenu(x + 90, y, ['fallos', 'precision'], function(sel:Int, value:String)
		{
			if (selectedNode == null) return;
			selectedNode.secretMode = (value == 'precision') ? 'accuracy' : 'fc';
			updateUI(); // el contador de al lado pasa a ser el de este modo
		}, 110);
		tab.add(nodeSecretModeDropDown);

		// un solo contador: con "fallos" son los fallos maximos; con "precision", el % minimo
		label(tab, x + 210, y - 17, 'Max fallos / % min:');
		nodeSecretAccStepper = new PsychUINumericStepper(x + 210, y, 1, 0, 0, 999, 0, 50);
		nodeSecretAccStepper.onValueChange = function()
		{
			if (selectedNode == null) return;
			if (selectedNode.secretMode == 'accuracy') selectedNode.secretAccuracy = Math.min(100, nodeSecretAccStepper.value);
			else selectedNode.secretMisses = Std.int(nodeSecretAccStepper.value);
		};
		tab.add(nodeSecretAccStepper);

		y += 36;
		label(tab, x, y - 17, 'Su salida secreta desbloquea (ids; en modo L, SHIFT+clic):');
		nodeSecretInput = new PsychUIInputText(x, y + 2, 280, '', 10);
		nodeSecretInput.onChange = function(old:String, cur:String)
		{
			if (selectedNode == null) return;

			var list:Array<String> = [];
			var unknown:Array<String> = [];
			for (part in cur.split(','))
			{
				var trimmed:String = part.trim();
				if (trimmed.length < 1 || list.contains(trimmed)) continue;
				list.push(trimmed);
				if (OverworldData.findNode(worldFile, trimmed) == null) unknown.push(trimmed);
			}
			selectedNode.secretUnlocks = list;
			unsavedProgress = true;
			reloadMap(true);

			if (unknown.length > 0) showOutput('No existe ningun nodo: ' + unknown.join(', '), true);
			else if (list.length > 0) showOutput('La salida secreta de "${selectedNode.id}" desbloquea: ' + list.join(', '));
		};
		tab.add(nodeSecretInput);

		y += 34;
		tab.add(new PsychUIButton(x, y, 'Probar desde aqui', function() testWorld(true), 130));

		y += 30;
		tab.add(new FlxText(x, y, 340,
			'La semana filtra las canciones (sin semana: todas las de la build).\n'
			+ 'N superados: ademas se abre al tener N superados en este mundo.\n'
			+ 'Salida secreta: superar el nivel con esos fallos como mucho, o ese % minimo.', 11));
	}

	function addDecorTab()
	{
		var tab:FlxSpriteGroup = UI_box.getTab('Deco').menu;
		var x:Int = 10;
		var y:Int = 20;

		label(tab, x, y - 17, 'Sprite (del elegido y de los nuevos):');
		decorImageDropDown = new PsychUIDropDownMenu(x, y + 2, imagesFor('decor'), function(sel:Int, value:String)
		{
			lastDecorImage = value;

			var anims:Array<String> = OverworldData.listAnimations(value);
			decorAnimDropDown.list = [''].concat(anims);
			lastDecorAnim = '';
			decorAnimDropDown.selectedLabel = '';

			if (selectedSprite != null)
			{
				selectedSprite.image = value;
				selectedSprite.anim = '';
				refreshDecorSprite(selectedSprite);
			}
		}, 180);
		tab.add(decorImageDropDown);

		y += 42;
		label(tab, x, y - 17, 'Animacion:');
		decorAnimDropDown = new PsychUIDropDownMenu(x, y, [''], function(sel:Int, value:String)
		{
			lastDecorAnim = value;
			if (selectedSprite == null) return;
			selectedSprite.anim = value;
			refreshDecorSprite(selectedSprite);
		}, 150);
		tab.add(decorAnimDropDown);

		label(tab, x + 160, y - 17, 'FPS:');
		decorFpsStepper = new PsychUINumericStepper(x + 160, y, 1, 8, 0, 60, 0, 50);
		decorFpsStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.fps = Std.int(decorFpsStepper.value);
			refreshDecorSprite(selectedSprite);
		};
		tab.add(decorFpsStepper);

		y += 42;
		label(tab, x, y - 17, 'X / Y:');
		decorXStepper = new PsychUINumericStepper(x, y, 1, 0, -9999, 9999, 0, 60);
		decorXStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.x = decorXStepper.value;
			moveDecorSprite(selectedSprite);
		};
		tab.add(decorXStepper);

		decorYStepper = new PsychUINumericStepper(x + 70, y, 1, 0, -9999, 9999, 0, 60);
		decorYStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.y = decorYStepper.value;
			moveDecorSprite(selectedSprite);
		};
		tab.add(decorYStepper);

		label(tab, x + 140, y - 17, 'Escala:');
		decorScaleStepper = new PsychUINumericStepper(x + 140, y, 0.25, 1, 0.25, 10, 2, 60);
		decorScaleStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.scale = decorScaleStepper.value;
			refreshDecorSprite(selectedSprite);
		};
		tab.add(decorScaleStepper);

		label(tab, x + 210, y - 17, 'Alpha:');
		decorAlphaStepper = new PsychUINumericStepper(x + 210, y, 0.1, 1, 0, 1, 2, 60);
		decorAlphaStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.alpha = decorAlphaStepper.value;
			refreshDecorSprite(selectedSprite);
		};
		tab.add(decorAlphaStepper);

		y += 42;
		decorFlipXCheck = new PsychUICheckBox(x, y, 'Flip X', 70, function()
		{
			if (selectedSprite == null) return;
			selectedSprite.flipX = decorFlipXCheck.checked;
			refreshDecorSprite(selectedSprite);
		});
		tab.add(decorFlipXCheck);

		decorFlipYCheck = new PsychUICheckBox(x + 80, y, 'Flip Y', 70, function()
		{
			if (selectedSprite == null) return;
			selectedSprite.flipY = decorFlipYCheck.checked;
			refreshDecorSprite(selectedSprite);
		});
		tab.add(decorFlipYCheck);

		decorFrontCheck = new PsychUICheckBox(x + 160, y, 'Delante', 90, function()
		{
			if (selectedSprite == null) return;
			selectedSprite.front = decorFrontCheck.checked;
			reloadMap();
		});
		tab.add(decorFrontCheck);

		y += 42;
		tab.add(new PsychUIButton(x, y, 'Borrar decorado', function() deleteSelectedSprite(), 120));
		tab.add(new PsychUIButton(x + 130, y, 'Duplicar', function() duplicateSelection(), 90));
	}

	function addPathTab()
	{
		var tab:FlxSpriteGroup = UI_box.getTab('Camino').menu;
		var x:Int = 10;
		var y:Int = 20;

		pathInfoTxt = new FlxText(x, y, 340, 'Ningun camino seleccionado', 11);
		tab.add(pathInfoTxt);

		y += 40;
		label(tab, x, y - 17, 'Sprite de los puntitos:');
		pathDotsDropDown = new PsychUIDropDownMenu(x, y + 2, [''].concat(imagesFor('node')), function(sel:Int, value:String)
		{
			if (selectedPath == null) return;

			selectedPath.dots = value;
			var anims:Array<String> = OverworldData.listAnimations(value);
			pathDotAnimDropDown.list = [''].concat(anims);
			selectedPath.dotAnim = anims.length > 0 ? anims[0] : '';
			pathDotAnimDropDown.selectedLabel = selectedPath.dotAnim;
			reloadMap(true);
		}, 180);
		tab.add(pathDotsDropDown);

		y += 44;
		label(tab, x, y - 17, 'Animacion:');
		pathDotAnimDropDown = new PsychUIDropDownMenu(x, y, [''], function(sel:Int, value:String)
		{
			if (selectedPath == null) return;
			selectedPath.dotAnim = value;
			reloadMap(true);
		}, 140);
		tab.add(pathDotAnimDropDown);

		label(tab, x + 150, y - 17, 'Separacion:');
		pathSpacingStepper = new PsychUINumericStepper(x + 150, y, 1, 16, 2, 128, 0, 60);
		pathSpacingStepper.onValueChange = function()
		{
			if (selectedPath == null) return;
			selectedPath.dotSpacing = pathSpacingStepper.value;
			reloadMap(true);
		};
		tab.add(pathSpacingStepper);

		y += 46;
		tab.add(new PsychUIButton(x, y, 'Quitar ultimo punto', function()
		{
			if (selectedPath == null || selectedPath.points.length < 1) return;
			pushUndo();
			selectedPath.points.pop();
			reloadMap(true);
		}, 140));

		tab.add(new PsychUIButton(x + 150, y, 'Limpiar puntos', function()
		{
			if (selectedPath == null || selectedPath.points.length < 1) return;
			pushUndo();
			selectedPath.points = [];
			reloadMap(true);
		}, 130));

		y += 36;
		tab.add(new PsychUIButton(x, y, 'Borrar camino', function()
		{
			if (selectedPath == null) return;
			pushUndo();
			worldFile.paths.remove(selectedPath);
			selectedPath = null;
			reloadMap(true);
			updateUI();
		}, 140));

		y += 44;
		label(tab, x, y - 17, 'Solo se abre al completar (vacio: con sus nodos):');
		pathByDropDown = new PsychUIDropDownMenu(x, y, [''].concat([for (node in worldFile.nodes) node.id]), function(sel:Int, value:String)
		{
			if (selectedPath == null) return;
			selectedPath.unlockedBy = value;
			if (value == '') selectedPath.secret = false;
			reloadMap(true);
			updateUI();
		}, 150);
		tab.add(pathByDropDown);

		pathSecretCheck = new PsychUICheckBox(x + 160, y, 'con su salida secreta', 170, function()
		{
			if (selectedPath == null) return;
			selectedPath.secret = pathSecretCheck.checked && selectedPath.unlockedBy.length > 0;
			reloadMap(true);
			updateUI();
		});
		tab.add(pathSecretCheck);

		y += 34;
		lPathsCheck = new PsychUICheckBox(x, y, 'Unir en L los nodos no alineados (SHIFT: vertical primero)', 330, function() lPaths = lPathsCheck.checked);
		lPathsCheck.checked = lPaths;
		tab.add(lPathsCheck);

		y += 34;
		var tip:FlxText = new FlxText(x, y, 340,
			'Modo CAMINO (C):\n- clic en un nodo y luego en otro para unirlos\n- si ya estan unidos, se selecciona el camino\n- con un camino elegido, clic en el vacio anade\n  un punto de curva\n- en modo L, clic en un camino: lo abre el nodo de origen', 8);
		tab.add(tip);
	}

	var tilesetDropDown:PsychUIDropDownMenu;
	var paintFrontCheck:PsychUICheckBox;
	var paletteInfoTxt:FlxText;

	function addTilesTab()
	{
		var tab:FlxSpriteGroup = UI_box.getTab('Tiles').menu;
		var x:Int = 10;
		var y:Int = 20;

		var tilesets:Array<String> = [];
		for (image in imageList)
			if (OverworldData.hasAtlas(image)) tilesets.push(image);
		if (tilesets.length < 1) tilesets = [''];

		label(tab, x, y - 17, 'Tileset (cualquier png con su .xml):');
		tilesetDropDown = new PsychUIDropDownMenu(x, y + 2, tilesets, function(sel:Int, value:String) buildPalette(value), 290);
		tab.add(tilesetDropDown);

		y += 46;
		paintFrontCheck = new PsychUICheckBox(x, y, 'Pintar por delante de BF', 170, function() paintFront = paintFrontCheck.checked);
		tab.add(paintFrontCheck);

		y += 36;
		paletteInfoTxt = new FlxText(x, y, 340, 'Elige un tileset arriba.', 11);
		tab.add(paletteInfoTxt);

		y += 46;
		var tip:FlxText = new FlxText(x, y, 340,
			'Modo PINTAR TILES (T):\n'
			+ '- clic en un tile de la paleta para elegirlo\n'
			+ '- clic (o arrastra) en el mapa para pintar\n'
			+ '- clic derecho borra el tile de debajo\n'
			+ '- rueda del raton sobre la paleta = scroll\n'
			+ '- P oculta o muestra la paleta\n\n'
			+ 'Cada tile pintado es un decorado normal:\n'
			+ 'en modo V puedes seleccionarlo y retocarlo.', 11);
		tab.add(tip);
	}

	// --------------------------------------------- listas de sprites por categoria
	var bgList:Array<String> = [];
	var playerList:Array<String> = [];
	var nodeSpriteList:Array<String> = [];
	var showAllImages:Bool = false;

	function computeImageLists()
	{
		OverworldData.clearImageCache();

		bgList = OverworldData.filterImages(imageList, 'bg');
		playerList = OverworldData.filterImages(imageList, 'player');
		nodeSpriteList = OverworldData.filterImages(imageList, 'node');

		// si alguna categoria queda vacia, mejor enseñarlo todo que dejar la lista muerta
		if (bgList.length < 1) bgList = imageList.copy();
		if (playerList.length < 1) playerList = imageList.copy();
		if (nodeSpriteList.length < 1) nodeSpriteList = imageList.copy();
	}

	function imagesFor(category:String):Array<String>
	{
		if (showAllImages) return imageList;

		return switch (category)
		{
			case 'bg': bgList;
			case 'player': playerList;
			case 'decor': nodeSpriteList.concat(bgList);
			default: nodeSpriteList;
		}
	}

	function refreshImageLists()
	{
		bgDropDown.list = [''].concat(imagesFor('bg'));
		bgDropDown.selectedLabel = worldFile.bg;

		playerDropDown.list = imagesFor('player');
		playerDropDown.selectedLabel = worldFile.player;

		nodeImageDropDown.list = imagesFor('node');
		if (selectedNode != null) nodeImageDropDown.selectedLabel = selectedNode.image;

		decorImageDropDown.list = imagesFor('decor');
		if (selectedSprite != null) decorImageDropDown.selectedLabel = selectedSprite.image;

		pathDotsDropDown.list = [''].concat(imagesFor('node'));
		if (selectedPath != null) pathDotsDropDown.selectedLabel = selectedPath.dots;
	}

	// ------------------------------------------------------- revision del mundo
	inline function checkWorld():Array<String>
		return OverworldData.checkWorld(worldFile, worldName);

	function reportProblems():Bool
	{
		var problems:Array<String> = checkWorld();
		if (problems.length < 1) return true;

		// la lista completa va a la consola; en pantalla caben 4
		for (problem in problems) trace('Overworld "$worldName": $problem');

		var shown:Array<String> = problems.slice(0, 4);
		if (problems.length > 4) shown.push('(+${problems.length - 4} avisos mas)');

		showOutput('AVISOS DEL MUNDO:\n' + shown.join('\n'), true);
		return false;
	}

	// ------------------------------------------------------- deshacer / rehacer
	inline function snapshot():String
		return haxe.Json.stringify(worldFile);

	/** Guarda el estado ANTES de una accion que cambia el mundo. */
	function pushUndo(?state:String = null)
	{
		var entry:String = state != null ? state : snapshot();

		// si una accion ya guardo este mismo estado (p. ej. un desplegable que hace su propio
		// pushUndo y ademas lo registra recordUIChange), no se apila dos veces
		if (undoStack.length < 1 || undoStack[undoStack.length - 1] != entry) undoStack.push(entry);
		if (undoStack.length > MAX_UNDO) undoStack.shift();
		redoStack = [];
	}

	/**
	 * Cambiar de mundo (cargar otro o crear uno) empieza un historial nuevo: deshacer con el de
	 * antes metia el contenido de otro archivo bajo el nombre del nuevo, y CTRL+S lo machacaba.
	 */
	function resetHistory()
	{
		// el progreso apartado es de los nodos de este mundo: en otro mundo se devolveria a quien no es
		removedProgress.clear();
		clearGroup();
		undoStack = [];
		redoStack = [];
		lastUITarget = null;
		lastFocus = null;
		linkStart = null;
		pathStart = null;
	}

	var discardAskedAt:Float = -999;

	/** Con cambios sin guardar, cambiar de mundo hay que pedirlo dos veces seguidas. */
	function confirmDiscard(action:String):Bool
	{
		if (!unsavedProgress) return true;

		var now:Float = haxe.Timer.stamp();
		if (now - discardAskedAt < 5)
		{
			discardAskedAt = -999;
			return true;
		}

		discardAskedAt = now;
		showOutput('"$worldName" tiene cambios sin guardar.\nGuarda con CTRL+S, o repite $action para descartarlos', true);
		return false;
	}

	/** Abre otro mundo en el editor (con historial nuevo). false si no se ha abierto. */
	function openWorld(name:String, action:String):Bool
	{
		if (!confirmDiscard(action)) return false;

		var loaded:OverworldFile = OverworldData.load(name);
		if (loaded == null)
		{
			showOutput('No se pudo cargar "$name"', true);
			return false;
		}

		OverworldData.clearWorldCache();
		worldName = name;
		loadedName = name;
		worldFile = loaded;
		selectedNode = null;
		selectedSprite = null;
		selectedPath = null;
		resetHistory();
		unsavedProgress = false;
		reloadMap();
		updateUI();
		showOutput('Mundo "$name" cargado');
		return true;
	}

	function refreshWorldLists()
	{
		worldList = OverworldData.listWorlds().copy();
		worldsDropDown.list = worldList;
		worldsDropDown.selectedLabel = worldName;
		nodeWorldDropDown.list = [''].concat(worldList);
		if (selectedNode != null) nodeWorldDropDown.selectedLabel = selectedNode.world;
	}

	function uniqueWorldName(base:String):String
	{
		var name:String = base;
		var i:Int = 2;
		while (OverworldData.exists(name)) name = base + (i++);
		return name;
	}

	/** Lo que esta seleccionado: sirve para juntar clics seguidos sobre lo mismo en un paso. */
	function selectionTarget():Dynamic
	{
		if (selectedNode != null) return selectedNode;
		if (selectedSprite != null) return selectedSprite;
		if (selectedPath != null) return selectedPath;
		return worldFile;
	}

	/**
	 * Cambios hechos con el raton en la UI (desplegables, casillas, botones +-): `before` es el
	 * mundo justo antes de que la UI procesara el clic. Varios clics seguidos sobre lo mismo
	 * (subir un contador de 1 en 1) son un solo paso de deshacer.
	 */
	function recordUIChange(before:String)
	{
		if (snapshot() == before) return;

		var now:Float = haxe.Timer.stamp();
		var target:Dynamic = selectionTarget();
		if (target != lastUITarget || now - lastUIEditTime > UI_EDIT_GAP) pushUndo(before);

		lastUIEditTime = now;
		lastUITarget = target;
		// un boton que cambia y guarda a la vez (Crear submundo / pareja) deja el mundo guardado
		if (!savedThisFrame) unsavedProgress = true;
	}

	/** saveWorld() ha guardado en este fotograma (ver recordUIChange). */
	var savedThisFrame:Bool = false;

	/**
	 * Cambios tecleando en un campo: se aplican al mundo tecla a tecla, asi que se guarda el
	 * estado al entrar en el campo y se apila (una sola vez) en cuanto la primera tecla cambia algo.
	 * Asi un renombrado entero se deshace de una vez, no letra a letra.
	 */
	function trackFocusEdits()
	{
		var focus:PsychUIInputText = PsychUIInputText.focusOn;
		if (focus != lastFocus)
		{
			commitFocusEdit();
			lastFocus = focus;
			focusBefore = focus != null ? snapshot() : null;
			focusRecorded = false;
			return;
		}

		if (focus == null || focusRecorded || FlxG.keys.firstJustPressed() == -1) return;
		if (snapshot() == focusBefore) return;

		pushUndo(focusBefore);
		focusRecorded = true;
		unsavedProgress = true;
	}

	/**
	 * Un contador aplica su valor al salir del campo (Enter o clic fuera), despues de la ultima
	 * tecla: si eso cambio el mundo y no se habia apilado, se apila ahora como su paso.
	 */
	function commitFocusEdit()
	{
		if (lastFocus == null || focusBefore == null || focusRecorded) return;
		if (snapshot() == focusBefore) return;

		pushUndo(focusBefore);
		focusRecorded = true;
		unsavedProgress = true;
	}

	function undo()
	{
		if (undoStack.length < 1)
		{
			showOutput('No hay nada que deshacer');
			return;
		}

		redoStack.push(snapshot());
		applySnapshot(undoStack.pop());
		showOutput('Deshecho (quedan ${undoStack.length})');
	}

	function redo()
	{
		if (redoStack.length < 1)
		{
			showOutput('No hay nada que rehacer');
			return;
		}

		undoStack.push(snapshot());
		applySnapshot(redoStack.pop());
		showOutput('Rehecho (quedan ${redoStack.length})');
	}

	function applySnapshot(json:String)
	{
		// La seleccion se busca por ID (por posicion, al deshacer un borrado quedaba elegido otro
		// nodo y el siguiente SUPR borraba ese). Si el ID ya no existe (deshacer un renombrado),
		// por posicion, siempre que el numero de nodos no haya cambiado.
		var oldNodes:Int = worldFile.nodes.length;
		var oldSprites:Int = worldFile.sprites.length;
		var oldPaths:Int = worldFile.paths.length;
		var nodeIndex:Int = worldFile.nodes.indexOf(selectedNode);
		var spriteIndex:Int = worldFile.sprites.indexOf(selectedSprite);
		var pathIndex:Int = worldFile.paths.indexOf(selectedPath);
		var nodeId:String = selectedNode != null ? selectedNode.id : null;
		var sprite:OverworldSpriteFile = selectedSprite;
		var pathEnds:Array<String> = selectedPath != null ? [selectedPath.a, selectedPath.b] : null;

		var oldFile:OverworldFile = worldFile;
		worldFile = cast haxe.Json.parse(json);
		OverworldData.applyDefaults(worldFile);
		syncUndoProgress(oldFile, worldFile);
		restoreCreatedWorlds();

		selectedNode = OverworldData.findNode(worldFile, nodeId);
		if (selectedNode == null && nodeIndex > -1 && worldFile.nodes.length == oldNodes) selectedNode = worldFile.nodes[nodeIndex];

		selectedSprite = null;
		if (sprite != null)
		{
			selectedSprite = Lambda.find(worldFile.sprites, d -> d.x == sprite.x && d.y == sprite.y && d.image == sprite.image && d.anim == sprite.anim && d.front == sprite.front);
			if (selectedSprite == null && spriteIndex > -1 && worldFile.sprites.length == oldSprites) selectedSprite = worldFile.sprites[spriteIndex];
		}

		selectedPath = null;
		if (pathEnds != null)
		{
			selectedPath = Lambda.find(worldFile.paths, p -> p.a == pathEnds[0] && p.b == pathEnds[1]);
			if (selectedPath == null && pathIndex > -1 && worldFile.paths.length == oldPaths) selectedPath = worldFile.paths[pathIndex];
		}
		pathStart = null;
		linkStart = null;
		dragging = false;
		dragPointPath = null;
		unsavedProgress = true;

		// lo siguiente que se edite empieza un paso nuevo
		lastUITarget = null;
		lastFocus = null;
		clearGroup();

		// los decorados solo se rehacen si han cambiado, y solo los cambiados: con miles de tiles,
		// rehacerlos todos en cada CTRL+Z tardaba mas de medio segundo
		var sameBg:Bool = oldFile.bg == worldFile.bg && oldFile.bgAnim == worldFile.bgAnim
			&& oldFile.bgFps == worldFile.bgFps && oldFile.bgTile == worldFile.bgTile;
		if (sameBg && patchDecor(oldFile.sprites, worldFile.sprites)) reloadMap(true);
		else reloadMap();
		if (oldFile.gridSize != worldFile.gridSize) buildGrid(); // la recarga de grafo no la rehace
		updateUI();
	}

	static function sameDecor(a:OverworldSpriteFile, b:OverworldSpriteFile):Bool
	{
		return a.image == b.image && a.anim == b.anim && a.fps == b.fps && a.x == b.x && a.y == b.y && a.flipX == b.flipX
			&& a.flipY == b.flipY && a.scale == b.scale && a.alpha == b.alpha && a.front == b.front;
	}

	/**
	 * Pasa los sprites de los decorados de `oldList` a `newList` tocando solo lo que cambia: lo
	 * comun del principio y del final se queda, y lo de en medio se quita y se pone. false si no
	 * merece la pena (o los grupos no cuadran): entonces se rehace todo.
	 */
	function patchDecor(oldList:Array<OverworldSpriteFile>, newList:Array<OverworldSpriteFile>):Bool
	{
		var n:Int = oldList.length;
		var m:Int = newList.length;

		var oldFront:Int = 0;
		for (data in oldList) if (data.front) oldFront++;
		if (oldFront != spritesFront.length || n - oldFront != spritesBack.length) return false;

		var prefix:Int = 0;
		while (prefix < n && prefix < m && sameDecor(oldList[prefix], newList[prefix])) prefix++;
		var suffix:Int = 0;
		while (suffix < n - prefix && suffix < m - prefix && sameDecor(oldList[n - 1 - suffix], newList[m - 1 - suffix])) suffix++;

		var removed:Int = n - prefix - suffix;
		var added:Int = m - prefix - suffix;
		if (removed + added == 0) return true;
		if (removed + added > 400) return false;

		// fuera los sprites del tramo viejo
		var gone:Array<FlxSprite> = [];
		var goneFront:Array<Bool> = [];
		var front:Int = 0;
		var back:Int = 0;
		for (i in 0...n)
		{
			var local:Int = oldList[i].front ? front++ : back++;
			if (i < prefix || i >= n - suffix) continue;
			gone.push((oldList[i].front ? spritesFront : spritesBack).members[local]);
			goneFront.push(oldList[i].front);
		}
		for (i in 0...gone.length)
		{
			(goneFront[i] ? spritesFront : spritesBack).remove(gone[i], true);
			gone[i].destroy();
		}

		// y dentro los del tramo nuevo, cada uno en su sitio dentro de su grupo
		front = 0;
		back = 0;
		for (i in 0...m - suffix)
		{
			var data:OverworldSpriteFile = newList[i];
			var local:Int = data.front ? front++ : back++;
			if (i < prefix) continue;
			(data.front ? spritesFront : spritesBack).insert(local, buildDecorSprite(data));
		}
		return true;
	}

	/**
	 * Al deshacer o rehacer, el progreso sigue a los nodos: uno que vuelve recupera el que tenia al
	 * borrarlo, uno que desaparece lo aparta, y un renombrado se lo lleva al ID nuevo.
	 */
	function syncUndoProgress(oldFile:OverworldFile, newFile:OverworldFile)
	{
		if (oldFile.nodes.length == newFile.nodes.length)
		{
			for (i in 0...oldFile.nodes.length)
				if (oldFile.nodes[i].id != newFile.nodes[i].id)
					OverworldData.renameProgress(worldName, oldFile.nodes[i].id, newFile.nodes[i].id);
			return;
		}

		var oldIds:Map<String, Bool> = new Map<String, Bool>();
		for (node in oldFile.nodes) oldIds.set(node.id, true);
		var newIds:Map<String, Bool> = new Map<String, Bool>();
		for (node in newFile.nodes) newIds.set(node.id, true);

		for (node in oldFile.nodes) if (!newIds.exists(node.id)) stashProgress(node.id);
		for (node in newFile.nodes) if (!oldIds.exists(node.id)) restoreProgress(node.id);
		flushProgress();
	}

	// ------------------------------------------------- desplegable al frente
	function collectDropDowns()
	{
		dropDowns = [];
		dropDownGroups = [];

		for (tab in UI_box.tabs)
		{
			if (tab == null || tab.menu == null) continue;

			for (member in tab.menu.members)
			{
				if (member != null && (member is PsychUIDropDownMenu))
				{
					dropDowns.push(cast member);
					dropDownGroups.push(tab.menu);
				}
			}
		}
	}

	/** Al abrirse un desplegable lo movemos al final del grupo: asi se dibuja encima de todo. */
	function raiseOpenDropDown()
	{
		var focus:Dynamic = PsychUIInputText.focusOn;
		if (focus == lastFocused) return;

		lastFocused = focus;
		if (focus == null) return;

		for (i in 0...dropDowns.length)
		{
			if (dropDowns[i] != focus) continue;

			var group:FlxSpriteGroup = dropDownGroups[i];
			var dropDown:PsychUIDropDownMenu = dropDowns[i];
			if (group == null || group.members.length < 1) return;
			if (group.members[group.members.length - 1] == dropDown) return;

			group.remove(dropDown, true);
			group.add(dropDown);
			return;
		}
	}

	/** Carga de entrada el primer tileset que parezca una hoja de tiles. */
	function pickDefaultTileset()
	{
		if (tilesetDropDown == null || tilesetDropDown.list.length < 1) return;

		// por orden de preferencia: el tileset de terreno del overworld, luego cualquier otro
		var wanted:Array<String> = ['overworld_tiles', 'overworld_blocks', '_tiles', '_blocks', 'tileset'];

		var pick:String = null;
		for (want in wanted)
		{
			for (option in tilesetDropDown.list)
			{
				if (option.toLowerCase().endsWith(want))
				{
					pick = option;
					break;
				}
			}
			if (pick != null) break;
		}

		if (pick == null) return;
		tilesetDropDown.selectedLabel = pick;
		buildPalette(pick);
	}

	// ------------------------------------------------------------------ paleta
	function buildPalette(image:String)
	{
		paletteGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
		paletteGroup.clear();
		paletteFrames = [];
		paletteSelected = -1;
		paletteCursor.visible = false;
		paletteImage = image;

		if (image == null || image.length < 1 || !OverworldData.hasAtlas(image))
		{
			paletteInfoTxt.text = 'Ese archivo no tiene atlas (.xml).';
			return;
		}

		var atlas = Paths.getSparrowAtlas(image);
		if (atlas == null || atlas.frames == null || atlas.frames.length < 1)
		{
			paletteInfoTxt.text = 'No se han podido leer los tiles.';
			return;
		}

		paletteTileSize = Std.int(Math.max(atlas.frames[0].frame.width, atlas.frames[0].frame.height));
		if (paletteTileSize < 1) paletteTileSize = 16;

		paletteCell = Std.int(paletteTileSize * (paletteTileSize <= 16 ? 2 : 1.25)) + 4;
		paletteColumns = Std.int(Math.max(1, Math.floor(PALETTE_WIDTH / paletteCell)));

		for (index => frame in atlas.frames)
		{
			paletteFrames.push(frame.name);

			var spr:FlxSprite = new FlxSprite();
			spr.frames = atlas;
			spr.animation.frameName = frame.name;
			spr.antialiasing = false;

			var scale:Float = (paletteCell - 4) / paletteTileSize;
			spr.scale.set(scale, scale);
			spr.updateHitbox();

			var col:Int = index % paletteColumns;
			var row:Int = Std.int(index / paletteColumns);
			spr.setPosition(col * paletteCell + (paletteCell - spr.width) * 0.5, row * paletteCell + (paletteCell - spr.height) * 0.5);
			paletteGroup.add(spr);
		}

		var rows:Int = Math.ceil(paletteFrames.length / paletteColumns);
		paletteScrollMax = Math.max(0, rows * paletteCell - camPalette.height);
		camPalette.scroll.y = 0;

		paletteCursor.setGraphicSize(paletteCell, paletteCell);
		paletteCursor.updateHitbox();

		paletteInfoTxt.text = '${paletteFrames.length} tiles de ${paletteTileSize}x${paletteTileSize} px.
Rueda = bajar, shift+rueda = bajar rapido.';
		showOutput('Paleta cargada: ${paletteFrames.length} tiles de ${paletteTileSize}px. Pulsa T para pintar.');
	}

	function mouseOnPalette():Bool
	{
		if (!paletteShown || paletteFrames.length < 1) return false;

		return FlxG.mouse.screenX >= camPalette.x && FlxG.mouse.screenX < camPalette.x + camPalette.width
			&& FlxG.mouse.screenY >= camPalette.y && FlxG.mouse.screenY < camPalette.y + camPalette.height;
	}

	function updatePalette()
	{
		if (FlxG.mouse.wheel != 0)
		{
			// 3 filas por muesca, 15 con shift: con 2000 tiles hace falta
			var rows:Int = FlxG.keys.pressed.SHIFT ? 15 : 3;
			camPalette.scroll.y = Math.max(0, Math.min(paletteScrollMax, camPalette.scroll.y - FlxG.mouse.wheel * paletteCell * rows));
			return;
		}

		if (!FlxG.mouse.justPressed) return;

		var localX:Float = FlxG.mouse.screenX - camPalette.x + camPalette.scroll.x;
		var localY:Float = FlxG.mouse.screenY - camPalette.y + camPalette.scroll.y;

		var col:Int = Math.floor(localX / paletteCell);
		var row:Int = Math.floor(localY / paletteCell);
		if (col < 0 || col >= paletteColumns) return;

		var index:Int = row * paletteColumns + col;
		if (index < 0 || index >= paletteFrames.length) return;

		// CTRL+clic con un nodo elegido: ese tile pasa a ser su aspecto (SHIFT: al completarlo). El
		// desplegable de animaciones solo ofrece prefijos, no "tile0002". Va con CTRL porque elegir
		// un nodo abre su pestana, y un clic normal en la paleta tiene que seguir siendo "pintar".
		if (FlxG.keys.pressed.CONTROL)
		{
			if (selectedNode == null) showOutput('CTRL+clic en la paleta pone el tile a un nodo: elige antes el nodo (V)', true);
			else setNodeTile(selectedNode, paletteImage, paletteFrames[index], FlxG.keys.pressed.SHIFT);
			return;
		}

		paletteSelected = index;
		paletteCursor.visible = true;
		paletteCursor.setPosition(col * paletteCell, row * paletteCell);

		curMode = MODE_TILE;
		showOutput('Tile ${paletteFrames[index]} (${index + 1}/${paletteFrames.length}) elegido. Clic en el mapa para pintar.');
	}

	/**
	 * Pone un tile de la paleta como aspecto de un nodo. `asDone` lo pone como aspecto al
	 * completarlo, que tiene que salir del mismo atlas que el normal (un nodo tiene una imagen).
	 */
	function setNodeTile(node:OverworldNodeFile, image:String, frame:String, asDone:Bool)
	{
		if (asDone && node.image != image)
		{
			showOutput('El aspecto de completado tiene que ser del mismo atlas que el normal.\nElige antes el normal (CTRL+clic sin SHIFT) en este tileset', true);
			return;
		}

		pushUndo();
		if (asDone) node.animDone = frame;
		else
		{
			if (node.image != image) node.animDone = '';
			node.image = image;
			node.anim = frame;
			node.fps = 0;

			// los nodos nuevos salen con este aspecto
			lastNodeImage = image;
			lastNodeAnim = frame;
			lastNodeFps = 0;
		}
		unsavedProgress = true;
		reloadMap(true);
		updateUI();
		showOutput(asDone ? '"${node.id}": al completarlo se vera "$frame"' : '"${node.id}" usa el tile "$frame" (CTRL+SHIFT+clic en otro = su aspecto al completarlo)');
	}

	function paintTile(mouseX:Float, mouseY:Float)
	{
		if (paletteSelected < 0 || paletteSelected >= paletteFrames.length) return;

		var size:Int = paletteTileSize;
		var px:Float = Math.floor(mouseX / size) * size;
		var py:Float = Math.floor(mouseY / size) * size;
		var frame:String = paletteFrames[paletteSelected];

		// solo se sustituye otro tile pintado en la misma casilla: un decorado puesto a mano
		// (un castillo con B) no se borra por pintar encima
		var existing:OverworldSpriteFile = null;
		for (data in worldFile.sprites)
		{
			if (data.front == paintFront && data.x == px && data.y == py && isPaintedTile(data))
			{
				existing = data;
				break;
			}
		}

		if (existing != null && existing.image == paletteImage && existing.anim == frame) return; // ya esta pintado

		if (strokeUndoPending)
		{
			pushUndo();
			strokeUndoPending = false;
		}
		if (existing != null) removeDecor(existing);

		var data:OverworldSpriteFile = OverworldData.createSprite(paletteImage, px, py);
		data.anim = frame;
		data.fps = 0;
		data.front = paintFront;
		worldFile.sprites.push(data);
		unsavedProgress = true;

		// incremental: rehacer miles de tiles por cada celda pintada era injugable
		addDecorSprite(data);
		if (px + size > mapWidth || py + size > mapHeight) reloadMap(true); // el mapa crece
	}

	/** Al empezar un trazo: falta guardar su paso de deshacer (antes de la primera casilla que cambie). */
	var strokeUndoPending:Bool = false;

	/** Un tile pintado desde la paleta: un fotograma concreto ("tile0042") y 0 FPS. */
	static function isPaintedTile(data:OverworldSpriteFile):Bool
		return data.fps == 0 && data.anim != null && ~/[0-9]$/.match(data.anim);

	function addDecorSprite(data:OverworldSpriteFile):FlxSprite
	{
		var spr:FlxSprite = buildDecorSprite(data);
		if (data.front) spritesFront.add(spr);
		else spritesBack.add(spr);
		return spr;
	}

	/**
	 * Rehace solo el sprite de un decorado (imagen, animacion, escala, alpha, flips): rehacer los
	 * miles de tiles pintados en cada clic de un contador tardaba mas de medio segundo.
	 */
	function refreshDecorSprite(data:OverworldSpriteFile)
	{
		var old:FlxSprite = decorSpriteOf(data);
		if (old == null)
		{
			reloadMap();
			return;
		}

		var group = data.front ? spritesFront : spritesBack;
		group.replace(old, buildDecorSprite(data));
		old.destroy();
		updateSelectionBox();
	}

	function buildDecorSprite(data:OverworldSpriteFile):FlxSprite
	{
		var spr:FlxSprite = OverworldState.buildSprite(data.image, data.anim, data.fps);
		spr.flipX = data.flipX;
		spr.flipY = data.flipY;
		spr.alpha = data.alpha;
		if (data.scale != 1)
		{
			spr.scale.set(data.scale, data.scale);
			spr.updateHitbox();
		}
		spr.setPosition(data.x, data.y);
		return spr;
	}

	/** Cambia la cancion del nodo y arrastra el nombre visible si no lo has escrito tu. */
	function setNodeSong(value:String)
	{
		if (selectedNode == null) return;

		var previous:String = selectedNode.song;
		selectedNode.song = value;
		unsavedProgress = true;
		markProblemsDirty(); // un nivel sin cancion es un aviso

		var visible:String = selectedNode.name;
		if (visible == null || visible.length < 1 || visible == 'Nivel' || visible == 'Tutorial'
			|| (previous != null && previous.length > 0 && visible.toLowerCase() == previous.toLowerCase()))
		{
			selectedNode.name = value;
			if (nodeNameInput != null) nodeNameInput.text = value;
		}
	}

	/**
	 * Ajusta la lista de canciones del nodo a la semana elegida.
	 * Sin semana (o si la semana no declara canciones) salen todas las de la build.
	 */
	function refreshSongList()
	{
		if (nodeSongDropDown == null) return;

		var week:String = (selectedNode != null && selectedNode.week != null) ? selectedNode.week : '';
		var list:Array<String> = songList;
		var filtered:Bool = false;

		if (week.length > 0)
		{
			var weekSongs:Array<String> = OverworldData.listSongsOfWeek(week);
			if (weekSongs.length > 0)
			{
				list = weekSongs;
				filtered = true;
			}
		}

		nodeSongDropDown.list = [''].concat(list);
		if (nodeSongLabel != null)
			nodeSongLabel.text = filtered ? 'Cancion (semana "$week"):' : 'Cancion (todas las de la build):';

		if (selectedNode == null) return;

		// si la cancion que tenia no es de esa semana, se pasa a la primera de la semana
		if (filtered && selectedNode.song != null && selectedNode.song.length > 0 && !list.contains(selectedNode.song))
			setNodeSong(list[0]);

		nodeSongDropDown.selectedLabel = selectedNode.song;
	}

	function nodeIdList():Array<String>
	{
		var list:Array<String> = [];
		for (node in worldFile.nodes) list.push(node.id);
		if (list.length < 1) list.push('');
		return list;
	}

	function refreshNodeIdLists()
	{
		var ids:Array<String> = nodeIdList();
		var key:String = ids.join(',');
		if (key != lastNodeIds)
		{
			lastNodeIds = key;
			startDropDown.list = ids;
			if (pathByDropDown != null) pathByDropDown.list = [''].concat([for (node in worldFile.nodes) node.id]);
		}
		startDropDown.selectedLabel = worldFile.startNode;
	}

	var lastNodeIds:String = null;

	function updateUI()
	{
		worldNameInput.text = worldName;
		displayNameInput.text = worldFile.displayName;
		bgDropDown.selectedLabel = worldFile.bg;
		bgAnimDropDown.list = [''].concat(OverworldData.listAnimations(worldFile.bg));
		bgAnimDropDown.selectedLabel = worldFile.bgAnim;
		bgFpsStepper.value = worldFile.bgFps;
		bgTileCheck.checked = worldFile.bgTile;
		musicInput.text = worldFile.music;
		zoomStepper.value = worldFile.zoom;
		gridStepper.value = worldFile.gridSize;
		walkStepper.value = worldFile.walkSpeed;
		playerDropDown.selectedLabel = worldFile.player;
		refreshNodeIdLists();

		if (selectedNode != null)
		{
			nodeIdInput.text = selectedNode.id;
			nodeTypeDropDown.selectedLabel = selectedNode.type;
			nodeNameInput.text = selectedNode.name;
			nodeWeekDropDown.selectedLabel = selectedNode.week;
			refreshSongList();
			nodeWorldDropDown.selectedLabel = selectedNode.world;
			nodeImageDropDown.selectedLabel = selectedNode.image;

			// un tile concreto ("tile0002", elegido desde la paleta) no es un prefijo de animacion:
			// se anade a la lista para que el desplegable lo muestre
			var anims:Array<String> = [''].concat(OverworldData.listAnimations(selectedNode.image));
			for (frame in [selectedNode.anim, selectedNode.animDone])
				if (frame != null && frame.length > 0 && !anims.contains(frame)) anims.push(frame);
			nodeAnimDropDown.list = anims;
			nodeDoneDropDown.list = anims;
			nodeAnimDropDown.selectedLabel = selectedNode.anim;
			nodeDoneDropDown.selectedLabel = selectedNode.animDone;
			nodeFpsStepper.value = selectedNode.fps;
			nodeUnlockedCheck.checked = selectedNode.unlocked;
			nodeUnlocksInput.text = selectedNode.unlocks.join(', ');
			nodeNeedStepper.value = selectedNode.needLevels;
			nodeSecretModeDropDown.selectedLabel = selectedNode.secretMode == 'accuracy' ? 'precision' : 'fallos';
			nodeSecretAccStepper.value = selectedNode.secretMode == 'accuracy' ? selectedNode.secretAccuracy : selectedNode.secretMisses;
			nodeSecretInput.text = selectedNode.secretUnlocks.join(', ');
			nodeXStepper.value = selectedNode.x;
			nodeYStepper.value = selectedNode.y;
		}
		updateNodeButtons();

		if (selectedSprite != null)
		{
			decorImageDropDown.selectedLabel = selectedSprite.image;
			var decorAnims:Array<String> = [''].concat(OverworldData.listAnimations(selectedSprite.image));
			if (selectedSprite.anim != null && selectedSprite.anim.length > 0 && !decorAnims.contains(selectedSprite.anim))
				decorAnims.push(selectedSprite.anim); // un tile pintado usa un fotograma exacto ("tile0042")
			decorAnimDropDown.list = decorAnims;
			decorAnimDropDown.selectedLabel = selectedSprite.anim;
			decorFpsStepper.value = selectedSprite.fps;
			decorXStepper.value = selectedSprite.x;
			decorYStepper.value = selectedSprite.y;
			decorScaleStepper.value = selectedSprite.scale;
			decorAlphaStepper.value = selectedSprite.alpha;
			decorFlipXCheck.checked = selectedSprite.flipX;
			decorFlipYCheck.checked = selectedSprite.flipY;
			decorFrontCheck.checked = selectedSprite.front;
		}

		if (selectedPath != null)
		{
			pathInfoTxt.text = 'Camino: ${selectedPath.a}  <->  ${selectedPath.b}\nPuntos de curva: ${selectedPath.points.length}';
			pathDotsDropDown.selectedLabel = selectedPath.dots;
			pathDotAnimDropDown.list = [''].concat(OverworldData.listAnimations(selectedPath.dots));
			pathDotAnimDropDown.selectedLabel = selectedPath.dotAnim;
			pathSpacingStepper.value = selectedPath.dotSpacing;
			pathByDropDown.selectedLabel = selectedPath.unlockedBy;
			pathSecretCheck.checked = selectedPath.secret;
		}
		else pathInfoTxt.text = 'Ningun camino seleccionado';
	}

	// ------------------------------------------------------------------ update
	var lastFocusWasUI:Bool = false;
	var lastTab:Dynamic = null;

	override function update(elapsed:Float)
	{
		var hadFocus:Bool = (PsychUIInputText.focusOn != null);

		// Un clic en el panel (o con un desplegable abierto) puede cambiar el mundo desde la UI: se
		// guarda como estaba antes de procesarlo. Solo entonces: con miles de tiles, copiar el mundo
		// cuesta decenas de ms, y los clics en el mapa ya guardan su propio paso de deshacer.
		var clickOnUI:Bool = FlxG.mouse.justPressed && (mouseOnUI() || PsychUIInputText.focusOn != null);
		var beforeClick:String = clickOnUI ? snapshot() : null;
		var worldBefore:OverworldFile = worldFile;
		uiEventThisFrame = false;
		savedThisFrame = false;

		super.update(elapsed);

		// un campo o desplegable de la pestana que se deja ya no se actualiza, asi que nunca soltaria
		// el foco y el mapa y los atajos se quedarian bloqueados
		if (UI_box.selectedTab != lastTab)
		{
			lastTab = UI_box.selectedTab;
			if (PsychUIInputText.focusOn != null) PsychUIInputText.focusOn = null;
		}

		// si el clic cambio de mundo (cargar / nuevo), su historial ya se reinicio: no se apila.
		// Sin ningun evento de la UI no pudo cambiar nada: se ahorra la segunda copia.
		if (beforeClick != null && uiEventThisFrame && worldFile == worldBefore) recordUIChange(beforeClick);
		trackFocusEdits();

		// CTRL+Z / CTRL+Y tambien con un campo de texto activo (el campo no los usa): se sale del
		// campo y se deshace en el mundo; el campo vuelve a mostrar el valor deshecho
		if (PsychUIInputText.focusOn != null && FlxG.keys.pressed.CONTROL && (FlxG.keys.justPressed.Z || FlxG.keys.justPressed.Y))
		{
			var redoKey:Bool = FlxG.keys.justPressed.Y || FlxG.keys.pressed.SHIFT;
			PsychUIInputText.focusOn = null;
			// lo tecleado y aun sin apilar es lo primero que se deshace
			commitFocusEdit();
			lastFocus = null;
			redoKey ? redo() : undo();
			updateSelectionBox();
			return;
		}

		// soltar el raton donde updateMouse no lo ve (paleta, ayuda abierta, un campo activo) tambien
		// termina el rectangulo y los arrastres: si no, el siguiente clic en el mapa los continuaba
		if (FlxG.mouse.justReleased && (helpBg.visible || hadFocus || PsychUIInputText.focusOn != null || mouseOnPalette()))
			endMouseGestures();

		raiseOpenDropDown();
		updateProblems(elapsed);

		modeTxt.text = 'Mundo: $worldName  |  Modo: ${MODE_NAMES[curMode]}  |  F1 = ayuda'
			+ (problems.length > 0 ? '  |  ${problems.length} avisos (E)' : '')
			+ (hasGroup() ? '  |  grupo: ${groupNodes.length} nodos, ${groupSprites.length} deco' : '')
			+ (unsavedProgress ? '  |  * sin guardar' : '');

		if (helpBg.visible)
		{
			if (FlxG.keys.justPressed.F1 || FlxG.keys.justPressed.ESCAPE)
			{
				helpBg.visible = helpTxt.visible = false;
			}
			return;
		}

		if (FlxG.keys.justPressed.F1)
		{
			helpBg.visible = helpTxt.visible = true;
			return;
		}

		if (PsychUIInputText.focusOn == null)
		{
			updateKeys(elapsed);
			if (!hadFocus)
			{
				if (mouseOnPalette()) updatePalette();
				else updateMouse();
			}
		}

		updateSelectionBox();
	}

	function updateKeys(elapsed:Float)
	{
		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.S) saveWorld();
			if (FlxG.keys.justPressed.T) testWorld(FlxG.keys.pressed.SHIFT);
			if (FlxG.keys.justPressed.D) duplicateSelection();
			if (FlxG.keys.justPressed.Z) FlxG.keys.pressed.SHIFT ? redo() : undo();
			if (FlxG.keys.justPressed.Y) redo();
			return;
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			// ESC primero suelta el grupo
			if (hasGroup())
			{
				clearGroup();
				showOutput('Grupo soltado');
				return;
			}

			// despues saca del modo en el que estes; solo desde SELECCIONAR sale del editor
			if (curMode != MODE_SELECT)
			{
				curMode = MODE_SELECT;
				linkStart = null;
				pathStart = null;
				showOutput('Modo SELECCIONAR (ESC otra vez para salir del editor)');
				return;
			}

			if (!confirmDiscard('ESC')) return;
			MusicBeatState.switchState(new MasterEditorMenu());
			return;
		}

		var prevMode:Int = curMode;
		if (FlxG.keys.justPressed.V) curMode = MODE_SELECT;
		if (FlxG.keys.justPressed.N) curMode = MODE_NODE;
		if (FlxG.keys.justPressed.B) curMode = MODE_DECOR;
		if (FlxG.keys.justPressed.C) curMode = MODE_PATH;
		if (FlxG.keys.justPressed.T) curMode = MODE_TILE;
		// L hace de interruptor: pulsarla otra vez vuelve a SELECCIONAR
		if (FlxG.keys.justPressed.L) curMode = (prevMode == MODE_LINK) ? MODE_SELECT : MODE_LINK;

		if (curMode != prevMode)
		{
			// un enlace, un camino o un rectangulo a medias no sobrevive a un cambio de modo
			linkStart = null;
			pathStart = null;
			cancelBand();

			if (curMode == MODE_LINK)
			{
				if (!showUnlocks)
				{
					showUnlocks = true;
					reloadMap(true);
				}
				showOutput('ENLAZAR: clic en el nodo que desbloquea y luego en los que abre\n(L, V o ESC para salir del modo)');
			}
			else if (prevMode == MODE_LINK) showOutput('Modo ${MODE_NAMES[curMode]}');
		}

		if (FlxG.keys.justPressed.E) gotoNextProblem();

		if (FlxG.keys.justPressed.P)
		{
			paletteShown = !paletteShown;
			camPalette.visible = paletteShown;
		}

		if (FlxG.keys.justPressed.G)
		{
			showGrid = !showGrid;
			gridSprite.visible = showGrid;
		}

		if (FlxG.keys.justPressed.U)
		{
			showUnlocks = !showUnlocks;
			reloadMap(true);
			showOutput(showUnlocks ? 'Flechas de desbloqueo visibles' : 'Flechas de desbloqueo ocultas');
		}

		if (FlxG.keys.justPressed.DELETE)
		{
			if (hasGroup()) deleteGroup();
			else if (selectedNode != null) deleteSelectedNode();
			else if (selectedSprite != null) deleteSelectedSprite();
		}

		var speed:Float = 320 * elapsed / camGame.zoom;
		if (FlxG.keys.pressed.SHIFT) speed *= 3;
		if (FlxG.keys.pressed.LEFT) camGame.scroll.x -= speed;
		if (FlxG.keys.pressed.RIGHT) camGame.scroll.x += speed;
		if (FlxG.keys.pressed.UP) camGame.scroll.y -= speed;
		if (FlxG.keys.pressed.DOWN) camGame.scroll.y += speed;

		if (FlxG.mouse.wheel != 0 && !mouseOnPalette())
		{
			camGame.zoom += FlxG.mouse.wheel * 0.25;
			if (camGame.zoom < 0.5) camGame.zoom = 0.5;
			if (camGame.zoom > 10) camGame.zoom = 10;
		}

		if (FlxG.mouse.pressedMiddle)
		{
			camGame.scroll.x -= FlxG.mouse.deltaScreenX / camGame.zoom;
			camGame.scroll.y -= FlxG.mouse.deltaScreenY / camGame.zoom;
		}
	}

	function mouseOnUI():Bool
	{
		if (UI_box == null || !UI_box.visible) return false;
		return FlxG.mouse.overlaps(UI_box, camHUD);
	}

	function updateMouse()
	{
		if (mouseOnUI())
		{
			dragging = false;
			groupDragLast = null;
			cancelBand();
			return;
		}

		var mouse = FlxG.mouse.getWorldPosition(camGame);
		var mouseX:Float = mouse.x;
		var mouseY:Float = mouse.y;
		mouse.put();

		if (FlxG.mouse.justPressedRight)
		{
			// enlazando, el clic derecho solo cancela: nunca borra un nodo
			if (curMode == MODE_LINK)
			{
				if (linkStart != null) showOutput('Enlace terminado');
				linkStart = null;
				return;
			}

			// sobre un punto de curva, borra solo ese punto
			if ((curMode == MODE_SELECT || curMode == MODE_PATH) && deletePointUnderMouse(mouseX, mouseY)) return;

			// pintando, el clic derecho es la goma: no debe cargarse un nodo sin querer
			deleteUnderMouse(mouseX, mouseY, curMode != MODE_TILE);
			return;
		}

		// pintar tiles: continuo mientras se arrastra
		if (curMode == MODE_TILE && FlxG.mouse.pressed)
		{
			// el paso de deshacer se guarda al pintar la primera casilla que cambia: un clic sobre
			// lo mismo (o sin tile elegido) no debe gastar un paso ni borrar el rehacer
			if (FlxG.mouse.justPressed) strokeUndoPending = true;
			paintTile(mouseX, mouseY);
			return;
		}

		if (FlxG.mouse.justReleased)
		{
			dragging = false;
			dragSnapshot = null;
			dragPointPath = null;
			groupDragLast = null;
			groupDragSprites = null;
			if (bandStart != null) finishBand(mouseX, mouseY);
		}

		// rectangulo de seleccion
		if (bandStart != null && FlxG.mouse.pressed)
		{
			var left:Float = Math.min(bandStart[0], mouseX);
			var top:Float = Math.min(bandStart[1], mouseY);
			bandSprite.visible = true;
			bandSprite.setGraphicSize(Std.int(Math.max(1, Math.abs(mouseX - bandStart[0]))), Std.int(Math.max(1, Math.abs(mouseY - bandStart[1]))));
			bandSprite.updateHitbox();
			bandSprite.setPosition(left, top);
			return;
		}

		if (dragging && FlxG.mouse.pressed)
		{
			var newX:Float = snap(mouseX + dragOffsetX);
			var newY:Float = snap(mouseY + dragOffsetY);

			// arrastrando algo del grupo: todo el grupo se mueve lo mismo
			if (groupDragLast != null)
			{
				var dx:Float = newX - groupDragLast[0];
				var dy:Float = newY - groupDragLast[1];
				if (dx != 0 || dy != 0)
				{
					if (dragSnapshot != null)
					{
						pushUndo(dragSnapshot);
						dragSnapshot = null;
					}
					moveGroupBy(dx, dy);
					groupDragLast = [newX, newY];
					unsavedProgress = true;
				}
				return;
			}

			if (dragPointPath != null)
			{
				var point:Array<Float> = dragPointPath.points[dragPointIndex];
				if (point != null && (point[0] != newX || point[1] != newY))
				{
					if (dragSnapshot != null)
					{
						pushUndo(dragSnapshot);
						dragSnapshot = null;
					}
					point[0] = newX;
					point[1] = newY;
					unsavedProgress = true;
					reloadMap(true);
				}
			}
			else if (selectedNode != null)
			{
				if (selectedNode.x != newX || selectedNode.y != newY)
				{
					if (dragSnapshot != null)
					{
						pushUndo(dragSnapshot);
						dragSnapshot = null;
					}
					moveNodeTo(selectedNode, newX, newY);
					nodeXStepper.value = newX;
					nodeYStepper.value = newY;
					unsavedProgress = true;
					reloadMap(true);
				}
			}
			else if (selectedSprite != null)
			{
				if (selectedSprite.x != newX || selectedSprite.y != newY)
				{
					if (dragSnapshot != null)
					{
						pushUndo(dragSnapshot);
						dragSnapshot = null;
					}
					selectedSprite.x = newX;
					selectedSprite.y = newY;
					decorXStepper.value = newX;
					decorYStepper.value = newY;
					unsavedProgress = true;
					moveDecorSprite(selectedSprite);
				}
			}
			return;
		}

		if (!FlxG.mouse.justPressed) return;

		// un punto de curva se agarra antes que lo que tenga debajo
		if ((curMode == MODE_SELECT || curMode == MODE_PATH) && startPointDrag(mouseX, mouseY)) return;

		switch (curMode)
		{
			case MODE_NODE:
				createNode(snap(mouseX), snap(mouseY));

			case MODE_DECOR:
				createDecor(snap(mouseX), snap(mouseY));

			case MODE_PATH:
				handlePathClick(mouseX, mouseY);

			case MODE_LINK:
				handleLinkClick(mouseX, mouseY);

			default:
				selectUnderMouse(mouseX, mouseY, true);
		}
	}

	function snap(value:Float):Float
	{
		if (FlxG.keys.pressed.ALT) return Math.round(value);

		var grid:Int = worldFile.gridSize;
		if (grid < 2) return Math.round(value);
		return Math.round(value / grid) * grid;
	}

	function nodeUnderMouse(mouseX:Float, mouseY:Float):OverworldNodeFile
	{
		var best:OverworldNodeFile = null;
		var bestDist:Float = 9999;

		for (i in 0...worldFile.nodes.length)
		{
			var node:OverworldNodeFile = worldFile.nodes[i];
			var radius:Float = 10;
			if (i < nodesGroup.length)
			{
				var spr:FlxSprite = nodesGroup.members[i];
				radius = Math.max(spr.width, spr.height) * 0.5 + 3;
			}

			var dx:Float = mouseX - node.x;
			var dy:Float = mouseY - node.y;
			var dist:Float = Math.sqrt(dx * dx + dy * dy);
			if (dist <= radius && dist < bestDist)
			{
				best = node;
				bestDist = dist;
			}
		}
		return best;
	}

	/**
	 * Posicion de cada decorado dentro de su grupo (los de delante y los de detras van en grupos
	 * distintos, en el mismo orden que en `worldFile.sprites`). Una sola pasada: con miles de
	 * tiles, recontarlo por cada decorado eran millones de vueltas en cada clic.
	 */
	function decorLocalIndices():Array<Int>
	{
		var result:Array<Int> = [];
		var front:Int = 0;
		var back:Int = 0;
		for (data in worldFile.sprites) result.push(data.front ? front++ : back++);
		return result;
	}

	/** El sprite que dibuja un decorado, o null. */
	function decorSpriteOf(data:OverworldSpriteFile):FlxSprite
	{
		var index:Int = worldFile.sprites.indexOf(data);
		if (index < 0) return null;

		var local:Int = decorLocalIndices()[index];
		var group = data.front ? spritesFront : spritesBack;
		return local < group.length ? group.members[local] : null;
	}

	/** Mueve solo el sprite de un decorado (no hace falta rehacer los demas). */
	function moveDecorSprite(data:OverworldSpriteFile)
	{
		var spr:FlxSprite = decorSpriteOf(data);
		if (spr == null)
		{
			reloadMap();
			return;
		}
		spr.setPosition(data.x, data.y);

		// si se sale del mapa, el fondo y la rejilla tienen que crecer
		if (data.x + 64 > mapWidth || data.y + 64 > mapHeight) reloadMap(true);
		updateSelectionBox();
	}

	function spriteUnderMouse(mouseX:Float, mouseY:Float):OverworldSpriteFile
	{
		var locals:Array<Int> = decorLocalIndices();
		var index:Int = worldFile.sprites.length - 1;
		while (index >= 0)
		{
			var data:OverworldSpriteFile = worldFile.sprites[index];
			var group = data.front ? spritesFront : spritesBack;
			var localIndex:Int = locals[index];

			if (localIndex < group.length)
			{
				var spr:FlxSprite = group.members[localIndex];
				if (mouseX >= spr.x && mouseX <= spr.x + spr.width && mouseY >= spr.y && mouseY <= spr.y + spr.height)
					return data;
			}
			index--;
		}
		return null;
	}

	function selectUnderMouse(mouseX:Float, mouseY:Float, allowDrag:Bool)
	{
		var shift:Bool = allowDrag && FlxG.keys.pressed.SHIFT;
		var node:OverworldNodeFile = nodeUnderMouse(mouseX, mouseY);
		var data:OverworldSpriteFile = node == null ? spriteUnderMouse(mouseX, mouseY) : null;

		// SHIFT+clic: suma o quita del grupo
		if (shift && (node != null || data != null))
		{
			toggleInGroup(node, data);
			return;
		}

		// agarrar algo del grupo mueve el grupo entero; agarrar otra cosa lo suelta
		var inGroup:Bool = hasGroup() && ((node != null && groupNodes.contains(node)) || (data != null && groupSprites.contains(data)));
		if (!inGroup && !shift) clearGroup();

		if (node != null)
		{
			selectedNode = node;
			selectedSprite = null;
			UI_box.selectedName = 'Nodo';
			updateUI();

			if (allowDrag)
			{
				dragging = true;
				dragSnapshot = snapshot();
				dragOffsetX = node.x - mouseX;
				dragOffsetY = node.y - mouseY;
				if (inGroup) startGroupDrag(node.x, node.y);
			}
			return;
		}

		if (data != null)
		{
			selectedSprite = data;
			selectedNode = null;
			UI_box.selectedName = 'Deco';
			updateUI();

			if (allowDrag)
			{
				dragging = true;
				dragSnapshot = snapshot();
				dragOffsetX = data.x - mouseX;
				dragOffsetY = data.y - mouseY;
				if (inGroup) startGroupDrag(data.x, data.y);
			}
			return;
		}

		// clic en el vacio: suelta la seleccion y empieza un rectangulo (con SHIFT, anade al grupo)
		if (!shift)
		{
			selectedNode = null;
			selectedSprite = null;
		}
		updateSelectionBox();
		if (allowDrag) bandStart = [mouseX, mouseY];
	}

	// ------------------------------------------------------- seleccion en grupo
	inline function hasGroup():Bool
		return groupNodes.length + groupSprites.length > 1;

	/** Tras quitar algo del grupo: con menos de 2 deja de ser grupo, y las cajas se rehacen. */
	function normalizeGroup()
	{
		if (groupNodes.length + groupSprites.length < 2)
		{
			groupNodes = [];
			groupSprites = [];
		}
		refreshGroupBoxes();
	}

	function clearGroup()
	{
		groupNodes = [];
		groupSprites = [];
		groupDragLast = null;
		groupDragSprites = null;
		refreshGroupBoxes();
	}

	function cancelBand()
	{
		bandStart = null;
		if (bandSprite != null) bandSprite.visible = false;
	}

	function endMouseGestures()
	{
		dragging = false;
		dragSnapshot = null;
		dragPointPath = null;
		groupDragLast = null;
		groupDragSprites = null;
		cancelBand();
	}

	/** SHIFT+clic: mete o saca un nodo o decorado del grupo (lo elegido hasta ahora entra primero). */
	function toggleInGroup(node:OverworldNodeFile, data:OverworldSpriteFile)
	{
		if (groupNodes.length + groupSprites.length == 0)
		{
			if (selectedNode != null) groupNodes.push(selectedNode);
			else if (selectedSprite != null) groupSprites.push(selectedSprite);
		}

		if (node != null)
		{
			if (groupNodes.contains(node)) groupNodes.remove(node);
			else groupNodes.push(node);
		}
		if (data != null)
		{
			if (groupSprites.contains(data)) groupSprites.remove(data);
			else groupSprites.push(data);
		}

		// lo que se ve en las pestanas es lo ultimo anadido, o lo que quede
		if (node != null && groupNodes.contains(node))
		{
			selectedNode = node;
			selectedSprite = null;
			UI_box.selectedName = 'Nodo';
		}
		else if (data != null && groupSprites.contains(data))
		{
			selectedSprite = data;
			selectedNode = null;
			UI_box.selectedName = 'Deco';
		}
		else
		{
			selectedNode = groupNodes.length > 0 ? groupNodes[groupNodes.length - 1] : null;
			selectedSprite = (selectedNode == null && groupSprites.length > 0) ? groupSprites[groupSprites.length - 1] : null;
		}

		// con uno solo no hay grupo: es la seleccion normal
		if (groupNodes.length + groupSprites.length < 2)
		{
			groupNodes = [];
			groupSprites = [];
		}

		updateUI();
		refreshGroupBoxes();
		updateSelectionBox();
		if (hasGroup()) showOutput('${groupNodes.length} nodos y ${groupSprites.length} decorados: arrastra para moverlos, CTRL+D duplica, SUPR borra, ESC suelta');
	}

	/** Al soltar el rectangulo: selecciona los nodos (por su centro) y decorados (por su centro) de dentro. */
	function finishBand(mouseX:Float, mouseY:Float)
	{
		var left:Float = Math.min(bandStart[0], mouseX);
		var top:Float = Math.min(bandStart[1], mouseY);
		var right:Float = Math.max(bandStart[0], mouseX);
		var bottom:Float = Math.max(bandStart[1], mouseY);
		var adding:Bool = FlxG.keys.pressed.SHIFT;
		cancelBand();
		if (right - left < 3 && bottom - top < 3) return; // ha sido un clic, no un rectangulo

		inline function inside(x:Float, y:Float):Bool
			return x >= left && x <= right && y >= top && y <= bottom;

		if (!adding) groupNodes = [];
		if (!adding) groupSprites = [];
		if (adding && groupNodes.length + groupSprites.length == 0)
		{
			if (selectedNode != null) groupNodes.push(selectedNode);
			else if (selectedSprite != null) groupSprites.push(selectedSprite);
		}

		for (node in worldFile.nodes)
			if (inside(node.x, node.y) && !groupNodes.contains(node)) groupNodes.push(node);

		var already:haxe.ds.ObjectMap<Dynamic, Bool> = new haxe.ds.ObjectMap<Dynamic, Bool>();
		for (data in groupSprites) already.set(data, true);
		var front:Int = 0;
		var back:Int = 0;
		for (data in worldFile.sprites)
		{
			var local:Int = data.front ? front++ : back++;
			var group = data.front ? spritesFront : spritesBack;
			if (local >= group.length || already.exists(data)) continue;
			var spr:FlxSprite = group.members[local];
			if (inside(spr.x + spr.width * 0.5, spr.y + spr.height * 0.5)) groupSprites.push(data);
		}

		var total:Int = groupNodes.length + groupSprites.length;
		selectedNode = groupNodes.length > 0 ? groupNodes[0] : null;
		selectedSprite = (selectedNode == null && groupSprites.length > 0) ? groupSprites[0] : null;
		if (selectedNode != null) UI_box.selectedName = 'Nodo';
		else if (selectedSprite != null) UI_box.selectedName = 'Deco';
		if (total < 2)
		{
			groupNodes = [];
			groupSprites = [];
		}

		updateUI();
		refreshGroupBoxes();
		updateSelectionBox();
		if (hasGroup()) showOutput('${groupNodes.length} nodos y ${groupSprites.length} decorados: arrastra para moverlos, CTRL+D duplica, SUPR borra, ESC suelta');
	}

	/** Cajas azules sobre todo lo del grupo (la amarilla es el elegido, el que muestran las pestanas). */
	function refreshGroupBoxes()
	{
		if (groupBoxes == null) return;
		groupBoxes.forEach(function(box:FlxSprite) box.destroy());
		groupBoxes.clear();
		if (!hasGroup()) return;

		for (node in groupNodes)
		{
			var index:Int = worldFile.nodes.indexOf(node);
			if (index > -1 && index < nodesGroup.length) addGroupBox(nodesGroup.members[index]);
		}
		if (groupSprites.length > 0)
		{
			var sprites:haxe.ds.ObjectMap<Dynamic, FlxSprite> = decorSpriteMap(groupSprites);
			for (data in groupSprites)
			{
				var spr:FlxSprite = sprites.get(data);
				if (spr != null) addGroupBox(spr);
			}
		}
	}

	function addGroupBox(target:FlxSprite)
	{
		if (target == null) return;
		var box:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		box.color = 0xFF66CCFF;
		box.alpha = 0.35;
		box.setGraphicSize(Std.int(target.width + 2), Std.int(target.height + 2));
		box.updateHitbox();
		box.setPosition(target.x - 1, target.y - 1);
		groupBoxes.add(box);
	}

	/** El sprite de cada decorado pedido, en una sola pasada por la lista (con miles de tiles). */
	function decorSpriteMap(datas:Array<OverworldSpriteFile>):haxe.ds.ObjectMap<Dynamic, FlxSprite>
	{
		var wanted:haxe.ds.ObjectMap<Dynamic, Bool> = new haxe.ds.ObjectMap<Dynamic, Bool>();
		for (data in datas) wanted.set(data, true);

		var result:haxe.ds.ObjectMap<Dynamic, FlxSprite> = new haxe.ds.ObjectMap<Dynamic, FlxSprite>();
		var front:Int = 0;
		var back:Int = 0;
		for (data in worldFile.sprites)
		{
			var local:Int = data.front ? front++ : back++;
			if (!wanted.exists(data)) continue;
			var group = data.front ? spritesFront : spritesBack;
			if (local < group.length) result.set(data, group.members[local]);
		}
		return result;
	}

	function startGroupDrag(x:Float, y:Float)
	{
		groupDragLast = [x, y];
		groupDragSprites = decorSpriteMap(groupSprites);
	}

	/** Mueve todo el grupo. Los caminos entre dos nodos del grupo se mueven enteros, con sus curvas. */
	function moveGroupBy(dx:Float, dy:Float)
	{
		var ids:Map<String, Bool> = new Map<String, Bool>();
		for (node in groupNodes) ids.set(node.id, true);

		for (pth in worldFile.paths)
			if (ids.exists(pth.a) && ids.exists(pth.b) && pth.points != null)
				for (point in pth.points)
				{
					point[0] += dx;
					point[1] += dy;
				}
		for (node in groupNodes) moveNodeTo(node, node.x + dx, node.y + dy, ids);

		var grows:Bool = false;
		for (data in groupSprites)
		{
			data.x += dx;
			data.y += dy;
			var spr:FlxSprite = groupDragSprites != null ? groupDragSprites.get(data) : null;
			if (spr != null) spr.setPosition(data.x, data.y);
			if (data.x + 64 > mapWidth || data.y + 64 > mapHeight) grows = true;
		}
		groupBoxes.forEach(function(box:FlxSprite) box.setPosition(box.x + dx, box.y + dy));

		if (groupNodes.length > 0 || grows) reloadMap(true);
		if (selectedNode != null)
		{
			nodeXStepper.value = selectedNode.x;
			nodeYStepper.value = selectedNode.y;
		}
		if (selectedSprite != null)
		{
			decorXStepper.value = selectedSprite.x;
			decorYStepper.value = selectedSprite.y;
		}
		updateSelectionBox();
	}

	/** SUPR con un grupo: lo borra todo en un solo paso de deshacer. */
	function deleteGroup()
	{
		pushUndo();
		var nodes:Array<OverworldNodeFile> = groupNodes.copy();
		var sprites:Array<OverworldSpriteFile> = groupSprites.copy();
		clearGroup();

		for (node in nodes) removeNode(node);
		flushProgress();
		if (sprites.length > 0)
		{
			var gone:haxe.ds.ObjectMap<Dynamic, Bool> = new haxe.ds.ObjectMap<Dynamic, Bool>();
			for (data in sprites) gone.set(data, true);
			worldFile.sprites = worldFile.sprites.filter(data -> !gone.exists(data));
		}

		selectedNode = null;
		selectedSprite = null;
		selectedPath = null;
		unsavedProgress = true;
		if (sprites.length > 0) reloadMap();
		else reloadMap(true);
		updateUI();
		showOutput('Borrados ${nodes.length} nodos y ${sprites.length} decorados (CTRL+Z para recuperarlos)');
	}

	/**
	 * CTRL+D: duplica lo elegido (o el grupo) un poco mas abajo a la derecha. Los nodos copiados
	 * llevan IDs nuevos, y los caminos y desbloqueos entre ellos apuntan a las copias.
	 */
	function duplicateSelection()
	{
		var nodes:Array<OverworldNodeFile> = hasGroup() ? groupNodes.copy() : (selectedNode != null ? [selectedNode] : []);
		var sprites:Array<OverworldSpriteFile> = hasGroup() ? groupSprites.copy() : (selectedSprite != null ? [selectedSprite] : []);
		if (nodes.length + sprites.length < 1)
		{
			showOutput('Elige antes algo para duplicar (o haz un grupo con SHIFT+clic o un rectangulo)', true);
			return;
		}

		pushUndo();
		var offset:Float = Math.max(8, worldFile.gridSize);
		var idMap:Map<String, String> = new Map<String, String>();
		var newNodes:Array<OverworldNodeFile> = [];
		for (node in nodes)
		{
			var copy:OverworldNodeFile = Reflect.copy(node);
			copy.unlocks = node.unlocks.copy();
			copy.secretUnlocks = node.secretUnlocks.copy();
			var base:String = ~/[0-9]+$/.replace(node.id, '');
			copy.id = OverworldData.uniqueNodeId(worldFile, base.length > 0 ? base : 'node');
			copy.x += offset;
			copy.y += offset;
			idMap.set(node.id, copy.id);
			worldFile.nodes.push(copy);
			OverworldData.clearStaleProgress(worldName, copy.id);
			newNodes.push(copy);
		}

		// los enlaces entre nodos copiados apuntan a las copias
		inline function remap(id:String):String
			return idMap.exists(id) ? idMap.get(id) : id;
		for (copy in newNodes)
		{
			copy.unlocks = [for (id in copy.unlocks) remap(id)];
			copy.secretUnlocks = [for (id in copy.secretUnlocks) remap(id)];
		}
		for (pth in worldFile.paths.copy())
		{
			if (!idMap.exists(pth.a) || !idMap.exists(pth.b)) continue;
			var copy:OverworldPathFile = Reflect.copy(pth);
			copy.a = idMap.get(pth.a);
			copy.b = idMap.get(pth.b);
			copy.points = [for (point in pth.points) [point[0] + offset, point[1] + offset]];
			if (copy.unlockedBy != null && copy.unlockedBy.length > 0) copy.unlockedBy = remap(copy.unlockedBy);
			worldFile.paths.push(copy);
		}

		var newSprites:Array<OverworldSpriteFile> = [];
		for (data in sprites)
		{
			var copy:OverworldSpriteFile = Reflect.copy(data);
			copy.x += offset;
			copy.y += offset;
			worldFile.sprites.push(copy);
			addDecorSprite(copy); // al final de su grupo, igual que en worldFile.sprites
			newSprites.push(copy);
		}

		// lo copiado pasa a ser la seleccion
		groupNodes = newNodes.length + newSprites.length > 1 ? newNodes : [];
		groupSprites = newNodes.length + newSprites.length > 1 ? newSprites : [];
		selectedNode = newNodes.length > 0 ? newNodes[0] : null;
		selectedSprite = (selectedNode == null && newSprites.length > 0) ? newSprites[0] : null;
		unsavedProgress = true;
		reloadMap(true);
		updateUI();
		refreshGroupBoxes();
		updateSelectionBox();
		showOutput('Duplicados ${newNodes.length} nodos y ${newSprites.length} decorados');
	}

	function createNode(x:Float, y:Float)
	{
		pushUndo();

		var node:OverworldNodeFile = OverworldData.createNode(OverworldData.uniqueNodeId(worldFile), x, y);

		var allowed:Array<String> = OverworldData.listSongsOfWeek(node.week);
		if (allowed.length < 1) allowed = songList;
		if (!allowed.contains(node.song) && allowed.length > 0)
		{
			node.song = allowed[0];
			node.name = allowed[0];
		}
		node.image = lastNodeImage;
		node.anim = lastNodeAnim;
		node.fps = lastNodeFps;
		node.type = lastNodeType;
		if (worldFile.nodes.length < 1) node.unlocked = true;

		worldFile.nodes.push(node);
		OverworldData.clearStaleProgress(worldName, node.id); // no hereda el de un nodo borrado
		selectedNode = node;
		selectedSprite = null;
		unsavedProgress = true;

		reloadMap(true);
		UI_box.selectedName = 'Nodo';
		updateUI();
		showOutput('Nodo "${node.id}" creado');
	}

	function createDecor(x:Float, y:Float)
	{
		if (lastDecorImage == null || lastDecorImage.length < 1)
		{
			showOutput('Elige antes un sprite en la pestana "Decorado"', true);
			return;
		}

		pushUndo();

		var data:OverworldSpriteFile = OverworldData.createSprite(lastDecorImage, x, y);
		data.anim = lastDecorAnim;
		worldFile.sprites.push(data);

		selectedSprite = data;
		selectedNode = null;
		unsavedProgress = true;

		addDecorSprite(data);
		if (data.x + 64 > mapWidth || data.y + 64 > mapHeight) reloadMap(true); // el mapa crece
		updateUI();
	}

	function handlePathClick(mouseX:Float, mouseY:Float, ?verticalFirst:Bool = false)
	{
		var node:OverworldNodeFile = nodeUnderMouse(mouseX, mouseY);

		if (node != null)
		{
			if (pathStart == null)
			{
				pathStart = node;
				selectedNode = node;
				selectedSprite = null;
				updateUI();
				showOutput('Camino: nodo inicial "${node.id}", ahora elige el destino');
				return;
			}

			if (pathStart == node)
			{
				pathStart = null;
				showOutput('Camino cancelado');
				return;
			}

			var existing:OverworldPathFile = findPath(pathStart.id, node.id);
			if (existing != null)
			{
				selectedPath = existing;
				pathStart = null;
				UI_box.selectedName = 'Camino';
				reloadMap(true);
				updateUI();
				showOutput('Ese camino ya existia, lo he seleccionado');
				return;
			}

			pushUndo();
			var pth:OverworldPathFile = OverworldData.createPath(pathStart.id, node.id);
			// nodos no alineados: el camino hace una esquina, como en SMW (SHIFT: primero vertical)
			var bent:Bool = lPaths && pathStart.x != node.x && pathStart.y != node.y;
			if (bent) pth.points.push((verticalFirst || FlxG.keys.pressed.SHIFT) ? [pathStart.x, node.y] : [node.x, pathStart.y]);
			worldFile.paths.push(pth);
			selectedPath = pth;
			pathStart = null;
			unsavedProgress = true;

			UI_box.selectedName = 'Camino';
			reloadMap(true);
			updateUI();
			showOutput('Camino creado: ${pth.a} <-> ${pth.b}' + (bent ? ' (en L; con SHIFT al unir, primero vertical)' : ''));
			return;
		}

		// clic en el vacio: anadir punto de curva al camino seleccionado
		if (selectedPath != null)
		{
			pushUndo();
			selectedPath.points.push([snap(mouseX), snap(mouseY)]);
			unsavedProgress = true;
			reloadMap(true);
			updateUI();
			return;
		}

		pathStart = null;
	}

	// ------------------------------------------------------- mover nodos y puntos de curva
	/**
	 * Mueve un nodo arrastrando el punto de curva pegado a el en cada camino: si ese punto estaba
	 * alineado con el nodo en vertical u horizontal, sigue alineado, asi una L no se tuerce.
	 */
	function moveNodeTo(node:OverworldNodeFile, newX:Float, newY:Float, ?skipInside:Map<String, Bool>)
	{
		var oldX:Float = node.x;
		var oldY:Float = node.y;

		for (pth in worldFile.paths)
		{
			if (pth.points == null || pth.points.length < 1 || pth.a == pth.b) continue;
			// un camino con los dos extremos en el grupo ya se ha movido entero
			if (skipInside != null && skipInside.exists(pth.a) && skipInside.exists(pth.b)) continue;

			var point:Array<Float> = null;
			if (pth.a == node.id) point = pth.points[0];
			else if (pth.b == node.id) point = pth.points[pth.points.length - 1];
			if (point == null || point.length < 2) continue;

			if (Math.abs(point[0] - oldX) < 0.01) point[0] = newX;
			if (Math.abs(point[1] - oldY) < 0.01) point[1] = newY;
		}

		node.x = newX;
		node.y = newY;
		unsavedProgress = true;
	}

	/** Punto de curva bajo el raton: [camino, indice], o null. El radio no depende del zoom. */
	function pointUnderMouse(mouseX:Float, mouseY:Float):Array<Dynamic>
	{
		var radius:Float = Math.max(3, 8 / camGame.zoom);
		var best:Array<Dynamic> = null;
		var bestDist:Float = radius;

		for (pth in worldFile.paths)
		{
			if (pth.points == null) continue;
			for (i in 0...pth.points.length)
			{
				var point:Array<Float> = pth.points[i];
				var dist:Float = Math.sqrt(Math.pow(mouseX - point[0], 2) + Math.pow(mouseY - point[1], 2));
				if (dist > bestDist) continue;

				bestDist = dist;
				best = [pth, i];
			}
		}
		return best;
	}

	function startPointDrag(mouseX:Float, mouseY:Float):Bool
	{
		var hit:Array<Dynamic> = pointUnderMouse(mouseX, mouseY);
		if (hit == null) return false;

		var pth:OverworldPathFile = hit[0];
		var index:Int = hit[1];

		selectedPath = pth;
		selectedNode = null;
		selectedSprite = null;
		pathStart = null;

		dragPointPath = pth;
		dragPointIndex = index;
		dragging = true;
		dragSnapshot = snapshot();
		dragOffsetX = pth.points[index][0] - mouseX;
		dragOffsetY = pth.points[index][1] - mouseY;

		UI_box.selectedName = 'Camino';
		reloadMap(true);
		updateUI();
		showOutput('Punto ${index + 1} de ${pth.a} <-> ${pth.b}: arrastra para moverlo, clic derecho para borrarlo');
		return true;
	}

	function deletePointUnderMouse(mouseX:Float, mouseY:Float):Bool
	{
		var hit:Array<Dynamic> = pointUnderMouse(mouseX, mouseY);
		if (hit == null) return false;

		var pth:OverworldPathFile = hit[0];
		var index:Int = hit[1];

		pushUndo();
		pth.points.splice(index, 1);
		selectedPath = pth;
		unsavedProgress = true;
		reloadMap(true);
		updateUI();
		showOutput('Punto borrado de ${pth.a} <-> ${pth.b}');
		return true;
	}

	// ------------------------------------------------------- modo enlazar (L)
	/**
	 * Clic en el nodo que desbloquea y luego en cada nodo que abre: cada clic alterna el enlace.
	 * Enlazar bloquea al destino (si empezaba abierto, el desbloqueo no haria nada) y quitar su
	 * ultimo enlace lo vuelve a dejar abierto, para que el grafo nunca quede con nodos sin salida.
	 */
	function handleLinkClick(mouseX:Float, mouseY:Float, ?forceSecret:Bool = false)
	{
		var node:OverworldNodeFile = nodeUnderMouse(mouseX, mouseY);
		var secret:Bool = forceSecret || FlxG.keys.pressed.SHIFT;

		// con un nodo de origen, clic en un camino: ese camino solo se abre al completarlo
		if (node == null && linkStart != null)
		{
			var pth:OverworldPathFile = pathUnderMouse(mouseX, mouseY);
			if (pth != null)
			{
				linkPath(pth, secret);
				return;
			}
		}

		if (node == null || node == linkStart)
		{
			if (linkStart != null) showOutput('Enlace terminado');
			linkStart = null;
			return;
		}

		if (linkStart == null)
		{
			if (!OverworldData.canBeCompleted(node))
			{
				showOutput('"${node.id}" es "${node.type}" y nunca se completa: no puede desbloquear nada', true);
				return;
			}

			linkStart = node;
			selectedNode = node;
			selectedSprite = null;
			selectedPath = null;
			UI_box.selectedName = 'Nodo';
			updateUI();
			showOutput('"${node.id}": clic en los nodos (o caminos) que desbloquea; SHIFT+clic = con su salida secreta.\nClic en el mismo o en el vacio para terminar');
			return;
		}

		if (secret && linkStart.type != 'level')
		{
			showOutput('Solo un nivel tiene salida secreta: "${linkStart.id}" es "${linkStart.type}"', true);
			return;
		}

		var list:Array<String> = secret ? linkStart.secretUnlocks : linkStart.unlocks;
		if (node.id == worldFile.startNode && !list.contains(node.id))
		{
			showOutput('"${node.id}" es el nodo inicial: tiene que empezar abierto', true);
			return;
		}

		pushUndo();
		var what:String = secret ? 'su salida secreta' : '';
		var message:String;
		if (list.contains(node.id))
		{
			list.remove(node.id);
			message = '"${linkStart.id}" ya no desbloquea "${node.id}"' + (secret ? ' con su salida secreta' : '');
			// nadie mas lo abre: vuelve a empezar abierto (salvo un warp que se abre por su pareja,
			// o un nodo de "N superados": esos empezaban cerrados a proposito)
			if (!node.unlocked && !OverworldData.hasOpener(worldFile, node, worldName))
			{
				node.unlocked = true;
				message += ' (nadie mas lo desbloquea: vuelve a empezar abierto)';
			}
		}
		else
		{
			list.push(node.id);
			message = '"${linkStart.id}" desbloquea "${node.id}"' + (secret ? ' con su salida secreta' : '');
			if (node.unlocked)
			{
				node.unlocked = false;
				message += ' (ahora empieza bloqueado)';
			}
		}

		unsavedProgress = true;
		reloadMap(true);
		updateUI();
		showOutput(message);
	}

	/** Modo ENLAZAR sobre un camino: lo abre `linkStart` al completarse (o con su salida secreta). */
	function linkPath(pth:OverworldPathFile, secret:Bool)
	{
		if (secret && linkStart.type != 'level')
		{
			showOutput('Solo un nivel tiene salida secreta: "${linkStart.id}" es "${linkStart.type}"', true);
			return;
		}

		pushUndo();
		var name:String = '${pth.a} <-> ${pth.b}';
		if (pth.unlockedBy == linkStart.id && pth.secret == secret)
		{
			pth.unlockedBy = '';
			pth.secret = false;
			showOutput('El camino $name ya no depende de "${linkStart.id}": se abre con sus nodos');
		}
		else
		{
			pth.unlockedBy = linkStart.id;
			pth.secret = secret;
			showOutput('El camino $name solo se abre al ' + (secret ? 'sacar la salida secreta de' : 'completar') + ' "${linkStart.id}"');
		}
		selectedPath = pth;
		unsavedProgress = true;
		reloadMap(true);
		updateUI();
	}

	// ------------------------------------------------------- avisos sobre el mapa
	static inline final PROBLEM_DELAY:Float = 0.35;

	/** Recalcula los avisos un rato despues del ultimo cambio, nunca a mitad de un arrastre. */
	function updateProblems(elapsed:Float)
	{
		if (!problemsDirty || dragging) return;

		problemsTimer += elapsed;
		if (problemsTimer < PROBLEM_DELAY) return;

		problemsDirty = false;
		// los otros mundos salen de la cache (se vacia al guardar y al abrir un mundo): releerlos
		// todos de disco en cada comprobacion se notaba con mapas pintados
		problems = OverworldData.checkWorldProblems(worldFile, worldName);
		problemCursor = -1;
		buildProblemMarkers();
	}

	/** Los avisos se recalculan en un momento (cambios que no rehacen el grafo). */
	function markProblemsDirty()
	{
		problemsDirty = true;
		problemsTimer = 0;
	}

	/** Contorno rojo alrededor de cada nodo con algun aviso. */
	function buildProblemMarkers()
	{
		problemGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
		problemGroup.clear();

		var marked:Array<String> = [];
		for (problem in problems)
		{
			if (problem.node == null || marked.contains(problem.node)) continue;
			marked.push(problem.node);

			var index:Int = -1;
			for (i in 0...worldFile.nodes.length)
				if (worldFile.nodes[i].id == problem.node) index = i;
			if (index < 0 || index >= nodesGroup.length) continue;

			var spr:FlxSprite = nodesGroup.members[index];
			var width:Int = Std.int(Math.max(spr.width, 12)) + 6;
			var height:Int = Std.int(Math.max(spr.height, 12)) + 6;

			var box:FlxSprite = new FlxSprite().makeGraphic(width, height, FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawRect(box, 0.5, 0.5, width - 1, height - 1, FlxColor.TRANSPARENT, {color: FlxColor.RED, thickness: 1});
			box.setPosition(worldFile.nodes[index].x - width * 0.5, worldFile.nodes[index].y - height * 0.5);
			problemGroup.add(box);
		}
	}

	/** E: salta al siguiente aviso, centra la camara en su nodo y lo selecciona. */
	function gotoNextProblem()
	{
		if (problemsDirty)
		{
			problemsDirty = false;
			problems = OverworldData.checkWorldProblems(worldFile, worldName);
			problemCursor = -1;
			buildProblemMarkers();
		}
		if (problems.length < 1)
		{
			showOutput('Todo correcto: el mundo se puede recorrer entero.');
			return;
		}

		problemCursor = (problemCursor + 1) % problems.length;
		var problem:OverworldProblem = problems[problemCursor];
		var node:OverworldNodeFile = problem.node != null ? OverworldData.findNode(worldFile, problem.node) : null;

		if (node != null)
		{
			selectedNode = node;
			selectedSprite = null;
			selectedPath = null;
			UI_box.selectedName = 'Nodo';
			updateUI();
			camGame.scroll.set(node.x - camGame.width * 0.5, node.y - camGame.height * 0.5);
		}

		showOutput('AVISO ${problemCursor + 1}/${problems.length}: ${problem.text}', true);
	}

	// ------------------------------------------------------- unir mundos (bloque B)
	var nodeLinkButton:PsychUIButton;
	var nodeGotoButton:PsychUIButton;
	var nodeNeedStepper:PsychUINumericStepper;
	var nodeSecretModeDropDown:PsychUIDropDownMenu;
	var nodeSecretAccStepper:PsychUINumericStepper;
	var nodeSecretInput:PsychUIInputText;
	var pathByDropDown:PsychUIDropDownMenu;
	var pathSecretCheck:PsychUICheckBox;
	var lPathsCheck:PsychUICheckBox;

	/**
	 * El mundo al que lleva un nodo: su destino, o para una salida sin destino, el mapa del que
	 * se entra a este (su padre). null si no lleva a ninguno.
	 */
	function nodeDestination(node:OverworldNodeFile):String
	{
		if (node == null) return null;
		var target:String = (node.world != null && node.world.length > 0) ? node.world : null;
		return switch (node.type)
		{
			case 'world' | 'warp': target;
			case 'exit':
				if (target != null) target;
				else
				{
					var parent:Array<String> = OverworldData.findParentWorld(worldName);
					parent != null ? parent[0] : null;
				}
			default: null;
		}
	}

	/** En el mundo `dest`, el nodo por el que se vuelve aqui desde `node` (su pareja). */
	function returnNodeIn(dest:OverworldFile, node:OverworldNodeFile):OverworldNodeFile
	{
		for (other in dest.nodes)
		{
			switch (node.type)
			{
				case 'world': // dentro del submundo, su salida sin destino
					if (other.type == 'exit' && (other.world == null || other.world.length < 1)) return other;
				case 'exit':
					if (node.world == null || node.world.length < 1)
					{
						if (other.type == 'world' && other.world == worldName) return other; // el castillo de fuera
					}
					else if (other.type == 'exit' && other.world == worldName) return other;
				case 'warp':
					if (other.type == 'warp' && other.world == worldName) return other;
			}
		}
		return null;
	}

	/** Que botones de "unir mundos" tienen sentido para el nodo elegido, y con que texto. */
	function updateNodeButtons()
	{
		if (nodeLinkButton == null) return;

		var node:OverworldNodeFile = selectedNode;
		var action:String = null;
		if (node != null)
		{
			var target:String = (node.world != null && node.world.length > 0) ? node.world : null;
			if (node.type == 'world' && target == null) action = 'Crear submundo';
			else if ((node.type == 'exit' || node.type == 'warp') && target != null)
			{
				var dest:OverworldFile = target == worldName ? null : OverworldData.loadCached(target);
				if (dest != null && returnNodeIn(dest, node) == null) action = 'Crear pareja';
			}
		}
		nodeLinkButton.visible = nodeLinkButton.active = action != null;
		if (action != null) nodeLinkButton.label = action;

		var destination:String = nodeDestination(node);
		nodeGotoButton.visible = nodeGotoButton.active = destination != null && OverworldData.exists(destination);
	}

	function linkNodeWorld()
	{
		if (selectedNode == null) return;
		if (selectedNode.type == 'world') createSubWorld();
		else createPartner();
	}

	/**
	 * Unir mundos escribe en dos archivos, y el otro necesita ver este en disco (una salida sin
	 * destino busca a su padre; un warp, a su pareja): por eso este mundo se guarda a la vez.
	 */
	function canWriteLinkedWorlds():Bool
	{
		if (worldName == null || worldName.trim().length < 1)
		{
			showOutput('Ponle antes un nombre de archivo a este mundo (pestana Mundo)', true);
			return false;
		}
		// el guardado de este mundo se frenaria por sobrescribir otro: que se resuelva antes
		if (worldName != loadedName && OverworldData.exists(worldName))
		{
			showOutput('Ya existe otro mundo "$worldName". Guarda antes este (CTRL+S) o cambiale el nombre', true);
			return false;
		}
		return true;
	}

	/** Un mundo nuevo con los ajustes de este y un primer nivel con el aspecto de sus niveles. */
	function buildStarterWorld(display:String):OverworldFile
	{
		var file:OverworldFile = OverworldData.createEmpty();
		file.displayName = display;
		file.bg = worldFile.bg;
		file.bgAnim = worldFile.bgAnim;
		file.bgFps = worldFile.bgFps;
		file.bgTile = worldFile.bgTile;
		file.music = worldFile.music;
		file.zoom = worldFile.zoom;
		file.gridSize = worldFile.gridSize;
		file.player = worldFile.player;
		file.walkSpeed = worldFile.walkSpeed;

		var first:OverworldNodeFile = file.nodes[0];
		first.id = 'n0';
		first.name = 'Nivel 1';
		first.x = 128;
		first.y = 128;
		var style:OverworldNodeFile = Lambda.find(worldFile.nodes, n -> n.type == 'level');
		if (style != null)
		{
			first.image = style.image;
			first.anim = style.anim;
			first.animDone = style.animDone;
			first.fps = style.fps;
			first.week = style.week;
			first.song = style.song;
		}
		file.startNode = first.id;
		return file;
	}

	/** Un punto fuera de lo que se ve en el juego, a la izquierda de `from` y a su altura. */
	function offscreenLeftOf(file:OverworldFile, from:OverworldNodeFile):Array<Float>
	{
		var size:Array<Float> = OverworldState.mapSize(file);
		var area:Array<Float> = OverworldState.cameraArea(size[0], size[1], file.zoom);
		var grid:Int = file.gridSize > 1 ? file.gridSize : 16;
		return [Math.floor((area[0] - 24) / grid) * grid, from.y];
	}

	/** Un hueco libre junto a `from` (abajo, a la derecha, arriba o a la izquierda). */
	function freeSpotNear(file:OverworldFile, from:OverworldNodeFile):Array<Float>
	{
		var grid:Int = file.gridSize > 1 ? file.gridSize : 16;
		var step:Float = grid * 3;
		for (offset in [[0, step], [step, 0], [0, -step], [-step, 0], [step, step], [-step, step]])
		{
			var x:Float = from.x + offset[0];
			var y:Float = from.y + offset[1];
			if (!Lambda.exists(file.nodes, n -> Math.abs(n.x - x) < grid && Math.abs(n.y - y) < grid)) return [x, y];
		}
		return [from.x, from.y + step * 2];
	}

	/** "Crear submundo": mundo nuevo con un nivel y su salida invisible fuera de la pantalla. */
	function createSubWorld()
	{
		var node:OverworldNodeFile = selectedNode;
		if (node == null || node.type != 'world' || !canWriteLinkedWorlds()) return;

		// si ya se creo antes en esta sesion y se deshizo, se reutiliza (en vez de dejarlo huerfano)
		var baseName:String = OverworldData.toWorldFileName(worldName + '_' + node.id);
		var subName:String = isOrphanCreated(baseName) ? baseName : uniqueWorldName(baseName);
		var sub:OverworldFile = buildStarterWorld(node.name != null && node.name.length > 0 ? node.name : subName);
		var first:OverworldNodeFile = sub.nodes[0];

		// la salida: sin destino vuelve al mapa de fuera, encima de este nodo
		var spot:Array<Float> = offscreenLeftOf(sub, first);
		var exit:OverworldNodeFile = OverworldData.createNode('salida', spot[0], spot[1]);
		exit.type = 'exit';
		exit.image = '';
		exit.anim = '';
		exit.name = 'Salida';
		exit.song = '';
		exit.week = '';
		exit.unlocked = true;
		sub.nodes.push(exit);
		sub.paths.push(OverworldData.createPath(first.id, exit.id));

		if (OverworldData.saveWorldFiles(subName, sub).length < 1)
		{
			showOutput('No se pudo crear el archivo de "$subName"', true);
			return;
		}
		OverworldData.resetProgress(subName); // sin restos de un mundo borrado con el mismo nombre
		createdWorlds.set(subName, OverworldData.stringify(sub));

		pushUndo();
		node.world = subName;
		reloadMap(true);
		updateUI();
		if (!saveWorld()) return; // su mensaje explica por que
		showOutput('Submundo "$subName" creado con un nivel y su salida (se ha guardado "$worldName").\n"Ir al destino" para editarlo');
	}

	/** "Crear pareja": la salida o el warp de vuelta en el mundo destino, unido a su nodo inicial. */
	function createPartner()
	{
		var node:OverworldNodeFile = selectedNode;
		if (node == null || (node.type != 'exit' && node.type != 'warp') || !canWriteLinkedWorlds()) return;
		if (node.world == null || node.world.length < 1) return;

		var destName:String = node.world;
		if (destName == worldName)
		{
			showOutput('"${node.id}" lleva a este mismo mundo: cambia su "Mundo destino"', true);
			return;
		}
		var dest:OverworldFile = OverworldData.load(destName);
		if (dest == null)
		{
			showOutput('No se pudo cargar "$destName"', true);
			return;
		}
		if (returnNodeIn(dest, node) != null)
		{
			showOutput('"$destName" ya tiene la pareja de este nodo');
			return;
		}

		var start:OverworldNodeFile = OverworldData.findNode(dest, dest.startNode);
		if (start == null && dest.nodes.length > 0) start = dest.nodes[0];
		if (start == null)
		{
			showOutput('"$destName" no tiene nodos donde enganchar la pareja', true);
			return;
		}

		var partner:OverworldNodeFile = OverworldData.createNode(OverworldData.uniqueNodeId(dest, 'vuelta'), 0, 0);
		partner.type = node.type;
		partner.world = worldName;
		partner.name = 'Hacia ' + worldFile.displayName;
		partner.song = '';
		partner.week = '';

		var spot:Array<Float>;
		if (node.type == 'warp')
		{
			// tuberia visible junto al nodo inicial; se abre sola cuando este warp esta abierto
			partner.image = node.image;
			partner.anim = node.anim;
			partner.animDone = '';
			partner.fps = node.fps;
			partner.unlocked = false;
			spot = freeSpotNear(dest, start);
		}
		else
		{
			// salida invisible fuera de la pantalla: abierta, o BF no podria entrar andando por ella
			partner.image = '';
			partner.anim = '';
			partner.unlocked = true;
			spot = offscreenLeftOf(dest, start);
		}
		partner.x = spot[0];
		partner.y = spot[1];
		dest.nodes.push(partner);
		dest.paths.push(OverworldData.createPath(start.id, partner.id));

		if (!saveWorld()) return; // su mensaje explica por que
		if (OverworldData.saveWorldFiles(destName, dest).length < 1)
		{
			showOutput('No se pudo guardar "$destName"', true);
			return;
		}
		updateUI();
		markProblemsDirty(); // el aviso de "sin pareja" ya no vale
		showOutput('Pareja "${partner.id}" creada en "$destName" junto a "${start.id}" (se ha guardado "$worldName").\n"Ir al destino" para colocarla donde quieras');
	}

	/** "Ir al destino": abre el otro mundo y selecciona el nodo por el que se vuelve aqui. */
	function gotoDestination()
	{
		var node:OverworldNodeFile = selectedNode;
		var destination:String = nodeDestination(node);
		if (destination == null) return;

		var from:String = worldName;
		var probe:OverworldNodeFile = Reflect.copy(node);
		if (!openWorld(destination, '"Ir al destino"')) return;

		// returnNodeIn compara con el mundo abierto: aqui hay que buscar el que apunta a `from`
		var back:OverworldNodeFile = null;
		for (other in worldFile.nodes)
		{
			var points:Bool = switch (probe.type)
			{
				case 'world': other.type == 'exit' && (other.world == null || other.world.length < 1);
				case 'warp': other.type == 'warp' && other.world == from;
				case 'exit': (probe.world == null || probe.world.length < 1) ? (other.type == 'world' && other.world == from)
					: (other.type == 'exit' && other.world == from);
				default: false;
			}
			if (points)
			{
				back = other;
				break;
			}
		}

		if (back != null)
		{
			selectedNode = back;
			UI_box.selectedName = 'Nodo';
			updateUI();
			updateSelectionBox();
			camGame.scroll.set(back.x - camGame.width * 0.5, back.y - camGame.height * 0.5);
			showOutput('Mundo "$destination" cargado: "${back.id}" lleva de vuelta a "$from"');
		}
	}

	#if debug // autoprueba de "unir mundos" (-selftest): crea mundos zz_*, los comprueba y los borra
	function runSelfTest()
	{
		var fails:Int = 0;
		function check(ok:Bool, what:String)
		{
			trace((ok ? 'SELFTEST OK   ' : 'SELFTEST FAIL ') + what);
			if (!ok) fails++;
		}
		function nodeIn(file:OverworldFile, id:String) return file == null ? null : OverworldData.findNode(file, id);
		function castleWorld(id:String):String
		{
			var node:OverworldNodeFile = OverworldData.findNode(worldFile, id);
			return node == null ? null : node.world;
		}

		// la partida simulada empieza en el mundo de prueba (y no en el de por defecto)
		OverworldData.simStartWorld = 'zz_self';

		// otro mundo sencillo en disco, destino de una salida y un warp
		var other:OverworldFile = OverworldData.createEmpty();
		other.nodes[0].id = 'o0';
		other.startNode = 'o0';
		OverworldData.saveWorldFiles('zz_other', other);

		// mundo de prueba: un nodo world sin destino, una salida y un warp hacia zz_other
		worldName = 'zz_self';
		loadedName = null;
		worldFile = OverworldData.createEmpty();
		worldFile.nodes[0].id = 'n0';
		worldFile.startNode = 'n0';
		var w:OverworldNodeFile = OverworldData.createNode('w', 160, 128);
		w.type = 'world';
		var e:OverworldNodeFile = OverworldData.createNode('e', 128, 192);
		e.type = 'exit';
		e.world = 'zz_other';
		var p:OverworldNodeFile = OverworldData.createNode('p', 96, 128);
		p.type = 'warp';
		p.world = 'zz_other';
		p.image = 'overworld/pipe';
		p.anim = 'idle';
		p.unlocked = false;
		worldFile.nodes[0].unlocks = ['p'];
		for (n in [w, e, p]) worldFile.nodes.push(n);
		for (n in ['w', 'e', 'p']) worldFile.paths.push(OverworldData.createPath('n0', n));
		check(saveWorld(), 'guardar zz_self');
		reloadMap();

		// 1. crear submundo
		selectedNode = OverworldData.findNode(worldFile, 'w');
		updateUI();
		check(nodeLinkButton.visible && nodeLinkButton.label == 'Crear submundo', 'boton "Crear submundo" visible en un world sin destino');
		createSubWorld();
		var subName:String = selectedNode.world;
		var sub:OverworldFile = OverworldData.load(subName);
		check(subName == 'zz_self_w' && sub != null, 'submundo creado en disco: $subName');
		var salida:OverworldNodeFile = nodeIn(sub, 'salida');
		check(salida != null && salida.type == 'exit' && salida.world == '' && salida.unlocked, 'el submundo tiene su salida sin destino, abierta');
		check(salida != null && OverworldData.findNode(sub, sub.startNode) != null && sub.paths.length == 1, 'la salida esta unida al nivel inicial');
		var area:Array<Float> = OverworldState.cameraArea(OverworldState.mapSize(sub)[0], OverworldState.mapSize(sub)[1], sub.zoom);
		check(salida != null && salida.x < area[0], 'la salida queda fuera de la pantalla (x=${salida.x}, vista desde ${area[0]})');
		check(OverworldData.checkWorld(sub, subName).length == 0, 'el submundo no da avisos: ' + OverworldData.checkWorld(sub, subName).join(' | '));
		check(OverworldData.findParentWorld(subName) != null && OverworldData.findParentWorld(subName)[0] == 'zz_self', 'el submundo encuentra a su padre en disco');
		updateUI();
		check(!nodeLinkButton.visible && nodeGotoButton.visible, 'con submundo: sin "Crear", con "Ir al destino"');

		// 2. crear pareja de la salida
		selectedNode = OverworldData.findNode(worldFile, 'e');
		updateUI();
		check(nodeLinkButton.visible && nodeLinkButton.label == 'Crear pareja', 'boton "Crear pareja" en una salida con destino');
		createPartner();
		var otherNow:OverworldFile = OverworldData.load('zz_other');
		var backExit:OverworldNodeFile = otherNow == null ? null : Lambda.find(otherNow.nodes, n -> n.type == 'exit' && n.world == 'zz_self');
		check(backExit != null && backExit.unlocked, 'zz_other tiene la salida de vuelta, abierta');
		check(backExit != null && Lambda.exists(otherNow.paths, pth -> pth.a == 'o0' && pth.b == backExit.id), 'la salida de vuelta esta unida al nodo inicial');

		// 3. crear pareja del warp
		selectedNode = OverworldData.findNode(worldFile, 'p');
		updateUI();
		createPartner();
		otherNow = OverworldData.load('zz_other');
		var backWarp:OverworldNodeFile = otherNow == null ? null : Lambda.find(otherNow.nodes, n -> n.type == 'warp' && n.world == 'zz_self');
		check(backWarp != null && !backWarp.unlocked && backWarp.image == 'overworld/pipe', 'zz_other tiene la tuberia de vuelta (bloqueada, abre por pareja)');
		check(backWarp != null && Math.abs(backWarp.x - 128) + Math.abs(backWarp.y - 128) > 1, 'la tuberia no cae encima del nodo inicial');
		OverworldData.clearWorldCache();
		check(OverworldData.checkWorld(OverworldData.load('zz_other'), 'zz_other').length == 0, 'zz_other no da avisos: ' + OverworldData.checkWorld(OverworldData.load('zz_other'), 'zz_other').join(' | '));
		check(OverworldData.checkWorld(worldFile, worldName).length == 0, 'zz_self no da avisos: ' + OverworldData.checkWorld(worldFile, worldName).join(' | '));
		updateUI();
		check(!nodeLinkButton.visible, 'con pareja ya creada no se ofrece crearla otra vez');

		// 4. etiquetas con destino
		check(nodeLabel(OverworldData.findNode(worldFile, 'w')) == 'w\n> zz_self_w', 'etiqueta del castillo con su destino');

		// 5. ir al destino y volver
		selectedNode = OverworldData.findNode(worldFile, 'w');
		gotoDestination();
		check(worldName == 'zz_self_w' && selectedNode != null && selectedNode.id == 'salida', 'ir al submundo selecciona su salida');
		gotoDestination();
		check(worldName == 'zz_self' && selectedNode != null && selectedNode.id == 'w', 'desde la salida se vuelve al castillo');
		selectedNode = OverworldData.findNode(worldFile, 'p');
		gotoDestination();
		check(worldName == 'zz_other' && selectedNode != null && selectedNode.type == 'warp', 'ir por el warp selecciona su pareja');

		// 6. aspecto de un nodo desde la paleta (CTRL+clic / CTRL+SHIFT+clic)
		var tiled:OverworldNodeFile = worldFile.nodes[0];
		selectedNode = tiled;
		setNodeTile(tiled, 'overworld/og_mario/level_tiles', 'tile0002', false);
		check(tiled.image == 'overworld/og_mario/level_tiles' && tiled.anim == 'tile0002' && tiled.fps == 0, 'tile concreto como aspecto del nodo');
		setNodeTile(tiled, 'overworld/og_mario/overworld_tiles', 'tile0003', true);
		check(tiled.animDone == '', 'el aspecto de completado de otro tileset se rechaza');
		setNodeTile(tiled, 'overworld/og_mario/level_tiles', 'tile0003', true);
		check(tiled.animDone == 'tile0003', 'aspecto de completado del mismo tileset');
		updateUI();
		check(nodeAnimDropDown.list.contains('tile0002') && nodeDoneDropDown.list.contains('tile0003'), 'los desplegables muestran los tiles concretos');
		undo();
		check(worldFile.nodes[0].animDone == '', 'CTRL+Z deshace el aspecto de completado');

		// 7. guardar con el nombre de otro mundo existente pide confirmacion
		worldName = 'zz_self';
		unsavedProgress = false;
		check(!saveWorld(), 'guardar zz_other como "zz_self" (que existe) se frena la primera vez');

		// 8. partida completa: un mundo al que solo se llega por una tuberia que abre ese mismo
		// mundo. Cada mundo por separado parece correcto; jugando desde el principio no se llega.
		var dead:OverworldFile = OverworldData.createEmpty();
		dead.nodes[0].id = 'd0';
		dead.startNode = 'd0';
		var back:OverworldNodeFile = OverworldData.createNode('r', 176, 124);
		back.type = 'warp';
		back.world = 'zz_self';
		back.song = '';
		back.unlocked = false;
		dead.nodes.push(back);
		dead.nodes[0].unlocks = ['r'];
		dead.paths.push(OverworldData.createPath('d0', 'r'));
		OverworldData.saveWorldFiles('zz_dead', dead);

		var selfFile:OverworldFile = OverworldData.load('zz_self');
		var pipe:OverworldNodeFile = OverworldData.createNode('q', 64, 160);
		pipe.type = 'warp';
		pipe.world = 'zz_dead';
		pipe.song = '';
		pipe.unlocked = false;
		selfFile.nodes.push(pipe);
		selfFile.paths.push(OverworldData.createPath(selfFile.startNode, 'q'));
		var selfProblems:Array<OverworldProblem> = OverworldData.checkWorldProblems(selfFile, 'zz_self');
		check(Lambda.exists(selfProblems, pr -> pr.node == 'q' && pr.text.indexOf('jugando desde el principio') > -1),
			'partida completa: se detecta la tuberia que espera a su propio mundo: ' + [for (pr in selfProblems) pr.text].join(' | '));
		var deadProblems:Array<String> = OverworldData.checkWorld(OverworldData.load('zz_dead'), 'zz_dead');
		check(Lambda.exists(deadProblems, t -> t.indexOf('nunca se llega a este mundo') > -1), 'partida completa: se detecta el mundo al que no se llega');

		// 9. deshacer un borrado deja elegido el mismo nodo (antes, por posicion, otro distinto)
		if (worldFile.nodes.length >= 2)
		{
			selectedNode = worldFile.nodes[0];
			deleteSelectedNode();
			selectedNode = worldFile.nodes[worldFile.nodes.length - 1];
			var kept:String = selectedNode.id;
			undo();
			check(selectedNode != null && selectedNode.id == kept, 'deshacer un borrado conserva la seleccion ("$kept")');
		}

		// 10. pintar encima del mismo tile no gasta un paso de deshacer ni borra el rehacer
		if (paletteFrames.length > 0)
		{
			paletteSelected = 0;
			var size:Float = paletteTileSize;
			strokeUndoPending = true;
			paintTile(size * 0.5, size * 0.5);
			strokeUndoPending = true;
			paintTile(size * 1.5, size * 0.5);
			undo();
			var undoCount:Int = undoStack.length;
			var redoCount:Int = redoStack.length;
			strokeUndoPending = true;
			paintTile(size * 0.5, size * 0.5);
			check(redoCount > 0 && undoStack.length == undoCount && redoStack.length == redoCount, 'pintar encima del mismo tile no gasta deshacer ni borra el rehacer');
		}

		// 11. grupo: duplicar con su camino de dentro, borrar en un paso y deshacer
		worldName = 'zz_group';
		loadedName = null;
		worldFile = OverworldData.createEmpty();
		worldFile.nodes = [];
		resetHistory();
		var ga:OverworldNodeFile = OverworldData.createNode('a', 64, 64);
		var gb:OverworldNodeFile = OverworldData.createNode('b', 128, 64);
		var gc:OverworldNodeFile = OverworldData.createNode('c', 64, 128);
		for (n in [ga, gb, gc]) worldFile.nodes.push(n);
		worldFile.paths.push(OverworldData.createPath('a', 'b'));
		worldFile.paths.push(OverworldData.createPath('a', 'c'));
		ga.unlocks = ['b'];
		worldFile.startNode = 'a';
		reloadMap();

		selectedNode = ga;
		toggleInGroup(gb, null);
		check(hasGroup() && groupNodes.length == 2, 'SHIFT+clic arma un grupo de 2 nodos');
		duplicateSelection();
		var copies:Array<OverworldNodeFile> = groupNodes.copy();
		var copyPath:Bool = copies.length == 2 && findPath(copies[0].id, copies[1].id) != null;
		check(worldFile.nodes.length == 5 && copyPath && copies[0].unlocks.join(',') == copies[1].id,
			'duplicar el grupo copia sus nodos, el camino de dentro y el desbloqueo entre ellos');
		deleteGroup();
		check(worldFile.nodes.length == 3 && worldFile.paths.length == 2, 'SUPR borra el grupo entero');
		undo();
		check(worldFile.nodes.length == 5 && worldFile.paths.length == 3, 'CTRL+Z recupera el grupo borrado');

		// mover el grupo arrastra tambien las curvas del camino de dentro
		var inner:OverworldPathFile = findPath(copies[0].id, copies[1].id);
		if (inner != null)
		{
			var na:OverworldNodeFile = OverworldData.findNode(worldFile, inner.a);
			var nb:OverworldNodeFile = OverworldData.findNode(worldFile, inner.b);
			inner.points = [[na.x, na.y + 32]];
			groupNodes = [na, nb];
			groupSprites = [];
			startGroupDrag(na.x, na.y);
			moveGroupBy(16, 0);
			groupDragLast = null;
			check(inner.points[0][0] == na.x && inner.points[0][1] == na.y + 32, 'mover el grupo mueve las curvas de sus caminos');
			clearGroup();
		}

		// 12. borrar un nodo aparta su progreso y deshacer se lo devuelve
		OverworldData.setCompleted('zz_group', 'c');
		OverworldData.setCompleted('zz_group', 'c' + OverworldData.SECRET);
		selectedNode = OverworldData.findNode(worldFile, 'c');
		deleteSelectedNode();
		check(!OverworldData.isCompleted('zz_group', 'c') && !OverworldData.isSecretCompleted('zz_group', 'c'), 'borrar un nodo aparta su progreso');
		undo();
		check(OverworldData.isCompleted('zz_group', 'c') && OverworldData.isSecretCompleted('zz_group', 'c'), 'deshacer el borrado le devuelve el progreso (y el de su salida secreta)');

		// 13. deshacer un trazo de tiles quita solo esos tiles (sin rehacer los demas)
		if (paletteFrames.length > 0)
		{
			paletteSelected = 0;
			var cell:Float = paletteTileSize;
			strokeUndoPending = true;
			for (i in 0...3) paintTile(cell * (i + 0.5), cell * 6.5);
			strokeUndoPending = true;
			for (i in 0...2) paintTile(cell * (i + 0.5), cell * 7.5);
			var backSprites:FlxSprite = spritesBack.members[0];
			undo();
			var backCount:Int = Lambda.count(worldFile.sprites, d -> !d.front);
			check(worldFile.sprites.length == 3 && spritesBack.length == backCount && spritesBack.members[0] == backSprites,
				'deshacer un trazo quita solo sus tiles y deja los demas sprites como estaban');
			redo();
			check(worldFile.sprites.length == 5 && spritesBack.length == Lambda.count(worldFile.sprites, d -> !d.front), 'rehacer el trazo vuelve a ponerlos');
		}

		// 14. rectangulo de seleccion
		bandStart = [0, 0];
		finishBand(160, 160);
		check(hasGroup() && groupNodes.length >= 3, 'el rectangulo selecciona los nodos de dentro (${groupNodes.length} nodos, ${groupSprites.length} decorados)');
		clearGroup();

		// 15. "Crear submundo" deshecho: al guardar se borra el submundo que ya no usa nadie
		var castle:OverworldNodeFile = OverworldData.createNode('w', 128, 128);
		castle.type = 'world';
		worldFile.nodes.push(castle);
		worldFile.paths.push(OverworldData.createPath('a', 'w'));
		reloadMap(true);
		selectedNode = castle;
		createSubWorld();
		var orphan:String = castle.world;
		check(orphan != null && orphan.length > 0 && OverworldData.exists(orphan), 'submundo creado para deshacerlo: $orphan');
		undo();
		check(saveWorld() && OverworldData.exists(orphan), 'mientras CTRL+Y pueda volver a el, el submundo deshecho se queda');
		redo();
		check(OverworldData.exists(orphan) && castleWorld(castle.id) == orphan, 'rehacer vuelve a enlazar el submundo');
		undo();
		pushUndo(); // otra accion: el rehacer se vacia y ya nada puede volver a el
		undoStack = undoStack.filter(state -> state.indexOf('"world":"$orphan"') < 0);
		check(saveWorld() && !OverworldData.exists(orphan), 'guardar cuando ya nada lo usa borra el submundo sin usar');

		// 15b. "N superados" en un nodo abierto lo cierra
		var needNode:OverworldNodeFile = OverworldData.findNode(worldFile, 'b');
		selectedNode = needNode;
		updateUI();
		nodeNeedStepper.value = 2;
		nodeNeedStepper.onValueChange();
		check(needNode.needLevels == 2 && !needNode.unlocked, 'poner "N superados" a un nodo abierto lo deja cerrado');
		nodeNeedStepper.value = 0;
		nodeNeedStepper.onValueChange();

		// 16. avisos de las reglas nuevas
		var rules:OverworldFile = OverworldData.createEmpty();
		rules.nodes[0].id = 'r0';
		rules.startNode = 'r0';
		var need:OverworldNodeFile = OverworldData.createNode('need', 96, 124);
		need.unlocked = false;
		need.needLevels = 5;
		var notLevel:OverworldNodeFile = OverworldData.createNode('paso', 160, 124);
		notLevel.type = 'empty';
		notLevel.secretUnlocks = ['need'];
		rules.nodes.push(need);
		rules.nodes.push(notLevel);
		rules.paths.push(OverworldData.createPath('r0', 'need'));
		var ghostPath:OverworldPathFile = OverworldData.createPath('r0', 'paso');
		ghostPath.unlockedBy = 'nadie';
		rules.paths.push(ghostPath);
		var ruleTexts:String = OverworldData.checkWorld(rules, 'zz_rules').join(' | ');
		check(ruleTexts.indexOf('se abre con 5 superados') > -1, 'aviso: pide mas superados de los que hay');
		check(ruleTexts.indexOf('solo un nivel con cancion tiene salida secreta') > -1, 'aviso: salida secreta en algo que no es un nivel');
		check(ruleTexts.indexOf('lo abre "nadie", que no existe') > -1, 'aviso: camino abierto por un nodo que no existe');

		// limpieza: build y repo
		for (name in ['zz_self', 'zz_self_w', 'zz_other', 'zz_dead', 'zz_group', 'zz_group_w'])
		{
			for (folder in [Paths.getSharedPath('overworlds/'), '../../../../assets/shared/overworlds/'])
				if (FileSystem.exists('$folder$name.json')) FileSystem.deleteFile('$folder$name.json');
			OverworldData.resetProgress(name);
		}
		OverworldData.clearWorldCache();
		OverworldData.simStartWorld = null;
		trace('SELFTEST FIN: ' + (fails == 0 ? 'todo correcto' : '$fails fallos'));
	}
	#end

	function findPath(a:String, b:String):OverworldPathFile
	{
		for (pth in worldFile.paths)
			if ((pth.a == a && pth.b == b) || (pth.a == b && pth.b == a)) return pth;
		return null;
	}

	function deleteUnderMouse(mouseX:Float, mouseY:Float, allowNodes:Bool = true)
	{
		var node:OverworldNodeFile = allowNodes ? nodeUnderMouse(mouseX, mouseY) : null;
		if (node != null)
		{
			selectedNode = node;
			deleteSelectedNode();
			return;
		}

		var data:OverworldSpriteFile = spriteUnderMouse(mouseX, mouseY);
		if (data != null)
		{
			selectedSprite = data;
			deleteSelectedSprite();
		}
	}

	function deleteSelectedNode()
	{
		if (selectedNode == null) return;

		pushUndo();
		var id:String = selectedNode.id;
		removeNode(selectedNode);
		flushProgress();
		selectedNode = null;
		selectedPath = null;
		unsavedProgress = true;

		reloadMap(true);
		updateUI();
		showOutput('Nodo "$id" borrado');
	}

	/** Quita un nodo con sus caminos y todo lo que lo nombra (sin paso de deshacer ni recarga). */
	function removeNode(node:OverworldNodeFile)
	{
		var id:String = node.id;

		// un camino o un enlace a medias desde este nodo se quedaria apuntando a un nodo borrado
		if (pathStart == node) pathStart = null;
		if (linkStart == node) linkStart = null;
		if (groupNodes.remove(node)) normalizeGroup();
		worldFile.nodes.remove(node);

		// su progreso se aparta: otro nodo con este ID no lo hereda, y deshacer se lo devuelve
		stashProgress(id);

		var index:Int = worldFile.paths.length - 1;
		while (index >= 0)
		{
			var pth:OverworldPathFile = worldFile.paths[index];
			if (pth.a == id || pth.b == id) worldFile.paths.remove(pth);
			index--;
		}

		for (other in worldFile.nodes)
		{
			if (other.unlocks != null) other.unlocks = other.unlocks.filter(target -> target != id);
			if (other.secretUnlocks != null) other.secretUnlocks = other.secretUnlocks.filter(target -> target != id);
		}
		for (pth in worldFile.paths)
		{
			if (pth.unlockedBy != id) continue;
			pth.unlockedBy = '';
			pth.secret = false;
		}

		// sin esto el mundo se quedaria apuntando a un nodo inicial que ya no existe
		if (worldFile.startNode == id && worldFile.nodes.length > 0)
		{
			var first:OverworldNodeFile = Lambda.find(worldFile.nodes, n -> n.type != 'exit');
			worldFile.startNode = (first != null ? first : worldFile.nodes[0]).id;
			refreshNodeIdLists();
		}
	}

	/** Aparta (y borra de la partida) el progreso de un nodo que desaparece. */
	function stashProgress(id:String)
	{
		for (key in [id, id + OverworldData.SECRET])
		{
			if (!OverworldData.isCompleted(worldName, key)) continue;
			removedProgress.set(key, true);
			OverworldData.setCompleted(worldName, key, false, false);
			progressDirty = true;
		}
	}

	/** Devuelve el progreso apartado a un nodo que vuelve a aparecer (deshacer su borrado). */
	function restoreProgress(id:String)
	{
		for (key in [id, id + OverworldData.SECRET])
		{
			if (!removedProgress.exists(key)) continue;
			removedProgress.remove(key);
			OverworldData.setCompleted(worldName, key, true, false);
			progressDirty = true;
		}
	}

	/** La partida se escribe una sola vez al final de un borrado o un deshacer, no por cada nodo. */
	var progressDirty:Bool = false;

	function flushProgress()
	{
		if (!progressDirty) return;
		progressDirty = false;
		FlxG.save.flush();
	}

	function deleteSelectedSprite()
	{
		if (selectedSprite == null) return;

		pushUndo();
		removeDecor(selectedSprite);
		selectedSprite = null;
		unsavedProgress = true;
		updateUI();
	}

	/**
	 * Quita un decorado y solo su sprite: es la goma del modo tiles, y rehacer miles de tiles
	 * por cada uno borrado costaba casi un segundo.
	 */
	function removeDecor(data:OverworldSpriteFile)
	{
		var spr:FlxSprite = decorSpriteOf(data);
		worldFile.sprites.remove(data);
		if (selectedSprite == data) selectedSprite = null;
		if (groupSprites.remove(data)) normalizeGroup();
		if (spr == null)
		{
			reloadMap();
			return;
		}

		(data.front ? spritesFront : spritesBack).remove(spr, true);
		spr.destroy();
		updateSelectionBox();
	}

	// ------------------------------------------------------------------ guardar
	var overwriteAskedAt:Float = -999;

	/** Guarda en la build y en el repo. false si no se ha guardado. */
	function saveWorld():Bool
	{
		if (worldName == null || worldName.trim().length < 1)
		{
			showOutput('Ponle un nombre de archivo al mundo', true);
			return false;
		}

		// otro nombre que ya existe en disco: se sobrescribiria otro mundo sin querer
		if (worldName != loadedName && OverworldData.exists(worldName))
		{
			var now:Float = haxe.Timer.stamp();
			if (now - overwriteAskedAt > 5)
			{
				overwriteAskedAt = now;
				showOutput('Ya existe un mundo "$worldName" y lo sobrescribirias.\nCambia el nombre de archivo, o guarda otra vez para sobrescribirlo', true);
				return false;
			}
			overwriteAskedAt = -999;
		}

		var saved:Array<String> = OverworldData.saveWorldFiles(worldName, worldFile);
		if (saved.length < 1)
		{
			showOutput('No se pudo guardar, prueba con "Guardar como..."', true);
			return false;
		}

		loadedName = worldName;
		unsavedProgress = false;
		savedThisFrame = true;
		var orphans:Array<String> = cleanupOrphanWorlds();
		refreshWorldLists();

		var problems:Array<String> = checkWorld();
		if (problems.length > 0)
		{
			var shown:Array<String> = problems.slice(0, 3);
			if (problems.length > 3) shown.push('(+${problems.length - 3} mas)');
			showOutput('Guardado, pero con avisos:
' + shown.join('
'), true);
		}
		else showOutput('Guardado en: ' + saved.join('  +  '));
		if (orphans.length > 0) showOutput(outputTxt.text + '\nBorrado el submundo sin usar: ' + orphans.join(', '), outputTxt.color == FlxColor.RED);
		return true;
	}

	/**
	 * Submundos creados en esta sesion con "Crear submundo" que ya no usa nadie (se deshizo) y que
	 * nadie ha tocado desde entonces: se borran al guardar, para no dejar archivos huerfanos.
	 */
	function cleanupOrphanWorlds():Array<String>
	{
		var removed:Array<String> = [];
		for (name in [for (key in createdWorlds.keys()) key])
		{
			if (!isOrphanCreated(name)) continue;
			OverworldData.deleteWorldFiles(name);
			createdWorlds.remove(name);
			removed.push(name);
		}
		return removed;
	}

	function isOrphanCreated(name:String):Bool
	{
		if (!createdWorlds.exists(name) || name == worldName) return false;
		if (Lambda.exists(worldFile.nodes, n -> n.world == name)) return false;

		// editado despues de crearlo: ya es trabajo de alguien, se queda
		var raw:String = Paths.getTextFromFile('${OverworldData.FOLDER}/$name.json');
		if (raw == null || raw != createdWorlds.get(name)) return false;

		// ningun otro mundo lleva a el (este se mira en memoria, arriba)
		for (type in ['world', 'exit', 'warp'])
			for (entry in OverworldData.nodesInto(name, type))
				if (entry[0] != worldName) return false;

		// CTRL+Z / CTRL+Y aun pueden volver a un estado que lo usa: se queda hasta que no
		var mark:String = '"world":"$name"';
		for (state in undoStack) if (state.indexOf(mark) > -1) return false;
		for (state in redoStack) if (state.indexOf(mark) > -1) return false;
		return true;
	}

	/** Deshacer o rehacer vuelve a un castillo cuyo submundo (creado aqui) ya se borro: se recrea. */
	function restoreCreatedWorlds()
	{
		for (node in worldFile.nodes)
		{
			if (node.world == null || !createdWorlds.exists(node.world) || OverworldData.exists(node.world)) continue;
			var file:OverworldFile = cast haxe.Json.parse(createdWorlds.get(node.world));
			OverworldData.applyDefaults(file);
			OverworldData.saveWorldFiles(node.world, file);
		}
	}

	function saveWorldAs()
	{
		if (!fileDialog.completed) return;

		fileDialog.save('$worldName.json', OverworldData.stringify(worldFile), function()
		{
			unsavedProgress = false;
			showOutput('Guardado en ${fileDialog.path}');
		}, null, function() showOutput('Error al guardar', true));
	}

	function testWorld(?fromSelected:Bool = false)
	{
		var start:OverworldNodeFile = fromSelected ? selectedNode : null;
		if (fromSelected && (start == null || start.type == 'exit'))
		{
			showOutput('Para probar desde un nodo, elige antes uno (que no sea una salida)', true);
			return;
		}

		// sin guardar se probaria la version vieja del archivo (o la de otro mundo)
		if (!saveWorld()) return;

		OverworldState.reset();
		OverworldState.curWorld = worldName;
		OverworldState.returnToEditor = true;
		OverworldState.editorWorld = worldName;
		if (start != null)
		{
			// BF aparece ahi aunque con la partida actual ese nodo aun este cerrado
			OverworldState.testStartWorld = worldName;
			OverworldState.testStartNode = start.id;
		}
		MusicBeatState.switchState(new OverworldState(worldName, start != null ? start.id : null));
	}

	var outputTimer:FlxTimer;

	function showOutput(text:String, ?error:Bool = false)
	{
		outputTxt.color = error ? FlxColor.RED : FlxColor.LIME;
		outputTxt.text = text;

		if (outputTimer != null) outputTimer.cancel();
		outputTimer = new FlxTimer().start(5, function(_:FlxTimer) if (outputTxt != null) outputTxt.text = '');
	}

	/** Algun control de la UI ha lanzado un evento en este fotograma (ver update). */
	var uiEventThisFrame:Bool = false;

	public function UIEvent(id:String, sender:Dynamic)
	{
		// la marca de "sin guardar" no se pone aqui: elegir tileset, cargar un mundo de la lista o
		// las casillas de vista no cambian el mundo. La ponen recordUIChange / trackFocusEdits
		// cuando el mundo de verdad ha cambiado.
		uiEventThisFrame = true;
	}
}
