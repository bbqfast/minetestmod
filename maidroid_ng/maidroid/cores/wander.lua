------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2022 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

-- Core interface function
local on_step, on_pause, on_resume, on_start, on_stop

-- Core extra functions
local to_wander

local timers = maidroid.timers
local speed_min = maidroid.settings.speed / 2

local lf = maidroid.lf


on_start = function(self)
	to_wander(self, "on_start", 0, timers.change_dir_max )
	self.us_time = minetest.get_us_time()
	self:halt()
end

on_resume = function(self)
	to_wander(self, "on_resume", 0, timers.change_dir_max )
	self:halt()
end

on_stop = function(self)
	self.state = nil
	self.timers.walk = 0
	self.timers.change_dir = 0
	self:halt()
	self:set_animation(maidroid.animation.STAND)
end

on_pause = function(self)
	self.state = nil
	self:halt()
	self.timers.wander_skip = 0
	self:set_animation(maidroid.animation.SIT)
end


on_step = function(self, dtime, moveresult, task, criterion, check_inside)
	-- Walk time over do task or randomly happy jump
	if self.timers.walk >= self.core.walk_max then
		self.timers.walk = 0
		self.timers.wander_skip = 0
		self.timers.change_dir = self.timers.change_dir + dtime
		if task then
			task(self, dtime, moveresult)
		elseif (not (self.core and self.core.no_jump)) and math.random(8) == 1 and self:is_on_ground() then
			self.object:set_velocity(vector.add(self.object:get_velocity(),vector.new(0,math.random(20,32)/10,0)))
		end
	-- Time to change dir
	elseif self.timers.change_dir >= timers.change_dir_max then
		self.timers.walk = self.timers.walk + dtime
		self.timers.change_dir = 0
		self:change_direction()
	else -- Basic step
		self.timers.walk = self.timers.walk + dtime
		self.timers.change_dir = self.timers.change_dir + dtime
		self.timers.wander_skip = self.timers.wander_skip + dtime

		local velocity = self.object:get_velocity()
		if self.timers.wander_skip > 0.5 then
			if math.sqrt(velocity.x^2 + velocity.z^2) < speed_min
				or self:is_blocked(criterion, check_inside) then
				self:strong_change_direction()
				self.timers.change_dir = 0
			elseif (not (self.core and self.core.no_jump)) and math.random(5) == 1 and self:is_on_ground() then
				velocity.y = maidroid.jump_velocity
				self.object:set_velocity(velocity)
			end
			self.timers.wander_skip = 0
		end
	end
	-- TODO check for water or holes
end

to_wander = function(self, caller, walk, change_dir)
	lf("wander", "to_wander (" .. tostring(caller) .. "): walk=" .. tostring(walk) .. ", change_dir=" .. tostring(change_dir))
	self.state = maidroid.states.WANDER
	self.timers.walk = walk or 0
	self.timers.change_dir = change_dir or 0
	self.timers.wander_skip = 0
	self:change_direction()
	self:set_animation(maidroid.animation.WALK)
end

maidroid.register_core("wander", {
	on_start	= on_start,
	on_stop		= on_stop,
	on_resume	= on_resume,
	on_pause	= on_pause,
	on_step		= on_step,
	to_wander	= to_wander,
})
maidroid.new_state("WANDER")

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
