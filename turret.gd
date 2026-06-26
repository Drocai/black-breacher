extends StaticBody3D

# ============================================================
#  BLACK BREACHER — turret
#  A stationary, bolted-down enemy. Never moves. Tracks the
#  player with a swivelling head and lobs projectiles when the
#  player is in range. Takes jab/kick hits like any enemy
#  (group "enemy") and topples over on death.
# ============================================================

@export var max_health: int = 5
@export var shoot_range: float = 16.0
@export var shoot_cooldown: float = 1.8
@export var projectile_scene: PackedScene

var health: int
var _down: bool = false
var _shoot_cd: float = 0.0
var _player: Node3D

@onready var head: MeshInstance3D = $Head

func _ready() -> void:
	health = max_health
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if _down:
		return
	if _shoot_cd > 0.0:
		_shoot_cd -= delta

	var p := _get_player()
	if p:
		var to_player: Vector3 = p.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		var dir := to_player.normalized()

		head.rotation.y = lerp_angle(head.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)

		if dist <= shoot_range and _shoot_cd <= 0.0:
			_shoot(dir)

func _shoot(dir: Vector3) -> void:
	_shoot_cd = shoot_cooldown
	if projectile_scene == null:
		return
	var muzzle: Vector3 = head.global_position + dir * 0.6
	var pr := projectile_scene.instantiate()
	get_tree().current_scene.add_child(pr)
	pr.global_position = muzzle
	if pr.has_method("setup"):
		pr.setup(dir)
	Game.spawn_hitspark(muzzle)

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
	Game.spawn_damage_number(global_position + Vector3(0.0, 1.4, 0.0), damage)
	Game.spawn_hitspark(head.global_position)
	if health <= 0:
		Game.add_kill()
		_die()

func stagger(_dir: Vector3) -> void:
	# Bolted down — it doesn't get knocked around, just a tiny shudder.
	if _down:
		return
	_flash()

func is_staggered() -> bool:
	return false

func _flash() -> void:
	var t := create_tween()
	t.tween_property(head, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
	t.tween_property(head, "scale", Vector3.ONE, 0.1)

func _die() -> void:
	_down = true
	remove_from_group("enemy")
	$CollisionShape3D.set_deferred("disabled", true)
	Game.spawn_hitspark(head.global_position)
	var t := create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(80.0), 0.4).set_ease(Tween.EASE_IN)
	t.tween_interval(0.8)
	t.tween_callback(queue_free)
