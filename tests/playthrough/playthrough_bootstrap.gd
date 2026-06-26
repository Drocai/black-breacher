extends Node

# Bootstrap for the automated playthrough regression test. Spawns the
# persistent TestDriver under the SceneTree root (so it survives the scene
# change), then loads the real main.tscn as the current scene. The driver
# pilots it through the full mission loop and asserts every link, then quits.

func _ready() -> void:
	var driver: Node = load("res://tests/playthrough/playthrough_driver.gd").new()
	driver.name = "TestDriver"
	get_tree().root.call_deferred("add_child", driver)
	call_deferred("_go")

func _go() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
