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

minetest.register_craftitem("snacks:cupcake", {
	description = ("cupcake"),
	inventory_image = "snack_cupcake.png",
	on_use = minetest.item_eat(2),
})


-- minetest.register_craftitem("snacks:pocky_strawberry", {
-- 	description = ("Pocky Strawberry"),
-- 	inventory_image = "pocky_strawberry.png",
-- 	on_use = minetest.item_eat(2),
-- })


minetest.register_craft( {
	output = "snacks:pretzel",
	recipe = {
		{"farming:flour", "", ""},
		{"farming:flour", "", ""},
		{"farming:flour", "", ""}
	}
})

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

