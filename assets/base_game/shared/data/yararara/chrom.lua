function onCreatePost()
 
	initLuaShader("yararara-chrom")

	if shadersEnabled ~= true then return end -- sin shaders, no hay filtro que poner

	makeLuaSprite("shaderImage")
	makeGraphic("shaderImage", screenWidth, screenHeight)
	setSpriteShader("shaderImage", "yararara-chrom")

    addHaxeLibrary("ShaderFilter", "openfl.filters")
	runHaxeCode([[
	trace(ShaderFilter);
	game.camGame.setFilters([new ShaderFilter(game.getLuaObject("shaderImage").shader)]);
	//game.camHUD.setFilters([new ShaderFilter(game.getLuaObject("shaderImage").shader)]);
	]])
end

function onUpdate()
    if shadersEnabled ~= true then return end
    setShaderFloat("shaderImage", "iTime", os.clock())
end

--[[
    if you use crt, monitor remove game.camHUD

]]