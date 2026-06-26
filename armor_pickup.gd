extends Area3D

# ============================================================
#  BLACK BREACHER — armor pickup
#  Dropped by enemies on death. Spins, and armors the player on touch.
# ============================================================

@export var armor_amount: int = 30

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	mesh.rotate_y(delta * 2.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("add_armor"):
		body.add_armor(armor_amount)
		queue_free()
