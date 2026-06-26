extends Area3D

# ============================================================
#  BLACK BREACHER — upgrade pickup
#  A floating, glowing power-up dropped between waves. Walk into
#  it to gain a permanent run upgrade. Four kinds, chosen via the
#  exported `kind`. On touch it calls apply_upgrade(kind) on the
#  player, plays feedback, and frees itself.
# ============================================================

@export var kind: String = "VITALITY"

@onready var mesh: MeshInstance3D = $Mesh
@onready var label: Label3D = $Label3D

var _taken: bool = false
var _t: float = 0.0
var _base_y: float = 0.8

func _ready() -> void:
	add_to_group("upgrade")
	body_entered.connect(_on_body_entered)

	# Keep the mesh's authored Y as the bob anchor.
	_base_y = mesh.position.y

	# Label shows the upgrade name.
	label.text = kind

	# Retint a *duplicated* material so instances do not share state.
	var c: Color = _accent_color()
	var m: StandardMaterial3D = mesh.material_override.duplicate()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	mesh.material_override = m

	# Tint the label to match its kind.
	label.modulate = c

func _process(delta: float) -> void:
	_t += delta
	# Gentle bob around the base Y plus a slow spin.
	mesh.position.y = _base_y + sin(_t * 2.0) * 0.12
	mesh.rotation.y += delta

func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	if body.is_in_group("player") and body.has_method("apply_upgrade"):
		_taken = true
		body.apply_upgrade(kind)
		if Game.has_method("spawn_hitspark"):
			Game.spawn_hitspark(global_position + Vector3(0, 1, 0))
		if Game.has_method("spawn_shockwave"):
			Game.spawn_shockwave(global_position, _accent_color(), 2.0)
		if Game.has_method("log_event"):
			Game.log_event("upgrade taken: " + kind)
		queue_free()

func _accent_color() -> Color:
	match kind:
		"VITALITY":
			return Color(0.2, 1.0, 0.3)
		"PLATING":
			return Color(0.6, 0.8, 1.0)
		"ORDNANCE":
			return Color(1.0, 0.5, 0.1)
		"ADRENALINE":
			return Color(1.0, 0.9, 0.2)
		_:
			return Color(0.2, 1.0, 0.3)
