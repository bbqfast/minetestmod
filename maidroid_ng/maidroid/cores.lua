------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

maidroid.jump_velocity = 2.6

-- Behaviors
dofile(maidroid.modpath .. "/cores/wander.lua") -- Always init first
dofile(maidroid.modpath .. "/cores/path.lua") -- Use to_wander
dofile(maidroid.modpath .. "/cores/follow.lua")

-- Mandatory core
dofile(maidroid.modpath .. "/cores/basic.lua") -- Use wander and follow

-- Jobs
if maidroid.settings.farming then
	dofile(maidroid.modpath .. "/cores/farming.lua") -- Use: Wander
end
if maidroid.settings.torcher then
	dofile(maidroid.modpath .. "/cores/torcher.lua") -- Use: Follow
end

if maidroid.settings.ocr then
	dofile(maidroid.modpath .. "/cores/ocr.lua")
end

if maidroid.settings.stockbreeder then -- Use wander, path
	dofile(maidroid.modpath .. "/cores/stockbreeder.lua")
end

if maidroid.settings.waffler then -- Use wander, (todo path)
	dofile(maidroid.modpath .. "/cores/waffler.lua")
end
-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
