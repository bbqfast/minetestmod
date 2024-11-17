------------------------------------------------------------
-- Copyleft (Я) 2023 mazes + johann-fr
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator

minetest.register_tool("maidroid:robbery_stick", {
	description = S("maidroid robbery stick"),
	inventory_image = "maidroid_robbery_stick.png",
	on_use = function(itemstack, user, pointed_thing)
		if (pointed_thing.type ~= "object") then
			return
		end

		local obj = pointed_thing.ref
		if obj:is_player() then
			return
		end
		local droid = obj:get_luaentity()
		if droid == nil then
			return
		end
		if not maidroid.is_maidroid(droid.name) then
			if droid.name == "__builtin:item" then
				droid:on_punch(user)
			end
			return
		end
		-- The droid must be owned
		if not droid.owner then return end

		local username = user:get_player_name()
		local droidpos = droid:get_pos()
		local droidowner = minetest.get_player_by_name(droid.owner)
		if	droid.owner == username or								-- droid owner is not puncher
			minetest.is_protected(droidpos, username)				-- area is accessible to user
			or not droidowner or									-- droid owner is online
			vector.distance(droidpos, droidowner:get_pos()) > 50	-- and near to his droid
		then return itemstack end

		itemstack:add_wear(8192) -- 65536/8
		if math.random() > 0.1 then
			return itemstack
		end

		droid.owner = username
		droid:update_infotext()
		return itemstack
	end
})

local stickname
if minetest.get_modpath("basic_materials") then
	stickname = "basic_materials:steel_bar"
else
	stickname = "default:stick"
end

minetest.register_craft({
	output = "maidroid:robbery_stick",
	recipe = {
		{"", "", maidroid.tame_item},
		{"", stickname, ""},
		{stickname, "", ""}
	},
})
-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
