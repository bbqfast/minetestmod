local lf = assert(_G.lf, "global lf not initialized")

local riddles = {
	{
		question = "What has hands but can't clap?",
		answers = {"A tree", "A clock", "A river", "A mountain", "A shadow"},
		correct = 2
	},
	{
		question = "What has a head and a tail but no body?",
		answers = {"A snake", "A coin", "A worm", "A fish", "A ghost"},
		correct = 2
	},
	{
		question = "What gets wetter the more it dries?",
		answers = {"A sponge", "A towel", "Rain", "A river", "Ice"},
		correct = 2
	},
	{
		question = "What can travel around the world while staying in a corner?",
		answers = {"A spider", "A stamp", "A snail", "The wind", "A shadow"},
		correct = 2
	},
	{
		question = "What has keys but no locks?",
		answers = {"A treasure chest", "A door", "A piano", "A map", "A safe"},
		correct = 3
	}
}

local active_riddles = {}

local function get_riddle_formspec(riddle)
	local fs = "size[8,7]" ..
		"label[0.5,0.5;" .. minetest.formspec_escape(riddle.question) .. "]"
	local y = 1.5
	for i, answer in ipairs(riddle.answers) do
		local btn_name = "ans" .. i
		fs = fs .. "button[0.5," .. y .. ";7,1;" .. btn_name .. ";" ..
			minetest.formspec_escape(answer) .. "]"
		y = y + 1
	end
	fs = fs .. "button_exit[3,6;2,1;exit;Close]"
	return fs
end


-- simple riddler NPC for LT race
mobs:register_mob("lottmobs:ltee_riddler", {
	type = "npc",
	race = "GAMEltee",
	hp_min = 10,
	hp_max = 20,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "character.b3d",
	textures = {"character_Mary_LT_mt.png"},
	view_range = 10,
	walk_velocity = 1,
	run_velocity = 2,
	damage = 1,
	armor = 100,
	light_resistant = true,
	drawtype = "front",
	attack_type = "dogfight",
	peaceful = true,
	group_attack = false,
	step = 1,
    animation = {
        speed_normal = 15,
        speed_run = 20,
        stand_start = 0,
        stand_end = 79,
        walk_start = 168,
        walk_end = 187,
        run_start = 168,
        run_end = 187,
        punch_start = 189,
        punch_end = 198,
        sit_start = 81,
        sit_end = 160,
    },
    sounds = {
        war_cry = "mobs_die_yell",
        death = "default_death",
        attack = "mobs_slash_attack",
    },
    attacks_monsters = true,
    
	on_rightclick = function(self, clicker)
		local name = clicker and clicker:get_player_name()
		if not name then
			return
		end
		-- stop moving and face the player
		self.state = "stand"
		if self.object then
			self.object:set_velocity({x = 0, y = 0, z = 0})
		end
		if self.set_animation then
			self:set_animation("stand")
		end
		if lottmobs and lottmobs.face_pos and clicker and clicker.get_pos then
			lottmobs.face_pos(self, clicker:get_pos())
		end
		-- temporarily pause wandering while dialog is open
		self._orig_walk_velocity = self._orig_walk_velocity or self.walk_velocity or 1
		self._orig_run_velocity  = self._orig_run_velocity  or self.run_velocity  or 2
		self._orig_jump          = self._orig_jump
		self._orig_walk_chance   = self._orig_walk_chance or self.walk_chance
		self.walk_velocity = 0
		self.run_velocity  = 0
		self.jump          = false
		self.walk_chance   = 0
		if #riddles == 0 then
			minetest.chat_send_player(name, "Riddler: I have no riddles right now.")
			return
		end
		local idx = math.random(1, #riddles)
		active_riddles[name] = { idx = idx, obj = self.object }
		local formspec = get_riddle_formspec(riddles[idx])
		minetest.show_formspec(name, "ltee_riddler_form", formspec)
	end,
})

minetest.register_chatcommand("spawn_ltee_riddler", {
	description = "Spawns an LT riddler NPC",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player not found" end
		local pos = vector.add(player:get_pos(), {x = 2, y = 0, z = 0})
		local obj = minetest.add_entity(pos, "lottmobs:ltee_riddler")
		if obj then
			return true, "ltee_riddler spawned."
		else
			return false, "Failed to spawn ltee_riddler."
		end
	end
})


minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "ltee_riddler_form" then
		return
	end
	local name = player and player:get_player_name()
	if not name then
		return
	end
	local data = active_riddles[name]
	if not data or not data.idx or not riddles[data.idx] then
		return
	end
	local riddle = riddles[data.idx]

	-- if the dialog was closed (Close button or Esc), resume wandering
	if fields.exit or fields.quit then
		local obj = data.obj
		if obj then
			local lua = obj:get_luaentity()
			if lua then
				lua.walk_velocity = lua._orig_walk_velocity or lua.walk_velocity or 1
				lua.run_velocity  = lua._orig_run_velocity  or lua.run_velocity  or 2
				if lua._orig_jump ~= nil then
					lua.jump = lua._orig_jump
				else
					lua.jump = true
				end
				if lua._orig_walk_chance ~= nil then
					lua.walk_chance = lua._orig_walk_chance
				end
				lua.state = "walk"
			end
		end
		active_riddles[name] = nil
		return
	end

	-- answer buttons: just respond in chat, keep NPC frozen until Close is pressed
	local chosen
	for i = 1, #riddle.answers do
		local field_name = "ans" .. i
		if fields[field_name] then
			chosen = i
			break
		end
	end
	if not chosen then
		return
	end
	if chosen == riddle.correct then
		minetest.chat_send_player(name, "Riddler: Correct! " .. riddle.answers[chosen] .. " is the right answer.")
	else
		minetest.chat_send_player(name, "Riddler: Incorrect. The correct answer is " .. riddle.answers[riddle.correct] .. ".")
	end
end)
