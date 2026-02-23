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

-- Point system configuration
local ACTION_POINTS = {
	toilet = 5,
	fridge = 10,
	shower = 8,
	bookshelf = 7
}

-- Reward system configuration
local REWARD_CONFIG = {
	rewards = {
		["default:coal_lump"] = 10,
		["default:iron_lump"] = 30,
		["default:silver_lump"] = 60,
		["default:gold_lump"] = 100
	}
}

-- Reward multiplier (defaults to 1)
local REWARD_MULTIPLIER = 1

-- Reward check interval (seconds)
local REWARD_CHECK_INTERVAL = 60

-- Timer for periodic metrics logging
local metrics_log_timer = 0
local metrics_log_interval = 35 -- seconds

-- Point system functions
local function initialize_points(self)
	if not self._reward_accumulated_points then
		self._reward_accumulated_points = 0
		lf("traveller", "Initialized point system with 0 points")
	end
	
	-- Initialize per-maidroid metrics
	if not self._action_taken_metrics then
		self._action_taken_metrics = {}
	end
	if not self._food_eaten_metrics then
		self._food_eaten_metrics = {}
	end
	lf("traveller", "Initialized per-maidroid metrics")
end

local function add_points(self, action, points)
	-- Apply reward multiplier
	local multiplier = REWARD_MULTIPLIER or 1
	local adjusted_points = math.floor(points * multiplier)
	
	lf("traveller:add_points", string.format("add_points called: action=%s, base_points=%d, multiplier=%s, adjusted_points=%d, _reward_accumulated_points=%s", 
		action, points, tostring(multiplier), adjusted_points, tostring(self._reward_accumulated_points)))
	if self._reward_accumulated_points ~= nil then
		self._reward_accumulated_points = self._reward_accumulated_points + adjusted_points
		lf("DEBUG traveller", string.format("Action '%s' completed: +%d points (base: %d, multiplier: %s) (Total: %d)", 
			action, adjusted_points, points, tostring(multiplier), self._reward_accumulated_points))
	else
		lf("DEBUG traveller", "Warning: Point system not initialized for action '" .. action .. "'")
	end
end

-- ,,reward
local function get_total_points(self)
	return self._reward_accumulated_points or 0
end

-- Function to display points in chat (for debugging)
local function show_points(self)
	local points = get_total_points(self)
	local pos = self:get_pos()
	minetest.chat_send_all(string.format("Traveller at %s has %d accumulated points", 
		minetest.pos_to_string(pos), points))
	lf("traveller", string.format("Points display requested: %d points", points))
end

-- Function to log traveller metrics for a specific maidroid
local function log_traveller_metrics(self)
	lf("traveller_metrics", "**************** Traveller Metrics ****************")
	
	local droid_pos = self:get_pos()
	
	-- Log accumulated points
	if self._reward_accumulated_points then
		lf("points_metrics", string.format("Traveller: %d accumulated points", 
			self._reward_accumulated_points))
	end
	
	-- Log action taken metrics
	if self._action_taken_metrics and next(self._action_taken_metrics) ~= nil then
		local action_parts = {}
		for action_name, count in pairs(self._action_taken_metrics) do
			table.insert(action_parts, string.format("%s:%d", action_name, count))
		end
		lf("action_metrics", string.format("Traveller - Action Metrics: %s", 
			table.concat(action_parts, ", ")))
	else
		lf("action_metrics", string.format("Traveller - No actions taken yet"))
	end
	
	-- Log food eaten metrics
	if self._food_eaten_metrics and next(self._food_eaten_metrics) ~= nil then
		local food_parts = {}
		for food_name, count in pairs(self._food_eaten_metrics) do
			table.insert(food_parts, string.format("%s:%d", food_name, count))
		end
		lf("food_metrics", string.format("Traveller - Food Eaten Metrics: %s", 
			table.concat(food_parts, ", ")))
	else
		lf("food_metrics", string.format("Traveller - No food items eaten yet"))
	end
	
	lf("traveller_metrics", "**************** End Traveller Metrics ****************")
end

-- Reward system functions
local function initialize_reward_system(self)
	if not self._reward_points_used then
		self._reward_points_used = 0
		self._reward_check_timer = 0
		-- self._selected_reward = "default:coal_lump" -- Default to coal
		self._selected_reward = "default:gold_lump" -- Default to coal
		lf("traveller", "Initialized reward system")
	end
end


-- Award reward items to traveller inventory
local function award_reward_items(self, selected_reward, rewards_earned, points_to_use)
	local inv = self:get_inventory()
	local reward_stack = ItemStack(selected_reward .. " " .. rewards_earned)
	
	if inv:room_for_item("main", reward_stack) then
		inv:add_item("main", reward_stack)
		self._reward_points_used = (self._reward_points_used or 0) + points_to_use
		
		lf("traveller", string.format("Awarded %dx %s for %d points (Total used: %d)", 
			rewards_earned, selected_reward, points_to_use, self._reward_points_used))
		
		-- Optional: Send chat message about reward
		local pos = self:get_pos()
		minetest.chat_send_all(string.format("Traveller at %s earned %dx %s! (%d points spent)", 
			minetest.pos_to_string(pos), rewards_earned, selected_reward, points_to_use))
	else
		lf("traveller", "Inventory full, cannot award rewards")
	end
end

-- ,,reward 
local function check_and_award_rewards(self)
	local total_points = get_total_points(self)
	local points_available = total_points - (self._reward_points_used or 0)
	
	-- Get the selected reward item and its cost
	local selected_reward = self._selected_reward or "default:coal_lump"
	local reward_cost = REWARD_CONFIG.rewards[selected_reward]
	
	if reward_cost and points_available >= reward_cost then
		-- Calculate how many of this reward we can give
		local rewards_earned = math.floor(points_available / reward_cost)
		local points_to_use = rewards_earned * reward_cost
		
-- Add reward items to inventory
		award_reward_items(self, selected_reward, rewards_earned, points_to_use)
	end
end

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


-- ,,surrounding
local function get_standable_pos_around(pos)
    local offsets = {
        {x=1,y=0,z=0},
        {x=-1,y=0,z=0},
        {x=0,y=0,z=1},
        {x=0,y=0,z=-1},
    }

    local candidates = {}
    
    for _, off in ipairs(offsets) do
        local p = vector.add(pos, off)

        local node = minetest.get_node(p)
        local below = minetest.get_node({x=p.x,y=p.y-1,z=p.z})
        local above = minetest.get_node({x=p.x,y=p.y+1,z=p.z})

        if not minetest.registered_nodes[node.name].walkable
        and minetest.registered_nodes[below.name].walkable
        and not minetest.registered_nodes[above.name].walkable then
            table.insert(candidates, p)
        end
    end

    return candidates
end

-- Function to get the shortest path by checking multiple standable positions around target
-- ,,shortest_path
local function get_shortest_path(target_pos, player_pos)
    local shortest_path = nil
    local shortest_length = math.huge
    local shortest_destination = nil
    
    lf("shortest_path", "Starting get_shortest_path: target=" .. minetest.pos_to_string(target_pos) .. " player=" .. minetest.pos_to_string(player_pos))
    
    -- Get standable positions around target
    local standable_candidates = get_standable_pos_around(target_pos)
    
    -- Find path to each standable candidate and return the shortest
    for i, pos in ipairs(standable_candidates) do
        lf("shortest_path", "Checking path to position " .. i .. ": " .. minetest.pos_to_string(pos))
        local path = minetest.find_path(player_pos, pos, 8, 1, 1, "A*")
        if path then
            lf("shortest_path", "Path found with " .. #path .. " nodes")
            if #path < shortest_length then
                shortest_path = path
                shortest_length = #path
                shortest_destination = pos
                lf("shortest_path", "New shortest path found: " .. shortest_length .. " nodes to " .. minetest.pos_to_string(pos))
            else
                lf("shortest_path", "Path longer than current shortest (" .. #path .. " vs " .. shortest_length .. ")")
            end
        else
            lf("shortest_path", "No path found to position " .. i)
        end
    end
    
    if shortest_path then
        lf("shortest_path", "Returning shortest path with " .. #shortest_path .. " nodes to destination " .. minetest.pos_to_string(shortest_destination))
    else
        lf("shortest_path", "No valid path found, returning nil")
    end
    
    return shortest_path, shortest_destination
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
-- ,,sho3
local function turn_on_shower_head(droid, pos)
    pos = droid._shower_pos
	local node = minetest.get_node(droid._shower_pos)
	
	-- Check if it's a shower head
	lf("traveller:turn_on_shower_head", "Checking node at " .. minetest.pos_to_string(pos) .. ": " .. node.name)
	if node.name == "homedecor:shower_head" then
		lf("traveller:turn_on_shower_head", "Found shower head, checking fixture below")
		-- Check if there's a valid fixture below (same logic as right-click)
		local below = minetest.get_node_or_nil({x=pos.x, y=pos.y-2.0, z=pos.z})
		lf("traveller:turn_on_shower_head", "Fixture below: " .. (below and below.name or "nil"))
		if below and (
			below.name == "homedecor:shower_tray" or
			below.name == "homedecor:bathtub_clawfoot_brass_taps" or
			below.name == "homedecor:bathtub_clawfoot_chrome_taps" ) then
			
			lf("traveller:turn_on_shower_head", "Valid fixture found, starting particle effects")
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
			
			-- Update per-maidroid action_taken_metrics
			if not droid._action_taken_metrics then
				droid._action_taken_metrics = {}
			end
			droid._action_taken_metrics["shower_used"] = (droid._action_taken_metrics["shower_used"] or 0) + 1
			lf("action_metrics", "shower_used called: " .. droid._action_taken_metrics["shower_used"])
			
			-- Award points for successful shower action
			add_points(droid, "shower", ACTION_POINTS.shower)
			
			-- Save the exact shower position for later teleport
			droid._shower_pos = vector.round(pos)
			lf("traveller", "Saved shower position: " .. minetest.pos_to_string(droid._shower_pos))
			
			-- Teleport to shower position before turning on the shower
			teleport_to_shower_position(droid)
			
			-- Set showering state and halt the maidroid
			-- if droid then
            -- Check if already showering to prevent multiple shower calls
            if droid._is_showering == true then
                lf("traveller:turn_on_shower_head", "maidroid already showering, ignoring shower action")
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
            
            lf("traveller:turn_on_shower_head", "maidroid showering at " .. minetest.pos_to_string(pos) .. " (shower_flag=true, velocity=0)")
            
            -- Add automatic turn-off timer similar to handle_sleep_action
            local shower_time = 6 -- Shower for 6 seconds
            lf("traveller:turn_on_shower_head", "setting shower turn-off timer for " .. shower_time .. " seconds")
            
            minetest.after(shower_time, function()
                lf("traveller:shower_timer", "shower turn-off timer triggered!")
                
                if droid and droid.object then
                    lf("traveller:shower_timer", "droid and object valid, clearing shower flag")
                    
                    -- Clear the shower flag FIRST to allow normal movement
                    droid._is_showering = false
                    droid._shower_pos = nil
                    
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
                    
                    lf("traveller:shower_timer", "maidroid finished showering, shower flag cleared, action cleared")
                else
                    lf("traveller:shower_timer", "shower turn-off timer: droid or object is nil")
                    lf("traveller:shower_timer", "droid=" .. tostring(droid) .. " object=" .. tostring(droid and droid.object))
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

-- Helper function to convert yaw to readable direction
local function yaw_to_direction(yaw)
	local normalized = yaw % (2 * math.pi)
	if normalized < math.pi/4 or normalized >= 7*math.pi/4 then return "North"
	elseif normalized < 3*math.pi/4 then return "East"
	elseif normalized < 5*math.pi/4 then return "South"
	else return "West"
	end
end

-- ,toi
-- Function to teleport to saved toilet position
local function teleport_to_toilet_position(droid)
	if not droid._toilet_pos then
		lf("traveller", "No saved toilet position available for teleport")
		return false
	end
	
	local current_pos = droid:get_pos()
	local toilet_pos = droid._toilet_pos
	
	lf("traveller", "Teleporting from " .. minetest.pos_to_string(current_pos) .. " to toilet at " .. minetest.pos_to_string(toilet_pos))
	
	-- Calculate teleport position (toilet seat at y=0.5, maidroid bottom at -0.5, so center at y=1.0)
	local teleport_pos = vector.add(toilet_pos, {x=0, y=0.2, z=0})
	
	-- Get toilet node to check its orientation
	local toilet_node = minetest.get_node(toilet_pos)
	local toilet_param2 = toilet_node.param2 or 0
	
	-- Calculate facing direction based on toilet's param2
	-- param2 values: 0=north, 1=east, 2=south, 3=west (90-degree rotations)
	-- Different logic for cardinal vs diagonal directions
	local toilet_yaw = toilet_param2 * (math.pi / 2)
	local backward_yaw
	
	-- For North (0) and South (2), add π (face opposite)
	-- For East (1) and West (3), face same direction
	if toilet_param2 == 0 or toilet_param2 == 2 then
		backward_yaw = (toilet_yaw + math.pi) % (2 * math.pi)  -- Face opposite
	else
		backward_yaw = toilet_yaw  -- Face same direction
	end
	
	lf("traveller", "POS: Toilet orientation param2=" .. toilet_param2 .. ", toilet_yaw=" .. toilet_yaw .. " (" .. yaw_to_direction(toilet_yaw) .. "), setting corrected yaw=" .. backward_yaw .. " (" .. yaw_to_direction(backward_yaw) .. ")")
	
	-- Perform teleport
	droid.object:set_pos(teleport_pos)
	
	-- Set rotation to face backward relative to toilet's orientation
	droid.object:set_yaw(backward_yaw)
	
	-- Add a small delay to check the actual yaw after setting it
	minetest.after(0.1, function()
		if droid and droid.object then
			local actual_yaw = droid.object:get_yaw() or 0
			lf("traveller", "POS: Maidroid actual yaw after setting: " .. actual_yaw .. " (" .. yaw_to_direction(actual_yaw) .. ")")
		end
	end)
	
	-- Immediately halt and set velocity to zero after teleport
	droid:halt()
	droid.object:set_velocity({x = 0, y = 0, z = 0})
	
	lf("traveller", "Successfully teleported to toilet position and halted")
	
	return true
end

-- Function to flush toilet at specific position
local function flush_toilet(droid, pos)
    pos = droid._toilet_pos
	local node = minetest.get_node(pos)
	
	-- Check if it's a toilet
	lf("traveller:flush_toilet", "Checking node at " .. minetest.pos_to_string(pos) .. ": " .. node.name)
	if node.name == "homedecor:toilet" or node.name == "homedecor:toilet_open" then
		lf("traveller:flush_toilet", "Found toilet, flushing it")
		
		-- Teleport to toilet position before flushing
		teleport_to_toilet_position(droid)
		
		-- Check if already using toilet to prevent multiple toilet calls
		if droid._is_using_toilet == true then
			lf("traveller:flush_toilet", "maidroid already using toilet, ignoring toilet action")
			return true
		end
		
		-- Set a flag to prevent on_step from reactivating movement
		droid._is_using_toilet = true
		
		-- Halt the maidroid while using toilet
		droid:halt()
		
		-- Explicitly set velocity to zero to prevent any movement
		droid.object:set_velocity({x = 0, y = 0, z = 0})
		
		-- Set sit animation while using toilet
		local sit_anim = (maidroid and maidroid.animation and maidroid.animation.SIT) or "sit"
		droid:set_animation(sit_anim, 0)
		
		lf("traveller:flush_toilet", "maidroid sitting on toilet at " .. minetest.pos_to_string(pos) .. " (toilet_flag=true, velocity=0)")
		
		-- Get the node definition and call its on_rightclick to flush
		local def = minetest.registered_nodes[node.name]
		if def and def.on_rightclick then
			def.on_rightclick(pos, node, nil, nil, nil)
			lf("traveller", "Flushed toilet at " .. minetest.pos_to_string(pos))
			
			-- Update per-maidroid action_taken_metrics
			if not droid._action_taken_metrics then
				droid._action_taken_metrics = {}
			end
			droid._action_taken_metrics["toilet_used"] = (droid._action_taken_metrics["toilet_used"] or 0) + 1
			lf("action_metrics", "toilet_used called: " .. droid._action_taken_metrics["toilet_used"])
			
			-- Award points for successful toilet action
			add_points(droid, "toilet", ACTION_POINTS.toilet)
		end
		
		-- Add automatic timer to finish using toilet
		local toilet_time = 4 -- Use toilet for 4 seconds
		lf("traveller:flush_toilet", "setting toilet finish timer for " .. toilet_time .. " seconds")
		
		minetest.after(toilet_time, function()
			lf("traveller:toilet_timer", "toilet finish timer triggered!")
			
			if droid and droid.object then
				lf("traveller:toilet_timer", "droid and object valid, clearing toilet flag")
				
				-- Clear the toilet flag FIRST to allow normal movement
				droid._is_using_toilet = false
				
				-- IMPORTANT: Clear the action state to prevent immediate re-toilet
				droid.action = nil
				
				-- Restore normal animation
				local stand_anim = (maidroid and maidroid.animation and maidroid.animation.STAND) or "stand"
				droid:set_animation(stand_anim, 30)
				
				-- Resume normal behavior - force return to wander
				to_wander(droid, "traveller:toilet_timer")
				
				lf("traveller:toilet_timer", "maidroid finished using toilet, toilet flag cleared, action cleared")
			else
				lf("traveller:toilet_timer", "toilet finish timer: droid or object is nil")
				lf("traveller:toilet_timer", "droid=" .. tostring(droid) .. " object=" .. tostring(droid and droid.object))
			end
		end)
		
		return true
	else
		lf("traveller", "Node at " .. minetest.pos_to_string(pos) .. " is not a toilet")
	end
	
	return false
end

-- Function to check if maidroid is using toilet and handle toilet state
local function on_step_toilet_check(droid, dtime, moveresult)
	-- Check if maidroid is using toilet - if so, prevent all movement and processing
	if droid._is_using_toilet == true then
		-- Ensure velocity stays zero while using toilet
		droid.object:set_velocity({x = 0, y = 0, z = 0})
		-- Keep sit animation active while using toilet
		local sit_anim = (maidroid and maidroid.animation and maidroid.animation.SIT) or "sit"
		droid:set_animation(sit_anim, 0)
		-- Skip all other processing while using toilet
		return true -- Return true to indicate toilet state is active
	end
	return false -- Return false to indicate not using toilet
end

-- Function to check if maidroid is using refrigerator and handle refrigerator state
local function on_step_refrigerator_check(droid, dtime, moveresult)
	-- Check if maidroid is using refrigerator - if so, prevent all movement and processing
	if droid._is_using_refrigerator == true then
		-- Ensure velocity stays zero while using refrigerator
		droid.object:set_velocity({x = 0, y = 0, z = 0})
		-- Keep mining animation active while using refrigerator (holding item)
		local mine_anim = (maidroid and maidroid.animation and maidroid.animation.MINE) or "mine"
		droid:set_animation(mine_anim, 0)
		-- Skip all other processing while using refrigerator
		return true -- Return true to indicate refrigerator state is active
	end
	return false -- Return false to indicate not using refrigerator
end

-- Function to check if maidroid is using bookshelf and handle bookshelf state
local function on_step_bookshelf_check(droid, dtime, moveresult)
	-- Check if maidroid is using bookshelf - if so, prevent all movement and processing
	if droid._is_using_bookshelf == true then
		-- Ensure velocity stays zero while using bookshelf
		droid.object:set_velocity({x = 0, y = 0, z = 0})
		-- Keep mining animation active while using bookshelf (holding item)
		local mine_anim = (maidroid and maidroid.animation and maidroid.animation.MINE) or "mine"
		droid:set_animation(mine_anim, 0)
		-- Skip all other processing while using bookshelf
		return true -- Return true to indicate bookshelf state is active
	end
	return false -- Return false to indicate not using bookshelf
end

-- ,,fri4
-- Function to get the position in front of a refrigerator based on its orientation
local function get_refrigerator_front(refrigerator_pos)
	-- Get refrigerator node and its orientation
	local refrigerator_node = minetest.get_node(refrigerator_pos)
	local refrigerator_param2 = refrigerator_node.param2 or 0
	
	-- Calculate offset based on refrigerator's facing direction
	-- param2 values: 0=north, 1=east, 2=south, 3=west (90-degree rotations)
	local offset = {x=0, y=0, z=0}
	if refrigerator_param2 == 0 then
		-- Facing north, front is at negative Z (behind refrigerator)
		offset.z = -1
	elseif refrigerator_param2 == 1 then
		-- Facing east, front is at negative X (behind refrigerator)
		offset.x = -1
	elseif refrigerator_param2 == 2 then
		-- Facing south, front is at positive Z (behind refrigerator)
		offset.z = 1
	elseif refrigerator_param2 == 3 then
		-- Facing west, front is at positive X (behind refrigerator)
		offset.x = 1
	end
	
	-- Calculate and return the position in front of refrigerator
	return vector.add(refrigerator_pos, offset)
end

-- ,,book3
-- Function to get the position in front of a bookshelf based on its orientation
local function get_bookshelf_front(bookshelf_pos)
	-- Get bookshelf node and its orientation
	local bookshelf_node = minetest.get_node(bookshelf_pos)
	local bookshelf_param2 = bookshelf_node.param2 or 0
	
	-- Debug logging to check what we're actually detecting
	lf("traveller:get_bookshelf_front", "Bookshelf node name: " .. (bookshelf_node.name or "unknown"))
	lf("traveller:get_bookshelf_front", "Bookshelf param2 value: " .. bookshelf_param2)
	lf("traveller:get_bookshelf_front", "Bookshelf position: " .. minetest.pos_to_string(bookshelf_pos))
	
	-- Calculate offset based on bookshelf's facing direction (-90 degree rotation)
	-- param2 values: 0=north, 1=east, 2=south, 3=west (90-degree rotations)
	-- Rotated -90 degrees: north→west, east→north, south→east, west→south
	local offset = {x=0, y=0, z=0}
	local locked_orientation = nil
	
	if bookshelf_param2 == 0 then
		-- Facing north, rotated -90°, front is at negative X (west)
		offset.x = -1
		locked_orientation = "north→west"
	elseif bookshelf_param2 == 1 then
		-- Facing east, rotated -90°, front is at negative Z (north)
		offset.z = -1
		locked_orientation = "east→north"
	elseif bookshelf_param2 == 2 then
		-- Facing south, rotated -90°, front is at positive X (east)
		offset.x = 1
		locked_orientation = "south→east"
	elseif bookshelf_param2 == 3 then
		-- Facing west, rotated -90°, front is at positive Z (south)
		offset.z = 1
		locked_orientation = "west→south"
	else
		-- Handle unexpected param2 values
		lf("traveller:get_bookshelf_front", "Unexpected param2 value: " .. bookshelf_param2)
		locked_orientation = "unknown"
	end
	
	-- Log locked orientation for debugging
	lf("traveller:get_bookshelf_front", "Bookshelf orientation locked: " .. (locked_orientation or "unknown") .. 
	   " (param2=" .. bookshelf_param2 .. ")")
	
	-- Calculate and return the position in front of bookshelf
	local target_pos = vector.add(bookshelf_pos, offset)
	lf("traveller:get_bookshelf_front", "Bookshelf front position: " .. minetest.pos_to_string(target_pos))
	
	return target_pos
end

-- Function to check and highlight positions in all four cardinal directions
-- ,,check1,,chk
local function front_check(pos)
	if not pos then
		lf("traveller:front_check", "No position provided")
		return
	end
	
	lf("traveller:front_check", "Checking directions around position: " .. minetest.pos_to_string(pos))
	
	-- Define offsets for each cardinal direction (clockwise order)
	local directions = {
		{name = "North", offset = {x = 0,  y = 0,  z = -1}},
		{name = "East",  offset = {x = 1,  y = 0,  z = 0}},
		{name = "South", offset = {x = 0,  y = 0,  z = 1}},
		{name = "West",  offset = {x = -1, y = 0,  z = 0}}
	}
	
	-- Function to place destination marker (similar to path.lua)
	local function place_marker(target_pos, direction_name)
		if not target_pos then return end
		
		-- Check what's at the target position
		local dest_node = minetest.get_node(target_pos)
		local place_pos
		
		-- If target is on walkable nodes, place marker above
		if dest_node.name ~= "air" then
			place_pos = { x = target_pos.x, y = target_pos.y + 1, z = target_pos.z }
		else
			-- If target is in air, place at target level
			place_pos = { x = target_pos.x, y = target_pos.y, z = target_pos.z }
		end
		
		local current_node = minetest.get_node(place_pos)
		-- Only place if current node is air
		if current_node.name == "air" then
			-- Place marker with different colors for each direction
			local param2_color = 240 -- Default yellow
			if direction_name == "East" then
				param2_color = 240 -- Yellow
			elseif direction_name == "South" then
				param2_color = 180 -- Red
			elseif direction_name == "West" then
				param2_color = 120 -- Blue
			elseif direction_name == "North" then
				param2_color = 60  -- Green
			end
			
			minetest.set_node(place_pos, { name = "maidroid:destination_marker", param2 = param2_color })
			lf("traveller:front_check", "Placed " .. direction_name .. " marker at " .. minetest.pos_to_string(place_pos))
			
			-- Set up removal timer for marker (3 seconds)
			minetest.after(3, function()
				local node = minetest.get_node(place_pos)
				if node.name == "maidroid:destination_marker" then
					minetest.set_node(place_pos, { name = "air" })
					lf("traveller:front_check", "Removed " .. direction_name .. " marker at " .. minetest.pos_to_string(place_pos))
				end
			end)
		end
	end
	
	-- Check each direction with delay
	for i, dir in ipairs(directions) do
		local target_pos = vector.add(pos, dir.offset)
		local target_node = minetest.get_node(target_pos)
		
		lf("traveller:front_check", string.format("%s (+%d,%d,%d): %s at %s", 
			dir.name, 
			dir.offset.x, dir.offset.y, dir.offset.z,
			target_node.name,
			minetest.pos_to_string(target_pos)
		))
		
		-- Place marker with delay
		minetest.after(i * 0.5, function()
			place_marker(target_pos, dir.name)
		end)
	end
	
	-- Also highlight the center position with delay
	minetest.after(0, function()
		place_marker(pos, "Center")
	end)
	
	lf("traveller:front_check", "Scheduled marker placement for center and all 4 directions with 0.5s delays")
end

-- Function to teleport to saved refrigerator position
-- ,,fri2
local function teleport_to_refrigerator_position(droid)
	if not droid._refrigerator_pos then
		lf("traveller", "No saved refrigerator position available for teleport")
		return false
	end
	
	local current_pos = droid:get_pos()
	local refrigerator_pos = droid._refrigerator_pos
	
	lf("traveller", "Teleporting from " .. minetest.pos_to_string(current_pos) .. " to refrigerator at " .. minetest.pos_to_string(refrigerator_pos))
	
	-- Calculate teleport position in front of refrigerator based on its orientation
	-- local teleport_pos = get_refrigerator_front(refrigerator_pos)
	local teleport_pos = droid._refrigerator_front
	lf("traveller", "Teleport position: " .. minetest.pos_to_string(teleport_pos))
	
	-- Perform teleport
	droid.object:set_pos(teleport_pos)
	
	-- Immediately halt and set velocity to zero after teleport
	droid:halt()
	droid.object:set_velocity({x = 0, y = 0, z = 0})
	
	lf("traveller", "Successfully teleported to refrigerator position and halted")
	
	return true
end

-- Function to teleport to saved bookshelf position
-- ,,book2
local function teleport_to_bookshelf_position(droid)
	if not droid._bookshelf_pos then
		lf("traveller", "No saved bookshelf position available for teleport")
		return false
	end
	
	local current_pos = droid:get_pos()
	local bookshelf_pos = droid._bookshelf_pos
	
	lf("traveller", "Teleporting from " .. minetest.pos_to_string(current_pos) .. " to bookshelf at " .. minetest.pos_to_string(bookshelf_pos))
	
	-- Calculate teleport position in front of bookshelf based on its orientation
	-- local teleport_pos = get_refrigerator_front(bookshelf_pos)
	local teleport_pos = droid._bookshelf_front
	lf("traveller", "Teleport position: " .. minetest.pos_to_string(teleport_pos))
	
	-- Perform teleport
	droid.object:set_pos(teleport_pos)
	
	-- Immediately halt and set velocity to zero after teleport
	droid:halt()
	droid.object:set_velocity({x = 0, y = 0, z = 0})
	
	lf("traveller", "Successfully teleported to bookshelf position and halted")
	
	return true
end

-- ref3
-- Function to get random item from refrigerator and hold it
local function use_refrigerator(droid, pos)
    pos = droid._refrigerator_pos 
	local node = minetest.get_node(pos)
	
	-- Check if it's a refrigerator
	lf("traveller:use_refrigerator", "Checking node at " .. minetest.pos_to_string(pos) .. ": " .. node.name)
	if node.name == "homedecor:refrigerator_white" then
		lf("traveller:use_refrigerator", "Found refrigerator, getting item from it")
		
		-- Save the exact refrigerator position for later teleport
		droid._refrigerator_pos = vector.round(pos)
		lf("traveller", "Saved refrigerator position: " .. minetest.pos_to_string(droid._refrigerator_pos))
		
		-- Teleport to refrigerator position before using it
		teleport_to_refrigerator_position(droid)
		
		-- Check if already using refrigerator to prevent multiple refrigerator calls
		if droid._is_using_refrigerator == true then
			lf("traveller:use_refrigerator", "maidroid already using refrigerator, ignoring refrigerator action")
			return true
		end
		
		-- Set a flag to prevent on_step from reactivating movement
		droid._is_using_refrigerator = true
		
		-- Halt the maidroid while using refrigerator
		droid:halt()
		
		-- Explicitly set velocity to zero to prevent any movement
		droid.object:set_velocity({x = 0, y = 0, z = 0})
		
		-- Get refrigerator's inventory to pick a random item
		local refrigerator_meta = minetest.get_meta(pos)
		local refrigerator_inv = refrigerator_meta:get_inventory()
		
		-- Try to get a random item from refrigerator
		local item_list = refrigerator_inv:get_list("main")
		
		-- Collect non-empty items with their original positions
		local valid_items = {}
		for i, stack in ipairs(item_list) do
			if not stack:is_empty() then
				table.insert(valid_items, {stack = stack, index = i})
			end
		end
		
		-- Pick a random item if available
		local selected_item = nil
		local original_index = nil
		if #valid_items > 0 then
			local random_index = math.random(#valid_items)
			local selected_data = valid_items[random_index]
			selected_item = selected_data.stack
			original_index = selected_data.index
			lf("traveller", "Selected random item from refrigerator: " .. selected_item:get_name() .. " from slot " .. original_index)
			
			-- Update per-maidroid food_eaten_metrics
			if not droid._food_eaten_metrics then
				droid._food_eaten_metrics = {}
			end
			local item_name = selected_item:get_name()
			droid._food_eaten_metrics[item_name] = (droid._food_eaten_metrics[item_name] or 0) + 1
			lf("food_metrics", "food_eaten updated: " .. item_name .. " = " .. droid._food_eaten_metrics[item_name])
			
			-- Deduct 1 item from refrigerator immediately
			selected_item:take_item(1)
			refrigerator_inv:set_stack("main", original_index, selected_item)
			lf("traveller", "Deducted 1 " .. item_name .. " from refrigerator at slot " .. original_index)
			
			-- Set the selected item as the maidroid's tool (simulating holding it)
			droid:set_tool(item_name)
			droid.selected_tool = item_name
		else
			lf("traveller", "Refrigerator is empty, using default tool")
			droid:set_tool("default:bronzeblock")
			droid.selected_tool = "default:bronzeblock"
		end
		
		-- Update per-maidroid action_taken_metrics
		if not droid._action_taken_metrics then
			droid._action_taken_metrics = {}
		end
		droid._action_taken_metrics["refrigerator_used"] = (droid._action_taken_metrics["refrigerator_used"] or 0) + 1
		lf("action_metrics", "refrigerator_used called: " .. droid._action_taken_metrics["refrigerator_used"])
		
		-- Award points for successful refrigerator action
		add_points(droid, "fridge", ACTION_POINTS.fridge)
		
		-- Set mining animation while using refrigerator (holding item)
		local mine_anim = (maidroid and maidroid.animation and maidroid.animation.MINE) or "mine"
		droid:set_animation(mine_anim, 0)
		
		lf("traveller:use_refrigerator", "maidroid using refrigerator at " .. minetest.pos_to_string(pos) .. " (refrigerator_flag=true, velocity=0)")
		
		-- Add automatic timer to finish using refrigerator (hold item for 10 seconds)
		local refrigerator_time = 10 -- Use refrigerator for 10 seconds
		lf("traveller:use_refrigerator", "setting refrigerator finish timer for " .. refrigerator_time .. " seconds")
		
		minetest.after(refrigerator_time, function()
			lf("traveller:refrigerator_timer", "refrigerator finish timer triggered!")
			
			if droid and droid.object then
				lf("traveller:refrigerator_timer", "droid and object valid, clearing refrigerator flag")
				
				-- Clear the refrigerator flag FIRST to allow normal movement
				droid._is_using_refrigerator = false
				
				-- IMPORTANT: Clear the action state to prevent immediate re-refrigerator
				droid.action = nil
				
				-- Restore normal tool (bronze block)
				droid:set_tool("default:bronzeblock")
				droid.selected_tool = "default:bronzeblock"
				
				-- Restore normal animation
				local stand_anim = (maidroid and maidroid.animation and maidroid.animation.STAND) or "stand"
				droid:set_animation(stand_anim, 30)
				
				-- Resume normal behavior - force return to wander
				to_wander(droid, "traveller:refrigerator_timer")
				
				lf("traveller:refrigerator_timer", "maidroid finished using refrigerator, refrigerator flag cleared, action cleared")
			else
				lf("traveller:refrigerator_timer", "refrigerator finish timer: droid or object is nil")
				lf("traveller:refrigerator_timer", "droid=" .. tostring(droid) .. " object=" .. tostring(droid and droid.object))
			end
		end)
		
		return true
	else
		lf("traveller", "Node at " .. minetest.pos_to_string(pos) .. " is not a refrigerator")
	end
	
	return false
end

-- Function to get random book from bookshelf and hold it
-- ,,book4
local function use_bookshelf(droid, pos)
    pos = droid._bookshelf_pos 
	local node = minetest.get_node(pos)
	
	-- Check if it's a bookshelf
	lf("traveller:use_bookshelf", "Checking node at " .. minetest.pos_to_string(pos) .. ": " .. node.name)
	if node.name == "default:bookshelf" then
		lf("traveller:use_bookshelf", "Found bookshelf, getting book from it")
		
		-- Save the exact bookshelf position for later teleport
		-- droid._bookshelf_pos = vector.round(pos)
		lf("traveller", "Saved bookshelf position: " .. minetest.pos_to_string(droid._bookshelf_pos))
		
		-- Teleport to bookshelf position before using it
		teleport_to_bookshelf_position(droid)
		
		-- Check if already using bookshelf to prevent multiple bookshelf calls
		if droid._is_using_bookshelf == true then
			lf("traveller:use_bookshelf", "maidroid already using bookshelf, ignoring bookshelf action")
			return true
		end
		
		-- Set a flag to prevent on_step from reactivating movement
		droid._is_using_bookshelf = true
		
		-- Halt the maidroid while using bookshelf
		droid:halt()
		
		-- Explicitly set velocity to zero to prevent any movement
		droid.object:set_velocity({x = 0, y = 0, z = 0})
		
		-- Get bookshelf's inventory to pick a random book
		local bookshelf_meta = minetest.get_meta(pos)
		local bookshelf_inv = bookshelf_meta:get_inventory()
		
		-- Collect non-empty books with their original positions
		local valid_books = {}
		local current_inventory = "books"
		lf("traveller", "Starting book collection from bookshelf at " .. minetest.pos_to_string(pos))
		
		-- First try books inventory
		local book_list = bookshelf_inv:get_list("books")
		lf("traveller", "Checking 'books' inventory, list available: " .. tostring(book_list ~= nil))
		if book_list then
			lf("traveller", "Books inventory size: " .. #book_list)
			for i, stack in ipairs(book_list) do
				if not stack:is_empty() then
					-- Check if it's a proper MTG book type
					local item_name = stack:get_name()
					lf("traveller", "Slot " .. i .. ": " .. item_name .. " count: " .. stack:get_count())
					if item_name == "default:book" or item_name == "default:book_written" then
						table.insert(valid_books, {stack = stack, index = i, inventory_name = "books"})
						lf("traveller", "Added book from 'books' inventory: " .. item_name)
					end
				end
			end
		end
		
		-- If no books found in books inventory, try main inventory
		if #valid_books == 0 then
			lf("traveller", "No books found in 'books' inventory, trying 'main' inventory")
			current_inventory = "main"
			book_list = bookshelf_inv:get_list("main")
			lf("traveller", "Checking 'main' inventory, list available: " .. tostring(book_list ~= nil))
			if book_list then
				lf("traveller", "Main inventory size: " .. #book_list)
				for i, stack in ipairs(book_list) do
					if not stack:is_empty() then
						-- Check if it's a proper MTG book type
						local item_name = stack:get_name()
						lf("traveller", "Slot " .. i .. ": " .. item_name .. " count: " .. stack:get_count())
						if item_name == "default:book" or item_name == "default:book_written" then
							table.insert(valid_books, {stack = stack, index = i, inventory_name = "main"})
							lf("traveller", "Added book from 'main' inventory: " .. item_name)
						end
					end
				end
			end
		end
		
		lf("traveller", "Book collection completed, found " .. #valid_books .. " valid books")
		
		-- Pick a random book if available
		local selected_book = nil
		local original_index = nil
		local inventory_name = nil
		
		if #valid_books > 0 then
			local random_index = math.random(#valid_books)
			local selected_data = valid_books[random_index]
			selected_book = selected_data.stack
			original_index = selected_data.index
			inventory_name = selected_data.inventory_name
			lf("traveller", "Selected random book from bookshelf: " .. selected_book:get_name() .. " from slot " .. original_index .. " in " .. inventory_name)
			
			-- Transfer the FULL stack from bookshelf to maidroid
			local droid_inv = droid:get_inventory()
			lf("traveller", "Starting book transfer process")
			lf("traveller", "Maidroid inventory available: " .. tostring(droid_inv ~= nil))
			
			if droid_inv then
				-- Log book details before transfer
				lf("traveller", "Book to transfer: " .. selected_book:get_name() .. " count: " .. selected_book:get_count())
				lf("traveller", "Removing from inventory: " .. inventory_name .. " slot: " .. original_index)
				
				-- Remove book from bookshelf
				local removed_successfully = bookshelf_inv:set_stack(inventory_name, original_index, ItemStack(""))
				lf("traveller", "Book removal completed, success: " .. tostring(removed_successfully))
				
				-- Add full stack to maidroid inventory
				local remaining_stack = droid_inv:add_item("main", selected_book)
				lf("traveller", "Book addition completed, remaining stack: " .. tostring(remaining_stack:get_count()))
				
				if remaining_stack:is_empty() then
					lf("traveller", "Full book stack transferred successfully to maidroid")
				else
					lf("traveller", "Partial transfer - " .. remaining_stack:get_count() .. " items could not be added (inventory full?)")
				end
			else
				lf("traveller", "ERROR: Failed to get maidroid inventory - transfer aborted")
			end
			
			-- Update per-maidroid food_eaten_metrics (for books read)
			if not droid._food_eaten_metrics then
				droid._food_eaten_metrics = {}
			end
			local book_name = selected_book:get_name()
			droid._food_eaten_metrics[book_name] = (droid._food_eaten_metrics[book_name] or 0) + 1
			lf("book_metrics", "book_read updated: " .. book_name .. " = " .. droid._food_eaten_metrics[book_name])
			
			-- Set the selected book as the maidroid's tool (simulating holding it)
			droid:set_tool(book_name)
			droid.selected_tool = book_name
			
			-- Print reading message with book content preview
			local function read_book_stack(stack)
				lf("traveller", "read_book_stack: Starting function")
				
				if stack:is_empty() then 
					lf("traveller", "read_book_stack: Stack is empty, returning nil")
					return nil 
				end

				local name = stack:get_name()
				lf("traveller", "read_book_stack: Stack name: " .. name)
				
				-- Books in MTG are usually default:book or default:book_written
				if name ~= "default:book" and name ~= "default:book_written" then
					lf("traveller", "read_book_stack: Not a valid MTG book type, returning nil")
					return nil
				end
				
				lf("traveller", "read_book_stack: Valid book type detected: " .. name)

				local meta  = stack:get_meta()
				local title = meta:get_string("title") -- "" if none
				local text  = meta:get_string("text")  -- "" if none
				
				-- Dump all metadata for debugging
				lf("traveller", "read_book_stack: Dumping all metadata fields:")
				local meta_table = meta:to_table()
				if meta_table and meta_table.fields then
					for key, value in pairs(meta_table.fields) do
						lf("traveller", "read_book_stack:   [" .. key .. "] = '" .. value .. "' (len=" .. #value .. ")")
					end
				else
					lf("traveller", "read_book_stack:   No metadata fields found or metadata is nil")
				end
				
				-- Check if metadata is stored as serialized data (common in some book mods)
				local default_data = meta:get_string("")
				if default_data and default_data ~= "" and default_data:find("return") then
					lf("traveller", "read_book_stack: Found serialized book data, attempting to parse")
					lf("traveller", "read_book_stack: Serialized data: " .. default_data)
					
					-- Try to parse the serialized data
					local success, book_func = pcall(loadstring, default_data)
					if success and book_func then
						lf("traveller", "read_book_stack: Successfully loaded serialized function")
						local book_data = book_func()
						if book_data then
							lf("traveller", "read_book_stack: Successfully executed function and got data")
							title = book_data.title or ""
							text = book_data.text or ""
							lf("traveller", "read_book_stack: Parsed title: '" .. title .. "'")
							lf("traveller", "read_book_stack: Parsed text length: " .. #text)
						else
							lf("traveller", "read_book_stack: Function executed but returned nil data")
						end
					else
						lf("traveller", "read_book_stack: Failed to load serialized data: " .. tostring(book_func))
					end
				end
				
				lf("traveller", "read_book_stack: Final title extracted: '" .. title .. "'")
				lf("traveller", "read_book_stack: Final text length: " .. #text)

				-- Fallback title if missing
				if title == "" then
					title = (name == "default:book_written") and "(Untitled Book)" or "(Blank Book)"
					lf("traveller", "read_book_stack: Using fallback title: " .. title)
				else
					lf("traveller", "read_book_stack: Using original title: " .. title)
				end

				local result = { name = name, title = title, text = text }
				lf("traveller", "read_book_stack: Returning book data: name=" .. result.name .. " title=" .. result.title .. " text_len=" .. #result.text)
				return result
			end

			-- Read the book from maidroid's inventory after transfer
			local droid_inv = droid:get_inventory()
			local book_stack = nil
			
			-- Find the book in maidroid's main inventory (should be the last added item)
			if droid_inv then
				local main_list = droid_inv:get_list("main")
				if main_list then
					for i = #main_list, 1, -1 do  -- Search backwards to find the most recently added book
						local stack = main_list[i]
						if not stack:is_empty() and (stack:get_name() == "default:book" or stack:get_name() == "default:book_written") then
							book_stack = stack
							lf("traveller", "Found book in maidroid inventory at slot " .. i .. ": " .. stack:get_name())
							break
						end
					end
				end
			end

			local book = read_book_stack(book_stack or ItemStack(""))
			if book then
				local content_preview = book.text:sub(1, 10)
				minetest.chat_send_all("Reading " .. book.title .. "..." .. content_preview .. "....")
				lf("traveller", "Reading book: " .. book.title .. " (len=" .. #book.text .. ")")
				lf("traveller", "Preview: " .. content_preview)
			else
				minetest.chat_send_all("Reading unknown book...")
				lf("traveller", "Could not read book metadata properly")
			end
		else
			lf("traveller", "Bookshelf is empty or no books found, using default tool")
			droid:set_tool("default:bronzeblock")
			droid.selected_tool = "default:bronzeblock"
		end
		
		-- Update per-maidroid action_taken_metrics
		if not droid._action_taken_metrics then
			droid._action_taken_metrics = {}
		end
		droid._action_taken_metrics["bookshelf_used"] = (droid._action_taken_metrics["bookshelf_used"] or 0) + 1
		lf("action_metrics", "bookshelf_used called: " .. droid._action_taken_metrics["bookshelf_used"])
		
		-- Award points for successful bookshelf action
		add_points(droid, "bookshelf", ACTION_POINTS.bookshelf)
		
		-- Set reading animation while using bookshelf (holding book)
		local mine_anim = (maidroid and maidroid.animation and maidroid.animation.MINE) or "mine"
		droid:set_animation(mine_anim, 0)
		
		lf("traveller:use_bookshelf", "maidroid using bookshelf at " .. minetest.pos_to_string(pos) .. " (bookshelf_flag=true, velocity=0)")
		
		-- Add automatic timer to finish using bookshelf (read book for 8 seconds)
		local bookshelf_time = 8 -- Use bookshelf for 8 seconds
		lf("traveller:use_bookshelf", "setting bookshelf finish timer for " .. bookshelf_time .. " seconds")
		
		minetest.after(bookshelf_time, function()
			lf("traveller:bookshelf_timer", "bookshelf finish timer triggered!")
			
			if droid and droid.object then
				lf("traveller:bookshelf_timer", "droid and object valid, clearing bookshelf flag")
				
				-- Put the book back into the bookshelf
				local droid_inv = droid:get_inventory()
				if droid_inv then
					local main_list = droid_inv:get_list("main")
					if main_list then
						-- Find the book in maidroid's inventory (search backwards for most recent)
						for i = #main_list, 1, -1 do
							local stack = main_list[i]
							if not stack:is_empty() and (stack:get_name() == "default:book" or stack:get_name() == "default:book_written") then
								-- Get bookshelf inventory
								local bookshelf_meta = minetest.get_meta(pos)
								local bookshelf_inv = bookshelf_meta:get_inventory()
								
								if bookshelf_inv then
									-- Try to put book back in books inventory first
									local books_list = bookshelf_inv:get_list("books")
									if books_list then
										-- Find empty slot in books inventory
										for slot_idx = 1, #books_list do
											if books_list[slot_idx]:is_empty() then
												bookshelf_inv:set_stack("books", slot_idx, stack)
												droid_inv:set_stack("main", i, ItemStack(""))
												lf("traveller:bookshelf_timer", "Returned book to bookshelf books inventory at slot " .. slot_idx)
												break
											end
										end
									end
									
									-- If books inventory is full, try main inventory
									if not books_list or #books_list == 0 then
										local main_bookshelf_list = bookshelf_inv:get_list("main")
										if main_bookshelf_list then
											for slot_idx = 1, #main_bookshelf_list do
												if main_bookshelf_list[slot_idx]:is_empty() then
													bookshelf_inv:set_stack("main", slot_idx, stack)
													droid_inv:set_stack("main", i, ItemStack(""))
													lf("traveller:bookshelf_timer", "Returned book to bookshelf main inventory at slot " .. slot_idx)
													break
												end
											end
										end
									end
								end
								break
							end
						end
					end
				end
				
				-- Clear the bookshelf flag FIRST to allow normal movement
				droid._is_using_bookshelf = false
				
				-- IMPORTANT: Clear the action state to prevent immediate re-bookshelf
				droid.action = nil
				
				-- Restore normal tool (bronze block)
				droid:set_tool("default:bronzeblock")
				droid.selected_tool = "default:bronzeblock"
				
				-- Restore normal animation
				local stand_anim = (maidroid and maidroid.animation and maidroid.animation.STAND) or "stand"
				droid:set_animation(stand_anim, 30)
				
				-- Resume normal behavior - force return to wander
				to_wander(droid, "traveller:bookshelf_timer")
				
				lf("traveller:bookshelf_timer", "maidroid finished using bookshelf, bookshelf flag cleared, action cleared")
			else
				lf("traveller:bookshelf_timer", "bookshelf finish timer: droid or object is nil")
				lf("traveller:bookshelf_timer", "droid=" .. tostring(droid) .. " object=" .. tostring(droid and droid.object))
			end
		end)
		
		return true
	else
		lf("traveller", "Node at " .. minetest.pos_to_string(pos) .. " is not a bookshelf")
	end
	
	return false
end


-- Function to find path to shower head and turn on on
-- ,,sho1
local function find_and_turn_on_shower(self)
	lf("traveller:find_and_turn_on_shower", "Starting shower search")
	local pos = self:get_pos()
	
	-- Find shower head within range
	lf("traveller:find_and_turn_on_shower", "Searching for shower heads within " .. TRAVEL_RANGE .. " blocks")
	local shower_pos = minetest.find_node_near(pos, TRAVEL_RANGE, {"homedecor:shower_head"})
	
	if not shower_pos then
		lf("traveller", "No shower head found within range")
		return false
	end
    self._shower_pos = vector.round(shower_pos)
	
	lf("traveller", "Found shower head at " .. minetest.pos_to_string(shower_pos))
	lf("traveller:find_and_turn_on_shower", "Checking if shower location is safe")
	
	-- Check if destination is safe
	if not is_destination_safe(self, shower_pos) then
		lf("traveller", "Shower head location is not safe")
		return false
	end
	
	-- Calculate distance to shower
	local distance = vector.distance(pos, shower_pos)
	lf("traveller:find_and_turn_on_shower", "Distance to shower: " .. string.format("%.2f", distance))
	
	-- If already close to shower, turn it on
	if distance < 2 then
		lf("traveller", "Already near shower head, turning it on")
		lf("traveller:find_and_turn_on_shower", "Calling turn_on_shower_head directly")
		return turn_on_shower_head(self, shower_pos)
	end
	
	-- Find path to shower head
	lf("traveller", "Finding path to shower head from " .. minetest.pos_to_string(pos) .. " to " .. minetest.pos_to_string(shower_pos))
	lf("traveller:find_and_turn_on_shower", "Using A* pathfinding with parameters: 8, 1, 1")
	
	-- Create under_shower_pos as destination (one block below shower head)
	local under_shower_pos = { x = shower_pos.x, y = shower_pos.y - 1, z = shower_pos.z }
	lf("traveller:find_and_turn_on_shower", "Created under_shower_pos at " .. minetest.pos_to_string(under_shower_pos))
	
	local path = minetest.find_path(pos, under_shower_pos, 8, 1, 1, "A*")
	
	if path ~= nil then
		lf("traveller", "Path found to under shower position with " .. #path .. " nodes")
		lf("traveller:find_and_turn_on_shower", "Path found successfully, setting up movement")
		self:set_yaw({self:get_pos(), under_shower_pos})
		
		-- Set up action to turn on shower when arriving
		lf("traveller:find_and_turn_on_shower", "Setting destination and action for shower")
		-- self.destination = under_shower_pos
		-- self.action = "turn_on_shower"
		self.shower_head_pos = shower_pos  -- Store shower head position for action
		-- core_path.to_follow_path(self, path, under_shower_pos, to_action, "turn_on_shower")
        task_base(self, "turn_on_shower", under_shower_pos)
		return true
	else
		lf("traveller", "No path found to under shower position")
		return false
	end
end

-- ,,toi
-- Function to find path to toilet and use it
local function find_and_use_toilet(self)
	lf("traveller:find_and_use_toilet", "Starting toilet search")
	local pos = self:get_pos()
	
	-- Find toilet within range
	lf("traveller:find_and_use_toilet", "Searching for toilets within " .. TRAVEL_RANGE .. " blocks")
	local toilet_pos = minetest.find_node_near(pos, TRAVEL_RANGE, {"homedecor:toilet", "homedecor:toilet_open"})
	
	if not toilet_pos then
		lf("traveller", "No toilet found within range")
		return false
	end
	
	lf("traveller", "Found toilet at " .. minetest.pos_to_string(toilet_pos))
	
	-- Save the exact toilet position for later teleport
	self._toilet_pos = vector.round(toilet_pos)
	lf("traveller", "Saved toilet position: " .. minetest.pos_to_string(self._toilet_pos))
	
	lf("traveller:find_and_use_toilet", "Checking if toilet location is safe")
	
	-- Check if destination is safe
	if not is_destination_safe(self, toilet_pos) then
		lf("traveller", "Toilet location is not safe")
		return false
	end
	
	-- Calculate distance to toilet
	local distance = vector.distance(pos, toilet_pos)
	lf("traveller:find_and_use_toilet", "Distance to toilet: " .. string.format("%.2f", distance))
	
	-- If already close to toilet, use it
	if distance < 2 then
		lf("traveller", "Already near toilet, using it")
		lf("traveller:find_and_use_toilet", "Calling flush_toilet directly")
		return flush_toilet(self, toilet_pos)
	end
	
	-- Find path to toilet
	lf("traveller", "Finding path to toilet from " .. minetest.pos_to_string(pos) .. " to " .. minetest.pos_to_string(toilet_pos))
	lf("traveller:find_and_use_toilet", "Using A* pathfinding with parameters: 8, 1, 1")
	
	-- Create above_toilet_pos as destination (one block above toilet)
	local above_toilet_pos = { x = toilet_pos.x, y = toilet_pos.y + 1, z = toilet_pos.z }
	lf("traveller:find_and_use_toilet", "Created above_toilet_pos at " .. minetest.pos_to_string(above_toilet_pos))
	
	local path = minetest.find_path(pos, above_toilet_pos, 8, 1, 1, "A*")
	
	if path ~= nil then
		lf("traveller", "Path found to toilet with " .. #path .. " nodes")
		lf("traveller:find_and_use_toilet", "Path found successfully, setting up movement")
		self:set_yaw({self:get_pos(), above_toilet_pos})
		
		-- Set up action to use toilet when arriving
		lf("traveller:find_and_use_toilet", "Setting destination and action for toilet")
		self.destination = above_toilet_pos
		self.action = "use_toilet"
		core_path.to_follow_path(self, path, above_toilet_pos, to_action, "use_toilet")
		return true
	else
		lf("traveller", "No path found to toilet")
		return false
	end
end

-- Function to find path to refrigerator and use it
-- ,,ref1
local function find_and_use_refrigerator(self)
	lf("traveller:find_and_use_refrigerator", "Starting refrigerator search")
	local pos = self:get_pos()
	
	-- Find refrigerator within range
	lf("traveller:find_and_use_refrigerator", "Searching for refrigerators within " .. TRAVEL_RANGE .. " blocks")
	local refrigerator_pos = minetest.find_node_near(pos, TRAVEL_RANGE, {"homedecor:refrigerator_white"})
	
	if not refrigerator_pos then
		lf("traveller", "No refrigerator found within range")
		return false
	end
	
	-- Save refrigerator position
	self._refrigerator_pos = refrigerator_pos
	lf("traveller", "Found refrigerator at " .. minetest.pos_to_string(refrigerator_pos))
	lf("traveller:find_and_use_refrigerator", "Checking if refrigerator location is safe")
	

    	-- Calculate target position in front of refrigerator based on its orientation
	local target_pos = get_refrigerator_front(refrigerator_pos)
	self._refrigerator_front = target_pos
	lf("traveller", "Target position in front of refrigerator: " .. minetest.pos_to_string(target_pos))

    
	-- Check if destination is safe
	if not is_destination_safe(self, refrigerator_pos) then
		lf("traveller", "Refrigerator location is not safe")
		return false
	end
	
	-- Calculate distance to refrigerator
	local distance = vector.distance(pos, refrigerator_pos)
	lf("traveller:find_and_use_refrigerator", "Distance to refrigerator: " .. string.format("%.2f", distance))
	
	-- If already close to refrigerator, use it
	if distance < 3 then
		lf("traveller", "Already near refrigerator, using it")
		lf("traveller:find_and_use_refrigerator", "Calling use_refrigerator directly")
		return use_refrigerator(self, refrigerator_pos)
	end
	
	-- Find path to refrigerator
	lf("traveller", "Finding path to refrigerator from " .. minetest.pos_to_string(pos) .. " to " .. minetest.pos_to_string(refrigerator_pos))
	lf("traveller:find_and_use_refrigerator", "Using A* pathfinding with parameters: 8, 1, 1")
	local path = minetest.find_path(pos, target_pos, 8, 1, 1, "A*")
	
	if path ~= nil then
		lf("traveller", "Path found to refrigerator with " .. #path .. " nodes")
		lf("traveller:find_and_use_refrigerator", "Path found successfully, setting up movement")
		self:set_yaw({self:get_pos(), target_pos})
		
		-- Set up action to use refrigerator when arriving
		lf("traveller:find_and_use_refrigerator", "Setting destination and action for refrigerator")
		self.destination = refrigerator_pos
		self.action = "use_refrigerator"
		core_path.to_follow_path(self, path, target_pos, to_action, "use_refrigerator")
		return true
	else
		lf("traveller", "No path found to refrigerator")
		return false
	end
end

-- Function to find path to bookshelf and use it
-- ,,book1
local function find_and_use_bookshelf(self)
	lf("traveller:find_and_use_bookshelf", "Starting bookshelf search")
	local pos = self:get_pos()
	
	-- Find bookshelf within range
	lf("traveller:find_and_use_bookshelf", "Searching for bookshelves within " .. TRAVEL_RANGE .. " blocks")
	local bookshelf_pos = minetest.find_node_near(pos, TRAVEL_RANGE, {"default:bookshelf"})
	
	if not bookshelf_pos then
		lf("traveller", "No bookshelf found within range")
		return false


	else
		-- Log bookshelf position and node name
		local bookshelf_node = minetest.get_node(bookshelf_pos)
		lf("traveller", "Found bookshelf at position: " .. minetest.pos_to_string(bookshelf_pos) .. " with node name: " .. (bookshelf_node.name or "unknown"))
	end

    -- front_check(bookshelf_pos)
	
	-- Save bookshelf position
	self._bookshelf_pos = bookshelf_pos
	lf("traveller", "Found bookshelf at " .. minetest.pos_to_string(bookshelf_pos))
	lf("traveller:find_and_use_bookshelf", "Checking if bookshelf location is safe")
	

    	-- Calculate target position in front of bookshelf based on its orientation
	-- local target_pos = get_bookshelf_front(bookshelf_pos)
	-- self._bookshelf_front = target_pos
	-- lf("traveller", "Target position in front of bookshelf: " .. minetest.pos_to_string(target_pos))
	lf("traveller", "Target position in front of bookshelf: " .. minetest.pos_to_string(bookshelf_pos))

    
	-- Check if destination is safe
	if not is_destination_safe(self, bookshelf_pos) then
		lf("traveller", "Bookshelf location is not safe")
		return false
	end
	
	-- Calculate distance to bookshelf
	local distance = vector.distance(pos, bookshelf_pos)
	lf("traveller:find_and_use_bookshelf", "Distance to bookshelf: " .. string.format("%.2f", distance))
	
	-- If already close to bookshelf, use it
	if distance < 1 then
		lf("traveller", "Already near bookshelf, using it")
		lf("traveller:find_and_use_bookshelf", "Calling use_bookshelf directly")
		return use_bookshelf(self, bookshelf_pos)
	end
	
	-- Find path to bookshelf
	lf("traveller", "Finding path to bookshelf from " .. minetest.pos_to_string(pos) .. " to " .. minetest.pos_to_string(bookshelf_pos))
	lf("traveller:find_and_use_bookshelf", "Using A* pathfinding with parameters: 8, 1, 1")
	-- local path = minetest.find_path(pos, target_pos, 8, 1, 1, "A*")
	local path, actual_destination = get_shortest_path(bookshelf_pos, pos)

	if path ~= nil then
        self._bookshelf_front = actual_destination
        for i, node in ipairs(path) do
            lf("traveller:find_and_use_bookshelf", string.format("Path step %d: %s", i, minetest.pos_to_string(node)))
        end

        lf("traveller", "Path found to bookshelf with " .. #path .. " nodes")
		lf("traveller:find_and_use_bookshelf", "Path found successfully, setting up movement")
		lf("traveller:find_and_use_bookshelf", "Actual destination: " .. minetest.pos_to_string(actual_destination))
		self:set_yaw({self:get_pos(), actual_destination})
		
		-- Set up action to use bookshelf when arriving
		lf("traveller:find_and_use_bookshelf", "Setting destination and action for bookshelf")
		self.destination = actual_destination
		self.action = "use_bookshelf"
        -- ,,hack
		core_path.to_follow_path(self, path, actual_destination, to_action, "use_bookshelf")
		return true
	else
		lf("traveller", "No path found to bookshelf")
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
	-- if distance < 2 then
	-- 	lf("traveller:task_base", "Already at destination, performing action")
	-- 	self.destination = destination
	-- 	self.action = action
	-- 	to_action(self)
	-- 	return true
	-- end

	-- Find path to destination
	lf("traveller:task_base", "Finding path from " .. minetest.pos_to_string(pos) .. " to " .. minetest.pos_to_string(destination))
	local path = minetest.find_path(pos, destination, 8, 1, 1, "A*")

	if path ~= nil then
		lf("traveller:task_base", "Path found with " .. #path .. " nodes")
		-- Place destination marker
		maidroid.cores.path.place_destination_marker(destination)
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
	self._is_using_toilet = nil  -- Clear toilet state
	self._toilet_pos = nil      -- Clear saved toilet position
	self._is_using_refrigerator = nil  -- Clear refrigerator state
	self._refrigerator_pos = nil      -- Clear saved refrigerator position
	-- Set the correct tool for traveller
	self:set_tool("default:bronzeblock")
	lf("traveller:to_wander", "setting state to WANDER")
	wander.to_wander(self, from_caller or "traveller:to_wander")
end

-- ,,act
-- Action handler
local act = function(self)
	lf("traveller:act", "act function called! action=" .. tostring(self.action))
	
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
				lf("DEBUG traveller:act", "sleep action completed, staying in sleep state")
				return nil -- Prevent return to wander
			else
				lf("DEBUG traveller:act", "beds mod not available for sleeping")
			end
		else
			lf("traveller:act", "traveller_sleep: no bed target")
		end
		self._bed_target = nil
	elseif self.action == "turn_on_shower" then
		lf("traveller:act", "turn_on_shower: " .. minetest.pos_to_string(self:get_pos()))
		lf("traveller:act", "destination=" .. (self.destination and minetest.pos_to_string(self.destination) or "nil"))
		if self.destination then
			lf("traveller:act", "Calling turn_on_shower_head at destination")
			local success = turn_on_shower_head(self, self.destination)
			lf("traveller:act", "turn_on_shower_head returned: " .. tostring(success))
			if success then
				lf("DEBUG traveller:act", "Successfully turned on shower")
				-- Points are now awarded directly in turn_on_shower_head function
			else
				lf("DEBUG traveller:act", "Failed to turn on shower")
			end
		else
			lf("traveller:act", "turn_on_shower: no destination")
		end
		self.destination = nil
	elseif self.action == "use_toilet" then
		lf("traveller:act", "use_toilet: " .. minetest.pos_to_string(self:get_pos()))
		lf("traveller:act", "destination=" .. (self.destination and minetest.pos_to_string(self.destination) or "nil"))
		if self.destination then
			lf("traveller:act", "Calling flush_toilet at destination")
			local success = flush_toilet(self, self.destination)
			if success then
				lf("DEBUG traveller:act", "Successfully used toilet")
				-- Points are now awarded directly in flush_toilet function
			else
				lf("DEBUG traveller:act", "Failed to use toilet")
			end
		else
			lf("traveller:act", "use_toilet: no destination")
		end
		self.destination = nil
	elseif self.action == "use_refrigerator" then
		lf("traveller:act", "use_refrigerator: " .. minetest.pos_to_string(self:get_pos()))
		lf("traveller:act", "destination=" .. (self.destination and minetest.pos_to_string(self.destination) or "nil"))
		if self.destination then
			lf("traveller:act", "Calling use_refrigerator at destination")
			local success = use_refrigerator(self, self.destination)
			if success then
				lf("DEBUG traveller:act", "Successfully used refrigerator")
				-- Points are now awarded directly in use_refrigerator function
			else
				lf("DEBUG traveller:act", "Failed to use refrigerator")
			end
		else
			lf("traveller:act", "use_refrigerator: no destination")
		end
		self.destination = nil
	elseif self.action == "use_bookshelf" then
		lf("traveller:act", "use_bookshelf: " .. minetest.pos_to_string(self:get_pos()))
		lf("traveller:act", "destination=" .. (self.destination and minetest.pos_to_string(self.destination) or "nil"))
		if self.destination then
			lf("traveller:act", "Calling use_bookshelf at destination")
			local success = use_bookshelf(self, self.destination)
			if success then
				lf("DEBUG traveller:act", "Successfully used bookshelf")
				-- Points are now awarded directly in use_bookshelf function
			else
				lf("DEBUG traveller:act", "Failed to use bookshelf")
			end
		else
			lf("traveller:act", "use_bookshelf: no destination")
		end
		self.destination = nil
	else
		lf("traveller:act", "unknown action: " .. tostring(self.action))
	end
	
	-- Return to wander after action completion (only if not showering, using toilet, using refrigerator, or using bookshelf)
	if not self._is_showering and not self._is_using_toilet and not self._is_using_refrigerator and not self._is_using_bookshelf then
	    to_wander(self, "traveller:act")
	end
end

-- ,,task
task = function(self)
	local pos = self:get_pos()
	local inv = self:get_inventory()
	
	-- Randomly pick one of five actions
	local choice = math.random(5)
    choice = 5
	lf("traveller:task", "CHOICE=" .. choice .. " selected")

	if choice == 1 then
		lf("traveller:task", "CHOICE=1: try_sleep_in_bed - about to call")
		lf("traveller:task", "pos=" .. minetest.pos_to_string(pos))
		lf("traveller:task", "core_module params: to_action=" .. tostring(to_action) .. ", name=traveller")
		local result = maidroid.sleep.try_sleep_in_bed(self, pos, {to_action = to_action, name = "traveller"})
		lf("traveller:task", "try_sleep_in_bed returned: " .. tostring(result))
	elseif choice == 2 then
		lf("traveller:task", "CHOICE=2: find_and_turn_on_shower")
		lf("traveller:task", "Calling find_and_turn_on_shower function")    
		find_and_turn_on_shower(self)
	elseif choice == 3 then
		lf("traveller:task", "CHOICE=3: find_and_use_toilet")
		lf("traveller:task", "Calling find_and_use_toilet function")
		find_and_use_toilet(self)
	elseif choice == 4 then
		lf("traveller:task", "CHOICE=4: find_and_use_refrigerator")
		lf("traveller:task", "Calling find_and_use_refrigerator function")
		find_and_use_refrigerator(self)
	elseif choice == 5 then
		lf("traveller:task", "CHOICE=5: find_and_use_bookshelf")
		lf("traveller:task", "Calling find_and_use_bookshelf function")
		find_and_use_bookshelf(self)
	end
end

-- ,,start
-- Core interface functions
on_start = function(self)
	self.path = nil
	current_destination = nil
	
	-- Initialize point system
	initialize_points(self)
	
	-- Initialize reward system
	initialize_reward_system(self)
	
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
	-- Throttle: only process every 0.3 seconds to reduce frequency
	self._step_timer = (self._step_timer or 0) + dtime
	if self._step_timer < 0.3 then
		return -- Skip processing until 0.3 seconds have passed
	end
	
	-- Preserve accumulated time for wander core timers
	local accumulated_dtime = self._step_timer
	self._step_timer = 0 -- Reset timer after executing step
	
	-- Periodically log total points and check rewards (every 30 seconds for logging, 60 seconds for rewards)
	self._points_log_timer = (self._points_log_timer or 0) + accumulated_dtime
	self._reward_check_timer = (self._reward_check_timer or 0) + accumulated_dtime
	
	-- Update metrics logging timer
	metrics_log_timer = metrics_log_timer + accumulated_dtime
	if metrics_log_timer >= metrics_log_interval then
		log_traveller_metrics(self)
		metrics_log_timer = 0 -- Reset timer
	end
	
	-- Check for rewards every 60 seconds
	if self._reward_check_timer >= REWARD_CHECK_INTERVAL then
		self._reward_check_timer = 0
		check_and_award_rewards(self)
	end
	
	-- Log points every 30 seconds
	if self._points_log_timer >= 30 then
		self._points_log_timer = 0
		local total_points = get_total_points(self)
		local points_used = self._reward_points_used or 0
		local points_available = total_points - points_used
		lf("traveller", string.format("Current accumulated points: %d (Available for rewards: %d)", total_points, points_available))
	end
	
	-- Check if maidroid is sleeping - if so, prevent all movement and processing
	if maidroid.sleep.on_step_sleep_check(self, accumulated_dtime, moveresult) then
		return -- Skip all other processing while sleeping
	end
	
	-- Check if maidroid is showering - if so, prevent all movement and processing
	if on_step_shower_check(self, accumulated_dtime, moveresult) then
		return -- Skip all other processing while showering
	end
	
	-- Check if maidroid is using toilet - if so, prevent all movement and processing
	if on_step_toilet_check(self, accumulated_dtime, moveresult) then
		return -- Skip all other processing while using toilet
	end
	
	-- Check if maidroid is using refrigerator - if so, prevent all movement and processing
	if on_step_refrigerator_check(self, accumulated_dtime, moveresult) then
		return -- Skip all other processing while using refrigerator
	end
	
	-- Check if maidroid is using bookshelf - if so, prevent all movement and processing
	if on_step_bookshelf_check(self, accumulated_dtime, moveresult) then
		return -- Skip all other processing while using bookshelf
	end
	
	-- Check distance from activation position and teleport back if too far
	if check_distance_from_activation(self) then
		return -- Teleported back, skip other processing
	end
	
    -- lf("DDEBUG on_step", "TIMER ON - dtime=" .. tostring(accumulated_dtime))
    
	-- Ensure we have the correct tool (bronze block) when not sleeping, showering, using toilet, using refrigerator, or using bookshelf
	if not self._is_sleeping and not self._is_showering and not self._is_using_toilet and not self._is_using_refrigerator and not self._is_using_bookshelf and self.selected_tool ~= "default:bronzeblock" then
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
		maidroid.cores.path.on_step(self, accumulated_dtime, moveresult)
		return
	end
	
	-- Use wander core's on_step with our task function
	-- This handles the wander behavior and calls our task function periodically
	if self.state ~= maidroid.states.ACT then
		wander_core.on_step(self, accumulated_dtime, moveresult, task)
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
	.. S("It can find and travel to chests, beds, signs, showers, toilets, refrigerators, and other points of interest.") .. "\n\n"
	.. S("Activation: Give the maidroid a bronze block to activate traveller mode.") .. "\n\n"
	.. S("Features:") .. "\n"
	.. "- " .. S("Automatic destination finding") .. "\n"
	.. "- " .. S("Safe pathfinding") .. "\n"
	.. "- " .. S("Periodic exploration") .. "\n"
	.. "- " .. S("Occasional sleeping in beds") .. "\n"
	.. "- " .. S("Finding and turning on shower heads") .. "\n"
	.. "- " .. S("Finding and using toilets") .. "\n"
	.. "- " .. S("Finding and using refrigerators") .. "\n"
	.. "- " .. S("Point system for completed actions") .. "\n"
	.. "- " .. S("Distance limit (10 blocks from activation)") .. "\n"
	.. "- " .. S("Auto-teleport back if too far") .. "\n"
	.. "- " .. S("Wanders when no destinations available") .. "\n\n"
	.. S("Point System:") .. "\n"
	.. "- Toilet: 5 points" .. "\n"
	.. "- Shower: 8 points" .. "\n"
	.. "- Refrigerator: 10 points" .. "\n"
	.. "- Reward: 1 coal lump per 10 points" .. "\n\n"
	.. S("The traveller will automatically explore within a configurable range and return to wandering when no destinations are found.") .. "\n"
	.. S("It will occasionally sleep in nearby beds to rest during its travels.") .. "\n"
	.. S("It can also find shower heads and turn them on, creating water particle effects.") .. "\n"
	.. S("Additionally, it can find toilets and flush them, simulating bathroom breaks.") .. "\n"
	.. S("It can also find refrigerators and randomly pick items to hold for 10 seconds, simulating snack breaks.") .. "\n"
	.. S("Each successful action awards points that are accumulated in the maidroid's memory.") .. "\n"
	.. S("Every 60 seconds, the system checks for accumulated points and awards coal lumps automatically.") .. "\n"
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
	path_max         = 18,
	can_sell         = true,
	doc = doc,
})

-- lrfurn:sofa
-- default:bookshelf
-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
