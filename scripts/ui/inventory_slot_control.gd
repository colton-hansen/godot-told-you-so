extends Control

class_name InventorySlotControl

signal equip_requested(area: PlayerLoadout.Area, index: int)
signal context_requested(area: PlayerLoadout.Area, index: int, screen_pos: Vector2)
signal transfer_requested(area: PlayerLoadout.Area, index: int)

enum FrameKind { ACTIVE, POCKET, FAVORITE, BACKPACK, STORAGE }

@export var frame_kind: FrameKind = FrameKind.POCKET
@export var pocket_index: int = 0
@export var backpack_index: int = 0

var allow_drag: bool = true
var storage_id: StringName = StringName()
var _loadout: PlayerLoadout


func bind_loadout(loadout: PlayerLoadout) -> void:
	if _loadout != null and _loadout.changed.is_connected(_on_loadout_changed):
		_loadout.changed.disconnect(_on_loadout_changed)
	_loadout = loadout
	if _loadout != null:
		_loadout.changed.connect(_on_loadout_changed)
	var side := float(InventoryLayout.SLOT_SIZE_PX)
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
		if _is_locked_backpack()
		else Control.MOUSE_FILTER_STOP
	)
	queue_redraw()


func _is_held_pocket() -> bool:
	return (
		frame_kind == FrameKind.POCKET
		and _loadout != null
		and pocket_index == _loadout.held_pocket
	)


func _is_locked_backpack() -> bool:
	return (
		frame_kind == FrameKind.BACKPACK
		and InventoryLayout.is_backpack_slot_locked(backpack_index)
	)


func _on_loadout_changed() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
		if _is_locked_backpack()
		else Control.MOUSE_FILTER_STOP
	)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, InventoryLayout.SLOT_FILL)
	if _is_locked_backpack():
		_draw_locked_cross(rect)
		return
	if _is_held_pocket():
		var inset := InventoryLayout.BORDER_WIDTH_PX * 0.5
		draw_rect(rect.grow(-inset), InventoryLayout.COLOR_ACTIVE, false, InventoryLayout.BORDER_WIDTH_PX)
	var stack := _stack_for_view()
	if stack == null or stack.is_empty():
		return
	var letter := stack.definition.display_name.substr(0, 1)
	var font := InventoryLayout.FONT
	var font_size := InventoryLayout.FONT_SIZE
	var ascent := font.get_ascent(font_size)
	draw_string(
		font,
		Vector2(8, 8 + ascent),
		letter,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		InventoryLayout.LABEL_COLOR,
	)
	_draw_quantity_badge(stack.quantity, rect)


func _draw_locked_cross(rect: Rect2) -> void:
	var pad := 14.0
	var w := InventoryLayout.LOCKED_CROSS_WIDTH_PX
	var c := InventoryLayout.LOCKED_CROSS
	var tl := rect.position + Vector2(pad, pad)
	var br := rect.end - Vector2(pad, pad)
	var tr := Vector2(br.x, tl.y)
	var bl := Vector2(tl.x, br.y)
	draw_line(tl, br, c, w, true)
	draw_line(tr, bl, c, w, true)


func _draw_quantity_badge(qty: int, rect: Rect2) -> void:
	if qty <= 1:
		return
	var text := "×%d" % qty
	var font := InventoryLayout.FONT
	var font_size := InventoryLayout.FONT_SIZE
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_h := font.get_height(font_size)
	var ascent := font.get_ascent(font_size)
	var inset := 4.0
	var badge_size := Vector2(text_size.x + inset * 2.0, text_h + inset * 2.0)
	var badge_pos := Vector2(rect.end.x - inset - badge_size.x, rect.end.y - inset - badge_size.y)
	draw_rect(Rect2(badge_pos, badge_size), InventoryLayout.BADGE_BG, true)
	draw_string(
		font,
		Vector2(badge_pos.x + inset, badge_pos.y + inset + ascent),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		InventoryLayout.LABEL_COLOR,
	)


func slot_area() -> PlayerLoadout.Area:
	return _area()


func slot_index() -> int:
	return _index()


func _stack_for_view() -> ItemStack:
	if _loadout == null or _is_locked_backpack():
		return null
	match frame_kind:
		FrameKind.ACTIVE:
			return _loadout.held_stack()
		FrameKind.POCKET, FrameKind.STORAGE:
			if pocket_index < 0 or pocket_index >= _loadout.pockets.size():
				return null
			return _loadout.pockets[pocket_index]
		FrameKind.FAVORITE:
			return _loadout.favorite_stack()
		FrameKind.BACKPACK:
			return _loadout.backpack[backpack_index]
	return null


func _gui_input(event: InputEvent) -> void:
	if _is_locked_backpack():
		return
	if frame_kind == FrameKind.FAVORITE:
		if _loadout == null or _loadout.favorite_index < 0:
			if event is InputEventMouseButton and event.pressed:
				accept_event()
			return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var area := _area()
	var index := _index()
	var stack := _loadout.slot_at(area, index) if _loadout != null else null
	if event.button_index == MOUSE_BUTTON_LEFT:
		if frame_kind == FrameKind.ACTIVE:
			return
		if event.shift_pressed:
			if stack != null and not stack.is_empty():
				transfer_requested.emit(area, index)
			accept_event()
			return
		if frame_kind == FrameKind.POCKET:
			equip_requested.emit(area, index)
			accept_event()
			return
		if frame_kind == FrameKind.STORAGE:
			accept_event()
			return
		if stack == null or stack.is_empty():
			return
		if frame_kind == FrameKind.FAVORITE:
			area = _loadout.favorite_area
			index = _loadout.favorite_index
		equip_requested.emit(area, index)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if stack == null or stack.is_empty():
			return
		if frame_kind == FrameKind.FAVORITE:
			area = _loadout.favorite_area
			index = _loadout.favorite_index
		context_requested.emit(area, index, event.global_position)
		accept_event()


func _area() -> PlayerLoadout.Area:
	match frame_kind:
		FrameKind.ACTIVE:
			return PlayerLoadout.Area.ACTIVE
		FrameKind.POCKET, FrameKind.STORAGE:
			return PlayerLoadout.Area.POCKET
		FrameKind.BACKPACK:
			return PlayerLoadout.Area.BACKPACK
		FrameKind.FAVORITE:
			if _loadout != null and _loadout.favorite_index >= 0:
				return _loadout.favorite_area
			return PlayerLoadout.Area.POCKET
	return PlayerLoadout.Area.POCKET


func _index() -> int:
	match frame_kind:
		FrameKind.ACTIVE:
			return 0
		FrameKind.POCKET, FrameKind.STORAGE:
			return pocket_index
		FrameKind.BACKPACK:
			return backpack_index
		FrameKind.FAVORITE:
			if _loadout != null:
				return _loadout.favorite_index
			return 0
	return 0


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not allow_drag or _is_locked_backpack() or _loadout == null:
		return null
	var stack := _stack_for_view()
	if stack == null or stack.is_empty():
		return null
	set_drag_preview(_make_drag_preview(stack))
	return {
		"loadout": _loadout,
		"area": _area(),
		"index": _index(),
		"storage_id": storage_id,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _drop_ok(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _drop_ok(data):
		return
	var src_lo: PlayerLoadout = data["loadout"]
	var src_area: PlayerLoadout.Area = data["area"]
	var src_index: int = int(data["index"])
	_loadout.take_from(src_lo, src_area, src_index, _area(), _index())


func _drop_ok(data: Variant) -> bool:
	if not allow_drag or _is_locked_backpack() or _loadout == null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("loadout") or not data.has("area") or not data.has("index"):
		return false
	var src_lo: PlayerLoadout = data["loadout"]
	if src_lo == null:
		return false
	var src_area: PlayerLoadout.Area = data["area"]
	var src_index: int = int(data["index"])
	if src_lo == _loadout and src_area == _area() and src_index == _index():
		return false
	var src_stack := src_lo.slot_at(src_area, src_index)
	if src_stack == null or src_stack.is_empty():
		return false
	if not _container_accepts(storage_id, src_stack.definition):
		return false
	var dst_stack := _loadout.slot_at(_area(), _index())
	if dst_stack == null:
		return false
	if dst_stack.is_empty():
		return true
	if dst_stack.definition == src_stack.definition:
		return dst_stack.quantity < dst_stack.definition.max_stack
	var src_storage_id: StringName = data.get("storage_id", StringName()) as StringName
	return _container_accepts(src_storage_id, dst_stack.definition)


func _container_accepts(sid: StringName, def: ItemDefinition) -> bool:
	if def == null:
		return false
	if sid == StringName():
		return true
	return KitchenStorages.accepts_item(sid, def)


func _make_drag_preview(stack: ItemStack) -> Control:
	var box := ColorRect.new()
	var side := float(InventoryLayout.SLOT_SIZE_PX)
	box.color = InventoryLayout.SLOT_FILL
	box.custom_minimum_size = Vector2(side, side)
	box.size = Vector2(side, side)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := Label.new()
	lab.text = stack.definition.display_name.substr(0, 1)
	lab.add_theme_font_override(&"font", InventoryLayout.FONT)
	lab.add_theme_font_size_override(&"font_size", InventoryLayout.FONT_SIZE)
	lab.add_theme_color_override(&"font_color", InventoryLayout.LABEL_COLOR)
	lab.position = Vector2(8, 8)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lab)
	return box
