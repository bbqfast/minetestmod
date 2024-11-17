------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator

minetest.register_privilege("maidroid", { S("Can") ..  " " .. S("administer any maidroid"),
	give_to_singleplayer = false,
	on_grant = function(name, _)
		minetest.chat_send_player(name, S("You gained privilege: ") .. S("administer any maidroid"))
	end,
	on_revoke = function(name, _)
		minetest.chat_send_player(name, S("You lost privilege: ") .. S("administer any maidroid"))
	end,
})

minetest.register_craft{
	output = "maidroid:maidroid_egg",
	recipe = {
		{"default:coalblock", "default:mese"          , "default:coalblock"},
		{""                 , "maidroid_tool:nametag" , ""},
		{""                 , "default:bronzeblock"   , ""},
	},
}

minetest.register_craft{
	output = "maidroid_tool:nametag",
	recipe = {
		{""                , "farming:cotton", ""},
		{"default:paper"   , "default:paper" , "default:paper"},
		{"default:tin_lump", "dye:black"     , "default:copper_ingot"},
	},
}

if maidroid.settings.tools_capture_rod then
	minetest.register_craft{
		output = "maidroid_tool:capture_rod",
		recipe = {
			{"wool:blue"          , "dye:red"            , "default:mese_crystal"},
			{""                   , "default:steel_ingot", "dye:red"},
			{"default:steel_ingot", ""                   , "wool:violet"},
		},
	}
end

--------------------------------------------------------------------
-- Compatibility: clean every old format wield item
minetest.register_entity("maidroid:dummy_item", {
	static_save = false,
	on_activate = function (self)
		minetest.log("[ Maidroid ]: found old maidroid:dummy_item, cleaning")
		self.object:remove()
	end
})

-- Register a wield item
minetest.register_entity("maidroid:wield_item", {
	hp_max = 1,
	visual = "item",
	visual_size = {x = 0.1875, y = 0.1875},
	physical = false,
	pointable = false,
	static_save = false,
	on_detach = function(self)
		self.object:remove()
	end
})

-- Totally transparent texture for wield item
minetest.register_craftitem("maidroid:hand", {
	inventory_image = "maidroid_dummy_empty_craftitem.png",
	groups = { not_in_creative_inventory = 1 },
})

-- A spatula to be held by wafflers
if maidroid.settings.waffler then
	minetest.register_craftitem("maidroid:spatula", {
		inventory_image = "maidroid_spatula.png",
		groups = { not_in_creative_inventory = 1 },
	})
end
-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
