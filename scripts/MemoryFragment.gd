extends Resource

# MemoryFragment - A voiced/recorded memory triggered by object interaction
# Each fragment is a moment Kira remembers, spoken in her voice

class_name MemoryFragment

@export var fragment_id: String
@export var chamber: String
@export var trigger_object: String
@export var aspect: String  # Which aspect of Kira remembers this
@export var text: String
@export var requires_state: Dictionary = {}  # Emotional requirements to trigger
@export var unlocks_after_visit: int = 0  # Visit count required
@export var is_secret: bool = false  # Hidden until conditions met

var has_been_heard: bool = false

func can_trigger() -> bool:
	if has_been_heard and is_secret:
		return false
	
	if MemorySystem.total_visits < unlocks_after_visit:
		return false
	
	for axis in requires_state.keys():
		var current = EmotionalState.get(axis)
		var required = requires_state[axis]
		if current < required:
			return false
	
	return true

func mark_heard():
	has_been_heard = true
	MemorySystem.record_memory(fragment_id)
