class_name ItemStack
extends RefCounted

var definition: ItemDefinition
var quantity: int = 0


func _init(def: ItemDefinition = null, qty: int = 0) -> void:
	definition = def
	quantity = qty


func is_empty() -> bool:
	return definition == null or quantity <= 0


func total_weight_kg() -> float:
	if is_empty():
		return 0.0
	return definition.weight_kg * float(quantity)


func can_merge(other: ItemStack) -> bool:
	if is_empty() or other == null or other.is_empty():
		return false
	if definition != other.definition:
		return false
	return quantity < definition.max_stack
