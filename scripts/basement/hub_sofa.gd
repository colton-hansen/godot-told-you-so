extends Node
## Kitchen sofa is a 3-seater: look at a cushion, sit in that third. Pillows count too.

const GROUP_INTERACT_MESH := &"interactable_mesh"
const SIT_PLACES := 3


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		return
	_scan(sketch)


func _scan(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and String(mi.name).to_lower() == "sofa":
			_tag_seat(mi, mi)
			_tag_pillows(mi, mi)
	for c: Node in n.get_children():
		_scan(c)


func _tag_pillows(n: Node, sofa: MeshInstance3D) -> void:
	for c: Node in n.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh != null and String(mi.name).to_lower().begins_with("pillow"):
				_tag_seat(mi, sofa)
		_tag_pillows(c, sofa)


func _tag_seat(mi: MeshInstance3D, sofa: MeshInstance3D) -> void:
	mi.add_to_group(GROUP_INTERACT_MESH)
	mi.set_meta(&"interact_kind", &"sit")
	mi.set_meta(&"sit_seat", sofa)
	sofa.set_meta(&"sit_places", SIT_PLACES)
	mi.set_meta(&"interact_faces", mi.mesh.get_faces())
