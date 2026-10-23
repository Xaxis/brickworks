## My collection, on screen: what the person owns, what the open model
## needs that they do not, and what they could build.
##
## Three pages behind three buttons along the top, over the model like the
## parts list (it is consulted and dismissed, and wants the room):
##
##   What I own        bring it in — a Rebrickable account, a Rebrickable
##                     CSV export, a BrickLink XML, sets typed by number —
##                     and see it, with Start over
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
## The sums are Collection's; the keeping is CollectionStore's. Built by
## Shell, which reaches the app the way it does for its own parts, so
## main.gd only has the parts list's new button to pass on.
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
## Whose collection was last fetched: the account's id, empty for nobody.
var _loaded_for: String = ""

signal said(text: String)


## What happens to a Rebrickable key: [method _rebrickable_note].
var _rb_note: Label


## Take the app's parts and put the panel on screen, hidden.
func attach(main: Node) -> void:
	app = main
	library = main.get("_library")
	world = main.get("_world")
	models = main.get("_store")
	bar = main.get("_bar")
	store = CollectionStore.new()
	store.account = main.get("_account")
	store.library = library
	add_child(store)
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
	var account: Account = main.get("_account")
	if account != null:
		account.changed.connect(_on_account)
		_on_account()


func _ready() -> void:
	visible = false
	_build()


## Open on one page: "own", "need" or "build".
func open(page: String = "own") -> void:
	visible = true
	_rb_note.text = _rebrickable_note()
	_show(page)


## What happens to a Rebrickable key, and, with the assistant in the window
## (Settings, Assistant (AI)), what it can do with the collection.
static func _rebrickable_note() -> String:
	return ("Your Rebrickable key goes from here to rebrickable.com and nowhere else, and is "
		+ "not kept; what comes back replaces the sets and loose parts in this collection."
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


## Fetched once per person signing in, not on every change the account
## reports (a renewal, going offline); forgotten on signing out, so the next
## person on this machine starts from their own.
func _on_account() -> void:
	var account: Account = app.get("_account")
	var who: String = account.user_id if account != null and account.signed_in() else ""
	if who == _loaded_for:
		return
	_loaded_for = who
	if who.is_empty():
		store.collection = Collection.new()
		store.on_hand = {}
		store.records = {}
		store.changed.emit()
		return
	store.load_collection()


func _on_store_changed() -> void:
	# The assistant prefers what is owned, for a brief that asks it to.
	var assistant: Variant = app.get("_assistant")
	if assistant != null:
		assistant.set("owned", store.on_hand)
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
		lit.bg_color = Color(0.36, 0.6, 1.0, 0.38)
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

	_own_rows = _scrolled(page)
	return page


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
	if not mine.sets.is_empty():
		_own_rows.add_child(_label("Sets", 12, 0.6))
	for entry: Dictionary in mine.sets:
		var number: String = str(entry["set"])
		var record: Dictionary = store.records.get(number, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		row.add_child(_label("%d ×" % int(entry["qty"]), 12, 1.0, 40.0))
		row.add_child(_label(number, 12, 0.55, 90.0))
		var name: Label = _label(str(record.get("n", "no inventory known for this set"))
			+ (" (%d)" % int(record["y"]) if record.has("y") else ""), 12,
			1.0 if not record.is_empty() else 0.5)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var pieces: int = 0
		for lot: Variant in record.get("p", []):
			pieces += int((lot as Array)[2])
		row.add_child(_label("%s pieces" % _comma(pieces) if pieces > 0 else "", 12, 0.6, 90.0))
		var drop := Button.new()
		drop.text = "Remove"
		drop.add_theme_font_size_override("font_size", 11)
		drop.pressed.connect(_remove_set.bind(number))
		row.add_child(drop)
		_own_rows.add_child(row)
	if not mine.parts.is_empty():
		_own_rows.add_child(_label("Loose parts — %d lots" % mine.parts.size(), 12, 0.6))
	var shown: int = 0
	for entry: Dictionary in mine.parts:
		if shown >= MOST_ROWS:
			_own_rows.add_child(_label("…and %d more lots" % (mine.parts.size() - shown), 12, 0.5))
			break
		shown += 1
		_own_rows.add_child(_part_row(str(entry["part"]), int(entry["colour"]),
			"%d ×" % int(entry["qty"])))


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
	link.pressed.connect(func() -> void: OS.shell_open(url))
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
		line = Download.give(str(made["text"]), title + "_wanted.xml", "application/xml")
	else:
		made = ShopLists.rebrickable_csv(short)
		line = Download.give(str(made["text"]), title + "_wanted.csv", "text/csv")
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
		go.pressed.connect(func() -> void: OS.shell_open(OMR_PAGE + page))
	row.add_child(go)
	# The flows' hook is the first row that opens in the app. On the web an
	# official set's model only links out, and since m95 matched them to their
	# sets one often ranks first.
	if go.text == "Open" and not _controls.has("collection_open_first"):
		_controls["collection_open_first"] = go
	return row


func _open_candidate(candidate: Dictionary) -> void:
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
	var result: Dictionary = await store.add({"from": "sets", "text": text, "mode": "add"})
	if not str(result["error"]).is_empty():
		_say(str(result["error"]))
		return
	_typed.text = ""
	var unknown: PackedStringArray = store.collection.unknown_sets
	_say("added %s%s" % [text, "" if unknown.is_empty()
		else " — no inventory is known for %s, so it adds no parts" % ", ".join(unknown)])


func _on_file(text: String, file_name: String) -> void:
	_say("reading %s…" % file_name)
	var result: Dictionary = await store.add({"from": _picking, "text": text, "mode": "add"})
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
	var result: Dictionary = await store.add({"from": "rebrickable_api", "sets": got["sets"],
		"parts": got["parts"], "mode": "replace"})
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


func _remove_set(number: String) -> void:
	var next := Collection.from_json(store.collection.to_json())
	var kept: Array = []
	for entry: Dictionary in next.sets:
		if str(entry["set"]) != number:
			kept.append(entry)
	next.sets = kept
	var trouble: String = await store.put(next)
	_say(trouble if not trouble.is_empty() else "took %s out" % number)


func _on_clear() -> void:
	var trouble: String = await store.clear()
	_say(trouble if not trouble.is_empty() else "your collection is empty")


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
		"pieces": store.pieces_on_hand(), "offline": store.offline,
		"need": {"pieces": int(_need_cover.get("pieces", 0)), "owned": int(_need_cover.get("owned", 0)),
			"short": short, "lots": _need_plan.size()},
		"build": {"ranked": _ranked.size(), "top": top}}), true)
