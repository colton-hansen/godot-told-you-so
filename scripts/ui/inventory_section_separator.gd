extends Control

func _ready() -> void:
	custom_minimum_size = Vector2(InventoryLayout.panel_inner_width_px(), InventoryLayout.SEPARATOR_HEIGHT_PX)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), InventoryLayout.COLOR_ACTIVE)
