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

local DIG_BELOW_INTERVAL = 0.5

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

local follow = maidroid.cores.follow.on_step
local wander = maidroid.cores.wander.on_step

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

local lf = function(func, msg)
	local pre="**************************************************"
	local pre="++++++++++++++++++++++++++++++++++++++++++++++++++"
	if msg == nil then
		msg = "null"
	end

	black_list={}
	-- black_list["mow"]=true
	black_list["select_seed"]=true
	black_list["mow"]=true

	if (black_list[func] == nil) then
		-- ll("LF mow: "..msg)
		ll(func.."(): "..msg)
		-- ll(func.."(): "..msg)
	end
end

local ld = function(msg, dest)
	if (dest ~= nil) then
		local destnode = minetest.get_node(dest)
		-- ll(msg.." "..destnode.name)
	end
	
end

-- ,,x1
local function extract_before_underscore(str)
    -- return str:match("([^_]*)")
    return str:match("(.*)_[0-9]+")
end


on_start = function(self)
	lf("digger:on_start", "initialized digger core")

	self.path = nil
	-- wander_core.on_start(self)
	self.state = maidroid.states.IDLE
	self.timers.walk = 0
	self.timers.change_dir = 0
	self.timers.place_torch = 0
	self.timers.dig_below = 0
	self.is_placing = false
	self:halt()
	self:set_animation(maidroid.animation.STAND)	
	self._old_accel = self.object:get_acceleration()
	self.object:set_acceleration({x = 0, y = -3, z = 0})  -- tweak -3 → -2/-4 as you like
end

on_resume = function(self)
	self.path = nil
	-- wander_core.on_resume(self)
end

on_stop = function(self)
	self.path = nil
	-- wander_core.on_stop(self)
	
end

on_pause = function(self)
	wander_core.on_pause(self)
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


to_action = function(self)
	self.state = maidroid.states.ACT
	self.timers.action = 0
	self.timers.walk = 0
end

local move_up_one = function(self)
	local pos = self:get_pos()
	-- if pos and self.object then
	-- 	self.object:set_pos({x = pos.x, y = pos.y + 2, z = pos.z})
	-- end
end



local dig_block_below = function(self)
	local pos = self:get_pos()
	if not pos then
		return
	end

	local below = vector.add(pos, { x = 0, y = -1, z = 0 })
	if minetest.is_protected(below, self.owner) then
		return
	end

	local node = minetest.get_node(below)
	if not node or node.name == "air" then
		return
	end

	local drops = minetest.get_node_drops(node.name)
	minetest.remove_node(below)

	move_up_one(self)
	if not drops or #drops == 0 then
		return
	end

	local stacks = {}
	for _, item in ipairs(drops) do
		table.insert(stacks, ItemStack(item))
	end

	if #stacks > 0 and self.add_items_to_main then
		self:add_items_to_main(stacks)
	end
end

on_step = function(self, dtime, moveresult)
	if self.object and self.object:get_velocity().y < -1 then
		local vel = self.object:get_velocity()
		self.object:set_velocity({x = vel.x, y = math.max(vel.y, -1), z = vel.z})
	end

	-- get owner safely
	local player = minetest.get_player_by_name(self.owner)

	local pos = self:get_pos()
	if pos then
		local light_pos = {
			x = math.floor(pos.x + 0.5),
			y = math.floor(pos.y),
			z = math.floor(pos.z + 0.5),
		}

		-- Always light up when close to player, regardless of what they're holding
		local should_light = false
		if player then
			local ppos = player:get_pos()
			if ppos then
				local dist = vector.distance(ppos, pos)
				if dist <= 15 then
					should_light = true
				end
			end
		end

		local node = minetest.get_node(light_pos)

		if self._last_light_pos and node and node.name == "maidroid:helper_light" then
			local moved = vector.distance(light_pos, self._last_light_pos) > 0.1
			if moved then
				minetest.remove_node(self._last_light_pos)
				lf("digger:on_step", "Moved helper_light from " .. minetest.pos_to_string(self._last_light_pos) .. " to " .. minetest.pos_to_string(light_pos))
				if node.name == "air" or node.name == "ignore" then
					minetest.set_node(light_pos, {name = "maidroid:helper_light"})
				end
			end
		end

		if should_light then
			if node.name ~= "maidroid:helper_light" then
				if self._last_light_pos then
					minetest.remove_node(self._last_light_pos)
				end
				minetest.set_node(light_pos, {name = "maidroid:helper_light"})
				lf("digger:on_step", "Placed helper_light at " .. minetest.pos_to_string(light_pos))
				self._last_light_pos = vector.new(light_pos)
				self._last_light_node = node and node.name or nil
			else
				self._last_light_pos = vector.new(light_pos)
				self._last_light_node = node and node.name or nil
			end
		else
			if node.name == "maidroid:helper_light" then
				minetest.remove_node(light_pos)
			end
			self._last_light_pos = nil
			self._last_light_node = nil
		end
	end

	-- Check for lava and move up if necessary
	pos = self:get_pos()
	if pos and self.object then
		local here = vector.round(pos)
		local here_node = minetest.get_node(here)
		if here_node and (
			here_node.name == "default:lava_source" or
			here_node.name == "default:lava_flowing" or
			here_node.name == "default:water_source" or
			here_node.name == "default:water_flowing" or
			here_node.name == "default:river_water_source" or
			here_node.name == "default:river_water_flowing" or
			minetest.get_item_group(here_node.name, "water") > 0
		) then
			minetest.log("action", "[maidroid:digger] Emergency escape at " .. minetest.pos_to_string(pos))
			self.object:set_pos({x = pos.x, y = pos.y + 3, z = pos.z})
		end
	end

	if not self._digger_accum then
		self._digger_accum = 0
	end
	self._digger_accum = self._digger_accum + dtime
	if self._digger_accum < 1 then
		return
	end
	dtime = self._digger_accum
	self._digger_accum = 0

	player = minetest.get_player_by_name(self.owner)
	lf("digger:on_step", "Checking teleport: player=" .. tostring(player and player:get_player_name() or "nil") ..
		", wielded=" .. tostring(player and player:get_wielded_item():get_name() or "nil"))
	if player then
		local inv = self:get_inventory()
		local first_stack = inv and inv:get_stack("main", 1)
		if first_stack and player:get_wielded_item():get_name() == first_stack:get_name() then
			local self_pos = self:get_pos()
			lf("digger:on_step", "Teleport trigger: self_pos=" .. minetest.pos_to_string(self_pos or {}))
			if self_pos then
				player:set_pos({x = self_pos.x, y = self_pos.y + 5, z = self_pos.z})
				minetest.chat_send_player(player:get_player_name(), "Teleported to your maidroid!")
			end
		end
	end

	local func_name = "digger:on_step"
	player = minetest.get_player_by_name(self.owner)
	if player and (player:get_wielded_item():get_name() == "default:pick_stone" or player:get_wielded_item():get_name() == "lottores:goldpick") then
		local player_pos = player:get_pos()
		self.object:set_pos({x = player_pos.x, y = player_pos.y + 1, z = player_pos.z})
		return
	end

	if maidroid.settings.farming_offline == false
		and not minetest.get_player_by_name(self.owner) then
		return
	end

	self:pickup_item()

	pos = self:get_pos()
	local min_y = math.floor(pos.y) - 1
	local found = false
	local target_x, target_y
	for y = min_y, min_y - 10, -1 do
		local check_pos = {x = math.floor(pos.x + 0.5), y = y, z = math.floor(pos.z + 0.5)}
		local node = minetest.get_node(check_pos)
		if node and node.name ~= "air" and node.name ~= "ignore" then
			target_x, target_y = check_pos.x, check_pos.y
			found = true
			break
		end
	end
	if not found then
		target_x, target_y = math.floor(pos.x + 0.5), min_y
	end

	if found and self.object and pos then
		self.object:set_pos({x = target_x, y = pos.y, z = math.floor(pos.z + 0.5)})
	end

	self.timers.dig_below = (self.timers.dig_below or 0) + dtime
	if self.timers.dig_below >= DIG_BELOW_INTERVAL then
		self.timers.dig_below = 0
		self:set_animation(maidroid.animation.MINE)
		local pos = self:get_pos()
		local below = vector.add(pos, { x = 0, y = -1, z = 0 })
		minetest.add_particlespawner({
			amount = 16,
			time = 0.2,
			minpos = vector.subtract(below, 0.3),
			maxpos = vector.add(below, 0.3),
			minvel = {x = -0.5, y = 0.5, z = -0.5},
			maxvel = {x = 0.5, y = 1.5, z = 0.5},
			minacc = {x = 0, y = -9.8, z = 0},
			maxacc = {x = 0, y = -9.8, z = 0},
			minexptime = 0.3,
			maxexptime = 0.7,
			minsize = 1,
			maxsize = 2,
			texture = minetest.registered_nodes[minetest.get_node(below).name] and
				(minetest.registered_nodes[minetest.get_node(below).name].tiles[1] or "default_dirt.png") or "default_dirt.png",
			glow = 0,
		})

		local node_below = minetest.get_node(below)
		lf("digger", "node_below: " .. node_below.name)
		if node_below and (node_below.name == "default:lava_source" or node_below.name == "default:lava_flowing") then
			self.object:set_pos({x = pos.x, y = pos.y + 1, z = pos.z})
			minetest.set_node(below, {name = "default:water_source"})
			self.timers.dig_below = -2
			move_up_one(self)
			return
		end

		node_below = minetest.get_node(below)
		if node_below and (
			node_below.name == "default:water_source"
			or node_below.name == "default:river_water_source"
			or node_below.name == "default:water_flowing"
			or node_below.name == "default:river_water_flowing"
			or minetest.get_item_group(node_below.name, "water") > 0
		) then
			for dx = -1, 1 do
				for dz = -1, 1 do
					local pos_to_set = {x = below.x + dx, y = below.y, z = below.z + dz}
					local n = minetest.get_node(pos_to_set)
					if n and (
						n.name == "default:water_source"
						or n.name == "default:river_water_source"
						or n.name == "default:water_flowing"
						or n.name == "default:river_water_flowing"
						or minetest.get_item_group(n.name, "water") > 0
					) then
						minetest.set_node(pos_to_set, {name = "default:dirt"})
						lf("digger", "setting to dirt: " .. n.name .. " at " .. minetest.pos_to_string(pos_to_set))
					end
				end
			end
			self.timers.dig_below = -2
			move_up_one(self)
			return
		end

		node_below = minetest.get_node(below)
		if node_below and node_below.name == "air" then
			self.timers.dig_below = self.timers.dig_below - dtime + 2
			return
		end

		dig_block_below(self)
	end
end


is_tool = function(stack)
	local name = stack:get_name()
	lf("is_tool", "stack  "..name)

	local istool = name == "default:pick_stone" or name == "default:pick_gold" or name == "lottores:goldpick"
	-- local istool = minetest.get_item_group(name, "pickaxe") > 0

	lf("is_tool", "is_tool: "..tostring(istool))
	return istool
	-- return true
end

maidroid.cores.basic.doc = maidroid.cores.basic.doc .. "\t"
	.. S("Digger: pickaxes") .. "\n"


maidroid.register_core("digger", {
	description	= S("a digger"),
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
-- maidroid.new_state("ACT")

minetest.register_node("maidroid:helper_light", {
    description = "Maidroid Helper Light (Invisible)",
    drawtype = "airlike",
    tiles = {"invisible.png"},
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = false,
    light_source = 14,  -- same as torch
    groups = {not_in_creative_inventory = 1},
    selection_box = {
        type = "regular",
    },
})