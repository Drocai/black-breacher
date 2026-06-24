extends Camera3D

# ============================================================
#  BLACK BREACHER — follow camera rig
#  Smoothly tracks the player from a fixed angle with a little
#  look-ahead in the direction of movement, plus decaying shake.
#  Trackpad-friendly: no mouse-look, fully automatic.
# ============================================================

@export var offset: Vector3 = Vector3(0, 3.4, 5.8)
@export var follow_lerp: float = 9.0
@export var look_ahead: float = 1.4
@export var pitch_degrees: float = -28.0

var _player: Node3D
var _shake_t: float = 0.0
var _shake_dur: float = 0.0
var _shake_amp: float = 0.0

func _ready() -> void:
	add_to_group("camera")
	rotation = Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0)
	var p := _get_player()
	if p:
		global_position = p.global_position + offset

func _physics_process(delta: float) -> void:
	var p := _get_player()
	if p == null:
		return

	var lead := Vector3.ZERO
	if "velocity" in p:
		var flat := Vector3(p.velocity.x, 0.0, p.velocity.z)
		lead = flat.limit_length(8.0) / 8.0 * look_ahead

	var target: Vector3 = p.global_position + offset + lead
	var t: float = 1.0 - exp(-follow_lerp * delta)
	global_position = global_position.lerp(target, t)

	if _shake_t > 0.0:
		_shake_t -= delta
		var f: float = _shake_t / _shake_dur
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_amp * f

func shake(amplitude: float = 0.12, duration: float = 0.3) -> void:
	_shake_amp = amplitude
	_shake_dur = duration
	_shake_t = duration

func _get_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var a := get_tree().get_nodes_in_group("player")
	_player = a[0] if a.size() > 0 else null
	return _player
