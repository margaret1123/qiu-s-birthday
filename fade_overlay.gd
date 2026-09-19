extends CanvasLayer

## A reusable full-screen black wipe.
##
## Visual component only: it knows nothing about scenes, routing or game state.
## Every map instantiates one and drives it itself.

const DEFAULT_DURATION := 0.25

@onready var _black: ColorRect = $Black

var _tween: Tween

func _ready() -> void:
	# Maps open on black and fade in. A scene that wants a hard cut can just
	# call fade_in(0.0).
	_black.modulate.a = 1.0

## Black out: alpha 0 -> 1. Awaitable.
func fade_out(duration := DEFAULT_DURATION) -> void:
	await _fade_to(1.0, duration)

## Clear the black: alpha 1 -> 0. Awaitable.
func fade_in(duration := DEFAULT_DURATION) -> void:
	await _fade_to(0.0, duration)

func _fade_to(target_alpha: float, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_black, "modulate:a", target_alpha, duration)
	await _tween.finished
