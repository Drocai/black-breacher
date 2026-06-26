extends Node

# Spawns a persistent PerfDriver under the SceneTree root (survives the scene
# change), then loads main.tscn. Run WINDOWED for real rendered FPS.

func _ready() -> void:
	var d: Node = load("res://tools/perf/perf_driver.gd").new()
	d.name = "PerfDriver"
	get_tree().root.call_deferred("add_child", d)
	call_deferred("_go")

func _go() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
