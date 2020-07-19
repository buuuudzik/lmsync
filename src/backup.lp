<?
require('apps')
require('json')
_SCRIPTNAME = 'LM Sync'
requestMethod = ngx.var.request_method

function handleGET()
	local objects = db:getall('SELECT * FROM objects')
	local object_tags = db:getall('SELECT * FROM objecttags')

	local backup = {
		objects = objects,
		objectTags = objects_tags,
	}
  	print(json.encode(backup))
end

function handlePOST()
	upload();

	local backup = getvar('file')

	if #backup > 0 then
		backup = json.decode(backup)
	else
		return print('not saved')
	end

	local policies = {
		newObject = getvar("newObject") or "create",
		notExisting = getvar("notExisting") or "let",
		name = getvar("name") or "replace",
		value = getvar("value") or "replace",
		updatetime = getvar("updatetime") or "replace",
		tags = getvar("tags") or "concat"
	}

	local backupObjectsIndex = {}
	for k,v in ipairs(backup.objects) do
		backupObjectsIndex[v.id] = { object = v, tags = {} }
	end

	function getById(id)
		return backupObjectsIndex[id]
	end

	for k,t in ipairs(backup.tags) do
		local obj = getById(t.object)
		table.insert(obj.tags, t)
	end

	-- Create objects list diff
	local toDeleteObjects = {} -- czy usuwać je czy stworzyć ich listę?
	local newObjects = {}	
	local withDiffName = {}
	local withDiffValue = {}
	local withDiffTags = {}
	local withDiffTime = {}
	
	-- parse and solve conflicts
	local current_objects = db:getall('SELECT * FROM objects')
	local current_object_tags = db:getall('SELECT * FROM objecttags')

	for k,v in ipairs(current_objects) do
		if backupObjectsIndex[v.id] then
			backupObjectsIndex[v.id].currentObject = v
			if backupObjectsIndex[v.id].object.name ~= v.name then table.insert(withDiffName, v.id) end
			if backupObjectsIndex[v.id].object.value ~= v.value then table.insert(withDiffValue, v.id) end
			if backupObjectsIndex[v.id].object.tagcache ~= v.tagcache then table.insert(withDiffTags, v.id) end
			if backupObjectsIndex[v.id].object.updatetime ~= v.updatetime then table.insert(withDiffTime, v.id) end
		else
			table.insert(toDeleteObjects, v.id)
		end
	end

	for k,v in pairs(backupObjectsIndex) do
		if not v.currentObject then
			table.insert(newObjects, v.object.id)
		end
	end

	for k,t in ipairs(current_object_tags) do
		local obj = getById(t.object)
		if obj then
			if not obj.currentTags then
				obj.currentTags = {}
			end
			table.insert(obj.currentTags, t)
		end
	end

	-- actions according to the defined policies
	if policies.newObject == "create" then
		local toInsert = {}
		for k,id in ipairs(newObjects) do
			local obj = getById(id).object
			if obj then db:insert('objects', obj) end
		end
	end

	if policies.notExisting == "delete" then
		for k,id in ipairs(toDeleteObjects) do
			db:delete("objects", { id = id })
		end
	end

	if policies.name == "replace" then
		for k,id in ipairs(withDiffName) do
			local v = getById(id).object;
			db:update('objects', { name = v.name }, { id = v.id })
		end
	end

	if policies.value == "replace" then
		for k,id in ipairs(withDiffValue) do
			local v = getById(id).object;
			db:update('objects', { value = v.value, datahex = v.datahex }, { id = v.id })
		end
	end

	if policies.updatetime == "replace" then
		for k,id in ipairs(withDiffTime) do
			local v = getById(id).object;
			db:update('objects', { updatetime = v.updatetime }, { id = v.id })
		end
	end

	if policies.tags == "replace" then
		for k,id in ipairs(withDiffTags) do
			local v = getById(id).object;
			local tags = getById(id).tags;
			local c = getById(id).currentObject;
			local cTags = getById(id).currentTags;
			
			db:update("objects", { tagcache = v.tagcache }, { id = v.id } )
			if #currentTags > 0 then db:delete("objecttags", { object = id }) end
			for _,t in ipairs(tags) do
				db:insert("objecttags", t)
			end
		end
	elseif policies.tags == "concat" then
		for k,id in ipairs(withDiffTags) do
			local v = getById(id).object;
			local c = getById(id).currentObject;
			local tags = getById(id).tags;
			local currentTags = getById(id).currentTags;
			local currentTagsIndex = {}

			local tagcache = ""
			if currentTags then
				for _,t in ipairs(currentTags) do
					currentTagsIndex[t.tag] = true
					tagcache = tagcache .. " " .. t.tag
				end
			end

			-- usuń duplikaty
			local tagsToAdd = {}
			if tags then
				for _,t in ipairs(tags) do
					if not currentTagsIndex[t.tag] then
						table.insert(tagsToAdd, t)
						tagcache = tagcache .. " " .. t.tag
					end
				end
			end

			tagcache = tagcache:trim()
			
			db:update("objects", { tagcache = tagcache }, { id = v.id } )
			if #tagsToAdd > 0 then log("tagsToAdd", #tagsToAdd, tagsToAdd[1]) end
			for _,t in ipairs(tagsToAdd) do
				db:insert("objecttags", t)
			end
		end
	end

	write("saved")
end

if requestMethod == "GET" then
	handleGET();
elseif requestMethod == "POST" then
	handlePOST()
end