extends Node

# Loads the arena, spawns THE WARDEN (boss) flanked by two operators, and
# frames them from a low hero angle so we can verify the boss renders at the
# right towering scale with its floor-aligned model. Run WINDOWED.

const BOSS := preload("res://boss.tscn")
const ENEMY := preload("res://enemy.tscn")

var _t := 0.0
var _spawned := false
var _shot := false
var _cam: Camera3D
var _boss: Node3D

func _process(delta: float) -> void:
	_t += delta
	var scene := get_tree().current_scene
	if scene == null or scene.name != "World":
		return
	if _t > 1.5 and not _spawned:
		_spawned = true
		var p := get_tree().get_first_node_in_group("player")
		var c: Vector3 = p.global_position if p else Vector3.ZERO
		_boss = BOSS.instantiate()
		scene.add_child(_boss)
		_boss.global_position = c + Vector3(0.0, 0.0, -5.0)
		for i in 2:
			var e := ENEMY.instantiate()
			if "start_alerted" in e:
				e.start_alerted = true
			scene.add_child(e)
			e.global_position = c + Vector3(-2.5 + 5.0 * i, 0.0, -3.5)
		_cam = Camera3D.new()
		add_child(_cam)
	if _spawned and is_instance_valid(_boss):
		# Low hero angle looking up at the boss.
		_cam.global_position = _boss.global_position + Vector3(2.6, 1.0, 3.4)
		_cam.look_at(_boss.global_position + Vector3(0.0, 2.4, 0.0), Vector3.UP)
		_cam.make_current()
	if _t > 3.0 and not _shot:
		_shot = true
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://bb_boss.png")
		print("CAPTURE_SAVED ", ProjectSettings.globalize_path("user://bb_boss.png"))
		get_tree().quit()
