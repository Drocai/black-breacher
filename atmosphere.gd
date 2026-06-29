extends GPUParticles3D

## Ambient atmosphere VFX: slow floating dust motes / embers.
## Purely cosmetic. Place once in a scene; it loops forever.
## `tint` lets callers recolor the motes per arena (warm dust, cold dust, etc.).

@export var tint: Color = Color(0.6, 0.55, 0.45)


func _ready() -> void:
	# Always loop the field.
	emitting = true

	# Best-effort tint of the draw-pass material. Never crash if anything
	# along the path is missing — the tint is a nice-to-have, the scene's
	# default color is a perfectly good fallback.
	var mesh_res: Mesh = draw_pass_1
	if mesh_res == null:
		return
	if mesh_res.get_surface_count() <= 0:
		return

	var base_mat: Material = mesh_res.surface_get_material(0)
	if base_mat == null:
		return

	var std_mat: StandardMaterial3D = base_mat as StandardMaterial3D
	if std_mat == null:
		return

	# Duplicate so instances do not share the material resource.
	var dup: Resource = std_mat.duplicate()
	var inst_mat: StandardMaterial3D = dup as StandardMaterial3D
	if inst_mat == null:
		return

	# Preserve the existing (dim) alpha so the effect stays subtle.
	var existing_alpha: float = inst_mat.albedo_color.a
	inst_mat.albedo_color = Color(tint.r, tint.g, tint.b, existing_alpha)
	mesh_res.surface_set_material(0, inst_mat)
