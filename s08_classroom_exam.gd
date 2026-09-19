extends Node2D

## S08 "ClassroomExam": back in the same classroom, the afternoon exam, and the
## joke about what the phone is actually for.
##
## The same room as S01 and the same event shape as S03: scene-local, no manager,
## no GlobalState beyond the spawn position, and the player held still by the
## boxes that already stop movement while they are open.
##
## It fires from a one-shot Area2D standing in for the player's seat rather than
## from an NPC, because this is a fixed event and there is nothing to talk to
## afterwards. That is also why a cancelled dialogue segment goes straight back up
## instead of being skipped - see _await_segment_closed.
##
## There is no exam system: no questions, no timer, no marking, no teacher. The
## exam is one line of dialogue, one punchline, and a short black screen.

enum FlowState {
	WALKING,       ## Free walk; the seat trigger has not fired yet.
	INTRO,         ## Biu's one line about the exam.
	CHOOSING,      ## The prompt is up, or the fake branch is playing out.
	WRONG_REPLY,   ## Biu answers "完了！没准备" with "？？？", then the prompt again.
	TRANSITIONING, ## Answer given; the screen is going black and the scene is done.
}

## Biu is named lowercase everywhere else in the project.
const BIU_NAME := "biu"

## Where the player stands when S09 opens: the aisle beside their own desk, on
## open floor.
const S09_SPAWN := Vector2(712, 878)
const S09_SCENE := "res://s09_classroom_afterschool.tscn"

## One line, and no more: no exam rules, no teacher, no pep talk.
const INTRO_LINES: Array[String] = [
	"下午有考试。",
]

## index 0 is the fake option and only ever leads back to this same prompt, so it
## can be picked any number of times. index 1 is what actually happened.
const CHOICE_OPTIONS: Array[String] = [
	"完了！没准备",
	"开什么玩笑，手机拿来干什么的！",
]

## The fake answer gets one word back. Nothing is added after it.
const WRONG_REPLY_LINES: Array[String] = [
	"？？？",
]

## How long the black holds between the punchline and the empty classroom. It
## stands in for the whole exam - no caption, no progress bar, no exam UI.
const EXAM_BLACK_HOLD := 0.8

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
@onready var _trigger: Area2D = $ExamSeatTrigger

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_segment_finished)
	_choice_box.choice_selected.connect(_on_choice_selected)
	_trigger.body_entered.connect(_on_seat_entered)
	# Walked back in off the street - a fresh map, so fade up from black.
	_fade.fade_in()

func _on_segment_finished() -> void:
	_segment_finished = true

func _on_seat_entered(body: Node2D) -> void:
	if state != FlowState.WALKING or not body.is_in_group("player"):
		return
	# One shot: the exam must never be able to fire again.
	_trigger.set_deferred("monitoring", false)
	# Locks the player for the whole event, so they cannot walk out of the
	# dialogue. Released only by the transition to S09.
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
		_run_exam_transition()

## The fake branch. Biu refuses the 完了！没准备 answer and the same two options
## come straight back, so picking it never advances anything.
func _run_wrong_reply() -> void:
	state = FlowState.WRONG_REPLY
	await _show_segment(BIU_NAME, WRONG_REPLY_LINES)
	await _await_segment_closed()
	_open_choice()

## "开什么玩笑，手机拿来干什么的！" is the punchline on its own, so nothing follows
## it but the time skip: the screen goes black, holds, and comes back up in S09.
func _run_exam_transition() -> void:
	state = FlowState.TRANSITIONING
	# The player keeps their input until the fade is done, so freeze them rather
	# than letting them walk off during it. They stay frozen: the next scene is
	# what puts them back.
	_player.set_physics_process(false)
	await _fade.fade_out(0.25)
	# The black is the exam. Nothing is drawn on it.
	await get_tree().create_timer(EXAM_BLACK_HOLD).timeout
	GlobalState.spawn_position = S09_SPAWN
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S09_SCENE)

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
## The exam event fires from a one-shot trigger and has no NPC behind it, so the
## only thing that matters is that it never loses a segment: DialogueBox hides
## itself on ui_cancel and emits nothing, and its cancel check reads
## is_action_just_pressed - which Input.action_release does not clear, so a cancel
## cannot be swallowed from up here. Instead a box that went away without
## dialogue_finished was cancelled and the same segment goes straight back up, so
## ESC can interrupt a line but cannot drop the event, skip to S09 or strand the
## player. The shared DialogueBox is left alone.
func _await_segment_closed() -> void:
	while _dialogue_box.is_open():
		await get_tree().process_frame
	while not _segment_finished:
		_dialogue_box.call_deferred("show_dialogue", _segment_speaker, _segment_lines)
		await get_tree().process_frame
		while _dialogue_box.is_open():
			await get_tree().process_frame
