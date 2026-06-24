extends GPUParticles3D

# One-shot hit spark burst that frees itself once finished.

func _ready() -> void:
	emitting = true
	await get_tree().create_timer(1.0).timeout
	queue_free()
