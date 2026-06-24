extends CharacterBody3D

# --- Tunable settings ---
@export var speed: float = 4.0
@export var run_speed: float = 7.0
@export var rotation_speed: float = 10.0

# Gravity pulled from project settings so he falls naturally
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Grab the AnimationPlayer that came in with the model
@onready var anim: AnimationPlayer = $breacher/AnimationPlayer

func _physics_process(delta: float) -> void:
	# Apply gravity so he stays planted on the floor
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Read WASD / arrow keys
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed: float = run_speed if Input.is_key_pressed(KEY_SHIFT) else speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		# Turn him to face the way he's moving
		var target_angle: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		# Play the walk
		if anim.current_animation != "Casual_Walk":
			anim.play("Casual_Walk")
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		# Idle when standing still
		if anim.current_animation != "Axe_Breathe_and_Look_Around":
			anim.play("Axe_Breathe_and_Look_Around")

	# Punch on Spacebar / J — interrupts and throws the jab
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_J):
		anim.play("Right_Jab_from_Guard")

	move_and_slide()
