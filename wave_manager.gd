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

@export var max_waves: int = 3

var _wave: int = 0
var _started: bool = false
var _spawning: bool = false
var _alive: Array = []
var _points: Array = []

func _ready() -> void:
	Game.reset()
	Game.max_waves = max_waves
	for c in get_children():
		if c is Marker3D:
			_points.append(c.global_position)
	if _points.is_empty():
		_points.append(global_position)

func _process(_delta: float) -> void:
	_alive = _alive.filter(func(e): return is_instance_valid(e))
	Game.wave_enemies_left = _alive.size()

	if not _started:
		var p := _player()
		if p and p.global_position.z < -4.0:
			_started = true
			_next_wave()
		return

	if _spawning:
		return

	if _alive.is_empty():
		if _wave < max_waves:
			_next_wave()
		elif not Game.all_waves_done:
			Game.all_waves_done = true

func _next_wave() -> void:
	_wave += 1
	Game.wave = _wave
	_spawning = true
	var count := 2 + _wave
	for i in count:
		var pt: Vector3 = _points[i % _points.size()]
		var ranged := _wave >= 2 and i % 3 == 0
		var e: Node3D = (RANGED if ranged else MELEE).instantiate()
		get_tree().current_scene.add_child(e)
		e.global_position = pt + Vector3(0.0, 0.1, 0.0)
		_alive.append(e)
	await get_tree().create_timer(0.3).timeout
	_spawning = false

func _player() -> Node3D:
	var a := get_tree().get_nodes_in_group("player")
	return a[0] if a.size() > 0 else null
