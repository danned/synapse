# Repository Guidelines

## Project Structure & Module Organization

SYNAPSE is a Godot 4.7.2 project. `main.tscn` is the entry scene and attaches `scripts/main.gd`. Runtime code lives in `scripts/`; reusable systems use `class_name` declarations such as `GameController`, `NetworkGraph`, and `SaveService`. The custom test runner is `tests/run_tests.gd`. Engine settings are in `project.godot`, while `export_presets.cfg` defines the Web build. Treat `.godot/` and `dist/` as generated output; both are ignored.

## Build, Test, and Development Commands

```bash
godot --path .
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/run_tests.gd
mkdir -p dist/web
godot --headless --path . --export-release Web dist/web/index.html
python3 -m http.server 8060 --directory dist/web
```

The first command launches the game locally. In a fresh worktree, run the editor command once to build Godot's ignored class cache. The test command returns a nonzero exit code on failure. The remaining commands create and serve the Web export; install the Godot 4.7.2 Web export templates first.

## Coding Style & Naming Conventions

Follow existing GDScript style: tabs for indentation, `snake_case` for files, functions, and variables, and `PascalCase` for `class_name` types. Prefix internal helpers with `_`, add type annotations where they improve clarity, and keep signal names action-oriented. Preserve Godot-generated `.gd.uid` files. Prefer changing engine settings through the Godot editor because `project.godot` contains editor-managed values.

## Testing Guidelines

Tests use a lightweight `SceneTree` runner rather than an external framework. Name cases `_test_*`, call each new case from `_init()`, and assert through `_expect(condition, message)`. Use fixed seeds for generation tests and add regression coverage whenever game rules, graph behavior, saves, or progression change. No formal coverage threshold is configured; run the full headless suite before every merge.

## Worktrees, Commits, and Pull Requests

Never develop directly on `main`. Give every task or agent its own branch and worktree, for example:

```bash
git worktree add ../tower-defence-graph-fix -b fix/graph-routing main
```

Commit in that worktree. Before integration, rebase onto current `main`, rerun tests, then fast-forward from the primary checkout with `git merge --ff-only <branch>`. This keeps parallel work isolated and history linear.

Use concise Conventional Commit subjects such as `feat: add wave preview` or `fix: reject graph cycles`. Never add Codex attribution or a `Co-Authored-By: Codex` footer. Pull requests should explain behavior changes, report test results, link relevant issues, and include screenshots or recordings for visible UI changes.
