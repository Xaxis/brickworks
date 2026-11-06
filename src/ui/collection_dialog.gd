## My collection, on screen: what the person owns, what the open model
## needs that they do not, and what they could build.
##
## Three pages behind three buttons along the top, over the model like the
## parts list (it is consulted and dismissed, and wants the room):
##
##   What I own        bring it in — a Rebrickable account, a Rebrickable
##                     CSV export, a BrickLink XML, sets typed by number,
##                     loose parts one lot at a time — and see it, with
##                     Start over
##   What do I need?   the open model's parts against the collection: what
##                     is short, by part and colour, with what could stand
##                     in (the part in a colour that is spare, two smaller
##                     parts that make the same footprint, the other
##                     moulding), each part's BrickLink page, and the
##                     shortfall as a BrickLink wanted list or a
##                     Rebrickable CSV
##   What can I build? the examples, the person's own saved models and the
##                     official LDraw set models, ranked by how much of each
##                     they own
##
## Loose parts (mybricks, APP_UX5 #2, 2026-11-06): most people own a tub
## of loose bricks, not an inventory. A lot is added in one row — a part
## found by the bin's own search (a colour's name typed with it is taken:
## "red 2x4 brick"), by Like this, or from a photo of the part (the bin's
## Brickognize, which says the colour too), or chosen in the bin itself
## while this page is open; its colour; how many; Add — and listed under
## Loose parts, each lot's count changed or the lot taken out by itself.
## What a session added over MCP (edit_collection) is listed apart, under
## who added it, with Keep them and Take back.
##
## The sums are Collection's; the keeping is CollectionStore's, the one the
## window makes and fetches as the person signs in (Shell.collection_store),
## given to this panel as it is made. Built by Shell, which reaches the app
## the way it does for its own parts, so main.gd only has the parts list's
## new button to pass on.
class_name CollectionDialog
extends PanelContainer

const WIDE := 920.0
const TALL := 660.0
## Rows drawn on a page at most; the rest are counted.
const MOST_ROWS := 150
const OMR_PAGE := "https://library.ldraw.org/omr/sets/"

var app: Node
var library: PartLibrary
var world: BrickWorld
var models: ModelStore
var bar: ModelBar
## The window's (Shell.collection_store), set before [method attach].
var store: CollectionStore
var rebrickable: RebrickableAccount

var _picker: TextFilePicker
var _picking: String = ""
var _page: String = "own"
var _tabs: Dictionary = {}
var _pages: Dictionary = {}
var _status: Label
var _controls: Dictionary = {}

var _summary: Label
var _typed: LineEdit
var _own_rows: VBoxContainer
var _rb_key: LineEdit
var _rb_token: LineEdit
var _rb_user: LineEdit
var _rb_pass: LineEdit
var _confirm_clear: ConfirmationDialog

var _need_heading: Label
var _need_rows: VBoxContainer
var _need_stock: Inventory
var _need_plan: Array = []
var _need_cover: Dictionary = {}

var _build_heading: Label
var _build_rows: VBoxContainer
var _ranked: Array = []
## path -> {"modified", "needs"}, so a model is read once until it changes.
var _read: Dictionary = {}
var _busy: bool = false

signal said(text: String)


## What happens to a Rebrickable key: [method _rebrickable_note].
var _rb_note: Label

# The row a loose lot is added in, and what it has chosen.
var _loose_search: LineEdit
var _loose_colour: OptionButton
var _loose_count: SpinBox
var _loose_found: HFlowContainer
var _loose_picture: TextureRect
var _picture_wait: Timer
var _search_wait: Timer
## The part chosen to add, "" for none; the parts listed beside it; and how
## sure Brickognize was of each, while a photo's answer is listed.
var _loose_part: String = ""
var _loose_listed: Array[PartLibrary.PartInfo] = []
var _loose_sure: Dictionary = {}
## The colour codes the colour list holds, in its order.
var _colour_codes: Array[int] = []
var _photo: PickImage
var _brickognize: Brickognize
var _telling: ConfirmationDialog
var _likeness: PartLike
## Counts typed into the lots' rows, sent together a moment after the last:
## lot key -> [lot, the count its row shows as kept ({"qty"}), the count
## typed]. Sent, or dropped, before any other change is (mybricks2).
var _counts_typed: Dictionary = {}
var _count_wait: Timer
## A change at the account is being made: the next waits its turn, so each
## says what was shown after the one before it.
var _writing: bool = false
## A name -> LDraw code for every colour, as typed words say them
## (_colour_words): LDraw's, the LEGO Group's and the language's own.
var _colour_names: Dictionary = {}

## The most parts listed beside the chosen one.
const LISTED := 6


## Take the app's parts and put the panel on screen, hidden.
func attach(main: Node) -> void:
	app = main
	library = main.get("_library")
	world = main.get("_world")
	models = main.get("_store")
	bar = main.get("_bar")
	rebrickable = RebrickableAccount.new()
	add_child(rebrickable)
	_picker = TextFilePicker.new()
	add_child(_picker)
	_picker.picked.connect(_on_file)
	_picker.failed.connect(func(why: String) -> void: _say(why))
	main.get_node("HUD").add_child(self)
	_fit()
	get_viewport().size_changed.connect(_fit)
	store.changed.connect(_on_store_changed)
	# A part chosen in the bin, by its search, Like this or a photo, while
	# What I own is open, is the part the row adds, in the bin's colour.
	var bin: PartsBin = main.get("_bin")
	if bin != null:
		bin.part_chosen.connect(func(id: String) -> void:
			if visible and _page == "own":
				choose_loose(id, int(bin.get("_selected_color"))))


func _ready() -> void:
	visible = false
	_build()


## Open on one page: "own", "need" or "build".
func open(page: String = "own") -> void:
	visible = true
	_rb_note.text = _rebrickable_note()
	_show(page)
	# What another device or a session changed since is shown, not a copy
	# read at sign-in (mbreview finding 1).
	if store.account != null and store.account.signed_in():
		store.load_collection()


## What happens to a Rebrickable key, and, with the assistant in the window
## (Settings, Assistant (AI)), what it can do with the collection.
static func _rebrickable_note() -> String:
	return ("Your Rebrickable key goes from here to rebrickable.com and nowhere else, and is "
		+ "not kept; what comes back replaces what Rebrickable brought before. What you count here, "
		+ "and what an assistant added, stay."
		+ (" Ask the assistant for \"a small house from my collection\" and it builds from what you own."
			if ShellPrefs.assistant_shown() else ""))


func is_showing() -> bool:
	return visible


func close() -> void:
	visible = false


## Where each control is, for a browser test to press it as a person does.
func controls_by_name() -> Dictionary:
	return _controls if visible else {}


func _fit() -> void:
	const MARGIN := 24.0
	var room: Vector2 = get_viewport().get_visible_rect().size
	var wide: float = minf(WIDE, room.x - MARGIN * 2.0)
	var tall: float = minf(TALL, room.y - MARGIN * 2.0)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -wide * 0.5
	offset_right = wide * 0.5
	offset_top = -tall * 0.5
	offset_bottom = tall * 0.5


func _on_store_changed() -> void:
	_read.clear()
	if visible:
		_show(_page)
	_tell_page()


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
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)
	var title := Label.new()
	title.text = "My collection"
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	header.add_child(gap)
	for page: Array in [["own", "What I own"], ["need", "What do I need?"],
			["build", "What can I build?"]]:
		var tab := Button.new()
		tab.text = page[1]
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
		# The same margins unlit, or the lit one is wider than the button
		# was measured for and its words are cut off.
		for state: String in ["normal", "hover"]:
			var plain: StyleBoxFlat = lit.duplicate()
			plain.bg_color = Color(1, 1, 1, 0.05 if state == "normal" else 0.12)
			# Edged as every button is (Look.OUTLINE), inside the same box.
			plain.border_color = Look.OUTLINE
			plain.set_border_width_all(1)
			tab.add_theme_stylebox_override(state, plain)
		var named: String = page[0]
		tab.pressed.connect(func() -> void: _show(named))
		header.add_child(tab)
		_tabs[named] = tab
		_controls["collection_tab_" + named] = tab
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(fill)
	var done := _button(header, "Done", close, "collection_done")
	done.focus_mode = Control.FOCUS_NONE

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.7)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stack)
	_pages["own"] = _own_page()
	_pages["need"] = _need_page()
	_pages["build"] = _build_page()
	for page: String in _pages:
		var holder: Control = _pages[page]
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		stack.add_child(holder)

	_confirm_clear = ConfirmationDialog.new()
	_confirm_clear.title = "Start over"
	_confirm_clear.dialog_text = "Forget every set and part in your collection? This cannot be undone."
	_confirm_clear.ok_button_text = "Forget it all"
	_confirm_clear.confirmed.connect(_on_clear)
	add_child(_confirm_clear)


func _own_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 13)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_summary)

	var typed := HBoxContainer.new()
	typed.add_theme_constant_override("separation", 8)
	page.add_child(typed)
	_typed = LineEdit.new()
	_typed.placeholder_text = "Set numbers: 10237-1, 6020"
	_typed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_typed.add_theme_font_size_override("font_size", 12)
	_typed.text_submitted.connect(func(_t: String) -> void: _add_typed())
	typed.add_child(_typed)
	_controls["collection_sets"] = _typed
	_button(typed, "Add sets", _add_typed, "collection_add_sets")

	var files := HBoxContainer.new()
	files.add_theme_constant_override("separation", 8)
	page.add_child(files)
	# Straight from the press into the chooser: see TextFilePicker.
	_button(files, "Rebrickable CSV…", func() -> void:
		_picking = "rebrickable_csv"
		_picker.ask(".csv,.txt"), "collection_csv",
		"A sets list or a parts list exported from Rebrickable (My LEGO®, Export)")
	_button(files, "BrickLink XML…", func() -> void:
		_picking = "bricklink_xml"
		_picker.ask(".xml,.txt"), "collection_xml",
		"A BrickLink wanted list or inventory, as XML")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	files.add_child(spacer)
	_button(files, "Start over…", func() -> void: _confirm_clear.popup_centered(),
		"collection_clear", "Forget every set and part in your collection")

	var account := HBoxContainer.new()
	account.add_theme_constant_override("separation", 6)
	page.add_child(account)
	account.add_child(_label("Rebrickable account", 12, 0.75))
	_rb_key = _field(account, "Rebrickable API key", true, "collection_rb_key")
	_rb_token = _field(account, "User token", true, "collection_rb_token")
	_rb_user = _field(account, "or username", false, "collection_rb_user")
	_rb_pass = _field(account, "and password", true, "collection_rb_pass")
	_button(account, "Fetch", _fetch_rebrickable, "collection_rb_go",
		"Read your sets and parts lists from your Rebrickable account")
	var note := Label.new()
	note.text = _rebrickable_note()
	_rb_note = note
	note.add_theme_font_size_override("font_size", 11)
	note.modulate = Color(1, 1, 1, 0.55)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)

	_loose_row(page)
	_own_rows = _scrolled(page)
	return page


## The row a loose lot is added in: a part (searched for, from a photo, or
## like the one chosen), its colour, how many, Add; and under it, the part
## chosen and the others found.
func _loose_row(page: Container) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	# Its own width: a clipped label beside a field that fills the row had
	# none, and the row went unnamed.
	var named: Label = _label("Loose parts", 12, 0.75)
	named.clip_text = false
	row.add_child(named)
	_loose_search = LineEdit.new()
	_loose_search.placeholder_text = "A part: its number or words, like red 2x4 brick"
	_loose_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loose_search.add_theme_font_size_override("font_size", 12)
	_loose_search.clear_button_enabled = true
	_loose_search.text_submitted.connect(func(text: String) -> void:
		_search_wait.stop()
		search_loose(text)
		if not _loose_part.is_empty():
			_loose_count.get_line_edit().grab_focus()
			_loose_count.get_line_edit().select_all())
	_loose_search.text_changed.connect(func(_text: String) -> void: _search_wait.start())
	row.add_child(_loose_search)
	_controls["collection_loose_search"] = _loose_search
	_search_wait = Timer.new()
	_search_wait.one_shot = true
	_search_wait.wait_time = 0.3
	_search_wait.timeout.connect(func() -> void: search_loose(_loose_search.text))
	add_child(_search_wait)
	_button(row, "Photo…", _ask_photo, "collection_loose_photo",
		"Find the part from a photo of it, as the parts bin's camera does")
	_button(row, "Like this", like_loose, "collection_loose_like",
		"Parts like the one chosen: its other sizes and kinds")
	_loose_colour = OptionButton.new()
	_loose_colour.add_theme_font_size_override("font_size", 12)
	_loose_colour.custom_minimum_size = Vector2(170, 0)
	_loose_colour.fit_to_longest_item = false
	_loose_colour.clip_text = true
	_loose_colour.tooltip_text = "Its colour: the colours the part was made in first"
	_loose_colour.item_selected.connect(func(_at: int) -> void: _show_chosen())
	row.add_child(_loose_colour)
	_controls["collection_loose_colour"] = _loose_colour
	_loose_count = SpinBox.new()
	_loose_count.min_value = 1
	_loose_count.max_value = 100000
	_loose_count.step = 1
	_loose_count.value = 1
	_loose_count.select_all_on_focus = true
	_loose_count.custom_minimum_size = Vector2(76, 0)
	_loose_count.tooltip_text = "How many"
	_loose_count.get_line_edit().add_theme_font_size_override("font_size", 12)
	_loose_count.get_line_edit().text_submitted.connect(func(text: String) -> void:
		if text.strip_edges().is_valid_int():
			_loose_count.value = clampi(int(text), 1, 100000)
		add_loose())
	row.add_child(_loose_count)
	_controls["collection_loose_count"] = _loose_count
	_button(row, "Add", add_loose, "collection_loose_add",
		"Add these to your loose parts, kept with your account")

	# Flowing, so the parts found go onto a second line rather than widen
	# the page: in one row, six of them pushed Add, Add sets and every
	# Remove past the dialog's edge at 1280 x 720.
	_loose_found = HFlowContainer.new()
	_loose_found.add_theme_constant_override("h_separation", 4)
	_loose_found.add_theme_constant_override("v_separation", 4)
	_loose_found.custom_minimum_size = Vector2(0, 30)
	page.add_child(_loose_found)
	_picture_wait = Timer.new()
	_picture_wait.wait_time = 0.25
	_picture_wait.timeout.connect(_show_picture)
	add_child(_picture_wait)
	_count_wait = Timer.new()
	_count_wait.one_shot = true
	_count_wait.wait_time = 0.6
	_count_wait.timeout.connect(_send_counts)
	add_child(_count_wait)
	_show_chosen()


func _need_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	page.add_child(top)
	_need_heading = Label.new()
	_need_heading.add_theme_font_size_override("font_size", 13)
	_need_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_need_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_need_heading)
	_button(top, "BrickLink wanted list", func() -> void: _export("bricklink"),
		"collection_export_bricklink", "What is short, as an XML BrickLink's wanted lists take")
	_button(top, "Rebrickable CSV", func() -> void: _export("rebrickable"),
		"collection_export_rebrickable", "What is short, as a parts list Rebrickable imports")
	var note := Label.new()
	note.text = ("BrickLink's prices are not free to read, so each part links to its BrickLink "
		+ "page instead. What could stand in comes from what this model does not itself use.")
	note.add_theme_font_size_override("font_size", 11)
	note.modulate = Color(1, 1, 1, 0.55)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 9)
	page.add_child(columns)
	var short: Label = _label("short of", 11, 0.5, 64.0)
	short.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	columns.add_child(short)
	columns.add_child(_label("", 11, 0.5, 15.0))
	columns.add_child(_label("part", 11, 0.5, 74.0))
	var named: Label = _label("name", 11, 0.5)
	named.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(named)
	columns.add_child(_label("colour", 11, 0.5, 150.0))
	columns.add_child(_label("shop", 11, 0.5, 60.0))
	_need_rows = _scrolled(page)
	return page


func _build_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	_build_heading = Label.new()
	_build_heading.add_theme_font_size_override("font_size", 13)
	_build_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_build_heading)
	_build_rows = _scrolled(page)
	return page


func _scrolled(into: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	into.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 3)
	scroll.add_child(rows)
	return rows


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


func _field(row: Container, hint: String, secret: bool, named: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.secret = secret
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", 12)
	row.add_child(field)
	_controls[named] = field
	return field


func _label(text: String, size: int = 12, fade: float = 1.0, wide: float = 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, fade)
	label.clip_text = true
	if wide > 0.0:
		label.custom_minimum_size = Vector2(wide, 0)
	return label


func _swatch(code: int) -> Panel:
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(15, 15)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	var colour: PartLibrary.BrickColor = library.color(code)
	style.bg_color = colour.shown if colour != null else Color.MAGENTA
	style.set_corner_radius_all(3)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.3)
	if colour != null and colour.is_transparent():
		style.set_border_width_all(2)
		style.border_color = Color(colour.rgb, 1.0).darkened(0.4)
	swatch.add_theme_stylebox_override("panel", style)
	return swatch


func _clear_rows(rows: Container) -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()


func _say(text: String) -> void:
	_status.text = text
	said.emit(text)
	_tell_page()


# --- the pages ----------------------------------------------------------

func _show(page: String) -> void:
	_page = page
	for name: String in _pages:
		(_pages[name] as Control).visible = name == page
		(_tabs[name] as Button).button_pressed = name == page
	match page:
		"own":
			_fill_own()
		"need":
			_fill_need()
		"build":
			_fill_build()
	_tell_page()


func _fill_own() -> void:
	var mine: Collection = store.collection
	var sets: int = 0
	for entry: Dictionary in mine.sets:
		sets += int(entry["qty"])
	if mine.is_empty():
		_summary.text = ("Nothing here yet. Bring in what you own: your Rebrickable account, "
			+ "a Rebrickable or BrickLink export, or set numbers typed in.")
	else:
		_summary.text = "%d set%s and %s loose piece%s — %s pieces in all%s" % [
			sets, "" if sets == 1 else "s", _comma(mine.loose_pieces()),
			"" if mine.loose_pieces() == 1 else "s", _comma(store.pieces_on_hand()),
			" (the copy on this device)" if store.offline else ", kept with your account"]
	_clear_rows(_own_rows)
	_controls.erase("collection_build_all")
	_controls.erase("collection_build_first")
	if not mine.sets.is_empty():
		var heading := HBoxContainer.new()
		var named: Label = _label("Sets", 12, 0.6)
		named.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(named)
		# Every set owned, counted together, as one bin to build from.
		var every := PackedStringArray()
		for entry: Dictionary in mine.sets:
			for _copy: int in int(entry["qty"]):
				every.append(str(entry["set"]))
		if every.size() > 1:
			_small(_button(heading, "Build from them all", _build_from.bind(every),
				"collection_build_all", "The bin becomes the parts of every set here, counted "
				+ "together, each counting how many are left as you build"))
		_own_rows.add_child(heading)
	for entry: Dictionary in mine.sets:
		var number: String = str(entry["set"])
		var record: Dictionary = store.records.get(number, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		row.add_child(_label("%d ×" % int(entry["qty"]), 12, 1.0, 40.0))
		row.add_child(_label(number, 12, 0.55, 90.0))
		var name: Label = _label(str(record.get("n", "no inventory known for this set"))
			+ (" (%d)" % int(record["y"]) if record.has("y") else "")
			+ _from_words(str(entry.get("src", ""))), 12,
			1.0 if not record.is_empty() else 0.5)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var pieces: int = 0
		for lot: Variant in record.get("p", []):
			pieces += int((lot as Array)[2])
		row.add_child(_label("%s pieces" % _comma(pieces) if pieces > 0 else "", 12, 0.6, 90.0))
		if pieces > 0:
			var copies := PackedStringArray()
			for _copy: int in int(entry["qty"]):
				copies.append(number)
			var build: Button = _small(_button(row, "Build from it", _build_from.bind(copies), "",
				"The bin becomes this set's parts, each counting how many are left as you build"))
			if not _controls.has("collection_build_first"):
				_controls["collection_build_first"] = build
		var drop := Button.new()
		drop.text = "Remove"
		drop.add_theme_font_size_override("font_size", 11)
		drop.pressed.connect(_remove_set.bind(entry))
		row.add_child(drop)
		_own_rows.add_child(row)
	# What a session added first, apart, to be looked over: kept as the
	# person's own, or taken back, all at once.
	var added: Array = mine.added_lots()
	_controls.erase("collection_take_back")
	_controls.erase("collection_keep_added")
	if not added.is_empty():
		var pieces: int = 0
		var who: Dictionary = {}
		for lot: Dictionary in added:
			pieces += int(lot["qty"])
			who[str(lot["by"])] = true
		var named: String = str(who.keys()[0]) if who.size() == 1 else "your assistants"
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 8)
		var said: Label = _label("Added by %s — %s, %s: look them over" % [named,
			Counted.of(added.size(), "lot"), Counted.of(pieces, "piece")], 12, 0.85)
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		said.add_theme_color_override("font_color", Look.ACCENT)
		heading.add_child(said)
		_small(_button(heading, "Keep them", _keep_added, "collection_keep_added",
			"Keep these as your own loose parts"))
		_small(_button(heading, "Take back what %s added" % named, _take_back,
			"collection_take_back", "Take out exactly the lots listed here; nothing of yours"))
		_own_rows.add_child(heading)
		for lot: Dictionary in added.slice(0, MOST_ROWS):
			_own_rows.add_child(_lot_row(lot))
	# The person's own, under where each came from: what they counted here
	# first, then each import's (a Rebrickable fetch replaces only its own).
	var shown: int = 0
	for from: String in Collection.SOURCES:
		var loose: Array = mine.own_lots(from)
		if loose.is_empty():
			continue
		_own_rows.add_child(_label("%s — %s" % [Collection.SOURCES[from], Counted.of(loose.size(), "lot")], 12, 0.6))
		for n: int in loose.size():
			if shown >= MOST_ROWS:
				_own_rows.add_child(_label("…and %d more lots" % (loose.size() - n), 12, 0.5))
				break
			shown += 1
			_own_rows.add_child(_lot_row(loose[n]))


func _part_row(part: String, colour: int, count: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var counted: Label = _label(count, 12, 1.0, 64.0)
	counted.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(counted)
	row.add_child(_swatch(colour))
	row.add_child(_label(part, 12, 0.55, 74.0))
	var info: PartLibrary.PartInfo = library.parts.get(part)
	var name: Label = _label(Inventory._tidy(info.name) if info != null else "not in the library")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(_label(_colour(colour), 12, 0.6, 150.0))
	return row


## A loose lot on What I own: how many (changed in place), its part and
## colour, and Remove.
func _lot_row(lot: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = _part_row(str(lot["part"]), int(lot["colour"]), "")
	var counted: Control = row.get_child(0)
	row.remove_child(counted)
	counted.queue_free()
	var count := SpinBox.new()
	count.min_value = 1
	count.max_value = 100000
	count.step = 1
	count.value = int(lot["qty"])
	count.select_all_on_focus = true
	count.custom_minimum_size = Vector2(64, 0)
	count.get_line_edit().add_theme_font_size_override("font_size", 12)
	count.tooltip_text = "How many you have; changed here, kept with your account"
	# The count this row shows as kept: what a change typed here says it saw.
	var kept: Dictionary = {"qty": int(lot["qty"])}
	count.value_changed.connect(func(value: float) -> void: _count_typed(lot, kept, int(value)))
	row.add_child(count)
	row.move_child(count, 0)
	row.set_meta("lot", lot)
	var drop := Button.new()
	drop.text = "Remove"
	drop.tooltip_text = "Take this lot out of your collection"
	drop.add_theme_font_size_override("font_size", 11)
	drop.pressed.connect(func() -> void: remove_lot(lot, kept))
	row.add_child(drop)
	return row


## The lots' rows on What I own, in order, each with its lot (meta "lot").
func lot_rows() -> Array[HBoxContainer]:
	var out: Array[HBoxContainer] = []
	for child: Node in _own_rows.get_children():
		if child is HBoxContainer and (child as HBoxContainer).has_meta("lot"):
			out.append(child)
	return out


func _fill_need() -> void:
	_clear_rows(_need_rows)
	_need_stock = Inventory.of(world, library, models.scenery)
	if _need_stock.pieces == 0:
		_need_heading.text = "There is nothing on the baseplate yet to check against your collection."
		_need_plan = []
		_need_cover = {}
		return
	var needs: Dictionary = Collection.needs_of(_need_stock, library)
	_need_cover = Collection.coverage(needs, store.on_hand)
	_need_plan = Collection.plan(needs, store.on_hand, library)
	var short: int = 0
	var left: int = 0
	for row: Dictionary in _need_plan:
		short += int(row["short"])
		left += int(row["left"])
	var title: String = bar.model_name() if bar != null else "This model"
	if store.collection.is_empty():
		_need_heading.text = ("%s needs %s pieces. Your collection is empty, so all of it is short — "
			+ "add what you own on the first page.") % [title, _comma(int(_need_cover["pieces"]))]
	elif short == 0:
		_need_heading.text = "%s: you own all %s pieces it needs." % [title,
			_comma(int(_need_cover["pieces"]))]
	else:
		_need_heading.text = ("%s: %s pieces — you own %s (%d%%). Short: %s pieces in %d lots%s.") % [
			title, _comma(int(_need_cover["pieces"])), _comma(int(_need_cover["owned"])),
			roundi(100.0 * float(_need_cover["exact"])), _comma(short), _need_plan.size(),
			"" if left == short else ", %s once what could stand in is used" % _comma(left)]
	var shown: int = 0
	for row: Dictionary in _need_plan:
		if shown >= MOST_ROWS:
			_need_rows.add_child(_label("…and %d more lots" % (_need_plan.size() - shown), 12, 0.5))
			break
		shown += 1
		_need_rows.add_child(_need_row(row))


func _need_row(row: Dictionary) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	var line: HBoxContainer = _part_row(str(row["part"]), int(row["colour"]),
		"%d of %d" % [int(row["short"]), int(row["need"])])
	var link := LinkButton.new()
	link.text = "BrickLink"
	link.add_theme_font_size_override("font_size", 11)
	link.tooltip_text = "This part, in this colour, on BrickLink"
	var url: String = Collection.bricklink_page(str(row["part"]), int(row["colour"]), library)
	link.pressed.connect(func() -> void: Outside.open_link(url))
	line.add_child(link)
	block.add_child(line)
	var could := PackedStringArray()
	for swap: Dictionary in row["swaps"]:
		could.append("%d in %s" % [int(swap["qty"]), _colour(int(swap["colour"]))])
	for combo: Dictionary in row["combos"]:
		var pieces := PackedStringArray()
		for piece: Array in combo["parts"]:
			var info: PartLibrary.PartInfo = library.parts.get(str(piece[0]))
			pieces.append("%s%s" % ["%d × " % int(piece[1]) if int(piece[1]) > 1 else "",
				Inventory._tidy(info.name) if info != null else str(piece[0])])
		could.append("%d made of %s" % [int(combo["qty"]), " + ".join(pieces)])
	var said: String = ""
	if not could.is_empty():
		said = "could stand in: " + "; ".join(could)
	if not (row["moulds"] as Array).is_empty():
		var other := PackedStringArray()
		for mould: Array in row["moulds"]:
			other.append("%d as %s" % [int(mould[1]), Collection.part_of(str(mould[0]))])
		said += ("; " if not said.is_empty() else "") + "counted as had: " + ", ".join(other)
	if int(row["left"]) > 0 and int(row["left"]) < int(row["short"]):
		said += " — still %d to find" % int(row["left"])
	if not said.is_empty():
		var note: Label = _label("          " + said, 11, 0.6)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.clip_text = false
		block.add_child(note)
	return block


func _export(shop: String) -> void:
	if _need_stock == null or _need_plan.is_empty():
		_say("nothing is short, so there is nothing to order")
		return
	var short: Inventory = Collection.shortfall_stock(_need_stock, _need_plan, library)
	var title: String = (bar.model_name() if bar != null else "model").to_snake_case()
	if title.is_empty():
		title = "model"
	var made: Dictionary
	var line: String
	if shop == "bricklink":
		made = ShopLists.bricklink_xml(short, library)
		line = await Download.save(str(made["text"]), title + "_wanted.xml", "application/xml")
	else:
		made = ShopLists.rebrickable_csv(short)
		line = await Download.save(str(made["text"]), title + "_wanted.csv", "text/csv")
	if line.is_empty():
		return
	if int(made["left_out"]) > 0:
		line += " — %d lots left off: %s" % [int(made["left_out"]),
			ShopLists.why_left_off(made, shop)]
	_say("%s: %d pieces in %d lots%s" % [line.get_slice(" —", 0), short.pieces,
		int(made["lots"]), "" if int(made["left_out"]) == 0 else " —" + line.get_slice(" —", 1)])


func _fill_build() -> void:
	_clear_rows(_build_rows)
	_controls.erase("collection_open_first")
	if _busy:
		return
	_busy = true
	_build_heading.text = "Counting what you could build…"
	var candidates: Array = []
	for entry: ModelStore.Entry in models.list_saved():
		candidates.append({"name": entry.name, "kind": "Yours", "path": entry.path,
			"needs": _needs_at(entry.path)})
	for entry: ModelStore.Entry in models.list_examples():
		candidates.append({"name": entry.name, "kind": "Example", "path": entry.path,
			"needs": _needs_at(entry.path)})
	for model: Dictionary in await store.inventories.official_models():
		candidates.append({"name": str(model["name"]), "kind": "Official set %s%s" % [
			str(model["set"]), " (%d)" % int(model["year"]) if int(model["year"]) > 0 else ""],
			"file": str(model["file"]), "set": str(model["set"]), "page": str(model["page"]),
			"needs": model["needs"]})
	_ranked = []
	for candidate: Dictionary in candidates:
		if (candidate["needs"] as Dictionary).is_empty():
			continue
		candidate["cover"] = Collection.coverage(candidate["needs"], store.on_hand)
		_ranked.append(candidate)
	_ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var x: Dictionary = a["cover"]
		var y: Dictionary = b["cover"]
		if not is_equal_approx(float(x["exact"]), float(y["exact"])):
			return float(x["exact"]) > float(y["exact"])
		if not is_equal_approx(float(x["any_colour"]), float(y["any_colour"])):
			return float(x["any_colour"]) > float(y["any_colour"])
		return int(x["pieces"]) < int(y["pieces"]))
	_busy = false
	if store.collection.is_empty():
		_build_heading.text = ("Add what you own on the first page, and every model here is "
			+ "ranked by how much of it you already have.")
	else:
		_build_heading.text = ("%d models, most of it owned first: the examples, your own saved "
			+ "models, and the official LDraw models of real sets.") % _ranked.size()
	var shown: int = 0
	for candidate: Dictionary in _ranked:
		if shown >= MOST_ROWS:
			_build_rows.add_child(_label("…and %d more" % (_ranked.size() - shown), 12, 0.5))
			break
		shown += 1
		_build_rows.add_child(_build_row(candidate))
	_tell_page()


func _build_row(candidate: Dictionary) -> Control:
	var cover: Dictionary = candidate["cover"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var share: Label = _label("%d%%" % roundi(100.0 * float(cover["exact"])), 15, 1.0, 54.0)
	share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(share)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_label(str(candidate["name"]), 13))
	words.add_child(_label("%s — %s of %s pieces owned, %s missing; %d%% in any colour" % [
		str(candidate["kind"]), _comma(int(cover["owned"])), _comma(int(cover["pieces"])),
		_comma(int(cover["missing"])), roundi(100.0 * float(cover["any_colour"]))], 11, 0.6))
	row.add_child(words)
	var go := Button.new()
	go.add_theme_font_size_override("font_size", 12)
	if candidate.has("path") or FileAccess.file_exists("res://vendor/omr/files/" + str(candidate.get("file", ""))):
		go.text = "Open"
		go.tooltip_text = "Open it, and see what is missing"
		go.pressed.connect(_open_candidate.bind(candidate))
	else:
		go.text = "See it"
		go.tooltip_text = "The official LDraw model of this set, at library.ldraw.org"
		var page: String = str(candidate.get("page", ""))
		go.disabled = page.is_empty()
		go.pressed.connect(func() -> void: Outside.open_link(OMR_PAGE + page))
	row.add_child(go)
	# The flows' hook is the first row that opens in the app. On the web an
	# official set's model only links out, and since m95 matched them to their
	# sets one often ranks first.
	if go.text == "Open" and not _controls.has("collection_open_first"):
		_controls["collection_open_first"] = go
	return row


func _open_candidate(candidate: Dictionary) -> void:
	if bar != null and not await bar.ask_to_replace("“%s”" % candidate.get("name",
			str(candidate.get("path", "")).get_file().get_basename())):
		return
	var placed: int = 0
	if candidate.has("path"):
		placed = await models.open_fetched(str(candidate["path"]))
	else:
		var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/" + str(candidate["file"]))
		placed = int((await models.open_text_fetched(text, str(candidate["name"])))["placed"])
	if not models.not_opened.is_empty():
		_say("could not open %s: %s" % [candidate.get("name", str(candidate.get("path", "")).get_file()),
			models.not_opened])
		return
	if bar != null:
		bar.opened.emit(placed)
	open("need")


func _needs_at(path: String) -> Dictionary:
	var modified: int = FileAccess.get_modified_time(path)
	var held: Dictionary = _read.get(path, {})
	if not held.is_empty() and int(held["modified"]) == modified:
		return held["needs"]
	var needs: Dictionary = Collection.needs_of_ldraw(FileAccess.get_file_as_string(path), library)
	_read[path] = {"modified": modified, "needs": needs}
	return needs


# --- what the buttons do ------------------------------------------------

func _add_typed() -> void:
	var text: String = _typed.text.strip_edges()
	if text.is_empty():
		_say("type a set number first, like 10237-1")
		return
	_say("adding %s…" % text)
	await _begin()
	var result: Dictionary = await store.add({"from": "sets", "text": text, "mode": "add"})
	_end()
	if not str(result["error"]).is_empty():
		_say(str(result["error"]))
		return
	_typed.text = ""
	var unknown: PackedStringArray = store.collection.unknown_sets
	_say("added %s%s" % [text, "" if unknown.is_empty()
		else " — no inventory is known for %s, so it adds no parts" % ", ".join(unknown)])


func _on_file(text: String, file_name: String) -> void:
	_say("reading %s…" % file_name)
	await _begin()
	var result: Dictionary = await store.add({"from": _picking, "text": text, "mode": "add"})
	_end()
	_report(result, file_name)


func _fetch_rebrickable() -> void:
	_say("asking Rebrickable…")
	var got: Dictionary = await rebrickable.read(_rb_key.text, _rb_token.text, _rb_user.text,
		_rb_pass.text)
	_rb_pass.text = ""
	if not str(got["error"]).is_empty():
		_say(str(got["error"]))
		return
	if (got["sets"] as Array).is_empty() and (got["parts"] as Array).is_empty():
		_say("Rebrickable has no sets or parts lists for that account")
		return
	await _begin()
	var result: Dictionary = await store.add({"from": "rebrickable_api", "sets": got["sets"],
		"parts": got["parts"], "mode": "replace"})
	_end()
	_report(result, "your Rebrickable account")


func _report(result: Dictionary, source: String) -> void:
	if not str(result["error"]).is_empty():
		_say("%s: %s" % [source, str(result["error"])])
		return
	var imported: Dictionary = result["imported"]
	var line: String = "from %s: %d set%s and %d lot%s of parts" % [source,
		int(imported.get("sets", 0)), "" if int(imported.get("sets", 0)) == 1 else "s",
		int(imported.get("lots", 0)), "" if int(imported.get("lots", 0)) == 1 else "s"]
	var left := PackedStringArray()
	for out: Variant in result["left_out"]:
		left.append("%d %s" % [int((out as Dictionary).get("count", 0)), str((out as Dictionary).get("why", ""))])
	if not left.is_empty():
		line += " — left out: " + "; ".join(left)
	var unknown: PackedStringArray = store.collection.unknown_sets
	if not unknown.is_empty():
		line += " — no inventory is known for %s" % ", ".join(unknown)
	_say(line)


func _small(button: Button) -> Button:
	button.add_theme_font_size_override("font_size", 11)
	return button


## Build from [param numbers]' parts: the bin becomes theirs (PartsBin
## .build_from), and the panel makes way for it.
func _build_from(numbers: PackedStringArray) -> void:
	var bin: PartsBin = app.get("_bin") if app != null else null
	if bin == null:
		return
	if await bin.build_from(numbers) == 0:
		_say("could not build from %s: %s" % [" ".join(numbers), bin.trouble])
		return
	var dock: Variant = app.get("_bin_dock")
	if dock != null and not dock.is_open():
		dock.set_open(true)
	close()
	if bar != null:
		bar.say("building from the parts of %s" % bin.set_showing())


# --- a loose part ---------------------------------------------------------

## What is typed into the row: a part by the bin's own search (PartLibrary
## .search, the words a family's first, PartsBin._named_first), the first
## found chosen; a colour named with it ("red 2x4 brick", "3001 light bluish
## grey") is taken as the colour.
func search_loose(text: String) -> void:
	var words: PackedStringArray = text.strip_edges().split(" ", false)
	var named: Array = _colour_in(words)
	var code: int = int(named[0])
	var asked: String = " ".join(named[1] as PackedStringArray)
	_loose_sure = {}
	if asked.is_empty():
		_loose_listed = []
		if code >= 0:
			_pick_colour(code)
		_show_chosen()
		return
	var needles: PackedStringArray = PartLibrary.in_ldraw_words(asked).split(" ", false)
	var found: Array[PartLibrary.PartInfo] = []
	for info: PartLibrary.PartInfo in library.search(asked, 200, true, true,
			PartWords.spoken(Language.current())):
		if info.reachable and Collection.ownable(info.id, library):
			found.append(info)
	found = PartsBin._named_first(found, needles)
	# The part named exactly as asked, first: the search put the Plate 1 x 1
	# Round, used more, before the Plate 1 x 1 to "black plate 1 x 1", and a
	# person counting their own pile then had a fourth action to choose it.
	var said: String = " ".join(needles)
	for n: int in found.size():
		if " ".join(PartLibrary.in_ldraw_words(found[n].name).split(" ", false)) == said:
			found.push_front(found.pop_at(n))
			break
	_loose_listed = found.slice(0, LISTED)
	if found.is_empty():
		_loose_part = ""
		_say("no part answers “%s”" % asked)
		_show_chosen()
		return
	choose_loose(found[0].id, code if code >= 0 else -1, false)


## [param id] is the part the row adds, in [param colour] (-1 keeps the
## colour chosen); with [param relist], the parts listed beside it are it
## alone.
func choose_loose(id: String, colour: int = -1, relist: bool = true) -> void:
	var info: PartLibrary.PartInfo = library.parts.get(library.resolve(id))
	if info == null:
		return
	_loose_part = info.id
	if relist:
		_loose_listed = [info]
		_loose_sure = {}
	_fill_colours(info, colour if colour >= 0 else _chosen_colour())
	_show_chosen()


## Parts like the one chosen (PartLike, as the bin's Like this lists them),
## listed beside it to choose from.
func like_loose() -> void:
	if _loose_part.is_empty():
		_say("choose a part first, then Like this lists parts like it")
		return
	if _likeness == null:
		_likeness = PartLike.new(library)
	while not _likeness.ready():
		_likeness.read_some(12.0)
		await get_tree().process_frame
	var subject: PartLibrary.PartInfo = library.parts.get(_loose_part)
	var like: Array[PartLibrary.PartInfo] = [subject]
	for info: PartLibrary.PartInfo in _likeness.like(_loose_part):
		if like.size() > LISTED:
			break
		if info.reachable and info.id != _loose_part and Collection.ownable(info.id, library):
			like.append(info)
	_loose_listed = like
	_loose_sure = {}
	_say("parts like %s: choose one" % Inventory._tidy(subject.name))
	_show_chosen()


## The camera: the photo goes to Brickognize, a third party, which is said
## before the first one, as the bin says it (the same choice, kept once).
func _ask_photo() -> void:
	if _photo == null:
		_photo = PickImage.new()
		_photo.picked.connect(func(image: Image) -> void:
			_say("asking Brickognize what part this is…")
			_brickognize.identify(image))
		_photo.failed.connect(func(why: String) -> void:
			if why != "no picture chosen":
				_say(why))
		add_child(_photo)
		_brickognize = Brickognize.new()
		_brickognize.answered.connect(show_guesses)
		_brickognize.failed.connect(func(why: String) -> void: _say(why))
		add_child(_brickognize)
	if bool(ShellPrefs.value("photo_told")):
		_photo.ask()
		return
	if _telling == null:
		_telling = ConfirmationDialog.new()
		_telling.title = "Find a part from a photo"
		_telling.dialog_text = ("The photo you choose is sent to Brickognize "
			+ "(brickognize.com), a third party that identifies LEGO® parts. Under its "
			+ "terms it may keep the photo and use it to train its recognition, and it is "
			+ "for personal, non-commercial use: Pro’s licence for commercial use does not "
			+ "cover it.\n\n"
			+ "Nothing is sent until you choose a photo.")
		_telling.dialog_autowrap = true
		_telling.ok_button_text = "Choose a photo"
		_telling.confirmed.connect(func() -> void:
			ShellPrefs.put("photo_told", true)
			_photo.ask())
		add_child(_telling)
	_telling.popup_centered(Vector2i(420, 0))


## A photo's answer: Brickognize's guesses, most likely first, as the part
## here (PartLibrary.by_shop), the first chosen, in the colour the photo
## shows where Brickognize is sure of it (PartsBin.COLOUR_LEAST).
## [param seen] is its colour, {"bricklink", "score"}; the answer's own
## when not given.
func show_guesses(guesses: Array, seen: Dictionary = {}) -> void:
	if seen.is_empty() and _brickognize != null:
		seen = _brickognize.colour
	var found: Array[PartLibrary.PartInfo] = []
	var sure: Dictionary = {}
	for guess: Dictionary in guesses:
		var info: PartLibrary.PartInfo = library.parts.get(library.by_shop(str(guess["bricklink"])))
		if info == null or not info.reachable or sure.has(info.id):
			continue
		sure[info.id] = float(guess["score"])
		found.append(info)
	if found.is_empty():
		_say("Brickognize saw no part it knows in that photo: try another, the part alone on a plain background")
		return
	var code: int = int(PartLibrary.by_bricklink.get(int(seen.get("bricklink", -1)), -1)) \
		if float(seen.get("score", 0.0)) >= PartsBin.COLOUR_LEAST else -1
	_loose_listed = found.slice(0, LISTED)
	choose_loose(found[0].id, code if library.colors.has(code) else -1, false)
	_loose_sure = sure
	_show_chosen()
	_say("from your photo, most likely first, as Brickognize sees it")


## Add the row's lot to the collection, at the account.
func add_loose() -> void:
	if _loose_part.is_empty():
		_say("find the part first: its number or words, or a photo of it")
		return
	var colour: int = _chosen_colour()
	var count: int = int(_loose_count.value)
	var info: PartLibrary.PartInfo = library.parts.get(_loose_part)
	_say("adding %d × %s…" % [count, Inventory._tidy(info.name)])
	await _begin()
	var done: Dictionary = await store.change_lots([{"part": _loose_part, "colour": colour, "qty": count}])
	_end()
	if done["kind"] != CollectionStore.DONE:
		_say(str(done["said"]))
		return
	_say("added %d × %s in %s" % [count, Inventory._tidy(info.name), _colour(colour)])
	_loose_search.text = ""
	_loose_count.value = 1
	_loose_search.grab_focus()


## A change's turn: after the one being made, and after any count still
## being typed is sent, so what it says it saw is what is shown.
func _begin() -> void:
	while _writing:
		await get_tree().process_frame
	_writing = true
	_count_wait.stop()
	await _send_typed()


func _end() -> void:
	_writing = false


## A lot's count typed into its row: sent with any others typed a moment
## after the last, as one change, from the count the row showed.
func _count_typed(lot: Dictionary, kept: Dictionary, count: int) -> void:
	var key: String = _lot_key(lot)
	if count == int(kept["qty"]) and not _counts_typed.has(key):
		return
	_counts_typed[key] = [lot, kept, count]
	_count_wait.start()


func _send_counts() -> void:
	await _begin()
	_end()


## The counts typed, sent: each from the count its row showed as kept.
## Refused when any is no longer that, and the collection shown as it is.
func _send_typed() -> void:
	var asked: Array = []
	var rows: Array = []
	for key: String in _counts_typed:
		var entry: Array = _counts_typed[key]
		if int(entry[2]) == int((entry[1] as Dictionary)["qty"]):
			continue
		var one: Dictionary = (entry[0] as Dictionary).duplicate()
		one["qty"] = int((entry[1] as Dictionary)["qty"])
		one["to"] = int(entry[2])
		asked.append(one)
		rows.append(entry)
	_counts_typed.clear()
	if asked.is_empty():
		return
	var done: Dictionary = await store.set_counts(asked)
	if done["kind"] == CollectionStore.DONE:
		for entry: Array in rows:
			(entry[1] as Dictionary)["qty"] = int(entry[2])
	_say(str(done["said"]) if done["kind"] != CollectionStore.DONE else "kept: %s" % ", ".join(asked.map(
		func(lot: Dictionary) -> String: return "%d × %s" % [int(lot["to"]), str(lot["part"])])))


## [param lot]'s count, as shown, put at [param count] at once (a probe's
## way; a row's own goes by [method _count_typed]). Returns what went wrong.
func set_lot_count(lot: Dictionary, count: int) -> String:
	await _begin()
	var asked: Dictionary = lot.duplicate()
	asked["to"] = count
	var done: Dictionary = await store.set_counts([asked])
	_end()
	_say(str(done["said"]) if done["kind"] != CollectionStore.DONE else "kept: %d × %s" % [count, str(lot["part"])])
	return str(done["said"])


## [param lot] taken out, at the count its row shows ([param kept], once a
## count typed there is sent; the lot's own when none). Returns what went
## wrong.
func remove_lot(lot: Dictionary, kept: Dictionary = {}) -> String:
	await _begin()
	var asked: Dictionary = lot.duplicate()
	asked["qty"] = int(kept.get("qty", lot["qty"]))
	asked["to"] = 0
	var done: Dictionary = await store.set_counts([asked])
	_end()
	var info: PartLibrary.PartInfo = library.parts.get(str(lot["part"]))
	_say(str(done["said"]) if done["kind"] != CollectionStore.DONE else "took out %d × %s in %s" % [int(asked["qty"]),
		Inventory._tidy(info.name) if info != null else str(lot["part"]), _colour(int(lot["colour"]))])
	return str(done["said"])


func _take_back() -> void:
	await _begin()
	var count: int = store.collection.added_lots().size()
	var done: Dictionary = await store.take_back()
	_end()
	_say(str(done["said"]) if done["kind"] != CollectionStore.DONE
		else "took back the %s added" % Counted.of(count, "lot"))


func _keep_added() -> void:
	await _begin()
	var count: int = store.collection.added_lots().size()
	var done: Dictionary = await store.keep_added()
	_end()
	_say(str(done["said"]) if done["kind"] != CollectionStore.DONE
		else "kept the %s as your own" % Counted.of(count, "lot"))


static func _lot_key(lot: Dictionary) -> String:
	return JSON.stringify([lot["part"], int(lot["colour"]), lot.get("src", ""), lot.get("by", ""), lot.get("chat", "")])


## The colour the row has chosen: the list's, or the bin's while it has none.
func _chosen_colour() -> int:
	if _loose_colour != null and _loose_colour.selected >= 0 and _loose_colour.selected < _colour_codes.size() \
			and _colour_codes[_loose_colour.selected] >= 0:
		return _colour_codes[_loose_colour.selected]
	var bin: Variant = app.get("_bin") if app != null else null
	return int(bin.get("_selected_color")) if bin != null else 4


func _pick_colour(code: int) -> void:
	var at: int = _colour_codes.find(code)
	if at < 0:
		_fill_colours(library.parts.get(_loose_part), code)
		at = _colour_codes.find(code)
	if at >= 0:
		_loose_colour.select(at)


## The colour list: the colours [param info] was made in first, most used
## first, then every other one in the bin's palette; [param keep] chosen.
func _fill_colours(info: PartLibrary.PartInfo, keep: int) -> void:
	var made: Array = []
	var rest: Array = []
	for code: int in library.colors:
		var colour: PartLibrary.BrickColor = library.colors[code]
		if code in PartsBin.NOT_A_COLOUR or not PartsBin._in_any_group(colour):
			continue
		if info != null and PartsBin.made_in(info, code):
			made.append(colour)
		else:
			rest.append(colour)
	var by_use := func(a: PartLibrary.BrickColor, b: PartLibrary.BrickColor) -> bool:
		return a.sets > b.sets if a.sets != b.sets else a.code < b.code
	made.sort_custom(by_use)
	rest.sort_custom(by_use)
	_loose_colour.clear()
	_colour_codes.clear()
	for colour: PartLibrary.BrickColor in made + rest:
		if _colour_codes.size() == made.size() and not made.is_empty():
			_loose_colour.add_separator()
			_colour_codes.append(-1)
		_loose_colour.add_icon_item(_swatch_icon(colour), colour.name.replace("_", " "))
		_colour_codes.append(colour.code)
	var at: int = _colour_codes.find(keep)
	if at < 0:
		at = _colour_codes.find(4)
	_loose_colour.select(maxi(at, 0))


static func _swatch_icon(colour: PartLibrary.BrickColor) -> ImageTexture:
	var image := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	image.fill(Color(colour.shown, 1.0))
	for n: int in 14:
		for edge: Vector2i in [Vector2i(n, 0), Vector2i(n, 13), Vector2i(0, n), Vector2i(13, n)]:
			image.set_pixelv(edge, Color(1, 1, 1, 0.35))
	return ImageTexture.create_from_image(image)


## The colour [param words] name at their start or end, longest first, as
## [code, the words left]; -1 and the words when none does.
func _colour_in(words: PackedStringArray) -> Array:
	if _colour_names.is_empty():
		for code: int in library.colors:
			var colour: PartLibrary.BrickColor = library.colors[code]
			if code in PartsBin.NOT_A_COLOUR or not PartsBin._in_any_group(colour):
				continue
			for name: String in [colour.name, colour.lego_name, PartWords.colour(colour.name, Language.current())]:
				var said: String = PartWords.plain(PartsBin._colour_words(name))
				if not said.is_empty() and not _colour_names.has(said):
					_colour_names[said] = code
	for size: int in range(mini(4, words.size()), 0, -1):
		for from: int in [0, words.size() - size]:
			var said: String = PartWords.plain(PartsBin._colour_words(" ".join(words.slice(from, from + size))))
			if _colour_names.has(said):
				var left := PackedStringArray()
				left.append_array(words.slice(0, from))
				left.append_array(words.slice(from + size))
				return [int(_colour_names[said]), left]
	return [-1, words]


## The chosen part's picture, name and colour, and the others found beside
## it, each a button that chooses it.
func _show_chosen() -> void:
	if _loose_found == null:
		return
	for child: Node in _loose_found.get_children():
		_loose_found.remove_child(child)
		child.queue_free()
	_loose_picture = TextureRect.new()
	_loose_picture.custom_minimum_size = Vector2(30, 30)
	_loose_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loose_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_loose_found.add_child(_loose_picture)
	if _loose_part.is_empty():
		# Its own width, or a clipped label in a flowing row has none.
		var hint: Label = _label("Find a part above, by its number or words, from a photo, or "
			+ "by choosing it in the parts bin; then how many, and Add.", 11, 0.55)
		hint.clip_text = false
		_loose_found.add_child(hint)
		return
	var listed: Array[PartLibrary.PartInfo] = _loose_listed.duplicate()
	if not listed.any(func(info: PartLibrary.PartInfo) -> bool: return info.id == _loose_part):
		listed.push_front(library.parts.get(_loose_part))
	for info: PartLibrary.PartInfo in listed:
		var pick := Button.new()
		pick.toggle_mode = true
		pick.button_pressed = info.id == _loose_part
		pick.focus_mode = Control.FOCUS_NONE
		pick.add_theme_font_size_override("font_size", 11)
		pick.text = "%s %s%s" % [info.id, Inventory._tidy(info.name).left(28),
			" · %d%%" % roundi(100.0 * float(_loose_sure[info.id])) if _loose_sure.has(info.id) else ""]
		pick.tooltip_text = "%s %s" % [info.id, Inventory._tidy(info.name)]
		var lit := StyleBoxFlat.new()
		lit.bg_color = Look.CHOSEN
		lit.set_corner_radius_all(4)
		lit.content_margin_left = 6
		lit.content_margin_right = 6
		pick.add_theme_stylebox_override("pressed", lit)
		pick.add_theme_stylebox_override("hover_pressed", lit)
		var id: String = info.id
		pick.pressed.connect(func() -> void:
			var sure: Dictionary = _loose_sure
			choose_loose(id, -1, false)
			_loose_sure = sure
			_show_chosen())
		_loose_found.add_child(pick)
	_picture_wait.start()
	_show_picture()


func _show_picture() -> void:
	var thumbs: Variant = app.get("_thumbnails") if app != null else null
	if thumbs == null or _loose_picture == null or _loose_part.is_empty():
		_picture_wait.stop()
		return
	var drawn: ImageTexture = (thumbs as PartThumbnails).request(_loose_part, _chosen_colour())
	if drawn != null:
		_loose_picture.texture = drawn
		_picture_wait.stop()


## What the row would add now: {"part", "colour", "qty"}, the part "" for
## none, for a probe to read.
func loose_chosen() -> Dictionary:
	return {"part": _loose_part, "colour": _chosen_colour(), "qty": int(_loose_count.value),
		"listed": _loose_listed.map(func(info: PartLibrary.PartInfo) -> String: return info.id)}


## A set taken out, at the count shown: nothing else in the collection is
## written (mbreview finding 1: the whole collection, from a copy read at
## sign-in, was).
func _remove_set(entry: Dictionary) -> void:
	await _begin()
	var done: Dictionary = await store.remove_set(entry)
	_end()
	_say(str(done["said"]) if done["kind"] != CollectionStore.DONE else "took %s out" % str(entry["set"]))


func _on_clear() -> void:
	await _begin()
	var done: Dictionary = await store.clear()
	_end()
	_say(str(done["said"]) + (": Start over again to forget it all" if done["kind"] == CollectionStore.CONFLICT else "")
		if done["kind"] != CollectionStore.DONE else "your collection is empty")


## Where a set came from, as its row says it: nothing for one typed here.
static func _from_words(from: String) -> String:
	match from:
		"rebrickable":
			return " · from Rebrickable"
		"rebrickable_csv":
			return " · from a Rebrickable export"
		"bricklink_xml":
			return " · from a BrickLink XML"
	return ""


# --- words --------------------------------------------------------------

func _colour(code: int) -> String:
	var found: PartLibrary.BrickColor = library.color(code)
	return found.name.replace("_", " ") if found != null else "colour %d" % code


static func _comma(value: int) -> String:
	var text: String = str(value)
	var out: String = ""
	for index: int in text.length():
		if index > 0 and (text.length() - index) % 3 == 0:
			out += ","
		out += text[index]
	return out


## What the panel shows, for a browser test to read: window.brickworksCollection.
func _tell_page() -> void:
	if not OS.has_feature("web"):
		return
	var short: int = 0
	for row: Dictionary in _need_plan:
		short += int(row["short"])
	var top: Array = []
	for candidate: Dictionary in _ranked.slice(0, 5):
		top.append({"name": candidate["name"], "kind": candidate["kind"],
			"exact": float((candidate["cover"] as Dictionary)["exact"])})
	JavaScriptBridge.eval("window.brickworksCollection = %s" % JSON.stringify({
		"open": visible, "page": _page, "status": _status.text if _status != null else "",
		"sets": store.collection.sets.size(), "lots": store.collection.parts.size(),
		"added": store.collection.added_lots().size(),
		"pieces": store.pieces_on_hand(), "offline": store.offline,
		"need": {"pieces": int(_need_cover.get("pieces", 0)), "owned": int(_need_cover.get("owned", 0)),
			"short": short, "lots": _need_plan.size()},
		"build": {"ranked": _ranked.size(), "top": top}}), true)
