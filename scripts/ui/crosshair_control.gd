extends Control

func _draw() -> void:
	var c := size * 0.5
	draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(1, 1, 1, 0.85), 1.5)
	draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color(1, 1, 1, 0.85), 1.5)
