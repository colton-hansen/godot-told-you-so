extends Node
## Microwave + toaster inventories. Door opens while looting; cooking comes later.

const GROUP_ANIM := &"hub_storage_anim"
const GROUP_INTERACT_MESH := &"interactable_mesh"
const TWEEN_SEC := 0.35
const MICROWAVE_OPEN_DEG := 90.0

var _door: MeshInstance3D
var _rest_z: float = 0.0
var _open_delta: float = 0.0
var _door_open: bool = false
var _tween: Tween


func _ready() -> void:
	add_to_group(GROUP_ANIM)
	call_deferred("_setup")


func set_open(sid: StringName, want: bool, _mesh: MeshInstance3D = null) -> void:
	if sid != KitchenStorages.ID_MICROWAVE:
		return
	_tween_door(want)


func _setup() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	var chamber := _find_mesh(sketch, "microwave-chember")
	_door = _find_mesh(sketch, "microwave-door")
	var toaster := _find_mesh(sketch, "toster")
	if toaster == null:
		toaster = _find_mesh(sketch, "toaster")
	_tag(chamber, KitchenStorages.ID_MICROWAVE)
	_tag(_find_mesh(sketch, "microwave-nuumpad"), KitchenStorages.ID_MICROWAVE)
	_tag(_find_mesh(sketch, "microwave-screen"), KitchenStorages.ID_MICROWAVE)
	if _door != null:
		_rest_z = _door.rotation.z
		_open_delta = _pick_open_delta(_door, chamber)
		_tag(_door, KitchenStorages.ID_MICROWAVE)
	_tag(toaster, KitchenStorages.ID_TOASTER)


func _tag(mi: MeshInstance3D, sid: StringName) -> void:
	if mi == null:
		return
	mi.add_to_group(GROUP_INTERACT_MESH)
	mi.set_meta(&"interact_kind", &"storage")
	mi.set_meta(&"storage_id", sid)
	if mi.mesh != null:
		mi.set_meta(&"interact_faces", mi.mesh.get_faces())


func _pick_open_delta(door: MeshInstance3D, body: MeshInstance3D) -> float:
	var mag := deg_to_rad(MICROWAVE_OPEN_DEG)
	if body == null or door.mesh == null:
		return -mag
	var rest := door.rotation
	var body_c := _mesh_center(body)
	door.rotation.z = rest.z - mag
	var d_neg := _mesh_center(door).distance_squared_to(body_c)
	door.rotation.z = rest.z + mag
	var d_pos := _mesh_center(door).distance_squared_to(body_c)
	door.rotation = rest
	return mag if d_pos > d_neg else -mag


func _mesh_center(mi: MeshInstance3D) -> Vector3:
	if mi.mesh == null:
		return mi.global_position
	return mi.global_transform * mi.mesh.get_aabb().get_center()


func _tween_door(want_open: bool) -> void:
	if _door == null:
		return
	if _door_open == want_open and _tween == null:
		return
	_door_open = want_open
	if _tween != null:
		_tween.kill()
	var z: float = _rest_z + (_open_delta if want_open else 0.0)
	_tween = create_tween()
	_tween.tween_property(_door, "rotation:z", z, TWEEN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	_tween.finished.connect(func() -> void: _tween = null)


func _find_mesh(n: Node, want: String) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name).to_lower() == want:
		return n as MeshInstance3D
	for c: Node in n.get_children():
		var found := _find_mesh(c, want)
		if found != null:
			return found
	return null
