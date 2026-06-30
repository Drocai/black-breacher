extends Node

# Generic scene screenshot driver. Reads tools/capture/_shot.cfg
#   line1 = target scene (res://...)
#   line2 = output png name (saved to user://)
#   line3 = optional settle delay seconds (default 3.0)
#   line4 = optional "x,y,z" to teleport the player to (e.g. interior views)
# Loads the target, optionally moves the player, lets it settle, saves a
# rendered PNG, quits. MUST run WINDOWED (not --headless) for a real frame.

var _t: float = 0.0
var _shot: bool = false
var _loaded: bool = false
var _tp_done: bool = false
var target: String = "res://main.tscn"
var out_name: String = "bb_shot.png"
var delay: float = 3.0
var teleport = null   # Vector3 or null

func _ready() -> void:
	var f := FileAccess.open("res://tools/capture/_shot.cfg", FileAccess.READ)
	if f:
		var lines := f.get_as_text().strip_edges().split("\n")
		if lines.size() >= 1 and lines[0].strip_edges() != "":
			target = lines[0].strip_edges()
		if lines.size() >= 2 and lines[1].strip_edges() != "":
			out_name = lines[1].strip_edges()
		if lines.size() >= 3 and lines[2].strip_edges() != "":
			delay = float(lines[2].strip_edges())
		if lines.size() >= 4 and lines[3].strip_edges() != "":
			var parts := lines[3].strip_edges().split(",")
			if parts.size() == 3:
				teleport = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	call_deferred("_load")

func _load() -> void:
	get_tree().change_scene_to_file(target)
	_loaded = true

func _process(d: float) -> void:
	if not _loaded or _shot:
		return
	_t += d
	if teleport != null and not _tp_done and _t > 0.6:
		var p := get_tree().get_first_node_in_group("player")
		if p != null and p is Node3D:
			(p as Node3D).global_position = teleport
		_tp_done = true
	# Keep the player safe so combat-area captures aren't washed red.
	if _tp_done:
		var pl := get_tree().get_first_node_in_group("player")
		if pl != null:
			if "max_health" in pl:
				pl.health = pl.max_health
			if "_invuln" in pl:
				pl._invuln = 99.0
		Game.hit_flash = 0.0
	if _t >= delay:
		_shot = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var pth := "user://" + out_name
		img.save_png(pth)
		print("CAPTURE_SAVED ", ProjectSettings.globalize_path(pth))
		get_tree().quit()
