extends Node
## Ek Tap: the game-picker menu. Tap a card to play; back returns here.
## Run one game directly (for testing): godot --path . -- --game=<id> | --game-path=res://games/x.gd [--autoplay]

const GAMES := [
	"res://games/almost_pop.gd",
	"res://games/dhaba_pour.gd",
	"res://games/rope_race.gd",
	"res://games/kite_cutter.gd",
	"res://games/tawa_flip.gd",
	"res://games/cricket_edge.gd",
	"res://games/orbit_sling.gd",
	"res://games/scale_call.gd",
	"res://games/wire_walker.gd",
	"res://games/kabaddi_raid.gd",
	"res://games/bazaar_bell.gd",
	"res://games/chowk_crossing.gd",
]
const BIG := preload("res://fonts/LilitaOne-Regular.ttf")
const BODY := preload("res://fonts/AtkinsonHyperlegible-Bold.ttf")

var _menu: Control
var _game: MiniGame
var _info := []   # [{path, id, title, tagline, bg, ink, accent, fmt, lower}]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#101820"))
	for path in GAMES:
		if not ResourceLoader.exists(path):
			continue
		var g: MiniGame = load(path).new()
		_info.append({"path": path, "id": g.game_id, "title": g.title, "tagline": g.tagline,
			"bg": g.bg, "ink": g.ink, "accent": g.accent, "fmt": g.score_fmt})
		g.free()
	_build_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--game-path="):   # any game file, registered or not (testing)
			_open(a.trim_prefix("--game-path="))
		if a.begins_with("--game="):
			var id := a.trim_prefix("--game=")
			for i in _info:
				if i.id == id:
					_open(i.path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _game:
			_close()
		else:
			get_tree().quit()

func _open(path: String) -> void:
	_menu.hide()
	_game = load(path).new()
	_game.quit_to_menu.connect(_close)
	add_child(_game)

func _close() -> void:
	if _game:
		Sfx.loop_stop()
		_game.queue_free()
		_game = null
	_build_menu()

func _build_menu() -> void:
	if _menu:
		_menu.queue_free()
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var bg := ColorRect.new()
	bg.color = Color("#101820")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_bottom", 48)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Ek Tap"
	title.add_theme_font_override("font", BIG)
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", Color("#FFF8EC"))
	col.add_child(title)
	var sub := Label.new()
	sub.text = "%d games. One finger each." % _info.size()
	sub.add_theme_font_override("font", BODY)
	sub.add_theme_font_size_override("font_size", 32)
	sub.add_theme_color_override("font_color", Color("#9FB3AE"))
	col.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	col.add_child(grid)
	for i in _info:
		grid.add_child(_card(i))

func _card(i: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 300)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = i.bg
	s.set_corner_radius_all(32)
	s.border_color = i.accent
	s.border_width_bottom = 10
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, s)
	b.pressed.connect(_open.bind(i.path))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26
	v.offset_right = -26
	v.offset_top = 26
	v.offset_bottom = -26
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	b.add_child(v)
	var t := Label.new()
	t.text = i.title
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_override("font", BIG)
	t.add_theme_font_size_override("font_size", 50)
	t.add_theme_color_override("font_color", i.ink)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var tag := Label.new()
	tag.text = i.tagline
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag.add_theme_font_override("font", BODY)
	tag.add_theme_font_size_override("font_size", 25)
	tag.add_theme_color_override("font_color", Color(i.ink, 0.8))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tag)
	var best: float = Save.best(i.id)
	var bl := Label.new()
	bl.text = ("best " + (i.fmt % best)) if best != 0.0 else "new"
	bl.add_theme_font_override("font", BODY)
	bl.add_theme_font_size_override("font_size", 26)
	bl.add_theme_color_override("font_color", i.accent)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bl)
	return b
