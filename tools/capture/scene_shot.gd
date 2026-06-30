extends Node

# Boot for the generic scene screenshot harness. Spawns a persistent driver
# under the SceneTree root (survives the scene change), which loads + captures
# the target scene named in tools/capture/_shot.cfg. Run WINDOWED.

func _ready() -> void:
	var d: Node = load("res://tools/capture/scene_shot_driver.gd").new()
	d.name = "ShotDriver"
	get_tree().root.call_deferred("add_child", d)
