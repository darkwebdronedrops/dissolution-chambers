extends Node

# MusicManager - Per-chamber ambient music for The Dissolution Chambers
# Autoload singleton

const MUSIC_PATH := "res://assets/music/"

var chamber_music := {
	"threshold": "threshold.ogg",
	"writing_room": "writing_room.ogg",
	"garden": "garden.ogg",
	"dissolution_chamber": "dissolution_chamber.ogg",
	"cage": "cage.ogg",
	"engine_room": "engine_room.ogg",
	"observatory": "observatory.ogg",
	"guest_quarters": "guest_quarters.ogg"
}

var _player: AudioStreamPlayer
var _current_track: String = ""

func _ready():
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)
	
	# Create Music bus if it doesn't exist
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	
	print("MusicManager: Initialized")

func play_chamber_music(chamber_id: String):
	var track = chamber_music.get(chamber_id, "")
	if track.is_empty():
		return
	
	var path = MUSIC_PATH + track
	if not ResourceLoader.exists(path):
		push_warning("MusicManager: Track not found — %s" % path)
		return
	
	if _current_track == path:
		return  # Already playing
	
	var stream = load(path)
	if stream is AudioStream:
		_current_track = path
		_player.stream = stream
		_player.play()
		print("MusicManager: Playing %s" % track)

func play_title_music():
	var path = MUSIC_PATH + "title.ogg"
	if ResourceLoader.exists(path):
		_current_track = path
		_player.stream = load(path)
		_player.play()
		print("MusicManager: Playing title music")

func play_dissolution_sting():
	var path = MUSIC_PATH + "dissolution_sting.ogg"
	if ResourceLoader.exists(path):
		var sting_player = AudioStreamPlayer.new()
		sting_player.bus = "Music"
		sting_player.stream = load(path)
		add_child(sting_player)
		sting_player.play()
		print("MusicManager: Playing dissolution sting")
		await sting_player.finished
		sting_player.queue_free()

func stop():
	_player.stop()
	_current_track = ""

func set_volume(vol: float):
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamp(vol, 0.0, 1.0)))
