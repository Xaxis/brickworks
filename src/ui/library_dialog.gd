## The library: any of LDraw's models of real sets, or a model the community
## shared, opened in a tab of its own (File, Open, From the library…).
##
## Two shelves behind two buttons along the top, as My collection has its
## pages, over the model like it (consulted and dismissed, and wants the
## room):
##
##   LDraw sets   every model of a real set in LDraw's Official Model
##                Repository (ModelLibrary), searched by name, set
##                number, theme or designer, and by theme, decade and
##                size, sorted
##   Community    the gallery at brickworks.diy/gallery (api/share.js
##                ?op=list), searched by words, kind and size, sorted
##
## The search is first, under the shelves' buttons, edged as a control is
## and marked by a magnifier: below the shelf's note it was a field with no
## edge between two lines of small print, and the owner asked for a search
## (2026-10-29). It asks again as the person types, a moment after the last
## key; its words go with them to the other shelf. Ctrl+F (Cmd+F) comes to
## it while the library shows, Escape clears it, and Enter opens the first
## model found (on a phone, whose screen's keyboard has an Enter for every
## field, Enter only asks). Words that find nothing say so where the covers
## would be, with the ways to find more: the search cleared, the filters
## let go, the other shelf.
##
## Each is a grid of covers, a page at a time. Open puts the model in a new
## tab (TabSession.open_another: a new window on the desktop), so the model
## on this baseplate is never touched. A set opens as the repository has
## it, credited to the LDraw member who made it, under its licence, with
## its LDraw page (ModelStore.credit, in Properties); a community model is
## copied into the person's models as Open in Brickworks on its page does
## (/app?copy=, Main._maybe_copy), all rights reserved ones too, and no
## more than that allows.
class_name LibraryDialog
extends PanelContainer

const WIDE := 980.0
const TALL := 700.0
## A card is at least this wide; the grid fits as many as the room takes.
const CARD := 168.0
const GAP := 10.0
const COVER_TALL := 112.0
## Covers asked for at once.
const FETCHING := 4
## The gallery's sorts, as its page names them (api/_directory.js SORTS).
const GALLERY_SORTS: Array = [["newest", "Newest"], ["top", "Top builds"], ["builds", "Most built"],
	["likes", "Most liked"], ["views", "Most viewed"], ["remixes", "Most remixed"]]
const DISCLAIMER := ("LEGO® is a trademark of the LEGO Group of companies which does not sponsor, "
	+ "authorize or endorse this app.")
## The magnifier at the search's end while it is empty; its clear button
## takes the place once something is typed.
const MAGNIFIER := "res://assets/ui/tools/search.svg"
const MAGNIFIER_TALL := 14.0

var app: Node
var books: ModelLibrary

var _source: String = "sets"
var _tabs: Dictionary = {}
var _controls: Dictionary = {}
var _status: Label
var _note: Label
var _search: LineEdit
var _theme: OptionButton
var _decade: OptionButton
var _size: OptionButton
var _sort: OptionButton
var _kind: OptionButton
var _sets_row: Array[Control] = []
var _community_row: Array[Control] = []
var _scroll: ScrollContainer
var _grid: GridContainer
var _page_words: Label
var _previous: Button
var _next: Button
var _typing: Timer
## Said where the covers would be when the words typed find nothing.
var _none: VBoxContainer
var _none_words: Label
var _none_hint: Label
var _let_go: Button
var _elsewhere: Button

var _page: int = 1
var _pages: int = 1
var _more: bool = false
## What is shown now: {"id", "name", "kind": "set"|"community", "facts",
## "credit", "picture" (a path in the library or an address)}.
var _shown: Array = []
var _covers: Dictionary = {}
var _wanted: Array = []
var _fetchers: int = 0
## Bumped at every fill, so an answer to an older question is dropped.
var _asked: int = 0
## The fill whose answer is shown: [member _asked] once it has come.
var _answered: int = 0
## What the shelf said last, for a probe and the page.
var last: Dictionary = {}

## What Open did, for the status bar: the screen's own line says the rest.
signal said(text: String)


## Put the panel on screen, hidden.
func attach(main: Node) -> void:
	app = main
	books = main.get("_model_library")
	main.get_node("HUD").add_child(self)
	# Over the frame: while it shows, F6 comes into it, at its search, and
	# Tab from the search goes on to what it found (FocusGuard).
	add_to_group(FocusGuard.OVER)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _ready() -> void:
	visible = false
	_build()


## Open on a shelf: "sets" or "community".
func open(source: String = "") -> void:
	visible = true
	# Drawn for the screen it is on now: a browser's ratio is known only
	# once the page is up.
	var magnifier: ImageTexture = Icons.texture_for(MAGNIFIER, MAGNIFIER_TALL, Icons.density(self))
	if magnifier != null:
		magnifier.set_size_override(Vector2i(int(MAGNIFIER_TALL), int(MAGNIFIER_TALL)))
	_search.right_icon = magnifier
	_show(source if not source.is_empty() else _source)


func is_showing() -> bool:
	return visible


func close() -> void:
	visible = false
	_tell_page()


## Where each control is, for a browser test to press it as a person does.
func controls_by_name() -> Dictionary:
	return _controls if visible else {}


## Ctrl+F (Cmd+F on a Mac) while the library shows: the keys to its search,
## what it says chosen, so the next words replace them. Over the model, the
## engine had no Ctrl+F and the app's own F fitted the view behind.
func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	if key.keycode == KEY_F and (key.ctrl_pressed or key.meta_pressed) and not key.alt_pressed \
			and not key.shift_pressed:
		_search.grab_focus()
		_search.select_all()
		get_viewport().set_input_as_handled()


func _fit() -> void:
	var room: Vector2 = get_viewport().get_visible_rect().size
	# A phone's whole screen: the covers want the height more than a margin.
	var narrow: bool = room.x < 900.0
	var margin: float = 6.0 if narrow else 24.0
	var wide: float = minf(WIDE, room.x - margin * 2.0)
	var tall: float = room.y - margin * 2.0 if narrow else minf(TALL, room.y - margin * 2.0)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -wide * 0.5
	offset_right = wide * 0.5
	offset_top = -tall * 0.5
	offset_bottom = tall * 0.5
	_lay_grid.call_deferred()


# --- building the panel -------------------------------------------------

func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	backing.content_margin_top = 14
	backing.content_margin_bottom = 14
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var header := HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 6)
	header.add_theme_constant_override("v_separation", 6)
	column.add_child(header)
	var title := Label.new()
	title.text = "Library"
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	header.add_child(gap)
	for shelf: Array in [["sets", "LDraw sets"], ["community", "Community"]]:
		var tab := Button.new()
		tab.text = shelf[1]
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", 12)
		var lit := StyleBoxFlat.new()
		lit.bg_color = Look.CHOSEN
		lit.set_corner_radius_all(4)
		lit.content_margin_left = 8
		lit.content_margin_right = 8
		lit.content_margin_top = 3
		lit.content_margin_bottom = 3
		tab.add_theme_stylebox_override("pressed", lit)
		tab.add_theme_stylebox_override("hover_pressed", lit)
		for state: String in ["normal", "hover"]:
			var plain: StyleBoxFlat = lit.duplicate()
			plain.bg_color = Color(1, 1, 1, 0.05 if state == "normal" else 0.12)
			# Edged as every button is (Look.OUTLINE), inside the same box.
			plain.border_color = Look.OUTLINE
			plain.set_border_width_all(1)
			tab.add_theme_stylebox_override(state, plain)
		var named: String = shelf[0]
		tab.pressed.connect(func() -> void: _show(named))
		header.add_child(tab)
		_tabs[named] = tab
		_controls["library_tab_" + named] = tab
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(fill)
	var done := _button(header, "Done", close, "library_done")
	done.focus_mode = Control.FOCUS_NONE

	# The search and the filters first, the shelf's note after them.
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 6)
	filters.add_theme_constant_override("v_separation", 6)
	column.add_child(filters)
	_search = LineEdit.new()
	_search.custom_minimum_size = Vector2(220, 0)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.add_theme_font_size_override("font_size", 12)
	_search.clear_button_enabled = true
	# Edged as the buttons beside it are (Look.OUTLINE), inside the same box.
	var engine := ThemeDB.get_default_theme().get_stylebox("normal", "LineEdit") as StyleBoxFlat
	var edged: StyleBoxFlat = engine.duplicate() if engine != null else StyleBoxFlat.new()
	edged.border_color = Look.OUTLINE
	edged.set_border_width_all(1)
	_search.add_theme_stylebox_override("normal", edged)
	_search.accessibility_description = ("%s+F comes here; Escape clears it; Enter opens the first "
		+ "found") % EditVerbs.held_key()
	# Escape clears the words; once there are none it leaves the field, not
	# the dialog (FocusGuard).
	_search.set_meta(FocusGuard.CLEAR_ON_ESCAPE, true)
	_search.text_changed.connect(_typed)
	_search.text_submitted.connect(_entered)
	_search.focus_entered.connect(_tell_page)
	_search.focus_exited.connect(_tell_page)
	filters.add_child(_search)
	_controls["library_search"] = _search
	_typing = Timer.new()
	_typing.one_shot = true
	_typing.wait_time = 0.35
	_typing.timeout.connect(_refill)
	add_child(_typing)

	_theme = _choice(filters, "library_theme", "Which theme of sets")
	_decade = _choice(filters, "library_decade", "Which years the sets came out")
	_kind = _choice(filters, "library_kind", "What kind of model")
	for kind: String in ModelKinds.ids():
		_kind.add_item(ModelKinds.label(kind))
		_kind.set_item_metadata(_kind.item_count - 1, kind)
	_size = _choice(filters, "library_size", "How many parts")
	# The sizes in the gallery's own words, short: a list as wide as its
	# longest item pushed Sort onto a line of its own.
	for size: Array in [["small", "Under 200 parts"], ["medium", "200 to 999 parts"],
			["large", "1,000 parts or more"]]:
		_size.add_item(size[1])
		_size.set_item_metadata(_size.item_count - 1, size[0])
	_sort = OptionButton.new()
	_sort.focus_mode = Control.FOCUS_NONE
	_sort.add_theme_font_size_override("font_size", 12)
	_sort.tooltip_text = "Which first"
	_sort.item_selected.connect(func(_at: int) -> void: _refill())
	filters.add_child(_sort)
	_controls["library_sort"] = _sort
	_sets_row = [_theme, _decade]
	_community_row = [_kind]

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 11)
	_note.modulate = Color(1, 1, 1, 0.6)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.75)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# How many the words found, said to a screen reader as it changes.
	_status.accessibility_live = AccessibilityServer.LIVE_POLITE
	column.add_child(_status)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.resized.connect(_lay_grid)
	column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_scroll.add_child(_grid)

	_none = VBoxContainer.new()
	_none.visible = false
	_none.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_none.alignment = BoxContainer.ALIGNMENT_CENTER
	_none.add_theme_constant_override("separation", 8)
	column.add_child(_none)
	_none_words = Label.new()
	_none_words.add_theme_font_size_override("font_size", 15)
	_none_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_none_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_none_words.accessibility_live = AccessibilityServer.LIVE_POLITE
	_none.add_child(_none_words)
	_none_hint = Label.new()
	_none_hint.add_theme_font_size_override("font_size", 12)
	_none_hint.modulate = Color(1, 1, 1, 0.75)
	_none_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_none_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_none.add_child(_none_hint)
	var ways := HFlowContainer.new()
	ways.alignment = FlowContainer.ALIGNMENT_CENTER
	ways.add_theme_constant_override("h_separation", 8)
	ways.add_theme_constant_override("v_separation", 6)
	_none.add_child(ways)
	_button(ways, "Clear the search", _clear_search, "library_clear_search")
	_let_go = _button(ways, "", _any_filter, "library_any_filter")
	_elsewhere = _button(ways, "", func() -> void: _show("community" if _source == "sets" else "sets"),
		"library_search_elsewhere")

	var foot := HFlowContainer.new()
	foot.add_theme_constant_override("h_separation", 8)
	foot.add_theme_constant_override("v_separation", 4)
	column.add_child(foot)
	_previous = _button(foot, "‹ Previous", func() -> void: _turn(-1), "library_previous")
	_page_words = Label.new()
	_page_words.add_theme_font_size_override("font_size", 12)
	_page_words.modulate = Color(1, 1, 1, 0.7)
	foot.add_child(_page_words)
	_next = _button(foot, "Next ›", func() -> void: _turn(1), "library_next")
	var mark := Label.new()
	mark.text = DISCLAIMER
	mark.add_theme_font_size_override("font_size", 10)
	mark.modulate = Color(1, 1, 1, 0.45)
	mark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mark.custom_minimum_size = Vector2(200, 0)
	foot.add_child(mark)


func _choice(row: Container, named: String, tip: String) -> OptionButton:
	var choice := OptionButton.new()
	choice.focus_mode = Control.FOCUS_NONE
	choice.add_theme_font_size_override("font_size", 12)
	choice.tooltip_text = tip
	choice.add_item("Any " + {"library_theme": "theme", "library_decade": "year",
		"library_kind": "kind", "library_size": "size"}[named])
	choice.set_item_metadata(0, "")
	choice.item_selected.connect(func(_at: int) -> void: _refill())
	row.add_child(choice)
	_controls[named] = choice
	return choice


func _button(row: Container, text: String, action: Callable, named: String = "",
		tip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	row.add_child(button)
	if not named.is_empty():
		_controls[named] = button
	return button


# --- the shelves --------------------------------------------------------

func _show(source: String) -> void:
	_source = source
	for name: String in _tabs:
		(_tabs[name] as Button).button_pressed = name == source
	var sets: bool = source == "sets"
	for control: Control in _sets_row:
		control.visible = sets
	for control: Control in _community_row:
		control.visible = not sets
	# What each shelf's words are matched against: ModelLibrary.search, and
	# the gallery's directory_words (supabase/directory.sql).
	_search.placeholder_text = "Search sets by name, set number, theme or designer" if sets \
		else "Search models by name, designer or tag"
	_search.accessibility_name = "Search the LDraw sets" if sets else "Search the community's models"
	_note.text = ("Models of real LEGO® sets from LDraw's Official Model Repository, each made by "
		+ "the LDraw member credited and free to use under its licence. Open puts one in a new %s; "
		+ "the model here stays as it is.") % _tab_word() if sets else ("Models people built in "
		+ "Brickworks and shared. Open copies one into your models in a new %s, as Open in "
		+ "Brickworks on its page does: credit its designer and keep to its licence.") % _tab_word()
	_sort.clear()
	if sets:
		for sort: String in ModelLibrary.SORTS:
			_sort.add_item(str(ModelLibrary.SORT_WORDS[sort]))
			_sort.set_item_metadata(_sort.item_count - 1, sort)
	else:
		for sort: Array in GALLERY_SORTS:
			_sort.add_item(str(sort[1]))
			_sort.set_item_metadata(_sort.item_count - 1, sort[0])
	_refill()


static func _tab_word() -> String:
	return "tab" if OS.has_feature("web") else "window"


## Ask again from the first page: the search or a filter changed.
func _refill() -> void:
	_page = 1
	await _fill()


## Words typed: asked a moment after the last key, and at once when the
## field is emptied (its clear button, Escape, Clear the search).
func _typed(text: String) -> void:
	if text.strip_edges().is_empty():
		_typing.stop()
		_refill()
	else:
		_typing.start()


## Enter: the first model found opened, as its Open does, in the press (a
## browser opens a tab only in answer to one); asked first when the words
## have not been yet. On a phone it only asks: its screen's keyboard has an
## Enter for every field, and the person has not seen what was found.
func _entered(_text: String) -> void:
	_typing.stop()
	if Phone.on():
		_refill()
		return
	if not _answers_the_field():
		await _refill()
		if not visible or not _answers_the_field():
			return
	if not _shown.is_empty():
		_open_card(_shown[0])


## Whether what is shown is the answer to the words in the field now.
func _answers_the_field() -> bool:
	return _answered == _asked and last.get("source") == _source \
		and str((last.get("ask", {}) as Dictionary).get("q", "")) == _search.text.strip_edges()


func _clear_search() -> void:
	# Asked again at once: clear() sends text_changed (_typed).
	_search.clear()
	# The keys back in the field for the next words; not on a phone, where
	# that brings its keyboard up over what came back.
	if not Phone.on():
		_search.grab_focus()


## Every filter of the shelf showing back at Any, and asked again.
func _any_filter() -> void:
	for choice: OptionButton in [_theme, _decade, _kind, _size]:
		if choice.visible:
			choice.select(0)
	_refill()


## The filters chosen on the shelf showing, in their own words: "Town, 1980s".
func _filtering() -> PackedStringArray:
	var chosen := PackedStringArray()
	for choice: OptionButton in [_theme, _decade, _kind, _size]:
		if choice.visible and choice.selected > 0:
			chosen.append(choice.get_item_text(choice.selected))
	return chosen


func _turn(by: int) -> void:
	_page = maxi(1, _page + by)
	await _fill()
	_scroll.scroll_vertical = 0


static func _picked(choice: OptionButton) -> String:
	return str(choice.get_item_metadata(choice.selected)) if choice.selected >= 0 else ""


## What the filters ask now, for the shelf showing.
func asking() -> Dictionary:
	var ask: Dictionary = {"q": _search.text.strip_edges(), "size": _picked(_size),
		"sort": _picked(_sort), "page": _page}
	if _source == "sets":
		ask["theme"] = _picked(_theme)
		ask["decade"] = _picked(_decade)
	else:
		ask["kind"] = _picked(_kind)
	return ask


func _fill() -> void:
	_asked += 1
	var asked: int = _asked
	_say("Looking…")
	var found: Dictionary
	if _source == "sets":
		found = await _sets(asking())
	else:
		found = await _community(asking())
	if asked != _asked:
		return
	_answered = asked
	_shown = found.get("models", [])
	_pages = int(found.get("pages", 1))
	_more = bool(found.get("more", false))
	_previous.disabled = _page <= 1
	_next.disabled = not (_page < _pages or _more)
	_page_words.text = ("Page %d of %d" % [_page, _pages]) if _source == "sets" else "Page %d" % _page
	_say(str(found.get("said", "")))
	# Words that found nothing: said where the covers would be. With no
	# words, the filters alone, the status line says it as it did.
	var words: String = _search.text.strip_edges()
	var none: bool = bool(found.get("answered", false)) and _shown.is_empty() and not words.is_empty()
	if none:
		_say_none(words)
	_none.visible = none
	_scroll.visible = not none
	_status.visible = not none
	last = {"asked": asked, "source": _source, "ask": asking(), "total": int(found.get("total", _shown.size())),
		"shown": _shown.map(func(one: Dictionary) -> String: return str(one["id"])),
		"status": _status.text, "none": _none_words.text if none else ""}
	_lay_cards()
	_tell_page()


## Nothing found for [param words]: what was asked, and the ways to more.
func _say_none(words: String) -> void:
	var sets: bool = _source == "sets"
	var quoted: String = "“%s”" % words.left(60)
	var filtering: PackedStringArray = _filtering()
	_none_words.text = ("No set matches %s" if sets else "Nothing in the gallery matches %s") % quoted
	_none_hint.text = ("Try fewer words or another spelling, or a set number such as 6056 or 10179-1."
		if sets else "Try fewer words or another spelling: a model's name, its designer or a tag.")
	if not filtering.is_empty():
		_none_hint.text += " Searched only within the filters chosen: %s." % " · ".join(filtering)
	_let_go.visible = not filtering.is_empty()
	_let_go.text = "Any theme, year and size" if sets else "Any kind and size"
	_elsewhere.text = "Search Community for %s" % quoted if sets else "Search LDraw sets for %s" % quoted
	_say(_none_words.text + ".")


## A page of sets: {"models", "pages", "total", "said"}.
func _sets(ask: Dictionary) -> Dictionary:
	if books == null:
		return {"said": "This app has no library."}
	var every: Array = await books.models()
	if every.is_empty():
		return {"said": books.trouble}
	if _theme.item_count == 1:
		for theme: String in ModelLibrary.themes(every):
			_theme.add_item(theme)
			_theme.set_item_metadata(_theme.item_count - 1, theme)
		for decade: String in ModelLibrary.decades(every):
			_decade.add_item(decade)
			_decade.set_item_metadata(_decade.item_count - 1, decade)
	var found: Dictionary = ModelLibrary.search(every, ask)
	var cards: Array = []
	for entry: Dictionary in found["models"]:
		var facts := PackedStringArray()
		if not str(entry["set"]).is_empty():
			facts.append(str(entry["set"]))
		if int(entry["year"]) > 0:
			facts.append(str(entry["year"]))
		facts.append(ModelLibrary.parts_words(entry))
		cards.append({"id": entry["id"], "name": ModelLibrary.tidy(str(entry["name"])), "kind": "set",
			"facts": " · ".join(facts), "theme": ModelLibrary.tidy(str(entry["theme"])),
			"credit": _credit_line(str(entry["author"]), str(entry["licence"])),
			"picture": entry["cover"], "entry": entry})
	_page = int(found["page"])
	var total: int = int(found["total"])
	return {"models": cards, "pages": int(found["pages"]), "total": total, "answered": true,
		"said":("%s of %s sets" % [CollectionDialog._comma(total), CollectionDialog._comma(every.size())]
			if total > 0 else "No set matches. Try fewer words, or Any theme.")}


## A page of the gallery: {"models", "more", "said"}.
func _community(ask: Dictionary) -> Dictionary:
	var query := PackedStringArray(["op=list", "page=%d" % int(ask["page"])])
	if not str(ask["q"]).is_empty():
		query.append("q=" + str(ask["q"]).left(100).uri_encode())
	for key: String in ["kind", "size", "sort"]:
		if not str(ask.get(key, "")).is_empty():
			query.append("%s=%s" % [key, str(ask[key])])
	var got: Dictionary = await books.fetch(Deployment.api_base() + "/api/share?" + "&".join(query),
		512 * 1024) if books != null else {"code": 0, "bytes": PackedByteArray()}
	var json := JSON.new()
	if int(got["code"]) != 200 or json.parse((got["bytes"] as PackedByteArray).get_string_from_utf8()) != OK \
			or not json.data is Dictionary:
		var body: Variant = json.data if json.data is Dictionary else null
		return {"said": SharedModels.trouble({"code": got["code"], "body": body},
			"The gallery answered %d." % int(got["code"]))}
	var cards: Array = []
	for one: Variant in (json.data as Dictionary).get("models", []):
		if not one is Dictionary or not SharedModels.is_id(str((one as Dictionary).get("id", ""))):
			continue
		var model: Dictionary = one
		var facts := PackedStringArray(["%s parts" % CollectionDialog._comma(int(model.get("parts", 0)))])
		if model.get("kind") is String:
			facts.append(ModelKinds.label(str(model["kind"])))
		if int(model.get("builds", 0)) > 0:
			facts.append("built %s" % GalleryTool._times(int(model["builds"])))
		var thumb: String = str(model["thumb"]) if model.get("thumb") is String else ""
		cards.append({"id": model["id"], "name": str(model.get("name", "?")), "kind": "community",
			"facts": " · ".join(facts), "theme": "",
			"credit": _credit_line(str(model["author"]) if model.get("author") is String else "",
				GalleryTool._licence_name(model.get("licence"))),
			"picture": thumb if thumb.begins_with("http") else "%s/m/%s.webp" % [Deployment.api_base(),
				model["id"]]})
	var more: bool = bool((json.data as Dictionary).get("more", false))
	return {"models": cards, "more": more, "total": cards.size(), "answered": true,
		"said":("Models shared in the gallery" if not cards.is_empty()
			else "Nothing in the gallery matches. Try fewer words, or Any kind.")}


static func _credit_line(by: String, licence: String) -> String:
	return ("by %s · %s" % [by, licence]) if not by.is_empty() else licence


# --- the grid -----------------------------------------------------------

## As many columns as the room takes, each card as wide as they share.
func _lay_grid() -> void:
	if _grid == null or _scroll == null:
		return
	var room: float = _scroll.size.x - 12.0
	if room <= 0.0:
		return
	var columns: int = maxi(1, floori((room + GAP) / (CARD + GAP)))
	if room >= 2.0 * 136.0 + GAP:
		columns = maxi(columns, 2)
	_grid.columns = columns
	var wide: float = floorf((room - GAP * (columns - 1)) / columns)
	for card: Control in _grid.get_children():
		card.custom_minimum_size.x = wide


func _lay_cards() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_controls.erase("library_open_first")
	_wanted.clear()
	for n: int in _shown.size():
		_grid.add_child(_card(_shown[n], n == 0))
	_lay_grid()
	for card: Dictionary in _shown:
		if not _covers.has(str(card["picture"])):
			_wanted.append(card)
	while _fetchers < FETCHING and not _wanted.is_empty():
		_fetch_covers()


func _card(card: Dictionary, first: bool) -> Control:
	var panel := PanelContainer.new()
	var face := StyleBoxFlat.new()
	face.bg_color = Color(1, 1, 1, 0.04)
	face.border_color = Color(1, 1, 1, 0.1)
	face.set_border_width_all(1)
	face.set_corner_radius_all(5)
	face.content_margin_left = 8
	face.content_margin_right = 8
	face.content_margin_top = 8
	face.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var cover := TextureRect.new()
	cover.name = "cover"
	cover.custom_minimum_size = Vector2(0, COVER_TALL)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.texture = _covers.get(str(card["picture"]))
	cover.set_meta("picture", str(card["picture"]))
	column.add_child(cover)
	var named: Label = _label(str(card["name"]), 13, 1.0)
	named.tooltip_text = str(card["name"])
	named.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(named)
	column.add_child(_label(str(card["facts"]), 11, 0.6))
	if not str(card["theme"]).is_empty():
		column.add_child(_label(str(card["theme"]), 11, 0.5))
	column.add_child(_label(str(card["credit"]), 11, 0.6))
	var go := Button.new()
	go.text = "Open"
	go.add_theme_font_size_override("font_size", 12)
	go.tooltip_text = "Open it in a new %s; the model here stays as it is" % _tab_word()
	go.pressed.connect(_open_card.bind(card))
	column.add_child(go)
	if first:
		_controls["library_open_first"] = go
	return panel


func _label(text: String, size: int, fade: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, fade)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


## Covers, a few at a time, each put on whichever card shows it now.
func _fetch_covers() -> void:
	_fetchers += 1
	while not _wanted.is_empty():
		var card: Dictionary = _wanted.pop_front()
		var picture: String = str(card["picture"])
		if _covers.has(picture):
			continue
		var texture: Texture2D = null
		if card["kind"] == "set":
			texture = await books.cover(card["entry"])
		else:
			var got: Dictionary = await books.fetch(picture, ModelLibrary.MOST_COVER)
			texture = ModelLibrary.picture(got["bytes"]) if int(got["code"]) == 200 else null
		_covers[picture] = texture
		for shown: Node in _grid.get_children():
			var rect: TextureRect = shown.find_child("cover", true, false) as TextureRect
			if rect != null and str(rect.get_meta("picture", "")) == picture:
				rect.texture = texture
	_fetchers -= 1
	_tell_page()


# --- opening ------------------------------------------------------------

## Open in a new tab, in the press itself: a browser opens a tab only in
## answer to one (Shell.IN_THE_PRESS).
func _open_card(card: Dictionary) -> void:
	var where: String = _tab_word()
	if card["kind"] == "set":
		TabSession.open_another({"library": str(card["id"])})
		_say("Opening %s in a new %s%s." % [ModelLibrary.title_of(card["entry"]), where,
			"" if OS.has_feature("web") else ": it takes a moment to start"])
	else:
		TabSession.open_another({"copy": str(card["id"])})
		_say("Copying “%s” into your models in a new %s%s." % [card["name"], where,
			"" if OS.has_feature("web") else ": it takes a moment to start"])
	last["opened"] = card["id"]
	said.emit(_status.text)
	_tell_page()


func _say(text: String) -> void:
	_status.text = text


## What the screen shows, for a browser test to read: window.brickworksLibrary.
func _tell_page() -> void:
	if not OS.has_feature("web"):
		return
	var covered: int = 0
	for card: Dictionary in _shown:
		if _covers.get(str(card["picture"])) != null:
			covered += 1
	var told: Dictionary = last.duplicate()
	told["open"] = visible
	told["covers"] = covered
	told["status"] = _status.text if _status != null else ""
	told["typed"] = _search.text
	told["searching"] = _search.has_focus()
	JavaScriptBridge.eval("window.brickworksLibrary = %s" % JSON.stringify(told), true)
