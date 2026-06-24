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
# ============================================================

# --- Movement tunables ---
@export var speed: float = 4.0
@export var run_speed: float = 7.0
@export var rotation_speed: float = 12.0
@export var jump_velocity: float = 5.0

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

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var anim: AnimationPlayer = $breacher/AnimationPlayer
@onready var mesh: Node3D = $breacher
@onready var camera: Camera3D = $Camera3D
@onready var jab_sound: AudioStreamPlayer = $JabSound

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

# Camera shake
var _cam_base: Transform3D
var _shake_time: float = 0.0
var _shake_dur: float = 0.0
var _shake_amp: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_cam_base = camera.transform
	health = max_health
	_spawn = global_transform

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
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_jab()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_kick()

func _physics_process(delta: float) -> void:
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
		_update_shake(delta)
		return

	# --- Movement (world-relative; WASD + arrows) ---
	var direction := _current_input_dir()
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	var current_speed := run_speed if running else speed

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		var target_angle := atan2(direction.x, direction.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	_update_locomotion_anim(direction != Vector3.ZERO, running)
	move_and_slide()
	_update_shake(delta)

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

func _update_locomotion_anim(moving: bool, running: bool) -> void:
	if attack_timer > 0.0:
		return
	if not is_on_floor():
		return
	if moving:
		if running:
			if anim.current_animation != "Running":
				anim.play("Running")
		elif anim.current_animation != "Casual_Walk":
			anim.play("Casual_Walk")
	elif anim.current_animation != "Axe_Breathe_and_Look_Around":
		anim.play("Axe_Breathe_and_Look_Around")

func _busy() -> bool:
	return attack_timer > 0.0 or _dodge_time_left > 0.0

# --- Punch combo (J / left-click) ---
func _try_jab() -> void:
	if _busy():
		return
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
			enemy.take_hit(_pending_hit_damage)
			landed = true
	if landed and jab_sound:
		jab_sound.play()

# --- Special launcher (E): big hit + knockback ---
func _try_special() -> void:
	if _busy() or _special_cd > 0.0:
		return
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

# --- Dodge (Q): i-frame dash ---
func _try_dodge() -> void:
	if _dodge_cd > 0.0 or _dodge_time_left > 0.0 or attack_timer > 0.0:
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

# --- Camera shake ---
func shake(amplitude: float = 0.12, duration: float = 0.3) -> void:
	_shake_amp = amplitude
	_shake_dur = duration
	_shake_time = duration

func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		camera.transform = _cam_base
		return
	_shake_time -= delta
	var falloff := _shake_time / _shake_dur
	var offset := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_amp * falloff
	camera.transform = _cam_base
	camera.transform.origin += offset

# --- Damage / respawn ---
func take_damage(amount: int) -> void:
	if health <= 0 or _invuln > 0.0:
		return
	health -= amount
	shake(0.08, 0.2)
	if health <= 0:
		_respawn()

func _respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	health = max_health

func _play_action(anim_name: String) -> void:
	if not anim.has_animation(anim_name):
		return
	anim.play(anim_name)
	attack_timer = anim.get_animation(anim_name).length
