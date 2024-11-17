------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local on_step, to_follow_path

local timers = maidroid.timers
local wander_core = maidroid.cores.wander

local is_near = function(self, pos, distance)
	local p = self:get_pos()
	return vector.distance(p, pos) < distance
end

on_step = function(self, dtime, moveresult)
	if is_near(self, self.destination, 1.5) then
		self.finalize(self, dtime, moveresult)
		return
	end

	if self.timers.walk >= timers.walk_max then -- time over.
		wander_core.to_wander(self)
		return true
	end

	self.timers.find_path = self.timers.find_path + dtime
	self.timers.walk = self.timers.walk + dtime

	if self.timers.find_path >= timers.find_path_max then
		self.timers.find_path = 0
		local path = minetest.find_path(self:get_pos(), self.destination, 10, 1, 1, "A*")
		if path == nil then
			wander_core.to_wander(self)
			return
		end
		self.path = path
	end

	-- follow path
	if is_near(self, self.path[1], 0.5) then
		table.remove(self.path, 1)

		if #self.path == 0 then -- end of path
			self.finalize(self, dtime, moveresult)
		else -- else next step, follow next path.
			self:set_target_node(self.path[1])
		end
	end
end

to_follow_path = function(self, path, destination, finalize, action)
	self.state = maidroid.states.PATH
	self.path = path
	self.destination = destination
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
