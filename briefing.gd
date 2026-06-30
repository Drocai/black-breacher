extends CanvasLayer

# ============================================================
#  BLACK BREACHER — mission briefing / deploy screen
#  Shown before each mission. Reads the current mission framing
#  off the Game autoload, then loads the mission scene on input.
#  This is what turns "3 arenas" into "a campaign."
# ============================================================

var _deploying: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m: Dictionary = Game.mission_meta()
	$Center/VBox/Tag.text = "MISSION %d  /  %d" % [Game.mission, Game.mission_count()]
	$Center/VBox/Codename.text = str(m.get("codename", "OPERATION"))
	$Center/VBox/Location.text = str(m.get("location", "Marrow, GA"))
	$Center/VBox/Objective.text = "OBJECTIVE   —   " + str(m.get("objective", "Clear the area."))
	$Center/VBox/Brief.text = str(m.get("brief", ""))

func _unhandled_input(event: InputEvent) -> void:
	if _deploying:
		return
	var go: bool = event.is_action_pressed("ui_accept")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		go = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	if go:
		_deploy()

func _deploy() -> void:
	_deploying = true
	var scene: String = Game.scene_for_current_mission()
	if scene == "":
		get_tree().change_scene_to_file(Game.VICTORY_SCENE)
	else:
		get_tree().change_scene_to_file(scene)
