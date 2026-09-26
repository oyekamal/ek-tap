extends MiniGame
## Rope Race: hold to climb, let go to rest your grip. Reach the bell at 60 m.
## Solo time-attack port of rope-race/index.html (room/multiplayer code dropped).

const GOAL := 60.0                 # metres to the bell
const VIEW := 12.0                 # metres visible on screen
const BASE_SPEED := 2.2            # m/s at the start of a hold
const ACCEL := 0.9                 # speed grows by this factor per second held
const MAX_SPEED := 7.0
const DRAIN_BASE := 0.18
const DRAIN_PER_SPEED := 0.05      # grip lost per second while climbing
const REGEN := 0.5                 # grip regained per second while hanging
const KNOT_EVERY := 8.0
const KNOT_WINDOW := 0.6           # let go within this many metres of a knot = full grip
const SLIP_DROP := 5.0
const SLIP_TIME := 0.5
const STUN_TIME := 0.8
const SLIP_GRIP := 0.5

const SKY_TOP_A := Color("#8FD3FF")
const SKY_TOP_B := Color("#FFC496")
const SKY_BOT_A := Color("#8FD3FF")
const SKY_BOT_B := Color("#FFC496")
const ROPE := Color("#D9B98C")
const GO := Color("#1FB36B")
const WARN := Color("#FFB020")
const DANGER := Color("#F2464B")
const GROUND := Color("#4BAE5B")
const GROUND_EDGE := Color("#3C9449")
const KNOT_COL := Color("#9C7447")
const BELL_ROPE := Color("#6B4A2B")
const BELL_GOLD := Color("#FFC93C")
const TXT := Color("#13233F")
const CARD_COL := Color("#FFFDF6")
const MY_COLOR := Color("#F2464B")
const GHOST_COL := Color("#FFFFFF")

# ---------- my climber ----------
var h := 0.0
var v := 0.0
var grip := 1.0
var hold_t := 0.0
var slip_t := 0.0
var stun_t := 0.0
var slip_from := 0.0
var last_tick := 0.0

var state := "idle"     # idle | climb | done
var elapsed := 0.0
var hud_t := 0.0
var trace: Array = []
var trace_t := 0.0
var ghost = null         # Array of heights every 0.1s, or null
var parts: Array = []
var flashes: Array = []

func _init() -> void:
	game_id = "rope_race"
	title = "Rope Race"
	tagline = "Hold to climb. Let go before your grip runs out."
	bg = SKY_TOP_A
	ink = TXT
	accent = GO
	hint = "Hold to climb. Let go to rest your grip."
	lower_is_better = true
	score_fmt = "%.1f s"
	use_lives = false

func _unit() -> float:
	return W / 400.0

func _ppm() -> float:
	return H / VIEW

func _setup() -> void:
	h = 0.0
	v = 0.0
	grip = 1.0
	hold_t = 0.0
	slip_t = 0.0
	stun_t = 0.0
	last_tick = 0.0
	elapsed = 0.0
	hud_t = 0.0
	trace = [0.0]
	trace_t = 0.0
	parts.clear()
	flashes.clear()
	state = "idle"
	var g = Save.get_data(game_id, "ghost", [])
	ghost = g if g is Array and g.size() > 0 else null

func _on_press() -> void:
	if state == "idle":
		state = "climb"

func _on_release() -> void:
	if state != "climb":
		return
	# let go on a knot = full grip
	var nearest := roundi(h / KNOT_EVERY) * KNOT_EVERY
	if nearest > 0 and nearest < GOAL and absf(h - nearest) <= KNOT_WINDOW and slip_t <= 0.0 and stun_t <= 0.0:
		grip = 1.0
		Sfx.tone(660.0, 0.18, "sine", 0.1)
		Sfx.tone(990.0, 0.18, "sine", 0.1)
		flashes.append({"h": float(nearest), "t": 0.0})
	hold_t = 0.0
	v = 0.0

func _finish() -> void:
	state = "done"
	score = elapsed
	Sfx.chord([784.0, 988.0, 1175.0, 1568.0])
	for i in 40:
		parts.append(_confetti())
	var secs := elapsed
	var heading := "Rang the bell"
	var is_new_best := ghost == null or secs < best() or best() == 0.0
	if is_new_best:
		trace.append(GOAL)
		ghost = trace.duplicate()
		Save.set_data(game_id, "ghost", ghost)
	end_run(heading)

func _confetti() -> Dictionary:
	var a := -PI / 2.0 + (rng.randf() - 0.5) * 2.2
	var s := 200.0 + rng.randf() * 350.0
	return {
		"x": W / 2, "y": H * 0.3, "vx": cos(a) * s, "vy": sin(a) * s,
		"t": 0.0, "life": 1.2 + rng.randf() * 0.6,
		"c": Color(GO if rng.randi() % 2 == 0 else WARN),
		"w": (5.0 + rng.randf() * 6.0) * _unit(), "rot": rng.randf() * 6.0,
	}

func _tick(dt: float) -> void:
	if state == "climb":
		elapsed += dt
		if slip_t > 0.0:
			slip_t -= dt
			h = maxf(0.0, slip_from - SLIP_DROP * (1.0 - maxf(0.0, slip_t) / SLIP_TIME))
			if slip_t <= 0.0:
				stun_t = STUN_TIME
		elif stun_t > 0.0:
			stun_t -= dt
		elif holding:
			hold_t += dt
			v = minf(MAX_SPEED, BASE_SPEED * (1.0 + ACCEL * hold_t))
			h += v * dt
			grip -= (DRAIN_BASE + DRAIN_PER_SPEED * v) * dt
			if h - last_tick >= 0.6:
				last_tick = h
				Sfx.tone(180.0 + grip * 160.0, 0.05, "tri", 0.05)
			if grip <= 0.0:
				grip = SLIP_GRIP
				slip_t = SLIP_TIME
				slip_from = h
				hold_t = 0.0
				v = 0.0
				shake(0.8)
				Sfx.tone(600.0, 0.5, "saw", 0.08, 120.0)
				last_tick = h - SLIP_DROP
		else:
			grip = minf(1.0, grip + REGEN * dt)
		trace_t += dt
		while trace_t >= 0.1:
			trace_t -= 0.1
			trace.append(roundf(h * 10.0) / 10.0)
		if h >= GOAL:
			h = GOAL
			_finish()

	for p in parts:
		p.t += dt
		p.vy += 600.0 * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.rot += dt * 6.0
	parts = parts.filter(func(p): return p.t < p.life)
	for f in flashes:
		f.t += dt
	flashes = flashes.filter(func(f): return f.t < 0.6)

	if state == "climb":
		hud_t += dt
		if hud_t >= 0.1:
			hud_t = 0.0
			score = elapsed
			_hud.refresh(self)

func _sky_at(hh: float) -> Color:
	var k: float = clampf(hh / GOAL, 0.0, 1.0)
	return Color(
		lerpf(0.561, 1.0, k), lerpf(0.827, 0.769, k), lerpf(1.0, 0.588, k))

func _draw_game() -> void:
	var u := _unit()
	var ppm := _ppm()
	var cam_h: float = clampf(h, 0.0, GOAL)
	var y_of := func(hh): return H * 0.62 - (hh - cam_h) * ppm

	# sky gradient blue -> dusk
	var top_c := _sky_at(cam_h + VIEW * 0.6)
	var bot_c := _sky_at(cam_h - VIEW * 0.4)
	var steps := 24
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		draw_rect(Rect2(0, H * t0, W, H * (t1 - t0) + 1.0), top_c.lerp(bot_c, t0))

	# clouds
	for i in 9:
		var ch := i * 7.0 + 3.0
		var y: float = H * 0.62 - (ch - cam_h) * ppm * 0.6
		if y < -60.0 or y > H + 60.0:
			continue
		var x: float = fmod(i * 137.0, 100.0) / 100.0 * W
		_ellipse(Vector2(x, y), 60.0 * u, 18.0 * u, Color(1, 1, 1, 0.55))
		_ellipse(Vector2(x + 30.0 * u, y - 10.0 * u), 36.0 * u, 16.0 * u, Color(1, 1, 1, 0.55))

	var gy: float = y_of.call(0.0) + 56.0 * u
	if gy < H:
		draw_rect(Rect2(0, gy, W, H - gy), GROUND)
		draw_rect(Rect2(0, gy, W, 8.0 * u), GROUND_EDGE)

	var lanes := 2 if ghost != null else 1
	var lane_w: float = minf(110.0 * u, (W - 32.0 * u) / lanes)
	var x0: float = W / 2.0 - (lane_w * (lanes - 1)) / 2.0
	var lane := 0

	var draw_rope := func(x: float):
		var top: float = maxf(0.0, y_of.call(GOAL) - 30.0 * u)
		var bot: float = minf(H, gy)
		draw_line(Vector2(x, top), Vector2(x, bot), ROPE, 6.0 * u, true)
		var k := KNOT_EVERY
		while k < GOAL:
			var ky: float = y_of.call(k)
			if ky >= -20.0 and ky <= H + 20.0:
				_ellipse(Vector2(x, ky), 9.0 * u, 7.0 * u, KNOT_COL)
			k += KNOT_EVERY

	# bell across the top
	var by: float = y_of.call(GOAL) - 40.0 * u
	if by > -80.0:
		draw_rect(Rect2(16.0 * u, by - 6.0 * u, W - 32.0 * u, 10.0 * u), BELL_ROPE)
		var bp := PackedVector2Array()
		var steps2 := 16
		for i in steps2 + 1:
			var t := float(i) / steps2
			bp.append(Vector2(lerpf(-22.0, 22.0, t) * u, 0) + Vector2(0, by))
		# simple bell silhouette (triangle + curve approximation)
		var bell_poly := PackedVector2Array([
			Vector2(W / 2.0 - 22.0 * u, by + 34.0 * u),
			Vector2(W / 2.0 - 10.0 * u, by + 4.0 * u),
			Vector2(W / 2.0 + 10.0 * u, by + 4.0 * u),
			Vector2(W / 2.0 + 22.0 * u, by + 34.0 * u),
		])
		draw_colored_polygon(bell_poly, BELL_GOLD)
		draw_circle(Vector2(W / 2.0, by + 38.0 * u), 5.0 * u, BELL_GOLD)

	# my rope + lane
	var mx: float = x0 + lane_w * lane
	lane += 1
	draw_rope.call(mx)

	var nearest := roundi(h / KNOT_EVERY) * KNOT_EVERY
	if state == "climb" and nearest > 0 and nearest < GOAL and absf(h - nearest) <= KNOT_WINDOW:
		draw_circle(Vector2(mx, y_of.call(float(nearest))), 18.0 * u, Color(BELL_GOLD, 0.55))
	for f in flashes:
		draw_arc(Vector2(mx, y_of.call(f.h)), 14.0 * u + f.t * 60.0 * u, 0, TAU, 32, Color(BELL_GOLD, 1.0 - f.t / 0.6), 4.0 * u)

	# ghost of best solo climb
	if ghost != null:
		var gx: float = x0 + lane_w * lane
		lane += 1
		draw_rope.call(gx)
		var idx: int = mini(ghost.size() - 1, int((0.0 if state == "idle" else elapsed) * 10.0))
		var gh: float = ghost[idx]
		_climber(Vector2(gx, y_of.call(gh) + 30.0 * u), GHOST_COL, 1.0, false, u, 0.45)

	# me
	_climber(Vector2(mx, y_of.call(h) + 30.0 * u), MY_COLOR, grip, slip_t > 0.0, u, 1.0)

	# grip bar beside my climber
	var gx2: float = mx + 30.0 * u
	var gy_top: float = y_of.call(h) - 6.0 * u
	draw_rect(Rect2(gx2, gy_top, 8.0 * u, 60.0 * u), Color(TXT, 0.25))
	var grip_col := GO if grip > 0.5 else (WARN if grip > 0.2 else DANGER)
	draw_rect(Rect2(gx2, gy_top + 60.0 * u * (1.0 - grip), 8.0 * u, 60.0 * u * grip), grip_col)

	for p in parts:
		set_xform(Vector2(p.x, p.y), p.rot)
		draw_rect(Rect2(-p.w / 2.0, -p.w / 4.0, p.w, p.w / 2.0), p.c)
	set_xform()

func _climber(pos: Vector2, color: Color, g: float, slipping: bool, u: float, alpha := 1.0) -> void:
	var hand_c := GO if g > 0.5 else (WARN if g > 0.2 else DANGER)
	var wob := sin(Time.get_ticks_msec() / 30.0) * 5.0 * u if slipping else 0.0
	set_xform(pos, 0, Vector2(u, u))
	# body
	draw_rect(Rect2(-13 + wob / u, 6, 26, 34), Color(color, alpha))
	# head
	draw_circle(Vector2(wob / u, -6), 13.0, Color(color, alpha))
	draw_circle(Vector2(wob / u - 4.0, -7.0), 2.0, Color(TXT, alpha))
	draw_circle(Vector2(wob / u + 4.0, -7.0), 2.0, Color(TXT, alpha))
	# arms
	draw_line(Vector2(-10, 12), Vector2(-4, -22), Color(color, alpha), 6.0, true)
	draw_line(Vector2(10, 12), Vector2(4, -30), Color(color, alpha), 6.0, true)
	draw_circle(Vector2(-4, -22), 6.0, Color(hand_c, alpha))
	draw_circle(Vector2(4, -30), 6.0, Color(hand_c, alpha))
	# legs
	draw_line(Vector2(-6, 38), Vector2(-4, 54), Color(color, alpha), 4.0, true)
	draw_line(Vector2(6, 38), Vector2(4, 50), Color(color, alpha), 4.0, true)
	set_xform()

func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 32:
		var a := float(i) / 32.0 * TAU
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(p, col)

func _bot(dt: float) -> void:
	if state == "idle" and not holding:
		_press()
	elif state == "climb":
		# hold in bursts; sometimes greedy (ignores grip) and slips, sometimes releases at knots
		if holding:
			var nearest := roundi(h / KNOT_EVERY) * KNOT_EVERY
			var near_knot: bool = nearest > 0 and nearest < GOAL and absf(h - nearest) <= KNOT_WINDOW
			if grip < 0.15 or (near_knot and rng.randf() < 0.5) or hold_t > rng.randf_range(1.0, 2.5):
				_release()
		else:
			if slip_t <= 0.0 and stun_t <= 0.0:
				_press()
