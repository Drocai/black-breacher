extends CanvasLayer

# ============================================================
#  BLACK BREACHER — HUD (pull-based, no coupling)
#   - health bar
#   - "Press F to Breach" prompt when a door is in range
#   - progressive objective line: clear the building -> reach
#     the objective -> MISSION COMPLETE
# ============================================================

@onready var health_bar: ProgressBar = $Health
@onready var prompt: Label = $BreachPrompt
@onready var status: Label = $Status

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p: Node = players[0]
		health_bar.value = p.health
		var target = p.breach_target
		prompt.visible = target != null and is_instance_valid(target) and not target.breached
	else:
		prompt.visible = false

	var enemies := get_tree().get_nodes_in_group("enemy").size()
	var obj := get_tree().get_first_node_in_group("objective")
	var reached: bool = obj != null and obj.reached

	if reached and enemies == 0:
		status.text = "MISSION COMPLETE   (R to restart)"
	elif enemies == 0:
		status.text = "AREA CLEAR  —  reach the objective"
	else:
		status.text = "ENEMIES: %d" % enemies
