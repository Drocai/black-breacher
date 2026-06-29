extends StaticBody3D

# ============================================================
#  BLACK BREACHER — sniper
#  A stationary, bolted-down enemy that fires a slow but heavy
#  TELEGRAPHED shot. It aims its head at the nearest player,
#  then locks an aim point and projects a thin red beam along
#  the line. The player has the telegraph window to dodge OUT
#  of the line before the shot fires. Heavy damage if it lands.
#  Takes jab/kick hits like any enemy (group "enemy") and
#  topples over on death.
# ============================================================

@export var max_health: int = 4
@export var shoot_range: float = 24.0
@export var telegraph_time: float = 1.1
@export var cooldown: float = 3.0
@export var shot_damage: int = 22

const BEAM_THICKNESS: float = 0.06
const HIT_RADIUS: float = 1.2
const HEAD_HEIGHT: float = 0.7

var health: int
var _down: bool = false
var _telegraphing: bool = false
var _telegraph_t: float = 0.0
var _cooldown_t: float = 0.0
var _locked_point: Vector3 = Vector3.ZERO
var _player: Node3D
var _vis := CharacterVisuals.new()

const WALK_GLB := preload("res://characters/operator_swat_walk.glb")

@export var model_yaw_offset_deg: float = 180.0

@onready var mesh: Node3D = $Mesh
@onready var muzzle: Marker3D = $Mesh/Muzzle
@onready var beam: MeshInstance3D = $Beam

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	beam.visible = false
	_vis.setup(mesh, WALK_GLB, model_yaw_offset_deg, Color(1, 1, 1, 1))

func _physics_process(delta: float) -> void:
	if _down:
		return
	# Bolted-down operator: hold a standing ready-stance (no locomotion).
	_vis.drive(Vector3.ZERO, 1.0, delta, false)
	if _cooldown_t > 0.0:
		_cooldown_t -= delta

	var p: Node3D = _get_player()

	if _telegraphing:
		_aim_beam_at(_locked_point)
		_telegraph_t -= delta
		if _telegraph_t <= 0.0:
			_fire(p)
		return

	if p == null:
		return

	var to_player: Vector3 = p.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist < 0.001:
		return
	var dir: Vector3 = to_player.normalized()

	# Swivel the operator to track the player.
	mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(dir.x, dir.z), 6.0 * delta)

	if dist <= shoot_range and _cooldown_t <= 0.0:
		_begin_telegraph(p)

func _begin_telegraph(p: Node3D) -> void:
	_telegraphing = true
	_telegraph_t = telegraph_time
	# Lock the aim point at the player's current position. Keeping it
	# fixed lets the player dodge out of the line during the telegraph.
	_locked_point = p.global_position
	beam.visible = true
	_aim_beam_at(_locked_point)

func _aim_beam_at(target: Vector3) -> void:
	var origin: Vector3 = muzzle.global_position
	var to_target: Vector3 = target - origin
	var length: float = to_target.length()
	if length < 0.001:
		beam.visible = false
		return
	# Position the beam at the midpoint and orient it toward the target.
	var mid: Vector3 = origin + to_target * 0.5
	beam.global_position = mid
	beam.look_at(target, Vector3.UP)
	# look_at points -Z at the target; the BoxMesh is 1 unit long on Z,
	# so scale Z to the full distance and keep it thin on X/Y.
	beam.scale = Vector3(BEAM_THICKNESS, BEAM_THICKNESS, length)

func _fire(p: Node3D) -> void:
	_telegraphing = false
	_cooldown_t = cooldown
	beam.visible = false

	var impact: Vector3 = _locked_point
	if p != null:
		var diff: Vector3 = p.global_position - _locked_point
		diff.y = 0.0
		if diff.length() <= HIT_RADIUS:
			if p.has_method("take_damage"):
				p.take_damage(shot_damage)
			impact = p.global_position
	Game.spawn_hitspark(impact)

func _get_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var a: Array = get_tree().get_nodes_in_group("player")
	_player = a[0] if a.size() > 0 else null
	return _player

func take_hit(damage: int) -> void:
	if _down:
		return
	health -= damage
	_flash()
	Game.spawn_damage_number(global_position + Vector3(0.0, 1.9, 0.0), damage)
	Game.spawn_hitspark(muzzle.global_position)
	if health <= 0:
		Game.add_kill()
		_die()

func stagger(_dir: Vector3) -> void:
	# Bolted down — it doesn't get knocked around, just a tiny shudder.
	if _down:
		return
	_flash()

func is_staggered() -> bool:
	return false

func _flash() -> void:
	var t: Tween = create_tween()
	t.tween_property(mesh, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
	t.tween_property(mesh, "scale", Vector3.ONE, 0.1)
	_vis.pulse(self, Color(1.0, 0.15, 0.1), 3.0, 0.02, 0.16)

func _die() -> void:
	_down = true
	_telegraphing = false
	beam.visible = false
	remove_from_group("enemy")
	$CollisionShape3D.set_deferred("disabled", true)
	_vis.pause()
	Game.spawn_hitspark(muzzle.global_position)
	var t: Tween = create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(80.0), 0.4).set_ease(Tween.EASE_IN)
	t.tween_interval(0.8)
	t.tween_callback(queue_free)
