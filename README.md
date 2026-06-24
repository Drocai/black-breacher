# Black Breacher

A 3D action game built in **Godot 4.7-stable** (Forward+ renderer, Jolt physics).

---

## Open the project

1. Launch the **Godot 4.7-stable** editor.
2. In the **Project Manager**, click **Import**.
3. Select the `project.godot` file in the root of this repo and open it.

> Requires Godot **4.7-stable**. Opening in an older 4.x build may upgrade/alter project files.

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
