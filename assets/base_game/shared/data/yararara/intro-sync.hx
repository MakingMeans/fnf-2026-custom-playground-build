// Generado por tools/ports/yararara.py (no es del mod). Ver INTRO_SYNC alli.
var cover:FlxSprite; // FlxSprite y FlxColor ya los da el HScript de Psych
var intro = null;
var waiting:Bool = false;

function onCreate()
{
	game.skipCountdown = true;
	cover = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	cover.cameras = [game.camOther];
	game.add(cover);
}

// la primera vez se para la cancion y se abre el video; cuando ya avanza, se vuelve a llamar y sigue
function onStartCountdown()
{
	if (intro != null || waiting) return waiting ? Function_Stop : Function_Continue;

	intro = game.startVideo('yararara/1', true, false, false, true);
	if (intro == null) return Function_Continue;
	waiting = true;
	game.canPause = false;
	return Function_Stop;
}

function onUpdate(elapsed:Float)
{
	if (!waiting || intro == null || intro.videoSprite == null) return;
	if (intro.videoSprite.bitmap.position <= 0) return;

	waiting = false;
	game.remove(cover);
	cover.destroy();
	game.startCountdown();
}
