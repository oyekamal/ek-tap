extends MiniGame
## Wire Walker: tap to flip which way your balance pole is leaning.
## Wind gusts push you off balance; the pole opposes it -- but flipping
## when the pole is already opposing the wind throws you the OTHER way.
## Score = metres walked before you fall. No lives: one fall ends the run.

const LEAN_CAP := 1.0             # |lean| >= this = fall (the point of no return)
const POLE_ACCEL := 0.62          # lean/s the pole pushes, in pole_dir
const GUST_MIN := 0.30            # wind push magnitude range
const GUST_MAX := 0.48
const GUST_INTERVAL_START := 3.6  # seconds between gusts at the start of a walk
const GUST_INTERVAL_MIN := 1.7    # seconds between gusts once ramped up
const GUST_RAMP_METRES := 90.0    # metres walked to reach the fastest gust rate
const WALK_SPEED := 2.4           # metres/second while alive
const NO_FAIL_TIME := 10.0        # seconds of practice where a fall can't happen
const PRACTICE_RAMP_TIME := 4.0   # seconds after practice ends before fail-tolerance is at full tightness
const MAX_TILT := 0.5             # radians the walker tilts at full lean
const WIRE_Y_F := 0.46            # wire height, fraction of H

const WIRE_COL := Color("#B7C2E8")
const WINDOW_LIT := Color("#FFD873")
const WINDOW_DARK := Color("#324372")
const BUILDING := Color("#1B2547")
const GAUGE_BG := Color("#182242")
const GAUGE_FILL := Color("#5C72C7")
const DANGER := Color("#FF4D4D")
const GOLD := Color("#FFD34D")
const CORAL := Color("#FF6F59")

var lean := 0.0
var wind := 0.0
var pole_dir := -1
var gust_t := 1.1
var gust_interval := GUST_INTERVAL_START
var _pulse_t := 0.0
var _bot_cd := 0.0

func _init() -> void:
	game_id = "wire_walker"
	title = "Wire Walker"
	tagline = "Flip the pole only when the wind's really against you."
	bg = Color("#22305C")
	ink = Color("#F2F4FF")
	accent = CORAL
	hint = "Tap to flip your pole's lean."
	use_lives = false
	score_fmt = "%d m"

func _setup() -> void:
	lean = 0.0
	wind = 0.0
	pole_dir = -1
	gust_t = 1.1
	gust_interval = GUST_INTERVAL_START
	_pulse_t = 0.0
	_bot_cd = 0.0

func _unit() -> float:
	return W / 720.0

func _tap_helps() -> bool:
	return wind != 0.0 and (wind > 0.0) == (pole_dir > 0)

func _on_press() -> void:
	pole_dir = -pole_dir
	Sfx.tone(460.0 if pole_dir > 0 else 300.0, 0.07, "tri", 0.28)

func _on_release() -> void:
	pass

func _tick(dt: float) -> void:
	if not started:
		return
	_pulse_t += dt
	gust_t -= dt
	if gust_t <= 0.0:
		wind = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(GUST_MIN, GUST_MAX)
		var k: float = clampf(score / GUST_RAMP_METRES, 0.0, 1.0)
		gust_interval = lerpf(GUST_INTERVAL_START, GUST_INTERVAL_MIN, k)
		gust_t = gust_interval * rng.randf_range(0.85, 1.2)
	lean += (wind + pole_dir * POLE_ACCEL) * dt
	var practicing: bool = time < NO_FAIL_TIME
	# taper practice->live instead of an instant cliff: right when practice ends the
	# clamp is still loose and the fail threshold still forgiving, both tightening over
	# PRACTICE_RAMP_TIME so a lean built up safely during practice doesn't insta-kill.
	var ramp: float = 0.0 if practicing else clampf((time - NO_FAIL_TIME) / PRACTICE_RAMP_TIME, 0.0, 1.0)
	var clamp_bound: float = LEAN_CAP * 0.85 if practicing else lerpf(LEAN_CAP * 0.9, LEAN_CAP * 1.08, ramp)
	lean = clampf(lean, -clamp_bound, clamp_bound)
	add_score(WALK_SPEED * dt)
	if not practicing:
		var fail_threshold: float = lerpf(LEAN_CAP * 1.15, LEAN_CAP, ramp)
		if absf(lean) >= fail_threshold:
			_fall()

func _fall() -> void:
	Sfx.tone(130.0, 0.35, "saw", 0.5, 40.0)
	hitstop(100)
	shake(0.9)
	var dir_txt := "gust from the right" if wind > 0.0 else "gust from the left"
	popup("FELL", "%d m -- %s" % [int(score), dir_txt], Vector2(W / 2.0, H * 0.32), DANGER)
	burst(Vector2(W / 2.0, H * WIRE_Y_F), CORAL, 22, 0.7)
	lose_life()

func _draw_game() -> void:
	var u := _unit()
	var wire_y := H * WIRE_Y_F
	# night sky: a few static stars
	for i in 22:
		var sx: float = fmod(i * 233.0, W)
		var sy: float = fmod(i * 97.0, wire_y * 0.8)
		draw_circle(Vector2(sx, sy + 20.0 * u), 2.0 * u, Color(ink, 0.5))
	# skyline + lit windows below the wire, scrolling with distance walked
	var scroll: float = fmod(score * 14.0, 90.0 * u)
	var col_w := 78.0 * u
	var cols: int = int(W / col_w) + 3
	for ci in range(-1, cols):
		var bx: float = ci * col_w - scroll
		var bh: float = 90.0 * u + fmod(float(absi(ci)) * 53.0, 160.0) * u
		draw_rect(Rect2(bx, H - bh, col_w - 10.0 * u, bh + 60.0), BUILDING)
		for wx in 3:
			for wy in range(int(bh / (26.0 * u))):
				var lit: bool = fmod(float(absi(ci) * 7 + wx * 3 + wy * 5), 3.0) < 1.4
				var wcol := WINDOW_LIT if lit else WINDOW_DARK
				draw_rect(Rect2(bx + 10.0 * u + wx * 20.0 * u, H - bh + 14.0 * u + wy * 26.0 * u, 12.0 * u, 16.0 * u), wcol)
	# darken the bottom band the hint label sits over -- lit windows behind it wash out
	# the white "Tap to flip..." text otherwise
	if not started:
		draw_rect(Rect2(0, H - 150.0 * u, W, 150.0 * u), Color(0, 0, 0, 0.38))

	# the wire
	draw_line(Vector2(0, wire_y), Vector2(W, wire_y), WIRE_COL, 4.0 * u, true)
	draw_line(Vector2(0, wire_y - 2.0 * u), Vector2(W, wire_y - 2.0 * u), Color(WIRE_COL, 0.4), 1.5 * u, true)

	var practicing: bool = time < NO_FAIL_TIME
	var helps: bool = _tap_helps()
	var tell_strength: float = 1.0 if practicing else 0.5   # readable always, subtler once live

	# lean gauge: always visible, with point-of-no-return marks at both ends
	var gx := W / 2.0
	var gy := 216.0
	var gw := W * 0.56
	draw_rect(Rect2(gx - gw / 2.0, gy - 8.0 * u, gw, 16.0 * u), GAUGE_BG)
	draw_rect(Rect2(gx - 6.0 * u, gy - 8.0 * u, 12.0 * u, 16.0 * u), Color(ink, 0.35))
	var fx: float = clampf(lean / LEAN_CAP, -1.0, 1.0) * (gw / 2.0)
	var dot_col: Color = GAUGE_FILL.lerp(GOLD, tell_strength) if helps else GAUGE_FILL
	draw_circle(Vector2(gx + fx, gy), 9.0 * u, dot_col)
	draw_rect(Rect2(gx - gw / 2.0 - 4.0 * u, gy - 12.0 * u, 6.0 * u, 24.0 * u), DANGER)
	draw_rect(Rect2(gx + gw / 2.0 - 2.0 * u, gy - 12.0 * u, 6.0 * u, 24.0 * u), DANGER)

	# walker + pole, tilted by lean
	var tilt: float = clampf(lean / LEAN_CAP, -1.0, 1.0) * MAX_TILT
	set_xform(Vector2(W / 2.0, wire_y), tilt)
	draw_rect(Rect2(-9.0 * u, -58.0 * u, 18.0 * u, 40.0 * u), CORAL)
	draw_circle(Vector2(0, -70.0 * u), 13.0 * u, CORAL)
	draw_line(Vector2(-6.0 * u, -18.0 * u), Vector2(-10.0 * u, 6.0 * u), CORAL, 6.0 * u, true)
	draw_line(Vector2(6.0 * u, -18.0 * u), Vector2(10.0 * u, 6.0 * u), CORAL, 6.0 * u, true)
	var pole_col := ink
	var pole_w := 5.0 * u
	if helps:
		var pulse: float = 0.6 + 0.4 * sin(_pulse_t * 12.0)
		pole_col = ink.lerp(GOLD, tell_strength)
		pole_w = (5.0 + 3.0 * pulse * tell_strength) * u
	var pole_ang: float = -tilt * 1.6
	var dx: float = cos(pole_ang) * 110.0 * u
	var dy: float = sin(pole_ang) * 110.0 * u
	draw_line(Vector2(-dx, -34.0 * u - dy), Vector2(dx, -34.0 * u + dy), pole_col, pole_w, true)
	set_xform()

func _bot(dt: float) -> void:
	if holding:
		_release()
		return
	_bot_cd -= dt
	if _bot_cd <= 0.0:
		var helps := _tap_helps()
		if helps and rng.randf() < 0.88:
			_press()
			_bot_cd = 0.18
		elif not helps and rng.randf() < 0.04:
			_press()   # occasional mistake -- taps when it doesn't help
			_bot_cd = 0.18
		else:
			_bot_cd = 0.05
