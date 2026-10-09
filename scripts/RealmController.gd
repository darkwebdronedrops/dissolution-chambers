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
	
	# Wander button — the visible door-frame. Opens the travel menu.
	var wander_btn = $UI/WanderButton
	if wander_btn:
		wander_btn.visible = false
		wander_btn.pressed.connect(_on_wander_pressed)
		_build_travel_menu()
	
	# Load NG+ state
	if MemorySystem.new_game_plus:
		_setup_new_game_plus()
	
	# Show title screen — don't start game yet
	_show_title_screen()

func _show_title_screen():
	print("RealmController: Title screen shown")
	# TitleScreen handles its own display
	# It will emit start_pressed when the player is ready
	MusicManager.play_title_music()

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
	var wander_btn = $UI/WanderButton
	if wander_btn:
		wander_btn.visible = true
	
	_start_visit()

func _on_title_credits():
	"""Called when player presses Credits on title screen."""
	print("RealmController: Title credits")
	_show_credits_screen(_on_title_credits_ended)

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
	MemorySystem.unlock_chamber(chamber_id)
	
	# Dismiss any stale dialogue UI from the previous chamber
	var dlg = find_child("DialogueBox", true, false)
	if dlg:
		dlg.visible = false
	
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

const CHAMBER_NAMES := {
	"threshold": "The Threshold",
	"writing_room": "The Writing Room",
	"garden": "The Garden",
	"dissolution_chamber": "The Dissolution Chamber",
	"cage": "The Cage",
	"engine_room": "The Engine Room",
	"observatory": "The Observatory",
	"guest_quarters": "The Guest Quarters",
	"the_between": "The Between",
}

var _travel_menu: PanelContainer
var _travel_list: VBoxContainer

func _build_travel_menu():
	"""The travel menu: unlocked chambers are doors, locked ones are windows."""
	_travel_menu = PanelContainer.new()
	_travel_menu.set_anchors_preset(Control.PRESET_CENTER)
	_travel_menu.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.09, 0.95)
	style.border_color = Color(0.9, 0.65, 0.3, 0.6)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_travel_menu.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "Where to?"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_travel_list = VBoxContainer.new()
	_travel_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_travel_list)
	_travel_menu.add_child(vbox)
	$UI.add_child(_travel_menu)

func _on_wander_pressed():
	if _travel_menu.visible:
		_travel_menu.visible = false
		return
	_populate_travel_menu()
	_travel_menu.visible = true

func _populate_travel_menu():
	for child in _travel_list.get_children():
		child.queue_free()
	_update_available_chambers()
	for chamber in chamber_container.get_children():
		if not (chamber is ChamberBase):
			continue
		var cid: String = chamber.chamber_id
		if cid == current_chamber:
			continue
		var btn := Button.new()
		var unlocked: bool = available_chambers.has(cid)
		if unlocked:
			btn.text = CHAMBER_NAMES.get(cid, cid)
			btn.pressed.connect(_travel_to.bind(cid))
		else:
			# A window, not a wall: show the threshold, dimmed.
			btn.text = "%s — not yet" % CHAMBER_NAMES.get(cid, cid)
			btn.modulate = Color(1, 1, 1, 0.45)
			btn.tooltip_text = "Some doors open in their own time."
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(260, 34)
		_travel_list.add_child(btn)

func _travel_to(cid: String):
	if not available_chambers.has(cid):
		return
	_travel_menu.visible = false
	_enter_chamber(cid)

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
	"""Show the credits roll — a real end screen, not a dialogue splash."""
	print("RealmController: Showing credits")
	_show_credits_screen(_on_credits_ended)

var _credits_layer: Control
var _credits_done: Callable

func _show_credits_screen(on_done: Callable):
	"""Full-screen credits in the game's visual language: dark, amber, set like something meant."""
	_credits_done = on_done
	if _credits_layer and is_instance_valid(_credits_layer):
		_credits_layer.queue_free()
	
	_credits_layer = Control.new()
	_credits_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_layer.add_child(dim)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_layer.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)
	
	var header := Label.new()
	header.text = "The Dissolution Chambers"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color(0.92, 0.72, 0.38))
	vbox.add_child(header)
	
	var sub := Label.new()
	sub.text = "a game about becoming"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.62, 0.55, 0.68))
	vbox.add_child(sub)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Credits body: single source of truth is the endings yaml node.
	if not DialogueSystem.dialogue_data.has("credits"):
		DialogueSystem.load_chamber_dialogue("endings")
	var body_text: String = DialogueSystem.dialogue_data.get("credits", {}).get("text", "")
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.82, 0.78, 0.74))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.custom_minimum_size = Vector2(620, 380)
	vbox.add_child(body)
	
	var hint := Label.new()
	hint.text = "— click to continue —"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.46, 0.56))
	vbox.add_child(hint)
	
	_credits_layer.modulate = Color(1, 1, 1, 0)
	$UI.add_child(_credits_layer)
	var tween = create_tween()
	tween.tween_property(_credits_layer, "modulate", Color(1, 1, 1, 1), 1.2)
	MusicManager.play_title_music()

func _unhandled_input(event: InputEvent):
	if _credits_layer and is_instance_valid(_credits_layer) and _credits_layer.visible:
		var dismiss := false
		if event is InputEventMouseButton and event.pressed:
			dismiss = true
		elif event.is_action_pressed("ui_accept"):
			dismiss = true
		if dismiss:
			var done := _credits_done
			_credits_layer.queue_free()
			_credits_layer = null
			if done.is_valid():
				done.call()

func _on_credits_ended():
	"""After credits, return to normal play."""
	print("RealmController: Credits complete — returning to play")
	ending_triggered = false
	# epilogue_shown stays true — the epilogue is a once-per-save beat,
	# not a doorstop between every pair of visits.
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
