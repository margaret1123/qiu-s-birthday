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
## The whole layer is switched off where no touchscreen is reported, so a desktop
## keyboard build never sees it. That also takes the buttons out of input
## entirely, because a TouchScreenButton only processes input while it is visible
## in the tree.

## Shows the controls where no touchscreen is reported. The runtime harness sets
## this, and it is there to be toggled from the editor; the game leaves it false.
@export var force_visible := false:
	set(value):
		force_visible = value
		_apply_visibility()

## Warm yellow, matching the highlight the choice plates use for the picked
## option, so a held button reads as "this one is live" in the game's own palette.
const PRESSED_TINT := Color(0.992157, 0.952941, 0.627451)

@onready var _buttons: Array[TouchScreenButton] = [
	$Controls/Up,
	$Controls/Down,
	$Controls/Left,
	$Controls/Right,
	$Controls/Action,
]

func _ready() -> void:
	_apply_visibility()
	for button in _buttons:
		button.pressed.connect(_set_tint.bind(button, PRESSED_TINT))
		button.released.connect(_set_tint.bind(button, Color.WHITE))

func _apply_visibility() -> void:
	visible = force_visible or DisplayServer.is_touchscreen_available()

func _set_tint(button: TouchScreenButton, color: Color) -> void:
	button.modulate = color
