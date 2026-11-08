extends Node
## Fridge / freezer / drink-fridge doors: no collision, swing open while looting.

const GROUP_CTRL := &"hub_fridge_doors"
const GROUP_ANIM := &"hub_storage_anim"
const GROUP_INTERACT_MESH := &"interactable_mesh"
const TWEEN_SEC := 0.35
const OPEN_DEG := 60.0

var _doors: Dictionary = {} # StringName id -> MeshInstance3D
var _rest_z: Dictionary = {}
var _open_delta: Dictionary = {}
var _open_id: StringName = StringName()
var _tweens: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP_CTRL)
	add_to_group(GROUP_ANIM)
	call_deferred("_setup")


func set_open(sid: StringName, want: bool, _mesh: MeshInstance3D = null) -> void:
	if not _doors.has(sid):
		return
	if want:
		if _open_id != StringName() and _open_id != sid:
			_tween_door(_open_id, false)
		_open_id = sid
		_tween_door(sid, true)
	else:
		if _open_id != StringName():
			_tween_door(_open_id, false)
		_open_id = StringName()


func _setup() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	var fridge := _find_mesh(sketch, "fridge")
	var freezer_door := _find_mesh(sketch, "fridge-door")
	var fridge_door := _find_mesh(sketch, "fridge-door_001")
	var drink := _find_mesh(sketch, "drink-fridge")
	var drink_door := _find_mesh(sketch, "drink-fridge-door")
	_bind(KitchenStorages.ID_FREEZER, freezer_door, fridge)
	_bind(KitchenStorages.ID_FRIDGE, fridge_door, fridge)
	_bind(KitchenStorages.ID_DRINK_FRIDGE, drink_door, drink)
	_tag_body(fridge, KitchenStorages.ID_FRIDGE)
	_tag_body(drink, KitchenStorages.ID_DRINK_FRIDGE)


func _bind(sid: StringName, door: MeshInstance3D, body: MeshInstance3D) -> void:
	if door == null:
		return
	_doors[sid] = door
	_rest_z[sid] = door.rotation.z
	_open_delta[sid] = _pick_open_delta(door, body)
	_tag_mesh(door, sid)


func _tag_mesh(mi: MeshInstance3D, sid: StringName) -> void:
	mi.add_to_group(GROUP_INTERACT_MESH)
	mi.set_meta(&"interact_kind", &"storage")
	mi.set_meta(&"storage_id", sid)
	if mi.mesh != null:
		mi.set_meta(&"interact_faces", mi.mesh.get_faces())


func _tag_body(mi: MeshInstance3D, sid: StringName) -> void:
	if mi == null:
		return
	_tag_mesh(mi, sid)


func _pick_open_delta(door: MeshInstance3D, body: MeshInstance3D) -> float:
	var mag := deg_to_rad(OPEN_DEG)
	if body == null or door.mesh == null:
		return -mag
	# Sample the real node pose. Drink-fridge rest is X=-180 after the mesh fix;
	# composing Euler with Basis.from_euler disagrees with tweening rotation.z.
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


func _tween_door(sid: StringName, want_open: bool) -> void:
	if not _doors.has(sid):
		return
	var door: MeshInstance3D = _doors[sid]
	var rest: float = float(_rest_z[sid])
	var z: float = rest + (float(_open_delta[sid]) if want_open else 0.0)
	var existing: Variant = _tweens.get(sid, null)
	if existing is Tween:
		(existing as Tween).kill()
	var tw := create_tween()
	_tweens[sid] = tw
	tw.tween_property(door, "rotation:z", z, TWEEN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	tw.finished.connect(func() -> void: _tweens.erase(sid))


func _find_mesh(n: Node, want: String) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name).to_lower() == want:
		return n as MeshInstance3D
	for c: Node in n.get_children():
		var found := _find_mesh(c, want)
		if found != null:
			return found
	return null
