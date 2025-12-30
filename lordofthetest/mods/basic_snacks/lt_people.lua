local skins = {
    "character.png",
    "player_1.png",
    "player_2.png",
    -- Add more skin filenames here
}

-- Function to get a random skin
local function get_random_skin()
    return skins[math.random(#skins)]
end

-- "C:\minetest-jan\V5.6\games\minetest_game\mods\player_api\models\character.b3d"
-- "C:\minetest-jan\V5.6\mods\skinsdb\models\skinsdb_3d_armor_character_5.b3d"


local function get_preview(texture_file)

	-- ,,x1
	-- local player_skin = "("..self:get_texture()..")"
	local player_skin = "("..texture_file..")"
	local skin = ""

	-- Consistent on both sizes:
	--Chest
	skin = skin .. "([combine:16x32:-16,-12=" .. player_skin .. "^[mask:skindb_mask_chest.png)^"
	--Head
	skin = skin .. "([combine:16x32:-4,-8=" .. player_skin .. "^[mask:skindb_mask_head.png)^"
	--Hat
	skin = skin .. "([combine:16x32:-36,-8=" .. player_skin .. "^[mask:skindb_mask_head.png)^"
	--Right Arm
	skin = skin .. "([combine:16x32:-44,-12=" .. player_skin .. "^[mask:skindb_mask_rarm.png)^"
	--Right Leg
	skin = skin .. "([combine:16x32:0,0=" .. player_skin .. "^[mask:skindb_mask_rleg.png)^"

	-- 64x skins have non-mirrored arms and legs
	local left_arm
	local left_leg

	format="1.5"
	if format == "1.8" then
		left_arm = "([combine:16x32:-24,-44=" .. player_skin .. "^[mask:(skindb_mask_rarm.png^[transformFX))^"
		left_leg = "([combine:16x32:-12,-32=" .. player_skin .. "^[mask:(skindb_mask_rleg.png^[transformFX))^"
	else
		left_arm = "([combine:16x32:-44,-12=" .. player_skin .. "^[mask:skindb_mask_rarm.png^[transformFX)^"
		left_leg = "([combine:16x32:0,0=" .. player_skin .. "^[mask:skindb_mask_rleg.png^[transformFX)^"
	end

	-- Left Arm
	skin = skin .. left_arm
	--Left Leg
	skin = skin .. left_leg

	-- Add overlays for 64x skins. these wont appear if skin is 32x because it will be cropped out
	--Chest Overlay
	skin = skin .. "([combine:16x32:-16,-28=" .. player_skin .. "^[mask:skindb_mask_chest.png)^"
	--Right Arm Overlay
	skin = skin .. "([combine:16x32:-44,-28=" .. player_skin .. "^[mask:skindb_mask_rarm.png)^"
	--Right Leg Overlay
	skin = skin .. "([combine:16x32:0,-16=" .. player_skin .. "^[mask:skindb_mask_rleg.png)^"
	--Left Arm Overlay
	skin = skin .. "([combine:16x32:-40,-44=" .. player_skin .. "^[mask:(skindb_mask_rarm.png^[transformFX))^"
	--Left Leg Overlay
	skin = skin .. "([combine:16x32:4,-32=" .. player_skin .. "^[mask:(skindb_mask_rleg.png^[transformFX))"

	-- Full Preview
	skin = "(((" .. skin .. ")^[resize:64x128)^[mask:skindb_transform.png)"

	return skin
end

-- ,,rlt
local function register_lt(mob_name, mob_desc, texture_file, preview)
	mob_id="snacks:"..mob_name
	mobs:register_mob(mob_id, {
		type = "animal",
		passive = false,
		damage = 3,
		attack_type = "dogfight",
		hp_min = 10,
		hp_max = 20,
		armor = 100,
		collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
		visual = "mesh",
		mesh = "character.b3d",
		textures = {
			-- "character_Mary_LT_mt.png"
			texture_file
		},
		child_texture = 
			{"character.png"},
		makes_footstep_sound = true,
		sounds = {
			random = "player_random",
			damage = "player_damage",
		},
		walk_velocity = 1,
		run_velocity = 3,
		jump = true,
		drops = {
			{name = "default:apple", chance = 1, min = 1, max = 2},
		},
		water_damage = 0,
		lava_damage = 2,
		light_damage = 0,
		fall_damage = 1,
		fear_height = 3,
		animation = {
			speed_normal = 30,
			speed_run = 30,
			stand_start = 0,
			stand_end = 79,
			walk_start = 168,
			walk_end = 187,
			run_start = 168,
			run_end = 187,
			punch_start = 189,
			punch_end = 198,
		},
	})
	-- Register spawn egg

	-- mobs:register_egg("snacks:human", "Human Mob", "player_1_preview.png", 0)
	mobs:register_egg(mob_id, mob_desc, preview, 0)
	minetest.log("action", "-- --------------------------------  register LT: "..mob_id )
end

prev=get_preview("character_Mary_LT_mt.png")
-- register_lt("mary", "Mary LT", "character_Mary_LT_mt.png",  "character_Mary_LT_mt.png^[sheet:6x2:2,1")
register_lt("mary", "Mary LT", "character_Mary_LT_mt.png",  prev)
register_lt("alisa", "Alisa LT", "character_player_Alisa2_mt.png",  get_preview("character_player_Alisa2_mt.png"))
register_lt("club", "Club LT", "character_player_Cubes_lil_thing_Club_Mt.png",  get_preview("character_player_Cubes_lil_thing_Club_Mt.png"))


-- register_lt("liam", "Liam LT", "character_Liam_fifth_stolen_LT_mt.png",  "[combine:8x8:0,0=character_Liam_fifth_stolen_LT_mt.png^[sheet:8x4:1,0")
register_lt("liam", "Liam LT", "character_Liam_fifth_stolen_LT_mt.png",  get_preview("character_Liam_fifth_stolen_LT_mt.png"))
register_lt("pat", "Pat LT", "character_player_peters_lt_pat_mt.png",  get_preview("character_player_peters_lt_pat_mt.png"))
register_lt("carlos", "Carlos LT", "character_Carlos_LT_third_LT_stolen_mt.png",  get_preview("character_Carlos_LT_third_LT_stolen_mt.png"))
register_lt("sarah", "Sarah LT", "character_Sarah_LT_fourth_LT_stolen_mt.png",  get_preview("character_Sarah_LT_fourth_LT_stolen_mt.png"))
register_lt("dusk", "dusk", "character_player_Dusk_mt.png",  get_preview("character_player_Dusk_mt.png"))
register_lt("santa", "santa", "character_santa_LT_mt.png",  get_preview("character_santa_LT_mt.png"))


register_lt("farmer", "farmer", "character_farmer.png",  "character_farmer.png")


minetest.log("action", "-- --------------------------------  Player human egg register: " )