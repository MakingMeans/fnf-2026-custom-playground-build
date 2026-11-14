function onEvent(name, value1, value2)
	if name == 'Zoom Camera' then
		if value2 == '0' or '' then
			setProperty('defaultCamZoom', value1);
		else
			doTweenZoom('camTween', 'camGame', value1, value2, 'circOut')
		end
	end
end