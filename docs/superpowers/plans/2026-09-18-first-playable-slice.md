# Qiu Birthday First Playable Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the smallest complete Godot Web vertical slice: S01 placeholder classroom, four-direction movement, collision, interaction, dialogue, two choices, mobile landscape controls, and a fade transition to a second placeholder map.

**Architecture:** A persistent `Game` scene owns `World`, `Player`, and `UI`. Maps are lightweight `Node2D` scenes swapped inside `World`; the player and UI persist. Dialogue is JSON-driven. A tiny `GameState` autoload owns input locks and common platform checks.

**Tech Stack:** Godot 4.x stable, GDScript, Compatibility renderer, Web export, JSON dialogue data.

---

## Scope guard

This plan intentionally does **not** implement the full birthday story. It proves the reusable architecture with two placeholder maps. Do not add inventory, saves, quests, combat, TileMap, vehicle driving, complex animation state machines, or deployment automation in this plan.

After this slice passes, later content work should mostly be: copy a map scene, replace the background, draw collisions, place NPC interaction areas, and add JSON dialogue.

## File map

Create these files:

```
project.godot
.gitignore
README.md
export_presets.cfg

scripts/
  game_state.gd
  game.gd
  player.gd
  interaction_target.gd
  dialogue_ui.gd
  touch_controls.gd
  orientation_overlay.gd

scenes/
  core/
    game.tscn
    player.tscn
  ui/
    dialogue_ui.tscn
    touch_controls.tscn
    orientation_overlay.tscn
  maps/
    s01_classroom.tscn
    test_destination.tscn

data/
  dialogue/
    s01.json

tests/
  test_bootstrap.gd
  test_player.gd
  test_map_contract.gd
  test_dialogue.gd
  test_game_smoke.gd
```

Responsibilities:

- `game_state.gd`: input-lock reasons, runtime input actions, mobile-Web detection.
- `game.gd`: persistent shell, map swapping, spawn placement, fade transitions, dialogue actions.
- `player.gd`: movement, facing, ray interaction.
- `interaction_target.gd`: reusable `Area2D` carrying an `event_id`.
- `dialogue_ui.gd`: load JSON events, show lines, render choices, emit actions.
- `touch_controls.gd`: mobile-only buttons that press the same InputMap actions as keyboard.
- `orientation_overlay.gd`: mobile portrait warning and orientation input lock.
- Map scenes: background/placeholder geometry, collisions, spawn points, interaction targets only.
- Tests: headless contract/smoke tests using built-in GDScript assertions; no third-party test framework.

---

### Task 1: Bootstrap the Godot project

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `README.md`
- Create: `tests/test_bootstrap.gd`

- [ ] **Step 1: Create the failing bootstrap test**

Create `tests/test_bootstrap.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	assert(ProjectSettings.get_setting("display/window/size/viewport_width", 0) == 640)
	assert(ProjectSettings.get_setting("display/window/size/viewport_height", 0) == 360)
	assert(ProjectSettings.get_setting("rendering/renderer/rendering_method", "") == "gl_compatibility")
	assert(ProjectSettings.has_setting("application/run/main_scene"))
	print("PASS: bootstrap")
	quit()
```

- [ ] **Step 2: Run the bootstrap test and verify it fails**

Run from repository root:

```bash
godot --headless --path . --script res://tests/test_bootstrap.gd
```

If the executable is named `godot4` on this machine, use that exact executable for all later commands.

Expected before `project.godot` exists: non-zero exit or assertion failure because project settings are missing.

- [ ] **Step 3: Create the minimal project configuration**

Create `project.godot`:

```ini
[application]

config/name="Qiu's Birthday"
run/main_scene="res://scenes/core/game.tscn"

[display]

window/size/viewport_width=640
window/size/viewport_height=360
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
textures/canvas_textures/default_texture_filter=0
```

Create `.gitignore`:

```gitignore
.godot/
build/
.DS_Store
Thumbs.db
```

Create `README.md`:

```markdown
# Qiu's Birthday

A very small Web-only Godot birthday gift game.

## Development target

- Godot 4.x stable
- Compatibility renderer
- Logical viewport: 640x360
- Desktop: WASD / arrows + Space / Enter + mouse
- Mobile: landscape + touch controls

## Principle

Keep the game small. Story, movement, dialogue, choices, and scene transitions are enough.
```

- [ ] **Step 4: Run the bootstrap test**

Run:

```bash
godot --headless --path . --script res://tests/test_bootstrap.gd
```

Expected:

```text
PASS: bootstrap
```

- [ ] **Step 5: Commit**

```bash
git add project.godot .gitignore README.md tests/test_bootstrap.gd
git commit -m "chore: bootstrap Godot web project"
```

---

### Task 2: Add GameState and the Player

**Files:**
- Create: `scripts/game_state.gd`
- Create: `scripts/player.gd`
- Create: `scenes/core/player.tscn`
- Modify: `project.godot`
- Create: `tests/test_player.gd`

- [ ] **Step 1: Write the failing Player contract test**

Create `tests/test_player.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var packed := load("res://scenes/core/player.tscn") as PackedScene
	assert(packed != null)

	var player := packed.instantiate()
	assert(player.has_signal("interaction_requested"))
	assert(player.get("speed") > 0.0)

	var ray := player.get_node_or_null("InteractionRay")
	assert(ray is RayCast2D)
	assert(ray.collision_mask == 2)

	player.free()
	print("PASS: player")
	quit()
```

- [ ] **Step 2: Run it and verify failure**

```bash
godot --headless --path . --script res://tests/test_player.gd
```

Expected: FAIL because `scenes/core/player.tscn` does not exist.

- [ ] **Step 3: Implement the lightweight global state**

Create `scripts/game_state.gd`:

```gdscript
extends Node

var _locks: Dictionary = {}

func _ready() -> void:
	_ensure_input_actions()

func set_lock(reason: StringName, enabled: bool) -> void:
	if enabled:
		_locks[reason] = true
	else:
		_locks.erase(reason)

func is_input_locked() -> bool:
	return not _locks.is_empty()

func clear_locks() -> void:
	_locks.clear()

func is_mobile_web() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios")

func _ensure_input_actions() -> void:
	_ensure_key_action(&"move_up", [KEY_W, KEY_UP])
	_ensure_key_action(&"move_down", [KEY_S, KEY_DOWN])
	_ensure_key_action(&"move_left", [KEY_A, KEY_LEFT])
	_ensure_key_action(&"move_right", [KEY_D, KEY_RIGHT])
	_ensure_key_action(&"interact", [KEY_SPACE, KEY_ENTER])

func _ensure_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	if not InputMap.action_get_events(action).is_empty():
		return

	for key_code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key_code
		InputMap.action_add_event(action, event)
```

Modify `project.godot` by adding:

```ini
[autoload]

GameState="*res://scripts/game_state.gd"
```

Create `scripts/player.gd`:

```gdscript
extends CharacterBody2D

signal interaction_requested(event_id: StringName)

@export var speed: float = 92.0

@onready var interaction_ray: RayCast2D = $InteractionRay

var facing: Vector2 = Vector2.DOWN

func _physics_process(_delta: float) -> void:
	if GameState.is_input_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if input_vector != Vector2.ZERO:
		facing = _cardinal_direction(input_vector)
		interaction_ray.target_position = facing * 22.0

	velocity = input_vector * speed
	move_and_slide()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _cardinal_direction(value: Vector2) -> Vector2:
	if abs(value.x) > abs(value.y):
		return Vector2.RIGHT if value.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if value.y > 0.0 else Vector2.UP

func _try_interact() -> void:
	if not interaction_ray.is_colliding():
		return

	var target := interaction_ray.get_collider()
	if target == null or not target.has_method("interact"):
		return

	var event_id: StringName = target.interact(self)
	if event_id != &"":
		interaction_requested.emit(event_id)
```

Create `scenes/core/player.tscn`:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/player.gd" id="1_player"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(12, 16)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_visual"]
size = Vector2(14, 20)

[node name="Player" type="CharacterBody2D"]
collision_layer = 1
collision_mask = 1
script = ExtResource("1_player")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-7, -10, 7, -10, 7, 10, -7, 10)
color = Color(0.36, 0.62, 0.85, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, 2)
shape = SubResource("RectangleShape2D_player")

[node name="InteractionRay" type="RayCast2D" parent="."]
target_position = Vector2(0, 22)
collision_mask = 2
collide_with_areas = true
collide_with_bodies = false
```

- [ ] **Step 4: Run the Player test**

```bash
godot --headless --path . --script res://tests/test_player.gd
```

Expected:

```text
PASS: player
```

Also run a parser/import check:

```bash
godot --headless --path . --editor --quit
```

Expected: exit code 0 and no GDScript parser errors.

- [ ] **Step 5: Commit**

```bash
git add project.godot scripts/game_state.gd scripts/player.gd scenes/core/player.tscn tests/test_player.gd
git commit -m "feat: add shared input state and player movement"
```

---

### Task 3: Add reusable maps, collisions, and interaction targets

**Files:**
- Create: `scripts/interaction_target.gd`
- Create: `scenes/maps/s01_classroom.tscn`
- Create: `scenes/maps/test_destination.tscn`
- Create: `tests/test_map_contract.gd`

- [ ] **Step 1: Write the failing map contract test**

Create `tests/test_map_contract.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	for path in [
		"res://scenes/maps/s01_classroom.tscn",
		"res://scenes/maps/test_destination.tscn",
	]:
		var packed := load(path) as PackedScene
		assert(packed != null)

		var map := packed.instantiate()
		assert(map.get_node_or_null("SpawnPoints/Default") is Marker2D)
		map.free()

	var classroom_packed := load("res://scenes/maps/s01_classroom.tscn") as PackedScene
	var classroom := classroom_packed.instantiate()
	var target := classroom.get_node_or_null("Story/ClassroomEscape")
	assert(target is Area2D)
	assert(target.get("event_id") == &"classroom_escape")
	classroom.free()

	print("PASS: map contract")
	quit()
```

- [ ] **Step 2: Run it and verify failure**

```bash
godot --headless --path . --script res://tests/test_map_contract.gd
```

Expected: FAIL because the map scenes do not exist.

- [ ] **Step 3: Add the reusable interaction target**

Create `scripts/interaction_target.gd`:

```gdscript
extends Area2D

@export var event_id: StringName
@export var one_time: bool = false

var _used: bool = false

func interact(_player: Node) -> StringName:
	if one_time and _used:
		return &""

	_used = true
	return event_id
```

- [ ] **Step 4: Create the placeholder S01 classroom**

Create `scenes/maps/s01_classroom.tscn`:

```ini
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://scripts/interaction_target.gd" id="1_target"]

[sub_resource type="RectangleShape2D" id="Shape_top"]
size = Vector2(640, 16)

[sub_resource type="RectangleShape2D" id="Shape_side"]
size = Vector2(16, 360)

[sub_resource type="RectangleShape2D" id="Shape_desk"]
size = Vector2(150, 44)

[sub_resource type="CircleShape2D" id="Shape_interact"]
radius = 16.0

[node name="S01Classroom" type="Node2D"]

[node name="Background" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, 0, 640, 0, 640, 360, 0, 360)
color = Color(0.82, 0.76, 0.62, 1)

[node name="FrontBoard" type="Polygon2D" parent="."]
polygon = PackedVector2Array(170, 24, 470, 24, 470, 80, 170, 80)
color = Color(0.12, 0.29, 0.22, 1)

[node name="DeskVisual" type="Polygon2D" parent="."]
polygon = PackedVector2Array(245, 158, 395, 158, 395, 202, 245, 202)
color = Color(0.39, 0.25, 0.15, 1)

[node name="Walls" type="Node2D" parent="."]

[node name="Top" type="StaticBody2D" parent="Walls"]
position = Vector2(320, 8)
collision_layer = 1
collision_mask = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/Top"]
shape = SubResource("Shape_top")

[node name="Bottom" type="StaticBody2D" parent="Walls"]
position = Vector2(320, 352)
collision_layer = 1
collision_mask = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/Bottom"]
shape = SubResource("Shape_top")

[node name="Left" type="StaticBody2D" parent="Walls"]
position = Vector2(8, 180)
collision_layer = 1
collision_mask = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/Left"]
shape = SubResource("Shape_side")

[node name="Right" type="StaticBody2D" parent="Walls"]
position = Vector2(632, 180)
collision_layer = 1
collision_mask = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/Right"]
shape = SubResource("Shape_side")

[node name="Desk" type="StaticBody2D" parent="."]
position = Vector2(320, 180)
collision_layer = 1
collision_mask = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="Desk"]
shape = SubResource("Shape_desk")

[node name="SpawnPoints" type="Node2D" parent="."]

[node name="Default" type="Marker2D" parent="SpawnPoints"]
position = Vector2(120, 270)

[node name="Story" type="Node2D" parent="."]

[node name="NpcVisual" type="Polygon2D" parent="Story"]
polygon = PackedVector2Array(-7, -10, 7, -10, 7, 10, -7, 10)
position = Vector2(520, 220)
color = Color(0.74, 0.39, 0.42, 1)

[node name="ClassroomEscape" type="Area2D" parent="Story"]
position = Vector2(520, 220)
collision_layer = 2
collision_mask = 0
monitorable = true
script = ExtResource("1_target")
event_id = &"classroom_escape"

[node name="CollisionShape2D" type="CollisionShape2D" parent="Story/ClassroomEscape"]
shape = SubResource("Shape_interact")
```

Create `scenes/maps/test_destination.tscn`:

```ini
[gd_scene format=3]

[node name="TestDestination" type="Node2D"]

[node name="Background" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, 0, 640, 0, 640, 360, 0, 360)
color = Color(0.39, 0.55, 0.39, 1)

[node name="Title" type="Label" parent="."]
offset_left = 210.0
offset_top = 145.0
offset_right = 430.0
offset_bottom = 185.0
text = "TEST DESTINATION"
horizontal_alignment = 1

[node name="SpawnPoints" type="Node2D" parent="."]

[node name="Default" type="Marker2D" parent="SpawnPoints"]
position = Vector2(320, 250)
```

- [ ] **Step 5: Run the map contract test**

```bash
godot --headless --path . --script res://tests/test_map_contract.gd
```

Expected:

```text
PASS: map contract
```

- [ ] **Step 6: Commit**

```bash
git add scripts/interaction_target.gd scenes/maps/s01_classroom.tscn scenes/maps/test_destination.tscn tests/test_map_contract.gd
git commit -m "feat: add reusable map and interaction contract"
```

---

### Task 4: Add data-driven dialogue and choices

**Files:**
- Create: `data/dialogue/s01.json`
- Create: `scripts/dialogue_ui.gd`
- Create: `scenes/ui/dialogue_ui.tscn`
- Create: `tests/test_dialogue.gd`

- [ ] **Step 1: Write the failing dialogue test**

Create `tests/test_dialogue.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var packed := load("res://scenes/ui/dialogue_ui.tscn") as PackedScene
	assert(packed != null)

	var ui := packed.instantiate()
	root.add_child(ui)
	await process_frame

	assert(ui.has_event(&"classroom_escape"))
	assert(ui.has_event(&"classroom_wrong_choice"))
	assert(ui.has_event(&"classroom_go_canteen"))

	var event_data: Dictionary = ui.get_event(&"classroom_escape")
	assert(event_data.get("choices", []).size() == 2)

	ui.queue_free()
	await process_frame

	print("PASS: dialogue")
	quit()
```

- [ ] **Step 2: Run it and verify failure**

```bash
godot --headless --path . --script res://tests/test_dialogue.gd
```

Expected: FAIL because the dialogue scene does not exist.

- [ ] **Step 3: Create the first dialogue data**

Create `data/dialogue/s01.json`:

```json
{
  "classroom_escape": {
    "lines": [
      {
        "speaker": "我",
        "text": "现在溜出去的话，应该还赶得上早饭……"
      },
      {
        "speaker": "我",
        "text": "可是老师好像看到了？"
      }
    ],
    "choices": [
      {
        "text": "一天之计在于晨，回去早读",
        "next": "classroom_wrong_choice"
      },
      {
        "text": "开什么玩笑，食堂甩卤面！",
        "next": "classroom_go_canteen"
      }
    ]
  },
  "classroom_wrong_choice": {
    "lines": [
      {
        "speaker": "biu",
        "text": "？？？"
      },
      {
        "speaker": "biu",
        "text": "你今天吃错药了？"
      }
    ],
    "next": "classroom_escape"
  },
  "classroom_go_canteen": {
    "lines": [
      {
        "speaker": "我",
        "text": "走！"
      }
    ],
    "action": {
      "type": "change_map",
      "map": "res://scenes/maps/test_destination.tscn",
      "spawn": "Default"
    }
  }
}
```

- [ ] **Step 4: Implement the dialogue UI controller**

Create `scripts/dialogue_ui.gd`:

```gdscript
extends Control

signal action_requested(action: Dictionary)

@onready var name_label: Label = %NameLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var choices_box: VBoxContainer = %ChoicesBox

var _database: Dictionary = {}
var _current_event: Dictionary = {}
var _line_index: int = 0
var _choices_visible: bool = false

func _ready() -> void:
	visible = false
	_load_dialogue_directory("res://data/dialogue")

func has_event(event_id: StringName) -> bool:
	return _database.has(String(event_id))

func get_event(event_id: StringName) -> Dictionary:
	return _database.get(String(event_id), {})

func start_event(event_id: StringName) -> void:
	if not has_event(event_id):
		push_warning("Unknown dialogue event: %s" % event_id)
		return

	GameState.set_lock(&"dialogue", true)
	visible = true
	_show_event(String(event_id))

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _choices_visible:
		return

	if event.is_action_pressed("interact"):
		advance()
		get_viewport().set_input_as_handled()

func advance() -> void:
	var lines: Array = _current_event.get("lines", [])
	if lines.is_empty():
		_finish_event()
		return

	_line_index += 1
	if _line_index < lines.size():
		_show_line(lines[_line_index])
		return

	_after_lines()

func _show_event(event_id: String) -> void:
	_clear_choices()
	_current_event = _database[event_id]
	_line_index = 0

	var lines: Array = _current_event.get("lines", [])
	if lines.is_empty():
		_after_lines()
	else:
		_show_line(lines[0])

func _show_line(line: Dictionary) -> void:
	name_label.text = str(line.get("speaker", ""))
	body_label.text = str(line.get("text", ""))

func _after_lines() -> void:
	var choices: Array = _current_event.get("choices", [])
	if not choices.is_empty():
		_show_choices(choices)
		return

	if _current_event.has("next"):
		_show_event(str(_current_event["next"]))
		return

	_finish_event()

func _show_choices(choices: Array) -> void:
	_choices_visible = true
	choices_box.visible = true

	for choice_value in choices:
		var choice: Dictionary = choice_value
		var button := Button.new()
		button.text = str(choice.get("text", ""))
		button.custom_minimum_size = Vector2(0, 34)
		button.pressed.connect(_select_choice.bind(choice))
		choices_box.add_child(button)

	if choices_box.get_child_count() > 0:
		var first_button := choices_box.get_child(0) as Button
		first_button.grab_focus()

func _select_choice(choice: Dictionary) -> void:
	if choice.has("next"):
		_show_event(str(choice["next"]))
		return

	if choice.has("action"):
		_finish_with_action(choice["action"])
		return

	_finish_event()

func _finish_event() -> void:
	var action: Dictionary = _current_event.get("action", {})
	_clear_choices()
	visible = false
	GameState.set_lock(&"dialogue", false)

	if not action.is_empty():
		action_requested.emit(action)

func _finish_with_action(action: Dictionary) -> void:
	_clear_choices()
	visible = false
	GameState.set_lock(&"dialogue", false)
	action_requested.emit(action)

func _clear_choices() -> void:
	_choices_visible = false
	choices_box.visible = false
	for child in choices_box.get_children():
		child.queue_free()

func _load_dialogue_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Dialogue directory not found: %s" % path)
		return

	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() != "json":
			continue

		var file := FileAccess.open(path.path_join(file_name), FileAccess.READ)
		if file == null:
			continue

		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_database.merge(parsed, true)
```

Create `scenes/ui/dialogue_ui.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/dialogue_ui.gd" id="1_dialogue"]

[node name="DialogueUI" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_dialogue")

[node name="Panel" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 12
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 36.0
offset_top = -126.0
offset_right = -36.0
offset_bottom = -16.0
grow_horizontal = 2
grow_vertical = 0
mouse_filter = 1

[node name="NameLabel" type="Label" parent="Panel"]
unique_name_in_owner = true
layout_mode = 0
offset_left = 14.0
offset_top = 10.0
offset_right = 150.0
offset_bottom = 34.0
text = "我"

[node name="BodyLabel" type="RichTextLabel" parent="Panel"]
unique_name_in_owner = true
layout_mode = 0
offset_left = 14.0
offset_top = 34.0
offset_right = 548.0
offset_bottom = 92.0
fit_content = true
scroll_active = false

[node name="ChoicesBox" type="VBoxContainer" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -190.0
offset_top = -52.0
offset_right = 190.0
offset_bottom = 52.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 8
```

- [ ] **Step 5: Run the dialogue test**

```bash
godot --headless --path . --script res://tests/test_dialogue.gd
```

Expected:

```text
PASS: dialogue
```

- [ ] **Step 6: Commit**

```bash
git add data/dialogue/s01.json scripts/dialogue_ui.gd scenes/ui/dialogue_ui.tscn tests/test_dialogue.gd
git commit -m "feat: add data-driven dialogue and choices"
```

---

### Task 5: Build the persistent Game shell and map transition

**Files:**
- Create: `scripts/game.gd`
- Create: `scenes/core/game.tscn`
- Create: `tests/test_game_smoke.gd`

- [ ] **Step 1: Write the failing game smoke test**

Create `tests/test_game_smoke.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var packed := load("res://scenes/core/game.tscn") as PackedScene
	assert(packed != null)

	var game := packed.instantiate()
	root.add_child(game)

	await process_frame
	await process_frame

	assert(game.get_node_or_null("World/S01Classroom") != null)
	assert(game.get_node_or_null("Player") != null)
	assert(game.get_node_or_null("UI/DialogueUI") != null)

	var player := game.get_node("Player") as CharacterBody2D
	assert(player.global_position == Vector2(120, 270))

	game.queue_free()
	await process_frame

	print("PASS: game smoke")
	quit()
```

- [ ] **Step 2: Run it and verify failure**

```bash
godot --headless --path . --script res://tests/test_game_smoke.gd
```

Expected: FAIL because `scenes/core/game.tscn` does not exist.

- [ ] **Step 3: Implement the persistent shell**

Create `scripts/game.gd`:

```gdscript
extends Node2D

@export_file("*.tscn") var initial_map_path: String = "res://scenes/maps/s01_classroom.tscn"
@export var initial_spawn: String = "Default"

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var dialogue_ui: Control = $UI/DialogueUI
@onready var transition_overlay: ColorRect = $UI/TransitionOverlay

var _transitioning: bool = false

func _ready() -> void:
	player.interaction_requested.connect(_on_interaction_requested)
	dialogue_ui.action_requested.connect(_on_dialogue_action)
	await get_tree().process_frame
	await change_map(initial_map_path, initial_spawn, false)

func _on_interaction_requested(event_id: StringName) -> void:
	dialogue_ui.start_event(event_id)

func _on_dialogue_action(action: Dictionary) -> void:
	if str(action.get("type", "")) != "change_map":
		return

	var map_path := str(action.get("map", ""))
	var spawn_name := str(action.get("spawn", "Default"))

	if map_path.is_empty():
		push_warning("change_map action missing map path")
		return

	await change_map(map_path, spawn_name, true)

func change_map(map_path: String, spawn_name: String = "Default", use_fade: bool = true) -> void:
	if _transitioning:
		return

	_transitioning = true
	GameState.set_lock(&"transition", true)

	if use_fade:
		await _fade_to(1.0)

	for child in world.get_children():
		world.remove_child(child)
		child.free()

	var packed := load(map_path) as PackedScene
	if packed == null:
		push_error("Could not load map: %s" % map_path)
		GameState.set_lock(&"transition", false)
		_transitioning = false
		return

	var map := packed.instantiate()
	world.add_child(map)
	await get_tree().process_frame

	var spawn := map.get_node_or_null("SpawnPoints/%s" % spawn_name) as Marker2D
	if spawn == null:
		push_warning("Spawn not found: %s in %s" % [spawn_name, map_path])
	else:
		player.global_position = spawn.global_position

	if use_fade:
		await _fade_to(0.0)

	GameState.set_lock(&"transition", false)
	_transitioning = false

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(transition_overlay, "modulate:a", alpha, 0.18)
	await tween.finished
```

Create `scenes/core/game.tscn`:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/game.gd" id="1_game"]
[ext_resource type="PackedScene" path="res://scenes/core/player.tscn" id="2_player"]
[ext_resource type="PackedScene" path="res://scenes/ui/dialogue_ui.tscn" id="3_dialogue"]

[node name="Game" type="Node2D"]
script = ExtResource("1_game")

[node name="World" type="Node2D" parent="."]

[node name="Player" parent="." instance=ExtResource("2_player")]

[node name="UI" type="CanvasLayer" parent="."]

[node name="DialogueUI" parent="UI" instance=ExtResource("3_dialogue")]

[node name="TransitionOverlay" type="ColorRect" parent="UI"]
layout_mode = 0
offset_right = 640.0
offset_bottom = 360.0
mouse_filter = 2
color = Color(0, 0, 0, 1)
modulate = Color(1, 1, 1, 0)
```

- [ ] **Step 4: Run the game smoke test**

```bash
godot --headless --path . --script res://tests/test_game_smoke.gd
```

Expected:

```text
PASS: game smoke
```

Also run:

```bash
godot --headless --path . --quit-after 2
```

Expected: exit code 0 with no parser/runtime errors.

- [ ] **Step 5: Manual desktop acceptance test**

Run:

```bash
godot --path . --editor
```

Press F6/F5 as appropriate and verify:

1. S01 placeholder room appears.
2. WASD and arrow keys move.
3. Player cannot cross the outer walls.
4. Player cannot walk through the central desk.
5. Walk near the red placeholder NPC and face it.
6. Space/Enter opens dialogue.
7. Space/Enter advances the two lines.
8. Two choices appear.
9. Mouse can click either choice.
10. Choosing the first loops through the joke and returns.
11. Choosing the second displays “走！”.
12. One more confirm fades to the green test destination.
13. Player appears at `Vector2(320, 250)`.

- [ ] **Step 6: Commit**

```bash
git add scripts/game.gd scenes/core/game.tscn tests/test_game_smoke.gd
git commit -m "feat: add persistent game shell and map transitions"
```

---

### Task 6: Add mobile touch controls

**Files:**
- Create: `scripts/touch_controls.gd`
- Create: `scenes/ui/touch_controls.tscn`
- Modify: `scenes/core/game.tscn`

- [ ] **Step 1: Add a failing scene-contract assertion to the smoke test**

Modify `tests/test_game_smoke.gd` so the three node assertions become:

```gdscript
	assert(game.get_node_or_null("World/S01Classroom") != null)
	assert(game.get_node_or_null("Player") != null)
	assert(game.get_node_or_null("UI/DialogueUI") != null)
	assert(game.get_node_or_null("UI/TouchControls") != null)
```

Run:

```bash
godot --headless --path . --script res://tests/test_game_smoke.gd
```

Expected: FAIL because `UI/TouchControls` is absent.

- [ ] **Step 2: Implement touch buttons using the same InputMap actions**

Create `scripts/touch_controls.gd`:

```gdscript
extends Control

var _buttons: Dictionary = {}

func _ready() -> void:
	visible = GameState.is_mobile_web()
	_create_buttons()
	_layout_buttons()
	resized.connect(_layout_buttons)

func _create_buttons() -> void:
	_buttons["up"] = _make_button("↑", &"move_up")
	_buttons["down"] = _make_button("↓", &"move_down")
	_buttons["left"] = _make_button("←", &"move_left")
	_buttons["right"] = _make_button("→", &"move_right")
	_buttons["interact"] = _make_button("对话", &"interact")

func _make_button(label_text: String, action: StringName) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(58, 58)
	button.focus_mode = Control.FOCUS_NONE
	button.modulate = Color(1, 1, 1, 0.72)
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	add_child(button)
	return button

func _layout_buttons() -> void:
	if _buttons.is_empty():
		return

	var bottom := size.y - 72.0
	var left := 70.0

	_buttons["up"].position = Vector2(left, bottom - 64.0)
	_buttons["down"].position = Vector2(left, bottom)
	_buttons["left"].position = Vector2(left - 64.0, bottom)
	_buttons["right"].position = Vector2(left + 64.0, bottom)
	_buttons["interact"].position = Vector2(size.x - 96.0, bottom - 8.0)

func _exit_tree() -> void:
	for action in [&"move_up", &"move_down", &"move_left", &"move_right", &"interact"]:
		Input.action_release(action)
```

Create `scenes/ui/touch_controls.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/touch_controls.gd" id="1_touch"]

[node name="TouchControls" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_touch")
```

Modify `scenes/core/game.tscn`:

1. Increase `load_steps` from `4` to `5`.
2. Add this resource:

```ini
[ext_resource type="PackedScene" path="res://scenes/ui/touch_controls.tscn" id="4_touch"]
```

3. Add this node after `DialogueUI`:

```ini
[node name="TouchControls" parent="UI" instance=ExtResource("4_touch")]
```

- [ ] **Step 3: Run smoke and parser tests**

```bash
godot --headless --path . --script res://tests/test_game_smoke.gd
godot --headless --path . --editor --quit
```

Expected:
- `PASS: game smoke`
- exit code 0
- no parser errors

- [ ] **Step 4: Commit**

```bash
git add scripts/touch_controls.gd scenes/ui/touch_controls.tscn scenes/core/game.tscn tests/test_game_smoke.gd
git commit -m "feat: add mobile touch controls"
```

---

### Task 7: Add landscape-only mobile orientation handling

**Files:**
- Create: `scripts/orientation_overlay.gd`
- Create: `scenes/ui/orientation_overlay.tscn`
- Modify: `scenes/core/game.tscn`
- Modify: `tests/test_game_smoke.gd`

- [ ] **Step 1: Add the failing overlay contract**

Add this assertion to `tests/test_game_smoke.gd`:

```gdscript
	assert(game.get_node_or_null("UI/OrientationOverlay") != null)
```

Run:

```bash
godot --headless --path . --script res://tests/test_game_smoke.gd
```

Expected: FAIL because the overlay is absent.

- [ ] **Step 2: Implement the overlay**

Create `scripts/orientation_overlay.gd`:

```gdscript
extends ColorRect

func _ready() -> void:
	get_viewport().size_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var viewport_size := get_viewport_rect().size
	var portrait := viewport_size.y > viewport_size.x
	var should_show := GameState.is_mobile_web() and portrait

	visible = should_show
	GameState.set_lock(&"orientation", should_show)
```

Create `scenes/ui/orientation_overlay.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/orientation_overlay.gd" id="1_orientation"]

[node name="OrientationOverlay" type="ColorRect"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
color = Color(0.08, 0.10, 0.14, 0.97)
script = ExtResource("1_orientation")

[node name="Message" type="Label" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -30.0
offset_right = 150.0
offset_bottom = 30.0
grow_horizontal = 2
grow_vertical = 2
text = "↻ 请旋转手机
使用横屏游玩"
horizontal_alignment = 1
vertical_alignment = 1
```

Modify `scenes/core/game.tscn`:

1. Increase `load_steps` from `5` to `6`.
2. Add:

```ini
[ext_resource type="PackedScene" path="res://scenes/ui/orientation_overlay.tscn" id="5_orientation"]
```

3. Add this node last inside `UI`, after `TransitionOverlay`:

```ini
[node name="OrientationOverlay" parent="UI" instance=ExtResource("5_orientation")]
```

- [ ] **Step 3: Run headless tests**

```bash
godot --headless --path . --script res://tests/test_game_smoke.gd
godot --headless --path . --editor --quit
```

Expected:
- `PASS: game smoke`
- no parser errors

- [ ] **Step 4: Commit**

```bash
git add scripts/orientation_overlay.gd scenes/ui/orientation_overlay.tscn scenes/core/game.tscn tests/test_game_smoke.gd
git commit -m "feat: add mobile landscape orientation guard"
```

---

### Task 8: Configure Web export and run the first complete acceptance pass

**Files:**
- Create: `export_presets.cfg`
- Modify: `README.md`

- [ ] **Step 1: Create the Web export preset**

Create `export_presets.cfg`:

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/web/index.html"
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=false
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
```

- [ ] **Step 2: Update local run/export instructions**

Append to `README.md`:

```markdown

## Run

```bash
godot --path . --editor
```

## Headless checks

```bash
godot --headless --path . --script res://tests/test_bootstrap.gd
godot --headless --path . --script res://tests/test_player.gd
godot --headless --path . --script res://tests/test_map_contract.gd
godot --headless --path . --script res://tests/test_dialogue.gd
godot --headless --path . --script res://tests/test_game_smoke.gd
godot --headless --path . --editor --quit
```

## Web export

Godot Web export templates must be installed in the local Godot editor.

```bash
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
```

Serve `build/web` through a local HTTP server for browser testing; do not open `index.html` directly from the filesystem.
```

- [ ] **Step 3: Run the full automated check set**

Run:

```bash
godot --headless --path . --script res://tests/test_bootstrap.gd
godot --headless --path . --script res://tests/test_player.gd
godot --headless --path . --script res://tests/test_map_contract.gd
godot --headless --path . --script res://tests/test_dialogue.gd
godot --headless --path . --script res://tests/test_game_smoke.gd
godot --headless --path . --editor --quit
```

Expected:
- All five scripts print `PASS`.
- Editor import/parser command exits 0.
- No GDScript parser errors.

- [ ] **Step 4: Export the Web build**

Run:

```bash
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
```

Expected: export succeeds and `build/web/index.html` exists.

If Godot reports that Web export templates are missing, install the matching export templates from the Godot editor and rerun the exact same command. Do not change the project architecture to work around missing local templates.

- [ ] **Step 5: Browser acceptance test**

Serve the build locally:

```bash
python -m http.server 8000 --directory build/web
```

Open `http://localhost:8000` and verify on desktop:

1. The game starts.
2. No touch buttons are visible.
3. WASD and arrows move.
4. Space / Enter interacts and advances dialogue.
5. Mouse selects choices.
6. Collision works.
7. Choosing the intended cafeteria answer fades to the test destination.
8. Refreshing the page starts cleanly again.

Then test on one real phone over the same local network or after temporary hosting:

1. Portrait shows only the rotate message.
2. Rotating to landscape removes the message.
3. Direction buttons appear.
4. Touch movement works.
5. Touch interact works.
6. Dialogue choices can be tapped.
7. Rotating portrait during dialogue pauses input.
8. Rotating back does not lose the current dialogue state.

- [ ] **Step 6: Commit**

```bash
git add export_presets.cfg README.md
git commit -m "chore: configure web export and acceptance checks"
```

---

## Final milestone checklist

Claude Code must report the result of every item, not just say “done”.

- [ ] Godot project opens without parser errors.
- [ ] Main scene launches.
- [ ] Placeholder S01 loads.
- [ ] WASD works.
- [ ] Arrow keys work.
- [ ] Collision works.
- [ ] Interaction ray detects the placeholder NPC.
- [ ] Space / Enter opens and advances dialogue.
- [ ] Two dialogue choices render.
- [ ] Mouse can choose.
- [ ] Keyboard focus/accept can choose.
- [ ] Wrong memory choice loops back.
- [ ] Intended choice reaches the map-change action.
- [ ] Fade transition works.
- [ ] Test destination loads.
- [ ] Mobile controls use the same input actions.
- [ ] Mobile portrait lock works.
- [ ] Mobile landscape resumes correctly.
- [ ] Web export completes.
- [ ] Desktop browser smoke test passes.
- [ ] Real mobile browser smoke test passes.

## Stop condition

Once this checklist passes, stop engineering the framework.

The next plan should be **content integration**, not framework expansion:
1. Replace S01 placeholders with the real classroom background and character sprites.
2. Draw real collision shapes over the final art.
3. Add the real S01 NPC placement and dialogue.
4. Duplicate the proven map pattern for cafeteria, corridor, gate, internet cafe, return-to-school, exam, after-school, and 2026 ending.
5. Add music/SFX only after the full story can be played start-to-finish.

Do not add infrastructure unless a real scene proves it is necessary.
