extends Node
## Три межкомнатные двери хаба (`door_001`..`003`). В FBX они открыты (local Z ≈ 90°);
## закрытое положение — Z = 0, в плоскости своей `frame_*`.

const GROUP_CTRL := &"hub_swing_doors"
const GROUP_INTERACT_MESH := &"interactable_mesh"
const TWEEN_SEC := 0.35
const CLOSED_Z := 0.0

var _tweens: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP_CTRL)
	call_deferred("_setup")


func is_closed(door: MeshInstance3D) -> bool:
	return door != null and bool(door.get_meta(&"door_closed", false))


func toggle(door: MeshInstance3D) -> void:
	if door == null or not door.has_meta(&"door_open_z"):
		return
	_set_closed(door, not is_closed(door))


func _setup() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	_scan(sketch)


func _scan(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if _is_swing_door(mi):
			_prepare(mi)
	for c: Node in n.get_children():
		_scan(c)


func _is_swing_door(mi: MeshInstance3D) -> bool:
	if mi.mesh == null:
		return false
	if not _is_swing_door_leaf_name(String(mi.name)):
		return false
	var p := mi.get_parent()
	return p != null and _is_door_frame_name(String(p.name))


func _is_swing_door_leaf_name(n: String) -> bool:
	var s := n.to_lower()
	if s.begins_with("door-frame"):
		return false
	return s.begins_with("door")


func _is_door_frame_name(n: String) -> bool:
	var s := n.to_lower()
	return s.begins_with("frame") or s.begins_with("door-frame")


func _prepare(mi: MeshInstance3D) -> void:
	_tag_interact(mi, mi)
	mi.set_meta(&"door_open_z", mi.rotation.z)
	mi.set_meta(&"door_closed", false)
	_add_leaf_collision(mi)
	var frame := mi.get_parent() as MeshInstance3D
	if frame != null and _is_door_frame_name(String(frame.name)):
		_tag_interact(frame, mi)


func _tag_interact(mi: MeshInstance3D, leaf: MeshInstance3D) -> void:
	mi.add_to_group(GROUP_INTERACT_MESH)
	mi.set_meta(&"interact_kind", &"door")
	mi.set_meta(&"door_leaf", leaf)
	if mi.mesh != null:
		mi.set_meta(&"interact_faces", mi.mesh.get_faces())


func _add_leaf_collision(mi: MeshInstance3D) -> void:
	if mi.get_node_or_null("DoorCollision") != null:
		return
	var shape: Shape3D = mi.mesh.create_trimesh_shape()
	if shape == null:
		return
	var body := StaticBody3D.new()
	body.name = "DoorCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	mi.add_child(body)


func _set_closed(door: MeshInstance3D, want_closed: bool) -> void:
	var id := door.get_instance_id()
	var busy: bool = _tweens.has(id)
	if is_closed(door) == want_closed and not busy:
		return
	door.set_meta(&"door_closed", want_closed)
	if busy:
		(_tweens[id] as Tween).kill()
		_tweens.erase(id)
	var z: float = CLOSED_Z if want_closed else float(door.get_meta(&"door_open_z"))
	var tw := create_tween()
	_tweens[id] = tw
	tw.tween_property(door, "rotation:z", z, TWEEN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	tw.finished.connect(func() -> void: _tweens.erase(id))
