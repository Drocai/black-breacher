extends Node3D

# ============================================================
#  BLACK BREACHER — title-screen 3D stage
#  The Breacher stands idling in a moody spotlight with a breach
#  door behind him, while the menu sits to the left. Purely a
#  cosmetic backdrop, built in code so it's easy to tune.
# ============================================================

func _ready() -> void:
	# Moody, foggy dark environment.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.5)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.04, 0.06)
	env.fog_density = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Floor.
	_box(Vector3(24, 0.4, 24), Vector3(0, -0.2, 0), Color(0.06, 0.06, 0.07), 0.9)
	# A wall + breach door behind him for context.
	_box(Vector3(9, 4.4, 0.3), Vector3(1.6, 2.2, -2.4), Color(0.15, 0.14, 0.13), 0.95)
	_box(Vector3(1.25, 2.5, 0.16), Vector3(1.6, 1.25, -2.24), Color(0.32, 0.19, 0.12), 0.8)
	# A warm doorway glow behind the door.
	var dg := OmniLight3D.new()
	dg.position = Vector3(1.6, 1.4, -2.7)
	dg.light_color = Color(1.0, 0.7, 0.4)
	dg.light_energy = 3.0
	dg.omni_range = 5.0
	add_child(dg)

	# The Breacher, idling, angled toward the light/menu.
	var glb: Resource = load("res://breacher.glb")
	if glb != null:
		var b: Node3D = glb.instantiate()
		b.position = Vector3(1.55, 0.0, 0.0)
		b.rotation.y = deg_to_rad(-24.0)
		add_child(b)
		# Apply the same PBR skin the player uses at runtime (the glb ships gray).
		var mat: Resource = load("res://textures/breacher_material.tres")
		var mesh_inst := b.find_child("char1", true, false)
		if mat != null and mesh_inst is MeshInstance3D:
			(mesh_inst as MeshInstance3D).material_override = mat
		var ap := b.find_child("AnimationPlayer", true, false)
		if ap is AnimationPlayer and (ap as AnimationPlayer).has_animation("Axe_Breathe_and_Look_Around"):
			(ap as AnimationPlayer).play("Axe_Breathe_and_Look_Around")

	# Key spotlight from front-left — dramatic rake across him.
	var key := SpotLight3D.new()
	key.position = Vector3(-1.2, 4.0, 3.2)
	key.look_at_from_position(key.position, Vector3(1.55, 1.4, 0.0), Vector3.UP)
	key.light_color = Color(1.0, 0.9, 0.76)
	key.light_energy = 8.0
	key.spot_range = 16.0
	key.spot_angle = 42.0
	key.shadow_enabled = true
	add_child(key)
	# Cool rim from behind-right to carve his silhouette out of the dark.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12.0, 150.0, 0.0)
	rim.light_color = Color(0.5, 0.66, 1.0)
	rim.light_energy = 1.3
	add_child(rim)

	# Camera framing him on the right, room for the menu on the left.
	var cam := Camera3D.new()
	cam.position = Vector3(0.35, 1.55, 4.3)
	cam.rotation_degrees = Vector3(-5.0, 0.0, 0.0)
	cam.fov = 52.0
	add_child(cam)

func _box(size: Vector3, pos: Vector3, col: Color, rough: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material = m
	add_child(b)
