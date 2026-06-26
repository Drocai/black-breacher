extends GPUParticles3D

# One-shot debris shower of small falling chunks. Emits once, then frees itself.
# Purely cosmetic: no physics bodies, no collision, no groups.

var _freed: bool = false


func _ready() -> void:
	emitting = true
	one_shot = true
	var wait_time: float = lifetime + 0.4
	await get_tree().create_timer(wait_time).timeout
	if not _freed:
		_freed = true
		queue_free()
