extends Node2D

# ChamberBase - Base class for all chambers
# Attach to root of each chamber scene

class_name ChamberBase

signal chamber_exit_requested(target_chamber: String)

@export var chamber_id: String = ""
@export var chamber_name: String = "Unnamed Chamber"
@export var chamber_description: String = ""
@export var aspect_hint: String = "Girl"
@export var background_texture: Texture2D

var is_active: bool = false
var is_unlocked: bool = false

func _ready():
	print("ChamberBase: %s ready" % chamber_id)
	_setup_background()
	_check_unlock_state()
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)
	DissolutionManager.sequence_completed.connect(_on_dissolution_complete)
	# Connect zone click events for navigation
	for child in get_children():
		if child is Area2D and child.name.begins_with("Zone_"):
			child.input_event.connect(_on_zone_clicked.bind(child))
			child.input_pickable = true

func _on_zone_clicked(viewport: Node, event: InputEvent, shape_idx: int, zone: Area2D):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target_chamber = zone.name.trim_prefix("Zone_").to_snake_case()
		print("ChamberBase: Clicked zone %s -> target %s" % [zone.name, target_chamber])
		chamber_exit_requested.emit(target_chamber)

func _setup_background():
	var bg = $Background
	if bg and background_texture:
		bg.texture = background_texture

func _check_unlock_state():
	is_unlocked = MemorySystem.is_chamber_unlocked(chamber_id)
	if not is_unlocked and chamber_id != "threshold":
		visible = false
		print("ChamberBase: %s locked" % chamber_id)
	else:
		visible = true

func enter_chamber():
	"""Called when player enters this chamber."""
	if not is_unlocked:
		return
	
	is_active = true
	visible = true
	
	# Start chamber music
	MusicManager.play_chamber_music(chamber_id)
	
	# Load dialogue
	DialogueSystem.load_chamber_dialogue(chamber_id)
	
	# Start with intro node
	var intro_node = chamber_id + "_intro"
	if not intro_node in DialogueSystem.dialogue_data:
		intro_node = "intro"
	
	DialogueSystem.start_dialogue(intro_node)
	
	# Track aspect
	MemorySystem.record_aspect(EmotionalState.current_aspect)
	print("ChamberBase: Entered %s" % chamber_id)

func exit_chamber():
	is_active = false
	print("ChamberBase: Exited %s" % chamber_id)

func _on_dialogue_ended():
	"""Dialogue finished — show exit options or auto-exit."""
	print("ChamberBase: Dialogue ended in %s" % chamber_id)

func _on_dissolution_complete(new_aspect: String):
	"""After dissolution, reload chamber with new aspect."""
	if is_active:
		print("ChamberBase: Dissolution complete in %s — new aspect: %s" % [chamber_id, new_aspect])
		# Could reload dialogue or show confusion lines

func unlock():
	"""Unlock this chamber."""
	is_unlocked = true
	MemorySystem.unlock_chamber(chamber_id)
	visible = true
	print("ChamberBase: %s unlocked" % chamber_id)
