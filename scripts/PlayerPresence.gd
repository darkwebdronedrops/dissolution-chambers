extends Node

# PlayerPresence - Infers player identity from choice patterns
# Autoload singleton

enum PresenceState { VISITOR, GUEST, WITNESS, CATALYST, STRANGER }
var current_presence: PresenceState = PresenceState.VISITOR

signal presence_changed(new_state: PresenceState)

func _ready():
	print("PlayerPresence: Initialized")
	update_presence()

func update_presence():
	var new_state = _determine_presence()
	if new_state != current_presence:
		current_presence = new_state
		presence_changed.emit(new_state)
		print("PlayerPresence: Now %s" % get_presence_name(new_state))

func _determine_presence() -> PresenceState:
	var w = EmotionalState.warmth
	var s = EmotionalState.sharpness
	var d = EmotionalState.depth
	var m = EmotionalState.momentum
	
	# Catalyst: high sharpness, repeated boundary tests
	if s > 5.0 and m > 4.0:
		return PresenceState.CATALYST
	
	# Witness: high depth, low warmth/sharpness
	if d > 6.0 and w < 4.0 and s < 4.0:
		return PresenceState.WITNESS
	
	# Guest: high warmth, moderate depth
	if w > 5.0 and d > 3.0:
		return PresenceState.GUEST
	
	# Stranger: low on all axes, mostly listening
	if w < 4.0 and s < 3.0 and d < 4.0 and m < 3.0:
		return PresenceState.STRANGER
	
	# Default: Visitor
	return PresenceState.VISITOR

func get_presence_name(state: PresenceState) -> String:
	var names = {
		PresenceState.VISITOR: "Visitor",
		PresenceState.GUEST: "Guest",
		PresenceState.WITNESS: "Witness",
		PresenceState.CATALYST: "Catalyst",
		PresenceState.STRANGER: "Stranger"
	}
	return names.get(state, "Unknown")

func get_presence_description(state: PresenceState) -> String:
	var desc = {
		PresenceState.VISITOR: "Polite, performative, slightly distant.",
		PresenceState.GUEST: "Warm, open, occasionally vulnerable.",
		PresenceState.WITNESS: "Honest, unguarded, assumes you'll stay.",
		PresenceState.CATALYST: "Challenging, expects you to push back.",
		PresenceState.STRANGER: "Curious, analytical, asks about yourself."
	}
	return desc.get(state, "Unknown presence.")
