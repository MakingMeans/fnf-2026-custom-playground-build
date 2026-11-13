package shaders;

import flixel.system.FlxAssets.FlxShader;

/**
 * Transicion de iris del overworld (como en Super Mario World): todo negro salvo un circulo
 * alrededor de `uCenter`, en pixeles de la pantalla. Se pone en un sprite negro del tamaño de la
 * pantalla, en la camara del HUD, y se anima el radio.
 */
class IrisShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform vec2 uCenter;
		uniform float uRadius;

		void main()
		{
			vec2 pos = openfl_TextureCoordv * openfl_TextureSize;
			float d = distance(pos, uCenter);
			// borde de 3 px suavizado: sin el, el circulo se ve dentado al cerrarse
			float alpha = smoothstep(uRadius - 1.5, uRadius + 1.5, d);
			gl_FragColor = vec4(0.0, 0.0, 0.0, alpha);
		}
	')
	public function new()
	{
		super();
		uCenter.value = [0, 0];
		uRadius.value = [0];
	}

	public function setIris(x:Float, y:Float, radius:Float)
	{
		uCenter.value = [x, y];
		uRadius.value = [radius];
	}
}
