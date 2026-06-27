extends Camera3D

# ============================================================
#  BLACK BREACHER — follow camera rig
#  Smoothly tracks the player from a fixed angle with a little
#  look-ahead in the direction of movement, plus decaying shake.
#  Trackpad-friendly: no mouse-look, fully automatic.
# ============================================================

@export var offset: Vector3 = Vector3(0, 2.9, 5.2)
@export var follow_lerp: float = 9.0
@export var look_ahead: float = 1.4
@export var pitch_degrees: float = -22.0
@export var punch_amount: float = 0.32   # how far the hero punch-in pulls the camera in
@export var hero_drop: float = 1.3       # how far the camera dips to look UP at him
@export var hero_pitch_up: float = 7.0   # extra up-tilt (deg) during a hero beat
@export var fp_head_height: float = 2.9   # first-person eye height — high up = you feel huge
@export var fp_forward: float = 0.35      # nudge the FP cam forward of the head
@export var fp_look_down: float = 0.32    # tilt the gaze DOWN at the small enemies below
@export var fp_bob_amount: float = 0.14   # heavy weight-bob travel while moving

var first_person: bool = false
var _fp_bob_t: float = 0.0

var _player: Node3D
var _shake_t: float = 0.0
var _shake_dur: float = 0.0
var _shake_amp: float = 0.0
var _punch: float = 0.0   # 1 -> 0, decays after a finisher/takedown
var _fov_base: float = 75.0
var _fov_kick_t: float = 0.0
var _fov_kick_dur: float = 0.0
var _fov_kick_amp: float = 0.0
var _hero_t: float = 0.0   # low-angle "look up at his size" emphasis
var _hero_dur: float = 0.0

func _ready() -> void:
	add_to_group("camera")
	rotation = Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0)
	_fov_base = fov
	var p := _get_player()
	if p:
		global_position = p.global_position + offset

func _physics_process(delta: float) -> void:
	var p := _get_player()
	if p == null:
		return

	if first_person:
		_update_first_person(p, delta)
		return

	var lead := Vector3.ZERO
	if "velocity" in p:
		var flat := Vector3(p.velocity.x, 0.0, p.velocity.z)
		lead = flat.limit_length(8.0) / 8.0 * look_ahead

	# Low-angle "look up at him" emphasis during signature beats.
	var hero := 0.0
	if _hero_t > 0.0:
		_hero_t -= delta
		hero = clampf(_hero_t / maxf(_hero_dur, 0.001), 0.0, 1.0)

	var off: Vector3 = offset * (1.0 - punch_amount * _punch)
	off.y -= hero_drop * hero
	var target: Vector3 = p.global_position + off + lead
	var t: float = 1.0 - exp(-follow_lerp * delta)
	global_position = global_position.lerp(target, t)
	_punch = move_toward(_punch, 0.0, delta / 0.45)

	rotation.x = deg_to_rad(pitch_degrees + hero_pitch_up * hero)

	# FOV punch-kick (widens then settles) for high-impact moments.
	if _fov_kick_t > 0.0:
		_fov_kick_t -= delta
		fov = _fov_base + _fov_kick_amp * clampf(_fov_kick_t / maxf(_fov_kick_dur, 0.001), 0.0, 1.0)
	else:
		fov = _fov_base

	if _shake_t > 0.0:
		_shake_t -= delta
		var f: float = _shake_t / _shake_dur
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_amp * f

func set_first_person(v: bool) -> void:
	first_person = v

# First-person view: ride the character's head, look where he faces. Shake +
# FOV-kick still land (dampened) so impacts read; default stays third-person.
func _update_first_person(p: Node3D, delta: float) -> void:
	var yaw: float = 0.0
	if "mesh" in p and p.mesh != null:
		yaw = p.mesh.rotation.y
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))

	# Heavy weight-bob: a slow, deep vertical sway + roll while he lumbers, so
	# his mass reads in first-person even without a body in view.
	var hspeed: float = 0.0
	if "velocity" in p:
		hspeed = Vector2(p.velocity.x, p.velocity.z).length()
	var moving: float = clampf(hspeed / 6.0, 0.0, 1.0)
	_fp_bob_t += delta * (5.0 + hspeed * 0.5)
	var bob_y: float = sin(_fp_bob_t) * fp_bob_amount * moving
	var roll: float = sin(_fp_bob_t * 0.5) * 0.025 * moving

	var head: Vector3 = p.global_position + Vector3(0.0, fp_head_height + bob_y, 0.0) + fwd * fp_forward
	var t: float = 1.0 - exp(-follow_lerp * 2.0 * delta)
	global_position = global_position.lerp(head, t)
	# Look forward AND down — enemies sit far below his eyeline, selling height.
	look_at(global_position + fwd + Vector3(0.0, -fp_look_down, 0.0), Vector3.UP)
	rotation.z = roll

	if _fov_kick_t > 0.0:
		_fov_kick_t -= delta
		fov = _fov_base + _fov_kick_amp * clampf(_fov_kick_t / maxf(_fov_kick_dur, 0.001), 0.0, 1.0)
	else:
		fov = _fov_base

	if _shake_t > 0.0:
		_shake_t -= delta
		var f: float = _shake_t / _shake_dur
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_amp * f * 0.5

func shake(amplitude: float = 0.12, duration: float = 0.3) -> void:
	_shake_amp = amplitude
	_shake_dur = duration
	_shake_t = duration

# Cinematic punch-in for finishers / takedowns / throws.
func punch_in(strength: float = 1.0) -> void:
	_punch = clampf(strength, 0.0, 1.0)
	shake(0.18, 0.35)

# Briefly widen FOV then settle — a visceral "whoomph" on big hits.
func fov_kick(amount: float = 6.0, duration: float = 0.35) -> void:
	_fov_kick_amp = amount
	_fov_kick_dur = duration
	_fov_kick_t = duration

# Dip low and tilt up to read his full height on a signature beat.
func hero_angle(duration: float = 0.6) -> void:
	_hero_dur = duration
	_hero_t = maxf(_hero_t, duration)

func _get_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var a := get_tree().get_nodes_in_group("player")
	_player = a[0] if a.size() > 0 else null
	return _player
