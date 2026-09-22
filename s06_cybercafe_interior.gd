extends Node2D

## S06 "CybercafeInterior": inside 今朝网吧, the order that was actually placed, and
## the walk back out.
##
## Scene-local only - GlobalState still does nothing but carry the spawn position.
## There is no manager and no separate cutscene scene: the event is this scene with
## the player held still by the dialogue and choice boxes, which already stop
## movement while they are open.
##
## Unlike S01-S05 this event hangs off an NPC rather than a one-shot trigger, and
## that changes one thing: a cancelled segment must not be put back up. ESC closes
## Biu's opening lines and emits nothing, which leaves the flow in INTRO with the
## prompt unopened - the player talks to her again and starts over from "老地方。".
## _on_dialogue_finished therefore only reacts to INTRO; every later segment is
## driven by the coroutines below, so it is not answered twice.
##
## Once the order is in, Biu is given her closing line for good and the exit is
## armed. The player is not teleported to it: they walk back to the door
## themselves, which is what makes leaving their own move.

enum FlowState {
	INTRO,        ## Biu's opening three lines are up, or waiting for them.
	CHOOSING,     ## The food prompt is up, or a branch off it is playing out.
	WRONG_REPLY,  ## Biu brushes the 汉堡 answer off, then the same prompt again.
	COMPLETED,    ## The order is in; the player is free and the exit is armed.
}

## Biu is named lowercase everywhere else in the project.
const BIU_NAME := "biu"

## Where the player stands when S07 opens: on the road back to school, with the
## gate still up the street.
const S07_SPAWN := Vector2(760, 880)
const S07_SCENE := "res://s07_return_to_school.tscn"

## The opening three lines lead to the prompt and nothing else. She only ever
## says them until the order is placed, so an interrupted run simply starts here
## again.
const INTRO_LINES: Array[String] = [
	"老地方。",
	"先开机。",
	"中午吃啥？",
]

## index 0 is the fake option and only ever leads back to this same prompt, so it
## can be picked any number of times. index 1 is what actually happened.
const CHOICE_OPTIONS: Array[String] = [
	"汉堡",
	"开什么玩笑，泡椒牛肉面！",
]

const WRONG_REPLY_LINES: Array[String] = [
	"来今朝吃汉堡？",
	"你今天怎么回事。",
]

## All three lines are the point; nothing is played after them. No cut to black,
## no sitting down, no keyboard. The order itself is the memory.
const ORDER_LINES: Array[String] = [
	"这还差不多。",
	"泡椒牛肉面。",
	"开机！",
]

## What Biu has left to say once the order is in. Handed to her for good in
## _finish_story, so talking to her again cannot reopen the prompt or replay the
## story.
const AFTER_LINES: Array[String] = [
	"差不多该回学校了。",
]

var state: FlowState = FlowState.INTRO

var _transitioning := false

## The segment currently on screen, kept so a cancelled one can be put back.
var _segment_speaker := ""
var _segment_lines: Array[String] = []
## Set by the DialogueBox only when the player reads a segment through to the end.
## A cancel closes the box without it, which is how the two are told apart.
var _segment_finished := false

## The two bodies are sized here rather than left to the scene.
##
## The scene used to override them directly, which is the ordinary way to do this
## and is what the editor shows. The exported build does not keep it: Godot 4.7
## drops `[node name="Body" parent="WorldSort/Player" index="0"]` when it converts
## a scene for export, so the build fell back to player.tscn's and npc.tscn's own
## scales and both characters came out about half again too large in the cafe.
## The override survives in the editor, which is why this only ever showed up in a
## shipped build.
##
## The values are the ones the scene carried.
const PLAYER_SCALE := Vector2(0.267477, 0.267477)
const BIU_SCALE := Vector2(0.131441, 0.131441)

@onready var _dialogue_box = $DialogueBox
@onready var _choice_box = $ChoiceBox
@onready var _fade = $FadeOverlay
@onready var _player: CharacterBody2D = $WorldSort/Player
@onready var _biu = $WorldSort/Biu
@onready var _exit_marker: Sprite2D = $ExitMarker
@onready var _exit_trigger: Area2D = $ExitTrigger

func _ready() -> void:
	_size_bodies()
	_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	_choice_box.choice_selected.connect(_on_choice_selected)
	_exit_trigger.body_entered.connect(_on_exit_entered)
	# The scene owns what Biu says, so her opening lines live here with the rest
	# of the flow rather than split across the scene file.
	_biu.dialogue_lines = INTRO_LINES
	# The way out is the way in, and it does not exist until the story is over.
	_exit_marker.visible = false
	_exit_trigger.monitoring = false
	# Walked in off the street - a fresh map, so fade up from black.
	_fade.fade_in()

func _size_bodies() -> void:
	var player_body := _player.get_node_or_null("Body") as AnimatedSprite2D
	if player_body != null:
		player_body.scale = PLAYER_SCALE
	var biu_body := _biu.get_node_or_null("Body") as AnimatedSprite2D
	if biu_body != null:
		biu_body.scale = BIU_SCALE

## Biu's own interaction opens her lines; this only decides what follows them.
##
## Only the opening segment leads into the prompt. A cancel never reaches here at
## all, so an interrupted opening leaves the prompt closed and the player free to
## try again. Everything after the opening is driven by the coroutines below, so
## a segment that ends while one of them is running is not answered here as well.
func _on_dialogue_finished() -> void:
	_segment_finished = true
	if state != FlowState.INTRO:
		return
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
		_run_order()

## The fake branch. Biu refuses the 汉堡 answer and the same two options come
## straight back, so picking it never advances anything.
func _run_wrong_reply() -> void:
	state = FlowState.WRONG_REPLY
	await _show_segment(BIU_NAME, WRONG_REPLY_LINES)
	await _await_segment_closed()
	_open_choice()

## The route that actually happened, and the whole of it: three lines, then the
## player has the screen back and the door opens.
func _run_order() -> void:
	await _show_segment(BIU_NAME, ORDER_LINES)
	await _await_segment_closed()
	_finish_story()

func _finish_story() -> void:
	state = FlowState.COMPLETED
	# Replaced outright, so the three opening lines are gone rather than merely
	# gated off, and she cannot be talked back into the prompt.
	_biu.dialogue_lines = AFTER_LINES
	_open_exit()

func _open_exit() -> void:
	_exit_marker.visible = true
	_exit_trigger.monitoring = true

func _on_exit_entered(body: Node2D) -> void:
	if _transitioning or state != FlowState.COMPLETED or not body.is_in_group("player"):
		return
	_transitioning = true
	# Disarm immediately so the body standing in the doorway for the whole fade
	# cannot start a second transition. Deferred because Area2D refuses this
	# while an in/out signal is being emitted.
	_exit_trigger.set_deferred("monitoring", false)
	# The player keeps their input until the fade is done, so freeze them rather
	# than letting them walk off during it.
	_player.set_physics_process(false)
	await _fade.fade_out()
	GlobalState.spawn_position = S07_SPAWN
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S07_SCENE)

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
## These two segments are spoken by this scene rather than by the NPC, so a cancel
## would leave the flow with nothing on screen and no way forward. DialogueBox
## hides itself on ui_cancel and emits nothing, and its cancel check reads
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
