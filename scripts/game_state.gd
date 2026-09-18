extends Node

var _locks: Dictionary = {}

func _ready() -> void:
	_ensure_input_actions()

func set_lock(reason: StringName, enabled: bool) -> void:
	if enabled:
		_locks[reason] = true
	else:
		_locks.erase(reason)

func is_input_locked() -> bool:
	return not _locks.is_empty()

func clear_locks() -> void:
	_locks.clear()

func is_mobile_web() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios")

func _ensure_input_actions() -> void:
	_ensure_key_action(&"move_up", [KEY_W, KEY_UP])
	_ensure_key_action(&"move_down", [KEY_S, KEY_DOWN])
	_ensure_key_action(&"move_left", [KEY_A, KEY_LEFT])
	_ensure_key_action(&"move_right", [KEY_D, KEY_RIGHT])
	_ensure_key_action(&"interact", [KEY_SPACE, KEY_ENTER])

func _ensure_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	if not InputMap.action_get_events(action).is_empty():
		return

	for key_code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key_code
		InputMap.action_add_event(action, event)
