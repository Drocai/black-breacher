extends Node3D

# ============================================================
#  BLACK BREACHER — wave manager
#  Once the player enters the arena (breaches the front door),
#  spawns escalating waves of enemies at its Marker3D children.
#  Each wave clears before the next spawns; after the final wave
#  it sets Game.all_waves_done so the boss/objective finale opens.
# ============================================================

const MELEE := preload("res://enemy.tscn")
const RANGED := preload("res://enemy_ranged.tscn")
const BOMBER := preload("res://bomber.tscn")
const TURRET := preload("res://turret.tscn")
const BRUTE := preload("res://brute.tscn")
const MEDIC := preload("res://medic.tscn")
const SNIPER := preload("res://sniper.tscn")
const UPGRADE := preload("res://upgrade_pickup.tscn")
const UP_KINDS: Array = ["VITALITY", "PLATING", "ORDNANCE", "ADRENALINE"]

@export var max_waves: int = 3
@export var intermission_time: float = 4.0   # resupply window between waves
# Per-arena flavor. "" = the standard balanced roster. "bruiser" skews toward
# brutes/heavies (close-quarters maul). "ranged" skews toward ranged/snipers/
# turrets (open sightlines). Set on the WaveManager node in each arena scene.
@export var enemy_bias: String = ""

var _wave: int = 0
var _started: bool = false
var _spawning: bool = false
var _intermission: bool = false
var _alive: Array = []
var _points: Array = []
var _center: Vector3 = Vector3.ZERO

func _ready() -> void:
	Game.reset()
	Game.max_waves = max_waves
	for c in get_children():
		if c is Marker3D:
			_points.append(c.global_position)
	if _points.is_empty():
		_points.append(global_position)
	# Arena centroid — where the resupply upgrade drops between waves.
	for pt in _points:
		_center += pt
	_center /= float(_points.size())

func _process(_delta: float) -> void:
	_alive = _alive.filter(func(e): return is_instance_valid(e))
	Game.wave_enemies_left = _alive.size()

	if not _started:
		var p := _player()
		if p and p.global_position.z < -4.0:
			_started = true
			_next_wave()
		return

	if _spawning or _intermission:
		return

	if _alive.is_empty():
		if _wave < max_waves:
			_run_intermission()
		elif not Game.all_waves_done:
			Game.all_waves_done = true

# A short resupply window between waves: drop one upgrade for the player to
# grab, then start the next wave.
func _run_intermission() -> void:
	_intermission = true
	_spawn_upgrade()
	await get_tree().create_timer(intermission_time).timeout
	_intermission = false
	_next_wave()

func _spawn_upgrade() -> void:
	var u := UPGRADE.instantiate()
	u.kind = UP_KINDS[_wave % UP_KINDS.size()]
	get_tree().current_scene.add_child(u)
	u.global_position = _center + Vector3(0.0, 0.8, 0.0)
	Game.log_event("resupply drop: " + str(u.kind))

func _next_wave() -> void:
	_wave += 1
	Game.wave = _wave
	_spawning = true
	var count := maxi(1, 2 + _wave + (Game.mission - 1) + Game.count_bonus())
	for i in count:
		var pt: Vector3 = _points[i % _points.size()]
		var kind := "melee"
		if _wave >= 3 and i % 5 == 0:
			kind = "turret"
		elif _wave >= 3 and i % 6 == 3:
			kind = "sniper"
		elif _wave >= 2 and i % 7 == 0:
			kind = "medic"
		elif _wave >= 2 and i % 4 == 0:
			kind = "bomber"
		elif _wave >= 2 and i % 3 == 0:
			kind = "ranged"
		elif _wave >= 2 and i % 5 == 2:
			kind = "brute"
		elif i % 4 == 0:
			kind = "heavy"
		elif i % 2 == 1:
			kind = "fast"
		kind = _apply_bias(kind, i)
		_spawn_enemy(kind, pt)
	await get_tree().create_timer(0.3).timeout
	_spawning = false

## Re-flavor a portion of each wave toward the arena's threat archetype, while
## leaving the rest of the roster intact so fights stay varied.
func _apply_bias(kind: String, i: int) -> String:
	if enemy_bias == "bruiser" and i % 2 == 0:
		return "brute" if (_wave >= 2 and i % 4 == 0) else "heavy"
	if enemy_bias == "ranged" and i % 2 == 0:
		if _wave >= 3 and i % 6 == 0:
			return "sniper"
		if _wave >= 3 and i % 5 == 0:
			return "turret"
		return "ranged"
	return kind

func _spawn_enemy(kind: String, pos: Vector3) -> void:
	var hp_scale := 1.0 + 0.3 * float(Game.mission - 1)
	var e: Node3D
	match kind:
		"ranged":
			e = RANGED.instantiate()
			e.max_health = int(round(3 * hp_scale))
			e.scale = Vector3.ONE * 0.9
		"bomber":
			e = BOMBER.instantiate()
		"turret":
			e = TURRET.instantiate()
		"sniper":
			e = SNIPER.instantiate()
		"medic":
			e = MEDIC.instantiate()
		"brute":
			e = BRUTE.instantiate()
		"heavy":
			e = MELEE.instantiate()
			e.max_health = int(round(8 * hp_scale))
			e.move_speed = 1.3
			e.attack_damage = 14
			e.knockback_force = 1.5
			e.scale = Vector3.ONE * 1.3
			e.tint = Color(0.55, 0.6, 0.8)
		"fast":
			e = MELEE.instantiate()
			e.max_health = 2
			e.move_speed = 4.5
			e.attack_damage = 5
			e.scale = Vector3.ONE * 0.85
			e.tint = Color(1.4, 1.1, 0.5)
		_:
			e = MELEE.instantiate()
			e.max_health = int(round(4 * hp_scale))
			e.scale = Vector3.ONE * 0.9
	# Difficulty scaling
	e.max_health = maxi(1, int(round(float(e.max_health) * Game.hp_mult())))
	if "attack_damage" in e:
		e.attack_damage = int(round(float(e.attack_damage) * Game.dmg_mult()))
	get_tree().current_scene.add_child(e)
	e.global_position = pos + Vector3(0.0, 0.1, 0.0)
	_alive.append(e)

func _player() -> Node3D:
	var a := get_tree().get_nodes_in_group("player")
	return a[0] if a.size() > 0 else null
