local elPutoPajinDeMierda = {
    {name = "pajin_frontal", path = "endless-us/stage/a", x = -1292, y = -212, animName = "Idle", animPrefix = "a", fps = 24, loop = false, flipX = false, scaleX = 1.5, scaleY = 1.5, scrollX = 0.85, scrollY = 0, front = true, lowQualityHide = true}
}

local countdador = {
    {name = "three", path = "endless-us/stage/three", x = 0, y = 0, scaleX = 1, scaleY = 1, alpha = 0, front = false},
    {name = "two", path = "endless-us/stage/two", x = 0, y = 0, scaleX = 1, scaleY = 1, alpha = 0, front = false},
    {name = "one", path = "endless-us/stage/one", x = 0, y = 0, scaleX = 1, scaleY = 1, alpha = 0, front = false},
    {name = "go", path = "endless-us/stage/gofun", x = 0, y = 0, scaleX = 1, scaleY = 1, alpha = 0, front = false}

}
function onCreate()
    for _, putoMajin in ipairs(elPutoPajinDeMierda) do
        if not (lowQuality and putoMajin.lowQualityHide) then
            makeAnimatedLuaSprite(putoMajin.name, putoMajin.path, putoMajin.x, putoMajin.y)
            addAnimationByPrefix(putoMajin.name, putoMajin.animName, putoMajin.animPrefix, putoMajin.fps, putoMajin.loop)
            setProperty(putoMajin.name..'.flipX', putoMajin.flipX)
            scaleObject(putoMajin.name, putoMajin.scaleX, putoMajin.scaleY)
            setScrollFactor(putoMajin.name, putoMajin.scrollX, putoMajin.scrollY)
            addLuaSprite(putoMajin.name, putoMajin.front)
            --debugPrint(putoMajin.name.." Esta vivo. Por mi que se muera")
        end
    end

    for _, counter in ipairs(countdador) do
        makeLuaSprite(counter.name, counter.path, counter.x, counter.y)
        scaleObject(counter.name, counter.scaleX, counter.scaleY)
        setObjectCamera(counter.name, 'camHUD')
        screenCenter(counter.name)
        setProperty(counter.name..'.alpha', counter.alpha)
        addLuaSprite(counter.name, counter.front)
    end
end

function onEvent(eventName, value1)
    if eventName == 'noteSpin' then
        for i = 0, 7 do
            setProperty('strumLineNotes.members['..i..'].angle', 0)
            cancelTween(i..'AngleTween')
            noteTweenAngle(i..'AngleTween', i, 360, 0.3, 'circOut')
        end
        playSound('endless-us/sonic sfx', 0.8, 'USSpin')
    end
    if eventName == 'USCounter' then
        if value1 == '3' then
            setProperty('three.alpha', 1)
            doTweenAlpha('threeAlpha', 'three', 0, 0.4)
            doTweenScale('three', 'three', 0, 0.4, 'smootherStepInOut')
        end
        if value1 == '2' then
            setProperty('two.alpha', 1)
            doTweenAlpha('twoAlpha', 'two', 0, 0.4)
            doTweenScale('two', 'two', 0, 0.4, 'smootherStepInOut')
        end
        if value1 == '1' then
            setProperty('one.alpha', 1)
            doTweenAlpha('oneAlpha', 'one', 0, 0.4)
            doTweenScale('one', 'one', 0, 0.4, 'smootherStepInOut')
        end
        if value1 == 'Go' then
            setProperty('go.alpha', 1)
            doTweenAlpha('goAlpha', 'go', 0, 0.4)
            doTweenScale('go', 'go', 0, 0.4, 'smootherStepInOut')
            doTweenAngle('goAngleTween', 'go', 8, 0.4)
        end
        if value1 == 'remove' then
            for _, borralacuenta in ipairs(countdador) do
                cancelTween('goScaleX')
                cancelTween('goScaleY')
                cancelTween('goAlpha')
                cancelTween('goAngleTween')
                removeLuaSprite(borralacuenta.name, true)
            end
        end
    end
end

function onBeatHit()
    if curBeat %2 == 0 then
        for _, majinsIdle in ipairs({"pajines", "pajines2", "pajin_frontal", "pajin_frontal2", "sprite7"}) do
            playAnim(majinsIdle, "Idle", true)
        end
    end
end

function onSectionHit()
    if mustHitSection == true then
        doTweenAlpha("pajin_frontalAlpha", "pajin_frontal", 1, 0.5)
    else
        doTweenAlpha("pajin_frontalAlpha", "pajin_frontal", 0.4, 0.5)
    end
end

--From Dudu
--Tweens the scale of an object
function doTweenScale(tag, obj, target, time, ease)
	doTweenX(tag..'scaleX', obj..'.scale', target, time, ease)
	doTweenY(tag..'scaleY', obj..'.scale', target, time, ease)
end