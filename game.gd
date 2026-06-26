extends Node

# ============================================================
#  BLACK BREACHER — Game singleton (autoload "Game")
#  Run state (kills, score, wave, mission) + shared combat FX +
#  a small persistent save (best score / missions cleared) and
#  lightweight event logging.
# ============================================================

const DMG_NUM := preload("res://damage_number.tscn")
const SPARK := preload("res://hitspark.tscn")
const EXPLOSION := preload("res://explosion.tscn")
const SHOCKWAVE := preload("res://shockwave.tscn")
const SAVE_PATH := "user://blackbreacher_save.cfg"

# Campaign arenas in order. mission 1 → index 0, etc. Past the last one,
# the campaign is complete (→ victory screen).
const ARENA_SCENES: Array = ["res://main.tscn", "res://main2.tscn"]
const VICTORY_SCENE := "res://victory.tscn"

# run state
var kills: int = 0
var score: int = 0
var mission: int = 1
var difficulty: int = 1   # 0 easy, 1 normal, 2 hard
var wave: int = 0
var max_waves: int = 3
var wave_enemies_left: int = 0
var all_waves_done: bool = false
var detected: bool = false   # set true once any guard spots the player this mission
var combo: int = 0
var _combo_timer: float = 0.0

# persistent
var best_score: int = 0
var missions_cleared: int = 0

var _alert: AudioStreamPlayer

func _ready() -> void:
	# Hitstop scales time down; a scene reload mid-hitstop could otherwise
	# leave the whole game in slow-motion. Normalize on boot (player._ready
	# also normalizes on every scene load).
	Engine.time_scale = 1.0
	_load()
	_alert = AudioStreamPlayer.new()
	_alert.stream = load("res://alert.wav")
	_alert.volume_db = -3.0
	add_child(_alert)
	log_event("boot — best %d, missions cleared %d" % [best_score, missions_cleared])

# Flip to detected once, with an alert sting (called by guards on first spot).
func raise_detection() -> void:
	if detected:
		return
	detected = true
	if _alert:
		_alert.play()
	log_event("detected!")

func reset() -> void:
	# per-arena state only; mission/kills/score persist across mission reloads
	wave = 0
	wave_enemies_left = 0
	all_waves_done = false
	detected = false
	combo = 0
	_combo_timer = 0.0

# Called when the entry door is breached: reward a silent (ghost) approach.
func evaluate_stealth() -> void:
	if not detected:
		score += 1000
		if score > best_score:
			best_score = score
		log_event("GHOST — silent entry (+1000)")
	else:
		log_event("loud entry")

func full_reset() -> void:
	mission = 1
	kills = 0
	score = 0
	reset()

# --- Difficulty scaling (set from the title screen) ---
func _diff() -> int:
	return clampi(difficulty, 0, 2)

func hp_mult() -> float:
	return [0.7, 1.0, 1.4][_diff()]

func dmg_mult() -> float:
	return [0.6, 1.0, 1.5][_diff()]

func count_bonus() -> int:
	return [-1, 0, 1][_diff()]

func player_hp() -> int:
	return [150, 100, 80][_diff()]

func _process(delta: float) -> void:
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0

func combo_mult() -> int:
	return clampi(combo, 1, 5)

func add_kill(points: int = 100) -> void:
	kills += 1
	combo += 1
	_combo_timer = 3.0
	score += points * combo_mult()
	if score > best_score:
		best_score = score

# Scene path for the current `mission` value, or "" if the campaign is done.
func scene_for_current_mission() -> String:
	var idx: int = mission - 1
	if idx >= 0 and idx < ARENA_SCENES.size():
		return ARENA_SCENES[idx]
	return ""

func is_final_mission() -> bool:
	return mission >= ARENA_SCENES.size()

func on_mission_cleared() -> void:
	missions_cleared += 1
	if score > best_score:
		best_score = score
	log_event("mission %d cleared — score %d, best %d" % [mission, score, best_score])
	save()

func spawn_damage_number(pos: Vector3, amount: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var d := DMG_NUM.instantiate()
	scene.add_child(d)
	d.global_position = pos
	if d.has_method("set_amount"):
		d.set_amount(amount)

func spawn_hitspark(pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var s := SPARK.instantiate()
	scene.add_child(s)
	s.global_position = pos

func spawn_explosion(pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var fx := EXPLOSION.instantiate()
	scene.add_child(fx)
	fx.global_position = pos
	# A ground ring + a deep concussive bang sell the blast bigger.
	spawn_shockwave(pos + Vector3(0.0, 0.05, 0.0), Color(1.0, 0.55, 0.2), 5.0)
	spawn_sound_3d(pos, "res://flashbang.wav", -2.0)

# A flat expanding ground ring for heavy impacts (explosions, finishers,
# boss slams). Purely cosmetic. Tunable color / radius per call.
func spawn_shockwave(pos: Vector3, ring_color: Color = Color(1.0, 0.7, 0.35), ring_scale: float = 4.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var sw := SHOCKWAVE.instantiate()
	# Set the exports BEFORE add_child so _ready() reads the tuned values.
	if "color" in sw:
		sw.color = ring_color
	if "max_scale" in sw:
		sw.max_scale = ring_scale
	scene.add_child(sw)
	sw.global_position = pos

# Fire-and-forget positional one-shot. Spawns an AudioStreamPlayer3D at pos,
# plays the stream, and frees itself when finished.
func spawn_sound_3d(pos: Vector3, stream_path: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var stream := load(stream_path)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.unit_size = 8.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

func log_event(msg: String) -> void:
	print("[BB] ", msg)

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "missions_cleared", missions_cleared)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("progress", "best_score", 0))
		missions_cleared = int(cfg.get_value("progress", "missions_cleared", 0))
