extends CharacterBody2D

signal interaction_requested(event_id: StringName)

const GameStateScript := preload("res://scripts/game_state.gd")

@export var speed: float = 92.0

@onready var interaction_ray: RayCast2D = $InteractionRay

# Looked up through the scene tree rather than the bare `GameState` identifier:
# Godot does not register autoloads as global identifiers when a script is run
# with `--script`, which would make this file fail to compile in headless tests.
@onready var game_state: GameStateScript = get_node_or_null(^"/root/GameState")

var facing: Vector2 = Vector2.DOWN

func _physics_process(_delta: float) -> void:
	if game_state != null and game_state.is_input_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if input_vector != Vector2.ZERO:
		facing = _cardinal_direction(input_vector)
		interaction_ray.target_position = facing * 22.0

	velocity = input_vector * speed
	move_and_slide()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _cardinal_direction(value: Vector2) -> Vector2:
	if abs(value.x) > abs(value.y):
		return Vector2.RIGHT if value.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if value.y > 0.0 else Vector2.UP

func _try_interact() -> void:
	if not interaction_ray.is_colliding():
		return

	var target := interaction_ray.get_collider()
	if target == null or not target.has_method("interact"):
		return

	var event_id: StringName = target.interact(self)
	if event_id != &"":
		interaction_requested.emit(event_id)
