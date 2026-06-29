# CLAUDE.md — Operating Contract for Black Breacher

> This file governs how any AI (Claude Code via `@claude`, or otherwise) works in this repo.
> It exists to prevent the mistakes that come from guessing and broad changes. Read it before
> acting. The **code and measured numbers are the source of truth — not older notes/SKILL.md.**

## What this project actually is
A complete **Godot 4.7-stable** (Forward+, Jolt physics) wave-based **stealth-brawler**: 3 campaign
arenas (`main.tscn`, `main2.tscn`, `main3.tscn`), a stealth/detection system, ~10 enemy archetypes,
a boss ("The Warden"), grenades, pickups, upgrades, HUD, title/victory, persistent save, plus a
Meshy asset pipeline (`tools/`) and headless capture/perf/playthrough harnesses. Binary assets are
**Git LFS** — run `git lfs install` once per machine or models arrive as broken stubs.

## The character fantasy
The Black Breacher is large, heavy, dominant — but the game still needs **readable, governed**
scale. "Big" is a measured number, not an eyeballed multiplier.

## HARD RULES (do not break without explicit approval)
1. **Measure before any scale / proportion / collision change.** Never type a scale multiplier you
   didn't derive from a measured height. Native mesh heights (measured 2026-06-29, corrected for the
   Meshy `Armature` 0.01 convention): **player `breacher.glb` = 1.91 m · `operator_swat` = 1.85 m ·
   `operator_merc` = 1.80 m.** Boss/brute use the breacher family (~1.91 m). The numbers live in
   `character_scale.gd` — use them.
3. **One approved task at a time.** Smallest reversible change. Branch + PR. Never push broad rewrites to `main`.
4. **Don't rename/delete/move** files, nodes, scenes, or vars unless that IS the approved task.
5. **Don't touch art direction, gameplay design, camera style, or the character concept** without approval.
   The enemy models are CORRECT — sizing only, no regen.
6. **Don't silently fix unrelated things.** Report them separately as follow-ups.
7. **No new dependencies/plugins/tools** without approval. No secrets/keys/tokens committed.
8. For every change: state files affected, reason, risk (low/med/high), and how to test it in Godot.

## The scale standard (single source of truth)
Encoded in `character_scale.gd`. Mirror table for humans:

| Character | Native | Target height | Correct scale | Was |
|---|---|---|---|---|
| Player (breacher) | 1.91 m | 1.98 m (6'6") | **1.04** | 1.55 (rendered 9'9") |
| Grunt (operator_swat) | 1.85 m | 1.78 m (5'10") | **0.96** | 0.90 (5'6") |
| Boss (Warden) | 1.91 m | 2.03 m (6'8") | **1.06** | 1.50 (9'5") |
| Brute | 1.91 m | ~1.96 m (6'5") | **~1.02** | 1.20 (7'6") |

Formula for any character: `node_scale = target_height / native_height`. Capsule height ≈ target
height; y-offset ≈ height / 2; radius ≈ height × 0.18–0.22. Apply scale at the **root node** going
forward (the player currently scales the mesh child; converting it to root-node scaling is a later
approved task).

## Task ledger (work top-down, one PR each)
1. ✅ **Player scale 1.55 → 1.04** in `main/main2/main3.tscn`. (Done — PR #16.)
2. ✅ **Grunt 0.90 → 0.96** (via `CharacterScale.GRUNT_SCALE`) and **boss 1.50 → 1.06**, **brute 1.20 → 1.02**.
3. ✅ Add `character_scale.gd` const holding the table above + a `capsule_for(height)` helper.
4. ✅ De-duplicate the grunt scale constant (`main*.tscn` Guard1/Guard2 + `wave_manager.gd`).
5. ⏳ Align collision capsules to corrected heights (player ~1.98 @ y0.99; boss/brute capsule height
   ~1.91 so it tracks the mesh). **Do this AFTER the visual scale is F5-verified** — capsules are
   derived from the verified heights. NOTE: player `AnimationPlayer.speed_scale = 0.654` in
   `main.tscn` is dead — `player.gd` `_ready()` forces `speed_scale = 1.0` in every arena, so there
   is no real cadence drift (audit item corrected).

## How we collaborate (roles)
- **PM (Cowork):** owns this ledger, writes issue specs, reviews PR diffs, merges, runs the daily standup.
- **Claude Code (`@claude`):** implements one issue at a time on a branch, opens a PR, follows these rules.
- **Derrick:** verifies in Godot (F5), approves direction, says when to merge.

## Test expectations
Prefer checks runnable in the Godot editor or by launching the game. For scale work: confirm visually
from gameplay camera AND editor scene view, feet on floor, no clipping, hits land at the right height.
If you can't verify directly, say so and state exactly what Derrick should check.
