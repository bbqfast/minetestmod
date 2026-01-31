
-- Copyleft (Я) 2026 mazes-style extension
-- Maidroid core: generic cooker (rice + furnace)
------------------------------------------------------------

local S = maidroid.translator

local on_start, on_pause, on_resume, on_stop, on_step, is_tool
local task, to_action, to_wander, act

local wander = maidroid.cores.wander
local states = maidroid.states
local timers = maidroid.timers
local lf = maidroid.lf
local chest_reach_dist = 2.5

-- Encapsulated target info for a single chest interaction
local GenericCookerTarget = {}
GenericCookerTarget.__index = GenericCookerTarget

local all_cookable_items_short = {
    { item_name = "farming:seed_rice",  count = 5 },
    { item_name = "default:sand",       count = 5 },
    { item_name = "farming:rice_flour", count = 5 },
}

local all_cookable_items = {
    { item_name = "farming:flour_multigrain", count = 5 },
    { item_name = "farming:bread_slice",      count = 5 },
    { item_name = "group:food_corn",          count = 5 },
    { item_name = "group:food_sugar",         count = 5 },
    { item_name = "bucket:bucket_water",      count = 5 },
    { item_name = "farming:pumpkin_dough",    count = 5 },
    { item_name = "farming:rice_flour",       count = 5 },
    { item_name = "farming:tofu",             count = 5 },
    { item_name = "farming:flour",            count = 5 },
    { item_name = "farming:cocoa_beans_raw",  count = 5 },
    { item_name = "default:papyrus",          count = 5 },
    { item_name = "group:food_potato",        count = 5 },
    { item_name = "farming:seed_sunflower",   count = 5 },
}


local all_take_items = {
	{ item_name = "farming:seed_rice",  quantity = 5 },
	{ item_name = "farming:rice_flour", quantity = 5 },
}

local all_farming_outputs = {
    "farming:flour", "farming:flour_multigrain", "farming:bread_slice 5", "farming:toast_sandwich", "farming:garlic_clove 8", "farming:garlic", "farming:garlic 9", "farming:popcorn", "farming:cornstarch",
    "farming:bottle_ethanol", "farming:coffee_cup", "farming:chocolate_dark", "farming:chocolate_block", "farming:chocolate_dark 9", "farming:chili_powder", "farming:chili_bowl", "farming:carrot_juice", "farming:blueberry_pie", "farming:muffin_blueberry 2", "farming:tomato_soup",
    "farming:glass_water 4", "farming:sugar_cube", "farming:salt 9", "farming:salt_crystal", "farming:mayonnaise", "farming:rose_water", "farming:turkish_delight 4", "farming:garlic_bread", "farming:donut 3", "farming:donut_chocolate",
    "farming:donut_apple", "farming:porridge", "farming:jaffa_cake 3", "farming:apple_pie", "farming:cactus_juice", "farming:pasta", "farming:mac_and_cheese", "farming:spaghetti", "farming:bibimbap", "farming:burger", "farming:salad", "farming:smoothie_berry",
    "farming:spanish_potatoes", "farming:potato_omelet", "farming:paella", "farming:flan", "farming:cheese_vegan", "farming:butter_vegan", "farming:onigiri", "farming:gyoza 4", "farming:mochi", "farming:gingerbread_man 3", "farming:mint_tea", "farming:onion_soup",
    "farming:pea_soup", "farming:pepper_ground", "farming:pineapple_ring 5", "farming:pineapple_juice", "farming:pineapple_juice 2", "farming:potato_salad", "farming:melon_8", "farming:melon_slice 4", "farming:pumpkin", "farming:pumpkin_slice 4", "farming:pumpkin_dough",
    "farming:smoothie_raspberry", "farming:rhubarb_pie", "farming:rice_flour", "farming:soy_sauce", "farming:soy_milk", "farming:tofu", "farming:vanilla_extract", "farming:jerusalem_artichokes",
    "farming:cookie 8", "farming:carrot_gold", "farming:beetroot_soup", "farming:sunflower_oil", "farming:sunflower_bread", "farming:bowl 4"
}

local craft_outputs = {
    "farming:flour",
    "farming:rice_flour",
}

local furnace_inputs = { "farming:flour_multigrain", "farming:bread_slice", "group:food_corn", "group:food_sugar", "bucket:bucket_water", "farming:pumpkin_dough", "farming:rice_flour",
    "farming:tofu", "farming:flour", "farming:cocoa_beans_raw", "default:papyrus", "group:food_potato", "farming:seed_sunflower" }

function GenericCookerTarget.new(pos, item_name, max_take, take_items)
	return setmetatable({
		pos = pos,
		item_name = item_name,
		max_take = max_take,
		-- Optional list of specs for chest interactions:
		--   { item_name = "name", quantity = N }
		-- When present, take_item_from_chest will pick a random spec.
		take_items = take_items,
	}, GenericCookerTarget)
end

maidroid.register_tool_rotation("maidroid:spatula", vector.new(-75, -90, 90))
-- maidroid.register_tool_rotation("maidroid:spatula", vector.new(-75,45,-45))

on_start = function(droid)
	wander.on_start(droid)
end

on_resume = function(droid)
	wander.on_resume(droid)
end

on_stop = function(droid)
	wander.on_stop(droid)
end

on_pause = function(droid)
	wander.on_pause(droid)
end

to_action = function(droid)
	droid:halt()
	droid.timers.action = 0
	droid.state = states.ACT
	-- Show a cooking tool instead of rice while acting at the chest
	droid:set_tool("maidroid:spatula")
	droid:set_animation(maidroid.animation.MINE)
end

-- ,,wander
to_wander = function(droid, from_caller)
	-- Clear any current job-specific intent and delegate to the wander core,
	-- similar to waffler.lua's to_wander behavior.
	droid.destination = nil
	droid.action = nil
	droid:set_tool("maidroid:spatula")
    lf("generic_cooker:to_wander", "setting state to WANDER")
	wander.to_wander(droid, from_caller or "generic_cooker:to_wander")
end

is_tool = function(stack)
	return stack:get_name() == "default:furnace"
end


-- ,,ch1
local function take_item_from_chest(droid, chest_pos, take_items)
	if not chest_pos then
        lf("generic_cooker", "take_item_from_chest: no chest_pos")
		return false
	end

	lf("generic_cooker", "checking chest at " .. minetest.pos_to_string(chest_pos))
	local meta = minetest.get_meta(chest_pos)
	local owner = meta:get_string("owner")
	if owner and owner ~= "" and owner ~= droid.owner then
		lf("generic_cooker", "take_item_from_chest: chest owner does not match")
		return false
	end

	local chest_inv = meta:get_inventory()
	local inv = droid:get_inventory()

    -- ,,x1
	if type(take_items) ~= "table" or #take_items == 0 then
        lf("generic_cooker", "take_item_from_chest: no take_items")
		return false
	end

	-- Log all items in the chest for debugging
	local chest_list = chest_inv:get_list("main")
	if chest_list then
		lf("generic_cooker", "take_item_from_chest: chest contents:")
		for i, stack in ipairs(chest_list) do
			if not stack:is_empty() then
				lf("generic_cooker", "  slot " .. i .. ": " .. stack:to_string())
			end
		end
	end

	-- Build a list of candidate specs that the chest can actually supply.
	local candidates = {}
	for _, spec in ipairs(take_items) do
		if type(spec) == "table" then
			local name = spec.item_name
			local count = spec.quantity or 1
			if name and count > 0 then
				local want = name .. " " .. tostring(count)
                lf("generic_cooker", "take_item_from_chest: want=" .. want)
				if chest_inv:contains_item("main", want) then
					candidates[#candidates + 1] = spec
				end
			end
		end
	end

	if #candidates == 0 then
        lf("generic_cooker", "take_item_from_chest: no candidates")
		return false
	end

	local spec = candidates[math.random(#candidates)]
	local item_name = spec.item_name
	local take_count = spec.quantity or 1
	local wanted_stack = item_name .. " " .. tostring(take_count)

	if not inv:room_for_item("main", wanted_stack) then
		return false
	end

	local stack = chest_inv:remove_item("main", wanted_stack)
	if stack:is_empty() then
		return false
	end

	lf("generic_cooker", "took " .. tostring(stack:get_count()) .. " " .. item_name .. " from chest")
	inv:add_item("main", stack)
	return true
end

-- ,,chest
local function try_get_item_from_nearby_chest(droid, pos, take_items)
    lf("generic_cooker", "try_get_item_from_nearby_chest: pos=" .. minetest.pos_to_string(pos))
    local dist = 5
	local chest_pos = minetest.find_node_near(pos, dist, {"default:chest", "default:chest_locked"})
	if not chest_pos then
        lf("generic_cooker", "try_get_item_from_nearby_chest: no chest found")
		return false
	end

	-- local distance = vector.distance(pos, chest_pos)
	-- if distance <= chest_reach_dist then
	-- 	-- Already close enough: perform a short ACT with mine animation while taking from chest
	-- 	local target = vector.add(chest_pos, {x=0, y=1, z=0})
	-- 	droid._generic_cooker_target = GenericCookerTarget.new(chest_pos, nil, nil, take_items)
	-- 	droid.destination = target
	-- 	droid.action = "generic_cooker_take_item"
	-- 	to_action(droid)
    -- ,,x1
	local target = vector.add(chest_pos, {x=0, y=1, z=0})
    local path = minetest.find_path(pos, target, dist + 1, 2, 2, "A*_noprefetch")
	if not path then
        lf("generic_cooker", "try_get_item_from_nearby_chest: no path found")
		return false
	end

	droid._generic_cooker_target = GenericCookerTarget.new(chest_pos, nil, nil, nil)
	-- Show bucket while walking to chest, similar to farming dump logic
	droid:set_tool("bucket:bucket_empty")
    lf("generic_cooker", "try_get_item_from_nearby_chest: path found")
	maidroid.cores.path.to_follow_path(droid, path, target, to_action, "generic_cooker_take_item")
	return true
end

-- ,,furnace
-- NOTE: here 'pos' is expected to be the actual furnace position already
-- (normal or active). We no longer search again, to avoid failing when
-- the furnace is burning.
--
-- items: array of specs, each spec may be
--   { item_name = "name", count = N }
--   { name = "name", count = N }
--   { "name", N }
-- The first spec for which the maidroid has matching items and the furnace
-- has room will be fed into the correct list (fuel/src).
local function feed_furnace_from_inventory_generic(droid, pos, items)
	if not pos then
		return false
	end

	if type(items) ~= "table" then
		lf("generic_cooker:feed_furnace_from_inventory_generic", "items must be a table of specs")
		return false
	end

	local node = minetest.get_node(pos)
	if node.name ~= "default:furnace" and node.name ~= "default:furnace_active" then
	    local furnace_pos = minetest.find_node_near(pos, 5, "default:furnace")
	    if not furnace_pos then
			lf("generic_cooker:feed_furnace_from_inventory_generic", "pos is not a furnace: " .. node.name .. " at " .. minetest.pos_to_string(pos))
			return false
		end
	    pos = furnace_pos
	end

	local meta = minetest.get_meta(pos)
	local finv = meta:get_inventory()
	local inv = droid:get_inventory()

	for _, spec in ipairs(items) do
		local name, count
		if type(spec) == "table" then
			name = spec.item_name or spec.name or spec[1]
			count = spec.count or spec[2] or 1
		elseif type(spec) == "string" then
			name = spec
			count = 1
		end
		if name and count and count > 0 then
			local listname = (name == "default:coal_lump") and "fuel" or "src"
			-- Try to remove up to 'count' items; if the player has fewer,
			-- remove and use whatever is available.
			local want = name .. " " .. tostring(count)
			local stack = inv:remove_item("main", want)
			if not stack:is_empty() then
				if not finv:room_for_item(listname, stack) then
					-- Not enough room; put items back and try next spec.
					inv:add_item("main", stack)
				else
					finv:add_item(listname, stack)
					lf("generic_cooker", "feed_furnace_from_inventory_generic: added " .. tostring(stack:get_count()) .. " " .. name .. " to " .. listname .. " at " .. minetest.pos_to_string(pos))
					return true
				end
			end
		end
	end

	lf("generic_cooker:feed_furnace_from_inventory_generic", "no matching items or no room in furnace")
	return false
end

-- Collect finished items from a nearby furnace into the droid's inventory
-- ,,finish
local function collect_finished_from_furnace0(droid, pos)
    lf("generic_cooker", "collect_finished_from_furnace: pos=" .. minetest.pos_to_string(pos))
    local furnace_pos = minetest.find_node_near(pos, 5, "default:furnace")
    if not furnace_pos then
        return false
    end
    local node = minetest.get_node(furnace_pos)
    -- Only collect when the furnace is not actively burning
    if node and node.name == "default:furnace_active" then
        return false
    end
    local meta = minetest.get_meta(furnace_pos)
    local finv = meta and meta:get_inventory()
    if not finv then
        return false
    end
    local dst = finv:get_list("dst") or {}
    local collected = {}
    for idx, stack in ipairs(dst) do
        if not stack:is_empty() then
            collected[#collected + 1] = stack
            dst[idx] = ItemStack("")
        end
    end
    if #collected == 0 then
        return false
    end
    finv:set_list("dst", dst)
    droid:add_items_to_main(collected)
    lf("generic_cooker", "collect_finished_from_furnace: collected finished items from furnace at "
        .. minetest.pos_to_string(furnace_pos))
    return true
end

-- ,,fg2
-- Combined helper: if furnace is active, do nothing;
-- if inactive and has finished items, collect them;
-- otherwise, feed the specified item into the furnace.
local function feed_get_from_furnace__generic(droid, pos)
    lf("generic_cooker:feed_get_from_furnace__generic", "pos=" .. minetest.pos_to_string(pos))
	if not pos then
        lf("generic_cooker:feed_get_from_furnace__generic", "no pos provided")
		return false
	end

	-- Resolve to an actual furnace node near pos, if needed
	local node = minetest.get_node(pos)
	if node.name ~= "default:furnace" and node.name ~= "default:furnace_active" then
		local furnace_pos = minetest.find_node_near(pos, 5, "default:furnace")
		if not furnace_pos then
			lf("generic_cooker:feed_get_from_furnace__generic",
				"no furnace found near pos=" .. minetest.pos_to_string(pos))
			return false
		end
		pos = furnace_pos
		node = minetest.get_node(pos)
	end

	-- If furnace is active, do nothing.
	if node and node.name == "default:furnace_active" then
		lf("generic_cooker:feed_get_from_furnace__generic",
			"furnace active at " .. minetest.pos_to_string(pos) .. ", skipping")
		return false
	end

	local meta = minetest.get_meta(pos)
	local finv = meta and meta:get_inventory()
	if finv then
		-- If there is no fuel, and the droid has at least 5 coal, try to add 5 coal as fuel.
		local fuel_list = finv:get_list("fuel") or {}
		local has_fuel = false
		for _, stack in ipairs(fuel_list) do
			if not stack:is_empty() then
				has_fuel = true
				break
			end
		end
		if not has_fuel then
			local inv = droid:get_inventory()
			if inv:contains_item("main", "default:coal_lump 5")
				and finv:room_for_item("fuel", "default:coal_lump 5") then
				local coal_stack = inv:remove_item("main", "default:coal_lump 5")
				if not coal_stack:is_empty() then
					finv:add_item("fuel", coal_stack)
					lf("generic_cooker:feed_get_from_furnace__generic",
						"added 5 coal to furnace fuel at " .. minetest.pos_to_string(pos))
				end
			end
		end

		-- First, try to collect finished items from dst if any.
		local dst = finv:get_list("dst") or {}
		local collected = {}
		for idx, stack in ipairs(dst) do
			if not stack:is_empty() then
				collected[#collected + 1] = stack
				dst[idx] = ItemStack("")
			end
		end
		if #collected > 0 then
			finv:set_list("dst", dst)
			droid:add_items_to_main(collected)
			lf("generic_cooker:feed_get_from_furnace__generic",
				"collected finished items from furnace at " .. minetest.pos_to_string(pos))
			return true
		end
	end

	return feed_furnace_from_inventory_generic(droid, pos, all_cookable_items)
end

-- ,,fg1,
-- Pathfinding helper: walk to a nearby furnace and then perform the
-- combined feed/get behavior defined in feed_get_from_furnace__generic.
local function try_feed_get_from_furnace__generic(droid, pos)
    local find_dist = 12
	local furnace_pos = minetest.find_node_near(pos, find_dist, "default:furnace")
	if not furnace_pos then
		lf("generic_cooker:try_feed_get_from_furnace__generic", "furnace not found: pos=" .. minetest.pos_to_string(pos))
		return false
	end

	local target = vector.add(furnace_pos, {x=0, y=1, z=0})
	local rounded_pos = vector.round(pos)
	local path = minetest.find_path(rounded_pos, target, find_dist+1, 2, 2, "A*_noprefetch")
	if not path then
		lf("generic_cooker:try_feed_get_from_furnace__generic", "path not found")
		return false
	end

	droid._furnace_target = GenericCookerTarget.new(furnace_pos, nil, nil)
	droid:set_tool("maidroid:spatula")
	maidroid.cores.path.to_follow_path(droid, path, target, to_action, "generic_cooker_feed_get")
	return true
end

local function feed_furnace_from_inventory(droid, pos)
	local furnace_pos = minetest.find_node_near(pos, 5, "default:furnace")
	if not furnace_pos then
		return
	end

	local node = minetest.get_node(furnace_pos)
	local meta = minetest.get_meta(furnace_pos)
	local finv = meta:get_inventory()
	local inv = droid:get_inventory()

	if node and node.name ~= "default:furnace_active" then
		local dst = finv:get_list("dst") or {}
		local collected = {}
		for idx, stack in ipairs(dst) do
			if not stack:is_empty() then
				collected[#collected + 1] = stack
				dst[idx] = ItemStack("")
			end
		end
		if #collected > 0 then
			finv:set_list("dst", dst)
			droid:add_items_to_main(collected)
			lf("generic_cooker", "collected finished items from furnace at " .. minetest.pos_to_string(furnace_pos))
		end
	end

	if inv:contains_item("main", "default:coal_lump 1") and finv:room_for_item("fuel", "default:coal_lump 1") then
		local coal_stack = inv:remove_item("main", "default:coal_lump 1")
		if not coal_stack:is_empty() then
			finv:add_item("fuel", coal_stack)
			lf("generic_cooker", "added coal to furnace at " .. minetest.pos_to_string(furnace_pos))
		end
	end

	if inv:contains_item("main", "farming:seed_rice 1") and finv:room_for_item("src", "farming:seed_rice 1") then
		local src_list = finv:get_list("src") or {}
		local current = 0
		for _, stack in ipairs(src_list) do
			if not stack:is_empty() then
				current = current + stack:get_count()
			end
		end
		if current < 5 then
			local need = 5 - current
			local take_spec = "farming:seed_rice " .. tostring(need)
			local rice_stack = inv:remove_item("main", take_spec)
			if not rice_stack:is_empty() then
				finv:add_item("src", rice_stack)
				lf("generic_cooker", "added seed_rice to furnace at " .. minetest.pos_to_string(furnace_pos) .. " (" .. tostring(rice_stack:get_count()) .. " seeds, total now <= 5)")
			end
		end
	end
end

local function get_replacements_for_recipe(output_name)
  local r = minetest.get_craft_recipe(output_name)
  if not r or not r.items then return nil, "no recipe" end

  -- Ask the engine to perform the craft so we can see what remains in the
  -- input grid (second return value). This exposes implicit replacements.
  local spec = {
    method = r.method or "normal",
    width  = r.width or 3,
    items  = r.items,
  }
  local res, decremented = minetest.get_craft_result(spec)
  lf("generic_cooker", "get_craft_result: spec=" .. dump(spec) .. " result=" .. dump(res) .. " decremented=" .. dump(decremented))

  -- Build a replacements list in the same shape as register_craft
  -- { { original_item, replacement_name }, ... }
  local replacements = {}
  if decremented and decremented.items then
    for idx, after in ipairs(decremented.items) do
      local before = r.items[idx]
      if before and before ~= "" and after and not after:is_empty() then
        local new_name = after:get_name()
        if new_name ~= "" then
          replacements[#replacements + 1] = { before, new_name }
          lf("generic_cooker", string.format(
            "get_replacements_for_recipe: before=%s -> replacement=%s",
            before, new_name))
        end
      end
    end
  end

  if #replacements == 0 then
    lf("generic_cooker", "get_replacements_for_recipe: no replacements detected")
    return nil, res and res.item or nil
  end

  return replacements, res and res.item or nil
end

-- Helper: return required inputs for a craft output name, split into
-- consumables and replacements.
-- First return value is { [item_name] = total_count, ... } built from
-- the normalized recipe items. Second return value is the replacements
-- list returned (or inferred) by get_replacements_for_recipe, or nil.
-- When no recipe is found, both return values are nil.
local function get_craft_requirements_from_registered(output_name)
	if not output_name or output_name == "" then
		return nil, nil
	end

	local recipe = minetest.get_craft_recipe(output_name)
    lf("generic_cooker", "get_craft_requirements_from_registered: recipe=" .. dump(recipe))
	if not recipe or not recipe.items or #recipe.items == 0 then
		return nil, nil
	end

	local consumables = {}

	for _, item in ipairs(recipe.items) do
		if item ~= "" then
			local stack = ItemStack(item)
			local name = stack:get_name()
			local count = stack:get_count()
			if name ~= "" and count > 0 then
				consumables[name] = (consumables[name] or 0) + count
			end
		end
	end

	if next(consumables) == nil then
		return nil, nil
	end

	local replacements = get_replacements_for_recipe(output_name)
	if replacements then
		lf("generic_cooker", "get_craft_requirements_from_registered: replacements=" .. dump(replacements))
	end
	return consumables, replacements
end

-- Helper: craft rice flour directly in the maidroid's inventory.
-- Consumes a fixed number of rice items and adds one rice flour if possible.
local function craft_rice_flour(droid)
	local inv = droid and droid:get_inventory()
	if not inv then
		return false
	end -- if not inv

	-- Get the actual craft recipe for farming:rice_flour from registered crafts.
	local all_consumables, replacements = get_craft_requirements_from_registered("farming:rice_flour")
	if not all_consumables then
		lf("generic_cooker", "craft_rice_flour: no craft recipe found for farming:rice_flour")
		return false
	end -- if not all_consumables

	-- Derive tool set from replacements and groups, then split consumables/tools.
	local tool_names = {}
	for _, rep in ipairs(replacements or {}) do
		local before = rep[1]
		local after = rep[2]
		if type(before) == "string" and before ~= "" then
			tool_names[before] = true
		end
		if type(after) == "string" and after ~= "" and not after:find("^group:") then
			tool_names[after] = true
		end
	end

	local consumables = {}
	for name, count in pairs(all_consumables) do
        consumables[name] = count
	end

	local output_stack = ItemStack("farming:rice_flour")

	-- Ensure there is room for the result before consuming inputs.
	if not inv:room_for_item("main", output_stack) then
		return false
	end -- if not room_for_item

	-- Check we have all required consumable ingredients.
	for name, count in pairs(consumables or {}) do
		local needed = string.format("%s %d", name, count)
        lf("generic_cooker", "craft_rice_flour: checking for " .. needed)
		if not inv:contains_item("main", needed) then
            lf("generic_cooker", "craft_rice_flour: missing " .. needed)
			return false
		end
	end

	-- Remove ingredients, keeping a list so we can roll back on failure.
	local removed_items = {}
	for name, count in pairs(consumables or {}) do
		local needed = string.format("%s %d", name, count)
		local removed = inv:remove_item("main", needed)
		local got = removed:get_count()
		if removed:is_empty() or got < count then
			-- Roll back anything we already removed.
			for _, r in ipairs(removed_items) do
				if not r:is_empty() then
					inv:add_item("main", r)
				end
			end -- for removed_items rollback
			if not removed:is_empty() then
				inv:add_item("main", removed)
			end
			return false
		end -- if removed empty or insufficient
		removed_items[#removed_items + 1] = removed
	end -- for consumables removal

	-- Add replacement items (tools that are returned after crafting) back to inventory.
	for _, rep in ipairs(replacements or {}) do
		local replacement_name = rep[2]
		if replacement_name and replacement_name ~= "" then
			local replacement_stack = ItemStack(replacement_name)
			inv:add_item("main", replacement_stack)
			lf("generic_cooker", "craft_rice_flour: returned replacement " .. replacement_stack:to_string())
		end -- if replacement_name
	end -- for replacements


	-- Add the crafted rice flour.
	inv:add_item("main", output_stack)
	lf("generic_cooker", "craft_rice_flour: crafted " .. output_stack:to_string())
	return true
end -- function craft_rice_flour

-- Helper: generic craft based on craft_outputs list.
-- Iterates craft_outputs and performs the first craftable recipe in the maidroid's inventory.
local function craft_generic(droid)
	local inv = droid and droid:get_inventory()
	if not inv then
		return false
	end -- if not inv

	for _, spec in ipairs(craft_outputs or {}) do
		local output_stack = ItemStack(spec)
		local output_name = output_stack:get_name()
		if output_name ~= "" then
			local all_consumables, replacements = get_craft_requirements_from_registered(output_name)
			if all_consumables then
				local consumables = {}
				for name, count in pairs(all_consumables) do
					consumables[name] = count
				end

				-- Ensure there is room for the result before consuming inputs.
				if inv:room_for_item("main", output_stack) then
					local missing = false
					for name, count in pairs(consumables or {}) do
						local needed = string.format("%s %d", name, count)
						lf("generic_cooker", "craft_generic(" .. output_name .. "): checking for " .. needed)
						if not inv:contains_item("main", needed) then
							lf("generic_cooker", "craft_generic(" .. output_name .. "): missing " .. needed)
							missing = true
							break
						end
					end

					if not missing then
						local removed_items = {}
						for name, count in pairs(consumables or {}) do
							local needed = string.format("%s %d", name, count)
							local removed = inv:remove_item("main", needed)
							local got = removed:get_count()
							if removed:is_empty() or got < count then
								for _, r in ipairs(removed_items) do
									if not r:is_empty() then
										inv:add_item("main", r)
									end
								end
								if not removed:is_empty() then
									inv:add_item("main", removed)
								end
								removed_items = nil
								break
							end
							removed_items[#removed_items + 1] = removed
						end

						if removed_items then
							for _, rep in ipairs(replacements or {}) do
								local replacement_name = rep[2]
								if replacement_name and replacement_name ~= "" then
									local replacement_stack = ItemStack(replacement_name)
									inv:add_item("main", replacement_stack)
									lf("generic_cooker", "craft_generic(" .. output_name .. "): returned replacement " .. replacement_stack:to_string())
								end
							end

							inv:add_item("main", output_stack)
							lf("generic_cooker", "craft_generic: crafted " .. output_stack:to_string())
							return true
						end
					end
				end
			end
		end
	end

	return false
end


-- ,,act

act = function(droid, dtime)
    lf("generic_cooker:act", "act: " .. minetest.pos_to_string(vector.round(droid:get_pos())) .. " action: " .. droid.action)
	if droid.timers.action < 2 then
		droid.timers.action = droid.timers.action + dtime
		return
	end

	if droid.action == "generic_cooker_take_item" then
        lf("generic_cooker:act", "generic_cooker_take_item: " .. minetest.pos_to_string(droid:get_pos()))
		local target = droid._generic_cooker_target
		if target and target.pos then

			take_item_from_chest(
				droid,
				target.pos,
				all_take_items
			)
		end
		droid._generic_cooker_target = nil
	elseif droid.action == "generic_cooker_feed_get" then
        lf("generic_cooker:act", "generic_cooker_feed_get: " .. minetest.pos_to_string(droid:get_pos()))
		local target = droid._furnace_target
		if target and target.pos  then
			feed_get_from_furnace__generic(
				droid, target.pos
			)
		end
		droid._furnace_target = nil
    elseif droid.action == "generic_cooker_craft_rice_flour" then
        lf("generic_cooker:act", "generic_cooker_craft_rice_flour: " .. minetest.pos_to_string(droid:get_pos()))
        craft_rice_flour(droid)
	-- elseif droid.action == "generic_cooker_collect_finished" then
    --     lf("generic_cooker:act", "generic_cooker_collect_finished: " .. minetest.pos_to_string(droid:get_pos()))
	-- 	local target = droid._furnace_target
	-- 	if target and target.pos then
	-- 		collect_finished_from_furnace(droid, target.pos)
	-- 	end
	-- 	droid._furnace_target = nil
	end

	-- Action finished: return cleanly to wander behavior, like waffler.to_wander
	return to_wander(droid, "generic_cooker:act")
end

-- ,,task
task = function(droid)
	local pos = droid:get_pos()
	local inv = droid:get_inventory()

	-- ,,x2: randomly pick one of two furnace actions, with choice 1 being twice as likely as choice 2
	-- Use math.random(3): values 1 and 2 map to choice 1, value 3 maps to choice 2
	local choice = math.random(3)
    choice = 1

	if choice == 1 then
		lf("generic_cooker:task", "CHOICE=1: try_feed_get_from_furnace__generic for ")
	    	try_feed_get_from_furnace__generic(droid, pos)
    elseif choice == 2 then
        lf("generic_cooker:task", "CHOICE=2: craft_rice_flour")
        -- craft_rice_flour(droid)
        craft_generic(droid)
	else
		lf("generic_cooker:task", "CHOICE=2: try_get_item_from_nearby_chest for all_take_items (seed_rice + rice_flour)")
	    	try_get_item_from_nearby_chest(droid, pos, all_take_items)
	end
end

-- ,,step
on_step = function(droid, dtime, moveresult)
	droid:pickup_item()

	if droid.state == states.WANDER then
		wander.on_step(droid, dtime, moveresult, task)
	elseif droid.state == states.PATH then
		maidroid.cores.path.on_step(droid, dtime, moveresult)
	elseif droid.state == states.ACT then
		act(droid, dtime)
	end
end

maidroid.cores.basic.doc = maidroid.cores.basic.doc .. "\t"
	.. S("Generic cooker: seed_rice + coal -> cooked") .. "\n"

local doc = S("They manage a nearby furnace using rice seeds") .. "\n\n"
	.. S("Abilities") .. "\n"
	.. "\t" .. S("Take farming:seed_rice from nearby chests") .. "\n"
	.. "\t" .. S("Feed coal to default:furnace") .. "\n"
	.. "\t" .. S("Feed farming:seed_rice to default:furnace input") .. "\n"

local hat
if maidroid.settings.hat then
	hat = {
		name = "hat_cook",
		mesh = "maidroid_hat_cook.obj",
		textures = { "maidroid_hat_cook.png" },
		offset = { x=0, y=0, z=0 },
		rotation = { x=0, y=0, z=0 },
	}
end

maidroid.register_core("generic_cooker", {
	description = S("Generic cooker"),
	on_start = on_start,
	on_stop = on_stop,
	on_resume = on_resume,
	on_pause = on_pause,
	on_step = on_step,
	is_tool = is_tool,
	default_item = "maidroid:spatula",
    walk_max = 4.5 * timers.walk_max,
	hat = hat,
	can_sell = true,
	doc = doc,
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
