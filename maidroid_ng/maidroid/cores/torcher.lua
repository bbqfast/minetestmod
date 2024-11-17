------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyright (c) 2020 IFRFSX.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator
local on_start, on_pause, on_stop, on_step, is_tool

local timers = maidroid.timers
local follow = maidroid.cores.follow.on_step
local wander = maidroid.cores.wander.on_step

maidroid.register_tool_rotation("default:torch", vector.new(15, 0, 0))

on_start = function(self)
	self.state = maidroid.states.IDLE
	self.timers.walk = 0
	self.timers.change_dir = 0
	self.timers.place_torch = 0
	self.is_placing = false
	self:halt()
	self:set_animation(maidroid.animation.STAND)
end

on_stop = function(self)
	self.state = nil
	self.timers.place_torch = nil
	self.is_placing = nil
	self:halt()
	self:set_animation(maidroid.animation.STAND)
end

on_pause = function(self)
	self:halt()
	self:set_animation(maidroid.animation.SIT)
end

local function is_dark(pos)
	local light_level = minetest.get_node_light(pos)
	return light_level <= 5
end

on_step = function(self, dtime, moveresult)
	-- When owner offline the maidroid does nothing.
	local player = minetest.get_player_by_name(self.owner)

	self:pickup_item()

	-- When owner offline just wander
	if not player then
		wander(self, dtime, moveresult)
		return
	end

	-- Save state and try to follow
	local laststate = self.state
	follow(self, dtime, moveresult, player)

	-- Can't follow just wander
	if self.state == maidroid.states.IDLE and self.far_from_owner then
		if laststate ~= self.state then
			minetest.chat_send_player(self.owner, S("One torcher is too far away"))
		end
		wander(self, dtime, moveresult)
		return
	end

	if self.timers.place_torch < timers.place_torch_max then
		self.timers.place_torch = self.timers.place_torch + dtime
	else
		self.timers.place_torch = 0
		if self.is_placing then
			if not self:get_inventory():contains_item("main", self.selected_tool) then
				self.need_core_selection = true
				return
			end
			if self.state == maidroid.states.IDLE then
				self:set_animation(maidroid.animation.STAND)
			else
				self:set_animation(maidroid.animation.WALK)
			end

			local pos = vector.round(self:get_pos())
			local stack = ItemStack(self.selected_tool)
			if not minetest.is_protected(pos, self.owner) then
				local _, success = minetest.item_place_node(stack, player, {
					type = "node",
					under = vector.add(pos, vector.new(0,-1,0)),
					above = pos,
				})
				if success then
					self:get_inventory():remove_item("main", stack)
				end
			end
			self.is_placing = false
		else
			if is_dark(vector.round(self:get_pos())) then -- if it is dark, set torch
				self.is_placing = true
				if self.state == maidroid.states.IDLE then
					self:set_animation(maidroid.animation.MINE)
				else
					self:set_animation(maidroid.animation.WALK_MINE)
				end
			end
		end
	end
end

is_tool = function(stack)
	local stackname = stack:get_name()
	if minetest.get_item_group(stackname, "torch") > 0 then
		return true
	end

	if stackname:sub(1,16) == "abritorch:torch_" then
		stackname = stackname:sub(17)
		for _, color in pairs(dye.dyes) do
			if stackname == color[1] then
				return true
			end
		end
	end
	return false
end

maidroid.cores.basic.doc = maidroid.cores.basic.doc .. "\t"
	.. S("Torcher: any torch") .. "\n"

-- register a definition of a new core.
maidroid.register_core("torcher", {
	description = S("a torcher"),
	on_start    = on_start,
	on_stop     = on_stop,
	on_resume   = on_start,
	on_pause    = on_pause,
	on_step     = on_step,
	is_tool     = is_tool,
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
