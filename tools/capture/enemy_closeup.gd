extends Node

# Loads the real arena, lets a wave spawn, then frames a live operator enemy
# from the front at ~2.8 m in true in-game lighting so we can judge the
# integrated character (look, scale, facing, mid-animation pose).

var _t := 0.0
var _done := false
var _cam: Camera3D

func _physics_process(delta: float) -> void:
	_t += delta
	if _done:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.name != "World":
		return
	if _t < 3.0:
		return
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	var e: Node3D = enemies[0]
	# Frame the operator from the front, slightly above eye line.
	var fwd := Vector3(sin(e.rotation.y), 0.0, cos(e.rotation.y))
	if _cam == null:
		_cam = Camera3D.new()
		add_child(_cam)
	var eye: Vector3 = e.global_position + fwd * 2.8 + Vector3(0.0, 1.25, 0.0)
	_cam.global_position = eye
	_cam.look_at(e.global_position + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	_cam.make_current()
	if _t > 3.6:
		_done = true
		await _grab("user://bb_enemy_closeup.png")
		get_tree().quit()

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("CAPTURE_SAVED ", ProjectSettings.globalize_path(path))
