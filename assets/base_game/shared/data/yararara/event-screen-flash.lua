function onEvent(name, value1, value2)
	if name == 'Screen Flash' then
		if value2 == '' then
			value2 = 1;
		end
		cameraFlash('hud', value2, tonumber(value1));
	end
end