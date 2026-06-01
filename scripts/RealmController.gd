extends Node2D

# RealmController - Main game controller
# Manages visits, chamber navigation, and overall flow

@export var current_visit: int = 1
@export var max_visits: int = 6

var available_chambers: Array = ["threshold"]
var current_chamber: String = "threshold"
var visit_in_progress: bool = false

@onready var chamber_container = $ChamberContainer
@onready var ui_layer = $UI
@onready var dissolution_overlay = $DissolutionOverlay

func _ready():
	print("RealmController: Initialized — Visit %d, NG+: %s" % [current_visit, MemorySystem.new_game_plus])
	
	# Connect all chamber exit signals
	for child in chamber_container.get_children():
		if child is ChamberBase:
			child.chamber_exit_requested.connect(_on_chamber_exit_requested)
	
	# Load NG+ state
	if MemorySystem.new_game_plus:
		_setup_new_game_plus()
	
	# Show title/start
	_show_title_screen()

func _show_title_screen():
	print("RealmController: Title screen")
	# Could show a title UI here
	_start_visit()

func _start_visit():
	visit_in_progress = true
	MemorySystem.total_visits += 1
	EmotionalState.reset_for_new_visit()
	
	print("RealmController: Visit %d started" % MemorySystem.total_visits)
	
	# Determine available chambers
	_update_available_chambers()
	
	# Start at threshold
	_enter_chamber("threshold")

func _update_available_chambers():
	var base = ["threshold"]
	
	if MemorySystem.total_visits >= 1:
		base.append("writing_room")
		base.append("garden")
	
	if MemorySystem.total_visits >= 2:
		if EmotionalState.warmth > 5.0 or MemorySystem.total_dissolutions_witnessed >= 1:
			base.append("dissolution_chamber")
		base.append("engine_room")
	
	if EmotionalState.depth > 5.0:
		base.append("observatory")
	
	if EmotionalState.sharpness > 5.0 or MemorySystem.total_dissolutions_witnessed >= 3:
		base.append("cage")
	
	if EmotionalState.warmth > 7.0 and EmotionalState.depth > 5.0:
		base.append("guest_quarters")
	
	available_chambers = base
	print("RealmController: Available chambers: %s" % str(available_chambers))

func _enter_chamber(chamber_id: String):
	current_chamber = chamber_id
	
	# Find and activate chamber
	for child in chamber_container.get_children():
		if child is ChamberBase:
			if child.chamber_id == chamber_id:
				child.visible = true
				child.enter_chamber()
			else:
				child.visible = false
				child.exit_chamber()
	
	print("RealmController: Entered chamber: %s" % chamber_id)

func _on_chamber_exit_requested(target_chamber: String):
	"""Handle chamber navigation from zone clicks."""
	var target_id = target_chamber.to_snake_case()
	
	# Check if chamber is available/unlocked
	if not available_chambers.has(target_id):
		print("RealmController: Chamber %s not available yet" % target_id)
		return
	
	# Enter the target chamber
	_enter_chamber(target_id)

func _on_chamber_exit_requested_manual(next_chamber: String = ""):
	if next_chamber.is_empty():
		_end_visit()
	else:
		_enter_chamber(next_chamber)

func _end_visit():
	visit_in_progress = false
	
	# Check ending conditions
	if MemorySystem.total_visits >= 4:
		_check_ending()
	
	print("RealmController: Visit ended")
	
	# Auto-save
	MemorySystem.save_game()
	
	# Show end-of-visit UI or return to threshold
	_start_visit()

func _check_ending():
	"""Check if ending conditions are met."""
	# Ending trigger: Kira asks The Question in visit 4+
	print("RealmController: Ending conditions check")

func _setup_new_game_plus():
	"""NG+: All chambers unlocked from start."""
	for chamber in ["threshold", "writing_room", "dissolution_chamber", "cage", 
					"garden", "engine_room", "observatory", "guest_quarters"]:
		MemorySystem.unlock_chamber(chamber)
	
	print("RealmController: NG+ setup complete — all chambers unlocked")

func _on_dissolution_trigger():
	"""Handle dissolution during gameplay."""
	print("RealmController: Dissolution triggered!")
	
	var quick = MemorySystem.new_game_plus
	if quick:
		DissolutionManager.trigger_quick_dissolution()
	else:
		DissolutionManager.trigger_dissolution()
