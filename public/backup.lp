<?
require('apps')
require('json')
_SCRIPTNAME = 'LM Sync'
requestMethod = ngx.var.request_method

function handleGET()
	local objects = db:getall('SELECT * FROM objects') or {};
	local object_tags = db:getall('SELECT * FROM objecttags') or {}

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

	if type(backup.objects) ~= "table" then return print("There is no objects!") end
	if type(backup.tags) ~= "table" then return print("There is no tags!") end

	local policies = {
		newObject = getvar("newObject") or "create",
		notExisting = getvar("notExisting") or "let",
		name = getvar("name") or "replace",
		value = getvar("value") or "useLater",
		comment = getvar("comment") or "replace",
		enums = getvar("enums") or "replace",
		type = getvar("type") or "replace",
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
	local withDiffTags = {}
	local withDiffTime = {}
	local withDiffType = {}
	local withDiffComment = {}
	local withDiffEnums = {}
	
	-- parse and solve conflicts
	local current_objects = db:getall('SELECT * FROM objects')
	local current_object_tags = db:getall('SELECT * FROM objecttags')

	for k,t in ipairs(current_object_tags) do
		local obj = getById(t.object)
		if obj then
			if not obj.currentTags then
				obj.currentTags = {}
			end
			table.insert(obj.currentTags, t)
		end
	end

	for k,c in ipairs(current_objects) do
		if backupObjectsIndex[c.id] then
			backupObjectsIndex[c.id].currentObject = c
			local obj = getById(c.id)
			local object = obj.object
			local currentTags = obj.currentTags or {}

			if object.name ~= "" and object.name ~= c.name then table.insert(withDiffName, c.id) end
			if object.type ~= c.type then table.insert(withDiffType, c.id) end
			if object.comment ~= "" and object.comment ~= c.comment then table.insert(withDiffComment, c.id) end
			if object.enums ~= c.enums then table.insert(withDiffEnums, c.id) end
			if object.tagcache ~= c.tagcache then
				table.insert(withDiffTags, c.id)
			else
				-- compare tagcache with tags
				local tagcacheIndex = {}
				local tagcacheParts = {}
				if type(c.tagcache) == "table" then
					tagcacheParts = string.split(c.tagcache, " ")
				end

				for _,tag in ipairs(tagcacheParts) do
					tagcacheIndex[tag] = true;
				end

				for _,tag in ipairs(currentTags) do
					if not tagcacheIndex[tag] then
						table.insert(withDiffTags, c.id)
					end
				end
			end

			if backupObjectsIndex[c.id].object.updatetime ~= c.updatetime then
				table.insert(withDiffTime, c.id)
			end
		else
			table.insert(toDeleteObjects, c.id)
		end
	end

	for k,v in pairs(backupObjectsIndex) do
		if not v.currentObject then
			table.insert(newObjects, v.object.id)
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

	if policies.value == "useLater" then
		for k,id in ipairs(withDiffTime) do
			local v = getById(id).object;
			local c = getById(id).currentObject;
			if v.updatetime > c.updatetime then
				db:update('objects', { value = v.value, updatetime = v.updatetime }, { id = v.id })
			end
		end
	end

	if policies.type == "replace" then
		for k,id in ipairs(withDiffType) do
			local v = getById(id).object;
			db:update('objects', { type = v.type }, { id = v.id })
		end
	end

	if policies.comment == "replace" then
		for k,id in ipairs(withDiffComment) do
			local v = getById(id).object;
			db:update('objects', { comment = v.comment }, { id = v.id })
		end
	end

	if policies.enums == "replace" then
		for k,id in ipairs(withDiffEnums) do
			local v = getById(id).object;
			-- db:update('objects', { enums = escape(v.enums) }, { id = v.id })
			local query = "UPDATE objects SET enums = '" .. v.enums .. "' WHERE id = " .. tostring(v.id)
			local res = db:execute(query)
			log(res, query)
		end
	end

	if policies.tags == "replace" then
		for k,id in ipairs(withDiffTags) do
			local v = getById(id).object;
			local tags = getById(id).tags;
			local c = getById(id).currentObject;
			
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
			if type(currentTags) == "table" then
				for _,t in ipairs(currentTags) do
					currentTagsIndex[t.tag] = true
					tagcache = tagcache .. " " .. t.tag
				end
			end

			
			-- when in tagcache there are some tags which doesn't exists in tags
			local tagsToAdd = {}

			local currentTagcache = {}
			if c.tagcache then
				currentTagcache = string.split(c.tagcache, " ")
				for _,tag in ipairs(currentTagcache) do
					if tag and not currentTagsIndex[tag] then
						table.insert(tagsToAdd, { object = c.id, tag = tag })
						currentTagsIndex[tag] = true
					end
				end
			end

			-- remove duplicates
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
