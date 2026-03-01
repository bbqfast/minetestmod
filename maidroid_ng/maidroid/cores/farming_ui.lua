-- Farming UI functions for maidroid mod
-- This file contains all farming tab related UI functions

local lf = maidroid.lf
local S = minetest.get_translator("maidroid")

lf("farming_ui", "Farming UI module loaded successfully!")

-- Function to get random animation frames
local function get_random_animation_frames()
	local animations = {
		maidroid.animation.STAND,
		maidroid.animation.SIT,
		maidroid.animation.LAY,
		maidroid.animation.WALK,
		maidroid.animation.MINE,
		maidroid.animation.WALK_MINE
	}
	
	local selected_anim = animations[math.random(#animations)]
	return selected_anim.x .. "," .. selected_anim.y
end

-- Create farming events for seed inventory
local function create_farming_events(self, inventory_name)
	self.farming_inventory_id = inventory_name
	local inventory = minetest.create_detached_inventory(self.farming_inventory_id, {
		on_put = function(_, listname)
			lf("DEBUG: create_farming_events:on_put", "*** ON_PUT CALLED *** for list: " .. tostring(listname))
		end,

		allow_put = function(inv, listname, index, stack, player)
			lf("DEBUG: create_farming_events:allow_put", "*** ALLOW_PUT CALLED *** by " .. player:get_player_name() .. " for list: " .. tostring(listname) .. ", item: " .. stack:get_name())
			
			-- Only allow putting seeds in seedable list
			if listname == "seedable" then
				local item_name = stack:get_name()
				-- Check if item is a seed using the global seed check function
				if maidroid.is_seed(item_name) then
					return stack:get_count()
				end
				return 0 -- Reject non-seed items
			end
			
			return 0
		end,

		on_take = function(_, listname, index, stack, player)
			lf("DEBUG: create_farming_events:on_take", "*** ON_TAKE CALLED *** for list: " .. tostring(listname) .. ", index: " .. tostring(index))
		end,

		allow_take = function(inv, listname, index, stack, player)
			lf("DEBUG: create_farming_events:allow_take", "*** ALLOW_TAKE CALLED *** by " .. player:get_player_name() .. " for list: " .. tostring(listname) .. ", item: " .. stack:get_name())
			return 99
		end,

		on_move = function(_, from_list, from_index, to_list, to_index, count, player)
			lf("DEBUG: create_farming_events:on_move", "*** ON_MOVE CALLED *** from " .. tostring(from_list) .. " to " .. tostring(to_list))
			
			-- Handle moving from seedable to seed_choice
			if from_list == "seedable" and to_list == "seed_choice" then
				lf("DEBUG: create_farming_events:farming_inventory", "*** ITEM MOVED FROM SEEDABLE TO SEED_CHOICE ***")
				
				-- Get the maidroid this inventory belongs to
				local droid = self
				lf("DEBUG: create_farming_events:farming_inventory", "*** DROID OBJECT ***: " .. tostring(droid))
				
				-- Update the selected seed based on the moved item
				local farming_inv = maidroid.farming_inventories[self.farming_inventory_id]
				if farming_inv then
					local moved_stack = farming_inv:get_stack(to_list, to_index)
					lf("DEBUG: create_farming_events:farming_inventory", "*** MOVED STACK ***: " .. tostring(moved_stack))
					if moved_stack and not moved_stack:is_empty() then
						local item_name = moved_stack:get_name()
						-- Set the selected seed for farming
						droid.selected_seed = item_name
						lf("DEBUG: create_farming_events:farming_inventory", "*** SELECTED SEED UPDATED TO ***: " .. item_name)
						lf("farming_ui", "Seed choice updated to: " .. item_name)
						
						-- Send confirmation to player
						if player and player:is_player() then
							minetest.chat_send_player(player:get_player_name(), "Seed selection updated to: " .. item_name)
						end
					else
						lf("DEBUG: create_farming_events:farming_inventory", "*** MOVED STACK IS EMPTY OR NIL ***")
					end
				else
					lf("DEBUG: create_farming_events:farming_inventory", "*** FARMING INVENTORY NOT FOUND ***")
				end
				
				-- Refresh the UI AFTER inventory operations are complete
				if player and player:is_player() then
					local current_tab = droid.current_tab or 4 -- Farming tab
					lf("DEBUG: create_farming_events:farming_inventory", "*** BEFORE UI REFRESH *** - current_tab: " .. tostring(droid.current_tab))
					minetest.show_formspec(player:get_player_name(), "maidroid:gui", maidroid.get_formspec(droid, player, current_tab))
					lf("DEBUG: create_farming_events:farming_inventory", "*** AFTER UI REFRESH *** - current_tab: " .. tostring(droid.current_tab))
				end
			-- Handle moving from seed_choice to seedable
			elseif from_list == "seed_choice" and to_list == "seedable" then
				lf("DEBUG: create_farming_events:farming_inventory", "*** ITEM MOVED FROM SEED_CHOICE TO SEEDABLE ***")
				
				-- Get the maidroid this inventory belongs to
				local droid = self
				
				-- Clear the selected seed when moving back
				droid.selected_seed = nil
				lf("DEBUG: create_farming_events:farming_inventory", "*** CLEARED SELECTED SEED ***")
				lf("farming_ui", "Seed selection cleared")
				
				-- Send confirmation to player
				if player and player:is_player() then
					minetest.chat_send_player(player:get_player_name(), "Seed selection cleared - reverted to auto-select")
				end
				
				-- Refresh the UI AFTER inventory operations are complete
				if player and player:is_player() then
					local current_tab = self.current_tab or 4 -- Farming tab
					minetest.show_formspec(player:get_player_name(), "maidroid:gui", maidroid.get_formspec(self, player, current_tab))
				end
			end
		end,

		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			lf("DEBUG: create_farming_events:allow_move", "*** ALLOW_MOVE CALLED *** by " .. player:get_player_name() .. " from " .. tostring(from_list) .. " to " .. tostring(to_list) .. ", count: " .. tostring(count))
			return count
		end,
	})

	inventory:set_size("seedable", 8) -- 8 slots for different seeds
	inventory:set_size("seed_choice", 1) -- 1 slot for seed selection

	return inventory
end

-- Handle seedable logic for farming
local function handle_seedable_logic(self)
	-- Create and update farming inventory
	if not self.farming_inventory_id then
		-- Use the new create_farming_events function
		local farming_inventory = create_farming_events(self, maidroid.generate_unique_manufacturing_id())
		maidroid.farming_inventories = maidroid.farming_inventories or {}
		maidroid.farming_inventories[self.farming_inventory_id] = farming_inventory
		lf("farming_tab", "Created farming inventory with ID: " .. self.farming_inventory_id)
		
		-- Initialize seed choice slot with selected seed if exists
		if self.selected_seed then
			local seed_stack = ItemStack(self.selected_seed .. " 1")
			farming_inventory:set_stack("seed_choice", 1, seed_stack)
			lf("farming_tab", "Set seed_choice slot to " .. self.selected_seed .. " 1")
		end
		
		-- Register UI callback for farming state updates
		local ui_callback = function(callback_data)
			lf("DEBUG farming_ui", "Received UI callback: " .. callback_data.state_type)
			-- Handle different state types
			if callback_data.state_type == "action_started" then
				lf("farming_ui", "Action started: " .. tostring(callback_data.state_data.action_type))
			elseif callback_data.state_type == "harvest_completed" then
				lf("farming_ui", "Harvest completed: " .. tostring(callback_data.state_data.crop_name))
			elseif callback_data.state_type == "state_changed" then
				lf("farming_ui", "State changed to: " .. callback_data.state_data.new_state)
			end
			
			-- Refresh UI after any state change
			if callback_data.player and callback_data.droid then
				-- Check if UI is currently active before refreshing
				local player_name = callback_data.player:get_player_name()
				
				-- Only refresh if the maidroid GUI is currently active (check maidroid_buf)
				if maidroid.maidroid_buf and maidroid.maidroid_buf[player_name] then
					local current_tab = callback_data.droid.current_tab or 4 -- Farming tab
					minetest.show_formspec(player_name, "maidroid:gui", maidroid.get_formspec(callback_data.droid, callback_data.player, current_tab))
					lf("DEBUG farming_ui", "Refreshed active UI for player: " .. player_name)
				else
					lf("DEBUG farming_ui", "UI not active for player: " .. player_name .. ", skipping refresh")
				end
			end
		end
		
		if maidroid.register_farming_ui_callback then
			maidroid.register_farming_ui_callback(ui_callback)
			lf("farming_tab", "Registered UI callback for farming state updates")
		else
			lf("farming_tab", "Warning: register_farming_ui_callback not available")
		end
	else
		-- Check if inventory needs to be recreated due to size change
		local farming_inv = maidroid.farming_inventories[self.farming_inventory_id]
		if farming_inv then
			local current_size = farming_inv:get_size("seedable")
			if current_size ~= 8 then
				lf("farming_tab", "Recreating inventory - size mismatch: current=" .. current_size .. ", expected=8")
				-- Remove old inventory
				maidroid.farming_inventories[self.farming_inventory_id] = nil
				-- Create new one
				local farming_inventory = create_farming_events(self, self.farming_inventory_id)
				maidroid.farming_inventories[self.farming_inventory_id] = farming_inventory
				lf("farming_tab", "Recreated farming inventory with correct size")
			end
		end
	end
	
	local farming_inv_id = self.farming_inventory_id
	local farming_inv = maidroid.farming_inventories[farming_inv_id]
	if farming_inv then
		lf("farming_tab", "Found farming inventory")
	else
		lf("farming_tab", "ERROR: Could not find farming inventory!")
	end
	
	return farming_inv, farming_inv_id
end

-- Generate the farming form UI
local function generate_farming_form(self, form, farming_inv, farming_inv_id)
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
		
	-- Seedable section
	form = form
		.. "label[0.5,0;" .. S("Available Seeds") .. "]"
		.. "list[detached:" .. farming_inv_id .. ";seedable;0.5,0.5;8,1;]"
		
	-- Seed choice section
	local current_seed = self.selected_seed or "Auto-select"
	local seed_display = string.format("Current: %s", current_seed:gsub("farming:seed_", ""):gsub(":", " "))
	
	form = form
		.. "label[0.5,1.7;" .. S("Seed Choice") .. "]"
		.. "list[detached:" .. farming_inv_id .. ";seed_choice;0.5,2.2;1,1;]"
		.. "label[2,2.5;" .. minetest.colorize("#FFFF00", seed_display) .. "]"
		.. "listring[detached:".. farming_inv_id .. ";seed_choice]"
		.. "listring[detached:".. farming_inv_id .. ";seedable]"
		.. "listring[detached:".. farming_inv_id .. ";seed_choice]"
		.. "listring[detached:".. farming_inv_id .. ";seedable]"
		.. "listring[current_player;main]"
		
	-- Add farming controls below the lists
	form = form
		.. "label[0.5,3.0;" .. S("Current Task:") .. " "
		.. minetest.colorize("#ACEEAC", (self.action and self.action or S("Idle"))) .. "]"
		.. "label[0.5,3.4;" .. S("State:") .. " "
		.. minetest.colorize("#ACEEAC", (self.state and tostring(self.state) or S("Unknown"))) .. "]"
	
	-- Add farming dimension section
	form = form
		.. "label[0.5,3.8;" .. S("Farming Dimension") .. "]"
		.. "field[0.5,4.3;1,0.8;farming_length;;" .. (self.farming_length or "5") .. "]"
		.. "label[1.6,4.2;" .. S("Length") .. "]"
		.. "field[2.5,4.3;1,0.8;farming_width;;" .. (self.farming_width or "5") .. "]"
		.. "label[3.6,4.2;" .. S("Width") .. "]"
		.. "button[4.5,4.0;1.5,0.8;set_farming_dim;" .. S("Set") .. "]"
	
	-- Add farming tools display
	local tools_list = {"hoe", "scythe", "water_bucket"}
	local y_pos = 5.0
	
	form = form .. "label[0.5," .. y_pos .. ";" .. S("Farming Tools:") .. "]"
	y_pos = y_pos + 0.5
	
	for _, tool_name in ipairs(tools_list) do
		local has_tool = "No"
		local inv = self:get_inventory()
		if inv then
			local main_list = inv:get_list("main") or {}
			for _, stack in ipairs(main_list) do
				if not stack:is_empty() and string.find(stack:get_name(), tool_name) then
					has_tool = "Yes"
					break
				end
			end
		end
		
		local color = has_tool == "Yes" and "#00FF00" or "#FF0000"
		form = form .. "label[0.5," .. y_pos .. ";" .. tool_name .. ": " .. minetest.colorize(color, has_tool) .. "]"
		y_pos = y_pos + 0.4
	end
	
	-- Add activation position display
	if self._activation_pos then
		form = form
			.. "label[0.5," .. y_pos .. ";" .. S("Home Position:") .. " "
			.. minetest.colorize("#87CEEB", minetest.pos_to_string(self._activation_pos)) .. "]"
		y_pos = y_pos + 0.4
	end
	
	-- Add 3D model with animation
	form = form
		.. "model[4,6;3,3;3d;character.b3d;"
		.. minetest.formspec_escape(self.textures[1])
		.. ";" .. math.random(-15,15) .. "," .. (180 + math.random(-45,45)) .. ";false;true;" .. get_random_animation_frames() .. ";7.5]"
	
	return form
end

-- Handle farming tab logic
function maidroid.handle_farming_tab(self, form)
	-- Initialize farming systems
	local farming_inv, farming_inv_id = handle_seedable_logic(self)
	
	-- Generate UI form
	form = generate_farming_form(self, form, farming_inv, farming_inv_id)
	return form
end

-- Export functions to maidroid namespace
maidroid.create_farming_events = create_farming_events
maidroid.handle_seedable_logic = handle_seedable_logic
maidroid.generate_farming_form = generate_farming_form

-- Utility function to get current seed selection
function maidroid.get_current_seed_selection(droid)
	if not droid then
		return nil -- No default for farming
	end
	return droid.selected_seed
end

-- Utility function to set seed selection
function maidroid.set_farming_selected_seed(droid, seed_name)
	if not droid then
		return false
	end
	if seed_name and maidroid.is_seed(seed_name) then
		droid.selected_seed = seed_name
		lf("farming_ui", "Set farming selected seed to: " .. seed_name)
		return true
	elseif not seed_name then
		droid.selected_seed = nil
		lf("farming_ui", "Cleared farming selected seed")
		return true
	end
	return false
end

-- Handle farming receive fields
function maidroid.handle_farming_receive_fields(droid, player, player_name, fields)
	if not (fields.set_farming_dim or (fields.farming_length and fields.key_enter_field == "farming_length") or (fields.farming_width and fields.key_enter_field == "farming_width")) then
		return false
	end
	
	local length = tonumber(fields.farming_length)
	local width = tonumber(fields.farming_width)
	

	lf("DEBUG api:register", "====================== function maidroid.set_farming_dimensions")
	-- Use the new set_farming_dimensions function
	local success = maidroid.set_farming_dimensions(droid, length, width)
	
	if success then
		minetest.chat_send_player(player_name, "Farming dimension set to " .. (length or droid.farming_length or 10) .. "x" .. (width or droid.farming_width or 10))
	else
		-- Show error messages for invalid values
		if length and (length <= 0 or length > 50) then
			minetest.chat_send_player(player_name, "Invalid length. Please enter a number between 1 and 50.")
		end
		if width and (width <= 0 or width > 50) then
			minetest.chat_send_player(player_name, "Invalid width. Please enter a number between 1 and 50.")
		end
	end
	
	lf("DEBUG api:register", "====================== function maidroid.set_farming_dimensions")
	-- Refresh the formspec to show updated values
	local current_tab = droid.current_tab or 4 -- Farming tab
	minetest.show_formspec(player_name, "maidroid:gui",
		maidroid.get_formspec(droid, player, current_tab))
	
	return true
end