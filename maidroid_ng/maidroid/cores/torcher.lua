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


local lf = function(func, msg)
	local pre = "++++++++++++++++++++++++++++++++++++++++++++++++++"
	if func == nil then func = "unknown" end
	if msg == nil then msg = "null" end

	local black_list = {}
	black_list["select_seed"] = true
	black_list["mow"] = true

	if black_list[func] == nil then
		minetest.log("warning", pre .. func .. "(): " .. msg )
	end
end

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

    self.object:set_properties({
        physical = true,
        collide_with_objects = true,
    })	
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
	local func_name = "tourcher:on_step"
	local player = minetest.get_player_by_name(self.owner)
	self:pickup_item()

	self.object:set_properties({
		physical = false,
		collide_with_objects = false,
	})	

	if not player then
		lf(func_name, "owner offline, wandering")
		wander(self, dtime, moveresult)
		return
	end

	local laststate = self.state
	follow(self, dtime, moveresult, player)

	if self.state == maidroid.states.IDLE and self.far_from_owner then
		lf(func_name, "too far from owner, state=" .. tostring(self.state))
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
			lf(func_name, "attempting to place torch")
			if not self:get_inventory():contains_item("main", self.selected_tool) then
				lf(func_name, "no torch tool in inventory, need core selection")
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
			local placed = false
			local torch_found = false
			for dy = -2, 2 do
				for dx = -2, 2 do
					for dz = -2, 2 do
						local check_pos = vector.add(pos, {x = dx, y = dy, z = dz})
						local node = minetest.get_node(check_pos)
						if minetest.get_item_group(node.name, "torch") > 0 then
							torch_found = true
							lf(func_name, "existing torch found at " .. minetest.pos_to_string(check_pos))
							break
						end
					end
					if torch_found then break end
				end
				if torch_found then break end
			end

			if not torch_found then
				local placed = false
				for dy = -2, 2 do
					for dx = -2, 2 do
						for dz = -2, 2 do
							if placed then break end
							local try_pos = vector.add(pos, {x = dx, y = dy, z = dz})
							if not minetest.is_protected(try_pos, self.owner) then
								local _, success = minetest.item_place_node(stack, player, {
									type = "node",
									under = vector.add(try_pos, vector.new(0, -1, 0)),
									above = try_pos,
								})
								-- lf(func_name, "torch placement attempted at " .. minetest.pos_to_string(try_pos) .. ", success=" .. tostring(success))
								if success then
									self:get_inventory():remove_item("main", stack)
									placed = true
									break
								end
							else
								lf(func_name, "position protected: " .. minetest.pos_to_string(try_pos))
							end
						end
						if placed then break end
					end
					if placed then break end
				end
				if not placed then
					lf(func_name, "no valid torch placement around " .. minetest.pos_to_string(pos))
				end
			else
				lf(func_name, "torch already present in region, skipping placement")
			end
			self.is_placing = false
		else
			if is_dark(vector.round(self:get_pos())) then
				lf(func_name, "darkness detected, will place torch")
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
	-- minetest.log("warning", "************************************************** torch:is_tool  ")
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
