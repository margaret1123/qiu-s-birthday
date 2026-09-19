extends Node2D

## S09 "ClassroomAfterSchool": the same classroom, the exam behind them, school
## over.
##
## A map shell and deliberately nothing else. The one line of story that belongs
## here is the next round's; this round only puts the room back up after the black
## screen, so the player comes out of the time skip somewhere they can walk.
## No DialogueBox, no ChoiceBox, no trigger and no exit.
##
## Scene-local and storyless - GlobalState still does nothing but carry the spawn
## position. Like S01 it has no Biu actor: the background already has students
## drawn into it.

func _ready() -> void:
	# Came up out of the black screen the exam skipped past, so: fade up.
	$FadeOverlay.fade_in()
