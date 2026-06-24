extends CharacterBody3D

# ============================================================
#  BLACK BREACHER — player controller
#  Built on the SKILL.md source-of-truth baseline:
#    - world-relative movement (camera is fixed, so world == screen)
#    - only the MESH rotates to face travel; the body never spins,
#      so the child camera stays stable (no tank-control feel)
#    - attack_timer interrupt pattern so an action anim wins over
#      walk/idle instead of getting stomped every frame
#  Added this pass: jump, breach action, jab hit-detection, groups.
#
#  Controls: WASD/Arrows move - Shift run - Space jump
#            J or Left-click jab - F breach a door in range
# ============================================================

# --- Tunables ---
@export var speed: float = 4.0
@export var run_speed: float = 7.0
@export var rotation_speed: float = 12.0
@export var jump_velocity: float = 5.0
@export var jab_range: float = 1.9
@export var jab_damage: int = 1

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var anim: AnimationPlayer = $breacher/AnimationPlayer
@onready var mesh: Node3D = $breacher

var attack_timer: float = 0.0      # locks locomotion anim while an action plays
var _jump_queued: bool = false
var breach_target: Node = null     # set by a door's BreachZone while we're in range
var _pending_breach: Node = null   # door to swing once the strike connects

func _ready() -> void:
	add_to_group("player")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				_jump_queued = true
			KEY_J:
				_try_jab()
			KEY_F:
				_try_breach()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_jab()

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

# --- Jab (J / left-click) ---
func _try_jab() -> void:
	if attack_timer > 0.0:
		return
	_play_action("Right_Jab_from_Guard")
	# Land the hit partway through the swing
	get_tree().create_timer(0.15).timeout.connect(_apply_jab_hit)

func _apply_jab_hit() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node3D) or not enemy.has_method("take_hit"):
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() <= jab_range:
			enemy.take_hit(jab_damage)

# --- Breach (F, when a door reports us in range) ---
func _try_breach() -> void:
	if attack_timer > 0.0:
		return
	if breach_target == null or not is_instance_valid(breach_target):
		return
	_pending_breach = breach_target
	_play_action("Push_Forward_and_Stop")
	get_tree().create_timer(0.25).timeout.connect(_finish_breach)

func _finish_breach() -> void:
	if is_instance_valid(_pending_breach) and _pending_breach.has_method("breach"):
		_pending_breach.breach()
	_pending_breach = null

func _play_action(anim_name: String) -> void:
	if not anim.has_animation(anim_name):
		return
	anim.play(anim_name)
	attack_timer = anim.get_animation(anim_name).length
