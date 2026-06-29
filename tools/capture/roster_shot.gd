extends Node3D

# Renders the operator roster (base SWAT, heavy breacher, lean merc) in a
# studio line-up, each running its locomotion clip, for a single clean review
# image. Run WINDOWED.

const ROSTER := [
	{"glb": "res://characters/operator_swat_run.glb", "x": -2.2, "s": 1.0},
	{"glb": "res://characters/operator_breacher_run.glb", "x": 0.0, "s": 1.2},
	{"glb": "res://characters/operator_merc_run.glb", "x": 2.2, "s": 1.0},
]

var _t := 0.0
var _shot := false

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.075, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.4)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -40, 0)
	key.light_energy = 1.7; key.shadow_enabled = true; add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 150, 0)
	rim.light_energy = 0.7; rim.light_color = Color(0.6, 0.72, 1.0); add_child(rim)

	for r in ROSTER:
		var packed = load(r["glb"])
		if packed == null:
			continue
		var m: Node3D = packed.instantiate()
		add_child(m)
		m.position = Vector3(r["x"], 0.0, 0.0)
		m.scale = Vector3.ONE * r["s"]
		m.rotation.y = deg_to_rad(15.0)   # slight 3/4 view
		var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
		if ap:
			var list := ap.get_animation_list()
			if list.size() > 0:
				ap.play(list[0])
				ap.seek(0.35, true)   # a readable mid-stride pose
				ap.pause()

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 5.4)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	add_child(cam)

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.8 and not _shot:
		_shot = true
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://bb_roster.png")
		print("CAPTURE_SAVED ", ProjectSettings.globalize_path("user://bb_roster.png"))
		get_tree().quit()
