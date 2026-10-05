extends Node

# DialogueSystem - Parses dialogue YAML and manages branching
# Autoload singleton

signal dialogue_started(node_id: String)
signal dialogue_line(text: String, speaker: String, portrait: String)
signal choices_presented(options: Array[Dictionary])
signal dialogue_ended()
signal hold_for_continue()

# Terminal lines (nodes with no choices) hold until the player clicks —
# otherwise the last line of every branch is unreadable.
var awaiting_continue: bool = false
signal dissolution_triggered()

# Merged view across all loaded chambers — all chambers are instanced
# simultaneously, so single-chamber storage would clobber earlier loads.
var dialogue_data: Dictionary = {}
var current_chamber: String = ""
var current_node: String = ""
var current_yaml_path: String = ""

func _ready():
	print("DialogueSystem: Initialized")
	# The dissolution sequence is fully built but nothing invoked it —
	# bridge our trigger signal to the manager's sequence.
	dissolution_triggered.connect(DissolutionManager.trigger_dissolution)

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
	
	var parsed := _parse_yaml_dialogue(raw_text)
	for node_id in parsed.keys():
		dialogue_data[node_id] = parsed[node_id]
	current_chamber = chamber_id
	
	print("DialogueSystem: Loaded %s (%d nodes, %d total)" % [chamber_id, parsed.size(), dialogue_data.size()])
	return true

func _parse_yaml_dialogue(text: String) -> Dictionary:
	"""YAML parser for dialogue files. Indent-sensitive:
	nodes at 2 spaces, node props at 4, choice items at 6, choice props at 8."""
	var nodes = {}
	var lines = text.split("\n")
	var current_node_id = ""
	var current_node = {}
	var in_choices = false
	var current_choice = {}
	var in_effects_block := false
	var effect_base := 0
	var in_multiline_text = false
	var multiline_buffer = ""

	for raw_line in lines:
		var stripped = raw_line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		var indent := 0
		while indent < raw_line.length() and raw_line[indent] == " ":
			indent += 1

		if stripped == "nodes:":
			continue

		# Node header: exactly 2-space indent, ends with ':'
		if indent == 2 and stripped.ends_with(":"):
			_flush_node(nodes, current_node_id, current_node, in_multiline_text, multiline_buffer)
			if in_choices and not current_choice.is_empty() and nodes.has(current_node_id):
				nodes[current_node_id]["choices"].append(current_choice)
			current_node_id = stripped.trim_suffix(":").strip_edges()
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
			current_choice = {}
			in_multiline_text = false
			multiline_buffer = ""
			continue

		if current_node_id.is_empty():
			continue

		# Multiline text capture: swallow deeper-indented lines while in a block
		if in_multiline_text and indent >= 4:
			var is_known_key := stripped.begins_with("text:") or stripped.begins_with("speaker:") \
				or stripped.begins_with("aspect_lock:") or stripped.begins_with("choices:") \
				or stripped.begins_with("dissolve_after:") or stripped.begins_with("memory_unlock:") \
			or stripped.begins_with("- ")
			if not is_known_key:
				multiline_buffer += raw_line.substr(4) + "\n"
				continue

		# Choice block: both dialects (items at 4 or 6, props deeper).
		# Handles inline and multi-line emotional_effect blocks.
		if in_choices and indent >= 4:
			if in_effects_block:
				if indent > effect_base and stripped.contains(":"):
					var ekv := stripped.split(":")
					if ekv.size() == 2 and ekv[1].strip_edges().is_valid_float():
						current_choice["emotional_effect"][ekv[0].strip_edges()] = ekv[1].strip_edges().to_float()
						continue
				in_effects_block = false
			if stripped.begins_with("- "):
				if not current_choice.is_empty():
					current_node["choices"].append(current_choice)
				current_choice = {}
				var choice_text := stripped.substr(2).strip_edges()
				if choice_text.begins_with("text: "):
					current_choice["text"] = choice_text.substr(6).trim_prefix("\"").trim_suffix("\"")
				else:
					current_choice["text"] = choice_text
			elif stripped == "emotional_effect:":
				current_choice["emotional_effect"] = {}
				in_effects_block = true
				effect_base = indent
			elif stripped.begins_with("emotional_effect:"):
				current_choice["emotional_effect"] = _parse_effects(stripped.substr(17))
			elif stripped.begins_with("target: "):
				current_choice["target"] = stripped.substr(8).strip_edges()
			elif stripped.begins_with("dissolve_after: "):
				current_choice["dissolve_after"] = stripped.substr(16).strip_edges() == "true"
			elif stripped.begins_with("requires: "):
				current_choice["requires"] = _parse_effects(stripped.substr(10))
			elif stripped.begins_with("requires_memory: "):
				current_choice["requires_memory"] = stripped.substr(18).strip_edges()
			elif stripped.begins_with("locked_text: "):
				var lt := stripped.substr(13).strip_edges()
				current_choice["locked_text"] = lt.trim_prefix("\"").trim_suffix("\"")
			continue

		# Node props: exactly 4-space indent
		if indent != 4:
			continue

		if stripped.begins_with("text: "):
			var text_val := stripped.substr(6)
			if text_val == "|":
				in_multiline_text = true
				multiline_buffer = ""
			else:
				in_multiline_text = false
				current_node["text"] = text_val.trim_prefix("\"").trim_suffix("\"")
		elif stripped.begins_with("speaker: "):
			current_node["speaker"] = stripped.substr(9)
		elif stripped.begins_with("aspect_lock: "):
			current_node["aspect_lock"] = stripped.substr(13)
		elif stripped.begins_with("dissolve_after: "):
			current_node["dissolve_after"] = stripped.substr(16).strip_edges() == "true"
		elif stripped.begins_with("memory_unlock: "):
			current_node["memory_unlock"] = stripped.substr(15)
		elif stripped.begins_with("dialogue_ended: "):
			current_node["dialogue_ended"] = stripped.substr(16).strip_edges() == "true"
		elif stripped == "choices:" or stripped.begins_with("choices: #"):
			if in_multiline_text:
				current_node["text"] = multiline_buffer.strip_edges()
				in_multiline_text = false
				multiline_buffer = ""
			in_choices = true

	# Final flush
	_flush_node(nodes, current_node_id, current_node, in_multiline_text, multiline_buffer)
	if in_choices and not current_choice.is_empty() and nodes.has(current_node_id):
		nodes[current_node_id]["choices"].append(current_choice)

	return nodes

func _flush_node(nodes: Dictionary, node_id: String, node: Dictionary, in_multiline: bool, buffer: String) -> void:
	if node_id.is_empty() or node.is_empty():
		return
	if in_multiline:
		node["text"] = buffer.strip_edges()
	nodes[node_id] = node

func _parse_effects(effect_str: String) -> Dictionary:
	var effects = {}
	var cleaned := effect_str.strip_edges().trim_prefix("{").trim_suffix("}").strip_edges()
	if cleaned.is_empty():
		return effects
	var pairs = cleaned.split(",")
	for pair in pairs:
		var kv = pair.strip_edges().split(":")
		if kv.size() == 2:
			var axis = kv[0].strip_edges().trim_prefix("\"").trim_suffix("\"")
			var val = kv[1].strip_edges().trim_prefix("\"").trim_suffix("\"").to_float()
			effects[axis] = val
	return effects

func start_dialogue(node_id: String):
	awaiting_continue = false
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
	
	# Present choices (annotated with lock state)
	var choices = node.get("choices", [])
	if choices.is_empty():
		# Terminal line: hold until the player clicks continue.
		awaiting_continue = true
		hold_for_continue.emit()
	else:
		for ch in choices:
			ch["_locked"] = not requirements_met(ch)
		choices_presented.emit(_typed_choices(choices))

func continue_dialogue():
	"""Player clicked to dismiss a terminal line."""
	if not awaiting_continue:
		return
	awaiting_continue = false
	dialogue_ended.emit()

func _typed_choices(choices: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for ch in choices:
		typed.append(ch)
	return typed

func requirements_met(choice: Dictionary) -> bool:
	var req: Dictionary = choice.get("requires", {})
	for axis in req.keys():
		if EmotionalState.get(axis) < req[axis]:
			return false
	var mem: String = choice.get("requires_memory", "")
	if not mem.is_empty():
		if mem.begins_with("visits:"):
			return MemorySystem.total_visits >= mem.trim_prefix("visits:").to_int()
		if mem.begins_with("dissolutions:"):
			return MemorySystem.total_dissolutions_witnessed >= mem.trim_prefix("dissolutions:").to_int()
		if mem.begins_with("chamber:"):
			return MemorySystem.is_chamber_unlocked(mem.trim_prefix("chamber:"))
		return MemorySystem.memories_unlocked.has(mem)
	return true

func first_available_choice_index(choices: Array) -> int:
	for i in choices.size():
		if not choices[i].get("_locked", false):
			return i
	return -1

func make_choice(choice_index: int):
	var node = dialogue_data.get(current_node, {})
	var choices = node.get("choices", [])
	
	if choice_index < 0 or choice_index >= choices.size():
		push_error("DialogueSystem: Invalid choice index %d" % choice_index)
		return
	
	var choice = choices[choice_index]

	# Gate check: a locked choice is a window, not a wall — say so, then re-present
	if choice.get("_locked", false):
		var gate_line: String = choice.get("locked_text", "Not yet. Not like this. But it's here. I'm here. Come back different, and I'll show you.")
		dialogue_line.emit(gate_line, "Kira", KiraAspect.get_portrait_for_aspect(EmotionalState.current_aspect))
		choices_presented.emit(_typed_choices(choices))
		return
	
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
