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
## The most a search says, as the gallery's own (api/share.js ?op=list q).
const SEARCH_MOST := 100
## A file's head read for its link: its metas come before its first part.
const HEAD_LINES := 400
## The line under the title for somebody back, and for somebody here the
## first time ([method open]'s first).
const BACK_LEAD := "Pick up where you left off, or see what came back from other builders."
const FIRST_LEAD := "Start a model of your own: New model, this week's quick build or one from the gallery. The example car is behind this."
## The same, where Start in Simple is offered beside New model ([method open]'s
## simple): what each of the two gives.
const FIRST_LEAD_SIMPLE := "Start in Simple to drag big bricks from a tray with a finger, or New model for every part and tool. This week's quick build and the gallery are below; the example car is behind this."

## Who, and what everything is asked through (Main sets them).
var shared: SharedModels
var store: ModelStore
var account: Account
## Fetches the models' pictures (ModelLibrary.fetch).
var pictures: ModelLibrary
## The parts' geometry, for a picture of a model with none stored (Main's).
var library: PartLibrary
## What each choice does (Main's): open_saved(path), copy(id), came(item),
## begin_new().
var open_saved: Callable = Callable()
var copy: Callable = Callable()
var came_wanted: Callable = Callable()
var begin_new: Callable = Callable()
## A new model in Simple's controls (Main: use_controls(&"simple"), then New),
## offered where [method open] is told to (a touch screen in Full): a phone's
## first visit had Simple only as a tile inside More (appwalk2, askaudit
## 11-28 loading_in_390.png), where nobody new looks for it.
var begin_simple: Callable = Callable()
## Shown to somebody with no model yet, welcomed (open's first).
var welcoming: bool = false

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
## The line under the title: what the screen is for, to whom it is shown.
var _lead: Label
var _close: Button
var _new: Button
var _simple: Button
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
var _bringing: bool = false
var _finding: bool = false
var _found_ok: bool = false
var _asked_ms: int = -1000000
var _found_ms: int = -1000000
## On a phone or a tablet (Main, by TouchSizing.size_panel, which grows its
## text to points): how much a desktop unit of text has grown, so its tiles
## and rows keep room for their words. 1 on a desktop.
var text_k: float = 1.0
## What was asked before it showed (prepare) is shown as it is when younger
## than this; older, it is asked again.
const FRESH_MS := 60000
## A model with no stored picture is drawn from its file (ModelThumbnail's
## drawing, on a worker), this many pixels square, and kept here by the
## file's hash, so it is drawn once a change and not once a visit.
const DRAWN_AT := "user://thumbnails/"
const DRAWN_SIZE := 176
## How long a tile waits for a model still on its way from the account.
const COMING_MS := 120000
## The site's avatar colours, in its order (web/site.css --avatar-N).
const TONES: Array[Color] = [Color("#b42318"), Color("#1f5fbf"), Color("#1f7a3d"), Color("#7a3fb0"),
	Color("#9a4a00"), Color("#0e6f8a"), Color("#a3175a"), Color("#4b5563")]
const FACE := 40.0
## Pictures drawn this run, by the file's hash; what waits to be drawn
## ([rect, path, since, tries]), one at a time.
var _drawn: Dictionary = {}
var _drawing: Array = []
var _draw_running: bool = false
var _shapes_read: bool = false
## The header's pieces, which a phone lays out in two rows (_lay).
var _head: HBoxContainer
var _titles: VBoxContainer
var _head_gap: Control
var _under_head: VBoxContainer


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

	# The title beside its two buttons, which stay their own height: on a
	# phone the buttons have the row to themselves and the words go under
	# them, the width of the card (_lay).
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 10)
	column.add_child(_head)
	_titles = VBoxContainer.new()
	_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titles.add_theme_constant_override("separation", 2)
	_head.add_child(_titles)
	_head_gap = Control.new()
	_head_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_gap.visible = false
	_head.add_child(_head_gap)
	_under_head = VBoxContainer.new()
	_under_head.visible = false
	column.add_child(_under_head)
	_title = _label("Welcome back", 21, Color(0.97, 0.97, 0.98))
	_titles.add_child(_title)
	_lead = _label(BACK_LEAD, 13, Look.GREYED, true)
	_titles.add_child(_lead)
	_simple = _button("Start in Simple", true)
	_simple.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_simple.tooltip_text = "Big bricks and fingers: tray, colours, drag to build"
	_simple.visible = false
	_simple.pressed.connect(func() -> void:
		_chose({"what": "simple"})
		if begin_simple.is_valid():
			begin_simple.call())
	_head.add_child(_simple)
	_name("start_simple", _simple)
	_new = _button("New model", false)
	_new.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_new.tooltip_text = "An empty baseplate"
	_new.pressed.connect(func() -> void:
		_chose({"what": "new"})
		if begin_new.is_valid():
			begin_new.call())
	_head.add_child(_new)
	_close = _close_button()
	_close.tooltip_text = "Put this away (Esc): the model is behind it"
	_close.pressed.connect(func() -> void: close("closed"))
	_head.add_child(_close)
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
## and what the server says asked for at once. [param bringing]: the
## account's models are on their way to this device (CloudModels), and
## set_models lists them when they are here. [param first]: somebody with
## no model yet, where Build your first model has no room (Main
## ._maybe_start): welcomed, and New model the screen's strong button.
## [param simple]: Start in Simple offered before New model (a touch screen
## in Full), the strong button for somebody welcomed.
func open(saved: Array, bringing: bool = false, first: bool = false, simple: bool = false) -> void:
	shown_ms = Time.get_ticks_msec()
	filled_ms = -1
	visible = true
	# Over whatever was laid out after it (a phone's bars).
	move_to_front()
	_bringing = bringing
	_lay()
	set_models(saved)
	welcoming = first
	var offer_simple: bool = simple and begin_simple.is_valid()
	_simple.visible = offer_simple
	_title.text = "Welcome to Brickworks" if first else "Welcome back"
	_lead.text = (FIRST_LEAD_SIMPLE if offer_simple else FIRST_LEAD) if first else BACK_LEAD
	_face(_simple, first)
	_face(_new, first and not offer_simple)
	var now: int = Time.get_ticks_msec()
	if asked == "ok" and now - _asked_ms < FRESH_MS:
		_fill_prompt()
		_fill_came()
	elif asked != "asking":
		_ask()
	if _finding and finding.is_empty():
		pass
	elif found_for.is_empty() and _found_ok and now - _found_ms < FRESH_MS:
		_fill_found(true)
	else:
		_find("")


## Asked before it shows (Main, as the studio starts): what came back, the
## week's build and the gallery's first page, beside the model's open, so
## they are there when it does.
func prepare() -> void:
	if asked.is_empty():
		_ask()
	if not _finding and found.is_empty():
		_find("")


## Nobody signed in now, or somebody else: what was asked as them goes.
func forget() -> void:
	close("signed out")
	asked = ""
	answer = {}
	_asked_ms = -1000000


## Continue from the account's list (CloudModels.listed), newest first,
## while its models are on their way to this device: each opens once it is
## here (Main's open_saved waits for it).
func set_listed(listed: Array) -> void:
	if not models.is_empty():
		return
	for one: Variant in listed:
		if models.size() >= CONTINUE_MOST:
			break
		if not one is Dictionary:
			continue
		var name: String = str((one as Dictionary).get("name", ""))
		if name.is_empty():
			continue
		var parts: Variant = (one as Dictionary).get("parts")
		models.append({"name": name, "path": ModelStore.saved_path(name),
			"bricks": int(parts) if parts is float or parts is int else 0,
			"modified": int(Time.get_unix_time_from_datetime_string(str((one as Dictionary).get("saved_at", "")).left(19))),
			"link": "", "coming": true})
	_fill_continue()


## Continue's models: [param saved] as ModelStore lists them, its first
## few, each with its link where it has one (its picture is its card's).
func set_models(saved: Array) -> void:
	if not saved.is_empty():
		_bringing = false
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
	var got: Dictionary = await shared.studio_start(token, Language.current()) if not token.is_empty() \
		else {"code": 401}
	# Signed out (forget) while it was asked: not theirs to show.
	if asked != "asking":
		return
	var body: Variant = got.get("body")
	if int(got.get("code", 0)) == 200 and body is Dictionary:
		answer = body
		asked = "ok"
		_asked_ms = Time.get_ticks_msec()
	else:
		asked = "away"
	_fill_prompt()
	_fill_came()


func _find_now() -> void:
	_typed.stop()
	var words: String = plain(_search.text)
	# Said, never cut: the gallery searches at most SEARCH_MOST letters.
	if words.length() > SEARCH_MOST:
		_found_title.text = "Search with fewer words: at most %d letters" % SEARCH_MOST
		return
	_find(words)


## The gallery's models for [param words] (its own first page for none).
func _find(words: String) -> void:
	if shared == null or _finding and finding == words:
		return
	_finding = true
	finding = words
	_found_title.text = "Looking…" if words.is_empty() else "Looking for “%s”…" % words
	# Searched as them, so nobody they blocked is in it; the first page as
	# anybody, which the gallery's cache answers at once.
	var token: String = await account.access_token() \
		if not words.is_empty() and account != null and account.signed_in() else ""
	var got: Dictionary = await shared.gallery(words, token)
	if finding != words:
		return
	_finding = false
	finding = ""
	var body: Variant = got.get("body")
	_found_ok = int(got.get("code", 0)) == 200
	_found_ms = Time.get_ticks_msec()
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
	_continue_none.text = "Bringing your models here from your account…" if _bringing \
		else "Nothing saved yet: a model you save is here next time, on any device you sign in on."
	var n: int = 0
	for one: Dictionary in models:
		var facts: String = "%s · %s" % [_parts_words(int(one["bricks"])), _ago_unix(int(one["modified"]))]
		var picture: String = _picture_of(str(one["link"])) if not str(one["link"]).is_empty() else ""
		var path: String = str(one["path"])
		var tile: Button = _tile(str(one["name"]), facts, picture, PICTURE, path)
		tile.tooltip_text = "Open “%s”" % str(one["name"])
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
	# A week with no template: its page, with its brief, its entries and how
	# to enter, never a button that does nothing.
	var page: String = str(week.get("page", "")) if week.get("page") is String else ""
	var has_template: bool = SharedModels.is_id(template)
	var go := _button("Start from its template" if has_template else "See it and its entries", true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.disabled = not has_template and page.is_empty()
	go.tooltip_text = "Your own copy of its template, on the baseplate: publish it to enter" if has_template \
		else "Its page: the brief, what others built, and how to enter"
	go.pressed.connect(func() -> void:
		if not has_template:
			_chose({"what": "prompt page", "page": page})
			Outside.open_link(page if page.begins_with("http") else Deployment.api_base() + page)
			return
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
	row.custom_minimum_size = Vector2(0, 58.0 * text_k)
	row.clip_contents = true
	_face_button(row, Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.08))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8
	line.offset_right = -8
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var who: String = str(item.get("who", "")) if item.get("who") is String else ""
	line.add_child(_face_of(item.get("by"), who))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 1)
	line.add_child(words)
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
	# A phone is narrow whatever its units: 720 across a portrait one.
	var narrow: bool = room.x < NARROW or text_k > 1.0
	var margin: float = 8.0 if narrow else 28.0
	var wide: float = minf(WIDEST, room.x - margin * 2.0)
	var tall: float = room.y - margin * 2.0 if narrow else minf(room.y - margin * 2.0, 760.0)
	_card.position = Vector2(floorf((room.x - wide) * 0.5), floorf((room.y - tall) * 0.5))
	_card.size = Vector2(wide, tall)
	var inner: float = wide - 44.0
	# Columns as wide as a picture, or as wide as its words grown for a finger.
	_continue.columns = clampi(floori((inner + 12.0) / (PICTURE.x * maxf(1.0, text_k * 0.9) + 12.0)), 2,
		CONTINUE_MOST)
	_found_grid.columns = clampi(floori((inner + 12.0) / (PICTURE.x * 0.82 * maxf(1.0, text_k * 0.75) + 12.0)),
		2, FOUND_MOST)
	_middle.columns = 1 if narrow else 2
	var titles_at: Container = _under_head if narrow else _head
	if _titles.get_parent() != titles_at:
		_titles.get_parent().remove_child(_titles)
		titles_at.add_child(_titles)
		if not narrow:
			_head.move_child(_titles, 0)
	_head_gap.visible = narrow
	_under_head.visible = narrow
	for tile: Control in _continue.get_children() + _found_grid.get_children():
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# -- the pieces ----------------------------------------------------------------------

func _tile(title: String, facts: String, picture: String, picture_size: Vector2,
		model_path: String = "") -> Button:
	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.clip_contents = true
	# As wide as its column, which the grid shares out (_lay): a phone's two
	# columns are narrower than a picture's own width.
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0, picture_size.y + 50.0 * text_k)
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
	var shown := TextureRect.new()
	shown.name = "Shown"
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(shown)
	# Its stored picture, or, with none or none that comes, its own file
	# drawn: a model is shown as itself, never as a letter.
	if not picture.is_empty():
		_picture_into(shown, picture, func() -> void:
			if not model_path.is_empty():
				_drawn_into(shown, model_path))
	elif not model_path.is_empty():
		_drawn_into(shown, model_path)
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


## A close button as a window's: a sign in a square, its ground only under
## the pointer.
func _close_button() -> Button:
	var button := Button.new()
	button.text = "×"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(34, 34)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 22)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(1, 1, 1, 0.0 if state == "normal" or state == "disabled"
			else (0.10 if state == "hover" else 0.16))
		face.set_corner_radius_all(8)
		face.content_margin_left = 4
		face.content_margin_right = 4
		face.content_margin_top = 0
		face.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, face)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(colour, Color(0.86, 0.88, 0.92) if colour == "font_color" else Color.WHITE)
	return button


func _button(words: String, main: bool) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(36, 34)
	button.add_theme_font_size_override("font_size", 13)
	_face(button, main)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	return button


## [param button] filled in the screen's one strong colour ([param main]),
## or in its quiet one.
func _face(button: Button, main: bool) -> void:
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
	var items: Array = []
	for one: Variant in came:
		if not one is Dictionary:
			continue
		var item: Dictionary = one
		pins += 1 if bool(item.get("pinned", false)) else 0
		if items.size() < CAME_MOST:
			items.append({"kind": str(item.get("kind", "")), "pinned": bool(item.get("pinned", false)),
				"comment": int(item.get("comment", 0)) if item.get("comment") is float or item.get("comment") is int else 0,
				"model": str(item.get("model", ""))})
	var prompt: Variant = answer.get("prompt")
	return {"shown": visible, "welcoming": welcoming, "title": _title.text if _title != null else "",
		"continue": models.size(), "came": mini(came.size(), CAME_MOST), "pins": pins,
		"prompt": str((prompt as Dictionary).get("title", "")) if prompt is Dictionary else "",
		"found": found.size(), "found_for": found_for,
		"found_title": _found_title.text if _found_title != null else "", "real": real_items(), "asked": asked,
		"shown_ms": shown_ms, "filled_ms": filled_ms, "chosen": chosen, "items": items,
		"names": models.map(func(one: Dictionary) -> String: return str(one["name"])),
		"pictured": _pictured(_continue), "faces": _faces()}


## How many of [param grid]'s tiles show a picture.
func _pictured(grid: Container) -> int:
	var n: int = 0
	if grid != null:
		for tile: Node in grid.get_children():
			var shown: TextureRect = tile.find_child("Shown", true, false) as TextureRect
			n += 1 if shown != null and shown.texture != null else 0
	return n


## How many came-back rows show whoever it was.
func _faces() -> int:
	var n: int = 0
	if _came_list != null:
		for row: Node in _came_list.get_children():
			n += 1 if row.find_child("Face", true, false) != null else 0
	return n


# -- pictures, links and words ---------------------------------------------------------

## The gallery's picture of a model by its link.
static func _picture_of(link: String) -> String:
	return "%s/m/%s.webp" % [Deployment.api_base(), link]


static func _absolute(address: String) -> String:
	return address if address.begins_with("http") else Deployment.api_base() + address


## The picture at [param address] into [param rect]; [param otherwise] called
## when there is none to be had.
func _picture_into(rect: TextureRect, address: String, otherwise: Callable = Callable(),
		hidden: Control = null) -> void:
	var texture: Texture2D = null
	if _covers.has(address):
		texture = _covers[address]
	elif pictures != null:
		var got: Dictionary = await pictures.fetch(address, ModelLibrary.MOST_COVER)
		texture = ModelLibrary.picture(got["bytes"]) if int(got.get("code", 0)) == 200 else null
		_covers[address] = texture
	if not is_instance_valid(rect):
		return
	if texture == null:
		if otherwise.is_valid():
			otherwise.call()
		return
	rect.texture = texture
	if hidden != null and is_instance_valid(hidden):
		hidden.visible = false


## [param rect] given the picture of the model file at [param path], drawn
## when it has none kept: in turn, one model at a time.
func _drawn_into(rect: TextureRect, path: String) -> void:
	_drawing.append([rect, path, Time.get_ticks_msec(), 0])
	if not _draw_running:
		_draw_running = true
		_draw_all()


func _draw_all() -> void:
	while not _drawing.is_empty() and is_inside_tree():
		var job: Array = _drawing.pop_front()
		var rect: TextureRect = job[0] as TextureRect if is_instance_valid(job[0]) else null
		if rect == null:
			continue
		var path: String = job[1]
		if not FileAccess.file_exists(path):
			# Still on its way from the account (set_listed): drawn once here.
			if Time.get_ticks_msec() - int(job[2]) < COMING_MS:
				_drawing.append(job)
				await get_tree().create_timer(1.0).timeout
			continue
		var drawn: Array = await _drawing_of(path)
		if drawn[0] != null and is_instance_valid(rect):
			rect.texture = drawn[0]
		# Parts still coming over the wire: drawn again once they may be here.
		if not bool(drawn[1]) and int(job[3]) < 2:
			job[3] = int(job[3]) + 1
			get_tree().create_timer(6.0).timeout.connect(func() -> void:
				if is_instance_valid(rect):
					_drawing.append(job)
					if not _draw_running:
						_draw_running = true
						_draw_all())
	_draw_running = false


## The picture of the model file at [param path] and whether it has every
## part ([texture or null, whole]): kept by its file's hash, or drawn by
## ModelThumbnail's drawer on a worker, so the frame goes on meanwhile.
func _drawing_of(path: String) -> Array:
	var key: String = FileAccess.get_md5(path)
	if key.is_empty():
		return [null, true]
	if _drawn.has(key):
		return [_drawn[key], true]
	var kept: String = DRAWN_AT + key + ".png"
	if FileAccess.file_exists(kept):
		var image: Image = Image.load_from_file(kept)
		if image != null and not image.is_empty():
			_drawn[key] = ImageTexture.create_from_image(image)
			return [_drawn[key], true]
	if library == null:
		return [null, true]
	var read: Dictionary = ModelThumbnail.model_text(path)
	if not str(read.get("error", "")).is_empty():
		return [null, true]
	var placed: Array[LdrModel.Placement] = LdrModel.parse(str(read["text"]), path.get_file()).flatten()
	# Each part's geometry where it lies (the build's or the library's
	# files), read on the worker; a part only in memory (fetched, or one of
	# the person's own) taken from there now.
	var files: Dictionary = {}
	var shapes: Dictionary = {}
	var missing: Array = []
	for placement: LdrModel.Placement in placed:
		var id: String = placement.part_id
		if files.has(id) or shapes.has(id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(id)
		var on_disk: String = library._on_disk(info.mesh_hash) if info != null else ""
		if not on_disk.is_empty():
			files[id] = on_disk
		elif library.is_resident(id):
			var mesh: Lbm.PartMesh = library.mesh_for(id)
			if mesh != null:
				shapes[id] = ModelThumbnail.Shape.of_part(mesh)
		elif info != null:
			missing.append(id)
	if not missing.is_empty():
		library.want(missing)
	var colours: Dictionary = {}
	for code: Variant in library.colors:
		var colour: PartLibrary.BrickColor = library.colors[code]
		colours[int(code)] = Color(colour.rgb, float(colour.alpha) / 255.0)
	# A function's first run on two threads at once can take the engine
	# down (WorkerTasks.first_here): the first part read here.
	if not _shapes_read and not files.is_empty():
		_shapes_read = true
		var first: String = str(files.keys()[0])
		var shape: ModelThumbnail.Shape = ModelThumbnail.Shape.read(str(files[first]))
		files.erase(first)
		if shape != null:
			shapes[first] = shape
	var out: Dictionary = {}
	var lock := Mutex.new()
	var task: int = WorkerThreadPool.add_task(func() -> void:
		var all: Dictionary = shapes.duplicate()
		for id: String in files:
			var shape: ModelThumbnail.Shape = ModelThumbnail.Shape.read(str(files[id]))
			if shape != null:
				all[id] = shape
		var names: Dictionary = {}
		for id: String in all:
			names[id] = id
		var drawer := ModelThumbnail.Drawer.new()
		drawer.alone = true
		drawer.colours = colours
		var image: Image = drawer.draw(placed, names, all, DRAWN_SIZE)
		lock.lock()
		out["image"] = image
		lock.unlock(), false, "studio start picture")
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	lock.lock()
	var image: Image = out.get("image")
	lock.unlock()
	if image == null:
		return [null, missing.is_empty()]
	var texture := ImageTexture.create_from_image(image)
	if missing.is_empty():
		_drawn[key] = texture
		DirAccess.make_dir_recursive_absolute(DRAWN_AT)
		image.save_png(kept)
	return [texture, missing.is_empty()]


## Whoever a came-back row names, as the site shows them (web/card.js
## avatarHtml): their picture, or the first letter of their name on their
## colour. [param who] names one the answer gives no person for.
func _face_of(by: Variant, who: String) -> Control:
	var person: Dictionary = by if by is Dictionary else {}
	var handle: String = str(person.get("handle", ""))
	var named: String = str(person.get("name", "")).strip_edges()
	var said: String = named if not named.is_empty() else (handle if not handle.is_empty() else who)
	var across: float = roundf(FACE * text_k)
	var face := Panel.new()
	face.name = "Face"
	face.custom_minimum_size = Vector2(across, across)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var disc := StyleBoxFlat.new()
	disc.set_corner_radius_all(ceili(across * 0.5))
	disc.bg_color = tone_of(handle if not handle.is_empty() else said) if not said.is_empty() \
		else Color(1, 1, 1, 0.12)
	face.add_theme_stylebox_override("panel", disc)
	var letter := _label(said.left(1).to_upper() if not said.is_empty() else "?", 17, Color.WHITE)
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_child(letter)
	var picture: String = str(person.get("picture", ""))
	if picture.begins_with("/api/people?op=avatar&id="):
		var shown := TextureRect.new()
		shown.name = "Picture"
		shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.add_child(shown)
		_picture_into(shown, _absolute(picture), Callable(), letter)
	return face


## A person's colour, as the site picks it (web/card.js avatarTone): FNV-1a
## of their handle, lower case, into the eight.
static func tone_of(handle: String) -> Color:
	var mixed: int = 0x811c9dc5
	var lower: String = handle.to_lower()
	for i: int in lower.length():
		mixed = mixed ^ lower.unicode_at(i)
		mixed = (mixed * 0x01000193) & 0xFFFFFFFF
	return TONES[mixed % 8]


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
## What a person typed or pasted, as the gallery searches it: a no-break,
## wide or other Unicode space read as a space, the zero-width ones gone,
## runs of spaces made one.
static func plain(typed: String) -> String:
	var out: String = ""
	for i: int in typed.length():
		var c: int = typed.unicode_at(i)
		if c in [0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF, 0xAD]:
			continue
		var space: bool = c < 32 or c == 0x7F or c in [0xA0, 0x1680, 0x202F, 0x205F, 0x3000, 0x2028, 0x2029] \
			or (c >= 0x2000 and c <= 0x200A)
		out += " " if space else String.chr(c)
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()


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
