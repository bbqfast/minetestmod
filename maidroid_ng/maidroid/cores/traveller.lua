------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator

local lf = maidroid.lf

local timers = maidroid.timers

-- Import sleep module
dofile(minetest.get_modpath("maidroid") .. "/sleep.lua")

-- Core interface functions
local on_start, on_pause, on_resume, on_stop, on_step, is_tool

-- Core extra functions
local travel_to_destination, find_destination, to_action, to_wander
local task_base, task

local wander_core =  maidroid.cores.wander
local wander = maidroid.cores.wander
local to_wander = wander_core.to_wander
local core_path = maidroid.cores.path

local search = maidroid.helpers.search_surrounding

-- Traveller-specific configuration
local TRAVEL_RANGE = 50 -- Maximum distance to travel
local REST_INTERVAL = 5 -- Seconds to rest between travels
local MAX_CARRY_WEIGHT = 100 -- Maximum items the traveller can carry
local MAX_DISTANCE_FROM_ACTIVATION = 5 -- Maximum distance from activation point

-- Destination tracking
local destinations = {}
local current_destination = nil

-- Function to check distance from activation and teleport back if too far
local function check_distance_from_activation(self)
	local pos = self:get_pos()
	
	-- Check if we have an activation position
	if not self._activation_pos then
		self._activation_pos = vector.round(pos)
		lf("traveller", "Set activation position: " .. minetest.pos_to_string(self._activation_pos))
		return false
	end
	
	local distance = vector.distance(pos, self._activation_pos)
	
	-- If too far from activation, teleport back
	if distance > MAX_DISTANCE_FROM_ACTIVATION then
		lf("traveller", string.format("Too far from activation (%.1f > %d), teleporting back", distance, MAX_DISTANCE_FROM_ACTIVATION))
		
		-- Clear current destination and path
		current_destination = nil
		self.path = nil
		
		-- Teleport back to activation position
		self.object:set_pos(self._activation_pos)
		
		-- Return to wander state
		to_wander(self, "traveller:teleport_back")
		return true
	end
	
	return false
end

-- Function to find interesting destinations
local function find_interesting_destinations(self)
	local pos = self:get_pos()
	local found_destinations = {}
	
	-- Look for special nodes within range
	local nodes_to_find = {
		"default:chest",
		"default:chest_locked", 
		"beds:bed",
		"default:sign_wall",
		"default:sign_wall_wood"
	}
	
	for _, node_name in ipairs(nodes_to_find) do
		local found_pos = minetest.find_node_near(pos, TRAVEL_RANGE, {node_name})
		if found_pos then
			table.insert(found_destinations, {
				pos = found_pos,
				type = node_name,
				distance = vector.distance(pos, found_pos)
			})
		end
	end
	
	-- Sort by distance (closest first)
	table.sort(found_destinations, function(a, b)
		return a.distance < b.distance
	end)
	
	return found_destinations
end

-- Function to check if a destination is reachable and safe
local function is_destination_safe(self, dest_pos)
	if minetest.is_protected(dest_pos, self.owner) then
		lf("traveller", "Destination " .. minetest.pos_to_string(dest_pos) .. " is protected")
		return false
	end
	
	-- Check if destination is not in dangerous terrain
	local node = minetest.get_node(dest_pos)
	if node.name == "default:lava_source" or node.name == "default:lava_flowing" then
		lf("traveller", "Destination contains lava")
		return false
	end
	
	return true
end

-- Function to travel to a destination
travel_to_destination = function(self, destination)
	if not destination then
		lf("traveller", "No destination provided")
		return false
	end
	
	if not is_destination_safe(self, destination) then
		lf("traveller", "Destination is not safe")
		return false
	end
	
	local pos = self:get_pos()
	lf("traveller", "Traveling to destination: " .. minetest.pos_to_string(destination))
	
	-- Use task_base to handle pathfinding and movement
	if task_base(self, travel_to_destination, destination) then
		current_destination = destination
		return true
	else
		lf("traveller", "Could not find path to destination")
		return false
	end
end

-- ,,task
-- Task base function for handling movement and actions
task_base = function(self, action, destination)
	if not destination then 
		lf("traveller:task_base", "No destination provided")
		return false
	end

	local pos = self:get_pos()
	local distance = vector.distance(pos, destination)
	
	-- If already at destination, perform action
	if distance < 2 then
		lf("traveller:task_base", "Already at destination, performing action")
		self.destination = destination
		self.action = action
		to_action(self)
		return true
	end

	-- Find path to destination
	lf("traveller:task_base", "Finding path from " .. minetest.pos_to_string(pos) .. " to " .. minetest.pos_to_string(destination))
	local path = minetest.find_path(pos, destination, 8, 1, 1, "A*")

	if path ~= nil then
		lf("traveller:task_base", "Path found with " .. #path .. " nodes")
		self:set_yaw({self:get_pos(), destination})
		core_path.to_follow_path(self, path, destination, to_action, action)
		return true
	else
		lf("traveller:task_base", "No path found")
		return false
	end
end

-- Action state handler
to_action = function(self)
	lf("DEBUG traveller:to_action", "to_action called, setting action state")
	self.state = maidroid.states.ACTION
	self:set_animation(maidroid.animation.WALK)
end

-- ,,wand
-- Wander state handler for traveller
to_wander = function(self, from_caller)
	lf("traveller:to_wander", "returning to wander from " .. tostring(from_caller))
	-- Clear any current job-specific intent and delegate to the wander core,
	-- similar to generic_cooker.lua's to_wander behavior.
	self.destination = nil
	self.action = nil
	self._bed_target = nil
	-- Set the correct tool for traveller
	self:set_tool("default:bronzeblock")
	lf("traveller:to_wander", "setting state to WANDER")
	wander.to_wander(self, from_caller or "traveller:to_wander")
end

-- ,,act
-- Action handler
local act = function(self)
	lf("DEBUG traveller:act", "act function called! action=" .. tostring(self.action))
	
	-- if not self.action then
	-- 	lf("DEBUG traveller:act", "no action, returning")
	-- 	return
	-- end
	
	lf("traveller:act", "handling action: " .. tostring(self.action))
	
	if self.action == "traveller_sleep" then
		lf("DEBUG traveller:act", "traveller_sleep: " .. minetest.pos_to_string(self:get_pos()))
		local target = self._bed_target
		if target and target.pos then
			-- Check if beds mod is available
			if beds then
				maidroid.sleep.handle_sleep_action(self, target.pos)
				lf("DEBUG traveller:act", "sleep action completed, staying in sleep state")
				return nil -- Prevent return to wander
			else
				lf("DEBUG traveller:act", "beds mod not available for sleeping")
			end
		else
			lf("DEBUG traveller:act", "traveller_sleep: no bed target")
		end
		self._bed_target = nil
	else
		lf("DEBUG traveller:act", "unknown action: " .. tostring(self.action))
	end
	
	-- Return to wander after action completion
	to_wander(self, "traveller:act")
end

-- ,,task
task = function(self)
	local pos = self:get_pos()
	local inv = self:get_inventory()
	
	-- Randomly pick one of three actions, with choice 1 being twice as likely as others
	-- Use math.random(4): values 1 and 2 map to choice 1, values 3 and 4 map to choices 2 and 3
	local choice = math.random(4)
	choice = 3

	if choice == 1 or choice == 2 then
		lf("DEBUG traveller:task", "CHOICE=" .. choice .. ": find_and_travel_to_destination")
		local destinations = find_interesting_destinations(self)
		if #destinations > 0 then
			local next_dest = destinations[1]
			lf("traveller:task", "Found destination: " .. next_dest.type .. " at " .. minetest.pos_to_string(next_dest.pos))
			travel_to_destination(self, next_dest.pos)
		else
			lf("traveller:task", "No destinations found, staying idle")
		end
	elseif choice == 3 then
		lf("DEBUG traveller:task", "CHOICE=3: try_sleep_in_bed - about to call")
		lf("DEBUG traveller:task", "pos=" .. minetest.pos_to_string(pos))
		lf("DEBUG traveller:task", "core_module params: to_action=" .. tostring(to_action) .. ", name=traveller")
		local result = maidroid.sleep.try_sleep_in_bed(self, pos, {to_action = to_action, name = "traveller"})
		lf("DEBUG traveller:task", "try_sleep_in_bed returned: " .. tostring(result))
	else
		lf("DEBUG traveller:task", "CHOICE=4: explore_nearby_area")
		-- Simple exploration - pick a random nearby position and try to go there
		local random_offset = {
			x = math.random(-TRAVEL_RANGE/2, TRAVEL_RANGE/2),
			y = 0,
			z = math.random(-TRAVEL_RANGE/2, TRAVEL_RANGE/2)
		}
		local explore_pos = vector.add(pos, random_offset)
		lf("traveller:task", "Exploring position: " .. minetest.pos_to_string(explore_pos))
		travel_to_destination(self, explore_pos)
	end
end

-- ,,start
-- Core interface functions
on_start = function(self)
	self.path = nil
	current_destination = nil
	
	-- Store activation position if not already set
	if not self._activation_pos then
		self._activation_pos = vector.round(self:get_pos())
		lf("traveller", "Stored activation position: " .. minetest.pos_to_string(self._activation_pos))
	end
	
	wander_core.on_start(self)
	lf("traveller", "Traveller core started")
end

on_resume = function(self)
	self.path = nil
	wander_core.on_resume(self)
	lf("traveller", "Traveller core resumed")
end

on_stop = function(self)
	self.path = nil
	current_destination = nil
	wander_core.on_stop(self)
	lf("traveller", "Traveller core stopped")
end

on_pause = function(self)
	wander_core.on_pause(self)
	lf("traveller", "Traveller core paused")
end

-- ,,step
-- Main step function
on_step = function(self, dtime, moveresult)
	-- Check if maidroid is sleeping - if so, prevent all movement and processing
	if maidroid.sleep.on_step_sleep_check(self, dtime, moveresult) then
		return -- Skip all other processing while sleeping
	end
	
	-- Check distance from activation position and teleport back if too far
	if check_distance_from_activation(self) then
		return -- Teleported back, skip other processing
	end
	
	-- Ensure we have the correct tool (bronze block) when not sleeping
	if not self._is_sleeping and self.selected_tool ~= "default:bronzeblock" then
		self:set_tool("default:bronzeblock")
		self.selected_tool = "default:bronzeblock"
		lf("traveller:on_step", "corrected tool to bronze block")
	end
	
	-- Handle ACTION state by calling act function
	if self.state == maidroid.states.ACTION then
		lf("DEBUG traveller:on_step", "In ACTION state, calling act function")
		act(self)
		return
	end
	
	-- Handle PATH state by delegating to path core
	if self.state == maidroid.states.PATH then
		lf("DEBUG traveller:on_step", "In PATH state, delegating to path core")
		maidroid.cores.path.on_step(self, dtime, moveresult)
		return
	end
	
	-- Use wander core's on_step with our task function
	-- This handles the wander behavior and calls our task function periodically
	if self.state ~= maidroid.states.ACT then
		wander_core.on_step(self, dtime, moveresult, task)
	end
end

-- Tool checking function
is_tool = function(stack)
	if not stack or stack:is_empty() then
		return false
	end
	
	local tool_name = stack:get_name()
    lf("traveller", "is_tool: " .. tool_name)
	return tool_name == "default:bronzeblock"
end

-- Documentation for the traveller core
local doc = S("Traveller maidroid core") .. "\n\n"
	.. S("The traveller maidroid explores the world and visits interesting locations.") .. "\n"
	.. S("It can find and travel to chests, beds, signs, and other points of interest.") .. "\n\n"
	.. S("Activation: Give the maidroid a bronze block to activate traveller mode.") .. "\n\n"
	.. S("Features:") .. "\n"
	.. "- " .. S("Automatic destination finding") .. "\n"
	.. "- " .. S("Safe pathfinding") .. "\n"
	.. "- " .. S("Periodic exploration") .. "\n"
	.. "- " .. S("Occasional sleeping in beds") .. "\n"
	.. "- " .. S("Distance limit (10 blocks from activation)") .. "\n"
	.. "- " .. S("Auto-teleport back if too far") .. "\n"
	.. "- " .. S("Wanders when no destinations available") .. "\n\n"
	.. S("The traveller will automatically explore within a configurable range and return to wandering when no destinations are found.") .. "\n"
	.. S("It will occasionally sleep in nearby beds to rest during its travels.") .. "\n"
	.. S("If the traveller gets more than 10 blocks away from its activation position, it will automatically teleport back.")

-- Register the traveller core
maidroid.register_core("traveller", {
	description      = S("a traveller"),
	on_start         = on_start,
	on_stop          = on_stop,
	on_resume        = on_resume,
	on_pause         = on_pause,
	on_step          = on_step,
	act              = act,
	is_tool          = is_tool,
	default_item     = "default:bronzeblock",
	to_wander        = to_wander,
	doc = doc,
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
