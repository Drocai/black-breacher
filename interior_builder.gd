extends Node3D

# ============================================================
#  BLACK BREACHER — procedural interior structure
#  Turns a bare breach room into a warehouse floor: double-sided
#  shelving racks (forming lanes), a manager's office cubicle with
#  a doorway, hung work-lights, and cargo. Set-dressing + cover.
#  Built in code; the nav baker walks all collidable CSG, so the
#  racks/office bake into the navmesh and enemies path the lanes.
#  Keep racks against the side walls so the central lane stays wide
#  (agent radius 0.5 -> openings stay >= 1.5 m).
# ============================================================

@export var frame_tint: Color = Color(0.18, 0.19, 0.22)
@export var crate_tint: Color = Color(0.45, 0.32, 0.18)
@export var office_glow: Color = Color(0.4, 0.8, 0.95)
@export var light_color: Color = Color(1.0, 0.85, 0.6)

var _frame: StandardMaterial3D
var _board: StandardMaterial3D
var _crate: StandardMaterial3D
var _screen: StandardMaterial3D
var _lamp: StandardMaterial3D

func _ready() -> void:
	_frame = _mat(frame_tint, 0.5, 0.6)
	_board = _mat(Color(0.30, 0.22, 0.14), 0.85, 0.0)
	_crate = _mat(crate_tint, 0.8, 0.0)
	_screen = _mat(Color(0.1, 0.35, 0.45), 0.35, 0.0)
	_screen.emission_enabled = true
	_screen.emission = office_glow
	_screen.emission_energy_multiplier = 2.5
	_lamp = _mat(Color(1.0, 0.9, 0.7), 0.5, 0.2)
	_lamp.emission_enabled = true
	_lamp.emission = light_color
	_lamp.emission_energy_multiplier = 5.0

	# Racks hug the side walls, leaving a wide central lane.
	_rack(Vector3(-4.2, 0.0, -13.0), 6.0)
	_rack(Vector3(4.2, 0.0, -12.0), 5.5)
	_office(Vector3(3.3, 0.0, -6.8))
	_hang_light(Vector3(0.0, 3.7, -8.5), light_color, 2.4)
	_hang_light(Vector3(-1.5, 3.7, -14.5), Color(1.0, 0.8, 0.55), 2.2)

func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

func _box(size: Vector3, pos: Vector3, mat: Material, collide: bool = true, yrot: float = 0.0) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.rotation.y = deg_to_rad(yrot)
	b.material = mat
	b.use_collision = collide
	add_child(b)
	return b

func _rack(center: Vector3, length: float) -> void:
	var depth := 0.9
	var hi := 2.7
	# Upright posts.
	for sx in [-depth * 0.5, depth * 0.5]:
		for sz in [-length * 0.5 + 0.2, length * 0.5 - 0.2]:
			_box(Vector3(0.12, hi, 0.12), center + Vector3(sx, hi * 0.5, sz), _frame)
	# Shelf boards (no collision; the posts carry the nav footprint).
	for sy in [0.7, 1.5, 2.3]:
		_box(Vector3(depth, 0.06, length), center + Vector3(0.0, sy, 0.0), _frame, false)
	# Cargo on the shelves.
	for s in [Vector3(0, 0.95, -length * 0.3), Vector3(0, 1.75, length * 0.18), Vector3(0, 1.75, -length * 0.32), Vector3(0, 0.95, length * 0.28)]:
		_box(Vector3(0.7, 0.5, 0.7), center + s, _crate, false)

func _office(corner: Vector3) -> void:
	var h := 2.4
	_box(Vector3(3.0, h, 0.12), corner + Vector3(0.0, h * 0.5, -1.4), _frame)   # back wall
	_box(Vector3(0.12, h, 2.8), corner + Vector3(1.4, h * 0.5, 0.0), _frame)    # side wall; doorway on the open side
	_box(Vector3(1.4, 0.8, 0.7), corner + Vector3(0.3, 0.4, -1.0), _board)      # desk
	_box(Vector3(0.7, 0.45, 0.06), corner + Vector3(0.3, 1.05, -1.25), _screen, false)  # monitor
	var lamp := OmniLight3D.new()
	lamp.position = corner + Vector3(0.3, 1.5, -1.0)
	lamp.light_color = office_glow
	lamp.light_energy = 1.3
	lamp.omni_range = 4.5
	add_child(lamp)

func _hang_light(pos: Vector3, col: Color, energy: float) -> void:
	_box(Vector3(0.04, 0.6, 0.04), pos + Vector3(0.0, 0.35, 0.0), _frame, false)  # stem
	_box(Vector3(0.55, 0.12, 0.55), pos, _lamp, false)                            # fixture
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0.0, -0.2, 0.0)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = 9.0
	add_child(l)
