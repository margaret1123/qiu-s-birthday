extends Node2D

## S07 "ReturnToSchool": the road back, and the phone question on the way.
##
## Scene-local only - GlobalState still does nothing but carry the spawn position.
## There is no manager and no separate cutscene scene: the event is this scene with
## the player held still by the dialogue and choice boxes, which already stop
## movement while they are open.
##
## The event fires from a one-shot Area2D placed partway up the street, so the
## player gets a stretch of walking first and there is nothing to talk to again
## afterwards. That is also why a cancelled dialogue segment is put straight back
## up instead of being skipped - see _await_segment_closed.
##
## Once the joke has landed the school gate is armed. The player is not teleported
## to it: they walk the rest of the way themselves, which is what makes arriving
## at school their own move rather than a cutscene beat.

enum FlowState {
	WALKING,      ## Free walk; the trigger has not fired yet.
	INTRO,        ## Biu's three lines about phones at school.
	CHOOSING,     ## The prompt is up, or the fake branch is playing out.
	WRONG_REPLY,  ## Biu answers "凉拌" with "？？？", then the same prompt again.
	COMPLETED,    ## Joke over; the player walks on and the gate is armed.
}

## Biu is named lowercase everywhere else in the project.
const BIU_NAME := "biu"

## Where the player stands when S08 opens: just inside the classroom door, on open
## floor with no desk under them and clear of the seat trigger.
const S08_SPAWN := Vector2(1370, 620)
const S08_SCENE := "res://s08_classroom_exam.tscn"

## The setup for the prompt, and all of it. No phone item, no phone sprite and no
## animation - the question is the whole event.
const INTRO_LINES: Array[String] = [
	"学校不是不让带手机吗？",
	"看见就没收。",
	"那被没收了怎么办？",
]

## index 0 is the fake option and only ever leads back to this same prompt, so it
## can be picked any number of times. index 1 is what actually happened.
const CHOICE_OPTIONS: Array[String] = [
	"凉拌",
	"开什么玩笑！攒钱买！",
]

## The fake answer gets one word back. The joke is how short it is, so nothing is
## added after it.
const WRONG_REPLY_LINES: Array[String] = [
	"？？？",
]

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
@onready var _trigger: Area2D = $PhoneEventTrigger
@onready var _exit_marker: Sprite2D = $ExitMarker
@onready var _exit_trigger: Area2D = $ExitTrigger

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_segment_finished)
	_choice_box.choice_selected.connect(_on_choice_selected)
	_trigger.body_entered.connect(_on_trigger_entered)
	_exit_trigger.body_entered.connect(_on_exit_entered)
	# The gate is up the street and it does not exist until the joke has landed.
	_exit_marker.visible = false
	_exit_trigger.monitoring = false
	# Rode back out of the cybercafe into daylight, so: fade up.
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
	await _show_segment(BIU_NAME, INTRO_LINES)
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
		_finish_event()

## The fake branch. Biu refuses the 凉拌 answer and the same two options come
## straight back, so picking it never advances anything.
func _run_wrong_reply() -> void:
	state = FlowState.WRONG_REPLY
	await _show_segment(BIU_NAME, WRONG_REPLY_LINES)
	await _await_segment_closed()
	_open_choice()

## "开什么玩笑！攒钱买！" is the punchline on its own, so nothing is played after
## it: the player gets the screen back and the gate opens.
func _finish_event() -> void:
	state = FlowState.COMPLETED
	# The trigger stays disarmed, so the event cannot replay.
	_player.set_physics_process(true)
	# Armed only now that the joke is over and the player has the screen back.
	# Before this it is invisible and not monitoring, so the event cannot be
	# walked out of and the gate cannot be reached early.
	_open_exit()

func _open_exit() -> void:
	_exit_marker.visible = true
	_exit_trigger.monitoring = true

func _on_exit_entered(body: Node2D) -> void:
	if _transitioning or state != FlowState.COMPLETED or not body.is_in_group("player"):
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
	GlobalState.spawn_position = S08_SPAWN
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S08_SCENE)

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
## The phone event fires from a one-shot trigger and has no NPC behind it, so the
## only thing that matters is that it never loses a segment: DialogueBox hides
## itself on ui_cancel and emits nothing, and its cancel check reads
## is_action_just_pressed - which Input.action_release does not clear, so a cancel
## cannot be swallowed from up here. Instead a box that went away without
## dialogue_finished was cancelled and the same segment goes straight back up, so
## ESC can interrupt a line but cannot drop the event or strand the player. The
## shared DialogueBox is left alone.
func _await_segment_closed() -> void:
	while _dialogue_box.is_open():
		await get_tree().process_frame
	while not _segment_finished:
		_dialogue_box.call_deferred("show_dialogue", _segment_speaker, _segment_lines)
		await get_tree().process_frame
		while _dialogue_box.is_open():
			await get_tree().process_frame
