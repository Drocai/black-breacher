extends Area3D

# ============================================================
#  BLACK BREACHER — objective trigger
#  Sits on the glowing box in the back alcove. When the player
#  reaches it, flips `reached` true; the HUD reads it to decide
#  MISSION COMPLETE (once the building is also cleared).
# ============================================================

var reached: bool = false
var _completing: bool = false

func _ready() -> void:
	add_to_group("objective")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		reached = true

func _process(_delta: float) -> void:
	if _completing:
		return
	# Building cleared = all waves done and nothing left alive (boss included).
	var cleared: bool = Game.all_waves_done and get_tree().get_nodes_in_group("enemy").size() == 0
	# "boss" missions end on that clear (killing the Warden IS the objective);
	# "reach" missions also need the player to reach the objective marker.
	var goal: String = str(Game.mission_meta().get("goal", "reach"))
	if cleared and (goal == "boss" or reached):
		_completing = true
		_advance()

func _advance() -> void:
	Game.score += 500  # mission clear bonus
	Game.on_mission_cleared()
	await get_tree().create_timer(2.5).timeout
	Game.mission += 1
	# Brief the next mission (or roll credits once the campaign is done).
	var next: String = Game.scene_for_current_mission()
	if next == "":
		get_tree().change_scene_to_file(Game.VICTORY_SCENE)
	else:
		get_tree().change_scene_to_file("res://briefing.tscn")
