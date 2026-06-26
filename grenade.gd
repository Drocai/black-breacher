extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — throwable grenade
#  Launched by the player with launch(). Arcs under gravity using
#  move_and_slide, then detonates on a fuse timer or on contact with
#  the floor/wall after a brief minimum airborne time. The blast
#  damages and staggers every enemy within range.
# ============================================================

@export var fuse_time: float = 1.2
@export var blast_radius: float = 3.5
@export var blast_damage: int = 14
@export var min_airborne: float = 0.18
@export var up_boost: float = 4.5

@onready var light: OmniLight3D = $Light

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _fuse: float = 0.0
var _airborne: float = 0.0
var _launched: bool = false
var _exploded: bool = false
var _blink: float = 0.0

func launch(dir: Vector3, force: float) -> void:
	var flat: Vector3 = dir.normalized()
	velocity = flat * force + Vector3(0.0, up_boost, 0.0)
	_launched = true
	_fuse = 0.0
	_airborne = 0.0

func _physics_process(delta: float) -> void:
	if _exploded:
		return

	velocity.y -= _gravity * delta
	move_and_slide()

	# Blink the indicator light.
	_blink += delta
	if light != null:
		light.visible = fmod(_blink, 0.18) < 0.09

	if not _launched:
		return

	_airborne += delta
	_fuse += delta

	if _fuse >= fuse_time:
		_explode()
		return

	# Detonate on surface contact once it has been airborne briefly.
	if _airborne >= min_airborne and get_slide_collision_count() > 0:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true

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

	Game.spawn_explosion(global_position)
	Game.spawn_hitspark(global_position)
	queue_free()
