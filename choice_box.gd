extends CanvasLayer

## A minimal two-option prompt.
##
## This is UI only: it knows nothing about the scene that uses it. It shows two
## strings, tracks which one is highlighted, and reports the picked index.

signal choice_selected(index: int)

# Plate art. The source PNGs are wide canvases with a lot of transparent
# padding around a much smaller plate, so the scene crops them with
# AtlasTexture. Exported rather than preloaded here to keep the art a scene
# concern.
@export var plate_normal: Texture2D
@export var plate_selected: Texture2D

# Matches the pale yellow border and arrow of the selected plate.
const COLOR_HIGHLIGHT := Color(0.992157, 0.952941, 0.627451, 1)
const COLOR_IDLE := Color(1, 1, 1, 1)

var _open: bool = false
var _highlighted: int = 0

@onready var _panel: Panel = $Panel
@onready var _options: Array[Button] = [
	$Panel/VBoxContainer/Option0 as Button,
	$Panel/VBoxContainer/Option1 as Button,
]
@onready var _plates: Array[TextureRect] = [
	$Panel/VBoxContainer/Option0/Plate as TextureRect,
	$Panel/VBoxContainer/Option1/Plate as TextureRect,
]
@onready var _labels: Array[Label] = [
	$Panel/VBoxContainer/Option0/Text as Label,
	$Panel/VBoxContainer/Option1/Text as Label,
]

func _ready() -> void:
	add_to_group("choice_box")
	for i in _options.size():
		_options[i].pressed.connect(_on_option_pressed.bind(i))
	hide_choices()

func is_open() -> bool:
	return _open

func show_choices(options: Array[String]) -> void:
	# Two options only, by design - this is a binary prompt, not a menu.
	for i in _labels.size():
		_labels[i].text = options[i] if i < options.size() else ""
	_set_highlight(0)
	_open = true
	_panel.visible = true

func hide_choices() -> void:
	_open = false
	_panel.visible = false

func _process(_delta: float) -> void:
	if not _open:
		return
	if Input.is_action_just_pressed("ui_up"):
		_set_highlight(0)
	elif Input.is_action_just_pressed("ui_down"):
		_set_highlight(1)
	# "interact" is E and Space, "ui_accept" is Enter.
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		_select(_highlighted)

func _input(event: InputEvent) -> void:
	# Hover follows real mouse motion only. Godot also raises mouse_entered when
	# a control appears under an already resting cursor, which would steal the
	# default highlight the moment the box opens.
	if not _open or not (event is InputEventMouseMotion):
		return
	for i in _options.size():
		var option := _options[i]
		if Rect2(Vector2.ZERO, option.size).has_point(option.get_local_mouse_position()):
			_set_highlight(i)
			return

func _set_highlight(index: int) -> void:
	_highlighted = index
	for i in _options.size():
		var is_highlighted := i == index
		_plates[i].texture = plate_selected if is_highlighted else plate_normal
		_labels[i].add_theme_color_override(
			"font_color", COLOR_HIGHLIGHT if is_highlighted else COLOR_IDLE
		)

func _select(index: int) -> void:
	hide_choices()
	choice_selected.emit(index)

func _on_option_pressed(index: int) -> void:
	if _open:
		_select(index)
