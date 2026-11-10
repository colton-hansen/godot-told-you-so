extends CharacterBody3D

const BodyState := preload("res://scripts/player/player_body_state.gd")
const WORLD_BLOCKING_MASK: int = 1 << 0 # layer 1 — walls / map collision

enum SitPhase { NONE, APPROACHING, ENTERING, SEATED, EXITING }

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
@export var interact_range: float = 2.0
@export var sit_stand_gap: float = 0.5
@export var sit_seat_gap: float = -0.32
@export var sit_backup_speed: float = 4.95
@export var sit_turn_deg_per_sec: float = 360.0
@export var sit_arrive_dist: float = 0.14
@export var sit_camera_lift: float = 0.32
@export var sit_anim_speed: float = 2.325
@export var sit_yaw_limit_deg: float = 120.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var fps_man: Node3D = $FpsMan
@onready var inventory_ui: InventoryUI = $InventoryUI
@onready var player_inventory: Node = $PlayerInventory
@onready var crosshair: Control = $Crosshair
@onready var interact_hint: InteractHint = $InteractHint
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
var _aimed_storage_id: StringName = StringName()
var _aimed_interactable: bool = false
var _aimed_kind: StringName = StringName()
var _aimed_seat: MeshInstance3D = null
var _aimed_hit_point: Vector3 = Vector3.ZERO
var _aimed_door: MeshInstance3D = null
var _aimed_lid: MeshInstance3D = null
var is_sitting: bool = false
var is_sit_turning: bool = false
var _sit_phase: int = SitPhase.NONE
var _sit_yaw: float = 0.0
var _sit_anchor: Vector3 = Vector3.ZERO
var _sit_approach: Vector3 = Vector3.ZERO
var _sit_from: Vector3 = Vector3.ZERO
var _sit_facing: Vector3 = Vector3.FORWARD
var _sit_enter_t: float = 0.0
var _sit_enter_dur: float = 2.2
var _sit_pose_blend: float = 0.0
var _open_storage_id: StringName = StringName()
var _aimed_storage_mesh: MeshInstance3D = null
var _open_storage_mesh: MeshInstance3D = null
var _rummaging: bool = false


var _run_target: RunInteraction


func _ready() -> void:
	add_to_group(&"player")
	_pitch = camera.rotation.x
	_camera_rest_local = camera.position
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	inventory_ui.setup(player_inventory.loadout)
	inventory_ui.closed.connect(_on_inventory_closed)
	inventory_ui.opened.connect(_on_inventory_opened)
	inventory_ui.storage_closed.connect(_on_storage_closed)
	_prepare_body_shape()
	_apply_body_height()
	if fps_man != null and fps_man.has_signal(&"action_finished"):
		fps_man.action_finished.connect(_on_man_action_finished)
	set_physics_process(true)
	set_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _is_locked():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_hotbar(-1)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_hotbar(1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var slot_i: int = key.physical_keycode - KEY_1
		if slot_i >= 0 and slot_i <= 5:
			_equip_hotbar(slot_i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("toggle_inventory"):
		if inventory_ui.is_storage_open:
			inventory_ui.close_storage()
			get_viewport().set_input_as_handled()
			return
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if inventory_ui.is_storage_open:
			inventory_ui.close_storage()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_update_crosshair()
			get_viewport().set_input_as_handled()
			return
		if _sit_phase == SitPhase.APPROACHING or _sit_phase == SitPhase.ENTERING or _sit_phase == SitPhase.EXITING:
			get_viewport().set_input_as_handled()
			return
		if _sit_phase == SitPhase.SEATED:
			_begin_stand_from_sit()
			get_viewport().set_input_as_handled()
			return
		if not inventory_ui.is_open and is_instance_valid(_run_target) and _run_target.enabled():
			get_viewport().set_input_as_handled()
			_run_target.action.call()
			return
		if not inventory_ui.is_open and _aimed_kind == &"sit":
			_begin_sit()
			get_viewport().set_input_as_handled()
			return
		if not inventory_ui.is_open and _aimed_kind == &"door":
			_toggle_aimed_door()
			get_viewport().set_input_as_handled()
			return
		if not inventory_ui.is_open and _aimed_kind == &"lid":
			_toggle_aimed_lid()
			get_viewport().set_input_as_handled()
			return
		if not inventory_ui.is_open and _aimed_interactable and _open_storage(_aimed_storage_id):
			get_viewport().set_input_as_handled()
		return
	if _is_locked():
		return
	if _sit_phase != SitPhase.NONE:
		if (
			_sit_phase != SitPhase.APPROACHING
			and event is InputEventMouseMotion
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		):
			camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
			_pitch -= event.relative.y * mouse_sensitivity
			_clamp_sit_look_yaw()
			_apply_pitch()
		if event.is_action_pressed("jump"):
			if _sit_phase == SitPhase.SEATED:
				_begin_stand_from_sit()
			get_viewport().set_input_as_handled()
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
		if inventory_ui.is_storage_open:
			inventory_ui.close_storage()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_update_crosshair()
			get_viewport().set_input_as_handled()
			return
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
	if _sit_phase == SitPhase.APPROACHING:
		_tick_sit_approach(delta)
		_apply_body_height()
		move_and_slide()
		return
	if _sit_phase != SitPhase.NONE:
		_tick_sitting(input_dir)
		return
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
	if _sit_phase == SitPhase.APPROACHING:
		_apply_body_look_yaw(_sit_yaw)
	_update_interact_aim()
	_update_crosshair()
	if not inventory_ui.is_open:
		_ensure_yaw_only_on_camera_pivot()
		_clamp_sit_look_yaw()
		_apply_pitch()
		if _sit_phase == SitPhase.APPROACHING:
			_apply_body_look_yaw(_sit_yaw)


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
		head_pos.y += crouch_camera_lift * _crouch + sit_camera_lift * _sit_pose_blend
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
	rest.y = (
		lerpf(head_eye_height_from_feet, crouch_eye_height, _crouch)
		+ crouch_camera_lift * _crouch
		+ sit_camera_lift * _sit_pose_blend
	)
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


func _interact_raycast() -> Dictionary:
	if camera == null:
		return {}
	var w := get_world_3d()
	if w == null:
		return {}
	var origin := camera.global_position
	var dir := (-camera.global_transform.basis.z).normalized()

	# Closest visible triangle within range, blocked by walls.
	var best_d := interact_range
	var best: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"interactable_mesh"):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var kind := _interact_kind_of(mi)
		if kind == StringName():
			continue
		var hit: Dictionary = _closest_triangle_hit(mi, origin, dir, best_d)
		if not bool(hit.get("ok", false)):
			continue
		var dist := float(hit.dist)
		if dist >= best_d:
			continue
		if not _has_clear_los_to(origin, hit.point as Vector3, w):
			continue
		best_d = dist
		best = {
			"kind": kind,
			"id": mi.get_meta(&"storage_id", StringName()) as StringName,
			"mesh": mi,
			"point": hit.point as Vector3,
		}
	return best


func _interact_kind_of(mi: MeshInstance3D) -> StringName:
	if mi.has_meta(&"interact_kind"):
		return mi.get_meta(&"interact_kind") as StringName
	if mi.has_meta(&"storage_id"):
		return &"storage"
	return StringName()


func _closest_triangle_hit(mi: MeshInstance3D, origin: Vector3, dir: Vector3, max_d: float) -> Dictionary:
	var faces: PackedVector3Array
	if mi.has_meta(&"interact_faces"):
		faces = mi.get_meta(&"interact_faces") as PackedVector3Array
	else:
		var mesh: Mesh = mi.mesh
		if mesh == null:
			return {"ok": false}
		faces = mesh.get_faces()
		mi.set_meta(&"interact_faces", faces)
	if faces.size() < 3:
		return {"ok": false}
	# FBX doors have non-uniform parent scale (~50/100). Local-space rays miss;
	# test triangles in world space.
	var xf := mi.global_transform
	var best_world := max_d
	var best_pt := Vector3.ZERO
	var ok := false
	var i := 0
	while i + 2 < faces.size():
		var p: Variant = Geometry3D.ray_intersects_triangle(
			origin, dir, xf * faces[i], xf * faces[i + 1], xf * faces[i + 2]
		)
		if p != null:
			var world_p := p as Vector3
			var d: float = origin.distance_to(world_p)
			if d > 0.002 and d < best_world:
				best_world = d
				best_pt = world_p
				ok = true
		i += 3
	if not ok:
		return {"ok": false}
	return {"ok": true, "dist": best_world, "point": best_pt}


func _has_clear_los_to(
	origin: Vector3, aim: Vector3, w: World3D, extra_exclude: Array[RID] = []
) -> bool:
	var dist: float = origin.distance_to(aim)
	if dist < 0.02:
		return true
	var q_wall := PhysicsRayQueryParameters3D.create(origin, aim)
	q_wall.collide_with_areas = false
	q_wall.collide_with_bodies = true
	q_wall.collision_mask = WORLD_BLOCKING_MASK
	q_wall.hit_from_inside = false
	var ex: Array[RID] = _ray_exclude_rids()
	ex.append_array(extra_exclude)
	q_wall.exclude = ex
	var hit_w: Dictionary = w.direct_space_state.intersect_ray(q_wall)
	if hit_w.is_empty():
		return true
	# Merged map collision includes the aimed mesh — a hit at the aim point is not a wall.
	var dist_wall: float = origin.distance_to(hit_w.position)
	return dist_wall >= dist - 0.08


func _ray_exclude_rids() -> Array[RID]:
	# exclude expects the CharacterBody3D physics RID
	return [get_rid()] as Array[RID]


func _toggle_aimed_door() -> void:
	if _aimed_door == null:
		return
	var ctrl: Node = get_tree().get_first_node_in_group(&"hub_swing_doors")
	if ctrl != null and ctrl.has_method("toggle"):
		ctrl.call("toggle", _aimed_door)


func _toggle_aimed_lid() -> void:
	if _aimed_lid == null:
		return
	var ctrl: Node = get_tree().get_first_node_in_group(&"hub_lids")
	if ctrl != null and ctrl.has_method("toggle"):
		ctrl.call("toggle", _aimed_lid)


func _open_storage(sid: StringName) -> bool:
	if sid == StringName() or inventory_ui == null:
		return false
	if inventory_ui.is_open:
		return false
	var loadout: PlayerLoadout = KitchenStorages.loadout(sid)
	if loadout == null:
		return false
	inventory_ui.open_storage(loadout, KitchenStorages.interact_label(sid), sid)
	_open_storage_id = sid
	_open_storage_mesh = _aimed_storage_mesh
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_crosshair()
	_start_rummage()
	_set_appliance_open(sid, true)
	return true


func _update_interact_aim() -> void:
	_run_target = null
	_aimed_interactable = false
	_aimed_storage_id = StringName()
	_aimed_storage_mesh = null
	_aimed_kind = StringName()
	_aimed_seat = null
	_aimed_hit_point = Vector3.ZERO
	_aimed_door = null
	_aimed_lid = null
	if interact_hint != null:
		interact_hint.set_hint("")
	if _sit_phase == SitPhase.SEATED:
		if interact_hint != null:
			interact_hint.set_hint("Stand [E]")
		return
	if _sit_phase != SitPhase.NONE:
		return
	if _is_locked() or camera == null:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	var best := interact_range
	for node in get_tree().get_nodes_in_group(&"run_interaction"):
		var target := node as RunInteraction
		var distance := camera.global_position.distance_to(target.global_position)
		if distance >= best or not target.enabled():
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, target.global_position,
			WORLD_BLOCKING_MASK, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		_run_target = target
		best = distance
	if _run_target != null:
		interact_hint.set_hint(_run_target.prompt + " [E]")
		return
	var hit := _interact_raycast()
	if hit.is_empty():
		return
	var kind: StringName = hit.kind as StringName
	if kind == &"sit":
		_aimed_kind = &"sit"
		var seat := hit.mesh as MeshInstance3D
		if seat != null and seat.has_meta(&"sit_seat"):
			seat = seat.get_meta(&"sit_seat") as MeshInstance3D
		_aimed_seat = seat
		_aimed_hit_point = hit.point as Vector3
		_aimed_interactable = true
		if interact_hint != null:
			interact_hint.set_hint("Sit [E]")
		return
	if kind == &"door":
		_aimed_kind = &"door"
		var door_mesh := hit.mesh as MeshInstance3D
		if door_mesh != null and door_mesh.has_meta(&"door_leaf"):
			_aimed_door = door_mesh.get_meta(&"door_leaf") as MeshInstance3D
		else:
			_aimed_door = door_mesh
		_aimed_interactable = true
		if interact_hint != null:
			var closed := _aimed_door != null and bool(_aimed_door.get_meta(&"door_closed", false))
			interact_hint.set_hint("Open [E]" if closed else "Close [E]")
		return
	if kind == &"lid":
		_aimed_kind = &"lid"
		var lid_mesh := hit.mesh as MeshInstance3D
		if lid_mesh != null and lid_mesh.has_meta(&"lid_leaf"):
			_aimed_lid = lid_mesh.get_meta(&"lid_leaf") as MeshInstance3D
		else:
			_aimed_lid = lid_mesh
		_aimed_interactable = true
		if interact_hint != null:
			var lid_closed := _aimed_lid != null and bool(_aimed_lid.get_meta(&"lid_closed", true))
			interact_hint.set_hint("Open [E]" if lid_closed else "Close [E]")
		return
	var sid: StringName = hit.id as StringName
	var loadout: PlayerLoadout = KitchenStorages.loadout(sid)
	if loadout == null:
		return
	_aimed_kind = &"storage"
	_aimed_interactable = true
	_aimed_storage_id = sid
	_aimed_storage_mesh = hit.mesh as MeshInstance3D
	if interact_hint != null:
		var name_part := KitchenStorages.interact_label(sid)
		interact_hint.set_hint("%s [E]" % name_part)


func _tick_sitting(input_dir: Vector2) -> void:
	velocity = Vector3.ZERO
	is_sprinting = false
	_air_sprint = false
	if _body_state.wants_crouch():
		_body_state.enter_stand()
	is_crouching = false
	_crouch = 0.0
	if _sit_phase == SitPhase.ENTERING or _sit_phase == SitPhase.EXITING:
		_sit_enter_t += get_physics_process_delta_time()
		var a := clampf(_sit_enter_t / maxf(_sit_enter_dur, 0.05), 0.0, 1.0)
		a = a * a * (3.0 - 2.0 * a)
		_sit_pose_blend = a if _sit_phase == SitPhase.ENTERING else 1.0 - a
		var p := _sit_from.lerp(_sit_anchor, a)
		p.y = _sit_anchor.y
		global_position = p
	elif _sit_phase == SitPhase.SEATED:
		_sit_pose_blend = 1.0
		global_position = _sit_anchor
	else:
		_sit_pose_blend = 0.0
	_apply_body_height()
	if _sit_phase == SitPhase.SEATED and not _is_locked():
		if input_dir.length() > 0.35 or Input.is_action_just_pressed("jump"):
			_begin_stand_from_sit()


func _tick_sit_approach(delta: float) -> void:
	is_sprinting = false
	_air_sprint = false
	if _body_state.wants_crouch():
		_body_state.enter_stand()
	is_crouching = false
	_crouch = move_toward(_crouch, 0.0, crouch_blend_speed * delta)
	_sit_pose_blend = 0.0
	var target_yaw := _yaw_from_dir(_sit_facing)
	_sit_yaw = rotate_toward(_sit_yaw, target_yaw, deg_to_rad(sit_turn_deg_per_sec) * delta)
	_apply_body_look_yaw(_sit_yaw)
	var yaw_err := absf(angle_difference(_sit_yaw, target_yaw))
	if yaw_err > deg_to_rad(8.0):
		velocity.x = 0.0
		velocity.z = 0.0
		return
	is_sit_turning = false
	var to := _sit_approach - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= sit_arrive_dist:
		velocity.x = 0.0
		velocity.z = 0.0
		_start_sit_down()
		return
	var dir := to / dist
	var speed := sit_backup_speed
	if dist < 0.4:
		speed = sit_backup_speed * clampf(dist / 0.4, 0.25, 1.0)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _apply_body_look_yaw(yaw: float) -> void:
	camera_pivot.rotation = Vector3(0.0, yaw, 0.0)
	if fps_man == null:
		return
	var extra := 0.0
	if fps_man.get("model_yaw_degrees") != null:
		extra = deg_to_rad(float(fps_man.get("model_yaw_degrees")))
	var model_pitch := deg_to_rad(crouch_model_pitch_deg) * _crouch
	fps_man.rotation = Vector3(model_pitch, yaw + extra, 0.0)


func _yaw_from_dir(dir: Vector3) -> float:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.0001:
		return camera_pivot.rotation.y
	# Camera looks down local -Z; looking_at matches that, atan2(x, -z) was 180° off.
	return Basis.looking_at(d.normalized(), Vector3.UP).get_euler().y


func _begin_sit() -> void:
	if _aimed_seat == null or _sit_phase != SitPhase.NONE:
		return
	if not is_on_floor():
		return
	_sit_facing = _seat_facing(_aimed_seat)
	_sit_approach = _seat_anchor(_aimed_seat, _sit_facing, sit_stand_gap)
	_sit_anchor = _seat_anchor(_aimed_seat, _sit_facing, sit_seat_gap)
	_sit_yaw = camera_pivot.rotation.y
	velocity = Vector3.ZERO
	_body_state.enter_stand()
	is_crouching = false
	is_sitting = false
	is_sit_turning = true
	_sit_phase = SitPhase.APPROACHING
	_apply_body_look_yaw(_sit_yaw)


func _start_sit_down() -> void:
	_sit_from = global_position
	_sit_from.y = _sit_anchor.y
	_sit_enter_t = 0.0
	_sit_enter_dur = 2.2 / sit_anim_speed
	if fps_man != null and fps_man.has_method("action_length"):
		var d: float = float(fps_man.call("action_length", &"stand_to_sit"))
		if d > 0.05:
			_sit_enter_dur = d / sit_anim_speed
	_sit_yaw = _yaw_from_dir(_sit_facing)
	_apply_body_look_yaw(_sit_yaw)
	is_sitting = true
	is_sit_turning = false
	_sit_phase = SitPhase.ENTERING
	if not bool(fps_man.call("play_action", &"stand_to_sit", 0.12, sit_anim_speed)):
		if bool(fps_man.call("play_action", &"sit_idle", 0.16)):
			global_position = _sit_anchor
			_sit_phase = SitPhase.SEATED
		else:
			is_sitting = false
			_sit_phase = SitPhase.NONE


func _begin_stand_from_sit() -> void:
	if _sit_phase != SitPhase.SEATED:
		return
	_sit_phase = SitPhase.EXITING
	_sit_from = global_position
	_sit_anchor = _sit_anchor + _sit_facing * 0.28
	_sit_enter_t = 0.0
	_sit_enter_dur = 2.2 / sit_anim_speed
	if fps_man != null and fps_man.has_method("action_length"):
		var d: float = float(fps_man.call("action_length", &"sit_to_stand"))
		if d > 0.05:
			_sit_enter_dur = d / sit_anim_speed
	if not bool(fps_man.call("play_action", &"sit_to_stand", 0.12, sit_anim_speed)):
		_finish_stand_from_sit()


func _finish_stand_from_sit() -> void:
	_sit_phase = SitPhase.NONE
	is_sitting = false
	is_sit_turning = false
	_sit_pose_blend = 0.0
	if fps_man != null and fps_man.has_method("release_action"):
		fps_man.call("release_action")


func _on_man_action_finished(clip: StringName) -> void:
	if clip == &"stand_to_sit" and _sit_phase == SitPhase.ENTERING:
		if bool(fps_man.call("play_action", &"sit_idle", 0.18)):
			_sit_phase = SitPhase.SEATED
		else:
			_finish_stand_from_sit()
		return
	if clip == &"sit_to_stand" and _sit_phase == SitPhase.EXITING:
		_finish_stand_from_sit()


func _seat_facing(mi: MeshInstance3D) -> Vector3:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return Vector3.FORWARD
	var aabb: AABB = mi.global_transform * mesh.get_aabb()
	var center: Vector3 = aabb.get_center()
	var to_player := global_position - center
	to_player.y = 0.0
	if aabb.size.x <= aabb.size.z:
		var sx := signf(to_player.x)
		if is_zero_approx(sx):
			sx = 1.0
		return Vector3(sx, 0.0, 0.0)
	var sz := signf(to_player.z)
	if is_zero_approx(sz):
		sz = 1.0
	return Vector3(0.0, 0.0, sz)


func _seat_anchor(mi: MeshInstance3D, facing: Vector3, gap: float) -> Vector3:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return global_position
	var aabb: AABB = mi.global_transform * mesh.get_aabb()
	var center := _sit_slot_center(mi, aabb)
	var half := minf(aabb.size.x, aabb.size.z) * 0.5
	return Vector3(center.x, global_position.y, center.z) + facing * (half + gap)


func _sit_slot_center(mi: MeshInstance3D, aabb: AABB) -> Vector3:
	var places := int(mi.get_meta(&"sit_places", 1))
	if places < 2:
		return aabb.get_center()
	var along_z := aabb.size.z >= aabb.size.x
	var hint := _aimed_hit_point
	if hint == Vector3.ZERO:
		hint = global_position
	var best_i := 0
	var best_d := INF
	for i in places:
		var c := _slot_center(aabb, along_z, i, places)
		var d := Vector2(c.x - hint.x, c.z - hint.z).length_squared()
		if d < best_d:
			best_d = d
			best_i = i
	return _slot_center(aabb, along_z, best_i, places)


func _slot_center(aabb: AABB, along_z: bool, i: int, n: int) -> Vector3:
	var t := (float(i) + 0.5) / float(n)
	var c := aabb.get_center()
	if along_z:
		c.z = aabb.position.z + aabb.size.z * t
	else:
		c.x = aabb.position.x + aabb.size.x * t
	return c


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


func _equip_hotbar(slot_i: int) -> void:
	var loadout: PlayerLoadout = player_inventory.loadout
	if loadout == null:
		return
	if slot_i < 0 or slot_i > 5:
		return
	loadout.set_held_pocket(slot_i)


func _cycle_hotbar(delta: int) -> void:
	var loadout: PlayerLoadout = player_inventory.loadout
	if loadout == null:
		return
	loadout.set_held_pocket(posmod(loadout.held_pocket + delta, InventoryLayout.POCKET_COUNT))


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


func _on_storage_closed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_crosshair()
	_stop_rummage()
	_set_appliance_open(_open_storage_id, false)
	_open_storage_id = StringName()
	_open_storage_mesh = null


func _start_rummage() -> void:
	if _rummaging or _sit_phase != SitPhase.NONE:
		return
	if fps_man == null:
		return
	_rummaging = true
	fps_man.call("play_action", &"while_interacting", 0.14)


func _stop_rummage() -> void:
	if not _rummaging:
		return
	_rummaging = false
	if _sit_phase == SitPhase.NONE and fps_man != null and fps_man.has_method("release_action"):
		fps_man.call("release_action")


func _set_appliance_open(sid: StringName, want: bool) -> void:
	var mesh := _open_storage_mesh
	for n: Node in get_tree().get_nodes_in_group(&"hub_storage_anim"):
		if n.has_method("set_open"):
			n.call("set_open", sid, want, mesh)


func _update_crosshair() -> void:
	if crosshair == null:
		return
	var ui_open := inventory_ui.is_open
	var should_show: bool = not ui_open and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
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


func _clamp_sit_look_yaw() -> void:
	if (
		_sit_phase != SitPhase.ENTERING
		and _sit_phase != SitPhase.SEATED
		and _sit_phase != SitPhase.EXITING
	):
		return
	var base := _yaw_from_dir(_sit_facing)
	var limit := deg_to_rad(sit_yaw_limit_deg)
	var offset := angle_difference(base, camera_pivot.rotation.y)
	camera_pivot.rotation.y = base + clampf(offset, -limit, limit)
