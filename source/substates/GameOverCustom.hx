package substates;

/**
 * Game over propio de un escenario. El escenario lo pone en `GameOverSubstate.custom` al crearse
 * (`resetVariables()` lo quita en cada canción) y GameOverSubstate llama a estas funciones.
 * Por defecto no cambian nada del game over de Psych.
 */
class GameOverCustom
{
	public var sub:GameOverSubstate;

	/** false = la clase base no pasa sola de 'firstDeath' a 'deathLoop': lo hace esta clase con `sub.startDeathLoop()`. */
	public var autoLoop:Bool = true;
	/** Tras confirmar: segundos hasta el fundido a negro y duración del fundido. */
	public var endFadeDelay:Float = 0.7;
	public var endFadeTime:Float = 2;

	public function new() {}

	/** Ya existen el personaje, la cámara y la música (sin empezar). */
	public function create():Void {}
	public function update(elapsed:Float):Void {}
	/** false = todavía no se puede reintentar. */
	public function canConfirm():Bool return true;
	/** Se va a reintentar (antes de la animación de confirmar y del fundido). */
	public function confirm():Void {}
	/** Se sale del game over al menú o al mapa (BACK o `sub.exitToMenu()`). */
	public function leave():Void {}
}
