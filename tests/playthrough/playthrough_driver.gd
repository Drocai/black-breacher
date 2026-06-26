extends Node

# ============================================================
#  BLACK BREACHER — automated headless playthrough (regression test)
#  Pilots the REAL campaign — every arena in Game.ARENA_SCENES, in
#  sequence — through the full win chain and on to the victory screen,
#  asserting the whole flow. Prints PLAYTHROUGH_OK + stats on success,
#  or PLAYTHROUGH_FAIL + a state dump on any broken link.
#  Run via tools/run_playthrough.ps1. Exit 0 = pass, 1 = fail.
#
#  The loop is arena-agnostic: each arena's WaveManager resets wave state
#  on load (Game.reset()), so the same per-frame logic drives arena 1,
#  arena 2, ... until the objective chain swaps in victory.tscn.
#
#  Per-arena chain it forces and verifies:
#    enter (push player past z=-4) -> waves spawn -> instakill each wave
#    (boss spared) -> all_waves_done -> kill boss -> trip objective ->
#    mission cleared -> next arena loads. After the last arena -> Victory.
# ============================================================

var _t: float = 0.0
var _missions_start: int = 0
var _kills_start: int = 0
const TIMEOUT := 180.0
const ARENA_COUNT := 3   # keep in sync with Game.ARENA_SCENES.size()

func _ready() -> void:
	Game.full_reset()
	Game.difficulty = 0          # easy = fewer/weaker enemies, faster loop
	_missions_start = Game.missions_cleared
	_kills_start = Game.kills

func _fail(reason: String) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy").size()
	var sname := "<null>"
	if get_tree().current_scene != null:
		sname = get_tree().current_scene.name
	print("PLAYTHROUGH_FAIL: ", reason)
	print("  state: t=%.1f scene=%s kills=%d wave=%d/%d all_waves_done=%s enemies=%d mission=%d missions_cleared=%d" % [
		_t, sname, Game.kills, Game.wave, Game.max_waves, str(Game.all_waves_done), enemies, Game.mission, Game.missions_cleared])
	get_tree().quit(1)

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
	if _t > TIMEOUT:
		_fail("timeout — campaign never completed")
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	# Reached the campaign-complete screen → done.
	if scene.name == "Victory":
		_pass()
		return

	# Mid-transition or some other scene — wait it out.
	if scene.name != "World":
		return

	var p := get_tree().get_first_node_in_group("player")
	_keep_player_alive(p)
	var enemies := get_tree().get_nodes_in_group("enemy").size()

	if Game.all_waves_done and enemies == 0:
		# Building cleared — trip the objective to finish the mission.
		var obj := get_tree().get_first_node_in_group("objective")
		if obj != null and "reached" in obj:
			obj.reached = true
	elif Game.all_waves_done:
		# Waves done, boss (or stragglers) remain — finish them.
		_kill_enemies(false)
	elif Game.wave >= 1:
		# Waves in progress (or in a resupply intermission) — mow them down,
		# sparing the boss for its own stage.
		_kill_enemies(true)
		# If a resupply drop is out (intermission), walk onto it so the
		# upgrade-pickup -> player.apply_upgrade() path gets exercised.
		var up := get_tree().get_first_node_in_group("upgrade")
		if up != null and p != null:
			p.global_position = up.global_position
	else:
		# Not engaged yet — shove the player into the arena to start waves.
		if p != null:
			p.global_position = Vector3(0.0, 1.0, -7.0)

func _pass() -> void:
	var missions_done := Game.missions_cleared - _missions_start
	var ok := true
	var msgs: Array = []
	if missions_done < ARENA_COUNT:
		ok = false; msgs.append("expected %d missions cleared, got %d" % [ARENA_COUNT, missions_done])
	if Game.kills <= _kills_start:
		ok = false; msgs.append("expected kills to increase")
	if Game.score <= 0:
		ok = false; msgs.append("expected score>0")
	if ok:
		print("PLAYTHROUGH_OK arenas=%d kills=%d score=%d missions_cleared=%d (reached Victory)" % [
			ARENA_COUNT, Game.kills, Game.score, Game.missions_cleared])
		get_tree().quit(0)
	else:
		_fail("final assertions: " + ", ".join(msgs))
