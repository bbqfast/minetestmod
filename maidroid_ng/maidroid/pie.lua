------------------------------------------------------------
-- Copyleft (Я) 2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

if not maidroid.mods.pie then
	return
end

local S = maidroid.translator
pie.register_pie("maidroid_pie", S("Maidroid Golden Pie"))
minetest.register_craft({
	output = "pie:maidroid_pie_0",
	description = S("Maidroid Golden Pie"),
	recipe = {
		{"default:gold_ingot", "default:gold_ingot", "default:gold_ingot"},
		{"default:tin_lump", "default:gold_lump", "default:tin_lump"},
		{"default:gold_ingot", "default:gold_ingot", "default:gold_ingot"},
	}
})

local mod_hunger = minetest.get_modpath("hunger")
local mod_hbhunger = minetest.get_modpath("hbhunger")
local mod_stamina = minetest.global_exists("stamina")
local mod_mcl_hunger = minetest.get_modpath("mcl_hunger")

-- Watch "replace_pie" function from pie mod to "rebase" updates
local maidroid_gold_pie_on_punch = function(pos, node, puncher)
	if minetest.is_protected(pos, puncher:get_player_name()) then
		return
	end -- is this my pie?

	-- which size of pie did we hit?
	local pie = node.name:sub(1,-3)
	local num = tonumber(node.name:sub(-1))

	-- are we using crystal shovel to pick up full pie using soft touch?
	local tool = puncher:get_wielded_item():get_name()
	if num == 0 and tool == "ethereal:shovel_crystal" then
		local inv = puncher:get_inventory()
		minetest.remove_node(pos)
		if inv:room_for_item("main", {name = pie .. "_0"}) then
			inv:add_item("main", pie .. "_0")
		else
			pos.y = pos.y + 0.5
			minetest.add_item(pos, {name = pie .. "_0"})
		end
		return
	end

	-- eat slice or remove whole pie
	if num == 3 then
		node.name = "air"
	elseif num < 3 then
		node.name = pie .. "_" .. (num + 1)
	end

	minetest.swap_node(pos, node)

	if num == 3 then
		minetest.check_for_falling(pos)
	end

	-- default eat sound
	local sound = "default_dig_crumbly"

	if mod_hunger then -- Blockmen's hud_hunger mod
		sound = "hunger_eat"
	elseif mod_hbhunger then -- Wuzzy's hbhunger mod
		sound = "hbhunger_eat_generic"
	elseif mod_stamina then -- Sofar's stamina mod
		sound = "stamina_eat"
	elseif mod_mcl_hunger then -- mineclone2 mcl_hunger mod
		sound = "mcl_hunger_bite"
	end

	local h = puncher:get_hp()
	h = math.max(0, math.min(h - 6, 30))
	puncher:set_hp(h, {poison = true, hunger = true})

	minetest.sound_play(sound, {pos = pos, gain = 0.7, max_hear_distance = 5}, true)
end

for idx=0,3 do
	minetest.override_item("pie:maidroid_pie_" .. idx, { on_punch = maidroid_gold_pie_on_punch })
end
-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
