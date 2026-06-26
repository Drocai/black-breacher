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

**Character is now TEXTURED (June 2026)** — automated via `tools/meshy_retexture.py` (Meshy Retexture API). Gotcha: **retexture strips the rig/animations** (returns a static mesh), so the pipeline keeps the animated `breacher.glb` and applies the returned PBR maps (`textures/` → `breacher_material.tres`) as a `material_override` on the `char1` surface at runtime (`player.gd _apply_character_skin()`). Only external item left: a **jump animation clip** (none in the Meshy set).

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

**Full moveset (June 2026):** WASD move, Shift run, **Space jump**, **J/left-click = 4-hit combo** (jab→hook→upper hook→uppercut), **right-click = cycling heavy kicks**, **E = special launcher** (`Charged_Upward_Slash`, knockback, 2s cd), **Q = dodge** (i-frame dash, `Dodge_and_Counter`), **F = Spartan-kick breach**. All Meshy clips are now wired except `Boxing_Guard_Prep_Straight_Punch`/`Walking` (spare).

**Level (June 2026):** floor is 40×40; the room is now a big enclosed space (4m walls + ceiling, 2 interior lights, 3 cover crates) with a **2nd breach door** at the back into an **alcove** holding a glowing **objective** + an **elite enemy** (10 HP). 6 enemies total. Loop: breach front → fight through cover → breach back → drop the elite → AREA CLEAR.

**Autonomy:** `tools/meshy_retexture.py` drives the Meshy Retexture API (reads `MESHY_API_KEY` from env). Because retexture returns a static (un-rigged) mesh, the pipeline keeps the rigged glb and applies the PBR maps as a material — re-run anytime to re-skin. Blender MCP (start its server) covers procedural materials / mesh / anim ops.

**Environment textured (June 2026):** walls/ceiling concrete noise, crates + door wood noise, floor noise — matches the textured character. Win flow: objective trigger → **MISSION COMPLETE**, progressive HUD, **R** restarts.

**Combat depth (June 2026):** **ranged enemies** (`enemy_ranged`) that keep distance and lob **projectiles** (`projectile`); enemies drop spinning **health pickups** (`pickup`) on death; player **auto-faces the nearest enemy** when attacking; per-enemy hit sound; enemies cache the player ref (perf). New scripts: `enemy_ranged.gd`, `projectile.gd`, `pickup.gd` (+ scenes).

**Systems pass (June 2026):**
- **`Game` autoload** (`game.gd`) holds run state (kills/score/wave) + spawns shared FX. Reset by the wave manager on scene load.
- **Juice:** hitstop on impact, floating damage numbers (`damage_number`), hit sparks (`hitspark`), score/kills on HUD.
- **Block/parry:** hold **Ctrl** to block (cuts damage); block within 0.2s = parry (negate + stagger). `Boxing_Guard_Prep_Straight_Punch` is the guard pose.
- **Waves:** `wave_manager.gd` (on a node with Marker3D spawn points) spawns 3 escalating waves once the player enters the arena (z < -4); tracks its own `_alive` list so the pre-placed Boss doesn't block wave progress.
- **Boss room:** the back alcove is enlarged (8×8) into a boss arena past Door2; scaled-up Boss (16 HP) guards the objective. Removed the old training dummy.
- Re-skinned the character with a sharper Meshy prompt.

**Feel/camera/enemy pass (June 2026 — audit Pass 1):**
- Fixed a **floor fall-through** — the enlarged boss room (z-25) overran the old 40² floor; floor is now **60×60**. (Lesson: when extending the level, grow the Floor `size` to match.)
- **Combat feel:** attacks play 1.4× (the rig defaults to 0.654× = sluggish), every hit applies **hitstun + knockback** to enemies and a small screen shake.
- **Camera:** decoupled into `camera_rig.gd` (top-level `Camera3D`, group "camera") — smooth lerp follow + movement look-ahead + shake. `player.shake()` now forwards to it. **Jolt note:** non-uniform `scale` on a CharacterBody capsule errors — scale enemies uniformly only.
- **Enemies de-ballooned:** capsule + **head** sphere + noise-textured bodies; bigger boss (uniform 1.5×).
- 50-point audit recorded.

**Audit Pass 2 (June 2026):**
- **Mission progression:** clearing the objective advances `Game.mission` and reloads; difficulty scales (more enemies + scaled HP per mission). `R` = `Game.full_reset()`. `Game.reset()` only clears per-arena wave state now (mission/kills/score persist across reloads).
- **Enemy variety:** `wave_manager._spawn_enemy(kind)` spawns melee / ranged / **heavy** (slow, tanky, knockback-resistant) / **fast** (fragile, quick) by setting `@export` params before `add_child`.
- **FX:** muzzle flash on ranged shots, impact spark on projectile hit, spark+sound on block & parry. HUD shows MISSION + SCORE.
- **Still deferred (need visual pass):** navmesh (CSG bakes 0 polys — rebuild collision), spring-arm camera wall-collision, jump clip (Meshy export).

**Audit Pass 3 (June 2026 — presence):**
- **Walk sync fixed:** the rig was globally forced to `0.654×` (foot-sliding); now `anim.speed_scale = 1.0` and walk/run playback is driven per-frame by actual horizontal velocity (`_update_locomotion_anim(... hspeed)`). Also fixed a latent attack-timing mismatch (`_play_action` 1.4× is now truly 1.4×).
- **Footsteps:** `footstep.wav` (heavy thud) paced by speed → reinforces his weight.
- **Size presence:** regular enemies spawn at 0.9× so the Breacher towers; boss 1.5×. Brutal knockback (enemy `knockback_force` 6).

**Combat readability (June 2026):** melee enemies now **telegraph** — `_begin_attack` starts a 0.4s wind-up (red glow via per-instance duplicated `_mat`, anticipation pull-back, holds position), then `_land_attack` only deals damage if the player is still in range — so block/parry/dodge/step-out all work as reactions. Red **hit-flash** (emission pulse) on every hit. Per-enemy material is duplicated in `_ready` so flashes don't bleed across instances.

**Halligan + patrols (June 2026):**
- **Halligan** (`halligan.tscn`) is attached to the **RightHand bone** at runtime (`player._attach_halligan` via `BoneAttachment3D`). **Grip is tunable** in the Inspector: `halligan_offset`, `halligan_rotation_deg`, `halligan_scale` (the in-hand alignment is a first guess — adjust to taste). **X = heavy halligan sweep** (`_try_halligan`/`_apply_halligan_hit`): long reach (`halligan_range` 3.2), wide arc, knockback all, breaks crates, 1.4s cd.
- **Patrols:** unaware guards with `patrol_distance > 0` pace along their facing and turn home at the limit, sweeping their vision cone (Guard1/Guard2 set to 1.5). Stealth now has moving sightlines.

**Cinematic + stealth depth (June 2026):**
- **Hero-cam:** `camera_rig.punch_in(strength)` pulls the camera in + shakes on takedowns (1.0), finishers (0.8), grab-throws (0.7); decays over ~0.45s (`player._hero_cam`).
- **Line-of-sight:** unaware guards raycast to the player (`enemy._has_los`) — no seeing through walls/crates.
- **Alarm-spread:** a guard going alert wakes nearby guards <9m (`enemy._raise_alarm`); takedowns stay silent (don't alarm).
- Boss room has a menacing warm light now.

**Breach dynamics (June 2026):**
- **Breakable crates** (`crate.tscn`/`crate.gd`, group "breakable", wood-noise) — strike them to burst open and drop a pickup. `player._apply_melee_hit` now also damages the "breakable" group.
- **Finisher:** hitting an enemy that `is_staggered()` AND `health <= 4` executes it (`take_hit(999)` + extra shake/spark) — rewards setting up with special/grab-throw/shove.
- **Shove-aside:** `player._shove_aside(hspeed)` after `move_and_slide` staggers any "enemy" collider he barrels into at speed > 4 (his bulk reads in motion).

**Harden + save/log + grab-throw (June 2026):**
- **Save:** `Game` persists `best_score` + `missions_cleared` to `user://blackbreacher_save.cfg` (ConfigFile); loaded on boot, saved on mission clear (`Game.on_mission_cleared()`).
- **Logging:** `Game.log_event()` → `[BB] ...` prints (boot, mission cleared, takedown, player down).
- **Hardening:** `Engine.time_scale` normalized in both `Game._ready` and `player._ready` (so R during hitstop can't leave the game in slow-mo); null guards on `Game.spawn_*`.
- **GRAB + THROW = V** (`player._try_grab_or_throw`): grab a melee enemy in front (`enemy.grab`), V again to **throw** (`enemy.throw`) — thrown body is ballistic (`_thrown` in `enemy._physics`), and `_thrown_impact()` does AoE damage + stagger to nearby enemies then dies. Throw clip = `Charged_Upward_Slash`. While holding, attacks/dodge/block are gated (`_held_enemy` in `_busy`). HUD shows BEST.

**Stealth core landed (June 2026 — roadmap #1-4):** enemies have an `alerted` state; `start_alerted` (default true for wave/combat enemies) — **placed guards** set it false and start UNAWARE, scanning a vision cone (`initial_facing_deg`, `view_distance`, `view_dot`, `detect_time` in `enemy.gd::_update_unaware`). **Crouch-sneak = C** (toggle): slower (`sneak_speed`), silent (no footsteps), halves guard spot range (`player.sneaking`). **Stealth takedown:** attacking an unaware enemy in range (≤2.3m) is an instant kill (`_do_takedown`, uppercut finisher) — wired into `_try_jab`. Two unaware guards placed before the front door. HUD shows `[ SNEAKING ]`. Still TODO: LOS raycast, patrol routes, alarm spreading, dedicated takedown animation.

**THEME DIRECTION (use for all future gameplay work):** "Black Breacher" = **Black** (stealth — sneaking in shadows, stealth missions, then coming up brutal) + **Breacher** (breaching doors, people, and items/containers). His **large size must read everywhere** — vs enemies, doors, items, in actions and fighting. Next 20-point roadmap covers stealth (light/shadow visibility, crouch, takedowns, vision cones, noise), breaching (grab/throw people, kick open containers, breach finishers, loud-vs-quiet entries), and size-relevance (shove-aside, hero framing, grab-and-throw, halligan weapon).

**Resume point:** **F5** and play the full loop (textured character + environment, full moveset, win condition). Remaining: a **jump animation clip** (no Meshy jump anim yet — needs a Meshy export) and a **proper enemy navmesh** (a `NavigationRegion3D` bakes to 0 polys over CSG — needs the level rebuilt with real CollisionShape3D/MeshInstance boxes; interim sidestep avoidance is in `enemy.gd`). Then: balance the 6-enemy fight.

---

## 10. FILE MAP

- `C:/Users/djmc1/Documents/breacher/` — the Godot project (main.tscn, player.gd, breacher.glb, icon.svg)
- `/mnt/user-data/outputs/BLACK-BREACHER-IP-BIBLE.md` — full IP bible
- `/mnt/user-data/outputs/BLACK-BREACHER-3D-PIPELINE-WALKTHROUGH.md` — zero-to-walking beginner walkthrough (Meshy → Godot)
- `/mnt/user-data/outputs/black-breacher-logo.svg`, `black-breacher-steam-capsule.svg` — brand art
