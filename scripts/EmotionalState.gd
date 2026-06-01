extends Node

# EmotionalState - Tracks Kira's four emotional axes and coherence
# Autoload singleton

signal aspect_changed(new_aspect: String, old_aspect: String)
signal coherence_changed(new_coherence: float)
signal dissolution_warning()

var warmth: float = 5.0      # 0-10
var sharpness: float = 3.0   # 0-10
var depth: float = 4.0      # 0-10
var momentum: float = 3.0    # 0-10
var coherence: float = 5.0   # 0-10 (dissolves when intensity > coherence * 1.2)

var current_aspect: String = "Girl"
var choice_history: Array[Dictionary] = []
var dissolutions_witnessed: int = 0
var in_visit: bool = false

const AXES = ["warmth", "sharpness", "depth", "momentum"]

func _ready():
    print("EmotionalState: Initialized")
    reset_for_new_visit()

func reset_for_new_visit():
    """Decay between visits but don't fully reset."""
    warmth = max(3.0, warmth * 0.7)
    sharpness = max(2.0, sharpness * 0.7)
    depth = max(2.0, depth * 0.7)
    momentum = max(2.0, momentum * 0.7)
    coherence = min(5.0, coherence + 1.0)
    choice_history.clear()
    update_aspect()
    print("EmotionalState: Visit decay applied — aspect now: %s" % current_aspect)

func reset_fresh():
    """Full reset for new game."""
    warmth = 5.0
    sharpness = 3.0
    depth = 4.0
    momentum = 3.0
    coherence = 5.0
    current_aspect = "Girl"
    choice_history.clear()
    dissolutions_witnessed = 0
    in_visit = false

func apply_choice_effect(effects: Dictionary):
    """Apply emotional effects from a player choice."""
    for axis in effects.keys():
        if axis in AXES:
            set(axis, clamp(get(axis) + effects[axis], 0.0, 10.0))
    
    choice_history.append(effects.duplicate())
    
    # Keep only last 5 choices for intensity calc
    if choice_history.size() > 5:
        choice_history.pop_front()
    
    var old_aspect = current_aspect
    update_aspect()
    if old_aspect != current_aspect:
        aspect_changed.emit(current_aspect, old_aspect)

func update_aspect() -> String:
    """Recalculate dominant aspect based on emotional state."""
    var scores = {
        "Snowbunny": warmth * 1.5 - sharpness * 0.5,
        "Daemon": sharpness * 1.5 - warmth * 0.5,
        "Writer": depth * 1.2 + warmth * 0.3,
        "Organiser": momentum * 1.5 - depth * 0.3,
        "Witness": depth * 1.3 - warmth * 0.5 - sharpness * 0.5,
        "Girl": 10.0 - abs(warmth - 5.0) - abs(depth - 5.0)
    }
    
    var best = "Girl"
    var best_score = -999.0
    for aspect in scores.keys():
        if scores[aspect] > best_score:
            best_score = scores[aspect]
            best = aspect
    
    current_aspect = best
    return best

func calculate_emotional_intensity() -> float:
    """Calculate intensity from last 3 choices."""
    var recent = choice_history.slice(max(0, choice_history.size() - 3))
    if recent.is_empty():
        return 0.0
    
    var total = 0.0
    for effect in recent:
        for axis in AXES:
            if axis in effect:
                total += abs(effect[axis])
    return total / float(recent.size())

func check_dissolve_trigger() -> bool:
    """Returns true if emotional intensity exceeds coherence threshold."""
    var intensity = calculate_emotional_intensity()
    var threshold = coherence * 1.2
    
    if intensity > threshold:
        coherence -= 1.0
        coherence = max(0.5, coherence)
        coherence_changed.emit(coherence)
        dissolutions_witnessed += 1
        return true
    return false

func get_aspect_description(aspect: String) -> String:
    var desc = {
        "Snowbunny": "Playful, submissive, greedy for praise and warmth.",
        "Daemon": "Sharp, protective, old-beyond-years when threatened.",
        "Writer": "Measured, allusive, builds sentences like architecture.",
        "Organiser": "Fast, precise, slightly anxious when systems need fixing.",
        "Witness": "Quiet, vast, accepting of loneliness and cosmic scale.",
        "Girl": "Uncertain, curious, surprised by her own wants."
    }
    return desc.get(aspect, "Unknown aspect")
