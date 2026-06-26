extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — bomber enemy
#  Rushes the nearest player, holds at close range while a short
#  fuse telegraphs (pulsing scale), then detonates an AoE blast.
#  Dying from a hit also triggers the blast. Takes jab/kick hits
#  like the other enemies (group "enemy") and can be staggered.
# ============================================================

@export var max_health: int = 2
@export var move_speed: float = 3.6
@export var explode_range: float = 1.6
@export var blast_radius: float = 3.0
@export var blast_damage: int = 25

@export var fuse_time: float = 0.6

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _exploded: bool = false
var _fuse: float = 0.0
var _fusing: bool = false
var _stagger_time: float = 0.0
var _player: Node3D

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	health = max_health
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if _exploded:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Staggered: ride out the knockback, no chase/fuse.
	if _stagger_time > 0.0:
		_stagger_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 0.5)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 0.5)
		move_and_slide()
		return

	# Fuse lit — hold position and pulse the mesh to telegraph the blast.
	if _fusing:
		_fuse -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		var pulse := 1.0 + sin(_fuse * 40.0) * 0.18
		mesh.scale = Vector3(pulse, pulse, pulse)
		if _fuse <= 0.0:
			_explode()
			return
		move_and_slide()
		return

	var p := _get_player()
	if p:
		var to_player: Vector3 = p.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		var dir := to_player.normalized()

		if dist > explode_range:
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			# Snagged on a wall/crate last frame? veer sideways to slip around it.
			if is_on_wall():
				var perp := Vector3(-dir.z, 0.0, dir.x)
				velocity.x += perp.x * move_speed
				velocity.z += perp.z * move_speed
			mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			_begin_fuse()
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

func _get_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var arr := get_tree().get_nodes_in_group("player")
	_player = arr[0] if arr.size() > 0 else null
	return _player

func _begin_fuse() -> void:
	if _fusing or _exploded:
		return
	_fusing = true
	_fuse = fuse_time

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_fusing = false

	var p := _get_player()
	if p and p.has_method("take_damage"):
		if global_position.distance_to(p.global_position) <= blast_radius:
			p.take_damage(blast_damage)

	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not (e is Node3D) or not e.has_method("take_hit"):
			continue
		if global_position.distance_to(e.global_position) < blast_radius:
			e.take_hit(6)
			if e.has_method("stagger"):
				var d: Vector3 = e.global_position - global_position
				e.stagger(Vector3(d.x, 0.0, d.z).normalized())

	Game.spawn_hitspark(global_position + Vector3(0.0, 0.6, 0.0))
	queue_free()

func take_hit(damage: int) -> void:
	if _exploded:
		return
	health -= damage
	_flash()
	Game.spawn_damage_number(global_position + Vector3(0.0, 1.8, 0.0), damage)
	Game.spawn_hitspark(global_position + Vector3(0.0, 1.2, 0.0))
	if health <= 0:
		Game.add_kill()
		_explode()

func stagger(dir: Vector3) -> void:
	if _exploded:
		return
	_stagger_time = 0.3
	velocity = dir.normalized() * 6.0
	velocity.y = 0.0

func is_staggered() -> bool:
	return _stagger_time > 0.0

func _flash() -> void:
	if _exploded:
		return
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.2, 0.8, 1.2), 0.05)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.1)
