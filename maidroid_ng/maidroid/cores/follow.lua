------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local lf = function(func, msg)
	local pre = "++++++++++++++++++++++++++++++++++++++++++++++++++"
	if func == nil then func = "unknown" end
	if msg == nil then msg = "null" end

	local black_list = {}
	black_list["select_seed"] = true
	black_list["mow"] = true

	if black_list[func] == nil then
		minetest.log("warning", pre .. func .. "(): " .. msg .. " | lottfarming_on=" .. tostring(lottfarming_on))
	end
end

local on_step

on_step = function(self, _, moveresult, player)
	local func_name = "follow:on_step"
	local position = self:get_pos()
	local player_position = player:get_pos()
	local distance = vector.distance(player_position, position)
	-- lf(func_name, "distance to player: " .. tostring(distance))

	-- If extremely far, teleport to player
	if distance > 50 then
		lf(func_name, "teleporting to player due to extreme distance")
		self.object:set_pos(player_position)
		self:set_animation(maidroid.animation.STAND)
		self.state = maidroid.states.IDLE
		self.far_from_owner = false
		return
	end

	-- if distance > 12 then
	-- 	lf(func_name, "too far from player, switching to IDLE")
	-- 	if self.state == maidroid.states.FOLLOW then
	-- 		self:set_animation(maidroid.animation.STAND)
	-- 		self.state = maidroid.states.IDLE
	-- 		self.far_from_owner = true
	-- 	end
	-- 	return
	-- end

	local direction = vector.direction(position, player_position)
	local velocity = self.object:get_velocity()

	self:set_yaw(direction)
	local is_torcher = false
	if self.core then
		-- lf(func_name, "core: " .. tostring(self.core.name))
		if self.core.name == "torcher" then
			is_torcher = true
		end
	end

	if not is_torcher then
		if distance < 3 or (
			math.abs(player_position.x - position.x) +
			math.abs(player_position.z - position.z) ) < 3 then
			lf(func_name, "close to player, switching to IDLE")
			if self.state == maidroid.states.FOLLOW then
				self:set_animation(maidroid.animation.STAND)
				self.state = maidroid.states.IDLE
				self:halt()
				self.far_from_owner = false
			end
			return
		end
	end

	if self.state == maidroid.states.IDLE then
		lf(func_name, "starting to FOLLOW")
		self:set_animation(maidroid.animation.WALK)
		self.state = maidroid.states.FOLLOW
	end

	-- Follow player on Y axis too
	local dy = player_position.y - position.y
	local y

	if math.abs(dy) < 0.5 then
		y = velocity.y
	else
		local max_v = maidroid.jump_velocity or 6
		y = math.max(math.min(dy * 2, max_v), -max_v)
	end

	higher_speed = 8
	-- direction = vector.multiply(direction, math.random(10) / 10 + 2.5)
	direction = vector.multiply(direction, math.random(10) / 10 + higher_speed)
	direction.y = y
	-- lf(func_name, "setting velocity to: " .. minetest.pos_to_string(direction))
	self.object:set_velocity(direction)
end

-- register a definition of a new core.
maidroid.register_core("follow", {
	on_step = on_step,
})
maidroid.new_state("IDLE")
maidroid.new_state("FOLLOW")

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
