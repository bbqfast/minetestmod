------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

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

on_step = function(self, dtime, moveresult)
	if is_near(self, self.destination, 1.5) then
		lf("path", "Reached destination (near); finishing path at " .. minetest.pos_to_string(self.destination))
		self.finalize(self, dtime, moveresult)
		return
	end
	
	-- Respect per-core walk_max when timing out path following.
	local core_walk_max = (self.core and self.core.walk_max) or timers.walk_max
	if self.timers.walk >= core_walk_max then -- time over.
		wander_core.to_wander(
			self,
			"path:on_step_TIMEOUT, walk=" .. tostring(self.timers.walk) .. "/" .. tostring(core_walk_max),
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
})
maidroid.new_state("PATH")

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
