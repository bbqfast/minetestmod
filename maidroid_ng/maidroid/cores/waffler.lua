------------------------------------------------------------
-- Copyleft (Я) 2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator

-- Core interface functions
local on_start, on_pause, on_resume, on_stop, on_step, is_tool
local act, task, to_action, to_wander
local is_water_source

local wander = maidroid.cores.wander
local states = maidroid.states
local farming_redo = farming and farming.mod and farming.mod == "redo"
local maker_dist = 2.5
maidroid.register_tool_rotation("maidroid:spatula", vector.new(-75,45,-45))

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

is_tool = function(stack)
	return stack:get_name() == "waffles:waffle_stack"
end

local actions = {
	craft_flour = "farming:wheat",
	craft_batter = "farming:flour",
	water = "bucket:bucket_empty",
	fill = "waffles:waffle_batter",
	collect = "maidroid:spatula",
}

to_action = function(droid)
	droid:halt()
	droid.timers.action = 0
	droid.state = maidroid.states.ACT
	droid:set_animation(maidroid.animation.MINE)
	droid:set_tool(droid.action and actions[droid.action] or "maidroid:hand")
end

local to_action_local = function(droid, target, action)
		droid.destination = target
		droid.action = action
		if target then
			droid:set_yaw({droid:get_pos(), target})
		-- else -- TODO use a workbench
		end
		to_action(droid)
end

to_wander = function(droid, itemset)
	-- Job is done clear references
	droid.destination = nil
	droid.action = nil

	if itemset then
		droid:add_items_to_main(itemset)
		if droid.pause then
			return
		end
	end

	droid:set_tool("maidroid:spatula")
	wander.to_wander(droid)
end

local is_water = function(pos)
	return minetest.get_node(pos).name == "default:water_source"
end

is_water_source = function(pos, name)
	if minetest.is_protected(pos, name) or not is_water(pos) then
		return false
	end
	local count = 0
	for _,i in ipairs({-1,1}) do
		if is_water(vector.add(pos, {x=i, y=0, z=0})) then
			count = count + 1
		end
		if is_water(vector.add(pos, {x=0, y=0, z=i})) then
			count = count + 1
		end
	end
	return count > 1
end

local can_craft_batter = function(inv, item)
	if not inv:contains_item("main", item or "bucket:bucket_water") then
		return false
	end
	return inv:contains_item("main", "farming:flour 2")
end

local cereals = {
	"farming:wheat"
}
if farming_redo then
	table.insert(cereals, "farming:barley")
	table.insert(cereals, "farming:oat")
	table.insert(cereals, "farming:rye")
end

local can_craft_flour = function(inv, amount)
	if farming_redo and not inv:contains_item("main", "farming:mortar_pestle") then
		return false
	end
	local count = 4 * ( amount or 1 )
	for _, cereal in ipairs(cereals) do
		cereal = cereal .. " " .. count
		if inv:contains_item("main", cereal) then
			return true, cereal
		end
	end
end

act = function(droid, dtime)
	if droid.timers.action < 2 then
		droid.timers.action = droid.timers.action + dtime
		return
	end

	if droid.action:sub(1,6) == "craft_" then
		droid.action = droid.action:sub(7)
		local inv = droid:get_inventory()
		if droid.action == "batter" then -- Prepare batter
			return to_wander(droid, { "bucket:bucket_empty"
				, "waffles:waffle_batter 3" })
		elseif droid.action == "flour" then -- Try to prepare flour
			if ( not farming_redo or inv:contains_item("main", "farming:mortar_pestle") ) then
				return to_wander(droid, {"farming:flour"})
			end
		end
		return to_wander(droid)
	elseif droid.action == "water" then -- Collect water from world
		local inv = droid:get_inventory()
		if is_water_source(droid.destination, droid.owner) and
			( can_craft_batter(inv, "bucket:bucket_empty") or
			(  inv:contains_item("main", "bucket:bucket_empty")
			and can_craft_flour(inv, 2) ) ) then
			minetest.remove_node(droid.destination)
			inv:remove_item("main", "bucket:bucket_empty")
			return to_wander(droid, { "bucket:bucket_water" })
		end
		return to_wander(droid)
	end

	local node = minetest.get_node(droid.destination)
	if  node.name ~= "waffles:waffle_maker_open" and
		node.name ~= "waffles:waffle_maker" then
		return to_wander(droid)
	end

	local cooked = minetest.get_meta(droid.destination):get_float("cooked")
	local nodedef = minetest.registered_nodes[node.name]
	if node.name == "waffles:waffle_maker" then
		if droid.action == "open" and cooked == -1 then
			nodedef.on_rightclick(droid.destination, node, nil, ItemStack("waffles:waffle_maker"))
			if minetest.get_node(droid.destination) == "waffles:waffles_maker_open" then
				return to_wander(droid)
			end
		end
	else
		if droid.action == "collect" and cooked >= 0.8 then
			nodedef.on_punch(droid.destination, node, droid) -- Collect waffle
			return to_wander(droid)
		elseif droid.action == "fill" then -- Fill with batter
			local inv = droid:get_inventory()
			if inv:contains_item("main", "waffles:waffle_batter") then
				local stack = ItemStack("waffles:waffle_batter")
				stack = nodedef.on_rightclick(droid.destination, node, nil, stack)
				if stack:is_empty() then
					inv:remove_item("main", "waffles:waffle_batter")
					return to_wander(droid)
				end
			end
		elseif droid.action == "close" then -- Cook waffle
			nodedef.on_rightclick(droid.destination, node, nil, ItemStack("waffles:waffle_maker"))
			return to_wander(droid)
		end
	end
	return to_wander(droid)
end

local store_path = function(action, target, distance, path)
	return {
		action = action,
		distance = distance,
		path = path,
		target = target,
	}
end

task = function(droid)
	local pos = droid:get_pos()
	local distance, path, previous

	local target = minetest.find_node_near(pos, 10, "waffles:waffle_maker")
	if target then -- open empty waffle makers
		distance = vector.distance(target,pos)
		if distance <= maker_dist then
			local cooked = minetest.get_meta(target):get_float("cooked")
			if cooked == -1 then -- check maker is empty
				return to_action_local(droid, target, "open")
			end
		else
			target = vector.add(target, {x=0, y=1, z=0})
			path = minetest.find_path(pos, target, 2, 1, 1)
			if path then
				previous = store_path("open", target, distance, path)
			end
		end
	end

	local inv = droid:get_inventory()
	target = minetest.find_node_near(pos, 10, "waffles:waffle_maker_open")
	if target then
		local l_action
		local cooked = minetest.get_meta(target):get_float("cooked")
		if cooked >= 0.8 then -- collect waffle
			l_action = "collect"
		elseif cooked == -1 then -- fill with batter
			if inv:contains_item("main", "waffles:waffle_batter") then
				l_action = "fill"
			end
		elseif cooked == 0 then -- close makers filled with batter
			l_action = "close"
		end

		if l_action then
			distance = vector.distance(target,pos)
			if distance <= maker_dist then
				return to_action_local(droid, target, l_action)
			elseif not previous or distance < previous.distance then
				target = vector.add(target, {x=0, y=1, z=0})
				path = minetest.find_path(pos, target, 2, 1, 1)
				if path then
					previous = store_path(l_action, target, distance, path)
				end
			end
		end
	end

	if inv:contains_item("main", "waffles:waffle_batter") then
		if previous then
			maidroid.cores.path.to_follow_path(droid, previous.path, previous.target, to_action, previous.action)
		end
		return
	end

	if can_craft_batter(inv) then
		inv:remove_item("main", "farming:flour 2")
		inv:remove_item("main", "bucket:bucket_water")
		return to_action_local(droid, nil, "craft_batter")
	end -- Prepare batter

	local ok, cereal = can_craft_flour(inv)
	if ok then
		inv:remove_item("main", cereal)
		return to_action_local(droid, nil, "craft_flour")
	end -- Prepare flour

	if can_craft_batter(inv, "bucket:bucket_empty") then
		target = maidroid.helpers.search_surrounding(pos, is_water_source, droid.owner)
		if target then
			return to_action_local(droid, target, "water")
		else
			target = minetest.find_node_near(pos, 10, "default:water_source")
			if target and is_water_source(target, droid.owner) then
				distance = vector.distance(pos, target)
				if not previous or distance < previous.distance then
					path = minetest.find_path(pos, target, 2, 1, 1)
					if path then
						previous = store_path("water", target, distance, path)
					end
				end
			end
		end
	end -- Collect water

	if previous then
		maidroid.cores.path.to_follow_path(droid, previous.path, previous.target, to_action, previous.action)
	end
end

on_step = function(droid, dtime, moveresult)
	-- Pickup surrounding items
	droid:pickup_item()

	if droid.state == states.WANDER then
		wander.on_step(droid, dtime, moveresult, task)
	elseif droid.state == states.PATH then
		maidroid.cores.path.on_step(droid, dtime, moveresult)
	elseif droid.state == states.ACT then
		act(droid, dtime)
	end
end

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

maidroid.cores.basic.doc = maidroid.cores.basic.doc .. "\t"
	.. S("Waffler: waffle stack") .. "\n"

local doc = S("They produce waffles faster than you") .. "\n\n"
	.. S("Abilities") .. "\n"
	.. "\t" .. S("Manage waffle makers") .. "\n"
	.. "\t" .. S("Craft batter") .. "\n"
	.. "\t" .. S("Craft flour") .. "\n"
	.. "\t" .. S("Collect water") .. "\n"
	.. "\n" .. S("Just waffles!")

maidroid.register_core("waffler", {
	description	= S("Waffle cooker"),
	on_start	= on_start,
	on_stop		= on_stop,
	on_resume	= on_resume,
	on_pause	= on_pause,
	on_step		= on_step,
	is_tool		= is_tool,
	default_item = "maidroid:spatula",
	hat = hat,
	can_sell = true,
	doc = doc,
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
