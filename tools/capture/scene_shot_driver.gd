extends Node

# Generic scene screenshot driver. Reads tools/capture/_shot.cfg
#   line1 = target scene (res://...)
#   line2 = output png name (saved to user://)
#   line3 = optional settle delay seconds (default 3.0)
# Loads the target, waits for it to settle, saves a rendered PNG, quits.
# MUST run WINDOWED (not --headless) for a real frame.

var _t: float = 0.0
var _shot: bool = false
var _loaded: bool = false
var target: String = "res://main.tscn"
var out_name: String = "bb_shot.png"
var delay: float = 3.0

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
	call_deferred("_load")

func _load() -> void:
	get_tree().change_scene_to_file(target)
	_loaded = true

func _process(d: float) -> void:
	if not _loaded or _shot:
		return
	_t += d
	if _t >= delay:
		_shot = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var p := "user://" + out_name
		img.save_png(p)
		print("CAPTURE_SAVED ", ProjectSettings.globalize_path(p))
		get_tree().quit()
