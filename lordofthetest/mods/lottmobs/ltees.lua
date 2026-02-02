local lf = assert(_G.lf, "global lf not initialized")

local function clear_ltee_hud(self)
	-- Clear all multi-player HUDs
	if self.hud_ids then
		for name, id in pairs(self.hud_ids) do
			local player = minetest.get_player_by_name(name)
			if player and player.is_player and player:is_player() then
				player:hud_remove(id)
			end
		end
	end

	-- Clear single HUD if present
	if self.hud_id and self.hud_player then
		local player = self.hud_player
		if player and player.is_player and player:is_player() then
			player:hud_remove(self.hud_id)
		end
	end

	self.hud_ids = nil
	self.hud_players = nil
	self.hud_id = nil
	self.hud_player = nil
end

-- Per-player HUDs (for lottmobs:ltee)
local function handle_player_hud(self, player, dtime, pos, target_pos, quotes, min_dist, color, hud_pos)
	hud_pos = hud_pos or {x = 0.5, y = 0.8}
	local dist = vector.distance(pos, target_pos)

	self.hud_ids = self.hud_ids or {}
	self.hud_players = self.hud_players or {}

	local name = player:get_player_name()
	if not name then return end

	-- 10 bright random colors
	local bright_colors = {
		0xFF0000, -- Red
		0x00FF00, -- Green
		0x00FFFF, -- Cyan
		0xFFFF00, -- Yellow
		0xFF00FF, -- Magenta
		0xFFA500, -- Orange
		0x00FF7F, -- Spring Green
		0xFF69B4, -- Hot Pink
		0x7FFF00, -- Chartreuse
		0x1E90FF, -- Dodger Blue
	}

	if dist < min_dist then
		-- Initialize shared quote state once
		if not self.quotes then
			self.quotes = quotes
			self.current_quote_index = 1
			self.quote_timer = 0
		end

		-- Create HUD for this specific player if missing
		if not self.hud_ids[name] then
			-- Pick a random bright color
			local random_color = bright_colors[math.random(1, #bright_colors)]
			local text_elem = {
					hud_elem_type = "text",
					text = self.quotes[self.current_quote_index],
					position = hud_pos,
					--scale = {x=2,y=2},
					number = random_color,
					size = {x = 2},
					alignment = {x = 0, y = 0},
					style = 1,
			}
			local id = player:hud_add(text_elem)
			self.hud_ids[name] = id
			self.hud_players[name] = true
		else
			-- Advance quote timer and update text for this player
			self.quote_timer = (self.quote_timer or 0) + 1
			if self.quote_timer >= 3 and #self.quotes > 0 then
				self.quote_timer = 0
				self.current_quote_index = self.current_quote_index % #self.quotes + 1
				local id = self.hud_ids[name]
				if id then
					player:hud_change(id, "text", self.quotes[self.current_quote_index])
				end
			end
		end
	else
		-- Player moved out of range: clear only their HUD
		local id = self.hud_ids[name]
		if id then
			player:hud_remove(id)
			self.hud_ids[name] = nil
			self.hud_players[name] = nil
		end
	end
end

-- Single-player HUD (for follower NPC)
local function handle_single_player_hud(self, player, dtime, pos, target_pos, quotes, min_dist, color, hud_pos)
	hud_pos = hud_pos or {x = 0.5, y = 0.8}
	local dist = vector.distance(pos, target_pos)

	if dist < min_dist then
		if not self.hud_id then
			-- initialize quotes from parameter and reset state
			self.quotes = quotes
			self.current_quote_index = 1
			self.quote_timer = 0
			self.hud_player = player

			local text_elem = {
					hud_elem_type = "text",
					text = self.quotes[self.current_quote_index],
					position = hud_pos,
					--scale = {x=2,y=2},
					number = color or 0xFFFFFF,
					size = {x = 2},
					alignment = {x = 0, y = 0},
					style = 1,
			}
			self.hud_id = player:hud_add(text_elem)
		else
			self.quote_timer = (self.quote_timer or 0) + 1
			if self.quote_timer >= 3 then
				self.quote_timer = 0
				self.current_quote_index = self.current_quote_index % #self.quotes + 1
				local hud_player = self.hud_player or player
				if hud_player then
					hud_player:hud_change(self.hud_id, "text", self.quotes[self.current_quote_index])
					self.hud_player = hud_player
				end
			end
		end
	else
		if self.hud_id then
			local hud_player = self.hud_player or player
			if hud_player then
				hud_player:hud_remove(self.hud_id)
			end
			self.hud_id = nil
			self.hud_player = nil
		end
	end
end

function lottmobs.register_ltee(n, hpmin, hpmax, textures, wv, rv, damg, arm, drops, price, race_quotes)
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
			sit_start = 81,
			sit_end = 160,
		},
		sounds = {
			war_cry = "mobs_die_yell",
			death = "default_death",
			attack = "mobs_slash_attack",
		},
		attacks_monsters = true,
		ltee_quotes = quotes,
		-- on_rightclick = function(self, clicker)
		-- 	lottmobs.guard(self, clicker, "default:gold_ingot", "Elf", "elf", price)
		-- end,
		on_rightclick = function(self, clicker)
			minetest.log("warning", "NPC right-clicked by " .. clicker:get_player_name())	
			-- error("Debugging error: NPC right-clicked")

			lottmobs_trader(self, clicker, entity, lottmobs.elf, "gui_elfbg.png", "GAMEelf")
		end,
        -- ,,quo
        do_custom = function(self, dtime)
            -- your per-tick logic here
            -- return false to stop the normal mob AI for this step

            -- Check for nearby players and display HUD with cycling quotes

            self.timer = self.timer + dtime
            if self.timer < 1 then return end
            
            lottmobs.do_custom_guard(self, dtime)

            local pos = self.object:get_pos()
            if not pos then 
                lf("ltee", "do_custom: no position found")
                return false 
            end
            
            -- Assign ltee_quotes from the quotes parameter passed to register_ltee
            self.ltee_quotes = self.ltee_quotes or race_quotes
            
            for _, player in ipairs(minetest.get_connected_players()) do
                local target_pos = player:get_pos()
                local dist = vector.distance(pos, target_pos)
                -- lf("ltee", "Player distance: " .. dist)

                local quotes = self.ltee_quotes or {
                    "I prefer to remain silent."
                }

                local hud_color
                if n == 1 then
                    hud_color = 0xFFFF00 -- yellow for ltee1
                elseif n == 2 then
                    hud_color = 0x0000FF -- blue for ltee2
                else
                    hud_color = nil -- default (white)
                end

                local hud_pos = {x = 0.5, y = 0.75}
                handle_player_hud(self, player, dtime, pos, target_pos, quotes, 10, hud_color, hud_pos)
            end
            
            
            return false
            
        end,        
		-- do_custom = lottmobs.do_custom_guard,
		peaceful = true,
		group_attack = true,
		step = 1,
		on_die = function(self, killer)
			clear_ltee_hud(self)
			if lottmobs.guard_die then
				lottmobs.guard_die(self, killer)
			end
		end,
	})
	mobs:register_spawn("lottmobs:ltee" .. n, {"lottmapgen:ltee_grass"}, 20, 0, 18000, 3, 31000)
	lottmobs.register_guard_craftitem("lottmobs:ltee"..n, "Elven Guard", "lottmobs_elven_guard"..n.."_inv.png")
end

--Basic elves

local textures1 = {"character_Mary_LT_mt.png"}
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

local ltee_quotes_basic = {
    "Welcome to our village, traveler!",
    "The stars shine bright tonight.",
    "Have you seen the ancient forests?",
    "Beware of the shadows in the east.",
    "Our people value peace above all.",
    "May your journey be safe and swift.",
}

local ltee_quotes_basic2 = {
    "Middle earth can be unforgiving.",
    "Gold is our currency.",
    "We LTs are peaceful, but we can defend ourselves.",
    "Rings are the most powerful items in Middle-earth.",
    "Have you explored Middle-Earth yet?",
    "Watch out for orcs and other dangers!",
    "The elves have been kind to us newcomers.",
}

lottmobs.register_ltee(1, 20, 35, textures1, 2.5, 5, 4, 200, drops1, 30, ltee_quotes_basic)

--Elves in full armor

local textures2 = {
    {"character_player_peters_lt_pat_mt.png"},
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

lottmobs.register_ltee(2, 20, 35, textures2, 2, 4.5, 6, 100, drops2, 50, ltee_quotes_basic2)

--Elves with chestplates and powerful weapons!

local textures3 = {
    {"character_Dave_Lt_mt.png"},
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

lottmobs.register_ltee(3, 20, 35, textures3, 2.25, 4.75, 8, 150, drops3, 50, ltee_quotes_basic)

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
    ["lottmobs:dunlending"] = true,
}

local function is_hostile_mob(name)
	-- minetest.log("warning", "Checking if " .. name .. " is a hostile mob")	
    return hostile_mobs[name] == true
end



local player_npcs = {}

local function count_player_npcs()
	local c = 0
	for _ in pairs(player_npcs) do
		c = c + 1
	end
	return c
end



-- Helper: remove the NPC that follows a given player
function lottmobs.remove_player_npc(playername)
    if not playername then return end
    local npc = player_npcs[playername]
	lf("remove_player_npc", "Total player NPCs: " .. tostring(count_player_npcs()))
    
    if npc and npc:get_luaentity() then
        minetest.log("action", "Removing NPC follower for player " .. playername)
        npc:remove()
    else
        minetest.log("warning", "No NPC follower found for player " .. playername)
    end
    player_npcs[playername] = nil
end

-- Helper: spawn an NPC follower for a player, if they are ltee and don't already have one
function lottmobs.spawn_player_npc(player)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    if not name then return end

    -- Only ltee race players (GAMEltee) should get a follower NPC
    local privs = minetest.get_player_privs(name)
    if not privs.GAMEltee then
        return
    end

    -- Don't spawn a duplicate NPC if one already exists and is valid
    local existing = player_npcs[name]
    if existing and existing:get_luaentity() then
        return
    end

    local pos = vector.add(player:get_pos(), {x = 1, y = 0, z = 0})
    local npc = minetest.add_entity(pos, "lottmobs:ltangel")
    if npc then
        local lua = npc:get_luaentity()
        if lua then
            lua.player_name = name
            lua.base_nametag = name .. "'s angel"
            npc:set_properties({nametag = lua.base_nametag})
            player_npcs[name] = npc
            minetest.chat_send_player(name, "Follower NPC spawned for you.")
            lf("spawn_player_npc", "Total player NPCs: " .. tostring(count_player_npcs()))

        else
            minetest.chat_send_player(name, "NPC entity missing Lua object.")
        end
    else
        minetest.chat_send_player(name, "NPC failed to spawn.")
    end
end



minetest.register_entity("lottmobs:ltangel", {
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
        nametag = "",
        nametag_color = {r = 255, g = 255, b = 255, a = 255},
        static_save = false,
		drawtype = "front",
        immortal = true,
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
        elseif name == "sit" then
            self.object:set_animation({x = anim_def.sit_start, y = anim_def.sit_end}, anim_def.speed_normal, 0)
        end
    end,
    update_hp_tag = function(self)
        if not self.hp_max then return end
        local hp = self.hp or self.hp_max
        local base = self.base_nametag or "NPC"
        self.object:set_properties({
            nametag = base .. " [" .. hp .. "/" .. self.hp_max .. "]"
        })
    end,
    on_activate = function(self)
		self.type = "npc"
		self.race = "GAMEltee"
		self.view_range = 10

		local props = self.object:get_properties()
		self.hp_max = 20
		self.hp = self.hp_max
		self.base_nametag = self.base_nametag or "NPC"
		self.object:set_hp(self.hp_max)
		self.is_disabled = false
		self.combat_timer = 0
		self.in_combat = false

         -- prevent engine damage
		self.object:set_armor_groups({immortal = 1})

        self.timer = 0
		self.spin_timer = 0
        self.say = true

		self:update_hp_tag()
	end,	

    on_punch = function(self, hitter, time_from_last_punch, tool_capabilities, dir, damage)
        local hitter_name = ""
        if hitter and hitter:is_player() then
            hitter_name = hitter:get_player_name() or ""
        else
            local lua = hitter and hitter:get_luaentity()
            hitter_name = lua and lua.name or "<non-player>"
        end

        lf("ltangel on_punch", "hitter: " .. hitter:get_player_name())
        lf("ltangel on_punch", "time_from_last_punch: " .. tostring(time_from_last_punch) .. ", dir: " .. minetest.pos_to_string(dir or {x=0,y=0,z=0}) .. ", damage: " .. tostring(damage))
        -- lf("on_punch", "tool_capabilities: " .. dump(tool_capabilities))
        
        local dmg = damage or 0

        -- If engine damage is 0 (typical for mob vs mob), try mob’s own damage field
        if (not dmg or dmg == 0) and hitter and hitter.get_luaentity then
            local lua = hitter:get_luaentity()
            if lua and lua.damage then
                if type(lua.damage) == "number" then
                    dmg = lua.damage
                elseif type(lua.damage) == "table" then
                    -- mobs_redo often stores per-attack damage in a table
                    dmg = lua.damage.fleshy or lua.damage[1] or 1
                end
            end
        end

        if not dmg or dmg <= 0 then
            dmg = 1  -- final fallback
        end

        -- reduce our custom HP
        self.hp = (self.hp or self.hp_max) - dmg
        -- reduce our custom HP by actual damage value (or 1 if nil)
        -- self.hp = (self.hp or self.hp_max) - dmg


        if self.hp <= 0 then
            -- clamp at 0 and “knock out” instead of dying
            self.hp = 0
            self.is_disabled = true

            -- optional: set animation / log
            self:set_animation("sit")
            lf("ltangel on_punch", "NPC knocked out, HP = 0")
        else
            lf("ltangel on_punch", "HP: " .. self.hp .. "/" .. self.hp_max)
        end

        -- keep engine HP > 0 so it never triggers real death
        self:update_hp_tag()
        self.object:set_hp(self.hp_max)

        -- mark as in combat whenever we take damage
        self.in_combat = true
        self.combat_timer = 0
    end,	
	on_deactivate = function(self)
		clear_ltee_hud(self)
		minetest.log("action", "NPC '" .. (self.player_name or "unknown") .. "' has been deactivated.")
		-- if self.player_name then
		-- 	local player = minetest.get_player_by_name(self.player_name)
		-- 	if player then
		-- 		local pos = vector.add(player:get_pos(), {x = 2, y = 0, z = 0})
		-- 		local npc = minetest.add_entity(pos, "lottmobs:ltangel")
		-- 		if npc then
		-- 			local lua = npc:get_luaentity()
		-- 			if lua then
		-- 				-- lua.player_name = self.player_name
		-- 				lua.player_name = self.player_name
		-- 				lua.base_nametag = self.player_name .. "'s angel"
		-- 				npc:set_properties({nametag = lua.base_nametag})
		-- 				-- Track the re-created NPC so remove_player_npc can find it later
		-- 				player_npcs[self.player_name] = npc
		-- 				minetest.log("action", "NPC '" .. self.player_name .. "' reactivated near the player.")
		-- 			end
		-- 		end
		-- 	end
		-- end		
	end,	
	on_die = function(self, killer)
		clear_ltee_hud(self)
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
        -- Check if player has angel ring in inventory
        local player_has_angel_ring = false
        if self.player_name then
            local player = minetest.get_player_by_name(self.player_name)
            if player then
                local inv = player:get_inventory()
                if inv then
                    for i = 1, 9 do
                        local stack = inv:get_stack("main", i)
                        if stack:get_name() == "lottother:angel_ring" then
                            player_has_angel_ring = true
                            break
                        end
                    end
                end
            end
        end


        local regen_amount = 2
        local regen_timer = 1
        if player_has_angel_ring then
            self.hp_max = 2000
            regen_timer = 1
            regen_amount = math.ceil(self.hp_max * 0.05)
            -- 200% more attack damage (total 3x base) when owner has angel ring
            -- if self.hp > self.hp_max then
            --     self.hp = self.hp_max
            -- end            
            self.attack_damage_multiplier = 3
        else
            regen_timer = 5
            self.hp_max = 20
            regen_amount = math.ceil(self.hp_max * 0.05)
            -- if self.hp > self.hp_max then
            --     self.hp = self.hp_max
            -- end
            self.attack_damage_multiplier = 1
        end

        -- if HP is 0 or below, immediately mark disabled and sit
        if self.hp and self.hp <= 0 then
            self.hp = 0
            self.is_disabled = true
            self:set_animation("sit")
        end

        -- combat idle timer
        self.combat_timer = (self.combat_timer or 0) + dtime
        if self.in_combat and self.combat_timer >= 30 then
            self.in_combat = false
        end

        -- HP regeneration (only when out of combat for at least 30 seconds)
        if not self.in_combat then
            self.hp_regen_timer = (self.hp_regen_timer or 0) + dtime
            if self.hp_regen_timer >= 5 then
                self.hp_regen_timer = 0
                if self.hp and self.hp < self.hp_max then
                    self.hp = self.hp + regen_amount
                    lf("ltangel hp", "regen amount: " .. regen_amount .. ", HP: " .. self.hp .. "/" .. self.hp_max)
                    if self.hp > self.hp_max then
                        self.hp = self.hp_max
                    end
                    if self.hp >= self.hp_max or self.hp > self.hp_max * 0.25 then
                        self.is_disabled = false
                        self:set_animation("stand")
                    end
                end
                self:update_hp_tag()
            end
        end
        self:update_hp_tag()
        -- minetest.log("warning", "NPC step")
        self.timer = self.timer + dtime
        if self.timer < 1 then return end
        -- minetest.log("warning", "NPC step")
        self.spin_timer = self.spin_timer + dtime
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
                -- Follow a point slightly behind the player, based on their look direction
                local player_pos = player:get_pos()
                local look_dir = player:get_look_dir() or {x = 0, y = 0, z = 1}
                local follow_distance = 2
                local vertical_factor = 2 -- match teleport vertical compensation
                local target_pos = {
                    x = player_pos.x - look_dir.x * follow_distance,
                    y = player_pos.y - look_dir.y * follow_distance * vertical_factor,
                    z = player_pos.z - look_dir.z * follow_distance,
                }

                local quotes = {
                    "Hi, LT!  Welcome to Middle-Earth",
                    "I'm LT angel",
                    "we're newly arrived race on the middle earth",
                    "We are a peaceful race here ",
                    "! There are dangerous mobs around",
                    "I'm here to help fight off some mobs",
                    "Our village situated on red grassland",
                    "Feel free to explore around",
                }

                local hud_pos = {x = 0.5, y = 0.8}
                handle_single_player_hud(self, player, dtime, pos, target_pos, quotes, 3, 0xFFFFFF, hud_pos)

                -- new code
                -- Step 1: Check for nearby hostiles
                local hostile_radius = 12
                run_dist = 12
                local hostiles = minetest.get_objects_inside_radius(pos, hostile_radius)
                if not self.is_disabled then
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

                            local dmg_mult = self.attack_damage_multiplier or 1
                            local dmg = 2 * dmg_mult
                            -- Optional: hit mob if close
                            if vector.distance(pos, mob_pos) < 2 then
                                if obj.punch then
                                    obj:punch(self.object, 1.0, {
                                        full_punch_interval = 1.0,
                                        damage_groups = {fleshy = dmg}
                                    }, nil)
                                    lf("lottmobs:ltee", "Hostile mob '" .. lua.name .. "' punched")
                                end						
                                if lua.health then
                                    lua.health = lua.health - dmg
                                    lf("lottmobs:ltee", "Hostile mob '" .. lua.name .. "' health reduced to " .. lua.health)
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
                else
                    lf("lottmobs:ltee", "NPC is disabled")
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

                if dist > run_dist then
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
                elseif dist > 2 then
					local yaw = math.atan2(dir.z, dir.x) + math.pi / 2
					yaw = yaw + math.pi
					self.object:set_yaw(yaw)
					self.object:set_velocity(vector.multiply(dir, 1))
					self:set_animation("walk")
				else
					-- minetest.log("warning", "NPC reached player, stopping")
					self.object:set_velocity({x=0, y=0, z=0})
					if self.is_disabled then
						self:set_animation("sit")
					else
						self:set_animation("stand")
					end
				end
            end
        end
    end,
})
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    minetest.after(1, function()  -- give the world time to load
        if not player or not player:is_player() then return end

        -- Only auto-spawn follower NPCs for ltee race players
        local privs = minetest.get_player_privs(name)
        if not privs.GAMEltee then
            return
        end

        if lottmobs and lottmobs.spawn_player_npc then
            lottmobs.spawn_player_npc(player)
        end
    end)
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if not name then return end
    if lottmobs and lottmobs.remove_player_npc then
        lottmobs.remove_player_npc(name)
    else
        local npc = player_npcs[name]
        if npc and npc:get_luaentity() then
            lf("on_leaveplayer", "NPC removed")
            npc:remove()
        end
        player_npcs[name] = nil
    end
end)

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	if not player or not player:is_player() then
        return
    end
	local name = player:get_player_name()
	local npc = player_npcs[name]
	if not npc then
		return
	end
	local lua = npc:get_luaentity()
	if not lua then
		return
	end
	local player_pos = player:get_pos()
	if not player_pos then
		return
	end
	-- Reposition the angel slightly *behind* the player based on look direction
	local look_dir = player:get_look_dir() or {x = 0, y = 0, z = 1}
	local follow_distance = 2
	local vertical_factor = 2 -- stronger vertical compensation than horizontal
	local target_pos = {
		x = player_pos.x - look_dir.x * follow_distance,
		y = player_pos.y - look_dir.y * follow_distance * vertical_factor,
		z = player_pos.z - look_dir.z * follow_distance,
	}
	npc:set_pos(target_pos)
	lf("npc:on_punch:set_pos", "teleported behind player to: " .. minetest.pos_to_string(target_pos))
	npc:set_velocity({x = 0, y = 0, z = 0})
	lua:set_animation("stand")
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
        		local npc = minetest.add_entity(pos, "lottmobs:ltangel")
		if npc then
			local lua = npc:get_luaentity()
			if lua then
				-- lua.player_name = name
				lua.player_name = name
				lua.base_nametag = name .. "'s angel"
				npc:set_properties({nametag = lua.base_nametag})
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