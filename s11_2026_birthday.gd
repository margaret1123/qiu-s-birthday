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
## The ending is the photograph, and the line it was read for stays up with it:
## the picture is the size of the wall it hangs on, not the size of the screen, so
## it is put up above the box rather than over it. Both are on screen together and
## the scene stops there: no return to a title, no black, no THE END, and no
## second conversation.

var _ended := false

## The grown-up body, put on in code rather than left to the scene.
##
## The scene used to override the player's Body child directly, which is the
## ordinary way to do this and is what the editor shows. The exported build does
## not keep it: Godot 4.7 drops `[node name="Body" parent="WorldSort/Player"
## index="0"]` when it converts the scene for export, so the build fell back to
## player.tscn's own frames and the last scene played with the school-age sprite -
## twenty years on, still in the uniform. The override survives in the editor,
## which is why this only ever showed up in a shipped build.
##
## Applied here, the build cannot drop it. The values are the ones the scene
## carried: the adult sheet, its scale and its offset. player.gd drives animation
## names, which the adult sheet shares with the student one, so the walk cycle
## keeps working without player.gd knowing anything about this.
const ADULT_FRAMES := preload("res://art/characters/Qiu/adult_qiu_sprite_frames.tres")
const ADULT_SCALE := Vector2(0.395653, 0.395653)
const ADULT_OFFSET := Vector2(0, -340)

@onready var _dialogue_box = $DialogueBox
@onready var _fade = $FadeOverlay
@onready var _player: CharacterBody2D = $WorldSort/Player
@onready var _biu: Node = $WorldSort/BiuActor
@onready var _photo: CanvasLayer = $FinalPhoto

func _ready() -> void:
	_wear_adult_body()
	_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	_photo.visible = false
	# Straight out of the black the gate ended on, so: fade up onto 2026.
	_fade.fade_in()

func _wear_adult_body() -> void:
	var body := _player.get_node_or_null("Body") as AnimatedSprite2D
	if body == null:
		return
	body.sprite_frames = ADULT_FRAMES
	body.scale = ADULT_SCALE
	body.offset = ADULT_OFFSET
	body.play("idle_down")

	# Biu is drawn as the cake sprite under Visual, and the scene switched her own
	# body off so the two would not stack. That override is dropped by the same
	# export step, which would leave an idle NPC standing behind the cake.
	var biu_body := _biu.get_node_or_null("Body") as AnimatedSprite2D
	if biu_body != null:
		biu_body.visible = false

## The line has been read through. Nothing is said after it and nothing is played
## after it: the photograph goes up, the line stays where it is, and the scene is
## left standing on the two of them.
##
## The line is put back deliberately. Reading the last line is what closed the
## box, and the ending is the last thing worth reading - so it is handed back to
## the box and then the box is switched off, which leaves it open on screen and
## unable to be advanced, cancelled or closed. Its layer sits under the
## photograph's, and the two do not overlap, so neither covers the other.
##
## The NPC and the player are switched off for the same reason. npc.gd is what
## would let the line be started again, and a second run would open a DialogueBox
## behind the photograph - where it can never be seen or closed. The ending has to
## be the last thing that can happen here.
func _on_dialogue_finished() -> void:
	if _ended:
		return
	_ended = true
	_biu.set_process(false)
	_player.set_physics_process(false)
	_photo.visible = true
	# Straight from the NPC, so the ending has one copy of the words and not two.
	_dialogue_box.show_dialogue(_biu.npc_name, _biu.dialogue_lines)
	_dialogue_box.set_process(false)
