extends CanvasLayer

## Emitted only when the player advances past the last line with the normal
## confirm key. Cancelling with ESC is not a completion and does not emit.
signal dialogue_finished

@onready var panel = $Panel
@onready var name_label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var text_label = $Panel/MarginContainer/VBoxContainer/TextLabel

var lines: Array[String] = []
var current_line: int = 0

func _ready():
	add_to_group("dialogue_box")
	hide_dialogue()

func is_open() -> bool:
	return panel.visible

func show_dialogue(npc_name: String, dialogue_lines: Array[String]):
	if dialogue_lines.is_empty():
		hide_dialogue()
		return
	lines = dialogue_lines
	current_line = 0
	name_label.text = npc_name
	text_label.text = lines[0]
	panel.visible = true

func hide_dialogue():
	panel.visible = false

func _process(_delta):
	if panel.visible:
		if Input.is_action_just_pressed("ui_cancel"):
			hide_dialogue()
		elif Input.is_action_just_pressed("interact"):
			current_line += 1
			if current_line >= lines.size():
				hide_dialogue()
				dialogue_finished.emit()
			else:
				text_label.text = lines[current_line]
