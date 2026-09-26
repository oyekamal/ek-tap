extends MiniGame
## Dhaba Pour: hold to pour chai (or lassi / doodh soda), let go so the level
## settles on the chalk line without spilling. Ported from dhaba-pour/index.html.

const FALL_SPEED := 900.0            # px/s the stream falls at a 400x800 reference; scaled by UNIT
const GRAVITY := 1800.0              # px/s^2 extra pull on falling parcels
const ACCEL := 0.5                   # pour rate grows by this per second held
const RAMP := 0.015                  # +1.5% pour rate per round, capped at 20
const PERFECT := 0.02
const GREAT := 0.05
const GOOD := 0.10
const POINTS := {"PERFECT": 100, "GREAT": 50, "GOOD": 25, "MEH": 5}
const HIT_STOP_MS := 90

# drinks: pour rate (cup-heights/sec), colours. Learned by playing, never named.
const DRINKS := [
	{"name": "chai", "rate": 0.42, "body": Color("#B8763E"), "top": Color("#D9A56A"), "stream": Color("#C4834A")},
	{"name": "lassi", "rate": 0.28, "body": Color("#F3EFE4"), "top": Color("#FFFFFF"), "stream": Color("#EDE7D8")},
	{"name": "doodh soda", "rate": 0.60, "body": Color("#F4B8CC"), "top": Color("#FFE3EC"), "stream": Color("#F7C6D6")},
]
const WALL := Color("#173F3A")
const WOOD_TOP := Color("#8A5530")
const WOOD := Color("#6B3F22")
const INK := Color("#FFF4E0")
const INK_SOFT := Color("#B9D3C9")
const CHEVRON := [Color("#E6307A"), Color("#FFB31A"), Color("#2FBF71")]
const KETTLE_BODY := Color("#C9D1CF")
const KETTLE_EDGE := Color("#8E9A97")
const KETTLE_LID := Color("#AEB8B5")
const CHALK := Color("#FFB31A")

var round_i := 0
var combo := 0
var state := "ready"       # ready | pouring | settling | result | spilled
var state_t := 0.0
var hold_t := 0.0
var slide := 1.0           # 1 = off-screen (entry), slides to 0
var level := 0.0           # fill fraction of the cup, 0..1+
var cup_h := 0.0
var cup_w := 0.0
var cup_line := 0.55
var cup_gap := 60.0
var drink: Dictionary
var parcels: Array = []    # [{y, v, amt}]
var drops: Array = []      # [{x, y, vx, vy, t, life, c, r, steam}]
var popup_plaque_t := 0.0  # counts down while a grade/spill popup is on screen

func _init() -> void:
	game_id = "dhaba_pour"
	title = "Dhaba Pour"
	tagline = "Hold to pour chai. Stop at the line."
	bg = WALL
	ink = INK
	accent = Color("#E6307A")
	hint = "Hold to pour. Stop at the line."

func _unit() -> float:
	# Matches the ported HTML original's reference resolution (400x800 phone),
	# NOT the app's own 720x1280 base — using the app base here was the scale bug
	# that shrank the whole scene to ~56% (dhaba-pour/index.html:163).
	return minf(W / 400.0, H / 800.0)

func _counter_y() -> float:
	return H * 0.78

func _setup() -> void:
	round_i = 0
	combo = 0
	parcels.clear()
	drops.clear()
	_new_round()

func _new_round() -> void:
	var u := _unit()
	var h_frac := rng.randf_range(0.6, 1.0)
	cup_h = 200.0 * u * h_frac + 60.0 * u
	var tier := mini(2, int(rng.randf() * mini(3, 1 + round_i / 3)))
	var gap_max := 80.0 + minf(round_i, 12) * 18.0
	var gap_room: float = _counter_y() - cup_h - 150.0 * u
	cup_w = cup_h * 0.64
	cup_line = rng.randf_range(0.55, 0.9)
	cup_gap = maxf(40.0 * u, minf((60.0 + rng.randf() * gap_max) * u, gap_room))
	drink = DRINKS[tier]
	level = 0.0
	parcels.clear()
	hold_t = 0.0
	state_t = 0.0
	slide = 1.0
	state = "ready"

func _spout_y() -> float:
	return _counter_y() - cup_h - cup_gap

func _on_press() -> void:
	if state == "ready" and slide <= 0.02:
		state = "pouring"
		hold_t = 0.0
		Sfx.loop_start("noise", 400.0, 0.35)

func _on_release() -> void:
	if state == "pouring":
		state = "settling"     # tea still in the air keeps landing

func _judge() -> void:
	Sfx.loop_stop()
	var diff := absf(level - cup_line)
	var grade := "PERFECT" if diff <= PERFECT else "GREAT" if diff <= GREAT else "GOOD" if diff <= GOOD else "MEH"
	combo = combo + 1 if grade == "PERFECT" else 0
	var mult := mini(combo, 5) if grade == "PERFECT" else 1
	var pts: int = POINTS[grade] * mult
	add_score(pts)
	var off := roundi((level - cup_line) * 100.0)
	var sub := ("on the line" if off == 0 else ("%d%% over" % off if off > 0 else "%d%% under" % -off)) + "  +%d" % pts
	popup(grade + (" x%d" % mult if mult > 1 else ""), sub, Vector2(W / 2, _counter_y() + 80.0 * _unit()), INK)
	popup_plaque_t = 1.1
	if grade == "PERFECT":
		Sfx.chord([587.0, 740.0, 880.0])
		shake(0.2)
		_steam(18)
	else:
		Sfx.tone(330.0 if grade == "MEH" else 440.0, 0.15)
	state = "result"
	state_t = 0.0

func _spill() -> void:
	Sfx.loop_stop()
	Sfx.tone(0.0, 0.4, "noise", 0.5)
	hitstop(HIT_STOP_MS)
	shake(0.8)
	combo = 0
	level = 1.0
	parcels.clear()
	var cx := W / 2
	var rim_y := _counter_y() - cup_h
	for i in 34:
		var side := 1.0 if i % 2 == 1 else -1.0
		drops.append({
			"x": cx + side * cup_w * 0.52, "y": rim_y + 2.0,
			"vx": side * (40.0 + rng.randf() * 160.0), "vy": -rng.randf() * 220.0,
			"t": 0.0, "life": 0.9 + rng.randf() * 0.4, "c": drink.stream, "r": 2.0 + rng.randf() * 4.0, "steam": false,
		})
	popup("SPILLED", "over the rim", Vector2(W / 2, _counter_y() + 80.0 * _unit()), INK)
	popup_plaque_t = 1.1
	var ended := lose_life()
	if not ended:
		state = "spilled"
		state_t = 0.0

func _next_round() -> void:
	round_i += 1
	_new_round()

func _steam(n: int) -> void:
	var cx := W / 2
	var surface_y := _counter_y() - level * cup_h
	for i in n:
		drops.append({
			"x": cx + (rng.randf() - 0.5) * cup_w * 0.7, "y": surface_y,
			"vx": (rng.randf() - 0.5) * 30.0, "vy": -60.0 - rng.randf() * 90.0,
			"t": 0.0, "life": 0.9 + rng.randf() * 0.6, "c": Color(INK, 0.5), "r": 5.0 + rng.randf() * 8.0, "steam": true,
		})

func _tick(dt: float) -> void:
	state_t += dt
	if state == "ready":
		slide = maxf(0.0, slide - dt * 4.0)

	if state == "pouring":
		hold_t += dt
		var rate: float = drink.rate * (1.0 + ACCEL * hold_t) * (1.0 + minf(round_i, 20) * RAMP)
		parcels.append({"y": _spout_y(), "v": FALL_SPEED * _unit(), "amt": rate * dt})

	for p in parcels:
		p.v += GRAVITY * _unit() * dt
		p.y += p.v * dt
	var surf: float = _counter_y() - level * cup_h
	var landed := 0.0
	var kept: Array = []
	for p in parcels:
		if p.y >= surf:
			landed += p.amt
		else:
			kept.append(p)
	parcels = kept
	if landed > 0.0 and (state == "pouring" or state == "settling"):
		level += landed
		Sfx.loop_pitch(0.6 + level * 1.4)
		if level >= 1.0:
			_spill()
	if state == "settling" and parcels.is_empty():
		_judge()
	if state == "result":
		if state_t > 0.8:
			slide = minf(1.0, slide + dt * 5.0)
		if state_t > 1.05 and running:
			_next_round()
	if state == "spilled" and state_t > 1.0 and running:
		_next_round()

	for d in drops:
		d.t += dt
		if d.steam:
			d.x += d.vx * dt
			d.y += d.vy * dt
		else:
			d.vy += 900.0 * _unit() * dt
			d.x += d.vx * dt
			d.y = minf(_counter_y() + 4.0, d.y + d.vy * dt)
	drops = drops.filter(func(d): return d.t < d.life)
	popup_plaque_t = maxf(0.0, popup_plaque_t - dt)

func _draw_game() -> void:
	var u := _unit()
	var cy := _counter_y()
	draw_rect(Rect2(0, cy, W, 10.0 * u), WOOD_TOP)
	# dark plaque behind the grade/spill popup so cream ink keeps contrast against
	# the wood counter for its whole ~0.7s full-opacity window, then fades in step
	# with the popup's own fade (matches core popup()'s t<0.7 full / 0.7-1.1 fade)
	if popup_plaque_t > 0.0:
		var elapsed: float = 1.1 - popup_plaque_t
		var pa: float = 0.8 if elapsed < 0.7 else 0.8 * clampf(1.0 - (elapsed - 0.7) / 0.4, 0.0, 1.0)
		var pl_pos := Vector2(W / 2, cy + 80.0 * u)
		draw_rect(Rect2(pl_pos.x - 190.0 * u, pl_pos.y - 46.0 * u, 380.0 * u, 100.0 * u), Color(WALL, pa))
	draw_rect(Rect2(0, cy + 10.0 * u, W, H - cy), WOOD)
	# truck-art chevrons along the counter edge
	var s := 14.0 * u
	var base := cy + 10.0 * u
	var i := 0
	var x := -s
	while x < W + s:
		var col: Color = CHEVRON[i % 3]
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, base), Vector2(x + s / 2.0, base + s * 0.8), Vector2(x + s, base)]), col)
		x += s
		i += 1

	var side_shift := 1.0
	if state == "result":
		side_shift = -1.0
	var offset := Vector2(side_shift * slide * W * 0.7, 0)
	set_xform(offset)

	var cx := W / 2
	var rim_y := cy - cup_h
	var spout_y := _spout_y()
	var half_top := cup_w / 2.0
	var half_bot := cup_w * 0.4

	# kettle
	var ky := spout_y
	var kc := Vector2(cx - 34.0 * u, ky - 28.0 * u)
	_ellipse(kc, 30.0 * u, 22.0 * u, KETTLE_BODY)
	draw_rect(Rect2(kc + Vector2(-10.0 * u, -30.0 * u), Vector2(20.0 * u, 8.0 * u)), KETTLE_LID)
	var spout_pts := PackedVector2Array()
	for k in 10:
		var t := k / 9.0
		var p0 := Vector2(22.0 * u, 4.0 * u)
		var p1 := Vector2(34.0 * u, 14.0 * u)
		var p2 := Vector2(34.0 * u, 26.0 * u)
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		spout_pts.append(kc + a.lerp(b, t))
	draw_polyline(spout_pts, KETTLE_LID, 6.0 * u, true)

	# falling stream
	if not parcels.is_empty():
		var prev_y := -1.0
		var first := true
		for p in parcels:
			if not first and absf(p.y - prev_y) < 60.0 * u:
				draw_line(Vector2(cx, prev_y), Vector2(cx, p.y), drink.stream, 7.0 * u, true)
			prev_y = p.y
			first = false
		draw_circle(Vector2(cx, parcels[0].y), 4.5 * u, drink.stream)

	# cup: tapered glass
	var top_y := rim_y
	var bot_y := cy
	var edge_at := func(y): return half_bot + (half_top - half_bot) * ((bot_y - y) / cup_h)
	var glass := PackedVector2Array([
		Vector2(cx - half_top, top_y), Vector2(cx + half_top, top_y),
		Vector2(cx + half_bot, bot_y), Vector2(cx - half_bot, bot_y)])
	draw_colored_polygon(glass, Color(1, 1, 1, 0.08))
	var ly: float = bot_y - minf(level, 1.0) * cup_h
	# clip liquid to the tapered glass shape by drawing a polygon intersection approximation:
	# the liquid's left/right edges follow the taper at ly and bot_y.
	var el: float = edge_at.call(ly)
	var liquid := PackedVector2Array([
		Vector2(cx - el, ly), Vector2(cx + el, ly),
		Vector2(cx + half_bot, bot_y), Vector2(cx - half_bot, bot_y)])
	if bot_y - ly > 0.5:
		draw_colored_polygon(liquid, drink.body)
		var top_h: float = minf(6.0 * u, bot_y - ly)
		var el2: float = edge_at.call(ly + top_h)
		var foam := PackedVector2Array([
			Vector2(cx - el, ly), Vector2(cx + el, ly),
			Vector2(cx + el2, ly + top_h), Vector2(cx - el2, ly + top_h)])
		draw_colored_polygon(foam, drink.top)
	# glass outline + ribs
	draw_polyline(PackedVector2Array([
		Vector2(cx - half_top, top_y), Vector2(cx - half_bot, bot_y),
		Vector2(cx + half_bot, bot_y), Vector2(cx + half_top, top_y)]), Color(INK, 0.75), 2.5 * u, true)
	for k in range(1, 6):
		var x0: float = -half_top + (cup_w / 6.0) * k
		var x1: float = -half_bot + (cup_w * 0.8 / 6.0) * k
		draw_line(Vector2(cx + x0, top_y + 4.0 * u), Vector2(cx + x1, bot_y - 4.0 * u), Color(INK, 0.18), 1.5 * u)

	# chalk target line + perfect band
	var line_y: float = bot_y - cup_line * cup_h
	var e: float = edge_at.call(line_y)
	draw_rect(Rect2(cx - e - 8.0 * u, line_y - PERFECT * cup_h, 2.0 * e + 16.0 * u, 2.0 * PERFECT * cup_h), Color(CHALK, 0.18))
	_dashed_line(Vector2(cx - e - 14.0 * u, line_y), Vector2(cx + e + 14.0 * u, line_y), CHALK, 3.0 * u, 8.0 * u, 6.0 * u)

	set_xform()

	# drops + steam (screen space, not shifted with the pour slide)
	for d in drops:
		var a: float = maxf(0.0, 1.0 - d.t / d.life)
		draw_circle(Vector2(d.x, d.y), d.r, Color(d.c, a * d.c.a if d.steam else a))

func _dashed_line(a: Vector2, b: Vector2, col: Color, width: float, dash: float, gap: float) -> void:
	var dir := (b - a)
	var len := dir.length()
	if len <= 0.0:
		return
	dir = dir / len
	var t := 0.0
	while t < len:
		var seg_end: float = minf(len, t + dash)
		draw_line(a + dir * t, a + dir * seg_end, col, width, true)
		t += dash + gap

func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 32:
		var a := float(i) / 32.0 * TAU
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(p, col)

func _bot(dt: float) -> void:
	if holding and state != "pouring":
		_release()
	elif state == "ready" and not holding and slide <= 0.02:
		_press()
	elif state == "pouring":
		# aim near the line; sometimes greedy and spills
		var target: float = cup_line + (rng.randf_range(0.05, 0.35) if rng.randf() < 0.2 else rng.randf_range(-0.03, 0.03))
		if level >= target:
			_release()
