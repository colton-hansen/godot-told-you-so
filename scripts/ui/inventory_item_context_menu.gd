class_name InventoryItemContextMenu
extends PopupMenu

signal action_chosen(action_id: StringName)

const ID_USE := &"use"
const ID_DROP := &"drop"

const _PANEL_BG := Color("#00000095")
const _ITEM_HOVER_BG := Color("#000000")


func _ready() -> void:
	id_pressed.connect(_on_id_pressed)
	_apply_theme(self)


static func _apply_theme(menu: PopupMenu) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = _PANEL_BG
	panel.set_content_margin_all(0)
	panel.set_border_width_all(0)
	var hover := StyleBoxFlat.new()
	hover.bg_color = _ITEM_HOVER_BG
	menu.add_theme_stylebox_override(&"panel", panel)
	menu.add_theme_stylebox_override(&"hover", hover)
	menu.add_theme_stylebox_override(&"hover_pressed", hover)
	menu.add_theme_constant_override(&"v_separation", 0)


func open_at(screen_pos: Vector2, can_use: bool) -> void:
	clear()
	add_item("Использовать", 0)
	set_item_disabled(0, not can_use)
	add_item("Положить", 1)
	position = screen_pos
	popup()


func _on_id_pressed(id: int) -> void:
	if id == 0:
		action_chosen.emit(ID_USE)
	elif id == 1:
		action_chosen.emit(ID_DROP)
