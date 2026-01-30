------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local entry_time = os.clock()

-- Fallback file for maidroid position storage when mod storage is unavailable
local maidroid_pos_file = nil
do
	local worldpath = minetest.get_worldpath and minetest.get_worldpath() or "."
	-- maidroid_pos_file = worldpath .. "/maidroid_positions.txt"
	local player_name = minetest.localplayer and minetest.localplayer:get_name() or "player"
	maidroid_pos_file = worldpath .. "/maidroid_positions_" .. player_name .. ".txt"


end

maidroid = maidroid or {}

local last_lf_func = nil
local last_lf_msg = nil
local last_lf_count = 0
local last_lf_time = 0

maidroid.lf = function(func, msg)
	local pre = "++++++++++++++++++++++++"
	if func == nil then func = "unknown" end
	if msg == nil then msg = "null" end

	local black_list = {}
	black_list["select_seed"] = true
	black_list["mow"] = true
	black_list["follow:on_step"] = true
	black_list["maidroid.globalstep"] = true

	if black_list[func] ~= nil then
		return
	end

    msg = string.format("[%s]: %s", func, msg)

	if func == last_lf_func and msg == last_lf_msg then
		last_lf_count = last_lf_count + 1
		return
	end

	if last_lf_msg ~= nil then
		local suffix = ""
		if last_lf_count > 1 then
			suffix = " (" .. tostring(last_lf_count) .. ")"
		end
		minetest.log("warning", pre .. last_lf_msg .. suffix)
	end

	last_lf_func = func
	last_lf_msg = msg
	last_lf_count = 1
	last_lf_time = os.clock()
	local scheduled_time = last_lf_time
	minetest.after(2, function(check_time)
		-- Flush only if no newer lf call has updated last_lf_time
		if last_lf_msg ~= nil and last_lf_time == check_time then
			local suffix = ""
			if last_lf_count > 1 then
				suffix = " (" .. tostring(last_lf_count) .. ")"
			end
			minetest.log("warning", pre .. last_lf_msg .. suffix)
			last_lf_func = nil
			last_lf_msg = nil
			last_lf_count = 0
		end
	end, scheduled_time)
end

local lf = maidroid.lf

-- maidroid = maidroid or {}

maidroid.helpers = {} -- helpers functions
maidroid.modname = minetest.get_current_modname()
maidroid.modpath = minetest.get_modpath(maidroid.modname)

print("[MOD] " .. maidroid.modname .. " loading")

if minetest.get_translator ~= nil then
	maidroid.translator = minetest.get_translator(maidroid.modname)
else
	maidroid.translator = function ( s ) return s end
end

dofile(maidroid.modpath .. "/settings.lua")
dofile(maidroid.modpath .. "/helpers.lua")
dofile(maidroid.modpath .. "/api.lua")
dofile(maidroid.modpath .. "/register.lua")
dofile(maidroid.modpath .. "/cores.lua")
dofile(maidroid.modpath .. "/pie.lua")

dofile(maidroid.modpath .. "/tools/nametag.lua")
if maidroid.settings.tools_capture_rod then
	dofile(maidroid.modpath .. "/tools/capture_rod.lua")
end
if maidroid.settings.tools_robbery_stick then
	dofile(maidroid.modpath .. "/tools/robbery_stick.lua")
end


print(string.format("[MOD] %s loaded in %.4fs", maidroid.modname, os.clock() - entry_time))
-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua



local timer = 0

local function append_maidroid_positions_from_storage(res)
	if not minetest.get_mod_storage then
		return
	end
	local storage = minetest.get_mod_storage()
	if not storage then
		return
	end
	local tbl = storage:to_table()
	if not (tbl and tbl.fields) then
		return
	end
	for key, value in pairs(tbl.fields) do
		if key:sub(1,13) == "maidroid_pos_" then
			local maidname = key:sub(14)
			table.insert(res, maidname .. ": " .. value)
		end
	end
end

local function append_maidroid_positions_from_file(out)
	if not maidroid_pos_file then
		return false
	end
	local f = io.open(maidroid_pos_file, "r")
	if not f then
		return false
	end
	for line in f:lines() do
		line = line:gsub("\r$", "")
		if line ~= "" then
			lf("maidroid_list", "Found maidroid position: " .. line)
			table.insert(out, line)
		end
	end
	f:close()
	return true
end

-- ,,command
minetest.register_chatcommand("maidroid_list", {
	description = "List all Maidroids' names and stored positions",
	privs = {server=true},
	func = function(name)
		local res = {}
		local used_fallback = false
		-- Try mod storage first
		append_maidroid_positions_from_storage(res)
		-- Fallback: read from text file when nothing was found in mod storage
		if #res == 0 then

			used_fallback = append_maidroid_positions_from_file(res)
		end
		if #res == 0 then
			if used_fallback then
				return true, "No maidroid positions stored in fallback file."
			end
			return true, "No maidroid positions stored."
		end

		local output = {"Maidroid positions:"}
		local max_lines = 30
		local max_total_chars = 3500
		local count = 0
		local total_chars = #output[1] + 1
		for _, line in ipairs(res) do
			count = count + 1
			if count > max_lines or total_chars + #line + 1 > max_total_chars then
				table.insert(output, ("... (%d more omitted)"):format(#res - (count-1)))
				break
			end
			table.insert(output, line)
			total_chars = total_chars + #line + 1
		end
		return true, table.concat(output, "\n")
	end
})

minetest.register_chatcommand("maidroid_tp", {
	description = "Teleport to a maidroid by name",
	privs = {server=true},
	params = "<maidroid_name>",
	func = function(name, param)
		local target_name = param:match("^%s*(.-)%s*$")
		if not target_name or target_name == "" then
			return false, "Usage: /maidroid_tp <maidroid_name>"
		end

		-- //,,x1
		-- HACK: append_maidroid_positions_from_file may fill out but return false if file not found at first but later lines exist
		local hack_check = {}
		append_maidroid_positions_from_file(hack_check)
		if #hack_check > 0 then
			positions = hack_check
		end

		local positions = {}
		if not append_maidroid_positions_from_file(positions) or #positions == 0 then
			return false, "No maidroid positions found in fallback file."
		end

		local found_pos
		for _, line in ipairs(positions) do
			local maidname, pos_str = line:match("^([^:]+):%s*(.+)$")
			lf("maidroid_tp", "Checking maidroid nametag for storage: nametag=" .. tostring(maidname))
			if maidname and pos_str and maidname == target_name then
				found_pos = minetest.string_to_pos(pos_str)
				break
			end
		end

		if not found_pos then
			return false, "No maidroid named '" .. target_name .. "' found in fallback file."
		end

		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end

		player:set_pos(found_pos)
		return true, "Teleported to maidroid '" .. target_name .. "' at " .. minetest.pos_to_string(found_pos)
	end
})



local function save_maidroid_pos_fallback(nametag, pos_str)
	local lines = {}
	local rf = io.open(maidroid_pos_file, "r")
	if rf then
		for line in rf:lines() do
			local name = line:match("^([^:]+):")
			if name ~= nametag then
				table.insert(lines, line)
			end
		end
		rf:close()
	end
	table.insert(lines, nametag .. ": " .. pos_str)
	local wf = io.open(maidroid_pos_file, "w")
	if wf then
		lf("globalstep", "Saving position for " .. nametag .. " in fallback file (" .. tostring(maidroid_pos_file) .. "): " .. pos_str)
		wf:write(table.concat(lines, "\n") .. "\n")
		wf:close()
	else
		lf("globalstep", "Failed to open fallback file for writing: " .. tostring(maidroid_pos_file))
	end
end


minetest.register_globalstep(function(dtime)
	    local func_name = "maidroid.globalstep"
	    timer = timer + dtime
	    if timer < 10 then return end
	    timer = 0
	    local players = minetest.get_connected_players()
	    local maidroids_far = {}
	    for _, player in ipairs(players) do
	        local ppos = player:get_pos()
	        local objs = minetest.get_objects_inside_radius(ppos, 500) -- big radius
	        for _, obj in ipairs(objs) do
	            local ent = obj:get_luaentity()
	            if ent and maidroid.is_maidroid(ent.name) then
	                -- "inactive" example: paused or IDLE state
	                lf(func_name, "[maidroid] ACTIVE maidroid far from players: " .. tostring(ent.nametag or ent.name) .. " at " .. minetest.pos_to_string(obj:get_pos()))
	                lf(func_name, "Checking maidroid nametag for storage: nametag=" .. tostring(ent.nametag))
	                if ent.nametag and ent.nametag ~= "" then
	                    lf(func_name, "nametag is present: " .. ent.nametag)
	                    local pos = vector.round(obj:get_pos())
	                    local pos_str = minetest.pos_to_string(pos)
	                    local stored = false
	                    -- Prefer mod storage when available
	                    if minetest.get_mod_storage then
	                        lf(func_name, "get_mod_storage available")
	                        local storage = minetest.get_mod_storage()
	                        if storage then
	                            lf(func_name, "mod storage obtained")
	                            lf(func_name, "Saving position for " .. ent.nametag .. " in mod storage: " .. pos_str)
	                            storage:set_string("maidroid_pos_" .. ent.nametag, pos_str)
	                            stored = true
	                        else
	                            lf(func_name, "mod storage unavailable (nil)")
	                        end
	                    else
	                        lf(func_name, "get_mod_storage not available")
	                    end
	                    -- Fallback: write to text file if mod storage failed
	                    if (not stored) and maidroid_pos_file then

	                        local ok, err = pcall(save_maidroid_pos_fallback, ent.nametag, pos_str)
	                        if not ok then
	                            lf(func_name, "Error writing fallback file: " .. tostring(err))
	                        end
	                    end
	                    -- lf(func_name, "nametag missing or empty")
	                end

	                local inactive = ent.pause or ent.state == maidroid.states.IDLE
	                if inactive then
	                    -- find nearest player distance
	                    local min_dist = math.huge
	                    for _, p2 in ipairs(players) do
	                        local d = vector.distance(obj:get_pos(), p2:get_pos())
	                        if d < min_dist then min_dist = d end
	                    end
	                    if min_dist > 200 then -- choose your threshold
	                        table.insert(maidroids_far, {ent = ent, dist = min_dist})
	                    end
	                end
	            end
	        end
	    end

	    -- e.g. log them occasionally
	    for _, info in ipairs(maidroids_far) do
	        minetest.log("warning",
	            "[maidroid] far inactive maidroid: "
	            .. (info.ent.nametag or "<unnamed>") ..
	            " at " .. minetest.pos_to_string(vector.round(info.ent:get_pos())) ..
	            " dist=" .. math.floor(info.dist))
	    end
end)