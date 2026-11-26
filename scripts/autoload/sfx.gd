extends Node
## Small placeholder sound effects made in code, so the game has feedback before real sounds exist.
## Each sound is a short tone that slides in pitch and fades out, and all of them play on the Effects bus,
## which means the Effects slider in Settings controls them.

const RATE := 22050
## Each sound is a start pitch, an end pitch, a length in seconds and a loudness from 0 to 1.
const SOUNDS := {
	"hit": [520.0, 300.0, 0.05, 0.25],
	"play": [380.0, 660.0, 0.09, 0.35],
	"tower_down": [180.0, 50.0, 0.45, 0.7],
	"chest": [300.0, 900.0, 0.25, 0.45],
	"evolve": [440.0, 1100.0, 0.2, 0.4],
	"card": [620.0, 820.0, 0.07, 0.3],
	"card_rare": [480.0, 1200.0, 0.16, 0.4],
	"legendary": [160.0, 1500.0, 0.7, 0.6],
}
const VOICES := 6

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for sound in SOUNDS:
		_streams[sound] = _make(SOUNDS[sound])
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		add_child(player)
		_players.append(player)


## Plays a sound on the next free voice. Several voices let quick sounds overlap instead of cutting each other off.
func play(sound: String) -> void:
	if not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.play()


func _make(shape: Array) -> AudioStreamWAV:
	var start: float = shape[0]
	var finish: float = shape[1]
	var length: float = shape[2]
	var loudness: float = shape[3]
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(start, finish, t) / RATE
		var sample := sin(phase) * loudness * (1.0 - t) * 32767.0
		data.encode_s16(i * 2, int(sample))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
