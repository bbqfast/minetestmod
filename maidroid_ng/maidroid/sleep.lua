-- Maidroid Sleep Module
-- Shared sleep functionality for all maidroid cores

-- Use a safe logging function that works even if maidroid isn't fully loaded yet
-- local lf = function(tag, msg)
--     if maidroid and maidroid.logf then
--         maidroid.logf(tag, msg)
--     elseif minetest then
--         minetest.log("info", "[sleep_module] " .. tag .. ": " .. msg)
--     else
--         print("[sleep_module] " .. tag .. ": " .. msg)
--     end
-- end

local lf = maidroid.lf


-- ,,bed,,sleep_action
-- Function to handle the sleep action for maidroid
local function handle_sleep_action(droid, bed_pos)
    lf("DEBUG sleep_module:handle_sleep_action", "handling sleep action at bed_pos=" .. minetest.pos_to_string(bed_pos))
    
    -- Check if already sleeping to prevent multiple sleep calls
    if droid._is_sleeping == true then
        lf("DEBUG sleep_module:handle_sleep_action", "maidroid already sleeping, ignoring sleep action")
        return false
    end
    
    -- Update action_taken_metrics for sleep (if available)
    if maidroid.cores and maidroid.cores.generic_cooker then
        local action_taken_metrics = maidroid.cores.generic_cooker.action_taken_metrics or {}
        action_taken_metrics["sleep"] = (action_taken_metrics["sleep"] or 0) + 1
        lf("DEBUG action_metrics", "sleep called: " .. action_taken_metrics["sleep"])
        maidroid.cores.generic_cooker.action_taken_metrics = action_taken_metrics
    end
    
    -- Make maidroid sleep directly using bed logic
    -- Position maidroid for sleeping (similar to lay_down function)
    local node = minetest.get_node(bed_pos)
    local param2 = node.param2
    local dir = minetest.facedir_to_dir(param2)
    
    -- Calculate sleep position - maidroid should sleep with head toward the pillow
    -- The pillow is usually at the head of the bed (param2 direction)
    -- So the maidroid should sleep perpendicular to the bed direction
    local sleep_pos
    local sleep_yaw
    
    if param2 == 0 then -- Bed facing +Z (north)
        sleep_pos = {x = bed_pos.x, y = bed_pos.y + 0.07, z = bed_pos.z + 0.2}
        sleep_yaw = math.pi -- Face north (corrected from south)
    elseif param2 == 1 then -- Bed facing +X (east)
        sleep_pos = {x = bed_pos.x - 0.2, y = bed_pos.y + 0.07, z = bed_pos.z}
        sleep_yaw = -math.pi / 2 -- Face west (corrected from east)
    elseif param2 == 2 then -- Bed facing -Z (south)
        sleep_pos = {x = bed_pos.x, y = bed_pos.y + 0.07, z = bed_pos.z - 0.2}
        sleep_yaw = 0 -- Face south (corrected from north)
    elseif param2 == 3 then -- Bed facing -X (west)
        sleep_pos = {x = bed_pos.x + 0.2, y = bed_pos.y + 0.07, z = bed_pos.z}
        sleep_yaw = math.pi / 2 -- Face east (corrected from west)
    else
        -- Fallback to original logic if param2 is unexpected
        sleep_pos = {
            x = bed_pos.x + dir.x / 2,
            y = bed_pos.y + 0.07,
            z = bed_pos.z + dir.z / 2
        }
        sleep_yaw = minetest.facedir_to_dir(param2).x
    end
    
    -- Move maidroid to sleep position
    droid.object:set_pos(sleep_pos)
    droid.object:set_yaw(sleep_yaw)
    
    -- Set sleep animation
    local lay_anim = (maidroid and maidroid.animation and maidroid.animation.LAY) or "lay"
    droid:set_animation(lay_anim, 0)
    
    -- Halt the maidroid while sleeping
    droid:halt()
    
    -- Explicitly set velocity to zero to prevent any movement
    droid.object:set_velocity({x = 0, y = 0, z = 0})
    
    -- Set a flag to prevent on_step from reactivating movement
    droid._is_sleeping = true
    
    lf("DEBUG sleep_module:handle_sleep_action", "maidroid sleeping in bed at " .. minetest.pos_to_string(bed_pos) .. " (DEBUG: keeping in sleep state, velocity=0, sleep_flag=true)")
    
    -- Add manual wake-up timer with better error handling
    local wake_time = 8
    lf("DEBUG sleep_module:handle_sleep_action", "setting wake-up timer for " .. wake_time .. " seconds")
    
    minetest.after(wake_time, function()
        lf("DEBUG sleep_module:wake_timer", "wake-up timer triggered!")
        
        if droid and droid.object then
            lf("DEBUG sleep_module:wake_timer", "droid and object valid, clearing sleep flag")
            
            -- Clear the sleep flag FIRST to allow normal movement
            droid._is_sleeping = false
            
            -- IMPORTANT: Clear the action state to prevent immediate re-sleep
            droid.action = nil
            
            -- Wake up the maidroid - move it away from bed
            local wake_pos = vector.add(bed_pos, {x=0, y=1, z=0})
            droid.object:set_pos(wake_pos)
            
            -- Restore normal animation
            local stand_anim = (maidroid and maidroid.animation and maidroid.animation.STAND) or "stand"
            droid:set_animation(stand_anim, 30)
            
            -- Resume normal behavior - force return to wander
            if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.to_wander then
                maidroid.cores.generic_cooker.to_wander(droid, "sleep_module:wake_timer", 0, 1)
            end
            
            lf("DEBUG sleep_module:wake_timer", "maidroid woke up from sleep, sleep flag cleared, action cleared, moved to " .. minetest.pos_to_string(wake_pos))
        else
            lf("DEBUG sleep_module:wake_timer", "wake-up timer: droid or object is nil")
            lf("DEBUG sleep_module:wake_timer", "droid=" .. tostring(droid) .. " object=" .. tostring(droid and droid.object))
        end
    end)
    
    -- Add backup wake-up timer at 15 seconds
    minetest.after(15, function()
        lf("DEBUG sleep_module:wake_timer", "backup wake-up timer triggered!")
        
        if droid and droid.object and droid._is_sleeping == true then
            lf("DEBUG sleep_module:wake_timer", "backup: forcing wake-up")
            droid._is_sleeping = false
            droid.action = nil  -- Clear action state
            local wake_pos = vector.add(bed_pos, {x=0, y=2, z=0})
            droid.object:set_pos(wake_pos)
            local stand_anim = (maidroid and maidroid.animation and maidroid.animation.STAND) or "stand"
            droid:set_animation(stand_anim, 30)
            if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.to_wander then
                maidroid.cores.generic_cooker.to_wander(droid, "sleep_module:backup_wake_timer", 0, 1)
            end
            lf("DEBUG sleep_module:wake_timer", "backup: maidroid force woke up, action cleared")
        end
    end)
    
    lf("DEBUG sleep_module:handle_sleep_action", "sleep state maintained for debugging (no auto wake-up)")
    
    return true
end

-- ,,bed,,sleep
-- Function to find and sleep in a nearby bed
local function try_sleep_in_bed(droid, pos, core_module)
    lf("DEBUG sleep_module:try_sleep_in_bed", "looking for bed near pos=" .. minetest.pos_to_string(pos))
    
    -- Check if beds mod is available
    if not beds or not beds.on_rightclick then
        lf("DEBUG sleep_module:try_sleep_in_bed", "beds mod not available")
        return false
    end
    
    local find_dist = 12
    local bed_pos = minetest.find_node_near(pos, find_dist, {"group:bed"})
    if not bed_pos then
        lf("DEBUG sleep_module:try_sleep_in_bed", "no bed found near pos=" .. minetest.pos_to_string(pos))
        return false
    end

    local target = vector.add(bed_pos, {x=0, y=1, z=0})
    local rounded_pos = vector.round(pos)
    local path = minetest.find_path(rounded_pos, target, find_dist+1, 2, 2, "A*_noprefetch")
    if not path then
        lf("DEBUG sleep_module:try_sleep_in_bed", "path not found to bed at " .. minetest.pos_to_string(bed_pos))
        return false
    end

    -- Use the core module's target system if available
    if core_module and core_module.GenericCookerTarget then
        droid._bed_target = core_module.GenericCookerTarget.new(bed_pos, nil, nil)
    else
        droid._bed_target = {pos = bed_pos}
    end
    
    droid:set_tool("maidroid:spatula")
    
    -- Use the core module's path following if available
    if core_module and maidroid.cores.path and maidroid.cores.path.to_follow_path then
        local to_action = core_module.to_action or function() end
        maidroid.cores.path.to_follow_path(droid, path, target, to_action, core_module.name .. "_sleep")
    else
        -- Fallback: directly handle sleep action
        handle_sleep_action(droid, bed_pos)
    end
    
    return true
end

-- ,,step_sleep_check
-- Function to check if maidroid is sleeping and handle sleep state
local function on_step_sleep_check(droid, dtime, moveresult)
    -- Check if maidroid is sleeping - if so, prevent all movement and processing
    if droid._is_sleeping == true then
        -- Ensure velocity stays zero while sleeping
        droid.object:set_velocity({x = 0, y = 0, z = 0})
        -- Keep sleep animation active
        local lay_anim = (maidroid and maidroid.animation and maidroid.animation.LAY) or "lay"
        droid:set_animation(lay_anim, 0)
        -- Skip all other processing while sleeping
        return true -- Return true to indicate sleep state is active
    end
    return false -- Return false to indicate not sleeping
end

-- Export functions
if maidroid then
    maidroid.sleep = {
        handle_sleep_action = handle_sleep_action,
        try_sleep_in_bed = try_sleep_in_bed,
        on_step_sleep_check = on_step_sleep_check
    }
end

lf("sleep_module", "Maidroid sleep module loaded")
