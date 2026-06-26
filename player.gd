extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — player controller
#  Baseline (SKILL.md): world-relative movement, mesh-only rotation
#  (camera never spins), attack_timer interrupt pattern.
#
#  Controls:
#    WASD / Arrows  move      Shift  run        Space  jump
#    J / Left-click punch combo (jab > hook > upper hook > uppercut)
#    Right-click    heavy kick (cycles High / Step-in / straight kick)
#    E             special launcher (Charged_Upward_Slash, knockback)
#    Q             dodge (i-frames, dashes in your move direction)
#    F             breach a door in range (Spartan_Kick)
#    Hold Ctrl     block (cuts damage; block early = parry + stagger)
# ============================================================

# --- Movement tunables ---
@export var speed: float = 4.0
@export var run_speed: float = 7.0
@export var rotation_speed: float = 12.0
@export var jump_velocity: float = 5.0
@export var sneak_speed: float = 2.0

# --- Combat tunables ---
@export var jab_range: float = 1.9
@export var kick_range: float = 2.4
@export var kick_damage: int = 3
@export var special_range: float = 2.4
@export var special_damage: int = 4
@export var special_cooldown: float = 2.0
@export var dodge_speed: float = 9.0
@export var dodge_time: float = 0.35
@export var dodge_cooldown: float = 0.8
@export var max_health: int = 100
@export var block_damage_reduction: float = 0.25
@export var parry_window: float = 0.2
@export var grab_range: float = 2.6
@export var throw_force: float = 14.0
@export var halligan_range: float = 3.2
@export var halligan_damage: int = 5
@export var halligan_cooldown: float = 1.4
@export_group("Halligan grip (tune in editor)")
@export var halligan_offset: Vector3 = Vector3(0.05, 0.02, 0.0)
@export var halligan_rotation_deg: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var halligan_scale: float = 1.0
@export_group("")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var anim: AnimationPlayer = $breacher/AnimationPlayer
@onready var mesh: Node3D = $breacher
@onready var jab_sound: AudioStreamPlayer = $JabSound
@onready var footstep_sound: AudioStreamPlayer = get_node_or_null("Footsteps")

var health: int
var _spawn: Transform3D

var attack_timer: float = 0.0      # locks locomotion anim while an action plays
var _jump_queued: bool = false
var breach_target: Node = null
var _pending_breach: Node = null

# Punch combo + in-flight hit
const JAB_CLIPS := ["Right_Jab_from_Guard", "Left_Hook_from_Guard", "Right_Upper_Hook_from_Guard", "Right_Uppercut_from_Guard"]
const JAB_DMG := [1, 1, 1, 2]
const KICK_CLIPS := ["High_Kick", "Step_in_High_Kick", "Boxing_Guard_Right_Straight_Kick"]
var _combo_index: int = 0
var _combo_timer: float = 0.0
var _kick_index: int = 0
var _pending_hit_damage: int = 1
var _pending_hit_range: float = 1.9

# Special + dodge state
var _special_cd: float = 0.0
var _dodge_cd: float = 0.0
var _dodge_time_left: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _invuln: float = 0.0
var _blocking: bool = false
var _block_time: float = 0.0
var _loco_speed: float = 1.0
var _step_timer: float = 0.0
var sneaking: bool = false
var _held_enemy: Node3D = null
var _halligan_cd: float = 0.0

func _ready() -> void:
	Engine.time_scale = 1.0   # normalize in case a reload happened mid-hitstop
	add_to_group("player")
	health = max_health
	_spawn = global_transform
	_apply_character_skin()
	# The imported rig defaults to 0.654x, which desynced the walk from
	# movement (foot-sliding). Run anims at full speed; locomotion speed is
	# then driven per-frame by actual velocity below.
	anim.speed_scale = 1.0
	_attach_halligan()

# Apply the Meshy-generated PBR skin to the rigged mesh at runtime.
# (Retexture strips the rig, so we keep the animated glb and just swap the
#  material onto its char1 surface — every animation is preserved.)
func _apply_character_skin() -> void:
	var mat := load("res://textures/breacher_material.tres")
	if mat == null:
		return
	var m := mesh.find_child("char1", true, false)
	if m is MeshInstance3D:
		m.material_override = mat

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				_jump_queued = true
			KEY_J:
				_try_jab()
			KEY_E:
				_try_special()
			KEY_Q:
				_try_dodge()
			KEY_F:
				_try_breach()
			KEY_C:
				sneaking = not sneaking
			KEY_V:
				_try_grab_or_throw()
			KEY_X:
				_try_halligan()
			KEY_R:
				Game.full_reset()
				get_tree().reload_current_scene()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_jab()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_kick()

func _physics_process(delta: float) -> void:
	_update_hold()

	if not is_on_floor():
		velocity.y -= gravity * delta

	if _jump_queued:
		_jump_queued = false
		if is_on_floor():
			velocity.y = jump_velocity

	if attack_timer > 0.0:
		attack_timer -= delta
	if _combo_timer > 0.0:
		_combo_timer -= delta
	else:
		_combo_index = 0
	if _special_cd > 0.0:
		_special_cd -= delta
	if _halligan_cd > 0.0:
		_halligan_cd -= delta
	if _dodge_cd > 0.0:
		_dodge_cd -= delta
	if _invuln > 0.0:
		_invuln -= delta

	# Dodge takes over movement for its duration
	if _dodge_time_left > 0.0:
		_dodge_time_left -= delta
		velocity.x = _dodge_dir.x * dodge_speed
		velocity.z = _dodge_dir.z * dodge_speed
		move_and_slide()
		return

	# Block (hold Ctrl): root in place, soak/parry incoming damage
	_blocking = Input.is_physical_key_pressed(KEY_CTRL) and is_on_floor() and attack_timer <= 0.0 and _held_enemy == null
	if _blocking:
		_block_time += delta
		velocity.x = move_toward(velocity.x, 0.0, run_speed)
		velocity.z = move_toward(velocity.z, 0.0, run_speed)
		if anim.has_animation("Boxing_Guard_Prep_Straight_Punch") and anim.current_animation != "Boxing_Guard_Prep_Straight_Punch":
			anim.play("Boxing_Guard_Prep_Straight_Punch")
		move_and_slide()
		return
	else:
		_block_time = 0.0

	# --- Movement (world-relative; WASD + arrows) ---
	var direction := _current_input_dir()
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	var current_speed := run_speed if running else speed
	if sneaking and not running:
		current_speed = sneak_speed

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		var target_angle := atan2(direction.x, direction.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	var hspeed := Vector2(velocity.x, velocity.z).length()
	_update_locomotion_anim(direction != Vector3.ZERO, running, hspeed)
	_tick_footsteps(delta, hspeed)
	move_and_slide()
	_shove_aside(hspeed)

func _current_input_dir() -> Vector3:
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		d.y += 1.0
	d = d.normalized()
	return Vector3(d.x, 0.0, d.y)

func _update_locomotion_anim(moving: bool, running: bool, hspeed: float) -> void:
	if attack_timer > 0.0:
		return
	if not is_on_floor():
		return
	if moving:
		var clip := "Running" if running else "Casual_Walk"
		var ref := run_speed if running else speed
		# Drive the walk/run playback by ACTUAL speed so the feet match travel.
		var spd: float = clampf(hspeed / maxf(ref, 0.1), 0.5, 1.6)
		if anim.current_animation != clip or absf(_loco_speed - spd) > 0.12:
			anim.play(clip, -1.0, spd)
			_loco_speed = spd
	elif anim.current_animation != "Axe_Breathe_and_Look_Around":
		anim.play("Axe_Breathe_and_Look_Around")

func _tick_footsteps(delta: float, hspeed: float) -> void:
	if footstep_sound == null or sneaking or not is_on_floor() or hspeed < 0.5:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		footstep_sound.play()
		_step_timer = clampf(2.6 / maxf(hspeed, 0.1), 0.28, 0.6)

func _busy() -> bool:
	return attack_timer > 0.0 or _dodge_time_left > 0.0 or _blocking or _held_enemy != null

# --- Punch combo (J / left-click) ---
func _try_jab() -> void:
	if _busy():
		return
	var td := _find_takedown_target()
	if td:
		_do_takedown(td)
		return
	_face_nearest_enemy()
	if _combo_timer <= 0.0:
		_combo_index = 0
	var clip: String = JAB_CLIPS[_combo_index]
	_pending_hit_damage = JAB_DMG[_combo_index]
	_pending_hit_range = jab_range
	_play_action(clip)
	_combo_index = (_combo_index + 1) % JAB_CLIPS.size()
	_combo_timer = attack_timer + 0.5
	get_tree().create_timer(0.15).timeout.connect(_apply_melee_hit)

# --- Heavy kick (right-click), cycles through the kick clips ---
func _try_kick() -> void:
	if _busy():
		return
	_face_nearest_enemy()
	_pending_hit_damage = kick_damage
	_pending_hit_range = kick_range
	var clip: String = KICK_CLIPS[_kick_index]
	_kick_index = (_kick_index + 1) % KICK_CLIPS.size()
	_play_action(clip)
	get_tree().create_timer(0.22).timeout.connect(_apply_melee_hit)

func _apply_melee_hit() -> void:
	var landed := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node3D) or not enemy.has_method("take_hit"):
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() <= _pending_hit_range:
			# Finisher: a staggered, weakened enemy gets executed.
			if enemy.has_method("is_staggered") and enemy.is_staggered() and ("health" in enemy) and enemy.health <= 4:
				enemy.take_hit(999)
				shake(0.18, 0.25)
				_hero_cam(0.8)
				Game.spawn_hitspark(enemy.global_position + Vector3(0.0, 1.0, 0.0))
			else:
				enemy.take_hit(_pending_hit_damage)
			landed = true
	# Breach crates / breakables in range.
	for b in get_tree().get_nodes_in_group("breakable"):
		if b is Node3D and b.has_method("take_hit"):
			if global_position.distance_to(b.global_position) <= _pending_hit_range + 0.6:
				b.take_hit(2)
				landed = true
	if landed:
		if jab_sound:
			jab_sound.play()
		_hitstop()
		shake(0.06, 0.12)

# His bulk shoves smaller enemies aside when he barrels into them.
func _shove_aside(hspeed: float) -> void:
	if hspeed < 4.0:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col and col is Node3D and col.is_in_group("enemy") and col.has_method("stagger"):
			var d: Vector3 = col.global_position - global_position
			col.stagger(Vector3(d.x, 0.0, d.z).normalized())

# --- Special launcher (E): big hit + knockback ---
func _try_special() -> void:
	if _busy() or _special_cd > 0.0:
		return
	_face_nearest_enemy()
	_special_cd = special_cooldown
	_play_action("Charged_Upward_Slash")
	get_tree().create_timer(0.2).timeout.connect(_apply_special_hit)

func _apply_special_hit() -> void:
	var landed := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node3D) or not enemy.has_method("take_hit"):
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() <= special_range:
			enemy.take_hit(special_damage)
			if enemy.has_method("stagger"):
				enemy.stagger(Vector3(to_enemy.x, 0.0, to_enemy.z).normalized())
			landed = true
	if landed:
		shake(0.15, 0.3)
		if jab_sound:
			jab_sound.play()
		_hitstop(0.09)

# --- Dodge (Q): i-frame dash ---
func _try_dodge() -> void:
	if _dodge_cd > 0.0 or _dodge_time_left > 0.0 or attack_timer > 0.0 or _held_enemy != null:
		return
	var dir := _current_input_dir()
	if dir == Vector3.ZERO:
		var back := mesh.global_transform.basis.z
		dir = Vector3(back.x, 0.0, back.z).normalized()
	_dodge_dir = dir
	_dodge_time_left = dodge_time
	_dodge_cd = dodge_cooldown
	_invuln = dodge_time + 0.1
	if anim.has_animation("Dodge_and_Counter"):
		anim.play("Dodge_and_Counter")

# --- Breach (F): Spartan kick the door open ---
func _try_breach() -> void:
	if _busy():
		return
	if breach_target == null or not is_instance_valid(breach_target):
		return
	_pending_breach = breach_target
	_play_action("Spartan_Kick")
	get_tree().create_timer(0.35).timeout.connect(_finish_breach)

func _finish_breach() -> void:
	if is_instance_valid(_pending_breach) and _pending_breach.has_method("breach"):
		_pending_breach.breach()
		shake(0.12, 0.35)
	_pending_breach = null

# --- Camera shake (forwarded to the follow-camera rig) ---
func shake(amplitude: float = 0.12, duration: float = 0.3) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("shake"):
		cam.shake(amplitude, duration)

func _hero_cam(strength: float = 1.0) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("punch_in"):
		cam.punch_in(strength)

# --- Halligan (signature gear): visible bar in his hand + a heavy sweep (X) ---
func _attach_halligan() -> void:
	var skel := mesh.find_child("Skeleton3D", true, false)
	if not (skel is Skeleton3D):
		return
	var idx: int = skel.find_bone("RightHand")
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_idx = idx
	var h := preload("res://halligan.tscn").instantiate()
	h.position = halligan_offset
	h.rotation = Vector3(deg_to_rad(halligan_rotation_deg.x), deg_to_rad(halligan_rotation_deg.y), deg_to_rad(halligan_rotation_deg.z))
	h.scale = Vector3.ONE * halligan_scale
	att.add_child(h)

func _try_halligan() -> void:
	if _busy() or _halligan_cd > 0.0:
		return
	_halligan_cd = halligan_cooldown
	_face_nearest_enemy()
	_play_action("Charged_Upward_Slash", 1.1)
	get_tree().create_timer(0.28).timeout.connect(_apply_halligan_hit)

func _apply_halligan_hit() -> void:
	var fwd := Vector3(sin(mesh.rotation.y), 0.0, cos(mesh.rotation.y))
	var landed := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.has_method("take_hit"):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() <= halligan_range and fwd.dot(to.normalized()) > -0.1:
			e.take_hit(halligan_damage)
			if e.has_method("stagger"):
				e.stagger(Vector3(to.x, 0.0, to.z).normalized())
			landed = true
	for b in get_tree().get_nodes_in_group("breakable"):
		if b is Node3D and b.has_method("take_hit") and global_position.distance_to(b.global_position) <= halligan_range:
			b.take_hit(3)
			landed = true
	if landed:
		if jab_sound:
			jab_sound.play()
		shake(0.2, 0.3)
		_hero_cam(0.6)
		_hitstop(0.08)

# --- Damage / respawn ---
func heal(amount: int) -> void:
	health = min(health + amount, max_health)

func _face_nearest_enemy() -> void:
	var nearest: Node3D = null
	var best := 4.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D:
			var d := global_position.distance_to(e.global_position)
			if d < best:
				best = d
				nearest = e
	if nearest:
		var to: Vector3 = nearest.global_position - global_position
		mesh.rotation.y = atan2(to.x, to.z)

# --- Stealth takedown: instant brutal kill on an unaware enemy ---
func _find_takedown_target() -> Node3D:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and ("alerted" in e) and not e.alerted:
			if global_position.distance_to(e.global_position) <= 2.3:
				return e
	return null

func _do_takedown(e: Node3D) -> void:
	var to: Vector3 = e.global_position - global_position
	mesh.rotation.y = atan2(to.x, to.z)
	_play_action("Right_Uppercut_from_Guard")
	shake(0.16, 0.25)
	if jab_sound:
		jab_sound.play()
	if e.has_method("take_hit"):
		e.take_hit(999)
	_hero_cam(1.0)
	Game.log_event("stealth takedown")

# --- Grab & throw (breaching bodies) ---
func _try_grab_or_throw() -> void:
	if is_instance_valid(_held_enemy):
		_do_throw()
	else:
		_try_grab()

func _try_grab() -> void:
	if _busy():
		return
	var target := _find_grab_target()
	if target == null:
		return
	_held_enemy = target
	target.grab(self)
	var to: Vector3 = target.global_position - global_position
	mesh.rotation.y = atan2(to.x, to.z)
	_play_action("Push_Forward_and_Stop")

func _do_throw() -> void:
	if not is_instance_valid(_held_enemy):
		_held_enemy = null
		return
	var fwd := Vector3(sin(mesh.rotation.y), 0.0, cos(mesh.rotation.y))
	if _held_enemy.has_method("throw"):
		_held_enemy.throw(fwd, throw_force)
	_held_enemy = null
	_play_action("Charged_Upward_Slash")
	shake(0.2, 0.3)
	_hero_cam(0.7)
	_hitstop(0.08)

func _find_grab_target() -> Node3D:
	var fwd := Vector3(sin(mesh.rotation.y), 0.0, cos(mesh.rotation.y))
	var best := grab_range
	var found: Node3D = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.has_method("grab"):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d <= best and fwd.dot(to.normalized()) > 0.2:
			best = d
			found = e
	return found

func _update_hold() -> void:
	if _held_enemy == null:
		return
	if not is_instance_valid(_held_enemy):
		_held_enemy = null
		return
	var fwd := Vector3(sin(mesh.rotation.y), 0.0, cos(mesh.rotation.y))
	_held_enemy.global_position = global_position + fwd * 1.4 + Vector3(0.0, 1.0, 0.0)

func _hitstop(duration: float = 0.06) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func take_damage(amount: int) -> void:
	if health <= 0 or _invuln > 0.0:
		return
	if _blocking:
		if _block_time <= parry_window:
			_parry()
			return
		amount = int(ceil(amount * block_damage_reduction))
		Game.spawn_hitspark(global_position + Vector3(0.0, 1.2, 0.0))
		if jab_sound:
			jab_sound.play()
	health -= amount
	shake(0.08, 0.2)
	if health <= 0:
		_respawn()

func _parry() -> void:
	shake(0.12, 0.2)
	Game.spawn_hitspark(global_position + Vector3(0.0, 1.4, 0.0))
	if jab_sound:
		jab_sound.play()
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and e.has_method("stagger"):
			var to: Vector3 = e.global_position - global_position
			if to.length() < 2.6:
				e.stagger(Vector3(to.x, 0.0, to.z).normalized())

func _respawn() -> void:
	Game.log_event("player down — respawn (score %d)" % Game.score)
	global_transform = _spawn
	velocity = Vector3.ZERO
	health = max_health

func _play_action(anim_name: String, speed: float = 1.4) -> void:
	if not anim.has_animation(anim_name):
		return
	anim.play(anim_name, -1, speed)
	attack_timer = anim.get_animation(anim_name).length / speed
