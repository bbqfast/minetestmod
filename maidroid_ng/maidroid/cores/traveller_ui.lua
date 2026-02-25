-- Traveller UI functions for maidroid mod
-- This file contains all traveller tab related UI functions



local lf = maidroid.lf
local S = minetest.get_translator("maidroid")

local reward_init_items = {
    "default:coal_lump",
    "default:iron_lump", 
    "default:gold_lump"
}

-- Initialize reward items once from reward_init_items
local reward_items = {}
for i, item in ipairs(reward_init_items) do
	reward_items[i] = {
		name = item,
		available = true,  -- Track if this position is available
		slot = i  -- UI slot position (1-based)
	}
end

-- Create traveller events for reward inventory
local function create_traveller_events(self, inventory_name)
	self.traveller_inventory_id = inventory_name
	local inventory = minetest.create_detached_inventory(self.traveller_inventory_id, {
		on_put = function(_, listname)
			lf("DEBUG: create_traveller_events:on_put", "*** ON_PUT CALLED *** for list: " .. tostring(listname))
		end,

		allow_put = function(inv, listname, index, stack, player)
			lf("DEBUG: create_traveller_events:allow_put", "*** ALLOW_PUT CALLED *** by " .. player:get_player_name() .. " for list: " .. tostring(listname) .. ", item: " .. stack:get_name())
			
			-- Only allow putting specific reward items in rewardable list
			if listname == "rewardable" then
				local item_name = stack:get_name()
				-- Check if item is in our reward_items tracking
				for _, reward_item in ipairs(reward_items) do
					if item_name == reward_item.name then
						return stack:get_count()
					end
				end
				return 0 -- Reject other items
			end
			
			return 0
		end,

		on_take = function(_, listname, index, stack, player)
			lf("DEBUG: create_traveller_events:on_take", "*** ON_TAKE CALLED *** for list: " .. tostring(listname) .. ", index: " .. tostring(index))
			
			-- Remove item from reward_items tracking when taken from rewardable list
			if listname == "rewardable" then
				if reward_items[index] then
					local removed_item = reward_items[index].name
					reward_items[index] = nil
					lf("DEBUG: create_traveller_events:on_take", "*** REMOVED ITEM " .. removed_item .. " FROM REWARD_ITEMS AT SLOT " .. index .. " (ITEM TAKEN) ***")
				end
			end
		end,

		allow_take = function(inv, listname, index, stack, player)
			lf("DEBUG: create_traveller_events:allow_take", "*** ALLOW_TAKE CALLED *** by " .. player:get_player_name() .. " for list: " .. tostring(listname) .. ", item: " .. stack:get_name())
			return 99
		end,

		on_move = function(_, from_list, from_index, to_list, to_index, count, player)
			lf("DEBUG: create_traveller_events:on_move", "*** ON_MOVE CALLED *** from " .. tostring(from_list) .. " to " .. tostring(to_list))
			
			-- Handle moving from rewardable to reward_choice
			if from_list == "rewardable" and to_list == "reward_choice" then
				lf("DEBUG: create_traveller_events:traveller_inventory", "*** ITEM MOVED FROM REWARDABLE TO REWARD_CHOICE ***")
				
				-- Get the maidroid this inventory belongs to
				local droid = self
				lf("DEBUG: create_traveller_events:traveller_inventory", "*** DROID OBJECT ***: " .. tostring(droid))
				
				-- Update the selected reward based on the moved item
				local traveller_inv = maidroid.traveller_inventories[self.traveller_inventory_id]
				if traveller_inv then
					local moved_stack = traveller_inv:get_stack(to_list, to_index)
					lf("DEBUG: create_traveller_events:traveller_inventory", "*** MOVED STACK ***: " .. tostring(moved_stack))
					if moved_stack and not moved_stack:is_empty() then
						local item_name = moved_stack:get_name()
						-- Use the set_selected_reward function instead of direct assignment
						local success = maidroid.set_traveller_selected_reward(droid, item_name)
						if success then
							lf("DEBUG: create_traveller_events:traveller_inventory", "*** SELECTED REWARD UPDATED TO ***: " .. item_name)
							lf("traveller_ui", "Reward choice updated to: " .. item_name)
							
							-- Send confirmation to player
							if player and player:is_player() then
								minetest.chat_send_player(player:get_player_name(), "Reward selection updated to: " .. item_name)
							end
						else
							lf("DEBUG: create_traveller_events:traveller_inventory", "*** FAILED TO SET REWARD TO ***: " .. item_name)
							if player and player:is_player() then
								minetest.chat_send_player(player:get_player_name(), "Failed to set reward selection: " .. item_name)
							end
						end
					else
						lf("DEBUG: create_traveller_events:traveller_inventory", "*** MOVED STACK IS EMPTY OR NIL ***")
					end
				else
					lf("DEBUG: create_traveller_events:traveller_inventory", "*** TRAVELLER INVENTORY NOT FOUND ***")
				end
				
				-- Remove the item from reward_items tracking completely
				if reward_items[from_index] then
					local removed_item = reward_items[from_index].name
					reward_items[from_index] = nil
					lf("DEBUG: create_traveller_events:traveller_inventory", "*** REMOVED ITEM " .. removed_item .. " FROM REWARD_ITEMS AT SLOT " .. from_index .. " ***")
				end
				
				-- Refresh the UI AFTER inventory operations are complete
				if player and player:is_player() then
					local current_tab = droid.current_tab or 3 -- Traveller tab
					lf("DEBUG: create_traveller_events:traveller_inventory", "*** BEFORE UI REFRESH *** - current_tab: " .. tostring(droid.current_tab))
					minetest.show_formspec(player:get_player_name(), "maidroid:gui", maidroid.get_formspec(droid, player, current_tab))
					lf("DEBUG: create_traveller_events:traveller_inventory", "*** AFTER UI REFRESH *** - current_tab: " .. tostring(droid.current_tab))
				end
			-- Handle moving from reward_choice to rewardable
			elseif from_list == "reward_choice" and to_list == "rewardable" then
				lf("DEBUG: create_traveller_events:traveller_inventory", "*** ITEM MOVED FROM REWARD_CHOICE TO REWARDABLE ***")
				
				-- Get the maidroid this inventory belongs to
				local droid = self
				
				-- Clear the selected reward when moving back
				local success = maidroid.set_traveller_selected_reward(droid, nil)
				if success then
					lf("DEBUG: create_traveller_events:traveller_inventory", "*** CLEARED SELECTED REWARD ***")
					lf("traveller_ui", "Reward selection cleared")
					
					-- Send confirmation to player
					if player and player:is_player() then
						minetest.chat_send_player(player:get_player_name(), "Reward selection cleared - reverted to default")
					end
				else
					lf("DEBUG: create_traveller_events:traveller_inventory", "*** FAILED TO CLEAR REWARD ***")
					if player and player:is_player() then
						minetest.chat_send_player(player:get_player_name(), "Failed to clear reward selection")
					end
				end
				
				-- Update availability tracking for the target slot
				if reward_items[to_index] then
					reward_items[to_index].available = true
					lf("DEBUG: create_traveller_events:traveller_inventory", "*** MARKED SLOT " .. to_index .. " AS AVAILABLE ***")
				end
				
				-- Refresh the UI AFTER inventory operations are complete
				if player and player:is_player() then
					local current_tab = self.current_tab or 3 -- Traveller tab
					minetest.show_formspec(player:get_player_name(), "maidroid:gui", maidroid.get_formspec(self, player, current_tab))
				end
			end
		end,

		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			lf("DEBUG: create_traveller_events:allow_move", "*** ALLOW_MOVE CALLED *** by " .. player:get_player_name() .. " from " .. tostring(from_list) .. " to " .. tostring(to_list) .. ", count: " .. tostring(count))
			return count
		end,
	})

	inventory:set_size("rewardable", 3) -- 3 slots: coal, steel, gold
	inventory:set_size("reward_choice", 1) -- 1 slot for reward selection

	return inventory
end

-- Handle rewardable logic for traveller
local function handle_rewardable_logic(self)
	-- Create and update traveller inventory
	if not self.traveller_inventory_id then
		-- Use the new create_traveller_events function
		local traveller_inventory = create_traveller_events(self, maidroid.generate_unique_manufacturing_id())
		maidroid.traveller_inventories = maidroid.traveller_inventories or {}
		maidroid.traveller_inventories[self.traveller_inventory_id] = traveller_inventory
		lf("traveller_tab", "Created traveller inventory with ID: " .. self.traveller_inventory_id)
		
		-- Initialize reward items only once from reward_init_items
		for i, reward_item in ipairs(reward_items) do
			if i <= 3 then -- Only fill first 3 slots
				local stack = ItemStack(reward_item.name .. " 1") -- Add 1 item
				traveller_inventory:set_stack("rewardable", i, stack)
				lf("traveller_tab", "Set rewardable slot " .. i .. " to " .. reward_item.name .. " 1")
			end
		end
		lf("DEBUG traveller_tab", "Initialized rewardable slots with default items")
		
		-- Register UI callback for traveller state updates
        -- ,,x1
		local ui_callback = function(callback_data)
			lf("DEBUG traveller_ui", "Received UI callback: " .. callback_data.state_type)
			-- Handle different state types
			if callback_data.state_type == "action_started" then
				lf("traveller_ui", "Action started: " .. tostring(callback_data.state_data.action_type))
			elseif callback_data.state_type == "points_updated" then
				lf("traveller_ui", "Points updated: +" .. callback_data.state_data.points_added .. " (Total: " .. callback_data.state_data.total_points .. ")")
			elseif callback_data.state_type == "state_changed" then
				lf("traveller_ui", "State changed to: " .. callback_data.state_data.new_state)
			end
			
			-- Refresh UI after any state change
			if callback_data.player and callback_data.droid then
				local current_tab = callback_data.droid.current_tab or 3 -- Traveller tab
				minetest.show_formspec(callback_data.player:get_player_name(), "maidroid:gui", maidroid.get_formspec(callback_data.droid, callback_data.player, current_tab))
			end
		end
		
		if maidroid.register_traveller_ui_callback then
			maidroid.register_traveller_ui_callback(ui_callback)
			lf("traveller_tab", "Registered UI callback for traveller state updates")
		else
			lf("traveller_tab", "Warning: register_traveller_ui_callback not available")
		end
	else
		-- Ensure inventory exists and items are populated
		local traveller_inv = maidroid.traveller_inventories[self.traveller_inventory_id]
		if traveller_inv then
			-- Check if slots are empty and repopulate if needed
			local needs_population = false
			for i = 1, 3 do
				local stack = traveller_inv:get_stack("rewardable", i)
				if stack:is_empty() then
					needs_population = true
					break
				end
			end
			
			if needs_population then
			-- Repopulate empty slots using reward_items tracking
			for i, reward_item in ipairs(reward_items) do
				if i <= 3 then -- Only fill first 3 slots
					local stack = ItemStack(reward_item.name .. " 1") -- Add 1 item
					traveller_inv:set_stack("rewardable", i, stack)
					lf("traveller_tab", "Repopulated rewardable slot " .. i .. " to " .. reward_item.name .. " 1")
				end
			end
				lf("traveller_tab", "Repopulated empty rewardable slots")
			end
		end
	end
	
	local traveller_inv_id = self.traveller_inventory_id
	local traveller_inv = maidroid.traveller_inventories[traveller_inv_id]
	if traveller_inv then
		lf("traveller_tab", "Found traveller inventory")
		-- Debug: check what's actually in the inventory
		for i = 1, 3 do
			local stack = traveller_inv:get_stack("rewardable", i)
			lf("traveller_tab", "Rewardable slot " .. i .. ": " .. stack:get_name() .. " " .. stack:get_count())
		end
	else
		lf("traveller_tab", "ERROR: Could not find traveller inventory!")
	end
	
	return traveller_inv, traveller_inv_id
end

-- Generate the traveller form UI
local function generate_traveller_form(self, form, traveller_inv, traveller_inv_id)
	-- UI FORM GENERATION
	local enligthen_tool = function(droid)
		if not droid.selected_tool then
			return ""
		end

		for y, item in ipairs(droid:get_inventory():get_list("main")) do
			if item:get_name() == droid.selected_tool then
				local x = y % 8
				y = (y - x) / 8
				x = x + 2
				return "box[" .. x .. "," .. y .. ";0.8,0.875;#32a823]"
			end
		end
		return ""
	end
	
	form = form .. enligthen_tool(self)
		
	-- Rewardable section
	form = form
		.. "label[0.5,0;" .. S("Rewardable Items") .. "]"
		.. "list[detached:" .. traveller_inv_id .. ";rewardable;0.5,0.5;3,1;]"
		.. "listring[detached:".. traveller_inv_id .. ";rewardable]"
		.. "listring[current_player;main]"
		
	-- Reward choice section
	local current_reward = maidroid.get_traveller_selected_reward(self)
	local reward_display = string.format("Current: %s", current_reward:gsub("default:", ""):gsub("_", " "))
	
	form = form
		.. "label[0.5,2;" .. S("Reward Choice") .. "]"
		.. "list[detached:" .. traveller_inv_id .. ";reward_choice;0.5,2.5;1,1;]"
		.. "label[2,2.8;" .. minetest.colorize("#FFFF00", reward_display) .. "]"
		.. "listring[detached:".. traveller_inv_id .. ";reward_choice]"
		.. "listring[current_player;main]"
		
	-- Add traveller controls below the lists
	form = form
		.. "button[0.5,4;2.5,1;toggle_traveller;" .. S("Toggle Traveller") .. "]"
		.. "button[3.5,4;2.5,1;view_metrics;" .. S("View Metrics") .. "]"
		.. "label[0.5,5;" .. S("Current Task:") .. " "
		.. minetest.colorize("#ACEEAC", (self.action and self.action or S("Idle"))) .. "]"
		.. "label[3.5,5;" .. S("State:") .. " "
		.. minetest.colorize("#ACEEAC", (self.state and tostring(self.state) or S("Unknown"))) .. "]"
		.. "model[4,6;3,3;3d;character.b3d;"
		.. minetest.formspec_escape(self.textures[1])
		.. ";0,180;false;true;200,219;7.5]"
	
	return form
end

-- Handle traveller tab logic
function maidroid.handle_traveller_tab(self, form)
	-- Initialize traveller systems
	local traveller_inv, traveller_inv_id = handle_rewardable_logic(self)
	
	-- Generate UI form
	form = generate_traveller_form(self, form, traveller_inv, traveller_inv_id)
	return form
end

-- Export functions to maidroid namespace
maidroid.create_traveller_events = create_traveller_events
maidroid.handle_rewardable_logic = handle_rewardable_logic
maidroid.generate_traveller_form = generate_traveller_form

-- Utility function to get available reward slots
function maidroid.get_available_reward_slots()
	local available_slots = {}
	for i, reward_item in ipairs(reward_items) do
		if reward_item and reward_item.available then
			table.insert(available_slots, {
				slot = i,
				name = reward_item.name
			})
		end
	end
	return available_slots
end

-- Utility function to get current reward selection
function maidroid.get_current_reward_selection(droid)
	if not droid then
		return "default:gold_lump" -- Default fallback
	end
	return maidroid.get_traveller_selected_reward(droid)
end

-- Utility function to get reward item info by slot
function maidroid.get_reward_item_info(slot)
	return reward_items[slot]
end
