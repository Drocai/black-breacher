extends Control

# ============================================================
#  BLACK BREACHER — title / difficulty select
# ============================================================

func _ready() -> void:
	$VBox/Easy.pressed.connect(_start.bind(0))
	$VBox/Normal.pressed.connect(_start.bind(1))
	$VBox/Hard.pressed.connect(_start.bind(2))
	$VBox/Best.text = "Best Score: %d    Missions Cleared: %d" % [Game.best_score, Game.missions_cleared]
	$VBox/Normal.grab_focus()

func _start(d: int) -> void:
	Game.difficulty = d
	Game.full_reset()
	get_tree().change_scene_to_file("res://main.tscn")
