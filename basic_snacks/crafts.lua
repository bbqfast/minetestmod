-- Lamb Kebab Raw
minetest.register_craftitem("snacks:pocky_original", {
	description = ("Pocky Original"),
	inventory_image = "pocky_original.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:pretzel", {
	description = ("pretzel"),
	inventory_image = "snack_pretzel.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craft( {
	output = "snacks:pretzel",
	recipe = {
		{"farming:flour", "farming:salt", ""},
		{"farming:flour", "", ""},
		{"farming:flour", "", ""}
	}
})

minetest.register_craftitem("snacks:cupcake", {
	description = ("cupcake"),
	inventory_image = "snack_cupcake.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:strawberry_shortcake", {
	description = ("strawberry shortcake"),
	-- inventory_image = "snack_strawberry_shortcake.png",
	--inventory_image = "snack_cupcake.png",
	inventory_image = "snack_strawberry_shortcake.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:matcha_cake", {
	description = ("matcha cake"),
	inventory_image = "snack_matcha_cake.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:carrot_cake", {
	description = ("carrot cake"),
	inventory_image = "snack_carrot_cake.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:boba_tea", {
	description = ("boba tea"),
	inventory_image = "snack_boba_tea.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:cinnamon_roll", {
	description = ("cinnamon roll"),
	inventory_image = "snack_cinnamon_roll.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:red_velvet_donut", {
	description = ("red velvet donut"),
	inventory_image = "snack_red_velvet_donut.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:raspberry_donut", {
	description = ("raspberry donut"),
	inventory_image = "snack_raspberry_donut.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craft( {
	output = "snacks:raspberry_donut",
	recipe = {
		{"", "group:food_raspberries", ""},
		{"", "farming:donut", ""},
		{"", "", ""}
	}
})

minetest.register_craftitem("snacks:oreo_donut", {
	description = ("cookies n' cream donut"),
	inventory_image = "snack_oreo_donut.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:vanilla_donut", {
	description = ("vanilla donut"),
	inventory_image = "snack_vanilla_donut.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craft( {
	output = "snacks:vanilla_donut",
	recipe = {
		{"", "farming:vanilla", ""},
		{"", "farming:donut", ""},
		{"", "", ""}
	}
})

minetest.register_craftitem("snacks:mint_donut", {
	description = ("mint chocolate donut"),
	inventory_image = "snack_mint_donut.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craft( {
	output = "snacks:mint_donut",
	recipe = {
		{"", "group:food_mint", ""},
		{"", "farming:donut_chocolate", ""},
		{"", "", ""}
	}
})

minetest.register_craftitem("snacks:lemon_donut", {
	description = ("lemon donut"),
	inventory_image = "snack_lemon_donut.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:orange_donut", {
	description = ("orange donut"),
	inventory_image = "snack_orange_donut.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craft( {
	output = "snacks:mint_donut",
	recipe = {
		{"", "group:food_mint", ""},
		{"", "farming:donut_chocolate", ""},
		{"", "", ""}
	}
})

minetest.register_craftitem("snacks:swiss_roll", {
	description = ("chocolate swiss roll"),
	inventory_image = "snack_swiss_roll.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:strawberry_roll", {
	description = ("strawberry swiss roll"),
	inventory_image = "snack_strawberry_roll.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:raspberry_roll", {
	description = ("raspberry swiss roll"),
	inventory_image = "snack_raspberry_roll.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:berry_muffin", {
	description = ("mixed berry muffin"),
	inventory_image = "snack_berry_muffin.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:bread", {
	description = ("bread loaf"),
	inventory_image = "snack_bread.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craft( {
	output = "snacks:bread",
	recipe = {
		{"farming:bread", "farming:bread", "farming:bread"},
		{"farming:bread", "farming:bread", "farming:bread"},
		{"farming:bread", "farming:bread", "farming:bread"}
	}
})

minetest.register_craftitem("snacks:souffle", {
	description = ("souffle pancake (proto)"),
	inventory_image = "snack_souffle.png",
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("snacks:cream", {
	description = ("cream"),
	inventory_image = "snack_cream.png",
	on_use = minetest.item_eat(2),
})

-- minetest.register_craftitem("snacks:pocky_strawberry", {
-- 	description = ("Pocky Strawberry"),
-- 	inventory_image = "pocky_strawberry.png",
-- 	on_use = minetest.item_eat(2),
-- })



minetest.register_craft( {
	output = "snacks:pocky_original",
	recipe = {
		{"snacks:pretzel", "", ""},
		{"snacks:pretzel", "", ""},
		{"snacks:pretzel", "", ""}
	}
})

minetest.register_craft( {
	output = "snacks:pocky_strawberry",
	recipe = {
		{"default:copper_ingot", "default:copper_ingot"},
		{"default:copper_ingot", ""}
	}
})