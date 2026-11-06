extends Node
## Shared world inventories for kitchen props (one loadout per logical storage).

const ID_FRIDGE := &"fridge"
const ID_CABINETS := &"cabinets"
const ID_METAL_SHELVES := &"metal_shelves"
const ID_TOASTER := &"toaster"
const ID_TV := &"tv"
const ID_MICROWAVE := &"microwave"

var _by_id: Dictionary = {}


func _ready() -> void:
	_register(ID_FRIDGE)
	_register(ID_CABINETS)
	_register(ID_METAL_SHELVES)
	_register(ID_TOASTER)
	_register(ID_TV)
	_register(ID_MICROWAVE)
	_seed_demo_items()


func _seed_demo_items() -> void:
	var can := preload("res://resources/items/canned_food.tres") as ItemDefinition
	var bandage := preload("res://resources/items/bandage.tres") as ItemDefinition
	if can != null:
		var fr: PlayerLoadout = _by_id[ID_FRIDGE]
		if fr != null:
			fr.try_add_item(can, 2)
		var cab: PlayerLoadout = _by_id[ID_CABINETS]
		if cab != null:
			cab.try_add_item(can, 2)
		var mw: PlayerLoadout = _by_id[ID_MICROWAVE]
		if mw != null:
			mw.try_add_item(can, 1)
		var ts: PlayerLoadout = _by_id[ID_TOASTER]
		if ts != null:
			ts.try_add_item(can, 1)
	if bandage != null:
		var sh: PlayerLoadout = _by_id[ID_METAL_SHELVES]
		if sh != null:
			sh.try_add_item(bandage, 2)


func _register(id: StringName) -> void:
	var pl := PlayerLoadout.new()
	pl.backpack_enabled = false
	pl.clear_favorite()
	_by_id[id] = pl


func loadout(id: StringName) -> PlayerLoadout:
	return _by_id.get(id, null) as PlayerLoadout


func interact_label(id: StringName) -> String:
	match id:
		ID_FRIDGE:
			return "Холодильник"
		ID_CABINETS:
			return "Шкафы"
		ID_METAL_SHELVES:
			return "Металлические полки"
		ID_TOASTER:
			return "Тостер"
		ID_TV:
			return "Телевизор"
		ID_MICROWAVE:
			return "Микроволновка"
	return "Хранилище"
