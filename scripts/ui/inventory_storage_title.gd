extends Control
## Full-width name bar for a linked world inventory. Height = half a slot.

@export var title_text: String = "Storage":
	set(value):
		title_text = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(0, InventoryLayout.STORAGE_TITLE_HEIGHT_PX)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), InventoryLayout.SLOT_FILL)
	var font := InventoryLayout.FONT
	var font_size := InventoryLayout.FONT_SIZE
	var pad := InventoryLayout.TITLE_PAD_PX
	var ascent := font.get_ascent(font_size)
	var text_h := font.get_height(font_size)
	var y := (size.y - text_h) * 0.5 + ascent
	draw_string(
		font,
		Vector2(pad, y),
		title_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		maxi(0, int(size.x - pad)),
		font_size,
		InventoryLayout.LABEL_COLOR,
	)
