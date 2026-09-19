extends Node2D

## S09 "ClassroomAfterSchool": the same classroom, the exam behind them, school
## over.
##
## Scene-local only - GlobalState still does nothing but carry the spawn position.
## The two lines are the whole scene: no choice, no second beat, and nothing about
## the date, because none of that has happened yet.
##
## The event is not on a trigger. The exam is already over, so the lines open on
## their own the moment the room is up and the player is held for them. The exit
## is S01's classroom door and it is disarmed until the lines are read through, so
## it is opened by having listened rather than by having walked - and a cancelled
## segment goes straight back up instead of being skipped, see
## _await_segment_closed.

enum FlowState {
	AFTER_SCHOOL, ## Biu's "考完了。 / 走，回家。" - the only beat in the scene.
	COMPLETED,    ## Lines over; the door is armed and the player has the screen.
}

## Biu is named lowercase everywhere else in the project.
const BIU_NAME := "biu"

## Ordinary school's-out and nothing else. No nostalgia, no date, no "later".
const AFTER_SCHOOL_LINES: Array[String] = [
	"考完了。",
	"走，回家。",
]

## Where the player stands when S10 opens: inside the gate, on the same open
## ground S04 itself spawned them on.
const S10_SPAWN := Vector2(700, 888)
const S10_SCENE := "res://s10_school_gate_afterschool.tscn"

var state: FlowState = FlowState.AFTER_SCHOOL

var _transitioning := false

## The segment currently on screen, kept so a cancelled one can be put back.
var _segment_speaker := ""
var _segment_lines: Array[String] = []
## Set by the DialogueBox only when the player reads a segment through to the end.
## A cancel closes the box without it, which is how the two are told apart.
var _segment_finished := false

@onready var _dialogue_box = $DialogueBox
@onready var _fade = $FadeOverlay
@onready var _player: CharacterBody2D = $WorldSort/Player
@onready var _exit_marker: Sprite2D = $ExitMarker
@onready var _exit_trigger: Area2D = $ExitTrigger

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_segment_finished)
	_exit_trigger.body_entered.connect(_on_exit_entered)
	# The door is the same door as S01's and it does not exist until the two lines
	# are over, so the scene cannot be walked out of ahead of them.
	_exit_marker.visible = false
	_exit_trigger.monitoring = false
	# Held for the whole scene: the lines open on their own, so there is never a
	# moment where walking is what the scene wants. Released in _finish_event.
	_player.set_physics_process(false)
	_run_event()

func _on_segment_finished() -> void:
	_segment_finished = true

func _run_event() -> void:
	state = FlowState.AFTER_SCHOOL
	# Came up out of the black screen S08 ended on, so: fade up first and let the
	# room register, then speak.
	await _fade.fade_in()
	await _show_segment(BIU_NAME, AFTER_SCHOOL_LINES)
	await _await_segment_closed()
	_finish_event()

## The lines are the whole scene, so nothing is played after them: the player gets
## the screen back and the door opens. They walk out themselves.
func _finish_event() -> void:
	state = FlowState.COMPLETED
	_player.set_physics_process(true)
	_open_exit()

func _open_exit() -> void:
	_exit_marker.visible = true
	_exit_trigger.monitoring = true

func _on_exit_entered(body: Node2D) -> void:
	if _transitioning or state != FlowState.COMPLETED or not body.is_in_group("player"):
		return
	_transitioning = true
	# Disarm immediately so the body sitting inside the area for the whole fade
	# cannot start a second transition. Deferred because Area2D refuses this while
	# an in/out signal is being emitted.
	_exit_trigger.set_deferred("monitoring", false)
	# The player keeps their input until the fade is done, so freeze them rather
	# than letting them walk off during it.
	_player.set_physics_process(false)
	await _fade.fade_out()
	GlobalState.spawn_position = S10_SPAWN
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S10_SCENE)

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
## anyway: the only thing that matters is that it never loses a segment. A box
## that went away without dialogue_finished was cancelled, and the same segment
## goes straight back up. ESC can interrupt a line but cannot drop the scene or
## strand the player, and the shared DialogueBox is left alone.
func _await_segment_closed() -> void:
	while _dialogue_box.is_open():
		await get_tree().process_frame
	while not _segment_finished:
		_dialogue_box.call_deferred("show_dialogue", _segment_speaker, _segment_lines)
		await get_tree().process_frame
		while _dialogue_box.is_open():
			await get_tree().process_frame
