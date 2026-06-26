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
@onready var controls: Label = get_node_or_null("Controls")
@onready var vignette: ColorRect = get_node_or_null("Vignette")

var _help_t: float = 7.0   # auto-show the controls for a few seconds at start
var _help_pinned: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_help_pinned = not _help_pinned
		_help_t = 0.0

func _process(delta: float) -> void:
	if _help_t > 0.0:
		_help_t -= delta
	if controls:
		controls.visible = _help_pinned or _help_t > 0.0

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p: Node = players[0]
		health_bar.value = p.health
		if vignette and vignette.material:
			var frac := float(p.health) / float(p.max_health)
			vignette.material.set_shader_parameter("intensity", clampf((0.5 - frac) / 0.5, 0.0, 1.0))
		var target = p.breach_target
		prompt.visible = target != null and is_instance_valid(target) and not target.breached
	else:
		prompt.visible = false

	var group_enemies := get_tree().get_nodes_in_group("enemy").size()
	var obj := get_tree().get_first_node_in_group("objective")
	var reached: bool = obj != null and obj.reached

	if reached and Game.all_waves_done and group_enemies == 0:
		status.text = "MISSION %d COMPLETE   SCORE %d   BEST %d" % [Game.mission, Game.score, Game.best_score]
	elif Game.all_waves_done:
		if group_enemies > 0:
			status.text = "MISSION %d   defeat the boss   KILLS %d" % [Game.mission, Game.kills]
		else:
			status.text = "MISSION %d   reach the objective   KILLS %d" % [Game.mission, Game.kills]
	elif Game.wave > 0:
		status.text = "MISSION %d   WAVE %d/%d   ENEMIES %d   SCORE %d" % [Game.mission, Game.wave, Game.max_waves, Game.wave_enemies_left, Game.score]
	else:
		var st := "UNDETECTED" if not Game.detected else "DETECTED"
		status.text = "MISSION %d   breach the door   [%s]" % [Game.mission, st]

	if players.size() > 0 and ("sneaking" in players[0]) and players[0].sneaking:
		status.text = "[ SNEAKING ]   " + status.text
	if players.size() > 0 and ("armor" in players[0]) and players[0].armor > 0:
		status.text += "   ARMOR %d" % players[0].armor
	if players.size() > 0 and ("grenades" in players[0]):
		status.text += "   GRENADES %d" % players[0].grenades
	if Game.combo > 1:
		status.text += "   x%d COMBO" % Game.combo_mult()
