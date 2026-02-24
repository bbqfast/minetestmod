------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

-- Register special debug node for path marking
minetest.register_node("maidroid:path_marker", {
	description = "Maidroid Path Marker (Debug)",
	tiles = {
		"maidroid_path_marker_top.png",
		"maidroid_path_marker_bottom.png", 
		"maidroid_path_marker_side.png",
		"maidroid_path_marker_side.png",
		"maidroid_path_marker_side.png",
		"maidroid_path_marker_side.png",
	},
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.3, -0.3, -0.3, 0.3, 0.3, 0.3}, -- Small cube in center
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.3, -0.3, -0.3, 0.3, 0.3, 0.3},
		},
	},
	light_source = 5, -- Emits some light
	walkable = false, -- Non-blocking
	pointable = true,  -- Can be pointed at for deletion
	diggable = true,  -- Can be manually dug/deleted
	groups = {oddly_breakable_by_hand = 3, dig_immediate = 3},
	drop = "", -- Doesn't drop anything when dug
})

-- Register special debug node for destination marking
minetest.register_node("maidroid:destination_marker", {
	description = "Maidroid Destination Marker (Debug)",
	tiles = {
		"maidroid_destination_marker_top.png",
		"maidroid_destination_marker_bottom.png", 
		"maidroid_destination_marker_side.png",
		"maidroid_destination_marker_side.png",
		"maidroid_destination_marker_side.png",
		"maidroid_destination_marker_side.png",
	},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "color",
	palette = "unifieddyes_palette_extended.png",
	color = "#ffff00", -- Yellow color by default
	node_box = {
		type = "fixed",
		fixed = {
			{-0.4, -0.4, -0.4, 0.4, -0.3, 0.4}, -- Base plate (red)
			{-0.1, -0.3, -0.1, 0.1, 0.5, 0.1}, -- Center pole (yellow)
			{-0.3, 0.4, -0.3, 0.3, 0.6, 0.3}, -- Top cap (red)
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.4, -0.4, -0.4, 0.4, 0.6, 0.4},
		},
	},
	light_source = 8, -- Emits more light than path marker
	walkable = false, -- Non-blocking
	pointable = true,  -- Can be pointed at for deletion
	diggable = true,  -- Can be manually dug/deleted
	groups = {oddly_breakable_by_hand = 3, dig_immediate = 3, ud_param2_color = 1},
	drop = "", -- Doesn't drop anything when dug
})

local on_step, to_follow_path

local timers = maidroid.timers
local wander_core = maidroid.cores.wander
local lf = maidroid.lf

local is_near = function(self, pos, distance)
	local p = self:get_pos()
	return vector.distance(p, pos) < distance
end

local function pos_xyz(p)
	if not p then return "(nil)" end
	return string.format("(%s, %s, %s)", tostring(p.x), tostring(p.y), tostring(p.z))
end

local function path_to_str(path)
	local path_parts = {}
	for i, p in ipairs(path or {}) do
		path_parts[i] = pos_xyz(p)
	end
	return "[" .. table.concat(path_parts, ", ") .. "]"
end

local function path_nodes_to_str(path)
	local parts = {}
	for i, p in ipairs(path or {}) do
		local node_name = "(nil)"
		if p then
			local below = { x = p.x, y = p.y - 1, z = p.z }
			local node = minetest.get_node(below)
			if node and node.name then
				node_name = node.name
			end
		end
		parts[i] = tostring(node_name)
	end
	return "[" .. table.concat(parts, ", ") .. "]"
end

local function place_path_markers(self, path)
	self.temp_node_name = "maidroid:path_marker"
	self.temp_node_positions = {}
	-- Place temporary debug marker nodes along the path
	for i, pos in ipairs(path) do
		-- Check what's at the path position
		local path_node = minetest.get_node(pos)
		local place_pos
		
		-- If path is on walkable nodes (plants, grass, etc.), place marker above
		if path_node.name ~= "air" then
			place_pos = { x = pos.x, y = pos.y + 1, z = pos.z }
		else
			-- If path is in air, place at path level
			place_pos = { x = pos.x, y = pos.y, z = pos.z }
		end
		
		local current_node = minetest.get_node(place_pos)
		-- Only place if the position is not protected and current node is air
		if current_node.name == "air" and not minetest.is_protected(place_pos, self.owner) then
			minetest.set_node(place_pos, { name = "maidroid:path_marker" })
			table.insert(self.temp_node_positions, place_pos)
			-- lf("path", "Placed temporary path marker at " .. minetest.pos_to_string(place_pos) .. " (path node: " .. path_node.name .. ")")
			
			-- Set up guaranteed removal timer for each node
			minetest.after(2, function()
				local node = minetest.get_node(place_pos)
				if node.name == "maidroid:path_marker" then
					minetest.set_node(place_pos, { name = "air" })
					-- lf("path", "Timer-removed temporary path marker at " .. minetest.pos_to_string(place_pos))
				end
			end)
		end
	end
end

-- Function to place destination marker
-- ,,mark
local function place_destination_marker(destination)
	if not destination then return end
	
	-- Check what's at the destination position
	local dest_node = minetest.get_node(destination)
	local place_pos
	
	-- If destination is on walkable nodes, place marker above
	if dest_node.name ~= "air" then
		place_pos = { x = destination.x, y = destination.y + 1, z = destination.z }
	else
		-- If destination is in air, place at destination level
		place_pos = { x = destination.x, y = destination.y, z = destination.z }
	end
	
	local current_node = minetest.get_node(place_pos)
	-- Only place if current node is air
	if current_node.name == "air" then
		-- Place marker with yellow color (param2 value for yellow in unifieddyes)
		minetest.set_node(place_pos, { name = "maidroid:destination_marker", param2 = 240 })
		-- lf("path", "Placed destination marker at " .. minetest.pos_to_string(place_pos))
		
		-- Set up guaranteed removal timer for destination marker (10 seconds)
		minetest.after(1, function()
			local node = minetest.get_node(place_pos)
			if node.name == "maidroid:destination_marker" then
				minetest.set_node(place_pos, { name = "air" })
				-- lf("path", "Timer-removed destination marker at " .. minetest.pos_to_string(place_pos))
			end
		end)
	end
end

on_step = function(self, dtime, moveresult)
	if is_near(self, self.destination, 1.5) then
		lf("path", "Reached destination (near); finishing path at " .. minetest.pos_to_string(self.destination))
		self.finalize(self, dtime, moveresult)
		return
	end
	
	-- Respect per-core path_max when timing out path following.
	local core_path_max = (self.core and self.core.path_max) or timers.path_max
	if self.timers.walk >= core_path_max then -- time over.
		wander_core.to_wander(
			self,
			"path:on_step_TIMEOUT, walk=" .. tostring(self.timers.walk) .. "/" .. tostring(core_path_max),
			self.timers.walk,
			self.timers.change_dir
		)
		return true
	end

	self.timers.find_path = self.timers.find_path + dtime
	self.timers.walk = self.timers.walk + dtime

	if self.timers.find_path >= timers.find_path_max then
		self.timers.find_path = 0
		local path = minetest.find_path(self:get_pos(), self.destination, 10, 1, 1, "A*")
		if path == nil then
			wander_core.to_wander(self, "path:on_step_find_path_failed")
			return
		end
		self.path = path
	end

	-- follow path
	if is_near(self, self.path[1], 0.5) then
		table.remove(self.path, 1)

		if #self.path == 0 then -- end of path
			lf("path", "Path list empty; finishing path at " .. minetest.pos_to_string(self.destination))
			self.finalize(self, dtime, moveresult)
		else -- else next step, follow next path.
			self:set_target_node(self.path[1])
		end
	end
end

-- ,,follow
to_follow_path = function(self, path, destination, finalize, action)
	local start_pos = self:get_pos()
	lf("path", "start=" .. pos_xyz(start_pos) .. " path=" .. path_to_str(path) .. " destination=" .. pos_xyz(destination))
	local destination_node_name = "(nil)"
	if destination then
		local below = { x = destination.x, y = destination.y - 1, z = destination.z }
		local node = minetest.get_node(below)
		if node and node.name then
			destination_node_name = node.name
		end
	end
	lf("path", "start=" .. pos_xyz(start_pos) .. " path_nodes=" .. path_nodes_to_str(path) .. " destination=" .. pos_xyz(destination) .. " destination_node=" .. tostring(destination_node_name))
    
	-- Place path markers
	place_path_markers(self, path)
	
	-- Place destination marker
	place_destination_marker(destination)
    
	self.state = maidroid.states.PATH
	self.path = path
	self.destination = destination
	self.path_start_pos = self:get_pos() -- Store starting position
	self.timers.find_path = 0 -- find path counter
	self.timers.walk = 0 -- walk counter
	self.finalize = finalize
	self.action = action
	self:set_target_node(path[1])
	self:set_animation(maidroid.animation.WALK)
end

-- register a definition of a new core.
maidroid.register_core("path", {
	on_step = on_step,
	to_follow_path = to_follow_path,
	place_destination_marker = place_destination_marker,
})
maidroid.new_state("PATH")

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
