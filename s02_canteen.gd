extends Node2D

## S02 "CanteenMorning": the space and its runtime only.
##
## The canteen story is not written yet - this scene exists so the S01 -> S02
## template is proven end to end. Player spawning is handled by GlobalState and
## player.gd; nothing else belongs here.

@onready var _fade = $FadeOverlay

func _ready() -> void:
	_fade.fade_in()
