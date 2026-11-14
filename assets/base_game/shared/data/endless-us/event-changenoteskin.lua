local currentNoteSkin = nil

function onCreatePost()
	local precached = {}
	for i = 0, getProperty('eventNotes.length') - 1 do
		if getPropertyFromGroup('eventNotes', i, 'event') == 'changenoteSkin' then
			local skin = getPropertyFromGroup('eventNotes', i, 'value1')
			if skin == nil or skin == '' then skin = 'NOTE_assets_ENDLESS' end
			if not precached[skin] then
				precached[skin] = true
				precacheImage('endless-us/noteSkins/'..skin)
			end
		end
	end
end

function onEvent(n, v1)
	if n ~= 'changenoteSkin' then return end

	if v1 == '' then
		currentNoteSkin = 'endless-us/noteSkins/NOTE_assets_ENDLESS'
	else
		currentNoteSkin = 'endless-us/noteSkins/'..v1
		for i = 0, getProperty('playerStrums.length') - 1 do setPropertyFromGroup('playerStrums', i, 'texture', currentNoteSkin) end
		for i = 0, getProperty('opponentStrums.length') - 1 do setPropertyFromGroup('opponentStrums', i, 'texture', currentNoteSkin) end
	end

	for i = 0, getProperty('notes.length') - 1 do setPropertyFromGroup('notes', i, 'texture', currentNoteSkin) end
end

function onSpawnNote(id)
	if currentNoteSkin ~= nil then setPropertyFromGroup('notes', id, 'texture', currentNoteSkin) end
end
