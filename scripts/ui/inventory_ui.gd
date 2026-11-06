class_name InventoryUI
extends CanvasLayer

signal opened
signal closed
signal item_dropped(stack: ItemStack)

const SlotControl := preload("res://scripts/ui/inventory_slot_control.gd")
const ContextMenuScript := preload("res://scripts/ui/inventory_item_context_menu.gd")

@onready var _panel: PanelContainer = $Panel
@onready var _panel_quick: HBoxContainer = $Panel/VBox/QuickRow
@onready var _backpack_wrap: CenterContainer = $Panel/VBox/BackpackWrap
@onready var _backpack_grid: GridContainer = $Panel/VBox/BackpackWrap/BackpackGrid
@onready var _separator: Control = $Panel/VBox/Separator
@onready var _hud_bar: PanelContainer = $HudQuickBar
@onready var _hud_quick: HBoxContainer = $HudQuickBar/QuickRow
@onready var _context_menu: PopupMenu = $ContextMenu

var is_open: bool = false
var _loadout: PlayerLoadout
var _context_area: PlayerLoadout.Area = PlayerLoadout.Area.ACTIVE
var _context_index: int = -1
var _slot_controls: Array[InventorySlotControl] = []


func setup(loadout: PlayerLoadout) -> void:
	_loadout = loadout
	if _loadout != null:
		_loadout.changed.connect(_refresh_all)
	if _context_menu.has_signal("action_chosen"):
		_context_menu.action_chosen.connect(_on_context_action)
	_backpack_grid.columns = InventoryLayout.BACKPACK_COLUMNS
	_build_slots()
	_apply_layout_metrics()
	_refresh_all()
	_panel.visible = false


func toggle() -> void:
	is_open = not is_open
	_panel.visible = is_open
	_hud_bar.visible = not is_open
	if is_open:
		opened.emit()
	else:
		closed.emit()


func _apply_layout_metrics() -> void:
	var backpack_on := _loadout != null and _loadout.backpack_enabled
	var popup_size := InventoryLayout.panel_popup_size_px(backpack_on)
	_panel.custom_minimum_size = popup_size
	_panel.size = popup_size
	_panel.offset_left = -popup_size.x * 0.5
	_panel.offset_top = -popup_size.y * 0.5
	_panel.offset_right = popup_size.x * 0.5
	_panel.offset_bottom = popup_size.y * 0.5

	var hud_size := InventoryLayout.hud_bar_size_px()
	_hud_bar.custom_minimum_size = hud_size
	_hud_bar.size = hud_size
	_hud_bar.offset_left = -hud_size.x * 0.5
	_hud_bar.offset_right = hud_size.x * 0.5
	_hud_bar.offset_top = -hud_size.y - 16.0
	_hud_bar.offset_bottom = -16.0

	_backpack_grid.custom_minimum_size = Vector2(
		InventoryLayout.backpack_grid_width_px(),
		InventoryLayout.backpack_grid_height_px(),
	)


func _build_slots() -> void:
	for child in _panel_quick.get_children():
		child.queue_free()
	for child in _hud_quick.get_children():
		child.queue_free()
	for child in _backpack_grid.get_children():
		child.queue_free()
	_slot_controls.clear()

	_add_quick_slot(_panel_quick, SlotControl.FrameKind.ACTIVE, 0)
	_add_quick_slot(_hud_quick, SlotControl.FrameKind.ACTIVE, 0)
	for i in InventoryLayout.POCKET_COUNT:
		_add_quick_slot(_panel_quick, SlotControl.FrameKind.POCKET, i)
		_add_quick_slot(_hud_quick, SlotControl.FrameKind.POCKET, i)
	_add_quick_slot(_panel_quick, SlotControl.FrameKind.FAVORITE, 0)
	_add_quick_slot(_hud_quick, SlotControl.FrameKind.FAVORITE, 0)

	for i in InventoryLayout.BACKPACK_COUNT:
		var slot := SlotControl.new()
		slot.frame_kind = SlotControl.FrameKind.BACKPACK
		slot.backpack_index = i
		_bind_slot(slot)
		_backpack_grid.add_child(slot)
		_slot_controls.append(slot)


func _add_quick_slot(parent: HBoxContainer, kind: SlotControl.FrameKind, pocket_idx: int) -> void:
	var slot := SlotControl.new()
	slot.frame_kind = kind
	slot.pocket_index = pocket_idx
	_bind_slot(slot)
	parent.add_child(slot)
	_slot_controls.append(slot)


func _bind_slot(slot: InventorySlotControl) -> void:
	slot.bind_loadout(_loadout)
	slot.equip_requested.connect(_on_equip_requested)
	slot.context_requested.connect(_on_context_requested)


func _on_equip_requested(area: PlayerLoadout.Area, index: int) -> void:
	if _loadout == null:
		return
	_loadout.equip_from_slot(area, index)


func _on_context_requested(area: PlayerLoadout.Area, index: int, screen_pos: Vector2) -> void:
	if _loadout == null:
		return
	var stack := _loadout.slot_at(area, index)
	if stack == null or stack.is_empty():
		return
	_context_area = area
	_context_index = index
	var can_use := stack.definition != null and stack.definition.is_usable()
	if _context_menu.has_method("open_at"):
		_context_menu.call("open_at", screen_pos, can_use)
	else:
		_context_menu.position = screen_pos
		_context_menu.popup()


func _on_context_action(action_id: StringName) -> void:
	if _loadout == null or _context_index < 0:
		return
	if action_id == ContextMenuScript.ID_USE:
		_loadout.use_from_slot(_context_area, _context_index)
	elif action_id == ContextMenuScript.ID_DROP:
		var taken := _loadout.extract_slot(_context_area, _context_index)
		if taken != null:
			item_dropped.emit(taken)
			print("Положил на землю: ", taken.definition.display_name, " x", taken.quantity)
	_context_index = -1


func _refresh_all() -> void:
	var backpack_on := _loadout != null and _loadout.backpack_enabled
	if _backpack_wrap != null:
		_backpack_wrap.visible = backpack_on
	if _separator != null:
		_separator.visible = backpack_on
	_apply_layout_metrics()
	for slot in _slot_controls:
		if is_instance_valid(slot):
			slot.queue_redraw()
