extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — armored brute
#  A slow, tanky bruiser. Chases the nearest player and lands heavy
#  lunging attacks on a wind-up telegraph. Light jabs glance off its
#  armor (deflected to a fraction); heavy blows (kick / halligan /
#  special / finisher) bite for full damage. Topples on death.
# ============================================================

@export var max_health: int = 12
@export var move_speed: float = 1.6
@export var detect_range: float = 18.0
@export var stop_distance: float = 1.8
@export var attack_range: float = 2.3
@export var attack_damage: int = 16
@export var attack_cooldown: float = 1.8
@export var armor_threshold: int = 3   # hits below this only chip the armor

@export var pickup_drop_chance: float = 0.6
@export var knockback_force: float = 3.0
@export var hitstun_time: float = 0.12
@export var stagger_resist: float = 0.55   # 0 = no resist, 1 = immovable
@export var tint: Color = Color(1, 1, 1, 1)

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _down: bool = false
var _atk_cd: float = 0.0
var _stagger_time: float = 0.0
var _player: Node3D
var _windup: float = 0.0
var _windup_target: Node3D
var _mat: StandardMaterial3D

const PICKUP_SCENE := preload("res://pickup.tscn")

@onready var mesh: MeshInstance3D = $Mesh
@onready var hit_sound: AudioStreamPlayer3D = get_node_or_null("HitSound")
@onready var _agent: NavigationAgent3D = get_node_or_null("NavAgent")

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	# Per-instance material so hit-flash / attack-glow don't affect other brutes.
	if mesh.material_override is StandardMaterial3D:
		_mat = mesh.material_override.duplicate()
		_mat.albedo_color = _mat.albedo_color * tint
		mesh.material_override = _mat

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _down:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Staggered: ride out the knockback, no chase/attack.
	if _stagger_time > 0.0:
		_stagger_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 0.5)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 0.5)
		move_and_slide()
		return

	# Winding up — committed; holds position and telegraphs (red glow),
	# giving the player a window to block / parry / dodge / step out.
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
			mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(dir.x, dir.z), 6.0 * delta)
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

func _begin_attack(player: Node3D) -> void:
	_atk_cd = attack_cooldown
	_windup = 0.55   # heavier, slower telegraph than the basic enemy
	_windup_target = player
	_set_glow(true)
	var t := create_tween()
	t.tween_property(mesh, "position:z", 0.22, 0.5)   # big anticipation pull-back

func _land_attack() -> void:
	_set_glow(false)
	var t := create_tween()
	t.tween_property(mesh, "position:z", -0.5, 0.08)   # heavy lunge
	t.tween_property(mesh, "position:z", 0.0, 0.16)
	var p := _windup_target
	if is_instance_valid(p) and p.has_method("take_damage"):
		if global_position.distance_to(p.global_position) <= attack_range + 0.6:
			p.take_damage(attack_damage)

func _set_glow(on: bool) -> void:
	if _mat == null:
		return
	_mat.emission_enabled = on
	if on:
		_mat.emission = Color(1.0, 0.2, 0.05)
		_mat.emission_energy_multiplier = 2.5
	else:
		_mat.emission_energy_multiplier = 0.0

# --- Armor mechanic -----------------------------------------
# Light jabs (damage < armor_threshold) glance off: only ~30% lands
# (min 1) and we play a metallic "clink" deflect spark. Heavy blows
# (kick / halligan / special / finisher, damage >= armor_threshold)
# punch through for full damage.
func take_hit(damage: int) -> void:
	if _down:
		return
	var deflected := damage < armor_threshold
	var dealt := damage
	if deflected:
		dealt = max(1, int(round(damage * 0.3)))
		_clink()
	else:
		_flash()
	health -= dealt
	if hit_sound:
		hit_sound.play()
	# Always report the ACTUAL damage dealt.
	Game.spawn_damage_number(global_position + Vector3(0.0, 2.2, 0.0), dealt)
	if deflected:
		# Spark at chest height — reads as a deflect off the plating.
		Game.spawn_hitspark(global_position + Vector3(0.0, 1.3, 0.0))
	else:
		Game.spawn_hitspark(global_position + Vector3(0.0, 1.5, 0.0))
	if health <= 0:
		Game.add_kill()
		_die()
	else:
		# Light hits barely move the brute; heavy hits rock it.
		if not deflected:
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
	# Armored frame resists stagger — shorter hitstun, weaker shove.
	_stagger_time = max(_stagger_time, 0.35 * (1.0 - stagger_resist))
	_atk_cd = max(_atk_cd, 0.5)
	velocity = dir.normalized() * 7.0 * (1.0 - stagger_resist)
	velocity.y = 0.0

func is_staggered() -> bool:
	return _stagger_time > 0.0

func _flash() -> void:
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.1, 0.9, 1.1), 0.05)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.1)
	if _mat:
		_mat.emission_enabled = true
		_mat.emission = Color(1.0, 0.15, 0.1)
		var t2 := create_tween()
		t2.tween_property(_mat, "emission_energy_multiplier", 3.5, 0.02)
		t2.tween_property(_mat, "emission_energy_multiplier", 0.0, 0.16)

func _clink() -> void:
	# A short, cold metallic flash — the hit skids off the armor.
	if _mat:
		_mat.emission_enabled = true
		_mat.emission = Color(0.7, 0.8, 1.0)
		var t := create_tween()
		t.tween_property(_mat, "emission_energy_multiplier", 2.0, 0.02)
		t.tween_property(_mat, "emission_energy_multiplier", 0.0, 0.1)

func _knockback_anim() -> void:
	var t := create_tween()
	t.tween_property(mesh, "rotation:x", deg_to_rad(10.0), 0.05)
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
	_maybe_drop_pickup()
	var t := create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(90.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_interval(0.8)
	t.tween_callback(queue_free)
