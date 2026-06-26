extends Area3D

# ============================================================
#  BLACK BREACHER — grenade pickup
#  Dropped in the field. Spins, and tops up the player's grenade
#  count on touch.
# ============================================================

@export var grenade_amount: int = 2

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	mesh.rotate_y(delta * 2.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("add_grenades"):
		body.add_grenades(grenade_amount)
		queue_free()
