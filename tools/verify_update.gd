extends SceneTree

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var scene := (load("res://scenes/basement/basement_hub.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 12:
		await physics_frame
	var player := scene.get_node("Player")
	var animation := player.get_node("FpsMan").find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(animation.has_animation("locomotion/f_walk"))
	assert(not animation.has_animation("locomotion/b_walk"))
	assert(animation.get_animation("locomotion/f_walk").get_track_count() > 10)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_V
	key.pressed = true
	player._unhandled_input(key)
	await process_frame
	await process_frame
	assert(player.third_person)
	print("CAMERA ", player.camera.position)
	assert(player.camera.position.z > 0)
	player._unhandled_input(key)
	await process_frame
	assert(not player.third_person)
	for variant in range(1, 4):
		var robot := (load("res://assets/characters/sint-bot/sint-bot-model-%d.glb" % variant) as PackedScene).instantiate()
		root.add_child(robot)
		var anim := robot.find_child("AnimationPlayer", true, false) as AnimationPlayer
		load("res://scripts/player/player_locomotion_anim.gd").install_locomotion_library(anim, {"idle": "idle", "walk": "walk", "run": "run", "overhead-punch": "overhead-punch"})
		assert(anim.get_animation_list().size() == 4)
		assert(anim.get_animation("locomotion/overhead-punch").get_track_count() > 10)
		robot.queue_free()
	scene.queue_free()
	await process_frame
	var raid := (load("res://scenes/mall/mall.tscn") as PackedScene).instantiate()
	root.add_child(raid)
	current_scene = raid
	root.get_node("RunState").phase = 1
	for i in 90:
		await physics_frame
	print("UPDATE_VERIFIED: hub, camera toggle, player tracks, all three sint-bot variants")
	quit()
