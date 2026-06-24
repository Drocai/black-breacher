extends Area3D

# ============================================================
#  BLACK BREACHER — objective trigger
#  Sits on the glowing box in the back alcove. When the player
#  reaches it, flips `reached` true; the HUD reads it to decide
#  MISSION COMPLETE (once the building is also cleared).
# ============================================================

var reached: bool = false

func _ready() -> void:
	add_to_group("objective")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		reached = true
