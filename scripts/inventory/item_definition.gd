class_name ItemDefinition
extends Resource

enum Category { MISC, GEAR, CONSUMABLE, MATERIAL, FOOD }

@export var id: StringName = &""
@export var display_name: String = "Предмет"
@export var weight_kg: float = 1.0
@export var max_stack: int = 1
@export var category: Category = Category.MISC


func category_name() -> String:
	match category:
		Category.GEAR:
			return "снаряжение"
		Category.CONSUMABLE:
			return "расходник"
		Category.MATERIAL:
			return "материал"
		Category.FOOD:
			return "еда"
		_:
			return "разное"


func is_usable() -> bool:
	return category == Category.CONSUMABLE or category == Category.FOOD
