extends Node

# Spawns a persistent CaptureDriver under the SceneTree root (so it survives
# the scene change), then loads the real main.tscn. Run WINDOWED.

func _ready() -> void:
	var driver: Node = load("res://tools/capture/capture_driver.gd").new()
	driver.name = "CaptureDriver"
	get_tree().root.call_deferred("add_child", driver)
	call_deferred("_go")

func _go() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
