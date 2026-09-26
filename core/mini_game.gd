class_name MiniGame
extends Node2D
## Base for every Ek Tap game. One input: press/release anywhere (touch, mouse, Space).
## A game overrides the settings + the six virtual methods below, and draws everything
## itself in _draw_game() with Godot's draw_* calls (no scenes, no image assets).

signal quit_to_menu

# ---------- settings a game overrides (set them in _init) ----------
var game_id := "base"             ## save key, lowercase, unique
var title := "Game"               ## shown on the menu card and game-over panel
var tagline := ""                 ## one-line pitch shown on the menu card
var bg := Color("#1F2B33")        ## background colour
var ink := Color("#FFFFFF")       ## HUD text colour (must read on bg)
var accent := Color("#FFB31A")    ## menu card accent
var hint := "Hold anywhere"       ## shown until the first press of a run
var lower_is_better := false      ## true for time-based games (fastest wins)
var score_fmt := "%d"             ## e.g. "%.1f s" for times
var use_lives := true
var max_lives := 3

# ---------- virtual methods ----------
func _setup() -> void: pass                 ## reset everything for a fresh run
func _tick(_dt: float) -> void: pass        ## game logic; dt is 0 during hit-stop
func _draw_game() -> void: pass             ## draw the world (W x H, origin top-left)
func _on_press() -> void: pass              ## finger down / Space down
func _on_release() -> void: pass            ## finger up / Space up
func _bot(dt: float) -> void: _default_bot(dt)  ## autoplay for headless testing

# ---------- state a game can read ----------
var W := 720.0
var H := 1280.0
var score := 0.0
var lives := 3
var holding := false
var running := false              ## false while the game-over panel is up
var started := false              ## true after the first press of a run
var time := 0.0                   ## seconds of play this run (frozen during hit-stop)
var rng := RandomNumberGenerator.new()
var font_big: Font = preload("res://fonts/LilitaOne-Regular.ttf")
var font_body: Font = preload("res://fonts/AtkinsonHyperlegible-Bold.ttf")

# ---------- internals ----------
const OVER_DELAY := 0.9   ## seconds between the fail and the game-over card
var _run_id := 0
var _trauma := 0.0
var _shake_off := Vector2.ZERO
var _freeze_left := 0.0
var _parts: Array = []
var _popups: Array = []
var _touches := {}
var _autoplay := false
var _bot_t := 0.0
var _bot_hold := false
var _hud: Hud

func _ready() -> void:
	_autoplay = "--autoplay" in OS.get_cmdline_user_args() or "--autoplay" in OS.get_cmdline_args()
	_hud = Hud.new()
	add_child(_hud)
	_hud.again_pressed.connect(start_run)
	_hud.menu_pressed.connect(func(): quit_to_menu.emit())
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	start_run()

func _on_resize() -> void:
	var s := get_viewport_rect().size
	W = s.x
	H = s.y

func start_run() -> void:
	_run_id += 1
	rng.randomize()
	score = 0.0
	lives = max_lives
	time = 0.0
	started = false
	running = true
	holding = false
	_touches.clear()
	_parts.clear()
	_popups.clear()
	_trauma = 0.0
	_setup()
	_hud.show_play(self)

# ---------- helpers for games ----------
func add_score(n: float) -> void:
	score += n
	_hud.refresh(self)

## Costs a life; ends the run when none are left. Returns true if the run ended.
func lose_life() -> bool:
	if not use_lives:
		end_run()
		return true
	lives -= 1
	_hud.refresh(self)
	if lives <= 0:
		end_run()
		return true
	return false

func end_run(heading := "") -> void:
	if not running:
		return
	running = false
	holding = false
	Sfx.loop_stop()
	var old := Save.submit(game_id, score, lower_is_better)
	# let the failure moment play out (freeze on the cause) before the card covers it
	var run := _run_id
	get_tree().create_timer(OVER_DELAY).timeout.connect(func():
		if run == _run_id and not running:
			_hud.show_over(self, heading, old))

func shake(amount: float) -> void:
	_trauma = clampf(maxf(_trauma, amount), 0.0, 1.0)

func hitstop(ms: int) -> void:
	_freeze_left = ms / 1000.0

func popup(text: String, sub := "", pos := Vector2(-1, -1), color := Color(-1, 0, 0)) -> void:
	if pos.x < 0:
		pos = Vector2(W / 2, H * 0.3)
	_popups.append({"text": text, "sub": sub, "pos": pos, "t": 0.0, "color": ink if color.r < 0 else color})

func burst(pos: Vector2, color: Color, n := 24, power := 1.0) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var s := rng.randf_range(120.0, 480.0) * power
		_parts.append({"p": pos, "v": Vector2(cos(a), sin(a)) * s, "t": 0.0,
			"life": rng.randf_range(0.5, 1.0), "c": color, "w": rng.randf_range(5.0, 12.0), "r": rng.randf() * TAU})

## Use instead of draw_set_transform inside _draw_game (keeps the screen shake).
func set_xform(pos := Vector2.ZERO, rot := 0.0, scl := Vector2.ONE) -> void:
	draw_set_transform(_shake_off + pos, rot, scl)

func best() -> float:
	return Save.best(game_id)

func fmt(v: float) -> String:
	return score_fmt % v

## Centered text. size in px; big=true uses the display font.
func text_c(s: String, pos: Vector2, size: int, color: Color, big := true) -> void:
	var f := font_big if big else font_body
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(pos.x - w / 2.0, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

# ---------- input ----------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = true
			if _touches.size() == 1:
				_press()
		else:
			_touches.erase(e.index)
			if _touches.is_empty():
				_release()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.keycode == KEY_SPACE and not e.echo:
		if not running:
			if e.pressed:
				start_run()
			return
		if e.pressed:
			_press()
		else:
			_release()
		get_viewport().set_input_as_handled()

func _press() -> void:
	if not running or holding:
		return
	holding = true
	if not started:
		started = true
		_hud.hide_hint()
	_on_press()

func _release() -> void:
	if not holding:
		return
	holding = false
	if running:
		_on_release()

# ---------- loop ----------
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if _freeze_left > 0.0:
		_freeze_left -= delta
		dt = 0.0
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	if running:
		if started:
			time += dt
		if _autoplay:
			_bot(dt)
		_tick(dt)
	elif _autoplay:
		_bot_t += delta
		if _bot_t > OVER_DELAY + 1.2:
			_bot_t = 0.0
			start_run()
	for p in _parts:
		p.t += delta
		p.v *= 0.96
		p.v.y += 700.0 * delta
		p.p += p.v * delta
		p.r += delta * 7.0
	_parts = _parts.filter(func(p): return p.t < p.life)
	for p in _popups:
		p.t += delta
	_popups = _popups.filter(func(p): return p.t < 1.1)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), bg)
	var amt := _trauma * _trauma * 16.0
	_shake_off = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	draw_set_transform(_shake_off)
	_draw_game()
	for p in _parts:
		var a: float = 1.0 - p.t / p.life
		draw_set_transform(p.p, p.r)
		draw_rect(Rect2(-p.w / 2, -p.w / 4, p.w, p.w / 2), Color(p.c, a))
	draw_set_transform(Vector2.ZERO)
	for p in _popups:
		var k: float = minf(1.0, p.t * 6.0)
		var fade: float = 1.0 if p.t < 0.7 else 1.0 - (p.t - 0.7) / 0.4
		var y: float = p.pos.y - p.t * 30.0
		text_c(p.text, Vector2(p.pos.x, y), int(64 * (0.7 + 0.3 * k)), Color(p.color, fade))
		if p.sub != "":
			text_c(p.sub, Vector2(p.pos.x, y + 40), 28, Color(p.color, fade * 0.8), false)

func _default_bot(dt: float) -> void:
	_bot_t -= dt
	if _bot_t <= 0.0:
		_bot_hold = not _bot_hold
		_bot_t = rng.randf_range(0.4, 1.2) if _bot_hold else rng.randf_range(0.3, 0.8)
		if _bot_hold:
			_press()
		else:
			_release()
