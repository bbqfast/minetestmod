------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator

local on_start, on_pause, on_stop, on_step

local wander = maidroid.cores.wander
local follow = maidroid.cores.follow

if maidroid.mods.pie then
	maidroid.tame_item = "pie:maidroid_pie_0"
else
	maidroid.tame_item = "default:goldblock"
end

on_start = function(self)
	wander.on_start(self)
end

on_stop = function(self)
	self.state = maidroid.states.IDLE
	self:halt()
	self:set_animation(maidroid.animation.STAND)
end

on_pause = function(self)
	self.state = maidroid.states.IDLE
	self:halt()
	self:set_animation(maidroid.animation.SIT)
end

-- get nearest player, can also filter player by wield item
local seek_tamer = function(self, range, item_name)
	local position = self:get_pos()
	local player_distance = range
	local droid_distance = range

	local player, droid, distance

	local objects = minetest.get_objects_inside_radius(position, range)
	for _, object in pairs(objects) do
		local entity = object:get_luaentity()
		if object:is_player() and -- player wielding taming item
			object:get_wielded_item():get_name() == item_name then
			distance = vector.distance(position, object:get_pos())
			if distance < player_distance then
				player_distance = distance
				player = object
			end
		elseif entity and maidroid.is_maidroid(entity.name)
			and entity.owner ~= "" and -- maidroid possesing taming item
			entity:get_inventory():contains_item("main", item_name) then
			distance = vector.distance(position, object:get_pos())
			if distance < droid_distance then
				droid_distance = distance
				droid = entity
			end
		end
	end

	return player, droid
end

local love_particles = function(player, pos)
	pos.y = pos.y + 0.8
	minetest.add_particlespawner({
		amount = 1,
		time = 0.1,
		minpos = {x = pos.x - 0.1, y = pos.y, z = pos.z - 0.1},
		maxpos = {x = pos.x + 0.1, y = pos.y, z = pos.z + 0.1},
		minvel = {x = -0.2, y = 0.5, z = -0.2},
		maxvel = {x = 0.3,  y = 1.5, z = 0.3},
		minacc = {x = 0, y = -0.1, z = 0},
		maxacc = {x = 0, y = 0.3, z = 0},
		minexptime = 0.1,
		maxexptime = 0.4,
		minsize = 0.2,
		maxsize = 1.5,
		collisiondetection = false,
		vertical = false,
		texture = "default_gold_lump.png",
		player = player
	})
end

local do_wander = function(self)
	if	self.state ~= maidroid.states.WANDER then
		self:set_animation(maidroid.animation.WALK)
		self.state = maidroid.states.WANDER
	end
end

local w_step = wander.on_step
on_step = function(self, dtime, moveresult)
	local player, droid
	local range = 12
	local pos = self:get_pos()

	if	self.owner ~= "" then -- Maidroid owned
		player = minetest.get_player_by_name(self.owner)
		if	not player or -- Player not logged in
			vector.distance(pos, player:get_pos()) > range or -- Player far
			player:get_wielded_item():get_name() ~= maidroid.tame_item then -- Not asking to follow
			do_wander(self); w_step(self, dtime, moveresult); return
		end
	end

	player, droid = seek_tamer(self, range, maidroid.tame_item)
	if	not player then -- No player to follow: wander
		if droid then -- A droid with enough gold block will tame us
			-- TODO: queued job list or migrate to mobkit and use internals
			-- TODO: animation and pause after capture for "droid"
			self.owner = droid.owner
			droid:get_inventory():remove_item("main", maidroid.tame_item)
			minetest.chat_send_player(self.owner,
				S("This maidroid is now yours") .. ": "
				.. minetest.pos_to_string(pos))
		end
		do_wander(self); w_step(self, dtime, moveresult); return
	end

	if	self.owner == "" then -- Untamed droid emit "love" particles
		love_particles(player, pos)
	else
		self:pickup_item(3.0)
	end

	-- Follow target player
	self:set_animation(maidroid.animation.WALK)
	self.state = maidroid.states.FOLLOW
	follow.on_step(self, dtime, moveresult, player)
end

local doc = S("You already tamed this maidroid.") .. "\n\n"
		.. S("Put activate items in inventory to choose job") .. "\n"
		.. S("The first activate item found appears highlighted") .. "\n\n"
		.. S("List of activate items") .. "\n"

-- register a definition of a new core.
maidroid.register_core("basic", {
	description      = S("a wanderer"),
	on_start         = on_start,
	on_stop          = on_stop,
	on_resume        = on_start,
	on_pause         = on_pause,
	on_step          = on_step,
	doc = doc,
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
