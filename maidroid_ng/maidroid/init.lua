------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local entry_time = os.clock()

maidroid = {}

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
