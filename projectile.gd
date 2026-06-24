extends Area3D

# ============================================================
#  BLACK BREACHER — projectile (fired by ranged enemies)
#  Flies straight, damages the player on contact, despawns on any
#  non-enemy body or after its lifetime.
# ============================================================

@export var speed: float = 12.0
@export var damage: int = 6
@export var life: float = 4.0

var _dir: Vector3 = Vector3.FORWARD

func setup(dir: Vector3) -> void:
	_dir = dir.normalized()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += _dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
