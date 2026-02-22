------------------------------------------------------------
-- Copyleft (Я) 2022-2023 mazes
-- https://gitlab.com/mazes_80/maidroid
------------------------------------------------------------

maidroid.helpers = {}

local voxels_sets = {}
local default_range = { dist=4, height=3 }

-- Allow to insert in result skipping duplicates and limits
local insert_voxel = function(childrens, inserted, range, x, y, z)
	local key = x .. "|" .. y .. "|" .. z

	-- Closer from initial position
	if inserted[key] then
		return
	end

	-- Check height is ok
	if math.abs(y) >= range.height then
		return
	end

	-- Check manhattan dist is ok
	if math.abs(x) + math.abs(y) + math.abs(z) > range.dist then
		return
	end

	childrens[key] = { x = x, y = y, z = z }
end

local init_voxels = function(range)
	local parents
	local inserted = {}
	local childrens = { }
	local voxels = {}

	childrens["0|0|0"] = vector.zero()

	for _=0, range.dist do
		parents = childrens
		childrens = {}
		-- Insert connected voxels
		for k, v in pairs(parents) do
			inserted[k] = true -- lookup table: check duplicates
			table.insert(voxels, v) -- insert selected child in return value
			insert_voxel(childrens, inserted, range, v.x + 1, v.y, v.z)
			insert_voxel(childrens, inserted, range, v.x - 1, v.y, v.z)
			insert_voxel(childrens, inserted, range, v.x, v.y, v.z + 1)
			insert_voxel(childrens, inserted, range, v.x, v.y, v.z - 1)
			insert_voxel(childrens, inserted, range, v.x, v.y + 1, v.z)
			insert_voxel(childrens, inserted, range, v.x, v.y - 1, v.z)
		end
	end

	-- Insert farther voxels
	for _, v in pairs(parents) do
		table.insert(voxels, v)
	end
	return voxels
end

function maidroid.helpers.search_surrounding(pos, pred, name, range)
	-- minetest.log("warning", "*************************  search_surrounding:"..name)
	pos = vector.round(pos)
	local voxels
	if not range then -- Use the default search range
		voxels = voxels_sets["4,3"]
	else
		local idx = range.dist .. "," .. range.height
		if not voxels_sets[idx] then -- This search range is still not set
			voxels_sets[idx] = init_voxels(range)
		end
		voxels = voxels_sets[idx]
	end
	for _, offset in ipairs(voxels) do
		local ret = vector.add(pos, offset) -- Offset current position

		if pred(ret, name) then
			return ret
		end
	end
end

maidroid.helpers.random_pos_near = function(pos)
	return vector.new(pos.x + (math.random(11)-6)/10, pos.y, pos.z + (math.random(11)-6)/10)
end

maidroid.helpers.emit_sound = function(name, sound, event, pos, gain)
	local def = minetest.registered_nodes[name]
	if def and def.sounds and def.sounds[event] then
		local snd = def.sounds[event]
		minetest.sound_play(snd.name, {pos = pos, gain = snd.gain})
	else
		minetest.sound_play(sound, {pos = pos, gain = gain})
	end
end

maidroid.helpers.is_fence = function(name)
	return minetest.get_item_group(name, "fence") > 0
			or name == "lottblocks:fence_wood"
			or name == "lottblocks:fence_alder"
			or name == "lottblocks:fence_birch"
			or name == "lottblocks:fence_junglewood"
			or name == "lottblocks:fence_lebethron"
			or name:sub(1,7) == "xpanes:"
			or name:sub(1,6) == "doors:"
end

-- maidroid.helpers.is_plant_like = function(name)
-- 	return minetest.get_item_group(name, "plant") > 0
-- 		or minetest.get_item_group(name, "flora") > 0
-- end

maidroid.helpers.is_walkable = function(name)
	return name ~= "air" and minetest.registered_nodes[name]
		and minetest.registered_nodes[name].walkable
end

maidroid.helpers.compact_dump = function(obj, indent, max_line_length)
	indent = indent or ""
	max_line_length = max_line_length or 80
	local result = {}
	local current_line = indent
	
	for k, v in pairs(obj) do
		local key = type(k) == "string" and k or "[" .. tostring(k) .. "]"
		local value
		
		if type(v) == "table" then
			if next(v) == nil then
				value = "{}"
			else
				value = maidroid.helpers.compact_dump(v, indent .. "  ", max_line_length)
			end
		elseif type(v) == "string" then
			if #v > 30 then
				value = '"' .. v:sub(1, 27) .. "..."
			else
				value = '"' .. v .. '"'
			end
		else
			value = tostring(v)
		end
		
		local pair = key .. " = " .. value
		local test_line = current_line == "" and pair or current_line .. ", " .. pair
		
		if #test_line <= max_line_length and not value:find("\n") then
			current_line = test_line
		else
			if current_line ~= "" then
				table.insert(result, current_line)
			end
			current_line = indent .. pair
		end
	end
	
	if current_line ~= "" then
		table.insert(result, current_line)
	end
	
	if #result == 1 then
		return "{ " .. result[1]:sub(#indent + 1) .. " }"
	else
		return "{\n" .. table.concat(result, ",\n") .. "\n" .. indent:gsub("  ", "", 1) .. "}"
	end
end

voxels_sets["4,3"] = init_voxels(default_range) -- initialize voxels for default range
-- vim: ai:noet:ts=4:sw=4:fdm=indent:syntax=lua
