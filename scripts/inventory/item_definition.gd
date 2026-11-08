class_name ItemDefinition
extends Resource

enum Category { MISC, GEAR, CONSUMABLE, MATERIAL, FOOD, DRINK }

@export var id: StringName = &""
@export var display_name: String = "Item"
@export var weight_kg: float = 1.0
@export var max_stack: int = 1
@export var category: Category = Category.MISC


func category_name() -> String:
	match category:
		Category.GEAR:
			return "gear"
		Category.CONSUMABLE:
			return "consumable"
		Category.MATERIAL:
			return "material"
		Category.FOOD:
			return "food"
		Category.DRINK:
			return "drink"
		_:
			return "misc"


func is_usable() -> bool:
	return (
		category == Category.CONSUMABLE
		or category == Category.FOOD
		or category == Category.DRINK
	)
