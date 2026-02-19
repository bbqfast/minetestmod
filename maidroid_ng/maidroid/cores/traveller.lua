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


-- Function to teleport to saved shower position
local function teleport_to_shower_position(droid)
	if not droid._shower_pos then
		lf("traveller", "No saved shower position available for teleport")
		return false
	end
	
	local current_pos = droid:get_pos()
	local shower_pos = droid._shower_pos
	
	lf("traveller", "Teleporting from " .. minetest.pos_to_string(current_pos) .. " to shower at " .. minetest.pos_to_string(shower_pos))
	
	-- Calculate teleport position (slightly away from shower head for better positioning)
	local teleport_pos = vector.add(shower_pos, {x=0, y=-2, z=0})
	
	-- Perform teleport
	droid.object:set_pos(teleport_pos)
	
	-- Immediately halt and set velocity to zero after teleport
	droid:halt()
	droid.object:set_velocity({x = 0, y = 0, z = 0})
	
	lf("traveller", "Successfully teleported to shower position and halted")
	
	-- -- Clear any current states and return to wander
	-- droid.action = nil
	-- droid.destination = nil
	-- droid._is_showering = nil
	-- droid._is_sleeping = nil
	
	-- -- Set correct tool
	-- droid:set_tool("default:bronzeblock")
	
	-- lf("traveller", "Successfully teleported to shower position")
	
	return true
end

-- Function to turn on shower head at specific position
local function turn_on_shower_head(droid, pos)
	local node = minetest.get_node(pos)
	
	-- Check if it's a shower head
	lf("DEBUG traveller:turn_on_shower_head", "Checking node at " .. minetest.pos_to_string(pos) .. ": " .. node.name)
	if node.name == "homedecor:shower_head" then
		lf("DEBUG traveller:turn_on_shower_head", "Found shower head, checking fixture below")
		-- Check if there's a valid fixture below (same logic as right-click)
		local below = minetest.get_node_or_nil({x=pos.x, y=pos.y-2.0, z=pos.z})
		lf("DEBUG traveller:turn_on_shower_head", "Fixture below: " .. (below and below.name or "nil"))
		if below and (
			below.name == "homedecor:shower_tray" or
			below.name == "homedecor:bathtub_clawfoot_brass_taps" or
			below.name == "homedecor:bathtub_clawfoot_chrome_taps" ) then
			
			lf("DEBUG traveller:turn_on_shower_head", "Valid fixture found, starting particle effects")
			-- Define particle settings (same as in on_rightclick)
			local particledef = {
				outlet      = { x = 0, y = -0.42, z = 0.1 },
				velocity_x  = { min = -0.15, max = 0.15 },
				velocity_y  = -2,
				velocity_z  = { min = -0.3,  max = 0.1 },
				spread      = 0.12
			}
			
			-- Start the particle effects
			homedecor.start_particle_spawner(pos, node, particledef, "homedecor_shower")
			lf("traveller", "Turned on shower head at " .. minetest.pos_to_string(pos))
			
			-- Save the exact shower position for later teleport
			droid._shower_pos = vector.round(pos)
			lf("traveller", "Saved shower position: " .. minetest.pos_to_string(droid._shower_pos))
			
			-- Teleport to shower position before turning on the shower
			teleport_to_shower_position(droid)
			
			-- Set showering state and halt the maidroid
			-- if droid then
            -- Check if already showering to prevent multiple shower calls
            if droid._is_showering == true then
                lf("DEBUG traveller:turn_on_shower_head", "maidroid already showering, ignoring shower action")
                return true
            end
            
            -- Set a flag to prevent on_step from reactivating movement
            droid._is_showering = true
            
            -- Halt the maidroid while showering
            droid:halt()
            
            -- Explicitly set velocity to zero to prevent any movement
            droid.object:set_velocity({x = 0, y = 0, z = 0})
            
            -- Set shower animation (use stand animation for now)
            local stand_anim = (maidroid and maidroid.animation and maidroid.animation.STAND) or "stand"
            droid:set_animation(stand_anim, 0)
            
            lf("DEBUG traveller:turn_on_shower_head", "maidroid showering at " .. minetest.pos_to_string(pos) .. " (shower_flag=true, velocity=0)")
            
            -- Add automatic turn-off timer similar to handle_sleep_action
            local shower_time = 6 -- Shower for 6 seconds
            lf("DEBUG traveller:turn_on_shower_head", "setting shower turn-off timer for " .. shower_time .. " seconds")
            
            minetest.after(shower_time, function()
                lf("DEBUG traveller:shower_timer", "shower turn-off timer triggered!")
                
                if droid and droid.object then
                    lf("DEBUG traveller:shower_timer", "droid and object valid, clearing shower flag")
                    
                    -- Clear the shower flag FIRST to allow normal movement
                    droid._is_showering = false
                    
                    -- IMPORTANT: Clear the action state to prevent immediate re-showering
                    droid.action = nil
                    
                    -- Stop the particle effects
                    homedecor.stop_particle_spawner(pos, "homedecor_shower")
                    lf("traveller", "Turned off shower head at " .. minetest.pos_to_string(pos))
                    
                    -- Restore normal animation
                    local stand_anim = (maidroid and maidroid.animation and maidroid.animation.STAND) or "stand"
                    droid:set_animation(stand_anim, 30)
                    
                    -- Resume normal behavior - force return to wander
                    to_wander(droid, "traveller:shower_timer")
                    
                    lf("DEBUG traveller:shower_timer", "maidroid finished showering, shower flag cleared, action cleared")
                else
                    lf("DEBUG traveller:shower_timer", "shower turn-off timer: droid or object is nil")
                    lf("DEBUG traveller:shower_timer", "droid=" .. tostring(droid) .. " object=" .. tostring(droid and droid.object))
                end
            end)
				
				-- Add backup turn-off timer at 12 seconds
				-- minetest.after(12, function()
				-- 	lf("DEBUG traveller:shower_timer", "backup shower turn-off timer triggered!")
					
				-- 	if droid and droid.object and droid._is_showering == true then
				-- 		lf("DEBUG traveller:shower_timer", "backup: forcing shower turn-off")
				-- 		droid._is_showering = false
				-- 		droid.action = nil  -- Clear action state
				-- 		homedecor.stop_particle_spawner(pos, "homedecor_shower")
				-- 		lf("traveller", "Backup: Turned off shower head at " .. minetest.pos_to_string(pos))
				-- 		local stand_anim = (maidroid and maidroid.animation and maidroid.animation.STAND) or "stand"
				-- 		droid:set_animation(stand_anim, 30)
				-- 		to_wander(droid, "traveller:backup_shower_timer")
				-- 		lf("DEBUG traveller:shower_timer", "backup: maidroid force finished showering, action cleared")
				-- 	end
				-- end)
			-- end
			
			return true
		else
			lf("traveller", "Shower head at " .. minetest.pos_to_string(pos) .. " has no valid fixture below")
		end
	else
		lf("traveller", "Node at " .. minetest.pos_to_string(pos) .. " is not a shower head")
	end
	
	return false
end

-- Function to check if maidroid is showering and handle shower state
local function on_step_shower_check(droid, dtime, moveresult)
	-- Check if maidroid is showering - if so, prevent all movement and processing
	if droid._is_showering == true then
		-- Ensure velocity stays zero while showering
		droid.object:set_velocity({x = 0, y = 0, z = 0})
		-- Keep stand animation active while showering
		local stand_anim = (maidroid and maidroid.animation and maidroid.animation.STAND) or "stand"
		droid:set_animation(stand_anim, 0)
		-- Skip all other processing while showering
		return true -- Return true to indicate shower state is active
	end
	return false -- Return false to indicate not showering
end


-- Function to find path to shower head and turn on on
local function find_and_turn_on_shower(self)
	lf("DEBUG traveller:find_and_turn_on_shower", "Starting shower search")
	local pos = self:get_pos()
	
	-- Find shower head within range
	lf("DEBUG traveller:find_and_turn_on_shower", "Searching for shower heads within " .. TRAVEL_RANGE .. " blocks")
	local shower_pos = minetest.find_node_near(pos, TRAVEL_RANGE, {"homedecor:shower_head"})
	
	if not shower_pos then
		lf("traveller", "No shower head found within range")
		return false
	end
	
	lf("traveller", "Found shower head at " .. minetest.pos_to_string(shower_pos))
	lf("DEBUG traveller:find_and_turn_on_shower", "Checking if shower location is safe")
	
	-- Check if destination is safe
	if not is_destination_safe(self, shower_pos) then
		lf("traveller", "Shower head location is not safe")
		return false
	end
	
	-- Calculate distance to shower
	local distance = vector.distance(pos, shower_pos)
	lf("DEBUG traveller:find_and_turn_on_shower", "Distance to shower: " .. string.format("%.2f", distance))
	
	-- If already close to shower, turn it on
	if distance < 3 then
		lf("traveller", "Already near shower head, turning it on")
		lf("DEBUG traveller:find_and_turn_on_shower", "Calling turn_on_shower_head directly")
		return turn_on_shower_head(self, shower_pos)
	end
	
	-- Find path to shower head
	lf("traveller", "Finding path to shower head from " .. minetest.pos_to_string(pos) .. " to " .. minetest.pos_to_string(shower_pos))
	lf("DEBUG traveller:find_and_turn_on_shower", "Using A* pathfinding with parameters: 8, 1, 1")
	local path = minetest.find_path(pos, shower_pos, 8, 1, 1, "A*")
	
	if path ~= nil then
		lf("traveller", "Path found to shower head with " .. #path .. " nodes")
		lf("DEBUG traveller:find_and_turn_on_shower", "Path found successfully, setting up movement")
		self:set_yaw({self:get_pos(), shower_pos})
		
		-- Set up action to turn on shower when arriving
		lf("DEBUG traveller:find_and_turn_on_shower", "Setting destination and action for shower")
		self.destination = shower_pos
		self.action = "turn_on_shower"
		core_path.to_follow_path(self, path, shower_pos, to_action, "turn_on_shower")
		return true
	else
		lf("traveller", "No path found to shower head")
		return false
	end
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
	lf("traveller:to_action", "to_action called, setting action state")
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
	self._is_showering = nil  -- Clear showering state
	self._shower_pos = nil    -- Clear saved shower position
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
		lf("traveller:act", "traveller_sleep: " .. minetest.pos_to_string(self:get_pos()))
		local target = self._bed_target
		if target and target.pos then
			-- Check if beds mod is available
			if beds then
				maidroid.sleep.handle_sleep_action(self, target.pos)
				lf("traveller:act", "sleep action completed, staying in sleep state")
				return nil -- Prevent return to wander
			else
				lf("traveller:act", "beds mod not available for sleeping")
			end
		else
			lf("traveller:act", "traveller_sleep: no bed target")
		end
		self._bed_target = nil
	elseif self.action == "turn_on_shower" then
		lf("DEBUG traveller:act", "turn_on_shower: " .. minetest.pos_to_string(self:get_pos()))
		lf("DEBUG traveller:act", "destination=" .. (self.destination and minetest.pos_to_string(self.destination) or "nil"))
		if self.destination then
			lf("DEBUG traveller:act", "Calling turn_on_shower_head at destination")
			local success = turn_on_shower_head(self, self.destination)
			if success then
				lf("traveller:act", "Successfully turned on shower")
			else
				lf("traveller:act", "Failed to turn on shower")
			end
		else
			lf("DEBUG traveller:act", "turn_on_shower: no destination")
		end
		self.destination = nil
	else
		lf("traveller:act", "unknown action: " .. tostring(self.action))
	end
	
	-- Return to wander after action completion
	to_wander(self, "traveller:act")
end

-- ,,task
task = function(self)
	local pos = self:get_pos()
	local inv = self:get_inventory()
	
	-- Randomly pick one of four actions, with choice 1 being twice as likely as others
	-- Use math.random(5): values 1 and 2 map to choice 1, values 3, 4, and 5 map to choices 2, 3, and 4
	local choice = math.random(5)
    choice = 4

	lf("traveller:task", "CHOICE=" .. choice .. " selected")

	if choice == 1 or choice == 2 then
		lf("traveller:task", "CHOICE=" .. choice .. ": find_and_travel_to_destination")
		local destinations = find_interesting_destinations(self)
		if #destinations > 0 then
			local next_dest = destinations[1]
			lf("traveller:task", "Found destination: " .. next_dest.type .. " at " .. minetest.pos_to_string(next_dest.pos))
			travel_to_destination(self, next_dest.pos)
		else
			lf("traveller:task", "No destinations found, staying idle")
		end
	elseif choice == 3 then
		lf("traveller:task", "CHOICE=3: try_sleep_in_bed - about to call")
		lf("traveller:task", "pos=" .. minetest.pos_to_string(pos))
		lf("traveller:task", "core_module params: to_action=" .. tostring(to_action) .. ", name=traveller")
		local result = maidroid.sleep.try_sleep_in_bed(self, pos, {to_action = to_action, name = "traveller"})
		lf("traveller:task", "try_sleep_in_bed returned: " .. tostring(result))
	elseif choice == 4 then
		lf("traveller:task", "CHOICE=4: find_and_turn_on_shower")
		lf("DEBUG traveller:task", "Calling find_and_turn_on_shower function")
		find_and_turn_on_shower(self)
	else
		lf("traveller:task", "CHOICE=5: explore_nearby_area")
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
	
	-- Check if maidroid is showering - if so, prevent all movement and processing
	if on_step_shower_check(self, dtime, moveresult) then
		return -- Skip all other processing while showering
	end
	
	-- Check distance from activation position and teleport back if too far
	if check_distance_from_activation(self) then
		return -- Teleported back, skip other processing
	end
	
	-- Ensure we have the correct tool (bronze block) when not sleeping or showering
	if not self._is_sleeping and not self._is_showering and self.selected_tool ~= "default:bronzeblock" then
		self:set_tool("default:bronzeblock")
		self.selected_tool = "default:bronzeblock"
		lf("traveller:on_step", "corrected tool to bronze block")
	end
	
	-- Handle ACTION state by calling act function
	if self.state == maidroid.states.ACTION then
		lf("traveller:on_step", "In ACTION state, calling act function")
		act(self)
		return
	end
	
	-- Handle PATH state by delegating to path core
	if self.state == maidroid.states.PATH then
		lf("traveller:on_step", "In PATH state, delegating to path core")
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
	.. S("It can find and travel to chests, beds, signs, showers, and other points of interest.") .. "\n\n"
	.. S("Activation: Give the maidroid a bronze block to activate traveller mode.") .. "\n\n"
	.. S("Features:") .. "\n"
	.. "- " .. S("Automatic destination finding") .. "\n"
	.. "- " .. S("Safe pathfinding") .. "\n"
	.. "- " .. S("Periodic exploration") .. "\n"
	.. "- " .. S("Occasional sleeping in beds") .. "\n"
	.. "- " .. S("Finding and turning on shower heads") .. "\n"
	.. "- " .. S("Distance limit (10 blocks from activation)") .. "\n"
	.. "- " .. S("Auto-teleport back if too far") .. "\n"
	.. "- " .. S("Wanders when no destinations available") .. "\n\n"
	.. S("The traveller will automatically explore within a configurable range and return to wandering when no destinations are found.") .. "\n"
	.. S("It will occasionally sleep in nearby beds to rest during its travels.") .. "\n"
	.. S("It can also find shower heads and turn them on, creating water particle effects.") .. "\n"
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
