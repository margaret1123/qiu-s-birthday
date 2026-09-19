extends Node2D

## S07 "ReturnToSchool": the road back, with the school gate up ahead.
##
## A map shell and deliberately nothing else. The two of them are walking back
## together and that is the whole of it - no DialogueBox, no ChoiceBox and no
## triggers, because the round that puts the phone question here adds all three.
## What this scene does have is its space already built, so that round does not
## have to come back and draw the street again.
##
## Scene-local and storyless - GlobalState still does nothing but carry the spawn
## position.

func _ready() -> void:
	# Rode back out of the cybercafe into daylight, so: fade up.
	$FadeOverlay.fade_in()
