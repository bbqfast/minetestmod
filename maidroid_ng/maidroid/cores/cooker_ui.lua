-- Cooker UI functions for maidroid mod
-- This file contains all cooker tab related UI functions

local S = minetest.get_translator("maidroid")

-- Helper function to handle tracking item positions for cookable list
function maidroid.handle_cookable(droid)
	lf("cooker_inventory", "Tracking cookable list item positions")
	
	if not droid then
		lf("cooker_inventory", "ERROR: Could not find maidroid for inventory " .. tostring(droid.crafting_inventory_id))
		return
	end
	
	-- Get all items from cookable list (current inventory state)
	-- local crafting_inv = maidroid.crafting_inventories[droid.crafting_inventory_id]
	local crafting_inv = maidroid.cooking_inventories[droid.cooking_inventory_id]
	local page_data = {} -- Store both items and empty positions
	
	for i = 1, 12 do -- cookable has 12 slots
		local stack = crafting_inv:get_stack("cookable", i)
		if not stack:is_empty() then
			page_data[i] = stack:get_name() -- Store item at its position
		else
			page_data[i] = nil -- Explicitly mark empty slot
		end
	end
	
	-- Get current page
	local current_page = (droid.cookable_page or 1)
	
	-- Initialize page items tracking if not exists
	if not droid.cookable_page_items then
		droid.cookable_page_items = {}
	end
	
	-- Store current page data with positions preserved
	droid.cookable_page_items[current_page] = page_data
	
	lf("cooker_inventory", "Updated cookable page data for page " .. current_page .. ": " .. dump(page_data))
end

-- Helper function to build complete desirable items list from all pages
function maidroid.build_complete_desirable_list(droid)
    -- lf("api:build_complete_desirable_list", "build_complete_desirable_list: " .. dump(droid))
	local all_desired_items = {}
	
	-- Build complete list from all pages
	if type(droid.desirable_page_items) == "table" then
		for page_num, page_items in pairs(droid.desirable_page_items) do
			for _, item in ipairs(page_items) do
				local already_exists = false
				for _, existing_item in ipairs(all_desired_items) do
					if existing_item == item then
						already_exists = true
						break
					end
				end
				if not already_exists then
					table.insert(all_desired_items, item)
				end
			end
		end
	end
	
    lf("api:build_complete_desirable_list", "all_desired_items: " .. dump(all_desired_items))
	return all_desired_items
end

-- Helper function to build complete cooklist items list from all pages
function maidroid.build_complete_cooklist_list(droid)
    -- lf("api:build_complete_cooklist_list", "build_complete_cooklist_list: " .. dump(droid))
	local all_cooklist_items = {}
	
	-- Build complete list from all pages
	if type(droid.cooklist_page_items) == "table" then
		for page_num, page_items in pairs(droid.cooklist_page_items) do
			for _, item in ipairs(page_items) do
				local already_exists = false
				for _, existing_item in ipairs(all_cooklist_items) do
					if existing_item == item then
						already_exists = true
						break
					end
				end
				if not already_exists then
					table.insert(all_cooklist_items, item)
				end
			end
		end
	end
	
    lf("api:build_complete_cooklist_list", "all_cooklist_items: " .. dump(all_cooklist_items))
	return all_cooklist_items
end

-- Create cooker events for cooking inventory
local function create_cooker_events(self, inventory_name)
	self.cooking_inventory_id = inventory_name
	local inventory = minetest.create_detached_inventory(self.cooking_inventory_id, {
		on_put = function(_, listname)
			lf("DEBUG: create_cooker_events:on_put", "*** ON_PUT CALLED *** for list: " .. tostring(listname))
		end,

		allow_put = function(inv, listname, index, stack, player)
			lf("DEBUG: create_cooker_events:allow_put", "*** ALLOW_PUT CALLED *** by " .. player:get_player_name() .. " for list: " .. tostring(listname) .. ", item: " .. stack:get_name())
			return 0
		end,

		on_take = function(_, listname)
			lf("DEBUG: create_cooker_events:on_take", "*** ON_TAKE CALLED *** for list: " .. tostring(listname))
		end,

		allow_take = function(inv, listname, index, stack, player)
			lf("DEBUG: create_cooker_events:allow_take", "*** ALLOW_TAKE CALLED *** by " .. player:get_player_name() .. " for list: " .. tostring(listname) .. ", item: " .. stack:get_name())
			return 99
		end,

		on_move = function(_, from_list, from_index, to_list, to_index, count, player)
			lf("DEBUG: create_cooker_events:on_move", "*** ON_MOVE CALLED *** from " .. tostring(from_list) .. " to " .. tostring(to_list))
			
			-- Handle moving from craftable to desirable
			if from_list == "cookable" and to_list == "cooklist" then
				lf("DEBUG: create_cooker_events:cooker_inventory", "*** ITEM MOVED FROM CRAFTABLE TO DESIRABLE *** - updating desired craft outputs")
				
				-- Get the maidroid this inventory belongs to
				local droid = self
				lf("DEBUG: create_cooker_events:cooker_inventory", "*** DROID OBJECT ***: " .. tostring(droid))
				
				-- Capture the moved item for recipe display
				local cooking_inv = maidroid.cooking_inventories[self.cooking_inventory_id]
				lf("DEBUG: create_cooker_events:cooker_inventory", "*** CRAFTING INVENTORY ID ***: " .. tostring(self.cooking_inventory_id))
				lf("DEBUG: create_cooker_events:cooker_inventory", "*** CRAFTING INVENTORY ***: " .. tostring(cooking_inv))
				
				if cooking_inv then
					local moved_stack = cooking_inv:get_stack(to_list, to_index)
					lf("DEBUG: create_cooker_events:cooker_inventory", "*** MOVED STACK ***: " .. tostring(moved_stack))
					if moved_stack and not moved_stack:is_empty() then
						local item_name = moved_stack:get_name()
						droid.selected_recipe_item = item_name
						lf("DEBUG: create_cooker_events:cooker_inventory", "*** SELECTED RECIPE ITEM ***: " .. item_name)
						lf("DEBUG: create_cooker_events:cooker_inventory", "*** DROID.SELECTED_RECIPE_ITEM SET TO ***: " .. tostring(droid.selected_recipe_item))
					else
						lf("DEBUG: create_cooker_events:cooker_inventory", "*** MOVED STACK IS EMPTY OR NIL ***")
					end
				else
					lf("DEBUG: create_cooker_events:cooker_inventory", "*** CRAFTING INVENTORY NOT FOUND ***")
				end
				
				maidroid.handle_change_cooklist(self)
				maidroid.handle_cookable(self)
				
				-- Refresh the UI AFTER inventory operations are complete
				if player and player:is_player() then
					local current_tab = droid.current_tab or 2
					lf("DEBUG: create_cooker_events:cooker_inventory", "*** BEFORE UI REFRESH *** - current_tab: " .. tostring(droid.current_tab))
					minetest.show_formspec(player:get_player_name(), "maidroid:gui", maidroid.get_formspec(droid, player, current_tab))
					lf("DEBUG: create_cooker_events:cooker_inventory", "*** AFTER UI REFRESH *** - current_tab: " .. tostring(droid.current_tab))
					lf("DEBUG: create_cooker_events:cooker_inventory", "*** UI REFRESHED FOR RECIPE DISPLAY ***")
				end
			-- Handle moving from desirable to craftable
			elseif from_list == "cooklist" and to_list == "cookable" then
				-- Clear the selected recipe item when moving back
				local droid = self
				droid.selected_recipe_item = nil
				lf("DEBUG: create_cooker_events:cooker_inventory", "*** CLEARED SELECTED RECIPE ITEM ***")
				
				maidroid.handle_change_cooklist(self)
				maidroid.handle_cookable(self)
            end
		end,

		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			lf("DEBUG: create_cooker_events:allow_move", "*** ALLOW_MOVE CALLED *** by " .. player:get_player_name() .. " from " .. tostring(from_list) .. " to " .. tostring(to_list) .. ", count: " .. tostring(count))
			return count
		end,
	})

	inventory:set_size("cookable", 12)
	inventory:set_size("cooklist", 6)

	return inventory
end

-- Handle craftable logic for generic_cooker
local function handle_craftable_logic(self)
	-- Create and update crafting inventory
	if not self.crafting_inventory_id then
		-- Use the new create_crafter_events function
		local crafting_inventory = maidroid.create_crafter_events(self, maidroid.generate_unique_manufacturing_id())
		maidroid.crafting_inventories[self.crafting_inventory_id] = crafting_inventory
		lf("cooker_tab", "Created crafting inventory with ID: " .. self.crafting_inventory_id)
	end
	
	local crafting_inv_id = self.crafting_inventory_id
	local crafting_inv = maidroid.crafting_inventories[crafting_inv_id]
	if crafting_inv then
		lf("cooker_tab", "Found crafting inventory, updating selection")
		if not self.desirable_page_items then
			maidroid.init_desirable_pageitems(self, self.desired_craft_outputs)
		end
	else
		lf("cooker_tab", "ERROR: Could not find crafting inventory!")
	end
	
	-- Shop-style layout for cooker with pagination
	-- Calculate current page and total pages for craftable items
	local craftable_outputs = {}
	craftable_outputs = maidroid.init_craftable_outputs
	-- Craftable pagination variables
	local craftable_total_pages, craftable_current_page = maidroid.calculate_pagination(self, #craftable_outputs, maidroid.CRAFTABLE_ITEMS_PER_PAGE, 1, "craftable_page")
	if not self.craftable_page_items then
		maidroid.init_craftable_pageitems(self, maidroid.init_craftable_outputs, self.desired_craft_outputs)
	end
	
	-- Get current craftable page items
	local craftable_page_items = maidroid.populate_current_page(self, craftable_current_page, maidroid.CRAFTABLE_ITEMS_PER_PAGE, #craftable_outputs, "craftable_page_items", "craftable")
	
	-- Update craftable inventory with current page items
	maidroid.populate_items_page(crafting_inv, self, craftable_page_items, "craftable", 12)
	
	return crafting_inv, crafting_inv_id
end

-- Handle desirable logic for generic_cooker
local function handle_desirable_logic(self, crafting_inv)
	-- Calculate desirable pagination (based on page items tracking)
	local desirable_outputs = {}
	
	-- Build complete list from all pages using helper function
	if type(self.desirable_page_items) == "table" then
		desirable_outputs = maidroid.build_complete_desirable_list(self)
	elseif type(self.desired_craft_outputs) == "table" then
		-- Fallback to regular desired outputs if page tracking not set
		desirable_outputs = self.desired_craft_outputs
	end
	
	-- If no desirable items, show empty
	if type(desirable_outputs) ~= "table" or #desirable_outputs == 0 then
		desirable_outputs = {}
	end
	
	local desirable_total_pages, desirable_current_page = maidroid.calculate_desirable_pagination(self, desirable_outputs, maidroid.DESIRABLE_ITEMS_PER_PAGE)
	
	-- Get current desirable page items (from actual desirable outputs)
	local desirable_page_items = maidroid.populate_current_page(self, desirable_current_page, maidroid.DESIRABLE_ITEMS_PER_PAGE, #desirable_outputs, "desirable_page_items", "desirable")
	
	-- Update desirable inventory with current page items
	maidroid.populate_items_page(crafting_inv, self, desirable_page_items, "desirable", 6)
	
	return desirable_outputs, desirable_total_pages, desirable_current_page
end

-- Handle cookable logic for generic_cooker
local function handle_cookable_logic(self)
	-- cooking_inventories - Copy of crafting inventory section
	if not self.cooking_inventory_id then
		-- Use the new create_crafter_events function
		local cooking_inventory = create_cooker_events(self, maidroid.generate_unique_manufacturing_id())
		maidroid.cooking_inventories[self.cooking_inventory_id] = cooking_inventory
		maidroid.populate_detached_inventory(cooking_inventory, self, maidroid.all_furnace_inputs, "cookable", 12)
		lf("cooker_tab", "Created cooking inventory with ID: " .. self.cooking_inventory_id)
	end
	
	local cooking_inv_id = self.cooking_inventory_id
	local cooking_inv = maidroid.cooking_inventories[cooking_inv_id]
	if cooking_inv then
		lf("cooker_tab", "Found cooking inventory, updating selection")
		if not self.cooklist_page_items then
			maidroid.init_cooklist_pageitems(self, maidroid.cookable_inputs)
		end
	else
		lf("cooker_tab", "ERROR: Could not find cooking inventory!")
	end
	
	maidroid.all_furnace_inputs = maidroid.cores.generic_cooker.get_cookable_items()
	if not self.cookable_page_items then
		-- Get cooklist items to exclude from cookable list
		local cooklist_items = maidroid.build_complete_cooklist_list(self)
		maidroid.init_cookable_pageitems(self, maidroid.all_furnace_inputs, cooklist_items)
	end

	local cookable_total_pages, cookable_current_page = maidroid.calculate_pagination(self, #maidroid.all_furnace_inputs, maidroid.CRAFTABLE_ITEMS_PER_PAGE, 1, "cookable_page")
	
	-- Get current cookable page items
	local cookable_page_items = maidroid.populate_current_page(self, cookable_current_page, maidroid.CRAFTABLE_ITEMS_PER_PAGE, #maidroid.all_furnace_inputs, "cookable_page_items", "cookable")
	lf("XXXXXXXXXXXXXXXXXXX api", "cookable_page_items=" .. dump(cookable_page_items))
	
	-- Update cookable inventory with current page items
	maidroid.populate_items_page(cooking_inv, self, cookable_page_items, "cookable", 12)
	
	return cooking_inv, cooking_inv_id
end

-- Handle cooklist logic for generic_cooker
local function handle_cooklist_logic(self, cooking_inv)
	-- Cooklist section (below cookables)
	-- Initialize cooklist page items if needed
	if not self.cooklist_page_items then
		local all_farming_outputs = {}
		if maidroid.cores and maidroid.cores.generic_cooker then
			local cooker_items = dofile(maidroid.modpath .. "/cores/cooker_items.lua")
			all_farming_outputs = cooker_items.all_farming_outputs or {}
		end
		maidroid.init_cooklist_pageitems(self, maidroid.cookable_inputs)
	end
	
	-- Calculate cooklist pagination variables
	local cooklist_data = {}
	if maidroid.cores and maidroid.cores.generic_cooker then
		local cooker_items = dofile(maidroid.modpath .. "/cores/cooker_items.lua")
		cooklist_data = cooker_items.all_farming_outputs or {}
	end
	
	local cooklist_total_pages, cooklist_current_page = maidroid.calculate_pagination(self, #cooklist_data, 6, 1, "cooklist_page")
	
	-- Get current cooklist page items
	local cooklist_page_items = maidroid.populate_current_page(self, cooklist_current_page, 6, #cooklist_data, "cooklist_page_items", "cooklist")
	
	-- Update cooklist inventory with current page items
	maidroid.populate_items_page(cooking_inv, self, cooklist_page_items, "cooklist", 6)
	
	return cooklist_total_pages, cooklist_current_page
end

-- Generate the cooker form UI
local function generate_cooker_form(self, form, crafting_inv, crafting_inv_id, cooking_inv, cooking_inv_id, 
									desirable_outputs, desirable_total_pages, desirable_current_page,
									cooklist_total_pages, cooklist_current_page)
	-- Calculate pagination for craftables
	local craftable_outputs = maidroid.init_craftable_outputs
	local craftable_total_pages, craftable_current_page = maidroid.calculate_pagination(self, #craftable_outputs, maidroid.CRAFTABLE_ITEMS_PER_PAGE, 1, "craftable_page")
	
	-- Calculate pagination for cookables
	maidroid.all_furnace_inputs = maidroid.cores.generic_cooker.get_cookable_items()
	local cookable_total_pages, cookable_current_page = maidroid.calculate_pagination(self, #maidroid.all_furnace_inputs, maidroid.CRAFTABLE_ITEMS_PER_PAGE, 1, "cookable_page")
	
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
		-- Left column - Craftables
		.. "label[0.5,0;" .. S("Craftables") .. "]"
		.. "label[2.5,0;" .. craftable_current_page .. "/" .. craftable_total_pages .. "]"
		.. "list[detached:" .. crafting_inv_id .. ";craftable;0.5,0.5;6,2;]"
		
	-- Add craftable pagination buttons on the right side if needed
	if craftable_total_pages > 1 then
		form = form
			.. "button[6.5,0.6;0.6,0.1;craftable_prev;<]"
			.. "button[6.5,1.4;0.6,0.1;craftable_next;>]"
	end
	
	-- Right column - Cookables (furnace inputs)
	form = form
		.. "label[7.5,0;" .. S("Cookables") .. "]"
		.. "label[9.5,0;" .. cookable_current_page .. "/" .. cookable_total_pages .. "]"
		.. "list[detached:" .. cooking_inv_id .. ";cookable;7.5,0.5;6,2;]"
		
	-- Add cookable pagination buttons on the far right if needed
	if cookable_total_pages > 1 then
		form = form
			.. "button[13.5,0.6;0.6,0.1;cookable_prev;<]"
			.. "button[13.5,1.4;0.6,0.1;cookable_next;>]"
	end
	
	-- Add cooklist UI below cookables
	form = form
		.. "label[7.5,2.8;" .. S("Cooking Results") .. "]"
		.. "button[10.5,2.65;1,0.5;reset_cooklist;" .. S("Reset") .. "]"
		.. "label[11.8,2.8;" .. cooklist_current_page .. "/" .. cooklist_total_pages .. "]"
		.. "list[detached:" .. cooking_inv_id .. ";cooklist;7.5,3.15;6,1;]"
		
	-- Add cooklist pagination buttons on the far right (always show for navigation)
	form = form
		.. "button[13.5,3.15;0.6,0.1;cooklist_prev;<]"
		.. "button[13.5,3.65;0.6,0.1;cooklist_next;>]"
	
	-- Desirable section
	form = form
		.. "label[0.5,2.8;" .. S("Desirable Craft") .. "]"
		.. "button[3.5,2.65;1,0.5;reset_desirable;" .. S("Reset") .. "]"
		.. "label[4.8,2.8;" .. desirable_current_page .. "/" .. desirable_total_pages .. "]"
		.. "list[detached:" .. crafting_inv_id .. ";desirable;0.5,3.55;6,1;]"
		.. "listring[detached:".. crafting_inv_id .. ";craftable]"
		.. "listring[detached:".. crafting_inv_id .. ";desirable]"
		.. "listring[detached:".. crafting_inv_id .. ";craftable]"
		.. "listring[detached:".. cooking_inv_id .. ";cookable]"
		.. "listring[detached:".. cooking_inv_id .. ";cooklist]"
		.. "listring[detached:".. cooking_inv_id .. ";cookable]"
		
	-- Add desirable pagination buttons on the right side (always show for navigation)
	form = form
		.. "button[6.5,3.65;0.6,0.1;desirable_prev;<]"
		.. "button[6.5,4.15;0.6,0.1;desirable_next;>]"
	
	-- Add recipe display area below desirable section
	local recipe_display = ""
	lf("cooker_ui", "Checking for recipe display, selected_recipe_item: " .. tostring(self.selected_recipe_item))
	if self.selected_recipe_item then
		lf("cooker_ui", "Calling format_recipe_display for: " .. self.selected_recipe_item)
		recipe_display = maidroid.format_recipe_display(self.selected_recipe_item)
	else
		lf("cooker_ui", "No selected recipe item found")
	end
	
	form = form
		.. "label[0.5,4.4;" .. S("Recipe") .. "]"
		.. "box[0.5,4.6;8,1.8;#000000]"
		.. recipe_display
		.. "model[9,4.6;3,3;3d;character.b3d;"
		.. minetest.formspec_escape(self.textures[1])
		.. ";0,180;false;true;200,219;7.5]"
	
	-- Add cooker controls below the lists
	form = form
		.. "button[0.5,7.5;2.5,1;toggle_cooker;" .. S("Toggle Cooker") .. "]"
		.. "button[3.5,7.5;2.5,1;view_metrics;" .. S("View Metrics") .. "]"
		.. "label[0.5,8.5;" .. S("Current Task:") .. " "
		.. minetest.colorize("#ACEEAC", (self.action and self.action or S("Idle"))) .. "]"
		.. "label[3.5,8.5;" .. S("State:") .. " "
		.. minetest.colorize("#ACEEAC", (self.state and tostring(self.state) or S("Unknown"))) .. "]"
	
	return form
end

--- Reset cooklist inventory and reinitialize cookable list
function maidroid.reset_cooklist_and_cookable(droid)
	lf("cooker_inventory", "Resetting cooklist and reinitializing cookable")
	
	-- Clear cooklist inventory
	local cooking_inv = maidroid.cooking_inventories[droid.cooking_inventory_id]
	if cooking_inv then
		for i = 1, 6 do -- cooklist has 6 slots
			cooking_inv:set_stack("cooklist", i, "")
		end
		lf("cooker_inventory", "Cleared all cooklist slots")
	end
	
	-- Clear cooklist tracking data
	droid.cooklist_page_items = {}
	droid.cooklist = {}
	droid.cooklist_page = 1
	
	-- Reinitialize cookable list
	maidroid.all_furnace_inputs = maidroid.cores.generic_cooker.get_cookable_items()
	maidroid.init_cookable_pageitems(droid, maidroid.all_furnace_inputs, {})
	droid.cookable_page = 1
	
	lf("cooker_inventory", "Cooklist reset complete")
end

--- Reset desirable inventory and reinitialize craftable list
function maidroid.reset_desirable_and_craftable(droid)
	lf("cooker_inventory", "Resetting desirable and reinitializing craftable")
	
	-- Clear desirable inventory
	local crafting_inv = maidroid.crafting_inventories[droid.crafting_inventory_id]
	if crafting_inv then
		for i = 1, 6 do -- desirable has 6 slots
			crafting_inv:set_stack("desirable", i, "")
		end
		lf("cooker_inventory", "Cleared all desirable slots")
	end
	
	-- Clear desirable tracking data
	droid.desirable_page_items = {}
	droid.desired_craft_outputs = {}
	droid.desirable_page = 1
	droid.selected_recipe_item = nil
	
	-- Reinitialize craftable list
    maidroid.init_craftable_pageitems(droid, maidroid.init_craftable_outputs, {})
	droid.craftable_page = 1
	
	lf("cooker_inventory", "Reset complete")
end

-- Handle generic_cooker tab logic
function maidroid.handle_generic_cooker_tab(self, form)
	-- Initialize all cooker systems
	local crafting_inv, crafting_inv_id = handle_craftable_logic(self)
	local cooking_inv, cooking_inv_id = handle_cookable_logic(self)
	local desirable_outputs, desirable_total_pages, desirable_current_page = handle_desirable_logic(self, crafting_inv)
	local cooklist_total_pages, cooklist_current_page = handle_cooklist_logic(self, cooking_inv)
	
	-- Generate UI form
	form = generate_cooker_form(self, form, crafting_inv, crafting_inv_id, cooking_inv, cooking_inv_id, 
							   desirable_outputs, desirable_total_pages, desirable_current_page,
							   cooklist_total_pages, cooklist_current_page)
	return form
end

-- Export functions to maidroid namespace
maidroid.create_cooker_events = create_cooker_events
maidroid.handle_craftable_logic = handle_craftable_logic
maidroid.handle_desirable_logic = handle_desirable_logic
maidroid.handle_cookable_logic = handle_cookable_logic
maidroid.handle_cooklist_logic = handle_cooklist_logic
maidroid.generate_cooker_form = generate_cooker_form