extends MiniGame
## Tawa Flip: tap to launch the roti off a spinning charge dial. The dial's
## charge at the instant you tap sets both the flip height and the rotation
## count (rotations = floor(charge/25)+1); land it while the charge is inside
## the shrinking safe zone for a clean landing, or it folds/skids off the pan.

const CHARGE_PERIOD_START := 1.7
const CHARGE_PERIOD_MIN := 0.55
const CHARGE_SPEEDUP := 0.97       # charge cycle time *= this per clean landing (~3% faster)
const ZONE_START := 42.0           # safe-zone width, percentage points of the 0-100 dial
const ZONE_MIN := 11.0
const ZONE_SHRINK := 0.95          # zone width *= this per clean landing (~5% smaller)
const FLIGHT_BASE := 0.55
const FLIGHT_SCALE := 0.55
const HEIGHT_BASE := 0.15          # fraction of H
const HEIGHT_SCALE := 0.34
const PAN_Y_F := 0.72

const IRON := Color("#15100D")
const IRON_EDGE := Color("#37281F")
const WOOD := Color("#1D1410")
const ROTI := Color("#E3A94B")
const ROTI_SPOT := Color("#8A5A24")
const FLAME_A := Color("#FF8A3D")
const FLAME_B := Color("#FFC463")
const DIAL_BG := Color("#4A362A")
const DIAL_FILL := Color("#FFD98A")
const ZONE_COL := Color("#7CE38B")
const FAIL_COL := Color("#FF6B5E")
const DUST := Color("#D8C9A3")
const FLOUR := Color("#FFF6E0")

var state := "idle"        # idle | flying | landed_good | landed_bad
var state_t := 0.0
var charge_t := 0.0
var charge_period := CHARGE_PERIOD_START
var zone_w := ZONE_START
var zone_c := 60.0
var combo := 0
var flight_t := 0.0
var flight_dur := 0.0
var flight_rot := 1
var flight_h := 0.0
var launch_charge := 0.0
var pending_success := false

func _init() -> void:
	game_id = "tawa_flip"
	title = "Tawa Flip"
	tagline = "Tap the roti off the dial into the shrinking green zone."
	bg = Color("#2A1F1A")
	ink = Color("#FFF1DC")
	accent = ROTI
	hint = "Tap when the dial is in the green."

func _setup() -> void:
	state = "idle"
	state_t = 0.0
	charge_t = 0.0
	charge_period = CHARGE_PERIOD_START
	zone_w = ZONE_START
	combo = 0
	flight_t = 0.0
	_new_zone()

func _unit() -> float:
	return W / 720.0

func _new_zone() -> void:
	var half: float = zone_w / 2.0
	zone_c = rng.randf_range(half + 6.0, 100.0 - half - 6.0)

func _charge_value() -> float:
	var p: float = fmod(charge_t, charge_period) / charge_period
	var tri: float = p * 2.0 if p < 0.5 else 2.0 - p * 2.0
	return tri * 100.0

func _on_press() -> void:
	if state != "idle":
		return
	launch_charge = _charge_value()
	pending_success = absf(launch_charge - zone_c) <= zone_w / 2.0
	flight_rot = int(floor(launch_charge / 25.0)) + 1
	flight_h = HEIGHT_BASE + HEIGHT_SCALE * (launch_charge / 100.0)
	flight_dur = FLIGHT_BASE + FLIGHT_SCALE * (launch_charge / 100.0)
	flight_t = 0.0
	state = "flying"
	Sfx.tone(280.0 + launch_charge * 3.2, 0.1, "tri", 0.22)

func _on_release() -> void:
	pass

func _tick(dt: float) -> void:
	state_t += dt
	match state:
		"idle":
			charge_t += dt
		"flying":
			flight_t += dt
			if flight_t >= flight_dur:
				_land()
		"landed_good", "landed_bad":
			if state_t > 0.5 and running:
				state = "idle"
				charge_t = 0.0
				state_t = 0.0

func _land() -> void:
	state_t = 0.0
	if pending_success:
		state = "landed_good"
		combo += 1
		# the decision: charging higher (waiting for the dial to swing further before
		# tapping) means a taller, faster, more-rotated flip -- harder to time -- but pays
		# a bigger multiplier. Landing dead-centre of the zone ("PERFECT") also pays far
		# more than clipping the edge ("CLEAN"), so a safe low-charge tap that just grazes
		# the zone edge is a real fallback, not the same payout as a bold, accurate one.
		var half: float = zone_w / 2.0
		var dist: float = absf(launch_charge - zone_c)
		var accuracy: float = 1.0 - clampf(dist / maxf(half, 0.001), 0.0, 1.0)   # 1 = dead centre, 0 = edge
		var risk_mult: float = 1.0 + 0.6 * (launch_charge / 100.0)              # higher charge = bigger, riskier flip
		var combo_mult: float = float(mini(combo, 5))
		var pts: int = int(round(lerpf(4.0, 22.0, accuracy) * combo_mult * risk_mult))
		add_score(pts)
		var perfect: bool = accuracy > 0.82
		var grade := "PERFECT" if perfect else "CLEAN"
		popup(grade + (" x%d" % combo if combo > 1 else ""), "+%d" % pts, Vector2(W / 2.0, H * PAN_Y_F - 190.0), ink)
		if perfect:
			Sfx.chord([659.0, 784.0, 988.0])
			burst(Vector2(W / 2.0, H * PAN_Y_F), Color("#FFE9A8"), 22, 0.6)
		else:
			Sfx.chord([523.0, 659.0, 784.0])
			burst(Vector2(W / 2.0, H * PAN_Y_F), ROTI, 16, 0.45)
		burst(Vector2(W / 2.0, H * PAN_Y_F - 10.0 * _unit()), FLOUR, 14, 0.3)   # flour puff on landing
		zone_w = maxf(ZONE_MIN, zone_w * ZONE_SHRINK)
		charge_period = maxf(CHARGE_PERIOD_MIN, charge_period * CHARGE_SPEEDUP)
		_new_zone()
	else:
		state = "landed_bad"
		combo = 0
		Sfx.tone(70.0, 0.22, "noise", 0.55)
		hitstop(90)
		shake(0.55)
		popup("FOLDED", "off the pan", Vector2(W / 2.0, H * PAN_Y_F - 190.0), FAIL_COL)
		burst(Vector2(W / 2.0, H * PAN_Y_F), DUST, 22, 0.6)
		lose_life()

func _draw_game() -> void:
	var u := _unit()
	var pan_y := H * PAN_Y_F
	# stove
	draw_rect(Rect2(W / 2.0 - 150.0 * u, pan_y + 26.0 * u, 300.0 * u, 90.0 * u), WOOD)
	# tawa -- drawn BEFORE the flames now, so the flames (wider than the pan and
	# anchored below its rim) lick out visibly past its edges instead of being
	# fully overpainted by it every frame.
	_ellipse(Vector2(W / 2.0, pan_y), 165.0 * u, 46.0 * u, IRON_EDGE)
	_ellipse(Vector2(W / 2.0, pan_y - 6.0 * u), 155.0 * u, 40.0 * u, IRON)
	for i in 8:
		var fx: float = W / 2.0 - 189.0 * u + i * 54.0 * u
		var flick: float = sin(Time.get_ticks_msec() / 60.0 + i) * 8.0 * u
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx - 9.0 * u, pan_y + 60.0 * u),
			Vector2(fx + 9.0 * u, pan_y + 60.0 * u),
			Vector2(fx + flick, pan_y + 14.0 * u),
		]), FLAME_A if i % 2 == 0 else FLAME_B)

	# landing zone: a ring on the tawa itself showing where the roti will come down
	if state == "idle" or state == "flying":
		draw_arc(Vector2(W / 2.0, pan_y - 10.0 * u), 66.0 * u, 0, TAU, 28, Color(ZONE_COL, 0.5), 3.0 * u)

	# charge dial: always visible
	var gx := W / 2.0
	var gy := H * 0.19   # scaled by H (was a hardcoded 216px) -- keeps clearance from the HUD line
	var gw := W * 0.58
	draw_rect(Rect2(gx - gw / 2.0, gy - 9.0 * u, gw, 18.0 * u), DIAL_BG)
	var zx0: float = gx - gw / 2.0 + gw * (zone_c - zone_w / 2.0) / 100.0
	draw_rect(Rect2(zx0, gy - 9.0 * u, gw * zone_w / 100.0, 18.0 * u), ZONE_COL)
	var shown_charge: float = launch_charge if state != "idle" else _charge_value()
	var nx: float = gx - gw / 2.0 + gw * shown_charge / 100.0
	draw_rect(Rect2(nx - 4.0 * u, gy - 15.0 * u, 8.0 * u, 30.0 * u), DIAL_FILL)

	# roti
	if state == "idle" or state == "landed_good":
		_roti(Vector2(W / 2.0, pan_y - 10.0 * u), 1.0, 0.0)
	elif state == "flying":
		var t: float = flight_t / flight_dur
		var arc: float = sin(t * PI) * flight_h * H
		var y: float = pan_y - 10.0 * u - arc
		var ang: float = t * float(flight_rot) * PI
		# short motion trail so the arc + spin read clearly, not just a static disc
		for k in [0.12, 0.06]:
			var tt: float = clampf(t - k, 0.0, 1.0)
			var t_arc: float = sin(tt * PI) * flight_h * H
			var t_y: float = pan_y - 10.0 * u - t_arc
			var t_ang: float = tt * float(flight_rot) * PI
			set_xform(Vector2(W / 2.0, t_y), t_ang, Vector2(1.0, 1.0))
			_ellipse(Vector2.ZERO, 56.0 * u, 27.0 * u, Color(ROTI, 0.15))
			set_xform()
		_roti(Vector2(W / 2.0, y), 1.0, ang)
	elif state == "landed_bad":
		var k: float = clampf(state_t / 0.5, 0.0, 1.0)
		_roti(Vector2(W / 2.0 + 70.0 * u * k, pan_y - 4.0 * u), 1.0 - 0.35 * k, 0.35 * k)

func _roti(pos: Vector2, squash: float, ang: float) -> void:
	var u := _unit()
	set_xform(pos, ang, Vector2(1.0, squash))
	_ellipse(Vector2.ZERO, 62.0 * u, 30.0 * u, ROTI)
	# asymmetric spot pattern (varying radii, not a symmetric ring) so spin reads frame-to-frame
	var spot_r := [34.0, 18.0, 30.0, 14.0, 26.0]
	for i in 5:
		var a: float = float(i) / 5.0 * TAU
		var r: float = spot_r[i] * u
		draw_circle(Vector2(cos(a) * r, sin(a) * r * 0.45), 5.0 * u, ROTI_SPOT)
	# one larger off-axis toasted mark -- the clearest single rotation tell
	draw_circle(Vector2(40.0 * u, 6.0 * u), 9.0 * u, ROTI_SPOT)
	set_xform()

func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 32:
		var a: float = float(i) / 32.0 * TAU
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(p, col)

func _bot(dt: float) -> void:
	if holding:
		_release()
		return
	if state != "idle":
		return
	var c := _charge_value()
	var margin: float = zone_w / 2.0
	var dist: float = absf(c - zone_c)
	if dist <= margin and rng.randf() < 0.9:
		_press()
	elif dist <= margin * 1.7 and rng.randf() < 0.05:
		_press()
