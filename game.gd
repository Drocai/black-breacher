extends Node

# ============================================================
#  BLACK BREACHER — Game singleton (autoload "Game")
#  Holds run state (kills, score, wave) and spawns shared combat
#  FX (floating damage numbers, hit sparks).
# ============================================================

const DMG_NUM := preload("res://damage_number.tscn")
const SPARK := preload("res://hitspark.tscn")

var kills: int = 0
var score: int = 0
var wave: int = 0
var max_waves: int = 3
var wave_enemies_left: int = 0
var all_waves_done: bool = false

func reset() -> void:
	kills = 0
	score = 0
	wave = 0
	wave_enemies_left = 0
	all_waves_done = false

func add_kill(points: int = 100) -> void:
	kills += 1
	score += points

func spawn_damage_number(pos: Vector3, amount: int) -> void:
	var d := DMG_NUM.instantiate()
	get_tree().current_scene.add_child(d)
	d.global_position = pos
	if d.has_method("set_amount"):
		d.set_amount(amount)

func spawn_hitspark(pos: Vector3) -> void:
	var s := SPARK.instantiate()
	get_tree().current_scene.add_child(s)
	s.global_position = pos
