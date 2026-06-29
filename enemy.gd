extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — reactive enemy (KayKit rigged humanoid)
#  Chases the player, attacks at close range on a cooldown, takes
#  hits, can be staggered/knocked back, and dies. Visuals are a real
#  skinned character (a KayKit GLB) driven by its AnimationPlayer;
#  the same AI/physics/awareness/stagger/grab logic as before.
# ============================================================

@export var max_health: int = 4
@export var move_speed: float = 2.4
@export var detect_range: float = 16.0
@export var stop_distance: float = 1.5
@export var attack_range: float = 1.9
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.3

@export var pickup_drop_chance: float = 0.5
@export var knockback_force: float = 6.0
@export var hitstun_time: float = 0.18
@export var throw_impact_damage: int = 6

# Stealth / awareness ("the Black"). Wave enemies start alerted; placed
# guards start unaware (idle, scanning a cone) and can be stealth-killed.
@export var start_alerted: bool = true
@export var initial_facing_deg: float = 0.0
@export var view_distance: float = 9.0
@export var view_dot: float = 0.4
@export var detect_time: float = 0.8
@export var tint: Color = Color(1, 1, 1, 1)   # kept for API compat (model is textured)
@export var patrol_distance: float = 0.0   # >0 = an unaware guard paces this far and back
@export var model_yaw_offset: float = 0.0   # rotate the model if its rig faces the wrong way

# Animation clip names (KayKit shared rig).
const ANIM_IDLE := "Idle"
const ANIM_RUN := "Running_A"
const ANIM_WALK := "Walking_A"
const ANIM_ATTACK := "1H_Melee_Attack_Chop"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var alerted: bool = true
var _awareness: float = 0.0
var _patrol_origin: Vector3 = Vector3.ZERO
var _down: bool = false
var _atk_cd: float = 0.0
var _stagger_time: float = 0.0
var _splatted: bool = false
var _grabbed: bool = false
var _thrown: bool = false
var _thrown_time: float = 0.0
var _player: Node3D
var _windup: float = 0.0
var _windup_target: Node3D
var _anim_lock: float = 0.0   # while >0, a one-shot anim (attack/hit) owns the model

const PICKUP_SCENE := preload("res://pickup.tscn")

@onready var model: Node3D = $Model
@onready var hit_sound: AudioStreamPlayer3D = get_node_or_null("HitSound")
@onready var _agent: NavigationAgent3D = get_node_or_null("NavAgent")
var anim: AnimationPlayer

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	alerted = start_alerted
	model.rotation.y = deg_to_rad(initial_facing_deg) + model_yaw_offset
	_patrol_origin = global_position
	var ap := model.find_child("AnimationPlayer", true, false)
	if ap is AnimationPlayer:
		anim = ap
		_play_anim(ANIM_IDLE, 0.0)

func _play_anim(name: String, blend: float = 0.12) -> void:
	if anim != null and anim.has_animation(name) and anim.current_animation != name:
		anim.play(name, blend)

func _face(dir: Vector3, delta: float) -> void:
	model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z) + model_yaw_offset, 8.0 * delta)

func _update_loco(moving: bool) -> void:
	if _down or _anim_lock > 0.0:
		return
	_play_anim(ANIM_RUN if moving else ANIM_IDLE)

func _physics_process(delta: float) -> void:
	if _anim_lock > 0.0:
		_anim_lock -= delta

	# Held by the player — the player positions us; no own physics.
	if _grabbed:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Thrown — ballistic until we hit ground/wall, then a brutal AoE impact.
	if _thrown:
		_thrown_time += delta
		move_and_slide()
		if _thrown_time > 0.12 and (is_on_floor() or is_on_wall()):
			_thrown_impact()
		return

	if _down:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Staggered: ride out the knockback, no chase/attack
	if _stagger_time > 0.0:
		_stagger_time -= delta
		var pre_speed := Vector2(velocity.x, velocity.z).length()
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 0.5)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 0.5)
		move_and_slide()
		# Hurled into a wall hard enough → crunching wall-splat.
		if not _splatted and pre_speed > 5.0 and is_on_wall():
			_wall_splat()
		return

	# Unaware: hold position and scan a vision cone; engage only once detected.
	if not alerted:
		_update_unaware(delta)
		move_and_slide()
		return

	# Winding up an attack — committed; holds position, the attack anim plays.
	if _windup > 0.0:
		_windup -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		if _windup <= 0.0:
			_land_attack()
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
		var moving := false

		if dist > stop_distance:
			# Path around walls/crates via the navmesh; fall back to a direct
			# bearing (with a sidestep) if no path is available.
			var move_dir := dir
			if _agent != null:
				_agent.target_position = player.global_position
				var to_next: Vector3 = _agent.get_next_path_position() - global_position
				to_next.y = 0.0
				if to_next.length() > 0.1:
					move_dir = to_next.normalized()
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
			if move_dir == dir and is_on_wall():
				var perp := Vector3(-dir.z, 0.0, dir.x)
				velocity.x += perp.x * move_speed
				velocity.z += perp.z * move_speed
			moving = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			if dist <= attack_range and _atk_cd <= 0.0:
				_begin_attack(player)

		if dist <= detect_range:
			_face(dir, delta)
		_update_loco(moving)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		_update_loco(false)

	move_and_slide()

func _get_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var arr := get_tree().get_nodes_in_group("player")
	_player = arr[0] if arr.size() > 0 else null
	return _player

func _update_unaware(delta: float) -> void:
	var moving := false
	if patrol_distance > 0.0:
		# Pace along the facing axis; turn back toward home when past the limit.
		var pf := Vector3(sin(model.rotation.y - model_yaw_offset), 0.0, cos(model.rotation.y - model_yaw_offset))
		velocity.x = pf.x * move_speed * 0.5
		velocity.z = pf.z * move_speed * 0.5
		moving = true
		if global_position.distance_to(_patrol_origin) > patrol_distance:
			var back: Vector3 = _patrol_origin - global_position
			model.rotation.y = atan2(back.x, back.z) + model_yaw_offset
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
	_update_loco(moving)
	var p := _get_player()
	if p == null:
		return
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var see := view_distance
	if "sneaking" in p and p.sneaking:
		see *= 0.4
	var fwd := Vector3(sin(model.rotation.y - model_yaw_offset), 0.0, cos(model.rotation.y - model_yaw_offset))
	if dist < see and fwd.dot(to.normalized()) > view_dot and _has_los(p):
		_awareness += delta / detect_time
		if _awareness >= 1.0 and not alerted:
			alerted = true
			Game.raise_detection()
			_raise_alarm()
	else:
		_awareness = maxf(0.0, _awareness - delta * 0.6)

func _has_los(p: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, 1.4, 0.0)
	var to := p.global_position + Vector3(0.0, 1.0, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == p

func _raise_alarm() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not ("alerted" in e):
			continue
		if not e.alerted and global_position.distance_to(e.global_position) < 9.0:
			e.alerted = true
	Game.log_event("alarm raised")

func _begin_attack(player: Node3D) -> void:
	_atk_cd = attack_cooldown
	_windup = 0.4
	_windup_target = player
	_play_anim(ANIM_ATTACK, 0.08)
	_anim_lock = 0.7

func _land_attack() -> void:
	var p := _windup_target
	if is_instance_valid(p) and p.has_method("take_damage"):
		if global_position.distance_to(p.global_position) <= attack_range + 0.5:
			p.take_damage(attack_damage)

func take_hit(damage: int) -> void:
	if _down:
		return
	health -= damage
	if hit_sound:
		hit_sound.play()
	Game.spawn_damage_number(global_position + Vector3(0.0, 1.8, 0.0), damage)
	Game.spawn_hitspark(global_position + Vector3(0.0, 1.2, 0.0))
	if health <= 0:
		Game.add_kill()
		_die()
	else:
		_play_anim(ANIM_HIT, 0.05)
		_anim_lock = 0.35
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
	_splatted = false
	_atk_cd = max(_atk_cd, 0.6)
	velocity = dir.normalized() * 7.0
	velocity.y = 0.0
	_play_anim(ANIM_HIT, 0.05)
	_anim_lock = 0.35

func is_staggered() -> bool:
	return _stagger_time > 0.0

# Slammed into a wall mid-knockback: extra crunch + spark + a little camera kick.
func _wall_splat() -> void:
	_splatted = true
	velocity.x = 0.0
	velocity.z = 0.0
	Game.spawn_hitspark(global_position + Vector3(0.0, 1.2, 0.0))
	Game.spawn_debris(global_position + Vector3(0.0, 0.4, 0.0))
	Game.spawn_damage_number(global_position + Vector3(0.0, 1.8, 0.0), 2)
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("shake"):
		cam.shake(0.12, 0.2)
	health -= 2
	if health <= 0:
		Game.add_kill()
		_die()

# --- Grabbed / thrown (player breaches bodies) ---
func grab(_holder: Node) -> void:
	if _down:
		return
	_grabbed = true
	alerted = true
	$CollisionShape3D.set_deferred("disabled", true)

func throw(dir: Vector3, force: float) -> void:
	_grabbed = false
	_thrown = true
	_thrown_time = 0.0
	$CollisionShape3D.set_deferred("disabled", false)
	velocity = dir.normalized() * force + Vector3(0.0, 4.0, 0.0)

func _thrown_impact() -> void:
	_thrown = false
	Game.spawn_hitspark(global_position + Vector3(0.0, 0.5, 0.0))
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not (e is Node3D) or not e.has_method("take_hit"):
			continue
		if global_position.distance_to(e.global_position) < 2.5:
			e.take_hit(throw_impact_damage)
			if e.has_method("stagger"):
				var d: Vector3 = e.global_position - global_position
				e.stagger(Vector3(d.x, 0.0, d.z).normalized())
	Game.add_kill()
	_die()

func _maybe_drop_pickup() -> void:
	if randf() > pickup_drop_chance:
		return
	var p := PICKUP_SCENE.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.3, 0.0)

func _die() -> void:
	_down = true
	remove_from_group("enemy")
	$CollisionShape3D.set_deferred("disabled", true)
	_maybe_drop_pickup()
	_play_anim(ANIM_DEATH, 0.1)
	_anim_lock = 999.0
	# Let the death animation play out, then sink and free.
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_property(self, "position:y", position.y - 1.2, 0.6)
	t.tween_callback(queue_free)
