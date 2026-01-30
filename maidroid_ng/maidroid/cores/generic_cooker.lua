------------------------------------------------------------
-- Copyleft (Я) 2026 mazes-style extension
-- Maidroid core: generic cooker (rice + furnace)
------------------------------------------------------------

local S = maidroid.translator

local on_start, on_pause, on_resume, on_stop, on_step, is_tool
local task, to_action, to_wander, act

local wander = maidroid.cores.wander
local states = maidroid.states
local lf = maidroid.lf
local chest_reach_dist = 2.5

-- Encapsulated target info for a single chest interaction
local GenericCookerTarget = {}
GenericCookerTarget.__index = GenericCookerTarget

function GenericCookerTarget.new(chest_pos, item_name, max_take)
	return setmetatable({
		pos = chest_pos,
		item_name = item_name,
		max_take = max_take,
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

local function take_item_from_chest(droid, chest_pos, item_name, max_take)
	if not chest_pos then
		return false
	end

	lf("generic_cooker", "checking chest at " .. minetest.pos_to_string(chest_pos))
	local meta = minetest.get_meta(chest_pos)
	local owner = meta:get_string("owner")
	if owner and owner ~= "" and owner ~= droid.owner then
		return false
	end

	local chest_inv = meta:get_inventory()
	local inv = droid:get_inventory()

	local take_count = max_take or 1
	if take_count <= 0 then
		return false
	end

	if not inv:room_for_item("main", item_name .. " " .. tostring(take_count)) then
		return false
	end

	local stack = chest_inv:remove_item("main", item_name .. " " .. tostring(take_count))
	if stack:is_empty() then
		return false
	end

	lf("generic_cooker", "took " .. tostring(stack:get_count()) .. " " .. item_name .. " from chest")
	inv:add_item("main", stack)
	return true
end

-- ,,chest
local function try_get_item_from_nearby_chest(droid, pos, item_name, max_take)
	local chest_pos = minetest.find_node_near(pos, 5, {"default:chest", "default:chest_locked"})
	if not chest_pos then
        lf("generic_cooker", "try_get_item_from_nearby_chest: no chest found")
		return false
	end

	-- local distance = vector.distance(pos, chest_pos)
	-- if distance <= chest_reach_dist then
	-- 	-- Already close enough: perform a short ACT with mine animation while taking from chest
	-- 	local target = vector.add(chest_pos, {x=0, y=1, z=0})
	-- 	droid._generic_cooker_target = GenericCookerTarget.new(chest_pos, item_name, max_take)
	-- 	droid.destination = target
	-- 	droid.action = "generic_cooker_take_item"
	-- 	to_action(droid)
	-- 	return true
	-- end

    -- ,,x1
	local target = vector.add(chest_pos, {x=0, y=1, z=0})
	-- local path = minetest.find_path(pos, target, 5, 1, 1)
    local path = minetest.find_path(pos, target, 5, 2, 2, "A*_noprefetch")
	if not path then
        lf("generic_cooker", "try_get_item_from_nearby_chest: no path found")
		return false
	end

	droid._generic_cooker_target = GenericCookerTarget.new(chest_pos, item_name, max_take)
	-- Show bucket while walking to chest, similar to farming dump logic
	droid:set_tool("bucket:bucket_empty")
	maidroid.cores.path.to_follow_path(droid, path, target, to_action, "generic_cooker_take_item")
	return true
end

-- ,,furnace
-- When collect_finished is true, the droid will walk to the furnace and then
-- run a special collect action instead of feeding items.
local function try_put_item_in_furnace(droid, pos, item_name, item_count, collect_finished)
	local furnace_pos = minetest.find_node_near(pos, 8, "default:furnace")
	if not furnace_pos then
        lf("generic_cooker:try_put_item_in_furnace", "furnace not found: pos=" .. minetest.pos_to_string(pos))
		return false
	end

	local target = vector.add(furnace_pos, {x=0, y=1, z=0})
	-- Extra debug: log start/target and nodes around them (kept commented for noise control)
	-- local rounded_pos = vector.round(pos)
	-- local start_node = minetest.get_node(rounded_pos)
	-- local below_target = vector.add(target, {x=0, y=-1, z=0})
	-- local below_node = minetest.get_node(below_target)
	-- lf("generic_cooker:try_put_item_in_furnace", "find_path from=" .. minetest.pos_to_string(rounded_pos)
	-- 	.. " (node=" .. start_node.name .. ") to target=" .. minetest.pos_to_string(target)
	-- 	.. " below_target_node=" .. below_node.name)

	-- Use a wider search distance and slightly more permissive jump/drop,
	-- similar to farming's task_base pathfinder usage.
	local rounded_pos = vector.round(pos)
	local path = minetest.find_path(rounded_pos, target, 8, 2, 2, "A*_noprefetch")
	if not path then
		lf("generic_cooker:try_put_item_in_furnace", "path not found")
		return false
	end

	-- Use a separate target slot for furnace interactions so it does not
	-- conflict with the chest target state.
	droid._furnace_target = GenericCookerTarget.new(furnace_pos, item_name, item_count)
	-- Show a cooking tool while walking to the furnace
	droid:set_tool("maidroid:spatula")
	if not collect_finished then
	    lf("generic_cooker:try_put_item_in_furnace", "putting " .. tostring(item_count) .. " " .. item_name .. " into furnace at " .. minetest.pos_to_string(furnace_pos))
	end
	local action_name
	if collect_finished then
		action_name = "generic_cooker_collect_finished"
	else
		action_name = "generic_cooker_put_item"
	end
	maidroid.cores.path.to_follow_path(droid, path, target, to_action, action_name)
	return true
end

-- ,,furnace
-- NOTE: here 'pos' is expected to be the actual furnace position already
-- (normal or active). We no longer search again, to avoid failing when
-- the furnace is burning.
local function feed_furnace_from_inventory_generic(droid, pos, item_name, item_count)
	if not pos then
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

	local count = item_count or 1
	if count <= 0 then
        lf("generic_cooker:feed_furnace_from_inventory_generic", "count <= 0")
		return false
	end

	local listname
	if item_name == "default:coal_lump" then
		listname = "fuel"
	else
		listname = "src"
	end

	-- Try to remove up to 'count' items; if the player has fewer,
	-- remove and use whatever is available.
	local spec = item_name .. " " .. tostring(count)
	local stack = inv:remove_item("main", spec)
	if stack:is_empty() then
        lf("generic_cooker:feed_furnace_from_inventory_generic", "stack is empty")
		return false
	end
	if not finv:room_for_item(listname, stack) then
		-- Not enough room for the amount we actually removed; put it back.
		inv:add_item("main", stack)
		return false
	end

	finv:add_item(listname, stack)
	lf("generic_cooker", "feed_furnace_from_inventory_generic: added " .. tostring(stack:get_count()) .. " " .. item_name .. " to " .. listname .. " at " .. minetest.pos_to_string(pos))
	return true
end

-- Collect finished items from a nearby furnace into the droid's inventory
-- ,,finish
local function collect_finished_from_furnace(droid, pos)
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
local function feed_get_from_furnace__generic(droid, pos, item_name, item_count)
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

	-- Otherwise, treat furnace as empty for our purposes and feed it.
	return feed_furnace_from_inventory_generic(droid, pos, item_name, item_count)
end

-- fg1,
-- Pathfinding helper: walk to a nearby furnace and then perform the
-- combined feed/get behavior defined in feed_get_from_furnace__generic.
local function try_feed_get_from_furnace__generic(droid, pos, item_name, item_count)
	local furnace_pos = minetest.find_node_near(pos, 8, "default:furnace")
	if not furnace_pos then
		lf("generic_cooker:try_feed_get_from_furnace__generic", "furnace not found: pos=" .. minetest.pos_to_string(pos))
		return false
	end

	local target = vector.add(furnace_pos, {x=0, y=1, z=0})
	local rounded_pos = vector.round(pos)
	local path = minetest.find_path(rounded_pos, target, 8, 2, 2, "A*_noprefetch")
	if not path then
		lf("generic_cooker:try_feed_get_from_furnace__generic", "path not found")
		return false
	end

	droid._furnace_target = GenericCookerTarget.new(furnace_pos, item_name, item_count)
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
		if target and target.pos and target.item_name then
			take_item_from_chest(
				droid,
				target.pos,
				target.item_name,
				target.max_take
			)
		end
		droid._generic_cooker_target = nil
	elseif droid.action == "generic_cooker_feed_get" then
        lf("generic_cooker:act", "generic_cooker_feed_get: " .. minetest.pos_to_string(droid:get_pos()))
		local target = droid._furnace_target
		if target and target.pos and target.item_name then
			feed_get_from_furnace__generic(
				droid,
				target.pos,
				target.item_name,
				target.max_take
			)
		end
		droid._furnace_target = nil
	elseif droid.action == "generic_cooker_collect_finished" then
        lf("generic_cooker:act", "generic_cooker_collect_finished: " .. minetest.pos_to_string(droid:get_pos()))
		local target = droid._furnace_target
		if target and target.pos then
			collect_finished_from_furnace(droid, target.pos)
		end
		droid._furnace_target = nil
	end

	-- Action finished: return cleanly to wander behavior, like waffler.to_wander
	return to_wander(droid, "generic_cooker:act")
end

-- ,,task
task = function(droid)
	local pos = droid:get_pos()

	local inv = droid:get_inventory()

	-- ,,x2: randomly pick one of three furnace actions
	local choice = math.random(2)
	if choice == 1 then
		-- lf("generic_cooker:task", "CHOICE=1: try_get_item_from_nearby_chest for farming:seed_rice")
        -- try_get_item_from_nearby_chest(droid, pos, "farming:seed_rice", 5)
        -- if not inv:contains_item("main", "farming:seed_rice 1") then
        --     if try_get_item_from_nearby_chest(droid, pos, "farming:seed_rice", 5) then
        --         return
        --     end
        -- end
    -- elseif choice == 2 then
		lf("generic_cooker:task", "CHOICE=1: try_feed_get_from_furnace__generic for ")
        try_feed_get_from_furnace__generic(droid, pos, "farming:seed_rice", 5)
	-- elseif choice == 2 then
	-- 	lf("generic_cooker:task", "CHOICE=2: try_put_item_in_furnace with farming:seed_rice")
	-- 	try_put_item_in_furnace(droid, pos, "farming:seed_rice", 5)
	-- elseif choice == 3 then
	-- 	lf("generic_cooker:task", "CHOICE=3: walk to furnace and collect finished items")
    --     try_put_item_in_furnace(droid, pos, "farming:seed_rice", 0, true)
	else
		lf("generic_cooker:task", "CHOICE=2: try_get_item_from_nearby_chest for farming:seed_rice")
        try_get_item_from_nearby_chest(droid, pos, "farming:seed_rice", 5)
        
		-- lf("generic_cooker:task", "CHOICE=4: feed coal into furnace")
		-- Feed coal into furnace
		-- try_put_item_in_furnace(droid, pos, "default:coal_lump", 5)
	end
	-- feed_furnace_from_inventory(droid, pos)
	-- feed_furnace_from_inventory_generic(droid, pos, "default:coal_lump", 5)
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
	hat = hat,
	can_sell = true,
	doc = doc,
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
