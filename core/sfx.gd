extends Node
## Tiny synth: tones and noise bursts rendered to AudioStreamWAV once, then cached.

const RATE := 22050
var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _loop: AudioStreamPlayer

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_loop = AudioStreamPlayer.new()
	add_child(_loop)

## wave: "sine", "square", "tri", "saw", "noise". slide_to: end frequency (0 = none).
func tone(freq: float, dur := 0.15, wave := "sine", vol := 0.5, slide_to := 0.0) -> void:
	var key := "%s|%d|%d|%s|%d" % [wave, int(freq), int(dur * 1000), vol, int(slide_to)]
	if not _cache.has(key):
		_cache[key] = _render(freq, dur, wave, vol, slide_to, false)
	_play(_cache[key])

func chord(freqs: Array, gap := 0.06, dur := 0.25) -> void:
	for i in freqs.size():
		get_tree().create_timer(gap * i).timeout.connect(tone.bind(freqs[i], dur, "sine", 0.4))

## A looping sound (pour, squeak); pitch_scale is changed while it plays.
func loop_start(wave := "noise", freq := 400.0, vol := 0.25) -> void:
	var key := "loop|%s|%d" % [wave, int(freq)]
	if not _cache.has(key):
		_cache[key] = _render(freq, 1.0, wave, vol, 0.0, true)
	_loop.stream = _cache[key]
	_loop.pitch_scale = 1.0
	_loop.play()

func loop_pitch(p: float) -> void:
	_loop.pitch_scale = clampf(p, 0.1, 4.0)

func loop_stop() -> void:
	_loop.stop()

func _play(s: AudioStreamWAV) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.play()

func _render(freq: float, dur: float, wave: String, vol: float, slide_to: float, looping: bool) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := freq if slide_to <= 0.0 else freq * pow(slide_to / freq, t)
		phase += f / RATE
		var x := fmod(phase, 1.0)
		var s := 0.0
		match wave:
			"sine": s = sin(TAU * x)
			"square": s = 1.0 if x < 0.5 else -1.0
			"tri": s = 4.0 * absf(x - 0.5) - 1.0
			"saw": s = 2.0 * x - 1.0
			_: s = randf() * 2.0 - 1.0
		var env := 1.0 if looping else pow(1.0 - t, 2.0) * minf(1.0, t * 200.0)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if looping:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	return w
