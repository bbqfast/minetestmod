local lf = assert(_G.lf, "global lf not initialized")

mobs:register_mob("lottmobs:elf_trader", {
	type = "npc",
        race = "GAMEelf",
        hp_min = 20,
	hp_max = 50,
	collisionbox = {-0.3,-1.1,-0.3, 0.3,0.91,0.3},
	textures = {
		{"lottmobs_elf_trader.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	visual = "mesh",
	visual_size = {x=0.95, y=1.15},
	mesh = "lottarmor_character.b3d",
	view_range = 20,
	makes_footstep_sound = true,
	walk_velocity = 1.5,
	run_velocity = 5,
	damage = 6,
	armor = 200,
	drops = { },
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 10,
	light_damage = 0,
	attack_type = "dogfight",
	follow = "lottother:narya",
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
	},
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "mobs_slash_attack",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
	on_rightclick = function(self, clicker)
		lottmobs_trader(self, clicker, entity, lottmobs.elf, "gui_elfbg.png", "GAMEelf")
	end,
})
mobs:register_spawn("lottmobs:elf_trader", {"lottmapgen:lorien_grass"}, 20, 0, 60000, 3, 31000)

mobs:register_mob("lottmobs:human_trader", {
	type = "npc",
        race = "GAMEman",
        hp_min = 15,
	hp_max = 35,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	textures = {
		{"lottmobs_human_trader.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	makes_footstep_sound = true,
	view_range = 12,
	walk_velocity = 1,
	run_velocity = 3,
	armor = 100,
	damage = 5,
	drops = { },
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 10,
	light_damage = 0,
	attack_type = "dogfight",
	follow = "lottother:narya",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
	on_rightclick = function(self, clicker)
		lottmobs_trader(self, clicker, entity, lottmobs.human, "gui_gondorbg.png", "GAMEman")
	end,
})
mobs:register_spawn("lottmobs:human_trader", {"lottmapgen:rohan_grass"}, 20, -1, 60000, 3, 31000)
mobs:register_spawn("lottmobs:human_trader", {"lottmapgen:gondor_grass"}, 20, -1, 60000, 3, 31000)

mobs:register_mob("lottmobs:hobbit_trader", {
	type = "npc",
        race = "GAMEman",
        hp_min = 5,
	hp_max = 15,
	collisionbox = {-0.3,-0.75,-0.3, 0.3,0.7,0.3},
	textures = {
		{"lottmobs_hobbit_trader.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	visual = "mesh",
	visual_size = {x=1.1, y=0.75},
	mesh = "lottarmor_character.b3d",
	makes_footstep_sound = true,
	walk_velocity = 1,
	armor = 300,
	drops = { },
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 5,
	light_damage = 0,
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	step=1,
	passive = true,
	sounds = {
	},
	on_rightclick = function(self, clicker)
		lottmobs_trader(self, clicker, entity, lottmobs.hobbit, "gui_hobbitbg.png", "GAMEhobbit")
	end,
})
mobs:register_spawn("lottmobs:hobbit_trader", {"lottmapgen:shire_grass"}, 20, -1, 60000, 3, 31000)

mobs:register_mob("lottmobs:dwarf_trader", {
	type = "npc",
        race = "GAMEdwarf",
        hp_min = 20,
	hp_max = 30,
	collisionbox = {-0.3,-.85,-0.3, 0.3,0.68,0.3},
	textures = {
		{"lottmobs_dwarf_trader.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	visual = "mesh",
	visual_size = {x=1.1, y=0.85},
	mesh = "lottarmor_character.b3d",
	view_range = 10,
	makes_footstep_sound = true,
	walk_velocity = 1,
	run_velocity = 2,
	armor = 200,
	damage = 4,
	drops = {},
	light_resistant = true,
	drawtype = "front",
	water_damage = 0,
	lava_damage = 10,
	light_damage = 0,
	attack_type = "dogfight",
	follow = "lottother:narya",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
	on_rightclick = function(self, clicker)
		lottmobs_trader(self, clicker, entity, lottmobs.dwarf, "gui_angmarbg.png", "GAMEdwarf")
	end,
})
mobs:register_spawn("lottmobs:dwarf_trader", {"lottmapgen:ironhill_grass"}, 20, -1, 60000, 3, 31000)


-- ltee_settings("character_Carlos_LT_third_LT_stolen_mt.png", "lottarmor_character.b3d", lottmobs.ltee1)
-- ,,ltee
function ltee_settings(skin_file, mesh_file, ltee_goods)
	setting_map =	
	{
		type = "npc",
		race = "GAMEltee",
		hp_min = 20,
		hp_max = 30,
		collisionbox = {-0.3, -.85, -0.3, 0.3, 0.68, 0.3},
		textures = {
			{skin_file},
		},
		visual = "mesh",
		visual_size = {x = 1.1, y = 0.85},
		mesh = mesh_file,
		view_range = 10,
		makes_footstep_sound = true,
		walk_velocity = 0,
		run_velocity = 0,
		armor = 200,
		damage = 4,
		drops = {},
		light_resistant = true,
		drawtype = "front",
		water_damage = 0,
		lava_damage = 10,
		light_damage = 0,
		attack_type = "dogfight",
		follow = "lottother:narya",
		animation = {
			speed_normal = 15,
			speed_run = 15,
			stand_start = 0,
			stand_end = 79,
			walk_start = 168,
			walk_end = 187,
			run_start = 168,
			run_end = 187,
			punch_start = 189,
			punch_end = 198,
		},
		jump = false,
		sounds = {
			war_cry = "mobs_die_yell",
			death = "default_death",
			attack = "default_punch2",
		},
		attacks_monsters = true,
		peaceful = true,
		group_attack = true,
		step = 1,
		on_rightclick = function(self, clicker)
			lf("lottmobs:ltee_trader_2", "on_rightclick called")
			self.game_name = "NPC"
			lottmobs_trader(self, clicker, entity, ltee_goods, "gui_angmarbg.png", "GAMEltee")
		end,
		on_spawn = function(self)
			local pos = self.object and self.object:get_pos() or {x = 0, y = 0, z = 0}

			lf("lottmobs:ltee_trader",
			string.format("on_spawn: name=%s (%d, %d, %d)",
				tostring(self.name), pos.x, pos.y, pos.z))
		end,

		on_activate = function(self)
			-- error("xxxxxxxxx.")
			-- minetest.log("action", "on_activate called for lottmobs:ltee_trader_2")
			lf("lottmobs:ltee_trader",
			"on_activate: name=" .. tostring(self.name)
			.. " skin=" .. tostring(self.textures and self.textures[1] and self.textures[1][1] or "unknown"))

			local pos = self.object:get_pos()
			lf("lottmobs:ltee_trader",
			string.format("on_activate at x=%d y=%d z=%d", pos.x, pos.y, pos.z))
			
			lf("lottmobs:ltee_trader", "skin file: " .. tostring(self.textures and self.textures[1] and self.textures[1][1] or "unknown"))

			self.timer = 0
			self.spin_timer = 0
			self.say = true
		end,		
		do_custom = function(self, dtime)
			-- Make the mob face the nearest player
			-- error("An intentional exception has been thrown in the on_step function.")
			-- minetest.log("action", "on_step called for lottmobs:ltee_trader_2")
			self.do_custom_timer = (self.do_custom_timer or 0) + dtime
			if self.do_custom_timer < 10 then
				return
			end
			self.do_custom_timer = 0
			
			local pos = self.object:get_pos()
			if not pos then
				lf("lottmobs:ltee_trader", "do_custom: object already removed")
				return
			end
			local players = minetest.get_connected_players()
			local closest_player, closest_dist = nil, math.huge

			for _, player in ipairs(players) do
				local player_pos = player:get_pos()
				local dist = vector.distance(pos, player_pos)
				-- Skip if player is too far
				if dist > 15 then
					goto continue
				end

				if dist < closest_dist then
					closest_player = player
					closest_dist = dist
				end

				::continue::
			end

			if closest_player then
				local player_pos = closest_player:get_pos()
				local vec = vector.subtract(player_pos, pos)
				local yaw = math.atan2(vec.z, vec.x) - math.pi / 2
				self.object:set_yaw(yaw)
			end
		end,
	}
	return setting_map
end



-- mobs:register_mob("lottmobs:ltee_trader_1", {
-- 	type = "npc",
--         race = "GAMEltee",
--         hp_min = 20,
-- 	hp_max = 30,
-- 	collisionbox = {-0.3,-.85,-0.3, 0.3,0.68,0.3},
-- 	textures = {
-- 		-- {"lottmobs_dwarf_trader.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
-- 		{"character_Carlos_LT_third_LT_stolen_mt.png"},
-- 	},
-- 	visual = "mesh",
-- 	visual_size = {x=1.1, y=0.85},
-- 	mesh = "lottarmor_character.b3d",
-- 	view_range = 10,
-- 	makes_footstep_sound = true,
-- 	walk_velocity = 1,
-- 	run_velocity = 2,
-- 	armor = 200,
-- 	damage = 4,
-- 	drops = {},
-- 	light_resistant = true,
-- 	drawtype = "front",
-- 	water_damage = 0,
-- 	lava_damage = 10,
-- 	light_damage = 0,
-- 	attack_type = "dogfight",
-- 	follow = "lottother:narya",
-- 	animation = {
-- 		speed_normal = 15,
-- 		speed_run = 15,
-- 		stand_start = 0,
-- 		stand_end = 79,
-- 		walk_start = 168,
-- 		walk_end = 187,
-- 		run_start = 168,
-- 		run_end = 187,
-- 		punch_start = 189,
-- 		punch_end = 198,
-- 	},
-- 	jump = true,
-- 	sounds = {
-- 		war_cry = "mobs_die_yell",
-- 		death = "default_death",
-- 		attack = "default_punch2",
-- 	},
-- 	attacks_monsters = true,
-- 	peaceful = true,
-- 	group_attack = true,
-- 	step = 1,
-- 	on_rightclick = function(self, clicker)
-- 		self.game_name = "NPC"
-- 		lottmobs_trader(self, clicker, entity, lottmobs.ltee1, "gui_angmarbg.png", "GAMEltee")
-- 	end,
-- })
-- mobs:register_spawn("lottmobs:ltee_trader_1", {"lottmapgen:ltee_grass"}, 20, -1, 60000, 3, 31000)

-- ,,lt2


mobs:register_mob("lottmobs:ltee_trader_1", ltee_settings("character_Carlos_LT_third_LT_stolen_mt.png", "lottarmor_character.b3d", lottmobs.ltee1))
-- make mobs:register_mob("lottmobs:ltee_trader_1 and mobs:register_mob("lottmobs:ltee_trader_2 call a common function
mobs:register_mob("lottmobs:ltee_trader_2", ltee_settings("character_Carla_sixth_stolen_LT_mt.png", "lottarmor_character.b3d", lottmobs.ltee2))
-- shop trader shouldn't spawn in the world
-- mobs:register_spawn("lottmobs:ltee_trader_2", {"lottmapgen:ltee_grass"}, 20, -1, 60000, 3, 31000)

mobs:register_mob("lottmobs:ltee_trader_3", ltee_settings("character_Sarah_LT_fourth_LT_stolen_mt.png", "lottarmor_character.b3d", lottmobs.ltee3))
mobs:register_mob("lottmobs:ltee_trader_santa", ltee_settings("character_santa_LT_mc.png", "lottarmor_character.b3d", lottmobs.ltee_santa))
-- shop trader shouldn't spawn in the world
-- mobs:register_spawn("lottmobs:ltee_trader_3", {"lottmapgen:ltee_grass"}, 20, -1, 60000, 3, 31000)



minetest.register_chatcommand("spawn_mob", {
    params = "<mobname>",
    description = "Spawn a mob by full entity name, e.g. lottmobs:ltee_trader_1",
    privs = {server = true},
    func = function(name, param)
        if param == "" then
            return false, "Please specify a mob entity name. Usage: /spawn_mob <mobname>"
        end
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found."
        end
        local pos = vector.add(player:get_pos(), {x = 2, y = 0, z = 0})
        local mob = minetest.add_entity(pos, param)
		if mob then
			local le = mob:get_luaentity()
			lf("spawn_mob", "spawned " .. tostring(param)
				.. " obj=" .. tostring(mob)
				.. " le.name=" .. tostring(le and le.name)
				.. " has_on_activate=" .. tostring(le and le.on_activate))
			return true, "Mob '" .. param .. "' spawned near you."
		else
			return false, "Failed to spawn mob. Check the mob entity name."
		end
    end,
})
