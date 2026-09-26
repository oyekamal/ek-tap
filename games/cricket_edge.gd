extends MiniGame
## Cricket Edge: tap to swing. Timing along one continuum decides everything --
## early (risky boundary), the narrow edge (safe singles), or late/no tap
## (bowled). No appeal, no second input: just the swing.

const BASE_BALL_TIME := 1.05        # seconds, bowler release to arrival at the bat
const BALL_TIME_JITTER := 0.08      # +/- seconds of natural variance per ball
const WINDOW_START := 0.12          # contact window (seconds) at over 1
const WINDOW_MIN := 0.07            # contact window (seconds) by over 4
const BRACKET_LEAD := 0.3           # seconds the contact bracket slides in before arrival
const CATCH_CHANCE := 0.35          # chance an early big shot is caught
const BALLS_PER_OVER := 6
const OVERS_TO_MIN_WINDOW := 3.0    # overs (1 -> 4) to reach WINDOW_MIN
const BALL_RADIUS := 13.0           # px at 720 wide -- must stay clearly >= 12
const BOWL_Y_F := 0.34              # keeps the bowler figure's head clear of the top ~200px HUD band

const GRASS := Color("#3E8E41")
const PITCH := Color("#D9C98A")
const STUMP_COL := Color("#F4E4B0")
const BAT_COL := Color("#C68A4A")
const KIT := Color("#2A4FB0")
const BALL_COL := Color("#B0221B")
const BALL_SEAM := Color("#FFFFFF")
const BRACKET_COL := Color("#FFD34D")
const OUT_COL := Color("#FF4D4D")

var state := "waiting"    # waiting | delivery | result
var state_t := 0.0
var ball_t := 0.0
var t_arrival := BASE_BALL_TIME
var swung := false
var outcome := ""         # edge | early | late | bowled | caught
var over_i := 0
var balls_faced := 0
var _bot_target := 0.0
var _bot_will_swing := true

func _init() -> void:
	game_id = "cricket_edge"
	title = "Cricket Edge"
	tagline = "Tap on the nick, not into the gloves."
	bg = GRASS
	ink = Color("#FFFFFF")
	accent = Color("#F4E4B0")
	hint = "Tap to swing. Time it."

func _setup() -> void:
	state = "waiting"
	state_t = 0.0
	over_i = 0
	balls_faced = 0
	swung = false
	outcome = ""

func _unit() -> float:
	return W / 720.0

func _half_window() -> float:
	var frac: float = clampf(float(over_i) / OVERS_TO_MIN_WINDOW, 0.0, 1.0)
	return lerpf(WINDOW_START, WINDOW_MIN, frac) / 2.0

func _new_ball() -> void:
	ball_t = 0.0
	t_arrival = BASE_BALL_TIME + rng.randf_range(-BALL_TIME_JITTER, BALL_TIME_JITTER)
	swung = false
	outcome = ""
	state = "delivery"
	state_t = 0.0
	var half := _half_window()
	var roll := rng.randf()
	_bot_will_swing = true
	if roll < 0.5:
		_bot_target = rng.randf_range(-half * 0.65, half * 0.65)
	elif roll < 0.8:
		_bot_target = -rng.randf_range(half * 1.3, half * 3.2)
	else:
		_bot_target = rng.randf_range(half * 1.3, half * 2.6)
		_bot_will_swing = rng.randf() < 0.45

func _on_press() -> void:
	if state != "delivery" or swung:
		return
	swung = true
	_resolve(ball_t - t_arrival)

func _on_release() -> void:
	pass

func _resolve(delta) -> void:
	var half := _half_window()
	state = "result"
	state_t = 0.0
	if delta == null:
		outcome = "bowled"
	elif delta < -half:
		outcome = "early"
	elif delta > half:
		outcome = "late"
	else:
		outcome = "edge"
	match outcome:
		"edge":
			var runs: int = 1 if rng.randf() < 0.5 else 2
			add_score(runs)
			popup("+%d" % runs, "nicked it", Vector2(W / 2.0, H * 0.34), ink)
			Sfx.tone(700.0, 0.1, "tri", 0.3)
		"early":
			if rng.randf() < CATCH_CHANCE:
				outcome = "caught"
				hitstop(110)
				shake(0.6)
				popup("CAUGHT", "too early", Vector2(W / 2.0, H * 0.34), OUT_COL)
				Sfx.tone(0, 0.2, "noise", 0.6)
				lose_life()
			else:
				var runs: int = 6 if rng.randf() < 0.4 else 4
				add_score(runs)
				popup(("SIX!" if runs == 6 else "FOUR!"), "+%d" % runs, Vector2(W / 2.0, H * 0.34), Color("#FFD34D"))
				Sfx.chord([523.0, 659.0, 784.0, 988.0])
				shake(0.35)
		"late", "bowled":
			hitstop(110)
			shake(0.7)
			popup("OUT", "bowled", Vector2(W / 2.0, H * 0.34), OUT_COL)
			Sfx.tone(90.0, 0.25, "saw", 0.5)
			lose_life()
	balls_faced += 1
	if balls_faced % BALLS_PER_OVER == 0:
		over_i += 1

func _tick(dt: float) -> void:
	state_t += dt
	match state:
		"waiting":
			if state_t > 0.45:
				_new_ball()
		"delivery":
			ball_t += dt
			var half := _half_window()
			if not swung and ball_t > t_arrival + half + 0.18:
				swung = true
				_resolve(null)
		"result":
			if state_t > 0.9 and running:
				state = "waiting"
				state_t = 0.0

func _draw_game() -> void:
	var u := _unit()
	var bowl_y := H * BOWL_Y_F
	var bat_y := H * 0.78
	var stump_y := H * 0.85
	var keep_y := H * 0.94
	# pitch strip
	draw_rect(Rect2(W / 2.0 - 55.0 * u, bowl_y - 20.0 * u, 110.0 * u, stump_y - bowl_y + 40.0 * u), PITCH)

	# keeper
	_figure(Vector2(W / 2.0, keep_y), KIT, u, 0.8)
	# stumps
	for i in 3:
		var sx: float = W / 2.0 + (i - 1) * 14.0 * u
		var col := STUMP_COL
		if outcome == "bowled" or outcome == "late":
			col = OUT_COL
		draw_line(Vector2(sx, stump_y), Vector2(sx, stump_y - 46.0 * u), col, 6.0 * u, true)
	# batter
	_figure(Vector2(W / 2.0 - 26.0 * u, bat_y), Color("#FFFFFF"), u, 1.0)
	draw_line(Vector2(W / 2.0 - 6.0 * u, bat_y - 24.0 * u), Vector2(W / 2.0 + 18.0 * u, bat_y + 22.0 * u), BAT_COL, 8.0 * u, true)
	# bowler (static, top of pitch)
	_figure(Vector2(W / 2.0, bowl_y - 20.0 * u), Color("#FFFFFF"), u, 0.85)

	# contact bracket: slides toward the bat in the last BRACKET_LEAD seconds
	if state == "delivery":
		var to_arrival: float = t_arrival - ball_t
		if to_arrival <= BRACKET_LEAD and to_arrival >= -0.05:
			var k: float = 1.0 - clampf(to_arrival / BRACKET_LEAD, 0.0, 1.0)
			var half_px: float = lerpf(70.0 * u, _half_window() * 420.0 * u, k)
			var by: float = lerpf(bowl_y + 90.0 * u, bat_y - 30.0 * u, k)
			draw_line(Vector2(W / 2.0 - half_px, by), Vector2(W / 2.0 - half_px + 16.0 * u, by), BRACKET_COL, 4.0 * u, true)
			draw_line(Vector2(W / 2.0 + half_px, by), Vector2(W / 2.0 + half_px - 16.0 * u, by), BRACKET_COL, 4.0 * u, true)

	# ball
	var by2: float = bowl_y
	var bx2: float = W / 2.0
	if state == "delivery":
		var t: float = clampf(ball_t / t_arrival, 0.0, 1.4)
		by2 = lerpf(bowl_y, bat_y, t)
	elif state == "result":
		match outcome:
			"caught":
				bx2 = W / 2.0 + 140.0 * u
				by2 = bat_y - 140.0 * u
			"late", "bowled":
				bx2 = W / 2.0
				by2 = stump_y - 20.0 * u
			_:
				bx2 = W / 2.0 - 10.0 * u
				by2 = bat_y - 6.0 * u
	if state == "delivery":
		for i in 3:
			var trail_t: float = clampf((ball_t - float(i + 1) * 0.03) / t_arrival, 0.0, 1.4)
			var trail_y: float = lerpf(bowl_y, bat_y, trail_t)
			draw_circle(Vector2(bx2, trail_y), (BALL_RADIUS - float(i) * 3.0) * u, Color(BALL_COL, 0.3 - float(i) * 0.08))
	draw_circle(Vector2(bx2, by2), BALL_RADIUS * u, BALL_COL)
	draw_arc(Vector2(bx2, by2), BALL_RADIUS * u, 0, PI, 6, BALL_SEAM, 1.5 * u)

func _figure(pos: Vector2, col: Color, u: float, scl: float) -> void:
	set_xform(pos, 0, Vector2(scl, scl))
	draw_rect(Rect2(-11.0 * u, -6.0 * u, 22.0 * u, 30.0 * u), col)
	draw_circle(Vector2(0, -18.0 * u), 11.0 * u, col)
	draw_line(Vector2(-6.0 * u, 24.0 * u), Vector2(-8.0 * u, 44.0 * u), col, 5.0 * u, true)
	draw_line(Vector2(6.0 * u, 24.0 * u), Vector2(8.0 * u, 44.0 * u), col, 5.0 * u, true)
	set_xform()

func _bot(dt: float) -> void:
	if holding:
		_release()
		return
	if state != "delivery" or swung:
		return
	if not _bot_will_swing:
		return
	if ball_t >= t_arrival + _bot_target:
		_press()
