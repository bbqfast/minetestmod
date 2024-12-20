-- local modpath = minetest.get_modpath("snacks")
-- if modpath then
--     minetest.log("action", "basic_snacks modpath: " .. modpath)
--     dofile(modpath .. "/cooking.lua")
-- else
--     minetest.log("error", "Failed to get modpath for basic_snacks")
-- end

dofile(minetest.get_modpath("snacks").."/crafts.lua")
dofile(minetest.get_modpath("snacks").."/cooking.lua")
