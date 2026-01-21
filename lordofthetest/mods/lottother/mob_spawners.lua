-- Mobs spawners for buildings
-- Mordor

local lf = assert(_G.lf, "global lf not initialized")

minetest.register_node("lottother:mordorms", {
	description = "Mordor Mob Spawner",
	drawtype = "glasslike",
	tiles = {"lottother_air.png"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = false,
	on_construct = function(pos, node)
		if math.random(1, 4) == 2 then
			minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:orc")
		elseif math.random(1, 5) == 3 then
			minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:uruk_hai")
		elseif math.random(1, 11) == 4 then
			minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:battle_troll")
		end
		minetest.remove_node(pos)
	end,
	groups = {not_in_creative_inventory=1,dig_immediate=3},
})

-- Rohan

minetest.register_node("lottother:rohanms", {
	description = "Rohan Mob Spawner",
	drawtype = "glasslike",
	tiles = {"lottother_air.png"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = false,
	on_construct = function(pos, node)
		if math.random(1, 3) == 2 then
			minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:rohan_guard")
		end
		minetest.remove_node(pos)
	end,
	groups = {not_in_creative_inventory=1,dig_immediate=3},
})

-- Elf

minetest.register_node("lottother:elfms", {
	description = "Elf Mob Spawner",
	drawtype = "glasslike",
	tiles = {"lottother_air.png"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = false,
	on_construct = function(pos, node)
		if math.random(1, 2) == 2 then
			minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:elf")
		end
		minetest.remove_node(pos)
	end,
	groups = {not_in_creative_inventory=1,dig_immediate=3},
})

--Hobbit

minetest.register_node("lottother:hobbitms", {
	description = "Hobbit Mob Spawner",
	drawtype = "glasslike",
	tiles = {"lottother_air.png"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = false,
	on_construct = function(pos, node)
		if math.random(1, 2) == 2 then
			minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:hobbit")
		end
		minetest.remove_node(pos)
	end,
	groups = {not_in_creative_inventory=1,dig_immediate=3},
})


-- LTs
-- detects if a trader is already spawned near spawner, then don't spawn extra trader
local function trader_exists_near(pos, radius, entity_name)
    local objs = minetest.get_objects_inside_radius(pos, radius or 1.5)
    for _, obj in ipairs(objs) do
        local ent = obj:get_luaentity()
        if ent and ent.name == entity_name then
			lf("trader_exists_near", string.format("Found %s at x=%d y=%d z=%d", entity_name, pos.x, pos.y, pos.z))
            return true
        end
    end
	lf("trader_exists_near", string.format("Not found %s at x=%d y=%d z=%d", entity_name, pos.x, pos.y, pos.z))
    return false
end

-- ,,x5
minetest.register_node("lottother:lteems", {
	description = "LT Mob Spawner",
	drawtype = "glasslike",
	tiles = {"lottother_air.png"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = false,
	on_construct = function(pos, node)
		minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:ltee")
		-- if math.random(1, 2) == 2 then
		-- 	minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:ltee")
		-- end
		-- minetest.remove_node(pos)
	end,
	groups = {not_in_creative_inventory=1,dig_immediate=3},
})

thin_plate = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, -0.4, 0.5 }, -- thin plate
	}

-- /giveme lottother:ltee_trader_1_ms
-- ,,ms1b
minetest.register_node("lottother:ltee_trader_1_ms", {
	description = "LT trader 1 Spawner",
	-- drawtype = "glasslike",
	-- tiles = {"lottother_air.png"},
	drawtype = "nodebox",
	node_box = thin_plate,	
	
	tiles = {"default_glass.png^[colorize:#ffff00:120"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = true,
	on_construct = function(pos, node)
		if trader_exists_near(pos, 1.5, "lottmobs:ltee_trader_1") then
			return
		end
		lf("ltee_trader_1_ms", string.format("at x=%d y=%d z=%d", pos.x, pos.y, pos.z))
		minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:ltee_trader_1")
	end,
	groups = {not_in_creative_inventory=1,dig_immediate=3},
})

-- ,,ms2
minetest.register_node("lottother:ltee_trader_2_ms", {
	description = "LT trader 2 Spawner",
	-- drawtype = "glasslike",
	drawtype = "nodebox",
	node_box = thin_plate,	
	-- tiles = {"lottother_air.png"},
	-- tiles = {"default_wood.png"},
	-- tiles = {"default_glass.png"},
	tiles = {"default_glass.png^[colorize:#00ffcc:120"},
-- ```](cascade:incomplete-link)
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	-- pointable = false,
	pointable = true,
	on_construct = function(pos, node)
		if trader_exists_near(pos, 1.5, "lottmobs:ltee_trader_2") then
			return
		end
		lf("ltee_trader_2_ms", string.format("at x=%d y=%d z=%d", pos.x, pos.y, pos.z))
		minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:ltee_trader_2")
		-- if math.random(1, 2) == 2 then
		-- 	minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:ltee")
		-- end
		-- minetest.remove_node(pos)
	end,
	-- groups = {not_in_creative_inventory=1,dig_immediate=3},
	groups = {dig_immediate=3},
})

minetest.register_node("lottother:ltee_trader_3_ms", {
	description = "LT trader 3 Spawner",
	drawtype = "nodebox",
	node_box = thin_plate,	
	-- tiles = {"lottother_air.png"},
	tiles = {"default_glass.png^[colorize:#00ff00:120"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = true,
	on_construct = function(pos, node)
		if trader_exists_near(pos, 1.5, "lottmobs:ltee_trader_3") then
			return
		end
		lf("ltee_trader_3_ms", string.format("at x=%d y=%d z=%d", pos.x, pos.y, pos.z))
		minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:ltee_trader_3")
	end,
	-- groups = {not_in_creative_inventory=1,dig_immediate=3},
	groups = {dig_immediate=3},
})

minetest.register_node("lottother:ltee_trader_santa_ms", {
	description = "LT trader santa Spawner",
	drawtype = "nodebox",
	node_box = thin_plate,	
	-- tiles = {"lottother_air.png"},
	tiles = {"default_glass.png^[colorize:#ff65b5:120"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = true,
	on_construct = function(pos, node)
		if trader_exists_near(pos, 1.5, "lottmobs:ltee_trader_santa") then
			return
		end
		lf("ltee_trader_santa_ms", string.format("at x=%d y=%d z=%d", pos.x, pos.y, pos.z))

		local obj = minetest.add_entity(
			{x = pos.x, y = pos.y + 1, z = pos.z},
			"lottmobs:ltee_trader_santa"
		)

		if obj then
			lf("ltee_trader_santa_ms", "add_entity SUCCESS: " .. tostring(obj))
		else
			lf("ltee_trader_santa_ms", "add_entity FAILED")
		end

		-- minetest.remove_node(pos)
	end,
	-- groups = {not_in_creative_inventory=1,dig_immediate=3},
	groups = {dig_immediate=3},
})


-- ,,lbms
minetest.register_lbm({
    name = "lottother:spawn_santa_trader",
    nodenames = {"lottother:ltee_trader_santa_ms"},
    run_at_every_load = true,
    action = function(pos, node)
		if trader_exists_near({x = pos.x, y = pos.y + 1, z = pos.z}, 1.5, "lottmobs:ltee_trader_santa") then
			return
		end
        lf("lottmobs:spawn_santa_trader", ("LBM spawning Santa at (%d, %d, %d)"):format(pos.x, pos.y, pos.z))

        local obj = minetest.add_entity(
            {x = pos.x, y = pos.y + 1, z = pos.z},
            "lottmobs:ltee_trader_santa"
        )
        if obj then
            minetest.remove_node(pos)
        end
    end,
})

minetest.register_lbm({
    name = "lottother:spawn_trader_1",
    nodenames = {"lottother:ltee_trader_1_ms"},
    run_at_every_load = true,  -- or false if you only want it once
	action = function(pos, node)
		
		if trader_exists_near({x = pos.x, y = pos.y + 1, z = pos.z}, 1.5, "lottmobs:ltee_trader_1") then
			return
		end
		lf("lottmobs:spawn_trader_1",
			("LBM spawning trader_1 at (%d, %d, %d)"):format(pos.x, pos.y, pos.z))
		local obj = minetest.add_entity(
			{x = pos.x, y = pos.y + 1, z = pos.z},
			"lottmobs:ltee_trader_1"
		)
		if obj then
			minetest.remove_node(pos)
		end
	end,
})


minetest.register_lbm({
    name = "lottother:spawn_trader_2",
    nodenames = {"lottother:ltee_trader_2_ms"},
    run_at_every_load = true,  -- or false if you only want it once
	action = function(pos, node)
		
		if trader_exists_near({x = pos.x, y = pos.y + 1, z = pos.z}, 1.5, "lottmobs:ltee_trader_2") then
			return
		end
		lf("lottmobs:spawn_trader_2",
			("LBM spawning trader_2 at (%d, %d, %d)"):format(pos.x, pos.y, pos.z))
		local obj = minetest.add_entity(
			{x = pos.x, y = pos.y + 1, z = pos.z},
			"lottmobs:ltee_trader_2"
		)
		if obj then
			minetest.remove_node(pos)
		end
	end,
})


minetest.register_lbm({
    name = "lottother:spawn_trader_3",
    nodenames = {"lottother:ltee_trader_3_ms"},
    run_at_every_load = true,  -- or false if you only want it once
    action = function(pos, node)
		if trader_exists_near({x = pos.x, y = pos.y + 1, z = pos.z}, 1.5, "lottmobs:ltee_trader_3") then
			return
		end
        lf("lottmobs:spawn_trader_3",
            ("LBM spawning trader_3 at (%d, %d, %d)"):format(pos.x, pos.y, pos.z))

        local obj = minetest.add_entity(
            {x = pos.x, y = pos.y + 1, z = pos.z},
            "lottmobs:ltee_trader_3"
        )
        if obj then
            minetest.remove_node(pos)
        end
    end,
})



--Gondor

minetest.register_node("lottother:gondorms", {
	description = "Gondor Mob Spawner",
	drawtype = "glasslike",
	tiles = {"lottother_air.png"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = false,
	on_construct = function(pos, node)
		if math.random(1, 3) == 2 then
			minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:gondor_guard")
		end
		minetest.remove_node(pos)
	end,
	groups = {not_in_creative_inventory=1,dig_immediate=3},
})

--Angmar

minetest.register_node("lottother:angmarms", {
	description = "Angmar Mob Spawner",
	drawtype = "glasslike",
	tiles = {"lottother_air.png"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = false,
	on_construct = function(pos, node)
		if math.random(1, 2) == 2 then
			minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:half_troll")
		end
		minetest.remove_node(pos)
	end,
	groups = {not_in_creative_inventory=1,dig_immediate=3},
})

--Dwarf

minetest.register_node("lottother:dwarfms", {
	description = "Dwarf Mob Spawner",
	drawtype = "glasslike",
	tiles = {"lottother_air.png"},
	drop = '',
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	pointable = false,
	on_construct = function(pos, node)
		if math.random(1, 2) == 2 then
			minetest.add_entity({x = pos.x, y = pos.y+1, z = pos.z}, "lottmobs:dwarf")
		end
		minetest.remove_node(pos)
	end,
	groups = {not_in_creative_inventory=1,dig_immediate=3},
})

minetest.register_alias("lottother:gondorms_on", "lottother:gondorms")
minetest.register_alias("lottother:gondorms_off", "lottother:gondorms")
minetest.register_alias("lottother:rohanms_on", "lottother:rohanms")
minetest.register_alias("lottother:rohanms_off", "lottother:rohanms")
minetest.register_alias("lottother:angmarms_on", "lottother:angmarms")
minetest.register_alias("lottother:angmarms_off", "lottother:angmarms")
minetest.register_alias("lottother:hobbitms_on", "lottother:hobbitms")
minetest.register_alias("lottother:hobbitms_off", "lottother:hobbitms")
minetest.register_alias("lottother:lteems_on", "lottother:lteems")
minetest.register_alias("lottother:lteems_off", "lottother:lteems")
minetest.register_alias("lottother:ltee_trader_2_ms_on", "lottother:ltee_trader_2_ms")
minetest.register_alias("lottother:ltee_trader_2_ms_off", "lottother:ltee_trader_2_ms")
minetest.register_alias("lottother:ltee_trader_3_ms_on", "lottother:ltee_trader_3_ms")
minetest.register_alias("lottother:ltee_trader_3_ms_off", "lottother:ltee_trader_3_ms")
minetest.register_alias("lottother:elfms_on", "lottother:elfms")
minetest.register_alias("lottother:elfms_off", "lottother:elfms")
minetest.register_alias("lottother:mordorms_on", "lottother:mordorms")
minetest.register_alias("lottother:mordorms_off", "lottother:mordorms")
