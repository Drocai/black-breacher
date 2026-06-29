extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — medic (support enemy)
#  Keeps its distance from the player and periodically emits a
#  heal pulse that restores nearby allies. Low HP on purpose so
#  players learn to prioritise it. Takes hits / staggers / dies
#  exactly like enemy.gd.
# ============================================================

@export var max_health: int = 3
@export var move_speed: float = 2.6
@export var heal_range: float = 6.0
@export var heal_amount: int = 3
@export var heal_cooldown: float = 2.2

@export var flee_distance: float = 5.0
@export var knockback_force: float = 6.0
@export var hitstun_time: float = 0.18
@export var tint: Color = Color(1, 1, 1, 1)

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _down: bool = false
var _heal_cd: float = 0.0
var _stagger_time: float = 0.0
var _player: Node3D
var _vis := CharacterVisuals.new()

const WALK_GLB := preload("res://characters/operator_merc_walk.glb")

@export var model_yaw_offset_deg: float = 180.0

@onready var mesh: Node3D = $Mesh
@onready var hit_sound: AudioStreamPlayer3D = get_node_or_null("HitSound")

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	_heal_cd = heal_cooldown
	# Faint cool/green cast identifies the support operator at a glance.
	var t: Color = tint if tint != Color(1, 1, 1, 1) else Color(0.84, 1.08, 0.92)
	_vis.setup(mesh, WALK_GLB, model_yaw_offset_deg, t)

func _physics_process(delta: float) -> void:
	_vis.drive(velocity, move_speed, delta, _down)
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _down:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Staggered: ride out the knockback, no support behaviour.
	if _stagger_time > 0.0:
		_stagger_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 0.5)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 0.5)
		move_and_slide()
		return

	if _heal_cd > 0.0:
		_heal_cd -= delta
		if _heal_cd <= 0.0:
			_heal_pulse()
			_heal_cd = heal_cooldown

	var player := _get_player()
	if player:
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		var dir := to_player.normalized()

		if dist < flee_distance:
			# Too close — back away from the player.
			velocity.x = -dir.x * move_speed
			velocity.z = -dir.z * move_speed
			if is_on_wall():
				var perp := Vector3(-dir.z, 0.0, dir.x)
				velocity.x += perp.x * move_speed
				velocity.z += perp.z * move_speed
		else:
			# Comfortable range — idle / reposition near other enemies.
			var ally := _nearest_ally()
			if ally and global_position.distance_to(ally.global_position) > heal_range * 0.6:
				var toward: Vector3 = ally.global_position - global_position
				toward.y = 0.0
				var ad := toward.normalized()
				velocity.x = ad.x * move_speed * 0.6
				velocity.z = ad.z * move_speed * 0.6
			else:
				velocity.x = move_toward(velocity.x, 0.0, move_speed)
				velocity.z = move_toward(velocity.z, 0.0, move_speed)

		# Always keep facing the player so the flee read is clear.
		mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
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

func _nearest_ally() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not (e is Node3D):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _heal_pulse() -> void:
	if _down:
		return
	_pulse_anim(self, mesh)
	_vis.pulse(self, Color(0.15, 1.0, 0.25), 3.0, 0.05, 0.3)
	Game.spawn_hitspark(global_position + Vector3(0.0, 1.6, 0.0))
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not (e is Node3D):
			continue
		if not ("health" in e and "max_health" in e):
			continue
		if global_position.distance_to(e.global_position) > heal_range:
			continue
		e.health = min(e.health + heal_amount, e.max_health)
		# Brief green visual on the healed ally.
		if "mesh" in e and e.mesh is Node3D:
			_pulse_anim(e, e.mesh)
		Game.spawn_hitspark(e.global_position + Vector3(0.0, 1.6, 0.0))

func _pulse_anim(_owner: Node, target_mesh: Node3D) -> void:
	# Quick green scale pop to telegraph the heal.
	var t := create_tween()
	t.tween_property(target_mesh, "scale", Vector3(1.2, 1.2, 1.2), 0.06)
	t.tween_property(target_mesh, "scale", Vector3.ONE, 0.12)

func take_hit(damage: int) -> void:
	if _down:
		return
	health -= damage
	_flash()
	if hit_sound:
		hit_sound.play()
	Game.spawn_damage_number(global_position + Vector3(0.0, 1.8, 0.0), damage)
	Game.spawn_hitspark(global_position + Vector3(0.0, 1.2, 0.0))
	if health <= 0:
		Game.add_kill()
		_die()
	else:
		_knockback_anim()
		_apply_knockback()

func _apply_knockback() -> void:
	var p := _get_player()
	if p:
		var away: Vector3 = global_position - p.global_position
		away.y = 0.0
		velocity = away.normalized() * knockback_force
	_stagger_time = max(_stagger_time, hitstun_time)

func stagger(dir: Vector3) -> void:
	if _down:
		return
	_stagger_time = 0.35
	_heal_cd = max(_heal_cd, 0.6)
	velocity = dir.normalized() * 7.0
	velocity.y = 0.0

func is_staggered() -> bool:
	return _stagger_time > 0.0

func _flash() -> void:
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.1)
	_vis.pulse(self, Color(0.2, 1.0, 0.25), 3.5, 0.02, 0.16)

func _knockback_anim() -> void:
	var t := create_tween()
	t.tween_property(mesh, "rotation:x", deg_to_rad(18.0), 0.05)
	t.tween_property(mesh, "rotation:x", 0.0, 0.15)

func _die() -> void:
	_down = true
	remove_from_group("enemy")
	$CollisionShape3D.set_deferred("disabled", true)
	_vis.pause()
	var t := create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(90.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_interval(0.8)
	t.tween_callback(queue_free)
