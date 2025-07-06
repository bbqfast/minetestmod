function lottmobs.register_ltee(n, hpmin, hpmax, textures, wv, rv, damg, arm, drops, price)
	mobs:register_mob("lottmobs:ltee" .. n, {
		type = "npc",
                race = "GAMEelf",
                hp_min = hpmin,
		hp_max = hpmax,
		collisionbox = {-0.3,-1.1,-0.3, 0.3,0.91,0.3},
		textures = textures,
		visual = "mesh",
		visual_size = {x=0.95, y=1.15},
		-- mesh = "lottarmor_character.b3d",
		mesh       = "character.b3d",
		textures   = {"character_Mary_LT_mt.png"},
		view_range = 20,
		makes_footstep_sound = true,
		walk_velocity = wv,
		run_velocity = rv,
		damage = damg,
		armor = arm,
		drops = drops,
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
		-- on_rightclick = function(self, clicker)
		-- 	lottmobs.guard(self, clicker, "default:gold_ingot", "Elf", "elf", price)
		-- end,
		on_rightclick = function(self, clicker)
			minetest.log("warning", "NPC right-clicked by " .. clicker:get_player_name())	
			error("Debugging error: NPC right-clicked")

			lottmobs_trader(self, clicker, entity, lottmobs.elf, "gui_elfbg.png", "GAMEelf")
		end,		
		do_custom = lottmobs.do_custom_guard,
		peaceful = true,
		group_attack = true,
		step = 1,
		on_die = lottmobs.guard_die,
	})
	mobs:register_spawn("lottmobs:ltee" .. n, {"lottmapgen:ltee_grass"}, 20, 0, 18000, 3, 31000)
	lottmobs.register_guard_craftitem("lottmobs:ltee"..n, "Elven Guard", "lottmobs_elven_guard"..n.."_inv.png")
end

--Basic elves

local textures1 = {
    {"lottmobs_lorien_elf_1.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
    {"lottmobs_lorien_elf_2.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
    {"lottmobs_lorien_elf_3.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
}

local drops1 = {
	{name = "lottplants:mallornsapling",
	chance = 5,
	min = 1,
	max = 3,},
	{name = "lottplants:mallornwood",
	chance = 5,
	min = 1,
	max = 6,},
	{name = "lottores:silveringot",
	chance = 20,
	min = 1,
	max = 7},
	{name = "lottores:silversword",
	chance = 20,
	min = 1,
	max = 1},
	{name = "lottarmor:helmet_silver",
	chance = 30,
	min = 1,
	max = 1},
	{name = "lottarmor:chestplate_silver",
	chance = 30,
	min = 1,
	max = 1},
	{name = "lottweapons:silver_spear",
	chance = 25,
	min = 1,
	max = 1,},
	{name = "lottores:blue_gem",
	chance = 200,
	min = 1,
	max = 1,},
	{name = "lottplants:yavannamiresapling",
	chance = 250,
	min = 1,
	max = 1,},
	{name = "lottores:mithril_lump",
	chance = 100,
	min = 1,
	max = 2,},
}

lottmobs.register_ltee("", 20, 35, textures1, 2.5, 5, 4, 200, drops1, 30)

--Elves in full armor

local textures2 = {
    {"lottmobs_lorien_elf_1.png", "lottarmor_chestplate_galvorn.png^lottarmor_leggings_galvorn.png^lottarmor_helmet_galvorn.png^lottarmor_boots_galvorn.png", "lottores_galvornsword.png", "lottarmor_trans.png"},
    {"lottmobs_lorien_elf_2.png", "lottarmor_chestplate_steel.png^lottarmor_leggings_steel.png^lottarmor_helmet_steel.png^lottarmor_boots_steel.png^lottarmor_shield_steel.png", "lottweapons_steel_battleaxe.png", "lottarmor_trans.png"},
    {"lottmobs_lorien_elf_3.png", "lottarmor_chestplate_silver.png^lottarmor_leggings_silver.png^lottarmor_helmet_silver.png^lottarmor_boots_silver.png^lottarmor_shield_silver.png", "lottores_silversword.png", "lottarmor_trans.png"},
}

local drops2 = {
	{name = "lottplants:mallornsapling",
	chance = 5,
	min = 1,
	max = 3,},
	{name = "lottplants:mallornwood",
	chance = 5,
	min = 1,
	max = 6,},
	{name = "lottores:silveringot",
	chance = 20,
	min = 1,
	max = 7},
	{name = "lottores:silversword",
	chance = 20,
	min = 1,
	max = 1},
	{name = "lottarmor:helmet_silver",
	chance = 30,
	min = 1,
	max = 1},
	{name = "lottarmor:chestplate_silver",
	chance = 30,
	min = 1,
	max = 1},
	{name = "lottweapons:silver_spear",
	chance = 25,
	min = 1,
	max = 1,},
	{name = "lottores:blue_gem",
	chance = 200,
	min = 1,
	max = 1,},
	{name = "lottplants:yavannamiresapling",
	chance = 250,
	min = 1,
	max = 1,},
	{name = "lottores:mithril_lump",
	chance = 100,
	min = 1,
	max = 2,},
}

lottmobs.register_ltee(1, 20, 35, textures2, 2, 4.5, 6, 100, drops2, 50)

--Elves with chestplates and powerful weapons!

local textures3 = {
    {"lottmobs_lorien_elf_1.png", "lottarmor_chestplate_galvorn.png", "lottweapons_elven_sword.png", "lottarmor_trans.png"},
    {"lottmobs_lorien_elf_2.png", "lottarmor_chestplate_gold.png^lottarmor_shield_gold.png", "lottweapons_gold_spear.png", "lottarmor_trans.png"},
    {"lottmobs_lorien_elf_3.png", "lottarmor_shield_steel.png", "lottweapons_steel_warhammer.png", "lottarmor_trans.png"},
}

local drops3 = {
	{name = "lottplants:mallornsapling",
	chance = 5,
	min = 1,
	max = 3,},
	{name = "lottplants:mallornwood",
	chance = 5,
	min = 1,
	max = 6,},
	{name = "lottores:silveringot",
	chance = 20,
	min = 1,
	max = 7},
	{name = "lottores:silversword",
	chance = 20,
	min = 1,
	max = 1},
	{name = "lottarmor:helmet_silver",
	chance = 30,
	min = 1,
	max = 1},
	{name = "lottarmor:chestplate_silver",
	chance = 30,
	min = 1,
	max = 1},
	{name = "lottweapons:silver_spear",
	chance = 25,
	min = 1,
	max = 1,},
	{name = "lottores:blue_gem",
	chance = 200,
	min = 1,
	max = 1,},
	{name = "lottplants:yavannamiresapling",
	chance = 250,
	min = 1,
	max = 1,},
	{name = "lottores:mithril_lump",
	chance = 100,
	min = 1,
	max = 2,},
}

lottmobs.register_ltee(2, 20, 35, textures3, 2.25, 4.75, 8, 150, drops3, 50)

local hostile_mobs = {
    ["lottmobs:orc"] = true,
    ["lottmobs:raiding_orc"] = true,
    ["lottmobs:battle_troll"] = true,
    ["lottmobs:half_troll"] = true,
    ["lottmobs:nazgul"] = true,
    ["lottmobs:witch_king"] = true,
    ["lottmobs:balrog"] = true,
    ["lottmobs:dead_men"] = true,
    ["lottmobs:troll"] = true,
    ["lottmobs:spider"] = true,
    ["lottmobs:ent"] = true,
    ["lottmobs:uruk_hai"] = true,
    ["lottmobs:warg"] = true,
}

local function is_hostile_mob(name)
	-- minetest.log("warning", "Checking if " .. name .. " is a hostile mob")	
    return hostile_mobs[name] == true
end


local player_npcs = {}
minetest.register_entity("lottmobs:npc", {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh",
        -- mesh = "character.b3d", -- Replace with your NPC's model
        -- textures = {"character.png"}, -- Replace with your NPC's texture
		mesh       = "character.b3d",
		-- textures   = {"character_Mary_LT_mt.png"},
		textures   = {"lt_angel_2_mt.png"},
        static_save = false,
		drawtype = "front",
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
    },

    set_animation = function(self, name)
        local anim_def = self.initial_properties.animation
        if self.current_anim == name then return end
        self.current_anim = name

        if name == "stand" then
            self.object:set_animation({x = anim_def.stand_start, y = anim_def.stand_end}, anim_def.speed_normal, 0)
        elseif name == "walk" then
            self.object:set_animation({x = anim_def.walk_start, y = anim_def.walk_end}, anim_def.speed_normal, 0)
        elseif name == "run" then
            self.object:set_animation({x = anim_def.run_start, y = anim_def.run_end}, anim_def.speed_run, 0)
        elseif name == "punch" then
            self.object:set_animation({x = anim_def.punch_start, y = anim_def.punch_end}, anim_def.speed_normal, 0)
        end
    end,

    on_activate = function(self)
        self.timer = 0
		self.spin_timer = 0
        self.say = true
    end,	

    on_punch = function(self, hitter)
        -- Optional: Code to run when the NPC is punched
    end,
    on_deactivate = function(self)
        minetest.log("action", "NPC '" .. (self.player_name or "unknown") .. "' has been deactivated.")
		if self.player_name then
			local player = minetest.get_player_by_name(self.player_name)
			if player then
				local pos = vector.add(player:get_pos(), {x = 2, y = 0, z = 0})
				local npc = minetest.add_entity(pos, "lottmobs:npc")
				if npc then
					local lua = npc:get_luaentity()
					if lua then
						lua.player_name = self.player_name
						minetest.log("action", "NPC '" .. self.player_name .. "' reactivated near the player.")
					end
				end
			end
		end		
    end,	
	on_die = function(self, killer)
		minetest.log("action", "NPC '" .. (self.player_name or "unknown") .. "' has died.")
	end,
	on_rightclick = function(self, clicker)
		minetest.log("warning", "NPC right-clicked by " .. clicker:get_player_name())	
		-- error("Debugging error: NPC right-clicked")
		self.game_name = "NPC"
		-- lottmobs_trader(self, clicker, entity, lottmobs.ltee, "gui_gondorbg.png", "GAMEltee")
		lottmobs_trader(self, clicker, entity, lottmobs.ltee_angel, "gui_gondorbg.png", "GAMEltee")
		-- lottmobs_trader(self, clicker, entity, lottmobs.elf, "gui_elfbg.png", "GAMEelf")
	end, 		
    on_step = function(self, dtime)
		-- minetest.log("warning", "NPC step")
        self.timer = self.timer + dtime
		self.spin_timer = self.spin_timer + dtime
        if self.timer < 0.2 then return end
        self.timer = 0
		-- minetest.log("warning", "NPC step")
        if self.player_name then
            local player = minetest.get_player_by_name(self.player_name)
			if not player then
				-- Player is gone (exit to menu or disconnected), remove NPC
				self.object:remove()
				return
			end
			
            if player then
                local pos = self.object:get_pos()
                local target_pos = player:get_pos()

				if vector.distance(pos, target_pos) < 5 then
					if not self.hud_id then
						-- Define the quotes
						self.quotes = {
							"Hi, LT!  Welcome to Middle-Earth",
							"I'm LT angel",
							"we're newly arrived race on the middle earth",
							"We don't have our own territory yet",
							"! There are dangerous mobs around",
							"I'm here to help fight off mobs",
							"Feel free to explore around"
						}
						self.current_quote_index = 1
						self.quote_timer = 0
				
						local text_elem={
							hud_elem_type="text",
							text=self.quotes[self.current_quote_index],
							position={x=0.5,y=0.8},
							--scale={x=2,y=2},
							number=0xFFFFFF,
							size={x=2},
							alignment={x=0,y=0},
							style=1,
						}
						self.hud_id=player:hud_add(text_elem)
					
						-- Add the initial HUD
						-- self.hud_id = player:hud_add({
						-- 	hud_elem_type = "text",
						-- 	position = {x = 0.5, y = 0.8}, -- Bottom center of the screen
						-- 	offset = {x = 0, y = 0},
						-- 	text = self.quotes[self.current_quote_index],
						-- 	alignment = {x = 0, y = 1}, -- Center alignment
						-- 	scale = {x = 1700, y = 1700}, -- Larger text
						-- 	number = 0xFFFFFF, -- White color
						-- })
					else
						-- Cycle through quotes every 3 seconds
						self.quote_timer = (self.quote_timer or 0) + dtime
						-- if self.quote_timer >= 3 then
						if self.quote_timer >= 1 then
							self.quote_timer = 0
							self.current_quote_index = self.current_quote_index % #self.quotes + 1
							player:hud_change(self.hud_id, "text", self.quotes[self.current_quote_index])
						end
					end
				else
					if self.hud_id then
						player:hud_remove(self.hud_id)
						self.hud_id = nil
					end
				end

				-- new code
				-- Step 1: Check for nearby hostiles
				local hostiles = minetest.get_objects_inside_radius(pos, 10)
				for _, obj in ipairs(hostiles) do
					local lua = obj:get_luaentity()
					-- if lua and lua.name and lua.name:match("^mobs:") and lua.owner ~= self.player_name then
					if lua and lua.name and is_hostile_mob(lua.name) then
					-- if lua and lua.name and not lua.name:match("npc") and lua.owner ~= self.player_name then
						minetest.log("warning", "Hostile mob found: " .. lua.name)
						-- Found a hostile mob, attack it!
						local mob_pos = obj:get_pos()
						local dir = vector.direction(pos, mob_pos)
						self.object:set_velocity(vector.multiply(dir, 2))

						local yaw = math.atan2(dir.z, dir.x) + math.pi * 1.5
						self.object:set_yaw(yaw)
						self:set_animation("walk")

						-- Optional: hit mob if close
						if vector.distance(pos, mob_pos) < 2 then
							if obj.punch then
								obj:punch(self.object, 1.0, {
									full_punch_interval = 1.0,
									damage_groups = {fleshy = 2}
								}, nil)
								minetest.log("action", "Hostile mob '" .. lua.name .. "' punched")
							end							
							if lua.health then
								lua.health = lua.health - 2
								minetest.log("action", "Hostile mob '" .. lua.name .. "' health reduced to " .. lua.health)
								if lua.health <= 0 then
									obj:remove()
								end
							-- elseif obj.punch then
							-- 	obj:punch(self.object, 1.0, {
							-- 		full_punch_interval = 1.0,
							-- 		damage_groups = {fleshy = 2}
							-- 	}, nil)
							-- 	minetest.log("action", "Hostile mob '" .. lua.name .. "' punched")
							end
						end

						return -- Only attack one mob per step
					end
				end				


                local dir = vector.direction(pos, target_pos)
                local dist = vector.distance(pos, target_pos)

				-- Spin randomly when idle
				if dist <= 2 and self.spin_timer > 2 then
					local current_yaw = self.object:get_yaw()
					local spin = math.random(0, 1) == 0 and -0.3 or 0.3  -- left or right
					self.object:set_yaw(current_yaw + spin)
					self.spin_timer = 0
				end

				-- Teleport NPC to player if distance is over 1000
				if dist > 300 then
					minetest.log("action", "NPC '" .. (self.player_name or "unknown") .. "' teleported to player due to large distance: " .. dist)
					self.object:set_pos(target_pos)
					return
				end

                if dist > 10 then
					local yaw = math.atan2(dir.z, dir.x) + math.pi / 2
					yaw = yaw + math.pi
					self.object:set_yaw(yaw)

                    -- self.object:set_velocity(vector.multiply(dir, 2))
					-- local speed = math.min(dist * 0.8, 40) -- Adjust the multiplier (0.5) and max speed (6) as needed
					local speed = dist * 0.8
					self.object:set_velocity(vector.multiply(dir, speed))   
					-- minetest.log("warning", "NPC moving towards player at speed: " .. speed .. ", distance: " .. dist)
					
                    -- self.object:set_velocity(vector.multiply(dir, 2))
                    self:set_animation("walk")
                else
					-- minetest.log("warning", "NPC reached player, stopping")
                    self.object:set_velocity({x=0, y=0, z=0})
                    self:set_animation("stand")
                end
            end
        end
    end,
})



-- Spawn NPC next to the player when they join
-- minetest.register_on_joinplayer(function(player)
--     local pos = player:get_pos()
--     pos.x = pos.x + 1 -- Adjust position to spawn NPC next to the player
--     minetest.add_entity(pos, "lottmobs:npc")
-- end)

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    minetest.after(1, function()  -- give the world time to load
        if not player or not player:is_player() then return end
        local pos = vector.add(player:get_pos(), {x = 1, y = 0, z = 0})
        local npc = minetest.add_entity(pos, "lottmobs:npc")
        if npc then
            local lua = npc:get_luaentity()
            if lua then
                lua.player_name = name
                player_npcs[name] = npc
                minetest.chat_send_player(name, "Follower NPC spawned for you.")
            else
                minetest.chat_send_player(name, "NPC entity missing Lua object.")
            end
        else
            minetest.chat_send_player(name, "NPC failed to spawn.")
        end
    end)
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    local npc = player_npcs[name]
    if npc and npc:get_luaentity() then
		minetest.log("warning", "NPC removed")
        npc:remove()
    end
    player_npcs[name] = nil
end)


minetest.register_chatcommand("list_npcs", {
    description = "List all NPCs near you",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end

        local pos = player:get_pos()
        local radius = 20
        local count = 0
        local info = {}

        for _, obj in ipairs(minetest.get_objects_inside_radius(pos, radius)) do
            local lua = obj:get_luaentity()
            if lua then
                table.insert(info, lua.name .. " at " .. minetest.pos_to_string(obj:get_pos()))
                count = count + 1
            end
        end

        if count == 0 then
            return true, "No NPCs found near you."
        else
            return true, table.concat(info, "\n")
        end
    end,
})


minetest.register_chatcommand("spawn_npc", {
    description = "Spawns test NPC",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        local pos = vector.add(player:get_pos(), {x = 2, y = 0, z = 0})
        local npc = minetest.add_entity(pos, "lottmobs:npc")
        if npc then
            local lua = npc:get_luaentity()
            if lua then
                lua.player_name = name
            end
            return true, "NPC spawned."
        else
            return false, "NPC failed to spawn."
        end
    end
})


minetest.register_chatcommand("recipe", {
    params = "<itemname>",
    description = "Check crafting recipe for an item",
    privs = {shout = true},
    func = function(name, param)
        if param == "" then
            return false, "Please provide an item name. Usage: /recipe <itemname>"
        end

        local recipes = minetest.get_all_craft_recipes(param)

        if not recipes or #recipes == 0 then
            return true, "No crafting recipe found for: " .. param
        end

        local message = "Recipes for: " .. param
        for i, recipe in ipairs(recipes) do
            message = message .. "\nMethod: " .. recipe.type
            for j, item in ipairs(recipe.items) do
                message = message .. "\n[" .. j .. "]: " .. item
            end
        end

        return true, message
    end
})