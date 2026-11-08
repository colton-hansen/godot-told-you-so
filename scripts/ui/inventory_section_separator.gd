extends Control

@export var fill_color: Color = InventoryLayout.INVENTORY_DIVIDER:
	set(value):
		fill_color = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(0, InventoryLayout.SEPARATOR_HEIGHT_PX)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), fill_color)
