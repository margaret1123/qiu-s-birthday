extends Node2D

## S04 "SchoolGateNoon": the two of them at the school gate at lunchtime, the two
## questions that decide where the afternoon goes, and the ride out.
##
## Scene-local only - this flow belongs to this scene and is deliberately not in
## GlobalState. GlobalState still does nothing but carry the spawn position.
## There is no manager, no separate cutscene scene and no ride scene: the ride is
## an overlay on this scene, driven from here.
##
## The gate event fires from a one-shot Area2D with nothing behind it to talk to
## again, so a cancelled dialogue segment is put straight back up instead of
## being skipped - see _await_segment_closed. ESC can interrupt a line but cannot
## get out of the event: both choices are answered, the player stays locked until
## the ride is over, and the ride ends in S05 regardless of which branch ran.

enum FlowState {
	WALKING,             ## Free walk; the gate trigger has not fired yet.
	DESTINATION_INTRO,   ## Biu's "中午了。 / 现在干嘛？".
	DESTINATION_CHOICE,  ## The lunch / 今朝 prompt is up.
	WRONG_DESTINATION,   ## Biu brushes the lunch answer off, then the same prompt again.
	PAYMENT_INTRO,       ## Biu's "这还差不多。 / 还有一个问题。 / 今天谁请？".
	PAYMENT_CHOICE,      ## The who-pays prompt is up.
	RIDE,                ## The ride overlay is playing.
	TRANSITIONING,       ## Fading into S05.
}

## Biu is named lowercase everywhere else in the project.
const BIU_NAME := "biu"

## Where the player stands when S05 opens: on the pavement outside the cybercafe,
## in front of the entrance and clear of the parked scooters.
const S05_SPAWN := Vector2(500, 726)
const S05_SCENE := "res://s05_cybercafe_exterior.tscn"

const DESTINATION_INTRO_LINES: Array[String] = [
	"中午了。",
	"现在干嘛？",
]

## index 0 is the fake option and only ever leads back to this same prompt, so it
## can be picked any number of times. index 1 is what actually happened.
const DESTINATION_OPTIONS: Array[String] = [
	"好好吃午饭，午休",
	"开什么玩笑，今朝！",
]

const WRONG_DESTINATION_LINES: Array[String] = [
	"你认真的？",
	"都走到校门口了。",
]

const PAYMENT_INTRO_LINES: Array[String] = [
	"这还差不多。",
	"还有一个问题。",
	"今天谁请？",
]

## Both of these are right, and both bottom out in the same ride: they differ in
## who pays and in nothing else. There is no wrong answer here to bounce back.
const PAYMENT_OPTIONS: Array[String] = [
	"月初：没钱了，biu请",
	"月末：biu没钱了，我请！",
]

const BIU_PAYS_LINES: Array[String] = [
	"行，我请。",
	"走。",
]

const PLAYER_PAYS_LINES: Array[String] = [
	"行，你请。",
	"走。",
]

## The ride is one pass across the screen, from just off the left edge to just
## off the right edge. At 0.34 the scooter is about a third of the screen tall -
## big enough to read, not big enough to fill the frame.
const RIDE_START := Vector2(-200, 480)
const RIDE_END := Vector2(1480, 480)
const RIDE_SECONDS := 2.8
## "2分钟后" comes up this long before the scooter leaves the screen, and stays
## up for a beat after it has.
const TIME_LABEL_LEAD := 1.0
const RIDE_HOLD := 0.6

var state: FlowState = FlowState.WALKING

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
@onready var _player_body: ColorRect = $WorldSort/Player/Body
@onready var _biu_body: ColorRect = $WorldSort/BiuActor/Visual/Body
@onready var _trigger: Area2D = $GateDecisionTrigger
@onready var _ride_overlay: CanvasLayer = $RideOverlay
@onready var _ride_sprite: Sprite2D = $RideOverlay/RideSprite
@onready var _time_label: Label = $RideOverlay/TimeLabel

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_segment_finished)
	_choice_box.choice_selected.connect(_on_choice_selected)
	_trigger.body_entered.connect(_on_trigger_entered)
	# Straight out of the teaching building - continuous with S03, so no caption.
	_fade.fade_in()

func _on_segment_finished() -> void:
	_segment_finished = true

func _on_trigger_entered(body: Node2D) -> void:
	if state != FlowState.WALKING or not body.is_in_group("player"):
		return
	# One shot: the gate decision must never be able to fire again.
	_trigger.set_deferred("monitoring", false)
	# Locks the player from here until the ride delivers them to S05, so they
	# cannot walk around behind the dialogue or off the gate during it.
	_player.set_physics_process(false)
	_run_event()

func _run_event() -> void:
	state = FlowState.DESTINATION_INTRO
	await _show_segment(BIU_NAME, DESTINATION_INTRO_LINES)
	await _await_segment_closed()
	_open_destination_choice()

## The fake branch. Biu refuses the lunch answer and the same two options come
## straight back, so picking it never advances anything.
func _run_wrong_destination() -> void:
	state = FlowState.WRONG_DESTINATION
	await _show_segment(BIU_NAME, WRONG_DESTINATION_LINES)
	await _await_segment_closed()
	_open_destination_choice()

func _run_to_cybercafe() -> void:
	state = FlowState.PAYMENT_INTRO
	await _show_segment(BIU_NAME, PAYMENT_INTRO_LINES)
	await _await_segment_closed()
	_open_payment_choice()

## Both payment answers land here. The only difference is who says they are
## paying; the ride afterwards is the same one either way.
func _run_payment(index: int) -> void:
	state = FlowState.RIDE
	await _show_segment(BIU_NAME, BIU_PAYS_LINES if index == 0 else PLAYER_PAYS_LINES)
	await _await_segment_closed()
	await _run_ride()

func _open_destination_choice() -> void:
	state = FlowState.DESTINATION_CHOICE
	_dialogue_box.hide_dialogue()
	# Deferred so the press that closed the last line is not seen again by the
	# choice box on the same frame.
	_choice_box.call_deferred("show_choices", DESTINATION_OPTIONS)

func _open_payment_choice() -> void:
	state = FlowState.PAYMENT_CHOICE
	_dialogue_box.hide_dialogue()
	_choice_box.call_deferred("show_choices", PAYMENT_OPTIONS)

## One ChoiceBox, two prompts: which one is on screen is told apart by the flow
## state, so the shared ChoiceBox keeps its single-index API and this scene does
## not need a second one.
func _on_choice_selected(index: int) -> void:
	match state:
		FlowState.DESTINATION_CHOICE:
			if index == 0:
				_run_wrong_destination()
			else:
				_run_to_cybercafe()
		FlowState.PAYMENT_CHOICE:
			_run_payment(index)
		_:
			pass

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
## anyway: the gate event fires from a one-shot trigger, so the only thing that
## matters is that it never loses a segment. A box that went away without
## dialogue_finished was cancelled, and the same segment goes straight back up.
## ESC can interrupt a line but cannot drop the event or strand the player, and
## the shared DialogueBox is left alone.
func _await_segment_closed() -> void:
	while _dialogue_box.is_open():
		await get_tree().process_frame
	while not _segment_finished:
		_dialogue_box.call_deferred("show_dialogue", _segment_speaker, _segment_lines)
		await get_tree().process_frame
		while _dialogue_box.is_open():
			await get_tree().process_frame

## The whole ride is a local overlay, not a scene. Black the screen with the
## shared wipe, swap the two walking actors out for the scooter, then run it.
func _run_ride() -> void:
	state = FlowState.RIDE
	await _fade.fade_out()
	# The overlay's own black covers the map anyway, but the two walking actors
	# are hidden outright too so the swap is real rather than merely covered.
	_player_body.visible = false
	_biu_body.visible = false
	_ride_sprite.position = RIDE_START
	_time_label.visible = false
	_ride_overlay.visible = true
	await _fade.fade_in()
	await _play_ride()
	await _fade.fade_out()
	_enter_s05()

func _play_ride() -> void:
	var tween := create_tween()
	tween.tween_property(_ride_sprite, "position", RIDE_END, RIDE_SECONDS)
	# Runs alongside the move, not after it: the caption lands on the last
	# stretch of the ride rather than on a second, static screen.
	await get_tree().create_timer(RIDE_SECONDS - TIME_LABEL_LEAD).timeout
	_time_label.visible = true
	await tween.finished
	await get_tree().create_timer(RIDE_HOLD).timeout

func _enter_s05() -> void:
	state = FlowState.TRANSITIONING
	GlobalState.spawn_position = S05_SPAWN
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S05_SCENE)
