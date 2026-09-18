extends Node2D

## S01 "ClassroomMorning" scene flow: Biu's intro dialogue, then the fake choice.
##
## Scene-local only - this state belongs to this scene and is deliberately not
## in GlobalState.

enum FlowState {
	INTRO,
	WRONG_REPLY,
	COMPLETED,
}

const BIU_NAME := "biu"

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

@onready var _dialogue_box = $DialogueBox
@onready var _choice_box = $ChoiceBox
@onready var _biu = $WorldSort/Biu

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	_choice_box.choice_selected.connect(_on_choice_selected)

func _on_dialogue_finished() -> void:
	# Both a finished intro and a finished scolding lead back to the choice.
	# Once the right option has been taken the scene is over: talking to Biu
	# again replays the intro, but must not reopen the choice.
	if state == FlowState.COMPLETED:
		return
	_open_choice()

func _on_choice_selected(index: int) -> void:
	# The choice box has already hidden itself by the time this runs.
	_set_biu_interaction_enabled(true)
	if index == 0:
		state = FlowState.WRONG_REPLY
		# Deferred for the same reason as the choice box: the key press that
		# picked this option must not also advance the reply it just opened.
		_dialogue_box.call_deferred("show_dialogue", BIU_NAME, WRONG_REPLY_LINES)
	else:
		state = FlowState.COMPLETED

func _open_choice() -> void:
	_dialogue_box.hide_dialogue()
	_set_biu_interaction_enabled(false)
	# Deferred so the press that closed the last dialogue line is not seen again
	# by the choice box on the same frame.
	_choice_box.call_deferred("show_choices", CHOICE_OPTIONS)

func _set_biu_interaction_enabled(enabled: bool) -> void:
	# Biu polls "interact" and only checks the dialogue box, so while the choice
	# is up a press would otherwise open the intro dialogue on top of it.
	# Only Biu's per-frame poll is toggled - its area signals keep working.
	_biu.set_process(enabled)
