extends Node2D

## S11 "Birthday2026": the end of the line. Twenty years on, the cake, and the
## only two lines the whole story was for.
##
## Scene-local only, and it does not even read GlobalState - there is nothing
## after this scene, so there is nothing to carry out of it.
##
## No player, no camera to follow one, no trigger, no exit and no choice. The room
## fades up, says its two lines and then stays exactly as it is: the final frame
## is the ending, so there is deliberately nothing to press that leads anywhere
## else and no third line to play.
##
## A cancelled segment goes straight back up (see _await_segment_closed), so ESC
## can interrupt a line but cannot skip the ending.

## Biu is named lowercase everywhere else in the project.
const BIU_NAME := "biu"

## The two lines, and the whole ending. Nothing is allowed after them: no
## "还记得吗", no "一转眼", no "谢谢你", no "未来", no THE END. The restraint is
## the ending.
const FINAL_LINES: Array[String] = [
	"生日快乐。",
	"我们认识20年了。",
]

## The segment currently on screen, kept so a cancelled one can be put back.
var _segment_speaker := ""
var _segment_lines: Array[String] = []
## Set by the DialogueBox only when the player reads a segment through to the end.
## A cancel closes the box without it, which is how the two are told apart.
var _segment_finished := false

@onready var _dialogue_box = $DialogueBox
@onready var _fade = $FadeOverlay

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_segment_finished)
	_run_ending()

func _on_segment_finished() -> void:
	_segment_finished = true

## Fade up onto 2026, say the two lines, stop.
##
## The stop is the point: once _await_segment_closed returns there is nothing left
## to do, so the scene is simply left standing on its last frame. Nothing here
## returns to a title, blacks the screen again or writes anything else.
func _run_ending() -> void:
	await _fade.fade_in()
	await _show_segment(BIU_NAME, FINAL_LINES)
	await _await_segment_closed()

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
## goes straight back up. ESC can interrupt a line but cannot skip the ending, and
## the shared DialogueBox is left alone.
func _await_segment_closed() -> void:
	while _dialogue_box.is_open():
		await get_tree().process_frame
	while not _segment_finished:
		_dialogue_box.call_deferred("show_dialogue", _segment_speaker, _segment_lines)
		await get_tree().process_frame
		while _dialogue_box.is_open():
			await get_tree().process_frame
