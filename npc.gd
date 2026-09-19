extends StaticBody2D

@export var npc_name: String = "Villager"
@export var dialogue_lines: Array[String] = [
	"Hello there! Welcome to our town.",
	"It's a lovely day, isn't it?",
	"We've been having great weather lately.",
	"Come back and visit anytime!"
]
# Shift the interaction zone relative to the NPC (e.g. in front of a counter)
@export var interaction_offset: Vector2 = Vector2.ZERO
# Size of the interaction zone (defaults to npc.tscn's 80×80)
@export var interaction_size: Vector2 = Vector2(80, 80)

var player_nearby = false

## Frames the DialogueBox has read as closed. The prompt is only allowed back
## once this is past 1, so it never returns on the very frame the box closes.
## That one-frame gap is what keeps S11 honest: that scene ends by switching the
## NPC off from inside dialogue_finished, so the frame the last line closes is
## also the last frame this ever runs - and a prompt put up in it would be left
## over the photograph with nothing left to take it down.
var _frames_box_closed = 0

@onready var _prompt: Sprite2D = $InteractIndicator

func _ready():
	add_to_group("npcs")
	$InteractionArea.position = interaction_offset
	var col := $InteractionArea.get_child(0) as CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = interaction_size
	col.shape = shape
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)
	_prompt.visible = false

func _process(_delta):
	if _is_box_open():
		_frames_box_closed = 0
	else:
		_frames_box_closed += 1
	_prompt.visible = _wants_prompt()

	if not player_nearby or not Input.is_action_just_pressed("interact"):
		return
	# An open prompt owns the interact key - the same press that confirms a
	# choice or advances a line must not also start a conversation behind it.
	var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	var choice_box = get_tree().get_first_node_in_group("choice_box")
	if dialogue_box and dialogue_box.is_open():
		return
	if choice_box and choice_box.is_open():
		return
	interact()

## The prompt is the invitation to talk, so it is up exactly when talking is
## possible: the player is in range and no conversation already owns the screen.
## It is not "this NPC is the one being talked to" - a scene is free to open the
## box itself, and the prompt goes down for that too.
func _is_box_open() -> bool:
	var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	return dialogue_box != null and dialogue_box.is_open()

func _wants_prompt() -> bool:
	return player_nearby and not _is_box_open() and _frames_box_closed > 1

func _on_body_entered(body):
	if body.name == "Player":
		player_nearby = true
		_prompt.visible = _wants_prompt()

func _on_body_exited(body):
	if body.name == "Player":
		player_nearby = false
		_prompt.visible = false

func interact():
	var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	if dialogue_box:
		# Down before the box goes up: the press that starts a conversation must
		# not leave the invitation to start it on screen over the first line.
		_frames_box_closed = 0
		_prompt.visible = false
		# Deferred so the box does not become visible during the same frame as
		# this interact press. If it did, dialogue_box._process would still see
		# that press as "just pressed" and advance straight past the first line.
		dialogue_box.call_deferred("show_dialogue", npc_name, dialogue_lines)
