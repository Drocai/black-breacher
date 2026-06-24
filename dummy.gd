extends StaticBody3D

# ============================================================
#  BLACK BREACHER — training dummy (a target for the jab)
#  Takes hits, recoils, and topples over when its health runs out.
# ============================================================

@export var max_health: int = 3

var health: int

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	health = max_health
	add_to_group("enemy")

func take_hit(damage: int) -> void:
	if health <= 0:
		return
	health -= damage
	_flash()
	if health <= 0:
		_die()
	else:
		_recoil()

func _flash() -> void:
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.15, 0.9, 1.15), 0.05)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.1)

func _recoil() -> void:
	var t := create_tween()
	t.tween_property(mesh, "rotation:x", deg_to_rad(15.0), 0.05)
	t.tween_property(mesh, "rotation:x", 0.0, 0.15)

func _die() -> void:
	remove_from_group("enemy")
	$CollisionShape3D.set_deferred("disabled", true)
	var t := create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(90.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_interval(0.6)
	t.tween_callback(queue_free)
