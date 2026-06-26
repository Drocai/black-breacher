extends Node3D

## Reusable one-shot "ground shockwave ring" cosmetic effect.
## Instantiate, set position, add to scene tree. It expands a flat ring
## on the XZ plane, fades out, then frees itself. Purely cosmetic:
## no physics, no collision, no groups, no gameplay effect.

@export var color: Color = Color(1.0, 0.7, 0.35)
@export var max_scale: float = 4.0
@export var duration: float = 0.45

@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	if mesh == null:
		queue_free()
		return

	# Duplicate the material so per-instance tweening never mutates a shared resource.
	var src_mat: Material = mesh.get_active_material(0)
	var mat: StandardMaterial3D
	if src_mat is StandardMaterial3D:
		mat = (src_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()

	# Force the cosmetic glow setup regardless of what the scene shipped.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0

	var start_albedo: Color = Color(color.r, color.g, color.b, 1.0)
	mat.albedo_color = start_albedo

	mesh.material_override = mat

	# Start small and flat on the ground (TorusMesh hole faces +Y in XZ plane).
	var start_scale: float = 0.2
	mesh.scale = Vector3(start_scale, start_scale, start_scale)

	var end_albedo: Color = Color(color.r, color.g, color.b, 0.0)
	var end_scale_vec: Vector3 = Vector3(max_scale, max_scale, max_scale)

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# Expanding ring (ease-out for a snappy impact pop).
	tween.tween_property(mesh, "scale", end_scale_vec, duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# Fade albedo alpha to zero over the same window.
	tween.tween_property(mat, "albedo_color", end_albedo, duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# Quick emission flash: spike bright, then ease down as it fades.
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.set_parallel(false)
	tween.tween_callback(queue_free)
