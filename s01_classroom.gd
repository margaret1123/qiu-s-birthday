extends Node2D

## S01 "ClassroomMorning": Biu's intro dialogue, the fake choice, then walking
## out of the door to the canteen.
##
## Scene-local only - this state belongs to this scene and is deliberately not
## in GlobalState.
##
## This is also the scene the game starts on, so it owns the cold open: the black
## the FadeOverlay already starts on, "2006" held over it on its own, and only
## then the room. That is the same shape S10 uses for "2026" at the other end of
## the story - a Label on a CanvasLayer above FadeOverlay. The two years are the
## two ends of one gesture, but neither scene knows about the other and there is
## no timeline to keep.

enum FlowState {
	INTRO,
	WRONG_REPLY,
	COMPLETED,
}

const BIU_NAME := "biu"

## How long "2006" stays up before the room arrives. One beat, the same hold S10
## gives "2026", so the opening and the ending read as the same cut.
const YEAR_HOLD := 1.2

## The one-time nudge for a keyboard, shown once the room is up and then gone.
## It is a nudge and not a tutorial: nothing waits on it and nothing remembers it.
const HINT_TEXT := "WASD / 方向键：移动　E / 空格：互动"
const HINT_FADE := 0.5
## How long the hint sits fully up before it starts fading. Four seconds is one
## glance at the room, not a prompt to answer.
const HINT_HOLD := 4.0

## Where the player stands when S02 opens. The canteen entrance is the front of
## the dining floor, between the two left-hand tables.
const S02_SPAWN := Vector2(585, 862)
const S02_SCENE := "res://s02_canteen.tscn"

# index 0 is the wrong answer, index 1 the one that ends the scene.
const CHOICE_OPTIONS: Array[String] = [
	"一天之计在于晨，老实回去早读",
	"开什么玩笑，食堂甩卤面！",
]

const WRONG_REPLY_LINES: Array[String] = [
	"？？？",
	"你今天吃错药了？",
]

var state: FlowState = FlowState.INTRO

var _transitioning := false

@onready var _dialogue_box = $DialogueBox
@onready var _choice_box = $ChoiceBox
@onready var _exit_marker: Sprite2D = $ExitMarker
@onready var _exit_trigger: Area2D = $ExitTrigger
@onready var _fade = $FadeOverlay
@onready var _player: CharacterBody2D = $WorldSort/Player
@onready var _year_overlay: CanvasLayer = $YearOverlay
@onready var _hint: Control = $ControlHint/Hint

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	_choice_box.choice_selected.connect(_on_choice_selected)
	_exit_trigger.body_entered.connect(_on_exit_entered)
	_run_opening()

## Black out, the year on its own, then the room.
##
## FadeOverlay is already at full black when this runs, so "2006" goes straight
## over it and the wipe underneath is never seen until it is asked for. The player
## is held for the whole thing rather than only for the caption: the room is not
## up yet, so there is nothing to walk into and nothing to read.
func _run_opening() -> void:
	_player.set_physics_process(false)
	_year_overlay.visible = true
	await get_tree().create_timer(YEAR_HOLD).timeout
	_year_overlay.visible = false
	await _fade.fade_in()
	_player.set_physics_process(true)
	_show_control_hint()

## The desktop nudge, shown once, after the room is up.
##
## Gated on the device rather than on anything the game knows, and by the same
## test the touch HUD uses: a machine that reports a touchscreen has its controls
## drawn on screen already, and telling it about WASD would be wrong. On a
## touchscreen this returns before the hint is ever made visible.
##
## Nothing is written down and nothing is added up - it is shown once when the
## game opens and then it is over, which is why it needs no home in GlobalState.
func _show_control_hint() -> void:
	if DisplayServer.is_touchscreen_available():
		return
	_hint.visible = true
	_hint.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_hint, "modulate:a", 1.0, HINT_FADE)
	tween.tween_interval(HINT_HOLD)
	tween.tween_property(_hint, "modulate:a", 0.0, HINT_FADE)
	tween.tween_callback(_hint.hide)

func _on_dialogue_finished() -> void:
	# Both a finished intro and a finished scolding lead back to the choice.
	# Once the right option has been taken the scene is over: talking to Biu
	# again replays the intro, but must not reopen the choice.
	if state == FlowState.COMPLETED:
		return
	_open_choice()

func _on_choice_selected(index: int) -> void:
	# The choice box has already hidden itself by the time this runs.
	if index == 0:
		state = FlowState.WRONG_REPLY
		# Deferred for the same reason as the choice box: the key press that
		# picked this option must not also advance the reply it just opened.
		_dialogue_box.call_deferred("show_dialogue", BIU_NAME, WRONG_REPLY_LINES)
	else:
		state = FlowState.COMPLETED
		_open_exit()

func _open_choice() -> void:
	_dialogue_box.hide_dialogue()
	# Deferred so the press that closed the last dialogue line is not seen again
	# by the choice box on the same frame.
	_choice_box.call_deferred("show_choices", CHOICE_OPTIONS)

func _open_exit() -> void:
	# The player is not teleported: the door hint appears and they walk there.
	# Nothing is armed before this point, so the choice itself can never trigger
	# the transition.
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
	GlobalState.spawn_position = S02_SPAWN
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S02_SCENE)
