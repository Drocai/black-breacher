extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — THE WARDEN (multi-phase boss)
#  A heavy, slow bruiser that cycles through telegraphed attacks.
#  Three phases gated by health fraction:
#    PHASE 1 (>66%): slow chase + AoE ground SLAM (long telegraph).
#    PHASE 2 (33-66%): adds PROJECTILE VOLLEY + SUMMON adds.
#    PHASE 3 (<33%): ENRAGE — faster, shorter telegraphs, CHARGE lunge.
#  Resists stagger/knockback (a tiny flinch only). Big death payoff.
#
#  Timer-driven state machine ticked in _physics_process. No awaits
#  on freed nodes; every player/target reference is guarded with
#  is_instance_valid before use.
# ============================================================

@export var max_health: int = 60
@export var boss_name: String = "THE WARDEN"

@export var move_speed: float = 1.6
@export var enrage_speed: float = 3.4
@export var detect_range: float = 40.0
@export var turn_speed: float = 5.0

# SLAM (AoE ground pound)
@export var slam_telegraph: float = 0.8
@export var slam_telegraph_enraged: float = 0.45
@export var slam_radius: float = 4.0
@export var slam_damage: int = 18
@export var slam_cooldown: float = 3.2

# VOLLEY (phase 2+)
@export var projectile_scene: PackedScene = preload("res://projectile.tscn")
@export var volley_count: int = 3
@export var volley_spread_deg: float = 18.0
@export var volley_cooldown: float = 4.5

# SUMMON (phase 2+)
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var summon_count: int = 2
@export var max_summons: int = 2          # how many summon waves total

# ERUPTION (phase 2+): a telegraphed AoE that marks the player's spot, then
# erupts after a delay — forces a dodge, unlike the fixed-radius proximity slam.
@export var eruption_cooldown: float = 5.5
@export var eruption_delay: float = 0.75
@export var eruption_radius: float = 2.8
@export var eruption_damage: int = 16

# CHARGE (phase 3)
@export var charge_telegraph: float = 0.5
@export var charge_speed: float = 11.0
@export var charge_time: float = 0.6
@export var charge_damage: int = 22
@export var charge_cooldown: float = 3.0

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# State machine
enum State { CHASE, TELEGRAPH_SLAM, TELEGRAPH_CHARGE, CHARGING, DEAD }
var _state: int = State.CHASE
var _state_timer: float = 0.0

# Cooldown clocks
var _slam_cd: float = 0.0
var _volley_cd: float = 0.0
var _eruption_cd: float = 0.0
var _charge_cd: float = 0.0
var _summons_done: int = 0

# Knockback resistance — a boss only flinches briefly.
var _flinch_time: float = 0.0

var _player: Node3D
var _charge_dir: Vector3 = Vector3.ZERO
var _charge_hit: bool = false
var _vis := CharacterVisuals.new()

const WALK_GLB := preload("res://characters/operator_breacher_walk.glb")

@export var model_yaw_offset_deg: float = 180.0

@onready var mesh: Node3D = $Mesh
@onready var hit_sound: AudioStreamPlayer3D = get_node_or_null("HitSound")

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	# Faint cold cast sets THE WARDEN apart from a rank-and-file breacher.
	_vis.setup(mesh, WALK_GLB, model_yaw_offset_deg, Color(0.78, 0.76, 0.86))
	_set_glow(false)   # persistent dim menace-glow from the start

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	_vis.drive(velocity, _cur_speed(), delta, false)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if _slam_cd > 0.0:
		_slam_cd -= delta
	if _volley_cd > 0.0:
		_volley_cd -= delta
	if _eruption_cd > 0.0:
		_eruption_cd -= delta
	if _charge_cd > 0.0:
		_charge_cd -= delta
	if _flinch_time > 0.0:
		_flinch_time -= delta

	match _state:
		State.CHASE:
			_tick_chase(delta)
		State.TELEGRAPH_SLAM:
			_tick_telegraph_slam(delta)
		State.TELEGRAPH_CHARGE:
			_tick_telegraph_charge(delta)
		State.CHARGING:
			_tick_charging(delta)

	move_and_slide()

# --- Phase helpers -------------------------------------------------

func _phase() -> int:
	var frac := float(health) / float(max_health)
	if frac > 0.66:
		return 1
	elif frac > 0.33:
		return 2
	return 3

func _cur_speed() -> float:
	return enrage_speed if _phase() == 3 else move_speed

func _cur_slam_telegraph() -> float:
	return slam_telegraph_enraged if _phase() == 3 else slam_telegraph

# --- States --------------------------------------------------------

func _tick_chase(delta: float) -> void:
	var spd := _cur_speed()

	# Brief flinch: bleed sideways momentum but keep deciding.
	if _flinch_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, spd)
		velocity.z = move_toward(velocity.z, 0.0, spd)
		return

	var player := _get_player()
	if player == null:
		velocity.x = move_toward(velocity.x, 0.0, spd)
		velocity.z = move_toward(velocity.z, 0.0, spd)
		return

	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var dir := to_player.normalized()

	# Face the player.
	if dist <= detect_range and dist > 0.01:
		mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(dir.x, dir.z), turn_speed * delta)

	# Pick an attack if anything is off cooldown and in range.
	if _try_start_attack(dist):
		return

	# Otherwise plod toward the player until close.
	if dist > slam_radius * 0.6:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if is_on_wall():
			var perp := Vector3(-dir.z, 0.0, dir.x)
			velocity.x += perp.x * spd
			velocity.z += perp.z * spd
	else:
		velocity.x = move_toward(velocity.x, 0.0, spd)
		velocity.z = move_toward(velocity.z, 0.0, spd)

func _try_start_attack(dist: float) -> bool:
	var phase := _phase()

	# PHASE 3: charge has priority when at mid range.
	if phase == 3 and _charge_cd <= 0.0 and dist > slam_radius and dist <= detect_range:
		_begin_telegraph_charge()
		return true

	# PHASE 2+: volley + summon at range.
	if phase >= 2 and _volley_cd <= 0.0 and dist <= detect_range:
		_do_volley()
		if _summons_done < max_summons:
			_do_summon()
			_summons_done += 1
		return true

	# PHASE 2+: ground eruption — a dodge-the-marked-spot AoE at mid range.
	if phase >= 2 and _eruption_cd <= 0.0 and dist > slam_radius and dist <= detect_range:
		_do_eruption()
		return true

	# All phases: slam when close.
	if _slam_cd <= 0.0 and dist <= slam_radius:
		_begin_telegraph_slam()
		return true

	return false

func _begin_telegraph_slam() -> void:
	_state = State.TELEGRAPH_SLAM
	_state_timer = _cur_slam_telegraph()
	_slam_cd = slam_cooldown
	_set_glow(true)
	velocity.x = 0.0
	velocity.z = 0.0
	# Leap/rear up (model feet baseline is 0), then slam down in _do_slam.
	var t := create_tween()
	t.tween_property(mesh, "position:y", 0.7, _state_timer * 0.7)
	t.tween_property(mesh, "position:y", 0.5, _state_timer * 0.3)

func _tick_telegraph_slam(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, _cur_speed())
	velocity.z = move_toward(velocity.z, 0.0, _cur_speed())
	_state_timer -= delta
	if _state_timer <= 0.0:
		_do_slam()

func _do_slam() -> void:
	_set_glow(false)
	_state = State.CHASE
	# Slam down hard to the ground, then a small landing bob.
	var t := create_tween()
	t.tween_property(mesh, "position:y", 0.0, 0.06)
	t.tween_property(mesh, "position:y", 0.08, 0.18)

	var feet := global_position + Vector3(0.0, 0.2, 0.0)
	Game.spawn_explosion(feet)
	Game.spawn_hitspark(global_position + Vector3(0.0, 0.6, 0.0))

	var player := _get_player()
	if is_instance_valid(player) and player.has_method("take_damage"):
		var d: Vector3 = player.global_position - global_position
		d.y = 0.0
		if d.length() <= slam_radius:
			player.take_damage(slam_damage)

func _do_volley() -> void:
	_volley_cd = volley_cooldown
	if projectile_scene == null:
		return
	var player := _get_player()
	if not is_instance_valid(player):
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < 0.01:
		return
	var base_dir := to_player.normalized()
	var muzzle := global_position + Vector3(0.0, 1.6, 0.0)

	# Fire a fan of projectiles centered on the player.
	for i in range(volley_count):
		var offset: float = 0.0
		if volley_count > 1:
			offset = lerpf(-volley_spread_deg, volley_spread_deg, float(i) / float(volley_count - 1))
		var dir: Vector3 = base_dir.rotated(Vector3.UP, deg_to_rad(offset))
		var pr := projectile_scene.instantiate()
		get_tree().current_scene.add_child(pr)
		pr.global_position = muzzle + dir * 1.0
		if pr.has_method("setup"):
			pr.setup(dir)
	Game.spawn_hitspark(muzzle + base_dir * 1.0)

func _do_summon() -> void:
	if enemy_scene == null:
		return
	var scene := get_tree().current_scene
	for i in range(summon_count):
		var add: Node = enemy_scene.instantiate()
		# Aggressive on spawn.
		if "start_alerted" in add:
			add.start_alerted = true
		var ang: float = TAU * float(i) / float(maxi(summon_count, 1))
		var off := Vector3(cos(ang), 0.0, sin(ang)) * 2.2
		scene.add_child(add)
		if add is Node3D:
			add.global_position = global_position + off + Vector3(0.0, 0.2, 0.0)
		Game.spawn_hitspark(global_position + off + Vector3(0.0, 0.6, 0.0))

# Mark the player's current spot, then erupt there after a delay — the player
# must read the warning ring and step off it.
func _do_eruption() -> void:
	_eruption_cd = eruption_cooldown
	var player := _get_player()
	if not is_instance_valid(player):
		return
	var target: Vector3 = player.global_position
	target.y = 0.05
	# Warning ring at the marked spot.
	Game.spawn_shockwave(target, Color(1.0, 0.3, 0.1), eruption_radius * 1.3)
	Game.spawn_hitspark(target + Vector3(0.0, 0.2, 0.0))
	var t := create_tween()
	t.tween_interval(eruption_delay)
	t.tween_callback(_erupt_at.bind(target))

func _erupt_at(pos: Vector3) -> void:
	if _state == State.DEAD:
		return
	Game.spawn_explosion(pos)
	var player := _get_player()
	if is_instance_valid(player) and player.has_method("take_damage"):
		var d: Vector3 = player.global_position - pos
		d.y = 0.0
		if d.length() <= eruption_radius:
			player.take_damage(eruption_damage)

func _begin_telegraph_charge() -> void:
	_state = State.TELEGRAPH_CHARGE
	_state_timer = charge_telegraph
	_charge_cd = charge_cooldown
	_charge_hit = false
	_set_glow(true)
	velocity.x = 0.0
	velocity.z = 0.0
	# Lock in charge direction toward the player at telegraph start.
	var player := _get_player()
	if is_instance_valid(player):
		var d: Vector3 = player.global_position - global_position
		d.y = 0.0
		_charge_dir = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
		mesh.rotation.y = atan2(_charge_dir.x, _charge_dir.z)
	else:
		_charge_dir = Vector3(sin(mesh.rotation.y), 0.0, cos(mesh.rotation.y))

func _tick_telegraph_charge(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, _cur_speed())
	velocity.z = move_toward(velocity.z, 0.0, _cur_speed())
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state = State.CHARGING
		_state_timer = charge_time
		# Anticipation pull-back into the lunge.
		var t := create_tween()
		t.tween_property(mesh, "position:z", -0.3, 0.06)
		t.tween_property(mesh, "position:z", 0.0, 0.2)

func _tick_charging(delta: float) -> void:
	velocity.x = _charge_dir.x * charge_speed
	velocity.z = _charge_dir.z * charge_speed

	# Contact damage along the lunge (once).
	if not _charge_hit:
		var player := _get_player()
		if is_instance_valid(player) and player.has_method("take_damage"):
			var d: Vector3 = player.global_position - global_position
			d.y = 0.0
			if d.length() <= 2.0:
				player.take_damage(charge_damage)
				Game.spawn_hitspark(global_position + Vector3(0.0, 1.2, 0.0))
				_charge_hit = true

	_state_timer -= delta
	if _state_timer <= 0.0 or is_on_wall():
		_set_glow(false)
		_state = State.CHASE

# --- Visuals -------------------------------------------------------

# The boss keeps a persistent dim menace-glow; attacks flare it bright red.
func _set_glow(on: bool) -> void:
	for m in _vis.mats:
		m.emission_enabled = true
		m.emission = Color(1.0, 0.1, 0.05) if on else Color(0.4, 0.05, 0.05)
		m.emission_energy_multiplier = 4.0 if on else 0.9

func _flash() -> void:
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3(1.08, 0.94, 1.08), 0.05)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.1)
	for m in _vis.mats:
		m.emission_enabled = true
		var t2 := create_tween()
		t2.tween_property(m, "emission_energy_multiplier", 5.0, 0.02)
		t2.tween_property(m, "emission_energy_multiplier", 0.9, 0.16)

# --- Damage / combat interface ------------------------------------

func take_hit(damage: int) -> void:
	if _state == State.DEAD:
		return
	health -= damage
	_flash()
	if hit_sound:
		hit_sound.play()
	Game.spawn_damage_number(global_position + Vector3(0.0, 2.6, 0.0), damage)
	Game.spawn_hitspark(global_position + Vector3(0.0, 1.6, 0.0))
	if health <= 0:
		_die()

func stagger(dir: Vector3) -> void:
	# A boss resists knockback — only a tiny flinch, never launched.
	if _state == State.DEAD:
		return
	if _state == State.CHARGING or _state == State.TELEGRAPH_CHARGE:
		return   # committed to the charge; unflinchable
	_flinch_time = max(_flinch_time, 0.12)
	velocity += dir.normalized() * 1.2
	velocity.y = 0.0

func is_staggered() -> bool:
	return _flinch_time > 0.0

# --- Death ---------------------------------------------------------

func _die() -> void:
	_state = State.DEAD
	remove_from_group("enemy")
	remove_from_group("boss")
	$CollisionShape3D.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	_vis.pause()

	Game.add_kill(2000)

	# A staggered burst of explosions around the body.
	Game.spawn_explosion(global_position + Vector3(0.0, 1.0, 0.0))
	var burst := create_tween()
	for i in range(5):
		var ox := randf_range(-1.6, 1.6)
		var oz := randf_range(-1.6, 1.6)
		var oy := randf_range(0.4, 2.2)
		burst.tween_interval(0.18)
		burst.tween_callback(_explosion_at.bind(Vector3(ox, oy, oz)))

	# Topple over and despawn.
	var t := create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(90.0), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_interval(1.4)
	t.tween_callback(queue_free)

func _explosion_at(offset: Vector3) -> void:
	Game.spawn_explosion(global_position + offset)

# --- Player lookup -------------------------------------------------

func _get_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var arr := get_tree().get_nodes_in_group("player")
	_player = arr[0] if arr.size() > 0 else null
	return _player
