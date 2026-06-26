extends StaticBody3D

# ============================================================
#  BLACK BREACHER — explosive barrel (breakable hazard)
#  Takes hits from the player's strikes; when broken it detonates,
#  damaging and staggering every enemy within the blast radius.
# ============================================================

@export var health: int = 2
@export var blast_radius: float = 3.5
@export var blast_damage: int = 8

@onready var mesh: MeshInstance3D = $Mesh

var _detonated: bool = false

func _ready() -> void:
	add_to_group("breakable")

func take_hit(damage: int) -> void:
	if health <= 0:
		return
	health -= damage
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.1, 0.88, 1.1), 0.04)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.08)
	Game.spawn_hitspark(global_position + Vector3(0.0, 0.6, 0.0))
	if health <= 0:
		_explode()

func _explode() -> void:
	if _detonated:
		return
	_detonated = true
	remove_from_group("breakable")
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node3D):
			continue
		var offset: Vector3 = enemy.global_position - global_position
		if offset.length() > blast_radius:
			continue
		if enemy.has_method("take_hit"):
			enemy.take_hit(blast_damage)
		if enemy.has_method("stagger"):
			var dir: Vector3 = offset
			dir.y = 0.0
			enemy.stagger(dir.normalized())
	Game.spawn_hitspark(global_position + Vector3(0.0, 0.6, 0.0))
	Game.spawn_explosion(global_position + Vector3(0.0, 0.6, 0.0))
	queue_free()
