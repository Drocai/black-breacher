extends CanvasLayer

# ============================================================
#  BLACK BREACHER — BOSS HEALTH BAR (pull-based)
#   - shown only while a valid boss is active
#   - reads health / max_health / boss_name from the "boss"
#     group node each frame, mirroring hud.gd's style
# ============================================================

@onready var box: Control = $Box
@onready var name_label: Label = $Box/Name
@onready var bar: ProgressBar = $Box/Bar

func _process(_delta: float) -> void:
	var boss: Node = get_tree().get_first_node_in_group("boss")
	# Only surface the boss bar during the finale (after the waves are cleared),
	# not from spawn — the boss node exists in the scene the whole time.
	if Game.all_waves_done and boss != null and is_instance_valid(boss) and ("health" in boss) and ("max_health" in boss) and boss.health > 0:
		box.visible = true
		name_label.text = str(boss.boss_name) if ("boss_name" in boss) else "BOSS"
		bar.max_value = boss.max_health
		bar.value = boss.health
	else:
		box.visible = false
