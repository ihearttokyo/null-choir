extends Node

var streams: Dictionary = {
	"tool": preload("res://audio/effects/tool.wav"),
	"rivet": preload("res://audio/effects/rivet.wav"),
	"scatter": preload("res://audio/effects/scatter.wav"),
	"dry": preload("res://audio/effects/dry.wav"),
	"flesh": preload("res://audio/effects/flesh.wav"),
	"impact": preload("res://audio/effects/impact.wav"),
	"crawler_charge": preload("res://audio/effects/crawler_charge.wav"),
	"worker_charge": preload("res://audio/effects/worker_charge.wav"),
	"caster_charge": preload("res://audio/effects/caster_charge.wav"),
	"stagger": preload("res://audio/effects/stagger.wav"),
	"death": preload("res://audio/effects/death.wav"),
	"seal_release": preload("res://audio/effects/seal_release.wav")
}
var players: Dictionary = {}
var paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Effects") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count()-1,"Effects")
	for cue in streams:
		var player = AudioStreamPlayer.new()
		player.bus = &"Effects"
		player.stream = streams[cue]
		player.max_polyphony = 2
		add_child(player)
		players[cue] = player

func play(cue: String, gain_db: float = -6.0) -> bool:
	if paused or not players.has(cue) or not is_finite(gain_db): return false
	var bus = AudioServer.get_bus_index("Effects")
	if AudioServer.is_bus_mute(bus) or db_to_linear(AudioServer.get_bus_volume_db(bus)) <= 0.0: return false
	players[cue].volume_db = clampf(gain_db,-60.0,0.0)
	players[cue].play()
	return true

func set_paused(value: bool) -> void:
	paused = value
	for player in players.values(): player.stream_paused = value

func stop() -> void:
	for player in players.values(): player.stop()
