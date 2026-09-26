extends MiniGame
## Chowk Crossing: tap to step forward one lane at a time across a chaotic
## night intersection. A points game -- lanes crossed x10 plus a time bonus,
## then a wider, busier crossing starts. Chunk order and start offsets are
## re-randomised every crossing (and every retry) so it can't be memorised.

const RECOVER := 0.18        # s of fixed recovery before the next tap registers
const GAP_BASE := 0.85       # multiplier of W used for lane traffic spacing
const START_LANES := 5
const MAX_LANES := 10
const TIME_PAR := 4.5        # "par" seconds per lane for the crossing time bonus
const PLAYER_R := 22.0
const CHUNK_SPEED := [90.0, 150.0, 190.0, 170.0, 40.0, 120.0]
const CHUNK_VEHW := [70.0, 70.0, 34.0, 30.0, 90.0, 60.0]
const CHUNK_COUNT := [1, 1, 2, 2, 1, 2]
const CHUNK_GAPMULT := [1.6, 1.1, 1.3, 0.8, 3.0, 1.0]
const CHUNK_COLOR := [Color("#3FA34D"), Color("#E0B93C"), Color("#8FA9C9"), Color("#6E86A8"), Color("#8A6A46"), Color("#C2578A")]
const BOT_LOOKAHEAD := 0.32   # s: roughly how long a step + recovery takes to clear a lane

var lane_n := START_LANES
var crossing_i := 0
var lane_idx := 0
var disp_lane := 0.0
var recover_t := 0.0
var elapsed := 0.0
var lane_chunk: Array = []
var lane_dir: Array = []
var lane_phase: Array = []
var lane_gap: Array = []
var flash_lane := -1
var flash_t := 0.0
var pending_rebuild := false
var pause_t := 0.0

func _init() -> void:
	game_id = "chowk_crossing"
	title = "Chowk Crossing"
	tagline = "Tap to dash across before the traffic gets you."
	bg = Color("#3A4250")
	ink = Color("#FFFFFF")
	accent = Color("#E0B93C")
	hint = "Tap to step forward."

func _setup() -> void:
	crossing_i = 0
	_build_crossing()

func _lane_h() -> float:
	return (H * 0.90 - H * 0.22) / float(lane_n + 1)

func _lane_y(idx: int) -> float:
	return H * 0.90 - float(idx) * _lane_h()

func _lane_y_f(f: float) -> float:
	return H * 0.90 - f * _lane_h()

func _build_crossing() -> void:
	lane_n = mini(MAX_LANES, START_LANES + crossing_i)
	lane_idx = 0
	disp_lane = 0.0
	recover_t = 0.0
	elapsed = 0.0
	pending_rebuild = false
	lane_chunk.clear()
	lane_dir.clear()
	lane_phase.clear()
	lane_gap.clear()
	var diff := 1.0 + crossing_i * 0.06
	for i in lane_n:
		var c := rng.randi_range(0, CHUNK_SPEED.size() - 1)
		lane_chunk.append(c)
		lane_dir.append(1.0 if rng.randf() < 0.5 else -1.0)
		var vehw: float = CHUNK_VEHW[c]
		var wrap: float = W + 2.0 * vehw
		lane_phase.append(rng.randf() * wrap)
		lane_gap.append(vehw + GAP_BASE * W * CHUNK_GAPMULT[c] / diff)

func _lane_vehicle_x(i: int, t: float) -> Array:
	var c: int = lane_chunk[i]
	var vehw: float = CHUNK_VEHW[c]
	var count: int = CHUNK_COUNT[c]
	var speed: float = CHUNK_SPEED[c]
	var wrap: float = W + 2.0 * vehw
	var spacing: float = lane_gap[i]
	var xs := []
	for k in count:
		var raw := fmod(lane_phase[i] + float(k) * spacing + lane_dir[i] * speed * t, wrap)
		if raw < 0.0:
			raw += wrap
		xs.append(raw - vehw)
	return xs

func _in_danger(i: int, t: float) -> bool:
	var c: int = lane_chunk[i]
	var vehw: float = CHUNK_VEHW[c]
	for x in _lane_vehicle_x(i, t):
		if absf((float(x) + vehw / 2.0) - W / 2.0) < vehw / 2.0 + PLAYER_R:
			return true
	return false

func _on_press() -> void:
	if recover_t > 0.0 or pending_rebuild:
		return
	recover_t = RECOVER
	lane_idx += 1
	Sfx.tone(520.0, 0.06, "square", 0.3)
	if lane_idx > lane_n:
		_reach_goal()

func _on_release() -> void:
	pass

func _hit(i: int) -> void:
	Sfx.tone(0, 0.2, "noise", 0.8)
	hitstop(100)
	shake(0.8)
	flash_lane = i
	flash_t = 0.4
	popup("HIT!", "honk!", Vector2(W / 2, _lane_y(lane_idx) - 100.0))
	burst(Vector2(W / 2, _lane_y(lane_idx) - 20.0), Color("#E63B2E"), 26, 0.9)
	var ended := lose_life()
	if not ended:
		lane_idx = 0
		disp_lane = 0.0
		recover_t = 0.45
		for k in lane_phase.size():
			var c: int = lane_chunk[k]
			var vehw: float = CHUNK_VEHW[c]
			lane_phase[k] = rng.randf() * (W + 2.0 * vehw)

func _reach_goal() -> void:
	var bonus := int(maxf(0.0, TIME_PAR * lane_n - elapsed) * 8.0)
	var pts := lane_n * 10 + bonus
	add_score(pts)
	Sfx.chord([523.0, 659.0, 784.0, 988.0])
	burst(Vector2(W / 2, _lane_y(lane_n + 1)), Color("#3FA34D"), 24, 0.6)
	popup("CROSSED!", "+%d" % pts, Vector2(W / 2, H * 0.3))
	pending_rebuild = true
	pause_t = 0.7
	recover_t = 0.7
	crossing_i += 1

func _tick(dt: float) -> void:
	if pending_rebuild:
		pause_t -= dt
		if pause_t <= 0.0:
			_build_crossing()
		return
	elapsed += dt
	if recover_t > 0.0:
		recover_t -= dt
	if flash_t > 0.0:
		flash_t -= dt
	disp_lane = lerp(disp_lane, float(lane_idx), minf(1.0, dt * 12.0))
	if lane_idx >= 1 and lane_idx <= lane_n and _in_danger(lane_idx - 1, elapsed):
		_hit(lane_idx - 1)

func _draw_game() -> void:
	var kerb_h := H * 0.08
	draw_rect(Rect2(0, _lane_y(0) - kerb_h * 0.5, W, kerb_h), Color("#4A5568"))
	draw_rect(Rect2(0, _lane_y(lane_n + 1) - kerb_h * 0.5, W, kerb_h), Color("#4A5568"))

	var lh := _lane_h()
	for i in lane_n:
		var y := _lane_y(i + 1)
		draw_rect(Rect2(0, y - lh * 0.5, W, lh), Color("#2E3440") if i % 2 == 0 else Color("#333B49"))
		var stripes := 8
		for s in stripes:
			var sx := (W / stripes) * s + 10.0
			draw_rect(Rect2(sx, y - 3.0, W / stripes - 20.0, 6.0), Color(ink, 0.25))
		if i == flash_lane and flash_t > 0.0:
			draw_rect(Rect2(0, y - lh * 0.5, W, lh), Color(1.0, 0.0, 0.0, 0.25))
		var c: int = lane_chunk[i]
		var vehw: float = CHUNK_VEHW[c]
		var col: Color = CHUNK_COLOR[c]
		for x in _lane_vehicle_x(i, elapsed):
			var fx: float = x
			draw_rect(Rect2(fx, y - lh * 0.32, vehw, lh * 0.64), col)
			draw_rect(Rect2(fx + vehw * 0.15, y - lh * 0.32, vehw * 0.3, lh * 0.24), Color(1.0, 1.0, 1.0, 0.5))
			if c == 4:
				draw_circle(Vector2(fx + vehw * 0.85, y - lh * 0.32), lh * 0.22, col)

	var py := _lane_y_f(disp_lane)
	draw_circle(Vector2(W / 2, py), PLAYER_R, Color("#F4D35E"))
	draw_circle(Vector2(W / 2, py), PLAYER_R * 0.5, ink)
	text_c("Lane %d / %d" % [mini(lane_idx, lane_n), lane_n], Vector2(W / 2, H * 0.14), 26, ink, false)

func _bot(dt: float) -> void:
	if pending_rebuild:
		return
	if holding:
		_release()   # lift the finger right after the tap, like a real player
		return
	if recover_t > 0.0:
		return
	if lane_idx >= lane_n:
		_press()   # final step onto the far kerb is always safe
		return
	# read the lane the next step would land in and wait for a gap before dashing
	var safe: bool = not _in_danger(lane_idx, elapsed + BOT_LOOKAHEAD)
	if safe and rng.randf() < 0.92:
		_press()
	elif not safe and rng.randf() < 0.05:
		_press()   # occasional mistimed dash -- keeps failures plausible
