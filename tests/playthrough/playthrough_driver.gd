extends Node

# ============================================================
#  BLACK BREACHER — automated headless playthrough (regression test)
#  Pilots the real main.tscn through the entire mission loop and
#  asserts every link of the win chain. Prints PLAYTHROUGH_OK + stats
#  on success, or PLAYTHROUGH_FAIL + a state dump on any broken link.
#  Run via tools/run_playthrough.ps1 (or load playthrough_bootstrap.tscn
#  headless). Exit code 0 = pass, 1 = fail.
#
#  Phases:
#    0 INIT      — wait for main.tscn ("World") to become current scene
#    1 ENGAGE    — shove the player past z=-4 so WaveManager starts
#    2 CLEAR     — instakill every wave enemy (boss spared) until
#                  Game.all_waves_done, keeping the player alive
#    3 BOSS      — kill what remains (the boss) until enemy group empty
#    4 OBJECTIVE — trip the objective and wait for the mission-clear chain
#    5 DONE      — assert the full state and quit
# ============================================================

var _phase: int = 0
var _t: float = 0.0
var _phase_t: float = 0.0
const TIMEOUT := 90.0

func _ready() -> void:
	Game.full_reset()
	Game.difficulty = 0   # easy = fewer/weaker enemies, faster loop

func _fail(reason: String) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy").size()
	print("PLAYTHROUGH_FAIL: ", reason)
	print("  state: phase=%d t=%.1f kills=%d wave=%d/%d all_waves_done=%s enemies_alive=%d mission=%d missions_cleared=%d" % [
		_phase, _t, Game.kills, Game.wave, Game.max_waves, str(Game.all_waves_done), enemies, Game.mission, Game.missions_cleared])
	get_tree().quit(1)

func _scene_ok() -> Node:
	var s := get_tree().current_scene
	if s == null or s.name != "World":
		return null
	return s

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _keep_player_alive(p: Node) -> void:
	if p != null and "health" in p:
		p.health = p.max_health

func _kill_enemies(spare_boss: bool) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if spare_boss and e is Node and e.is_in_group("boss"):
			continue
		if e is Node and e.has_method("take_hit"):
			e.take_hit(9999)

func _physics_process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	if _t > TIMEOUT:
		_fail("timeout — loop never completed")
		return

	if _scene_ok() == null:
		return
	var p := _player()

	match _phase:
		0:
			if p != null:
				_advance_phase()
		1:
			if p != null:
				p.global_position = Vector3(0.0, 1.0, -7.0)
				_keep_player_alive(p)
			if Game.wave >= 1:
				_advance_phase()
			elif _phase_t > 5.0:
				_fail("waves never started after entering arena")
		2:
			_keep_player_alive(p)
			_kill_enemies(true)   # spare the boss for its own stage
			if Game.all_waves_done:
				_advance_phase()
		3:
			_keep_player_alive(p)
			_kill_enemies(false)  # now finish the boss
			if get_tree().get_nodes_in_group("enemy").size() == 0:
				_advance_phase()
			elif _phase_t > 30.0:
				_fail("boss/stragglers never died")
		4:
			var obj := get_tree().get_first_node_in_group("objective")
			if obj != null and "reached" in obj:
				obj.reached = true
			if Game.missions_cleared >= 1:
				_advance_phase()
			elif _phase_t > 8.0:
				_fail("objective reached + waves done + no enemies, but mission never cleared")
		5:
			_pass()

func _advance_phase() -> void:
	print("  [phase %d OK @ t=%.1f] kills=%d wave=%d all_waves_done=%s enemies=%d" % [
		_phase, _t, Game.kills, Game.wave, str(Game.all_waves_done),
		get_tree().get_nodes_in_group("enemy").size()])
	_phase += 1
	_phase_t = 0.0

func _pass() -> void:
	var ok := true
	var msgs: Array = []
	if Game.kills <= 0:
		ok = false; msgs.append("expected kills>0")
	if not Game.all_waves_done:
		ok = false; msgs.append("expected all_waves_done")
	if Game.missions_cleared < 1:
		ok = false; msgs.append("expected missions_cleared>=1")
	if Game.score <= 0:
		ok = false; msgs.append("expected score>0")
	if ok:
		print("PLAYTHROUGH_OK kills=%d score=%d waves=%d missions_cleared=%d" % [
			Game.kills, Game.score, Game.max_waves, Game.missions_cleared])
		get_tree().quit(0)
	else:
		_fail("final assertions: " + ", ".join(msgs))
