function onEvent(name, value1, value2)
	if name == 'cameraSetTarget' then
		cameraSetTarget(value1);
		focus = value1
		if value2 ~= '' then
			if value2 == 'true' or value2 == 'false' then
				loop = value2
			end
		else
			loop = 'false'
		end
	end
end

function onSectionHit()
	if loop == 'true' then
		cameraSetTarget(focus);
	elseif loop == 'false' then
		-- Nothing...
	end
end