------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator

local formspec = "size[4,1.25]"
			.. "button_exit[3,0.25;1,0.875;apply_name;" .. S("Apply") .. "]"
			.. "field[0.5,0.5;2.75,1;value;" .. S("name") .. ";%s]"

local formspec_r = "size[4,1.25]"
			.. "button_exit[3,0.25;1,0.875;apply_owner;" .. S("Apply") .. "]"
			.. "field[0.5,0.5;2.75,1;value;" .. S("Owner") .. ";%s]"


local maidroid_buf = {} -- for buffer of target maidroids.

minetest.register_craftitem("maidroid:nametag", {
	description      = S("maidroid nametag"),
	inventory_image  = "maidroid_tool_nametag.png",

	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type ~= "object"
			or pointed_thing.ref:is_player()
			or not user:is_player() then
			return
		end

		local luaentity = pointed_thing.ref:get_luaentity()

		if not ( luaentity and
			maidroid.is_maidroid(luaentity.name) ) then
			pointed_thing.ref:punch(user)
			return
		elseif not luaentity:player_can_control(user) then
			return
		end

		local nametag = luaentity.nametag or ""

		minetest.show_formspec(user:get_player_name(), "maidroid_tool:nametag", formspec:format(nametag))
		maidroid_buf[user:get_player_name()] = { luaentity = luaentity, stack = itemstack }
	end,
	on_place = function(_, placer, pointed_thing)
		if pointed_thing.type ~= "object"
			or pointed_thing.ref:is_player()
			or not placer:is_player() then
			return
		end

		local luaentity = pointed_thing.ref:get_luaentity()

		if not luaentity or
			not maidroid.is_maidroid(luaentity.name) or
			not luaentity:player_can_control(placer) then
			return
		end

		minetest.show_formspec(placer:get_player_name(), "maidroid_tool:ownertag", formspec_r:format(luaentity.owner))
		maidroid_buf[placer:get_player_name()] = { luaentity = luaentity, stack = placer:get_wielded_item() }
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if not (formname and formname:sub(1,14) == "maidroid_tool:") then
		return
	end -- Let other callbacks treat this

	local player_name = player:get_player_name()
	if not fields.value then
		maidroid_buf[player_name] = nil
		return true
	end -- Nothing to set

	local luaentity = maidroid_buf[player_name].luaentity
	if luaentity and not maidroid.is_maidroid(luaentity.name) then
		maidroid_buf[player_name] = nil
		return true
	end -- Wrong target

	formname = formname:sub(15)
	local success = true

	if formname == "nametag" and fields.value then -- Set nametag
		luaentity.nametag = fields.value
		luaentity.object:set_nametag_attributes({ text = fields.value,
			color = { a=255, r=96, g=224, b=96 }})
	elseif formname == "ownertag" and fields.value == ""
		or minetest.player_exists(fields.value) then
		luaentity.owner = fields.value -- Set owner
		luaentity:update_infotext()
	else
		success = false
	end

	if success and maidroid_buf[player_name] and maidroid_buf[player_name].stack then
		local stack = maidroid_buf[player_name].stack
		stack:take_item()
		player:set_wielded_item(stack)
	end

	maidroid_buf[player_name] = nil
	return true
end)

minetest.register_alias("maidroid_tool:nametag", "maidroid:nametag")
-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
