-- Generado por tools/ports/yararara.py (no es del mod): el video de entrada es lo primero que se ve.
function onCreate()
	setProperty('skipCountdown', true) -- la cancion (y su video, en el segundo 0) empieza ya
end

function onCreatePost()
	makeLuaSprite('introCover', nil, 0, 0)
	makeGraphic('introCover', screenWidth, screenHeight, '000000')
	setObjectCamera('introCover', 'other')
	addLuaSprite('introCover', true)
end

function onEvent(name, value1, value2)
	if name == 'playVideo' then
		removeLuaSprite('introCover', true) -- el video ya pone su propio fondo negro
	end
end
