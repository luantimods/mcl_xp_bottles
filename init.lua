-- parts of this code is copied from Mineclonia game mod mcl_experience throwing ability
-- copied code is changed to allow amount specified in throwing
-- adds Bottled XP (N) for 1, 5, 10, 50, 100, 500, 1k, 5k, 10k, 50k
-- player can throw them or consume them
-- player can hold "Glass Bottle" and fill it with largest XP from their XP bar

local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local S = core.get_translator(modname)

local function fill_table(word, count)
	local tbl = {}

	for i = 1, count do
		table.insert(tbl, word)
	end

	return tbl
end

-- copied from /games/mineclonia/mods/HUD/mcl_experience/bottle.lua
-- modifed to have an amount value instead of math.random(3, 11)
core.register_entity(modname..":bottle",{
	initial_properties = {
		textures = {"mcl_experience_bottle.png"},
		hp_max = 1,
		visual_size = {x = 0.35, y = 0.35},
		collisionbox = {-0.1, -0.1, -0.1, 0.1, 0.1, 0.1},
		pointable = false,
	},

	amount = 0,

	on_step = function(self, _)
		local pos = self.object:get_pos()
		local node = core.get_node(pos)
		local n = node.name
		if n ~= "air" and n ~= "mcl_portals:portal" and n ~= "mcl_portals:portal_end" and core.get_item_group(n, "liquid") == 0 then
			core.sound_play("mcl_potions_breaking_glass", {pos = pos, max_hear_distance = 16, gain = 1})
			mcl_experience.throw_xp(pos, self.amount)
			core.add_particlespawner({
				amount = 50,
				time = 0.1,
				minpos = vector.add(pos, vector.new(-0.1, 0.5, -0.1)),
				maxpos = vector.add(pos, vector.new( 0.1, 0.6,  0.1)),
				minvel = vector.new(-2, 0, -2),
				maxvel = vector.new( 2, 2,  2),
				minacc = vector.new(0, 0, 0),
				maxacc = vector.new(0, 0, 0),
				minexptime = 0.5,
				maxexptime = 1.25,
				minsize = 1,
				maxsize = 2,
				collisiondetection = true,
				vertical = false,
				texture = "mcl_particles_effect.png^[colorize:blue:127",
			})
			if mod_target and n == "mcl_target:target_off" then
				mcl_target.hit(vector.round(pos), 0.4) --4 redstone ticks
			end
			self.object:remove()
		end
	end,
})

-- copied from /games/mineclonia/mods/HUD/mcl_experience/bottle.lua
-- modified to have min, max xp values (used in XP bottles to throw set amounts)
local function throw_xp_bottle(pos, dir, velocity, min, max)
	core.sound_play("mcl_throwing_throw", {pos = pos, gain = 0.4, max_hear_distance = 16}, true)
	local obj = core.add_entity(pos, modname..":bottle")
	if not obj or not obj:get_pos() then return end
	obj:set_velocity(vector.multiply(dir, velocity))
	local acceleration = vector.multiply(dir, -3)
	acceleration.y = -9.81
	obj:set_acceleration(acceleration)
	min = min or 3
	max = max or min
	obj:get_luaentity().amount = math.random(min, max)
end

-- XP bottles to register
local bottled_xp_values = {
	-- XP amount, text display, count needed for joining / splitting
	{xp=1, text="1", craft=5},
	{xp=5, text="5", craft=2},
	{xp=10, text="10", craft=5},
	{xp=50, text="50", craft=2},
	{xp=100, text="100", craft=5},
	{xp=500, text="500", craft=2},
	{xp=1000, text="1k", craft=5},
	{xp=5000, text="5k", craft=2},
	{xp=10000, text="10k", craft=5},
	{xp=50000, text="50k", craft=2},
	-- how big should they be?
	-- {xp=100000, text="100k", craft=5},
	-- {xp=500000, text="500k", craft=2},
	-- {xp=1000000, text="1m", craft=5},
	-- {xp=5000000, text="5m", craft=2},
}

-- register XP bottles loop
-- register each bottle with crafting into higher or lower bottles
local lentry = nil
for index, entry in ipairs(bottled_xp_values) do
	local xp = entry["xp"]
	core.register_craftitem(modname .. ":bottled_xp_" .. entry.text, {
		description = S("Bottled XP") .. " (" .. entry.text .. ")",
		inventory_image = "mcl_experience_bottle.png",
		wield_image = "mcl_experience_bottle.png",

		-- throw it
		on_use = function(itemstack, placer, _)
			throw_xp_bottle(vector.add(placer:get_pos(), vector.new(0, 1.5, 0)), placer:get_look_dir(), 10, xp)
			if not core.is_creative_enabled(placer:get_player_name()) then
				itemstack:take_item()
			end
			return itemstack
		end,

		-- use on self
		on_secondary_use = function(itemstack, player, pointed_thing)
			mcl_experience.set_xp(player, mcl_experience.get_xp(player) + xp)
			if not core.is_creative_enabled(player:get_player_name()) then
				-- take the XP bottle
				itemstack:take_item()

				-- lets give the player an empty bottle
				local inv = player:get_inventory()
				local itemstack = ItemStack("mcl_potions:glass_bottle")
				local leftover = inv:add_item("main", itemstack)
			end
			return itemstack
		end,

		-- dispensed
		_on_dispense = function(_, pos, _, _, dir)
			throw_xp_bottle(vector.add(pos, vector.multiply(dir, 0.51)), dir, 10, xp)
		end

	})

	if lentry then
		-- craft N previous entry with 1 current
		local craft = {
			type = "shapeless",
			output = modname .. ":bottled_xp_" .. lentry.text .. " " .. lentry.craft,
			recipe = fill_table(modname .. ":bottled_xp_" .. entry.text, 1)
		}
		core.register_craft(craft)

		-- craft 1 current with N previous
		local craft = {
			type = "shapeless",
			output = modname .. ":bottled_xp_" .. entry.text .. " 1",
			recipe = fill_table(modname .. ":bottled_xp_" .. lentry.text, lentry.craft)
		}
		core.register_craft(craft)
	end

	lentry = entry
end

-- calculate bigest xp bottle for players xp, take it and place in given inv or player "main"
-- returns true if succesful, false if inv full, nil if no XP left
mcl_potions.xp_to_bottle = function(player, inv, listname)
	inv = inv or player:get_inventory()
	listname = listname or "main"

	local pname = player:get_player_name()
	local xp = mcl_experience.get_xp(player)

	local take_xp = 0
	local bottle_name
	for _, entry in ipairs(bottled_xp_values) do
		if entry.xp <= xp then
			take_xp = entry.xp
			bottle_name = entry.text
		end
	end

	if take_xp > 0 then
		local give_itemstack = ItemStack(modname .. ":bottled_xp_" .. bottle_name)
		local leftover = inv:add_item("main", give_itemstack)
		-- only if we managed to add XP bottle to inventory?
		if leftover:is_empty() then
			mcl_experience.set_xp(player, xp - take_xp)

			core.log("action", pname .. " bottled " .. take_xp .. " xp")

			return true
		else
			return false
		end
	end
end

local mcl_potions_glass_bottle_def = core.registered_items["mcl_potions:glass_bottle"]
if mcl_potions_glass_bottle_def then
	core.override_item("mcl_potions:glass_bottle", {
		on_secondary_use = function(itemstack, player, pointed_thing)
			local pname = player:get_player_name()
			local result = mcl_potions.xp_to_bottle(player)
			if result == true then
				if not core.is_creative_enabled(pname) then
					itemstack:take_item()
				end
			elseif result == false then
				core.chat_send_player(pname, S("Not enough space for XP bottle"))
			end

			return itemstack
		end,
	})
end
