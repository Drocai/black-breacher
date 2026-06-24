extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — reactive enemy
#  Chases the player, attacks at close range (deals damage on a
#  cooldown), takes jab hits, recoils, and topples on death.
# ============================================================

@export var max_health: int = 4
@export var move_speed: float = 2.4
@export var detect_range: float = 16.0
@export var stop_distance: float = 1.5
@export var attack_range: float = 1.9
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.3

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _down: bool = false
var _atk_cd: float = 0.0

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

	if _atk_cd > 0.0:
		_atk_cd -= delta

	var player := _get_player()
	if player:
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		var dir := to_player.normalized()

		if dist > stop_distance:
			# Chase
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
		else:
			# In range — hold and attack
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			if dist <= attack_range and _atk_cd <= 0.0:
				_attack(player)

		if dist <= detect_range:
			mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

func _get_player() -> Node3D:
	var arr := get_tree().get_nodes_in_group("player")
	return arr[0] if arr.size() > 0 else null

func _attack(player: Node) -> void:
	_atk_cd = attack_cooldown
	# quick lunge for readability
	var t := create_tween()
	t.tween_property(mesh, "position:z", -0.35, 0.08)
	t.tween_property(mesh, "position:z", 0.0, 0.14)
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

func take_hit(damage: int) -> void:
	if _down:
		return
	health -= damage
	_flash()
	if health <= 0:
		_die()
	else:
		_knockback()

func _flash() -> void:
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.1)

func _knockback() -> void:
	var t := create_tween()
	t.tween_property(mesh, "rotation:x", deg_to_rad(18.0), 0.05)
	t.tween_property(mesh, "rotation:x", 0.0, 0.15)

func _die() -> void:
	_down = true
	remove_from_group("enemy")
	$CollisionShape3D.set_deferred("disabled", true)
	var t := create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(90.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_interval(0.8)
	t.tween_callback(queue_free)
