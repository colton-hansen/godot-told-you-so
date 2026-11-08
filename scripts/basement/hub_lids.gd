extends Node
## Oven door (90°), toilet lid (90°), washing-machine lid (80°). Moving meshes have no collision.

const GROUP_CTRL := &"hub_lids"
const GROUP_INTERACT_MESH := &"interactable_mesh"
const TWEEN_SEC := 0.35

var _hinges: Dictionary = {} # int instance_id -> Node3D
var _open_euler: Dictionary = {} # int -> Vector3
var _tweens: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP_CTRL)
	call_deferred("_setup")


func is_closed(leaf: MeshInstance3D) -> bool:
	return leaf != null and bool(leaf.get_meta(&"lid_closed", true))


func toggle(leaf: MeshInstance3D) -> void:
	if leaf == null:
		return
	if leaf.has_meta(&"lid_leaf"):
		leaf = leaf.get_meta(&"lid_leaf") as MeshInstance3D
	if leaf == null:
		return
	_set_closed(leaf, not is_closed(leaf))


func _setup() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	_bind(sketch, "oven", "oven-door", Vector3(0.0, 0.0, deg_to_rad(-90.0)))
	_bind(sketch, "toilet", "toilet-top", Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_bind(sketch, "washing-maschine", "washing-maschine-top", Vector3(deg_to_rad(-80.0), 0.0, 0.0))


func _bind(sketch: Node, body_name: String, lid_name: String, open_euler: Vector3) -> void:
	var body := _find_mesh(sketch, body_name)
	var lid := _find_mesh(sketch, lid_name)
	if lid == null:
		push_warning("hub_lids: missing " + lid_name)
		return
	var hinge := Node3D.new()
	hinge.name = String(lid.name) + "Hinge"
	var host := lid.get_parent()
	if host == null:
		return
	host.add_child(hinge)
	hinge.global_position = lid.global_position
	hinge.global_rotation = Vector3.ZERO
	lid.reparent(hinge, true)
	var id := lid.get_instance_id()
	_hinges[id] = hinge
	_open_euler[id] = open_euler
	lid.set_meta(&"lid_closed", true)
	_tag(lid, lid)
	_tag(body, lid)


func _tag(mi: MeshInstance3D, leaf: MeshInstance3D) -> void:
	if mi == null:
		return
	mi.add_to_group(GROUP_INTERACT_MESH)
	mi.set_meta(&"interact_kind", &"lid")
	mi.set_meta(&"lid_leaf", leaf)
	if mi.mesh != null:
		mi.set_meta(&"interact_faces", mi.mesh.get_faces())


func _set_closed(leaf: MeshInstance3D, want_closed: bool) -> void:
	var id := leaf.get_instance_id()
	if not _hinges.has(id):
		return
	var hinge: Node3D = _hinges[id]
	var busy: bool = _tweens.has(id)
	if is_closed(leaf) == want_closed and not busy:
		return
	leaf.set_meta(&"lid_closed", want_closed)
	if busy:
		(_tweens[id] as Tween).kill()
		_tweens.erase(id)
	var target: Vector3 = Vector3.ZERO if want_closed else (_open_euler[id] as Vector3)
	var tw := create_tween()
	_tweens[id] = tw
	tw.tween_property(hinge, "rotation", target, TWEEN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	tw.finished.connect(func() -> void: _tweens.erase(id))


func _find_mesh(n: Node, want: String) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name).to_lower() == want:
		return n as MeshInstance3D
	for c: Node in n.get_children():
		var found := _find_mesh(c, want)
		if found != null:
			return found
	return null
