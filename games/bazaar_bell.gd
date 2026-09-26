extends MiniGame
## Bazaar Bell: hold to keep haggling (the bell rings, price drops one step,
## suspicion rises), release to lock in the current price and bank the
## savings. Suspicion hitting 100% cancels the whole deal.

const RING_INTERVAL := 0.35     # seconds per bell ring while held
const RING_SUSPICION := 9.0     # suspicion % added per ring
const PRICE_STEP_FRAC := 0.07   # price cut per ring (fraction of current price)
const PRICE_FLOOR_FRAC := 0.15  # price can't drop below this fraction of original
const DECAY_RATE := 35.0        # suspicion %/s recovered while not holding
const RESULT_PAUSE := 0.75
const BASE_PRICE := 220.0
const GOOD_COLOR := Color("#C97A2B")
const BAR_BG := Color("#5A3A18")

var round_i := 0
var price0 := 0.0
var price := 0.0
var suspicion := 0.0
var ring_t := 0.0
var state := "ready"    # ready | haggling | result
var state_t := 0.0
var caught := false
var bot_release_susp := 60.0
var price_pulse := 0.0

func _init() -> void:
	game_id = "bazaar_bell"
	title = "Bazaar Bell"
	tagline = "Ring the bell to haggle, lock in before the shopkeeper catches you."
	bg = Color("#F2B53A")
	ink = Color("#3A1F0B")
	accent = Color("#C9342B")
	hint = "Hold to haggle. Release to lock in the price."

func _setup() -> void:
	round_i = 0
	_new_item()

func _new_item() -> void:
	price0 = maxf(80.0, BASE_PRICE + round_i * 12.0 + rng.randf_range(-15.0, 15.0))
	price = price0
	suspicion = 0.0
	ring_t = 0.0
	state = "ready"
	state_t = 0.0

func _on_press() -> void:
	if state == "ready":
		state = "haggling"
		state_t = 0.0
		ring_t = 0.0
		bot_release_susp = 105.0 if rng.randf() < 0.22 else rng.randf_range(35.0, 92.0)
		Sfx.loop_start("tri", 500.0, 0.12)

func _on_release() -> void:
	if state == "haggling":
		_lock_in()

func _lock_in() -> void:
	Sfx.loop_stop()
	var savings := price0 - price
	add_score(int(round(savings)))
	Sfx.chord([660.0, 880.0])
	burst(Vector2(W / 2, H * 0.5), Color("#FFD34D"), 18, 0.5)
	popup("LOCKED!", "saved Rs %d" % int(round(savings)), Vector2(W / 2, H * 0.20))
	caught = false
	state = "result"
	state_t = 0.0

func _do_ring() -> void:
	var ramp := RING_SUSPICION + round_i * 0.4
	suspicion = minf(100.0, suspicion + ramp)
	price = maxf(price0 * PRICE_FLOOR_FRAC, price * (1.0 - PRICE_STEP_FRAC))
	price_pulse = 1.0
	Sfx.tone(880.0, 0.06, "tri", 0.35)

func _get_caught() -> void:
	Sfx.loop_stop()
	Sfx.tone(0, 0.2, "noise", 0.7)
	hitstop(100)
	shake(0.7)
	popup("NO DEAL!", "caught haggling", Vector2(W / 2, H * 0.20))
	caught = true
	state = "result"
	state_t = 0.0
	lose_life()

func _tick(dt: float) -> void:
	state_t += dt
	match state:
		"haggling":
			ring_t += dt
			while ring_t >= RING_INTERVAL and state == "haggling":
				ring_t -= RING_INTERVAL
				_do_ring()
				if suspicion >= 100.0:
					_get_caught()
		"result":
			if state_t > RESULT_PAUSE and running:
				round_i += 1
				_new_item()
	if state != "haggling":
		suspicion = maxf(0.0, suspicion - DECAY_RATE * dt)
	price_pulse = maxf(0.0, price_pulse - dt * 6.0)

func _draw_game() -> void:
	var cx := W / 2
	draw_rect(Rect2(W * 0.1, H * 0.62, W * 0.8, H * 0.06), Color("#7A4A1E"))
	draw_rect(Rect2(W * 0.1, H * 0.62, W * 0.8, H * 0.06), ink, false, 3.0)

	var fill := 0.4 if price0 <= 0.0 else price / price0
	var gr := 46.0 + 28.0 * fill
	draw_circle(Vector2(cx, H * 0.60), gr, GOOD_COLOR)
	draw_circle(Vector2(cx, H * 0.60 - gr * 0.5), gr * 0.35, Color("#8A5A2B"))

	var sk := Vector2(cx, H * 0.44)
	draw_colored_polygon(PackedVector2Array([sk + Vector2(-46, 70), sk + Vector2(46, 70), sk + Vector2(30, 0), sk + Vector2(-30, 0)]), ink)
	draw_circle(sk + Vector2(0, -22), 30.0, ink)

	var bar := Rect2(W * 0.18, H * 0.28, W * 0.64, 26.0)
	draw_rect(bar, BAR_BG)
	var sfrac := suspicion / 100.0
	var scol := Color("#3FBE5E").lerp(Color("#E63B2E"), sfrac)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * sfrac, bar.size.y)), scol)
	draw_rect(bar, ink, false, 3.0)
	text_c("suspicion", Vector2(cx, bar.position.y - 32.0), 22, ink, false)

	var pulse := 1.0 + (0.12 * sin(ring_t / RING_INTERVAL * PI)) if state == "haggling" else 1.0
	set_xform(Vector2(W * 0.85, H * 0.5), 0.0, Vector2(pulse, pulse))
	draw_circle(Vector2.ZERO, 26.0, Color("#B8860B"))
	draw_circle(Vector2(0, -18), 6.0, Color("#B8860B"))
	set_xform()

	var psize := 64 + int(10.0 * price_pulse)
	text_c("Rs %d" % int(round(price)), Vector2(cx, H * 0.75), psize, ink)

	if state == "result" and caught:
		set_xform(Vector2(cx, H * 0.75), -0.18)
		draw_rect(Rect2(-150, -36, 300, 72), Color(0.9, 0.15, 0.1, 0.92))
		draw_rect(Rect2(-150, -36, 300, 72), Color.WHITE, false, 4.0)
		text_c("NO DEAL", Vector2(0, -20), 34, Color.WHITE)
		set_xform()

func _bot(dt: float) -> void:
	if holding and state != "haggling":
		_release()
	elif state == "ready" and not holding:
		_press()
	elif state == "haggling" and suspicion >= bot_release_susp:
		_release()
