-- Calculate distance from maidroid to player
local S = maidroid.translator
local lf = maidroid.lf

maidroid.distance_from_player = function(self)
	local player = minetest.get_player_by_name(self.owner)
	if not player then
		return nil
	end
	
	local pos = self:get_pos()
	local player_pos = player:get_pos()
	
	if not pos or not player_pos then
		return nil
	end
	
	return vector.distance(pos, player_pos)
end

-- Safe file reading helper function
maidroid.safe_read_file = function(path)
	local ok, content = pcall(function()
		local f = io.open(path, "r")
		if not f then error("unable to open file for read") end
		local c = f:read("*a")
		f:close()
		return c
	end)
	return ok, content
end

-- called when the object is destroyed.
maidroid.get_staticdata = function(self, captured)
	-- Log who called get_staticdata and why
	local pos = self:get_pos()
	local dist = maidroid.distance_from_player and maidroid.distance_from_player(self) or "unknown"
	lf("get_staticdata", "CALLED - nametag: " .. tostring(self.nametag) .. ", pos: " .. (pos and minetest.pos_to_string(pos) or "nil") .. ", distance from player: " .. tostring(dist) .. ", captured: " .. tostring(captured))
	
	local data = {
		nametag = self.nametag,
		owner_name = self.owner,
		inventory = {},
		textures = self.textures[0],
		tbchannel = self.tbchannel
	}

	-- data.textures = luaentity.object:get_properties()["textures"][1]

	-- lf("api", "====================== get_staticdata1:"..dump(self))
    mydump("get_staticdata", "====================== get_staticdata1", self)
	-- lf("api", "====================== get_staticdata2:"..dump(data))
    mydump("get_staticdata", "====================== get_staticdata2", data)
	-- lf("api", "====================== get_staticdata3:"..dump(self:get_properties()))
	-- check if object is destroyed, then return nil
	if not self.object or not self.object:get_pos() then
        lf("get_staticdata", "object is destroyed, name=" .. self.nametag)
		return nil
	end

	local eeee = self.object:get_properties()
	-- lf("api", "====================== get_staticdata3:"..dump(eeee))
    mydump("get_staticdata", "====================== get_staticdata3", eeee)
	-- to work aroudn texture loss problem save texture from object properties
	data["textures"] = eeee["textures"][1]

	-- if self:get_properties ~= nil then 
    -- mydump("get_staticdata", "====================== get_staticdata3", self:get_properties())
	-- end


	-- save inventory
	local inventory = self:get_inventory()
	for list_name, list in pairs(inventory:get_lists()) do
		local tmplist = {}
		for idx, item in ipairs(list) do
			tmplist[idx] = item:to_string()
		end
		data.inventory[list_name] = tmplist
	end

	if not captured then
		data.home = self.home
		-- Save activation position for generic_cooker core to retain last spawned position
		if self._activation_pos then
			data.activation_pos = self._activation_pos
		end
	end


	local id_str = "N/A"
	do
		if self.object then
			-- try to call get_id() if available, otherwise fallback to tostring(self.object)
			if self.object.get_id then
				local ok, id = pcall(function() return self.object:get_id() end)
				if ok and id then
					id_str = tostring(id)
				else
					id_str = tostring(self.object)
				end
			else
				id_str = tostring(self.object)
			end
		end
		lf("api", "====================== get_staticdata3 : " .. tostring(self.nametag)
			.. "  entity_id=" .. id_str)
	end
	
	-- write data dump to disk named by id_str and print the file location
	-- local ok, ser = pcall(function() return minetest.serialize(data) end)
	local ok, ser = pcall(function() return dump(data) end)
	if not ok then
        log("Inner pcall caught:", msg)
    end
	local dumptext = ok and ser or tostring(data)
	-- lf("api", "maidroid staticdata dump: " .. dumptext)

	local worldpath = minetest.get_worldpath() or "."

	-- Prefer nametag for filenames when available, otherwise fall back to id_str.
	local id_source
	if self.nametag and self.nametag ~= "" then
		id_source = self.nametag
	else
		id_source = id_str
		return nil
	end
	

	local ok, safe_id = pcall(function()
		local s = tostring(id_source or "")
		if s == "" then s = tostring(id_str or "unknown") end
		return s:gsub("[^%w%._%-]", "_")
	end)
	if not ok then
		lf("api", "maidroid: failed to sanitize id_str: " .. tostring(safe_id))
		-- local fallback = tostring(id_str or "")
		-- safe_id = fallback:gsub("[^%w%._%-]", "_")
	end
	local filename = "maidroid_staticdata_" .. safe_id .. ".txt"
	local filepath = worldpath .. "/" .. filename

	local file, ferr = io.open(filepath, "w")
	if file then
		file:write(dumptext)
		file:close()
		lf("api", "Saved maidroid staticdata to: " .. filepath)
	else
		lf("api", "Failed saving maidroid staticdata to: " .. filepath .. " error: " .. tostring(ferr))
	end



	-- Replace the selected block in get_staticdata with this single call:
	local ok_read, readtext = maidroid.safe_read_file(filepath)

	if ok_read and readtext then
		if readtext == dumptext then
			lf("api", "maidroid: staticdata verification OK: " .. filename)
		else
			lf("api", "maidroid: staticdata verification FAILED (content mismatch): " .. filename)
			-- log small prefixes to avoid overly large logs
			lf("api", "expected prefix: " .. tostring(dumptext):sub(1,200))
			lf("api", "read     prefix: " .. tostring(readtext):sub(1,200))
		end
	else
		lf("api", "maidroid: staticdata verification error reading file: " .. tostring(readtext))
	end

	return minetest.serialize(data)
end

-- Chat command to restore a maidroid from a staticdata dump file in the world folder.
-- Usage: /maidroid_load Eve_623
-- This will look for: <worldpath>/maidroid_staticdata_Eve_623.txt
local cmd_maidroid_load = {
	params = "<id>",
	description = S("Load a maidroid from maidroid_staticdata_<id>.txt in this world"),
	privs = { maidroid = true },
	func = function(name, param)
		param = (param or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if param == "" then
			return false, "Usage: /maidroid_load <id> (e.g. Eve_623)"
		end

		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found"
		end

		local worldpath = minetest.get_worldpath() or "."
		local filename = "maidroid_staticdata_" .. param .. ".txt"
		local filepath = worldpath .. "/" .. filename

		local ok_read, content = maidroid.safe_read_file(filepath)
		if not ok_read or not content or content == "" then
			return false, "Failed to read staticdata file: " .. filename
		end

		-- The dump file contains a Lua-like table (output of dump(data)).
		-- Safely evaluate it to reconstruct the data table.
		local ok_parse, data = pcall(function()
			local chunk, err = loadstring("return " .. content)
			if not chunk then
				error(err or "invalid staticdata dump")
			end
			return chunk()
		end)
		if not ok_parse or type(data) ~= "table" then
			return false, "Failed to parse staticdata in file: " .. filename
		end

		-- Spawn the maidroid near the player and initialize it using the existing on_activate logic.
		local pos = vector.add(player:get_pos(), { x = 0, y = 0.5, z = 0 })
		local obj = minetest.add_entity(pos, "maidroid:maidroid")
		if not obj then
			return false, "Failed to spawn maidroid entity"
		end

		local lua = obj:get_luaentity()
		if lua and lua.on_activate then
			lua:on_activate(minetest.serialize(data))
		end

		return true, "Maidroid loaded from " .. filename
	end,
}

minetest.register_chatcommand("maidroid_load", cmd_maidroid_load)
minetest.register_chatcommand("mr_load", cmd_maidroid_load)

-- Initialize cores table if not already initialized
maidroid.cores = maidroid.cores or {}

-- maidroid.register_core registers a definition of a new core.
function maidroid.register_core(name, def)
	def.name = name
	if not def.walk_max then
		def.walk_max = maidroid.timers.walk_max
	end

	-- Register a hat entity
	if def.hat then
		local hat_name = "maidroid:" .. def.hat.name
		def.hat.name = hat_name

		if minetest.get_current_modname() ~= "maidroid" then
			hat_name = ":" .. hat_name
		end
		minetest.register_entity(hat_name, {
			visual = "mesh",
			mesh = def.hat.mesh,
			textures = def.hat.textures,

			physical = false,
			pointable = false,
			static_save = false,

			on_detach = function(self)
				lf("api", "wield_item on_detach called - removing wield_item object")
				self.object:remove()
			end
		})
	end
	maidroid.cores[name] = def
end
