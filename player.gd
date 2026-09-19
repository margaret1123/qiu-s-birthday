extends CharacterBody2D

const SPEED = 200.0

## Which way the body is drawn. Held across frames rather than derived from the
## current input alone: on an exact diagonal neither axis dominates, and on a
## full stop there is no input at all. Re-deciding in those frames is what makes
## the sprite flicker between two facings, so the last clear facing is kept.
var _facing := "down"

@onready var _body: AnimatedSprite2D = $Body

func _ready() -> void:
	add_to_group("player")
	if GlobalState.spawn_position.x >= 0.0:
		position = GlobalState.spawn_position
		GlobalState.spawn_position = Vector2(-1.0, -1.0)

func _physics_process(_delta):
	# While a dialogue or a choice prompt is open the player stands still; the
	# same keys drive the UI instead of walking.
	var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	var choice_box = get_tree().get_first_node_in_group("choice_box")
	if (dialogue_box and dialogue_box.is_open()) or (choice_box and choice_box.is_open()):
		velocity = Vector2.ZERO
		_animate(Vector2.ZERO)
		move_and_slide()
		return

	# Get input direction
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Set velocity
	velocity = direction * SPEED

	_animate(direction)

	# Move
	move_and_slide()

## The scene owns the player's physics: every scripted event switches it off to
## hold the player still while it plays. The animation lives in _physics_process,
## so it stops with the physics - and a walk cycle left on screen keeps stepping
## under a body that can no longer move. Idle processing is not switched off, and
## is what puts the feet back under them.
##
## It only guards the state the physics cannot speak for. While the physics is
## on, this does nothing at all, so the walking rules stay in one place.
func _process(_delta: float) -> void:
	if not is_physics_processing():
		_animate(Vector2.ZERO)

## Reads the movement the controller asked for, not the velocity move_and_slide
## left behind: a body pressed against a wall has that velocity eaten by the
## collision, and standing still there is not what the player is doing.
##
## The keyboard and the touch HUD both feed the same ui_* actions, so they drive
## this one set of rules between them rather than one each.
func _animate(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_face(direction)
	_play(("walk_" if direction != Vector2.ZERO else "idle_") + _facing)

## The dominant axis of the movement picks the facing. An exact diagonal has no
## dominant axis, so the heading is left alone.
func _face(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		_facing = "right" if direction.x > 0.0 else "left"
	elif absf(direction.y) > absf(direction.x):
		_facing = "down" if direction.y > 0.0 else "up"

## Re-playing the animation already on screen would restart it, so a walk cycle
## asked for on every physics frame would sit on its first frame forever.
func _play(anim: String) -> void:
	if _body.animation != anim:
		_body.play(anim)
