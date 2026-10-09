extends Control

# DialogueBoxUI - Handles dialogue display and choice interaction

@onready var background = $Background
@onready var portrait = $Background/Portrait
@onready var speaker_label = $Background/SpeakerLabel
@onready var dialogue_text = $Background/DialogueText
@onready var choices_container = $Background/ChoicesContainer

var choice_buttons: Array[Button] = []
var done_button: Button = null

func _ready():
	visible = false
	DialogueSystem.dialogue_started.connect(_on_dialogue_started)
	DialogueSystem.dialogue_line.connect(_on_dialogue_line)
	DialogueSystem.choices_presented.connect(_on_choices_presented)
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)
	DialogueSystem.dissolution_triggered.connect(_on_dissolution_triggered)
	DialogueSystem.hold_for_continue.connect(_show_done)
	print("DialogueBoxUI: Ready")

func _on_dialogue_started(node_id: String):
	visible = true
	dialogue_text.text = ""
	_clear_choices()
	print("DialogueBoxUI: Dialogue started — %s" % node_id)

func _on_dialogue_line(text: String, speaker: String, portrait_path: String):
	visible = true
	speaker_label.text = speaker
	dialogue_text.text = text
	_hide_done()
	VoiceManager.speak(text)
	
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
		if choice.get("_locked", false):
			# A locked choice is a window, not a wall — show the threshold dimmed.
			btn.modulate = Color(1, 1, 1, 0.45)
			btn.tooltip_text = choice.get("locked_text", "Not yet.")
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(btn)
		choice_buttons.append(btn)
	_hide_done()

func _show_done():
	"""Terminal line: give the player an explicit way to close the conversation."""
	if done_button == null:
		done_button = Button.new()
		done_button.text = "Done"
		done_button.custom_minimum_size = Vector2(90, 32)
		done_button.add_theme_font_size_override("font_size", 14)
		done_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		done_button.position = Vector2(-100, -40)
		done_button.pressed.connect(_on_done_pressed)
		add_child(done_button)
	done_button.visible = true

func _hide_done():
	if done_button:
		done_button.visible = false

func _on_done_pressed():
	_hide_done()
	visible = false
	DialogueSystem.continue_dialogue()

func _on_choice_pressed(index: int):
	DialogueSystem.make_choice(index)
	_clear_choices()

func _on_dialogue_ended():
	visible = false
	_hide_done()
	_clear_choices()

func _unhandled_input(event: InputEvent) -> void:
	# A remark card (fragment/fallback line with no choices) dismisses on click.
	if visible and choice_buttons.is_empty():
		var dismiss := false
		if event is InputEventMouseButton and event.pressed:
			dismiss = true
		elif event.is_action_pressed("ui_accept"):
			dismiss = true
		if dismiss:
			visible = false
			_hide_done()
			DialogueSystem.continue_dialogue()
	print("DialogueBoxUI: Dialogue ended")

func _on_dissolution_triggered():
	visible = false
	_hide_done()
	_clear_choices()
	print("DialogueBoxUI: Dissolution triggered — hiding dialogue")

func _clear_choices():
	for btn in choice_buttons:
		btn.queue_free()
	choice_buttons.clear()
