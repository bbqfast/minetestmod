-- Minetest 0.4 mod: farming
-- See README.txt for licensing and other information.

farming = {}

--
-- Soil
--

ll = function(msg)
	local pre="**************************************************"
	local pre="++++++++++++++++++++++++++++++++++++++++++++++++++"
	if msg == nil then
		msg = "null"
	end

	-- minetest.log("warning", pre..msg)
end


minetest.register_node("farming:soil", {
	description = "Soil",
	tiles = {"farming_soil.png", "default_dirt.png"},
	drop = "default:dirt",
	is_ground_content = true,
	groups = {crumbly=3, not_in_creative_inventory=1, soil=2},
	sounds = default.node_sound_dirt_defaults(),
})

minetest.register_node("farming:soil_wet", {
	description = "Wet Soil",
	tiles = {"farming_soil_wet.png", "farming_soil_wet_side.png"},
	drop = "default:dirt",
	is_ground_content = true,
	groups = {crumbly=3, not_in_creative_inventory=1, soil=3},
	sounds = default.node_sound_dirt_defaults(),
})

minetest.register_abm({
	nodenames = {"farming:soil", "farming:soil_wet"},
	interval = 15,
	chance = 4,
	action = function(pos, node)
		pos.y = pos.y+1
		local nn = minetest.get_node(pos).name
		pos.y = pos.y-1
		if minetest.registered_nodes[nn] and
				minetest.registered_nodes[nn].walkable and
				minetest.get_item_group(nn, "plant") == 0
		then
			minetest.set_node(pos, {name="default:dirt"})
		end
		-- check if there is water nearby
		if minetest.find_node_near(pos, 3, {"group:water"}) then
			-- if it is dry soil turn it into wet soil
			if node.name == "farming:soil" then
				minetest.set_node(pos, {name="farming:soil_wet"})
			end
		else
			-- turn it back into dirt if it is already dry
			if node.name == "farming:soil" then
				-- only turn it back if there is no plant on top of it
				if minetest.get_item_group(nn, "plant") == 0 then
					minetest.set_node(pos, {name="default:dirt"})
				end

			-- if its wet turn it back into dry soil
			elseif node.name == "farming:soil_wet" then
				minetest.set_node(pos, {name="farming:soil"})
			end
		end
	end,
})

--
-- Hoes
--
-- turns nodes with group soil=1 into soil
function farming.hoe_on_use(itemstack, user, pointed_thing, uses)
	local pt = pointed_thing
	-- check if pointing at a node
	if not pt then
		return
	end
	if pt.type ~= "node" then
		return
	end

	local under = minetest.get_node(pt.under)
	local p = {x=pt.under.x, y=pt.under.y+1, z=pt.under.z}
	local above = minetest.get_node(p)

	-- return if any of the nodes is not registered
	if not minetest.registered_nodes[under.name] then
		return
	end
	if not minetest.registered_nodes[above.name] then
		return
	end

	-- check if the node above the pointed thing is air
	if above.name ~= "air" then
		return
	end

	-- check if pointing at dirt
	if minetest.get_item_group(under.name, "soil") ~= 1 then
		return
	end

	-- turn the node into soil, wear out item and play sound
	minetest.set_node(pt.under, {name="farming:soil"})
	minetest.sound_play("default_dig_crumbly", {
		pos = pt.under,
		gain = 0.5,
	})
	itemstack:add_wear(65535/(uses-1))
	return itemstack
end

minetest.register_tool("farming:hoe_wood", {
	description = "Wooden Hoe",
	inventory_image = "farming_tool_woodhoe.png",
	groups = {hoe = 1},
	on_use = function(itemstack, user, pointed_thing)
		return farming.hoe_on_use(itemstack, user, pointed_thing, 30)
	end,
})

minetest.register_tool("farming:hoe_stone", {
	description = "Stone Hoe",
	inventory_image = "farming_tool_stonehoe.png",
	groups = {hoe = 1},
	on_use = function(itemstack, user, pointed_thing)
		return farming.hoe_on_use(itemstack, user, pointed_thing, 90)
	end,
})

minetest.register_tool("farming:hoe_steel", {
	description = "Steel Hoe",
	inventory_image = "farming_tool_steelhoe.png",
	groups = {hoe = 1},
	on_use = function(itemstack, user, pointed_thing)
		return farming.hoe_on_use(itemstack, user, pointed_thing, 200)
	end,
})

minetest.register_tool("farming:hoe_bronze", {
	description = "Bronze Hoe",
	inventory_image = "farming_tool_bronzehoe.png",
	groups = {hoe = 1},
	on_use = function(itemstack, user, pointed_thing)
		return farming.hoe_on_use(itemstack, user, pointed_thing, 220)
	end,
})

minetest.register_craft({
	output = "farming:hoe_wood",
	recipe = {
		{"group:wood", "group:wood"},
		{"", "group:stick"},
		{"", "group:stick"},
	}
})

minetest.register_craft({
	output = "farming:hoe_stone",
	recipe = {
		{"group:stone", "group:stone"},
		{"", "group:stick"},
		{"", "group:stick"},
	}
})

minetest.register_craft({
	output = "farming:hoe_steel",
	recipe = {
		{"default:steel_ingot", "default:steel_ingot"},
		{"", "group:stick"},
		{"", "group:stick"},
	}
})

minetest.register_craft({
	output = "farming:hoe_bronze",
	recipe = {
		{"default:bronze_ingot", "default:bronze_ingot"},
		{"", "group:stick"},
		{"", "group:stick"},
	}
})

--
-- Override grass for drops
--
minetest.override_item("default:grass_1", {
	drop = {
		max_items = 1,
		items = {
			{items = {'farming:seed_wheat'},rarity = 7},
			{items = {'farming:seed_cotton'},rarity = 7},
			{items = {'default:grass_1'}},
		}
	}
})

for i=2,5 do
	minetest.override_item("default:grass_"..i, {
		drop = {
			max_items = 1,
			items = {
				{items = {'farming:seed_wheat'},rarity = 7},
				{items = {'farming:seed_cotton'},rarity = 7},
				{items = {'default:grass_1'}},
			}
		}
	})
end

minetest.register_node(":default:junglegrass", {
	description = "Jungle Grass",
	drawtype = "plantlike",
	visual_scale = 1.3,
	tiles = {"default_junglegrass.png"},
	inventory_image = "default_junglegrass.png",
	wield_image = "default_junglegrass.png",
	paramtype = "light",
	waving = 1,
	walkable = false,
	buildable_to = true,
	is_ground_content = true,
	drop = {
		max_items = 1,
		items = {
			{items = {'farming:seed_cotton'},rarity = 8},
			{items = {'default:junglegrass'}},
		}
	},
	groups = {snappy=3,flammable=2,flora=1,attached_node=1},
	sounds = default.node_sound_leaves_defaults(),
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5},
	},
})

--
-- Place seeds
--
local function place_seed(itemstack, placer, pointed_thing, plantname)
	local pt = pointed_thing
	-- check if pointing at a node
	if not pt then
		return
	end
	if pt.type ~= "node" then
		return
	end

	local under = minetest.get_node(pt.under)
	local above = minetest.get_node(pt.above)

	-- return if any of the nodes is not registered
	if not minetest.registered_nodes[under.name] then
		return
	end
	if not minetest.registered_nodes[above.name] then
		return
	end

	-- check if pointing at the top of the node
	if pt.above.y ~= pt.under.y+1 then
		return
	end

	-- check if you can replace the node above the pointed node
	if not minetest.registered_nodes[above.name].buildable_to then
		return
	end

	-- check if pointing at soil
	if minetest.get_item_group(under.name, "soil") <= 1 then
		return
	end

	-- add the node and remove 1 item from the itemstack
	minetest.add_node(pt.above, {name=plantname})
	if not minetest.settings:get_bool("creative_mode") then
		itemstack:take_item()
	end
	return itemstack
end

--
-- Wheat
--
minetest.register_craftitem("farming:seed_wheat", {
	description = "Wheat Seed",
	inventory_image = "farming_wheat_seed.png",
	on_place = function(itemstack, placer, pointed_thing)
		return place_seed(itemstack, placer, pointed_thing, "farming:wheat_1")
	end,
})

minetest.register_craftitem("farming:wheat", {
	description = "Wheat",
	inventory_image = "farming_wheat.png",
})

minetest.register_craftitem("farming:flour", {
	description = "Flour",
	inventory_image = "farming_flour.png",
})

minetest.register_craftitem("farming:bread", {
	description = "Bread",
	inventory_image = "farming_bread.png",
	on_use = minetest.item_eat(4),
})

minetest.register_craft({
	type = "shapeless",
	output = "farming:flour",
	recipe = {"farming:wheat", "farming:wheat", "farming:wheat", "farming:wheat"}
})

minetest.register_craft({
	type = "cooking",
	cooktime = 15,
	output = "farming:bread",
	recipe = "farming:flour"
})

for i=1,8 do
	local drop = {
		items = {
			{items = {'farming:wheat'},rarity=9-i},
			{items = {'farming:wheat'},rarity=18-i*2},
			{items = {'farming:seed_wheat'},rarity=9-i},
			{items = {'farming:seed_wheat'},rarity=18-i*2},
		}
	}
	minetest.register_node("farming:wheat_"..i, {
		drawtype = "plantlike",
		tiles = {"farming_wheat_"..i..".png"},
		paramtype = "light",
		waving = 1,
		walkable = false,
		buildable_to = true,
		is_ground_content = true,
		drop = drop,
		selection_box = {
			type = "fixed",
			fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5},
		},
		groups = {snappy=3,flammable=2,plant=1,wheat=i,not_in_creative_inventory=1,attached_node=1},
		sounds = default.node_sound_leaves_defaults(),
	})
end

-- helper: extract light check and growth for crops
-- generic crop growth helper
-- opts = {
--   group = "wheat",          -- group name used for logging (optional)
--   max_stage = 8,            -- maximum growth stage number
--   plant_prefix = "farming:wheat_" -- node name prefix; final node is plant_prefix..stage
-- }
-- function farming._maybe_grow_crop(pos, node, current_stage, opts)
function _maybe_grow_crop(pos, node, current_stage, opts)
	opts = opts or {}
	local group = opts.group or "crop"
	local max_stage = opts.max_stage or 8
	local plant_prefix = opts.plant_prefix or ("farming:"..group.."_")

	-- sanity
	if current_stage >= max_stage then
		--minetest.log("action", string.format("++++++++++ [farming] %s already full grown at %s", group, minetest.pos_to_string(pos)))
		ll(string.format("[farming] %s already full grown at %s", group, minetest.pos_to_string(pos)))
		return
	end

	local light_level = minetest.get_node_light(pos)
	--minetest.log("action", string.format("++++++++++ [farming] %s light_level=%s at %s", group, tostring(light_level), minetest.pos_to_string(pos)))
	ll(string.format("[farming] %s light_level=%s at %s", group, tostring(light_level), minetest.pos_to_string(pos)))
	if not light_level then
		--minetest.log("action", "++++++++++ [farming] light level unavailable, aborting")
		ll("[farming] light level unavailable, aborting")
		return
	end

	local c = math.max(1, math.ceil(2 * (light_level - 13) ^ 2 + 1))
	--minetest.log("action", "++++++++++ [farming] computed chance cap c="..tostring(c))
	ll("[farming] computed chance cap c="..tostring(c))

	local roll = math.random(1, c)
	--minetest.log("action", "++++++++++ [farming] random roll="..tostring(roll).." (1 means grow); light_level>=13="..tostring(light_level>=13))
	ll("[farming] random roll="..tostring(roll).." (1 means grow); light_level>=13="..tostring(light_level>=13))

	-- grow if roll hits or if very bright
	if roll == 1 or light_level >= 13 then
		local new_stage = current_stage + 1
		if new_stage > max_stage then new_stage = max_stage end
		--minetest.log("action", string.format("++++++++++ [farming] growing %s from %d to %d at %s", group, current_stage, new_stage, minetest.pos_to_string(pos)))
		ll(string.format("[farming] growing %s from %d to %d at %s", group, current_stage, new_stage, minetest.pos_to_string(pos)))
		minetest.set_node(pos, {name = plant_prefix .. new_stage})
	else
		--minetest.log("action", string.format("++++++++++ [farming] %s did not grow this tick (roll=%d, cap=%d)", group, roll, c))
		ll(string.format("[farming] %s did not grow this tick (roll=%d, cap=%d)", group, roll, c))
	end
end

-- Ensure helper exists (defensive): create wrapper if missing
-- if not farming then farming = {} end
-- if not farming._maybe_grow_wheat then
-- function farming._maybe_grow_wheat(pos, node, wheat_group)
function _maybe_grow_wheat(pos, node, wheat_group)
	-- return farming._maybe_grow_crop(pos, node, wheat_group, {
	return _maybe_grow_crop(pos, node, wheat_group, {
		group = "wheat",
		max_stage = 8,
		plant_prefix = "farming:wheat_",
	})
end

function _maybe_grow_cotton(pos, node, wheat_group)
	-- return farming._maybe_grow_crop(pos, node, wheat_group, {
	return _maybe_grow_crop(pos, node, wheat_group, {
		group = "cotton",
		max_stage = 8,
		plant_prefix = "farming:cotton_",
	})
end

minetest.register_abm({
	nodenames = {"group:wheat"},
	neighbors = {"group:soil"},
	-- interval = 30,
	interval = 10,
	-- chance = 20,
	chance = 100 ,
	action = function(pos, node)
			--minetest.log("action", "++++++++++ [farming] wheat ABM called at "..minetest.pos_to_string(pos).." node="..tostring(node.name))
			ll("[farming] wheat ABM called at "..minetest.pos_to_string(pos).." node="..tostring(node.name))

			-- return if already full grown
			local wheat_group = minetest.get_item_group(node.name, "wheat")
			--minetest.log("action", "++++++++++ [farming] wheat group value = "..tostring(wheat_group))
			ll("[farming] wheat group value = "..tostring(wheat_group))
			if wheat_group == 8 then
				--minetest.log("action", "++++++++++ [farming] wheat already full grown, aborting")
				ll("[farming] wheat already full grown, aborting")
				return
			end

			-- check if on wet soil
			pos.y = pos.y-1
			local n = minetest.get_node(pos)
			local soil_group = minetest.get_item_group(n.name, "soil")
			--minetest.log("action", "++++++++++ [farming] soil below is "..tostring(n.name).." with soil group="..tostring(soil_group))
			ll("[farming] soil below is "..tostring(n.name).." with soil group="..tostring(soil_group))
			if soil_group < 3 then
				--minetest.log("action", "++++++++++ [farming] soil not wet enough (soil_group < 3), aborting")
				ll("[farming] soil not wet enough (soil_group < 3), aborting")
				pos.y = pos.y+1
				return
			end
			pos.y = pos.y+1

			-- delegate light check and growth to helper
			-- farming._maybe_grow_wheat(pos, node, wheat_group)
			_maybe_grow_wheat(pos, node, wheat_group)
		end
	})

--
-- Cotton
--
minetest.register_craftitem("farming:seed_cotton", {
	description = "Cotton Seed",
	inventory_image = "farming_cotton_seed.png",
	on_place = function(itemstack, placer, pointed_thing)
		return place_seed(itemstack, placer, pointed_thing, "farming:cotton_1")
	end,
})

minetest.register_craftitem("farming:string", {
	description = "String",
	inventory_image = "farming_string.png",
})

minetest.register_craft({
	output = "wool:white",
	recipe = {
		{"farming:string", "farming:string"},
		{"farming:string", "farming:string"},
	}
})

for i=1,8 do
	local drop = {
		items = {
			{items = {'farming:string'},rarity=9-i},
			{items = {'farming:string'},rarity=18-i*2},
			{items = {'farming:string'},rarity=27-i*3},
			{items = {'farming:seed_cotton'},rarity=9-i},
			{items = {'farming:seed_cotton'},rarity=18-i*2},
			{items = {'farming:seed_cotton'},rarity=27-i*3},
		}
	}
	minetest.register_node("farming:cotton_"..i, {
		drawtype = "plantlike",
		tiles = {"farming_cotton_"..i..".png"},
		paramtype = "light",
		waving = 1,
		walkable = false,
		buildable_to = true,
		is_ground_content = true,
		drop = drop,
		selection_box = {
			type = "fixed",
			fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5},
		},
		groups = {snappy=3,flammable=2,plant=1,cotton=i,not_in_creative_inventory=1,attached_node=1},
		sounds = default.node_sound_leaves_defaults(),
	})
end

-- ,,x1 hack speed
-- minetest.settings:get("time_speed")
minetest.settings:set("time_speed", "72")

minetest.register_abm({
	nodenames = {"group:cotton"},
	neighbors = {"group:soil"},
	-- interval = 60,
	interval = 10,
	chance = 20,
	action = function(pos, node)
			--minetest.log("action", "++++++++++ [farming] cotton ABM called at "..minetest.pos_to_string(pos).." node="..tostring(node.name))
			ll("[farming] cotton ABM called at "..minetest.pos_to_string(pos).." node="..tostring(node.name))

			-- return if already full grown
			local cotton_group = minetest.get_item_group(node.name, "cotton")
			--minetest.log("action", "++++++++++ [farming] cotton group value = "..tostring(cotton_group))
			ll("[farming] cotton group value = "..tostring(cotton_group))
			if cotton_group == 8 then
				--minetest.log("action", "++++++++++ [farming] cotton already full grown, aborting")
				ll("[farming] cotton already full grown, aborting")
				return
			end

			-- check if on wet soil
			pos.y = pos.y-1
			local n = minetest.get_node(pos)
			local soil_group = minetest.get_item_group(n.name, "soil")
			--minetest.log("action", "++++++++++ [farming] soil below is "..tostring(n.name).." with soil group="..tostring(soil_group))
			ll("[farming] soil below is "..tostring(n.name).." with soil group="..tostring(soil_group))
			if soil_group < 3 then
				--minetest.log("action", "++++++++++ [farming] soil not wet enough (soil_group < 3), aborting")
				ll("[farming] soil not wet enough (soil_group < 3), aborting")
				pos.y = pos.y+1
				return
			end
			pos.y = pos.y+1

			-- check light
			-- local light_level = minetest.get_node_light(pos)
			-- --minetest.log("action", "++++++++++ [farming] light_level="..tostring(light_level))
			-- ll("[farming] light_level="..tostring(light_level))
			-- if not light_level then
			-- 	--minetest.log("action", "++++++++++ [farming] light level unavailable, aborting")
			-- 	ll("[farming] light level unavailable, aborting")
			-- 	return
			-- end
			-- local c = math.ceil(2 * (light_level - 13) ^ 2 + 1)
			-- --minetest.log("action", "++++++++++ [farming] computed chance cap c="..tostring(c))
			-- ll("[farming] computed chance cap c="..tostring(c))

			-- -- if light_level > 7 then
			-- if light_level > 1 or true then
			-- 	local roll = math.random(1, c)
			-- 	--minetest.log("action", "++++++++++ [farming] random roll="..tostring(roll).." (1 means grow); light_level>=13="..tostring(light_level>=13))
			-- 	ll("[farming] random roll="..tostring(roll).." (1 means grow); light_level>=13="..tostring(light_level>=13))
			-- 	if true or roll == 1 or light_level >= 13 then
			-- 		local height = minetest.get_item_group(node.name, "cotton") + 1
			-- 		--minetest.log("action", "++++++++++ [farming] growing cotton from "..tostring(minetest.get_item_group(node.name, "cotton")).." to height "..tostring(height))
			-- 		ll("[farming] growing cotton from "..tostring(minetest.get_item_group(node.name, "cotton")).." to height "..tostring(height))
			-- 		minetest.set_node(pos, {name="farming:cotton_"..height})
			-- 	else
			-- 		--minetest.log("action", "++++++++++ [farming] did not grow cotton this tick (roll did not meet condition)")
			-- 		ll("[farming] did not grow cotton this tick (roll did not meet condition)")
			-- 	end
			-- else
			-- 	--minetest.log("action", "++++++++++ [farming] light too low (<=7), no growth")
			-- 	ll("[farming] light too low (<=7), no growth")
			-- end
			_maybe_grow_wheat(pos, node, cotton_group)
		end
	})

minetest.register_node("farming:straw", {
	description = "Straw",
	tiles = {"farming_straw.png"},
	is_ground_content = false,
	groups = {snappy=3, flammable=4, fall_damage_add_percent=-30},
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_craft({
	output = "farming:straw 3",
	recipe = {
		{"farming:wheat", "farming:wheat", "farming:wheat"},
		{"farming:wheat", "farming:wheat", "farming:wheat"},
		{"farming:wheat", "farming:wheat", "farming:wheat"},
	}
})

minetest.register_craft({
	output = "farming:wheat 3",
	recipe = {
		{"farming:straw"},
	}
})
