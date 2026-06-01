extends Node

# DissolutionManager - Controls the dissolution visual sequence
# Autoload singleton

signal sequence_started()
signal sequence_completed(new_aspect: String)
signal pre_tremor()
signal breaking()
signal void_state()
signal reforming()

@export var pre_tremor_duration: float = 2.0
@export var break_duration: float = 1.0
@export var void_duration: float = 2.5
@export var reform_duration: float = 2.0
@export var confusion_duration: float = 3.0

var is_dissolving: bool = false

func _ready():
    print("DissolutionManager: Initialized")

func trigger_dissolution(new_aspect: String = ""):
    """Start full dissolution sequence."""
    if is_dissolving:
        return
    
    is_dissolving = true
    sequence_started.emit()
    
    print("DissolutionManager: Sequence started")
    
    # Play dissolution sting
    MusicManager.play_dissolution_sting()
    
    # Phase 1: Pre-tremor
    pre_tremor.emit()
    await get_tree().create_timer(pre_tremor_duration).timeout
    
    # Phase 2: Break
    breaking.emit()
    await get_tree().create_timer(break_duration).timeout
    
    # Phase 3: Void
    void_state.emit()
    await get_tree().create_timer(void_duration).timeout
    
    # Phase 4: Reform
    reforming.emit()
    await get_tree().create_timer(reform_duration).timeout
    
    # Done
    is_dissolving = false
    
    if new_aspect.is_empty():
        new_aspect = EmotionalState.current_aspect
    
    sequence_completed.emit(new_aspect)
    print("DissolutionManager: Sequence complete — aspect: %s" % new_aspect)

func trigger_quick_dissolution(new_aspect: String = ""):
    """Shorter version for NG+ or frequent dissolutions."""
    if is_dissolving:
        return
    
    is_dissolving = true
    sequence_started.emit()
    
    breaking.emit()
    await get_tree().create_timer(0.5).timeout
    
    void_state.emit()
    await get_tree().create_timer(1.0).timeout
    
    reforming.emit()
    await get_tree().create_timer(0.5).timeout
    
    is_dissolving = false
    
    if new_aspect.is_empty():
        new_aspect = EmotionalState.current_aspect
    
    sequence_completed.emit(new_aspect)
    print("DissolutionManager: Quick dissolution complete — aspect: %s" % new_aspect)
