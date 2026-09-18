# Qiu's Birthday - Game Design Spec

Date: 2026-09-18

## 1. Goal

Create a very lightweight birthday gift game that recreates one ordinary but memorable high-school day shared by the player and her longtime friend.

The experience should feel simple, nostalgic, personal, and easy to play. It is not an RPG system and should not grow into one.

Primary target: Web only.

Supported controls:
- Desktop: WASD / arrow keys to move; Space or Enter to interact/confirm; mouse to click UI.
- Mobile: landscape only; on-screen directional controls plus one interact/confirm button; choices are tappable.
- Portrait mobile view: show a simple "请旋转手机 / 使用横屏游玩" overlay and pause gameplay until landscape orientation is restored.

## 2. Core Experience

The player controls her high-school self.

The game covers one school day:
1. Early morning classroom before morning reading.
2. Sneak to the cafeteria and eat noodles.
3. Classroom corridor and the "Tank" slip-of-the-tongue joke.
4. Noon dismissal and the choice to go to the internet cafe.
5. Short electric-bike transition.
6. Internet cafe, payment joke, and instant noodles.
7. Return to school and talk about confiscated phones.
8. Afternoon exam.
9. School ends.
10. Walk out through the school gate.
11. Transition directly to 2026.
12. Present-day friend waits with a birthday cake.

Estimated total play time: about 15-30 minutes.

## 3. Scope Principles

Keep the project deliberately small.

Do not add:
- Combat.
- Inventory systems.
- Stats or leveling.
- Quest logs.
- Complex save systems.
- Branching story trees.
- Crafting.
- Networking.
- Account systems.
- Multiplayer.
- TileMap-based level construction.
- Real-time lighting systems.
- Heavy shaders.
- Complex particle effects.
- A drivable vehicle system.

Choices are lightweight narrative interactions. Most choices either:
- Lead back to the remembered "real" outcome after a joke response, or
- Allow two funny answers that reconverge immediately.

## 4. Technical Direction

Engine: Godot 4.x stable.

Renderer: Compatibility.

Export: Web only.

Game structure:
- Each story location is a self-contained map scene.
- Each map instances the shared Player scene and shared UI scenes it needs.
- Scene changes use Godot's direct `get_tree().change_scene_to_file(...)` flow.
- `GameState` remains a very small autoload for input locks, shared input actions, and mobile-Web detection.
- No persistent Game shell or SceneManager is required.

Recommended logical viewport: 640x360, scaled to the browser window while keeping a 16:9 gameplay area.

The project should remain friendly to desktop and mobile browsers.

## 5. Scene Architecture

The project follows the same simple scene-level pattern used by small Godot town/adventure demos: each location is a complete playable scene.

Example map scene:

S01Classroom
- Background
- Static collisions
- Player (instance of the shared Player scene)
- NPC / interaction targets
- DialogueBox
- Optional mobile controls and orientation overlay

Moving to the next story location uses `get_tree().change_scene_to_file(...)`.

This deliberately avoids a persistent world shell, map manager, spawn manager, or other framework code that the short linear story does not need.

Each map is intentionally simple:
- One complete background PNG.
- Static collision shapes placed over walls, desks, counters, railings, and other blocked areas.
- Shared Player scene instance.
- NPC / interaction targets.
- Dialogue UI.
- Optional cutscene trigger areas.

No TileMap is required.

## 6. Player

The player uses CharacterBody2D.

Responsibilities:
- Four-direction movement.
- Four-direction animation.
- Collision.
- Track facing direction.
- Detect nearby interaction targets.
- Stop movement during dialogue, choices, transitions, and cutscenes.

The Player should not contain story-specific code.

Desktop input:
- W / Up: move up.
- S / Down: move down.
- A / Left: move left.
- D / Right: move right.
- Space / Enter: interact / advance / confirm.

Mobile input:
- On-screen directional controls.
- One interact / confirm button.

The same InputMap actions must drive both desktop and mobile controls so gameplay code is shared.

## 7. Interaction System

Use a small reusable interaction interface.

Interactive targets may include:
- NPCs.
- Doors.
- Story triggers.
- Specific props.

When the player is close enough and facing a target:
- Show a small interaction hint such as "!".
- Pressing interact starts the target's assigned event.

Interaction targets should expose data such as:
- event_id
- optional one_time flag
- optional enabled condition

Story logic should not be hard-coded into the Player.

## 8. Dialogue and Choice System

Keep dialogue deliberately small and scene-driven.

Use one shared DialogueBox scene with a small public API:
- show one or more lines.
- advance lines.
- optionally show two choices.
- emit which choice was selected.
- emit when the current dialogue sequence finishes.

Each map script owns only the tiny amount of story flow needed in that location. Do not add JSON parsing, a dialogue graph engine, or a general-purpose narrative framework unless the real content later proves it necessary.

Choice types needed:
1. Memory choice: one answer produces a joke/reaction and returns to the intended outcome.
2. Reconverging choice: both answers have slightly different text but return to the same next story beat.

## 9. Game State

Use one lightweight global GameState.

It only needs to track data required by the story, for example:
- Current map.
- Completed one-time events.
- A small set of temporary flags.
- Input lock state.

Do not build a full save/load UI for the first version.

If persistence is later needed, only store minimal progress in browser-local storage. This is optional and outside the first playable milestone.

## 10. Scene Transition

Scene transitions are direct and linear.

A map may:
1. Lock input.
2. Optionally fade to black.
3. Call `get_tree().change_scene_to_file(target_scene)`.

The destination map defines its own Player start position, so no spawn manager is required for the main linear story.

The electric-bike segment is not player-controlled. It is a short 5-8 second transition/cutscene between the school gate and internet cafe.

## 11. UI

Visual style:
- Dark blue-gray panels.
- White text.
- Pale yellow selection/highlight.
- Pixel-art presentation matching the approved art direction.

Only essential UI:
- Dialogue box.
- Speaker name.
- Character portrait when needed.
- Two-choice panel when needed.
- Interaction hint.
- Mobile directional controls.
- Mobile interact button.
- Fade overlay.
- Portrait-orientation warning overlay.

No HUD is required during normal walking.

Desktop should not show mobile controls.

## 12. Mobile Web Behaviour

The game is landscape-only on mobile.

Portrait mode:
- Pause movement and story input.
- Display a full-screen orientation message.
- Resume automatically when the browser returns to landscape.

Touch controls should be large enough for a phone but visually unobtrusive.

UI must respect browser safe areas where practical.

Audio must only begin after a user gesture if required by the browser.

## 13. Asset Assumptions

Art assets are prepared separately and will be added by the user.

Expected categories:
- Full-scene backgrounds.
- Player sprite frames.
- Important NPC sprite frames.
- Static NPC sprites.
- Portraits.
- UI assets.
- Props.
- Optional transition/cutscene images.
- Music and sound effects.

Implementation must tolerate assets being added incrementally.

For the first playable milestone, placeholders may be used wherever final art has not yet been copied into the repository.

## 14. First Playable Milestone

Build only enough to prove the whole architecture.

The milestone is complete when a browser build can:

1. Open successfully.
2. Show the orientation overlay in mobile portrait mode.
3. Enter a test version of the S01 classroom.
4. Spawn the player.
5. Move with WASD / arrow keys.
6. Move with mobile directional controls.
7. Collide with room obstacles.
8. Detect a nearby NPC.
9. Show an interaction hint.
10. Start dialogue with Space / Enter / mobile interact.
11. Advance through multiple dialogue lines.
12. Show two choices.
13. Select choices using keyboard, mouse, or touch.
14. Execute the selected branch.
15. Fade out.
16. Load a second test map or test destination.
17. Fade back in with the player at the correct spawn point.

Do not implement later story scenes until this milestone passes.

## 15. Testing

For each implementation step, verify:
- No parser or runtime errors in Godot.
- Desktop keyboard controls work.
- Mouse choice selection works.
- Touch controls do not affect desktop layout.
- Player cannot walk through configured collisions.
- Dialogue locks player movement.
- Choices cannot be triggered twice.
- Scene transition cannot be started twice at the same time.
- Player spawns correctly after a transition.
- Portrait/landscape switching does not break the game state.

Web smoke test:
- Desktop Chromium-based browser.
- One mobile browser or responsive/mobile-device test.
- Refresh after loading.
- Resize between landscape and portrait.

## 16. Repository Structure

Suggested structure:

```
res://
  assets/
    backgrounds/
    characters/
    portraits/
    props/
    ui/
    audio/

  scenes/
    core/
      player.tscn
    ui/
      dialogue_box.tscn
      touch_controls.tscn
      orientation_overlay.tscn
    maps/
      s01_classroom.tscn
      test_destination.tscn

  scripts/
    game_state.gd
    player.gd
    interaction_target.gd
    dialogue_box.gd
    s01_classroom.gd
```

The exact file names may change slightly during implementation if Godot conventions make a simpler structure clearer, but the architectural boundaries should remain.

## 17. Definition of Done for the Full Gift

The project is finished when:
- The complete one-day story is playable from start to finish.
- All required scenes use the final artwork.
- Desktop and mobile-landscape controls work.
- The game runs from a Web build through a shareable URL.
- The final school-gate transition reaches the 2026 birthday scene.
- There are no systems beyond what this short story actually needs.

The governing principle for every implementation decision is: choose the simplest solution that preserves the intended memory, humour, and final emotional transition.
