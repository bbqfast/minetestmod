------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyright (c) 2020 IFRFSX.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator

local timers = maidroid.timers

-- Core interface functions
local on_start, on_pause, on_resume, on_stop, on_step, is_tool

-- Core extra functions
local plant, mow, collect_papyrus, plant_papyrus, to_action
local craft_seeds, select_seed, task, task_base
local is_seed, is_plantable, is_papyrus, is_papyrus_soil, is_mowable, is_scythe

local wander_core =  maidroid.cores.wander
local to_wander = wander_core.to_wander
local core_path = maidroid.cores.path

local search = maidroid.helpers.search_surrounding

local mature_plants = {}
local weed_plants = {}
local seeds = {}

local farming_redo = farming and farming.mod and farming.mod == "redo"

-- local lottfarming_on = lottfarming

-- check if lottfarming is installed, and set a flag
local lottfarming_on = false

if minetest.get_modpath("lottfarming") then
    lottfarming_on=true
end

local ll = function(msg)
	local pre="**************************************************"
	local pre="++++++++++++++++++++++++++++++++++++++++++++++++++"
	-- local pre="llllllllllllllllllllllllllllllllll "
	if msg == nil then
		msg = "null"
	end

	minetest.log("warning", pre..msg)
end

local lf = maidroid.lf

-- ,,x1
local function extract_before_underscore(str)
    -- return str:match("([^_]*)")
    return str:match("(.*)_[0-9]+")
end

weed_plants["default:grass"] = {chance=1, crop="default:grass_1"}
weed_plants["default:marram_grass"] = {chance=1, crop="default::marram_grass_1"}
-- Pepper can be harvested when green or yellow too
mature_plants["farming:pepper_7"] = {chance=1, crop="farming:pepper_1"}
mature_plants["farming:pepper_6"] = {chance=3, crop="farming:pepper_1"}
mature_plants["farming:pepper_5"] = {chance=9, crop="farming:pepper_1"}
if farming_redo then
	lf("[maidroid:farming]", "Detected farming redo, using registered_plants")
	local mature, crop
	for _, v in pairs(farming.registered_plants) do
		if v.steps then -- happens with mods like: "resources crops"
			--[IFRFSX] replace k to v.crop,this is plant's real name.
			mature = v.crop .. "_" .. v.steps
			crop = v.crop .. "_1"
			mature_plants[mature] = {chance=1, crop=crop}
			seeds[v.seed] = v.crop .. "_1"
			-- ll("mature: "..mature.." crop: "..mature_plants[mature].crop)
		end
	end

	-- ,,plant list
	mature_plants["default:grass_3"] = {chance=1, crop="default:grass_1"}

	weed_plants["default:grass"] = {chance=1, crop="default:grass_1"}
	weed_plants["default:marram_grass"] = {chance=1, crop="default::marram_grass_1"}
	-- Pepper can be harvested when green or yellow too
	mature_plants["farming:pepper_7"] = {chance=1, crop="farming:pepper_1"}
	mature_plants["farming:pepper_6"] = {chance=3, crop="farming:pepper_1"}
	mature_plants["farming:pepper_5"] = {chance=9, crop="farming:pepper_1"}
	if not maidroid.mods.sickles then
		maidroid.register_tool_rotation("farming:scythe_mithril", vector.new(-75,45,-45))
	end
else
	lf("[maidroid:farming]", "Using default farming (not redo)")
	local plant_list = { "cotton", "wheat" }
	local crop
	for _, plantname in ipairs(plant_list) do
			crop = "farming:" .. plantname .. "_1"
			mature_plants["farming:" .. plantname .. "_8"] = {chance=1,crop=crop}
			seeds["farming:seed_" .. plantname] = crop
			lf("[maidroid:farming]", "Added " .. plantname .. "_8 to mature_plants")
	end

	if maidroid.mods.better_farming then
		local mature, seed
		for _, def in ipairs(better_farming.plant_infos) do
			crop = def[1] .. "1"
			mature = def[1] .. def[2]
			seed = def[3]
			mature_plants[mature] = {chance=1, crop=crop}
			seeds[seed] = crop
		end
	end
end

if lottfarming_on then
	seeds["lottfarming:cabbage_seed"]= "lottfarming:cabbage_1"
	seeds["lottfarming:melon_seed"]= "lottfarming:melon_1"
	seeds["lottfarming:turnips_seed"]= "lottfarming:turnips_1"
	seeds["lottfarming:tomatoes_seed"]= "lottfarming:tomatoes_1"
	seeds["lottfarming:berries_seed"]= "lottfarming:berries_1"
	seeds["lottfarming:potato_seed"]= "lottfarming:potato_1"
	seeds["lottfarming:barley_seed"]= "lottfarming:barley_1"
	seeds["lottfarming:athelas_seed"]= "lottfarming:athelas_1"
	seeds["lottfarming:pipeweed_seed"]= "lottfarming:pipeweed_1"	
	-- [plant_name_without_steps
	mature_plants["lottfarming:cabbage_3"] = {chance=1, crop="lottfarming:cabbage_1"}
	mature_plants["lottfarming:melon_3"] = {chance=1, crop="lottfarming:melon_1"}
	mature_plants["lottfarming:turnips_4"] = {chance=1, crop="lottfarming:turnips_1"}
	mature_plants["lottfarming:tomatoes_4"] = {chance=1, crop="lottfarming:tomatoes_1"}
	mature_plants["lottfarming:berries_4"] = {chance=1, crop="lottfarming:berries_1"}
	mature_plants["lottfarming:potato_3"] = {chance=1, crop="lottfarming:potato_1"}
	mature_plants["lottfarming:barley_3"] = {chance=1, crop="lottfarming:barley_1"}
	mature_plants["lottfarming:athelas_3"] = {chance=1, crop="lottfarming:athelas_1"}
	mature_plants["lottfarming:pipeweed_4"] = {chance=1, crop="lottfarming:pipeweed_1"}	
end

lf("[maidroid:farming]", "Registered mature plants:")
for plant_name, plant_def in pairs(mature_plants) do
	lf("[maidroid:farming]", "  " .. plant_name .. " -> " .. plant_def.crop)
end
-- raise_error("maidroid:farming")

local ethereal_plants={}
if maidroid.mods.ethereal then
	-- [plant_name_without_steps]= { seed = "seed_name", step = int_step }
	ethereal_plants["ethereal:strawberry"] = {seed = "ethereal:strawberry", step = 8}
	ethereal_plants["ethereal:onion"] = {seed = "ethereal:wild_onion_plant", step = 5}

	for name, def in pairs(ethereal_plants) do
		local mature = name .. "_" .. def.step
		local crop = name .. "_1"
		mature_plants[mature] = {chance=1,crop=crop}
		seeds[def.seed] = crop
	end
end

if maidroid.mods.cucina_vegana then
	local germ
	if farming_redo then
		germ = tonumber(cucina_vegana.plant_settings.germ_launch)
		if germ == 0 then
			germ = 1
		end
	end

	for _, val in ipairs(cucina_vegana.plant_settings.bonemeal_list) do
		-- val1: plantname_, val[2]: steps, val[3]: seed
		local crop = farming_redo and val[1] .. germ or val[3]
		mature_plants[val[1] .. val[2]] = {chance=1,crop=crop}
		seeds[val[3]] = crop
	end
end

-- is_plantable reports whether maidroid can plant any seed.
-- ,,isp
is_plantable = function(pos, name)
	if minetest.is_protected(pos, name) then
		return false
	end
	local node = minetest.get_node(pos)
	local lpos = vector.add(pos, {x = 0, y = -1, z = 0})
	local lnode = minetest.get_node(lpos)

	-- minetest.set_node(self.destination, { name = "default:papyrus" })

	
	-- ,,x1
	-- minetest.log("warning", "xxxxx"..lnode.name)

	-- if lnode.name == "default:dirt_with_grass" or lnode.name == "default:dirt" then 
	-- 	minetest.set_node(lpos, { name = "farming:soil" })
	-- end
	
	return node.name == "air"
		and (minetest.get_item_group(lnode.name, "soil") > 1 or lnode.name == "default:dirt_with_grass" or lnode.name == "default:dirt")
end

is_weed = function(name)
	if name == nil then
		return false
	end

	if string.find(name, "flower") then
		-- lf("is_weed", "name: "..name.." name: "..name)
		return true
	end

	-- ll(name)
	local trim_name = extract_before_underscore(name)
	-- ll("PRE     name: "..name.." trim name: "..trim_name)
	-- ll(tm)

	if trim_name ~= nil then 
		if string.find(trim_name, "grass") then
			lf("is_weed", "name: "..name.." trim name: "..trim_name)
		end
		local weed = weed_plants[trim_name]
		if weed ~= nil then
			-- lf("is_weed", "weed found: "..trim_name)
			-- ll(weed)
			return true
		end		
	else
		-- lf("is_weed", "Error extracting node name:"..name)
	end
	return false

end

-- is_mowable reports whether maidroid can mow
is_mowable = function(pos, name)
	if minetest.is_protected(pos, name) then
		return false
	end
	
	local node = minetest.get_node(pos)
	local desc = mature_plants[node.name]
	local is_weed = is_weed(node.name)
	
	-- Return true only if this is a mature plant or weed
	return desc ~= nil or is_weed
end

is_seed = function(name)
	if name == nil then
		return false
	end
	if seeds[name] ~= nil then
		return true
	end
	return false
end

-- 	if minetest.is_protected(pos, name) then
-- 		return false
-- 	end

-- 	local node = minetest.get_node(pos)
-- 	local desc = mature_plants[node.name]

-- 	-- ll("is_mowable "..node.name)
-- 	local tm = extract_before_underscore(node.name)
-- 	-- ll(tm)

-- 	if tm ~= nil then 
-- 		-- if string.find(tm, "grass") then
-- 		if string.find(node.name, "grass") then
-- 			ll("is_mowable node="..node.name)
-- 			ll("is_mowable raw naem="..tm)
-- 		end
-- 	end

-- 	local weed = weed_plants[tm]
-- 	if weed ~= nil then
-- 		-- ll(tm)
-- 		ll("This is weed: "..weed)
-- 		return true
-- 	end

-- 	if is_weed(node.name) then
-- 		return true
-- 	end


-- 	if desc == nil then
-- 		return false
-- 	end
-- 	return math.random(desc.chance) == 1
-- end

local papyrus_neighbors = {}
papyrus_neighbors["default:dirt"] = true
papyrus_neighbors["default:dirt_with_grass"] = true
papyrus_neighbors["default:dirt_with_dry_grass"] = true
papyrus_neighbors["default:dirt_with_rainforest_litter"] = true
papyrus_neighbors["default:dry_dirt"] = true
papyrus_neighbors["default:dry_dirt_with_dry_grass"] = true

is_papyrus = function(pos, name)
	if minetest.is_protected(pos, name) then
		return false
	end

	local node = minetest.get_node(pos)
	if node.name ~= "default:papyrus" then
		return false
	end
	node = minetest.get_node(vector.add(pos, {x=0, y=1, z=0}))
	if node.name ~= "default:papyrus" then
		return false
	end
	node = minetest.get_node(vector.add(pos, {x=0, y=-1, z=0}))
	if papyrus_neighbors[node.name] then
		return true
	end
	return false
end

is_papyrus_soil = function(pos, name)
	if minetest.is_protected(pos, name) then
		return false
	end

	local n_name = minetest.get_node(pos).name
	if n_name ~= "air" then
		return false
	end -- Target is air
	n_name = minetest.get_node(vector.add(pos, {x=0, y=1, z=0})).name
	if n_name ~= "air" then
		return false
	end -- Node over target is air too
	n_name = minetest.get_node(vector.add(pos, {x=0, y=-1, z=0})).name
	if not papyrus_neighbors[n_name] then
		return false
	end -- Node under target is valid papyrus soil
	if not minetest.find_node_near(pos, 3, {"group:water"}) then
		return false
	end -- The papyrus will be able to grow
	return true
end

local supports = {}
if farming_redo then
	supports["farming:beans"] = "farming:beanpole"
	supports["farming:grapes"] = "farming:trellis"
end

-- select_seed select the first available seed stack
select_seed = function(self)
	local inv = self:get_inventory()
	local support

	self.selected_seed = nil
	lf("select_seed", "starting for owner=" .. tostring(self.owner))

	local list = inv:get_list("main") or {}
	for idx, stack in ipairs(list) do
		if not stack:is_empty() then
			local name = stack:get_name()
			lf("select_seed", "checking slot " .. tostring(idx) .. " item='" .. tostring(name) .. "'")
			if is_seed(name) then
				support = supports[name]
				if support then
					lf("select_seed", "seed '" .. name .. "' requires support '" .. support .. "'; checking inventory")
					if inv:contains_item("main", support) then
						lf("select_seed", "support '" .. support .. "' available, selecting seed '" .. name .. "'")
						self.selected_seed = name
						return true
					else
						lf("select_seed", "support '" .. support .. "' NOT available for seed '" .. name .. "'")
					end
				else
					lf("select_seed", "seed '" .. name .. "' requires no support, selecting")
					self.selected_seed = name
					return true
				end
			end
		end
	end

	lf("select_seed", "no suitable seed found")
	if self.state ~= maidroid.states.WANDER then
		to_wander(self)
	end
end

on_start = function(self)
	self.path = nil
	wander_core.on_start(self)
end

on_resume = function(self)
	self.path = nil
	wander_core.on_resume(self)
end

on_stop = function(self)
	self.path = nil
	wander_core.on_stop(self)
end

on_pause = function(self)
	wander_core.on_pause(self)
end

local position_ok = function(pos, to)
	local dist = vector.distance(pos, to)
	if dist < 1 then return to end -- Always good

	local from = vector.round(vector.copy(pos))
	-- Node directly under must be pumpkin or watermelon
	if to.x == from.x and to.z == from.z and to.y == from.y - 1 then
		return to
	end

	-- Skip when inside block
	local node = minetest.get_node(from)
	node = minetest.registered_nodes[node]
	if  node and node.buildable_to and
		( ( from.y == to.y and dist < 1.41 ) or
		( from.y ~= to.y and dist < 1.73 ) ) then
		return to
	end
end

task_base = function(self, action, destination)
	if not destination then 
		lf("[maidroid:farming]", "task_base: no destination")
		return 
	end

	-- lf("[maidroid:farming]", "task_base: destination=" .. minetest.pos_to_string(destination) .. " action=" .. tostring(action))
	local pos = self:get_pos()
	-- lf("[maidroid:farming]", "task_base: current pos=" .. minetest.pos_to_string(pos))
	
	-- Is this droid able to make an action
	if position_ok(pos, destination) then
		-- lf("[maidroid:farming]", "task_base: position ok, setting action")
		self.destination = destination
		self.action = action
		to_action(self)
		return true
	end

	-- Or does the droid have to follow a path
	-- lf("[maidroid:farming]", "task_base: finding path from " .. minetest.pos_to_string(pos) .. " to " .. minetest.pos_to_string(destination))
	local path = minetest.find_path(pos, destination, 8, 1, 1, "A*_noprefetch")
	if path ~= nil then
		-- lf("[maidroid:farming]", "task_base: path found with " .. #path .. " nodes")
		core_path.to_follow_path(self, path, destination, to_action, action)
		return true
	else
		lf("[maidroid:farming]", "task_base: NO PATH FOUND")
	end
end

is_valid_soil = function(name)
	if not name then return false end
	if name == "default:dirt_with_grass"
		or name == "default:dirt"
		or name == "lottmapgen:ltee_grass"
		or name == "lottmapgen:gondor_grass" then
		return true
	end
	-- Also accept any node whose name contains "soil"
	if string.find(name, "soil") or string.match(name, "_grass$") then
		return true
	end
		

	return false
end
	task = function(self)
		local pos = self:get_pos()
		local inv = self:get_inventory()
		-- ,,x1

		lpos = vector.add(pos, {x=0, y=-1, z=0})
		local lnode = minetest.get_node(lpos)
		local cnode = minetest.get_node(pos)

		-- Log node names under and at current position for debugging
		local lname = lnode and lnode.name or "nil"
		local cname = cnode and cnode.name or "nil"
		minetest.log("warning", "task() [maidroid:farming] lnode=" .. lname .. " cnode=" .. cname)

		-- error("dummy error")
		if cnode.name == "air" and is_valid_soil(lnode.name) then
			lf("task", "Convert dirt to soil at "..minetest.pos_to_string(lpos))
			lf("task", "Before: "..cnode.name)
			minetest.set_node(lpos, { name = "farming:soil" })
        else
            lf("task", "cannot CONVERT: "..lnode.name)
		end


		-- Ensure there is water within 3 nodes horizontally on the same y as lpos; if not, try to place a water source nearby
		-- only if LT on standing soil
		if lnode.name ~= "air" and cnode.name == "air" then
			lf("task", "SPOT FOR WATER Checking for water near "..minetest.pos_to_string(lpos))
			local water_found = false
			for dx = -3, 3 do
				if water_found then break end
				for dz = -3, 3 do
					local p = vector.add(lpos, { x = dx, y = 0, z = dz }) -- keep same y as lpos
					local nodename = minetest.get_node(p).name
					if nodename == "default:water_source" or minetest.get_item_group(nodename, "water") > 0 then
						water_found = true
						break
					end
				end
			end

			if not water_found then
				local under_name = minetest.get_node(lpos).name
				-- If the node under is dirt/soil, place a water source (unless protected)
				if is_valid_soil(under_name) or minetest.get_item_group(under_name, "soil") > 0 then
					if not minetest.is_protected(lpos, self.owner) then
						minetest.set_node(lpos, { name = "default:water_source" })
						water_found = true
						lf("task", "Placed water at "..minetest.pos_to_string(lpos).." (converted soil to water)")
					else
						lf("task", "Cannot place water at "..minetest.pos_to_string(lpos).." - protected")
					end
				end
			end
		end
		-- if not water_found then
		-- 	ll("No water found near " .. minetest.pos_to_string(lpos) .. " on same y, attempting to place water at lpos or nearby")
		-- 	local placed = false
		-- 	local owner = self.owner

		-- 	-- Try current lpos first, then nearby positions within a small radius
		-- 	local candidates = {}
		-- 	table.insert(candidates, vector.new(lpos))
		-- 	for dx = -1, 1 do
		-- 		for dz = -1, 1 do
		-- 			local p = vector.add(lpos, { x = dx, y = 0, z = dz })
		-- 			-- avoid duplicating lpos
		-- 			if not (p.x == lpos.x and p.y == lpos.y and p.z == lpos.z) then
		-- 				table.insert(candidates, p)
		-- 			end
		-- 		end
		-- 	end

		-- 	for _, p in ipairs(candidates) do
		-- 		if placed then break end
		-- 		local pstr = minetest.pos_to_string(p)
		-- 		if minetest.is_protected(p, owner) then
		-- 			ll("Position " .. pstr .. " is protected for owner " .. tostring(owner) .. ", skipping")
		-- 		else
		-- 			local nodename = minetest.get_node(p).name
		-- 			-- If it's already water, consider success and stop
		-- 			if nodename == "default:water_source" or minetest.get_item_group(nodename, "water") > 0 then
		-- 				ll("Found existing water at " .. pstr .. " (" .. nodename .. ")")
		-- 				placed = true
		-- 				break
		-- 			end
		-- 			local rnode = minetest.registered_nodes[nodename]
		-- 			-- Allow placement on air, buildable_to nodes, or replaceable soil (so we don't overwrite important nodes)
		-- 			if nodename == "air" or (rnode and rnode.buildable_to) or minetest.get_item_group(nodename, "soil") > 0 then
		-- 				minetest.set_node(p, { name = "default:water_source" })
		-- 				placed = true
		-- 				ll("Placed water at " .. pstr .. " (replaced " .. tostring(nodename) .. ")")
		-- 				break
		-- 			else
		-- 				ll("Node at " .. pstr .. " (" .. tostring(nodename) .. ") is not suitable for placement")
		-- 			end
		-- 		end
		-- 	end

		-- 	if not placed then
		-- 		ll("Attempted all candidate positions but failed to place water near " .. minetest.pos_to_string(lpos))
		-- 	else
		-- 		ll("Successfully ensured water near " .. minetest.pos_to_string(lpos))
		-- 	end
		-- else
		-- 	ll("Water already present near " .. minetest.pos_to_string(lpos) .. ", no placement needed")
		-- end

		local dest = search(pos, is_plantable, self.owner)
		if dest then
			-- local destnode = minetest.get_node(dest)
			if not ( self.selected_seed and							-- Is there already a selected seed
				inv:contains_item("main", self.selected_seed)) then -- in inventory
				if not select_seed(self) then						-- Try to find a seed in inventory
					craft_seeds(self)								-- Craft seeds if none
				end -- TODO delay crafting
			end
			-- Planting
			if self.selected_seed and
				task_base(self, plant, dest) then
				return
			end
		end

		-- Harvesting
		lf("[maidroid:farming]", "Searching for mowable plants near " .. minetest.pos_to_string(pos))
		dest = search(pos, is_mowable, self.owner)
		if dest then
			lf("[maidroid:farming]", "Found mowable plant at " .. minetest.pos_to_string(dest))
		else
			lf("[maidroid:farming]", "No mowable plants found")
		end
		if task_base(self, mow, dest) then
			return
		end

		-- Plant papyrus
		if not is_scythe(self.selected_tool) then
			dest = search(pos, is_papyrus_soil, self.owner)
			if inv:contains_item("main", "default:papyrus")
				and task_base(self, plant_papyrus, dest) then
				return
			end
		end

		-- Harvest papyrus
		dest = search(pos, is_papyrus, self.owner)
		task_base(self, collect_papyrus, dest)
	end

is_seed = function(name)
	if name == nil then
		-- ll("is_seed: name is nil")
		return false
	end
	local ok = seeds[name] ~= nil
	-- ll("is_seed >>>>  : checking '" .. tostring(name) .. "' -> " .. tostring(ok))
	return ok
end

local seed_recipes = {}
if farming_redo then
	-- Notice: Keep seed and replacement switched for pineapple
	seed_recipes["farming:garlic"]        = { count = 8, seed = "farming:garlic_clove" }
	seed_recipes["farming:melon_8"]       = { count = 4, seed = "farming:melon_slice" }
	seed_recipes["farming:pepper"]        = { count = 1, seed = "farming:peppercorn" }
	seed_recipes["farming:pepper_yellow"] = { count = 1, seed = "farming:peppercorn" }
	seed_recipes["farming:pepper_red"]    = { count = 1, seed = "farming:peppercorn" }
	seed_recipes["farming:pineapple"]     = { count = 5, seed = "farming:pineapple_ring" }
	seed_recipes["farming:pumpkin_8"]     = { count = 4, seed = "farming:pumpkin_slice" }
	seed_recipes["farming:sunflower"]     = { count = 5, seed = "farming:seed_sunflower" }

	seed_recipes["farming:melon_8"].tool          = "farming:cutting_board"
	seed_recipes["farming:pineapple"].replacement = "farming:pineapple_top"
	seed_recipes["farming:pumpkin_8"].tool        = "farming:cutting_board"
end

-- Maximal stuff used for recipe
for plantname, rules in pairs(seed_recipes) do
	local stack = ItemStack(plantname)
	local max = stack:get_stack_max()
	rules.remove = math.floor(max / rules.count)
end

craft_seeds = function(self)
	-- Scythes do not require seeds
	if is_scythe(self.selected_tool) then
		return
	end

	local inv = self:get_inventory()
	local stack, name, count, rules

	-- Does inventory contains any valid recipe to make seeds
	for _, inv_stack in pairs(inv:get_list("main")) do
		name = inv_stack:get_name()
		rules = seed_recipes[name]

		if rules and ( not rules.tool or
			inv:contains_item("main", rules.tool) ) then
			break
		end
	end
	if not rules then return end -- No recipe matched

	-- Remove used things from inventory
	stack = inv:remove_item("main", ItemStack(name .. " " .. rules.remove))
	count = stack:get_count()

	if count == 0 then return end -- Nothing was used

	-- Prepare output and store in inventory
	stack = { ItemStack(rules.seed .. " " .. count * rules.count) }
	if rules.replacement then
		table.insert(stack, ItemStack(rules.replacement .. " " .. count))
	end
	self:add_items_to_main(stack)
	-- NOTICE highly care about this when add new seed_recipes
	self.selected_seed = rules.replacement or rules.seed
end

to_action = function(self)
	self.state = maidroid.states.ACT
	self.timers.action = 0
	self.timers.walk = 0
end

local place_plant_support = function(self, plantname)
	local support = supports[plantname]
	if not support then
		return true
	end

	local inv = self:get_inventory()
	local stack = ItemStack(support)
	stack = inv:remove_item("main", stack)
	if stack:get_count() == 0 then
		return false
	end
	return true
end

local freeze_action = function(self, toolname)
	-- Check tool was not removed from inventory
	if not toolname or not self:get_inventory():contains_item("main", toolname) then
		self.need_core_selection = true
		return true
	end
	self:set_tool(toolname)
	self:halt()
	self:set_animation(maidroid.animation.MINE)
	self:set_yaw({self:get_pos(), self.destination})
end

local update_action_timers = function(self, dtime, toolname)
	if self.timers.action < timers.action_max then
		if self.timers.action == 0 then
			if freeze_action(self, toolname) then
				return true
			end
		end
		self.timers.action = self.timers.action + dtime
		return true
	end
	return false
end

plant = function(self, dtime)
	-- Skip until timer is ok

	pos = self.destination

	local lpos = vector.add(pos, {x = 0, y = -1, z = 0})
	local lnode = minetest.get_node(lpos)
	local lnode = minetest.get_node(lpos)


	minetest.set_node(lpos, { name = "farming:soil" })
	
	-- minetest.set_node(self.destination, { name = "default:papyrus" })

	
	-- ,,x1
	-- minetest.log("warning", "xxxxx"..lnode.name)

	-- if lnode.name == "default:dirt_with_grass" or lnode.name == "default:dirt" then 
	-- 	minetest.set_node(lpos, { name = "farming:soil" })
	-- end


	if update_action_timers(self, dtime, self.selected_seed) then return end

	if	not place_plant_support(self, self.selected_seed) then
		select_seed(self)
		return
	end

	if	not is_plantable(self.destination, self.owner) then
		to_wander(self, 0, timers.change_dir_max )
		self:set_tool(self.selected_tool)
		return
	end -- target node changed

	-- We can place plant
	local inv = self:get_inventory()
	local plantname = seeds[self.selected_seed] -- Lookup for a crop
	minetest.set_node(self.destination, { name = plantname,
		param2 = minetest.registered_nodes[plantname].place_param2 or 1 } )
	if maidroid.settings.farming_sound then
		maidroid.helpers.emit_sound(plantname, "default_place_node", "place", self.destination, 0.2)
	end
	if not farming_redo then
		minetest.get_node_timer(self.destination):start(math.random(166, 286))
	end

	inv:remove_item("main", ItemStack(self.selected_seed))

	-- Last selected seed used
	if not inv:contains_item("main", self.selected_seed) then
		select_seed(self)
	end

	to_wander(self, 0, timers.change_dir_max )
	self:set_tool(self.selected_tool)
end

mow = function(self, dtime)
	lf("[maidroid:farming]", "mow() called at destination " .. minetest.pos_to_string(self.destination))
	-- Skip until timer is ok
	if update_action_timers(self, dtime, self.selected_tool) then return end
	lf("mow", "start")

	local destnode = minetest.get_node(self.destination)
	local mature = destnode.name
	lf("mow2", "destination node = " .. tostring(mature) .. " at pos " .. minetest.pos_to_string(self.destination))

	local in_mature_list = mature_plants[mature] ~= nil
	local is_weed_here = is_weed(mature)
	lf("mow", "condition mature_plants[" .. tostring(mature) .. "] ~= nil = " .. tostring(in_mature_list))
	lf("mow", "condition is_weed(" .. tostring(mature) .. ") = " .. tostring(is_weed_here))
	
	if in_mature_list then
		lf("mow", "Found mature plant: " .. tostring(mature) .. " -> crop: " .. tostring(mature_plants[mature].crop))
	end

	if not in_mature_list and not is_weed_here then
		lf("mow", "early return (not mature and not weed)")
		to_wander(self, 0, timers.change_dir_max )
		return
	end -- target node changed

	local scythe_mode = is_scythe(self.selected_tool)
	lf("mow", "condition is_scythe(self.selected_tool) = " .. tostring(scythe_mode))

	if scythe_mode then -- Fast tool for farmers
		local name = mature_plants[mature].crop
		local p2 = minetest.registered_nodes[name].place_param2 or 1
		local filters = mature
		local stacks = {}
		lf("mow", "scythe mode: crop name = " .. tostring(name) .. ", p2 = " .. tostring(p2))

		local is_pepper_case = false
		if farming_redo and mature:sub(1, -2) == "farming:pepper_" then
			is_pepper_case = true
			filters = { "farming:pepper_5", "farming:pepper_6", "farming:pepper_7" }
		end
		lf("mow", "is_pepper_case = " .. tostring(is_pepper_case))
		lf("mow", "filters = " .. (type(filters) == "table" and table.concat(filters, ", ") or tostring(filters)))

		local nodes = minetest.find_nodes_in_area(
			vector.add(self.destination, {x=-1,y=-1,z=-1}),
			vector.add(self.destination, {x=1, y=1, z=1}),
			filters
		) -- Find connected nodes matching this mature plant
		lf("mow", "find_nodes_in_area returned " .. tostring(#nodes) .. " nodes")

		local count = 0
		local ok = false
		local drops
		for _, pos in ipairs(nodes) do
			local cond_break = ok and count == 4
			lf("mow", "loop pos=" .. minetest.pos_to_string(pos) .. " cond_break (ok and count==4) = " .. tostring(cond_break))
			if cond_break then -- Scythes treats 5 plants at most
				lf("mow", "breaking loop because cond_break true")
				break
			end

			local cond_do = ok or count < 4 or (pos.x == self.destination.x and pos.y == self.destination.y and pos.z == self.destination.z)
			lf("mow", "loop cond_do (ok or count<4 or pos==destination) = " .. tostring(cond_do) .. " (ok="..tostring(ok)..", count="..tostring(count)..", pos="..minetest.pos_to_string(pos)..")")

			if cond_do then
				local cond_pepper_filter = filters ~= mature
				lf("mow", "cond_pepper_filter (filters ~= mature) = " .. tostring(cond_pepper_filter))
				if cond_pepper_filter then -- This pepper is hot
					drops = minetest.get_node_drops(minetest.get_node(pos).name)
				else
					drops = minetest.get_node_drops(mature)
				end
				lf("mow", "drops for pos " .. minetest.pos_to_string(pos) .. " = " .. tostring(drops and #drops or 0))
				table.insert_all(stacks, drops) -- Save the drops
				minetest.set_node(pos, { name = name, param2 = p2 } )
				count = count + 1
				lf("mow", "after harvesting pos " .. minetest.pos_to_string(pos) .. " count = " .. tostring(count))
			end

			if pos.x == self.destination.x and pos.y == self.destination.y and pos.z == self.destination.z then
				count = count - 1
				ok = true
				lf("mow", "encountered target position, adjusted count = " .. tostring(count) .. ", ok set to true")
			end
		end

		if maidroid.settings.farming_sound then
			maidroid.helpers.emit_sound(mature, "default_dig_snappy", "dig", self.destination, 0.8)
			lf("mow", "played scythe sound for " .. tostring(mature))
		else
			lf("mow", "farming_sound disabled")
		end

		self:add_items_to_main(stacks)
		lf("mow", "added items to inventory (scythe mode), stacks count = " .. tostring(#stacks))
		to_wander(self, 0, timers.change_dir_max )
	else -- Normal mode
		lf("mow", "normal mode (not scythe)")
		local stacks = minetest.get_node_drops(mature)
		lf("mow", "node drops count = " .. tostring(#stacks))
		minetest.remove_node(self.destination)
		lf("mow", "removed node at destination")
		if maidroid.settings.farming_sound then
			maidroid.helpers.emit_sound(mature, "default_dig_snappy", "dig", self.destination, 0.8)
			lf("mow", "played normal dig sound for " .. tostring(mature))
		else
			lf("mow", "farming_sound disabled")
		end
		self:add_items_to_main(stacks)
		lf("mow", "added items to inventory (normal mode), stacks count = " .. tostring(#stacks))
		to_wander(self, 0, timers.change_dir_max )
	end
end

collect_papyrus = function(self, dtime)
	-- Skip until timer is ok
	if update_action_timers(self, dtime, self.selected_tool) then return end

	if not is_papyrus(self.destination) then
		to_wander(self, 0, timers.change_dir_max )
		return
	end -- target node changed

	local count = 0
	local pos = vector.add(self.destination, {x=0,y=1,z=0})
	while minetest.get_node(pos).name == "default:papyrus" do
		count = count + 1
		minetest.remove_node(pos)
		pos = vector.add(pos, {x=0,y=1,z=0})
	end

	if maidroid.settings.farming_sound then
		maidroid.helpers.emit_sound("default:papyrus", "default_dig_snappy", "dig", self.destination, 0.8)
	end
	self:add_items_to_main({"default:papyrus " .. count})
	to_wander(self, 0, timers.change_dir_max )
end

plant_papyrus = function(self, dtime)
	-- Skip until timer is ok
	if update_action_timers(self, dtime, "default:papyrus") then return end

	local inv = self:get_inventory()
	if not inv:contains_item("main", "default:papyrus")
		or not is_papyrus_soil(self.destination, self.owner) then
		to_wander(self, 0, timers.change_dir_max )
		return
	end -- target node changed

	minetest.set_node(self.destination, { name = "default:papyrus" })
	if maidroid.settings.farming_sound then
		maidroid.helpers.emit_sound("default:papyrus", "default_place_node", "place", self.destination, 0.2)
	end
	inv:remove_item("main", ItemStack("default:papyrus"))

	to_wander(self, 0, timers.change_dir_max )
	self:set_tool(self.selected_tool)
end

-- Check for fence detection failures
local check_fence_detection = function(self)
	local front = self:get_front()
	local below1 = vector.add(front, {x = 0, y = -1, z = 0})
	local below2 = vector.add(front, {x = 0, y = -2, z = 0})
	local pos_here = vector.round(self:get_pos())
	local pos_here_below = vector.add(pos_here, {x = 0, y = -1, z = 0})
	local n_front = minetest.get_node(front).name
	local n_below1 = minetest.get_node(below1).name
	local n_below2 = minetest.get_node(below2).name
	local n_here = minetest.get_node(pos_here).name
	local n_here_below = minetest.get_node(pos_here_below).name
	local has_fence = maidroid.helpers.is_fence(n_front)
		or maidroid.helpers.is_fence(n_below1)
		or maidroid.helpers.is_fence(n_below2)
		or maidroid.helpers.is_fence(n_here)
		or maidroid.helpers.is_fence(n_here_below)
	if has_fence and not self:is_blocked(maidroid.helpers.is_fence, true) then
		local pos = vector.round(self:get_pos())
		minetest.log("warning",
			"[maidroid fence debug] FAILED blocked detection (farming); self=" .. minetest.pos_to_string(pos) ..
			" front=" .. minetest.pos_to_string(front) ..
			" below1=" .. minetest.pos_to_string(below1) ..
			" below2=" .. minetest.pos_to_string(below2) ..
			" n_front=" .. n_front ..
			" n_below1=" .. n_below1 ..
			" n_below2=" .. n_below2 ..
			" n_here=" .. n_here ..
			" n_here_below=" .. n_here_below)
		if not self.pause and self.core and self.core.on_pause then
			self.core.on_pause(self)
			self.pause = true
		end
	end
end

on_step = function(self, dtime, moveresult)
	-- Pause if too far from home (more than 20 blocks)
	if self.home then
		local distance = vector.distance(self:get_pos(), self.home)
		if distance > 20 then
			if not self.pause then
				self.pause = true
				self._distance_paused = true
				if self.core and self.core.on_pause then
					self.core.on_pause(self)
				end
				minetest.log("warning", "farming maidroid paused: too far from home (" .. string.format("%.1f", distance) .. " blocks)")
			end
		else
			-- Resume if within range and currently paused for distance
			if self.pause and self._distance_paused then
				self.pause = false
				self._distance_paused = nil
				if self.core and self.core.on_resume then
					self.core.on_resume(self)
				end
				minetest.log("warning", "farming maidroid resumed: within range of home")
			end
		end
	end

	if self.pause then
		return
	end
	-- When owner offline mode disabled and if owner didn't login, the maidroid does nothing.
	if maidroid.settings.farming_offline == false
		and not minetest.get_player_by_name(self.owner) then
		return
	end

	-- Remember previous Y position for locking movement to a single plane
	local pos = self:get_pos()
	self._farming_prev_y = self._farming_prev_y or pos.y

	-- Pickup surrounding items
	self:pickup_item()

	-- Let wander core handle movement and task selection only
	-- when not currently performing an explicit action.
    -- this fixes the issue where the maidroid would not move when it was performing an action
	if self.state ~= maidroid.states.ACT then
		wander_core.on_step(self, dtime, moveresult, task, maidroid.helpers.is_fence, true)
		-- Check for fence detection failures
		check_fence_detection(self)
	end
	if self.state == maidroid.states.PATH then
		maidroid.cores.path.on_step(self, dtime, moveresult)
	elseif self.state == maidroid.states.ACT then
        -- lf("farming", "ACT state")
		self.action(self, dtime)
	end

	-- After movement has been processed, enforce Y-axis lock for farmers
	-- pos = self:get_pos()
	-- if pos.y ~= self._farming_prev_y then
	-- 	pos.y = self._farming_prev_y
	-- 	self.object:set_pos(pos)
	-- 	local v = self.object:get_velocity()
	-- 	if v then
	-- 		v.y = 0
	-- 		self.object:set_velocity(v)
	-- 	end
	-- end
end

is_scythe = function(name)
	return name == "farming:scythe_mithril"
		or minetest:get_item_group(name, "scythe") > 0
end

is_tool = function(stack)
	local name = stack:get_name()
	lf("[maidroid:farming]", "stack  "..name)
	local istool = minetest.get_item_group(name, "hoe") > 0
		or is_scythe(name)

	-- ll("farming:is_tool  "..istool)
	return istool
	-- return true
end

local hat
if maidroid.settings.hat then
	hat = {
		name = "hat_farming",
		mesh = "maidroid_hat_farming.obj",
		textures = { "maidroid_hat_farming.png" },
		offset = { x=0, y=0, z=0 },
		rotation = { x=0, y=0, z=0 },
	}
end

maidroid.cores.basic.doc = maidroid.cores.basic.doc .. "\t"
	.. S("Farmer: hoes or scythes") .. "\n"

local doc = S("Farmers can do much for you") .. "\n\n"
	.. S("Abilities:")
	.. "\t" .. S("Harvest farming plants") .. "\n"
	.. "\t" .. S("Harvest papyrus") .. "\n"
	.. "\t" .. S("Plant seeds") .. "\n"

if farming_redo then
	doc = doc
		.. "\t" .. S("Craft seeds") .. "\n"
		.. "\t\t" .. S("Garlic, Pepper, Sunflower") .. "\n"
		.. "\t\t" .. S("Melons: knife required") .. "\n"
		.. "\t\t" .. S("Pineapple: cut into slices and keep top") .. "\n"
end

doc = doc .. "\n"
	.. S("Near fences or panes they change direction" )

maidroid.register_core("farming", {
	description	= S("a farmer"),
	on_start	= on_start,
	on_stop		= on_stop,
	on_resume	= on_resume,
	on_pause	= on_pause,
	on_step	= on_step,
	is_tool		= is_tool,
	alt_tool	= select_seed,
	no_jump		= true,
	walk_max = 2.5 * timers.walk_max,
	hat = hat,
	can_sell = true,
	doc = doc,
})
maidroid.new_state("ACT")

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
