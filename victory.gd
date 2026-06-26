extends CanvasLayer

# Victory / campaign-complete screen for Black Breacher.
# Reads final run stats off the Game autoload and waits for a keypress
# to return to the title scene.

@onready var missions_label: Label = $Center/VBox/StatMissions
@onready var kills_label: Label = $Center/VBox/StatKills
@onready var score_label: Label = $Center/VBox/StatScore
@onready var best_label: Label = $Center/VBox/StatBest
@onready var leaderboard_label: Label = $Center/VBox/Leaderboard

var _returning: bool = false


func _ready() -> void:
	# Keep working even if the tree was paused when victory fired.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var missions: int = Game.missions_cleared
	var kills: int = Game.kills
	var final_score: int = Game.score
	var best: int = Game.best_score

	missions_label.text = "MISSIONS CLEARED    %d" % missions
	kills_label.text = "TOTAL KILLS    %d" % kills
	score_label.text = "FINAL SCORE    %d" % final_score
	best_label.text = "BEST SCORE    %d" % best

	# Record this run on the persistent leaderboard, then show the top runs
	# (highlighting where this run placed).
	var placement: int = Game.record_score(final_score)
	var lines: PackedStringArray = ["— TOP RUNS —"]
	for i in Game.top_scores.size():
		var marker: String = "  <-- this run" if i == placement else ""
		lines.append("%d.   %d%s" % [i + 1, int(Game.top_scores[i]), marker])
	leaderboard_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if _returning:
		return

	var accept: bool = false

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_SPACE:
			accept = true

	if not accept and event.is_action_pressed("ui_accept"):
		accept = true

	if accept:
		_returning = true
		get_tree().change_scene_to_file("res://title.tscn")
