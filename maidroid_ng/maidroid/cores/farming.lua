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

ll = function(msg)
	pre="**************************************************"
	pre="++++++++++++++++++++++++++++++++++++++++++++++++++"
	if msg == nil then
		msg = "null"
	end

	minetest.log("warning", pre..msg)
end

ld = function(msg, dest)
	if (dest ~= nil) then
		local destnode = minetest.get_node(dest)
		ll(msg.." "..destnode.name)
	end
	
end

-- ,,x1
local function extract_before_underscore(str)
    -- return str:match("([^_]*)")
    return str:match("(.*)_[0-9]+")
end

if farming_redo then
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
	local plant_list = { "cotton", "wheat" }
	local crop
	for _, plantname in ipairs(plant_list) do
		crop = "farming:" .. plantname .. "_1"
		mature_plants["farming:" .. plantname .. "_8"] = {chance=1,crop=crop}
		seeds["farming:seed_" .. plantname] = crop
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
		ll("name: "..name.." name: "..name)
		return true
	end

	-- ll(name)
	local trim_name = extract_before_underscore(name)
	-- ll("PRE     name: "..name.." trim name: "..trim_name)
	-- ll(tm)

	if trim_name ~= nil then 
		if string.find(trim_name, "grass") then
			ll("name: "..name.." trim name: "..trim_name)
		end
		local weed = weed_plants[trim_name]
		if weed ~= nil then
			ll("weed found: "..trim_name)
			-- ll(weed)
			return true
		end		
	-- else
	-- 	ll("Error extracting node name:"..name)
	end
	return false

end

-- is_mowable reports whether maidroid can mow.,,mo
is_mowable = function(pos, name)
	if minetest.is_protected(pos, name) then
		return false
	end

	local node = minetest.get_node(pos)
	local desc = mature_plants[node.name]

	-- local tm = extract_before_underscore(node.name)
	-- ll(tm)

	-- if tm ~= nil then 
	-- 	if string.find(tm, "grass") then
	-- 		ll(node.name)
	-- 	end
	-- end

	-- local weed = weed_plants[tm]
	-- if weed ~= nil then
	-- 	ll(tm)
	-- 	-- ll(weed)
	-- 	return true
	-- end

	if is_weed(node.name) then
		return true
	end


	if desc == nil then
		return false
	end
	return math.random(desc.chance) == 1
end

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
	local support

	self.selected_seed = nil
	for _, stack in pairs(self:get_inventory():get_list("main")) do
		if not stack:is_empty() and is_seed(stack:get_name()) then
			support = supports[stack:get_name()]
			if not support or self:get_inventory():contains_item("main", support) then
				self.selected_seed = stack:get_name()
				return true
			end
		end
	end

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
	if not destination then return end

	local pos = self:get_pos()
	-- Is this droid able to make an action
	if position_ok(pos, destination) then
		self.destination = destination
		self.action = action
		to_action(self)
		return true
	end

	-- Or does the droid have to follow a path
	local path = minetest.find_path(pos, destination, 8, 1, 1, "A*_noprefetch")
	if path ~= nil then
		core_path.to_follow_path(self, path, destination, to_action, action)
		return true
	end
end

task = function(self)
	local pos = self:get_pos()
	local inv = self:get_inventory()
	local dest = search(pos, is_plantable, self.owner)
	if dest then
		-- local destnode = minetest.get_node(dest)
		-- ll("task::isdest = "..destnode.name)
		-- ld("task::isdest", dest)
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
	dest = search(pos, is_mowable, self.owner)
	ld("task::mow section", dest)
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
	return seeds[name] ~= nil
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
	-- Skip until timer is ok
	-- ,,xx,,cc
	-- if update_action_timers(self, dtime, self.selected_tool) then return end
	ll("mow")
	local destnode = minetest.get_node(self.destination)
	local mature = destnode.name
	local stacks

	if not mature_plants[mature] and not is_weed(mature) then
		to_wander(self, 0, timers.change_dir_max )
		return
	end -- target node changed

	if is_scythe(self.selected_tool) then -- Fast tool for farmers
		local name = mature_plants[mature].crop
		local p2 = minetest.registered_nodes[name].place_param2 or 1
		local filters = mature
		stacks = {}
		if farming_redo and mature:sub(1,-2) == "farming:pepper_" then
			filters = { "farming:pepper_5", "farming:pepper_6", "farming:pepper_7" }
		end -- Treat pepper as a special case
		local nodes = minetest.find_nodes_in_area(
			vector.add(self.destination, {x=-1,y=-1,z=-1}),
			vector.add(self.destination, {x=1, y=1, z=1}),
			filters
		) -- Find connected nodes matching this mature plant

		local count = 0
		local ok = false
		local drops
		for _, pos in ipairs(nodes) do
			if ok and count == 4 then -- Scythes treats 5 plants at most
				break
			end
			if	ok or -- Target node already harvested
				count < 4 or -- Slot still available for target
				pos == self.destination then -- Always for target
				if filters ~= mature then -- This pepper is hot
					drops = minetest.get_node_drops(minetest.get_node(pos).name)
				else
					drops = minetest.get_node_drops(mature)
				end
				table.insert_all(stacks, drops) -- Save the drops
				minetest.set_node(pos, { name = name, param2 = p2 } )
				count = count + 1
			end
			if pos == self.destination then
				count = count - 1
				ok = true
			end
		end
	else -- Normal mode
		stacks = minetest.get_node_drops(mature)
		minetest.remove_node(self.destination)
	end
	if maidroid.settings.farming_sound then
		maidroid.helpers.emit_sound(mature, "default_dig_snappy", "dig", self.destination, 0.8)
	end
	self:add_items_to_main(stacks)
	to_wander(self, 0, timers.change_dir_max )
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

on_step = function(self, dtime, moveresult)
	-- When owner offline mode disabled and if owner didn't login, the maidroid does nothing.
	if maidroid.settings.farming_offline == false
		and not minetest.get_player_by_name(self.owner) then
		return
	end

	-- Pickup surrounding items
	self:pickup_item()

	if self.state == maidroid.states.WANDER then
		wander_core.on_step(self, dtime, moveresult, task, maidroid.helpers.is_fence, true)
	elseif self.state == maidroid.states.PATH then
		maidroid.cores.path.on_step(self, dtime, moveresult)
	elseif self.state == maidroid.states.ACT then
		self.action(self, dtime)
	end
end

is_scythe = function(name)
	return name == "farming:scythe_mithril"
		or minetest:get_item_group(name, "scythe") > 0
end

is_tool = function(stack)
	-- ll("farming:is_tool  ")
	local name = stack:get_name()
	return minetest.get_item_group(name, "hoe") > 0
		or is_scythe(name)
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
	on_step		= on_step,
	is_tool		= is_tool,
	alt_tool	= select_seed,
	toggle_jump = true,
	walk_max = 2.5 * timers.walk_max,
	hat = hat,
	can_sell = true,
	doc = doc,
})
maidroid.new_state("ACT")

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
