extends SceneTree

func _initialize() -> void:
	call_deferred("_preview")

func _preview() -> void:
	var scene := (load("res://scenes/basement/basement_hub.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(8, 10, 10)
	camera.look_at(Vector3(1, 0, -1.3))
	camera.current = true
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/hub-preview.png")
	var player := scene.get_node("Player")
	player.global_position = Vector3(-1, 0.1, -0.3)
	player.third_person = true
	player.fps_man.hide_head_from_player_camera = false
	camera.position = Vector3(-1, 1.4, -3.1)
	camera.look_at(Vector3(-1, 1.1, -0.3))
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/player-preview.png")
	print("HUB_PREVIEW_SAVED")
	quit()
