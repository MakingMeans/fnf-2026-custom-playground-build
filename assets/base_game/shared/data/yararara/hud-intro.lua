function onCreatePost()
    for i = 0,3 do
        setPropertyFromGroup('playerStrums', i, 'visible', false)
        setPropertyFromGroup('playerStrums', i, 'alpha', 0)
        setPropertyFromGroup('opponentStrums', i, 'visible', false)
        setPropertyFromGroup('opponentStrums', i, 'alpha', 0)
    end
    setProperty('uiGroup.visible', false)
    setProperty('uiGroup.alpha', 0)
    setProperty('botplayTxt.visible', false) 
end

function onStepHit()
    if curStep == 64 then
        setProperty('uiGroup.visible', true)
        setProperty('uiGroup.alpha', 0)
        for i = 0,3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            setPropertyFromGroup('opponentStrums', i, 'visible', true)
            setPropertyFromGroup('opponentStrums', i, 'alpha', 0)
        end
        doTweenAlpha('uiGroupIn64', 'uiGroup', 1, 1, 'sineInOut')
        for i = 0,3 do
            doTweenAlpha('playerIn64_'..i, 'playerStrums.members['..i..']', 1, 1, 'sineInOut')
            doTweenAlpha('opponentIn64_'..i, 'opponentStrums.members['..i..']', 1, 1, 'sineInOut')
        end
    end
    if curStep == 1199 then
        doTweenAlpha('uiGroupOut1584', 'uiGroup', 0, 1, 'sineInOut')
        for i = 0,3 do
            doTweenAlpha('playerOut1584_'..i, 'playerStrums.members['..i..']', 0, 1, 'sineInOut')
            doTweenAlpha('opponentOut1584_'..i, 'opponentStrums.members['..i..']', 0, 1, 'sineInOut')
        end
    end
end