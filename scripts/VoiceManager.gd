extends Node

# VoiceManager - Kira's voice in the chambers.
# Plays pre-generated ElevenLabs lines (Jessica) for fragments and key beats.
# Lookup is by text hash via assets/voice/manifest.json — a line speaks
# only if a recording exists; everything else stays silent by design.

const VOICE_DIR := "res://assets/voice/"

var _player: AudioStreamPlayer
var _manifest: Dictionary = {}

func _ready():
	_player = AudioStreamPlayer.new()
	add_child(_player)
	if AudioServer.get_bus_index("Voice") == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Voice")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), -3.0)
	_player.bus = "Voice"
	_load_manifest()
	print("VoiceManager: Initialized — %d voiced lines" % _manifest.size())

func _load_manifest():
	var path := VOICE_DIR + "manifest.json"
	if not ResourceLoader.exists(path):
		push_warning("VoiceManager: no manifest — no voiced lines")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_manifest = parsed

func speak(text: String):
	if _player.playing:
		_player.stop()
	var key := text.sha256_text()
	var file: String = _manifest.get(key, "")
	if file.is_empty():
		return
	var stream: AudioStream = load(VOICE_DIR + file)
	if stream:
		_player.stream = stream
		_player.play()

func stop():
	if _player.playing:
		_player.stop()
