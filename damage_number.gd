extends Label3D

# Floating combat damage number — rises and fades, then frees itself.

func set_amount(amount: int) -> void:
	text = str(amount)

func _ready() -> void:
	var t := create_tween()
	t.tween_property(self, "position:y", position.y + 1.2, 0.6)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)
