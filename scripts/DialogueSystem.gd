extends Node

# DialogueSystem - Parses dialogue YAML and manages branching
# Autoload singleton

signal dialogue_started(node_id: String)
signal dialogue_line(text: String, speaker: String, portrait: String)
signal choices_presented(options: Array[Dictionary])
signal dialogue_ended()
signal dissolution_triggered()

var dialogue_data: Dictionary = {}
var current_chamber: String = ""
var current_node: String = ""
var current_yaml_path: String = ""

func _ready():
	print("DialogueSystem: Initialized")

func load_chamber_dialogue(chamber_id: String):
	var path = "res://data/dialogue/%s.yaml" % chamber_id
	current_yaml_path = path
	
	if not FileAccess.file_exists(path):
		push_error("DialogueSystem: No dialogue file found: %s" % path)
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("DialogueSystem: Failed to open: %s" % path)
		return false
	
	var raw_text = file.get_as_text()
	file.close()
	
	dialogue_data = _parse_yaml_dialogue(raw_text)
	current_chamber = chamber_id
	
	print("DialogueSystem: Loaded %s (%d nodes)" % [chamber_id, dialogue_data.size()])
	return true

func _parse_yaml_dialogue(text: String) -> Dictionary:
	"""Simple YAML-like parser for dialogue files."""
	var nodes = {}
	var lines = text.split("\n")
	var current_node_id = ""
	var current_node = {}
	var in_choices = false
	var current_choice = {}
	
	for raw_line in lines:
		var line = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		
		# Node start: "  node_id:" or top-level key
		if line.begins_with("nodes:"):
			continue
		
		# Node ID (2-space indent, ends with colon)
		if line.begins_with("  ") and not line.begins_with("    ") and line.ends_with(":"):
			if not current_node_id.is_empty() and not current_node.is_empty():
				nodes[current_node_id] = current_node
			
			current_node_id = line.trim_suffix(":").strip_edges()
			current_node = {
				"node_id": current_node_id,
				"speaker": "Kira",
				"text": "",
				"aspect_lock": "",
				"choices": [],
				"dissolve_after": false,
				"memory_unlock": ""
			}
			in_choices = false
			continue
		
		if current_node_id.is_empty():
			continue
		
		# Node properties (4-space indent)
		if not line.begins_with("    "):
			continue
		
		var prop = line.substr(4)  # Remove indent
		
		if prop.begins_with("text: "):
			current_node["text"] = prop.substr(6).trim_prefix("\"").trim_suffix("\"")
		elif prop.begins_with("speaker: "):
			current_node["speaker"] = prop.substr(9)
		elif prop.begins_with("aspect_lock: "):
			current_node["aspect_lock"] = prop.substr(13)
		elif prop.begins_with("dissolve_after: "):
			current_node["dissolve_after"] = prop.substr(16).strip_edges() == "true"
		elif prop.begins_with("memory_unlock: "):
			current_node["memory_unlock"] = prop.substr(15)
		elif prop.begins_with("choices:"):
			in_choices = true
		elif in_choices and prop.begins_with("-"):
			if not current_choice.is_empty():
				current_node["choices"].append(current_choice)
			current_choice = {}
			var choice_text = prop.substr(1).strip_edges()
			if choice_text.begins_with("text: "):
				current_choice["text"] = choice_text.substr(6).trim_prefix("\"").trim_suffix("\"")
			else:
				current_choice["text"] = choice_text
		elif in_choices and prop.begins_with("target: "):
			current_choice["target"] = prop.substr(8)
		elif in_choices and prop.begins_with("emotional_effect:"):
			current_choice["emotional_effect"] = _parse_effects(prop.substr(17))
		elif in_choices and prop.begins_with("dissolve_after: "):
			current_choice["dissolve_after"] = prop.substr(16).strip_edges() == "true"
	
	# Save last node and choice
	if not current_node_id.is_empty() and not current_node.is_empty():
		nodes[current_node_id] = current_node
	if in_choices and not current_choice.is_empty():
		if current_node_id in nodes:
			nodes[current_node_id]["choices"].append(current_choice)
	
	return nodes

func _parse_effects(effect_str: String) -> Dictionary:
	var effects = {}
	var pairs = effect_str.split(",")
	for pair in pairs:
		var kv = pair.strip_edges().split(":")
		if kv.size() == 2:
			var axis = kv[0].strip_edges()
			var val = kv[1].strip_edges().to_float()
			effects[axis] = val
	return effects

func start_dialogue(node_id: String):
	current_node = node_id
	dialogue_started.emit(node_id)
	_show_current_node()

func _show_current_node():
	if not current_node in dialogue_data:
		push_error("DialogueSystem: Node not found: %s" % current_node)
		dialogue_ended.emit()
		return
	
	var node = dialogue_data[current_node]
	var text = node.get("text", "")
	var speaker = node.get("speaker", "Kira")
	var aspect = node.get("aspect_lock", "")
	var portrait = ""
	
	if aspect.is_empty():
		aspect = EmotionalState.current_aspect
	
	portrait = KiraAspect.get_portrait_for_aspect(aspect)
	
	dialogue_line.emit(text, speaker, portrait)
	
	# Check for memory unlock
	var mem = node.get("memory_unlock", "")
	if not mem.is_empty():
		MemorySystem.record_memory(mem)
	
	# Present choices
	var choices = node.get("choices", [])
	if choices.is_empty():
		# End of dialogue branch
		dialogue_ended.emit()
	else:
		choices_presented.emit(choices)

func make_choice(choice_index: int):
	var node = dialogue_data.get(current_node, {})
	var choices = node.get("choices", [])
	
	if choice_index < 0 or choice_index >= choices.size():
		push_error("DialogueSystem: Invalid choice index %d" % choice_index)
		return
	
	var choice = choices[choice_index]
	
	# Apply emotional effects
	var effects = choice.get("emotional_effect", {})
	if not effects.is_empty():
		EmotionalState.apply_choice_effect(effects)
	
	# Check for dissolution trigger
	var dissolve = choice.get("dissolve_after", false) or node.get("dissolve_after", false)
	if dissolve or EmotionalState.check_dissolve_trigger():
		dissolution_triggered.emit()
		return
	
	# Transition to target node
	var target = choice.get("target", "")
	if target.is_empty():
		dialogue_ended.emit()
	else:
		start_dialogue(target)
