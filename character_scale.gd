class_name CharacterScale
extends RefCounted

# ============================================================
#  BLACK BREACHER — character scale single source of truth
#
#  Sizing is a MEASURED number, never an eyeballed multiplier.
#  Formula:  node_scale = target_height / native_height
#  See CLAUDE.md "scale standard" for the canon this encodes.
# ============================================================

# Measured native GLB heights in metres (2026-06-29), corrected for the
# Meshy `Armature` 0.01 scale convention. Re-measure with
# tools/capture/model_probe.gd if a model is re-generated.
const NATIVE := {
	"breacher": 1.91,  # player + boss + brute (operator_breacher family)
	"swat": 1.85,      # basic melee grunt (operator_swat)
	"merc": 1.80,      # ranged operator (operator_merc)
}

# Canonical target heights in metres (confirmed with Derrick).
const TARGET := {
	"player": 1.98,  # 6'6"
	"grunt": 1.78,   # 5'10"
	"boss": 2.03,    # 6'8"
	"brute": 1.96,   # 6'5"
}

# Derived node scales (target / native). These are the numbers the scenes
# and spawner use. Keep them equal to scale_for(TARGET, NATIVE) below.
const PLAYER_SCALE := 1.04  # 1.98 / 1.91
const GRUNT_SCALE := 0.96   # 1.78 / 1.85
const BOSS_SCALE := 1.06    # 2.03 / 1.91
const BRUTE_SCALE := 1.02   # 1.96 / 1.91

# scale = target_height / native_height
static func scale_for(target_height: float, native_height: float) -> float:
	return target_height / native_height

# Derive a collision capsule from a target rendered height.
# Capsule height = target height; centre offset = height / 2 (feet on floor);
# radius ~= height * 0.2. Returns { height, offset_y, radius }.
static func capsule_for(height: float) -> Dictionary:
	return {
		"height": height,
		"offset_y": height * 0.5,
		"radius": height * 0.2,
	}
