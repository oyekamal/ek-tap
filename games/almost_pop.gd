extends MiniGame
## Almost Pop: hold to blow up the balloon, let go before it touches the pins.
## Reference game for the Ek Tap framework: copy this structure for new games.

const SPEEDS := [0.55, 0.8, 1.1]            # ring radii per second: yellow, coral, blue
const COLORS := [Color("#FFC23C"), Color("#FF5A4E"), Color("#2F6BFF")]
const ACCEL := 0.8                           # speed multiplier grows by this per second held
const RAMP := 0.02                           # +2% speed per round, capped at 20 rounds
const WOBBLE := 0.015                        # ±1.5% size wobble while inflating
const PERFECT := 0.96
const GREAT := 0.9
const GOOD := 0.8
const INK := Color("#1F2B33")

var round_i := 0
var combo := 0
var ring_r := 200.0
var pins := 24
var r := 20.0
var tier := 0
var state := "ready"      # ready | inflating | result | popped
var state_t := 0.0
var hold_t := 0.0
var fly_y := 0.0
var fly_v := 0.0
var bot_target := 0.9

func _init() -> void:
	game_id = "almost_pop"
	title = "Almost Pop"
	tagline = "Hold to blow it up. Let go before the pins."
	bg = Color("#CFE8DF")
	ink = INK
	accent = Color("#FF5A4E")
	hint = "Hold anywhere. Let go before the pins."

func _setup() -> void:
	round_i = 0
	combo = 0
	_new_round()

func _new_round() -> void:
	var f := rng.randf_range(0.45, 0.9)
	var max_r := minf(W, H * 0.8) * 0.38
	ring_r = max_r * f
	pins = int(18 + f * 14)
	tier = mini(2, int(rng.randf() * mini(3, 1 + round_i / 3)))
	r = ring_r * 0.12
	state = "ready"
	state_t = 0.0
	hold_t = 0.0
	fly_y = 0.0
	fly_v = 0.0

func _shown_r() -> float:
	return r * (1.0 + WOBBLE * sin(time * 18.0)) if state == "inflating" else r

func _on_press() -> void:
	if state == "ready":
		state = "inflating"
		hold_t = 0.0
		Sfx.loop_start("tri", 220.0, 0.15)

func _on_release() -> void:
	if state == "inflating":
		_lock_in()

func _lock_in() -> void:
	Sfx.loop_stop()
	var fill := r / ring_r
	var grade := "PERFECT" if fill >= PERFECT else "GREAT" if fill >= GREAT else "GOOD" if fill >= GOOD else "SMALL"
	combo = combo + 1 if grade == "PERFECT" else 0
	var mult := mini(combo, 5) if grade == "PERFECT" else 1
	var pts: int = {"PERFECT": 100, "GREAT": 50, "GOOD": 25, "SMALL": 5}[grade] * mult
	add_score(pts)
	popup(grade + (" ×%d" % mult if mult > 1 else ""), "%d%%  +%d" % [roundi(fill * 100), pts], Vector2(W / 2, _center().y - ring_r - 100), INK)
	if grade == "PERFECT":
		Sfx.chord([523.0, 659.0, 784.0])
		burst(_center(), COLORS[tier], 26, 0.6)
		shake(0.25)
	else:
		Sfx.tone(330.0 if grade == "SMALL" else 440.0, 0.15)
	state = "result"
	state_t = 0.0

func _pop() -> void:
	Sfx.loop_stop()
	Sfx.tone(0, 0.18, "noise", 0.8)
	hitstop(90)
	shake(0.9)
	combo = 0
	burst(_center(), COLORS[tier], 40, 1.2)
	popup("POP", "touched the pins", Vector2(W / 2, _center().y - ring_r - 100), INK)
	state = "popped"
	state_t = 0.0
	lose_life()

func _center() -> Vector2:
	return Vector2(W / 2, H * 0.52)

func _tick(dt: float) -> void:
	state_t += dt
	match state:
		"inflating":
			hold_t += dt
			var sp: float = SPEEDS[tier] * (1.0 + ACCEL * hold_t) * (1.0 + mini(round_i, 20) * RAMP)
			r += sp * ring_r * dt
			var fill := _shown_r() / ring_r
			Sfx.loop_pitch(0.9 + fill * fill * 3.0)   # squeak rises as it nears the pins
			if _shown_r() >= ring_r:
				_pop()
		"result":
			if state_t > 0.35:
				fly_v -= 1400.0 * dt
				fly_y += fly_v * dt
			if state_t > 0.8:
				round_i += 1
				_new_round()
		"popped":
			if state_t > 0.9 and running:
				round_i += 1
				_new_round()

func _draw_game() -> void:
	draw_rect(Rect2(0, H * 0.86, W, H * 0.14), Color("#B7DACD"))
	var c := _center()
	# pins: tips point inward and sit exactly on the ring radius
	for i in pins:
		var a := float(i) / pins * TAU + 0.2
		var d := Vector2(cos(a), sin(a))
		var hot := state == "popped"
		var col := Color("#FF5A4E") if hot else INK
		draw_line(c + d * ring_r, c + d * (ring_r + 22), col, 6.0 if hot else 4.0, true)
		draw_circle(c + d * (ring_r + 26), 9.0 if hot else 7.0, col)
	# faint perfect band (96-100%)
	draw_arc(c, ring_r * (1.0 + PERFECT) / 2.0, 0, TAU, 96, Color(INK, 0.12), ring_r * (1.0 - PERFECT))
	if state != "popped":
		var rr := _shown_r()
		var squash := 1.0 + sin(state_t / 0.25 * PI) * 0.08 if state == "result" and state_t < 0.25 else 1.0
		var bc := c + Vector2(0, fly_y)
		# string
		var pts := PackedVector2Array()
		for k in 12:
			var t := k / 11.0
			pts.append(bc + Vector2(sin(time * 3.0 + t * 3.0) * 8.0 * t, rr * 1.02 + t * 120.0))
		draw_polyline(pts, Color("#4A5B66"), 3.0, true)
		set_xform(bc, 0, Vector2(squash, 1.0 / squash))
		_ellipse(Vector2.ZERO, rr, rr * 1.02, COLORS[tier])
		draw_colored_polygon(PackedVector2Array([Vector2(-9, rr * 1.02 + 10), Vector2(9, rr * 1.02 + 10), Vector2(0, rr * 0.98)]), COLORS[tier])
		_ellipse(Vector2(-rr * 0.38, -rr * 0.42), rr * 0.14, rr * 0.24, Color(1, 1, 1, 0.55))
		set_xform()

func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 48:
		var a := float(i) / 48 * TAU
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(p, col)

func _bot(dt: float) -> void:
	# aim for ~90% fill: press when ready, release near the ring
	if holding and state != "inflating":
		_release()   # lift the finger after a pop, like a real player
	elif state == "ready" and not holding:
		bot_target = 1.2 if rng.randf() < 0.3 else rng.randf_range(0.84, 0.99)   # sometimes greedy -> pops
		_press()
	elif state == "inflating" and r / ring_r > bot_target:
		_release()
