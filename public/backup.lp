<?
require('apps')
require('json')
_SCRIPTNAME = 'LM Sync'
requestMethod = ngx.var.request_method

function getSafelyTable(t)
	if t and type(t) == "table" then
		return t
	end
	return {}
end

function addToIndex(values, index)
	values = getSafelyTable(values)
	for k,v in ipairs(values) do
		index[v] = values
	end
end

function getIndexKeys(index)
	index = getSafelyTable(index)
	local keys = {}
	for k,v in pairs(index) do
		table.insert(keys, k)
	end
	return keys
end

function filterEmptyStrings(values)
	values = getSafelyTable(values)
	local filtered = {}
	for k,v in ipairs(values) do
		if not v or v == "" then table.insert(filtered, v) end
	end
	return filtered
end

function getKeyValues(index, key)
	index = getSafelyTable(index)
	local values = {}
	for k,v in ipairs(index) do
		table.insert(values, v[key])
	end
	return values
end

function getAddr(id)
  return knxlib.decodega(id);
end

function syncObjectTags(objectGA, backupTags, mode)
	if mode == "omit" then return; end

	local tags = grp.gettags(objectGA)

	local resultTagsIndex = {}
	if mode == "concat" then
		addToIndex(tags, resultTagsIndex)
		addToIndex(backupTags, resultTagsIndex)
	elseif mode == "replace" then
		addToIndex(backupTags, resultTagsIndex)
	end

	local resultTags = getIndexKeys(resultTagsIndex)
	grp.settags(objectGA, filterEmptyStrings(resultTags))
end

queries = {
	getAllObjects = function()
		return db:getall('SELECT * FROM objects') or {}
	end,

	getAllTags = function()
		return db:getall('SELECT * FROM objecttags') or {}
	end,
}

function handleGET()
	local backup = {
		objects = queries.getAllObjects(),
		tags = queries.getAllTags(),
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

	if type(backup.objects) ~= "table" then
		return print("There is no objects!")
	end

	-- Correct to support old backup version
	if type(backup.objectTags) == "table" then
		backup.tags = backup.objectTags
	end

	local policies = {
		newObject = getvar("newObject") or "create",
		notExisting = getvar("notExisting") or "let",
		name = getvar("name") or "replace",
		value = getvar("value") or "useLater",
		comment = getvar("comment") or "replace",
		enums = getvar("enums") or "replace",
		datatype = getvar("datatype") or "replace",
		visparams = getvar("visparams") or "replace",
		tags = getvar("tags") or "concat"
	}

	if type(backup.tags) ~= "table" then
		if policies.tags ~= "omit" then
			-- There are no tags so the result would be a crash 
			return print("There is no tags!")
  		else
			-- There will be no manipulation on tags so it can be empty table
			backup.tags = {}
		end
	end

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
	local withDiffDatatype = {}
	local withDiffVisparams = {}
	local withDiffComment = {}
	local withDiffEnums = {}
	
	-- parse and solve conflicts
	local currentObjects = queries.getAllObjects()
	local currentObjectTags = queries.getAllTags()

	for k,t in ipairs(currentObjectTags) do
		local obj = getById(t.object)
		if obj then
			if not obj.currentTags then
				obj.currentTags = {}
			end
			table.insert(obj.currentTags, t)
		end
	end

	for k,c in ipairs(currentObjects) do
		if backupObjectsIndex[c.id] then
			backupObjectsIndex[c.id].currentObject = c
			local obj = getById(c.id)
			local object = obj.object
			local currentTags = obj.currentTags or {}

			if object.name ~= "" and object.name ~= c.name then table.insert(withDiffName, c.id) end
			if object.datatype ~= c.datatype then table.insert(withDiffDatatype, c.id) end
			if object.visparams ~= c.visparams then table.insert(withDiffVisparams, c.id) end
			if object.comment ~= "" and object.comment ~= c.comment then table.insert(withDiffComment, c.id) end
			if object.enums ~= c.enums then table.insert(withDiffEnums, c.id) end
			
			-- Always rewrite tags when replace or concat
			if policies.tags ~= "omit" then table.insert(withDiffTags, c.id) end

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

	if policies.notExisting == "delete" then
		for k,id in ipairs(toDeleteObjects) do
			db:delete("objects", { id = id })
			db:delete("objecttags", { object = id })
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

	if policies.datatype == "replace" then
		for k,id in ipairs(withDiffDatatype) do
			local v = getById(id).object;
			db:update('objects', { datatype = v.datatype }, { id = v.id })
		end
	end

	if policies.visparams == "replace" then
		for k,id in ipairs(withDiffVisparams) do
			local v = getById(id).object;
			db:update('objects', { visparams = v.visparams }, { id = v.id })
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
			db:update('objects', { enums = v.enums }, { id = v.id })
		end
	end

	if policies.tags == "replace" then
		for k,id in ipairs(withDiffTags) do
			local tags = getById(id).tags;
			local c = getById(id).currentObject;
			grp.settags(getAddr(c.address), getKeyValues(tags, "tag"))
		end
	elseif policies.tags == "concat" then
		for k,id in ipairs(withDiffTags) do
			local c = getById(id).currentObject;
			local tags = getById(id).tags;
			local currentTags = getById(id).currentTags;
			syncObjectTags(getAddr(c.address), getKeyValues(tags, "tag"), getKeyValues(currentTags, "tag"), "concat")
		end
	end

	-- actions according to the defined policies
	if policies.newObject == "create" then
		local toInsert = {}
		for k,id in ipairs(newObjects) do
			local obj = getById(id).object
			if obj then
				db:insert('objects', obj)
				grp.settags(getAddr(obj.address), getKeyValues(obj.tags, "tag"))
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
