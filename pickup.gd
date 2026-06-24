extends Area3D

# ============================================================
#  BLACK BREACHER — health pickup
#  Dropped by enemies on death. Spins, and heals the player on touch.
# ============================================================

@export var heal_amount: int = 25

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	mesh.rotate_y(delta * 2.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("heal"):
		body.heal(heal_amount)
		queue_free()
