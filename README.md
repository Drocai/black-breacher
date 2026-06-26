# Black Breacher

A 3D stealth-action brawler built in **Godot 4.7-stable** (Forward+ renderer, Jolt physics).

You play **the Black Breacher** — a large, brutal ex-military operator. **Black** = move
in the shadows: sneak past patrolling guards, break their line of sight, and take them
down silently for a *ghost bonus*. **Breacher** = come up hard: kick doors open, throw
bodies, smash crates, and fight through escalating waves of enemies into the boss room.
Clear the objective to advance to the next, harder mission. Score and best run persist.

---

## Open the project

1. Launch the **Godot 4.7-stable** editor.
2. In the **Project Manager**, click **Import**.
3. Select the `project.godot` file in the root of this repo and open it.

> Requires Godot **4.7-stable**. Opening in an older 4.x build may upgrade/alter project files.

Then press **F5** to play. (Press **H** in-game any time to toggle the controls overlay.)

---

## How to play

| Input | Action |
|---|---|
| **WASD / Arrows** | Move |
| **Shift** | Run |
| **C** | Sneak (slow, silent, harder to spot) |
| **Space** | Jump |
| **J / Left-click** | Strike — 4-hit combo (and **silent takedown** vs an unaware enemy) |
| **Right-click** | Heavy kick |
| **X** | Halligan sweep (long reach, wide arc) |
| **E** | Special launcher (knockback) |
| **Q** | Dodge (brief i-frames) |
| **Ctrl** (hold) | Block — tap as you're hit to **parry** |
| **V** | Grab, then **V** again to throw |
| **F** | Breach a door in range |
| **R** | Restart · **H** Toggle controls |

**The loop:** sneak the approach undetected (ghost bonus) → breach the door → survive
escalating waves of color-coded enemy types (they *telegraph* attacks — block/parry/dodge)
→ breach into the boss room → drop the boss → reach the objective → next mission.

---

## Version control & two-laptop sync

This repo **is** the sync layer between your laptops — not a cloud folder. Keep the
working copy **outside** OneDrive/Dropbox so a folder-sync service never fights git
over the `.git/` directory.

### Git LFS — read this first

Large binary assets (`.glb`, `.png`, `.wav`, etc.) are stored with **Git LFS**.

> **The second laptop must run `git lfs install` once — before its first clone or
> pull — or `.glb` and other binary assets will arrive as tiny broken pointer text
> files instead of real models.** This is a one-time, per-machine step.

### First-time setup on a NEW laptop

```bash
git lfs install
git clone https://github.com/Drocai/black-breacher.git
cd black-breacher
```

### Daily workflow

`main` is the shared branch. You push directly to it to move work between laptops.

**Before you start working** — pull the latest:

```bash
git pull
```

**When you're done** — save and upload your changes:

```bash
git add -A
git commit -m "Describe what you changed"
git push
```

That's the whole loop: `pull` before, `add`/`commit`/`push` after.

### How Claude Code contributes

Direct pushes to `main` are intentionally allowed so laptop-to-laptop sync stays
simple. For larger autonomous changes, Claude Code works on a **feature branch** and
opens a **pull request** into `main` for review — it does not push big changes
straight to `main`.

---

*Daddy Frequency Productions — Made by D RoC.*
