extends Node3D

# Standalone verification harness for an imported character GLB.
# Loads the operator, prints its animation names + skeleton bone count,
# plays the run animation, and saves rendered PNGs from a few angles so we
# can SEE that the rigged tactical operator imports, skins, and animates
# correctly BEFORE wiring it into the enemy. Run WINDOWED.

const MODELS := [
	"res://characters/operator_swat_run.glb",
	"res://characters/operator_swat_walk.glb",
	"res://characters/operator_swat_rigged.glb",
]

var _model: Node3D
var _anim: AnimationPlayer
var _cam: Camera3D
var _t := 0.0
var _shot := 0
var _model_idx := 0

func _ready() -> void:
	# Neutral studio lighting so material/clarity reads honestly.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.085, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.37, 0.42)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 1.6
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.7, 0.78, 1.0)
	add_child(fill)

	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.0, 3.2)
	_cam.rotation_degrees = Vector3(-8, 0, 0)
	add_child(_cam)

	_load_model(0)

func _load_model(idx: int) -> void:
	if _model and is_instance_valid(_model):
		_model.queue_free()
	var path: String = MODELS[idx]
	var packed := load(path)
	if packed == null:
		print("PROBE_FAIL could not load ", path)
		return
	_model = packed.instantiate()
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	var skel := _model.find_child("Skeleton3D", true, false)
	var bones := -1
	if skel:
		bones = skel.get_bone_count()
	var anims: PackedStringArray = []
	if _anim:
		anims = _anim.get_animation_list()
	# Report the AABB so we can confirm real-world scale (~1.85m tall).
	var aabb := _model_aabb(_model)
	print("PROBE_MODEL ", path)
	print("  bones=", bones, " anims=", anims, " size=", aabb.size)
	if _anim and anims.size() > 0:
		_anim.play(anims[0])

func _model_aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (c as MeshInstance3D).get_aabb()
		a = (c as MeshInstance3D).global_transform * a
		if first:
			box = a; first = false
		else:
			box = box.merge(a)
	return box

func _process(delta: float) -> void:
	_t += delta
	# Slow turntable for a readable silhouette.
	if _model:
		_model.rotation.y += delta * 0.7
	if _t > 1.2:
		_t = 0.0
		await _grab("user://probe_%d_%d.png" % [_model_idx, _shot])
		_shot += 1
		if _shot >= 2:
			_shot = 0
			_model_idx += 1
			if _model_idx >= MODELS.size():
				get_tree().quit()
				return
			_load_model(_model_idx)

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("CAPTURE_SAVED ", ProjectSettings.globalize_path(path))
