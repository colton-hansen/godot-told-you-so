extends PanelContainer

func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = InventoryLayout.PANEL_BG
	sb.set_border_width_all(0)
	sb.set_content_margin_all(InventoryLayout.PANEL_PADDING_PX)
	add_theme_stylebox_override(&"panel", sb)
