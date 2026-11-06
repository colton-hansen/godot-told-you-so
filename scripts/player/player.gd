extends CharacterBody3D

const BodyState := preload("res://scripts/player/player_body_state.gd")

@export var mouse_sensitivity: float = 0.002
@export var move_speed: float = 4.5
@export var sprint_speed: float = 7.5
@export var crouch_speed: float = 2.1
@export var jump_velocity: float = 4.8
@export var crouch_jump_velocity: float = 1.7
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.05
@export var crouch_blend_speed: float = 12.5
@export var sprint_after_stand_sec: float = 0.2
@export var crouch_eye_height: float = 1.02
@export var ground_acceleration: float = 22.0
@export var ground_friction: float = 28.0
@export var gravity_multiplier: float = 1.0
@export var pitch_limit_deg: float = 75.0
@export var camera_forward_idle: float = -0.02
@export var camera_forward_sprint: float = -0.14
@export var camera_forward_blend_speed: float = 10.0
@export var use_head_camera_anchor: bool = true
@export var head_camera_local_offset: Vector3 = Vector3(0.0, 0.02, 0.02)
@export var head_eye_height_from_feet: float = 1.68
@export var head_bob_scale: float = 0.35
@export var head_anchor_blend_speed: float = 18.0
@export var sprint_strafe: float = 0.32
@export var crouch_model_drop: float = 0.32
@export var crouch_model_pitch_deg: float = 10.0
@export var crouch_camera_lift: float = 0.25
@export var crouch_camera_forward: float = 0.14
@export var crouch_camera_right: float = 0.08

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var fps_man: Node3D = $FpsMan
@onready var inventory_ui: InventoryUI = $InventoryUI
@onready var player_inventory: Node = $PlayerInventory
@onready var crosshair: Control = $Crosshair
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _pitch: float = 0.0
var _enforce_pitch_limit: bool = true
var is_sprinting: bool = false
var is_crouching: bool = false
var _crouch: float = 0.0
var _air_sprint: bool = false
var _camera_pivot_rest: Vector3 = Vector3(0.0, 1.68, 0.0)
var _head_anchor_active: bool = false
var _camera_rest_local: Vector3 = Vector3.ZERO
var _body_shape: CylinderShape3D = null
var _body_state = BodyState.new()
var _sprint_ready_msec: int = 0


func _ready() -> void:
	add_to_group(&"player")
	_pitch = camera.rotation.x
	_camera_rest_local = camera.position
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	inventory_ui.setup(player_inventory.loadout)
	inventory_ui.closed.connect(_on_inventory_closed)
	inventory_ui.opened.connect(_on_inventory_opened)
	_seed_test_items()
	_prepare_body_shape()
	_apply_body_height()
	set_physics_process(true)
	set_process(true)


func _seed_test_items() -> void:
	var can := preload("res://resources/items/canned_food.tres") as ItemDefinition
	var bandage := preload("res://resources/items/bandage.tres") as ItemDefinition
	player_inventory.loadout.try_add_item(can, 2)
	player_inventory.loadout.try_add_item(bandage, 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if _is_locked():
		return
	if event.is_action_pressed("crouch"):
		_toggle_stance()
		get_viewport().set_input_as_handled()
		return
	if (
		event is InputEventMouseMotion
		and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	):
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch -= event.relative.y * mouse_sensitivity
		_apply_pitch()
	if event.is_action_pressed("ui_cancel"):
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED)
		_update_crosshair()


func _physics_process(delta: float) -> void:
	var gravity_value: float = (
		ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier
	)
	if not is_on_floor():
		velocity.y -= gravity_value * delta
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var locked: bool = _is_locked()
	if not locked:
		_stand_for_sprint(input_dir)
	_blend_stance_pose(delta)
	is_crouching = _body_state.wants_crouch()
	var sprint_req: bool = not locked and is_on_floor() and _sprint_requested(input_dir)
	var wish_dir := _wish_from_input(input_dir, sprint_req)
	if locked:
		is_sprinting = false
		_air_sprint = false
		if is_on_floor():
			_apply_horizontal_movement(Vector3.ZERO, delta, ground_friction, move_speed)
	elif is_on_floor():
		var moving: bool = wish_dir != Vector3.ZERO and _body_state.can_walk()
		var move_kind: int = _body_state.resolve_move(moving, sprint_req)
		is_sprinting = move_kind == BodyState.Move.SPRINT
		_air_sprint = is_sprinting
		var speed := _ground_speed()
		var accel := ground_acceleration if moving else ground_friction
		_apply_horizontal_movement(wish_dir if moving else Vector3.ZERO, delta, accel, speed)
		if _body_state.can_jump() and Input.is_action_just_pressed("jump"):
			velocity.y = crouch_jump_velocity if _body_state.wants_crouch() else jump_velocity
			_air_sprint = is_sprinting
	else:
		is_sprinting = _air_sprint and _body_state.can_sprint()
	_apply_body_height()
	move_and_slide()


func _process(delta: float) -> void:
	_update_camera_rig(delta)
	_update_crosshair()
	if not inventory_ui.is_open:
		_ensure_yaw_only_on_camera_pivot()
		_apply_pitch()


func _update_camera_rig(delta: float) -> void:
	if inventory_ui != null and inventory_ui.is_open:
		return
	var sprint_cam: bool = is_sprinting
	var target_forward: float = (
		camera_forward_sprint if sprint_cam else camera_forward_idle
	)
	target_forward -= crouch_camera_forward * _crouch
	var base_z := move_toward(
		camera.position.z,
		target_forward,
		camera_forward_blend_speed * delta,
	)
	camera.position = Vector3(
		_camera_rest_local.x + crouch_camera_right * _crouch,
		_camera_rest_local.y,
		base_z,
	)
	if use_head_camera_anchor and fps_man != null and fps_man.has_method("get_head_eye_global"):
		var head_pos: Vector3 = fps_man.get_head_eye_global(
			head_camera_local_offset,
			head_eye_height_from_feet,
			head_bob_scale,
		)
		head_pos.y += crouch_camera_lift * _crouch
		if head_pos.length_squared() > 0.0001:
			var blend := clampf(head_anchor_blend_speed * delta, 0.0, 1.0)
			if not _head_anchor_active:
				camera_pivot.global_position = head_pos
				_head_anchor_active = true
			else:
				camera_pivot.global_position = camera_pivot.global_position.lerp(head_pos, blend)
			return
	_head_anchor_active = false
	var rest := _camera_pivot_rest
	rest.y = lerpf(head_eye_height_from_feet, crouch_eye_height, _crouch) + crouch_camera_lift * _crouch
	camera_pivot.position = rest


func _forward_only(input_dir: Vector2) -> bool:
	return input_dir.y < -0.5


func _wish_from_input(input_dir: Vector2, sprinting: bool) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var local := Vector3(input_dir.x, 0.0, input_dir.y)
	if sprinting:
		local.x *= sprint_strafe
	var wish := camera_pivot.global_transform.basis * local
	wish.y = 0.0
	if wish.length_squared() < 0.0001:
		return Vector3.ZERO
	return wish.normalized()


func _is_locked() -> bool:
	return inventory_ui.is_open


func _toggle_stance() -> void:
	if _body_state.wants_crouch():
		if _has_stand_clearance():
			_body_state.enter_stand()
		return
	_body_state.enter_crouch()
	is_sprinting = false
	_air_sprint = false
	_sprint_ready_msec = 0


func _blend_stance_pose(delta: float) -> void:
	var target := 1.0 if _body_state.wants_crouch() else 0.0
	if target < _crouch and not _has_stand_clearance():
		target = 1.0
		_body_state.enter_crouch()
	_crouch = move_toward(_crouch, target, crouch_blend_speed * delta)


func _sprint_keys_held(input_dir: Vector2) -> bool:
	if not _forward_only(input_dir):
		return false
	if not Input.is_action_pressed("sprint"):
		return false
	return true


func _stand_for_sprint(input_dir: Vector2) -> void:
	if not _body_state.wants_crouch():
		return
	if not _sprint_keys_held(input_dir):
		return
	if not _has_stand_clearance():
		return
	_body_state.enter_stand()
	is_sprinting = false
	_air_sprint = false
	_sprint_ready_msec = Time.get_ticks_msec() + int(sprint_after_stand_sec * 1000.0)


func _sprint_requested(input_dir: Vector2) -> bool:
	if not _body_state.can_sprint():
		return false
	if Time.get_ticks_msec() < _sprint_ready_msec:
		return false
	return _sprint_keys_held(input_dir)


func _ground_speed() -> float:
	var speed := move_speed
	if is_sprinting:
		speed = sprint_speed
	elif _body_state.wants_crouch() or _crouch > 0.05:
		speed = crouch_speed
	return speed


func _prepare_body_shape() -> void:
	if _collision == null:
		return
	var src := _collision.shape
	if src is CylinderShape3D:
		_body_shape = (src as CylinderShape3D).duplicate() as CylinderShape3D
	else:
		_body_shape = CylinderShape3D.new()
	_body_shape.radius = 0.4
	_collision.shape = _body_shape
	_collision.scale = Vector3.ONE


func _has_stand_clearance() -> bool:
	var world := get_world_3d()
	if world == null:
		return true
	var from := global_position + Vector3(0.0, crouch_height * 0.55, 0.0)
	var to := global_position + Vector3(0.0, stand_height + 0.08, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return world.direct_space_state.intersect_ray(query).is_empty()


func _apply_body_height() -> void:
	if _collision == null:
		return
	if _body_shape == null:
		_prepare_body_shape()
	if _body_shape == null:
		return
	var height := lerpf(stand_height, crouch_height, _crouch)
	_body_shape.height = height
	_collision.position = Vector3(0.0, height * 0.5, 0.0)
	floor_snap_length = lerpf(0.2, 0.4, _crouch)
	if fps_man != null:
		fps_man.position.y = lerpf(0.0, -crouch_model_drop, _crouch)


func _apply_horizontal_movement(
	wish_dir: Vector3, delta: float, accel: float, speed: float = -1.0
) -> void:
	if speed < 0.0:
		speed = move_speed
	var target := wish_dir * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _toggle_inventory() -> void:
	inventory_ui.toggle()
	if inventory_ui.is_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_crosshair()


func _on_inventory_opened() -> void:
	_update_crosshair()


func _on_inventory_closed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_crosshair()


func _update_crosshair() -> void:
	if crosshair == null:
		return
	var should_show: bool = (
		not inventory_ui.is_open and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	crosshair.visible = should_show


func _ensure_yaw_only_on_camera_pivot() -> void:
	var rot := camera_pivot.rotation
	if absf(rot.x) > 0.00001 or absf(rot.z) > 0.00001:
		camera_pivot.rotation = Vector3(0.0, rot.y, 0.0)


func _pitch_limit_rad() -> float:
	return deg_to_rad(pitch_limit_deg)


func _apply_pitch() -> void:
	if _enforce_pitch_limit:
		_pitch = clamp(_pitch, -_pitch_limit_rad(), _pitch_limit_rad())
	camera.rotation.x = _pitch
