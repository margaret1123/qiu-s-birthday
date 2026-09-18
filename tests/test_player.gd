extends SceneTree

func _init() -> void:
	var packed := load("res://scenes/core/player.tscn") as PackedScene
	assert(packed != null)

	var player := packed.instantiate()
	assert(player.has_signal("interaction_requested"))
	assert(player.get("speed") > 0.0)

	var ray := player.get_node_or_null("InteractionRay")
	assert(ray is RayCast2D)
	assert(ray.collision_mask == 2)

	player.free()
	print("PASS: player")
	quit()
