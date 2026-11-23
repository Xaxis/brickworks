## The studio's first screen for somebody signed in (studiostart, docs/PLAN.md
## row 1), in place of the example car: where they left off and what came
## back from everyone else, each one tap from the model.
##
##   Continue: the models they saved last, here or on any device the
##     account keeps them from (CloudModels), opened with one tap.
##   This week's quick build (api/_prompts.js): its template opened as their
##     own copy with one tap, as its page's Start does.
##   What came back on their models: comments (one on a part opens the model
##     with the part lit), photos of builds and remixes, newest first, read
##     without marking anything read (api/people.js ?op=studio_start).
##   The gallery: its own first page, and a search, each model opened as a
##     copy of their own (Main._start_copy, as Open in Brickworks makes one).
##
## Studio's start page and Fusion's home do the first two; no CAD tells its
## builder what came back from the people who saw the model, and none opens
## the gallery inside the editor. Every CAD but this one starts a returning
## builder where it starts a stranger.
##
## Over the model, on a scrim: one click on the scrim, Escape, a shortcut or
## the model changed by anyone (a part put down, Claude building) puts it
## away, and it never comes back by itself in that tab. Its own tick says
## whether the studio opens on it (ShellPrefs "studio_start").
class_name StudioStart
extends Control

## The card's widest, and the width under which it is one column, as a
## phone's sheet.
const WIDEST := 960.0
const NARROW := 700.0
## How many of each it shows.
const CONTINUE_MOST := 4
const CAME_MOST := 5
const FOUND_MOST := 6
## The models' pictures, 4:3 as the gallery's cards.
const PICTURE := Vector2(176, 132)
const SMALL := Vector2(56, 42)
## A search typed is asked for once the typing stops this long.
const TYPED_WAIT := 0.45
## A file's head read for its link: its metas come before its first part.
const HEAD_LINES := 400

## Who, and what everything is asked through (Main sets them).
var shared: SharedModels
var store: ModelStore
var account: Account
## Fetches the models' pictures (ModelLibrary.fetch).
var pictures: ModelLibrary
## What each choice does (Main's): open_saved(path), copy(id), came(item),
## begin_new().
var open_saved: Callable = Callable()
var copy: Callable = Callable()
var came_wanted: Callable = Callable()
var begin_new: Callable = Callable()

## Put away: by a choice made, or by the person ("closed", "chosen").
signal closed(how: String)

## When it was shown, and when it first held three real things (a model of
## theirs, a notice, the week's build, a gallery model), in ticks; -1 till then.
var shown_ms: int = -1
var filled_ms: int = -1
## What the server said ({ready, came, prompt}), and how asking went:
## "" not asked, "asking", "ok", "away".
var answer: Dictionary = {}
var asked: String = ""
## The gallery's models shown, and what they were found for.
var found: Array = []
var found_for: String = ""
var finding: String = ""
## The models listed in Continue: {name, path, bricks, modified, link}.
var models: Array = []
## The last choice made, for a check: {what, id, path}.
var chosen: Dictionary = {}

## Each saved file's link as read: path -> [modified, link].
static var _links: Dictionary = {}
## Each picture fetched: address -> Texture2D (null: none there).
static var _covers: Dictionary = {}

var _scrim: ColorRect
var _card: PanelContainer
var _scroll: ScrollContainer
var _title: Label
var _close: Button
var _new: Button
var _continue: GridContainer
var _continue_none: Label
var _middle: GridContainer
var _prompt_box: VBoxContainer
var _came_list: VBoxContainer
var _search: LineEdit
var _found_title: Label
var _found_grid: GridContainer
var _found_said: Label
var _keep: CheckBox
var _typed: Timer
var _named: Dictionary = {}


func _ready() -> void:
	name = "StudioStart"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim = ColorRect.new()
	_scrim.color = Color(0.02, 0.03, 0.05, 0.55)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(func(event: InputEvent) -> void:
		var press: InputEventMouseButton = event as InputEventMouseButton
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if (press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT) \
				or (touch != null and touch.pressed):
			close("closed"))
	add_child(_scrim)
	_card = PanelContainer.new()
	_card.name = "StudioStartCard"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.105, 0.115, 0.14, 0.985)
	face.border_color = Look.EDGE
	face.set_border_width_all(1)
	face.set_corner_radius_all(14)
	face.shadow_color = Color(0, 0, 0, 0.45)
	face.shadow_size = 18
	face.content_margin_left = 22
	face.content_margin_right = 22
	face.content_margin_top = 16
	face.content_margin_bottom = 16
	_card.add_theme_stylebox_override("panel", face)
	add_child(_card)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	_scroll.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	_title = _label("Welcome back", 21, Color(0.97, 0.97, 0.98))
	titles.add_child(_title)
	titles.add_child(_label("Pick up where you left off, or see what came back from other builders.", 13,
		Look.GREYED, true))
	_new = _button("New model", false)
	_new.tooltip_text = "An empty baseplate"
	_new.pressed.connect(func() -> void:
		_chose({"what": "new"})
		if begin_new.is_valid():
			begin_new.call())
	head.add_child(_new)
	_close = _button("✕", false)
	_close.tooltip_text = "Put this away (Esc): the model is behind it"
	_close.pressed.connect(func() -> void: close("closed"))
	head.add_child(_close)
	_name("start_new", _new)
	_name("start_close", _close)

	column.add_child(_section("Continue"))
	_continue = GridContainer.new()
	_continue.add_theme_constant_override("h_separation", 12)
	_continue.add_theme_constant_override("v_separation", 12)
	column.add_child(_continue)
	_continue_none = _label("Nothing saved yet: a model you save is here next time, on any device you sign in on.",
		13, Look.GREYED, true)
	_continue_none.visible = false
	column.add_child(_continue_none)

	_middle = GridContainer.new()
	_middle.add_theme_constant_override("h_separation", 18)
	_middle.add_theme_constant_override("v_separation", 14)
	column.add_child(_middle)
	_prompt_box = VBoxContainer.new()
	_prompt_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_box.add_theme_constant_override("separation", 6)
	_middle.add_child(_prompt_box)
	var came_side := VBoxContainer.new()
	came_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	came_side.add_theme_constant_override("separation", 6)
	_middle.add_child(came_side)
	came_side.add_child(_section("What came back on your models"))
	_came_list = VBoxContainer.new()
	_came_list.add_theme_constant_override("separation", 4)
	came_side.add_child(_came_list)

	column.add_child(_section("Find in the gallery"))
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	column.add_child(search_row)
	_search = LineEdit.new()
	_search.name = "StudioStartSearch"
	_search.placeholder_text = "Search: a tug, a castle, a 6-wide car…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size = Vector2(0, 34)
	_search.max_length = 100
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", 14)
	_search.text_submitted.connect(func(_words: String) -> void: _find_now())
	_search.text_changed.connect(func(_words: String) -> void: _typed.start())
	search_row.add_child(_search)
	var go := _button("Search", false)
	go.pressed.connect(_find_now)
	search_row.add_child(go)
	_name("start_search", _search)
	_name("start_search_go", go)
	_typed = Timer.new()
	_typed.one_shot = true
	_typed.wait_time = TYPED_WAIT
	_typed.timeout.connect(_find_now)
	add_child(_typed)
	_found_title = _label("", 12, Look.GREYED)
	column.add_child(_found_title)
	_found_grid = GridContainer.new()
	_found_grid.add_theme_constant_override("h_separation", 12)
	_found_grid.add_theme_constant_override("v_separation", 12)
	column.add_child(_found_grid)
	_found_said = _label("", 13, Look.GREYED, true)
	_found_said.visible = false
	column.add_child(_found_said)

	_keep = CheckBox.new()
	_keep.text = "Open the studio on this screen"
	_keep.focus_mode = Control.FOCUS_NONE
	_keep.add_theme_font_size_override("font_size", 12)
	_keep.button_pressed = str(ShellPrefs.value("studio_start")) != "off"
	_keep.toggled.connect(func(on: bool) -> void: ShellPrefs.put("studio_start", "on" if on else "off"))
	column.add_child(_keep)
	_name("start_keep", _keep)

	resized.connect(_lay)
	_fill_prompt()
	_fill_came()


## Shown, with [param saved] (ModelStore.Entry, newest first) in Continue,
## and what the server says asked for at once.
func open(saved: Array) -> void:
	shown_ms = Time.get_ticks_msec()
	filled_ms = -1
	visible = true
	_lay()
	set_models(saved)
	_title.text = "Welcome back"
	_ask()
	_find("")


## Continue's models: [param saved] as ModelStore lists them, its first
## few, each with its link where it has one (its picture is its card's).
func set_models(saved: Array) -> void:
	models.clear()
	for entry: Variant in saved:
		if models.size() >= CONTINUE_MOST:
			break
		if entry is ModelStore.Entry and not (entry as ModelStore.Entry).example:
			var one: ModelStore.Entry = entry
			models.append({"name": one.name, "path": one.path, "bricks": one.bricks, "modified": one.modified,
				"link": link_of(one.path)})
	_fill_continue()


func close(how: String = "closed") -> void:
	if not visible:
		return
	visible = false
	_typed.stop()
	closed.emit(how)


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		close("closed")
		get_viewport().set_input_as_handled()
		return
	# A shortcut (Ctrl+O, Ctrl+N, …) is the person going on with the studio:
	# this goes, and the key does what it does.
	if (key.ctrl_pressed or key.meta_pressed) and not _search.has_focus():
		close("closed")


# -- asking ------------------------------------------------------------------------

func _ask() -> void:
	if shared == null or account == null or not account.signed_in():
		asked = "away"
		_fill_prompt()
		_fill_came()
		return
	asked = "asking"
	var token: String = await account.access_token()
	var got: Dictionary = await shared.studio_start(token) if not token.is_empty() else {"code": 401}
	var body: Variant = got.get("body")
	if int(got.get("code", 0)) == 200 and body is Dictionary:
		answer = body
		asked = "ok"
	else:
		asked = "away"
	_fill_prompt()
	_fill_came()


func _find_now() -> void:
	_typed.stop()
	_find(_search.text.strip_edges())


## The gallery's models for [param words] (its own first page for none).
func _find(words: String) -> void:
	if shared == null or finding == words and finding != "":
		return
	finding = words
	_found_title.text = "Looking…" if words.is_empty() else "Looking for “%s”…" % words
	# Searched as them, so nobody they blocked is in it; the first page as
	# anybody, which the gallery's cache answers at once.
	var token: String = await account.access_token() \
		if not words.is_empty() and account != null and account.signed_in() else ""
	var got: Dictionary = await shared.gallery(words, token)
	if finding != words:
		return
	finding = ""
	var body: Variant = got.get("body")
	found.clear()
	if int(got.get("code", 0)) == 200 and body is Dictionary and (body as Dictionary).get("models") is Array:
		for one: Variant in (body as Dictionary)["models"]:
			if found.size() >= FOUND_MOST:
				break
			if one is Dictionary and SharedModels.is_id(str((one as Dictionary).get("id", ""))):
				found.append(one)
	found_for = words
	_fill_found(int(got.get("code", 0)) == 200)


# -- what each part shows ----------------------------------------------------------

func _fill_continue() -> void:
	_clear(_continue)
	_continue_none.visible = models.is_empty()
	var n: int = 0
	for one: Dictionary in models:
		var facts: String = "%s · %s" % [_parts_words(int(one["bricks"])), _ago_unix(int(one["modified"]))]
		var picture: String = _picture_of(str(one["link"])) if not str(one["link"]).is_empty() else ""
		var tile: Button = _tile(str(one["name"]), facts, picture, PICTURE)
		tile.tooltip_text = "Open “%s”" % str(one["name"])
		var path: String = str(one["path"])
		tile.pressed.connect(func() -> void:
			_chose({"what": "continue", "path": path})
			if open_saved.is_valid():
				open_saved.call(path))
		_continue.add_child(tile)
		_name("start_continue_%d" % n, tile)
		n += 1
	_counted()


func _fill_prompt() -> void:
	_clear(_prompt_box)
	_prompt_box.add_child(_section("This week's quick build"))
	var prompt: Variant = answer.get("prompt")
	if not prompt is Dictionary:
		_prompt_box.add_child(_label("Looking…" if asked == "asking" or asked.is_empty()
			else ("No quick build this week: the month's challenge is on its page." if asked == "ok"
				else "Brickworks could not be reached just now."), 13, Look.GREYED, true))
		_counted()
		return
	var week: Dictionary = prompt
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _tile_face(Color(0.20, 0.42, 0.85, 0.14), Color(0.56, 0.74, 1.0, 0.35)))
	_prompt_box.add_child(box)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	box.add_child(inside)
	var title := _label(str(week.get("title", "")), 17, Color(0.97, 0.97, 0.98), true)
	inside.add_child(title)
	var brief := _label(str(week.get("brief", "")).left(240), 13, Color(0.86, 0.88, 0.92), true)
	brief.max_lines_visible = 4
	inside.add_child(brief)
	var facts := PackedStringArray()
	var day: String = SharedModels.day_words(str(week.get("ends_on", "")))
	if not day.is_empty():
		facts.append("Publish by %s" % day)
	var entries: int = int(week.get("entries", 0)) if week.get("entries") is float or week.get("entries") is int else 0
	facts.append("1 entry so far" if entries == 1 else "%d entries so far" % entries)
	inside.add_child(_label(" · ".join(facts), 12, Look.GREYED, true))
	var start: String = str(week.get("start", "")) if week.get("start") is String else ""
	var template: String = start.get_slice("copy=", 1).get_slice("&", 0) if start.contains("copy=") else ""
	var go := _button("Start from its template", true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.disabled = not SharedModels.is_id(template)
	go.tooltip_text = "Your own copy of its template, on the baseplate: publish it to enter"
	go.pressed.connect(func() -> void:
		_chose({"what": "prompt", "id": template})
		if copy.is_valid():
			copy.call(template))
	inside.add_child(go)
	_name("start_prompt", go)
	_counted()


func _fill_came() -> void:
	_clear(_came_list)
	var came: Array = answer.get("came", []) if answer.get("came") is Array else []
	if came.is_empty():
		_came_list.add_child(_label("Looking…" if asked == "asking" or asked.is_empty()
			else ("Nothing yet. Share a model, and comments, builds and remixes of it come back here."
				if asked == "ok" else "Brickworks could not be reached just now."), 13, Look.GREYED, true))
		_counted()
		return
	var n: int = 0
	for one: Variant in came:
		if n >= CAME_MOST:
			break
		if not one is Dictionary:
			continue
		var item: Dictionary = one
		_came_list.add_child(_came_row(item, n))
		n += 1
	_counted()


func _came_row(item: Dictionary, n: int) -> Button:
	var row := Button.new()
	row.name = "StartCame%d" % n
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.custom_minimum_size = Vector2(0, 58)
	row.clip_contents = true
	_face_button(row, Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.08))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8
	line.offset_right = -8
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var picture := TextureRect.new()
	picture.custom_minimum_size = SMALL
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(picture)
	var where: String = str(item.get("picture", "")) if item.get("picture") is String else ""
	if not where.is_empty():
		_picture_into(picture, _absolute(where))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 1)
	line.add_child(words)
	var who: String = str(item.get("who", "")) if item.get("who") is String else ""
	var said: String = str(item.get("line", "")).replace("{who}", who if not who.is_empty() else "A builder")
	var head := _label(said, 13, Color(0.95, 0.95, 0.96))
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(head)
	var quote: String = str(item.get("said", "")) if item.get("said") is String else ""
	if not quote.is_empty():
		var quoted := _label("“%s”" % quote, 12, Color(0.84, 0.86, 0.9))
		quoted.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.add_child(quoted)
	var facts := PackedStringArray([str(item.get("name", ""))])
	var when: String = _ago_iso(str(item.get("at", "")))
	if not when.is_empty():
		facts.append(when)
	if bool(item.get("pinned", false)):
		facts.append("on a part: shows it")
	var meta := _label(" · ".join(facts), 11, Look.GREYED)
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(meta)
	if bool(item.get("new", false)):
		var dot := ColorRect.new()
		dot.color = Color("#e8590c")
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(dot)
	var kind: String = str(item.get("kind", ""))
	row.tooltip_text = {"comment": "Open the model at this comment's part" if bool(item.get("pinned", false))
		else "Open the model", "photo": "See the photo on its page", "remix": "See the remix on its page"}.get(kind, "")
	row.pressed.connect(func() -> void:
		_chose({"what": "came", "id": str(item.get("model", "")), "comment": int(item.get("comment", 0)),
			"kind": kind})
		if came_wanted.is_valid():
			came_wanted.call(item))
	_name("start_came_%d" % n, row)
	return row


func _fill_found(answered: bool) -> void:
	_clear(_found_grid)
	_found_title.text = ("New in the gallery" if found_for.is_empty() else "Found for “%s”" % found_for) \
		if not found.is_empty() else ""
	_found_said.visible = found.is_empty()
	_found_said.text = ("Nothing in the gallery matches. Try fewer words." if answered
		else "The gallery could not be reached just now.")
	var n: int = 0
	for one: Dictionary in found:
		var id: String = str(one["id"])
		var by: String = str(one.get("author", "")) if one.get("author") is String else ""
		var facts: String = _parts_words(int(one.get("parts", 0)) if one.get("parts") is float
			or one.get("parts") is int else 0)
		if not by.is_empty():
			facts = "by %s · %s" % [by, facts]
		var thumb: String = str(one["thumb"]) if one.get("thumb") is String else ""
		var tile: Button = _tile(str(one.get("name", "?")), facts,
			thumb if thumb.begins_with("http") else _picture_of(id), PICTURE * 0.82)
		tile.tooltip_text = "A copy of “%s” of your own, on the baseplate" % str(one.get("name", "?"))
		tile.pressed.connect(func() -> void:
			_chose({"what": "copy", "id": id})
			if copy.is_valid():
				copy.call(id))
		_found_grid.add_child(tile)
		_name("start_found_%d" % n, tile)
		n += 1
	_counted()


## Three real things shown (a model of theirs, a notice, the week's build,
## a gallery model): the moment is kept, for the first screen's time.
func _counted() -> void:
	if filled_ms < 0 and visible and real_items() >= 3:
		filled_ms = Time.get_ticks_msec()


func real_items() -> int:
	var came: Array = answer.get("came", []) if answer.get("came") is Array else []
	return models.size() + mini(came.size(), CAME_MOST) + (1 if answer.get("prompt") is Dictionary else 0) \
		+ found.size()


func _chose(what: Dictionary) -> void:
	chosen = what
	close("chosen")


# -- laid out ------------------------------------------------------------------------

func _lay() -> void:
	if _card == null:
		return
	var room: Vector2 = size
	if room.x <= 0.0:
		return
	var narrow: bool = room.x < NARROW
	var margin: float = 8.0 if narrow else 28.0
	var wide: float = minf(WIDEST, room.x - margin * 2.0)
	var tall: float = room.y - margin * 2.0 if narrow else minf(room.y - margin * 2.0, 760.0)
	_card.position = Vector2(floorf((room.x - wide) * 0.5), floorf((room.y - tall) * 0.5))
	_card.size = Vector2(wide, tall)
	var inner: float = wide - 44.0
	_continue.columns = clampi(floori((inner + 12.0) / (PICTURE.x + 12.0)), 2, CONTINUE_MOST)
	_found_grid.columns = clampi(floori((inner + 12.0) / (PICTURE.x * 0.82 + 12.0)), 2, FOUND_MOST)
	_middle.columns = 1 if narrow else 2
	for tile: Control in _continue.get_children() + _found_grid.get_children():
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# -- the pieces ----------------------------------------------------------------------

func _tile(title: String, facts: String, picture: String, picture_size: Vector2) -> Button:
	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.clip_contents = true
	tile.custom_minimum_size = Vector2(picture_size.x, picture_size.y + 50.0)
	_face_button(tile, Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.09))
	var inside := VBoxContainer.new()
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 6
	inside.offset_top = 6
	inside.offset_right = -6
	inside.offset_bottom = -6
	inside.add_theme_constant_override("separation", 3)
	tile.add_child(inside)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(0, picture_size.y - 12.0)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	var ground := StyleBoxFlat.new()
	ground.bg_color = Color(0.16, 0.18, 0.22)
	ground.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", ground)
	inside.add_child(frame)
	var initial := _label(title.left(1).to_upper(), 34, Color(1, 1, 1, 0.22))
	initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(initial)
	var shown := TextureRect.new()
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(shown)
	if not picture.is_empty():
		_picture_into(shown, picture, initial)
	var name_line := _label(title, 13, Color(0.96, 0.96, 0.97))
	name_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inside.add_child(name_line)
	var facts_line := _label(facts, 11, Look.GREYED)
	facts_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inside.add_child(facts_line)
	return tile


func _tile_face(fill: Color, edge: Color) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = fill
	face.border_color = edge
	face.set_border_width_all(1)
	face.set_corner_radius_all(10)
	face.content_margin_left = 14
	face.content_margin_right = 14
	face.content_margin_top = 12
	face.content_margin_bottom = 12
	return face


func _face_button(button: Button, fill: Color, lit: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		face.bg_color = lit if state == "hover" or state == "pressed" else fill
		face.border_color = Color(Look.ACCENT, 0.7) if state == "hover" else Color(1, 1, 1, 0.07)
		face.set_border_width_all(1)
		face.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state, face)


func _button(words: String, main: bool) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(36, 34)
	button.add_theme_font_size_override("font_size", 13)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		var base: Color = Look.STRONG if main else Color(1, 1, 1, 0.08)
		face.bg_color = base.lightened(0.10) if state == "hover" else (base.darkened(0.12) if state == "pressed"
			else (Color(base, 0.4) if state == "disabled" else base))
		face.set_corner_radius_all(8)
		face.content_margin_left = 14
		face.content_margin_right = 14
		face.content_margin_top = 6
		face.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, face)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	return button


func _section(words: String) -> Label:
	return _label(words, 15, Color(0.97, 0.97, 0.98))


func _label(words: String, font_size: int, colour: Color, wrap: bool = false) -> Label:
	var made := Label.new()
	made.text = words
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", colour)
	if wrap:
		made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		made.custom_minimum_size = Vector2(120, 0)
	return made


func _clear(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _name(key: String, control: Control) -> void:
	_named[key] = control


## Its controls by name, for a browser check (Main._page_controls): only
## those on show.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	if not visible:
		return out
	for key: String in _named:
		var control: Control = _named[key] as Control
		if is_instance_valid(control) and control.is_visible_in_tree():
			out[key] = control
	return out


## What it shows, for a check (Main._tell_page).
func page_state() -> Dictionary:
	var came: Array = answer.get("came", []) if answer.get("came") is Array else []
	var pins: int = 0
	for one: Variant in came:
		pins += 1 if one is Dictionary and bool((one as Dictionary).get("pinned", false)) else 0
	var prompt: Variant = answer.get("prompt")
	return {"shown": visible, "continue": models.size(), "came": mini(came.size(), CAME_MOST), "pins": pins,
		"prompt": str((prompt as Dictionary).get("title", "")) if prompt is Dictionary else "",
		"found": found.size(), "found_for": found_for, "real": real_items(), "asked": asked,
		"shown_ms": shown_ms, "filled_ms": filled_ms, "chosen": chosen,
		"names": models.map(func(one: Dictionary) -> String: return str(one["name"]))}


# -- pictures, links and words ---------------------------------------------------------

## The gallery's picture of a model by its link.
static func _picture_of(link: String) -> String:
	return "%s/m/%s.webp" % [Deployment.api_base(), link]


static func _absolute(address: String) -> String:
	return address if address.begins_with("http") else Deployment.api_base() + address


func _picture_into(rect: TextureRect, address: String, hidden: Control = null) -> void:
	if _covers.has(address):
		rect.texture = _covers[address]
		if hidden != null and rect.texture != null:
			hidden.visible = false
		return
	if pictures == null:
		return
	var got: Dictionary = await pictures.fetch(address, ModelLibrary.MOST_COVER)
	var texture: Texture2D = ModelLibrary.picture(got["bytes"]) if int(got.get("code", 0)) == 200 else null
	_covers[address] = texture
	if is_instance_valid(rect):
		rect.texture = texture
	if texture != null and hidden != null and is_instance_valid(hidden):
		hidden.visible = false


## The link a saved model was shared under (its 0 !BRICKWORKS SHARE line,
## ModelStore.SHARE_META), or "": read from its head, once a change.
static func link_of(path: String) -> String:
	var modified: int = FileAccess.get_modified_time(path)
	var kept: Variant = _links.get(path)
	if kept is Array and int((kept as Array)[0]) == modified:
		return str((kept as Array)[1])
	var link: String = ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file != null:
		var read: int = 0
		while not file.eof_reached() and read < HEAD_LINES:
			var line: String = file.get_line().strip_edges()
			read += 1
			if line.begins_with(ModelStore.SHARE_META):
				var id: String = line.substr(ModelStore.SHARE_META.length()).strip_edges()
				link = id if SharedModels.is_id(id) else ""
				break
	_links[path] = [modified, link]
	return link


## The saved model shared under [param link]: its path, or "" for none here.
static func saved_with(link: String, saved: Array) -> String:
	if not SharedModels.is_id(link):
		return ""
	for entry: Variant in saved:
		if entry is ModelStore.Entry and link_of((entry as ModelStore.Entry).path) == link:
			return (entry as ModelStore.Entry).path
	return ""


static func _parts_words(n: int) -> String:
	if n == 1:
		return "1 part"
	var digits: String = str(n)
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return "%s parts" % (digits + grouped)


## "just now", "5 min ago", "3 h ago", "yesterday", "4 days ago" or a date,
## for a time in unix seconds.
static func _ago_unix(at: int) -> String:
	if at <= 0:
		return ""
	var gone: int = maxi(0, int(Time.get_unix_time_from_system()) - at)
	if gone < 60:
		return "just now"
	if gone < 3600:
		return "%d min ago" % (gone / 60)
	if gone < 86400:
		return "%d h ago" % (gone / 3600)
	if gone < 2 * 86400:
		return "yesterday"
	if gone < 30 * 86400:
		return "%d days ago" % (gone / 86400)
	return ModelVersions.when_saved(at).get_slice(" at ", 0)


static func _ago_iso(at: String) -> String:
	if at.is_empty():
		return ""
	return _ago_unix(int(Time.get_unix_time_from_datetime_string(at.left(19))))
