class_name InteractHint
extends Control

@onready var _label: Label = $Label


func set_hint(text: String) -> void:
	if _label == null:
		return
	var t := text.strip_edges()
	_label.text = t
	visible = t.length() > 0
