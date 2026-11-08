extends Node
## Drawer banks slide out 0.2 m while looting. All drawers share one inventory.

const GROUP_ANIM := &"hub_storage_anim"
const GROUP_INTERACT_MESH := &"interactable_mesh"
const TWEEN_SEC := 0.28
const SLIDE_M := 0.2

var _clusters: Dictionary = {} # drawer instance id -> Array[MeshInstance3D]
var _rest_pos: Dictionary = {} # instance id -> Vector3 local
var _slide_delta: Dictionary = {} # instance id -> Vector3 local
var _open_id: int = 0
var _tweens: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP_ANIM)
	call_deferred("_setup")


func set_open(sid: StringName, want: bool, mesh: MeshInstance3D = null) -> void:
	if sid != KitchenStorages.ID_DRAWERS:
		return
	if want:
		var cid := _cluster_id_of(mesh)
		if cid == 0:
			return
		if _open_id != 0 and _open_id != cid:
			_slide_cluster(_open_id, false)
		_open_id = cid
		_slide_cluster(cid, true)
	else:
		if _open_id != 0:
			_slide_cluster(_open_id, false)
		_open_id = 0


func _setup() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	_collect(sketch)
	for pid: int in _clusters:
		for mi: MeshInstance3D in _clusters[pid]:
			_prepare_drawer(mi)


func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if _is_drawer(mi):
			var cid := mi.get_instance_id()
			_clusters[cid] = [mi]
	for c: Node in n.get_children():
		_collect(c)


func _is_drawer(mi: MeshInstance3D) -> bool:
	return mi.mesh != null and String(mi.name).to_lower().begins_with("drawer")


func _prepare_drawer(mi: MeshInstance3D) -> void:
	var id := mi.get_instance_id()
	_rest_pos[id] = mi.position
	_slide_delta[id] = _local_slide(mi)
	mi.add_to_group(GROUP_INTERACT_MESH)
	mi.set_meta(&"interact_kind", &"storage")
	mi.set_meta(&"storage_id", KitchenStorages.ID_DRAWERS)
	mi.set_meta(&"interact_faces", mi.mesh.get_faces())


func _local_slide(mi: MeshInstance3D) -> Vector3:
	var aabb := _world_aabb(mi)
	var center := aabb.get_center()
	# Kitchen L sits on x≈-3 and z≈-3. Pull away from the nearer wall.
	var dist_west: float = absf(center.x - (-3.0))
	var dist_south: float = absf(center.z - (-3.0))
	var world_dir := Vector3.RIGHT if dist_west <= dist_south else Vector3.BACK
	var parent_n := mi.get_parent() as Node3D
	if parent_n == null:
		return world_dir * SLIDE_M
	return parent_n.global_transform.basis.inverse() * (world_dir * SLIDE_M)


func _world_aabb(mi: MeshInstance3D) -> AABB:
	var xf := mi.global_transform
	var local: AABB = mi.mesh.get_aabb()
	var out := AABB(xf * local.position, Vector3.ZERO)
	for i in 8:
		out = out.expand(xf * local.get_endpoint(i))
	return out


func _cluster_id_of(mesh: MeshInstance3D) -> int:
	if mesh == null:
		return 0
	var id := mesh.get_instance_id()
	if _clusters.has(id):
		return id
	return 0


func _slide_cluster(pid: int, want_open: bool) -> void:
	if not _clusters.has(pid):
		return
	for mi: MeshInstance3D in _clusters[pid]:
		var id := mi.get_instance_id()
		var rest: Vector3 = _rest_pos[id]
		var dest: Vector3 = rest + (_slide_delta[id] if want_open else Vector3.ZERO)
		var existing: Variant = _tweens.get(id, null)
		if existing is Tween:
			(existing as Tween).kill()
		var tw := create_tween()
		_tweens[id] = tw
		tw.tween_property(mi, "position", dest, TWEEN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(
			Tween.EASE_OUT
		)
		tw.finished.connect(func() -> void: _tweens.erase(id))
