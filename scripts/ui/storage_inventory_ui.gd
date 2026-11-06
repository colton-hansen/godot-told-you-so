extends CanvasLayer
class_name StorageInventoryUI
## Four-slot grid for a shared world PlayerLoadout.

signal opened
signal closed

const SlotControl := preload("res://scripts/ui/inventory_slot_control.gd")
const ContextMenuScript := preload("res://scripts/ui/inventory_item_context_menu.gd")

@onready var _panel: PanelContainer = $Panel
@onready var _grid: GridContainer = $Panel/Margin/VBox/Grid
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _context_menu: PopupMenu = $ContextMenu

var is_open: bool = false
var _loadout: PlayerLoadout
var _bound_loadout: PlayerLoadout
var _slot_controls: Array[InventorySlotControl] = []
var _context_area: PlayerLoadout.Area = PlayerLoadout.Area.POCKET
var _context_index: int = -1


func setup_storage(loadout: PlayerLoadout, title_text: String) -> void:
	if _bound_loadout != null and _bound_loadout.changed.is_connected(_refresh_all):
		_bound_loadout.changed.disconnect(_refresh_all)
	_loadout = loadout
	_bound_loadout = loadout
	if _title != null:
		_title.text = title_text
	if _loadout != null and not _loadout.changed.is_connected(_refresh_all):
		_loadout.changed.connect(_refresh_all)
	if _context_menu != null and _context_menu.has_signal("action_chosen"):
		if not _context_menu.action_chosen.is_connected(_on_context_action):
			_context_menu.action_chosen.connect(_on_context_action)
	_build_slots()
	_refresh_all()
	if _panel != null:
		_panel.visible = false
	is_open = false


func open_with(loadout: PlayerLoadout, title_text: String) -> void:
	if _bound_loadout != null and _bound_loadout.changed.is_connected(_refresh_all):
		_bound_loadout.changed.disconnect(_refresh_all)
	_loadout = loadout
	_bound_loadout = loadout
	if _title != null:
		_title.text = title_text
	if _loadout != null and not _loadout.changed.is_connected(_refresh_all):
		_loadout.changed.connect(_refresh_all)
	if _context_menu != null and _context_menu.has_signal("action_chosen"):
		if not _context_menu.action_chosen.is_connected(_on_context_action):
			_context_menu.action_chosen.connect(_on_context_action)
	_build_slots()
	_refresh_all()
	is_open = true
	if _panel != null:
		_panel.visible = true
	opened.emit()
	_refresh_all()


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _panel != null:
		_panel.visible = false
	closed.emit()


func _build_slots() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_slot_controls.clear()
	for i in InventoryLayout.POCKET_COUNT:
		var slot := SlotControl.new()
		slot.frame_kind = SlotControl.FrameKind.POCKET
		slot.pocket_index = i
		slot.bind_loadout(_loadout)
		slot.equip_requested.connect(_on_equip_requested)
		slot.context_requested.connect(_on_context_requested)
		_grid.add_child(slot)
		_slot_controls.append(slot)


func _on_equip_requested(_area: PlayerLoadout.Area, _index: int) -> void:
	pass


func _on_context_requested(area: PlayerLoadout.Area, index: int, screen_pos: Vector2) -> void:
	if _loadout == null:
		return
	var stack := _loadout.slot_at(area, index)
	if stack == null or stack.is_empty():
		return
	_context_area = area
	_context_index = index
	var can_use := stack.definition != null and stack.definition.is_usable()
	if _context_menu != null and _context_menu.has_method("open_at"):
		_context_menu.call("open_at", screen_pos, can_use)
	elif _context_menu != null:
		_context_menu.position = Vector2i(screen_pos)
		_context_menu.popup()


func _on_context_action(action_id: StringName) -> void:
	if _loadout == null or _context_index < 0:
		return
	if action_id == ContextMenuScript.ID_USE:
		_loadout.use_from_slot(_context_area, _context_index)
	elif action_id == ContextMenuScript.ID_DROP:
		var taken := _loadout.extract_slot(_context_area, _context_index)
		if taken != null and not taken.is_empty():
			_give_stack_to_player(taken)
	_context_index = -1


func _give_stack_to_player(taken: ItemStack) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player == null:
		_loadout.try_add_item(taken.definition, taken.quantity)
		return
	var inv := player.get_node_or_null("PlayerInventory") as Node
	if inv == null or inv.get("loadout") == null:
		_loadout.try_add_item(taken.definition, taken.quantity)
		return
	var pl: PlayerLoadout = inv.loadout
	var added := pl.try_add_item(taken.definition, taken.quantity)
	if added < taken.quantity:
		_loadout.try_add_item(taken.definition, taken.quantity - added)


func _refresh_all() -> void:
	for s in _slot_controls:
		if is_instance_valid(s):
			s.queue_redraw()
