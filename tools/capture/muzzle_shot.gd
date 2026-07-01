extends Node

# Spawns a ranged operator, triggers a muzzle flash at its weapon, and grabs the
# frame inside the ~0.08s flash window to verify gunfire reads well. Run WINDOWED.

const RANGED := preload("res://enemy_ranged.tscn")

var _t := 0.0
var _spawned := false
var _cam: Camera3D
var _op: Node3D
var _fired := false

func _process(delta: float) -> void:
	_t += delta
	var scene := get_tree().current_scene
	if scene == null or scene.name != "World":
		return
	if _t > 1.5 and not _spawned:
		_spawned = true
		var p := get_tree().get_first_node_in_group("player")
		var c: Vector3 = p.global_position if p else Vector3.ZERO
		_op = RANGED.instantiate()
		scene.add_child(_op)
		_op.global_position = c + Vector3(0.0, 0.0, -4.0)
		_op.rotation.y = PI   # face toward +Z (the camera/player side)
		_cam = Camera3D.new()
		add_child(_cam)
		_cam.global_position = c + Vector3(3.0, 1.5, 0.5)
		_cam.look_at(_op.global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
		_cam.make_current()
	# Fire a flash whose tracer streaks across the frame, then grab the SAME
	# frame so the flash light + tracer are at full brightness.
	if _t > 2.4 and not _fired and is_instance_valid(_op):
		_fired = true
		var muzzle: Vector3 = _op.global_position + Vector3(-0.1, 1.2, 0.55)
		Game.spawn_muzzle_flash(muzzle, Vector3(-1.0, 0.0, 0.15), 12.0)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://bb_muzzle.png")
		print("CAPTURE_SAVED ", ProjectSettings.globalize_path("user://bb_muzzle.png"))
		get_tree().quit()
