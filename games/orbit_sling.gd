extends MiniGame
## Orbit Sling: hold to orbit a stone around the current planet (speed builds);
## release fires it in a straight tangent line at that exact speed and angle.
## Thread it through the next planet to chain; miss and it flies off into space.

const R_ORBIT := 100.0            # stone's orbit radius around a planet
const PLANET_R := 46.0
const ORBIT_ACCEL := 3.4          # angular acceleration while held, rad/s^2
const MAX_SPEED := 14.0           # angular speed cap, rad/s
const TANGENT_SCALE := 1.0
const FLIGHT_MAX_T := 1.6         # seconds before a flying stone counts as lost
const CAPTURE_R := 92.0           # generous capture zone (~2x PLANET_R) so a decent aim lands
const AIM_SNAP_DEG := 16.0        # release forgiveness cone: nudges a near-miss straight onto the target
const LEAD_CHAIN := 4             # planets start drifting from this chain on
const DRIFT_R := 40.0
const DRIFT_SPEED := 1.4
const PALETTE := [Color("#FF5E7A"), Color("#3DDC97"), Color("#4CC3FF"), Color("#FFD23F")]
const INK := Color("#F4F1FF")

var chain := 0
var duration := 2.2
var state := "orbit"       # orbit | flying | lost
var state_t := 0.0

var planet_pos := Vector2.ZERO
var planet_col: Color = PALETTE[0]
var target_base := Vector2.ZERO
var target_pos := Vector2.ZERO
var target_col: Color = PALETTE[1]
var target_drift_t := 0.0

var stone_angle := 0.0
var stone_speed := 0.0        # angular speed, rad/s
var stone_pos := Vector2.ZERO
var stone_vel := Vector2.ZERO
var tangent_dir := Vector2.RIGHT
var hold_t := 0.0
var miss_pos := Vector2.ZERO
var flight_min_dist := 1.0e6

var stars := []

func _init() -> void:
	game_id = "orbit_sling"
	title = "Orbit Sling"
	tagline = "Whip your stone around the planet and let go to sling it clean through the next."
	bg = Color("#14122B")
	ink = INK
	accent = Color("#4CC3FF")
	hint = "Hold to orbit and build speed. Release to sling toward the next planet."

func _setup() -> void:
	chain = 0
	duration = 2.2
	_gen_stars()
	planet_pos = Vector2(W * 0.5, H * 0.5)
	planet_col = PALETTE[0]
	_new_target()
	_reset_orbit()

func _gen_stars() -> void:
	stars.clear()
	for i in 40:
		stars.append(Vector2(rng.randf_range(0.0, W), rng.randf_range(0.0, H)))

func _new_target() -> void:
	var ang := rng.randf_range(0.0, TAU)
	var dist := rng.randf_range(minf(W, H) * 0.28, minf(W, H) * 0.42)
	target_base = planet_pos + Vector2(cos(ang), sin(ang)) * dist
	target_base.x = clampf(target_base.x, 70.0, W - 70.0)
	target_base.y = clampf(target_base.y, H * 0.26, H * 0.90)
	target_pos = target_base
	target_drift_t = 0.0
	var idx := PALETTE.find(planet_col)
	target_col = PALETTE[(idx + 1 + rng.randi_range(0, 1)) % PALETTE.size()]

func _reset_orbit() -> void:
	state = "orbit"
	state_t = 0.0
	hold_t = 0.0
	stone_speed = 0.0
	stone_angle = (target_base - planet_pos).angle() + PI
	_place_stone()

func _place_stone() -> void:
	stone_pos = planet_pos + Vector2(cos(stone_angle), sin(stone_angle)) * R_ORBIT
	tangent_dir = Vector2(-sin(stone_angle), cos(stone_angle))

func _on_press() -> void:
	if state != "orbit":
		return
	hold_t = 0.0
	Sfx.loop_start("saw", 140.0, 0.10)

func _on_release() -> void:
	if state != "orbit":
		return
	_launch()

func _launch() -> void:
	Sfx.loop_stop()
	var speed := stone_speed * R_ORBIT * TANGENT_SCALE
	var launch_dir := tangent_dir
	var to_target := target_pos - stone_pos
	if to_target.length() > 1.0:
		var ideal := to_target.normalized()
		var ang := rad_to_deg(acos(clampf(tangent_dir.dot(ideal), -1.0, 1.0)))
		if ang < AIM_SNAP_DEG:
			launch_dir = ideal   # release forgiveness: a near-enough aim snaps true
	stone_vel = launch_dir * speed
	state = "flying"
	state_t = 0.0
	flight_min_dist = 1.0e6
	Sfx.tone(300.0 + minf(stone_speed, 12.0) * 40.0, 0.12)

func _update_target_drift(dt: float) -> void:
	if chain >= LEAD_CHAIN:
		target_drift_t += dt
		target_pos = target_base + Vector2(cos(target_drift_t * DRIFT_SPEED), sin(target_drift_t * DRIFT_SPEED * 1.3)) * DRIFT_R
	else:
		target_pos = target_base

func _tick(dt: float) -> void:
	match state:
		"orbit":
			if holding:
				hold_t += dt
				stone_speed = clampf(stone_speed + ORBIT_ACCEL * dt, 0.0, MAX_SPEED)
				stone_angle += stone_speed * dt
				_place_stone()
				if hold_t >= duration:
					_launch()
			_update_target_drift(dt)
		"flying":
			state_t += dt
			stone_pos += stone_vel * dt
			_update_target_drift(dt)
			flight_min_dist = minf(flight_min_dist, stone_pos.distance_to(target_pos))
			if stone_pos.distance_to(target_pos) < CAPTURE_R:
				_captured()
			elif state_t > FLIGHT_MAX_T or stone_pos.x < -80.0 or stone_pos.x > W + 80.0 or stone_pos.y < -80.0 or stone_pos.y > H + 80.0:
				_lost()
		"lost":
			state_t += dt
			if state_t > 0.9 and running:
				_new_target()
				_reset_orbit()

func _captured() -> void:
	chain += 1
	add_score(1)
	Sfx.chord([440.0, 554.0, 659.0])
	burst(target_pos, target_col, 24, 0.7)
	shake(0.2)
	popup("+1", "chain %d" % chain, Vector2(W / 2.0, H * 0.25), target_col)
	duration = lerpf(2.2, 1.0, clampf(float(chain) / 6.0, 0.0, 1.0))
	planet_pos = target_pos if chain >= LEAD_CHAIN else target_base
	planet_col = target_col
	_new_target()
	_reset_orbit()

func _lost() -> void:
	Sfx.tone(0.0, 0.2, "noise", 0.8)
	hitstop(90)
	shake(0.6)
	miss_pos = stone_pos
	var sub := "so close! %dpx off" % int(flight_min_dist - CAPTURE_R) if flight_min_dist < CAPTURE_R * 1.6 else "flew past the next planet"
	popup("MISSED", sub, Vector2(W / 2.0, H * 0.25), Color("#FF5E7A"))
	state = "lost"
	state_t = 0.0
	chain = 0
	lose_life()

func _draw_game() -> void:
	for s in stars:
		draw_circle(s, 1.6, Color(INK, 0.35))

	var t_r := PLANET_R * 0.8
	draw_arc(target_pos, CAPTURE_R, 0.0, TAU, 40, Color(target_col, 0.28), 3.0)
	draw_circle(target_pos, t_r, Color(target_col, 0.35))
	draw_circle(target_pos, t_r * 0.55, target_col)
	if chain >= LEAD_CHAIN:
		draw_arc(target_pos, t_r + 10.0, 0.0, TAU, 24, Color(target_col, 0.5), 2.0)

	draw_circle(planet_pos, PLANET_R, planet_col)
	draw_circle(planet_pos, PLANET_R * 0.7, Color(1, 1, 1, 0.12))
	if state == "orbit" and holding:
		var frac: float = 1.0 - clampf(hold_t / duration, 0.0, 1.0)
		draw_arc(planet_pos, PLANET_R + 16.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 40, INK, 5.0)
	else:
		draw_arc(planet_pos, PLANET_R + 16.0, 0.0, TAU, 40, Color(INK, 0.18), 3.0)

	if state == "orbit" and holding:
		var l: float = maxf(W, H) * 1.3
		draw_line(stone_pos, stone_pos + tangent_dir * l, Color(INK, 0.28), 3.0)

	if state == "flying":
		draw_line(planet_pos, stone_pos, Color(INK, 0.15), 2.0)

	var s_pos := miss_pos if state == "lost" else stone_pos
	draw_circle(s_pos, 12.0, INK)

func _bot(dt: float) -> void:
	if state != "orbit":
		return
	if not holding:
		_press()
		return
	if stone_speed > 2.0:
		var to_target := target_pos - stone_pos
		var dist := to_target.length()
		if dist > 1.0:
			var ideal := to_target / dist
			# perpendicular miss distance if released right now, along the tangent line
			var cross_dist: float = absf(tangent_dir.x * ideal.y - tangent_dir.y * ideal.x) * dist
			var dot := tangent_dir.dot(ideal)
			# usually aim tight enough for a clean capture; occasionally a looser, riskier release
			var tolerance: float = CAPTURE_R * (0.55 if rng.randf() < 0.85 else 0.25)
			if dot > 0.0 and cross_dist < tolerance:
				_release()
				return
	if hold_t > duration * rng.randf_range(0.85, 0.99):
		_release()
