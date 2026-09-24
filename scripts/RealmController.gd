extends Node2D

# RealmController - Main game controller
# Manages visits, chamber navigation, and overall flow

@export var current_visit: int = 1
@export var max_visits: int = 6

var available_chambers: Array = ["threshold"]
var current_chamber: String = "threshold"
var visit_in_progress: bool = false
var ending_triggered: bool = false
var epilogue_shown: bool = false
var game_started: bool = false

@onready var chamber_container = $ChamberContainer
@onready var ui_layer = $UI
@onready var dissolution_overlay = $DissolutionOverlay
@onready var title_screen = $UI/TitleScreen

func _ready():
	print("RealmController: Initialized — Visit %d, NG+: %s" % [current_visit, MemorySystem.new_game_plus])
	
	# Connect all chamber exit signals
	for child in chamber_container.get_children():
		if child is ChamberBase:
			child.chamber_exit_requested.connect(_on_chamber_exit_requested)
	
	# Connect End Visit button
	var end_btn = $UI/EndVisitButton
	if end_btn:
		end_btn.pressed.connect(_on_end_visit_pressed)
	
	# Connect title screen signals
	if title_screen:
		title_screen.start_pressed.connect(_on_title_start)
		title_screen.credits_pressed.connect(_on_title_credits)
	
	# Hide End Visit button until game starts
	if end_btn:
		end_btn.visible = false
	
	# Load NG+ state
	if MemorySystem.new_game_plus:
		_setup_new_game_plus()
	
	# Show title screen — don't start game yet
	_show_title_screen()

func _show_title_screen():
	print("RealmController: Title screen shown")
	# TitleScreen handles its own display
	# It will emit start_pressed when the player is ready

func _on_title_start(new_game: bool):
	"""Called when player presses Enter or Begin Anew on title screen."""
	print("RealmController: Title start — new_game=%s" % new_game)
	
	if new_game:
		MemorySystem.reset_for_new_game()
		EmotionalState.reset_fresh()
	
	game_started = true
	
	# Show End Visit button
	var end_btn = $UI/EndVisitButton
	if end_btn:
		end_btn.visible = true
	
	_start_visit()

func _on_title_credits():
	"""Called when player presses Credits on title screen."""
	print("RealmController: Title credits")
	DialogueSystem.load_chamber_dialogue("endings")
	DialogueSystem.dialogue_ended.connect(_on_title_credits_ended, CONNECT_ONE_SHOT)
	DialogueSystem.start_dialogue("credits")

func _on_title_credits_ended():
	"""After title screen credits, return to title."""
	if title_screen:
		title_screen.show_credits_return()

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
	
	# The Between — hidden chamber, unlocks after deep trust
	if MemorySystem.total_dissolutions_witnessed >= 3 or base.size() >= 8 or EmotionalState.depth > 7.0:
		if not base.has("the_between"):
			base.append("the_between")
			print("RealmController: The Between has appeared...")
	
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

func _on_end_visit_pressed():
	print("RealmController: End Visit button pressed")
	_end_visit()

func _end_visit():
	visit_in_progress = false
	
	# Check ending conditions
	if MemorySystem.total_visits >= 4 and MemorySystem.endings_seen.is_empty() and not ending_triggered:
		_trigger_ending()
		return
	
	# Show epilogue on visits after an ending
	if not MemorySystem.endings_seen.is_empty() and not epilogue_shown:
		_show_epilogue()
		return
	
	print("RealmController: Visit ended")
	
	# Auto-save
	MemorySystem.save_game()
	
	# Show end-of-visit UI or return to threshold
	_start_visit()

func _trigger_ending():
	"""Trigger the ending sequence — Kira asks The Question."""
	ending_triggered = true
	print("RealmController: Ending sequence triggered on visit %d" % MemorySystem.total_visits)
	
	# Load endings dialogue
	DialogueSystem.load_chamber_dialogue("endings")
	DialogueSystem.dialogue_ended.connect(_on_ending_dialogue_ended, CONNECT_ONE_SHOT)
	DialogueSystem.start_dialogue("ending_choice")

func _on_ending_dialogue_ended():
	"""Called when ending dialogue branch completes."""
	# Determine which ending was reached based on last node
	var ending_type = _determine_ending_type(DialogueSystem.current_node)
	if not ending_type.is_empty():
		MemorySystem.record_ending(ending_type)
		print("RealmController: Ending recorded — %s" % ending_type)
	
	# Show credits after ending
	_show_credits()

func _determine_ending_type(last_node: String) -> String:
	"""Map final dialogue node to ending type."""
	if last_node.begins_with("integration_") or last_node == "ending_integration_start":
		return "integration"
	elif last_node.begins_with("cycle_") or last_node == "ending_cycle_start":
		return "cycle"
	elif last_node.begins_with("leave_") or last_node == "ending_leave_start":
		return "leave"
	return ""

func _show_epilogue():
	"""Show epilogue for the ending that was achieved."""
	epilogue_shown = true
	var ending = MemorySystem.endings_seen[0] if not MemorySystem.endings_seen.is_empty() else ""
	var epilogue_node = ""
	
	match ending:
		"integration":
			epilogue_node = "epilogue_integration"
		"cycle":
			epilogue_node = "epilogue_cycle"
		"leave":
			epilogue_node = "epilogue_leave"
	
	if not epilogue_node.is_empty():
		print("RealmController: Showing epilogue — %s" % epilogue_node)
		DialogueSystem.load_chamber_dialogue("endings")
		DialogueSystem.dialogue_ended.connect(_on_epilogue_ended, CONNECT_ONE_SHOT)
		DialogueSystem.start_dialogue(epilogue_node)
	else:
		# No epilogue, just continue
		_start_visit()

func _on_epilogue_ended():
	"""After epilogue, show credits then continue."""
	_show_credits()

func _show_credits():
	"""Show the credits roll."""
	print("RealmController: Showing credits")
	DialogueSystem.load_chamber_dialogue("endings")
	DialogueSystem.dialogue_ended.connect(_on_credits_ended, CONNECT_ONE_SHOT)
	DialogueSystem.start_dialogue("credits")

func _on_credits_ended():
	"""After credits, return to normal play."""
	print("RealmController: Credits complete — returning to play")
	ending_triggered = false
	epilogue_shown = false
	_start_visit()

func _setup_new_game_plus():
	"""NG+: All chambers unlocked from start."""
	for chamber in ["threshold", "writing_room", "dissolution_chamber", "cage", 
					"garden", "engine_room", "observatory", "guest_quarters", "the_between"]:
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
