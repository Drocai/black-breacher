extends Node3D

# ============================================================
#  BLACK BREACHER — procedural exterior "site"
#  Turns the barren approach in front of a breach building into a
#  believable fenced lot: perimeter walls, cover, a parked vehicle,
#  and exterior flood lighting. Set-dressing + player cover only —
#  enemies spawn INSIDE, so this never touches their navigation.
#  Built in code so the scene file stays small and the layout is
#  tunable right here. Drop a `Site (Node3D + this script)` into an
#  arena; tune `front_z` to the building's front wall if it differs.
# ============================================================

@export var front_z: float = -5.0          # building front wall (lot opens onto it)
@export var concrete_tint: Color = Color(0.34, 0.32, 0.30)
@export var flood_color: Color = Color(0.8, 0.85, 1.0)

var _concrete: StandardMaterial3D
var _metal: StandardMaterial3D
var _rust: StandardMaterial3D
var _lamp: StandardMaterial3D

func _ready() -> void:
	_concrete = _mat(concrete_tint, 0.92, 0.0)
	_metal = _mat(Color(0.12, 0.13, 0.15), 0.45, 0.7)
	_rust = _mat(Color(0.30, 0.17, 0.10), 0.85, 0.1)
	_lamp = _mat(Color(1.0, 0.85, 0.6), 0.6, 0.0)
	_lamp.emission_enabled = true
	_lamp.emission = Color(1.0, 0.8, 0.5)
	_lamp.emission_energy_multiplier = 6.0

	_build_perimeter()
	_build_cover()
	_build_vehicle(Vector3(-8.0, 0.0, 3.5), 24.0)
	_build_lights()

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

func _build_perimeter() -> void:
	var h := 3.4
	var y := h * 0.5
	var back_z := front_z + 16.0
	# Back wall (behind spawn) split for a gate gap.
	_box(Vector3(9.0, h, 0.4), Vector3(-6.5, y, back_z), _concrete)
	_box(Vector3(9.0, h, 0.4), Vector3(6.5, y, back_z), _concrete)
	# Side walls.
	_box(Vector3(0.4, h, 16.4), Vector3(-13.0, y, front_z + 8.0), _concrete)
	_box(Vector3(0.4, h, 16.4), Vector3(13.0, y, front_z + 8.0), _concrete)
	# Short returns flanking the building face (leave the entry door clear).
	_box(Vector3(7.0, h, 0.4), Vector3(-9.0, y, front_z), _concrete)
	_box(Vector3(7.0, h, 0.4), Vector3(9.0, y, front_z), _concrete)

func _build_cover() -> void:
	var bar := Vector3(2.2, 0.95, 0.6)
	# Cover in the visible approach (between spawn and door), off the door lane.
	_box(bar, Vector3(-3.6, 0.47, -1.5), _concrete, true, 16)
	_box(bar, Vector3(4.2, 0.47, -1.0), _concrete, true, -22)
	_box(bar, Vector3(-5.5, 0.47, 1.8), _concrete, true, 74)
	# Crate stacks in a corner.
	_box(Vector3(1.0, 1.0, 1.0), Vector3(8.4, 0.5, 3.4), _rust)
	_box(Vector3(1.0, 1.0, 1.0), Vector3(9.1, 0.5, 4.0), _rust)
	_box(Vector3(0.9, 0.9, 0.9), Vector3(8.6, 1.45, 3.6), _rust, false)
	# Dumpster against the right wall.
	_box(Vector3(2.6, 1.3, 1.4), Vector3(11.2, 0.65, 5.5), _metal)

func _build_vehicle(pos: Vector3, yrot: float) -> void:
	var body := _box(Vector3(2.0, 0.7, 4.5), pos + Vector3(0, 0.55, 0), _metal, true, yrot)
	body.name = "CarBody"
	var cabin := _box(Vector3(1.85, 0.62, 2.3), pos + Vector3(0, 1.18, 0), _metal, false, yrot)
	cabin.name = "CarCabin"

func _build_lights() -> void:
	_pole_lamp(Vector3(-11.6, 0.0, front_z + 14.0), Color(1.0, 0.78, 0.45), 7.0, 4.6)
	# Entry floodlight washing the door from outside.
	var fl := OmniLight3D.new()
	fl.position = Vector3(0.0, 3.6, front_z + 1.8)
	fl.light_color = flood_color
	fl.light_energy = 3.0
	fl.omni_range = 11.0
	add_child(fl)

func _pole_lamp(base: Vector3, col: Color, energy: float, h: float) -> void:
	_box(Vector3(0.16, h, 0.16), base + Vector3(0, h * 0.5, 0), _metal)
	_box(Vector3(0.7, 0.25, 0.5), base + Vector3(0.0, h, 0.4), _lamp, false)
	var l := OmniLight3D.new()
	l.position = base + Vector3(0.0, h - 0.3, 0.6)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = 15.0
	add_child(l)
