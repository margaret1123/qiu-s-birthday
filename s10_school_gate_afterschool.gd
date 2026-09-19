extends Node2D

## S10 "SchoolGateAfterSchool": the same gate as S04, at the end of the day, and
## the step out through it.
##
## Scene-local only - GlobalState still does nothing but carry the spawn position,
## and this scene does not even set it: S11 has no player to place.
##
## There is no DialogueBox, no ChoiceBox and no Biu here on purpose. The whole
## scene is a walk, and everything that is said about the twenty years is said
## after the black, not before it. The banner and the door marker point at the
## gate and nothing further: "there is a surprise outside" is as much as this
## side of the fade is allowed to say, and it names no date.
##
## S04's collision, camera and world size are reused exactly as they were. It is
## the same gate; only what is behind it has changed.
##
## The time of day is the one thing added on top, and it is a single scene-local
## CanvasModulate: the same gate at the end of the day rather than at noon. It is
## a colour multiply over this scene's own canvas and nothing else - it does not
## reach the FadeOverlay or the YearOverlay, which are their own layers, so the
## black and the year stay exactly as black and as white as S10 needs them to be.
## There is no day/night system and nothing outside this scene knows about it.

enum FlowState {
	WALKING,  ## Free walk; the gate has not been stepped through yet.
	CROSSING, ## Out through the gate: black out, hold, 2026, cut.
}

const S11_SCENE := "res://s11_2026_birthday.tscn"

## Pure black held after the wipe, before anything comes up. Long enough to read
## as a cut rather than as a slow fade on its way somewhere.
const BLACK_HOLD := 0.6
## How long "当当当~" is knocked on the black before the date answers it. The
## knock is the joke the whole twenty years lands on, so it gets its own beat.
const KNOCK_HOLD := 1.0
## How long the date stays up. One beat, then it is gone.
const YEAR_HOLD := 1.2

var state: FlowState = FlowState.WALKING

var _transitioning := false

@onready var _fade = $FadeOverlay
@onready var _player: CharacterBody2D = $WorldSort/Player
@onready var _gate_trigger: Area2D = $GateExitTrigger
@onready var _year_overlay: CanvasLayer = $YearOverlay
@onready var _knock: Label = $YearOverlay/KnockLabel
@onready var _date: Node2D = $YearOverlay/YearMatrix
@onready var _banner: CanvasLayer = $Banner

func _ready() -> void:
	_gate_trigger.body_entered.connect(_on_gate_entered)
	_year_overlay.visible = false
	_knock.visible = false
	_date.visible = false
	# Walked straight out of S09's classroom door into the same afternoon, so:
	# fade up.
	_fade.fade_in()

func _on_gate_entered(body: Node2D) -> void:
	if _transitioning or state != FlowState.WALKING or not body.is_in_group("player"):
		return
	_transitioning = true
	state = FlowState.CROSSING
	# The banner has done its job the moment the gate is reached, and the fade is
	# about to take the screen anyway, so it goes down with the gate rather than
	# riding into the black.
	_banner.visible = false
	# One shot: stepping out must never be able to fire twice. Deferred because
	# Area2D refuses this while an in/out signal is being emitted.
	_gate_trigger.set_deferred("monitoring", false)
	# The player keeps their input until the fade is done, so freeze them rather
	# than letting them walk further out during it.
	_player.set_physics_process(false)
	_run_crossing()

## Black out, hold, knock, answer with the date, cut.
##
## The wipe and the captions are two separate layers: FadeOverlay is the project's
## shared wipe at layer 100, and both captions sit on this scene's own layer above
## it - so they read over the black instead of under it. Neither is a new system
## and there is no timeline to keep.
##
## The date is not type - it is a dot matrix of Polygon2D quads, one per lit cell,
## laid out in the scene next to the layer that shows it. That is the whole of it:
## no font, no picture file, nothing to import.
func _run_crossing() -> void:
	await _fade.fade_out()
	await get_tree().create_timer(BLACK_HOLD).timeout
	_year_overlay.visible = true
	_knock.visible = true
	await get_tree().create_timer(KNOCK_HOLD).timeout
	_knock.visible = false
	_date.visible = true
	await get_tree().create_timer(YEAR_HOLD).timeout
	_year_overlay.visible = false
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S11_SCENE)
