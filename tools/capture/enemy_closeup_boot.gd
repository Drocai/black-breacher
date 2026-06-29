extends Node

# Spawns the persistent enemy-closeup driver under the SceneTree root, then
# loads the real arena. Run WINDOWED.

func _ready() -> void:
	Game.full_reset()
	Game.difficulty = 0
	var driver: Node = load("res://tools/capture/enemy_closeup.gd").new()
	driver.name = "EnemyCloseup"
	get_tree().root.call_deferred("add_child", driver)
	call_deferred("_go")

func _go() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
