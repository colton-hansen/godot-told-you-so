@tool
extends Node3D

const Locomotion := preload("res://scripts/player/player_locomotion_anim.gd")

const HIDDEN_RENDER_LAYER: int = 2
const WORLD_RENDER_LAYER: int = 1

@export var hide_head_from_player_camera: bool = true:
	set(value):
		hide_head_from_player_camera = value
		_apply_mesh_layers()

@export var walk_speed_threshold: float = 0.15
@export var model_yaw_degrees: float = 180.0

@onready var _model_root: Node3D = $ManRig/ManModel

signal action_finished(clip: StringName)

var _body: CharacterBody3D
var _anim: AnimationPlayer
var _current: StringName = &""
var _rest_head_lift: float = NAN
var _action_lock: bool = false


func _ready() -> void:
	if _model_root == null:
		push_error("FpsMan: expected ManRig/ManModel.")
		return
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		_apply_editor_layout()
		return
	_apply_runtime_layout()


func _apply_editor_layout() -> void:
	position.y = 0.0
	_apply_mesh_layers(true)
	Locomotion.apply_body_material(_model_root)


func _apply_runtime_layout() -> void:
	position.y = 0.0
	_body = _find_player_body()
	Locomotion.apply_body_material(_model_root)
	_apply_mesh_layers(false)
	_anim = _model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		push_warning("FpsManView: no AnimationPlayer on man.fbx")
		return
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	Locomotion.install_locomotion_library(_anim)
	if not _anim.animation_finished.is_connected(_on_animation_finished):
		_anim.animation_finished.connect(_on_animation_finished)
	_play_locomotion(&"idle", 0.0)
	set_physics_process(true)
	set_process(true)


func get_head_eye_global(
	offset: Vector3,
	eye_height_from_feet: float,
	_bob_scale: float = 1.0,
) -> Vector3:
	if _body == null:
		return Vector3.ZERO
	var sk := _skeleton()
	if sk == null:
		return Vector3.ZERO
	var idx := _find_camera_bone(sk)
	if idx < 0:
		return Vector3.ZERO
	var head_world := sk.global_transform * sk.get_bone_global_pose(idx)
	var lift: float = head_world.origin.y - sk.global_transform.origin.y
	if is_nan(_rest_head_lift):
		_rest_head_lift = lift
	var eye_y: float = head_world.origin.y + (eye_height_from_feet - _rest_head_lift)
	var feet: Vector3 = _body.global_position
	return Vector3(feet.x, eye_y, feet.z) + head_world.basis * offset


func _skeleton() -> Skeleton3D:
	if _model_root == null:
		return null
	return _model_root.find_child("Skeleton3D", true, false) as Skeleton3D


func _find_camera_bone(sk: Skeleton3D) -> int:
	for bone_name in [&"Head", &"Neck"]:
		var idx := sk.find_bone(bone_name)
		if idx >= 0:
			return idx
	return -1


func play_action(clip: StringName, blend: float = 0.14, speed: float = 1.0) -> bool:
	var anim_id := Locomotion.clip_anim_id(clip)
	if _anim == null or not _anim.has_animation(anim_id):
		return false
	_action_lock = true
	_current = clip
	_anim.play(anim_id, blend)
	_anim.speed_scale = speed
	return true


func release_action() -> void:
	_action_lock = false
	_current = &""


func is_action_locked() -> bool:
	return _action_lock


func action_length(clip: StringName) -> float:
	var anim_id := Locomotion.clip_anim_id(clip)
	if _anim == null or not _anim.has_animation(anim_id):
		return 0.0
	return _anim.get_animation(anim_id).length


func _on_animation_finished(anim_name: StringName) -> void:
	var short := String(anim_name)
	if short.begins_with("locomotion/"):
		short = short.substr("locomotion/".length())
	action_finished.emit(StringName(short))


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _body == null:
		return
	if bool(_body.get("is_sitting")) or bool(_body.get("is_sit_turning")):
		return
	var pivot := _body.get_node_or_null("CameraPivot") as Node3D
	if pivot == null:
		return
	var yaw := pivot.rotation.y + deg_to_rad(model_yaw_degrees)
	var pitch := 0.0
	if _body.get("crouch_model_pitch_deg") != null and _body.get("_crouch") != null:
		pitch = deg_to_rad(float(_body.get("crouch_model_pitch_deg"))) * float(_body.get("_crouch"))
	rotation = Vector3(pitch, yaw, 0.0)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _anim == null or _body == null:
		return
	if _action_lock:
		return
	var h := Vector2(_body.velocity.x, _body.velocity.z).length()
	var clip: StringName = Locomotion.pick_locomotion(_body, walk_speed_threshold)
	_play_locomotion(clip, h)


func _find_player_body() -> CharacterBody3D:
	var n: Node = self
	while n != null:
		if n is CharacterBody3D:
			return n as CharacterBody3D
		n = n.get_parent()
	return null


func _apply_mesh_layers(editor_mode: bool = false) -> void:
	if _model_root == null:
		return
	var hide_head := hide_head_from_player_camera and not editor_mode
	for node in _model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.visible = true
		if hide_head:
			mi.layers = HIDDEN_RENDER_LAYER
		else:
			mi.layers = WORLD_RENDER_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _play_locomotion(name: StringName, horizontal_speed: float) -> void:
	var anim_id := Locomotion.clip_anim_id(name)
	if _anim == null or not _anim.has_animation(anim_id):
		return
	var speed_scale: float = Locomotion.locomotion_speed_scale(
		name, _body, horizontal_speed
	)
	if _current != name:
		var blend := Locomotion.blend_time(_current, name)
		_current = name
		_anim.play(anim_id, blend)
	_anim.speed_scale = speed_scale
