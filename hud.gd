extends CanvasLayer

# ============================================================
#  BLACK BREACHER — HUD (pull-based)
#   - health bar + breach prompt
#   - wave / enemy / kill readout driven by the Game singleton
#   - boss + objective finale, then MISSION COMPLETE
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

	var group_enemies := get_tree().get_nodes_in_group("enemy").size()
	var obj := get_tree().get_first_node_in_group("objective")
	var reached: bool = obj != null and obj.reached

	if reached and Game.all_waves_done and group_enemies == 0:
		status.text = "MISSION %d COMPLETE   SCORE %d   (next...)" % [Game.mission, Game.score]
	elif Game.all_waves_done:
		if group_enemies > 0:
			status.text = "MISSION %d   defeat the boss   KILLS %d" % [Game.mission, Game.kills]
		else:
			status.text = "MISSION %d   reach the objective   KILLS %d" % [Game.mission, Game.kills]
	elif Game.wave > 0:
		status.text = "MISSION %d   WAVE %d/%d   ENEMIES %d   SCORE %d" % [Game.mission, Game.wave, Game.max_waves, Game.wave_enemies_left, Game.score]
	else:
		status.text = "MISSION %d   breach the door" % Game.mission
