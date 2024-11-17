------------------------------------------------------------
-- Copyleft (Я) 2022-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

-- Declare mods
local mods = {}
mods.pipeworks      = nil ~= minetest.get_modpath("pipeworks") and
			minetest.settings:get_bool("pipeworks_enable_teleport_tube", true)


mods.better_farming = nil ~= minetest.get_modpath("better_farming")
mods.farming        = minetest.global_exists("farming")
mods.cucina_vegana  = nil ~= minetest.get_modpath("cucina_vegana")
mods.ethereal       = nil ~= minetest.get_modpath("ethereal")
mods.sickles        = nil ~= minetest.get_modpath("sickles")

mods.animal         = nil ~= minetest.get_modpath("mobs_animal")
mods.animalia       = nil ~= minetest.get_modpath("animalia")
mods.petz           = nil ~= minetest.get_modpath("petz")

mods.pdisc          = nil ~= minetest.get_modpath("pdisc")
mods.pie            = nil ~= minetest.get_modpath("pie")
mods.waffles        = nil ~= minetest.get_modpath("waffles")
maidroid.mods = mods

-- Settings
local m_settings = {}
local timers = {}
maidroid.timers = timers
maidroid.settings = m_settings

local g_settings = minetest.settings

local arrange_number = function(number, min, max, integer)
	number = tonumber(number)
	number = math.max(number, min)
	number = math.min(number, max)
	if integer then
		number = math.floor(number)
	end
	return number
end

m_settings.compat = g_settings:get_bool("maidroid.compat")
	or g_settings:get_bool("maidroid_compat", false)

m_settings.skip = g_settings:get("maidroid.skip_steps") or 0
m_settings.skip = arrange_number(m_settings.skip, 0, 10, true) + 1

m_settings.speed = arrange_number(g_settings:get("maidroid.speed") or 0.7, 0.4, 1)
m_settings.hat = g_settings:get_bool("maidroid.hat", true)

-- Optional cores
m_settings.torcher = g_settings:get_bool("maidroid.torcher", true)
m_settings.farming = mods.farming and g_settings:get_bool("maidroid.farming", true)
m_settings.ocr = mods.pdisc and g_settings:get_bool("maidroid.ocr", true)
m_settings.stockbreeder = ( mods.petz or mods.animalia or mods.animal )
	and g_settings:get_bool("maidroid.stockbreeder", true)
m_settings.waffler = mods.waffles and g_settings:get_bool("maidroid.waffler", true)

-- Tools
m_settings.tools_capture_rod = g_settings:get_bool("maidroid.tools.capture_rod")
	or g_settings:get_bool("maidroid_enable_capture_rod", true)
m_settings.tools_capture_rod_wears = g_settings:get_bool("maidroid.tools.capture_rod.wears")
	or g_settings:get_bool("maidroid_capture_rod_wears", true)
m_settings.tools_capture_rod_uses = g_settings:get("maidroid.tools.capture_rod.uses") or 100
m_settings.tools_capture_rod_uses = arrange_number(m_settings.tools_capture_rod_uses, 20, 200, true)
m_settings.tools_robbery_stick = g_settings:get_bool("maidroid.tools.robbery_stick", true)

-- Timers
timers.find_path_max = g_settings:get("maidroid.path.timeout")
	or g_settings:get("maidroid_find_path_interval") or 10
timers.find_path_max = arrange_number(timers.find_path_max, 5, 20)

timers.change_dir_max = g_settings:get("maidroid.wander.direction_timeout")
	or g_settings:get("maidroid_change_direction_time") or 2.5 -- change direction at least every n seconds
timers.change_dir_max = arrange_number(timers.change_dir_max, 2, 5)

timers.walk_max = g_settings:get("maidroid.wander.walk_timeout")
	or g_settings:get("maidroid_max_walk_time") or 4 -- n seconds max walk time
timers.walk_max = arrange_number(timers.walk_max, 2, 12)

if m_settings.torcher then
	timers.place_torch_max = g_settings:get("maidroid.torcher.delay")
		or g_settings:get("maidroid_torch_delay") or 0.75
	timers.place_torch_max = arrange_number(timers.place_torch_max, 0.25, 5)
end

if m_settings.farming then
	timers.action_max = g_settings:get("maidroid.farming.job_time")
		or g_settings:get("maidroid_farming_job_time") or 3
	timers.action_max = arrange_number(timers.action_max, 0.5, 5)
		or g_settings:get_bool("maidroid_offline_player", true)
	m_settings.farming_offline = g_settings:get_bool("maidroid.farming.offline")
		or g_settings:get("maidroid_farming_offline", true)
	m_settings.farming_sound = g_settings:get_bool("maidroid.farming.sound", true)
end

-- Misc
if m_settings.stockbreeder then
	m_settings.stockbreeder_pause = g_settings:get("maidroid.stockbreeder.pause")
		or g_settings:get("maidroid_job_pause_time") or 4
	m_settings.stockbreeder_pause = arrange_number(m_settings.stockbreeder_pause, 2, 20)
	m_settings.stockbreeder_max_poultries = g_settings:get("maidroid.stockbreeder.max_poultries") or 12
	m_settings.stockbreeder_max_poultries = arrange_number(m_settings.stockbreeder_max_poultries, 8, 20, true)
end

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
