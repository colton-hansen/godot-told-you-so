extends Node

enum Phase { MORNING, RAID, EVENING, ENDED }

const BASE := "res://scenes/basement/basement_hub.tscn"
const MALL := "res://scenes/mall/mall.tscn"
const FOOD := preload("res://resources/items/canned_food.tres")
const WATER := preload("res://resources/items/water_bottle.tres")
const BANDAGE := preload("res://resources/items/bandage.tres")

var phase := Phase.MORNING
var day := 1
var raid_seed := -1
var inventory: PlayerLoadout
var collected := 0
var food := 0
var water := 0
var deficit := 0
var report := ""
var _hud: Label


func _ready() -> void:
	_new_inventory()
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(18, 14)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_hud)
	_refresh()


func _new_inventory() -> void:
	inventory = PlayerLoadout.new()
	inventory.backpack_enabled = true
	inventory.try_add_item(FOOD, 2)
	inventory.try_add_item(WATER)
	inventory.try_add_item(BANDAGE)
	inventory.item_used.connect(_record_use)


func _record_use(item: ItemDefinition) -> void:
	if phase == Phase.ENDED:
		return
	if item.category == ItemDefinition.Category.FOOD:
		food += 1
	elif item.category == ItemDefinition.Category.DRINK:
		water += 1
	_refresh()


func begin_raid() -> void:
	if phase != Phase.MORNING:
		return
	if get_tree().change_scene_to_file(MALL) != OK:
		return
	phase = Phase.RAID
	raid_seed = randi()
	collected = 0
	report = ""
	_refresh()


func take_loot(item: ItemDefinition) -> bool:
	if phase != Phase.RAID or inventory.try_add_item(item) != 1:
		return false
	collected += 1
	_refresh()
	return true


func evacuate() -> void:
	_return_to_base(false)


func caught() -> void:
	_return_to_base(true)


func _return_to_base(failed: bool) -> void:
	if phase != Phase.RAID or get_tree().change_scene_to_file(BASE) != OK:
		return
	phase = Phase.ENDED if failed else Phase.EVENING
	report = "Run ended: caught by mall security. Rest in the living room to restart." if failed else (
		"Evacuated. Supplies picked up: %d. Eat, drink, then rest in the living room." % collected)
	_refresh()


func rest() -> void:
	if phase == Phase.ENDED:
		KitchenStorages.reset()
		_new_inventory()
		day = 1
		deficit = 0
		report = ""
		phase = Phase.MORNING
		food = 0
		water = 0
		get_tree().reload_current_scene()
	elif phase == Phase.EVENING:
		var missed := int(food == 0) + int(water == 0)
		deficit = maxi(0, deficit - 1) if missed == 0 else deficit + missed
		if deficit >= 4:
			phase = Phase.ENDED
			report = "Run ended: out of supplies. Rest in the living room to restart."
		else:
			day += 1
			phase = Phase.MORNING
			report = "Rested. Ready for another raid." if missed == 0 else "Rested without enough supplies."
		food = 0
		water = 0
	_refresh()


func reset_debug_layout() -> void:
	raid_seed = randi()


func _refresh() -> void:
	if _hud == null:
		return
	var title: String = ["PREPARE", "RAID", "REST", "RUN OVER"][phase]
	_hud.text = "DAY %d  /  %s   |   FOOD %d/1   WATER %d/1   DEPRIVATION %d/4" % [
		day, title, mini(food, 1), mini(water, 1), deficit]
	if not report.is_empty():
		_hud.text += "\n" + report
