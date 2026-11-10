package states.editors;

import backend.OverworldData;
import backend.WeekData;

import states.OverworldState;
import states.editors.content.FileDialogHandler;

import flixel.FlxObject;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSpriteUtil;

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

	static final MODE_NAMES:Array<String> = ['SELECCIONAR (V)', 'NODO (N)', 'DECORADO (B)', 'CAMINO (C)', 'PINTAR TILES (T)'];

	static inline var PALETTE_WIDTH:Int = 300;

	var worldName:String = 'nuevo_mundo';
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

		worldFile = OverworldData.load(worldName);
		if (worldFile == null) worldFile = OverworldData.createEmpty();

		spritesBack = new FlxTypedGroup<FlxSprite>();
		dotsGroup = new FlxTypedGroup<FlxSprite>();
		nodesGroup = new FlxTypedGroup<FlxSprite>();
		spritesFront = new FlxTypedGroup<FlxSprite>();
		labelsGroup = new FlxTypedGroup<FlxText>();

		add(spritesBack);
		add(dotsGroup);
		add(nodesGroup);
		add(spritesFront);
		add(labelsGroup);

		selectionBox = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		selectionBox.color = FlxColor.YELLOW;
		selectionBox.alpha = 0.35;
		selectionBox.visible = false;
		add(selectionBox);

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

		super.create();
	}

	// ------------------------------------------------------------------ mapa
	function reloadMap()
	{
		OverworldData.applyDefaults(worldFile);

		for (old in bgSprites)
		{
			remove(old);
			old.destroy();
		}
		bgSprites = OverworldState.buildBackgroundSprites(worldFile);
		for (i in 0...bgSprites.length) insert(i, bgSprites[i]);
		bgSprite = bgSprites.length > 0 ? bgSprites[bgSprites.length - 1] : null;

		calcMapSize();
		buildGrid();

		spritesBack.forEachAlive(function(spr:FlxSprite) spr.destroy());
		spritesFront.forEachAlive(function(spr:FlxSprite) spr.destroy());
		nodesGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
		dotsGroup.forEachAlive(function(spr:FlxSprite) spr.destroy());
		labelsGroup.forEachAlive(function(txt:FlxText) txt.destroy());
		spritesBack.clear();
		spritesFront.clear();
		nodesGroup.clear();
		dotsGroup.clear();
		labelsGroup.clear();

		for (data in worldFile.sprites)
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

			if (data.front) spritesFront.add(spr);
			else spritesBack.add(spr);
		}

		for (node in worldFile.nodes)
		{
			var spr:FlxSprite = OverworldState.buildSprite(node.image, node.anim, node.fps);
			spr.setPosition(node.x - spr.width * 0.5, node.y - spr.height * 0.5);
			nodesGroup.add(spr);

			var label:FlxText = new FlxText(node.x - 50, node.y + spr.height * 0.5 + 1, 100, node.id, 8);
			label.setFormat(Paths.font('vcr.ttf'), 8, labelColor(node), CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 1;
			labelsGroup.add(label);
		}

		buildPathLines();
		updateSelectionBox();
	}

	function labelColor(node:OverworldNodeFile):FlxColor
	{
		return switch (node.type)
		{
			case 'world': 0xFF7FD4FF;
			case 'empty': 0xFFBBBBBB;
			case 'exit': 0xFFFFA040;
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
			remove(gridSprite);
			gridSprite.destroy();
		}

		var wid:Int = Std.int(mapWidth);
		var hei:Int = Std.int(mapHeight);
		gridSprite = new FlxSprite().makeGraphic(wid, hei, FlxColor.TRANSPARENT, true);

		var grid:Int = worldFile.gridSize;
		if (grid < 2) grid = 16;

		var x:Int = 0;
		while (x <= wid)
		{
			FlxSpriteUtil.drawLine(gridSprite, x, 0, x, hei, {color: 0x33FFFFFF, thickness: 1});
			x += grid;
		}

		var y:Int = 0;
		while (y <= hei)
		{
			FlxSpriteUtil.drawLine(gridSprite, 0, y, wid, y, {color: 0x33FFFFFF, thickness: 1});
			y += grid;
		}

		FlxSpriteUtil.drawRect(gridSprite, 0, 0, wid - 1, hei - 1, FlxColor.TRANSPARENT, {color: 0x66FF00FF, thickness: 1});

		gridSprite.visible = showGrid;
		insert(members.indexOf(spritesBack), gridSprite);
	}

	var showGrid:Bool = true;

	function buildPathLines()
	{
		if (linesSprite != null)
		{
			remove(linesSprite);
			linesSprite.destroy();
		}

		linesSprite = new FlxSprite().makeGraphic(Std.int(mapWidth), Std.int(mapHeight), FlxColor.TRANSPARENT, true);
		insert(members.indexOf(nodesGroup), linesSprite);

		for (pth in worldFile.paths)
		{
			var nodeA:OverworldNodeFile = OverworldData.findNode(worldFile, pth.a);
			var nodeB:OverworldNodeFile = OverworldData.findNode(worldFile, pth.b);
			if (nodeA == null || nodeB == null) continue;

			var color:FlxColor = (pth == selectedPath) ? 0xFFFFFF00 : 0xFF00FF88;
			var line:Array<Array<Float>> = OverworldState.buildLine(pth, nodeA, nodeB);

			for (i in 0...line.length - 1)
				FlxSpriteUtil.drawLine(linesSprite, line[i][0], line[i][1], line[i + 1][0], line[i + 1][1], {color: color, thickness: 1});

			if (pth.points != null)
				for (point in pth.points)
					FlxSpriteUtil.drawRect(linesSprite, point[0] - 2, point[1] - 2, 4, 4, color);

			// vista previa de los puntitos del camino
			for (point in OverworldState.getDotPositions(pth, nodeA, nodeB))
			{
				var dot:FlxSprite = OverworldState.buildSprite(pth.dots, pth.dotAnim, 6);
				dot.setPosition(point[0] - dot.width * 0.5, point[1] - dot.height * 0.5);
				dot.alpha = 0.8;
				dotsGroup.add(dot);
			}
		}
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
		worldList = OverworldData.listWorlds();
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

		modeTxt = new FlxText(10, 42, 640, '', 16);
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
			+ 'V  modo seleccionar (mover nodos y decorados)\n'
			+ 'N  modo nodo: clic para crear un nivel\n'
			+ 'B  modo decorado: clic para colocar el sprite elegido\n'
			+ 'C  modo camino: clic en nodo A y luego en nodo B para unirlos\n'
			+ '   (con un camino elegido, clic en el vacio anade un punto de curva)\n'
			+ 'T  modo pintar tiles: elige un tile en la paleta y pinta arrastrando\n'
			+ 'P  mostrar / ocultar la paleta de tiles\n\n'
			+ 'Clic derecho          borrar lo que hay bajo el raton\n'
			+ 'SUPR                  borrar la seleccion\n'
			+ 'ALT (mantener)        colocar sin ajustar a la rejilla\n'
			+ 'Rueda del raton       zoom\n'
			+ 'Raton central / flechas  mover la camara\n'
			+ 'G                     mostrar/ocultar rejilla\n'
			+ 'CTRL+Z / CTRL+Y       deshacer / rehacer\n'
			+ 'CTRL+S                guardar\n'
			+ 'CTRL+T                probar el mundo\n'
			+ 'F1                    esta ayuda\n'
			+ 'ESC                   volver al menu de editores';

		helpTxt = new FlxText(40, 60, FlxG.width - 80, text, 16);
		helpTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT);
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
		zoomStepper.onValueChange = function() worldFile.zoom = zoomStepper.value;
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
		startDropDown = new PsychUIDropDownMenu(x, y, nodeIdList(), function(sel:Int, value:String) worldFile.startNode = value, 150);
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
			pushUndo();
			for (node in worldFile.nodes) node.unlocked = true;
			reloadMap();
			updateUI();
			showOutput('Todos los nodos quedan accesibles desde el principio');
		}, 155));

		showAllCheck = new PsychUICheckBox(x + 165, y - 32, 'Ver todos los sprites', 160, function()
		{
			showAllImages = showAllCheck.checked;
			refreshImageLists();
		});
		tab.add(showAllCheck);

		y += 36;
		tab.add(new PsychUIButton(x, y, 'Mundo nuevo', function()
		{
			pushUndo();
			worldFile = OverworldData.createEmpty();
			selectedNode = null;
			selectedSprite = null;
			selectedPath = null;
			reloadMap();
			updateUI();
			showOutput('Mundo nuevo creado (sin guardar)');
		}, 100));

		worldsDropDown = new PsychUIDropDownMenu(x + 110, y, worldList, function(sel:Int, value:String)
		{
			if (value == null || value.length < 1) return;

			var loaded:OverworldFile = OverworldData.load(value);
			if (loaded == null)
			{
				showOutput('No se pudo cargar "$value"', true);
				return;
			}

			pushUndo();
			worldName = value;
			worldFile = loaded;
			selectedNode = null;
			selectedSprite = null;
			selectedPath = null;
			reloadMap();
			updateUI();
			showOutput('Mundo "$value" cargado');
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

			if (worldFile.startNode == oldId) worldFile.startNode = newId;
			unsavedProgress = true;
			showOutput('Nodo "$oldId" renombrado a "$newId"');
			selectedNode.id = newId;
			reloadMap();
			refreshNodeIdLists();
		};
		tab.add(nodeIdInput);

		label(tab, x + 120, y - 17, 'Tipo:');
		nodeTypeDropDown = new PsychUIDropDownMenu(x + 120, y, ['level', 'world', 'empty', 'exit'], function(sel:Int, value:String)
		{
			if (selectedNode == null) return;
			pushUndo();
			selectedNode.type = value;
			lastNodeType = value;

			// Por defecto una salida es invisible: se coloca fuera de la pantalla y BF se va
			// andando por su camino. Si se quiere una salida visible (un tubo), se le pone sprite.
			if (value == 'exit' && selectedNode.image == OverworldData.createNode('', 0, 0).image)
			{
				selectedNode.image = '';
				selectedNode.anim = '';
				showOutput('Salida invisible: colocala fuera de la pantalla o ponle un sprite (un tubo...)');
			}

			unsavedProgress = true;
			reloadMap();
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
			selectedNode.x = nodeXStepper.value;
			reloadMap();
		};
		tab.add(nodeXStepper);

		nodeYStepper = new PsychUINumericStepper(x + 225, y, 1, 0, -9999, 9999, 0, 55);
		nodeYStepper.onValueChange = function()
		{
			if (selectedNode == null) return;
			selectedNode.y = nodeYStepper.value;
			reloadMap();
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
			reloadMap();
		}, 150);
		tab.add(nodeImageDropDown);

		label(tab, x + 160, y - 17, 'FPS:');
		nodeFpsStepper = new PsychUINumericStepper(x + 160, y, 1, 6, 0, 60, 0, 50);
		nodeFpsStepper.onValueChange = function()
		{
			if (selectedNode == null) return;
			selectedNode.fps = Std.int(nodeFpsStepper.value);
			lastNodeFps = selectedNode.fps;
			reloadMap();
		};
		tab.add(nodeFpsStepper);

		y += 40;
		label(tab, x, y - 17, 'Animacion:');
		nodeAnimDropDown = new PsychUIDropDownMenu(x, y, [''], function(sel:Int, value:String)
		{
			if (selectedNode == null) return;
			selectedNode.anim = value;
			lastNodeAnim = value;
			reloadMap();
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
			reloadMap();
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

			// aviso en vivo: una errata en un ID deja ese nodo bloqueado para siempre
			if (unknown.length > 0) showOutput('No existe ningun nodo: ' + unknown.join(', '), true);
			else if (list.length > 0) showOutput('"${selectedNode.id}" desbloquea: ' + list.join(', '));
		};
		tab.add(nodeUnlocksInput);

		y += 40;
		tab.add(new PsychUIButton(x, y, 'Borrar nodo', function() deleteSelectedNode(), 100));

		y += 40;
		tab.add(new FlxText(x, y, 340,
			'La semana filtra la lista de canciones:
'
			+ '- sin semana salen todas las de la build
'
			+ '- con semana, solo las que ella declara'
			+ '\nSalida (exit) sin Mundo destino: vuelve al mapa de fuera.'
			+ '\nCon destino: pasa a ese mundo y entra por su salida de vuelta.', 11));
	}

	function addDecorTab()
	{
		var tab:FlxSpriteGroup = UI_box.getTab('Deco').menu;
		var x:Int = 10;
		var y:Int = 20;

		label(tab, x, y - 17, 'Sprite (se usa al crear nuevos):');
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
				reloadMap();
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
			reloadMap();
		}, 150);
		tab.add(decorAnimDropDown);

		label(tab, x + 160, y - 17, 'FPS:');
		decorFpsStepper = new PsychUINumericStepper(x + 160, y, 1, 8, 0, 60, 0, 50);
		decorFpsStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.fps = Std.int(decorFpsStepper.value);
			reloadMap();
		};
		tab.add(decorFpsStepper);

		y += 42;
		label(tab, x, y - 17, 'X / Y:');
		decorXStepper = new PsychUINumericStepper(x, y, 1, 0, -9999, 9999, 0, 60);
		decorXStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.x = decorXStepper.value;
			reloadMap();
		};
		tab.add(decorXStepper);

		decorYStepper = new PsychUINumericStepper(x + 70, y, 1, 0, -9999, 9999, 0, 60);
		decorYStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.y = decorYStepper.value;
			reloadMap();
		};
		tab.add(decorYStepper);

		label(tab, x + 140, y - 17, 'Escala:');
		decorScaleStepper = new PsychUINumericStepper(x + 140, y, 0.25, 1, 0.25, 10, 2, 60);
		decorScaleStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.scale = decorScaleStepper.value;
			reloadMap();
		};
		tab.add(decorScaleStepper);

		label(tab, x + 210, y - 17, 'Alpha:');
		decorAlphaStepper = new PsychUINumericStepper(x + 210, y, 0.1, 1, 0, 1, 2, 60);
		decorAlphaStepper.onValueChange = function()
		{
			if (selectedSprite == null) return;
			selectedSprite.alpha = decorAlphaStepper.value;
			reloadMap();
		};
		tab.add(decorAlphaStepper);

		y += 42;
		decorFlipXCheck = new PsychUICheckBox(x, y, 'Flip X', 70, function()
		{
			if (selectedSprite == null) return;
			selectedSprite.flipX = decorFlipXCheck.checked;
			reloadMap();
		});
		tab.add(decorFlipXCheck);

		decorFlipYCheck = new PsychUICheckBox(x + 80, y, 'Flip Y', 70, function()
		{
			if (selectedSprite == null) return;
			selectedSprite.flipY = decorFlipYCheck.checked;
			reloadMap();
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
		tab.add(new PsychUIButton(x + 130, y, 'Duplicar', function()
		{
			if (selectedSprite == null) return;

			pushUndo();
			var copy:OverworldSpriteFile = OverworldData.createSprite(selectedSprite.image, selectedSprite.x + 16, selectedSprite.y + 16);
			copy.anim = selectedSprite.anim;
			copy.fps = selectedSprite.fps;
			copy.flipX = selectedSprite.flipX;
			copy.flipY = selectedSprite.flipY;
			copy.scale = selectedSprite.scale;
			copy.alpha = selectedSprite.alpha;
			copy.front = selectedSprite.front;

			worldFile.sprites.push(copy);
			selectedSprite = copy;
			reloadMap();
			updateUI();
		}, 90));
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
			reloadMap();
		}, 180);
		tab.add(pathDotsDropDown);

		y += 44;
		label(tab, x, y - 17, 'Animacion:');
		pathDotAnimDropDown = new PsychUIDropDownMenu(x, y, [''], function(sel:Int, value:String)
		{
			if (selectedPath == null) return;
			selectedPath.dotAnim = value;
			reloadMap();
		}, 140);
		tab.add(pathDotAnimDropDown);

		label(tab, x + 150, y - 17, 'Separacion:');
		pathSpacingStepper = new PsychUINumericStepper(x + 150, y, 1, 16, 2, 128, 0, 60);
		pathSpacingStepper.onValueChange = function()
		{
			if (selectedPath == null) return;
			selectedPath.dotSpacing = pathSpacingStepper.value;
			reloadMap();
		};
		tab.add(pathSpacingStepper);

		y += 46;
		tab.add(new PsychUIButton(x, y, 'Quitar ultimo punto', function()
		{
			if (selectedPath == null || selectedPath.points.length < 1) return;
			pushUndo();
			selectedPath.points.pop();
			reloadMap();
		}, 140));

		tab.add(new PsychUIButton(x + 150, y, 'Limpiar puntos', function()
		{
			if (selectedPath == null) return;
			pushUndo();
			selectedPath.points = [];
			reloadMap();
		}, 130));

		y += 36;
		tab.add(new PsychUIButton(x, y, 'Borrar camino', function()
		{
			if (selectedPath == null) return;
			pushUndo();
			worldFile.paths.remove(selectedPath);
			selectedPath = null;
			reloadMap();
			updateUI();
		}, 140));

		y += 46;
		var tip:FlxText = new FlxText(x, y, 340,
			'Modo CAMINO (C):\n- clic en un nodo y luego en otro para unirlos\n- si ya estan unidos, se selecciona el camino\n- con un camino elegido, clic en el vacio anade\n  un punto de curva', 8);
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
		undoStack.push(state != null ? state : snapshot());
		if (undoStack.length > MAX_UNDO) undoStack.shift();
		redoStack = [];
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
		worldFile = cast haxe.Json.parse(json);
		OverworldData.applyDefaults(worldFile);

		selectedNode = null;
		selectedSprite = null;
		selectedPath = null;
		pathStart = null;
		dragging = false;
		unsavedProgress = true;

		reloadMap();
		updateUI();
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

		paletteSelected = index;
		paletteCursor.visible = true;
		paletteCursor.setPosition(col * paletteCell, row * paletteCell);

		curMode = MODE_TILE;
		showOutput('Tile ${paletteFrames[index]} (${index + 1}/${paletteFrames.length}) elegido. Clic en el mapa para pintar.');
	}

	function paintTile(mouseX:Float, mouseY:Float)
	{
		if (paletteSelected < 0 || paletteSelected >= paletteFrames.length) return;

		var size:Int = paletteTileSize;
		var px:Float = Math.floor(mouseX / size) * size;
		var py:Float = Math.floor(mouseY / size) * size;
		var frame:String = paletteFrames[paletteSelected];

		var existing:OverworldSpriteFile = null;
		for (data in worldFile.sprites)
		{
			if (data.front == paintFront && data.x == px && data.y == py)
			{
				existing = data;
				break;
			}
		}

		var needsReload:Bool = false;
		if (existing != null)
		{
			if (existing.image == paletteImage && existing.anim == frame) return; // ya esta pintado
			worldFile.sprites.remove(existing);
			needsReload = true;
		}

		var data:OverworldSpriteFile = OverworldData.createSprite(paletteImage, px, py);
		data.anim = frame;
		data.fps = 0;
		data.front = paintFront;
		worldFile.sprites.push(data);
		unsavedProgress = true;

		if (needsReload || px + size > mapWidth || py + size > mapHeight) reloadMap();
		else addDecorSprite(data);
	}

	function addDecorSprite(data:OverworldSpriteFile):FlxSprite
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

		if (data.front) spritesFront.add(spr);
		else spritesBack.add(spr);
		return spr;
	}

	/** Cambia la cancion del nodo y arrastra el nombre visible si no lo has escrito tu. */
	function setNodeSong(value:String)
	{
		if (selectedNode == null) return;

		var previous:String = selectedNode.song;
		selectedNode.song = value;
		unsavedProgress = true;

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
		startDropDown.list = nodeIdList();
		startDropDown.selectedLabel = worldFile.startNode;
	}

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

			var anims:Array<String> = [''].concat(OverworldData.listAnimations(selectedNode.image));
			nodeAnimDropDown.list = anims;
			nodeDoneDropDown.list = anims;
			nodeAnimDropDown.selectedLabel = selectedNode.anim;
			nodeDoneDropDown.selectedLabel = selectedNode.animDone;
			nodeFpsStepper.value = selectedNode.fps;
			nodeUnlockedCheck.checked = selectedNode.unlocked;
			nodeUnlocksInput.text = selectedNode.unlocks.join(', ');
			nodeXStepper.value = selectedNode.x;
			nodeYStepper.value = selectedNode.y;
		}

		if (selectedSprite != null)
		{
			decorImageDropDown.selectedLabel = selectedSprite.image;
			decorAnimDropDown.list = [''].concat(OverworldData.listAnimations(selectedSprite.image));
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
		}
		else pathInfoTxt.text = 'Ningun camino seleccionado';
	}

	// ------------------------------------------------------------------ update
	var lastFocusWasUI:Bool = false;

	override function update(elapsed:Float)
	{
		var hadFocus:Bool = (PsychUIInputText.focusOn != null);

		super.update(elapsed);

		raiseOpenDropDown();

		modeTxt.text = 'Mundo: $worldName   |   Modo: ${MODE_NAMES[curMode]}   |   F1 = ayuda'
			+ (unsavedProgress ? '   |   * sin guardar' : '');

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
			if (FlxG.keys.justPressed.T) testWorld();
			if (FlxG.keys.justPressed.Z) FlxG.keys.pressed.SHIFT ? redo() : undo();
			if (FlxG.keys.justPressed.Y) redo();
			return;
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			MusicBeatState.switchState(new MasterEditorMenu());
			return;
		}

		if (FlxG.keys.justPressed.V) curMode = MODE_SELECT;
		if (FlxG.keys.justPressed.N) curMode = MODE_NODE;
		if (FlxG.keys.justPressed.B) curMode = MODE_DECOR;
		if (FlxG.keys.justPressed.C) curMode = MODE_PATH;
		if (FlxG.keys.justPressed.T) curMode = MODE_TILE;

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

		if (FlxG.keys.justPressed.DELETE)
		{
			if (selectedNode != null) deleteSelectedNode();
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
			return;
		}

		var mouse = FlxG.mouse.getWorldPosition(camGame);
		var mouseX:Float = mouse.x;
		var mouseY:Float = mouse.y;
		mouse.put();

		if (FlxG.mouse.justPressedRight)
		{
			// pintando, el clic derecho es la goma: no debe cargarse un nodo sin querer
			deleteUnderMouse(mouseX, mouseY, curMode != MODE_TILE);
			return;
		}

		// pintar tiles: continuo mientras se arrastra
		if (curMode == MODE_TILE && FlxG.mouse.pressed)
		{
			if (FlxG.mouse.justPressed) pushUndo();
			paintTile(mouseX, mouseY);
			return;
		}

		if (FlxG.mouse.justReleased)
		{
			dragging = false;
			dragSnapshot = null;
		}

		if (dragging && FlxG.mouse.pressed)
		{
			var newX:Float = snap(mouseX + dragOffsetX);
			var newY:Float = snap(mouseY + dragOffsetY);

			if (selectedNode != null)
			{
				if (selectedNode.x != newX || selectedNode.y != newY)
				{
					if (dragSnapshot != null)
					{
						pushUndo(dragSnapshot);
						dragSnapshot = null;
					}
					selectedNode.x = newX;
					selectedNode.y = newY;
					nodeXStepper.value = newX;
					nodeYStepper.value = newY;
					unsavedProgress = true;
					reloadMap();
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
					reloadMap();
				}
			}
			return;
		}

		if (!FlxG.mouse.justPressed) return;

		switch (curMode)
		{
			case MODE_NODE:
				createNode(snap(mouseX), snap(mouseY));

			case MODE_DECOR:
				createDecor(snap(mouseX), snap(mouseY));

			case MODE_PATH:
				handlePathClick(mouseX, mouseY);

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

	function spriteUnderMouse(mouseX:Float, mouseY:Float):OverworldSpriteFile
	{
		var index:Int = worldFile.sprites.length - 1;
		while (index >= 0)
		{
			var data:OverworldSpriteFile = worldFile.sprites[index];
			var group = data.front ? spritesFront : spritesBack;

			var localIndex:Int = 0;
			for (i in 0...index)
				if (worldFile.sprites[i].front == data.front) localIndex++;

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
		var node:OverworldNodeFile = nodeUnderMouse(mouseX, mouseY);
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
			}
			return;
		}

		var data:OverworldSpriteFile = spriteUnderMouse(mouseX, mouseY);
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
			}
			return;
		}

		selectedNode = null;
		selectedSprite = null;
		updateSelectionBox();
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
		selectedNode = node;
		selectedSprite = null;
		unsavedProgress = true;

		reloadMap();
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

		reloadMap();
		updateUI();
	}

	function handlePathClick(mouseX:Float, mouseY:Float)
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
				reloadMap();
				updateUI();
				showOutput('Ese camino ya existia, lo he seleccionado');
				return;
			}

			pushUndo();
			var pth:OverworldPathFile = OverworldData.createPath(pathStart.id, node.id);
			worldFile.paths.push(pth);
			selectedPath = pth;
			pathStart = null;
			unsavedProgress = true;

			UI_box.selectedName = 'Camino';
			reloadMap();
			updateUI();
			showOutput('Camino creado: ${pth.a} <-> ${pth.b}');
			return;
		}

		// clic en el vacio: anadir punto de curva al camino seleccionado
		if (selectedPath != null)
		{
			pushUndo();
			selectedPath.points.push([snap(mouseX), snap(mouseY)]);
			unsavedProgress = true;
			reloadMap();
			updateUI();
			return;
		}

		pathStart = null;
	}

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
		worldFile.nodes.remove(selectedNode);

		var index:Int = worldFile.paths.length - 1;
		while (index >= 0)
		{
			var pth:OverworldPathFile = worldFile.paths[index];
			if (pth.a == id || pth.b == id) worldFile.paths.remove(pth);
			index--;
		}

		for (node in worldFile.nodes)
			if (node.unlocks != null) node.unlocks = node.unlocks.filter(target -> target != id);

		// sin esto el mundo se quedaria apuntando a un nodo inicial que ya no existe
		if (worldFile.startNode == id && worldFile.nodes.length > 0)
		{
			worldFile.startNode = worldFile.nodes[0].id;
			refreshNodeIdLists();
		}

		selectedNode = null;
		selectedPath = null;
		unsavedProgress = true;

		reloadMap();
		updateUI();
		showOutput('Nodo "$id" borrado');
	}

	function deleteSelectedSprite()
	{
		if (selectedSprite == null) return;

		pushUndo();
		worldFile.sprites.remove(selectedSprite);
		selectedSprite = null;
		unsavedProgress = true;

		reloadMap();
		updateUI();
	}

	// ------------------------------------------------------------------ guardar
	function assetsFolder():String
		return Paths.getSharedPath('${OverworldData.FOLDER}/');

	/** Si el juego corre desde export/.../bin, devuelve la carpeta equivalente del repo. */
	function repoFolder():String
	{
		#if sys
		var root:String = '../../../../';
		if (FileSystem.exists('${root}Project.xml')) return '${root}assets/shared/${OverworldData.FOLDER}/';
		#end
		return null;
	}

	function saveWorld()
	{
		if (worldName == null || worldName.trim().length < 1)
		{
			showOutput('Ponle un nombre de archivo al mundo', true);
			return;
		}

		var data:String = OverworldData.stringify(worldFile);
		var saved:Array<String> = [];

		#if sys
		for (folder in [assetsFolder(), repoFolder()])
		{
			if (folder == null) continue;

			try
			{
				if (!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
				File.saveContent('$folder$worldName.json', data);
				saved.push('$folder$worldName.json');
			}
			catch (e:Dynamic)
			{
				trace('OverworldEditor: no se pudo guardar en $folder -> $e');
			}
		}
		#end

		if (saved.length < 1)
		{
			showOutput('No se pudo guardar, prueba con "Guardar como..."', true);
			return;
		}

		unsavedProgress = false;
		worldList = OverworldData.listWorlds();
		worldsDropDown.list = worldList;
		nodeWorldDropDown.list = [''].concat(worldList);

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

	function testWorld()
	{
		saveWorld();

		OverworldState.reset();
		OverworldState.curWorld = worldName;
		OverworldState.returnToEditor = true;
		MusicBeatState.switchState(new OverworldState(worldName));
	}

	var outputTimer:FlxTimer;

	function showOutput(text:String, ?error:Bool = false)
	{
		outputTxt.color = error ? FlxColor.RED : FlxColor.LIME;
		outputTxt.text = text;

		if (outputTimer != null) outputTimer.cancel();
		outputTimer = new FlxTimer().start(5, function(_:FlxTimer) if (outputTxt != null) outputTxt.text = '');
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		switch (id)
		{
			case PsychUIInputText.CHANGE_EVENT, PsychUINumericStepper.CHANGE_EVENT, PsychUICheckBox.CLICK_EVENT, PsychUIDropDownMenu.CLICK_EVENT:
				unsavedProgress = true;
		}
	}
}
