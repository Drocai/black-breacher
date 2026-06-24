extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — player controller
#  Built on the SKILL.md source-of-truth baseline:
#    - world-relative movement (camera is fixed, so world == screen)
#    - only the MESH rotates to face travel; the body never spins,
#      so the child camera stays stable (no tank-control feel)
#    - attack_timer interrupt pattern so an action anim wins over
#      walk/idle instead of getting stomped every frame
#  Added this pass: 3-hit punch combo, heavy kick, Spartan door-kick
#  (using the expanded Meshy animation set).
#
#  Controls: WASD/Arrows move - Shift run - Space jump
#            J / Left-click = punch combo - Right-click = heavy kick
#            F = breach a door in range (Spartan kick)
# ============================================================

# --- Tunables ---
@export var speed: float = 4.0
@export var run_speed: float = 7.0
@export var rotation_speed: float = 12.0
@export var jump_velocity: float = 5.0
@export var jab_range: float = 1.9
@export var kick_range: float = 2.4
@export var kick_damage: int = 3

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var anim: AnimationPlayer = $breacher/AnimationPlayer
@onready var mesh: Node3D = $breacher
@onready var camera: Camera3D = $Camera3D
@onready var jab_sound: AudioStreamPlayer = $JabSound

@export var max_health: int = 100

var health: int
var _spawn: Transform3D

var attack_timer: float = 0.0      # locks locomotion anim while an action plays
var _jump_queued: bool = false
var breach_target: Node = null     # set by a door's BreachZone while we're in range
var _pending_breach: Node = null   # door to swing once the strike connects

# Punch combo + the hit that's currently "in flight"
const JAB_CLIPS := ["Right_Jab_from_Guard", "Left_Hook_from_Guard", "Right_Uppercut_from_Guard"]
const JAB_DMG := [1, 1, 2]
var _combo_index: int = 0
var _combo_timer: float = 0.0
var _pending_hit_damage: int = 1
var _pending_hit_range: float = 1.9

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
			KEY_F:
				_try_breach()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_jab()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_kick()

func _physics_process(delta: float) -> void:
	# Gravity keeps him planted
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump only off the floor
	if _jump_queued:
		_jump_queued = false
		if is_on_floor():
			velocity.y = jump_velocity

	# Tick the action lock down
	if attack_timer > 0.0:
		attack_timer -= delta

	# Combo chain window
	if _combo_timer > 0.0:
		_combo_timer -= delta
	else:
		_combo_index = 0

	# --- Movement (world-relative; WASD + arrows) ---
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	input_dir = input_dir.normalized()

	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	var current_speed := run_speed if running else speed

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		# Turn ONLY the model to face travel — atan2(x, z) with NO minus signs
		# (minus signs make him face backward; that bug is documented in SKILL.md)
		var target_angle := atan2(direction.x, direction.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	_update_locomotion_anim(direction != Vector3.ZERO, running)
	move_and_slide()
	_update_shake(delta)

func _update_locomotion_anim(moving: bool, running: bool) -> void:
	# An action anim (jab / breach) wins while the lock is active
	if attack_timer > 0.0:
		return
	# Mid-hop: leave whatever's playing (no dedicated jump clip yet)
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

# --- Punch combo (J / left-click): jab -> hook -> uppercut ---
func _try_jab() -> void:
	if attack_timer > 0.0:
		return
	if _combo_timer <= 0.0:
		_combo_index = 0
	var clip: String = JAB_CLIPS[_combo_index]
	_pending_hit_damage = JAB_DMG[_combo_index]
	_pending_hit_range = jab_range
	_play_action(clip)
	_combo_index = (_combo_index + 1) % JAB_CLIPS.size()
	_combo_timer = attack_timer + 0.5   # window to chain the next punch
	get_tree().create_timer(0.15).timeout.connect(_apply_melee_hit)

# --- Heavy kick (right-click) ---
func _try_kick() -> void:
	if attack_timer > 0.0:
		return
	_pending_hit_damage = kick_damage
	_pending_hit_range = kick_range
	_play_action("High_Kick")
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

# --- Breach (F, when a door reports us in range) ---
func _try_breach() -> void:
	if attack_timer > 0.0:
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
	if health <= 0:
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
