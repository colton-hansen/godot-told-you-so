class_name InventoryUI
extends CanvasLayer

signal opened
signal closed
signal storage_closed
signal item_dropped(stack: ItemStack)

const SlotControl := preload("res://scripts/ui/inventory_slot_control.gd")
const ContextMenuScript := preload("res://scripts/ui/inventory_item_context_menu.gd")

@onready var _panel: PanelContainer = $Panel
@onready var _pockets_title: Control = $Panel/VBox/PocketsTitle
@onready var _panel_quick: HBoxContainer = $Panel/VBox/QuickRow
@onready var _backpack_title: Control = $Panel/VBox/BackpackTitle
@onready var _backpack_wrap: CenterContainer = $Panel/VBox/BackpackWrap
@onready var _backpack_grid: GridContainer = $Panel/VBox/BackpackWrap/BackpackGrid
@onready var _storage_separator: Control = $Panel/VBox/StorageSeparator
@onready var _storage_title: Control = $Panel/VBox/StorageTitle
@onready var _storage_wrap: CenterContainer = $Panel/VBox/StorageWrap
@onready var _storage_grid: GridContainer = $Panel/VBox/StorageWrap/StorageGrid
@onready var _hud_bar: PanelContainer = $HudQuickBar
@onready var _hud_quick: HBoxContainer = $HudQuickBar/QuickRow
@onready var _context_menu: InventoryItemContextMenu = $ContextMenu

var is_open: bool = false
var is_storage_open: bool = false
var _loadout: PlayerLoadout
var _storage_loadout: PlayerLoadout
var _storage_id: StringName = StringName()
var _context_area: PlayerLoadout.Area = PlayerLoadout.Area.ACTIVE
var _context_index: int = -1
var _context_from_storage: bool = false
var _slot_controls: Array[InventorySlotControl] = []
var _storage_slot_controls: Array[InventorySlotControl] = []


func setup(loadout: PlayerLoadout) -> void:
	_loadout = loadout
	if _loadout != null:
		_loadout.changed.connect(_refresh_all)
	if _context_menu.has_signal("action_chosen"):
		_context_menu.action_chosen.connect(_on_context_action)
	_backpack_grid.columns = InventoryLayout.BACKPACK_COLUMNS
	if _storage_separator != null:
		_storage_separator.visible = false
	_build_slots()
	_apply_layout_metrics()
	_refresh_all()
	_panel.visible = false


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if not event.is_action_pressed("toggle_inventory"):
		return
	_hide_context_menu()
	if is_storage_open:
		close_storage()
	else:
		toggle()
	get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_storage_open:
		close_storage()
		return
	is_open = not is_open
	_panel.visible = is_open
	_hud_bar.visible = not is_open
	if is_open:
		opened.emit()
	else:
		_hide_context_menu()
		closed.emit()


func open_storage(
	storage_loadout: PlayerLoadout,
	title_text: String,
	storage_id: StringName = StringName()
) -> void:
	if storage_loadout == null:
		return
	_unbind_storage_loadout()
	_storage_id = storage_id
	_storage_loadout = storage_loadout
	if _storage_loadout.changed.is_connected(_refresh_all) == false:
		_storage_loadout.changed.connect(_refresh_all)
	if _storage_title != null:
		_storage_title.set("title_text", title_text)
	_build_storage_slots()
	is_storage_open = true
	is_open = true
	_panel.visible = true
	_hud_bar.visible = false
	_refresh_all()
	opened.emit()


func close_storage() -> void:
	if not is_storage_open:
		return
	_hide_context_menu()
	_unbind_storage_loadout()
	_storage_id = StringName()
	_clear_storage_slots()
	is_storage_open = false
	is_open = false
	_panel.visible = false
	_hud_bar.visible = true
	_refresh_all()
	storage_closed.emit()
	closed.emit()


func _unbind_storage_loadout() -> void:
	if _storage_loadout != null and _storage_loadout.changed.is_connected(_refresh_all):
		_storage_loadout.changed.disconnect(_refresh_all)
	_storage_loadout = null


func _storage_slot_count() -> int:
	if _storage_loadout != null:
		return _storage_loadout.pockets.size()
	return InventoryLayout.STORAGE_SLOT_COUNT


func _apply_layout_metrics() -> void:
	var storage_slots := _storage_slot_count()
	var popup_size := InventoryLayout.panel_popup_size_px(true, is_storage_open, storage_slots)
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
	if _storage_grid != null:
		_storage_grid.columns = InventoryLayout.storage_columns_for(storage_slots)
		_storage_grid.custom_minimum_size = Vector2(
			InventoryLayout.storage_grid_width_px(storage_slots),
			InventoryLayout.storage_grid_height_px(storage_slots),
		)


func _build_slots() -> void:
	for child in _panel_quick.get_children():
		child.queue_free()
	for child in _hud_quick.get_children():
		child.queue_free()
	for child in _backpack_grid.get_children():
		child.queue_free()
	_slot_controls.clear()

	for i in InventoryLayout.POCKET_COUNT:
		_add_quick_slot(_panel_quick, SlotControl.FrameKind.POCKET, i)
		_add_quick_slot(_hud_quick, SlotControl.FrameKind.POCKET, i)

	for i in InventoryLayout.BACKPACK_COUNT:
		var slot := SlotControl.new()
		slot.frame_kind = SlotControl.FrameKind.BACKPACK
		slot.backpack_index = i
		slot.allow_drag = false
		_bind_slot(slot, false)
		_backpack_grid.add_child(slot)
		_slot_controls.append(slot)


func _build_storage_slots() -> void:
	if _storage_grid == null:
		return
	_clear_storage_slots()
	var n := _storage_slot_count()
	_storage_grid.columns = InventoryLayout.storage_columns_for(n)
	for i in n:
		var slot := SlotControl.new()
		slot.frame_kind = SlotControl.FrameKind.STORAGE
		slot.pocket_index = i
		slot.storage_id = _storage_id
		_bind_slot(slot, true)
		_storage_grid.add_child(slot)
		_storage_slot_controls.append(slot)


func _clear_storage_slots() -> void:
	if _storage_grid != null:
		while _storage_grid.get_child_count() > 0:
			var old := _storage_grid.get_child(0)
			_storage_grid.remove_child(old)
			old.free()
	_storage_slot_controls.clear()


func _add_quick_slot(parent: HBoxContainer, kind: SlotControl.FrameKind, pocket_idx: int) -> void:
	var slot := SlotControl.new()
	slot.frame_kind = kind
	slot.pocket_index = pocket_idx
	slot.allow_drag = parent == _panel_quick
	_bind_slot(slot, false)
	parent.add_child(slot)
	_slot_controls.append(slot)


func _bind_slot(slot: InventorySlotControl, from_storage: bool) -> void:
	if from_storage:
		slot.allow_drag = true
		slot.bind_loadout(_storage_loadout)
		slot.equip_requested.connect(_on_storage_equip_requested)
		slot.context_requested.connect(_on_storage_context_requested)
		slot.transfer_requested.connect(_on_storage_transfer_requested)
	else:
		slot.bind_loadout(_loadout)
		slot.equip_requested.connect(_on_equip_requested)
		slot.context_requested.connect(_on_context_requested)
		slot.transfer_requested.connect(_on_player_transfer_requested)


func _on_equip_requested(area: PlayerLoadout.Area, index: int) -> void:
	if _loadout == null:
		return
	_loadout.equip_from_slot(area, index)


func _on_storage_equip_requested(_area: PlayerLoadout.Area, _index: int) -> void:
	pass


func _on_player_transfer_requested(area: PlayerLoadout.Area, index: int) -> void:
	if not is_storage_open or _loadout == null or _storage_loadout == null:
		return
	_quick_move(_loadout, area, index, _storage_loadout, _storage_id)


func _on_storage_transfer_requested(area: PlayerLoadout.Area, index: int) -> void:
	if not is_storage_open or _loadout == null or _storage_loadout == null:
		return
	_quick_move(_storage_loadout, area, index, _loadout, StringName())


func _quick_move(
	src: PlayerLoadout,
	src_area: PlayerLoadout.Area,
	src_index: int,
	dst: PlayerLoadout,
	dst_storage_id: StringName,
	want: int = -1
) -> void:
	var stack := src.slot_at(src_area, src_index)
	if stack == null or stack.is_empty():
		return
	if dst_storage_id != StringName() and not KitchenStorages.accepts_item(dst_storage_id, stack.definition):
		return
	var qty: int = stack.quantity if want < 0 else mini(want, stack.quantity)
	if qty <= 0:
		return
	var added := dst.try_add_item(stack.definition, qty)
	if added <= 0:
		return
	stack.quantity -= added
	if stack.quantity <= 0:
		stack.definition = null
		stack.quantity = 0
		if src.is_favorite(src_area, src_index):
			src.favorite_index = -1
	src.emit_changed()


func _move_want(action_id: StringName, qty: int) -> int:
	match action_id:
		ContextMenuScript.ID_MOVE_SINGLE:
			return 1
		ContextMenuScript.ID_MOVE_HALF:
			return maxi(1, qty / 2)
		_:
			return qty


func _on_context_requested(area: PlayerLoadout.Area, index: int, screen_pos: Vector2) -> void:
	if _loadout == null:
		return
	var stack := _loadout.slot_at(area, index)
	if stack == null or stack.is_empty():
		return
	_context_from_storage = false
	_context_area = area
	_context_index = index
	var held := area == PlayerLoadout.Area.ACTIVE or (
		area == PlayerLoadout.Area.POCKET and index == _loadout.held_pocket
	)
	var can_use := held and stack.definition != null and stack.definition.is_usable()
	var can_move := (
		is_storage_open
		and stack.definition != null
		and KitchenStorages.accepts_item(_storage_id, stack.definition)
	)
	_open_context(screen_pos, can_use, can_move)


func _on_storage_context_requested(area: PlayerLoadout.Area, index: int, screen_pos: Vector2) -> void:
	if _storage_loadout == null:
		return
	var stack := _storage_loadout.slot_at(area, index)
	if stack == null or stack.is_empty():
		return
	_context_from_storage = true
	_context_area = area
	_context_index = index
	_open_context(screen_pos, false, true)


func _hide_context_menu() -> void:
	if _context_menu != null and _context_menu.has_method("close_menu"):
		_context_menu.call("close_menu")
	elif _context_menu != null:
		_context_menu.hide()


func _open_context(screen_pos: Vector2, can_use: bool, can_move: bool = false) -> void:
	if _context_menu.has_method("open_at"):
		_context_menu.call("open_at", screen_pos, can_use, can_move)


func _on_context_action(action_id: StringName) -> void:
	if _context_index < 0:
		return
	if action_id == ContextMenuScript.ID_USE:
		if _context_from_storage or _loadout == null:
			_context_index = -1
			return
		var held := _context_area == PlayerLoadout.Area.ACTIVE or (
			_context_area == PlayerLoadout.Area.POCKET
			and _context_index == _loadout.held_pocket
		)
		if held:
			_loadout.use_from_slot(_context_area, _context_index)
		_context_index = -1
		return
	if (
		action_id == ContextMenuScript.ID_MOVE_ALL
		or action_id == ContextMenuScript.ID_MOVE_SINGLE
		or action_id == ContextMenuScript.ID_MOVE_HALF
	):
		_on_context_move(action_id)
	_context_index = -1


func _on_context_move(action_id: StringName) -> void:
	if not is_storage_open or _loadout == null or _storage_loadout == null:
		return
	var src: PlayerLoadout = _storage_loadout if _context_from_storage else _loadout
	var dst: PlayerLoadout = _loadout if _context_from_storage else _storage_loadout
	var dst_sid: StringName = StringName() if _context_from_storage else _storage_id
	var stack := src.slot_at(_context_area, _context_index)
	if stack == null or stack.is_empty():
		return
	_quick_move(
		src,
		_context_area,
		_context_index,
		dst,
		dst_sid,
		_move_want(action_id, stack.quantity)
	)


func _refresh_all() -> void:
	if _pockets_title != null:
		_pockets_title.visible = true
	if _backpack_wrap != null:
		_backpack_wrap.visible = true
	if _backpack_title != null:
		_backpack_title.visible = true
	if _storage_separator != null:
		_storage_separator.visible = false
	if _storage_title != null:
		_storage_title.visible = is_storage_open
	if _storage_wrap != null:
		_storage_wrap.visible = is_storage_open
	_apply_layout_metrics()
	for slot in _slot_controls:
		if is_instance_valid(slot):
			slot.queue_redraw()
	for slot in _storage_slot_controls:
		if is_instance_valid(slot):
			slot.queue_redraw()
