------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local on_step

on_step = function(self, _, moveresult, player)
	local position = self:get_pos()
	local player_position = player:get_pos()
	local distance = vector.distance(player_position, position)

	if distance > 12 then
		if self.state == maidroid.states.FOLLOW then
			self:set_animation(maidroid.animation.STAND)
			self.state = maidroid.states.IDLE
			self.far_from_owner = true
		end
		return
	end

	local direction = vector.direction(position, player_position)
	local velocity = self.object:get_velocity()

	self:set_yaw(direction)
	if distance < 3 or (
		math.abs(player_position.x - position.x) +
		math.abs(player_position.z - position.z) ) < 3 then
		if self.state == maidroid.states.FOLLOW then
			self:set_animation(maidroid.animation.STAND)
			self.state = maidroid.states.IDLE
			self:halt()
			self.far_from_owner = false
		end
		return
	end

	if self.state == maidroid.states.IDLE then
		self:set_animation(maidroid.animation.WALK)
		self.state = maidroid.states.FOLLOW
	end

	-- Mimic player jumps
	local y = player:get_velocity().y
	if self:is_on_ground(moveresult) and y > 0.02
		and player_position.y > position.y then
		y = math.min(y * 0.75, maidroid.jump_velocity)
	else -- Just keep old velocity
		y = velocity.y
	end

	-- Scale velocity
	direction   = vector.multiply(direction, math.random(10) / 10 + 2.5)
	direction.y = y
	self.object:set_velocity(direction)
end

-- register a definition of a new core.
maidroid.register_core("follow", {
	on_step = on_step,
})
maidroid.new_state("IDLE")
maidroid.new_state("FOLLOW")

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
