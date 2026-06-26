extends CanvasLayer

# ============================================================
#  BLACK BREACHER — pause menu (Esc). Runs while paused
#  (PROCESS_MODE_ALWAYS) so it can resume / restart.
# ============================================================

@onready var panel: Control = $Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		var p := not get_tree().paused
		get_tree().paused = p
		panel.visible = p
	elif event.physical_keycode == KEY_R and get_tree().paused:
		get_tree().paused = false
		Game.full_reset()
		get_tree().reload_current_scene()
