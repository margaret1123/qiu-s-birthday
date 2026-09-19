extends Node2D

## S05 "CybercafeExterior": the two of them have arrived outside 今朝网吧, and the
## player walks in.
##
## Scene-local only - GlobalState still does nothing but carry the spawn position.
##
## The way in is the doorway itself rather than a prompt: one Area2D laid across
## the threshold, so walking up to the shop and stepping in is the whole
## interaction. Nothing is asked, nothing is confirmed with a key, and there is no
## DialogueBox or ChoiceBox in this scene to ask with.
##
## The spawn is well clear of the trigger, so the scene cannot open by dropping
## the player straight through it.

## Where the player stands when S06 opens: on the tiles just inside the door,
## between the pillar and the first desk row.
const S06_SPAWN := Vector2(500, 850)
const S06_SCENE := "res://s06_cybercafe_interior.tscn"

var _transitioning := false

@onready var _fade = $FadeOverlay
@onready var _player: CharacterBody2D = $WorldSort/Player
@onready var _entrance: Area2D = $EntranceTrigger

func _ready() -> void:
	_entrance.body_entered.connect(_on_entrance_entered)
	# Dropped off by the ride from S04 - no caption, that one was the time skip.
	_fade.fade_in()

func _on_entrance_entered(body: Node2D) -> void:
	if _transitioning or not body.is_in_group("player"):
		return
	_transitioning = true
	# Disarm immediately so the body standing on the threshold for the whole fade
	# cannot start a second transition. Deferred because Area2D refuses this
	# while an in/out signal is being emitted.
	_entrance.set_deferred("monitoring", false)
	# The player keeps their input until the fade is done, so freeze them rather
	# than letting them walk off during it.
	_player.set_physics_process(false)
	await _fade.fade_out()
	GlobalState.spawn_position = S06_SPAWN
	# Deferred: never swap scenes from inside a physics callback.
	get_tree().call_deferred("change_scene_to_file", S06_SCENE)
