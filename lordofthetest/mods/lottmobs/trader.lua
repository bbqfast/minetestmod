--This code comes almost exclusively from the trader and inventory of mobf, by Sapier.
--The copyright notice bellow is from mobf:
-------------------------------------------------------------------------------
-- Mob Framework Mod by Sapier
--
-- You may copy, use, modify or do nearly anything except removing this
-- copyright notice.
-- And of course you are NOT allow to pretend you have written it.
--
--! @file inventory.lua
--! @brief component containing mob inventory related functions
--! @copyright Sapier
--! @author Sapier
--! @date 2013-01-02
--
--! @defgroup Inventory Inventory subcomponent
--! @brief Component handling mob inventory
--! @ingroup framework_int
--! @{
--
-- Contact sapier a t gmx net
-------------------------------------------------------------------------------

local lf = assert(_G.lf, "global lf not initialized")

-- ,,allow
function lottmobs.allow_move(inv, from_list, from_index, to_list, to_index, count, player)
	-- lf("allow_move", "inv=" .. dump(inv) .. ", from_list=" .. dump(from_list) .. ", from_index=" .. dump(from_index) .. ", to_list=" .. dump(to_list) .. ", to_index=" .. dump(to_index) .. ", count=" .. dump(count) .. ", player=" .. dump(player))
	lf("allow_move", "Attempting to move items from " .. from_list .. " to " .. to_list .. " by player: " .. player:get_player_name())
	if (from_list == "selection" and to_list == "goods") then
		lf("allow_move", "Allowing move from selection to goods")
		local old_stack = inv.get_stack(inv, from_list, from_index)
		-- Log all items in the inventory for debugging
		for _, listname in ipairs(inv:get_lists()) do
			local list = inv:get_list(listname)
			if list then
				lf("allow_move", "Inventory list '" .. listname .. "':")
				for idx, stack in ipairs(list) do
					if not stack:is_empty() then
						lf("allow_move", "  Slot " .. idx .. ": " .. stack:to_string())
					end
				end
			end
		end

		-- Clear the price when moving items back from selection to goods
		inv.set_stack(inv, "price", 1, nil)

		if count ~= old_stack:get_count() then
			return 0
		end
		return count
	end

	
	if to_list ~= "selection" or
		from_list == "price" or
		from_list == "payment" or
		from_list == "takeaway" or
		from_list == "identifier" then
		return 0
	end

	-- forbid moving of parts of stacks
	local old_stack = inv.get_stack(inv, from_list, from_index)
	lf("allow_move", "Inventory: " .. dump(inv))
	lf("allow_move", "Old stack: " .. dump(old_stack:to_table()))
	if count ~= old_stack.get_count(old_stack) then
		return 0;
	end
	return count
end

function lottmobs.allow_put(inv, listname, index, stack, player)
	if listname == "payment" then
		return 99
	end
	return 0
end

function lottmobs.allow_take(inv, listname, index, stack, player)
	lf("allow_take", "Player " .. player:get_player_name() .. " is attempting to take items from " .. listname)
	if listname == "takeaway" or
		listname == "payment" then
		return 99
	else
		return 0
	end
end

function lottmobs.on_put(inv, listname, index, stack)
	if listname == "payment" then
		lottmobs.update_takeaway(inv)
	end
end

function lottmobs.on_take(inv, listname, count, index, stack, player)
	if listname == "takeaway" then
		local amount = inv:get_stack("payment",1):get_count()
		local price = inv:get_stack("price",1):get_count()
		local thing = inv:get_stack("payment",1):get_name()
		inv.set_stack(inv,"selection",1,nil)
		inv.set_stack(inv,"price",1,nil)
		inv.set_stack(inv,"takeaway",1,nil)
		inv.set_stack(inv,"payment",1,thing .. " " .. amount-price)
	end

	if listname == "payment" then
		if lottmobs.check_pay(inv,false) then
			local selection = inv.get_stack(inv,"selection", 1)
			if selection ~= nil then
				inv.set_stack(inv,"takeaway",1,selection)
			end
		else
			inv.set_stack(inv,"takeaway",1,nil)
		end
	end
end

function lottmobs.update_takeaway(inv)
	if lottmobs.check_pay(inv,false) then
		local selection = inv.get_stack(inv,"selection", 1)

		if selection ~= nil then
			inv.set_stack(inv,"takeaway",1,selection)
		end
	else
		inv.set_stack(inv,"takeaway",1,nil)
	end
end

function lottmobs.check_pay(inv,paynow)
	local now_at_pay = inv.get_stack(inv,"payment",1)
	local count = now_at_pay.get_count(now_at_pay)
	local name  = now_at_pay.get_name(now_at_pay)

	local price = inv.get_stack(inv,"price", 1)

	if price:get_name() == name then
		local price = price:get_count()
		if price > 0 and
			price <= count then
			if paynow then
				now_at_pay.take_item(now_at_pay,price)
				inv.set_stack(inv,"payment",1,now_at_pay)
				return true
			else
				return true
			end
		else
			if paynow then
				inv.set_stack(inv,"payment",1,nil)
			end
		end
	end

	return false
end
lottmobs.trader_inventories = {}

function lottmobs.add_goods(entity, race, same_race)
	lf("add_goods", "Entity value: " .. dump(entity))

	lf("add_goods", "Adding goods for trader entity: " .. tostring(entity) .. ", race: " .. tostring(race))
	local goods_to_add = nil
	for i=1,15 do
		if same_race == true then
			if math.random(0, 100) > race.items_race[i][3] then
				lottmobs.trader_inventory.set_stack(lottmobs.trader_inventory,"goods", i, race.items_race[i][1])
			end
		else
			if math.random(0, 100) > race.items[i][3] then
				lottmobs.trader_inventory.set_stack(lottmobs.trader_inventory,"goods", i, race.items[i][1])
			end
		end
	end
end

function lottmobs.face_pos(self,pos)
	local s = self.object:get_pos()
	local vec = {x=pos.x-s.x, y=pos.y-s.y, z=pos.z-s.z}
	local yaw = math.atan2(vec.z,vec.x)-math.pi/2
	if self.drawtype == "side" then
		yaw = yaw+(math.pi/2)
	end
	self.object:set_yaw(yaw)
	return yaw
end
----

function lottmobs_trader(self, clicker, entity, race, image, priv)
	lf("lottmobs_trader", "Race: " .. dump(race))

	-- lf("lottmobs_trader", "Self: " .. dump(self))

	lottmobs.face_pos(self, clicker:get_pos())
	local player = clicker:get_player_name()
	-- if self.id == 0 then
	if self.id == 0 or self.id == nil then
		self.id = (math.random(1, 1000) * math.random(1, 10000)) .. self.name .. (math.random(1, 1000) ^ 2)
	end
	if self.game_name == "mob" then
		self.game_name = tostring(race.names[math.random(1,#race.names)])
		--self.nametag = self.game_name
	end
	local unique_entity_id = self.id
	lf("lottmobs_trader", "Trader ID: " .. tostring(self.id))
	local is_inventory = minetest.get_inventory({type="detached", name=unique_entity_id})
	local same_race = false
	if minetest.get_player_privs(player)[priv] ~= nil then
		same_race = true
	end
	local move_put_take = {
		allow_move = lottmobs.allow_move,
		allow_put = lottmobs.allow_put,
		allow_take = lottmobs.allow_take,
		on_move = function(inventory, from_list, from_index, to_list, to_index, count, player)
			lf("lottmobs_trader.on_move", "Moving items from " .. tostring(from_list) .. " to " .. tostring(to_list))
			lf("lottmobs_trader.on_move", "From index: " .. tostring(from_index) .. ", to index: " .. tostring(to_index))
			lf("lottmobs_trader.on_move", "Count: " .. tostring(count))
			if from_list == "goods" and to_list == "selection" then
				lf("lottmobs_trader.on_move", "Condition: from_list == 'goods' and to_list == 'selection'")
				local inv = inventory
				local moved = inv.get_stack(inv, to_list, to_index)
				local goodname = moved.get_name(moved)
				local elements = moved.get_count(moved)
				lf("lottmobs_trader.on_move", "Item moved: " .. tostring(goodname) .. ", elements: " .. tostring(elements))
				if elements > count then
					lf("lottmobs_trader.on_move", "Condition: elements > count, splitting stack")
					inv.set_stack(inv, "selection", 1, goodname .. " " .. tostring(count))
					inv.set_stack(inv, "goods", from_index, goodname .. " " .. tostring(elements - count))
					elements = count
				else
					lf("lottmobs_trader.on_move", "Condition: elements <= count, no split needed")
				end
				local good = nil
				if same_race == true then
					lf("lottmobs_trader.on_move", "Condition: same_race == true")
					for i = 1, #race.items_race, 1 do
						local stackstring = goodname .. " " .. tostring(count)
						lf("lottmobs_trader.on_move", "Checking items_race[" .. tostring(i) .. "]: " .. tostring(race.items_race[i][1]) .. " vs " .. stackstring)
						if race.items_race[i][1] == stackstring then
							lf("lottmobs_trader.on_move", "Match found in items_race at index " .. tostring(i))
							good = race.items_race[i]
						end
					end
				else
					lf("lottmobs_trader.on_move", "Condition: same_race == false")
					for i = 1, #race.items, 1 do
						local stackstring = goodname .. " " .. tostring(count)
						lf("lottmobs_trader.on_move", "Checking items[" .. tostring(i) .. "]: " .. tostring(race.items[i][1]) .. " vs " .. stackstring)
						if race.items[i][1] == stackstring then
							lf("lottmobs_trader.on_move", "Match found in items at index " .. tostring(i))
							good = race.items[i]
						end
					end
				end
				if good ~= nil then
					lf("lottmobs_trader.on_move", "Condition: good ~= nil, setting price: " .. tostring(good[2]))
					inventory.set_stack(inventory, "price", 1, good[2])
				else
					lf("lottmobs_trader.on_move", "Condition: good == nil, clearing price")
					inventory.set_stack(inventory, "price", 1, nil)
				end
				lottmobs.update_takeaway(inv)
			else
				lf("lottmobs_trader.on_move", "Condition: Not goods -> selection, ignoring")
			end
		end,
		on_put = lottmobs.on_put,
		on_take = lottmobs.on_take
	}
	if is_inventory == nil then
		lottmobs.trader_inventory = minetest.create_detached_inventory(unique_entity_id, move_put_take)
		lottmobs.trader_inventory.set_size(lottmobs.trader_inventory,"goods",15)
		lottmobs.trader_inventory.set_size(lottmobs.trader_inventory,"takeaway",1)
		lottmobs.trader_inventory.set_size(lottmobs.trader_inventory,"selection",1)
		lottmobs.trader_inventory.set_size(lottmobs.trader_inventory,"price",1)
		lottmobs.trader_inventory.set_size(lottmobs.trader_inventory,"payment",1)
		-- lf("lottmobs_trader", "Logging race: " .. dump(race))

		lottmobs.add_goods(entity, race, same_race)
	end
	if race.quotes and type(race.quotes) == "table" and #race.quotes > 0 then
		self.current_quote_index = 1
		minetest.chat_send_player(player, "[NPC] <Trader " .. self.game_name .. "> " .. race.quotes[self.current_quote_index])
		local quotes_timer = minetest.get_us_time()
		local function send_next_quote()
			self.current_quote_index = self.current_quote_index + 1
			if self.current_quote_index > #race.quotes then return end
			minetest.chat_send_player(player, "[NPC] <Trader " .. self.game_name .. "> " .. race.quotes[self.current_quote_index])
			minetest.after(2, send_next_quote)
		end
		minetest.after(2, send_next_quote)
	else
		minetest.chat_send_player(player, "[NPC] <Trader " .. self.game_name .. "> Hello, " .. player .. ", have a look at my wares.")
	end

	minetest.chat_send_player(player, "[NPC] <Trader " .. self.game_name .. "> Hello, " .. player .. ", welcome to my shop.")
	minetest.show_formspec(player, "trade",
		"size[8,10;]" ..
		 "background[5,5;1,1;" .. image .. ";true]" ..
		"label[0,0;Trader " .. self.game_name .. "'s stock:]" ..
		"list[detached:" .. unique_entity_id .. ";goods;.5,.5;3,5;]" ..
		"label[4.5,0.5;Selection]" ..
		"list[detached:" .. unique_entity_id .. ";selection;4.5,1;5.5,2;]" ..
		"label[6,0.5;Price]" ..
		"list[detached:" .. unique_entity_id .. ";price;6,1;7,2;]" ..
		"label[4.5,3.5;Payment]" ..
		"list[detached:" .. unique_entity_id .. ";payment;4.5,4;5.5,5;]" ..
		"label[6,3.5;Brought items]" ..
		"list[detached:" .. unique_entity_id .. ";takeaway;6,4;7.5,5.5;]" ..
		"list[current_player;main;0,6;8,4;]"
	)
end
