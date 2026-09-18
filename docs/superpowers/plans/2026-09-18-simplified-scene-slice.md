# Qiu Birthday Simplified Scene Slice Plan

> **For Claude Code:** Continue from completed Tasks 1-2. This plan supersedes Tasks 3+ in the original first-playable plan.

**Goal:** Reach the first real playable classroom slice with the fewest moving parts.

**Architecture:** Each story location is a self-contained Godot scene. Every map instances the shared Player and shared UI it needs. Scene transitions call `get_tree().change_scene_to_file(...)` directly. No persistent Game shell, SceneManager, spawn manager, JSON dialogue database, or narrative engine.

**Reference:** The scene-level structure intentionally follows the simplicity of `odylic/godot-town-demo`: reusable Player / Dialogue UI scenes inside each playable map, direct scene changes, and small scripts. Do not import its minimap, full map, house system, generated buildings, or other unused systems.

---

## Already complete

- Godot 4.7.2 project bootstrap.
- 640x360 logical viewport.
- Compatibility renderer.
- Shared `GameState` autoload.
- Shared `Player` scene with movement, collision, facing, interaction ray, and interaction signal.

Keep those unless a verified bug requires changing them.

---

## Decision: GameState access

Keep the current `/root/GameState` lookup used by `player.gd`.

Reason: it works in the actual game and in the existing `--script` headless test harness. Do not introduce a resolver/helper abstraction. Future scripts should only look up GameState when they genuinely need it.

---

## Decision: Godot metadata

- Commit generated `*.gd.uid` files.
- Commit `<asset>.import` files together with their corresponding source assets when those assets are added to Git.
- Keep `.godot/` ignored.
- For now, leave the existing local `art/` directory untracked until the first real scene selects the exact assets it needs.

---

## Revised Task 3: Build the first real S01 scene

Create:

```
scripts/interaction_target.gd
scripts/dialogue_box.gd
scripts/s01_classroom.gd

scenes/ui/dialogue_box.tscn
scenes/maps/s01_classroom.tscn
scenes/maps/test_destination.tscn

tests/test_s01_scene.gd
```

Modify:

```
project.godot
```

### S01 scene contract

`s01_classroom.tscn` must contain:

```
S01Classroom
├─ Background
├─ Collisions
├─ Player              # instance of scenes/core/player.tscn
├─ Story
│  └─ ClassroomEscape  # interaction target, event_id = classroom_escape
├─ DialogueBox          # instance of shared dialogue box
└─ FadeOverlay          # simple black ColorRect
```

Use the real classroom background from local `art/` if an obvious S01 classroom image exists. If filename ambiguity makes selection unsafe, use a flat placeholder and report the candidate filenames instead of guessing.

### interaction_target.gd

A tiny `Area2D` script:

- exported `event_id: StringName`
- method `interact(_player) -> StringName`
- returns the event id
- optional `one_time` boolean only if actually needed

Do not add conditions, quest logic, inventory requirements, or generic action systems.

### DialogueBox public API

Keep one small shared dialogue component.

Required public behavior:

- `show_lines(speaker: String, lines: Array[String])`
- Space / Enter advances while open
- mouse/touch can advance through a visible continue/confirm control if needed
- signal `finished`
- `show_choices(options: Array[String])`
- signal `choice_selected(index: int)`
- while open, GameState locks Player input
- when fully closed, dialogue lock is released

Do not parse JSON.

### S01 story logic

`s01_classroom.gd` connects Player's `interaction_requested`.

When `classroom_escape` fires:

1. Show:
   - speaker: 我
   - “现在溜出去的话，应该还赶得上早饭……”
   - “可是老师好像看到了？”

2. Show two choices:
   - “一天之计在于晨，回去早读”
   - “开什么玩笑，食堂甩卤面！”

3. Choice 0:
   - speaker: biu
   - “？？？”
   - “你今天吃错药了？”
   - then show the same two choices again

4. Choice 1:
   - speaker: 我
   - “走！”
   - fade to black
   - `get_tree().change_scene_to_file("res://scenes/maps/test_destination.tscn")`

No generic dialogue graph is required.

### test_destination.tscn

Only needs:
- visibly different background/ColorRect
- Player instance
- a Label saying TEST DESTINATION

This scene proves direct map changes work.

### project.godot

Change:

```
run/main_scene="res://scenes/maps/s01_classroom.tscn"
```

This removes the current missing-`game.tscn` editor error.

### Automated scene test

`tests/test_s01_scene.gd` should load and instantiate S01, then assert:

- Player exists.
- DialogueBox exists.
- ClassroomEscape exists.
- ClassroomEscape event_id is `classroom_escape`.
- Test destination loads.
- No parser errors.

Use the existing Godot console executable and `--quit-after 10`.

The test should print exactly:

```
PASS: s01 scene
```

### Manual acceptance

Run the scene and verify:

1. Classroom appears.
2. Player moves with WASD and arrows.
3. Player collision works.
4. Facing and interacting with ClassroomEscape opens dialogue.
5. Player cannot move while dialogue/choices are open.
6. Wrong choice shows the joke and returns to the choices.
7. Correct choice shows “走！”.
8. Fade occurs.
9. Test destination loads.

Commit:

```
feat: add first playable classroom scene
```

Stop after this task.

---

## Revised Task 4: Mobile controls and portrait guard

Only after revised Task 3 passes:

- shared touch directional controls
- one interact/confirm button
- mobile-only visibility
- portrait warning overlay
- pause input in portrait
- resume unchanged in landscape

No joystick physics; touch buttons press the same InputMap actions.

---

## Revised Task 5: Web export smoke test

Only after revised Task 4 passes:

- add Web export preset
- export release build
- serve via local HTTP
- desktop browser smoke test
- one real mobile browser smoke test

Stop framework work after this milestone.

---

## Revised Task 6: Content integration

Once the Web slice passes, build the actual game scene by scene:

1. S01 classroom
2. cafeteria
3. corridor
4. noon school gate
5. short electric-bike cutscene
6. internet cafe
7. return to school
8. afternoon exam classroom
9. after-school classroom/gate
10. 2026 birthday ending

For every new scene, prefer copying the working S01 scene and replacing:
- background
- collision shapes
- interaction targets
- tiny scene story script

Do not introduce infrastructure unless a real scene cannot be implemented cleanly without it.
