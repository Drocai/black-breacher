extends Node3D

# ============================================================
#  BLACK BREACHER — breachable door (Stage E + F: the demo loop)
#  Walk into the BreachZone -> press F -> the Breacher strikes ->
#  the panel swings open, a sound + dust burst fire, doorway clears.
# ============================================================

@export var open_angle_deg: float = 110.0
@export var open_time: float = 0.5
@export var is_entry: bool = false   # the entry door scores the silent/ghost bonus

var breached: bool = false

@onready var hinge: Node3D = $Hinge
@onready var zone: Area3D = $BreachZone

func _ready() -> void:
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.breach_target = self

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.breach_target == self:
		body.breach_target = null

func breach() -> void:
	if breached:
		return
	breached = true

	if is_entry:
		Game.evaluate_stealth()

	# Clear the doorway so he can walk through
	var col := get_node_or_null("Hinge/Panel/Collision")
	if col:
		col.set_deferred("disabled", true)

	# Juice: sound + dust burst
	var sfx := get_node_or_null("Breach") as AudioStreamPlayer3D
	if sfx:
		sfx.play()
	var dust := get_node_or_null("Dust") as GPUParticles3D
	if dust:
		dust.restart()
		dust.emitting = true

	# Swing it open with a little overshoot for impact
	var t := create_tween()
	t.tween_property(hinge, "rotation:y", deg_to_rad(open_angle_deg), open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
