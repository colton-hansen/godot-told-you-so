extends Node
## FBX drops packed-texture paths (Image_0_009 with no bytes). Reapply albedo from the blend dump.

const TEX_DIR := "res://assets/textures/hub_imported/"
## Longer / more specific mesh-name fragments first. Pairs: fragment, filename.
const RULES: PackedStringArray = [
	"m_computercase", "Image_0_005.png",
	"m_tvcrt", "Image_0_006.png",
	"m_psx_stockpot", "Image_0_003.png",
	"object_4_001", "Image_0_003.png",
	"object_6_001", "Image_0_007.png",
	"flowerpot", "Image_0_010.png",
	"calathea", "Image_1.png",
	"_leaf_0", "Image_0.png",
	"_pots_0", "Image_2.png",
	"_rat_0", "Image_0_008.png",
	"_case_0", "Image_0_011.png",
	"_material_0", "Image_0_009.png",
	"object_10", "Image_0_007.png",
	"object_12", "Image_0_007.png",
	"object_14", "Image_0_007.png",
	"object_8", "Image_0_007.png",
	"object_6", "Image_0_004.png",
	"object_4", "Image_0_002.png",
]


func _ready() -> void:
	call_deferred("_apply")


func _apply() -> void:
	var sketch: Node3D = get_parent().get_node_or_null("BasementSketch") as Node3D
	if sketch == null:
		push_warning("hub_imported_textures: no BasementSketch")
		return
	_paint(sketch)


func _paint(n: Node) -> int:
	var hit := 0
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var tex := _tex_for(String(mi.name))
		if tex != null and mi.mesh != null:
			_override(mi, tex)
			hit += 1
	for c: Node in n.get_children():
		hit += _paint(c)
	return hit


func _tex_for(mesh_name: String) -> Texture2D:
	var nm := mesh_name.to_lower()
	if nm.contains("m_ps1"):
		return null
	var i := 0
	while i + 1 < RULES.size():
		if nm.contains(RULES[i]):
			var path := TEX_DIR + RULES[i + 1]
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
			push_warning("hub_imported_textures: missing " + path)
			return null
		i += 2
	return null


func _override(mi: MeshInstance3D, tex: Texture2D) -> void:
	for surf: int in range(mi.mesh.get_surface_count()):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE
		mat.roughness = 0.62
		mat.metallic = 0.0
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.texture_repeat = false
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.set_surface_override_material(surf, mat)
