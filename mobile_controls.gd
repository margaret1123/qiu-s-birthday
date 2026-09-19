extends CanvasLayer

## Shared on-screen controls for touch devices.
##
## Every button drives an action that is already in the input map, so the player,
## the dialogue box and the choice box keep reading input exactly the way they do
## for the keyboard. Nothing here moves the player, opens a box or answers a
## prompt itself - these buttons only stand in for keys the game already listens
## to, which is what keeps one movement path and one interaction path in the game
## rather than two.
##
## Visibility answers two separate questions, and keeping them apart is the whole
## point of this file:
##
##   * may this machine show a touch HUD at all - the device gate, which is what
##     force_visible exists to override, and which never changes while playing;
##   * which controls the game's current state has any use for - the state gate,
##     which follows the dialogue and choice boxes.
##
## Collapsing them into one visible flag would mean hiding the HUD for a choice
## box also read as "this is a desktop build", and the controls would never come
## back. They are applied together in _apply_visibility but decided separately.

## Shows the controls where no touchscreen is reported. The runtime harness sets
## this, and it is there to be toggled from the editor; the game leaves it false.
@export var force_visible := false:
	set(value):
		force_visible = value
		_apply_visibility()

## Warm yellow, matching the highlight the choice plates use for the picked
## option, so a held button reads as "this one is live" in the game's own palette.
const PRESSED_TINT := Color(0.992157, 0.952941, 0.627451)

@onready var _controls: Node2D = $Controls

@onready var _directions: Array[TouchScreenButton] = [
	$Controls/Up,
	$Controls/Down,
	$Controls/Left,
	$Controls/Right,
]

@onready var _action: TouchScreenButton = $Controls/Action

## Last state the visibility was built for, so the per-frame check only does work
## when a box actually opens or closes.
var _dialogue_open := false
var _choice_open := false

func _ready() -> void:
	for button in _directions:
		_wire(button)
	_wire(_action)
	_dialogue_open = _is_open(&"dialogue_box")
	_choice_open = _is_open(&"choice_box")
	_apply_visibility()

## The boxes are separate layers with their own lifecycles, so the HUD watches
## their state rather than being told about it - which also keeps this file free
## of any coupling to the dialogue or choice code.
func _process(_delta: float) -> void:
	if not visible:
		return
	var dialogue_open := _is_open(&"dialogue_box")
	var choice_open := _is_open(&"choice_box")
	if dialogue_open == _dialogue_open and choice_open == _choice_open:
		return
	_dialogue_open = dialogue_open
	_choice_open = choice_open
	_apply_visibility()

func _wire(button: TouchScreenButton) -> void:
	button.pressed.connect(_set_tint.bind(button, PRESSED_TINT))
	button.released.connect(_set_tint.bind(button, Color.WHITE))

## True while the box in p_group is up. This is the same test the player and the
## NPCs already make, so "a conversation owns the screen" keeps one meaning
## across the game.
func _is_open(group: StringName) -> bool:
	var box = get_tree().get_first_node_in_group(group)
	return box != null and box.is_open()

func _apply_visibility() -> void:
	var allowed := force_visible or DisplayServer.is_touchscreen_available()
	visible = allowed
	if not allowed or not is_node_ready():
		return

	# A choice owns the bottom right of the screen. Its second plate sits exactly
	# under the action button, so a tap meant for that option would be eaten by
	# the HUD instead. The options are ordinary Buttons and answer touch on their
	# own, so the whole HUD stands down and the choice is tapped directly.
	_controls.visible = not _choice_open

	# Nothing on the d-pad can move the player while a conversation is up - the
	# player refuses to walk - so the arrows are four dead keys and go away.
	for button in _directions:
		button.visible = not _dialogue_open and not _choice_open

	# Talking is advanced with interact, which is exactly the action button, so it
	# stays while a line is on screen - it is the continue key.
	_action.visible = not _choice_open

func _set_tint(button: TouchScreenButton, color: Color) -> void:
	button.modulate = color
