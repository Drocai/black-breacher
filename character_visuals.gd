class_name CharacterVisuals
extends RefCounted

# ============================================================
#  BLACK BREACHER — skinned-operator visual controller
#  Shared by every humanoid enemy (basic operator, brute, and future
#  variants). Wraps a rigged Meshy GLB instanced under a facing "Mesh"
#  Node3D and provides: per-instance flash/glow materials, velocity-driven
#  walk/run locomotion, and one-shot hit/death control. All Meshy basic
#  rigs share the same clip names, so those are the defaults.
# ============================================================

const ANIM_RUN := "Armature|running|baselayer"
const ANIM_WALK := "Armature|walking_man|baselayer"

var mats: Array[BaseMaterial3D] = []   # per-instance skinned materials
var anim: AnimationPlayer
var _cur: String = ""
var _lock: float = 0.0                 # one-shot anims own the model until 0

# wrapper: the facing Node3D ("Mesh") with the rigged GLB as child 0.
# walk_glb: the matching *_walk.glb (same skeleton) to graft the walk clip from.
func setup(wrapper: Node3D, walk_glb: PackedScene, yaw_offset_deg: float, tint: Color) -> void:
	var op := wrapper.get_child(0) if wrapper.get_child_count() > 0 else null
	if op is Node3D:
		(op as Node3D).rotation.y = deg_to_rad(yaw_offset_deg)
	# Duplicate skinned materials so flash/glow stay local to this instance.
	for mi in wrapper.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for s in m.get_surface_override_material_count():
			var base := m.get_active_material(s)
			if base is BaseMaterial3D:
				var dup: BaseMaterial3D = base.duplicate()
				if tint != Color(1, 1, 1, 1):
					dup.albedo_color = dup.albedo_color * tint
				m.set_surface_override_material(s, dup)
				mats.append(dup)
	# Animation: the model ships with "running"; graft "walking" from walk_glb.
	anim = wrapper.find_child("AnimationPlayer", true, false)
	if anim:
		var lib := anim.get_animation_library("")
		if lib:
			if anim.has_animation(ANIM_RUN):
				anim.get_animation(ANIM_RUN).loop_mode = Animation.LOOP_LINEAR
			if not anim.has_animation(ANIM_WALK) and walk_glb:
				var tmp := walk_glb.instantiate()
				var tap: AnimationPlayer = tmp.find_child("AnimationPlayer", true, false)
				if tap and tap.has_animation(ANIM_WALK):
					var wa: Animation = tap.get_animation(ANIM_WALK).duplicate(true)
					wa.loop_mode = Animation.LOOP_LINEAR
					lib.add_animation(ANIM_WALK, wa)
				tmp.queue_free()
		play(ANIM_RUN)

func play(name: String, blend: float = 0.12) -> void:
	if anim == null or name == _cur or not anim.has_animation(name):
		return
	_cur = name
	anim.play(name, blend)

# Pick locomotion from horizontal speed. `down` halts updates after death.
func drive(velocity: Vector3, move_speed: float, delta: float, down: bool) -> void:
	if anim == null:
		return
	if _lock > 0.0:
		_lock -= delta
		return
	if down:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > move_speed * 0.55:
		play(ANIM_RUN)
		anim.speed_scale = clampf(spd / max(move_speed, 0.1), 0.85, 1.5)
	elif spd > 0.25:
		play(ANIM_WALK)
		anim.speed_scale = 1.0
	else:
		play(ANIM_WALK)
		anim.speed_scale = 0.0   # held ready-stance, not a frozen sprint

func set_glow(on: bool, color: Color = Color(1.0, 0.25, 0.1)) -> void:
	for m in mats:
		m.emission_enabled = on
		if on:
			m.emission = color
			m.emission_energy_multiplier = 2.5
		else:
			m.emission_energy_multiplier = 0.0

# A short emissive pop on a tween owner (the enemy node creates the tweens).
func pulse(owner: Node, color: Color, peak: float, up: float, down_t: float) -> void:
	for m in mats:
		m.emission_enabled = true
		m.emission = color
		var t := owner.create_tween()
		t.tween_property(m, "emission_energy_multiplier", peak, up)
		t.tween_property(m, "emission_energy_multiplier", 0.0, down_t)

func pause() -> void:
	if anim:
		anim.pause()
