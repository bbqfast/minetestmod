farming = {}

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

function place_seed(itemstack, placer, pointed_thing, plantname, param2)
	local pt = pointed_thing
	if not pt then
		return
	end
	if pt.type ~= "node" then
		return
	end
	local under = minetest.get_node(pt.under)
	local above = minetest.get_node(pt.above)
	if not minetest.registered_nodes[under.name] then
		return
	end
	if not minetest.registered_nodes[above.name] then
		return
	end
	if pt.above.y ~= pt.under.y+1 then
		return
	end
	if not minetest.registered_nodes[above.name].buildable_to then
		return
	end
	if minetest.get_item_group(under.name, "soil") <= 1 then
		return
	end
	minetest.add_node(pt.above, {name=plantname, param2=param2})
	if not minetest.settings:get_bool("creative_mode") then
		itemstack:take_item()
	end
	return itemstack
end

function place_spore(itemstack, placer, pointed_thing, plantname, p2)
	local pt = pointed_thing
	if not pt then
		return
	end
	if pt.type ~= "node" then
		return
	end
	local under = minetest.get_node(pt.under)
	local above = minetest.get_node(pt.above)
	if not minetest.registered_nodes[under.name] then
		return
	end
	if not minetest.registered_nodes[above.name] then
		return
	end
	if pt.above.y ~= pt.under.y+1 then
		return
	end
	if not minetest.registered_nodes[above.name].buildable_to then
		return
	end
	if minetest.get_item_group(under.name, "fungi") <= 1 then
		return
	end
	minetest.add_node(pt.above, {name=plantname, param2 = p2})
	if not minetest.settings:get_bool("creative_mode") then
		itemstack:take_item()
	end
	return itemstack
end

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

function farming:add_plant(full_grown, names, interval, chance, p2)
	interval = interval / 10
	chance = chance * 4

	minetest.register_abm({
		nodenames = names,
		interval = interval,
		chance = chance,
		action = function(pos, node)
			lf("add_plant", "start at "..minetest.pos_to_string(pos).." node="..tostring(node.name))

			-- check soil beneath
			pos.y = pos.y-1
			local under = minetest.get_node(pos)
			lf("add_plant", "under node at "..minetest.pos_to_string(pos).." = "..tostring(under.name))
			if under.name ~= "farming:soil_wet" then
				lf("add_plant", "abort - under node is not farming:soil_wet")
				return
			end
			lf("add_plant", "ok - under is farming:soil_wet")

			-- restore pos and check light
			pos.y = pos.y+1
			local light_level = minetest.get_node_light(pos)
			lf("add_plant", "light_level at "..minetest.pos_to_string(pos).." = "..tostring(light_level))
			if not light_level then
				lf("add_plant", "abort - no light level")
				return
			end

			-- compute chance constant and evaluate growth condition
			local c = math.ceil(2 * (light_level - 13) ^ 2 + 1)
			lf("add_plant", "computed c = "..tostring(c).." (interval="..tostring(interval).." chance="..tostring(chance)..")")

			local rand = math.random(1, c)
			local cond_light = (light_level > 7)
			local cond_rand = (rand == 1)
			local cond_highlight = (light_level >= 13)
			local grow_condition = cond_light and (cond_rand or cond_highlight)

			lf("add_plant", "cond_light (light_level>7) = "..tostring(cond_light))
			lf("add_plant", "random roll = "..tostring(rand).." (cond_rand = "..tostring(cond_rand)..")")
			lf("add_plant", "cond_highlight (light_level>=13) = "..tostring(cond_highlight))
			lf("add_plant", "grow_condition = "..tostring(grow_condition))

			if not grow_condition then
				lf("add_plant", "abort - growth condition not met")
				return
			end

			-- find current step index in names
			local step
			for i, name in ipairs(names) do
				if name == node.name then
					step = i
					break
				end
			end
			lf("add_plant", "found step = "..tostring(step))
			if not step then
				lf("add_plant", "abort - current node name not in names list")
				return
			end

			-- determine new node (next growth stage or full grown)
			local new_name = names[step+1]
			if new_name == nil then
				new_name = full_grown
			end
			local new_node = {name = new_name, param2 = p2}
			lf("add_plant", "growing "..tostring(node.name).." -> "..tostring(new_node.name).." at "..minetest.pos_to_string(pos))

			minetest.set_node(pos, new_node)
		end
	})
end
-- })
-- end

-- ========= CORN =========
dofile(minetest.get_modpath("lottfarming").."/corn.lua")

-- ========= BERRIES =========
dofile(minetest.get_modpath("lottfarming").."/berries.lua")

-- ========= CABBAGE =========
dofile(minetest.get_modpath("lottfarming").."/cabbage.lua")

-- ========= ATHELAS =========
dofile(minetest.get_modpath("lottfarming").."/athelas.lua")

-- ========= POTATO =========
dofile(minetest.get_modpath("lottfarming").."/potato.lua")

-- ========= TOMATO =========
dofile(minetest.get_modpath("lottfarming").."/tomatoes.lua")

-- ========= TURNIP =========
dofile(minetest.get_modpath("lottfarming").."/turnips.lua")

-- ========= PIPEWEED =========
dofile(minetest.get_modpath("lottfarming").."/pipeweed.lua")

-- ========= MELON =========
dofile(minetest.get_modpath("lottfarming").."/melon.lua")

-- ========= BARLEY =========
dofile(minetest.get_modpath("lottfarming").."/barley.lua")

-- ========= CRAFTS =========
dofile(minetest.get_modpath("lottfarming").."/crafting.lua")

-- ========= BROWN MUSHROOM =========
dofile(minetest.get_modpath("lottfarming").."/brown.lua")

-- ========= RED MUSHROOM =========
dofile(minetest.get_modpath("lottfarming").."/red.lua")

-- ========= BLUE MUSHROOM =========
dofile(minetest.get_modpath("lottfarming").."/blue.lua")

-- ========= GREEN MUSHROOM =========
dofile(minetest.get_modpath("lottfarming").."/green.lua")

-- ========= WHITE MUSHROOM =========
dofile(minetest.get_modpath("lottfarming").."/white.lua")

-- ========= ORC FOOD =========
dofile(minetest.get_modpath("lottfarming").."/orc_food.lua")
