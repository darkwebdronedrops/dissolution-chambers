extends Area2D

# ClickableObject - An interactable object in a chamber
# Click to trigger dialogue, memory, or environmental effect

class_name ClickableObject

@export var object_id: String = ""
@export var object_name: String = "Object"
@export var object_description: String = ""
@export var dialogue_node: String = ""  # Dialogue node to trigger when clicked
@export var memory_id: String = ""  # Memory to unlock
@export var emotional_effect: Dictionary = {}  # { "warmth": +1, "depth": -1 }
@export var texture: Texture2D
@export var hover_scale: float = 1.1

var _base_scale: Vector2 = Vector2.ONE
var _is_hovering: bool = false

func _ready():
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_pickable = true
	
	# Set sprite if we have one
	var sprite = $Sprite2D
	if sprite and texture:
			sprite.texture = texture
			_base_scale = sprite.scale
	
	print("ClickableObject: %s ready" % object_id)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("ClickableObject: Clicked %s" % object_id)
		_interact()

func _on_mouse_entered():
	_is_hovering = true
	var sprite = $Sprite2D
	if sprite:
		sprite.scale = _base_scale * hover_scale
	# Could show tooltip or cursor change

func _on_mouse_exited():
	_is_hovering = false
	var sprite = $Sprite2D
	if sprite:
		sprite.scale = _base_scale

func _interact():
	"""Handle interaction."""
	# Apply emotional effects
	if not emotional_effect.is_empty():
		EmotionalState.apply_choice_effect(emotional_effect)
	
	# Unlock memory
	if not memory_id.is_empty():
		MemorySystem.record_memory(memory_id)
		print("ClickableObject: Memory unlocked — %s" % memory_id)
	
	# Trigger dialogue if specified
	if not dialogue_node.is_empty():
		if DialogueSystem.dialogue_data.has(dialogue_node):
			DialogueSystem.start_dialogue(dialogue_node)
		else:
			push_warning("ClickableObject: Dialogue node not found — %s" % dialogue_node)
			_show_fallback_text()
	else:
		_show_fallback_text()

func _show_fallback_text():
	"""Show a simple description when no dialogue is linked."""
	var fallback_text = object_description
	if fallback_text.is_empty():
		fallback_text = "It's %s." % object_name
	
	# Emit a signal that the dialogue box can catch as a simple line
	DialogueSystem.dialogue_line.emit(fallback_text, "Kira", "")
	DialogueSystem.dialogue_ended.emit()
