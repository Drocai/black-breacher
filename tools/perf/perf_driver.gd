extends Node

# Production performance probe. Loads the REAL main.tscn WINDOWED (real GPU
# render), drives a worst-case effects-heavy combat moment — accumulating
# enemies + a continuous storm of explosions (each = explosion FX + dust +
# debris + shockwave + sound) — and samples true rendered FPS (vsync off,
# uncapped) so we get a measured stability baseline, not a guess.

var _t: float = 0.0
var _fx_t: float = 0.0
var _samples: Array = []

func _ready() -> void:
	Game.full_reset()
	Game.difficulty = 2   # hard = the most enemies
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _physics_process(delta: float) -> void:
	_t += delta
	var scene := get_tree().current_scene
	if scene == null or scene.name != "World":
		return
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.global_position = Vector3(0.0, 1.0, -12.0)   # in the arena, waves spawn + close in
		if "health" in p:
			p.health = p.max_health

	# Worst-case FX storm: spawn heavy impacts around the player continuously.
	_fx_t += delta
	if _fx_t > 0.2:
		_fx_t = 0.0
		var off := Vector3(randf_range(-3.0, 3.0), 0.1, randf_range(-3.0, 3.0))
		Game.spawn_explosion(p.global_position + off if p != null else off)

	# Sample after a 3s warm-up (let waves spawn + FX ramp), report at 14s.
	if _t > 3.0:
		_samples.append(Engine.get_frames_per_second())
	if _t > 14.0:
		var sum := 0.0
		var mn := 1000000.0
		for f in _samples:
			sum += f
			if f < mn:
				mn = f
		var avg: float = sum / float(maxi(_samples.size(), 1))
		print("PERF_RESULT avg_fps=%.1f min_fps=%.1f samples=%d enemies=%d" % [
			avg, mn, _samples.size(), get_tree().get_nodes_in_group("enemy").size()])
		get_tree().quit()
