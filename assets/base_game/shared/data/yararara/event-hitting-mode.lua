local HITTING_Mode = false;
local altMode = false;
local isHit = false;

function onEvent(eventName, value1, value2)
	if eventName == 'HITTING Mode' then
		if value1 == 'true' then
			HITTING_Mode = true;
		else
			HITTING_Mode = false;
			isHit = false;
		end
		
		if value2 == 'true' then
			altMode = true;
		else
			altMode = false;
		end
	end
end

function onCreate()
	precacheSound("yararara/hit");
end

function onBeatHit()
	if HITTING_Mode == true then
		if curBeat % 2 == 1 or (altMode == true and curBeat % 4 == 2) then
			callOnLuas('hitNextZombie')
			playSound("yararara/hit", 1);
			cameraShake('camHUD', 0.01, 0.1);
			cameraShake('camStrum', 0.01, 0.1);
			upsetStrums((isHit and true or false));
			if isHit == true then
				isHit = false;
			end
		end
	end
end

function goodNoteHit(membersIndex, noteData, noteType, isSustainNote)
	if HITTING_Mode == true then
		if isHit == false then
			isHit = true;
		end
	end
end

function upsetStrums(isPlayer)
	local strumsName = (isPlayer and 'playerStrums' or 'opponentStrums');
	local defaultStrumX = (isPlayer and 'defaultPlayerStrumX' or 'defaultOpponentStrumX');
	local defaultStrumY = (isPlayer and 'defaultPlayerStrumY' or 'defaultOpponentStrumY');
	for i = 0, 3 do
		setPropertyFromGroup(strumsName, i, 'x', _G[defaultStrumX .. i] + getRandomInt(-50, 50));
		setPropertyFromGroup(strumsName, i, 'y', _G[defaultStrumY .. i] + getRandomInt(-50, 50));
		setPropertyFromGroup(strumsName, i, 'angle', getRandomInt(-50, 50));
		startTween('reset_' .. strumsName .. i, strumsName .. '.members[' .. i .. ']',
			{
				x = _G[defaultStrumX .. i],
				y = _G[defaultStrumY .. i],
				angle = 0
			}, (30 / curBpm), { ease = 'cubeOut'}
		);
	end
end