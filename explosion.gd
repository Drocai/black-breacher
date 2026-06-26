extends Node3D

# One-shot explosion burst: fireball + smoke particles plus an orange light
# flash that frees itself once finished.

@onready var _fireball: GPUParticles3D = $Fireball
@onready var _smoke: GPUParticles3D = $Smoke
@onready var _flash: OmniLight3D = $Flash


func _ready() -> void:
	_fireball.emitting = true
	_smoke.emitting = true

	var tween: Tween = create_tween()
	tween.tween_property(_flash, "light_energy", 0.0, 0.4).from(8.0)

	await get_tree().create_timer(1.2).timeout
	queue_free()
