
-- Copyleft (Я) 2026 mazes-style extension
-- Maidroid core: generic cooker (rice + furnace)
------------------------------------------------------------

local S = maidroid.translator

local on_start, on_pause, on_resume, on_stop, on_step, is_tool
local task, to_action, to_wander, act
local get_all_required_craft_items

local wander = maidroid.cores.wander
local states = maidroid.states
local timers = maidroid.timers
local lf = maidroid.lf
local chest_reach_dist = 2.5

-- Treat chests as blocking for generic cooker movement, similar to fences,
-- so the maidroid does not walk past chests while pathing or wandering.
local function is_fence_or_chest(name)
	if maidroid.helpers.is_fence(name) then
		return true
	end
    return false
	-- return name == "default:chest" or name == "default:chest_locked"
end

-- Load cooker items configuration
local cooker_items = dofile(maidroid.modpath .. "/cores/cooker_items.lua")
local all_cookable_items = cooker_items.all_cookable_items
local all_farming_outputs = cooker_items.all_farming_outputs
local all_take_item_names = cooker_items.all_take_item_names

-- Metrics table to track items taken from chests
local chest_taken_metrics = {}
local action_taken_metrics = {}
local craft_metrics = {}
local furnace_taken_metrics = {}
-- Timer for periodic metrics logging
local metrics_log_timer = 0
local metrics_log_interval = 35 -- seconds

-- Function to log chest taken metrics
local function log_chest_taken_metrics()
	-- Log chest taken metrics
    lf("chest_metrics", "**************** Metrics ****************")
	if next(chest_taken_metrics) == nil then
		lf("chest_metrics", "No items taken from chests yet.")
	else
		lf("chest_metrics", "**************** Chest Taken ")
		for item_name, count in pairs(chest_taken_metrics) do
			lf("chest_metrics", string.format("%s: %d", item_name, count))
		end
	end
	
	-- Log action taken metrics
	if next(action_taken_metrics) == nil then
		lf("action_metrics", "No actions taken yet.")
	else
		local action_parts = {}
		for action_name, count in pairs(action_taken_metrics) do
			table.insert(action_parts, string.format("%s:%d", action_name, count))
		end
		lf("action_metrics", "Action Metrics: " .. table.concat(action_parts, ", "))
	end
	
	-- Log craft metrics
	if next(craft_metrics) == nil then
		lf("craft_metrics", "No items crafted yet.")
	else
		local craft_parts = {}
		for item_name, count in pairs(craft_metrics) do
			table.insert(craft_parts, string.format("%s:%d", item_name, count))
		end
		lf("craft_metrics", "Craft Metrics: " .. table.concat(craft_parts, ", "))
	end
	
	-- Log furnace taken metrics
	if next(furnace_taken_metrics) == nil then
		lf("furnace_metrics", "No items taken from furnaces yet.")
	else
		local furnace_parts = {}
		for item_name, count in pairs(furnace_taken_metrics) do
			table.insert(furnace_parts, string.format("%s:%d", item_name, count))
		end
		lf("furnace_metrics", "Furnace Taken Metrics: " .. table.concat(furnace_parts, ", "))
	end
    lf("chest_metrics", "**************** End Metrics ****************")

end

-- Expose the function globally
maidroid.get_all_cookable_furnace_inputs = get_all_cookable_furnace_inputs

-- Encapsulated target info for a single chest interaction
local GenericCookerTarget = {}
GenericCookerTarget.__index = GenericCookerTarget

local all_cookable_items_short = {
    { item_name = "farming:seed_rice",  count = 5 },
    { item_name = "default:sand",       count = 5 },
    { item_name = "farming:rice_flour", count = 5 },
}

local all_take_items = {
	{ item_name = "farming:seed_rice",  quantity = 5 },
	{ item_name = "farming:rice_flour", quantity = 5 },
}

local craft_outputs = {
    "farming:flour",
    "farming:rice_flour",
    "farming:bread_slice"
}

local function lfv(verbose, ...)
	if verbose then
		lf(...)
	end
end

local function log_inventory(droid, label)
	if not droid or not droid.get_inventory then
		return
	end
	local inv = droid:get_inventory()
	if not inv then
		return
	end
	local list = inv:get_list("main")
	if not list then
		return
	end
	label = label or "main"
	lf("generic_cooker", "Inventory (" .. label .. "):")
	for i, stack in ipairs(list) do
		if not stack:is_empty() then
			lf("generic_cooker", "  slot " .. i .. ": " .. stack:to_string())
		end
	end
end

-- Helper: given a group spec like "group:food_bread", return a list of
-- all registered item names that belong to that group.
local function get_items_in_group(group_spec)
	if type(group_spec) ~= "string" then
		return {}
	end

	-- Accept either "group:name" or just "name" as input.
	local groupname = group_spec
	local prefix = "group:"
	if groupname:sub(1, #prefix) == prefix then
		groupname = groupname:sub(#prefix + 1)
	end
	if groupname == "" then
		return {}
	end

	local result = {}
	for name, def in pairs(minetest.registered_items) do
		-- Skip non-craftable or hidden entries if desired in the future.
		if minetest.get_item_group(name, groupname) and
			minetest.get_item_group(name, groupname) > 0 then
			result[#result + 1] = name
		end
	end

	return result
end

-- Function that returns all cookable furnace inputs by examining registered recipes
-- This dynamically discovers all items that can be cooked in a furnace
local function get_all_cookable_furnace_inputs()
	local cookable_inputs = {}
	local seen = {} -- To avoid duplicates
	
	-- Debug: log what we're looking for
	lf("get_all_cookable_furnace_inputs", "Starting search for cookable items")
	
	-- Check all registered items by testing them with get_craft_result
	for item_name, def in pairs(minetest.registered_items) do
		-- lf("get_all_cookable_furnace_inputs", "Testing item: " .. item_name)
		-- Skip groups and non-item entries
		-- if not string.find(item_name, "group:", 1, true) == 1 and item_name ~= "" then
			
			-- Test if this item can be cooked using get_craft_result
			local r = minetest.get_craft_result({
				method = "cooking",
				width  = 1,
				items  = { item_name },
			})
			
			if r and r.item and not r.item:is_empty() then
				lf("get_all_cookable_furnace_inputs", "Found cookable item: " .. item_name .. " -> " .. r.item:to_string())
				
				if not seen[item_name] then
					seen[item_name] = true
					cookable_inputs[#cookable_inputs + 1] = item_name
				end
			end
		-- end
	end
	
	-- Also check items with cook_result property (fallback for older mods)
	for item_name, def in pairs(minetest.registered_items) do
		if def and def.cook_result then
			lf("get_all_cookable_furnace_inputs", "Found cook_result for: " .. item_name .. " -> " .. def.cook_result)
			if not seen[item_name] then
				seen[item_name] = true
				cookable_inputs[#cookable_inputs + 1] = item_name
			end
		end
	end
	
	-- Sort the results for consistent output
	table.sort(cookable_inputs)
	
	lf("get_all_cookable_furnace_inputs", "Total cookable inputs found: " .. #cookable_inputs)
	return cookable_inputs
end


-- craft_outputs = all_farming_outputs

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


-- ,,ch2,,chest
local function take_item_from_chest(droid, chest_pos, take_items)
    lf("generic_cooker", "take_item_from_chest: " .. minetest.pos_to_string(chest_pos) .. " total take items=" .. #take_items)
	
	-- Update action_taken_metrics
	action_taken_metrics["chest_taken"] = (action_taken_metrics["chest_taken"] or 0) + 1
	lf("action_metrics", "chest_taken called: " .. action_taken_metrics["chest_taken"])
	
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
                -- lf("generic_cooker", "take_item_from_chest: want=" .. want)
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
        lf("generic_cooker", "take_item_from_chest: no room for " .. wanted_stack)
		return false
	end

	local stack = chest_inv:remove_item("main", wanted_stack)
	if stack:is_empty() then
        lf("generic_cooker", "take_item_from_chest: no stack")
		return false
	end

	lf("generic_cooker", "took " .. tostring(stack:get_count()) .. " " .. item_name .. " from chest")
	inv:add_item("main", stack)
	
	-- Update chest_taken_metrics
	chest_taken_metrics[item_name] = (chest_taken_metrics[item_name] or 0) + stack:get_count()
	lf("generic_cooker", "chest_taken_metrics updated: " .. item_name .. " = " .. chest_taken_metrics[item_name])
	
	return true
end

-- ,,ch1,chest
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
-- ,,fg3
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
			-- Check if maidroid has more than 5 of this item type
			local current_stack = inv:contains_item("main", name .. " 5")
			if current_stack then
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
			else
				lf("generic_cooker", "feed_furnace_from_inventory_generic: skipping " .. name .. " - only have 5 or fewer")
			end
		end
	end

	lf("generic_cooker:feed_furnace_from_inventory_generic", "no matching items or no room in furnace")
	return false
end

local function add_coal_fuel_if_needed(droid, pos, finv)
	-- If fuel is less than 20, and the droid has at least 5 coal, try to add 5 coal as fuel.
	local fuel_list = finv:get_list("fuel") or {}
	local fuel_count = 0
	for _, stack in ipairs(fuel_list) do
		if not stack:is_empty() then
			fuel_count = fuel_count + stack:get_count()
		end
	end
	if fuel_count < 20 then
		local inv = droid:get_inventory()
		if inv:contains_item("main", "default:coal_lump 5")
			and finv:room_for_item("fuel", "default:coal_lump 5") then
			local coal_stack = inv:remove_item("main", "default:coal_lump 5")
			if not coal_stack:is_empty() then
				finv:add_item("fuel", coal_stack)
				lf("generic_cooker:feed_get_from_furnace__generic",
					"added 5 coal to furnace fuel at " .. minetest.pos_to_string(pos) .. " (fuel was " .. fuel_count .. ")")
			end
		end
	end
end

local function collect_finished_items_from_furnace(droid, pos, finv)
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
		
		-- Update furnace_taken_metrics
		for _, stack in ipairs(collected) do
			local item_name = stack:get_name()			
			furnace_taken_metrics[item_name] = (furnace_taken_metrics[item_name] or 0) + stack:get_count()
			lf("furnace_metrics", "furnace_taken_metrics updated: " .. item_name .. " = " .. furnace_taken_metrics[item_name])
		end
		
		lf("generic_cooker:feed_get_from_furnace__generic",
			"collected finished items from furnace at " .. minetest.pos_to_string(pos))
            return true
        end
        return false
    end
    
    -- Combined helper: if furnace is active, do nothing;
    -- if inactive and has finished items, collect them;
    -- otherwise, feed the specified item into the furnace.
    -- ,,fg2
local function feed_get_from_furnace__generic(droid, pos)
    lf("generic_cooker:feed_get_from_furnace__generic", "pos=" .. minetest.pos_to_string(pos))
	
	-- Update action_taken_metrics
	action_taken_metrics["furnace_action"] = (action_taken_metrics["furnace_action"] or 0) + 1
	lf("action_metrics", "furnace_action called: " .. action_taken_metrics["furnace_action"])
	
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
    
    collect_finished_items_from_furnace(droid, pos, finv)
    
    add_coal_fuel_if_needed(droid, pos, finv)

	return feed_furnace_from_inventory_generic(droid, pos, all_cookable_items)
end

-- ,,fg1,,fur
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
			
			-- Update furnace_taken_metrics
			for _, stack in ipairs(collected) do
				local item_name = stack:get_name()
				furnace_taken_metrics[item_name] = (furnace_taken_metrics[item_name] or 0) + stack:get_count()
				lf("furnace_metrics", "furnace_taken_metrics updated: " .. item_name .. " = " .. furnace_taken_metrics[item_name])
			end
			
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


local function get_replacements_for_output(output_name, verbose)
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
  lfv(verbose, "generic_cooker", "get_craft_result: spec=" .. dump(spec) .. " result=" .. dump(res) .. " decremented=" .. dump(decremented))

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
          lfv(verbose, "generic_cooker", string.format(
            "get_replacements_for_recipe: before=%s -> replacement=%s",
            before, new_name))
        end
      end
    end
  end

  if #replacements == 0 then
    lfv(verbose, "generic_cooker", "get_replacements_for_recipe: no replacements detected")
    local result_str = nil
    if res and res.item and not res.item:is_empty() then
      result_str = res.item:to_string()
    end
    return nil, result_str
  end

  local result_str = nil
  if res and res.item and not res.item:is_empty() then
    result_str = res.item:to_string()
  end
  return replacements, result_str
end

-- Similar to get_replacements_for_output, but operates on an explicit
-- list of recipe items (such as recipe.items returned by
-- minetest.get_all_craft_recipes) instead of an output item name.
--
-- Params:
--   items  : array of item strings (recipe grid, row-major)
--   method : optional craft method (defaults to "normal")
--   width  : optional craft width (defaults to 3)
--   verbose: optional boolean for debug logging
--
-- Returns:
--   replacements table in the same shape as register_craft
--   (or nil if none were detected), and the crafted result item stack
--   (or nil on failure).
-- ,,repl
local function get_replacements_for_recipe(items, method, width, verbose)
  if not items or #items == 0 then
    return {}
  end

  verbose = not not verbose

  local spec = {
    method = method or "normal",
    width  = width or 3,
    items  = items,
  }

  local _, decremented = minetest.get_craft_result(spec)
  lfv(verbose, "generic_cooker", "get_replacements_for_recipe: input=" .. dump(spec) .. " decremented=" .. dump(decremented))

  local replacements = {}
  if decremented and decremented.items then
    for _, after in ipairs(decremented.items) do
      if after and not after:is_empty() then
        local name = after:get_name()
        if name ~= "" then
          replacements[#replacements + 1] = name
          lfv(verbose, "generic_cooker", "get_replacements_for_recipe(items): replacement=" .. name)
        end
      end
    end
  end

  if #replacements == 0 then
    lfv(verbose, "generic_cooker", "get_replacements_for_recipe(items): no replacements detected")
  end

  return replacements
end

-- Helper: return required inputs for a craft output name, split into
-- consumables and replacements.
-- First return value is { [item_name] = total_count, ... } built from
-- the normalized recipe items. Second return value is the replacements
-- list returned (or inferred) by get_replacements_for_recipe, or nil.
-- When no recipe is found, both return values are nil.
-- ,,craft,,req
local function get_craft_requirements_from_registered(output_name, verbose)
	if not output_name or output_name == "" then
		return nil
	end


	local recipes = minetest.get_all_craft_recipes(output_name)
	lfv(verbose, "generic_cooker", "get_craft_requirements_from_registered: ALLrecipes=" .. dump(recipes))
	if not recipes or #recipes == 0 then
		return nil
	end

	local all = {}

	for _, recipe in ipairs(recipes) do
		if recipe.items and #recipe.items > 0 then
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
			if next(consumables) ~= nil then
				local replacements = get_replacements_for_recipe(recipe.items, recipe.method, recipe.width, verbose)
				if replacements then
					lfv(verbose, "generic_cooker", "get_craft_requirements_from_registered: replacements=" .. dump(replacements))
				end
				-- Each entry is a tuple: { consumables, replacements }
				all[#all + 1] = { consumables, replacements }
			end
		end
	end

	if #all == 0 then
		return nil
	end

    lfv(verbose, "generic_cooker", ">>>>>>>>>>>>>>>>>>> get_craft_requirements_from_registered: all=" .. dump(all))
	return all
end

-- Helper: given a list of output specs (e.g. all_farming_outputs),
-- return a flat list of unique required craft input item names across
-- all of them. The list is expected to contain strings acceptable to
-- ItemStack, such as "farming:bread_slice" or "farming:bread_slice 5".
-- The return value is an array-like table of item names, e.g.:
--   { "farming:flour", "bucket:bucket_water", ... }
-- ,,req
local function get_all_required_craft_items(outputs, verbose)
	if type(outputs) ~= "table" then
		return {}
	end

	local seen = {}
	local list = {}

	for _, spec in ipairs(outputs) do
		if type(spec) == "string" and spec ~= "" then
			local stack = ItemStack(spec)
			local out_name = stack:get_name()
			if out_name ~= "" then
				local recipes = get_craft_requirements_from_registered(out_name, verbose)
				if recipes then
					for _, tuple in ipairs(recipes) do
						local consumables = tuple[1]
				if consumables then
					for in_name, _ in pairs(consumables) do
						if in_name ~= "" and not seen[in_name] then
							seen[in_name] = true
							list[#list + 1] = in_name
						end
					end
				end
			end
		end
	end
		end
	end

	return list
end

-- Helper: craft rice flour directly in the maidroid's inventory.
-- Consumes a fixed number of rice items and adds one rice flour if possible.
local function craft_rice_flour(droid)
	local inv = droid and droid:get_inventory()
	if not inv then
		return false
	end -- if not inv

	-- Get the actual craft recipe for farming:rice_flour from registered crafts.
	local recipes = get_craft_requirements_from_registered("farming:rice_flour")
	if not recipes or #recipes == 0 then
		lf("generic_cooker", "craft_rice_flour: no craft recipe found for farming:rice_flour")
		return false
	end -- if not all_consumables

	-- For now, use the first available recipe tuple { consumables, replacements }.
	local first = recipes[1]
	local all_consumables = first and first[1]
	local replacements = first and first[2]
	if not all_consumables then
		lf("generic_cooker", "craft_rice_flour: no consumables in first recipe for farming:rice_flour")
		return false
	end

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
	
	-- Update craft_metrics
	local crafted_name = output_stack:get_name()
	craft_metrics[crafted_name] = (craft_metrics[crafted_name] or 0) + output_stack:get_count()
	lf("craft_metrics", "crafted " .. output_stack:to_string() .. " total: " .. craft_metrics[crafted_name])
	
	return true
end -- function craft_rice_flour


local function test_get_items_in_groups()
    items = get_items_in_group("group:food_bread")
    lf("generic_cooker", "items=" .. dump(items))
end

local function test_get_craft_requirements()
    name = "farming:pasta"
	local all = get_craft_requirements_from_registered(name, true)
	-- local all = get_craft_requirements_from_registered("farming:rice_flour", true)
	lf("generic_cooker", ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> test_get_recipe: name=" .. name .. ", requirements=" .. dump(all))
end

-- ,,tt
local function tests()
    -- test_get_replacement()
    -- test_get_items_in_groups()
    -- test_get_craft_requirements()
    local cookable_inputs = get_all_cookable_furnace_inputs()
    lf("tests", "cookable_inputs=" .. dump(cookable_inputs))
    lf("tests", "")
    error("tests")
end

local function try_remove_item_for_craft(inv, consumables)
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
            return nil
        end
        removed_items[#removed_items + 1] = removed
    end
    return removed_items
end

-- Helper function to check if all required items are available
local function check_required_items(inv, consumables, output_name)
    -- ,,x2
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
    return missing
end

-- Helper function to check required items with group expansion
local function check_required_items_with_group(inv, consumables, output_name)
    -- ,,x1
    local missing = false
    local matching_items = {} -- Store the actual items that will be used (list of {name, count})
    
    for name, count in pairs(consumables or {}) do
        -- Check if this is a group item
        if string.find(name, "group:", 1, true) == 1 then
            -- This is a group, get all items in this group
            local group_name = string.sub(name, 7) -- Remove "group:" prefix
            local group_items = get_items_in_group("group:" .. group_name)
            
            lf("generic_cooker", "craft_generic(" .. output_name .. "): checking group " .. group_name .. " with items: " .. dump(group_items))
            
            -- Check if any item in the group is available
            local found_item = false
            for _, item_name in ipairs(group_items or {}) do
                -- local needed = string.format("%s %d", item_name, count)
                local needed = string.format("%s %d", item_name, count)
                lf("generic_cooker", "craft_generic(" .. output_name .. "): checking for " .. needed)
                if inv:contains_item("main", needed) then
                    lf("generic_cooker", "craft_generic(" .. output_name .. "): found group item " .. needed)
                    table.insert(matching_items, {name = item_name, count = count}) -- Store the actual item that matches the group
                    found_item = true
                    break
                end
            end
            
            if not found_item then
                lf("generic_cooker", "craft_generic(" .. output_name .. "): missing any item from group " .. group_name)
                missing = true
                break
            end
        else
            -- This is a regular item, check normally
            local needed = string.format("%s %d", name, count)
            lf("generic_cooker", "craft_generic(" .. output_name .. "): checking for " .. needed)
            if inv:contains_item("main", needed) then
                table.insert(matching_items, {name = name, count = count}) -- Store the regular item
            else
                lf("generic_cooker", "craft_generic(" .. output_name .. "): missing " .. needed)
                missing = true
                break
            end
        end
    end
    return missing, matching_items
end

-- Helper: generic craft based on craft_outputs list.
-- Iterates craft_outputs and performs the first craftable recipe in the maidroid's inventory.
-- ,,cg,,craft
local function craft_generic(droid)
    lf("action_metrics", "craft_generic called")
	
	-- Update action_taken_metrics
	action_taken_metrics["crafts"] = (action_taken_metrics["crafts"] or 0) + 1
	lf("action_metrics", "crafts called: " .. action_taken_metrics["crafts"])
	
    local inv = droid and droid:get_inventory()
    if not inv then
        return false
    end -- if not inv

    for _, spec in ipairs(craft_outputs or {}) do
        local output_stack = ItemStack(spec)
        local output_name = output_stack:get_name()
        if output_name ~= "" then
            local recipe_options = get_craft_requirements_from_registered(output_name)
            if recipe_options then
                -- Try each recipe option until we find one that can be crafted
                for _, recipe_tuple in ipairs(recipe_options) do
                    local consumables = recipe_tuple[1]
                    local replacements = recipe_tuple[2]
                    
                    -- Ensure there is room for the result before consuming inputs.
                    if inv:room_for_item("main", output_stack) then
                        local missing, matching_items = check_required_items_with_group(inv, consumables, output_name)
                        
                        -- Convert matching_items list back to consumables table format
                        local new_consumables = {}
                        for _, item in ipairs(matching_items) do
                            new_consumables[item.name] = item.count
                        end
                        consumables = new_consumables

                        -- ,,x1
                        if not missing then
                            local removed_items = try_remove_item_for_craft(inv, consumables)

                            if removed_items then
                                for _, rep in ipairs(replacements or {}) do
                                    lf("generic_cooker", "craft_generic(" .. output_name .. "): replacement " .. dump(rep))
                                    local replacement_name = rep
                                    if replacement_name and replacement_name ~= "" then
                                        local replacement_stack = ItemStack(replacement_name)
                                        inv:add_item("main", replacement_stack)
                                        lf("generic_cooker", "craft_generic(" .. output_name .. "): returned replacement " .. replacement_stack:to_string())
                                    end
                                end

                                inv:add_item("main", output_stack)
                                lf("generic_cooker", "craft_generic: crafted " .. output_stack:to_string())
                                
                                -- Update craft_metrics
                                local crafted_name = output_stack:get_name()
                                craft_metrics[crafted_name] = (craft_metrics[crafted_name] or 0) + output_stack:get_count()
                                lf("craft_metrics", "crafted " .. output_stack:to_string() .. " total: " .. craft_metrics[crafted_name])
                                
                                return true
                            end
                        end
                    end
                end -- for recipe_options loop
            end -- if recipe_options
        end -- if output
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
        else
            lf("generic_cooker:act", "generic_cooker_take_item: no target")
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
	end

	-- Teleport back to starting position if available
	if droid.path_start_pos then
		droid.object:set_pos(droid.path_start_pos)
		lf("generic_cooker:act", ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Teleported back to start pos: " .. minetest.pos_to_string(vector.round(droid.path_start_pos)))
	end


	-- Action finished: return cleanly to wander behavior, like waffler.to_wander
	return to_wander(droid, "generic_cooker:act")
end

-- ,,task
task = function(droid)
    local pos = droid:get_pos()
    local inv = droid:get_inventory()

	-- : randomly pick one of two furnace actions, with choice 1 being twice as likely as choice 2
	-- Use math.random(3): values 1 and 2 map to choice 1, value 3 maps to choice 2
	local choice = math.random(3)
    -- choice = 3

	if choice == 1 then
		lf("generic_cooker:task", "CHOICE=1: try_feed_get_from_furnace__generic for ")
	    	try_feed_get_from_furnace__generic(droid, pos)
    elseif choice == 2 then
        lf("generic_cooker:task", "CHOICE=2: craft_generic")
        -- craft_rice_flour(droid)
        craft_generic(droid)
	else
		lf("generic_cooker:task", "CHOICE=3: try_get_item_from_nearby_chest for all_take_items count=" .. #all_take_items)
	    	try_get_item_from_nearby_chest(droid, pos, all_take_items)
	end
end

-- Check for fence detection failures
local check_fence_detection = function(droid)
	local front = droid:get_front()
	local below1 = vector.add(front, {x = 0, y = -1, z = 0})
	local below2 = vector.add(front, {x = 0, y = -2, z = 0})
	local pos_here = vector.round(droid:get_pos())
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
	if has_fence and not droid:is_blocked(maidroid.helpers.is_fence, true) then
		local pos = vector.round(droid:get_pos())
		minetest.log("warning",
			"[maidroid fence debug] FAILED blocked detection (farming); droid=" .. minetest.pos_to_string(pos) ..
			" front=" .. minetest.pos_to_string(front) ..
			" below1=" .. minetest.pos_to_string(below1) ..
			" below2=" .. minetest.pos_to_string(below2) ..
			" n_front=" .. n_front ..
			" n_below1=" .. n_below1 ..
			" n_below2=" .. n_below2 ..
			" n_here=" .. n_here ..
			" n_here_below=" .. n_here_below)
		if not droid.pause and droid.core and droid.core.on_pause then
			droid.core.on_pause(droid)
			droid.pause = true
		end
	end
end
-- ,,step
on_step = function(droid, dtime, moveresult)
	droid:pickup_item()

	-- Check if maidroid is more than 20 blocks away from activation position
	if droid._activation_pos then
		local current_pos = droid:get_pos()
		local distance = vector.distance(current_pos, droid._activation_pos)
		if distance > 10 then
			lf("generic_cooker", "Too far from activation (" .. string.format("%.1f", distance) .. " > 20), teleporting back")
			droid.object:set_pos(droid._activation_pos)
		end
	end

	-- Update metrics logging timer
	metrics_log_timer = metrics_log_timer + dtime
	if metrics_log_timer >= metrics_log_interval then
		log_chest_taken_metrics()
		metrics_log_timer = 0 -- Reset timer
	end

	if droid.state ~= maidroid.states.ACT and droid.state ~= maidroid.states.PATH then
	-- if droid.state ~= maidroid.states.ACT  then
		wander.on_step(droid, dtime, moveresult, task, is_fence_or_chest, true)
		-- Check for fence detection failures
		check_fence_detection(droid)
	end
    

    if droid.state == states.PATH then
		-- Even while following a path, still respect fences and chests by using the
		-- same is_blocked logic; this avoids unexpectedly crossing them.
		-- local isblocked = droid:is_blocked(is_fence_or_chest, true)
		-- if isblocked then
		-- 	lf("generic_cooker", "PATH blocked by fence; cancelling path")
			
		-- 	-- Update action_taken_metrics
		-- 	action_taken_metrics["path_blocked"] = (action_taken_metrics["path_blocked"] or 0) + 1
		-- 	-- lf("action_metrics", "path_blocked called: " .. awdction_taken_metrics["path_blocked"])
			
        --     			-- Stop the maidroid immediately without cancelling path targets
		-- 	droid:halt()
		-- 	droid:set_animation(maidroid.animation.STAND)
		-- 	return

		-- 	-- Cancel any pending path targets
		-- 	-- droid._generic_cooker_target = nil
		-- 	-- droid._furnace_target = nil
		-- 	-- to_wander(droid, "generic_cooker:path_blocked", 0, timers.change_dir_max)
		-- 	-- droid.timers.wander_skip = 1
		-- 	-- return
		-- end
		maidroid.cores.path.on_step(droid, dtime, moveresult)
	elseif droid.state == states.ACT then
		act(droid, dtime)
	end
end



-- Static counter to track on_start calls
local on_start_call_count = 0

-- ,,start
on_start = function(droid)
    -- on_start_call_count = on_start_call_count + 1
    -- if on_start_call_count > 1 then
    --     droid.object:remove()
    --     return
    -- end
    
    -- tests()
    lf("generic_cooker", "------------------------------------------------on_start------------------------------------------------")
    
    for _, item_name in ipairs(all_take_item_names) do
        table.insert(all_take_items, { item_name = item_name, quantity = 5 })
    end

    lf("generic_cooker", "all_take_items=" .. dump(all_take_items))
    

    lf("generic_cooker", "test")
    -- error("x")

    log_inventory(droid)
    
   
	wander.on_start(droid)
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
	no_jump = true,
	hat = hat,
	can_sell = true,
	doc = doc,
})

-- Test command to verify the function works
minetest.register_chatcommand("test_cookable_inputs", {
	description = "Test the get_all_cookable_furnace_inputs function",
	privs = {server=true},
	func = function(name)
		local cookable_inputs = maidroid.get_all_cookable_furnace_inputs()
        lf("test_cookable_inputs", "cookable_inputs=" .. dump(cookable_inputs))
		local output = {"Cookable furnace inputs found: " .. #cookable_inputs}
		local max_lines = 30
		for i, item_name in ipairs(cookable_inputs) do
            lf("test_cookable_inputs", "item=" .. item_name)
			if i <= max_lines then
				output[#output + 1] = string.format("%d. %s", i, item_name)
			else
				output[#output + 1] = string.format("... and %d more items", #cookable_inputs - max_lines)
				break
			end
		end
		return true, table.concat(output, "\n")
	end
})

-- Chat command to view chest taken metrics
minetest.register_chatcommand("chest_metrics", {
	description = "View chest taken metrics",
	privs = {server=true},
	func = function(name)
		local metrics = maidroid.get_chest_taken_metrics()
		local output = {"Chest Taken Metrics:"}
		
		if next(metrics) == nil then
			output[#output + 1] = "No items taken from chests yet."
		else
			for item_name, count in pairs(metrics) do
				output[#output + 1] = string.format("%s: %d", item_name, count)
			end
		end
		
		return true, table.concat(output, "\n")
	end
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
