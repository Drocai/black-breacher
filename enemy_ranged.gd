extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — ranged enemy
#  Keeps its distance and lobs projectiles at the player. Takes
#  jab/kick hits like a melee enemy (group "enemy"), can be
#  staggered, and topples on death.
# ============================================================

@export var max_health: int = 3
@export var move_speed: float = 2.0
@export var preferred_dist: float = 7.0
@export var shoot_range: float = 15.0
@export var shoot_cooldown: float = 2.0
@export var projectile_scene: PackedScene

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _down: bool = false
var _shoot_cd: float = 0.0
var _player: Node3D

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	health = max_health
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _down:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _shoot_cd > 0.0:
		_shoot_cd -= delta

	var p := _get_player()
	if p:
		var to_player: Vector3 = p.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		var dir := to_player.normalized()

		if dist < preferred_dist - 1.0:
			velocity.x = -dir.x * move_speed
			velocity.z = -dir.z * move_speed
		elif dist > preferred_dist + 1.0 and dist < shoot_range:
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)

		mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)

		if dist <= shoot_range and _shoot_cd <= 0.0:
			_shoot(dir)

	move_and_slide()

func _shoot(dir: Vector3) -> void:
	_shoot_cd = shoot_cooldown
	if projectile_scene == null:
		return
	var pr := projectile_scene.instantiate()
	get_tree().current_scene.add_child(pr)
	pr.global_position = global_position + Vector3(0.0, 1.2, 0.0) + dir * 0.8
	if pr.has_method("setup"):
		pr.setup(dir)

func _get_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var a := get_tree().get_nodes_in_group("player")
	_player = a[0] if a.size() > 0 else null
	return _player

func take_hit(damage: int) -> void:
	if _down:
		return
	health -= damage
	_flash()
	if health <= 0:
		_die()

func stagger(dir: Vector3) -> void:
	if _down:
		return
	velocity = dir.normalized() * 6.0
	velocity.y = 0.0

func _flash() -> void:
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.1)

func _die() -> void:
	_down = true
	remove_from_group("enemy")
	$CollisionShape3D.set_deferred("disabled", true)
	var t := create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(90.0), 0.4).set_ease(Tween.EASE_IN)
	t.tween_interval(0.8)
	t.tween_callback(queue_free)
