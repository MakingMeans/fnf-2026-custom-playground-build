-- Zombi de cada hueco (1..15): tres atlas compartidos en vez de quince archivos.
-- Los huecos 3, 6, 7 y 8 son los que en el mod no cargaban por la errata "zombeis".
ZOMBIE_ATLAS = {'a', 'b', 'c', 'b', 'a', 'c', 'c', 'c', 'a', 'b', 'b', 'a', 'b', 'b', 'a'}

function onCreate()
    makeLuaSprite('A', 'yararara/stage/kw', -550, -450);
    scaleObject('A', 5, 5);
    setScrollFactor('A', 1, 1);
    addLuaSprite('A', false);
    makeLuaSprite('B', 'yararara/stage/kke', 150, -200);
    scaleObject('B', 1, 1);
    setScrollFactor('B', 1, 1);
    addLuaSprite('B', false);
    makeLuaSprite('C', 'yararara/stage/teto-0', 750, -200);
    scaleObject('C', 1, 1);
    setScrollFactor('C', 1, 1);
    addLuaSprite('C', false);
    makeLuaSprite('E', 'yararara/stage/background', -900, 300);
    scaleObject('E', 1, 1);
    setScrollFactor('E', 1, 1);
    addLuaSprite('E', false);
    makeLuaSprite('D', 'yararara/stage/background', -900, -550);
    scaleObject('D', 1, 1);
    setScrollFactor('D', 1, 1);
    addLuaSprite('D', false);
    local offscreenRight = 2000
    local offscreenLeft = -500
    local stepOffset = 300
    for i = 1, 15 do
        local initXZ = offscreenRight + i * stepOffset
        local initXP = offscreenLeft - i * stepOffset
        makeAnimatedLuaSprite('zombies-'..i, 'yararara/zombies/zombie-'..ZOMBIE_ATLAS[i], initXZ, -250)
        addAnimationByPrefix('zombies-'..i, 'zombies-'..i, 'idle', 20, true)
        addLuaSprite('zombies-'..i, false)
        setProperty('zombies-'..i..'.alpha', 0.0001)
        scaleObject('zombies-'..i, 0.8, 0.8)
        makeAnimatedLuaSprite('pzombies-'..i, 'yararara/zombies/zombie-'..ZOMBIE_ATLAS[i], initXP, 600)
        addAnimationByPrefix('pzombies-'..i, 'zombies-'..i, 'idle', 20, true)
        addLuaSprite('pzombies-'..i, false)
        setProperty('pzombies-'..i..'.alpha', 0.0001)
        setProperty('pzombies-'..i..'.flipX', true)
        scaleObject('pzombies-'..i, 0.8, 0.8)
    end
    setProperty('C.visible', false);
    setProperty('C.alpha', 0);
    setProperty('D.visible', false);
    setProperty('E.visible', false);
    startBeat = nil
    zombieInterval = 10
    pzombieInterval = 15
    zombieRespawnBeats = 10
    pzombieRespawnBeats = 15
    zombieSpeeds = {}
    pzombieSpeeds = {}
    hitFlags = {}
    isFlying = {}
    flyTime = {}
    lastHitZombieIndex = 0
    stopRespawn = false
    initPosZ = {}
    initPosP = {}
    fixedTargetX = nil
    fixedZTargetX = nil
    fixedPTargetX = nil
    for i = 1, 15 do
        hitFlags[i] = false
        isFlying[i] = false
        flyTime[i] = 0
        initPosZ[i] = offscreenRight + i * stepOffset
        initPosP[i] = offscreenLeft - i * stepOffset
    end
end
local beatBop = true
function getZTargetX()
    if fixedZTargetX ~= nil then return fixedZTargetX end
    return getProperty('dad.x') or 300
end
function getPTargetX()
    if fixedPTargetX ~= nil then return fixedPTargetX end
    return getProperty('boyfriend.x') or 1600
end
function moveAllZombies()
    if startBeat == nil then return end
    local targetZ = getZTargetX()
    local targetP = getPTargetX()
    for i = 1, 15 do
        if not hitFlags[i] then
            local z = 'zombies-'..i
            local pz = 'pzombies-'..i
            if zombieSpeeds[i] and zombieSpeeds[i] ~= 0 then
                local curX = getProperty(z..'.x')
                local nextX = curX + zombieSpeeds[i]
                local clampedX = math.max(nextX, targetZ)
                setProperty(z..'.x', clampedX)
                if clampedX == targetZ then zombieSpeeds[i] = 0 end
            end
            if pzombieSpeeds[i] and pzombieSpeeds[i] ~= 0 then
                local curX = getProperty(pz..'.x')
                local nextX = curX + pzombieSpeeds[i]
                local clampedX = math.min(nextX, targetP)
                setProperty(pz..'.x', clampedX)
                if clampedX == targetP then pzombieSpeeds[i] = 0 end
            end
        end
    end
end
function respawnZombie(i)
    if stopRespawn then return end
    runHaxeCode([[
        var z = game.getLuaObject("zombies-]]..i..[[");
        var pz = game.getLuaObject("pzombies-]]..i..[[");
        if (z != null) {
            FlxTween.cancelTweensOf(z);
            z.x = ]]..initPosZ[i]..[[;
            z.y = -250;
            z.alpha = 1;
        }
        if (pz != null) {
            FlxTween.cancelTweensOf(pz);
            pz.x = ]]..initPosP[i]..[[;
            pz.y = 600;
            pz.alpha = 1;
        }
    ]])
    hitFlags[i] = false
    isFlying[i] = false
    flyTime[i] = 0
    local targetZ = getZTargetX()
    local targetP = getPTargetX()
    local distZ = targetZ - initPosZ[i]
    local distP = targetP - initPosP[i]
    zombieSpeeds[i] = distZ / zombieRespawnBeats
    pzombieSpeeds[i] = distP / pzombieRespawnBeats
end
function moveZombies(hitNum)
    hitNum = ((hitNum - 1) % 15) + 1
    if hitFlags[hitNum] then return end
    local targetZ = getZTargetX()
    local targetP = getPTargetX()
    local z = 'zombies-'..hitNum
    local pz = 'pzombies-'..hitNum
    local curZ = getProperty(z..'.x')
    local curP = getProperty(pz..'.x')
    if math.abs(curZ - targetZ) > 10 or math.abs(curP - targetP) > 10 then
        return
    end
    setProperty(z..'.x', targetZ)
    setProperty(pz..'.x', targetP)
    hitFlags[hitNum] = true
    isFlying[hitNum] = true
    flyTime[hitNum] = curBeat
    doTweenX('flyZ_'..hitNum, z, targetZ - 500, 0.5, 'cubeOut')
    doTweenY('flyZY_'..hitNum, z, getProperty(z..'.y') - 200, 0.5, 'cubeOut')
    doTweenAlpha('flyZA_'..hitNum, z, 0, 0.5, 'linear')
    doTweenX('flyPZ_'..hitNum, pz, targetP + 500, 0.5, 'cubeOut')
    doTweenY('flyPZY_'..hitNum, pz, getProperty(pz..'.y') - 200, 0.5, 'cubeOut')
    doTweenAlpha('flyPZA_'..hitNum, pz, 0, 0.5, 'linear')
end
function hitNextZombie()
    for offset = 1, 15 do
        local i = ((lastHitZombieIndex + offset - 1) % 15) + 1
        if not hitFlags[i] then
            local z = 'zombies-'..i
            local pz = 'pzombies-'..i
            local alphaZ = getProperty(z..'.alpha')
            local alphaP = getProperty(pz..'.alpha')
            if alphaZ >= 0.5 and alphaP >= 0.5 then
                local curX = getProperty(z..'.x')
                local curY = getProperty(z..'.y')
                local curPX = getProperty(pz..'.x')
                local curPY = getProperty(pz..'.y')
                if curX <= 1800 and curPX >= 100 then
                    zombieSpeeds[i] = 0
                    pzombieSpeeds[i] = 0
                    hitFlags[i] = true
                    isFlying[i] = true
                    flyTime[i] = curBeat
                    lastHitZombieIndex = i
                    cancelTween('flyZ_'..i)
                    cancelTween('flyZY_'..i)
                    cancelTween('flyZA_'..i)
                    cancelTween('flyPZ_'..i)
                    cancelTween('flyPZY_'..i)
                    cancelTween('flyPZA_'..i)
                    doTweenX('flyZ_'..i, z, curX - 500, 0.5, 'cubeOut')
                    doTweenY('flyZY_'..i, z, curY - 200, 0.5, 'cubeOut')
                    doTweenAlpha('flyZA_'..i, z, 0, 0.5, 'linear')
                    doTweenX('flyPZ_'..i, pz, curPX + 500, 0.5, 'cubeOut')
                    doTweenY('flyPZY_'..i, pz, curPY - 200, 0.5, 'cubeOut')
                    doTweenAlpha('flyPZA_'..i, pz, 0, 0.5, 'linear')
                    return
                end
            end
        end
    end
end
function flyAllRemaining()
    stopRespawn = true
    local targetZ = getZTargetX()
    local targetP = getPTargetX()
    for i = 1, 15 do
        if not hitFlags[i] then
            hitFlags[i] = true
            isFlying[i] = true
            local z = 'zombies-'..i
            local pz = 'pzombies-'..i
            setProperty(z..'.x', targetZ)
            setProperty(pz..'.x', targetP)
            doTweenX('flyAllZ_'..i, z, targetZ - 500, 0.5, 'cubeOut')
            doTweenY('flyAllZY_'..i, z, getProperty(z..'.y') - 200, 0.5, 'cubeOut')
            doTweenAlpha('flyAllZA_'..i, z, 0, 0.5, 'linear')
            doTweenX('flyAllPZ_'..i, pz, targetP + 500, 0.5, 'cubeOut')
            doTweenY('flyAllPZY_'..i, pz, getProperty(pz..'.y') - 200, 0.5, 'cubeOut')
            doTweenAlpha('flyAllPZA_'..i, pz, 0, 0.5, 'linear')
        end
    end
    startBeat = nil
end
function onBeatHit()
    if beatBop then
    end
    if startBeat ~= nil then
        moveAllZombies()
    end
    if not stopRespawn then
        for i = 1, 15 do
            if isFlying[i] and curBeat - flyTime[i] >= 1 then
                respawnZombie(i)
            end
        end
    end
end
function onStepHit()
    if curStep == 224 then
        setProperty('D.visible', true);
    end
    if curStep == 210 then
        setProperty('C.visible', true);
        setProperty('C.alpha', 0);
        doTweenAlpha('cFadeIn', 'C', 1, 2, 'sineOut');
        beatBop = false
    end
    if curStep == 368 then
        setProperty('E.visible', true);
        if getProperty('gf') ~= nil then
            setProperty('gf.y', 550);
            fixedZTargetX = getProperty('dad.x') or 300
            fixedPTargetX = getProperty('boyfriend.x') or 1600
            local targetZ = fixedZTargetX
            local targetP = fixedPTargetX
            for i = 1, 15 do
                setProperty('zombies-'..i..'.x', initPosZ[i])
                setProperty('zombies-'..i..'.y', -250)
                setProperty('pzombies-'..i..'.x', initPosP[i])
                setProperty('pzombies-'..i..'.y', 600)
                setProperty('zombies-'..i..'.alpha', 1)
                setProperty('pzombies-'..i..'.alpha', 1)
                hitFlags[i] = false
                isFlying[i] = false
                flyTime[i] = 0
                if startBeat == nil then
                    startBeat = curBeat
                end
                local zBeatsToReach = (i-1) * zombieInterval
                local pBeatsToReach = (i-1) * pzombieInterval
                local distZ = targetZ - initPosZ[i]
                local distP = targetP - initPosP[i]
                if zBeatsToReach > 0 then
                    zombieSpeeds[i] = distZ / zBeatsToReach
                else
                    zombieSpeeds[i] = (i == 1 and distZ or 0)
                end
                if pBeatsToReach > 0 then
                    pzombieSpeeds[i] = distP / pBeatsToReach
                else
                    pzombieSpeeds[i] = (i == 1 and distP or 0)
                end
            end
        end
        if getProperty('boyfriend') ~= nil then
            setProperty('boyfriend.y', 950);
        end
        stopRespawn = false
    end
    if curStep == 616 then
        flyAllRemaining()
    end
    if curStep == 624 then
        setProperty('E.visible', false);
        if getProperty('gf') ~= nil then
            setProperty('gf.y', 30);
            setProperty('gf.x', 650);
            for i = 1, 15 do
                setProperty('pzombies-'..i..'.alpha', 0.0001)
                setProperty('zombies-'..i..'.alpha', 0.0001)
            end
        end
        if getProperty('boyfriend') ~= nil then
            setProperty('boyfriend.y', 50);
            setProperty('boyfriend.x', 1670);
        end
        startBeat = nil
        zombieSpeeds = {}
        pzombieSpeeds = {}
        fixedTargetX = nil
        fixedZTargetX = nil
        fixedPTargetX = nil
        for i = 1, 15 do
            hitFlags[i] = false
            isFlying[i] = false
            flyTime[i] = 0
        end
        stopRespawn = false
    end
    if curStep == 960 then
        setProperty('E.visible', true);
        if getProperty('gf') ~= nil then
            setProperty('gf.y', 550);
            fixedZTargetX = getProperty('dad.x') or 300
            fixedPTargetX = getProperty('boyfriend.x') or 1600
            local targetZ = fixedZTargetX
            local targetP = fixedPTargetX
            for i = 1, 15 do
                setProperty('zombies-'..i..'.x', initPosZ[i])
                setProperty('zombies-'..i..'.y', -250)
                setProperty('pzombies-'..i..'.x', initPosP[i])
                setProperty('pzombies-'..i..'.y', 600)
                setProperty('zombies-'..i..'.alpha', 1)
                setProperty('pzombies-'..i..'.alpha', 1)
                hitFlags[i] = false
                isFlying[i] = false
                flyTime[i] = 0
                if startBeat == nil then
                    startBeat = curBeat
                end
                local zBeatsToReach = (i-1) * zombieInterval
                local pBeatsToReach = (i-1) * pzombieInterval
                local distZ = targetZ - initPosZ[i]
                local distP = targetP - initPosP[i]
                if zBeatsToReach > 0 then
                    zombieSpeeds[i] = distZ / zBeatsToReach
                else
                    zombieSpeeds[i] = (i == 1 and distZ or 0)
                end
                if pBeatsToReach > 0 then
                    pzombieSpeeds[i] = distP / pBeatsToReach
                else
                    pzombieSpeeds[i] = (i == 1 and distP or 0)
                end
            end
        end
        if getProperty('boyfriend') ~= nil then
            setProperty('boyfriend.y', 950);
        end
        stopRespawn = false
    end
end