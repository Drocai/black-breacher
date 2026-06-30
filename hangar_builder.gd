extends Node3D

# ============================================================
#  BLACK BREACHER — hangar / cargo interior
#  Shipping containers as heavy cover, crate stacks, fuel-drum
#  clusters and work-lights for the hangar finale. Set-dressing +
#  cover; nav baker walks the collidable CSG so cargo becomes
#  obstacles. Placed in the z-gaps between spawn points so nothing
#  traps a spawner. Tuned for the wide hall (x +/- 8).
# ============================================================

@export var container_a: Color = Color(0.5, 0.34, 0.18)
@export var container_b: Color = Color(0.22, 0.34, 0.40)
@export var light_color: Color = Color(1.0, 0.74, 0.42)

var _ca: StandardMaterial3D
var _cb: StandardMaterial3D
var _end: StandardMaterial3D
var _crate: StandardMaterial3D
var _drum: StandardMaterial3D
var _hot: StandardMaterial3D
var _lamp: StandardMaterial3D

func _ready() -> void:
	_ca = _mat(container_a, 0.8, 0.2)
	_cb = _mat(container_b, 0.8, 0.2)
	_end = _mat(Color(0.12, 0.12, 0.14), 0.7, 0.4)
	_crate = _mat(Color(0.42, 0.30, 0.16), 0.85, 0.0)
	_drum = _mat(Color(0.55, 0.45, 0.12), 0.5, 0.3)
	_hot = _mat(Color(0.7, 0.15, 0.1), 0.6, 0.2)
	_lamp = _mat(Color(1.0, 0.9, 0.7), 0.5, 0.2)
	_lamp.emission_enabled = true
	_lamp.emission = light_color
	_lamp.emission_energy_multiplier = 5.0

	_container(Vector3(-6.0, 0.0, -17.0), Vector3(2.4, 2.8, 6.0), _ca)
	_container(Vector3(6.0, 0.0, -17.5), Vector3(2.4, 2.8, 5.0), _cb)
	# A stacked container near the back-left wall (clear of spawns at z -24).
	_container(Vector3(-6.4, 2.85, -29.0), Vector3(2.4, 2.6, 5.0), _cb)
	_crate_stack(Vector3(6.6, 0.0, -8.0))
	_crate_stack(Vector3(-6.6, 0.0, -8.0))
	_crate_stack(Vector3(0.0, 0.0, -20.5))
	_drums(Vector3(6.9, 0.0, -14.0))
	_drums(Vector3(-6.9, 0.0, -21.0))
	_hang_light(Vector3(0.0, 3.7, -13.0))
	_hang_light(Vector3(0.0, 3.7, -22.0))

func _mat(c: Color, r: float, m: float) -> StandardMaterial3D:
	var x := StandardMaterial3D.new()
	x.albedo_color = c
	x.roughness = r
	x.metallic = m
	return x

func _box(size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material = mat
	b.use_collision = collide
	add_child(b)
	return b

func _container(pos: Vector3, size: Vector3, mat: Material) -> void:
	_box(size, pos + Vector3(0, size.y * 0.5, 0), mat)
	# Darker door end-caps.
	_box(Vector3(size.x * 0.96, size.y * 0.94, 0.12), pos + Vector3(0, size.y * 0.5, size.z * 0.5), _end, false)
	_box(Vector3(size.x * 0.96, size.y * 0.94, 0.12), pos + Vector3(0, size.y * 0.5, -size.z * 0.5), _end, false)

func _crate_stack(base: Vector3) -> void:
	_box(Vector3(1.1, 1.1, 1.1), base + Vector3(0, 0.55, 0), _crate)
	_box(Vector3(1.1, 1.1, 1.1), base + Vector3(0.5, 0.55, 0.7), _crate)
	_box(Vector3(1.0, 1.0, 1.0), base + Vector3(0.15, 1.6, 0.2), _crate, false)

func _one_drum(pos: Vector3, mat: Material) -> void:
	var c := CSGCylinder3D.new()
	c.radius = 0.4
	c.height = 1.1
	c.position = pos + Vector3(0, 0.55, 0)
	c.material = mat
	c.use_collision = true
	add_child(c)

func _drums(base: Vector3) -> void:
	_one_drum(base, _drum_or_hot(0))
	_one_drum(base + Vector3(0.85, 0, 0.2), _drum_or_hot(1))
	_one_drum(base + Vector3(0.4, 0, 0.85), _drum_or_hot(2))

func _drum_or_hot(i: int) -> Material:
	return _hot if i == 1 else _drum

func _hang_light(pos: Vector3) -> void:
	_box(Vector3(0.04, 0.6, 0.04), pos + Vector3(0, 0.35, 0), _end, false)
	_box(Vector3(0.6, 0.12, 0.6), pos, _lamp, false)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, -0.2, 0)
	l.light_color = light_color
	l.light_energy = 2.6
	l.omni_range = 11.0
	add_child(l)
