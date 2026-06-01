extends Control

# DialogueBoxUI - Handles dialogue display and choice interaction

@onready var background = $Background
@onready var portrait = $Background/Portrait
@onready var speaker_label = $Background/SpeakerLabel
@onready var dialogue_text = $Background/DialogueText
@onready var choices_container = $Background/ChoicesContainer

var choice_buttons: Array[Button] = []

func _ready():
	visible = false
	DialogueSystem.dialogue_started.connect(_on_dialogue_started)
	DialogueSystem.dialogue_line.connect(_on_dialogue_line)
	DialogueSystem.choices_presented.connect(_on_choices_presented)
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)
	DialogueSystem.dissolution_triggered.connect(_on_dissolution_triggered)
	print("DialogueBoxUI: Ready")

func _on_dialogue_started(node_id: String):
	visible = true
	dialogue_text.text = ""
	_clear_choices()
	print("DialogueBoxUI: Dialogue started — %s" % node_id)

func _on_dialogue_line(text: String, speaker: String, portrait_path: String):
	speaker_label.text = speaker
	dialogue_text.text = text
	
	# Load portrait
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		var tex = load(portrait_path)
		if tex is Texture2D:
			portrait.texture = tex
			portrait.visible = true
	else:
		portrait.visible = false
	
	print("DialogueBoxUI: %s: %s" % [speaker, text])

func _on_choices_presented(options: Array[Dictionary]):
	_clear_choices()
	
	for i in range(options.size()):
		var choice = options[i]
		var btn = Button.new()
		btn.text = choice.get("text", "...")
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(btn)
		choice_buttons.append(btn)

func _on_choice_pressed(index: int):
	DialogueSystem.make_choice(index)
	_clear_choices()

func _on_dialogue_ended():
	visible = false
	_clear_choices()
	print("DialogueBoxUI: Dialogue ended")

func _on_dissolution_triggered():
	visible = false
	_clear_choices()
	print("DialogueBoxUI: Dissolution triggered — hiding dialogue")

func _clear_choices():
	for btn in choice_buttons:
		btn.queue_free()
	choice_buttons.clear()
