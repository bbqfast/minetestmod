------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyright (c) 2020 IFRFSX.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator
local on_start, on_resume, on_pause, on_stop, on_step, is_tool

local maidroid_instruction_set = {
	-- popular (similars in lua_api) information gathering functions
	get_pos = function(_, thread)
		local pos = thread.droid.object:get_pos()
		return true, {pos.x, pos.y, pos.z}
	end,

	get_velocity = function(_, thread)
		local vel = thread.droid.object:get_velocity()
		return true, {vel.x, vel.y, vel.z}
	end,

	get_acceleration = function(_, thread)
		local acc = thread.droid.object:get_acceleration()
		return true, {acc.x, acc.y, acc.z}
	end,

	get_yaw = function(_, thread)
		return true, thread.droid.object:get_yaw()
	end,

	-- other info functions

	-- popular actions for changing sth
	set_yaw = function(params, thread)
		if #params ~= 1 then
			return false, "wrong number of arguments"
		end
		local p = params[1]
		if type(p) ~= "number" then
			return false, "unsupported argument"
		end
		thread.droid.object:set_yaw(p)
		return true
	end,

	-- other actions
	jump = function(params, thread)
		-- test if it can jump
		local droid = thread.droid
		if droid.vel.y ~= 0
		or droid.vel_prev.y ~= 0 then
			return true, false
		end

		-- get the strength of the jump
		local h = tonumber(params[1])
		if not h
		or h <= 0
		or h > 2 then
			h = 1
		end

		-- play sound
		local p = droid.object:get_pos()
		p.y = p.y - 1
		local node_under = minetest.get_node(p).name
		local def = minetest.registered_nodes[node_under]
		if def
		and def.sounds then
			local snd = def.sounds.footstep or def.sounds.dig
			if snd then
				p.y = p.y + .5
				minetest.sound_play(snd.name, {pos = p, gain = snd.gain})
			end
		end

		-- perform jump
		droid.vel.y = math.sqrt(-2 * h * droid.object:get_acceleration().y)
		droid.object:set_velocity(droid.vel)
		return true, true
	end,

	beep = function(_, thread)
		minetest.sound_play("maidroid_beep", {pos = thread.droid.object:get_pos()})
		return true
	end,
}


local function mylog(log)
	-- This happens to the maidroids messages
	minetest.chat_send_all(S("maidroid says ") .. log)
end

-- the program is loaded from a "default:book_written" with title "main"
-- if it's not present, following program from IFRSFX is used in lieu:
local dummycode = [[
print $No book with title "main" found.
mov yaw_rot,pi
mul yaw_rot,0.6
add pi,pi; this is not read only

loop_start:
	get_us_time beep; var and cmd name can both be same
	beep
	usleep 500000

	get_yaw yaw
	add yaw,yaw_rot; rotate the droid a bit
	mod yaw,pi; pi is 2π
	set_yaw yaw

	get_us_time timediff
	neg beep
	add timediff,beep

	neg timediff
	add timediff,1000000
	usleep timediff; should continue 1s after previous beep
jmp loop_start
]]

local function get_code(self)
	local list = self:get_inventory():get_list("main")
	for i = 1,#list do
		local stack = list[i]
		if stack:get_name() == "default:book_written" then
			local stktbl = stack:to_table()
			if stktbl
			and stktbl["meta"]
			and stktbl["meta"]["title"] == "main" then
				if stktbl["meta"]["text"] ~= "" then
					return stktbl["meta"]["text"]
				end
			end
		end
	end
end

local ocr_thread_flush = function(self)
	mylog(self.log)
	self.log = ""
	return true
end

on_start = function(self)
	self:halt()
	self.vel = vector.new()

	local parsed_code = pdisc.parse(get_code(self) or dummycode)
	self.thread = pdisc.create_thread(function(thread)
		thread.flush = ocr_thread_flush
		table.insert(thread.is, 1, maidroid_instruction_set)
		thread.droid = self
	end, parsed_code)
	self.thread:suscitate()
	self:set_animation(maidroid.animation.STAND)
end

on_step = function(self)
	-- When owner offline the maidroid does nothing.
	if not minetest.get_player_by_name(self.owner) then
		return
	end

	local thread = self.thread
	if not thread.stopped then
		return
	end
	self.vel_prev = self.vel
	self.vel = self.object:get_velocity()

	thread:try_rebirth()
end

on_pause = function(self)
	self.thread:flush()
	self:set_animation(maidroid.animation.SIT)
end

on_stop = function(self)
	self.thread:exit()
	self.thread = nil

	self:halt()
end

on_resume = function(self)
	on_stop(self)
	on_start(self)
end

is_tool = function(stack)
	return stack:get_name() == "default:book_written"
end

maidroid.cores.basic.doc = maidroid.cores.basic.doc .. "\t"
	.. S("Progammable: Written book entitled main") .. "\n"

local doc = S("Programmable robot language") .. "\n\n"
	.. "ASM syntax"
	.. "\t" .. "https://github.com/HybridDog/pdisc" .. "\n\n"
	.. "Local additions" .. "\n"
	.. "\t" .. "get_yaw <var>" .. "\n"
	.. "\t" .. "set_yaw <val>" .. "\n"
	.. "\t" .. "beep" .. "\n"
	.. "\t" .. "jump" .. "\n"
	.. "\n\n" .. "Beware HybridDog has been confirmed to introduce some nasty code"


-- register a definition of a new core.
maidroid.register_core("ocr", {
	description = S("programmable"),
	on_start    = on_start,
	on_stop     = on_stop,
	on_resume   = on_resume,
	on_pause    = on_pause,
	on_step     = on_step,
	is_tool     = is_tool,
	doc = doc,
})

-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
