package states.stages.objects;

import objects.Note;

/**
 * Los splashes de Vs Sonic.exe (port de su scripts/noteSplashGlobal.lua), en lugar de los de Psych:
 *  - Un splash corto (0.18 s, una de sus dos variantes al azar) en cada nota "sick" del jugador.
 *  - Una "funda" por carril (8: rival y jugador) mientras se mantiene una nota larga: animacion de
 *    inicio, bucle, y la de final si es del jugador. Se esconde si pasa 1,5 pasos sin acertar trozos
 *    (al soltarla) o si la flecha de su carril no se ve.
 * `changeSkin` cambia las texturas (endless-us lo hace con su evento changenoteSkin).
 */
@:access(states.PlayState)
class SonicSplashes
{
	public static inline final PATH:String = 'sonic_exe/splashes/';
	static final COLORS:Array<String> = ['purple', 'blue', 'green', 'red'];
	static final END_COLORS:Array<String> = ['purp', 'blue', 'green', 'red'];

	var play:PlayState;
	var skin:String;
	var splashes:FlxTypedGroup<SonicSplash>;
	var holds:Array<FlxSprite> = [];
	var holdTimers:Array<Float> = [];
	/** Momento en que acaba la nota larga de cada carril (-1 = ninguna). */
	var holdEnds:Array<Float> = [];

	public function new(play:PlayState, skin:String, holdSkin:String)
	{
		this.play = play;
		this.skin = skin;

		// los splashes de Psych no salen; el mod respetaba las notas que los tenian desactivados
		for (note in play.unspawnNotes)
		{
			note.extraData.set('exeSplash', !note.noteSplashData.disabled);
			note.noteSplashData.disabled = true;
		}

		splashes = new FlxTypedGroup<SonicSplash>();
		play.noteGroup.insert(play.noteGroup.members.indexOf(play.strumLineNotes) + 1, splashes);
		for (lane in 0...8)
		{
			var hold:FlxSprite = new FlxSprite();
			hold.antialiasing = ClientPrefs.data.antialiasing;
			hold.visible = false;
			holds.push(hold);
			holdTimers.push(0);
			holdEnds.push(-1);
			play.noteGroup.add(hold);
		}
		loadHolds(holdSkin);
		Paths.getSparrowAtlas(PATH + skin); // precarga
	}

	public static function precache(skin:String, holdSkin:String)
	{
		Paths.getSparrowAtlas(PATH + skin);
		Paths.getSparrowAtlas(PATH + 'holds/' + holdSkin);
	}

	public function changeSkin(newSkin:String, holdSkin:String)
	{
		skin = newSkin;
		loadHolds(holdSkin);
	}

	function loadHolds(holdSkin:String)
	{
		for (lane => hold in holds)
		{
			var color:Int = lane % 4;
			hold.frames = Paths.getSparrowAtlas(PATH + 'holds/' + holdSkin);
			hold.animation.addByPrefix('start', 'sustain cover start ' + COLORS[color], 24, false);
			hold.animation.addByPrefix('hold', 'sustain cover loop ' + COLORS[color], 24, true);
			hold.animation.addByPrefix('end', 'sustain cover end ' + END_COLORS[color], 24, false);
			hold.animation.play('hold', true);
			hold.visible = false;
			holdTimers[lane] = 0;
			holdEnds[lane] = -1;
		}
	}

	/** Nota acertada (del jugador o del rival). */
	public function noteHit(note:Note)
	{
		var lane:Int = note.noteData + (note.mustPress ? 4 : 0);
		if (lane < 0 || lane >= holds.length) return;
		if (note.isSustainNote)
		{
			holdTimers[lane] = 0;
			return;
		}

		if (note.tail.length > 0)
		{
			holdTimers[lane] = 0;
			holdEnds[lane] = note.strumTime + note.sustainLength;
			var strum = play.strumLineNotes.members[lane];
			if (strum != null && strum.visible)
			{
				holds[lane].visible = true;
				holds[lane].animation.play('start', true);
			}
		}

		if (note.mustPress && note.extraData.get('exeSplash') == true && note.rating == 'sick')
			spawnSplash(note.noteData);
	}

	/** Nota del jugador fallada: si era un trozo de nota larga, fuera su funda. */
	public function noteMiss(note:Note)
	{
		if (!note.isSustainNote) return;
		var lane:Int = note.noteData + 4;
		if (lane < holds.length)
		{
			holds[lane].visible = false;
			holdEnds[lane] = -1;
		}
	}

	function spawnSplash(data:Int)
	{
		var strum = play.playerStrums.members[data];
		if (strum == null) return;
		var splash:SonicSplash = splashes.recycle(SonicSplash);
		splash.start(PATH + skin, strum.x - 75, strum.y - 100, 'note impact ${FlxG.random.int(1, 2)} ${COLORS[data % 4]}', 0.18 / play.playbackRate);
	}

	public function update(elapsed:Float)
	{
		var limit:Float = Conductor.stepCrochet * 1.5 / 1000;
		for (lane => hold in holds)
		{
			var strum = play.strumLineNotes.members[lane];
			if (strum == null) continue;

			// la nota larga ha terminado
			if (holdEnds[lane] >= 0 && Conductor.songPosition >= holdEnds[lane])
			{
				holdEnds[lane] = -1;
				if (lane >= 4) hold.animation.play('end', true);
				else
				{
					hold.visible = false;
					holdTimers[lane] = 0;
				}
			}

			hold.alpha = strum.alpha;
			if (!strum.visible || strum.alpha <= 0) hold.visible = false;
			if (!hold.visible) continue;

			var anim:String = hold.animation.name;
			holdTimers[lane] += elapsed * play.playbackRate;
			if (holdTimers[lane] > limit && anim != 'end') hold.visible = false;
			if (hold.animation.finished)
			{
				if (anim == 'start') hold.animation.play('hold', true);
				else if (anim == 'end')
				{
					hold.visible = false;
					holdTimers[lane] = 0;
				}
			}
			hold.setPosition(strum.x - 77, strum.y - 55);
		}
	}
}

/** Un splash: se mata solo al acabar su tiempo (el mod lo cortaba a los 0.18 s). */
class SonicSplash extends FlxSprite
{
	var life:Float = 0;
	var skin:String;

	public function start(skin:String, x:Float, y:Float, anim:String, life:Float)
	{
		if (this.skin != skin)
		{
			this.skin = skin;
			frames = Paths.getSparrowAtlas(skin);
			for (key in [1, 2])
				for (color in ['purple', 'blue', 'green', 'red'])
				{
					var name:String = 'note impact $key $color';
					animation.addByPrefix(name, name, 24, false);
				}
			antialiasing = ClientPrefs.data.antialiasing;
		}
		setPosition(x, y);
		animation.play(anim, true);
		this.life = life;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		life -= elapsed;
		if (life <= 0) kill();
	}
}
