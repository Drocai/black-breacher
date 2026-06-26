extends Node

# Diagnostic screenshot harness. Saves rendered viewport PNGs so we can SEE
# the graphics/lighting/camera/character (the playthrough test only proves
# logic). Must run WINDOWED (not --headless) for a real rendered frame.
#  - shot 1: the player at spawn, default camera framing (is HE visible?)
#  - shot 2: a combat beat with enemies engaged

var _t: float = 0.0
var _phase: int = 0
var _slammed: bool = false

func _ready() -> void:
	Game.full_reset()
	Game.difficulty = 0

func _physics_process(delta: float) -> void:
	_t += delta
	var scene := get_tree().current_scene
	if scene == null or scene.name != "World":
		return
	var p := get_tree().get_first_node_in_group("player")
	match _phase:
		0:
			# Let the scene + nav bake + render settle, player untouched at spawn.
			if _t > 1.8:
				await _grab("user://bb_start.png")
				_phase = 1
				_t = 0.0
		1:
			if p != null:
				p.global_position = Vector3(0.0, 1.0, -7.0)
			if Game.wave >= 1:
				_phase = 2
				_t = 0.0
		2:
			# Pose the player and one enemy side by side for a clean size read.
			if p != null:
				p.global_position = Vector3(0.0, 1.0, -10.0)
				if "health" in p:
					p.health = p.max_health
			var enemies := get_tree().get_nodes_in_group("enemy")
			if enemies.size() > 0 and p != null and enemies[0] is Node3D:
				enemies[0].global_position = p.global_position + Vector3(2.2, 0.0, 0.0)
			# Fire a slam mid-pose so dust/debris/shockwave are in-frame, and
			# flash the damage overlay, for a real impact-moment screenshot.
			if _t > 2.2 and not _slammed and p != null and p.has_method("_apply_seismic_slam"):
				p._apply_seismic_slam()
				_slammed = true
			if _t > 2.55:
				Game.hit_flash = 0.7
				await _grab("user://bb_combat.png")
				get_tree().quit()
				_phase = 3

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("CAPTURE_SAVED ", ProjectSettings.globalize_path(path))
