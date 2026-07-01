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
var _dmg_overlay: ColorRect   # red full-screen flash when the player is hit
var _dir_indicator: ColorRect # red wedge pointing toward the threat that hit you

func _ready() -> void:
	# Build the red damage-flash overlay at runtime so all arenas get it
	# without per-scene edits. Sits just above the vignette but below the
	# text labels, so HUD readouts stay readable through the flash.
	_dmg_overlay = ColorRect.new()
	_dmg_overlay.color = Color(0.7, 0.0, 0.0, 0.0)
	_dmg_overlay.anchor_right = 1.0
	_dmg_overlay.anchor_bottom = 1.0
	_dmg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dmg_overlay)
	move_child(_dmg_overlay, 1)

	# Directional damage indicator: a red wedge that points from screen-center
	# toward wherever the hit came from (relative to where the camera faces).
	_dir_indicator = ColorRect.new()
	_dir_indicator.color = Color(1.0, 0.45, 0.15, 0.0)   # hot orange-red, distinct from the red wash
	_dir_indicator.size = Vector2(18.0, 90.0)
	_dir_indicator.pivot_offset = _dir_indicator.size * 0.5
	_dir_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dir_indicator.visible = false
	add_child(_dir_indicator)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_help_pinned = not _help_pinned
		_help_t = 0.0

func _process(delta: float) -> void:
	if _help_t > 0.0:
		_help_t -= delta
	if controls:
		controls.visible = _help_pinned or _help_t > 0.0

	if _dmg_overlay:
		_dmg_overlay.color.a = clampf(Game.hit_flash, 0.0, 1.0) * 0.32   # a flash, not a wash

	# Point the directional damage wedge toward the threat (camera-relative).
	if _dir_indicator:
		var cam := get_tree().get_first_node_in_group("camera")
		if Game.hit_flash > 0.12 and cam is Camera3D:
			var b: Basis = (cam as Camera3D).global_transform.basis
			var fwd := Vector3(-b.z.x, 0.0, -b.z.z)
			var right := Vector3(b.x.x, 0.0, b.x.z)
			if fwd.length() > 0.01 and right.length() > 0.01:
				fwd = fwd.normalized()
				right = right.normalized()
				var ang: float = atan2(Game.hit_dir.dot(right), Game.hit_dir.dot(fwd))
				var screen: Vector2 = get_viewport().get_visible_rect().size
				var center: Vector2 = screen * 0.5
				var radius: float = minf(screen.x, screen.y) * 0.4
				_dir_indicator.position = center + Vector2(sin(ang), -cos(ang)) * radius - _dir_indicator.size * 0.5
				_dir_indicator.rotation = ang
				_dir_indicator.color.a = clampf(Game.hit_flash, 0.0, 1.0)
				_dir_indicator.visible = true
		else:
			_dir_indicator.visible = false

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

	if Game.all_waves_done and group_enemies == 0 and (reached or str(Game.mission_meta().get("goal", "reach")) == "boss"):
		status.text = "%s  —  COMPLETE   SCORE %d   BEST %d" % [_mname(), Game.score, Game.best_score]
	elif Game.all_waves_done:
		if group_enemies > 0:
			status.text = "%s  —  %s   KILLS %d" % [_mname(), str(Game.mission_meta().get("goal_label", "reach the objective")), Game.kills]
		else:
			status.text = "%s  —  %s   KILLS %d" % [_mname(), str(Game.mission_meta().get("goal_label", "reach the objective")), Game.kills]
	elif Game.wave > 0:
		status.text = "%s  —  WAVE %d/%d   ENEMIES %d   SCORE %d" % [_mname(), Game.wave, Game.max_waves, Game.wave_enemies_left, Game.score]
	else:
		var st := "UNDETECTED" if not Game.detected else "DETECTED"
		status.text = "%s  —  breach the door   [%s]" % [_mname(), st]

	if players.size() > 0 and ("sneaking" in players[0]) and players[0].sneaking:
		status.text = "[ SNEAKING ]   " + status.text
	if players.size() > 0 and ("armor" in players[0]) and players[0].armor > 0:
		status.text += "   ARMOR %d" % players[0].armor
	if players.size() > 0 and ("grenades" in players[0]):
		status.text += "   GRENADES %d" % players[0].grenades
	if Game.combo > 1:
		status.text += "   x%d COMBO" % Game.combo_mult()

	# Transient upgrade/event toast takes over the status line briefly.
	if Game.toast_active():
		status.text = ">>> %s <<<" % Game.toast_text

func _mname() -> String:
	return str(Game.mission_meta().get("codename", "MISSION %d" % Game.mission))
