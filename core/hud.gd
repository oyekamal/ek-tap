class_name Hud
extends CanvasLayer
## Shared in-game HUD: back button, score, best line, lives, hint, and the game-over card.

signal again_pressed
signal menu_pressed

const BIG := preload("res://fonts/LilitaOne-Regular.ttf")
const BODY := preload("res://fonts/AtkinsonHyperlegible-Bold.ttf")

var _score: Label
var _best: Label
var _lives: HBoxContainer
var _hint: Label
var _over: Control
var _over_title: Label
var _over_score: Label
var _over_note: Label
var _again: Button

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 40
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var back := _button("‹", true)
	back.custom_minimum_size = Vector2(72, 72)
	back.pressed.connect(func(): menu_pressed.emit())
	top.add_child(back)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mid)
	_score = _label("0", BIG, 72)
	mid.add_child(_score)
	_best = _label("", BODY, 26)
	mid.add_child(_best)

	_lives = HBoxContainer.new()
	_lives.custom_minimum_size = Vector2(72, 72)
	_lives.alignment = BoxContainer.ALIGNMENT_END
	_lives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_lives)

	_hint = _label("", BODY, 34)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -140
	_hint.offset_bottom = -80
	root.add_child(_hint)

	# game-over card
	_over = ColorRect.new()
	(_over as ColorRect).color = Color(0, 0, 0, 0.45)
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_over)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFF8EC")
	sb.set_corner_radius_all(36)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 14)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)
	_over_title = _label("", BIG, 60, Color("#1B2A27"))
	v.add_child(_over_title)
	_over_score = _label("", BIG, 120, Color("#1B2A27"))
	v.add_child(_over_score)
	_over_note = _label("", BODY, 30, Color("#45524F"))
	_over_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_over_note)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	_again = _button("Again", false)
	_again.pressed.connect(func(): again_pressed.emit())
	row.add_child(_again)
	var menu := _button("Games", false, true)
	menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu)
	_over.hide()

func show_play(g: MiniGame) -> void:
	_over.hide()
	_hint.text = g.hint
	_hint.show()
	for l in [_score, _best, _hint]:
		l.add_theme_color_override("font_color", g.ink)
	refresh(g)

func hide_hint() -> void:
	_hint.hide()

func refresh(g: MiniGame) -> void:
	_score.text = g.fmt(g.score)
	var b := g.best()
	if b == 0.0:
		_best.text = "no best yet"
	elif g.lower_is_better:
		_best.text = "best " + g.fmt(b)
	elif g.score > b:
		_best.text = "new best!"
	else:
		_best.text = "best %s · %s to go" % [g.fmt(b), g.fmt(b - g.score)]
	for c in _lives.get_children():
		c.queue_free()
	if g.use_lives:
		for i in g.max_lives:
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(22, 22)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var s := StyleBoxFlat.new()
			s.set_corner_radius_all(11)
			s.bg_color = g.ink if i < g.lives else Color(g.ink, 0.0)
			s.border_color = Color(g.ink, 0.5)
			s.set_border_width_all(3)
			dot.add_theme_stylebox_override("panel", s)
			_lives.add_child(dot)

func show_over(g: MiniGame, heading: String, old_best: float) -> void:
	refresh(g)
	_over_title.text = heading if heading != "" else "Game over"
	_over_score.text = g.fmt(g.score)
	var better := old_best == 0.0 or (g.score < old_best if g.lower_is_better else g.score > old_best)
	if old_best == 0.0:
		_over_note.text = "First best set. Now beat it."
	elif better:
		_over_note.text = "New best! Old best was %s." % g.fmt(old_best)
	elif is_equal_approx(g.score, old_best):
		_over_note.text = "Tied your best."
	else:
		_over_note.text = "%s short of your best (%s)." % [g.fmt(absf(old_best - g.score)), g.fmt(old_best)]
	_over.show()
	_again.grab_focus()

func _label(t: String, f: Font, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(t: String, ghost_light: bool, ghost := false) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", BIG if ghost_light else BODY)
	b.add_theme_font_size_override("font_size", 56 if ghost_light else 34)
	b.custom_minimum_size = Vector2(200, 84)
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(42)
	if ghost_light:
		s.bg_color = Color(1, 1, 1, 0.18)
		b.add_theme_color_override("font_color", Color.WHITE)
	elif ghost:
		s.bg_color = Color(0, 0, 0, 0)
		s.border_color = Color("#1B2A27")
		s.set_border_width_all(4)
		b.add_theme_color_override("font_color", Color("#1B2A27"))
	else:
		s.bg_color = Color("#1B2A27")
		b.add_theme_color_override("font_color", Color("#FFF8EC"))
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_hover_color", b.get_theme_color("font_color"))
	b.add_theme_color_override("font_pressed_color", b.get_theme_color("font_color"))
	b.add_theme_color_override("font_focus_color", b.get_theme_color("font_color"))
	return b
