function onEvent(tag, arg1, arg2)
    if tag ~= "233" then return end

    local command = stringTrim(arg1:upper())
    local tweenType = arg2 ~= '' and arg2 or "quadOut"
    local tweenTime = 0.5 
    local opponentNotes = {0,1,2,3}  
    local playerNotes = {4,5,6,7}    

    if command == 'A' then
        for _,i in ipairs(opponentNotes) do
            doTweenAlpha('oppFadeIn'..i, 'strumLineNotes.members['..i..']', 1, tweenTime, tweenType)
        end
    elseif command == 'B' then
        for _,i in ipairs(opponentNotes) do
            doTweenAlpha('oppFadeOut'..i, 'strumLineNotes.members['..i..']', 0, tweenTime, tweenType)
        end
    elseif command == 'C' then
        for _,i in ipairs(playerNotes) do
            doTweenAlpha('playerFadeOut'..i, 'strumLineNotes.members['..i..']', 0, tweenTime, tweenType)
        end
    elseif command == 'V' then
        for _,i in ipairs(playerNotes) do
            doTweenAlpha('playerFadeIn'..i, 'strumLineNotes.members['..i..']', 1, tweenTime, tweenType)
        end
    elseif command == 'N' then
        doTweenAlpha('healthBarHide', 'healthBar', 0, tweenTime, tweenType)
        doTweenAlpha('iconP1Hide', 'iconP1', 0, tweenTime, tweenType)
        doTweenAlpha('iconP2Hide', 'iconP2', 0, tweenTime, tweenType)
    elseif command == 'M' then
        doTweenAlpha('healthBarShow', 'healthBar', 1, tweenTime, tweenType)
        doTweenAlpha('iconP1Show', 'iconP1', 1, tweenTime, tweenType)
        doTweenAlpha('iconP2Show', 'iconP2', 1, tweenTime, tweenType)
    end
end