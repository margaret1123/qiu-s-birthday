extends Node2D

## S02 "CanteenMorning": Biu waiting at the noodle window, the noodle choice,
## then the two of them sitting down at Table5 to eat.
##
## Scene-local only - this flow belongs to this scene and is deliberately not in
## GlobalState. There is no manager, no separate cutscene scene and no animation
## system: the meal is the same scene with the walking actors swapped for two
## seated sprites.

enum FlowState {
	COUNTER,      ## Biu's four opening lines; the choice opens when they end.
	NOODLE_REPLY, ## Biu's reaction to the pick; the meal starts when it ends.
	MEAL_PART_1,  ## The player's lines while seated.
	MEAL_PART_2,  ## Biu's "把你当男娃娃……", then the ？？？？？ bubble.
	MEAL_PART_3,  ## Biu's "所以…… / 我们……", then the ！！！！ bubble.
	LAUGHING,     ## Both sprites bounce, "哈哈哈哈……" on screen.
	COMPLETED,    ## Meal over; Biu only has the one line left.
}

const BIU_NAME := "biu"
## Speaker for the lines the player themselves says at the table.
const PLAYER_NAME := "你"

## Biu waits in the aisle in front of the 米线/面 window, in the gap between
## Table1 and Table2. The player reaches them from the S02 spawn without
## crossing a table, and the interaction zone stays inside that gap so it can
## never be triggered through a table.
const BIU_COUNTER_POSITION := Vector2(630, 468)

## Table5 is the staging table. Its occluder sorts at y = 703: Biu sorts just
## above that so the table's front edge cuts her off at the waist, and the
## player sorts below it so they read as sitting on the near side.
##
## The player's sprite carries its own stool. Two things make it swallow the
## stool painted into the background instead of doubling it: x is that stool's
## centre (857.5, not the table's 865), and the figure is drawn at the scene's
## full 176px character height. The sprite's stool is shorter than the painted
## one, so at a smaller figure the painted seat stays visible as a second blue
## ring around it. The y stands the sprite's stool base on the floor.
const MEAL_BIU_POSITION := Vector2(865, 694)
const MEAL_PLAYER_POSITION := Vector2(857, 805)

## The hidden player body is parked here so the one Camera2D frames Table5.
const MEAL_CAMERA_ANCHOR := MEAL_PLAYER_POSITION
## Open floor below Table5, outside every table's collision box.
const AFTER_MEAL_SPAWN := Vector2(800, 852)
## Beside the player, in the same open floor and clear of the table.
const BIU_AFTER_MEAL_POSITION := Vector2(738, 848)

## Where the player stands when S03 opens: the left end of the corridor, on open
## floor and clear of the tank trigger.
const S03_SPAWN := Vector2(180, 872)
const S03_SCENE := "res://s03_corridor.tscn"

## Biu's opening lines. The choice only opens once all four have been read.
const COUNTER_LINES: Array[String] = [
	"走，吃面。",
	"我还是鸡肉的。",
	"一颗一颗的肉。",
	"你呢？",
]

## index 0 is the wrong pick, index 1 is what actually happened. This asks what
## the player wants, not what they end up with: both answers play out into the
## same meal and the same bowls, so there is no second forced re-pick.
const CHOICE_OPTIONS: Array[String] = [
	"鸡肉卤面",
	"杂酱卤面",
]

const WRONG_REPLY_LINES: Array[String] = [
	"？？？",
	"鸡肉不是我的吗？",
	"你不是杂酱的？",
	"口口有肉啊。",
]

const RIGHT_REPLY_LINES: Array[String] = [
	"对，杂酱的。",
	"口口有肉。",
	"那我还是鸡肉，一颗一颗的肉。",
]

const MEAL_PART_1_LINES: Array[String] = [
	"这几天老戴又找我妈谈话了。",
	"还不是说我跟男生玩得太近。",
	"我妈就说，没关系。",
	"我们家孩子就是男娃娃堆里长大的。",
	"就当男娃娃看待就行。",
]

const MEAL_BIU_LINES_1: Array[String] = [
	"哦……",
	"把你当男娃娃……",
	"我又跟你走那么近……",
]

## The trailing off is the joke - these two stay split, not explained.
const MEAL_BIU_LINES_2: Array[String] = [
	"所以……",
	"我们……",
]

const LAUGH_LINES: Array[String] = [
	"哈哈哈哈哈哈哈哈哈哈！",
]

const POST_MEAL_LINES: Array[String] = [
	"别笑了，快走。",
]

const QUESTION_EMOTE_SECONDS := 0.5
const EXCLAIM_EMOTE_SECONDS := 0.45

## Three small hops each. The two of them are staggered so it reads as two
## people laughing rather than one animation, and the whole thing stays inside
## about two thirds of a second.
const LAUGH_BEAT := 0.10
const LAUGH_BOUNCES: Array[float] = [-4.0, -3.0, -4.0]
const LAUGH_STAGGER := 0.04

var state: FlowState = FlowState.COUNTER

## True from the moment the meal takes the screen until it gives it back. Only
## used to swallow the cancel key - see _process.
var _meal_active := false

var _transitioning := false

@onready var _dialogue_box = $DialogueBox
@onready var _choice_box = $ChoiceBox
@onready var _exit_marker: Sprite2D = $ExitMarker
@onready var _exit_trigger: Area2D = $ExitTrigger
@onready var _fade = $FadeOverlay
@onready var _player: CharacterBody2D = $WorldSort/Player
@onready var _player_body: AnimatedSprite2D = $WorldSort/Player/Body
@onready var _interact_indicator: Node2D = $WorldSort/Biu/InteractIndicator
@onready var _biu: StaticBody2D = $WorldSort/Biu
@onready var _biu_body: AnimatedSprite2D = $WorldSort/Biu/Body
@onready var _meal_biu: Node2D = $WorldSort/MealBiu
@onready var _meal_biu_sprite: Sprite2D = $WorldSort/MealBiu/Sprite
@onready var _meal_player: Node2D = $WorldSort/MealPlayer
@onready var _meal_player_sprite: Sprite2D = $WorldSort/MealPlayer/Sprite
@onready var _meal_props: Node2D = $WorldSort/MealProps
@onready var _question_emote: Sprite2D = $WorldSort/MealEmotes/QuestionEmote
@onready var _exclaim_emote: Sprite2D = $WorldSort/MealEmotes/ExclaimEmote

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	_choice_box.choice_selected.connect(_on_choice_selected)
	_exit_trigger.body_entered.connect(_on_exit_entered)
	_biu.dialogue_lines = COUNTER_LINES
	_fade.fade_in()

func _process(_delta: float) -> void:
	# DialogueBox closes itself on ui_cancel and emits nothing, which mid-meal
	# would strand the player with a hidden body and no way to go on. Rather than
	# widen the shared DialogueBox API for one scene, the scene swallows the
	# cancel while the meal owns the screen. Parents process before children, so
	# the action state is already cleared by the time DialogueBox._process reads
	# it. The segment wait below does not depend on this working.
	if _meal_active and Input.is_action_pressed("ui_cancel"):
		Input.action_release("ui_cancel")

func _on_dialogue_finished() -> void:
	# Only the two window-side phases run off Biu's own dialogue_lines. From the
	# meal on, every segment is driven explicitly by _run_meal.
	match state:
		FlowState.COUNTER:
			_open_choice()
		FlowState.NOODLE_REPLY:
			_begin_meal()
		_:
			pass

func _open_choice() -> void:
	_dialogue_box.hide_dialogue()
	# Deferred so the press that closed the last line is not seen again by the
	# choice box on the same frame.
	_choice_box.call_deferred("show_choices", CHOICE_OPTIONS)

func _on_choice_selected(index: int) -> void:
	# The choice box has already hidden itself by the time this runs. Biu's reply
	# is parked on the NPC rather than played from here, so that cancelling it
	# and talking to Biu again simply replays it instead of dead-ending.
	_biu.dialogue_lines = WRONG_REPLY_LINES if index == 0 else RIGHT_REPLY_LINES
	state = FlowState.NOODLE_REPLY
	# Deferred for the same reason as the choice box: the press that picked this
	# option must not also advance the first reply line it just opened.
	_dialogue_box.call_deferred("show_dialogue", BIU_NAME, _biu.dialogue_lines)

## Opens one DialogueBox segment and waits a frame so the box is really up before
## anything polls it. Deferred so the key press that opened it is not read again
## by DialogueBox._process on that same frame.
func _show_segment(speaker: String, lines: Array[String]) -> void:
	_dialogue_box.call_deferred("show_dialogue", speaker, lines)
	await get_tree().process_frame

## Waits for the open segment to close. Polled rather than awaiting
## dialogue_finished on purpose: if a cancel ever did slip through, the box still
## closes and the cutscene carries on instead of hanging on a signal that will
## never arrive.
func _await_segment_closed() -> void:
	while _dialogue_box.is_open():
		await get_tree().process_frame

func _blink_emote(emote: Sprite2D, seconds: float) -> void:
	emote.visible = true
	await get_tree().create_timer(seconds).timeout
	emote.visible = false

func _begin_meal() -> void:
	_meal_active = true
	state = FlowState.MEAL_PART_1
	_player.set_physics_process(false)
	# Cutscene actor pause, not a modal: Biu must not be re-interactable while
	# sitting at the table.
	_biu.set_process(false)
	await _fade.fade_out()
	_player_body.visible = false
	_biu_body.visible = false
	# Park the hidden body so the one Camera2D settles on Table5. Done before the
	# prompt is re-hidden because the teleport can trip Biu's InteractionArea.
	_player.position = MEAL_CAMERA_ANCHOR
	_interact_indicator.visible = false
	_meal_biu.visible = true
	_meal_player.visible = true
	_meal_props.visible = true
	await _fade.fade_in()
	await _run_meal()

func _run_meal() -> void:
	# Each beat is its own DialogueBox segment. A finished segment is what
	# advances the flow, so nothing needs a per-line callback.
	state = FlowState.MEAL_PART_1
	await _show_segment(PLAYER_NAME, MEAL_PART_1_LINES)
	await _await_segment_closed()

	state = FlowState.MEAL_PART_2
	await _show_segment(BIU_NAME, MEAL_BIU_LINES_1)
	await _await_segment_closed()
	await _blink_emote(_question_emote, QUESTION_EMOTE_SECONDS)

	state = FlowState.MEAL_PART_3
	await _show_segment(BIU_NAME, MEAL_BIU_LINES_2)
	await _await_segment_closed()
	await _blink_emote(_exclaim_emote, EXCLAIM_EMOTE_SECONDS)

	state = FlowState.LAUGHING
	await _show_segment(BIU_NAME, LAUGH_LINES)
	await _bounce_laugh()
	# Waits for the player's own confirm if they are still reading.
	await _await_segment_closed()

	await _finish_meal()

## Only the Sprite2D children move. The MealBiu / MealPlayer anchors keep their
## y, so the draw order over Table5 never changes while they laugh.
func _bounce_laugh() -> void:
	_laugh_tween(_meal_biu_sprite, 0.0)
	# The staggered one finishes last, so it is the one worth waiting on.
	await _laugh_tween(_meal_player_sprite, LAUGH_STAGGER).finished

func _laugh_tween(sprite: Sprite2D, delay: float) -> Tween:
	var base := sprite.position
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	for height in LAUGH_BOUNCES:
		tween.tween_property(sprite, "position", base + Vector2(0, height), LAUGH_BEAT)
		tween.tween_property(sprite, "position", base, LAUGH_BEAT)
	return tween

func _finish_meal() -> void:
	state = FlowState.COMPLETED
	_meal_active = false
	await _fade.fade_out()
	_meal_biu.visible = false
	_meal_player.visible = false
	_meal_props.visible = false
	_question_emote.visible = false
	_exclaim_emote.visible = false
	_player.position = AFTER_MEAL_SPAWN
	_biu.position = BIU_AFTER_MEAL_POSITION
	_player_body.visible = true
	_biu_body.visible = true
	_player.set_physics_process(true)
	_biu.set_process(true)
	# From here on Biu only has the one line, and the meal cannot replay.
	_biu.dialogue_lines = POST_MEAL_LINES
	await _fade.fade_in()
	# Armed only now that the player has the screen and can see it. They are not
	# teleported out: the exit appears and they walk to it themselves.
	_open_exit()

func _open_exit() -> void:
	_exit_marker.visible = true
	_exit_trigger.monitoring = true

func _on_exit_entered(body: Node2D) -> void:
	if _transitioning or not body.is_in_group("player"):
		return
	_transitioning = true
	# Disarm immediately so the body sitting inside the area for the whole fade
	# cannot start a second transition. Deferred because Area2D refuses this
	# while an in/out signal is being emitted.
	_exit_trigger.set_deferred("monitoring", false)
	# The player keeps their input until the fade is done, so freeze them rather
	# than letting them walk off during it.
	_player.set_physics_process(false)
	await _fade.fade_out()
	GlobalState.spawn_position = S03_SPAWN
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S03_SCENE)
