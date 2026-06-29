extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — reactive enemy
#  Chases the player, attacks at close range on a cooldown, takes
#  hits, can be staggered/knocked back, and topples on death.
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
@export var tint: Color = Color(1, 1, 1, 1)
@export var patrol_distance: float = 0.0   # >0 = an unaware guard paces this far and back

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
var _mats: Array[BaseMaterial3D] = []   # per-instance skinned materials (flash/glow)
var _anim: AnimationPlayer
var _cur_anim: String = ""
var _anim_lock: float = 0.0             # one-shot anims own the model until this expires

const PICKUP_SCENE := preload("res://pickup.tscn")
const WALK_GLB := preload("res://characters/operator_swat_walk.glb")
const ANIM_RUN := "Armature|running|baselayer"
const ANIM_WALK := "Armature|walking_man|baselayer"

# Operator GLB faces -Z; our facing math (atan2(dir.x, dir.z)) points +Z at the
# target, so spin the model 180 so it runs toward the player face-first.
@export var model_yaw_offset_deg: float = 180.0

@onready var mesh: Node3D = $Mesh
@onready var hit_sound: AudioStreamPlayer3D = get_node_or_null("HitSound")
@onready var _agent: NavigationAgent3D = get_node_or_null("NavAgent")

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	alerted = start_alerted
	mesh.rotation.y = deg_to_rad(initial_facing_deg)
	_patrol_origin = global_position
	_setup_model()

func _setup_model() -> void:
	# Orient the skinned operator within the facing wrapper.
	var op := mesh.get_child(0) if mesh.get_child_count() > 0 else null
	if op is Node3D:
		(op as Node3D).rotation.y = deg_to_rad(model_yaw_offset_deg)
	# Per-instance skinned materials so hit-flash / attack-glow are local.
	for mi in mesh.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for s in m.get_surface_override_material_count():
			var base := m.get_active_material(s)
			if base is BaseMaterial3D:
				var dup: BaseMaterial3D = base.duplicate()
				if tint != Color(1, 1, 1, 1):
					dup.albedo_color = dup.albedo_color * tint
				m.set_surface_override_material(s, dup)
				_mats.append(dup)
	# Animation: the model ships with "running"; graft "walking" from the walk
	# GLB so unaware guards can pace and chasers can sprint.
	_anim = mesh.find_child("AnimationPlayer", true, false)
	if _anim:
		var lib := _anim.get_animation_library("")
		if lib:
			if _anim.has_animation(ANIM_RUN):
				_anim.get_animation(ANIM_RUN).loop_mode = Animation.LOOP_LINEAR
			if not _anim.has_animation(ANIM_WALK):
				var tmp := WALK_GLB.instantiate()
				var tap: AnimationPlayer = tmp.find_child("AnimationPlayer", true, false)
				if tap and tap.has_animation(ANIM_WALK):
					var wa: Animation = tap.get_animation(ANIM_WALK).duplicate(true)
					wa.loop_mode = Animation.LOOP_LINEAR
					lib.add_animation(ANIM_WALK, wa)
				tmp.queue_free()
		_play_anim(ANIM_RUN)

func _physics_process(delta: float) -> void:
	# Held by the player — the player positions us; no own physics.
	if _grabbed:
		return

	_update_anim(delta)

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

	# Winding up an attack — committed; holds position and telegraphs (red glow),
	# giving the player a window to block / parry / dodge / step out of range.
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
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			if dist <= attack_range and _atk_cd <= 0.0:
				_begin_attack(player)

		if dist <= detect_range:
			mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

# --- Skinned-model animation control ---
func _play_anim(name: String, blend: float = 0.12) -> void:
	if _anim == null or name == _cur_anim or not _anim.has_animation(name):
		return
	_cur_anim = name
	_anim.play(name, blend)

func _update_anim(delta: float) -> void:
	if _anim == null:
		return
	if _anim_lock > 0.0:
		_anim_lock -= delta
		return
	if _down:
		return
	# Locomotion from horizontal speed: sprint when chasing, pace when slow,
	# settle to a held stance (paused) when essentially still.
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > move_speed * 0.55:
		_play_anim(ANIM_RUN)
		_anim.speed_scale = clampf(spd / max(move_speed, 0.1), 0.85, 1.5)
	elif spd > 0.25:
		_play_anim(ANIM_WALK)
		_anim.speed_scale = 1.0
	else:
		# Hold a grounded ready-stance (first frame of walk), not a frozen sprint.
		_play_anim(ANIM_WALK)
		_anim.speed_scale = 0.0

func _get_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var arr := get_tree().get_nodes_in_group("player")
	_player = arr[0] if arr.size() > 0 else null
	return _player

func _update_unaware(delta: float) -> void:
	if patrol_distance > 0.0:
		# Pace along the facing axis; turn back toward home when past the limit.
		var pf := Vector3(sin(mesh.rotation.y), 0.0, cos(mesh.rotation.y))
		velocity.x = pf.x * move_speed * 0.5
		velocity.z = pf.z * move_speed * 0.5
		if global_position.distance_to(_patrol_origin) > patrol_distance:
			var back: Vector3 = _patrol_origin - global_position
			mesh.rotation.y = atan2(back.x, back.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
	var p := _get_player()
	if p == null:
		return
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var see := view_distance
	if "sneaking" in p and p.sneaking:
		see *= 0.4
	var fwd := Vector3(sin(mesh.rotation.y), 0.0, cos(mesh.rotation.y))
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
	_set_glow(true)
	var t := create_tween()
	t.tween_property(mesh, "position:z", 0.18, 0.35)   # anticipation pull-back

func _land_attack() -> void:
	_set_glow(false)
	var t := create_tween()
	t.tween_property(mesh, "position:z", -0.4, 0.07)   # lunge
	t.tween_property(mesh, "position:z", 0.0, 0.12)
	var p := _windup_target
	if is_instance_valid(p) and p.has_method("take_damage"):
		if global_position.distance_to(p.global_position) <= attack_range + 0.5:
			p.take_damage(attack_damage)

func _set_glow(on: bool) -> void:
	for m in _mats:
		m.emission_enabled = on
		if on:
			m.emission = Color(1.0, 0.25, 0.1)
			m.emission_energy_multiplier = 2.5
		else:
			m.emission_energy_multiplier = 0.0

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
	_splatted = false
	_atk_cd = max(_atk_cd, 0.6)
	velocity = dir.normalized() * 7.0
	velocity.y = 0.0

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
	_flash()
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

func _flash() -> void:
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.1)
	for m in _mats:
		m.emission_enabled = true
		m.emission = Color(1.0, 0.15, 0.1)
		var t2 := create_tween()
		t2.tween_property(m, "emission_energy_multiplier", 3.5, 0.02)
		t2.tween_property(m, "emission_energy_multiplier", 0.0, 0.16)

func _knockback_anim() -> void:
	var t := create_tween()
	t.tween_property(mesh, "rotation:x", deg_to_rad(18.0), 0.05)
	t.tween_property(mesh, "rotation:x", 0.0, 0.15)

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
	if _anim:
		_anim.pause()   # freeze mid-stride; the topple tween sells the drop
	_maybe_drop_pickup()
	var t := create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(90.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_interval(0.8)
	t.tween_callback(queue_free)
