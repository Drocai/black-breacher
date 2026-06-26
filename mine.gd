extends StaticBody3D

# ============================================================
#  BLACK BREACHER — proximity mine (breakable hazard)
#  Sits dormant until a player enters its trigger radius, then arms,
#  blinks faster as the fuse counts down, and detonates — damaging the
#  player and staggering every enemy caught in the blast. The player can
#  also shoot or strike it to pre-detonate it.
# ============================================================

@export var trigger_radius: float = 2.2
@export var fuse: float = 0.5
@export var blast_radius: float = 3.0
@export var blast_damage: int = 30

@onready var mesh: MeshInstance3D = $Mesh
@onready var light: OmniLight3D = $Mesh/Light

var _armed: bool = false
var _detonated: bool = false
var _fuse_left: float = 0.0
var _base_light_energy: float = 1.0

func _ready() -> void:
	add_to_group("breakable")
	if light != null:
		_base_light_energy = light.light_energy

func _physics_process(delta: float) -> void:
	if _detonated:
		return
	if _armed:
		_tick_fuse(delta)
		return
	var nearest: Node3D = _nearest_player()
	if nearest == null:
		return
	var offset: Vector3 = nearest.global_position - global_position
	if offset.length() <= trigger_radius:
		_arm()

func _arm() -> void:
	if _armed or _detonated:
		return
	_armed = true
	_fuse_left = fuse

func _tick_fuse(delta: float) -> void:
	_fuse_left -= delta
	# Blink/pulse faster as the fuse runs out (frequency scales with how
	# little time remains).
	var t: float = clampf(1.0 - (_fuse_left / maxf(fuse, 0.001)), 0.0, 1.0)
	var blink_speed: float = 6.0 + t * 28.0
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * blink_speed * TAU)
	if light != null:
		light.light_energy = _base_light_energy * (0.4 + 1.6 * pulse)
	if mesh != null:
		var s: float = 1.0 + 0.12 * pulse * t
		mesh.scale = Vector3(s, 1.0, s)
	if _fuse_left <= 0.0:
		_explode()

func take_hit(damage: int) -> void:
	# A strike or shot pre-detonates the mine.
	Game.spawn_hitspark(global_position + Vector3(0.0, 0.2, 0.0))
	_explode()

func _explode() -> void:
	if _detonated:
		return
	_detonated = true
	remove_from_group("breakable")
	var center: Vector3 = global_position + Vector3(0.0, 0.2, 0.0)
	for player in get_tree().get_nodes_in_group("player"):
		if not (player is Node3D):
			continue
		var p_offset: Vector3 = player.global_position - global_position
		if p_offset.length() > blast_radius:
			continue
		if player.has_method("take_damage"):
			player.take_damage(blast_damage)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node3D):
			continue
		var e_offset: Vector3 = enemy.global_position - global_position
		if e_offset.length() > blast_radius:
			continue
		if enemy.has_method("take_hit"):
			enemy.take_hit(8)
		if enemy.has_method("stagger"):
			var dir: Vector3 = e_offset
			dir.y = 0.0
			enemy.stagger(dir.normalized())
	Game.spawn_explosion(center)
	Game.spawn_hitspark(center)
	queue_free()

func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_dist: float = INF
	for player in get_tree().get_nodes_in_group("player"):
		if not (player is Node3D):
			continue
		var offset: Vector3 = player.global_position - global_position
		var d: float = offset.length()
		if d < best_dist:
			best_dist = d
			best = player
	return best
