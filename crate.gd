extends StaticBody3D

# ============================================================
#  BLACK BREACHER — breakable crate (breaching items)
#  Takes hits from the player's strikes; bursts open and drops a
#  pickup when broken.
# ============================================================

@export var health: int = 3

const PICKUP := preload("res://pickup.tscn")

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	add_to_group("breakable")

func take_hit(damage: int) -> void:
	if health <= 0:
		return
	health -= damage
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.1, 0.88, 1.1), 0.04)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.08)
	if health <= 0:
		_break()

func _break() -> void:
	remove_from_group("breakable")
	Game.spawn_hitspark(global_position + Vector3(0.0, 0.5, 0.0))
	var p := PICKUP.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.4, 0.0)
	queue_free()
