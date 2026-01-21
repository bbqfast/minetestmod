-- local modpath = minetest.get_modpath("snacks")
-- if modpath then
--     minetest.log("action", "basic_snacks modpath: " .. modpath)
--     dofile(modpath .. "/cooking.lua")
-- else
--     minetest.log("error", "Failed to get modpath for basic_snacks")
-- end

local lf = assert(_G.lf, "global lf not initialized")


snacks = snacks or {}
local snacks_damage_buffs = {}
local snacks_defense_buffs = {}

function snacks.apply_damage_buff(player, multiplier, duration)
	local name = player and player:get_player_name()
	if not name then
		return
	end
	local expire = minetest.get_gametime() + (duration or 0)
	snacks_damage_buffs[name] = {multiplier = multiplier or 1, expire = expire}
end

function snacks.get_damage_multiplier(player)
	local name = player and player:get_player_name()
	if not name then
		return nil
	end
	local buff = snacks_damage_buffs[name]
	if not buff then
		return nil
	end
	if buff.expire and minetest.get_gametime() > buff.expire then
		snacks_damage_buffs[name] = nil
		return nil
	end
	return buff.multiplier or 1
end

function snacks.apply_defense_buff(player, multiplier, duration)
	local name = player and player:get_player_name()
	if not name then
		return
	end
	local expire = minetest.get_gametime() + (duration or 0)
	snacks_defense_buffs[name] = {multiplier = multiplier or 1, expire = expire}
end

function snacks.get_defense_multiplier(player)
	local name = player and player:get_player_name()
	if not name then
		return nil
	end
	local buff = snacks_defense_buffs[name]
	if not buff then
		return nil
	end
	if buff.expire and minetest.get_gametime() > buff.expire then
		snacks_defense_buffs[name] = nil
		return nil
	end
	return buff.multiplier or 1
end

minetest.register_on_leaveplayer(function(player)
	local name = player and player:get_player_name()
	if not name then
		return
	end
	snacks_damage_buffs[name] = nil
	snacks_defense_buffs[name] = nil
end)

minetest.register_on_player_hpchange(function(player, hp_change, reason)
    local rtype = reason and reason.type or "nil"
    lf("register_on_player_hpchange",
        "player: " .. player:get_player_name() ..
        " hp_change: " .. tostring(hp_change) ..
        " reason: " .. rtype)

    if hp_change >= 0 then
		return hp_change
	end
	if not reason or reason.type ~= "punch" then
		return hp_change
	end
	if not snacks or not snacks.get_defense_multiplier then
		return hp_change
	end
	local mult = snacks.get_defense_multiplier(player)
	if not mult or mult <= 0 then
		return hp_change
	end

	return hp_change * mult
end, true)

lf("init", "basic_snacks finished registering on_player_hpchange")

dofile(minetest.get_modpath("snacks").."/crafts.lua")
dofile(minetest.get_modpath("snacks").."/cooking.lua")
dofile(minetest.get_modpath("snacks").."/lt_people.lua")
