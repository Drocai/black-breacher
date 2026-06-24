extends CanvasLayer

# ============================================================
#  BLACK BREACHER — HUD (pull-based, no coupling)
#  Reads the player + enemy groups each frame and updates:
#   - health bar
#   - "Press F to Breach" prompt when a door is in range
#   - enemy count / AREA CLEAR
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

	var n := get_tree().get_nodes_in_group("enemy").size()
	status.text = "ENEMIES: %d" % n if n > 0 else "AREA CLEAR"
