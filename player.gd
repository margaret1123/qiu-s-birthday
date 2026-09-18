extends CharacterBody2D

const SPEED = 200.0

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
		move_and_slide()
		return

	# Get input direction
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Set velocity
	velocity = direction * SPEED

	# Move
	move_and_slide()
