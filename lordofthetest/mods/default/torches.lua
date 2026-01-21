-- This code was derived by sofar from the 'torches' mod by
-- BlockMen (LGPLv2.1+), modified by Amaz
-- The models from Minetest Game were not used, they made from scratch
-- https://forum.minetest.net/viewtopic.php?f=11&t=6099
-- https://github.com/minetest/minetest_game/blob/master/mods/default/torch.lua

minetest.log("warning", "[lf-init] default/torches.lua loaded, lf=" .. tostring(_G.lf))

if not rawget(_G, "lf") then
	_G.lf = function(func, msg)
		local pre = ".............."
		if func == nil then func = "unknown" end
		if msg == nil then msg = "null" end

		local black_list = {}
		black_list["select_seed"] = true
		black_list["mow"] = true
		black_list["deserialize"] = true
		black_list["npc_attack"] = true


        -- TEMP DEBUG
        -- minetest.log("warning", "[lf-debug] func=" .. tostring(func)
        --     .. " black_list[func]=" .. tostring(black_list[func]))
            
            
		if black_list[func] == nil then
			minetest.log("warning", pre .. func .. "(): " .. msg)
		end
	end
end

local lf = assert(_G.lf, "global lf not initialized")


local function on_flood(pos, oldnode, newnode)
	minetest.add_item(pos, ItemStack("default:torch 1"))
	return false
end

local torch_light_radius = 6
local torch_light_level = 15
local torch_light_nodes = {}

local function get_player_name(player)
	return player and player:is_player() and player:get_player_name() or ""
end

-- local function set_temporary_light(pos, playername)
-- 	lf("set_temporary_light", "player " .. playername .. " at " .. minetest.pos_to_string(pos))
-- 	local key = minetest.pos_to_string(pos)
-- 	if not torch_light_nodes[key] then
-- 		lf("set_temporary_light", "key not present: " .. key)
-- 		local node = minetest.get_node_or_nil(pos)
-- 		-- If node is nil, it's likely outside loaded area; if not, check
-- 		-- If player is in the air but this returns "stone", it's probably
-- 		-- because the mapgen hasn't updated the node yet, or there's a bug.
-- 		-- For debugging:
-- 		if node then
-- 			lf("set_temporary_light", "DEBUG: node at " .. minetest.pos_to_string(pos) .. " is " .. node.name)
-- 		else
-- 			lf("set_temporary_light", "DEBUG: node at " .. minetest.pos_to_string(pos) .. " is nil")
-- 		end
-- 		if node then
-- 			lf("set_temporary_light", "node found: " .. node.name)
-- 			if node.name == "air" then
-- 				lf("set_temporary_light", "node is air at " .. key)
-- 				minetest.set_node(pos, {name = "air", param1 = torch_light_level, param2 = 0})
-- 				torch_light_nodes[key] = {player = playername, time = minetest.get_gametime()}
-- 			else
-- 				lf("set_temporary_light", "node is not air: " .. node.name)
-- 			end
-- 		else
-- 			lf("set_temporary_light", "node not found at " .. key)
-- 		end
-- 	else
-- 		lf("set_temporary_light", "key already present: " .. key)
-- 	end
-- end

-- local function clear_temporary_lights(playername)
-- 	for key, data in pairs(torch_light_nodes) do
-- 		if data.player == playername then
-- 			lf("clear_temporary_lights", "clearing light for player " .. playername .. " at " .. key)
-- 			local pos = minetest.string_to_pos(key)
-- 			local node = minetest.get_node(pos)
-- 			if node.name == "air" then
-- 				lf("clear_temporary_lights", "node is air at " .. key)
-- 				minetest.set_node(pos, {name = "air"})
-- 			else
-- 				lf("clear_temporary_lights", "node is not air at " .. key .. ": " .. node.name)
-- 			end
-- 			torch_light_nodes[key] = nil
-- 		end
-- 	end
-- end
-- Register invisible light node
minetest.register_node("default:torch_light_invis", {
	description = "Invisible Torch Light (internal)",
	drawtype = "airlike",
	tiles = {"invisible.png"},
	inventory_image = "invisible.png",
	wield_image = "invisible.png",
	paramtype = "light",
	sunlight_propagates = true,
	pointable = false,
	walkable = false,
	diggable = false,
	buildable_to = true,
	floodable = false,
	light_source = torch_light_level,
	groups = {not_in_creative_inventory=1, attached_node=1},
	drop = "",
})

local player_light_pos = {}

local function update_player_light(player, enable)
	local pname = get_player_name(player)
	if pname == "" then return end
	local pos = vector.round(player:get_pos())
	local key = minetest.pos_to_string(pos)
	local prev = player_light_pos[pname]
	-- Remove previous light node if player moved or torch is not held
	if prev and (not enable or not vector.equals(prev, pos)) then
		local prev_name = minetest.get_node(prev).name
		if prev_name == "default:torch_light_invis" then
			minetest.set_node(prev, {name = "air"})
		end
		player_light_pos[pname] = nil
	end
	-- Place new light node if enabled
	if enable then
		local nodename = minetest.get_node(pos).name
		if nodename == "air" or nodename == "default:torch_light_invis" then
			minetest.set_node(pos, {name = "default:torch_light_invis"})
			player_light_pos[pname] = pos
		end
	end
end

minetest.register_globalstep(function(dtime)
	for _, player in ipairs(minetest.get_connected_players()) do
		local item = player:get_wielded_item()
		local pname = get_player_name(player)
		if item:get_name() == "default:torch" then
			update_player_light(player, true)
		else
			update_player_light(player, false)
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	update_player_light(player, false)
end)

-- minetest.register_globalstep(function(dtime)
-- 	for _, player in ipairs(minetest.get_connected_players()) do
-- 		local item = player:get_wielded_item()
-- 		local pname = get_player_name(player)
-- 		if item:get_name() == "default:torch" then
-- 			local ppos = vector.round(player:get_pos())
-- 			for dx = -torch_light_radius, torch_light_radius do
-- 				for dy = -torch_light_radius, torch_light_radius do
-- 					for dz = -torch_light_radius, torch_light_radius do
-- 						local dist = math.abs(dx) + math.abs(dy) + math.abs(dz)
-- 						if dist <= torch_light_radius then
-- 							local pos = {x = ppos.x + dx, y = ppos.y + dy, z = ppos.z + dz}
-- 							set_temporary_light(pos, pname)
-- 						end
-- 					end
-- 				end
-- 			end
-- 		else
-- 			clear_temporary_lights(pname)
-- 		end
-- 	end
-- end)


minetest.register_node("default:torch", {
	description = "Torch",
	drawtype = "mesh",
	mesh = "default_torch_floor.obj",
	inventory_image = "default_torch_on_floor.png",
	wield_image = "default_torch_on_floor.png",
	tiles = {{
			name = "default_torch_on_floor_animated.png",
		    animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 3.3}
	}},
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	walkable = false,
	liquids_pointable = false,
	light_source = 12,
	groups = {choppy=2, dig_immediate=3, flammable=1, attached_node=1, torch=1},
	drop = "default:torch",
	selection_box = {
		type = "wallmounted",
		wall_bottom = {-1/8, -1/2, -1/8, 1/8, 2/16, 1/8},
		wall_top = {-1/8, -3/16, -1/8, 1/8, 1/2, 1/8},
	},
	on_place = function(itemstack, placer, pointed_thing)
		local under = pointed_thing.under
		local node = minetest.get_node(under)
		local def = minetest.registered_nodes[node.name]
		if def and def.on_rightclick and
			not (placer and placer:is_player() and
			placer:get_player_control().sneak) then
			return def.on_rightclick(under, node, placer, itemstack,
				pointed_thing) or itemstack
		end

		local above = pointed_thing.above
		local wdir = minetest.dir_to_wallmounted(vector.subtract(under, above))
		local fakestack = itemstack
		if wdir == 0 or wdir == 1 then
			fakestack:set_name("default:torch")
		else
			fakestack:set_name("default:torch_wall")
		end

		itemstack = minetest.item_place(fakestack, placer, pointed_thing, wdir)
		itemstack:set_name("default:torch")

		return itemstack
	end,
	floodable = true,
	on_flood = on_flood,
})

minetest.register_node("default:torch_wall", {
	drawtype = "mesh",
	mesh = "default_torch_wall.obj",
	tiles = {{
		    name = "default_torch_on_floor_animated.png",
		    animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 3.3}
	}},
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	walkable = false,
	light_source = 12,
	groups = {choppy=2, dig_immediate=3, flammable=1, not_in_creative_inventory=1, attached_node=1, torch=1},
	drop = "default:torch",
	selection_box = {
		type = "wallmounted",
		wall_side = {-1/2, -1/2, -1/8, -5/16, 1/8, 1/8},
	},
	floodable = true,
	on_flood = on_flood,
})

minetest.register_lbm({
	name = "default:3dtorch",
	nodenames = {"default:torch", "torches:floor", "torches:wall"},
	action = function(pos, node)
		if node.param2 == 0 or node.param2 == 1 then
			minetest.set_node(pos, {name = "default:torch",
				param2 = node.param2})
		else
			minetest.set_node(pos, {name = "default:torch_wall",
				param2 = node.param2})
		end
	end
})

