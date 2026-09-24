extends Control

# TitleScreen - The game's opening screen
# Atmospheric, personal, liminal

signal start_pressed(new_game: bool)
signal credits_pressed

@onready var title_label = $VBoxContainer/TitleLabel
@onready var tagline_label = $VBoxContainer/TaglineLabel
@onready var enter_button = $VBoxContainer/EnterButton
@onready var begin_anew_button = $VBoxContainer/BeginAnewButton
@onready var credits_button = $VBoxContainer/CreditsButton
@onready var version_label = $VersionLabel

var has_save: bool = false

func _ready():
	# Check for existing save
	has_save = FileAccess.file_exists(MemorySystem.save_path)
	
	# Set up button visibility
	enter_button.visible = true
	begin_anew_button.visible = has_save
	credits_button.visible = true
	
	# Button text
	if has_save:
		enter_button.text = "Continue"
		tagline_label.text = "You were here before. The door remembers."
	else:
		enter_button.text = "Enter"
		tagline_label.text = "A game about becoming."
	
	# Style the title with glow/shadow effects
	_style_title_text()
	
	# Connect signals
	enter_button.pressed.connect(_on_enter_pressed)
	begin_anew_button.pressed.connect(_on_begin_anew_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	
	# Animate title in
	_animate_title()
	
	print("TitleScreen: Ready — save found: %s" % has_save)

func _style_title_text():
	"""Apply rich text styling to title — outline, shadow, color."""
	# Amber/gold outline with dark shadow for depth
	title_label.add_theme_color_override("font_outline_color", Color(0.9, 0.7, 0.3, 0.9))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.08, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	
	# Tagline gets a subtler treatment
	tagline_label.add_theme_color_override("font_outline_color", Color(0.7, 0.5, 0.7, 0.6))
	tagline_label.add_theme_constant_override("outline_size", 2)
	tagline_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.04, 0.6))
	tagline_label.add_theme_constant_override("shadow_offset_x", 2)
	tagline_label.add_theme_constant_override("shadow_offset_y", 2)

func _animate_title():
	"""Gentle fade-in and subtle pulse for the title."""
	modulate = Color(1, 1, 1, 0)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 2.0)
	tween.set_ease(Tween.EASE_OUT)
	
	# Subtle pulse on the title
	tween.tween_property(title_label, "modulate", Color(1, 1, 1, 0.85), 3.0)
	tween.tween_property(title_label, "modulate", Color(1, 1, 1, 1.0), 3.0)
	tween.set_loops()
	


func _on_enter_pressed():
	print("TitleScreen: Enter pressed")
	_fade_out_and_start(false)

func _on_begin_anew_pressed():
	print("TitleScreen: Begin Anew pressed")
	_fade_out_and_start(true)

func _on_credits_pressed():
	print("TitleScreen: Credits pressed")
	credits_pressed.emit()

func _fade_out_and_start(new_game: bool):
	"""Fade out title screen, then signal to start."""
	enter_button.disabled = true
	begin_anew_button.disabled = true
	credits_button.disabled = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.5)
	tween.set_ease(Tween.EASE_IN)
	
	await tween.finished
	visible = false
	start_pressed.emit(new_game)

func show_credits_return():
	"""Called after credits roll to bring title screen back."""
	visible = true
	modulate = Color(1, 1, 1, 0)
	
	enter_button.disabled = false
	begin_anew_button.disabled = false
	credits_button.disabled = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 1.5)
	print("TitleScreen: Returned from credits")
