local rate = 16;
local intensity = 1;
local customBop = true;

function onEvent(eventName, value1, value2)
	if eventName == 'Set Camera Bop' then
		--setProperty('camZoomingMult', 0);
		if value1 ~= '' then
			rate = tonumber(value1);
			customBop = true;
		else
			rate = 16;
			customBop = false;
		end
		
		if value2 ~= '' then
			intensity = tonumber(value2);
		else
			intensity = 1;
		end
	end
end

function onStepHit()
	if getProperty('camZooming') then
		if customBop then
			if curStep % rate == 0 then
				--[[setProperty('camGame.zoom', getProperty('camGame.zoom') + 0.015 * intensity);
				setProperty('camHUD.zoom', getProperty('camHUD.zoom') + 0.03 * intensity);]]
				triggerEvent('Add Camera Zoom', 0.015 * intensity, 0.03 * intensity);
			end
		end
	end
end