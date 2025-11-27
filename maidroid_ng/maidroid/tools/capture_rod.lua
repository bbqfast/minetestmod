------------------------------------------------------------
-- Copyright (c) 2016 tacigar. All rights reserved.
------------------------------------------------------------
-- Copyleft (Я) 2021-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

local S = maidroid.translator

local rod_uses = maidroid.settings.tools_capture_rod_uses

local maid_skins = {
    "character_Mary_LT_mt.png^[invert:r",
    "character_Dave_Lt_mt.png^[invert:r",
    "character_Dave_Lt_mt.png^[invert:g",
    "character_Dave_Lt_mt.png^[invert:b",
    "character_Mary_LT_mt.png^[invert:g",
    "character_Mary_LT_mt.png^[invert:b",
    -- Add more skin filenames here
}

mydump = function(lbl, obj)
	pre="**************************************************"
	pre="++++++++++++++++++++++++++++++++++++++++++++++++++"
	if msg == nil then
		msg = "null"
	end

	-- minetest.log("warning", pre..msg)
	minetest.log("warning", "====================== "..lbl..":"..dump(obj))
	
	
end

mylog = function(msg)
	pre="**************************************************"
	pre="++++++++++++++++++++++++++++++++++++++++++++++++++"
	if msg == nil then
		msg = "null"
	end

	minetest.log("warning", pre..msg)
end

minetest.register_tool("maidroid:capture_rod", {
	description = S("maidroid capture rod"),
	inventory_image = "maidroid_tool_capture_rod.png",
	on_use = function(itemstack, user, pointed_thing)
		minetest.log("warning", "====================== capture_rod")
		if (pointed_thing.type ~= "object") then
			minetest.log("warning", "non object"..pointed_thing.type)
			return
		end

		local obj = pointed_thing.ref
		if obj:is_player() then
			return
		end
		local luaentity = obj:get_luaentity()
		if luaentity == nil then
			minetest.log("warning", "Nil entity")
			return
		end
		if not maidroid.is_maidroid(luaentity.name) then
			if luaentity.name == "__builtin:item" then
				luaentity:on_punch(user)
			end
			return
		end

		-- ensure mydroid belongs to user, maidroid admins bypass player name
		if not luaentity.player_can_control(luaentity, user) then
			minetest.log("warning", "player_can_control = false")
			return itemstack
		end

		local maidroid_name = luaentity.name:sub(10)
		local stack = ItemStack("maidroid_tool:captured_" .. maidroid_name .. "_egg")
		-- #,,x1

		local eeee = luaentity.object:get_properties()
		-- minetest.log("warning", "====================== capture_rod2:"..dump(eeee))
		mydump("capture_rod2", eeee)


		local sdata = luaentity:get_staticdata("capture")
		local sdatad = minetest.deserialize(sdata)
		sdatad.textures = eeee["textures"][1]
		sdata = minetest.serialize(sdatad)
		-- stack:set_metadata(luaentity:get_staticdata("capture"))
		-- minetest.log("warning", "====================== capture_rod3:"..dump(sdatad))
		mydump("capture_rod3", sdatad)
		stack:set_metadata(sdata)

		-- ,,text
		-- meta["textures"] = maidroid.generate_texture(tonumber(maidroid_name:sub(-2):gsub("k","")))
		-- meta = minetest.serialize(meta)

		-- stack:set_metadata({"capture":luaentity:get_staticdata("capture"), "pos": 5})

		local user_inv = minetest.get_inventory({type="player", name=user:get_player_name()})
		local leftover = user_inv:add_item("main", stack)

		local pos
		if leftover:get_count() > 0 then
			pos = vector.add(obj:get_pos(), {x = 0, y = 1, z = 0})
			minetest.add_item(pos, stack)
		end

		luaentity.wield_item:remove()
		pos = obj:get_pos()
		obj:remove()
		mylog("Rod capture obj remove")

		if maidroid.settings.tools_capture_rod_wears or
			not minetest.check_player_privs(user:get_player_name(), { maidroid = true }) then
			itemstack:add_wear(65535 / (rod_uses - 1))
		end

		minetest.sound_play("maidroid_tool_capture_rod_use", {pos = pos})
		minetest.add_particlespawner({
			amount = 20,
			time = 0.2,
			minpos = pos,
			maxpos = pos,
			minvel = {x = -1.5, y = 2, z = -1.5},
			maxvel = {x = 1.5,  y = 4, z = 1.5},
			minacc = {x = 0, y = -8, z = 0},
			maxacc = {x = 0, y = -4, z = 0},
			minexptime = 1,
			maxexptime = 1.5,
			minsize = 1,
			maxsize = 2.5,
			collisiondetection = true,
			vertical = false,
			texture = "maidroid_tool_capture_rod_star.png",
			player = user
		})

		minetest.log("warning", "====================== Rod capture END")
		return itemstack
	end
})


for name, _ in pairs(maidroid.registered_maidroids) do
	local maidroid_name = name:sub(10)
	local egg_def = minetest.registered_tools["maidroid:maidroid_egg"]
	local inv_img = "maidroid_tool_capture_rod_plate.png^" .. egg_def.inventory_image

	minetest.register_tool(":maidroid_tool:captured_" .. maidroid_name .. "_egg", {
		description = S("Captured ") .. egg_def.description,
		inventory_image = inv_img,
		groups = {not_in_creative_inventory = 1},
		on_use = function(itemstack, user, pointed_thing)
			minetest.log("warning", "====================== captured_egg")
			if pointed_thing.type ~= "node" then
				if pointed_thing.type == "object" then
					local luaentity = pointed_thing.ref:get_luaentity()
					if luaentity and luaentity.name == "__builtin:item" then
						luaentity:on_punch(user)
					end
				end
				return
			end

			local meta = itemstack:get_metadata()
			-- minetest.log("warning", "====================== captured_xxxxxx_2"..dump(meta["textures"]))
			-- minetest.log("warning", "====================== captured_xxxxxx_2"..dump(meta))
			mydump("captured_egg_2 metadata full", meta)
			-- Fix stack metadata if it is an "old maidroid"
			if maidroid.settings.compat then
				if maidroid_name:find("maidroid_mk") then
					minetest.log("[MOD] maidroid: Old egg used. Converting")
					meta = minetest.deserialize(meta)
					-- ,,text
					meta["textures"] = maidroid.generate_texture(tonumber(maidroid_name:sub(-2):gsub("k","")))
					meta = minetest.serialize(meta)
				end
			end

			-- ,,text
			local m_skin = maid_skins[math.random(6) - 1]
			-- m_skin = meta["textures"]
			meta = minetest.deserialize(meta)
			-- minetest.log("warning", "====================== captured_xxxxxx_3"..dump(meta["textures"]))
			mydump("captured_egg_3 textures", meta["textures"])
			-- minetest.log("warning", "====================== captured_xxxxxx_3"..meta["textures"])
			-- meta["textures"] = maidroid.generate_texture(tonumber(maidroid_name:sub(-2):gsub("k","")))
			-- meta["textures"] = m_skin
			m_skin = meta["textures"]
			minetest.log("warning", "====================== captured_egg_5"..m_skin)

			if m_skin == nil then
				minetest.log("warning", "====================== captured_egg_5:null skin")
				return
			end


			meta = minetest.serialize(meta)	

			local obj = minetest.add_entity(pointed_thing.above, "maidroid:maidroid", meta)
			local luaentity = obj:get_luaentity()

			luaentity:set_yaw({obj:get_pos(), user:get_pos()})

			-- Set the custom texture for the "maidroid:maidroid" entity
			-- maidroid_entity:set_textures({ { name = m_skin, animation = { type = "vertical_frames", length = 1.0 } } })


			minetest.log("warning", "====================== captured_egg_6"..m_skin)
			obj:set_properties({
				textures = {m_skin}
			})

		

			local pos = vector.add(obj:get_pos(), {x = 0, y = -0.2, z = 0})
			minetest.sound_play("maidroid_tool_capture_rod_open_egg", {pos = pos})
			minetest.add_particlespawner({
				amount = 30,
				time = 0.1,
				minpos = pos,
				maxpos = pos,
				minvel = {x = -2, y = 1.0, z = -2},
				maxvel = {x = 2,  y = 2.5, z = 2},
				minacc = {x = 0, y = -5, z = 0},
				maxacc = {x = 0, y = -2, z = 0},
				minexptime = 0.5,
				maxexptime = 1,
				minsize = 0.5,
				maxsize = 2,
				collisiondetection = false,
				vertical = false,
				texture = "maidroid_tool_capture_rod_star.png^[colorize:#ff8000:127",
				player = user
			})

			local rad = user:get_look_horizontal()
			minetest.add_particle({
				pos = pos,
				velocity = {x = math.cos(rad) * 2, y = 1.5, z = math.sin(rad) * 2},
				acceleration = {x = 0, y = -3, z = 0},
				expirationtime = 1.5,
				size = 6,
				collisiondetection = false,
				vertical = false,
				texture = "(" .. inv_img .. "^[resize:32x32)^[mask:maidroid_tool_capture_rod_mask_right.png",
				player = user
			})
			minetest.add_particle({
				pos = pos,
				velocity = {x = math.cos(rad) * -2, y = 1.5, z = math.sin(rad) * -2},
				acceleration = { x = 0, y = -3, z = 0},
				expirationtime = 1.5,
				size = 6,
				collisiondetection = false,
				vertical = false,
				texture = "(" .. inv_img .. "^[resize:32x32)^[mask:maidroid_tool_capture_rod_mask_left.png",
				player = user
			})

			itemstack:take_item()
			return itemstack
		end,
	})
end

minetest.register_alias("maidroid_tool:capture_rod", "maidroid:capture_rod")
-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
