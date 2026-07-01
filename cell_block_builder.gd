extends Node3D

# ============================================================
#  BLACK BREACHER — cell-block interior
#  A row of barred holding cells down each side of the hall,
#  leaving a central corridor. Set-dressing + cover; the nav
#  baker walks the collidable CSG so cells become obstacles and
#  fighting funnels down the corridor. Tune to the hall via exports.
# ============================================================

@export var wall_x: float = 6.85      # inner face of the side walls (+/-)
@export var z_start: float = -7.0
@export var z_end: float = -21.0
@export var cell_count: int = 4
@export var cell_depth: float = 1.8

var _bar: StandardMaterial3D
var _wall: StandardMaterial3D
var _bunk: StandardMaterial3D

func _ready() -> void:
	_bar = _mat(Color(0.10, 0.11, 0.13), 0.4, 0.8)
	_wall = _mat(Color(0.26, 0.27, 0.30), 0.9, 0.0)
	_bunk = _mat(Color(0.20, 0.22, 0.26), 0.8, 0.1)
	_build_side(-1)
	_build_side(1)
	_witness(Vector3(0.0, 0.0, -25.4))

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

# The witness you're here to pull out — a seated figure in the back holding
# cell, lit so "reach the witness" reads at a glance.
func _witness(pos: Vector3) -> void:
	var jump := _mat(Color(0.78, 0.42, 0.16), 0.85, 0.0)   # orange jumpsuit
	var skin := _mat(Color(0.5, 0.38, 0.3), 0.7, 0.0)
	_box(Vector3(0.5, 0.6, 0.34), pos + Vector3(0.0, 0.95, 0.0), jump, false)     # torso
	_box(Vector3(0.28, 0.28, 0.28), pos + Vector3(0.0, 1.42, 0.02), skin, false)  # head
	_box(Vector3(0.5, 0.24, 0.5), pos + Vector3(0.0, 0.58, 0.25), jump, false)    # thighs
	_box(Vector3(0.46, 0.5, 0.22), pos + Vector3(0.0, 0.34, 0.52), jump, false)   # shins
	_box(Vector3(0.7, 0.4, 0.8), pos + Vector3(0.0, 0.2, 0.15), _bunk, false)     # bench
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0.0, 2.2, 0.6)
	l.light_color = Color(0.95, 0.85, 0.7)
	l.light_energy = 1.6
	l.omni_range = 4.5
	add_child(l)

func _build_side(sgn: int) -> void:
	var x := wall_x * sgn
	var span := z_end - z_start
	var step := span / float(cell_count)
	var front_x := x - cell_depth * sgn    # corridor-facing edge of the cells
	# Dividers between cells (+ the two end caps).
	for i in range(cell_count + 1):
		var z0 := z_start + step * i
		_box(Vector3(cell_depth, 2.8, 0.12), Vector3(x - cell_depth * 0.5 * sgn, 1.4, z0), _wall)
	# Top rail running the length of the cell fronts.
	_box(Vector3(0.1, 0.14, span), Vector3(front_x, 2.6, (z_start + z_end) * 0.5), _bar, false)
	for i in range(cell_count):
		var z0 := z_start + step * i
		var zc := z0 + step * 0.5
		# Bunk inside the cell.
		_box(Vector3(0.8, 0.4, 1.8), Vector3(x - 0.75 * sgn, 0.4, zc), _bunk, false)
		# Vertical bars across the front, leaving a centered door gap.
		var bz := z0 + 0.26
		while bz < z0 + step - 0.12:
			if absf(bz - zc) > 0.55:
				_box(Vector3(0.08, 2.55, 0.08), Vector3(front_x, 1.28, bz), _bar)
			bz += 0.30
		# A dim cell light.
		var l := OmniLight3D.new()
		l.position = Vector3(x - cell_depth * 0.6 * sgn, 2.4, zc)
		l.light_color = Color(0.75, 0.8, 0.92)
		l.light_energy = 1.6
		l.omni_range = 4.4
		add_child(l)
