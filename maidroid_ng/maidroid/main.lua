-- Calculate distance from maidroid to player
local S = maidroid.translator
local lf = maidroid.lf

-- Initialize states table and function to register new states
maidroid.states = {}
maidroid.states_count = 0
maidroid.new_state = function(string)
	if not maidroid.states[string] then
		maidroid.states_count = maidroid.states_count + 1
		maidroid.states[string] = maidroid.states_count
	end
end

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
-- ,,stat
maidroid.get_staticdata = function(self, captured)
	-- Log who called get_staticdata and why
	local pos = self:get_pos()
	local dist = maidroid.distance_from_player and maidroid.distance_from_player(self) or "unknown"
	lf("get_staticdata", "1 CALLED - nametag: " .. tostring(self.nametag) .. ", pos: " .. (pos and minetest.pos_to_string(pos) or "nil") .. ", distance from player: " .. tostring(dist) .. ", captured: " .. tostring(captured))
	
	local data = {
		nametag = self.nametag,
		owner_name = self.owner,
		inventory = {},
		textures = self.textures[0],
		tbchannel = self.tbchannel
	}

	-- data.textures = luaentity.object:get_properties()["textures"][1]

	-- lf("api", "====================== get_staticdata1:"..dump(self))
    mydump("get_staticdata", "2===================== get_staticdata1", self)
	-- lf("api", "====================== get_staticdata2:"..dump(data))
    mydump("get_staticdata", "3===================== get_staticdata2", data)
	-- lf("api", "====================== get_staticdata3:"..dump(self:get_properties()))
	-- check if object is destroyed, then return nil
	if not self.object or not self.object:get_pos() then
        lf("get_staticdata", "object is destroyed, name=" .. self.nametag)
		return nil
	end

	local eeee = self.object:get_properties()
	-- lf("api", "====================== get_staticdata3:"..dump(eeee))
    mydump("get_staticdata", "4===================== get_staticdata3", eeee)
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

	-- dump final data with inventory included
    mydump("get_staticdata", "5====================== get_staticdata_final_with_inventory", data)

	if not captured then
		data.home = self.home
		-- Save activation position for generic_cooker core to retain last spawned position
		if self._activation_pos then
			data.activation_pos = self._activation_pos
		end
		-- Save farming dimension mode
		if self.farming_dim_mode then
			data.farming_dim_mode = self.farming_dim_mode
		end
		-- Save low fence mode
		if self._use_low_fence ~= nil then
			data._use_low_fence = self._use_low_fence
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


-- crossed_boundary checks if maidroid crossed width or length boundaries from activation position
-- Takes width and length parameters and returns true if maidroid crossed either boundary
-- Checks boundaries relative to self._activation_pos (center point)
function maidroid.crossed_boundary(self, width, length)
	local pos = self:get_pos()
	
	if not pos then
		lf("api", "crossed_boundary: maidroid position is nil")
		return false
	end
	
	if not self._activation_pos then
		lf("api", "crossed_boundary: activation position is nil")
		return false
	end
	
	-- Calculate offset from activation position
	local offset = vector.subtract(pos, self._activation_pos)
	
	-- Calculate half dimensions (boundaries extend from -half to +half in each direction)
	local half_width = width / 2
	local half_length = length / 2
	
	-- Check if offset is outside the rectangular boundary
	local crossed_width = offset.x < -half_width or offset.x > half_width
	local crossed_length = offset.z < -half_length or offset.z > half_length
	
	-- Return true if either boundary was crossed
	if crossed_width or crossed_length then
		lf("api", string.format("Boundary crossed: pos=%s, activation_pos=%s, width=%d, length=%d, crossed_width=%s, crossed_length=%s", 
			minetest.pos_to_string(pos), minetest.pos_to_string(self._activation_pos), width, length, tostring(crossed_width), tostring(crossed_length)))
		return true
	end
	
	return false
end

-- check_activation_position_and_boundary checks if maidroid is too far from activation position
-- or has crossed the farm boundary, and teleports back if needed
function maidroid.check_activation_position_and_boundary(self)
	if self._activation_pos then
		local current_pos = self:get_pos()
		local distance = vector.distance(current_pos, self._activation_pos)
		local max_distance = maidroid.get_max_distance_from_activation()
        
        -- if not self._is_bounded then
        local dim_mode = maidroid.get_farming_dim_mode(self)
        if dim_mode == "none" then
            return
        end


		if dim_mode == "radius" and distance > max_distance then
			lf("farming", "Too far from activation (" .. string.format("%.1f", distance) .. " > " .. max_distance .. "), teleporting back")
			self.object:set_pos(self._activation_pos)
            return
		end
		
		-- Check boundary based on dimension mode
		
		if dim_mode == "rectangle" then
			-- Check if maidroid crossed boundary using custom farm dimensions
			local farm_length = self.farming_length or 5
			local farm_width = self.farming_width or 5
			if maidroid.crossed_boundary(self, farm_width, farm_length) then
				lf("farming", "Crossed " .. farm_width .. "x" .. farm_length .. " rectangle boundary, teleporting back to activation position")
				self.object:set_pos(self._activation_pos)
			end
		-- else -- default to "radius"
		-- 	-- Check if maidroid crossed radius boundary
		-- 	local farm_radius = self.farming_radius or 5
		-- 	if distance > farm_radius then
		-- 		lf("farming", "Crossed radius " .. farm_radius .. " boundary, teleporting back to activation position")
		-- 		self.object:set_pos(self._activation_pos)
		-- 	end
		end
	end
end

-- Function to set farming dimensions
function maidroid.set_farming_dimensions(droid, length, width)
	if not droid then
		lf("farming", "set_farming_dimensions: droid is nil")
		return false
	end

    lf("DEBUG farming:set_farming_dimensions", "set_farming_dimensions: droid is not nil")
	
	-- Validate and set length
	if length and length > 0 and length <= 50 then
		droid.farming_length = length
		lf("farming", "Farming length set to: " .. length)
	else
		lf("farming", "Invalid length: " .. tostring(length) .. ". Please enter a number between 1 and 50.")
		return false
	end
	
	-- Validate and set width
	if width and width > 0 and width <= 50 then
		droid.farming_width = width
		lf("farming", "Farming width set to: " .. width)
	else
		lf("farming", "Invalid width: " .. tostring(width) .. ". Please enter a number between 1 and 50.")
		return false
	end
	
	lf("farming", "Farming dimension set to " .. length .. "x" .. width)
	return true
end

-- Function to set farming dimension mode (radius or rectangle) for specific droid
function maidroid.set_farming_dim_mode(droid, mode)
	-- Check for invalid mode first
	if not mode or (mode ~= "radius" and mode ~= "rectangle") then
		local error_msg = "Invalid farming dimension mode: " .. tostring(mode) .. ". Use 'radius' or 'rectangle'"
		lf("DEBUG set_farming_dim_mode", error_msg)
		error(error_msg)
		return -- Exit after error
	end
	
	-- Valid mode - proceed with setting
	droid.farming_dim_mode = mode
	lf("DEBUG set_farming_dim_mode", "Farming dimension mode set to: " .. mode .. " for droid at " .. minetest.pos_to_string(droid:get_pos()))
	return true
end

-- Function to get farming dimension mode for specific droid
function maidroid.get_farming_dim_mode(droid)
    lf("DEBUG get_farming_dim_mode", "Farming dimension mode: " .. (droid.farming_dim_mode or "radius"))
	return droid.farming_dim_mode or "radius"
end


