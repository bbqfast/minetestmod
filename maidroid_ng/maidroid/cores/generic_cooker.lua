------------------------------------------------------------
-- Copyleft (Я) 2026 mazes-style extension
-- Maidroid core: generic cooker (rice + furnace)
------------------------------------------------------------

local S = maidroid.translator

local on_start, on_pause, on_resume, on_stop, on_step, is_tool
local task

local wander = maidroid.cores.wander
local states = maidroid.states
local lf = maidroid.lf

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
	return stack:get_name() == "default:furnace"
end

local function take_rice_from_nearby_chest(droid, pos)
	local chest_pos = minetest.find_node_near(pos, 5, {"default:chest", "default:chest_locked"})
	if not chest_pos then
		return
	end

	lf("generic_cooker", "checking chest at " .. minetest.pos_to_string(chest_pos))
	local meta = minetest.get_meta(chest_pos)
	local owner = meta:get_string("owner")
	if owner and owner ~= "" and owner ~= droid.owner then
		return
	end

	local chest_inv = meta:get_inventory()
	local inv = droid:get_inventory()

	if not inv:room_for_item("main", "farming:seed_rice 1") then
		return
	end

	local stack = chest_inv:remove_item("main", "farming:seed_rice 1")
	if stack:is_empty() then
		return
	end

	lf("generic_cooker", "took " .. tostring(stack:get_count()) .. " farming:seed_rice from chest")
	inv:add_item("main", stack)
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

task = function(droid)
	local pos = droid:get_pos()

	local inv = droid:get_inventory()
	if not inv:contains_item("main", "farming:seed_rice 1") then
		take_rice_from_nearby_chest(droid, pos)
	end

	feed_furnace_from_inventory(droid, pos)
end

on_step = function(droid, dtime, moveresult)
	droid:pickup_item()

	if droid.state == states.WANDER then
		wander.on_step(droid, dtime, moveresult, task)
	elseif droid.state == states.PATH then
		maidroid.cores.path.on_step(droid, dtime, moveresult)
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
	default_item = "farming:seed_rice",
	hat = hat,
	can_sell = true,
	doc = doc,
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
