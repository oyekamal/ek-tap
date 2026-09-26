extends MiniGame
## Scale Call: hold to pile goods on the brass scale, release to stop adding — the
## needle keeps swinging on residual momentum for a moment before it settles, so you
## must let go before it looks level, anticipating the overshoot, not reacting to it.

const ADD_RATE := 60.0            # grams/second while holding
const EQ_SCALE := 34.0             # grams of over/under-weight = full needle deflection
const SPRING_K := 150.0
const DAMPING := 4.4
const LEVEL_PERFECT := 0.07
const LEVEL_GOOD := 0.18
const LEVEL_OK := 0.38
const VARIANCE_ROUND := 4          # round at which weight-rate variance kicks in
const TRAIL_LEN := 5
const VIS_CLAMP := 2.2             # needle_pos clamp before mapping to a drawn angle
const VIS_SCALE := 0.5             # radians of beam tilt per unit of clamped needle_pos
const BRASS := Color("#D9A441")
const INK := Color("#FFF1D6")
const SPILL := Color("#FF6B57")

var round_i := 0
var combo := 0
var required := 50.0
var weight_held := 0.0
var eq := 0.0
var needle_pos := 0.0
var needle_vel := 0.0
var rate_mult := 1.0
var shimmer_t := 0.0
var state := "ready"       # ready | filling | settling | crash
var state_t := 0.0
var trail := []

func _init() -> void:
	game_id = "scale_call"
	title = "Scale Call"
	tagline = "Pile goods on the brass scale and let go before it ever looks level."
	bg = Color("#5A1E2E")
	ink = INK
	accent = BRASS
	hint = "Hold to add goods. Let go before the needle looks centered."

func _setup() -> void:
	round_i = 0
	combo = 0
	_new_round()

func _new_round() -> void:
	required = rng.randf_range(40.0, 95.0) * (1.0 + mini(round_i, 10) * 0.03)
	weight_held = 0.0
	eq = -required / EQ_SCALE
	needle_pos = eq
	needle_vel = 0.0
	rate_mult = 1.0
	shimmer_t = 0.0
	state = "ready"
	state_t = 0.0
	trail.clear()

func _on_press() -> void:
	if state == "ready":
		state = "filling"
		Sfx.loop_start("noise", 300.0, 0.12)

func _on_release() -> void:
	if state == "filling":
		Sfx.loop_stop()
		state = "settling"
		state_t = 0.0

func _spring(dt: float) -> void:
	needle_vel += (eq - needle_pos) * SPRING_K * dt
	needle_vel *= exp(-DAMPING * dt)
	needle_pos += needle_vel * dt

func _push_trail() -> void:
	trail.append(needle_pos)
	if trail.size() > TRAIL_LEN:
		trail.pop_front()

func _tick(dt: float) -> void:
	match state:
		"filling":
			if round_i >= VARIANCE_ROUND:
				shimmer_t += dt
				if shimmer_t > 0.35:
					shimmer_t = 0.0
					rate_mult = rng.randf_range(0.7, 1.45)
			weight_held += ADD_RATE * rate_mult * dt
			eq = (weight_held - required) / EQ_SCALE
			Sfx.loop_pitch(1.0 + clampf(weight_held / required, 0.0, 2.0) * 0.6)
			_spring(dt)
		"settling":
			state_t += dt
			_spring(dt)
			if state_t > 1.6 or (state_t > 0.5 and absf(needle_vel) < 0.05):
				_grade()
		"crash":
			state_t += dt
			if state_t > 0.9 and running:
				round_i += 1
				_new_round()
	_push_trail()

func _grade() -> void:
	var dev := absf(needle_pos)
	if dev <= LEVEL_PERFECT:
		combo += 1
		var mult: int = mini(combo, 5)
		var pts := int(weight_held * mult)
		add_score(pts)
		Sfx.chord([523.0, 659.0, 784.0])
		burst(_needle_tip(), BRASS, 22, 0.6)
		shake(0.15)
		popup(("LEVEL ×%d" % mult) if mult > 1 else "LEVEL", "%dg  +%d" % [int(weight_held), pts], Vector2(W / 2.0, H * 0.25), BRASS)
		_advance()
	elif dev <= LEVEL_GOOD:
		combo = 0
		var pts2 := int(weight_held * 0.6)
		add_score(pts2)
		Sfx.tone(440.0, 0.15)
		popup("CLOSE", "%dg  +%d" % [int(weight_held), pts2], Vector2(W / 2.0, H * 0.25), INK)
		_advance()
	elif dev <= LEVEL_OK:
		combo = 0
		var pts3 := int(weight_held * 0.3)
		add_score(pts3)
		Sfx.tone(330.0, 0.15)
		popup("TIPPED", "%dg  +%d" % [int(weight_held), pts3], Vector2(W / 2.0, H * 0.25), INK)
		_advance()
	else:
		_crash()

func _advance() -> void:
	state = "ready"
	round_i += 1
	_new_round()

func _crash() -> void:
	combo = 0
	Sfx.tone(0.0, 0.22, "noise", 0.85)
	hitstop(100)
	shake(0.85)
	var dir := "right" if needle_pos > 0.0 else "left"
	burst(_needle_tip(), BRASS, 32, 1.1)
	popup("SPILLED", "crashed to the " + dir, Vector2(W / 2.0, H * 0.25), SPILL)
	state = "crash"
	state_t = 0.0
	lose_life()

func _needle_tip() -> Vector2:
	var pivot := Vector2(W * 0.5, H * 0.42)
	var beam_len: float = minf(W, H) * 0.34
	var a: float = clampf(needle_pos, -VIS_CLAMP, VIS_CLAMP) * VIS_SCALE
	return pivot + Vector2(beam_len, 0).rotated(a) + Vector2(0, 70.0)

func _pan(pos: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var t := float(i) / 19.0
		var a := lerpf(PI * 0.15, PI * 0.85, t)
		pts.append(pos + Vector2(cos(a), sin(a)) * 40.0)
	draw_polyline(pts, col, 6.0, true)

func _draw_game() -> void:
	var pivot := Vector2(W * 0.5, H * 0.42)
	var beam_len: float = minf(W, H) * 0.34

	# residual-momentum motion trail (drawn first, underneath the live beam)
	for i in trail.size():
		var p = trail[i]
		var a2: float = clampf(p, -VIS_CLAMP, VIS_CLAMP) * VIS_SCALE
		var alpha: float = float(i + 1) / float(maxi(trail.size(), 1)) * 0.22
		var seg := Vector2(beam_len * 0.9, 0).rotated(a2)
		draw_line(pivot - seg, pivot + seg, Color(INK, alpha), 3.0)

	# stand
	draw_line(pivot, Vector2(pivot.x, H * 0.86), BRASS, 10.0, true)
	draw_line(Vector2(pivot.x - 60.0, H * 0.86), Vector2(pivot.x + 60.0, H * 0.86), BRASS, 10.0, true)
	draw_circle(pivot, 10.0, BRASS)

	# beam + pans
	var tip_angle: float = clampf(needle_pos, -VIS_CLAMP, VIS_CLAMP) * VIS_SCALE
	var dir_l := Vector2(-beam_len, 0).rotated(tip_angle)
	var dir_r := Vector2(beam_len, 0).rotated(tip_angle)
	var l_end := pivot + dir_l
	var r_end := pivot + dir_r
	draw_line(l_end, r_end, BRASS, 8.0, true)
	draw_circle(l_end, 8.0, BRASS)
	draw_circle(r_end, 8.0, BRASS)

	var pan_drop := 70.0
	var l_pan := l_end + Vector2(0, pan_drop)
	var r_pan := r_end + Vector2(0, pan_drop)
	draw_line(l_end, l_pan, INK, 3.0)
	draw_line(r_end, r_pan, INK, 3.0)
	_pan(l_pan, Color(INK, 0.9))
	_pan(r_pan, BRASS)

	# reference weight on the left pan
	draw_rect(Rect2(l_pan.x - 16.0, l_pan.y - 24.0, 32.0, 24.0), Color(INK, 0.85))
	# goods pile on the right pan, height grows with weight held
	var pile_h: float = clampf(weight_held / 3.0, 0.0, 90.0)
	if pile_h > 1.0:
		draw_rect(Rect2(r_pan.x - 34.0, r_pan.y - pile_h, 68.0, pile_h), Color("#C97B3A"))
		if round_i >= VARIANCE_ROUND and state == "filling":
			var shimmer: float = 0.5 + 0.5 * sin(time * 30.0)
			draw_rect(Rect2(r_pan.x - 34.0, r_pan.y - pile_h, 68.0, 6.0), Color(1, 1, 1, 0.25 * shimmer))

func _bot(dt: float) -> void:
	match state:
		"ready":
			if not holding:
				_press()
		"filling":
			if not holding:
				return
			var guess_bias := rng.randf_range(-6.0, 10.0)
			if weight_held >= required + guess_bias:
				_release()
		"settling", "crash":
			if holding:
				_release()
