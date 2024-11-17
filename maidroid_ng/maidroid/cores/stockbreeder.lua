------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator

-- Core interface functions
local on_start, on_pause, on_resume, on_stop, on_step, is_tool

local wander =  maidroid.cores.wander

local known_shearable = {}
local known_milkable = {}
local known_killable = {}
local random_stack

maidroid.register_tool_rotation("bucket:bucket_empty", vector.new(-75, 0, -75))

local can_interact = function(droid, animal)
	return not animal.owner or animal.owner == "" or animal.owner == droid.owner
end

if maidroid.mods.petz then
	local test, action, foodtest, foodaction
	maidroid.register_tool_rotation("petz:shears", vector.new(-75, -45, -45))
	test = function(droid, animal)
		return not animal.is_male and not animal.is_baby and
			not animal.milked and can_interact(droid, animal)
	end
	action = function(_, animal)
		minetest.sound_play("petz_"..animal.type.."_moaning", {
			max_hear_distance = petz.settings.max_hear_distance,
			pos = animal.object:get_pos(),
			object = animal.object,
		})
		animal.food_count = kitz.remember(animal, "food_count", 0)
		animal.milked = kitz.remember(animal, "milked", true)
	end
	foodtest = function(_, animal) return animal.milked end
	foodaction = function(_,animal)
		animal.food_count = kitz.remember(animal, "food_count", animal.food_count + 1)
		kitz.heal(animal, animal.max_hp * petz.settings.tamagochi_feed_hunger_rate)
		petz.refill(animal)
	end
	known_milkable["petz:calf"] = { test = test, action = action, foodtest = foodtest, foodaction = foodaction, milk = "petz:bucket_milk" }
	known_milkable["petz:camel"] = { test = test, action = action, foodtest = foodtest, foodaction = foodaction, milk = "petz:bucket_milk" }
	known_milkable["petz:goat"] = { test = test, action = action, foodtest = foodtest, foodaction = foodaction, milk = "petz:bucket_milk" }
	test = function(droid, animal)
		return not animal.shaved and can_interact(droid, animal)
	end
	action = function(droid, animal)
		petz.lamb_wool_shave(animal, droid)
	end
	known_shearable["petz:lamb"] = { test = test, action = action }
	test = function(droid, animal)
		return can_interact(droid, animal)
	end
	action = function(droid, animal)
		local stacks = {}
		if animal.type ~= "ducky" then
			random_stack(stacks,"petz:raw_chicken", 3)
		else
			random_stack(stacks,"petz:ducky_feather ",3)
			random_stack(stacks,"petz:raw_ducky", 3)
		end
		random_stack(stacks,"petz:bone", 3)
		droid:add_items_to_main(stacks)
		kitz.clear_queue_high(animal)
		minetest.sound_play("petz_default_punch",
			{object = animal.object, gain = 0.5,
			max_hear_distance = petz.settings.max_hear_distance })
	end
	known_killable["petz:ducky"] = { test = test, action = action }
	known_killable["petz:hen"] = { test = test, action = action }
	known_killable["petz:chicken"] = { test = test, action = action }
	-- do not insert rooster as they will fight to death
end

if maidroid.mods.animalia then
	local test, action, foodtest, foodaction
	maidroid.register_tool_rotation("animalia:shears", vector.new(-75, -45, -45))
	test = function(droid, animal)
		return animal.growth_scale >= 1 and not animal.collected
			and can_interact(droid, animal)
	end
	action = function(_, animal)
		animal.collected = animal:memorize("collected", true)
	end
	foodtest = function() return true end
	foodaction = function(_, animal)
		animal.hp = math.max(animal.hp + animal.max_health / 5, animal.max_health)
		animal.feed_no = (animal.feed_no or 0) + 1
		if animal.feed_no >= 5 then
			animal.feed_no = 0
			animal._despawn = animal:memorize("_despawn", false)
			animal.despawn_after = animal:memorize("despawn_after", false)
		end
		-- NOTICE no breeding upstream yet
	end
	known_milkable["animalia:cow"] = { test = test, action = action, foodtest = foodtest, foodaction = foodaction, milk = "animalia:bucket_milk" }
	test = function(droid, animal)
		return animal.growth_scale > 0.9 and not animal.collected
			and can_interact(droid, animal)
	end
	action = function(droid, animal)
		droid:get_inventory():add_item("main", ItemStack("wool:white " .. math.random(1, 3)))
		animal.gotten = animal:memorize("collected", true)
		animal.dye_color = animal:memorize("dye_color", "white")
		animal.dye_hex = animal:memorize("dye_hex",  "#abababc000")
		animal.object:set_properties({ textures = {"animalia_sheep.png"}})
	end
	known_shearable["animalia:sheep"] = { test = test, action = action }
	test = function(droid, animal)
		return can_interact(droid, animal)
	end
	action = function(_, animal)
		minetest.sound_play("animalia_chicken_death",
			{object = animal.object, gain = 0.5,
			max_hear_distance = 8 })
		animal:initiate_utility("animalia:die", animal)
	end
	known_killable["animalia:chicken"] = { test = test, action = action }
	known_killable["animalia:turkey"] = { test = test, action = action }
end

if maidroid.mods.animal then
	local test, action, foodtest, foodaction
	maidroid.register_tool_rotation("mobs:shears", vector.new(-75, 45, -45))
	test = function(droid, animal)
		return not animal.child and not animal.gotten
			and can_interact(droid, animal)
	end
	action = function(_, animal)
		animal.gotten = true
	end
	foodtest = function() return true end
	foodaction = function(_, animal)
		animal.health = math.min(animal.hp_max, animal.health + 4)
		animal.food = (animal.food or 0) + 1
		if animal.food >= 8 then
			animal.food = 0
			animal.gotten = false
		end
	end
	known_milkable["mobs_animal:cow"] = { test = test, action = action, foodtest = foodtest, foodaction = foodaction, milk = "mobs:bucket_milk" }
	action = function(droid, animal)
		droid:add_items_to_main({ "wool:" .. known_shearable[animal.name].color .. " " .. math.random(1, 3) })
		animal.object:set_properties({ textures = {"mobs_sheep_shaved.png"}, mesh = "mobs_sheep_shaved.b3d"})
		animal.gotten = true
	end
	for _, color in ipairs(dye.dyes) do
		known_shearable["mobs_animal:sheep_"..color[1]] = { test = test, action = action, color = color[1] }
	end
	test = function() return true end
	action = function(droid, _)
		droid:add_items_to_main({ "mobs:chicken_raw",
			"mobs:chicken_feather " .. math.random(0,2)})
	end
	known_killable["mobs_animal:chicken"] = { test = test, action = action }
end

on_start = function(self)
	wander.on_start(self)
	self.timers.skip = 0
	self.job_pause = 0
end

on_resume = function(self)
	self:set_tool(self.selected_tool)
	self.timers.skip = 0
	self.job_pause = 0
	wander.on_resume(self)
end

on_stop = function(self)
	wander.on_stop(self)
	self.job_pause = nil
end

on_pause = function(self)
	wander.on_pause(self)
	self.job_pause = nil
end

is_tool = function(stack)
	local name = stack:get_name()
	for _, item in ipairs({"bucket:bucket_empty",
		"petz:shears", "mobs:shears", "animalia:shears"}) do
		if name == item then
			return true
		end
	end
	return false
end

local function set_animation_for_job(self, itemname, animal)
	self:set_animation(maidroid.animation.MINE)
	self:halt()
	self.job_pause = maidroid.settings.stockbreeder_pause
	self:set_tool(itemname)
	if animal then
		self:set_yaw({self:get_pos(),
			animal.object:get_pos()})
		self.target_obj = animal.object
	end
end

local function get_nearest_entity(self, names, radius)
	local pos = self:get_pos()
	local objects = minetest.get_objects_inside_radius(pos, radius)
	local dist, opos
	local ret = {}

	for _, obj in pairs(objects) do
		local entity = obj:get_luaentity()
		if  not obj:is_player() and entity
			and names[entity.name] then
			opos = obj:get_pos()
			dist = vector.distance(pos, opos)
			if dist < radius then
				table.insert(ret, {
					entity = entity,
					dist = dist,
					pos = opos })
			end
		end
	end

	table.sort(ret, function(a, b) return a.dist < b.dist end)

	while #ret > 0 do
		if minetest.find_path(ret[1].pos, pos, 2, 1, 2, "A*_noprefetch") then
			return ret[1].entity, ret
		end
		table.remove(ret, 1)
	end
end

-- Receive a list of objects and count matching ones in a list of name
local count_entities = function(list, names)
	local count = 0
	for _, t in ipairs(list) do
		for _, name in ipairs(names) do
			if t.entity.name == name then
				count = count + 1
				break
			end
		end
	end
	return count
end

local function select_follow_item(inv, animal)
	if not animal.follow then
		return -- Weird this animal can't be fed
	end

	local items = animal.follow
	if animal.name:sub(1,5) == "petz:" then
		items = animal.follow:gsub(" ", ""):split(",")
	end
	if not items then
		return
	end
	for _,item in ipairs(items) do
		if inv:contains_item("main", item) then
			return item
		end
	end
end

local function milk_cows(self)
	local animal = get_nearest_entity(self, known_milkable, 2.5)
	if not animal then
		return
	end
	local milkable = known_milkable[animal.name]

	-- Is animal ready to be milked
	local inv = self:get_inventory()
	if milkable.test(self, animal) and inv:contains_item("main", "bucket:bucket_empty") then
		inv:remove_item("main", ItemStack("bucket:bucket_empty"))
		if not inv:contains_item("main", "bucket:bucket_empty") then
			self.need_core_selection = true
		end

		set_animation_for_job(self, "bucket:bucket_empty", animal)
		self:add_items_to_main({milkable.milk})
		milkable.action(self, animal)
		return true
	end

	-- Can't milk => feed the animal
	local feed_item = select_follow_item(inv, animal)

	if feed_item and milkable.foodtest(self, animal) then
		set_animation_for_job(self, feed_item, animal)
		inv:remove_item("main", feed_item)
		milkable.foodaction(self, animal)
		return true
	end
end

local function shear_sheeps(self)
	local inv = self:get_inventory()
	local animal = get_nearest_entity(self, known_shearable, 2.5)
	local shears
	if self.selected_tool ~= "bucket:bucket_empty" then
		shears = self.selected_tool
	else
		for _, item in ipairs({ "petz:shears", "animalia:shears", "mobs:shears"}) do
			if inv:contains_item("main", item) then
				shears = item
				break
			end
		end
	end

	if not animal or not shears then
		return
	end

	local shearable = known_shearable[animal.name]
	if not shearable.test(self, animal) then
		return
	end
	shearable.action(self, animal) -- TODO delay action

	set_animation_for_job(self, shears, animal)
	return true
end

local function has_group_item(self, group)
	local stacks = self:get_inventory():get_list("main")

	for _, stack in ipairs(stacks) do
		if minetest.get_item_group(stack:get_name(), group) > 0 then
			return stack:get_name()
		end
	end
end

random_stack = function(stacks, name, chance)
	if not chance or chance == 1 or math.random(chance) == 1 then
		table.insert(stacks,ItemStack(name))
	end
end

local kill_poultries = function(self, animal_object)
	local animal = animal_object:get_luaentity()
	if not animal then
		return
	end
	local killable = known_killable[animal.name]
	if not killable or not killable.test(self, animal) then
		return
	end
	killable.action(self, animal)
	animal_object:remove()
end

local can_kill_poultries = function(self)
	local sword = has_group_item(self, "sword") -- Can we kill poultries with sword
	if not sword then
		return
	end
	local animal, list = get_nearest_entity(self, known_killable, 15)
	if not animal or not known_killable[animal.name] or
		vector.distance(self:get_pos(), animal.object:get_pos()) > 2.5 then
		return -- There is no poultries close enough
	end
	local names = { animal.name }
	if animal.name == "petz:hen" then
		table.insert(names, "petz:chicken")
	elseif animal.name == "petz:chicken" then
		table.insert(names, "petz:hen")
	end

	local count = count_entities(list, names)
	if count < maidroid.settings.stockbreeder_max_poultries then
		return -- Poultries population is too low here
	end

	self.action = kill_poultries
	set_animation_for_job(self, sword, animal)
	return true
end

local harvest_poop = function(self)
	if not maidroid.mods.petz then -- Do we have petz ?
		return
	end
	local shovel = has_group_item(self, "shovel") -- Do we have a shovel
	if not shovel then
		return
	end
	local poops = minetest.find_node_near(self.object:get_pos(), 3, "petz:poop", true)
	if not poops or minetest.is_protected(poops, self.owner) then
		return -- No diggable poop found
	end

	self:set_yaw({self:get_pos(), poops})
	set_animation_for_job(self, shovel)
	self.job_pause =  maidroid.settings.stockbreeder_pause / 2

	-- Add to inventory and remove node
	self:add_items_to_main({ "petz:poop" })
	minetest.remove_node(poops)
	return true
end

local grab_egg = function(self)
	if not maidroid.mods.petz then -- Do we have petz ?
		return
	end
	local egg = has_group_item(self, "food_egg") -- Do we have an egg
	if not egg then
		return
	end
	local nest = minetest.find_node_near(self.object:get_pos(), 3, { "petz:ducky_nest_egg", "petz:chicken_nest_egg" }, true)
	if not nest or minetest.is_protected(nest, self.owner) then
		return -- No accessible nest found
	end

	self:set_yaw({self:get_pos(), nest})
	set_animation_for_job(self, egg)
	self.job_pause =  maidroid.settings.stockbreeder_pause / 2

	-- Get an egg and reset nest
	if minetest.get_node(nest).name == "petz:ducky_nest_egg" then
		self:add_items_to_main({ "petz:ducky_egg" })
	else
		self:add_items_to_main({ "petz:chicken_egg" })
	end
	minetest.set_node(nest, { name =  "petz:ducky_nest" } )
	return true
end

local task = function(self)
	if milk_cows(self) then
		return
	elseif shear_sheeps(self) then
		return
	elseif grab_egg(self) then
		return
	elseif can_kill_poultries(self) then
		return
	else
		harvest_poop(self)
	end
end

on_step = function(self, dtime, moveresult)
	if self.job_pause > 0 then -- A job currently done, stand and mine
		-- Check we have an existing target
		if self.target_obj and self.target_obj:get_luaentity() then
			self:set_yaw({self:get_pos(), self.target_obj:get_pos()})
		end
		self.job_pause = self.job_pause - dtime
		if self.job_pause > 0 then
			return
		end

		-- We got an action to do now (only kill poultries for now)
		if self.target_obj and self.action then
			self.action(self, self.target_obj)
			self.action = nil
		end
		-- The rest takes end reset states and plan some wandering only cycles
		self:set_animation(maidroid.animation.WALK)
		self:set_tool(self.selected_tool)
		self.timers.skip = maidroid.settings.stockbreeder_pause
		self.target_obj = nil
	end

	self:pickup_item()

	local l_task
	if self.timers.skip > 0 then	-- A job has finished, rest a bit
		self.timers.skip = self.timers.skip - dtime
		if self.timers.skip < 0 then
			self.timers.walk = 0
		end
	else							-- Wander to look after cows
		l_task = task
	end
	wander.on_step(self, dtime, moveresult, l_task, maidroid.helpers.is_fence, true)
end

local hat
if maidroid.settings.hat then
	hat = {
		name = "hat_stockbreeder",
		mesh = "maidroid_hat_stockbreeder.obj",
		textures = { "maidroid_hat_stockbreeder.png" },
		offset = {x=0,y=0,z=0},
		rotation = {x=0,y=0,z=0},
	}
end

maidroid.cores.basic.doc = maidroid.cores.basic.doc .. "\t"
	.. S("Stockbreeder: empty bucket or shears") .. "\n"

local doc = S("Stockbreeder take care of animals") .. "\n\n"
	.. S("Abilities") .. "\n"
	.. "\t" .. S("Food and milk cows") .. "\n"
	.. "\t" .. S("Shear sheep if they have") .. "\n"
	.. "\t" .. S("Kill poultries when too much in area") .. "\n"
	.. "\n" .. S("Near fences or panes they change direction" )

maidroid.register_core("stockbreeder", {
	description	= S("a stockbreeder"),
	on_start	= on_start,
	on_stop		= on_stop,
	on_resume	= on_resume,
	on_pause	= on_pause,
	on_step		= on_step,
	is_tool		= is_tool,
	toggle_jump = true,
	walk_max = 1.25 * maidroid.timers.walk_max,
	hat = hat,
	can_sell = true,
	doc = doc,
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
