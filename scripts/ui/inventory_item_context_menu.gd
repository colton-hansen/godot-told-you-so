class_name InventoryItemContextMenu
extends Control

signal action_chosen(action_id: StringName)

const ID_USE := &"use"
const ID_MOVE_ALL := &"move_all"
const ID_MOVE_SINGLE := &"move_single"
const ID_MOVE_HALF := &"move_half"

const _PANEL_BG := Color("#00000095")
const _ITEM_HOVER_BG := Color("#000000")
const _ROW_H := 26
const _MENU_W := 140
const _SUBMENU_DOT_PX := 6

var _panel: PanelContainer
var _use_row: _MenuRow
var _move_row: _MenuRow
var _flyout: PanelContainer
var _can_move: bool = false
var _dot_icon: Texture2D


func _ready() -> void:
	visible = false
	z_index = 32
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	_dot_icon = _make_submenu_dot_icon(InventoryLayout.LABEL_COLOR, _SUBMENU_DOT_PX)
	_build()
	_fit_main()


func open_at(screen_pos: Vector2, can_use: bool, can_move: bool = false) -> void:
	_can_move = can_move
	if _use_row != null:
		_use_row.disabled = not can_use
	if _move_row != null:
		_move_row.disabled = not can_move
	_set_flyout_open(false)
	_fit_main()
	global_position = _clamped_pos(screen_pos, size)
	show()
	move_to_front()


func close_menu() -> void:
	_set_flyout_open(false)
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_inventory"):
		close_menu()
		return
	if event is InputEventMouseButton and event.pressed:
		if not _hits_menu():
			close_menu()


func _build() -> void:
	_panel = _make_panel()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	_panel.add_child(col)

	_use_row = _make_row("Use", false)
	_use_row.clicked.connect(func() -> void: _emit_and_close(ID_USE))
	_use_row.hovered.connect(func() -> void: _set_flyout_open(false))
	col.add_child(_use_row)

	_move_row = _make_row("Move", true)
	_move_row.clicked.connect(_on_move_clicked)
	_move_row.hovered.connect(_on_move_hovered)
	col.add_child(_move_row)

	_flyout = _make_panel()
	_flyout.visible = false
	_flyout.z_index = 1
	_flyout.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_flyout)

	var fly_col := VBoxContainer.new()
	fly_col.add_theme_constant_override(&"separation", 0)
	_flyout.add_child(fly_col)
	_add_move_choice(fly_col, "single", ID_MOVE_SINGLE)
	_add_move_choice(fly_col, "half", ID_MOVE_HALF)
	_add_move_choice(fly_col, "all", ID_MOVE_ALL)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _PANEL_BG
	sb.set_content_margin_all(0)
	sb.set_border_width_all(0)
	panel.add_theme_stylebox_override(&"panel", sb)
	return panel


func _add_move_choice(parent: Control, label: String, action_id: StringName) -> void:
	var row := _make_row(label, false)
	row.clicked.connect(func() -> void: _emit_and_close(action_id))
	parent.add_child(row)


func _make_row(text: String, with_dot: bool) -> _MenuRow:
	var row := _MenuRow.new()
	row.setup(text, _dot_icon if with_dot else null, _MENU_W, _ROW_H)
	return row


func _make_submenu_dot_icon(color: Color, size_px: int) -> ImageTexture:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size_px * 0.5, size_px * 0.5)
	var radius := size_px * 0.5 - 0.5
	for x in size_px:
		for y in size_px:
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _on_move_clicked() -> void:
	if _can_move:
		_emit_and_close(ID_MOVE_ALL)


func _on_move_hovered() -> void:
	if _can_move:
		_set_flyout_open(true)


func _set_flyout_open(open: bool) -> void:
	if _flyout == null:
		return
	var want := open and _can_move and visible
	_flyout.visible = want
	if want:
		_place_flyout()


func _place_flyout() -> void:
	var fly_size := Vector2(_MENU_W, _ROW_H * 3)
	_flyout.custom_minimum_size = fly_size
	_flyout.size = fly_size
	_flyout.position = Vector2(_MENU_W, _ROW_H)


func _fit_main() -> void:
	var fitted := Vector2(_MENU_W, _ROW_H * 2)
	custom_minimum_size = fitted
	size = fitted
	if _panel != null:
		_panel.custom_minimum_size = fitted
		_panel.size = fitted
		_panel.position = Vector2.ZERO


func _hits_menu() -> bool:
	var point := get_global_mouse_position()
	if _panel != null and _panel.get_global_rect().grow(2.0).has_point(point):
		return true
	if _flyout != null and _flyout.visible and _flyout.get_global_rect().grow(2.0).has_point(point):
		return true
	return false


func _clamped_pos(screen_pos: Vector2, box: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var fly_w: float = float(_MENU_W) if _can_move else 0.0
	return Vector2(
		clampf(screen_pos.x, 0.0, maxf(0.0, vp.x - box.x - fly_w)),
		clampf(screen_pos.y, 0.0, maxf(0.0, vp.y - box.y - float(_ROW_H)))
	)


func _emit_and_close(action_id: StringName) -> void:
	close_menu()
	action_chosen.emit(action_id)


class _MenuRow extends Control:
	signal clicked
	signal hovered

	var disabled: bool = false:
		set(value):
			disabled = value
			modulate = Color(1, 1, 1, 0.35) if disabled else Color.WHITE
			mouse_default_cursor_shape = (
				Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
			)

	var _hover: bool = false
	var _label: Label
	var _dot: TextureRect

	func setup(text: String, dot: Texture2D, width: int, height: int) -> void:
		custom_minimum_size = Vector2(width, height)
		size = Vector2(width, height)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_label = Label.new()
		_label.text = text
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_override(&"font", InventoryLayout.FONT)
		_label.add_theme_font_size_override(&"font_size", InventoryLayout.FONT_SIZE)
		_label.add_theme_color_override(&"font_color", InventoryLayout.LABEL_COLOR)
		_label.add_theme_constant_override(&"outline_size", 0)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_label.offset_left = 10
		_label.offset_right = -18
		add_child(_label)
		if dot != null:
			_dot = TextureRect.new()
			_dot.texture = dot
			_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			_dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			_dot.offset_left = -16
			_dot.offset_right = -8
			_dot.offset_top = -3
			_dot.offset_bottom = 3
			add_child(_dot)

	func _draw() -> void:
		if _hover and not disabled:
			draw_rect(Rect2(Vector2.ZERO, size), InventoryItemContextMenu._ITEM_HOVER_BG)

	func _gui_input(event: InputEvent) -> void:
		if disabled:
			return
		if not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			clicked.emit()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			_hover = true
			queue_redraw()
			hovered.emit()
		elif what == NOTIFICATION_MOUSE_EXIT:
			_hover = false
			queue_redraw()
