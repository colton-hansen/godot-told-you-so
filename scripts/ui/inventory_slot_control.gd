extends Control

class_name InventorySlotControl

signal equip_requested(area: PlayerLoadout.Area, index: int)
signal context_requested(area: PlayerLoadout.Area, index: int, screen_pos: Vector2)

enum FrameKind { ACTIVE, POCKET, FAVORITE, BACKPACK }

@export var frame_kind: FrameKind = FrameKind.POCKET
@export var pocket_index: int = 0
@export var backpack_index: int = 0

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
	var border := _border_color()
	var inset := InventoryLayout.BORDER_WIDTH_PX * 0.5
	draw_rect(rect.grow(-inset), border, false, InventoryLayout.BORDER_WIDTH_PX)
	var stack := _stack_for_view()
	if stack == null or stack.is_empty():
		return
	var letter := stack.definition.display_name.substr(0, 1)
	var font := ThemeDB.fallback_font
	var font_size := 16
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
	var font := ThemeDB.fallback_font
	var font_size := 14
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


func _border_color() -> Color:
	match frame_kind:
		FrameKind.ACTIVE:
			return InventoryLayout.COLOR_ACTIVE
		FrameKind.FAVORITE:
			return InventoryLayout.COLOR_FAVORITE
		FrameKind.BACKPACK:
			return InventoryLayout.COLOR_BACKPACK
		_:
			return InventoryLayout.COLOR_POCKET


func _stack_for_view() -> ItemStack:
	if _loadout == null or _is_locked_backpack():
		return null
	match frame_kind:
		FrameKind.ACTIVE:
			return _loadout.active
		FrameKind.POCKET:
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
		FrameKind.POCKET:
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
		FrameKind.POCKET:
			return pocket_index
		FrameKind.BACKPACK:
			return backpack_index
		FrameKind.FAVORITE:
			if _loadout != null:
				return _loadout.favorite_index
			return 0
	return 0
