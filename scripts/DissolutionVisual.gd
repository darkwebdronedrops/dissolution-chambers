extends Node

# DissolutionVisual - Drives the shader during dissolution sequence
# Attach to the DissolutionEffect node in Main.tscn

@export var dissolve_overlay: ColorRect

var _material: ShaderMaterial
var _tween: Tween

func _ready():
	# If not assigned via editor, try to find parent ColorRect
	if not dissolve_overlay:
		var parent = get_parent()
		if parent is ColorRect:
			dissolve_overlay = parent
		else:
			# Try to find ColorRect in parent or owner
			var owner_node = get_parent()
			while owner_node:
				if owner_node is ColorRect:
					dissolve_overlay = owner_node
					break
				owner_node = owner_node.get_parent()

	if dissolve_overlay:
		_material = dissolve_overlay.material as ShaderMaterial
	else:
		push_warning("DissolutionVisual: No dissolve_overlay assigned")
	
	# Connect to dissolution signals
	DissolutionManager.pre_tremor.connect(_on_pre_tremor)
	DissolutionManager.breaking.connect(_on_breaking)
	DissolutionManager.void_state.connect(_on_void)
	DissolutionManager.reforming.connect(_on_reforming)
	DissolutionManager.sequence_started.connect(_on_sequence_started)
	DissolutionManager.sequence_completed.connect(_on_sequence_completed)
	print("DissolutionVisual: Ready")

func _on_sequence_started():
	if dissolve_overlay:
		dissolve_overlay.visible = true
	if _material:
		_material.set_shader_parameter("progress", 0.0)
	print("DissolutionVisual: Sequence started")

func _on_pre_tremor():
	# Pre-tremor: progress from 0.0 to 0.1 (subtle, Kira notices)
	if _material:
		_tween = create_tween()
		_tween.tween_method(_set_progress, 0.0, 0.1, 2.0)

func _on_breaking():
	# Breaking: progress from 0.1 to 0.5 (particles explode)
	if _material:
		_tween = create_tween()
		_tween.tween_method(_set_progress, 0.1, 0.5, 1.0)

func _on_void():
	# Void: progress from 0.5 to 0.8 (particles drift, deep purple)
	if _material:
		_tween = create_tween()
		_tween.tween_method(_set_progress, 0.5, 0.8, 2.5)

func _on_reforming():
	# Reforming: progress from 0.8 to 1.0 (particles coalesce, fade)
	if _material:
		_tween = create_tween()
		_tween.tween_method(_set_progress, 0.8, 1.0, 2.0)

func _on_sequence_completed(_new_aspect: String):
	if dissolve_overlay:
		dissolve_overlay.visible = false
	if _material:
		_material.set_shader_parameter("progress", 0.0)
	print("DissolutionVisual: Sequence complete, overlay hidden")

func _set_progress(val: float):
	if _material:
		_material.set_shader_parameter("progress", val)
