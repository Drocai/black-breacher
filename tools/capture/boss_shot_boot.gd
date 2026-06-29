extends Node

# Spawns the persistent boss-shot driver under the SceneTree root, then loads
# the arena (so the driver survives the scene change). Run WINDOWED.

func _ready() -> void:
	Game.full_reset()
	Game.difficulty = 0
	var driver: Node = load("res://tools/capture/boss_shot.gd").new()
	driver.name = "BossShot"
	get_tree().root.call_deferred("add_child", driver)
	call_deferred("_go")

func _go() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
