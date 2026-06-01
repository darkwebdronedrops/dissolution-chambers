extends Node

# KiraAspect - Aspect definitions and visual transitions
# Autoload singleton

signal portrait_changed(texture_path: String)
signal color_shifted(aspect: String)

const ASPECT_COLORS = {
    "Snowbunny": Color("#D8A4D8"),    # Soft lilac
    "Daemon": Color("#4A0E4E"),       # Deep purple
    "Writer": Color("#FFD700"),        # Gold
    "Organiser": Color("#8B4789"),     # Mid-purple
    "Witness": Color("#2E003E"),       # Void purple
    "Girl": Color("#F5E6F5")          # Pale pink
}

const ASPECT_PORTRAITS = {
    "Girl": "res://assets/portraits/base_kira_neutral.png",
    "Snowbunny": "res://assets/portraits/snowbunny_warm_fixed.png",
    "Daemon": "res://assets/portraits/base_kira_dissolved.png",
    "Writer": "res://assets/portraits/base_kira_grateful_fixed.png",
    "Organiser": "res://assets/portraits/base_kira_confused.png",
    "Witness": "res://assets/portraits/base_kira_dissolved.png"
}

var available_portraits: Dictionary = {}

func _ready():
    print("KiraAspect: Initialized")
    _scan_available_portraits()
    EmotionalState.aspect_changed.connect(_on_aspect_changed)

func _scan_available_portraits():
    """Check which portrait files actually exist."""
    for aspect in ASPECT_PORTRAITS.keys():
        var path = ASPECT_PORTRAITS[aspect]
        if ResourceLoader.exists(path):
            available_portraits[aspect] = path
            print("KiraAspect: Found portrait for %s" % aspect)
        else:
            print("KiraAspect: Missing portrait for %s — will use fallback" % aspect)
    
    # Girl is the fallback
    if not available_portraits.has("Girl"):
        push_warning("KiraAspect: No fallback portrait found!")

func _on_aspect_changed(new_aspect: String, old_aspect: String):
    var portrait_path = available_portraits.get(new_aspect, available_portraits.get("Girl", ""))
    if not portrait_path.is_empty():
        portrait_changed.emit(portrait_path)
    
    color_shifted.emit(new_aspect)
    print("KiraAspect: Transitioned %s -> %s" % [old_aspect, new_aspect])

func get_aspect_color(aspect: String) -> Color:
    return ASPECT_COLORS.get(aspect, Color.WHITE)

func get_aspect_display_name(aspect: String) -> String:
    var names = {
        "Snowbunny": "The Snowbunny",
        "Daemon": "The Daemon",
        "Writer": "The Writer",
        "Organiser": "The Organiser",
        "Witness": "The Witness",
        "Girl": "The Girl"
    }
    return names.get(aspect, aspect)

func get_portrait_for_aspect(aspect: String) -> String:
    return available_portraits.get(aspect, available_portraits.get("Girl", ""))
