extends CanvasLayer

func _ready() -> void:
	visible = OS.is_debug_build()


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		get_viewport().set_input_as_handled()
		if RunState.phase == RunState.Phase.RAID:
			RunState.evacuate()
		else:
			RunState.begin_raid()
