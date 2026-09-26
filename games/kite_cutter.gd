extends MiniGame
## Kite Cutter: hold to reel tension while the kite drifts on the live wind vector;
## release to snap-cut whatever rival kite is currently crossing your string.
## Wait too long and a rival's own string cuts you first (risk climbs the longer you hold).

const KITE_HOME_Y_F := 0.38       # kite's resting height, fraction of H (raised: was 0.28, left ~50% dead sky)
const ANCHOR_Y_F := 0.8           # hand/spool height, fraction of H (lowered: was 0.95, same dead-sky fix)
const DRIFT_IDLE := 0.10          # idle horizontal drift, fraction of half-width
const DRIFT_HELD := 0.34          # extra drift at full tension, fraction of half-width
const BOW_F := 0.20               # string bow amount, fraction of half-width
const TENSION_TIME := 2.2         # seconds of holding to reach full tension
const RISK_BASE := 0.05           # base chance a rival cuts you first, per 0.5s held
const RISK_GROWTH := 0.04         # + this much per additional 0.5s interval held
const RISK_INTERVAL := 0.5
const RISK_CAP := 0.85
const CUT_RADIUS := 46.0          # how close a rival must be to your string to be "crossing"
const GUST_TELL := 0.4            # seconds a gust change is telegraphed before it happens
const SPAWN_BASE := 1.6
const RIVAL_SPEED := 130.0
const INK := Color("#2A1B3D")
const GOLD := Color("#FFE8A3")
# distinct Basant patang colours for rival kites, never the player's accent red or the GOLD cut-flash
const RIVAL_COLORS := [Color("#2FBF71"), Color("#2F6BFF"), Color("#FFD23C"), Color("#8A3FFC"), Color("#00B8B0")]
const BG_KITE_COLORS := [Color("#E6307A"), Color("#FFB31A"), Color("#2FBF71"), Color("#2F6BFF")]

var wind_x := 0.0
var wind_next := 0.0
var wind_t := 0.0
var wind_interval := 2.5
var telegraph := false

var round_i := 0
var kite_home := Vector2.ZERO
var anchor := Vector2.ZERO
var kite_pos := Vector2.ZERO
var tension := 0.0
var hold_t := 0.0
var risk_t := 0.0
var risk_hits := 0

var rivals := []             # [{p: Vector2, v: Vector2, color: Color, tail_ph: float}]
var spawn_t := 0.0
var string_pts := PackedVector2Array()
var roofs := []               # [{x, w, h, antenna: bool, tank: bool}] precomputed once per run
var bg_kites := []            # [{p: Vector2, s: float, color: Color, ph: float}] decorative, non-interactive
var birds := []               # [{p: Vector2, v: Vector2, ph: float}] decorative
var bot_release_target := 1.0

func _init() -> void:
	game_id = "kite_cutter"
	title = "Kite Cutter"
	tagline = "Reel your kite taut and snap the string the instant a rival crosses it."
	bg = Color("#F6A96B")
	ink = INK
	accent = Color("#C4432B")
	hint = "Hold to reel in. Release to cut whoever crosses your string."
	use_lives = false

func _setup() -> void:
	round_i = 0
	wind_x = rng.randf_range(-1.0, 1.0)
	wind_next = rng.randf_range(-1.0, 1.0)
	wind_t = 0.0
	wind_interval = 2.5
	telegraph = false
	tension = 0.0
	hold_t = 0.0
	risk_t = 0.0
	risk_hits = 0
	rivals.clear()
	spawn_t = 0.4
	anchor = Vector2(W * 0.5, H * ANCHOR_Y_F)
	kite_home = Vector2(W * 0.5, H * KITE_HOME_Y_F)
	kite_pos = kite_home
	_gen_roofs()
	_gen_ambient()
	_update_string()

func _gen_roofs() -> void:
	roofs.clear()
	var rx := 0.0
	while rx < W + 40.0:
		var w: float = rng.randf_range(60.0, 140.0)
		var h: float = rng.randf_range(24.0, 74.0)
		roofs.append({"x": rx, "w": w, "h": h, "antenna": rng.randf() < 0.35, "tank": rng.randf() < 0.25})
		rx += w + rng.randf_range(6.0, 26.0)

## Sparse background dressing for the sky gap between the roofs and the play kite:
## small non-interactive kites + a couple of birds. Fixed, low-alpha, never overlaps the HUD band.
func _gen_ambient() -> void:
	bg_kites.clear()
	birds.clear()
	var n_kites := 3
	for i in n_kites:
		bg_kites.append({
			"p": Vector2(W * (0.12 + 0.36 * i) + rng.randf_range(-20.0, 20.0), H * rng.randf_range(0.42, 0.62)),
			"s": rng.randf_range(0.16, 0.24), "color": BG_KITE_COLORS[i % BG_KITE_COLORS.size()],
			"ph": rng.randf() * TAU,
		})
	for i in 2:
		birds.append({
			"p": Vector2(W * rng.randf_range(0.1, 0.9), H * rng.randf_range(0.32, 0.5)),
			"v": Vector2((1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(14.0, 26.0), 0.0),
			"ph": rng.randf() * TAU,
		})

func _spawn_rival() -> void:
	var from_left := rng.randf() < 0.5
	var y := rng.randf_range(H * 0.26, H * 0.62)
	var speed: float = RIVAL_SPEED * (1.0 + mini(round_i, 12) * 0.04) * rng.randf_range(0.85, 1.2)
	var x := -60.0 if from_left else W + 60.0
	var vx := speed if from_left else -speed
	rivals.append({"p": Vector2(x, y), "v": Vector2(vx, 0.0),
		"color": RIVAL_COLORS[rng.randi() % RIVAL_COLORS.size()], "tail_ph": rng.randf() * TAU})
	spawn_t = maxf(0.5, SPAWN_BASE - round_i * 0.05)

func _on_press() -> void:
	tension = 0.0
	hold_t = 0.0
	risk_t = 0.0
	risk_hits = 0
	bot_release_target = rng.randf_range(0.5, 2.6)
	Sfx.loop_start("tri", 180.0, 0.12)

func _on_release() -> void:
	Sfx.loop_stop()
	var cut_list := []
	for i in rivals.size():
		if _crossing(rivals[i]):
			cut_list.append(i)
	if cut_list.is_empty():
		Sfx.tone(220.0, 0.12)
	else:
		var pts := 10 * cut_list.size()
		for idx in cut_list:
			burst(rivals[idx].p, GOLD, 18, 0.7)
		cut_list.sort()
		cut_list.reverse()
		for idx in cut_list:
			rivals.remove_at(idx)
		add_score(pts)
		if cut_list.size() > 1:
			Sfx.chord([523.0, 659.0, 784.0])
			popup("CHAIN ×%d" % cut_list.size(), "+%d" % pts, Vector2(W / 2.0, kite_pos.y - 60.0), GOLD)
			shake(0.3)
		else:
			Sfx.tone(660.0, 0.14)
			popup("CUT", "+%d" % pts, Vector2(W / 2.0, kite_pos.y - 60.0), GOLD)
		round_i += 1
	tension = 0.0
	hold_t = 0.0

func _crossing(rv) -> bool:
	var best := INF
	for p in string_pts:
		var d := p.distance_to(rv.p)
		if d < best:
			best = d
	return best < CUT_RADIUS

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var a := p0.lerp(p1, t)
	var b := p1.lerp(p2, t)
	return a.lerp(b, t)

func _update_string() -> void:
	var mid := anchor.lerp(kite_pos, 0.5)
	mid.x += wind_x * BOW_F * (W * 0.5) * (0.4 + 0.6 * tension)
	string_pts = PackedVector2Array()
	for i in 24:
		var t := float(i) / 23.0
		string_pts.append(_bezier(anchor, mid, kite_pos, t))

func _get_cut() -> void:
	var culprit := -1
	var best := INF
	for i in rivals.size():
		var d := INF
		for p in string_pts:
			var dd := p.distance_to(rivals[i].p)
			if dd < d:
				d = dd
		if d < best:
			best = d
			culprit = i
	Sfx.tone(0.0, 0.2, "noise", 0.85)
	hitstop(100)
	shake(0.9)
	if culprit >= 0:
		burst(rivals[culprit].p, Color("#C4432B"), 30, 1.1)
	popup("SNAPPED", "a rival cut you first", Vector2(W / 2.0, kite_pos.y - 60.0), Color("#C4432B"))
	lose_life()

func _tick(dt: float) -> void:
	wind_interval = lerpf(2.5, 1.2, clampf(float(round_i) / 8.0, 0.0, 1.0))
	wind_t += dt
	telegraph = wind_t > wind_interval - GUST_TELL
	if wind_t >= wind_interval:
		wind_t = 0.0
		wind_x = wind_next
		wind_next = rng.randf_range(-1.0, 1.0)

	if holding:
		hold_t += dt
		tension = clampf(hold_t / TENSION_TIME, 0.0, 1.0)
		risk_t += dt
		if risk_t >= RISK_INTERVAL:
			risk_t -= RISK_INTERVAL
			risk_hits += 1
			var chance: float = clampf(RISK_BASE + RISK_GROWTH * risk_hits, 0.0, RISK_CAP)
			if not rivals.is_empty() and rng.randf() < chance:
				_get_cut()
				return
	else:
		tension = maxf(0.0, tension - dt * 1.5)
		risk_hits = 0
		risk_t = 0.0

	var drift: float = (DRIFT_IDLE + (DRIFT_HELD - DRIFT_IDLE) * tension) if holding else DRIFT_IDLE
	kite_pos.x = kite_home.x + wind_x * drift * (W * 0.5)
	kite_pos.y = kite_home.y + sin(time * 2.2) * 8.0
	_update_string()

	spawn_t -= dt
	var max_r := 1 + int(clampf(float(round_i) / 5.0, 0.0, 1.0) * 3.0)
	if spawn_t <= 0.0 and rivals.size() < max_r:
		_spawn_rival()
	for rv in rivals:
		rv.p += rv.v * dt
	rivals = rivals.filter(func(rv): return rv.p.x > -80.0 and rv.p.x < W + 80.0)

	for b in birds:
		b.p += b.v * dt
		if b.p.x < -30.0:
			b.p.x = W + 30.0
		elif b.p.x > W + 30.0:
			b.p.x = -30.0

func _wind_sock(p: Vector2) -> void:
	var ang := wind_x * 0.6
	var glow: float = 1.0 if not telegraph else 0.55 + 0.45 * sin(time * 26.0)
	draw_line(p, p + Vector2(0, -46), INK, 5.0, true)
	# faint streak trail flowing with the wind so the sock reads as a wind cue, not an orphan flag
	var wdir := 1.0 if wind_x >= 0.0 else -1.0
	for k in 3:
		var t := float(k)
		draw_line(p + Vector2(0, -30.0 + t * 8.0), p + Vector2(wdir * (10.0 + absf(wind_x) * 16.0), -30.0 + t * 8.0),
			Color(INK, 0.18), 2.0, true)
	set_xform(p + Vector2(0, -46), ang)
	var col := accent if telegraph else Color(INK, 0.8)
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(30.0 * glow, -9.0), Vector2(34.0 * glow, 0.0), Vector2(30.0 * glow, 9.0)]), col)
	set_xform()

func _kite_shape(sc: float, dir: float, color: Color, tail_len: float, tail_ph: float) -> void:
	var kw := 46.0 * sc
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -kw), Vector2(kw * 0.7 * dir, 0), Vector2(0, kw), Vector2(-kw * 0.7 * dir, 0)]), color)
	draw_line(Vector2(-kw * 0.7 * dir, 0), Vector2(kw * 0.7 * dir, 0), INK, 3.0 * sc)
	draw_line(Vector2(0, -kw), Vector2(0, kw), INK, 3.0 * sc)
	var tail := PackedVector2Array()
	for i in 6:
		var t := float(i) / 5.0
		tail.append(Vector2(sin(time * 6.0 + tail_ph + t * 3.0) * 10.0 * t * sc, kw + t * tail_len))
	draw_polyline(tail, INK, 3.0 * sc, true)

func _draw_game() -> void:
	var roof_y := H * 0.9
	draw_rect(Rect2(0, roof_y, W, H - roof_y), INK)
	for r in roofs:
		draw_rect(Rect2(r.x, roof_y - r.h, r.w, r.h + 4.0), INK)
		if r.tank:
			draw_rect(Rect2(r.x + r.w * 0.2, roof_y - r.h - 16.0, 18.0, 16.0), Color(INK, 0.85))
		if r.antenna:
			var ax: float = r.x + r.w * 0.7
			draw_line(Vector2(ax, roof_y - r.h), Vector2(ax, roof_y - r.h - 34.0), Color(INK, 0.7), 2.0)
			draw_line(Vector2(ax - 8.0, roof_y - r.h - 22.0), Vector2(ax + 8.0, roof_y - r.h - 22.0), Color(INK, 0.7), 2.0)

	# decorative sky dressing: distant kites + birds, low-alpha so they never compete with play
	for bk in bg_kites:
		set_xform(bk.p, sin(time * 0.6 + bk.ph) * 0.08)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -46.0 * bk.s), Vector2(46.0 * bk.s * 0.7, 0), Vector2(0, 46.0 * bk.s), Vector2(-46.0 * bk.s * 0.7, 0)]),
			Color(bk.color, 0.35))
		set_xform()
	for b in birds:
		var wing: float = sin(time * 9.0 + b.ph) * 5.0
		var bp: Vector2 = b.p
		draw_line(bp + Vector2(-8, wing), bp, Color(INK, 0.4), 2.0, true)
		draw_line(bp, bp + Vector2(8, wing), Color(INK, 0.4), 2.0, true)

	_wind_sock(Vector2(W * 0.86, H * 0.20))

	if string_pts.size() > 1:
		draw_polyline(string_pts, INK, 4.0, true)
	draw_circle(anchor, 14.0, INK)
	draw_circle(anchor, 8.0, accent)

	if holding:
		var bar_w := 160.0
		var bar_p := anchor + Vector2(-bar_w / 2.0, -40.0)
		text_c("PULL", bar_p + Vector2(bar_w / 2.0, -16.0), 14, Color(INK, 0.7), false)
		draw_rect(Rect2(bar_p, Vector2(bar_w, 12.0)), Color(INK, 0.25))
		draw_rect(Rect2(bar_p, Vector2(bar_w * tension, 12.0)), accent)
		var danger: float = clampf(RISK_BASE + RISK_GROWTH * risk_hits, 0.0, RISK_CAP)
		var flash: float = 1.0 if danger < 0.5 else (0.5 + 0.5 * sin(time * 16.0))
		draw_rect(Rect2(bar_p + Vector2(0, 18), Vector2(bar_w, 8.0)), Color(INK, 0.18))
		draw_rect(Rect2(bar_p + Vector2(0, 18), Vector2(bar_w * danger, 8.0)), Color(Color("#C4432B"), flash))
		text_c("RISK", bar_p + Vector2(bar_w / 2.0, 44.0), 14, Color("#C4432B", 0.6 + 0.4 * flash), false)

	# rivals: real diamond kites with their own tail + a short string toward an implied edge anchor,
	# each a distinct colour so "cut a kite" reads instantly
	for rv in rivals:
		var cross := _crossing(rv)
		var dir := 1.0 if rv.v.x > 0.0 else -1.0
		var edge_anchor := Vector2(rv.p.x - dir * 34.0, H * 0.98)
		draw_line(rv.p, edge_anchor, Color(rv.color, 0.5), 2.0, true)
		if cross:
			draw_circle(rv.p, 30.0, Color(1, 1, 1, 0.35))
		set_xform(rv.p, 0.0, Vector2.ONE)
		_kite_shape(0.6, dir, GOLD if cross else rv.color, 46.0, rv.tail_ph)
		set_xform()

	set_xform(kite_pos, wind_x * 0.15)
	var kw := 46.0
	draw_colored_polygon(PackedVector2Array([Vector2(0, -kw), Vector2(kw * 0.7, 0), Vector2(0, kw), Vector2(-kw * 0.7, 0)]), accent)
	draw_line(Vector2(-kw * 0.7, 0), Vector2(kw * 0.7, 0), INK, 3.0)
	draw_line(Vector2(0, -kw), Vector2(0, kw), INK, 3.0)
	var tail := PackedVector2Array()
	for i in 6:
		var t := float(i) / 5.0
		tail.append(Vector2(sin(time * 6.0 + t * 3.0) * 10.0 * t, kw + t * 70.0))
	draw_polyline(tail, INK, 3.0, true)
	set_xform()

func _bot(dt: float) -> void:
	if not holding:
		_press()
		return
	for rv in rivals:
		if _crossing(rv):
			if rng.randf() < 0.6:
				_release()
			return
	if hold_t > bot_release_target:
		_release()
