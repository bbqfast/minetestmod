------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator
local mods = maidroid.mods
local lf = maidroid.lf
lf("api", "*************************  maidroid API")

-- Default craftable outputs for generic_cooker
-- local init_craftable_outputs = {
-- 	"farming:rhubarb_pie",
-- 	"farming:bread_slice", 
-- 	"farming:flour",
-- }
local init_craftable_outputs = {
    "farming:flour", "farming:flour_multigrain", "farming:bread_slice", "farming:toast_sandwich", "farming:garlic_clove", "farming:garlic", "farming:popcorn", "farming:cornstarch",
    "farming:bottle_ethanol", "farming:coffee_cup", "farming:chocolate_dark", "farming:chocolate_block", "farming:chili_powder", "farming:chili_bowl", "farming:carrot_juice", "farming:blueberry_pie", "farming:muffin_blueberry", "farming:tomato_soup",
    "farming:glass_water", "farming:sugar_cube", "farming:salt", "farming:salt_crystal", "farming:mayonnaise", "farming:rose_water", "farming:turkish_delight", "farming:garlic_bread", "farming:donut", "farming:donut_chocolate",
    "farming:donut_apple", "farming:porridge", "farming:jaffa_cake", "farming:apple_pie", "farming:cactus_juice", "farming:pasta", "farming:mac_and_cheese", "farming:spaghetti", "farming:bibimbap", "farming:burger", "farming:salad", "farming:smoothie_berry",
    "farming:spanish_potatoes", "farming:potato_omelet", "farming:paella", "farming:flan", "farming:cheese_vegan", "farming:butter_vegan", "farming:onigiri", "farming:gyoza", "farming:mochi", "farming:gingerbread_man", "farming:mint_tea", "farming:onion_soup",
    "farming:pea_soup", "farming:pepper_ground", "farming:pineapple_ring", "farming:pineapple_juice", "farming:potato_salad", "farming:melon", "farming:melon_slice", "farming:pumpkin", "farming:pumpkin_slice", "farming:pumpkin_dough",
    "farming:smoothie_raspberry", "farming:rhubarb_pie", "farming:rice_flour", "farming:soy_sauce", "farming:soy_milk", "farming:tofu", "farming:vanilla_extract", "farming:jerusalem_artichokes",
    "farming:cookie", "farming:carrot_gold", "farming:beetroot_soup", "farming:sunflower_oil", "farming:sunflower_bread", "farming:bowl"
}

-- Track spawned maidroid names to prevent duplicates
local spawned_maidroid_names = {}
local total_maidroids_spawned = 0
local MAX_MAIDROIDS_ALLOWED = 3

local all_maidroid_metrics = {}
all_maidroid_metrics.total_activated = 0
all_maidroid_metrics.total_deactivated = 0

local maidroid_metrics_log_timer = 0
local maidroid_metrics_log_interval = 30

minetest.register_globalstep(function(dtime)
	maidroid_metrics_log_timer = maidroid_metrics_log_timer + (dtime or 0)
	if maidroid_metrics_log_timer < maidroid_metrics_log_interval then
		return
	end
	maidroid_metrics_log_timer = 0
	lf("GLOBAL_STATS", "maidroid_metrics: activated=" .. tostring(all_maidroid_metrics.total_activated) .. " deactivated=" .. tostring(all_maidroid_metrics.total_deactivated))
	lf("GLOBAL_STATS", "spawned_maidroid_names: " .. dump(spawned_maidroid_names))
    
end)

local mydump = function(func, msg, obj)
    -- uncommon to incrase verbose
	-- lf(func, msg..dump(obj))
end

-- animation frame data of "models/maidroid.b3d".
maidroid.animation = {
	STAND     = {x =   1, y =  78},
	SIT       = {x =  81, y =  81},
	LAY       = {x = 162, y = 165},
	WALK      = {x = 168, y = 187},
	MINE      = {x = 189, y = 198},
	WALK_MINE = {x = 200, y = 219},
}


local maid_skins = {
    "character_Mary_LT_mt.png^[invert:r",
    "character_Dave_Lt_mt.png^[invert:r",
    "character_Dave_Lt_mt.png^[invert:g",
    "character_Dave_Lt_mt.png^[invert:b",
    "character_Mary_LT_mt.png^[invert:g",
    "character_Mary_LT_mt.png^[invert:b",
    -- Add more skin filenames here
}

-- animation = {
-- 	speed_normal = 30,
-- 	speed_run = 30,
-- 	stand_start = 0,
-- 	stand_end = 79,
-- 	walk_start = 168,
-- 	walk_end = 187,
-- 	run_start = 168,
-- 	run_end = 187,
-- 	punch_start = 189,
-- 	punch_end = 198,
-- },

-- all known maidroid states
maidroid.states = {}

-- local functions
local random_pos_near = maidroid.helpers.random_pos_near
local get_formspec, get_tube

local maidroid_buf = {} -- formspec buffer

-- states counter and function to register a new states
maidroid.states_count = 0
maidroid.new_state = function(string)
	if not maidroid.states[string] then
		maidroid.states_count = maidroid.states_count + 1
		maidroid.states[string] = maidroid.states_count
	end
end

-- registered maidroids list in case of import mode
maidroid.registered_maidroids = {}

-- list of cores registered by maidroid.register_core
maidroid.cores = {}

local farming_redo = farming and farming.mod and farming.mod == "redo"

-- Crafting inventory system for drag and drop (based on trader.lua)
maidroid.crafting_inventories = {}

function maidroid.crafting_allow_put(inv, listname, index, stack, player)
	-- Don't allow putting items directly into any list
	return 0
end

function maidroid.crafting_allow_take(inv, listname, index, stack, player)
	lf("crafting_allow_take", "Player " .. player:get_player_name() .. " is attempting to take items from " .. listname)
	-- Allow taking from desirable (to remove items) and craftable (though craftable should be refilled)
	if listname == "desirable" or listname == "craftable" then
		return 99
	else
		return 0
	end
end

function maidroid.crafting_on_move(inventory, from_list, from_index, to_list, to_index, count, player)
	lf("crafting_on_move", "Player " .. player:get_player_name() .. " is moving items from " .. from_list .. " to " .. to_list)
	if from_list == "craftable" and to_list == "desirable" then
		local inv = inventory
		local moved = inv:get_stack(from_list, from_index)  -- Check source stack before move
		local itemname = moved:get_name()
		
		-- Check if item already exists in desirable before allowing the move
		local player_name = player:get_player_name()
		local droid = maidroid.get_maidroid_by_player(player_name)
		local already_exists = false
		
		if droid and type(droid.desired_craft_outputs) == "table" then
			for _, v in ipairs(droid.desired_craft_outputs) do
				if v == itemname then
					already_exists = true
					break
				end
			end
		end
		
		-- Prevent the move if item already exists in desirable
		if already_exists then
			lf("crafting_on_move", "Prevented move: " .. itemname .. " already exists in desirable")
			return
		end
		
		local elements = moved:get_count()
		
		if elements > count then
			-- Split stack if needed
			inv:set_stack("desirable", to_index, itemname .. " " .. tostring(count))
			inv:set_stack("craftable", from_index, itemname .. " " .. tostring(elements - count))
		end
		
		-- Update the maidroid's desired_craft_outputs
		if droid then
			if type(droid.desired_craft_outputs) ~= "table" then
				droid.desired_craft_outputs = {}
			end
			
			-- Add item (we already know it doesn't exist)
			table.insert(droid.desired_craft_outputs, itemname)
			local max_selected = 6  -- Updated to match 6x1 grid
			while #droid.desired_craft_outputs > max_selected do
				table.remove(droid.desired_craft_outputs, 1)
			end
			
			-- Update the desired craft outputs
			if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.set_desired_craft_outputs then
				maidroid.cores.generic_cooker.set_desired_craft_outputs(droid, droid.desired_craft_outputs)
			end
		end
		
	elseif from_list == "desirable" and to_list == "craftable" then
		local inv = inventory
		local moved = inv:get_stack(to_list, to_index)
		local itemname = moved:get_name()
		local elements = moved:get_count()
		
		if elements > count then
			-- Split stack if needed
			inv:set_stack("craftable", to_index, itemname .. " " .. tostring(count))
			inv:set_stack("desirable", from_index, itemname .. " " .. tostring(elements - count))
		end
		
		-- Update the maidroid's desired_craft_outputs (remove the item)
		local player_name = player:get_player_name()
		local droid = maidroid.get_maidroid_by_player(player_name)
		if droid and type(droid.desired_craft_outputs) == "table" then
			-- Remove item from selection
			for i, v in ipairs(droid.desired_craft_outputs) do
				if v == itemname then
					table.remove(droid.desired_craft_outputs, i)
					break
				end
			end
			
			-- Update the desired craft outputs
			if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.set_desired_craft_outputs then
				maidroid.cores.generic_cooker.set_desired_craft_outputs(droid, droid.desired_craft_outputs)
			end
		end
	end
end

function maidroid.populate_desirable_items_page(inv, droid, page_items)
	-- Clear desirable inventory first
	inv:set_list("desirable", {})
	
	-- Fill desirable inventory with current page items, preserving positions
	for i = 1, 6 do -- desirable has 6 slots
		local spec = page_items[i]
		if type(spec) == "string" and spec ~= "" then
            lf("api:populate_desirable_items_page", "Setting slot " .. i .. " to: " .. tostring(spec))
			inv:set_stack("desirable", i, spec)
		else
            lf("api:populate_desirable_items_page", "Leaving slot " .. i .. " empty")
		end
	end
end

function maidroid.populate_craftable_items_page(inv, droid, page_items)
	-- Clear craftable inventory first
	inv:set_list("craftable", {})
	
	-- Fill craftable inventory with current page items
	for i, spec in ipairs(page_items) do
		if type(spec) == "string" and spec ~= "" then
            lf("api:populate_craftable_items_page", "populate_craftable_items_page: " .. tostring(spec))
			inv:set_stack("craftable", i, spec)
		end
	end
end

-- Function to convert craftable outputs array to a sparse array
-- Takes the output from maidroid.cores.generic_cooker.get_craftable_outputs()
-- and returns a sparse array where indices represent item positions
function maidroid.convert_craftable_outputs_to_sparse_array(craftable_outputs)
    lf("api:convert_craftable_outputs_to_sparse_array", "convert_craftable_outputs_to_sparse_array: " .. dump(craftable_outputs))
	if type(craftable_outputs) ~= "table" then
        lf("api:convert_craftable_outputs_to_sparse_array", "convert_craftable_outputs_to_sparse_array: " .. tostring(craftable_outputs))
		return {}
	end
	
	local sparse_array = {}
	
	-- Convert each item string to a sparse array entry
	for i, item_spec in ipairs(craftable_outputs) do
        lf("api:convert_craftable_outputs_to_sparse_array", "convert_craftable_outputs_to_sparse_array: " .. tostring(item_spec))
		if type(item_spec) == "string" and item_spec ~= "" then
            lf("api:convert_craftable_outputs_to_sparse_array", "convert_craftable_outputs_to_sparse_array: " .. tostring(item_spec))
			-- Use the original index as the key in the sparse array
			-- This preserves the original ordering while creating a sparse structure
			sparse_array[i] = item_spec
		end
	end
	
	return sparse_array
end

-- ,,x2
-- Convenience function that gets craftable outputs and converts to sparse array
-- This is a wrapper that combines get_craftable_outputs() and convert_craftable_outputs_to_sparse_array()
function maidroid.get_craftable_outputs_as_sparse_array()
	local craftable_outputs = {}
	-- if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.get_craftable_outputs then
	-- 	craftable_outputs = maidroid.cores.generic_cooker.get_craftable_outputs() or {}
    --     lf("api:get_craftable_outputs_as_sparse_array", "get_craftable_outputs_as_sparse_array: " .. dump(craftable_outputs))
    -- else
    --     error("maidroid.cores.generic_cooker.get_craftable_outputs is not a function")
    -- end
	
	return maidroid.convert_craftable_outputs_to_sparse_array(init_craftable_outputs)
end

function maidroid.populate_craftable_items(inv, droid, craftable_outputs)
	-- Get craftable outputs from generic_cooker
	-- local craftable_outputs = {}
	-- if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.get_craftable_outputs then
	-- 	craftable_outputs = maidroid.cores.generic_cooker.get_craftable_outputs() or {}
	-- end
	
	-- -- Fallback to default items if no outputs found
	-- if type(craftable_outputs) ~= "table" or #craftable_outputs == 0 then
	-- 	craftable_outputs = init_craftable_outputs
	-- end
	
	-- Fill craftable inventory
	for i = 1, math.min(#craftable_outputs, 12) do -- 6x2 = 12 slots max
		local spec = craftable_outputs[i]
		if type(spec) == "string" and spec ~= "" then
            lf("api:populate_craftable_items", "populate_craftable_items: " .. tostring(spec))
			inv:set_stack("craftable", i, spec)
		end
	end
end

-- ,,
function maidroid.update_selection_inventory(inv, droid)
	-- Clear desirable inventory
	inv:set_list("desirable", {})
	-- Calculate desirable pagination (based on page items tracking)
	local desirable_outputs = {}
	
	-- Build complete list from all pages

    lf("api:update_selection_inventory", "update_selection_inventory: type" .. type(droid.desirable_page_items))
	if type(droid.desirable_page_items) == "table" then
        lf("api:update_selection_inventory1", "update_selection_inventory: desirable_page_items: " .. dump(droid.desirable_page_items))
		for page_num, page_items in pairs(droid.desirable_page_items) do
			for _, item in ipairs(page_items) do
				local already_exists = false
				for _, existing_item in ipairs(desirable_outputs) do
					if existing_item == item then
						already_exists = true
						break
					end
				end
				if not already_exists then
					table.insert(desirable_outputs, item)
				end
			end
		end
	elseif type(droid.desired_craft_outputs) == "table" then
        lf("api:update_selection_inventory2", "update_selection_inventory: desired_craft_outputs: " .. dump(droid.desired_craft_outputs))
		-- Fallback to regular desired outputs if page tracking not set
		desirable_outputs = droid.desired_craft_outputs
	end
	
	-- Populate desirable list (max 6 for 6x1 grid)
	for i, itemname in ipairs(desirable_outputs) do
		if i <= 6 and type(itemname) == "string" and itemname ~= "" then
			inv:set_stack("desirable", i, itemname)
		end
	end
	
	lf("update_selection_inventory", "Populated desirable with: " .. dump(desired_items))
    lf("api:update_selection_inventory", "update_selection_inventory: " .. dump(inv))
    -- error("test")

end

-- ,,c2d
-- Helper function to handle moving items between craftable and desirable lists
function maidroid.handle_craftable_to_desirable_move(droid)
	lf("cooker_inventory", "Item moved from craftable to desirable, updating desired craft outputs")
	
	if not droid then
		lf("cooker_inventory", "ERROR: Could not find maidroid for inventory " .. tostring(droid.crafting_inventory_id))
		return
	end
	
	-- Get all items from desirable list (current inventory state)
	local crafting_inv = maidroid.crafting_inventories[droid.crafting_inventory_id]
	local page_data = {} -- Store both items and empty positions
	
	for i = 1, 6 do -- desirable has 6 slots
		local stack = crafting_inv:get_stack("desirable", i)
		if not stack:is_empty() then
			page_data[i] = stack:get_name() -- Store item at its position
		else
			page_data[i] = nil -- Explicitly mark empty slot
		end
	end
	
	-- Get current page
	local current_page = (droid.desirable_page or 1)
	
	-- Initialize page items tracking if not exists
	if not droid.desirable_page_items then
		droid.desirable_page_items = {}
	end
	
	-- Store current page data with positions preserved
	droid.desirable_page_items[current_page] = page_data
	
	-- Build complete list from all pages using helper function
	local all_desired_items = maidroid.build_complete_desirable_list(droid)
	
	-- Update generic_cooker's desired craft outputs
	if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.set_desired_craft_outputs then
		maidroid.cores.generic_cooker.set_desired_craft_outputs(droid, all_desired_items)
	else
		droid.desired_craft_outputs = all_desired_items
	end
	
	lf("cooker_inventory", "Updated desired craft outputs: " .. dump(all_desired_items))
end

-- Helper function to handle moving items from desirable to craftable list
function maidroid.handle_change_desirable(droid)
	lf("cooker_inventory", "Item moved from desirable to craftable, updating desired craft outputs")
	
	if not droid then
		lf("cooker_inventory", "ERROR: Could not find maidroid for inventory " .. tostring(droid.crafting_inventory_id))
		return
	end
	
	-- Get all items from desirable list (current inventory state)
	local crafting_inv = maidroid.crafting_inventories[droid.crafting_inventory_id]
	local page_data = {} -- Store both items and empty positions
	
	for i = 1, 6 do -- desirable has 6 slots
		local stack = crafting_inv:get_stack("desirable", i)
		if not stack:is_empty() then
			page_data[i] = stack:get_name() -- Store item at its position
		else
			page_data[i] = nil -- Explicitly mark empty slot
		end
	end
	
	-- Get current page
	local current_page = (droid.desirable_page or 1)
	
	-- Initialize page items tracking if not exists
	if not droid.desirable_page_items then
		droid.desirable_page_items = {}
	end
	
	-- Store current page data with positions preserved
	droid.desirable_page_items[current_page] = page_data
	
	-- Build complete list from all pages using helper function
	local all_desired_items = maidroid.build_complete_desirable_list(droid)
	
	-- Update generic_cooker's desired craft outputs
	if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.set_desired_craft_outputs then
		maidroid.cores.generic_cooker.set_desired_craft_outputs(droid, all_desired_items)
	else
		droid.desired_craft_outputs = all_desired_items
	end
	
	lf("cooker_inventory", "Updated desired craft outputs: " .. dump(all_desired_items))
end

-- Helper function to build complete desirable items list from all pages
-- ,,desire
function maidroid.build_complete_desirable_list(droid)
    lf("api:build_complete_desirable_list", "build_complete_desirable_list: " .. dump(droid))
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
	
	return all_desired_items
end

function maidroid.get_maidroid_by_player(player_name)
	if maidroid_buf[player_name] and maidroid_buf[player_name].self then
		return maidroid_buf[player_name].self
	end
	return nil
end
local control_item = "default:paper"
if farming_redo then
	control_item = "farming:sugar"
end

local tool_rotation = {} -- tool rotation offsets: itemname => vector

-- maidroid.is_maidroid reports whether a name is maidroid's name.
function maidroid.is_maidroid(name)
	return maidroid.registered_maidroids[name] == true
end

function maidroid.strong_change_direction(self)
	strong_change_direction(self)
end

function maidroid.update_infotext(self)
	update_infotext(self)
end

---------------------------------------------------------------------

-- get_inventory returns a inventory of a maidroid.
local get_inventory = function(self)
	return minetest.get_inventory {
		type = "detached",
		name = self.inventory_name,
	}
end

get_tube = function(channel)
	for _, tube in pairs(pipeworks.tptube.get_db()) do
		if tube.channel == channel then
			return tube
		end
	end
end

local set_tube = function(self, tbchannel)
	if tbchannel == self.tbchannel
		or not mods.pipeworks then
		return
	end -- Nothing to do

	if tbchannel == "" then
		self.tbchannel = ""
		return true
	end -- Reset tube channel

	if tbchannel:sub(1,#self.owner+1) == self.owner .. ";" then
		tbchannel = tbchannel:sub(#self.owner+2)
	end

	if get_tube(self.owner .. ";" .. tbchannel) then
		self.tbchannel = tbchannel
		return true
	end

	minetest.chat_send_player(self.owner, S("There is no known teleport tube named: ") .. self.owner .. ";" .. tbchannel)
end

-- select_tool_for_core: iterate through inventory stacks
-- each core implementing is_tool may get selected if the stack item matches
-- First matching "tool" will be used
local select_tool_for_core = function(self)
	local stacks = self:get_inventory():get_list("main")

	for idx, stack in ipairs(stacks) do
		for corename, l_core in pairs(maidroid.cores) do
			if l_core.is_tool and l_core.is_tool(stack) then
				self:set_tool(l_core.default_item or stack:get_name())
				self.selected_tool = stack:get_name()
				self.selected_idx = idx
				return corename
			end
		end
	end

	self:set_tool("maidroid:hand")
	self.selected_tool = nil
	self.selected_idx = 0
	return "basic"
end

-- select_core returns a maidroid's current core definition.
local select_core = function(self)
	local old_idx = self.selected_idx
	local name = select_tool_for_core(self)
	if not self.core or self.core.name ~= name or name == "ocr" then
		if self.core then -- used only when maidroid activated
			self.core.on_stop(self)
		end
		self.core = maidroid.cores[name]
		self.core.on_start(self)
		if self.pause then
			self.core.on_pause(self)
		end
		self:update_infotext()

		if self.hat then -- remove old core hat
			self.hat:remove()
		end
		if self.core.hat then -- wear new core hat
			local pos = self:get_pos()
			if pos then
				self.hat = minetest.add_entity(pos, self.core.hat.name)
				self.hat:set_attach(self.object, "Head", self.core.hat.offset, self.core.hat.rotation)
			else
				lf("api", "maidroid: cannot add hat entity - maidroid position is nil")
			end
		end
	end

	-- update formspec when opened
	if old_idx ~= self.selected_idx and maidroid_buf[self.owner] and
		maidroid_buf[self.owner].self == self then
		minetest.show_formspec(
			self.owner,
			"maidroid:gui",
			get_formspec(self, minetest.get_player_by_name(self.owner), self.current_tab)
		)
	end
end

-- set_tool set wield tool image and attach.
local group_rotation = {}
-- group_rotation.hoe    = vector.new(-75, 45, -45)
-- group_rotation.hoe    = vector.new(-75, 45, -45)
group_rotation.hoe    = vector.new(-75, -90, 90)
group_rotation.shovel = group_rotation.hoe
group_rotation.sword  = group_rotation.hoe
if maidroid.mods.sickles then
	group_rotation.scythes = group_rotation.hoe
end

-- ,,tool
local set_tool = function(self, name)
	local p = vector.new(0.375, 3.5, -1.75)
	local r = vector.new(-75, 0, 90)

    -- lf("maidroid", "tool_rotation: " .. dump(tool_rotation))

    -- lf("maidroid", "------------------------------------------- set_tool: " .. name)
	if tool_rotation[name] then
		r = tool_rotation[name]
        -- lf("maidroid", "------------------------------------------- tool_rotation: " .. name.." "..minetest.pos_to_string(r))
	else
		for group, rotation in pairs(group_rotation) do
			if minetest.get_item_group(name, group) > 0 then
				r = rotation
				break
			end
		end
	end

    -- local r = vector.new(-45, -90, 90)
    -- local r = vector.new(-75, -90, 90)
    -- local p = vector.new(0.375, 3.5, -1.75)
    local p = vector.new(0.375, 3.5, 1.5)
    -- local r = vector.new(180, 180, 180)

    lf("maidroid", "------------------------------------------- set_tool position: " .. minetest.pos_to_string(p) .. " rotation: " .. minetest.pos_to_string(r))
    
    
	self.wield_item:set_properties({ wield_item = name })
	-- self.wield_item:set_attach(self.object, "Arm_R", p, r)
	self.wield_item:set_attach(self.object, "Arm_Left", p, r)
end

-- get_pos get the position of maidroid object
local get_pos = function(self)
	return self.object:get_pos()
end

-- is_on_ground return true if maidroid touches floor
local is_on_ground = function(self, moveresult)
	if moveresult then
		return moveresult.touching_ground
	end
	local under = minetest.get_node(vector.add(self:get_pos(),vector.new(0,-0.8,0)))
	return maidroid.helpers.is_walkable(under.name)
end

local round_direction = function(value)
	if value >= 0.5 then
		return 1
	elseif value <= -0.5 then
		return -1
	end
	return 0
end

-- returns a position in front of the maidroid.
local get_front = function(self)
	local direction = self:get_look_direction()
	direction.x = round_direction(direction.x)
	direction.z = round_direction(direction.z)

	local position = self:get_pos()
	position = vector.round(position)

	return vector.add(position, direction)
end

-- get_front_node returns a node that exists in front of the maidroid.
local get_front_node = function(self)
	local front = self:get_front()
	return minetest.get_node(front)
end

-- returns maidroid's looking direction vector.
local get_look_direction = function(self)
	local yaw = self.object:get_yaw()
	return minetest.yaw_to_dir(yaw)
end

-- set_animation sets the maidroid's animation.
-- this method is wrapper for self.object:set_animation.
local set_animation = function(self, frame)
	-- ,,x1
	-- turn off animation
	self.object:set_animation(frame, 15, 0)
end

-- set the maidroid's yaw according a direction vector.
local set_yaw = function(self, data)
	local datatype = type(data)
	local yaw
	if datatype == "number" then
		yaw = data
	elseif vector.check(data) then
		yaw = minetest.dir_to_yaw(data)
	elseif datatype == "table" then
		yaw = minetest.dir_to_yaw(vector.direction(data[1], data[2]))
	else return end
	self.object:set_yaw(yaw)
end

local check_chest = function(pos, pname)
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local ok

	if node.name:sub(1,8) == "default:" then
		local owner = meta:get_string("owner")
		if not owner or owner == "" or owner == pname then
			ok = true
		end
		-- TODO: check for room in chest
	end
	return ok
end

-- flush items to teleport tubes or chest
-- when pos present function trys to flush to chest
-- initially used to flush to tubes
local flush = function(self, stacks, pos)
	local inv = self:get_inventory()
	local chest_inv
	local tube
	if pos then
		if not check_chest(pos, self.owner) then
			return
		end
		chest_inv = minetest.get_meta(pos):get_inventory()
	elseif inv:contains_item("main", "pipeworks:teleport_tube_1") then
		tube = get_tube(self.owner .. ";" .. self.tbchannel)
		if not tube then
			self.tbchannel = ""
			return
		end
	else
		return
	end

	local f_count, f_name, f_stack, stack
	for j=1,3 do  -- Iterate over filters
		f_stack = inv:get_stack("tube",j)
		f_name = f_stack:get_name()
		if f_name and f_name ~= "" then
			for i=#stacks,1,-1 do -- counterwise allows remove content
				if stacks[i]:get_name() == f_name then
					if pos then
						stack = chest_inv:add_item("main", stacks[i])
						if stack:get_count() == 0 then
							table.remove(stacks, i)
						else
							stacks[i] = stack
						end
					else
						pipeworks.tube_inject_item(self:get_pos(), tube, vector.new(1,1,1), stacks[i], self.owner)
						table.remove(stacks, i)
					end
				end
			end

			-- Send maximal size stacks in teleport tubes until stacks count is under or equal to maximum
			f_count = f_stack:get_stack_max()
			f_stack:set_count(f_count)
			while true do
				f_stack = inv:remove_item("main", f_stack)
				if (pos and not chest_inv:room_for_item("main", f_stack))
					or f_stack:get_count() < f_count
					or not inv:contains_item("main", f_stack:get_name()) then
					inv:add_item("main", f_stack)
					break;
				else
					if pos then
						chest_inv:add_item("main", f_stack)
					else
						pipeworks.tube_inject_item(self:get_pos(), tube, vector.new(1,1,1), f_stack, self.owner)
					end
				end
			end
		end
	end
end

-- add_items_to_main adds an item list to main inventory
-- return if an oveflow was detected or not
local add_items_to_main = function(self, stacks)
	if #stacks == 0 then
		return
	end
	local inv = self:get_inventory()
	local leftovers = {}
	local failure = false
	for _, stack in ipairs(stacks) do
		if failure then
			if type(stack) == "string" then
				stack = ItemStack(stack)
			end
			table.insert(leftovers, stack)
		else
			stack = inv:add_item("main", stack)
			if stack:get_count() > 0 then
				table.insert(leftovers, stack)
				failure = true
			end
		end
	end

	local pos = self:get_pos()
	if #leftovers ~= 0 then
		flush(self, leftovers) -- Flush to pipeworks
		pos = minetest.find_node_near(pos, 4, { "default:chest", "default:chest_locked" })
		if pos and #leftovers ~= 0 then
			flush(self, leftovers, pos)
		end -- Flush to chest -- TODO delay action
		for i=#leftovers,1,-1 do -- iterate counterwise to be able to remove content
			if inv:room_for_item("main",leftovers[i]) then
				inv:add_item("main", leftovers[i])
				table.remove(leftovers, i)
			end
		end
	end
	if #leftovers == 0 then return end

	pos = self:get_pos()
	for _, stack in ipairs(leftovers) do
		minetest.add_item(random_pos_near(pos), stack)
	end
	if minetest.get_player_by_name(self.owner) then
		minetest.chat_send_player(self.owner, S("A maidroid located at: ") ..
		minetest.pos_to_string(vector.round(self:get_pos()))
		.. S("; needs to take a rest: inventory full"))
	end
	self.core.on_pause(self)
	self.pause = true
	return true
end

-- is_named reports the maidroid is still named.
local is_named = function(self)
	return self.nametag ~= ""
end

-- has_item_in_main reports whether the maidroid has item.
local has_item_in_main = function(self, pred)
	local inv = self:get_inventory()
	local stacks = inv:get_list("main")

	for _, stack in ipairs(stacks) do
		local itemname = stack:get_name()
		if pred(itemname) then
			return true
		end
	end
end

-- change velocity to go to a target node
local set_target_node = function(self, destination)
	local position = self:get_pos()
	local direction = vector.direction(position, destination)
	direction.y = 0

	local speed = maidroid.settings.speed * ( 1 + math.random(0,10)/20 )
	local velocity = vector.multiply(direction, speed)

	self.object:set_velocity(velocity)
	self:set_yaw(direction)
end

-- changes direction randomly.
local change_direction = function(self, invert)
	local yaw = ( math.random(314) - 157 ) / 100 -- approximate [ -π/2, π/2 ]
	local direction
	local distance = vector.distance(self:get_pos(), self.home)
	if not invert and distance > 12 then
		direction = vector.subtract(self.home, self:get_pos())
		-- TODO notice we need to launch path_finding
		--if distance > 20 or direction.y > nnn then ret = true ?? end
		-- offset direction to home by percentage current direction
		yaw = yaw / 2 + minetest.dir_to_yaw(direction) - self.object:get_yaw()
		yaw = yaw / math.random(2,math.floor(distance/2))
		yaw = yaw + minetest.dir_to_yaw(direction)
	elseif invert then
		-- restrict to [ -π/4, π/4 ], and invert direction adding π
		yaw = yaw / 2 + 3.1415 + self.object:get_yaw()
	else
		yaw = yaw + self.object:get_yaw()
	end

	direction = vector.multiply(minetest.yaw_to_dir(yaw),
		maidroid.settings.speed * ( 1 + math.random(0,10)/20 ))
	self.object:set_velocity(direction)
	self.object:set_yaw(yaw)
end

-- strong_change_direction: force at least 90-degree turn to bypass obstacles
local strong_change_direction = function(self)
	local base = self.object:get_yaw()
	local left = base + math.pi/2
	local right = base - math.pi/2
	-- Add some randomness so it’s not exactly 90 degrees every time
	local yaw = math.random() > 0.5 and (left + math.random(-30,30)/100) or (right + math.random(-30,30)/100)
	local direction = vector.multiply(minetest.yaw_to_dir(yaw),
		maidroid.settings.speed * ( 1 + math.random(0,10)/20 ))
	self.object:set_velocity(direction)
	self.object:set_yaw(yaw)
end

-- update_infotext updates the infotext of the maidroid.
local update_infotext = function(self)
	local description
	if self.owner == "" then
		description = S("looking for gold")
	else
		description = self.core.description
	end

	local infotext = S("this maidroid is ")
		.. ": " .. description .. "\n" .. S("Health")
		.. ": " .. math.ceil(self.object:get_hp() * 100 / self.hp_max) .. "%\n"

	if self.owner ~= "" then
		infotext = infotext .. S("Owner") .. " : " .. self.owner
	end
	infotext = infotext .. "\n\n\n\n"

	self.object:set_properties({infotext = infotext})
end

local is_blocked_orig = function(self, criterion, check_inside)
	if criterion == nil then
		return false
	end

	local pos = self:get_pos()
	local node
	local dir

	if check_inside then
		dir = vector.multiply(self:get_look_direction(), 0.1875)
		node = minetest.get_node(vector.add(pos, dir))
		if criterion(node.name) then
			return true
		end
	end

	local front = self:get_front()
	dir = vector.subtract(front, vector.round(self:get_pos()))
	if dir.x == 0 or dir.z == 0 then
		node = minetest.get_node(front)
	else
		node = minetest.get_node(vector.add(front,vector.new(dir.x, 0, 0)))
		if not criterion(node.name) then
			return false
		end
		node = minetest.get_node(vector.add(front,vector.new(0, 0, dir.z)))
	end
	return criterion(node.name)
end

-- ,,isb,,blocked
local is_blocked = function(self, criterion, check_inside)
	-- Helper to add a distinct position to the history (max 3)
	local function add_prev_pos(pos)
		if not self._prev_pos then
			self._prev_pos = {}
		end
		-- local rounded = vector.round(pos)
		local rounded = pos
		-- Only add if different from the most recent position
		if #self._prev_pos == 0 or not vector.equals(rounded, self._prev_pos[#self._prev_pos]) then
			table.insert(self._prev_pos, rounded)
			-- Keep only the last 3
			if #self._prev_pos > 3 then
				table.remove(self._prev_pos, 1)
			end
		end
		-- Debug: dump position list
		local pos_str = {}
		for i, p in ipairs(self._prev_pos) do
			pos_str[i] = string.format("(%.2f,%.2f,%.2f)", p.x, p.y, p.z)
		end
		-- lf("is_blocked", "pos_list: [" .. table.concat(pos_str, ", ") .. "]")
	end
	local function on_blocked(node_name, msg)
		local pos = self:get_pos()
		-- lf("is_blocked", "blocked by node=" .. node_name .. " (" .. msg .. ") at pos=" .. minetest.pos_to_string(vector.round(pos)))
		return true
	end
	local function on_not_blocked(msg)
		add_prev_pos(self:get_pos())
		-- lf("is_blocked", "not blocked (" .. msg .. ")")
		return false
	end
	-- Use previous positions from last calls; update at the end
	local prev_pos = self._prev_pos and self._prev_pos[#self._prev_pos]
	local prev_prev_pos = self._prev_pos and #self._prev_pos >= 2 and self._prev_pos[#self._prev_pos - 1]
	-- Log if stuck (same as last position)
	-- if prev_pos and vector.equals(vector.round(self:get_pos()), vector.round(prev_pos)) then
	-- 	lf("is_blocked", "stuck: prev_pos same as current pos " .. minetest.pos_to_string(vector.round(self:get_pos())))
	-- end
	if criterion == nil then
		return on_not_blocked("criterion nil")
	end

	local pos = self:get_pos()
	local node
	local dir

	if check_inside then
		dir = vector.multiply(self:get_look_direction(), 0.1875)
		node = minetest.get_node(vector.add(pos, dir))
		if criterion(node.name) then
			return on_blocked(node.name, "inside")
		end

		-- Extra case for fences: also treat a fence directly under the maidroid as blocking.
		if criterion == maidroid.helpers.is_fence then
			local here = vector.round(pos)
			local here_below = vector.add(here, vector.new(0, -1, 0))
			local node_here_below = minetest.get_node(here_below)
			local is_fence_result = criterion(node_here_below.name)
			if is_fence_result then
				lf("is_blocked", "fence directly under at " .. minetest.pos_to_string(here) .. " node=" .. node_here_below.name)
				-- If check_inside, teleport back to previous-previous position to avoid stepping onto fence
                -- if prev_pos and vector.equals(vector.round(self:get_pos()), vector.round(prev_pos)) then
                if prev_prev_pos and not vector.equals(vector.round(self:get_pos()), vector.round(prev_prev_pos)) then
                    if prev_prev_pos then
                        self.object:set_pos(prev_prev_pos)
                        lf("is_blocked", "teleported back to prev_prev_pos " .. minetest.pos_to_string(prev_prev_pos))
                    end
                else 
                    lf("is_blocked", "stuck: prev_pos same as current pos " .. minetest.pos_to_string(vector.round(self:get_pos())))
                end

				return on_blocked(node_here_below.name, "fence under")
			end
		end
	end

	local front = self:get_front()
	local front_below = vector.add(front, vector.new(0, -1, 0))
	dir = vector.subtract(front, vector.round(self:get_pos()))
	if dir.x == 0 or dir.z == 0 then
		-- Straight ahead: check maidroid position, then node in front, then one node below the front.
		local here = vector.round(pos)
		local node_here = minetest.get_node(here)
		if criterion(node_here.name) then
			return on_blocked(node_here.name, "here")
		end
		local here_below = vector.add(here, vector.new(0, -1, 0))
		local node_here_below = minetest.get_node(here_below)
		if criterion(node_here_below.name) then
			return on_blocked(node_here_below.name, "here_below")
		end
		node = minetest.get_node(front)
		if criterion(node.name) then
			return on_blocked(node.name, "front")
		end
		node = minetest.get_node(front_below)
		if criterion(node.name) then
			return on_blocked(node.name, "front_below")
		end
		return on_not_blocked("straight")
	else
		-- Diagonal: check maidroid position, front itself, then both possible front edges and their nodes one below.
		local here = vector.round(pos)
		local node_here = minetest.get_node(here)
		if criterion(node_here.name) then
			return on_blocked(node_here.name, "diag_here")
		end
		local here_below = vector.add(here, vector.new(0, -1, 0))
		local node_here_below = minetest.get_node(here_below)
		if criterion(node_here_below.name) then
			return on_blocked(node_here_below.name, "diag_here_below")
		end
		node = minetest.get_node(front)
		if criterion(node.name) then
			return on_blocked(node.name, "diag_front")
		end
		node = minetest.get_node(front_below)
		if criterion(node.name) then
			return on_blocked(node.name, "diag_front_below")
		end
		local pos1 = vector.add(front, vector.new(dir.x, 0, 0))
		node = minetest.get_node(pos1)
		if criterion(node.name) then
			return on_blocked(node.name, "diag1")
		end
		local pos1_below = vector.add(pos1, vector.new(0, -1, 0))
		node = minetest.get_node(pos1_below)
		if criterion(node.name) then
			return on_blocked(node.name, "diag1_below")
		end

		local pos2 = vector.add(front, vector.new(0, 0, dir.z))
		node = minetest.get_node(pos2)
		if criterion(node.name) then
			return on_blocked(node.name, "diag2")
		end
		local pos2_below = vector.add(pos2, vector.new(0, -1, 0))
		node = minetest.get_node(pos2_below)
		if criterion(node.name) then
			return on_blocked(node.name, "diag2_below")
		end
		return on_not_blocked("diagonal")
	end
end

---------------------------------------------------------------------

local manufacturing_id = {}

-- generate_unique_manufacturing_id generate an unique id for each activated maidroid
-- perfomance issue appears increasingly while the table is filled up
-- having the "gametime" as a source balances this as the collision space is per time units
local function generate_unique_manufacturing_id()
	local id
	while true do
		id = string.format("%s:%x-%x-%x-%x", minetest.get_gametime(), math.random(1048575), math.random(1048575), math.random(1048575), math.random(1048575))
		if manufacturing_id[id] == nil then
			table.insert(manufacturing_id, { id = true })
			return "maidroid:" .. id
		end
	end
end

---------------------------------------------------------------------

-- maidroid.register_core registers a definition of a new core.
function maidroid.register_core(name, def)
	def.name = name
	if not def.walk_max then
		def.walk_max = maidroid.timers.walk_max
	end

	-- Register a hat entity
	if def.hat then
		local hat_name = "maidroid:" .. def.hat.name
		def.hat.name = hat_name

		if minetest.get_current_modname() ~= "maidroid" then
			hat_name = ":" .. hat_name
		end
		minetest.register_entity(hat_name, {
			visual = "mesh",
			mesh = def.hat.mesh,
			textures = def.hat.textures,

			physical = false,
			pointable = false,
			static_save = false,

			on_detach = function(self)
				lf("api", "wield_item on_detach called - removing wield_item object")
				self.object:remove()
			end
		})
	end
	maidroid.cores[name] = def
end

-- player_can_control return if the interacting player "owns" the maidroid
local player_can_control = function(self, player)
	if not player then
		return false
	end
	return self.owner and self.owner == player:get_player_name()
		or minetest.check_player_privs(player, "maidroid")
end

-- heal: heals a maidroid when punched with an healing item
local heal_items = {}
heal_items["default:tin_lump"] = 1
heal_items["default:mese_crystal_fragment"] = 3
local heal = function(self, stack)
	local hp = self.object:get_hp()
	if hp >= self.hp_max then
		return stack
	end
	local name = stack:get_name()
	if heal_items[name] and stack:take_item():get_count() == 1 then
		self.object:set_hp(hp + heal_items[name])
		self:update_infotext()
	end
	return stack
end

-- autoheal: checks for heal item in maidroid inventory and use it
local autoheal = function(self)
	local hp = self.object:get_hp()
	if hp >= self.hp_max then
		return
	end -- Do nothing when max hp

	local t_health = minetest.get_gametime()
	if t_health - self.t_health > 10 then
		self.t_health = t_health
	else
		return
	end -- Do nothing if timer is low

	local inv = self:get_inventory()
	for name, val in pairs(heal_items) do
		if inv:remove_item("main", ItemStack(name)):get_count() == 1 then
			self.object:set_hp(hp + val)
			self:update_infotext()
			return
		end
	end
end

-- generate_texture return a string with the maidroid texture
maidroid.generate_texture2 = function(index)
	lf("api", "******************************************   generate_texture")
	-- error("This is an error message", 2)

	-- ,,x1
	-- local texture_name = "[combine:40x40:0,0=maidroid_base.png"
	local texture_name = ""
	local color = index
	if type(index) ~= "string" then
		color = dye.dyes[index][1]
	end
	texture_name = texture_name ..  ":24,32=maidroid_eyes_" .. color .. ".png"
	if color == "dark_green" then
		color = "#004800"
	elseif color == "dark_grey" then
		color = "#484848"
	end
	texture_name = texture_name .. "^(maidroid_hairs.png^[colorize:" .. color .. ":255)"
	return texture_name
end

maidroid.generate_texture = function(index)
	lf("api", "******************************************   generate_texture")
	texture_name=""
	return texture_name
end

-- create_inventory return a new inventory.
-- ,,ci1
local function create_inventory(self, inventory_name)
	self.inventory_name = inventory_name
    -- ,,cdi2
	local inventory = minetest.create_detached_inventory(self.inventory_name, {
		on_put = function(_, listname)
			if listname == "main" then
				self.need_core_selection = true
			end
		end,

		allow_put = function(inv, listname, index, stack, player)
			if not self:player_can_control(player) then
				if listname == "prices" then
					local p_stack = inv:get_stack("prices", index)
					local s_stack = inv:get_stack("shop", index)
					if p_stack:get_name() ~= stack:get_name()
						or s_stack:get_name() == "" then
						return 0
					end
					local pinv = player:get_inventory()
					while stack:get_count() >= p_stack:get_count() and
						inv:contains_item("main", s_stack) and
						inv:room_for_item("main", p_stack) and
						pinv:room_for_item("main", s_stack) do
						inv:add_item("main", p_stack)
						pinv:add_item("main", s_stack)
						pinv:remove_item("main", p_stack)
						stack:set_count(stack:get_count() - p_stack:get_count())
					end
				end
				return 0
			end
			if listname == "main" then
				return stack:get_count()
			elseif listname == "tube" then
				stack:set_count(1)
				inv:set_stack(listname, index, stack)
				return 0
			end
			return 0
		end,

		on_take = function(_, listname)
			if listname == "main" then
				self.need_core_selection = true
			end
		end,

		allow_take = function(inv, listname, index, stack, player)
			if not self:player_can_control(player) then
				if listname == "shop" then
					local s_price = inv:get_stack("prices", index)
					local pinv = player:get_inventory()
					if inv:contains_item("main", stack) and
						inv:room_for_item("main", s_price) and
						pinv:contains_item("main", s_price) and
						pinv:room_for_item("main", stack) then
						inv:remove_item("main", stack)
						pinv:remove_item("main", s_price)
						inv:add_item("main", s_price)
						pinv:add_item("main", stack)
						local pname = player:get_player_name()
						if maidroid_buf[pname] then
							minetest.show_formspec(pname, "maidroid:gui", get_formspec(self, player, 2) )
						end
					end
				end
				return 0
			end
			if listname == "main" then
				return stack:get_count()
			end

			inv:set_stack(listname, index, ItemStack(""))
			return 0
		end,

		on_move = function(_, from_list, _, to_list)
			if to_list == "main" or from_list == "main" then
				self.need_core_selection = true
			end
		end,

		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			if not self:player_can_control(player) then
				return 0
			end

			if from_list == "tube" then
				inv:set_stack(from_list, from_index, ItemStack())
			elseif to_list == "tube" then
				inv:set_stack(to_list, to_index, ItemStack(inv:get_stack(from_list, from_index):get_name()))
			elseif from_list == "main" then
				if to_list == "main" then
					return count
				elseif to_list == "shop" or to_list == "prices" then
					inv:set_stack(to_list, to_index, ItemStack(inv:get_stack(from_list, from_index):get_name() .. " " .. count))
				end
			end
			return 0
		end,
	})

	inventory:set_size("main", 24)
	inventory:set_size("tube", 3)
	inventory:set_size("shop", 6)
	inventory:set_size("prices", 6)

	return inventory
end

-- create_cooker_inventory return a new crafting inventory.
local function create_cooker_inventory(self, inventory_name)
	self.crafting_inventory_id = inventory_name
	local inventory = minetest.create_detached_inventory(self.crafting_inventory_id, {
		on_put = function(_, listname)
			lf("cooker_inventory", "on_put called for list: " .. tostring(listname))
		end,

		allow_put = function(inv, listname, index, stack, player)
			lf("cooker_inventory", "allow_put called by " .. player:get_player_name() .. " for list: " .. tostring(listname) .. ", item: " .. stack:get_name())
			return 0
		end,

		on_take = function(_, listname)
			lf("cooker_inventory", "on_take called for list: " .. tostring(listname))
		end,

		allow_take = function(inv, listname, index, stack, player)
			lf("cooker_inventory", "allow_take called by " .. player:get_player_name() .. " for list: " .. tostring(listname) .. ", item: " .. stack:get_name())
			return 99
		end,

        -- ,,move
		on_move = function(_, from_list, _, to_list)
			lf("cooker_inventory", "on_move called from " .. tostring(from_list) .. " to " .. tostring(to_list))
			
			-- Handle moving from craftable to desirable
			if from_list == "craftable" and to_list == "desirable" then
				lf("cooker_inventory", "Item moved from craftable to desirable, updating desired craft outputs")
				
				-- Get the maidroid this inventory belongs to
				local droid = self
				
			
                maidroid.handle_change_desirable(self)
			-- Handle moving from desirable to craftable
			elseif from_list == "desirable" and to_list == "craftable" then
				maidroid.handle_change_desirable(self)
				
				-- Check all craftable slots for duplicates and remove them
				local droid = self
				if droid then
					local crafting_inv = maidroid.crafting_inventories[self.crafting_inventory_id]
					local items_seen = {}
					for i = 1, 12 do -- craftable has 12 slots
						local stack = crafting_inv:get_stack("craftable", i)
						if not stack:is_empty() then
							local item_name = stack:get_name()
							if items_seen[item_name] then
								-- This is a duplicate, remove it
								crafting_inv:set_stack("craftable", i, "")
								lf("cooker_inventory", "Removed duplicate " .. item_name .. " from craftable slot " .. i)
							else
								-- First time seeing this item
								items_seen[item_name] = true
							end
						end
					end
				end
			end
		end,

		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			lf("cooker_inventory", "allow_move called by " .. player:get_player_name() .. " from " .. tostring(from_list) .. " to " .. tostring(to_list) .. ", count: " .. tostring(count))
			return count
		end,
	})

	inventory:set_size("craftable", 12)
	inventory:set_size("desirable", 6)

	return inventory
end

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

-- get_formspec returns a string that represents a formspec definition.
-- ,,form
get_formspec = function(self, player, tab)
	local owns = self:player_can_control(player)
	local form = "size[11,7.4]"
		.. "box[0.2,3.9;2.3,2.7;black]"
		.. "box[0.3,4;2.1,2.5;#343848]"
		-- .. "model[0.2,4;3,3;3d;maidroid.b3d;"
		.. "model[0.2,4;3,3;3d;character.b3d;"
		.. minetest.formspec_escape(self.textures[1])
		.. ";0,180;false;true;200,219;7.5]" -- ]model
		.. "label[0,6.6;" .. S("Health") .. "]"
		.. "label[0,0;" .. S("this maidroid is ") .. "]"
		.. "label[0.5,0.75;" .. self.core.description .. "]"
		.. "tabheader[0,0;tabheader;" .. S("Inventory")
		.. ( owns and "," .. S("Flush") or "")
		.. ( self.core.can_sell and "," .. S("Shop") or "" )
		.. ( (owns and self.core.doc) and "," .. S("Doc") or "" )
		.. ( (self.core.name == "generic_cooker" and owns) and "," .. S("Cooker") or "" )
		.. ";" .. tab .. ";false;true]"
	self.current_tab = tab

	if self.owner ~= player:get_player_name() then
		form = form .. "label[0,1.5;" .. S("Owner") .. ":]"
			.. "label[0.5,2.25;" .. self.owner .. "]"
	end

	-- Eggs bar: health view
	local hp = self.object:get_hp() * 8 / self.hp_max
	for i = 0, 8 do
		if i <= hp then
			form = form .. "item_image[" .. i * 0.3 .. ",7.1;0.3,0.3;maidroid:maidroid_egg]"
		else
			form = form .. "image["      .. i * 0.3 .. ",7.1;0.3,0.3;maidroid_empty_egg.png]"
		end
	end

	if tab == 1 then -- droid and user inventories
		form = form .. enligthen_tool(self)
			.. "list[detached:"..self.inventory_name..";main;3,0;8,3;]"
		if owns then
			form = form .. "list[current_player;main;3,3.4;8,1;]"
			.. "listring[]"
			.. "list[current_player;main;3,4.6;8,3;8]"
		end
		return form
	end

	if tab == 2 and owns then -- droid inventory + flushable items list
		form = form .. enligthen_tool(self)
			.. "list[detached:"..self.inventory_name..";main;3,0;8,3;]"
			.. "label[3,3.5;" .. S("Flushable Items") .. "]"
			.. "list[detached:"..self.inventory_name..";tube;4,4.25;3,1;]"
		if mods.pipeworks and
			self:get_inventory():contains_item("main", "pipeworks:teleport_tube_1") then
			form = form
				.. "label[3,5.5;" .. S("Pipeworks Channel") .. ": "
				.. minetest.colorize("#EEACAC", self.owner .. minetest.formspec_escape(";"))
				.. minetest.colorize("#ACEEAC", self.tbchannel)
				.. "]field[4.25,6.25;3,1;channel;;" .. self.tbchannel .. "]"
				.. "field_close_on_enter[channel;false]"
			if self.tbchannel ~= "" then
				form = form .. "button[8,5.9;2.5,1;flush;" .. S("Flush") .. "]"
			end
		end -- and maybe select a pipeworks channel
		return form
	end

	local tab_max = owns and 3 or 2
	if tab == tab_max and self.core.can_sell then
		if owns then
			form = form .. enligthen_tool(self)
				.. "list[detached:"..self.inventory_name..";main;3,0;8,3;]"
		else
			form = form .. "list[current_player;main;3,0;8,3;]"
		end
		form = form
			.. "label[3,3.5;" .. S("Items to sell") .. "]"
			.. "list[detached:"..self.inventory_name..";shop;4,4.25;6,1;]"
			.. "label[3,5.5;" .. S("Prices") .. "]"
			.. "list[detached:"..self.inventory_name..";prices;4,6.25;6,1;]"
		return form
	end
	if self.core.can_sell then
		tab_max = tab_max + 1
	end

	if owns and self.core.doc and tab == tab_max then
		form = form .. "textarea[3,0;8,7.5;;;" .. self.core.doc .. "]"
		return form
	end
	
	-- Cooker tab for generic_cooker core
    -- ,,tab
	if owns and self.core.name == "generic_cooker" then
		tab_max = tab_max + 1
		if tab == tab_max then
			-- Create and update crafting inventory
			if not self.crafting_inventory_id then
				-- Use the new create_cooker_inventory function
				local crafting_inventory = create_cooker_inventory(self, generate_unique_manufacturing_id())
				maidroid.crafting_inventories[self.crafting_inventory_id] = crafting_inventory
				maidroid.populate_craftable_items(crafting_inventory, self, init_craftable_outputs)
				lf("cooker_tab", "Created crafting inventory with ID: " .. self.crafting_inventory_id)
			end
			
			local crafting_inv_id = self.crafting_inventory_id
			local crafting_inv = maidroid.crafting_inventories[crafting_inv_id]
			if crafting_inv then
				lf("cooker_tab", "Found crafting inventory, updating selection")
				maidroid.update_selection_inventory(crafting_inv, self)
			else
				lf("cooker_tab", "ERROR: Could not find crafting inventory!")
			end
			
			-- Shop-style layout for cooker with pagination
			-- Calculate current page and total pages for craftable items
			local craftable_outputs = {}
            craftable_outputs = init_craftable_outputs
            -- ,,x3
            self.craftable_outputs_ui = maidroid.get_craftable_outputs_as_sparse_array()
            
            lf("cooker_tab", "self.craftable_outputs_ui: " .. dump(self.craftable_outputs_ui))
            lf("cooker_tab", "self.craftable_page: " .. tostring(self.craftable_page))
            -- error("")

			-- if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.get_craftable_outputs then
			-- 	craftable_outputs = maidroid.cores.generic_cooker.get_craftable_outputs() or {}
			-- end
            
			-- if type(craftable_outputs) ~= "table" or #craftable_outputs == 0 then
			-- 	craftable_outputs = init_craftable_outputs
			-- end
			
			-- Craftable pagination variables
			local craftable_items_per_page = 12
			local craftable_total_pages = math.ceil(#craftable_outputs / craftable_items_per_page)
			local craftable_current_page = (self.craftable_page or 1)
			if craftable_current_page > craftable_total_pages then craftable_current_page = craftable_total_pages end
			if craftable_current_page < 1 then craftable_current_page = 1 end
			
			-- Get current craftable page items
			local craftable_start_idx = (craftable_current_page - 1) * craftable_items_per_page + 1
			local craftable_end_idx = math.min(craftable_start_idx + craftable_items_per_page - 1, #craftable_outputs)
			local craftable_page_items = {}
			for i = craftable_start_idx, craftable_end_idx do
				table.insert(craftable_page_items, craftable_outputs[i])
			end
			
			-- Update craftable inventory with current page items
			maidroid.populate_craftable_items_page(crafting_inv, self, craftable_page_items)
			
            local droid = self  
			-- Calculate desirable pagination (based on page items tracking)
			local desirable_outputs = {}
            local droid = self
			
			-- Build complete list from all pages using helper function
			if type(droid.desirable_page_items) == "table" then
				desirable_outputs = maidroid.build_complete_desirable_list(droid)
			elseif type(droid.desired_craft_outputs) == "table" then
				-- Fallback to regular desired outputs if page tracking not set
				desirable_outputs = droid.desired_craft_outputs
			end
			
			-- If no desirable items, show empty
			if type(desirable_outputs) ~= "table" or #desirable_outputs == 0 then
				desirable_outputs = {}
			end
			
			local desirable_items_per_page = 6
			-- Always show at least 2 pages when there are desirable items (for drag-and-drop)
			local desirable_total_pages = math.max(2, math.ceil(#desirable_outputs / desirable_items_per_page))
			local desirable_current_page = (self.desirable_page or 1)
			if desirable_current_page > desirable_total_pages then desirable_current_page = desirable_total_pages end
			if desirable_current_page < 1 then desirable_current_page = 1 end
			
			-- Get current desirable page items (from actual desirable outputs)
			local desirable_start_idx = (desirable_current_page - 1) * desirable_items_per_page + 1
			local desirable_end_idx = math.min(desirable_start_idx + desirable_items_per_page - 1, #desirable_outputs)
			local desirable_page_items = {}
			
			-- Check if we have stored page data for this page with preserved positions
			local stored_page_data = nil
			if droid.desirable_page_items and droid.desirable_page_items[desirable_current_page] then
				stored_page_data = droid.desirable_page_items[desirable_current_page]
				lf("cooker_tab", "Found stored page data for page " .. desirable_current_page .. ": " .. dump(stored_page_data))
			end
			
			if stored_page_data then
				-- Restore items to their exact positions from stored data
				for i = 1, desirable_items_per_page do
					if stored_page_data[i] then
						desirable_page_items[i] = stored_page_data[i]
					else
						desirable_page_items[i] = "" -- Empty slot
					end
				end
			elseif desirable_current_page > 1 and desirable_start_idx > #desirable_outputs then
				-- Show empty page for drag-and-drop
				for i = 1, desirable_items_per_page do
					table.insert(desirable_page_items, "")
				end
			else
				-- Show actual items for this page (no stored data)
				for i = desirable_start_idx, desirable_end_idx do
					table.insert(desirable_page_items, desirable_outputs[i])
				end
			end
			
			-- Update desirable inventory with current page items
			maidroid.populate_desirable_items_page(crafting_inv, self, desirable_page_items)
			
			form = form .. enligthen_tool(self)
				.. "label[3,0;" .. S("Craftables") .. "]"
				.. "list[detached:" .. crafting_inv_id .. ";craftable;3,0.5;6,2;]"
				
			-- Add craftable pagination buttons if needed
			if craftable_total_pages > 1 then
				form = form
					.. "button[3,2.8;1,0.5;craftable_prev;<]"
					.. "label[4.2,2.8;" .. S("Page") .. " " .. craftable_current_page .. "/" .. craftable_total_pages .. "]"
					.. "button[6,2.8;1,0.5;craftable_next;>]"
			end
			
			form = form
				.. "label[3,3.5;" .. S("Desirable Craft") .. "]"
				.. "list[detached:" .. crafting_inv_id .. ";desirable;4,4.25;6,1;]"
				
			-- Add desirable pagination buttons if there are desirable items (not just multiple pages)
			if #desirable_outputs > 0 then
				form = form
					.. "button[3,5.3;1,0.5;desirable_prev;<]"
					.. "label[4.2,5.3;" .. S("Page") .. " " .. desirable_current_page .. "/" .. desirable_total_pages .. "]"
					.. "button[6,5.3;1,0.5;desirable_next;>]"
			end
			
			-- Add cooker controls below the lists
			form = form
				.. "button[3,6;2.5,1;toggle_cooker;" .. S("Toggle Cooker") .. "]"
				.. "button[6,6;2.5,1;view_metrics;" .. S("View Metrics") .. "]"
				.. "label[3,7;" .. S("Current Task:") .. " "
				.. minetest.colorize("#ACEEAC", (self.action and self.action or S("Idle"))) .. "]"
				.. "label[6,7;" .. S("State:") .. " "
				.. minetest.colorize("#ACEEAC", (self.state and tostring(self.state) or S("Unknown"))) .. "]"
			
			return form
		end
	end
end

-- on_activate is a callback function that is called when the object is created or recreated.
local function on_activate(self, staticdata)
	all_maidroid_metrics.total_activated = (all_maidroid_metrics.total_activated or 0) + 1
	-- Check if we've already spawned the maximum number of maidroids
	-- if total_maidroids_spawned >= MAX_MAIDROIDS_ALLOWED then
	-- lf("api", "maidroid: maximum number of maidroids (" .. MAX_MAIDROIDS_ALLOWED .. ") already spawned. Removing duplicate maidroid.")
	-- 	self.object:remove()
	-- 	return
	-- end
	
	
	-- parse the staticdata, and compose a inventory.
	if staticdata == "" then
		lf("api", "*************************  on_activate null staticdata")
		create_inventory(self, generate_unique_manufacturing_id())
	else
		lf("api", "*************************  on_activate has staticdata")
		-- Clone and remove object if it is an "old maidroid"
		if maidroid.settings.compat and self.name:find("maidroid_mk", 9) then
			lf("api", "[MOD] maidroid: old maidroid found. replacing with new")

			-- Fix old datas
			local data = minetest.deserialize(staticdata)
			-- ,,x1 see if load old tesxtures
			-- data.textures = maidroid.generate_texture(tonumber(self.name:sub(-2):gsub("k","")))
			-- data.textures = {maid_skins[math.random(6) - 1] }
			table.insert(data.inventory.main, data.inventory.board[1])
			table.insert(data.inventory.main, data.inventory.wield_item[1])
			table.remove(data.inventory,data.inventory.board)
			table.remove(data.inventory,data.inventory.core)
			table.remove(data.inventory,data.inventory.wield_item)

			-- Create new format maidroid
			local obj = minetest.add_entity(self:get_pos(), "maidroid:maidroid")
			obj:get_luaentity():on_activate(minetest.serialize(data))

			-- ,,x4
			obj:set_yaw(self.object:get_yaw())
			-- obj:get_luaentity().set_set_textures({ { name = maid_skins[0] } })

			-- Remove this old maidroid
			lf("api", "REMOVING old maidroid during migration - nametag: " .. tostring(self.nametag) .. ", pos: " .. minetest.pos_to_string(self:get_pos()))
			self.object:remove()
			return
		end

		-- if static data is not empty string, this object has beed already created.
		local data = minetest.deserialize(staticdata)

		self.nametag = data.nametag
        -- self.display_name = data.nametag
		self.owner = data.owner_name
		self.tbchannel = data.tbchannel or ""

		local inventory = create_inventory(self, generate_unique_manufacturing_id())
		for list_name, list in pairs(data.inventory) do
			inventory:set_list(list_name, list)
		end

		local my_texture = maid_skins[1]
		lf("api", "*************************  on_activate: "..tostring(data.textures))
		self.textures = { my_texture }
		-- data.textures = { my_texture }
		self.object:set_properties({
			textures = {my_texture}
		})

		if data.textures ~= nil and data.textures ~= "" then
			self.textures = { data.textures }
			self.object:set_properties({textures = { data.textures }})
		end
		self.home = data.home
	end

	self.object:set_nametag_attributes({ text = self.nametag, color = { a=255, r=96, g=224, b=96 }})
	self.object:set_acceleration{x = 0, y = -10, z = 0}

	-- attach dummy item to new maidroid.
	self.wield_item = minetest.add_entity(self:get_pos(), "maidroid:wield_item", minetest.serialize({state = "new"}))
	self.wield_item:set_attach(self.object, "Arm_R", {x=0.4875, y=2.75, z=-1.125}, {x=-90, y=0, z=-45})
	if not self.home then
		self.home = self:get_pos()
	end
	-- Store activation position for distance checking
	self._activation_pos = self:get_pos()
	lf("api", "Stored activation position: " .. minetest.pos_to_string(self._activation_pos))
	self.t_health = minetest.get_gametime()
	self.timers = {}
	self.timers.walk = 0
	self.timers.wander_skip = 0
	self.timers.change_direction = 0

	-- Check if this maidroid name has already been spawned
	local spawned_count = spawned_maidroid_names[self.nametag] or 0
	if spawned_count > 0 then
		lf("api", "maidroid:maidroid already spawned with name '" .. self.nametag .. "' - removing duplicate.")
		-- self.object:remove()
		-- return
	end
	
	-- Mark this name as spawned and increment total count
	spawned_maidroid_names[self.nametag] = spawned_count + 1
	total_maidroids_spawned = total_maidroids_spawned + 1
	
	lf("api", "maidroid: activating maidroid #" .. total_maidroids_spawned .. "/" .. MAX_MAIDROIDS_ALLOWED .. " with name '" .. self.nametag .. "'")


	self:select_core()
end

-- Add this helper near other local functions (above get_staticdata)
local function safe_read_file(path)
	local ok, content = pcall(function()
		local f = io.open(path, "r")
		if not f then error("unable to open file for read") end
		local c = f:read("*a")
		f:close()
		return c
	end)
	return ok, content
end

-- Calculate distance from maidroid to player
local function distance_from_player(self)
	local player = minetest.get_player_by_name(self.owner)
	if not player then
		return nil
	end
	
	local pos = self:get_pos()
	local player_pos = player:get_pos()
	
	if not pos or not player_pos then
		return nil
	end
	
	return vector.distance(pos, player_pos)
end

-- called when the object is destroyed.
local get_staticdata = function(self, captured)
	-- Log who called get_staticdata and why
	local pos = self:get_pos()
	local dist = distance_from_player and distance_from_player(self) or "unknown"
	lf("get_staticdata", "CALLED - nametag: " .. tostring(self.nametag) .. ", pos: " .. (pos and minetest.pos_to_string(pos) or "nil") .. ", distance from player: " .. tostring(dist) .. ", captured: " .. tostring(captured))
	
	local data = {
		nametag = self.nametag,
		owner_name = self.owner,
		inventory = {},
		textures = self.textures[0],
		tbchannel = self.tbchannel
	}

	-- data.textures = luaentity.object:get_properties()["textures"][1]

	-- lf("api", "====================== get_staticdata1:"..dump(self))
    mydump("get_staticdata", "====================== get_staticdata1", self)
	-- lf("api", "====================== get_staticdata2:"..dump(data))
    mydump("get_staticdata", "====================== get_staticdata2", data)
	-- lf("api", "====================== get_staticdata3:"..dump(self:get_properties()))
	-- check if object is destroyed, then return nil
	if not self.object or not self.object:get_pos() then
        lf("get_staticdata", "object is destroyed, name=" .. self.nametag)
		return nil
	end

	local eeee = self.object:get_properties()
	-- lf("api", "====================== get_staticdata3:"..dump(eeee))
    mydump("get_staticdata", "====================== get_staticdata3", eeee)
	-- ,,x1,,skip
	-- to work aroudn texture loss problem save texture from object properties
	data["textures"] = eeee["textures"][1]

	-- if self:get_properties ~= nil then 
    -- mydump("get_staticdata", "====================== get_staticdata3", self:get_properties())
	-- end


	-- save inventory
	local inventory = self:get_inventory()
	for list_name, list in pairs(inventory:get_lists()) do
		local tmplist = {}
		for idx, item in ipairs(list) do
			tmplist[idx] = item:to_string()
		end
		data.inventory[list_name] = tmplist
	end

	if not captured then
		data.home = self.home
	end


	local id_str = "N/A"
	do
		if self.object then
			-- try to call get_id() if available, otherwise fallback to tostring(self.object)
			if self.object.get_id then
				local ok, id = pcall(function() return self.object:get_id() end)
				if ok and id then
					id_str = tostring(id)
				else
					id_str = tostring(self.object)
				end
			else
				id_str = tostring(self.object)
			end
		end
		lf("api", "====================== get_staticdata3 : " .. tostring(self.nametag)
			.. "  entity_id=" .. id_str)
	end
	
	-- write data dump to disk named by id_str and print the file location
	-- local ok, ser = pcall(function() return minetest.serialize(data) end)
	local ok, ser = pcall(function() return dump(data) end)
	if not ok then
        log("Inner pcall caught:", msg)
    end
	local dumptext = ok and ser or tostring(data)
	lf("api", "maidroid staticdata dump: " .. dumptext)

	local worldpath = minetest.get_worldpath() or "."

	-- Prefer nametag for filenames when available, otherwise fall back to id_str.
	local id_source
	if self.nametag and self.nametag ~= "" then
		id_source = self.nametag
	else
		id_source = id_str
		return nil
	end
	

	local ok, safe_id = pcall(function()
		local s = tostring(id_source or "")
		if s == "" then s = tostring(id_str or "unknown") end
		return s:gsub("[^%w%._%-]", "_")
	end)
	if not ok then
		lf("api", "maidroid: failed to sanitize id_str: " .. tostring(safe_id))
		-- local fallback = tostring(id_str or "")
		-- safe_id = fallback:gsub("[^%w%._%-]", "_")
	end
	local filename = "maidroid_staticdata_" .. safe_id .. ".txt"
	local filepath = worldpath .. "/" .. filename

	local file, ferr = io.open(filepath, "w")
	if file then
		file:write(dumptext)
		file:close()
		lf("api", "Saved maidroid staticdata to: " .. filepath)
	else
		lf("api", "Failed saving maidroid staticdata to: " .. filepath .. " error: " .. tostring(ferr))
	end



	-- Replace the selected block in get_staticdata with this single call:
	local ok_read, readtext = safe_read_file(filepath)

	if ok_read and readtext then
		if readtext == dumptext then
			lf("api", "maidroid: staticdata verification OK: " .. filename)
		else
			lf("api", "maidroid: staticdata verification FAILED (content mismatch): " .. filename)
			-- log small prefixes to avoid overly large logs
			lf("api", "expected prefix: " .. tostring(dumptext):sub(1,200))
			lf("api", "read     prefix: " .. tostring(readtext):sub(1,200))
		end
	else
		lf("api", "maidroid: staticdata verification error reading file: " .. tostring(readtext))
	end

	return minetest.serialize(data)
end

-- Chat command to restore a maidroid from a staticdata dump file in the world folder.
-- Usage: /maidroid_load Eve_623
-- This will look for: <worldpath>/maidroid_staticdata_Eve_623.txt
local cmd_maidroid_load = {
	params = "<id>",
	description = S("Load a maidroid from maidroid_staticdata_<id>.txt in this world"),
	privs = { maidroid = true },
	func = function(name, param)
		param = (param or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if param == "" then
			return false, "Usage: /maidroid_load <id> (e.g. Eve_623)"
		end

		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found"
		end

		local worldpath = minetest.get_worldpath() or "."
		local filename = "maidroid_staticdata_" .. param .. ".txt"
		local filepath = worldpath .. "/" .. filename

		local ok_read, content = safe_read_file(filepath)
		if not ok_read or not content or content == "" then
			return false, "Failed to read staticdata file: " .. filename
		end

		-- The dump file contains a Lua-like table (output of dump(data)).
		-- Safely evaluate it to reconstruct the data table.
		local ok_parse, data = pcall(function()
			local chunk, err = loadstring("return " .. content)
			if not chunk then
				error(err or "invalid staticdata dump")
			end
			return chunk()
		end)
		if not ok_parse or type(data) ~= "table" then
			return false, "Failed to parse staticdata in file: " .. filename
		end

		-- Spawn the maidroid near the player and initialize it using the existing on_activate logic.
		local pos = vector.add(player:get_pos(), { x = 0, y = 0.5, z = 0 })
		local obj = minetest.add_entity(pos, "maidroid:maidroid")
		if not obj then
			return false, "Failed to spawn maidroid entity"
		end

		local lua = obj:get_luaentity()
		if lua and lua.on_activate then
			lua:on_activate(minetest.serialize(data))
		end

		return true, "Maidroid loaded from " .. filename
	end,
}

minetest.register_chatcommand("maidroid_load", cmd_maidroid_load)
minetest.register_chatcommand("mr_load", cmd_maidroid_load)

local cmd_maidroid_ls = {
	params = "",
	description = S("List all maidroid_staticdata_*.txt files in this world"),
	privs = { maidroid = true },
	func = function(name, param)
		local worldpath = minetest.get_worldpath() or "."
		local files = minetest.get_dir_list(worldpath, false) or {}
		local ids = {}
		for _, fname in ipairs(files) do
			-- match files like maidroid_staticdata_<id>.txt
			local id = fname:match("^maidroid_staticdata_(.+)%.txt$")
			if id then
				table.insert(ids, id)
			end
		end

		if #ids == 0 then
			return true, "No maidroid_staticdata_*.txt files found in this world."
		end

		table.sort(ids)
		return true, "Saved maidroids (" .. #ids .. "): \n" .. table.concat(ids, ", ")
	end,
}

minetest.register_chatcommand("maidroid_ls", cmd_maidroid_ls)
minetest.register_chatcommand("mr_ls", cmd_maidroid_ls)

-- pickup_item pickup collect all stacks from world in radius
local pickup_item = function(self, radius)
	local pos = self:get_pos()
	local all_objects = minetest.get_objects_inside_radius(pos, radius or 1.0)
	local stacks = {}
	local ok = false

	for _, obj in pairs(all_objects) do
		local luaentity = obj:get_luaentity()
		if not obj:is_player() and luaentity
			and luaentity.name == "__builtin:item"
			and luaentity.itemstring ~= "" then
			local stack = ItemStack(luaentity.itemstring)
			if stack:get_name() == "maidroid:helper_light" then
				goto continue
			end
			self.need_core_selection = true
			table.insert(stacks, stack)
			obj:remove()
			ok = true
		end
		::continue::
	end
	if ok then
		self:add_items_to_main(stacks)
	end
end

-- toggle_entity_jump: forbid "jumping" if maidroid is over an entity
local toggle_entity_jump = function(self, _, moveresult)

	if not moveresult then
		lf("api", "toggle_entity_jump: moveresult is nil")
		return
	end

	local stepheight = self.object:get_properties().stepheight
	-- Do not allow "jumping" when standing on object
	if moveresult.standing_on_object and stepheight ~= 0 then
		self.object:set_properties({ stepheight = 0 })
	elseif moveresult.touching_ground and stepheight == 0 then
		self.object:set_properties({ stepheight = 1.1 })
	end
end

-- on_step is a callback function that is called every delta times.
local function on_step(self, dtime, moveresult)
	if self.core.toggle_jump then
		self:toggle_entity_jump(dtime, moveresult)
	end

	if maidroid.settings.skip > 1 then
		self.skip = ( self.skip + 1 ) % maidroid.settings.skip
		if self.skip ~= 0 then
			self.skiptime = self.skiptime + dtime
			return
		else
			dtime = self.skiptime + dtime
			self.skiptime = 0
		end
	end

	if self.need_core_selection then
		self:select_core()
		if self.core and self.core.alt_tool then
			self.core.alt_tool(self)
		end
		self.need_core_selection = false
	end

	autoheal(self) --  Self-healing

	if not self.pause then
		self.core.on_step(self, dtime, moveresult)
	end -- call current core
end

-- on_rightclick is a callback function that is called when a player right-click them.
local function on_rightclick(self, clicker)
	if self.owner == "" or not clicker:is_player() then
		return -- Not tamed
	end

	if clicker:get_wielded_item():get_name() == "maidroid:nametag" then
		local item = minetest.registered_items["maidroid:nametag"]
		item:on_place(clicker, { ref = self.object, type = "object" } )
		return -- avoid displaying gui
	end

	minetest.show_formspec(
		clicker:get_player_name(),
		"maidroid:gui",
		get_formspec(self, clicker, 1)
	)
	maidroid_buf[clicker:get_player_name()] = { self = self }
end

local function on_punch(self, puncher, _, tool_capabilities, _, damage)
	local player_controls = self.owner == "" or self:player_can_control(puncher)
	local stack = puncher:get_wielded_item()

	-- Tame unowned maidroids with a golden pie or a gold block
	if self.owner == "" and stack:get_name() == maidroid.tame_item then
		minetest.chat_send_player(puncher:get_player_name(), S("This maidroid is now yours"))
		self.owner = puncher:get_player_name()
		self:update_infotext()
		stack:take_item()
		puncher:set_wielded_item(stack)
	-- ensure player can control maidroid
	elseif not player_controls then
		return true
	-- Pause maidroids with 'control item'
	elseif stack:get_name() == control_item or stack:get_name() == "default:paper" then
		self.pause = not self.pause
		if self.pause == true then
			self.core.on_pause(self)
		else
			self.core.on_resume(self)
		end

		self:update_infotext()
	-- colorize maidroid accordingly when punched by dye
	elseif minetest.get_item_group(stack:get_name(), "dye") > 0 then
		local color = puncher:get_wielded_item():get_name():sub(5)
		local can_process = false
		for _, dye in ipairs(dye.dyes) do
			if dye[1] == color then
				can_process = true
				break
			end
		end
		if can_process then
			local textures = { maidroid.generate_texture( color ) }
			self.object:set_properties( { textures = textures } )
			self.textures = textures

			stack:take_item()
			puncher:set_wielded_item(stack)
		end
	-- Heal
	elseif stack:get_name() == "default:mese_crystal_fragment"
		or stack:get_name() == "default:tin_lump" then
		stack = self:heal(stack)
		puncher:set_wielded_item(stack)
	-- damage your maidroids if your current item is fleshy
	elseif tool_capabilities.damage_groups.fleshy and
		tool_capabilities.damage_groups.fleshy > 1 and
		not minetest.is_creative_enabled(puncher) then
		local hp = math.max(self.object:get_hp(), 0)
		hp = math.max(hp - damage, 0)
		if hp == 0 then
			local pos = self.object:get_pos()
			local dist = distance_from_player and distance_from_player(self) or "unknown"
			lf("api", "MAIDROID DYING - nametag: " .. tostring(self.nametag) .. ", pos: " .. (pos and minetest.pos_to_string(pos) or "nil") .. ", distance from player: " .. tostring(dist) .. ", damage: " .. tostring(damage))

			for _, i_stack in pairs(self:get_inventory():get_list("main")) do
				minetest.add_item(random_pos_near(pos), i_stack)
			end
			minetest.add_item(random_pos_near(pos), ItemStack("default:bronze_ingot 7"))
			minetest.add_item(random_pos_near(pos), ItemStack("default:mese_crystal"))

			minetest.sound_play("maidroid_tool_capture_rod_use", {pos = self:get_pos()})
			minetest.add_particlespawner({
				amount = 20,
				time = 0.2,
				minpos = self:get_pos(),
				maxpos = self:get_pos(),
				minvel = {x = -1.5, y = 2, z = -1.5},
				maxvel = {x = 1.5,  y = 4, z = 1.5},
				minacc = {x = 0, y = -8, z = 0},
				maxacc = {x = 0, y = -4, z = 0},
				minexptime = 1,
				maxexptime = 1.5,
				minsize = 1,
				maxsize = 2.5,
				collisiondetection = false,
				vertical = false,
				texture = "maidroid_tool_capture_rod_star.png",
				player = puncher
			})
			self.wield_item:remove()
			if self.hat then
				self.hat:remove()
			end
			lf("api", "CALLING object:remove() for dying maidroid: " .. tostring(self.nametag))
			self.object:remove()
			return true
		end
		self.object:set_hp(hp)
		self:update_infotext()
	end
	return true
end

local null_vector = vector.new()
local halt = function(self)
	self.object:set_velocity(null_vector)
end

-- ,,rm
-- register_maidroid registers a definition of a new maidroid.
local register_maidroid = function(product_name, def)
	lf("api", "************************************************** register_maidroid = "..product_name)
	
	maidroid.registered_maidroids[product_name] = true

	def.collisionbox = {-0.25, -0.5, -0.25, 0.25, 0.625, 0.25}
	if minetest.has_feature("compress_zstd") then
		-- minetest version is >= 5.7.0
		def.selectionbox = {-0.2, -0.5, -0.2, 0.2, 0.625, 0.2, rotate = true }
	end

	-- register a definition of a new maidroid.
	minetest.register_entity(product_name, {
		-- basic initial properties
		hp_max   = 15,
		infotext = "",
		nametag  = "",
		mesh     = def.mesh,
		weight   = def.weight,
		textures = def.textures,

		is_visible   = true,
		physical     = true,
		stepheight   = 1.1,
		visual       = "mesh",
		collide_with_objects = true,
		makes_footstep_sound = true,
		collisionbox = def.collisionbox,
		selectionbox = def.selectionbox,

		-- extra initial properties
		skip = 0,
		core = nil,
		skiptime = 0,
		pause = false,
		tbchannel = "",
		owner = "",
		wield_item = nil,
		selected_tool = nil,
		need_core_selection = false,

		-- callback methods.
		on_activate    = on_activate,
		on_step        = on_step,
		on_rightclick  = on_rightclick,
		on_punch       = on_punch,
		get_staticdata = get_staticdata,
		on_deactivate  = function(self)
			all_maidroid_metrics.total_deactivated = (all_maidroid_metrics.total_deactivated or 0) + 1
			lf("api", "maidroid_on_deactivate CALLED - nametag: " .. tostring(self.nametag))
			if self._last_light_pos then
				local old = minetest.get_node(self._last_light_pos)
				if old and old.name == "maidroid:helper_light" then
					minetest.remove_node(self._last_light_pos)
				end
				self._last_light_pos = nil
			end
			
			if self.wield_item then
				lf("api", "Removing wield_item for maidroid: " .. tostring(self.nametag))
				self.wield_item:remove()
			end
			if self.hat then
				lf("api", "Removing hat for maidroid: " .. tostring(self.nametag))
				self.hat:remove()
			end
		end,
 
		-- extra methods.
		get_inventory      = get_inventory,
		get_front          = get_front,
		get_front_node     = get_front_node,
		get_look_direction = get_look_direction,
		get_player_name    = function(self)
			return self.owner or ""
		end,
		set_animation      = set_animation,
		set_yaw            = set_yaw,
		add_items_to_main  = add_items_to_main,
		is_named           = is_named,
		has_item_in_main   = has_item_in_main,
		change_direction   = change_direction,
		strong_change_direction = strong_change_direction,
		set_target_node    = set_target_node,
		update_infotext    = update_infotext,
		player_can_control = player_can_control,
		pickup_item        = pickup_item,
		select_core        = select_core,
		set_tool           = set_tool,
		heal               = heal,
		get_pos            = get_pos,
		is_on_ground       = is_on_ground,
		is_blocked         = is_blocked,
		toggle_entity_jump = toggle_entity_jump,
		halt               = halt,
	})

	-- register maidroid egg.
	-- ,,egg
	minetest.register_tool("maidroid:maidroid_egg", {
		description = S("Maidroid Egg"),
		inventory_image = def.egg_image,
		stack_max = 1,

		on_use = function(itemstack, user, pointed_thing)
			lf("api", "====================== maidroid_egg:on_use")

			if pointed_thing.above == nil then
				return nil
			end
			-- set maidroid's direction.
			local new_maidroid = minetest.add_entity(pointed_thing.above, "maidroid:maidroid")

			if new_maidroid then
				local rand = math.random(6)
				lf("api", "====================== maidroid_egg:rand="..tostring(rand))
				local m_skin = maid_skins[rand]
				-- Set the custom texture for the "maidroid:maidroid" entity
				new_maidroid:set_properties({
					textures = {m_skin}
				})

				-- assign a random display name (nametag) to the new maidroid
				local male_names = { "Dave", "Alex", "Max", "Kai", "Leo", "Finn", "Eli", "Sam", "Noah", "Jude" }
				local female_names = { "Ada", "Eve", "Luna", "Nova", "Iris", "Mira", "Zoe", "Kira", "Maidy", "Sera" }
				local names
				local skin = tostring(m_skin or "")
				if skin:find("Dave") then
					names = male_names
				elseif skin:find("Mary") then
					names = female_names
				else
					-- fallback: use both lists if skin not recognized
					error("")
					names = {}
					for _, n in ipairs(male_names) do table.insert(names, n) end
					for _, n in ipairs(female_names) do table.insert(names, n) end
				end
				local chosen = names[math.random(#names)]
				-- append a short random number to reduce chance of collisions
				local display_name = chosen .. "_" .. tostring(math.random(100,999))

				-- set on the luaentity and on the object so the nametag is visible immediately
				local lua = new_maidroid:get_luaentity()
				if lua then
					lua.nametag = display_name
				end
				new_maidroid:set_nametag_attributes({ text = display_name, color = { a = 255, r = 96, g = 224, b = 96 } })

                mydump("maidroid_egg_on_use", "====================== maidroid_egg_on_use", new_maidroid:get_properties())
				-- print(new_maidroid:get_properties())

				-- new_maidroid:get_luaentity().set_set_textures({ { name = m_skin } })
			end
			new_maidroid:get_luaentity():set_yaw(new_maidroid:get_pos(), user:get_pos())
			new_maidroid:get_luaentity().owner = ""
			new_maidroid:get_luaentity():update_infotext()

			itemstack:take_item()
			return itemstack
		end,
	})
end

-- Register a rotation for a specific wield item. Base is (-75,0,90)
maidroid.register_tool_rotation = function(itemname, r_shift)
	tool_rotation[itemname] = r_shift
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "maidroid:gui" then
		return
	end

	local player_name = player:get_player_name()
	if not maidroid_buf[player_name] then
		return
	end

	local droid = maidroid_buf[player_name].self
	if not maidroid.is_maidroid(droid.name) then
		return
	end

	if fields.tabheader then -- Switch tab
		minetest.show_formspec(player_name, "maidroid:gui",
			get_formspec(droid, player, tonumber(fields.tabheader)))
		return
	end

	if fields.flush then -- Flush maidroid inventory
		flush(droid, {})
		minetest.show_formspec(player_name, "maidroid:gui",
			get_formspec(droid, player, 2))
		return
	end

	if fields.channel then
		if fields.channel ~= droid.tbchannel then -- Change pipeworks channel
			if set_tube(droid, fields.channel) then
				minetest.show_formspec(player_name, "maidroid:gui",
					get_formspec(droid, player, 2))
			end
		end
		return
	end
	
	-- Cooker tab field handling
	if fields.toggle_cooker then
		-- Toggle cooker functionality
		if droid.pause then
			droid.pause = false
			if droid.core and droid.core.on_resume then
				droid.core.on_resume(droid)
			end
			minetest.chat_send_player(player_name, "Cooker resumed")
		else
			droid.pause = true
			if droid.core and droid.core.on_pause then
				droid.core.on_pause(droid)
			end
			minetest.chat_send_player(player_name, "Cooker paused")
		end
		-- Refresh the formspec
		local current_tab = droid.current_tab or 1
		minetest.show_formspec(player_name, "maidroid:gui",
			get_formspec(droid, player, current_tab))
		return
	end
	
	-- Craftable pagination handling
	if fields.craftable_prev then
		-- Go to previous page
		local current_page = droid.craftable_page or 1
		if current_page > 1 then
			droid.craftable_page = current_page - 1
		end
		-- Refresh the formspec
		local current_tab = droid.current_tab or 1
		minetest.show_formspec(player_name, "maidroid:gui",
			get_formspec(droid, player, current_tab))
		return
	end
	
    -- ,,x1
	if fields.craftable_next then
		-- Go to next page
		local current_page = droid.craftable_page or 1
		local craftable_outputs = {}
		if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.get_craftable_outputs then
			craftable_outputs = maidroid.cores.generic_cooker.get_craftable_outputs() or {}
		end
		if type(craftable_outputs) ~= "table" or #craftable_outputs == 0 then
			craftable_outputs = init_craftable_outputs
		end
		
		local items_per_page = 12
		local total_pages = math.ceil(#craftable_outputs / items_per_page)
		
		if current_page < total_pages then
			droid.craftable_page = current_page + 1
		end
		-- Refresh the formspec
		local current_tab = droid.current_tab or 1
		minetest.show_formspec(player_name, "maidroid:gui",
			get_formspec(droid, player, current_tab))
		return
	end
	
	-- Desirable pagination handling
	if fields.desirable_prev then
		-- Go to previous page
		local current_page = droid.desirable_page or 1
		if current_page > 1 then
			droid.desirable_page = current_page - 1
		end
		-- Refresh the formspec
		local current_tab = droid.current_tab or 1
		minetest.show_formspec(player_name, "maidroid:gui",
			get_formspec(droid, player, current_tab))
		return
	end
	
	if fields.desirable_next then
		-- Go to next page
		local current_page = droid.desirable_page or 1
		local desirable_outputs = {}
		
		-- Build complete list from all pages using helper function
		if type(droid.desirable_page_items) == "table" then
			desirable_outputs = maidroid.build_complete_desirable_list(droid)
		elseif type(droid.desired_craft_outputs) == "table" then
			-- Fallback to regular desired outputs if page tracking not set
			desirable_outputs = droid.desired_craft_outputs
		end
		
		if type(desirable_outputs) ~= "table" or #desirable_outputs == 0 then
			desirable_outputs = {}
		end
		
		local items_per_page = 6
		-- Always show at least 2 pages when there are desirable items
		local total_pages = math.max(2, math.ceil(#desirable_outputs / items_per_page))
		
		if current_page < total_pages then
			droid.desirable_page = current_page + 1
		end
		-- Refresh the formspec
		local current_tab = droid.current_tab or 1
		minetest.show_formspec(player_name, "maidroid:gui",
			get_formspec(droid, player, current_tab))
		return
	end
	
	if fields.set_distance or (fields.max_distance and fields.key_enter_field == "max_distance") then
		-- Set the max distance from activation
		local new_distance = tonumber(fields.max_distance)
		if new_distance and new_distance > 0 and new_distance <= 100 then
			-- Try to access the generic_cooker functions directly from the module
			local success = false
            success = maidroid.set_max_distance_from_activation(new_distance)
			-- if maidroid.cores.generic_cooker and maidroid.cores.generic_cooker.set_max_distance_from_activation then
			-- 	success = maidroid.cores.generic_cooker.set_max_distance_from_activation(new_distance)
            --     lf("api", "====================== function maidroid.cores.generic_cooker.set_max_distance_from_activation")
			-- elseif maidroid.set_max_distance_from_activation then
			-- 	-- Fallback to direct function access
			-- 	success = maidroid.set_max_distance_from_activation(new_distance)
            --     lf("api", "====================== function maidroid_set_distance_from_activation")
			-- else
			-- 	-- Last resort: set the setting directly
			-- 	minetest.settings:set("maidroid.generic_cooker.max_distance_from_activation", tostring(new_distance))
			-- 	-- Also try to set the external variable if it exists
			-- 	if maidroid.cores.generic_cooker then
			-- 		maidroid.cores.generic_cooker.max_distance_from_activation = new_distance
			-- 	end
			-- 	success = true
			-- end
			
			if success then
				minetest.chat_send_player(player_name, "Max distance from activation set to " .. new_distance .. " blocks")
			else
				minetest.chat_send_player(player_name, "Failed to set distance")
			end
		else
			minetest.chat_send_player(player_name, "Invalid distance. Please enter a number between 1 and 100.")
		end
		-- Refresh the formspec to show updated value
		local current_tab = droid.current_tab or 1
		minetest.show_formspec(player_name, "maidroid:gui",
			get_formspec(droid, player, current_tab))
		return
	end
	
	if fields.view_metrics then
		-- Show metrics in chat
		if maidroid.get_chest_taken_metrics then
			local chest_metrics = maidroid.get_chest_taken_metrics()
			local output = {"Cooker Metrics:"}
			
			if next(chest_metrics) == nil then
				output[#output + 1] = "No items taken from chests yet."
			else
				for item_name, count in pairs(chest_metrics) do
					output[#output + 1] = string.format("%s: %d", item_name, count)
				end
			end
			
			for _, line in ipairs(output) do
				minetest.chat_send_player(player_name, line)
			end
		else
			minetest.chat_send_player(player_name, "Metrics function not available")
		end
		return
	end
	-- Handle checkbox changes for cooker settings
	if fields.auto_craft or fields.auto_fuel or fields.auto_collect then
		-- Store cooker settings (you could add these to the maidroid's staticdata)
		local settings = droid._cooker_settings or {}
		settings.auto_craft = fields.auto_craft == "true"
		settings.auto_fuel = fields.auto_fuel == "true"
		settings.auto_collect = fields.auto_collect == "true"
		droid._cooker_settings = settings
		
		minetest.chat_send_player(player_name, "Cooker settings updated")
		return
	end

	maidroid_buf[player_name] = nil
	return true
end)

register_maidroid( "maidroid:maidroid", {
	hp_max     = 15,
	weight     = 20,
	-- mesh       = "maidroid.b3d",
	mesh       = "character.b3d",
	textures   = {"character_Mary_LT_mt.png"},
	-- textures   = {m_skin},
	egg_image  = "maidroid_maidroid_egg.png",
})
-- textures   = { "[combine:40x40:0,0=maidroid_base.png:24,32=maidroid_eyes_white.png" },
-- textures   = { "maidroid_base.png" },
-- textures2   = { "[combine:40x40:0,0=maidroid_base.png:24,32=maidroid_eyes_white.png" },
-- textures   = { "[combine:40x40:0,0=maidroid_base.png:24,32=maidroid_eyes_white.png" },

-- Compatibility with tagicar maidroids
-- ,,x1
-- if maidroid.settings.compat then
if false then
	for i,_ in ipairs(dye.dyes) do
		local product_name = "maidroid:maidroid_mk" .. tostring(i)
		local texture_name = maidroid.generate_texture(i)
		local egg_img_name = "maidroid_maidroid_egg.png"
		register_maidroid(product_name, {
			hp_max     = 15000,
			weight     = 20,
			mesh       = "maidroid.b3d",
			textures   = { texture_name },
			egg_image  = egg_img_name,
		})

		minetest.register_alias("maidroid:maidroid_mk" .. i .. "_egg", "maidroid:maidroid_egg")
		minetest.register_alias("maidroid_tool:captured_maidroid_mk" .. i .. "_egg", ":maidroid_tool:captured_maidroid_egg")
	end
end

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
