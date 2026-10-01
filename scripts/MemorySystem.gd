extends Node

# MemorySystem - Persists data across visits and playthroughs
# Autoload singleton

var save_path: String = "user://dissolution_save.json"

# Persistent state
var endings_seen: Array[String] = []
var aspects_encountered: Array[String] = []
var memories_unlocked: Array[String] = []
var total_dissolutions_witnessed: int = 0
var total_visits: int = 0
var new_game_plus: bool = false
var visit_memory: Dictionary = {}  # What Kira remembers about player

func _ready():
	print("MemorySystem: Initialized")
	load_game()

func save_game():
	var data = {
		"endings_seen": endings_seen,
		"aspects_encountered": aspects_encountered,
		"memories_unlocked": memories_unlocked,
		"total_dissolutions_witnessed": total_dissolutions_witnessed,
		"total_visits": total_visits,
		"new_game_plus": new_game_plus,
		"visit_memory": visit_memory
	}
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("MemorySystem: Game saved")
	else:
		push_error("MemorySystem: Failed to save game")

func load_game():
	if not FileAccess.file_exists(save_path):
		print("MemorySystem: No save file found — starting fresh")
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("MemorySystem: Failed to open save file")
		return
	
	var text = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(text)
	if data == null:
		push_error("MemorySystem: Failed to parse save file")
		return
	
	endings_seen = data.get("endings_seen", [])
	aspects_encountered = data.get("aspects_encountered", [])
	memories_unlocked = data.get("memories_unlocked", [])
	total_dissolutions_witnessed = data.get("total_dissolutions_witnessed", 0)
	total_visits = data.get("total_visits", 0)
	new_game_plus = data.get("new_game_plus", false)
	visit_memory = data.get("visit_memory", {})
	
	print("MemorySystem: Loaded save — visits: %d, endings: %d, NG+: %s" % [total_visits, endings_seen.size(), new_game_plus])

func record_aspect(aspect: String):
	if not aspects_encountered.has(aspect):
		aspects_encountered.append(aspect)

func record_ending(ending: String):
	if not endings_seen.has(ending):
		endings_seen.append(ending)
		# Unlock NG+ after first ending
		if not new_game_plus:
			new_game_plus = true
			print("MemorySystem: New Game+ unlocked!")
	
	# Save automatically on ending
	save_game()

func record_memory(memory_id: String):
	if not memories_unlocked.has(memory_id):
		memories_unlocked.append(memory_id)

func unlock_chamber(chamber_id: String) -> bool:
	var key = "chamber_" + chamber_id
	if not visit_memory.has(key):
		visit_memory[key] = true
		print("MemorySystem: Chamber unlocked — %s" % chamber_id)
		return true
	return false

func is_chamber_unlocked(chamber_id: String) -> bool:
	# The Threshold is the entry chamber — always unlocked by design.
	if chamber_id == "threshold":
		return true
	var key = "chamber_" + chamber_id
	return visit_memory.get(key, false)

func set_visit_memory(key: String, value):
	visit_memory[key] = value

func get_visit_memory(key: String, default = null):
	return visit_memory.get(key, default)

func completion_percentage() -> float:
	var ending_score = endings_seen.size() * 20.0
	var aspect_score = aspects_encountered.size() * 3.0
	var memory_score = memories_unlocked.size() * 0.5
	return min(100.0, ending_score + aspect_score + memory_score)

func reset_for_new_game():
	endings_seen.clear()
	aspects_encountered.clear()
	memories_unlocked.clear()
	total_dissolutions_witnessed = 0
	total_visits = 0
	new_game_plus = false
	visit_memory.clear()
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string("{}")
		file.close()
	
	print("MemorySystem: Fresh start — all memory wiped")
