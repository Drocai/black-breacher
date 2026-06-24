---
name: black-breacher
description: >-
  Project operating skill for BLACK BREACHER — the Daddy Frequency Productions
  father-son 3D action brawler built in Godot 4.7 (original IP; Derrick's son
  named the character and co-builds it). Load this FIRST in any session that
  touches the game: Godot scene work, the Breacher character, the Meshy→Godot
  asset pipeline, movement/animation scripting, the door-breach loop, texturing,
  custom animations, or anything inside the `breacher` Godot project. Trigger on
  "Black Breacher," "the breacher," "the game with my son," "Marrow Georgia,"
  "door-breach," "halligan," any Godot work, any .glb / Meshy / rig / animation
  task for the character, or picking the project back up from any device. Carries
  the source-of-truth: current playable state, the proven asset pipeline, the
  working movement script, the node-tree architecture, the hard-won gotchas,
  Derrick's 3D-beginner + trackpad-only constraints, and the build roadmap. If
  unsure whether a request touches the game, trigger.
---

# BLACK BREACHER — Project Operating Skill

> Father-son 3D action brawler. Original IP. Built in **Godot 4.7-stable**.
> Daddy Frequency Productions / Made by D RoC.
> **Load this first.** It tells you where we are and how to teach Derrick.

---

## 1. WHERE WE ARE (current state — read this first)

**The door-breach loop is BUILT as of June 2026** — the demoable payoff. Current controls:

- **WASD / arrow keys** → walk (world-relative movement)
- **Shift (hold)** → run
- **Spacebar** → **jump** (changed from jab — Derrick chose the standard scheme)
- **J / left-click** → jab (`Right_Jab_from_Guard`, interrupt-protected so walk/idle don't stomp it)
- **F** → breach a door while standing in its BreachZone (plays `Push_Forward_and_Stop`, door swings open)
- **Idle** plays when standing still (`Axe_Breathe_and_Look_Around`)
- Character turns to face travel direction; **camera stays stable** (only the mesh rotates, not the body) and now sits properly behind him at (0, 3, 5)
- Scene now has a **sun + sky**, a **textured (noise) floor**, a **training dummy**, a **breachable door**, and a **room with 3 attacking enemies** behind it
- **HUD** (`hud.gd`): health bar, "Press F to Breach" prompt, enemy counter → AREA CLEAR
- **Player health + respawn** (full heal at spawn on death); **enemies chase and attack** for damage; jab landing plays `hit.wav`
- Breach was made forgiving (bigger zone) + capsule slimmed so the doorway clears easily

> Status: implemented and **headless-validated** (clean import + 40-frame run, zero errors) via the feature-branch PR `feature/breach-loop`. **Pending Derrick's in-editor F5 playtest** before calling it confirmed-working.

**Animation set expanded (June 2026):** swapped in a new `breacher.glb` from Meshy with kicks + more punches (same 24-bone rig, all old clips kept). New clips: `Spartan_Kick`, `High_Kick`, `Step_in_High_Kick`, `Boxing_Guard_Right_Straight_Kick`, `Left_Hook_from_Guard`, `Right_Upper_Hook_from_Guard`, `Right_Uppercut_from_Guard`, `Charged_Upward_Slash`, `Dodge_and_Counter`. Wired so far: **breach = `Spartan_Kick`** (real door-kick, no Blender needed), **J/left-click = 3-hit punch combo** (jab→hook→uppercut), **right-click = `High_Kick`** heavy hit. Still unused & available: `Step_in_High_Kick`, `Dodge_and_Counter`, `Charged_Upward_Slash`, extra hooks.

**Still NEEDS external tools:** the character texture pass (Meshy auto-paint) and a jump clip (none in the set). Character is still gray clay.

---

## 2. THE STACK

| Layer | Tool | Notes |
|---|---|---|
| Engine | **Godot 4.7-stable, Standard** (NOT .NET/Mono) | Forward+ renderer. Portable zip, no installer. SmartScreen → More info → Run anyway. |
| 3D asset gen | **Meshy** (Pro, $20) | Image→3D = 20 credits; Remesh / Rig / Animate = 0 credits. License Private (commercial/owned). |
| Project location | `C:/Projects/web/black-breacher` | Moved OUT of OneDrive (git + OneDrive double-sync corrupts `.git/`). The folder *is* the game. A stale pre-git copy may still sit at `OneDrive/Desktop/breacher` — ignore/delete it. |
| Repo | **`Drocai/black-breacher`** (GitHub, PRIVATE) | ✅ Created. `main` is directly pushable for laptop sync; Claude's larger changes arrive via feature-branch PRs. Run `git lfs install` once per machine or `.glb` arrives as a broken pointer. |
| Main hero asset | `breacher.glb` | Renamed from Meshy's `..._Meshy_Merged_Animations.glb`. Mesh + skeleton + ALL animations. |

**Two-device workflow:** ✅ now git, not folder-copying. `git pull` before working; `git add -A && git commit -m "..." && git push` when done. New machine: `git lfs install` once, then `git clone https://github.com/Drocai/black-breacher.git`.

---

## 3. IP CANON (essentials — full bible in outputs)

- **Game:** gritty Southern-town brawler. Setting: **Marrow, Georgia.**
- **Character:** ex-Ranger / SWAT breacher who kicks doors. "Black Breacher" is his in-story birth name (Derrick's son named it — protect that, it's the kid's contribution).
- **Signature gear:** **halligan pry bar** + **brass key on a bootlace.**
- **Theme line:** *"Not every door should be kicked."*
- **Look (locked reference):** scarred face, shaved head, open dark work jacket over charcoal henley, faded olive cargos, scuffed black combat boots, brass key on bootlace.
- Full IP bible: `/mnt/user-data/outputs/BLACK-BREACHER-IP-BIBLE.md`. Logo + Steam capsule SVGs also in outputs.

**Brand lock applies** (per global rule): never alter delivered logos/colors/fonts. Use assets exactly as given.

---

## 4. ASSET PIPELINE (Meshy → Godot — proven, repeat for new assets)

**Meshy generate:**
1. Feed the **single hero T-pose image only.** NOT a 4-view turnaround (strips mangle output), NOT arms-down (fuses limbs). T-pose arms-out is the one that works.
2. Settings: Standard model, **Meshy 6**, Image Enhancement ON, Pose = **T-Pose**, License = Private, Multi-view OFF. (~20 credits.)

**Remesh (this is the make-or-break lesson):**
3. **100K / Quad.** Heavier ≠ better, but too light starves the face — 30K Quad **blobbed the face**. The pro move is sculpt-high (the raw ~325K output) → retopo to clean **100K quads** (likeness preserved + animation-friendly topology). Re-remesh the ORIGINAL high model, not a degraded one.
4. **Ignore ALL "Printability" warnings** (Watertight / Holes / Non-manifold / AI Auto-Repair). Those are 3D-*printing* metrics — irrelevant to a rigged game character. **Never click AI Auto-Repair.**

**Rig:**
5. Character Type = **Humanoid** (not Quadruped, not Smart-Rig-Beta).
6. Alignment screen: Rotate/Offset all 0; Height value is cosmetic, ignore it.
7. Joint markers (chin / shoulders / elbows / wrists / groin / knees / ankles), **Symmetry ON.** Eyeball them — they usually land clean.

**Animate — grab these clips (names are load-bearing; the script calls them verbatim):**
- `Casual_Walk` — walk
- `Running` — run
- `Axe_Breathe_and_Look_Around` — idle
- `Right_Jab_from_Guard` — attack/jab
- (also present: `Walking`, `Push_Forward_and_Stop`, `Boxing_Guard_Prep_Straight_Punch`)

**Export:**
8. Download Settings → Format **glb**, Rigged Character ON, Animation = **All Added**, Single file ON.
9. Meshy outputs two files. Use the one ending **`_Meshy_Merged_Animations.glb`** (mesh + skeleton + ALL anims). Rename it **`breacher.glb`**, drop into the project folder, Godot auto-reimports.
10. Adding a new animation later = re-download with All Added → rename `breacher.glb` → overwrite → Godot reimports → new clip appears in AnimationPlayer dropdown.

**Texture = DEFERRED on purpose.** Model is gray clay (0 materials/0 images). Texturing is non-blocking and swappable anytime — do it as a focused Meshy AI auto-paint pass *after* gameplay feels good, re-export, swap the file. Don't let it block playable progress.

---

## 5. GODOT ARCHITECTURE

**Scene tree (confirmed working):**
```
World (Node3D)              [main.tscn root]
├── Floor (CSGBox3D)        Size 20 / 0.5 / 20, Use Collision ON, Pos (0, -0.25, 0)
├── Player (CharacterBody3D)   ← player.gd attached HERE
│   ├── CollisionShape3D (CapsuleShape3D)
│   ├── breacher (Node3D, Editable Children ON)
│   │   ├── Armature → Skeleton3D → char1
│   │   └── AnimationPlayer
│   └── Camera3D            Pos (0, 3, 5), Rotation (-25, 0, 0)   — fixed follow, doesn't spin
├── Sun (DirectionalLight3D)   pitched ~ -50°, shadows on
├── WorldEnvironment           ProceduralSky + filmic tonemap
├── Door (door.tscn instance)  at (0, 0, -5) — the breach target
└── Dummy (dummy.tscn instance) at (3, 0, -2) — the jab target
```
> Floor now carries a noise-based `StandardMaterial3D` (uv tiled 10×). The character mesh is still gray clay — that's the deferred Meshy texture pass, not a bug.

**Critical import gotcha:** dragging a `.glb` onto the scene makes a **locked/instanced** node (no expand arrow). Fix = right-click the node → **Editable Children** → tree unlocks. Without this you can't reach Skeleton3D/AnimationPlayer.

**Why the script lives on Player and the camera is its child:** the camera follows automatically because it's parented to the body. The body never rotates (only the mesh does), so the camera never spins — that's what makes it feel like a real game instead of tank controls.

---

## 6. THE WORKING MOVEMENT SCRIPT (`player.gd`) — source of truth

This is the corrected, shipped baseline. World-relative input, mesh-only rotation, interrupt-protected jab, run on Shift. The facing line is `atan2(direction.x, direction.z)` — **no minus signs** (minus signs make him face backward; that was the bug we fixed).

```gdscript
extends CharacterBody3D

@export var speed: float = 4.0
@export var run_speed: float = 7.0
@export var rotation_speed: float = 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var anim: AnimationPlayer = $breacher/AnimationPlayer
@onready var mesh: Node3D = $breacher

var attack_timer: float = 0.0

func _physics_process(delta: float) -> void:
	# Gravity keeps him on the floor
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Count down the attack so walk/idle don't stomp the jab
	if attack_timer > 0.0:
		attack_timer -= delta

	# --- Jab on Spacebar ---
	if Input.is_action_just_pressed("ui_accept") and attack_timer <= 0.0:
		anim.play("Right_Jab_from_Guard")
		attack_timer = anim.get_animation("Right_Jab_from_Guard").length

	# --- Movement: world-relative ---
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction: Vector3 = Vector3(input_dir.x, 0, input_dir.y).normalized()

	var running: bool = Input.is_key_pressed(KEY_SHIFT)
	var current_speed: float = run_speed if running else speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		# Turn ONLY the model to face travel — camera stays put
		var target_angle: float = atan2(direction.x, direction.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	# --- Pick animation (jab wins while attack_timer is running) ---
	if attack_timer <= 0.0:
		if direction:
			if running:
				if anim.current_animation != "Running":
					anim.play("Running")
			else:
				if anim.current_animation != "Casual_Walk":
					anim.play("Casual_Walk")
		else:
			if anim.current_animation != "Axe_Breathe_and_Look_Around":
				anim.play("Axe_Breathe_and_Look_Around")

	move_and_slide()
```

When extending movement (door-breach, jump, dodge), build ON this — don't rewrite from scratch. Keep the `attack_timer` interrupt pattern; that's how an action animation wins over locomotion without getting stomped every frame.

---

## 7. HARD-WON LESSONS (don't relearn these)

- **Facing flip** → `atan2(direction.x, direction.z)` with NO minus signs. Minus = faces backward on all four directions.
- **Animation stomp** → an attack anim played in `_physics_process` gets overwritten one frame later by walk/idle. Gate locomotion behind an `attack_timer` countdown (done in the script).
- **Camera spin / tank controls** → caused by rotating the whole Player. Rotate the **mesh only**; leave the body (and its child camera) unrotated.
- **Locked GLB node** → right-click → **Editable Children**.
- **Face blob on remesh** → never go light (30K). Use **100K Quad** off the original high model.
- **Printability red warnings** → 3D-print noise. Ignore. Never AI-Auto-Repair a game character.
- **Texture** → deferred by design; gray clay is fine until gameplay is solid.
- **Floor height** → CSGBox Size-Y 0.5 centered, so Pos-Y **-0.25** drops the top surface to world zero. Exact value isn't critical; gravity settles him.

---

## 8. HOW TO TEACH DERRICK (operating constraints — important)

Derrick is **new to 3D / game tooling** even though he's a high-literacy systems builder everywhere else. In THIS domain:

- Give **exact clicks, exact button names, exact field values, exact menu paths.** Screenshot-by-screenshot cadence. He sends a screenshot, you read it and give the next concrete step.
- **He's trackpad-only on the dev laptop (no mouse).** Keep camera/orbit instructions minimal — lean on **F-to-focus + two-finger scroll-zoom** rather than orbit-heavy flying. Two-finger press = middle-click.
- **One strongest path, no buffets.** Don't offer three ways to do a thing — give the one that works.
- **Don't dump a wall of code and say "find line 36."** When a fix is needed, hand back the **whole corrected block** ready to paste. (He called this out directly.)
- **Declare the next action** — never end on "what's next?" Tell him exactly what to press/click next.
- **Remind Ctrl+S** — the tab shows `main(*)` when unsaved.
- This is a **father-son build.** The emotional ROI is his son seeing the character move. Optimize sessions toward visible, playable wins the kid can touch, not invisible polish.

---

## 9. ROADMAP

| Stage | What | Status |
|---|---|---|
| A | Floor | ✅ done |
| B | Player body (CharacterBody3D + capsule) | ✅ done |
| C | Movement script (WASD/run/idle/jab) | ✅ done |
| D | Follow camera | ✅ done |
| — | Sun + sky (DirectionalLight3D + WorldEnvironment) | ✅ added |
| **E** | Framed door panel on a hinge + Area3D BreachZone | ✅ done (`door.tscn` / `door.gd`) |
| **F** | Breach loop: enter range → **F** → strike anim → door swings open | ✅ done — headless-validated, pending F5 playtest |
| + | Jump (Space), training dummy + jab hit-detection, textured noise floor | ✅ done |
| + | Room behind the door + reactive enemy inside it (`enemy.tscn` / `enemy.gd`) | ✅ done |
| + | Breach juice: `breach.wav` (synth placeholder), dust GPUParticles3D, camera shake | ✅ done — swap `breach.wav` for a real sound anytime |
| **G** | Signature door-kick (`Spartan_Kick`) + combo punches + heavy kick | ✅ done (Meshy clips, no Blender) |
| **G** | Jump animation clip (none in rig) | ▶ external (Meshy/Blender) |
| later | CHARACTER texture pass (Meshy AI auto-paint → re-export → swap breacher.glb) | deferred (environment is textured; the character is still gray clay) |
| later | Custom signature anims: real halligan door-kick + halligan swing (not in Meshy library — build later) | deferred |
| later | GitHub `black-breacher` repo via Claude Code (kills manual folder copying) | recommended |

**Resume point:** **F5** and play — WASD move, Shift run, **Space jump**, **J / left-click = punch combo**, **right-click = heavy kick**, **F = Spartan-kick breach** the door, then clear the room of 3 enemies. Remaining external work: character texture pass + a jump clip (both Meshy). Plenty of unused clips to wire into combat (`Dodge_and_Counter`, `Charged_Upward_Slash`, `Step_in_High_Kick`).

---

## 10. FILE MAP

- `C:/Users/djmc1/Documents/breacher/` — the Godot project (main.tscn, player.gd, breacher.glb, icon.svg)
- `/mnt/user-data/outputs/BLACK-BREACHER-IP-BIBLE.md` — full IP bible
- `/mnt/user-data/outputs/BLACK-BREACHER-3D-PIPELINE-WALKTHROUGH.md` — zero-to-walking beginner walkthrough (Meshy → Godot)
- `/mnt/user-data/outputs/black-breacher-logo.svg`, `black-breacher-steam-capsule.svg` — brand art
