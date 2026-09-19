extends Node2D

## S05 "CybercafeExterior": the two of them have arrived outside 今朝网吧.
##
## No story here yet, and deliberately none: this scene exists so the ride has
## somewhere to land. The player walks in freely and Biu is standing beside them,
## already arrived. There is no entrance trigger and no dialogue, because the
## round that goes inside adds both - an Area2D with no S06 behind it would only
## be a dead prompt.
##
## The pavement in front of the doorway is left clear and reachable, since that
## is where the way in will be.

func _ready() -> void:
	$FadeOverlay.fade_in()
