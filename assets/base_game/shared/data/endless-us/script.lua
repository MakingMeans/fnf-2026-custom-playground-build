local chillModchart = false
local fastModchart = false
function onEvent(n, v1, v2)
    if n == 'colorFlash' and (not shadersEnabled or lowQuality or not flashingLights) then
        local values = stringSplit(v1, ',')
        local settings = stringSplit(v2, ',')
        if tonumber(values[2]) <= -100 then
            makeLuaSprite('endBlack', nil, 0, 0)
            makeGraphic('endBlack', screenWidth * 4, screenHeight * 4, '000000')
            setScrollFactor('endBlack', 0, 0)
            screenCenter('endBlack')
            setProperty('endBlack.alpha', 0)
            addLuaSprite('endBlack', true)
            doTweenAlpha('endBlackAlpha', 'endBlack', 1, tonumber(settings[1]), stringTrim(settings[2]))
        end
    end
    if n == 'USModchart' then
        if v1 == 'slow' then
            chillModchart = true
        elseif v1 == 'fast' then
            chillModchart = false
            fastModchart = true
        end
    end
    if n == 'fade' then
        if v1 == 'hud' then
            doTweenAlpha('camHUDAlpha', 'camHUD', 0, 3)
        end
    end
end

local holdMove = 0
function onUpdatePost(elapsed)
    holdMove = holdMove + elapsed * 5
    if chillModchart then
        for i = 0, 7 do
            setPropertyFromGroup('strumLineNotes', i, 'x', getPropertyFromGroup('strumLineNotes', i, 'x') + math.cos(holdMove + i) * 0.2)
            setPropertyFromGroup('strumLineNotes', i, 'y', getPropertyFromGroup('strumLineNotes', i, 'y') + math.sin(holdMove + i) * 0.1)
        end
    end
    if fastModchart then
        holdMove = holdMove + elapsed * 10
        for i = 0, 7 do
            setPropertyFromGroup('strumLineNotes', i, 'x', getPropertyFromGroup('strumLineNotes', i, 'x') + math.cos(holdMove + i) * 0.3)
            setPropertyFromGroup('strumLineNotes', i, 'y', getPropertyFromGroup('strumLineNotes', i, 'y') + math.sin(holdMove + i) * 0.5)
        end
    end
end