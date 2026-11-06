extends Node
## Приоткрывает `fridge-door` на OPEN_DEG, когда кто-то роется в холодильнике.

const OPEN_DEG := 60.0
const TWEEN_SEC := 0.35
const GROUP_CTRL := &"fridge_door_ctrl"

@export var open_degrees: float = OPEN_DEG

var _door: MeshInstance3D
var _rest_y: float = 0.0
var _open_delta: float = 0.0
var _open: bool = false
var _tween: Tween


func _ready() -> void:
	add_to_group(GROUP_CTRL)
	call_deferred("_capture_door")


func set_open(want: bool) -> void:
	if _door == null:
		_capture_door()
	if _door == null:
		return
	if _open == want:
		return
	_open = want
	if _tween != null:
		_tween.kill()
	var y: float = _rest_y + (_open_delta if want else 0.0)
	_tween = create_tween()
	_tween.tween_property(_door, "rotation:y", y, TWEEN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)


func _capture_door() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	_door = _find_mesh(sketch, "fridge-door")
	if _door == null:
		return
	_rest_y = _door.rotation.y
	_open_delta = _pick_open_delta(sketch)


func _pick_open_delta(sketch: Node) -> float:
	var mag := deg_to_rad(open_degrees)
	var fridge := _find_mesh(sketch, "fridge")
	if fridge == null or fridge.mesh == null or _door.mesh == null:
		return -mag
	var fridge_c: Vector3 = (fridge.global_transform * fridge.mesh.get_aabb()).get_center()
	var d_neg := _door_center_if_yaw(-mag).distance_squared_to(fridge_c)
	var d_pos := _door_center_if_yaw(mag).distance_squared_to(fridge_c)
	# Дверь должна уходить ОТ корпуса, не в него.
	return mag if d_pos > d_neg else -mag


func _door_center_if_yaw(delta_y: float) -> Vector3:
	var parent_n := _door.get_parent() as Node3D
	if parent_n == null:
		return _door.global_position
	var local := Transform3D(_door.basis.rotated(Vector3.UP, delta_y), _door.position)
	return parent_n.global_transform * local * _door.mesh.get_aabb().get_center()


func _find_mesh(n: Node, want: String) -> MeshInstance3D:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.name.to_lower() == want:
			return mi
	for c: Node in n.get_children():
		var found := _find_mesh(c, want)
		if found != null:
			return found
	return null
