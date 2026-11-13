package states;

#if debug
import backend.OverworldData;
import states.editors.OverworldEditorState;
import flixel.FlxBasic;
import flixel.FlxState;

typedef PlaytestStep =
{
	var name:String;
	var run:Void->Bool;     // true = paso terminado
	var switches:Bool;      // cambia de pantalla: el siguiente espera a la pantalla nueva
	var free:Bool;          // se ejecuta cada fotograma aunque el mapa este ocupado
}

/**
 * Prueba automatica del overworld (solo debug): `FNF2026Playground.exe -playtest`.
 *
 * 1. Monta unos mundos de demostracion con las MISMAS funciones que usan los botones y gestos
 *    del editor (pintar terreno, crear nodos, aspecto desde la paleta, enlazar, caminos, crear
 *    submundo, crear pareja, cambiar de tipo y de destino, guardar).
 * 2. Los juega por codigo, sin teclado ni raton: andar (tryWalk), superar niveles (uno con
 *    PlayState de verdad y los demas simulados como al acabar la cancion), entrar y salir de un
 *    castillo, tuberias (warp), salida lateral, R y el menu de ESC. En cada paso comprueba el
 *    estado y deja capturas (escribe playtest_shot.txt para que las haga un script de fuera).
 * 3. Lo borra todo (mundos zz_demo* en build y repo, y su progreso) y cierra el juego.
 *
 * No toca la partida del usuario: no guarda posicion y solo usa claves de progreso zz_demo*.
 */
@:access(states.OverworldState)
@:access(states.editors.OverworldEditorState)
class OverworldPlaytest extends FlxBasic
{
	public static var running:Bool = false;

	static final WORLDS:Array<String> = ['zz_demo', 'zz_demo_c', 'zz_demo2', 'zz_demo_hub'];
	static final CLOSED_WORLD:String = 'zz_demo_closed';

	/** Mundo de reglas: salidas secretas, nodo de "N superados" y camino con condicion propia. */
	static final RULES_WORLD:String = 'zz_demo_rules';

	static function deleteWorld(world:String)
	{
		OverworldData.resetProgress(world);
		for (folder in [Paths.getSharedPath('overworlds/'), '../../../../assets/shared/overworlds/'])
			if (FileSystem.exists('$folder$world.json')) FileSystem.deleteFile('$folder$world.json');
		OverworldData.clearWorldCache();
	}
	static final STEP_LIMIT:Float = 30;

	var steps:Array<PlaytestStep> = [];
	var cursor:Int = 0;
	var waitTime:Float = 0;
	var stepTime:Float = 0;
	var pendingFrom:FlxState = null;
	var phase:Int = 0;
	var log:Array<String> = [];
	var fails:Int = 0;
	var checks:Int = 0;
	var finished:Bool = false;

	// rendimiento en el mapa
	var mapFrames:Int = 0;
	var mapTime:Float = 0;
	var worstFrame:Float = 0;

	public static function start()
	{
		running = true;
		OverworldData.simStartWorld = 'zz_demo'; // la partida simulada (avisos) empieza en la demo
		FlxG.autoPause = false; // sin foco, flixel pausaria el juego y la prueba se quedaria parada
		for (world in WORLDS) OverworldData.resetProgress(world);
		OverworldData.resetProgress(RULES_WORLD);
		FlxG.plugins.addPlugin(new OverworldPlaytest());
	}

	public function new()
	{
		super();
		buildScript();
	}

	// ------------------------------------------------------------------ bucle
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (finished) return;

		var map:OverworldState = Std.downcast(FlxG.state, OverworldState);
		if (map != null && FlxG.state.subState == null && cursor > 0)
		{
			mapFrames++;
			mapTime += elapsed;
			if (elapsed > worstFrame) worstFrame = elapsed;
		}

		if (waitTime > 0)
		{
			waitTime -= elapsed;
			return;
		}

		var step:PlaytestStep = steps[cursor];
		stepTime += elapsed;
		if (stepTime > STEP_LIMIT)
		{
			check(false, 'el paso "${step.name}" no termino en ${STEP_LIMIT}s: se aborta');
			finish();
			return;
		}

		if (!step.free && !ready()) return;

		var done:Bool = false;
		try
		{
			done = step.run();
		}
		catch (e:Dynamic)
		{
			check(false, 'el paso "${step.name}" lanzo una excepcion: $e');
			finish();
			return;
		}
		if (!done) return;

		if (step.switches) pendingFrom = FlxG.state;
		cursor++;
		stepTime = 0;
		phase = 0;
		if (cursor >= steps.length) finish();
	}

	/** El mapa esta quieto: sin fundido, sin andar, sin revelar caminos, sin una accion en curso. */
	function ready():Bool
	{
		if (pendingFrom != null)
		{
			if (FlxG.state == pendingFrom) return false;
			pendingFrom = null;
		}

		var map:OverworldState = Std.downcast(FlxG.state, OverworldState);
		if (map == null) return Std.downcast(FlxG.state, OverworldEditorState) != null;
		if (FlxG.state.subState != null || map.worldFile == null) return false;
		return !map.walking && !map.revealing && !map.busy;
	}

	// ------------------------------------------------------------------ pasos
	function add(name:String, run:Void->Bool, ?switches:Bool = false, ?free:Bool = false)
		steps.push({name: name, run: run, switches: switches, free: free});

	function check(ok:Bool, what:String)
	{
		checks++;
		if (!ok) fails++;
		var line:String = (ok ? 'OK    ' : 'FAIL  ') + what;
		log.push(line);
		trace('PLAYTEST ' + line);
	}

	static inline function map():OverworldState
		return Std.downcast(FlxG.state, OverworldState);

	function expectAt(world:String, node:String)
		add('estar en $world/$node', function()
		{
			check(OverworldState.curWorld == world && OverworldState.curNodeId == node,
				'BF esta en $world/$node (esta en ${OverworldState.curWorld}/${OverworldState.curNodeId})');
			return true;
		});

	function expectUnlocked(node:String, open:Bool)
		add('$node abierto=$open', function()
		{
			var m:OverworldState = map();
			var n:OverworldNodeFile = OverworldData.findNode(m.worldFile, node);
			var isOpen:Bool = OverworldData.isUnlocked(OverworldState.curWorld, m.worldFile, n);
			check(n != null && isOpen == open, '${OverworldState.curWorld}/$node ' + (open ? 'abierto' : 'cerrado') + (isOpen == open ? '' : ' (no lo esta)'));
			return true;
		});

	function expectCompleted(world:String, node:String, done:Bool)
		add('$world/$node completado=$done', function()
		{
			var real:Bool = OverworldData.isCompleted(world, node);
			check(real == done, '$world/$node ' + (done ? 'superado' : 'sin superar') + (real == done ? '' : ' (no lo esta)'));
			return true;
		});

	function expectPath(a:String, b:String, visible:Bool)
		add('camino $a-$b visible=$visible', function()
		{
			var m:OverworldState = map();
			var pth:OverworldPathFile = Lambda.find(m.worldFile.paths, p -> (p.a == a && p.b == b) || (p.a == b && p.b == a));
			var open:Bool = pth != null && m.isPathOpen(pth);
			check(pth != null && open == visible, 'camino $a-$b ' + (visible ? 'visible' : 'oculto') + (open == visible ? '' : ' (no lo esta)'));
			return true;
		});

	function expectStack(depth:Int)
		add('pila $depth', function()
		{
			check(OverworldState.worldStack.length == depth, 'pila de submundos con $depth (tiene ${OverworldState.worldStack.length})');
			return true;
		});

	function walk(dx:Float, dy:Float, label:String)
		add('andar $label', function()
		{
			var m:OverworldState = map();
			var before:String = OverworldState.curNodeId;
			m.tryWalk(dx, dy);
			if (!m.walking) check(false, 'BF no pudo andar $label desde $before');
			return true;
		});

	/** Superar el nivel actual como al acabar su cancion (PlayState.endSong). */
	function beat()
		add('superar nivel', function()
		{
			OverworldState.fromOverworld = true;
			OverworldState.lastLevelNode = OverworldState.curNodeId;
			OverworldState.completeCurrentNode();
			OverworldState.backToOverworld();
			return true;
		}, true);

	/** Superar el nivel actual pasando por PlayState de verdad (carga de chart, endSong y vuelta). */
	function beatForReal()
		add('superar nivel con PlayState', function()
		{
			switch (phase)
			{
				case 0:
					map().enterNode();
					phase = 1;
				case 1:
					var play:PlayState = Std.downcast(FlxG.state, PlayState);
					if (play != null && FlxG.state.subState == null && !play.startingSong && FlxG.sound.music != null && FlxG.sound.music.playing)
					{
						check(true, 'la cancion del nivel arranca en PlayState');
						play.KillNotes();
						FlxG.sound.music.onComplete(); // lo mismo que la tecla 1 de debug
						phase = 2;
					}
				case 2:
					if (map() != null && ready()) return true;
			}
			return false;
		}, false, true);

	/** Superar el nivel actual con un resultado concreto (para la salida secreta). */
	function beatWith(misses:Int, accuracy:Float)
		add('superar nivel con $misses fallos y ${Math.round(accuracy * 100)}%', function()
		{
			OverworldState.fromOverworld = true;
			OverworldState.lastLevelNode = OverworldState.curNodeId;
			OverworldState.completeCurrentNode(misses, accuracy);
			OverworldState.backToOverworld();
			return true;
		}, true);

	function expectSecret(world:String, node:String, done:Bool)
		add('$world/$node secreta=$done', function()
		{
			var real:Bool = OverworldData.isSecretCompleted(world, node);
			check(real == done, '$world/$node ' + (done ? 'con su salida secreta' : 'sin su salida secreta') + (real == done ? '' : ' (no es asi)'));
			return true;
		});

	function enter(label:String)
		add('entrar $label', function()
		{
			map().enterNode();
			return true;
		}, true);

	/**
	 * Captura hecha por el propio juego: dibuja el escenario en un BitmapData fuera de pantalla y lo
	 * guarda en playtest_shots/. No depende de que el monitor este encendido (capturar la ventana
	 * desde fuera sale en negro con la pantalla en reposo).
	 */
	static inline function isPlaceholder(key:String):Bool
		return key != null && key.indexOf('flixel/images/logo/default') > -1;

	function shot(name:String)
		add('captura $name', function()
		{
			// cada captura revisa tambien que ningun sprite use una imagen ya liberada (al volver de
			// una cancion se veia la textura de relleno de flixel en vez del mapa)
			var destroyed:Int = 0;
			function scan(basic:FlxBasic)
			{
				if (basic == null) return;
				var spr:FlxSprite = Std.downcast(basic, FlxSprite);
				// al dibujarse, flixel cambia una imagen destruida por su textura de relleno
				if (spr != null && spr.graphic != null && (spr.graphic.isDestroyed || isPlaceholder(spr.graphic.key) || isPlaceholder(spr.graphic.assetsKey)))
					destroyed++;
				var group:flixel.group.FlxGroup.FlxTypedGroup<Dynamic> = Std.downcast(basic, flixel.group.FlxGroup.FlxTypedGroup);
				if (group != null) for (member in group.members) scan(cast member);
				var sprGroup:flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup<Dynamic> = Std.downcast(basic, flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup);
				if (sprGroup != null) for (member in sprGroup.members) scan(cast member);
			}
			scan(FlxG.state);
			check(destroyed == 0, '$name: ningun sprite usa una imagen liberada' + (destroyed > 0 ? ' ($destroyed lo hacen)' : ''));

			#if sys
			try
			{
				var bmp:openfl.display.BitmapData = new openfl.display.BitmapData(FlxG.stage.stageWidth, FlxG.stage.stageHeight, false, 0xFF000000);
				bmp.draw(FlxG.stage);
				var png = bmp.encode(bmp.rect, new openfl.display.PNGEncoderOptions());
				if (!FileSystem.exists('playtest_shots')) FileSystem.createDirectory('playtest_shots');
				sys.io.File.saveBytes('playtest_shots/$name.png', png);
				bmp.dispose();
			}
			catch (e:Dynamic)
			{
				check(false, 'no se pudo guardar la captura $name: $e');
			}
			#end
			return true;
		});

	// ------------------------------------------------------------------ guion
	function buildScript()
	{
		add('montar los mundos con el editor', buildWorlds);

		// capturas del editor con el mundo de reglas: pestana Nodo, pestana Camino y un grupo
		add('editor: nodo con reglas', function()
		{
			if (FlxG.state.subState != null) return false; // el fundido de entrada del editor aun tapa la pantalla
			var ed:OverworldEditorState = Std.downcast(FlxG.state, OverworldEditorState);
			ed.selectedNode = OverworldData.findNode(ed.worldFile, 'R2');
			ed.selectedPath = null;
			ed.UI_box.selectedName = 'Nodo';
			ed.showUnlocks = true;
			ed.camGame.zoom = 3;
			ed.camGame.scroll.set(150 - ed.camGame.width * 0.5, 170 - ed.camGame.height * 0.5);
			ed.reloadMap(true);
			ed.updateUI();
			return true;
		});
		shot('00a_editor_nodo');
		add('editor: camino con condicion', function()
		{
			var ed:OverworldEditorState = Std.downcast(FlxG.state, OverworldEditorState);
			ed.selectedNode = null;
			ed.selectedPath = ed.findPath('R3', 'G');
			ed.UI_box.selectedName = 'Camino';
			ed.reloadMap(true);
			ed.updateUI();
			return true;
		});
		shot('00b_editor_camino');
		add('editor: grupo con un rectangulo', function()
		{
			var ed:OverworldEditorState = Std.downcast(FlxG.state, OverworldEditorState);
			ed.selectedPath = null;
			ed.bandStart = [40, 70];
			ed.finishBand(220, 180);
			check(ed.hasGroup() && ed.groupNodes.length == 4, 'el rectangulo coge R1, R2, R3 y G (${ed.groupNodes.length} nodos)');
			return true;
		});
		shot('00c_editor_grupo');
		add('editor: soltar el grupo', function()
		{
			Std.downcast(FlxG.state, OverworldEditorState).clearGroup();
			return true;
		});

		add('abrir el mundo de demostracion', function()
		{
			OverworldState.reset();
			OverworldState.curWorld = 'zz_demo';
			MusicBeatState.switchState(new OverworldState());
			return true;
		}, true);

		add('sin avisos al cargar', function()
		{
			for (world in WORLDS)
			{
				var problems:Array<String> = OverworldData.checkWorld(OverworldData.load(world), world);
				check(problems.length == 0, '$world sin avisos' + (problems.length > 0 ? ': ' + problems.join(' | ') : ''));
			}
			OverworldData.simStartWorld = RULES_WORLD;
			var rules:Array<String> = OverworldData.checkWorld(OverworldData.load(RULES_WORLD), RULES_WORLD);
			OverworldData.simStartWorld = 'zz_demo';
			check(rules.length == 0, '$RULES_WORLD sin avisos' + (rules.length > 0 ? ': ' + rules.join(' | ') : ''));
			return true;
		});

		// --- inicio
		expectAt('zz_demo', 'L1');
		expectUnlocked('L2', false);
		expectPath('L1', 'L2', false);
		shot('01_inicio');

		// --- L1 con PlayState de verdad: carga el chart, acaba la cancion y vuelve al mapa
		beatForReal();
		expectCompleted('zz_demo', 'L1', true);
		expectPath('L1', 'L2', true);
		shot('02_tras_L1');

		// --- L2 abre L3 y la salida lateral
		walk(1, 0, 'a la derecha (L2)');
		expectAt('zz_demo', 'L2');
		beat();
		expectUnlocked('L3', true);
		expectUnlocked('E', true);

		// --- L3 abre el castillo
		walk(1, 0, 'a la derecha (L3)');
		beat();
		expectUnlocked('C', true);
		walk(0, 1, 'abajo (castillo)');
		expectAt('zz_demo', 'C');
		shot('03_castillo');

		// --- dentro del castillo
		enter('al castillo');
		expectAt('zz_demo_c', 'n0');
		expectStack(1);
		shot('04_submundo');
		beat();
		expectCompleted('zz_demo_c', 'n0', true);
		walk(-1, 0, 'a la izquierda (salida del submundo)');
		expectAt('zz_demo', 'C');
		expectStack(0);
		expectCompleted('zz_demo', 'C', true);
		expectUnlocked('P', true);
		expectPath('C', 'P', true);
		shot('05_vuelta_del_castillo');

		// --- tuberia al mundo central y vuelta
		walk(-1, 0, 'a la izquierda (tuberia)');
		expectAt('zz_demo', 'P');
		enter('por la tuberia');
		expectAt('zz_demo_hub', 'vuelta0');
		expectStack(0);
		expectUnlocked('vuelta1', false);
		shot('06_central');
		enter('por la tuberia de vuelta');
		expectAt('zz_demo', 'P');

		// --- salida lateral al vecino (entra andando)
		walk(1, 0, 'a la derecha (castillo)');
		walk(0, -1, 'arriba (L3)');
		walk(1, 0, 'a la derecha (salida lateral)');
		expectAt('zz_demo2', 'n0');
		shot('07_vecino');
		beat();
		expectUnlocked('W2', true);
		walk(0, 1, 'abajo (tuberia del vecino)');
		expectAt('zz_demo2', 'W2');
		enter('por la tuberia del vecino');
		expectAt('zz_demo_hub', 'vuelta1');
		expectUnlocked('vuelta0', true);
		expectPath('centro', 'vuelta1', true);
		expectPath('centro', 'vuelta0', true);
		shot('08_central_completo');

		// --- en el central, de una tuberia a la otra y de vuelta al mundo principal
		walk(-1, 0, 'a la izquierda (centro)');
		walk(0, 1, 'abajo (tuberia al mundo 1)');
		expectAt('zz_demo_hub', 'vuelta0');
		enter('por la tuberia al mundo 1');
		expectAt('zz_demo', 'P');

		// --- ESC: menu y vuelta al mismo sitio
		add('ESC abre el menu', function()
		{
			map().goBack();
			return true;
		}, true);
		add('en el menu, con vuelta al mapa', function()
		{
			if (Std.downcast(FlxG.state, MainMenuState) == null || FlxG.state.subState != null) return false;
			check(OverworldState.menuFromMap, 'el menu sabe que se abrio desde el mapa');
			OverworldState.menuFromMap = false;
			MusicBeatState.switchState(new OverworldState()); // lo mismo que hace su BACK
			return true;
		}, true, true);
		expectAt('zz_demo', 'P');

		// --- R: reinicia este mundo y su submundo, no el vecino
		add('pulsar R', function()
		{
			map().resetWorldProgress();
			return true;
		}, true);
		expectCompleted('zz_demo', 'L1', false);
		expectCompleted('zz_demo_c', 'n0', false);
		expectCompleted('zz_demo2', 'n0', true);
		expectAt('zz_demo', 'L1');
		expectPath('L1', 'L2', false);
		shot('09_tras_R');

		// --- un mapa sin ningun nodo abierto no deja a BF atrapado: vuelve al mapa de fuera
		add('entrar a un mapa sin nodos abiertos', function()
		{
			var closed:OverworldFile = OverworldData.createEmpty();
			closed.nodes[0].id = 'x';
			closed.nodes[0].unlocked = false;
			closed.startNode = 'x';
			OverworldData.saveWorldFiles(CLOSED_WORLD, closed);
			OverworldState.returnToEditor = false; // probando desde el editor se quiere ver el aviso
			OverworldState.worldStack = [['zz_demo', 'L1']];
			OverworldState.curWorld = CLOSED_WORLD;
			OverworldState.curNodeId = 'x';
			MusicBeatState.switchState(new OverworldState());
			return true;
		}, true);
		expectAt('zz_demo', 'L1');
		add('borrar el mapa cerrado', function()
		{
			check(map() != null && map().errorTxt == null, 'el mapa de fuera se ve sin el aviso de "ningun nodo desbloqueado"');
			deleteWorld(CLOSED_WORLD);
			OverworldState.returnToEditor = true;
			return true;
		});

		// --- probar desde un nodo que con la partida actual esta cerrado (CTRL+SHIFT+T del editor)
		add('probar desde un nodo cerrado', function()
		{
			OverworldState.reset();
			OverworldState.returnToEditor = true;
			OverworldState.testStartWorld = RULES_WORLD;
			OverworldState.testStartNode = 'R3';
			MusicBeatState.switchState(new OverworldState(RULES_WORLD, 'R3'));
			return true;
		}, true);
		expectAt(RULES_WORLD, 'R3');
		expectUnlocked('R3', false);
		add('volver al principio del mundo de reglas', function()
		{
			OverworldState.testStartWorld = null;
			OverworldState.testStartNode = null;
			MusicBeatState.switchState(new OverworldState(RULES_WORLD, 'R1'));
			return true;
		}, true);
		expectAt(RULES_WORLD, 'R1');
		expectUnlocked('S', false);
		expectUnlocked('G', false);
		shot('10_reglas');

		// --- R1 sin fallos: salida secreta. Su camino baja fuera de la pantalla y la camara lo sigue
		beatWith(0, 1);
		expectCompleted(RULES_WORLD, 'R1', true);
		expectSecret(RULES_WORLD, 'R1', true);
		expectUnlocked('S', true);
		expectPath('R1', 'S', true);
		add('la camara siguio al camino revelado', function()
		{
			check(map().revealFollowed, 'la camara fue a mirar el camino que se revelaba fuera de pantalla');
			check(map().iris != null && !map().iris.visible, 'el iris se ha abierto del todo');
			return true;
		});
		shot('11_salida_secreta');

		// --- R2 pide 90% de precision: con 85% se supera pero sin secreta; G se abre con 2 superados
		walk(1, 0, 'a la derecha (R2)');
		beatWith(3, 0.85);
		expectCompleted(RULES_WORLD, 'R2', true);
		expectSecret(RULES_WORLD, 'R2', false);
		expectUnlocked('S2', false);
		expectUnlocked('G', true);
		expectPath('R2', 'G', true);

		// --- repetirlo con 95% saca la secreta
		beatWith(0, 0.95);
		expectSecret(RULES_WORLD, 'R2', true);
		expectUnlocked('S2', true);

		// --- el atajo R3-G solo se abre al superar R3
		walk(1, 0, 'a la derecha (R3)');
		expectPath('R3', 'G', false);
		expectPath('R3', 'S2', true);
		beat();
		expectPath('R3', 'G', true);
		walk(0, 1, 'abajo por el atajo (G)');
		expectAt(RULES_WORLD, 'G');
		shot('12_reglas_final');
		add('fin', () -> true);
	}

	// ------------------------------------------------------------------ montar los mundos
	/** Todo con funciones del editor, como lo haria el usuario. */
	function buildWorlds():Bool
	{
		var ed:OverworldEditorState = Std.downcast(FlxG.state, OverworldEditorState);
		if (ed == null) return false;

		// mundos auxiliares: el vecino y el central
		var neighbour:OverworldFile = OverworldData.createEmpty();
		neighbour.displayName = 'Vecino de prueba';
		neighbour.nodes[0].id = 'n0';
		neighbour.nodes[0].x = 96;
		neighbour.nodes[0].y = 112;
		neighbour.startNode = 'n0';
		OverworldData.saveWorldFiles('zz_demo2', neighbour);

		var hub:OverworldFile = OverworldData.createEmpty();
		hub.displayName = 'Central de prueba';
		hub.nodes[0].id = 'centro';
		hub.nodes[0].type = 'empty';
		hub.nodes[0].x = 128;
		hub.nodes[0].y = 112;
		hub.startNode = 'centro';
		OverworldData.saveWorldFiles('zz_demo_hub', hub);

		// mundo principal desde cero
		ed.worldName = 'zz_demo';
		ed.loadedName = null;
		ed.worldFile = OverworldData.createEmpty();
		ed.worldFile.displayName = 'Isla de prueba';
		ed.worldFile.nodes = [];
		ed.selectedNode = null;
		ed.resetHistory();
		ed.reloadMap();

		// terreno: un rectangulo de tiles pintados
		var t:Float = haxe.Timer.stamp();
		ed.buildPalette('overworld/og_mario/overworld_blocks');
		ed.paletteSelected = 40;
		var painted:Int = 0;
		for (row in 0...12)
			for (col in 0...16)
			{
				ed.paintTile(col * 16 + 4, row * 16 + 4);
				painted++;
			}
		check(ed.worldFile.sprites.length == painted, 'pintados $painted tiles en ${Math.round((haxe.Timer.stamp() - t) * 1000)} ms');

		// nodos
		// los niveles con el circulo amarillo/rojo de la paleta; el resto con su aspecto por defecto
		function makeNode(id:String, x:Float, y:Float, levelLook:Bool):OverworldNodeFile
		{
			ed.lastNodeType = 'level';
			ed.lastNodeImage = 'overworld/dot';
			ed.lastNodeAnim = 'idle';
			ed.lastNodeFps = 6;
			ed.createNode(x, y);
			var node:OverworldNodeFile = ed.selectedNode;
			ed.nodeIdInput.onChange(node.id, id);
			if (levelLook)
			{
				ed.setNodeTile(node, 'overworld/og_mario/level_tiles', 'tile0002', false);
				ed.setNodeTile(node, 'overworld/og_mario/level_tiles', 'tile0003', true);
			}
			return node;
		}
		var l1:OverworldNodeFile = makeNode('L1', 64, 96, true);
		var l2:OverworldNodeFile = makeNode('L2', 128, 96, true);
		var l3:OverworldNodeFile = makeNode('L3', 192, 96, true);
		var c:OverworldNodeFile = makeNode('C', 192, 160, false);
		var p:OverworldNodeFile = makeNode('P', 64, 160, false);
		ed.worldFile.startNode = 'L1';
		check(ed.worldFile.nodes.length == 5 && OverworldData.findNode(ed.worldFile, 'L1') != null, 'creados y renombrados los 5 nodos');
		check(l1.anim == 'tile0002' && l1.animDone == 'tile0003', 'aspecto de nivel desde la paleta');

		// la salida lateral, fuera de la pantalla por la derecha
		var size:Array<Float> = OverworldState.mapSize(ed.worldFile);
		var area:Array<Float> = OverworldState.cameraArea(size[0], size[1], ed.worldFile.zoom);
		var e:OverworldNodeFile = makeNode('E', Math.ceil((area[0] + area[2] + 24) / 16) * 16, 96, false);

		// tipos y destinos con los desplegables del editor
		ed.selectedNode = c;
		ed.nodeTypeDropDown.onSelect(1, 'world');
		ed.setNodeTile(c, 'overworld/og_mario/level_blocks', 'tile0010', false); // un castillo
		ed.selectedNode = p;
		ed.nodeTypeDropDown.onSelect(4, 'warp');
		ed.nodeWorldDropDown.onSelect(0, 'zz_demo_hub');
		ed.selectedNode = e;
		ed.nodeTypeDropDown.onSelect(3, 'exit');
		ed.nodeWorldDropDown.onSelect(0, 'zz_demo2');
		check(c.type == 'world' && p.type == 'warp' && p.image == 'overworld/pipe' && e.type == 'exit' && e.image == '', 'tipos cambiados (el warp se ve como tuberia, la salida invisible)');

		// caminos: clic en un nodo y luego en otro
		function connect(a:OverworldNodeFile, b:OverworldNodeFile)
		{
			ed.pathStart = null;
			ed.handlePathClick(a.x, a.y);
			ed.handlePathClick(b.x, b.y);
		}
		connect(l1, l2);
		connect(l2, l3);
		connect(l3, c);
		connect(c, p);
		connect(l3, e);
		check(ed.worldFile.paths.length == 5, 'creados 5 caminos');

		// castillo: crear submundo (antes de enlazarlo: sin destino, un world nunca se completa)
		ed.selectedNode = c;
		ed.updateUI();
		ed.createSubWorld();
		check(c.world == 'zz_demo_c' && OverworldData.exists('zz_demo_c'), 'submundo creado: ${c.world}');

		// desbloqueos con el modo ENLAZAR
		function link(from:OverworldNodeFile, targets:Array<OverworldNodeFile>)
		{
			ed.linkStart = null;
			ed.handleLinkClick(from.x, from.y);
			for (target in targets) ed.handleLinkClick(target.x, target.y);
			ed.handleLinkClick(-9999, -9999);
		}
		link(l1, [l2]);
		link(l2, [l3, e]);
		link(l3, [c]);
		link(c, [p]);
		check(!l2.unlocked && !e.unlocked && !p.unlocked && l1.unlocks.join(',') == 'L2' && c.unlocks.join(',') == 'P',
			'enlaces hechos y destinos bloqueados');

		// parejas de la tuberia y de la salida
		ed.selectedNode = p;
		ed.createPartner();
		ed.selectedNode = e;
		ed.createPartner();
		check(ed.saveWorld(), 'guardado zz_demo');

		// en el vecino: su tuberia al central, que abre su nivel
		check(ed.openWorld('zz_demo2', 'abrir vecino'), 'abierto el vecino en el editor');
		var n0:OverworldNodeFile = OverworldData.findNode(ed.worldFile, 'n0');
		var w2:OverworldNodeFile = makeNode('W2', 96, 160, false);
		ed.selectedNode = w2;
		ed.nodeTypeDropDown.onSelect(4, 'warp');
		ed.nodeWorldDropDown.onSelect(0, 'zz_demo_hub');
		connect(n0, w2);
		link(n0, [w2]);
		ed.selectedNode = w2;
		ed.createPartner();
		check(ed.saveWorld(), 'guardado zz_demo2');

		// la tuberia de vuelta del central tiene que estar unida al centro
		var hubNow:OverworldFile = OverworldData.load('zz_demo_hub');
		check(hubNow != null && hubNow.nodes.length == 3 && hubNow.paths.length == 2, 'el central tiene sus 2 tuberias unidas al centro');

		// mundo de reglas:
		//              R1 --- R2 --- R3 --- S2   (S2: lo abre la secreta de R2, con 90%)
		//              |      |      |
		//              |      G -----+           (G: se abre con 2 superados; el atajo R3-G, al superar R3)
		//              |
		//              S  (muy abajo, fuera de lo que se ve; lo abre la secreta de R1, sin fallos)
		ed.worldName = RULES_WORLD;
		ed.loadedName = null;
		ed.worldFile = OverworldData.createEmpty();
		ed.worldFile.displayName = 'Reglas de prueba';
		ed.worldFile.nodes = [];
		ed.selectedNode = null;
		ed.resetHistory();
		ed.reloadMap();

		var r1:OverworldNodeFile = makeNode('R1', 64, 96, true);
		var r2:OverworldNodeFile = makeNode('R2', 128, 96, true);
		var r3:OverworldNodeFile = makeNode('R3', 192, 96, true);
		var g:OverworldNodeFile = makeNode('G', 128, 160, true);
		var top:OverworldNodeFile = makeNode('S', 64, 352, true); // abajo, fuera de lo que se ve desde R1
		var s2:OverworldNodeFile = makeNode('S2', 256, 96, true);
		ed.worldFile.startNode = 'R1';

		connect(r1, r2);
		connect(r2, r3);
		connect(r2, g);
		connect(r1, top);
		connect(r3, s2);
		ed.pathStart = null;
		ed.handlePathClick(r3.x, r3.y);
		ed.handlePathClick(g.x, g.y, true); // no alineados: en L, primero vertical
		var shortcut:OverworldPathFile = ed.findPath('R3', 'G');
		check(shortcut != null && shortcut.points.length == 1 && shortcut.points[0][0] == 192 && shortcut.points[0][1] == 160,
			'camino en L al unir dos nodos no alineados');

		link(r1, [r2]);
		link(r2, [r3]);

		// salidas secretas con el modo ENLAZAR (SHIFT+clic)
		ed.linkStart = null;
		ed.handleLinkClick(r1.x, r1.y);
		ed.handleLinkClick(top.x, top.y, true);
		ed.handleLinkClick(-9999, -9999);
		ed.linkStart = null;
		ed.handleLinkClick(r2.x, r2.y);
		ed.handleLinkClick(s2.x, s2.y, true);
		ed.handleLinkClick(-9999, -9999);
		ed.selectedNode = r2;
		ed.nodeSecretModeDropDown.onSelect(1, 'precision');
		ed.nodeSecretAccStepper.value = 90;
		ed.nodeSecretAccStepper.onValueChange();

		// G: se abre con 2 superados (bloqueado de entrada)
		ed.selectedNode = g;
		ed.nodeNeedStepper.value = 2;
		ed.nodeNeedStepper.onValueChange();
		g.unlocked = false;

		// el atajo: modo ENLAZAR desde R3 y clic en el camino
		ed.linkStart = null;
		ed.handleLinkClick(r3.x, r3.y);
		var middle:Array<Float> = ed.pathMiddle(shortcut);
		ed.handleLinkClick(middle[0], middle[1]);
		ed.handleLinkClick(-9999, -9999);

		check(r1.secretUnlocks.join(',') == 'S' && !top.unlocked && r2.secretUnlocks.join(',') == 'S2' && r2.secretMode == 'accuracy'
			&& r2.secretAccuracy == 90 && g.needLevels == 2 && shortcut.unlockedBy == 'R3' && !shortcut.secret,
			'reglas puestas con el editor (secretas, N superados, atajo)');
		check(ed.saveWorld(), 'guardado $RULES_WORLD');
		return true;
	}

	// ------------------------------------------------------------------ fin
	function finish()
	{
		if (finished) return;
		finished = true;

		var fps:String = mapFrames > 0 ? Std.string(Math.round(mapFrames / mapTime)) : '?';
		var worst:String = Std.string(Math.round(worstFrame * 1000));
		log.push('Rendimiento en el mapa: $fps FPS de media, peor fotograma $worst ms');
		log.push((fails == 0 ? 'TODO CORRECTO: ' : 'FALLOS: $fails de ') + '$checks comprobaciones');

		// limpieza: progreso y archivos de los mundos de demostracion
		for (world in WORLDS.concat([CLOSED_WORLD, RULES_WORLD])) deleteWorld(world);
		OverworldData.simStartWorld = null;

		#if sys
		sys.io.File.saveContent('playtest_result.txt', log.join('\n'));
		#end
		trace('PLAYTEST FIN');
		Sys.exit(0);
	}
}
#end
