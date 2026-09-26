extends MiniGame
## Kabaddi Raid: hold to raid deep and auto-tag defenders, release to sprint
## home before they catch you. Points from tags are provisional -- they only
## bank on a safe return home.

const ADV_SPEED := 300.0        # px/s the raider advances while held
const RETREAT_SPEED := 330.0    # px/s automatic retreat after release
const CLOSE_RATE := 95.0        # px/s a defender's gap closes, scaled by speed_mult
const TAG_INTERVAL := 1.5       # seconds of continuous holding between auto-tags
const TAG_POINTS := 15
const TAG_ACCEL := 1.08         # remaining defenders speed up per tag
const RESULT_PAUSE := 0.85
const RAIDER_BLUE := Color("#2F6BFF")
const DEF_RED := Color("#E63B2E")

var home_y := 0.0
var top_y := 0.0
var depth_max := 1.0
var depth := 0.0
var defender_gaps: Array[float] = []
var hold_timer := 0.0
var raid_i := 0
var raid_score := 0
var speed_mult := 1.0
var state := "ready"      # ready | advance | retreat | caught | safe
var state_t := 0.0
var safe_depth := 0.0
var bot_release_depth := 0.0
var _no_defenders_t := 0.0   # safety valve: forces advance->retreat if the bot (or a human)
                             # never releases once every defender is tagged

func _init() -> void:
	game_id = "kabaddi_raid"
	title = "Kabaddi Raid"
	tagline = "Raid deep, tag defenders, sprint home before they grab you."
	bg = Color("#C9784A")
	ink = Color("#2B1408")
	accent = RAIDER_BLUE
	hint = "Hold to raid. Release to sprint home."

func _setup() -> void:
	raid_i = 0
	_measure()
	_ready_next()

func _measure() -> void:
	home_y = H * 0.90
	top_y = H * 0.24
	depth_max = home_y - top_y

func _ready_next() -> void:
	state = "ready"
	state_t = 0.0
	depth = 0.0
	raid_score = 0

func _begin_raid() -> void:
	_measure()
	var n := mini(4, 2 + int(raid_i / 3))
	defender_gaps.clear()
	for i in n:
		defender_gaps.append(depth_max * rng.randf_range(0.55, 0.95))
	speed_mult = 1.0 + raid_i * 0.05
	hold_timer = 0.0
	depth = 0.0
	raid_score = 0
	state = "advance"
	state_t = 0.0
	_no_defenders_t = 0.0
	# always a reachable depth (depth is clamped to depth_max, so a target >= depth_max
	# would never trigger the bot's release check -- that was the soft-lock).
	bot_release_depth = depth_max * (0.98 if rng.randf() < 0.25 else rng.randf_range(0.3, 0.9))
	Sfx.loop_start("tri", 180.0, 0.18)

func _on_press() -> void:
	if state == "ready":
		_begin_raid()

func _on_release() -> void:
	if state == "advance":
		state = "retreat"
		state_t = 0.0
		Sfx.loop_pitch(1.4)

func _nearest_gap() -> float:
	var g := INF
	for gp in defender_gaps:
		g = minf(g, gp)
	return g

func _close_defenders(dt: float) -> void:
	for i in defender_gaps.size():
		defender_gaps[i] = maxf(-40.0, defender_gaps[i] - CLOSE_RATE * speed_mult * dt)

func _check_caught() -> bool:
	for gp in defender_gaps:
		if gp <= 0.0:
			_caught()
			return true
	return false

func _tag_nearest() -> void:
	var idx := 0
	var best := INF
	for i in defender_gaps.size():
		if defender_gaps[i] < best:
			best = defender_gaps[i]
			idx = i
	defender_gaps.remove_at(idx)
	speed_mult *= TAG_ACCEL
	raid_score += TAG_POINTS
	popup("TAG!", "+%d" % TAG_POINTS, Vector2(W / 2, home_y - depth - 90))
	Sfx.tone(700.0, 0.12, "square", 0.4)
	burst(Vector2(W / 2, home_y - depth), DEF_RED, 14, 0.5)

func _caught() -> void:
	Sfx.loop_stop()
	Sfx.tone(0, 0.2, "noise", 0.8)
	hitstop(90)
	shake(0.8)
	burst(Vector2(W / 2, home_y - depth), DEF_RED, 30, 1.0)
	popup("CAUGHT!", "raid lost", Vector2(W / 2, home_y - depth - 90))
	state = "caught"
	state_t = 0.0
	lose_life()

func _safe_return() -> void:
	Sfx.loop_stop()
	Sfx.chord([523.0, 659.0, 784.0])
	add_score(raid_score)
	popup("SAFE!", "+%d pts" % raid_score, Vector2(W / 2, home_y - 60))
	burst(Vector2(W / 2, home_y), RAIDER_BLUE, 20, 0.6)
	state = "safe"
	state_t = 0.0

func _tick(dt: float) -> void:
	_measure()
	state_t += dt
	match state:
		"advance":
			depth = minf(depth_max, depth + ADV_SPEED * dt)
			hold_timer += dt
			if hold_timer >= TAG_INTERVAL and not defender_gaps.is_empty():
				hold_timer -= TAG_INTERVAL
				_tag_nearest()
			_close_defenders(dt)
			Sfx.loop_pitch(0.9 + (depth / depth_max) * 1.4)
			if _check_caught():
				return
			# fallback: once every defender is tagged and the raider has reached max
			# depth, force the sprint home after a short beat -- guarantees the state
			# always advances even if a release is never triggered.
			if defender_gaps.is_empty() and depth >= depth_max:
				_no_defenders_t += dt
				if _no_defenders_t > 0.4:
					state = "retreat"
					state_t = 0.0
					Sfx.loop_pitch(1.4)
			else:
				_no_defenders_t = 0.0
		"retreat":
			depth = maxf(0.0, depth - RETREAT_SPEED * dt)
			_close_defenders(dt)
			if not _check_caught() and depth <= 0.0:
				_safe_return()
		"caught":
			if state_t > RESULT_PAUSE and running:
				raid_i += 1
				_ready_next()
		"safe":
			if state_t > RESULT_PAUSE * 0.7 and running:
				raid_i += 1
				_ready_next()

func _draw_court() -> void:
	var court := Rect2(W * 0.08, top_y, W * 0.84, home_y - top_y)
	# mat texture: alternating faint stripes so it reads as a mat, not a flat fill
	var stripe_n := 10
	for i in stripe_n:
		if i % 2 == 0:
			var sy0 := top_y + (home_y - top_y) * (float(i) / stripe_n)
			var sy1 := top_y + (home_y - top_y) * (float(i + 1) / stripe_n)
			draw_rect(Rect2(court.position.x, sy0, court.size.x, sy1 - sy0), Color(ink, 0.045))
	draw_rect(court, ink, false, 4.0)
	# lobbies: narrow strips either side of the main court
	var lobby_w := W * 0.05
	draw_rect(Rect2(court.position.x - lobby_w, top_y, lobby_w, home_y - top_y), Color(ink, 0.03))
	draw_rect(Rect2(court.position.x + court.size.x, top_y, lobby_w, home_y - top_y), Color(ink, 0.03))
	draw_rect(Rect2(court.position.x - lobby_w, top_y, lobby_w, home_y - top_y), ink, false, 2.0)
	draw_rect(Rect2(court.position.x + court.size.x, top_y, lobby_w, home_y - top_y), ink, false, 2.0)
	# midline
	draw_line(Vector2(W * 0.03, top_y + (home_y - top_y) * 0.5), Vector2(W * 0.97, top_y + (home_y - top_y) * 0.5), Color(ink, 0.5), 3.0)
	# baulk line (near home, first commitment line) and bonus line (deep, extra-risk line)
	var baulk_y := home_y - depth_max * 0.22
	var bonus_y := home_y - depth_max * 0.68
	draw_line(Vector2(W * 0.03, baulk_y), Vector2(W * 0.97, baulk_y), Color(ink, 0.55), 2.5)
	text_c("baulk", Vector2(W * 0.03 + 34.0, baulk_y - 18.0), 16, Color(ink, 0.6), false)
	draw_dashed_line(Vector2(W * 0.03, bonus_y), Vector2(W * 0.97, bonus_y), Color(ink, 0.55), 2.5, 10.0)
	text_c("bonus", Vector2(W * 0.03 + 34.0, bonus_y - 18.0), 16, Color(ink, 0.6), false)
	draw_rect(Rect2(W * 0.08, home_y - 6.0, W * 0.84, 6.0), RAIDER_BLUE)

func _draw_game() -> void:
	_draw_court()

	if state != "ready":
		var gap_n := _nearest_gap()
		if defender_gaps.is_empty():
			safe_depth = depth_max
		else:
			var rate := CLOSE_RATE * speed_mult
			safe_depth = clampf(maxf(0.0, gap_n) * RETREAT_SPEED / maxf(1.0, rate), 0.0, depth_max)
		var line_y := home_y - safe_depth
		# approach ratio: how close `depth` is to the safe line, BEFORE crossing it.
		# 0 = far from the line, 1 = right at it, >1 = past it (danger).
		var approach := 0.0 if safe_depth <= 0.0 else depth / safe_depth
		var col: Color
		if approach >= 1.0:
			var flash := absf(sin(time * 10.0)) > 0.4
			col = Color("#E63B2E") if flash else Color("#FFE9B8", 0.9)
		elif approach >= 0.6:
			col = Color("#FFE9B8", 0.9).lerp(Color("#F2A33A"), (approach - 0.6) / 0.4)
		else:
			col = Color("#FFE9B8", 0.9)
		var dashes := 24
		for i in dashes:
			if i % 2 == 0:
				var x0 := W * 0.08 + (W * 0.84) * (float(i) / dashes)
				var x1 := W * 0.08 + (W * 0.84) * (float(i + 1) / dashes)
				draw_line(Vector2(x0, line_y), Vector2(x1, line_y), col, 5.0)

		for i in defender_gaps.size():
			var dg: float = defender_gaps[i]
			var ddepth := clampf(depth - dg, 0.0, depth_max)
			var dx := W / 2 + (float(i) - float(defender_gaps.size() - 1) / 2.0) * 84.0
			var dy := home_y - ddepth
			# lunge-range telegraph: translucent arc facing the raider, closes in as they close the gap
			var close_frac := clampf(1.0 - dg / depth_max, 0.0, 1.0)
			draw_arc(Vector2(dx, dy), 40.0 + 18.0 * close_frac, PI * 0.15, PI * 0.85, 10, Color(DEF_RED, 0.3 + 0.25 * close_frac), 4.0)
			# defender body: torso + head + two braced legs so it doesn't read as a flat dot
			var bob := sin(time * 9.0 + float(i) * 1.7) * 3.0
			draw_circle(Vector2(dx, dy + bob), 24.0, DEF_RED)
			draw_circle(Vector2(dx, dy + bob - 30.0), 13.0, DEF_RED)
			draw_line(Vector2(dx - 16.0, dy + bob + 20.0), Vector2(dx - 26.0, dy + bob + 38.0), DEF_RED, 6.0)
			draw_line(Vector2(dx + 16.0, dy + bob + 20.0), Vector2(dx + 26.0, dy + bob + 38.0), DEF_RED, 6.0)

		var raid_bob := sin(time * 11.0) * 3.0
		draw_circle(Vector2(W / 2, home_y - depth + raid_bob), 30.0, RAIDER_BLUE)
		draw_circle(Vector2(W / 2, home_y - depth - 40.0 + raid_bob), 14.0, RAIDER_BLUE)
		draw_line(Vector2(W / 2 - 18.0, home_y - depth + 22.0 + raid_bob), Vector2(W / 2 - 28.0, home_y - depth + 42.0 + raid_bob), RAIDER_BLUE, 6.0)
		draw_line(Vector2(W / 2 + 18.0, home_y - depth + 22.0 + raid_bob), Vector2(W / 2 + 28.0, home_y - depth + 42.0 + raid_bob), RAIDER_BLUE, 6.0)

	text_c("Raid: %d pts" % raid_score, Vector2(W / 2, home_y + 24.0), 28, ink, false)

func _bot(dt: float) -> void:
	if holding and state != "advance":
		_release()
	elif state == "ready" and not holding:
		_press()
	elif state == "advance" and depth >= bot_release_depth:
		_release()
