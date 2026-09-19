extends Node2D

## S01 "ClassroomMorning": Biu's intro dialogue, the fake choice, then walking
## out of the door to the canteen.
##
## Scene-local only - this state belongs to this scene and is deliberately not
## in GlobalState.

enum FlowState {
	INTRO,
	WRONG_REPLY,
	COMPLETED,
}

const BIU_NAME := "biu"

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

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	_choice_box.choice_selected.connect(_on_choice_selected)
	_exit_trigger.body_entered.connect(_on_exit_entered)
	_fade.fade_in()

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
