extends Node2D

## S03 "CorridorMorning": the two of them walking back through the teaching
## building, and the boy's slip of the tongue.
##
## Scene-local only - this flow belongs to this scene and is deliberately not in
## GlobalState. There is no manager, no separate cutscene scene and no animation
## system: the event is the same scene with the player's physics switched off
## for the length of it.
##
## The event cannot be replayed: it fires from a one-shot Area2D rather than from
## an NPC, so there is nothing to talk to again afterwards. That is also why a
## cancelled dialogue segment is put straight back up instead of being skipped -
## see _await_segment_closed.
##
## Once the event is over the corridor's right-hand exit is armed. The player is
## not teleported to it: they walk there themselves, which is what makes leaving
## the teaching building their own move rather than a cutscene beat.

enum FlowState {
	WALKING,      ## Free walk; the trigger has not fired yet.
	INTRO,        ## The boy's "biu—— / ……Tank～！", then Biu's reaction.
	CHOOSING,     ## The prompt is up, or the picked branch is playing out.
	WRONG_REPLY,  ## Biu brushes the correction off, then the same prompt again.
	COMPLETED,    ## Event over; the player walks on.
}

## Biu is named lowercase everywhere else in the project.
const BIU_NAME := "biu"
const BOY_NAME := "男生"
## Speaker for the lines the player themselves says.
const PLAYER_NAME := "你"

## The slip itself: he means to shout Biu's name and lands on the player's old
## nickname instead. Two lines of one segment, so the pause lands before "Tank".
const BOY_INTRO_LINES: Array[String] = [
	"biu——",
	"……Tank～！",
]

const BIU_REACTION_LINES: Array[String] = [
	"？",
	"他刚刚是不是把你的外号喊出来了？",
]

## index 0 is the fake option, index 1 is what actually happened. The fake one
## only ever leads back to this same prompt, so it can be picked any number of
## times - same shape as the S01 fake choice.
const CHOICE_OPTIONS: Array[String] = [
	"澄清：你叫错了",
	"笑他！笑几十年！",
]

const WRONG_REPLY_LINES: Array[String] = [
	"澄清什么。",
	"这也太好笑了吧。",
]

const PLAYER_LAUGH_LINES: Array[String] = [
	"哈哈哈哈哈哈哈哈哈！",
]

const BIU_RIGHT_REPLY_LINES: Array[String] = [
	"你完了。",
	"这个我要笑你几十年。",
]

const BOY_REPLY_LINES: Array[String] = [
	"……",
	"我就是嘴瓢了！",
]

const BIU_FINAL_LINES: Array[String] = [
	"Tank～！",
	"哈哈哈哈哈哈。",
]

## Two very light hops on Biu's visual node: four steps of 0.09s, so the whole
## thing is over in 0.36s. Only the visual moves - her body and her sort position
## over the floor never change, so the draw order never flickers.
const LAUGH_BOUNCE_HEIGHT := -3.0
const LAUGH_BEAT := 0.09
const LAUGH_BOUNCES := 2

## Where the player stands when S04 opens: on the schoolyard pavement below the
## gate, well outside the gate trigger's reach, so they walk to the gate
## themselves. Biu is not standing on it either.
const S04_SPAWN := Vector2(700, 888)
const S04_SCENE := "res://s04_school_gate_noon.tscn"

var state: FlowState = FlowState.WALKING

var _transitioning := false

## The segment currently on screen, kept so a cancelled one can be put back.
var _segment_speaker := ""
var _segment_lines: Array[String] = []
## Set by the DialogueBox only when the player reads a segment through to the end.
## A cancel closes the box without it, which is how the two are told apart.
var _segment_finished := false

@onready var _dialogue_box = $DialogueBox
@onready var _choice_box = $ChoiceBox
@onready var _fade = $FadeOverlay
@onready var _player: CharacterBody2D = $WorldSort/Player
@onready var _biu_visual: Node2D = $WorldSort/BiuActor/Visual
@onready var _trigger: Area2D = $TankEventTrigger
@onready var _exit_marker: Sprite2D = $ExitMarker
@onready var _exit_trigger: Area2D = $ExitTrigger

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_segment_finished)
	_choice_box.choice_selected.connect(_on_choice_selected)
	_trigger.body_entered.connect(_on_trigger_entered)
	_exit_trigger.body_entered.connect(_on_exit_entered)
	# Straight back into the walk from the canteen - no time-skip caption here,
	# this one is continuous with S02.
	_fade.fade_in()

func _on_segment_finished() -> void:
	_segment_finished = true

func _on_trigger_entered(body: Node2D) -> void:
	if state != FlowState.WALKING or not body.is_in_group("player"):
		return
	# One shot: the event must never be able to fire again.
	_trigger.set_deferred("monitoring", false)
	# Locks the player for the whole event, so they cannot walk out of the
	# dialogue. Released again in _finish_event.
	_player.set_physics_process(false)
	_run_event()

func _run_event() -> void:
	state = FlowState.INTRO
	await _show_segment(BOY_NAME, BOY_INTRO_LINES)
	await _await_segment_closed()

	await _show_segment(BIU_NAME, BIU_REACTION_LINES)
	await _await_segment_closed()

	_open_choice()

func _open_choice() -> void:
	state = FlowState.CHOOSING
	_dialogue_box.hide_dialogue()
	# Deferred so the press that closed the last line is not seen again by the
	# choice box on the same frame.
	_choice_box.call_deferred("show_choices", CHOICE_OPTIONS)

func _on_choice_selected(index: int) -> void:
	# The choice box has already hidden itself by the time this runs.
	if index == 0:
		_run_wrong_reply()
	else:
		_run_right_reply()

## The fake option. Biu refuses to clarify and the two options come straight
## back, so picking it never advances anything.
func _run_wrong_reply() -> void:
	state = FlowState.WRONG_REPLY
	await _show_segment(BIU_NAME, WRONG_REPLY_LINES)
	await _await_segment_closed()
	_open_choice()

func _run_right_reply() -> void:
	state = FlowState.CHOOSING
	await _show_segment(PLAYER_NAME, PLAYER_LAUGH_LINES)
	await _await_segment_closed()
	await _bounce_biu()

	await _show_segment(BIU_NAME, BIU_RIGHT_REPLY_LINES)
	await _await_segment_closed()

	await _show_segment(BOY_NAME, BOY_REPLY_LINES)
	await _await_segment_closed()

	await _show_segment(BIU_NAME, BIU_FINAL_LINES)
	await _await_segment_closed()

	_finish_event()

func _finish_event() -> void:
	state = FlowState.COMPLETED
	# The trigger stays disarmed, so the event cannot replay.
	_player.set_physics_process(true)
	# Armed only now that the event is over and the player has the screen back.
	# Before this it is invisible and not monitoring, so the event cannot be
	# walked out of and the exit cannot be reached early.
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
	GlobalState.spawn_position = S04_SPAWN
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S04_SCENE)

## Opens one DialogueBox segment and waits a frame so the box is really up before
## anything polls it. Deferred so the press that opened it is not read again by
## DialogueBox._process on that same frame.
func _show_segment(speaker: String, lines: Array[String]) -> void:
	_segment_speaker = speaker
	_segment_lines = lines
	_segment_finished = false
	_dialogue_box.call_deferred("show_dialogue", speaker, lines)
	await get_tree().process_frame

## Waits until the open segment has been read through to the end.
##
## DialogueBox hides itself on ui_cancel and emits nothing, and its cancel check
## reads is_action_just_pressed - which Input.action_release does not clear, so a
## cancel cannot be swallowed from up here. This scene does not need to swallow it
## anyway. The tank event fires from a one-shot trigger and has no NPC behind it,
## so the only thing that matters is that it never loses a segment: a box that
## went away without dialogue_finished was cancelled, and the same segment goes
## straight back up. The event can be neither broken out of nor dead-ended, and
## the shared DialogueBox is left alone.
func _await_segment_closed() -> void:
	while _dialogue_box.is_open():
		await get_tree().process_frame
	while not _segment_finished:
		_dialogue_box.call_deferred("show_dialogue", _segment_speaker, _segment_lines)
		await get_tree().process_frame
		while _dialogue_box.is_open():
			await get_tree().process_frame

func _bounce_biu() -> void:
	var base := _biu_visual.position
	var tween := create_tween()
	for _i in LAUGH_BOUNCES:
		tween.tween_property(_biu_visual, "position", base + Vector2(0, LAUGH_BOUNCE_HEIGHT), LAUGH_BEAT)
		tween.tween_property(_biu_visual, "position", base, LAUGH_BEAT)
	await tween.finished
