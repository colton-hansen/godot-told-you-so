extends Node
## Shared world inventories for hub appliances.

const ID_FRIDGE := &"fridge"
const ID_FREEZER := &"freezer"
const ID_DRINK_FRIDGE := &"drink_fridge"
const ID_DRAWERS := &"drawers"
const ID_CABINETS := &"cabinets"
const ID_METAL_SHELVES := &"metal_shelves"
const ID_TOASTER := &"toaster"
const ID_TV := &"tv"
const ID_MICROWAVE := &"microwave"

const COOKER_SLOT_COUNT := 2

var _by_id: Dictionary = {}


func _ready() -> void:
	_register(ID_FRIDGE)
	_register(ID_FREEZER)
	_register(ID_DRINK_FRIDGE)
	_register(ID_DRAWERS)
	_register(ID_MICROWAVE, COOKER_SLOT_COUNT)
	_register(ID_TOASTER, COOKER_SLOT_COUNT)
	_seed_demo_items()


func _seed_demo_items() -> void:
	var can := preload("res://resources/items/canned_food.tres") as ItemDefinition
	var water := preload("res://resources/items/water_bottle.tres") as ItemDefinition
	var bandage := preload("res://resources/items/bandage.tres") as ItemDefinition
	if can != null:
		var fr: PlayerLoadout = _by_id[ID_FRIDGE]
		if fr != null:
			fr.try_add_item(can, 2)
		var fz: PlayerLoadout = _by_id[ID_FREEZER]
		if fz != null:
			fz.try_add_item(can, 1)
	if water != null:
		var dr: PlayerLoadout = _by_id[ID_DRINK_FRIDGE]
		if dr != null:
			dr.try_add_item(water, 2)
	if bandage != null:
		var dw: PlayerLoadout = _by_id[ID_DRAWERS]
		if dw != null:
			dw.try_add_item(bandage, 2)


func _register(id: StringName, slot_count: int = InventoryLayout.STORAGE_SLOT_COUNT) -> void:
	var pl := PlayerLoadout.new()
	pl.setup_storage(slot_count)
	_by_id[id] = pl


func is_cooker(id: StringName) -> bool:
	return id == ID_MICROWAVE or id == ID_TOASTER


func loadout(id: StringName) -> PlayerLoadout:
	return _by_id.get(id, null) as PlayerLoadout


func interact_label(id: StringName) -> String:
	match id:
		ID_FRIDGE:
			return "Fridge"
		ID_FREEZER:
			return "Freezer"
		ID_DRINK_FRIDGE:
			return "Drink Fridge"
		ID_DRAWERS:
			return "Drawers"
		ID_MICROWAVE:
			return "Microwave"
		ID_TOASTER:
			return "Toaster"
	return "Storage"


func accepts_item(id: StringName, def: ItemDefinition) -> bool:
	if def == null:
		return false
	match id:
		ID_DRINK_FRIDGE:
			return def.category == ItemDefinition.Category.DRINK
		ID_FRIDGE, ID_FREEZER, ID_MICROWAVE, ID_TOASTER:
			return def.category == ItemDefinition.Category.FOOD
		ID_DRAWERS:
			return (
				def.category != ItemDefinition.Category.FOOD
				and def.category != ItemDefinition.Category.DRINK
			)
	return true
