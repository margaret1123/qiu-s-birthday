extends Node2D

## S11 "Birthday2026": the end of the line. Twenty years on, the cake, the one
## line the whole story was for, and the photograph it stops on.
##
## Scene-local only, and it does not even read GlobalState - there is nothing
## after this scene, so there is nothing to carry out of it.
##
## The beat is played the way S01 plays its opening one, and deliberately not
## re-implemented: Biu is an npc.tscn, so the player walks over, the interact
## indicator comes up and the player presses to talk. The shared NPC and the
## shared DialogueBox do all of that; this scene only listens for the end of it,
## and the line itself lives on the NPC where S01 keeps hers.
##
## The ending is the photograph. Once the line has been read the picture goes up
## over the game and the scene stops there: no return to a title, no black, no
## THE END, and no second conversation.

var _ended := false

@onready var _dialogue_box = $DialogueBox
@onready var _fade = $FadeOverlay
@onready var _player: CharacterBody2D = $WorldSort/Player
@onready var _biu: Node = $WorldSort/BiuActor
@onready var _photo: CanvasLayer = $FinalPhoto

func _ready() -> void:
	_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	_photo.visible = false
	# Straight out of the black the gate ended on, so: fade up onto 2026.
	_fade.fade_in()

## The line has been read through. Nothing is said after it and nothing is played
## after it: the photograph goes straight up over the game and the scene is left
## standing on it.
##
## The NPC and the player are both switched off first. npc.gd is what would let
## the line be started again, and a second run would open a DialogueBox behind
## the photograph - where it can never be seen or closed. The ending has to be
## the last thing that can happen here.
func _on_dialogue_finished() -> void:
	if _ended:
		return
	_ended = true
	_biu.set_process(false)
	_player.set_physics_process(false)
	_photo.visible = true
