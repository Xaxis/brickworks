## The parts list, on screen.
##
## Shown over the model rather than beside it, because it is something
## you consult and dismiss rather than work alongside — and because at
## four hundred pieces it wants the room.
##
## Every row carries its colour as a swatch. A list that says "Red" and
## "Dark Red" in the same typeface on the same page is a list that will
## get mis-ordered, and the colour is the half of a lot most easily got
## wrong. And its picture: on a hotel of 3,164 parts the list was 686 rows
## of numbers, and a part is known by its shape before its number.
##
## A row is also the way to the parts in the model. Clicked, it selects every
## one of them and the view frames them; the find field over the rows keeps
## the ones a number, a name or a colour answers ("3004", "1x2 brick", "blue
## 1x2 brick"), and Enter selects all of those. Studio's palette has an "In
## model" view that does this; without it, finding where the one blue 1 x 2
## brick of a hotel was had no route at all (walk180, 2026-10-23).
##
## And a row over them for the lots that are hard to buy (rareswap, APP_UX9
## #12): each lot whose part comes in its colour in three sets or fewer
## (RareSwap), marked on its own row with how many, and the swaps for them
## listed under the row, each a common part or colour, picked or not, put in
## by Find and Replace as one undo step.
##
## And a row for the lots the person owns too few of (ownswap, APP_UX10 #2):
## against their collection, as submit_design mine=true and My bricks count
## it (OwnSwap), how many lots and pieces are short and the share of the
## model that is theirs; pressed, each with the swap from their own parts that
## keeps its look or "none you own", and Use what I own puts them in as one
## undo step, after which the row says what is still missing.
class_name InventoryPanel
extends PanelContainer

## The tallest a row is: its picture's side.
const ROW := 30

var library: PartLibrary
## Draws the rows' pictures, those in sight (main's, the parts bin's own).
var thumbnails: PartThumbnails
## What the parts bin is built from holds, by part and colour
## (Collection.key_of: SetBin.have), and its name; {} for the whole library.
## Set before the list is shown: a part the model has more of than it holds
## is marked over, as the bin's tile says it (From my bricks, ownlimit).
var held: Dictionary = {}
var held_title: String = ""
## What the model uses by the same key, worked out as the list is shown.
var _used: Dictionary = {}
## The app (Main), for a rare lot's swap through Find and Replace; null, and
## no swap offered, in a shared model's viewer (rareswap).
var app: Node = null

var _rows: GridContainer
var _scroll: ScrollContainer
var _sight: ThumbTile.Sight
var _find: LineEdit
## Every lot's row, made once a showing: [Inventory.Lot, Button, its place in
## the model's order]. The find
## takes rows out of the list and puts them back rather than making them
## again.
var _made: Array = []
## Where the list was scrolled to, and the stock it was of, for opening it
## again where it was after a row was clicked.
var _was_at: int = 0
var _was_of: String = ""
## Scrolled to once the rows are laid out, or -1.
var _scroll_to: int = -1
var _heading: Label
var _stock: Inventory
var _title: String = "Model"
var _need: Button
var _csv: Button
var _bricklink: Button
## What BrickLink's wanted list asks of each part, beside its button
## ([method ask_bricklink]).
var _bricklink_wants: Button
var _wants_dialog: ConfirmationDialog
var _condition: OptionButton
var _wanted_list: LineEdit
var _notify: CheckBox
var _rebrickable: Button
## LEGO's own shop: a Pick a Brick list of element numbers.
var _pickabrick: Button
## What the last list written said: where it went, and the parts left off it
## by name. Wrapped at the panel's foot, as many lines as it needs.
var _note: Label
var _done: Button
# rareswap (APP_UX9 #12): the rare lots' row, and their swaps in its place.
var _world: BrickWorld
var _scenery: Dictionary = {}
var _swapper: RefCounted = null      ## RareSwap
var _finder: FindReplace = null
## The rare lots of the stock shown (RareSwap.Lot), rarest first.
var _rare: Array = []
## How many lots' set counts are still on their way (the web's colours files).
var _rare_waiting: int = 0
## What the last swap did, said on the row once the list is taken again.
var _swapped_words: String = ""
var _rare_row: Button
var _swaps_scroll: ScrollContainer
var _swaps: VBoxContainer
var _swap_bar: HBoxContainer
var _swap_now: Button
var _swap_back: Button
var _swap_note: Label
## Each rare lot's row in the list, by its key: the rows tagged "in 2 sets".
var _rare_rows: Dictionary = {}
## The swap list is being made or put in.
var _swapping: bool = false
## ...made: the offers worked out, which on the web wait for the counts they
## read (up to RareSwap.WAIT_MS), and Back to the list leaves them.
var _offering: bool = false
## The boxes the builder pressed, by lot key: kept when the swaps are worked
## out again as a colours file comes in (the web).
var _own_picks: Dictionary = {}
# end rareswap
# ownswap (APP_UX10 #2): the lots the person owns too few of, and their swaps
# from what they own, in the same list as the rare lots' while it shows them.
var _own_swapper: RefCounted = null  ## OwnSwap
## OwnSwap.short_of's, as the list was shown: its lots (OwnSwap.Lot), the
## biggest shortfall first, the pieces and the share owned, and what is free.
var _own_short: Dictionary = {}
var _own: Array = []
var _own_row: Button
## What the last Use what I own did, said on the row once the list is taken again.
var _own_words: String = ""
## The swaps' list shows the person's own swaps, not the rare lots'.
var _listing_own: bool = false
# end ownswap
## partplaces: the list in the model's order, or by where each part is kept
## (CollectionStore.places), shown while the person keeps any places.
var _sort: OptionButton
## Where each part and colour is kept, as the list was shown with.
var _places: Dictionary = {}

signal closed
## Select these bricks and show them: a row clicked, or Enter in the find.
## [param what] is what they are, said in the bar.
signal chosen(ids: PackedInt64Array, what: String)
## The parts against the person's collection: CollectionDialog.
signal need_wanted
## A shop's list was asked for: "bricklink", "rebrickable" or "pickabrick".
signal shop_wanted(shop: String)
## Where the CSV went, for the status bar too, with its Show in folder.
signal said(line: String)


func _header_button(header: Container, words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 11)
	button.focus_mode = Control.FOCUS_NONE
	header.add_child(button)
	return button


## What a shop's list came to, said where it was asked for: at the panel's
## foot, wrapped, so a list's parts left off are all there to read.
func tell(line: String) -> void:
	if not line.is_empty():
		_note.text = line
		_note.visible = true


## Its controls, for the page to find.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named: Dictionary = {"parts_need": _need, "parts_csv": _csv,
		"parts_bricklink": _bricklink, "parts_rebrickable": _rebrickable, "parts_done": _done,
		"parts_find": _find}
	named["parts_bricklink_wants"] = _bricklink_wants
	named["parts_pickabrick"] = _pickabrick
	if _sort.visible:
		named["parts_sort"] = _sort
	if _note.visible:
		named["parts_note"] = _note
	if _wants_dialog != null and _wants_dialog.visible:
		named["bricklink_condition"] = _condition
		named["bricklink_list"] = _wanted_list
		named["bricklink_notify"] = _notify
		named["bricklink_save"] = _wants_dialog.get_ok_button()
	if _rare_row.visible:
		named["parts_rare"] = _rare_row
	if _own_row.visible:
		named["parts_own"] = _own_row
	if _swaps_scroll.visible:
		named["parts_use_own" if _listing_own else "parts_swap"] = _swap_now
		named["parts_swap_back"] = _swap_back
		var boxes: Array = _swap_boxes()
		if not boxes.is_empty():
			named["parts_swap_row"] = boxes[0]
	# The first row shown, which a click selects in the model.
	if _rows.get_child_count() > 0:
		named["parts_row"] = _rows.get_child(0)
	return named


func _ready() -> void:
	visible = false
	_build()
	visibility_changed.connect(func() -> void:
		if not visible and thumbnails != null:
			thumbnails.watch(self, []))


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
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 15)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)

	_need = _header_button(header, "What do I need?",
		"These parts against your collection: what is short, and what could stand in")
	_need.pressed.connect(func() -> void:
		hide_list()
		need_wanted.emit())
	_csv = _header_button(header, "Save as CSV", "A spreadsheet, or a shop's bulk-add box")
	_csv.pressed.connect(_on_csv)
	# The two shops' own lists, here as well as under File › Export: the
	# list is where somebody decides to buy the parts, and a shared model's
	# viewer has no File menu at all.
	_bricklink = _header_button(header, "BrickLink",
		"A BrickLink wanted list (.xml), to upload under Wanted › Upload")
	_bricklink.pressed.connect(func() -> void: shop_wanted.emit("bricklink"))
	# Its condition, wanted list and email, as BrickLink's upload reads them,
	# beside it: the button itself writes the list as they were last chosen.
	_bricklink_wants = _header_button(header, "",
		"BrickLink wanted list: new or used, which of your wanted lists, and an email when one is listed")
	# A drop-down's own arrow: the font has no small one.
	_bricklink_wants.icon = get_theme_icon("arrow", "OptionButton")
	_bricklink_wants.pressed.connect(ask_bricklink)
	_rebrickable = _header_button(header, "Rebrickable",
		"A Rebrickable parts list (.csv), to import into a list of your own")
	_rebrickable.pressed.connect(func() -> void: shop_wanted.emit("rebrickable"))
	_pickabrick = _header_button(header, "LEGO® Pick a Brick",
		"A list of LEGO® element numbers (.csv), to upload at LEGO® Pick a Brick: the parts it has no number for are named")
	_pickabrick.pressed.connect(func() -> void: shop_wanted.emit("pickabrick"))

	_done = _header_button(header, "Done", "")
	_done.pressed.connect(hide_list)

	_find = LineEdit.new()
	_find.placeholder_text = "Find in the model: a part's number, its name, a colour…"
	_find.tooltip_text = ("Only the parts that answer it: 3004, brick 1x2, blue 1x2 brick.\n"
		+ "Enter selects all of them in the model; a row selects its own")
	_find.clear_button_enabled = true
	_find.add_theme_font_size_override("font_size", 12)
	_find.text_changed.connect(func(_text: String) -> void: _filter())
	_find.text_submitted.connect(func(_text: String) -> void: _choose_shown())
	_find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var finding := HBoxContainer.new()
	finding.add_theme_constant_override("separation", 8)
	column.add_child(finding)
	finding.add_child(_find)
	# partplaces: by where each part is kept, a walk round the drawers.
	_sort = OptionButton.new()
	_sort.add_theme_font_size_override("font_size", 12)
	_sort.focus_mode = Control.FOCUS_NONE
	_sort.add_item("As in the model")
	_sort.add_item("By where it's kept")
	_sort.tooltip_text = "By where it's kept: the parts in the order of their places, as a walk round them takes, " \
		+ "those kept nowhere last (My collection, Where it's kept…)"
	_sort.visible = false
	_sort.item_selected.connect(func(at: int) -> void:
		ShellPrefs.put("parts_by_place", at == 1)
		_order()
		_filter())
	finding.add_child(_sort)
	_build_rare(column)
	_build_own(column)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	# One column of a grid rather than a box: a grid's rows are what
	# ThumbTile.Sight reads the rows in sight from, to draw their pictures
	# and no others.
	_rows = GridContainer.new()
	_rows.columns = 1
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("v_separation", 2)
	_scroll.add_child(_rows)
	_sight = ThumbTile.Sight.new(_scroll, _rows)
	_build_swaps(column)

	# At the foot, under the rows: a list written never moves the row under
	# the pointer.
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 12)
	_note.modulate = Color(1, 1, 1, 0.8)
	_note.visible = false
	column.add_child(_note)


func is_showing() -> bool:
	return visible


## Take stock and show it.
func show_for(world: BrickWorld, from_library: PartLibrary,
		scenery: Dictionary, title: String) -> bool:
	library = from_library
	_title = title
	_world = world
	_scenery = scenery
	_stock = Inventory.of(world, from_library, scenery)
	if _stock.pieces == 0:
		return false
	_take_rare()
	_take_own()
	_show_rows()

	_heading.text = _counts()
	_note.visible = false

	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_made.clear()
	_used = {}
	if not held.is_empty():
		for lot: Inventory.Lot in _stock.lots:
			var key: String = Collection.key_of(lot.part_id, lot.color_code, library)
			_used[key] = int(_used.get(key, 0)) + lot.count
	_rare_rows.clear()
	_places = CollectionStore.places
	for lot: Inventory.Lot in _stock.lots:
		var row: Button = _row(lot)
		_made.append([lot, row, _made.size()])
	_sort.visible = not _places.is_empty()
	_sort.select(1 if _sort.visible and bool(ShellPrefs.value("parts_by_place")) else 0)
	_order()
	for pair: Array in _made:
		_rows.add_child(pair[1])
	_tag_rare()
	_tag_own()
	_sight.forget()

	HudFront.show_panel(self)
	# Where it was, when it is the same model's list again: the way to find
	# one part, look at it, and come back for the next.
	var of: String = "%s %d %d" % [title, _stock.pieces, _stock.lot_count()]
	var at: int = _was_at if of == _was_of else 0
	_was_of = of
	_find.text = ""
	_scroll.scroll_vertical = 0
	_scroll_to = at
	return true


## Show it with the find ready to type into (Edit, Select by, Part number
## or name).
func show_finding(world: BrickWorld, from_library: PartLibrary,
		scenery: Dictionary, title: String) -> bool:
	if not show_for(world, from_library, scenery, title):
		return false
	_scroll_to = -1
	_find.grab_focus()
	return true


func hide_list() -> void:
	_was_at = _scroll.scroll_vertical
	_swapped_words = ""
	_own_words = ""
	if _find.has_focus():
		_find.release_focus()
	visible = false
	closed.emit()


func _counts() -> String:
	return "%s · %s · %s" % [Counted.of(_stock.pieces, "piece"), Counted.of(_stock.lot_count(), "lot"),
		_stock.weight()]


## The rows in the order chosen: the model's (Inventory's), or by where
## each is kept (Collection.place_less), those kept nowhere last in the
## model's order.
func _order() -> void:
	_made.sort_custom(func(a: Array, b: Array) -> bool:
		if _sort.selected == 1:
			var x: String = place_of(a[0])
			var y: String = place_of(b[0])
			if x != y:
				return Collection.place_less(x, y)
		return int(a[2]) < int(b[2]))


## Where [param lot]'s part and colour is kept, as the list was shown with,
## or "".
func place_of(lot: Inventory.Lot) -> String:
	return Collection.place_in(_places, lot.part_id, lot.color_code, library) if not lot.custom else ""


## The rows' lots in the order shown, for a probe: [{"part", "colour",
## "place"}].
func rows_listed() -> Array:
	var out: Array = []
	for child: Node in _rows.get_children():
		for pair: Array in _made:
			if pair[1] == child:
				var lot: Inventory.Lot = pair[0]
				out.append({"part": lot.part_id, "colour": lot.color_code, "place": place_of(lot)})
				break
	return out


## Only the rows the find answers, in the list's own order.
func _filter() -> void:
	if _stock == null:
		return
	var said: String = _find.text.strip_edges()
	var colours: Dictionary = {}
	for pair: Array in _made:
		colours[(pair[0] as Inventory.Lot).color_code] = true
	var wanted: SelectBy.Wanted = SelectBy.wanted(library, said, colours)
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
	var lots: int = 0
	var pieces: int = 0
	var lower: String = said.to_lower()
	for pair: Array in _made:
		var lot: Inventory.Lot = pair[0]
		# A place's words find what is kept there too ("drawer 3").
		if wanted.takes(lot.part_id, lot.color_code) or (not said.is_empty() and not _places.is_empty()
				and place_of(lot).to_lower().contains(lower)):
			_rows.add_child(pair[1])
			lots += 1
			pieces += lot.count
	_sight.forget()
	_scroll.scroll_vertical = 0
	if said.is_empty():
		_heading.text = _counts()
	elif lots == 0:
		_heading.text = "Nothing in this model answers “%s”" % said
	else:
		_heading.text = "%d piece%s in %d lot%s answer “%s”: Enter selects them" % [
			pieces, "" if pieces == 1 else "s", lots, "" if lots == 1 else "s", said]


## Enter in the find: every row it kept.
func _choose_shown() -> void:
	var said: String = _find.text.strip_edges()
	if said.is_empty() or _rows.get_child_count() == 0:
		return
	var ids := PackedInt64Array()
	for pair: Array in _made:
		if (pair[1] as Node).get_parent() == _rows:
			ids.append_array((pair[0] as Inventory.Lot).bricks)
	_choose(ids, "the parts that answer “%s”" % said)


func _choose(ids: PackedInt64Array, what: String) -> void:
	hide_list()
	chosen.emit(ids, what)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _scroll_to >= 0 and _rows.size.y > 0.0:
		_scroll.scroll_vertical = _scroll_to
		_scroll_to = -1
	if thumbnails == null or not _sight.changed():
		return
	thumbnails.watch(self, _sight.tiles())


## A row, which is a button: clicked, it selects its parts in the model.
func _row(lot: Inventory.Lot) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ROW)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Select %s in the model" % (
		"it" if lot.count == 1 else "these %d" % lot.count)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state: String in ["hover", "pressed"]:
		var lit := StyleBoxFlat.new()
		lit.bg_color = Color(1, 1, 1, 0.07 if state == "hover" else 0.12)
		lit.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state, lit)
	var what: String = "%s in %s" % [lot.name, lot.color_name]
	var ids: PackedInt64Array = lot.bricks
	button.pressed.connect(func() -> void: _choose(ids, what))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var count := Label.new()
	count.text = "%d ×" % lot.count
	count.custom_minimum_size = Vector2(44, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 12)
	row.add_child(count)

	# Its picture, in its colour: the parts bin's, drawn when it comes
	# into sight.
	var tile := ThumbTile.new(lot.part_id, lot.color_code)
	tile.custom_minimum_size = Vector2(ROW, ROW)
	button.set_meta("tile", tile)
	if thumbnails != null:
		var ready_now: ImageTexture = thumbnails.peek(lot.part_id, lot.color_code)
		if ready_now != null:
			tile.show_picture(ready_now, false)
	row.add_child(tile)

	# The colour, as a colour. A transparent part gets a lighter border so
	# trans-clear and white are not the same square.
	var swatch := Panel.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(15, 15)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	var color: PartLibrary.BrickColor = library.color(lot.color_code)
	style.bg_color = color.shown if color != null else Color.MAGENTA
	style.set_corner_radius_all(3)
	if color != null and color.is_transparent():
		style.set_border_width_all(2)
		style.border_color = Color(color.rgb, 1.0).darkened(0.4)
	swatch.add_theme_stylebox_override("panel", style)
	row.add_child(swatch)

	var id := Label.new()
	id.text = lot.part_id
	id.custom_minimum_size = Vector2(74, 0)
	id.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	id.add_theme_font_size_override("font_size", 12)
	id.modulate = Color(1, 1, 1, 0.55)
	row.add_child(id)

	var name := Label.new()
	name.text = lot.name
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 12)
	row.add_child(name)

	var shade := Label.new()
	shade.text = lot.color_name
	shade.custom_minimum_size = Vector2(150, 0)
	shade.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shade.add_theme_font_size_override("font_size", 12)
	shade.modulate = Color(1, 1, 1, 0.6)
	shade.clip_text = true
	row.add_child(shade)

	# Where it is kept (partplaces), as the person named it: a column of
	# its own while they keep any places, empty for a part kept nowhere, so
	# the colours stay in one column.
	var place: String = place_of(lot)
	if not _places.is_empty():
		var kept := Label.new()
		kept.text = place
		kept.custom_minimum_size = Vector2(110, 0)
		kept.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		kept.add_theme_font_size_override("font_size", 12)
		kept.add_theme_color_override("font_color", Look.ACCENT)
		kept.clip_text = true
		row.add_child(kept)
		if not place.is_empty():
			kept.tooltip_text = "Kept in “%s”" % place
			button.tooltip_text += "\nKept in “%s”" % place

	# More of it than the bin's sets or the person's own bricks hold.
	var past: int = over_of(lot)
	if past > 0:
		var over := Label.new()
		over.text = "%d over" % past
		over.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		over.add_theme_font_size_override("font_size", 12)
		over.add_theme_color_override("font_color", Color(1.0, 0.62, 0.3))
		row.add_child(over)
		button.tooltip_text += "\n%d over the %d in %s" % [past,
			int(held.get(Collection.key_of(lot.part_id, lot.color_code, library), 0)), held_title]
	return button


## How many of [param lot]'s part and colour the model has past what the bin
## holds ([member held]), all its lots of that key together; 0 when within it,
## with no bin, or for a part nobody owns on its own (Collection.ownable).
func over_of(lot: Inventory.Lot) -> int:
	if held.is_empty() or lot.custom or not Collection.ownable(lot.part_id, library):
		return 0
	var key: String = Collection.key_of(lot.part_id, lot.color_code, library)
	return maxi(0, int(_used.get(key, 0)) - int(held.get(key, 0)))


## The BrickLink wanted list's choices, as its upload help names them: the
## condition (CONDITION), which wanted list (WANTEDLISTID) and an email when
## a lot is listed (NOTIFY); kept on this device (ShopLists.Wants), and the
## list written with them.
func ask_bricklink() -> void:
	if _wants_dialog == null:
		_wants_dialog = ConfirmationDialog.new()
		_wants_dialog.title = "BrickLink wanted list"
		_wants_dialog.ok_button_text = "Save the list"
		# Each word beside its field; on a phone above it, the screen being no
		# wider than a field and its word (a sheet as wide as the screen).
		var phone: bool = Phone.on()
		var fields := GridContainer.new()
		fields.columns = 1 if phone else 2
		fields.add_theme_constant_override("h_separation", 12)
		fields.add_theme_constant_override("v_separation", 8)
		var condition := Label.new()
		condition.text = "Condition"
		fields.add_child(condition)
		_condition = OptionButton.new()
		for words: String in ["New or used", "New only", "Used only"]:
			_condition.add_item(words)
		_condition.tooltip_text = "The condition BrickLink looks for in each part"
		fields.add_child(_condition)
		var into := Label.new()
		into.text = "Wanted list"
		fields.add_child(into)
		_wanted_list = LineEdit.new()
		_wanted_list.placeholder_text = "Main wanted list"
		_wanted_list.tooltip_text = ("Another of your wanted lists: its ID, the number after "
			+ "wantedMoreID= in its address on BrickLink. Empty for your main wanted list")
		_wanted_list.custom_minimum_size = Vector2(0 if phone else 240, 0)
		_wanted_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wanted_list.max_length = 12
		# Digits only: any other key is not an ID.
		_wanted_list.text_changed.connect(func(text: String) -> void:
			var digits: String = ""
			for character: String in text:
				if character >= "0" and character <= "9":
					digits += character
			if digits != text:
				var at: int = _wanted_list.caret_column
				_wanted_list.text = digits
				_wanted_list.caret_column = mini(at, digits.length()))
		_wanted_list.text_submitted.connect(func(_text: String) -> void:
			_wants_dialog.get_ok_button().pressed.emit())
		fields.add_child(_wanted_list)
		# Where its ID is, in sight: a tooltip is not read before a list goes
		# to the wrong one.
		if not phone:
			fields.add_child(Control.new())
		var where := Label.new()
		where.text = ("Empty for your main list. Another: the number after wantedMoreID= "
			+ "in its address on BrickLink")
		where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		where.custom_minimum_size = Vector2(0 if phone else 240, 0)
		where.add_theme_font_size_override("font_size", 11)
		where.modulate = Color(1, 1, 1, 0.65)
		fields.add_child(where)
		if not phone:
			fields.add_child(Control.new())
		_notify = CheckBox.new()
		_notify.text = "Email me when one is listed for sale"
		_notify.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fields.add_child(_notify)
		_wants_dialog.add_child(fields)
		_wants_dialog.confirmed.connect(func() -> void:
			var wants := ShopLists.Wants.new()
			wants.condition = ["", "N", "U"][_condition.selected]
			wants.wanted_list = _wanted_list.text.strip_edges().lstrip("0")
			wants.notify = _notify.button_pressed
			wants.keep()
			shop_wanted.emit("bricklink"))
		add_child(_wants_dialog)
	var kept: ShopLists.Wants = ShopLists.Wants.kept()
	_condition.select(["", "N", "U"].find(kept.condition))
	_wanted_list.text = kept.wanted_list
	_notify.button_pressed = kept.notify
	_wants_dialog.popup_centered()
	_condition.grab_focus()


func _on_csv() -> void:
	if _stock == null:
		return
	var file_name: String = SubmodelFile.titled(_title, "_parts.csv")
	var line: String = await Download.save(_stock.to_csv(), file_name, "text/csv")
	tell(line)
	if not line.is_empty():
		said.emit(line)


# -- rareswap (APP_UX9 #12): the lots hard to buy, and their swaps --------------------


## The row over the list that says how many lots are rare, and opens their
## swaps; hidden while none is.
func _build_rare(column: Container) -> void:
	_rare_row = Button.new()
	_rare_row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rare_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rare_row.focus_mode = Control.FOCUS_NONE
	_rare_row.add_theme_font_size_override("font_size", 12)
	_rare_row.add_theme_color_override("font_color", RARE_COLOUR)
	_rare_row.visible = false
	_rare_row.pressed.connect(show_swaps)
	column.add_child(_rare_row)


## The swaps' list, in the rows' place while it is open, and its buttons.
func _build_swaps(column: Container) -> void:
	_swaps_scroll = ScrollContainer.new()
	_swaps_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_swaps_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_swaps_scroll.visible = false
	column.add_child(_swaps_scroll)
	_swaps = VBoxContainer.new()
	_swaps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_swaps.add_theme_constant_override("separation", 6)
	_swaps_scroll.add_child(_swaps)
	_swap_bar = HBoxContainer.new()
	_swap_bar.add_theme_constant_override("separation", 10)
	_swap_bar.visible = false
	column.add_child(_swap_bar)
	_swap_note = Label.new()
	_swap_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_swap_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_swap_note.add_theme_font_size_override("font_size", 11)
	_swap_note.modulate = Color(1, 1, 1, 0.7)
	_swap_bar.add_child(_swap_note)
	_swap_back = _header_button(_swap_bar, "Back to the list", "The parts list, nothing swapped")
	_swap_back.pressed.connect(_show_rows)
	_swap_now = _header_button(_swap_bar, "Swap", "")
	_swap_now.pressed.connect(func() -> void: await swap_picked())


## The colour a rare lot is said in: the "over" mark's amber.
const RARE_COLOUR := Color(1.0, 0.62, 0.3)
## How far, in points, a press on a swap's row may move and still be a tap.
const ROW_TAP_SLOP := 10.0


## The rare lots of the stock shown, counted again (RareSwap.rare_of), and
## the row that says so.
func _take_rare() -> void:
	if _swapper == null:
		_swapper = RareSwap.new(library)
		library.colour_sets_came.connect(_colour_sets_came)
	(_swapper as RareSwap).library = library
	var rare: Dictionary = (_swapper as RareSwap).rare_of(_stock)
	_rare = rare["lots"]
	_rare_waiting = int(rare["waiting"])
	_say_rare()


## A part's colours file came in on the web: the counts it held, said, and
## the swaps shown worked out again where one of theirs was still to come
## (rsreview F3: a mould's file late, and 3070a was offered nothing).
func _colour_sets_came() -> void:
	if not visible or _stock == null or _swapping:
		return
	# The person's own swaps shown: the rare counts taken again, kept for the
	# rows, and the list left as it is (ownswap).
	if _listing_own and _swaps_scroll.visible:
		if _rare_waiting > 0:
			_take_rare()
			_tag_rare()
			_rare_row.visible = false
		return
	var again: bool = _swaps_scroll.visible and _rare.any(func(lot: RefCounted) -> bool:
		return bool(lot.get("waited")))
	if _rare_waiting > 0:
		_take_rare()
		_tag_rare()
		# The lots taken again are new: the swaps shown were the old ones'.
		again = again or _swaps_scroll.visible
	if again:
		await show_swaps(true)


## The row's words: how many lots are rare and what a press does, what the
## last swap did, or nothing to say.
func _say_rare() -> void:
	var count: int = _rare.size()
	var words: String = ""
	if count > 0:
		words = ("%s in %d sets or fewer, so few sellers have %s" % [
			"1 lot comes" if count == 1 else "%d lots come" % count, RareSwap.RARE_IN,
			"it" if count == 1 else "them"])
		if can_swap():
			words += ": swap for common parts…"
	if not _swapped_words.is_empty():
		words = _swapped_words + (". Still rare: " + words if count > 0 else ". No lot is rare now")
	elif count == 0 and _rare_waiting > 0:
		words = "Counting the sets each part comes in…"
	_rare_row.text = words
	_rare_row.visible = not words.is_empty()
	_rare_row.disabled = count == 0 or not can_swap()
	_rare_row.tooltip_text = ("Each comes in its colour in %d sets or fewer, by Rebrickable's "
		+ "set inventories: each swap is a part or a colour in %d sets or more, picked or not, "
		+ "put in as one undo step") % [RareSwap.RARE_IN, RareSwap.COMMON_IN] if can_swap() \
		else "Each comes in its colour in %d sets or fewer, by Rebrickable's set inventories" \
			% RareSwap.RARE_IN


## Whether the model shown can be changed here: not in a shared model's
## viewer, which has no edits.
func can_swap() -> bool:
	return app != null and app.get("_share_view") == null


## Each rare lot's own row marked "in 2 sets", as a lot over the bin is
## marked over.
func _tag_rare() -> void:
	var sets: Dictionary = {}
	for lot: RefCounted in _rare:
		sets[lot.get("key")] = int(lot.get("sets"))
	_rare_rows.clear()
	for pair: Array in _made:
		var lot: Inventory.Lot = pair[0]
		var button: Button = pair[1]
		var line: HBoxContainer = button.get_child(0)
		var had: Label = button.get_meta("rare_tag") if button.has_meta("rare_tag") else null
		var key: String = "%s/%d" % [lot.part_id, lot.color_code]
		if not sets.has(key):
			if had != null:
				had.queue_free()
				button.remove_meta("rare_tag")
			continue
		_rare_rows[key] = button
		if had == null:
			had = Label.new()
			had.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			had.add_theme_font_size_override("font_size", 12)
			had.add_theme_color_override("font_color", RARE_COLOUR)
			line.add_child(had)
			button.set_meta("rare_tag", had)
		had.text = "rare: " + RareSwap.sets_words(int(sets[key]))


## The rows of the model's parts, the swaps closed.
func _show_rows() -> void:
	if _swapping and not _offering:
		return
	_listing_own = false
	_swaps_scroll.visible = false
	_swap_bar.visible = false
	_scroll.visible = true
	(_find.get_parent() as Control).visible = true
	if _stock != null:
		_heading.text = _counts()
	_say_rare()
	_say_own()


## The rare lots' swaps, in the rows' place: each with what it is, what it
## becomes and in how many sets each comes, picked or not by its box.
## Shown at once and filled once every swap is known (an equal part's shape
## may have to be fetched on the web). Only those that keep the look start
## picked ([method RareSwap.keeps_look]). [param again]: worked out again as
## a colours file came in, the builder's own presses kept.
func show_swaps(again: bool = false) -> void:
	if again and _rare.is_empty() and not _swapping:
		_show_rows()
		return
	if _rare.is_empty() or not can_swap() or _swapping:
		return
	if _finder == null:
		_finder = FindReplace.new(app)
	if not again:
		_own_picks.clear()
	_listing_own = false
	_swapping = true
	_own_row.visible = false
	_scroll.visible = false
	# The find and its sort by place: the swaps are no rows to find or sort.
	(_find.get_parent() as Control).visible = false
	_rare_row.visible = false
	_swaps_scroll.visible = true
	_swap_bar.visible = true
	_heading.text = "Rare lots, and a common swap for each"
	for child: Node in _swaps.get_children():
		_swaps.remove_child(child)
		child.queue_free()
	_swap_note.text = "Finding a common part or colour for each…"
	_swap_now.disabled = true
	_offering = true
	await (_swapper as RareSwap).offer_all(_rare, _finder)
	# The rows put in a few a frame, as the offers are worked out: each
	# row's words are shaped in the frame after it goes in (rsfix F6).
	var slice: int = Time.get_ticks_usec()
	for lot: RefCounted in _rare:
		if not _swaps_scroll.visible:
			break
		if _own_picks.has(lot.get("key")) and bool(lot.call("offered")):
			lot.set("picked", bool(_own_picks[lot.get("key")]))
		_swaps.add_child(_swap_row(lot))
		if Time.get_ticks_usec() - slice > RareSwap.SLICE_US:
			await get_tree().process_frame
			slice = Time.get_ticks_usec()
	_offering = false
	_swapping = false
	if not _swaps_scroll.visible:
		for child: Node in _swaps.get_children():
			_swaps.remove_child(child)
			child.queue_free()
		return
	_swap_note.text = ("A swap is a part or a colour in %d sets or more: the same shape in "
		+ "the lot's colour where there is one, else the nearest colour of its finish. Only a "
		+ "swap that keeps the look starts picked: the same shape, or a close colour of the "
		+ "same finish. Pick any other yourself") % RareSwap.COMMON_IN
	_say_picked()


## One lot's swap: its box (picked or not), the colour it is and the colour
## it becomes, and the words of both.
func _swap_row(lot: RefCounted) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var box := CheckBox.new()
	box.focus_mode = Control.FOCUS_NONE
	box.button_pressed = bool(lot.get("picked"))
	box.disabled = not bool(lot.call("offered"))
	if _listing_own:
		box.tooltip_text = "Swap this lot" if not box.disabled else "None of your parts stands in for it"
	else:
		box.tooltip_text = "Swap this lot" if not box.disabled else "No part or colour of it comes in %d sets" \
			% RareSwap.COMMON_IN
	box.toggled.connect(func(on: bool) -> void:
		lot.set("picked", on)
		_own_picks[lot.get("key")] = on
		_say_picked())
	box.set_meta("lot", lot)
	# Named by its lot's words, said through the translation as the row's
	# label draws them: its tooltip alone is the same on every row, and
	# read in English. What it becomes is its description, read after it
	# (rsreview F11: a reader heard what a box swapped, never into what).
	box.accessibility_name = str(_lister().call("from_words", lot))
	box.accessibility_description = str(_lister().call("into_words", lot))
	row.add_child(box)
	# A touch anywhere on the row is a touch on its box, as a list row's is
	# on a phone (rsreview F10: a finger lands on the words). A drag that
	# scrolls the list is no touch: it lets go away from where it went down.
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.gui_input.connect(func(event: InputEvent) -> void:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button == null or button.button_index != MOUSE_BUTTON_LEFT or box.disabled:
			return
		if button.pressed:
			# A press on the box is the box's: on a touch screen it passes
			# its presses on to the row too (TouchSizing, so a drag from it
			# scrolls the list), and the row toggled it back.
			if box.get_rect().has_point(button.position):
				row.remove_meta("down_at")
				return
			row.set_meta("down_at", button.position)
		elif row.has_meta("down_at"):
			var went: float = button.position.distance_to(row.get_meta("down_at"))
			row.remove_meta("down_at")
			if went <= ROW_TAP_SLOP * Phone.per_point(get_tree().root):
				box.button_pressed = not box.button_pressed
				row.accept_event())
	row.add_child(_swatch(int(lot.get("colour"))))
	var into: int = int(lot.get("into_colour"))
	if bool(lot.call("offered")):
		var arrow := Control.new()
		arrow.custom_minimum_size = Vector2(12, 15)
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.draw.connect(_draw_arrow.bind(arrow))
		row.add_child(arrow)
		row.add_child(_swatch(into if into >= 0 else int(lot.get("colour"))))
	# What it is, and below it what it becomes: each one entry of the words.
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	for said: String in [str(_lister().call("from_words", lot)), str(_lister().call("into_words", lot))]:
		var line := Label.new()
		line.text = said
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 12)
		if not bool(lot.call("offered")):
			line.modulate = Color(1, 1, 1, 0.6)
		words.add_child(line)
	row.add_child(words)
	return row


## A swap row's arrow, drawn: a label of "→" cost 8-23 ms a row at load,
## where a label of the row's words cost under 1 ms (the interface's font has
## no such glyph, so the system's fonts were searched for one each time), and
## it was most of the rare row's first press (rsfix F6).
func _draw_arrow(arrow: Control) -> void:
	var colour: Color = arrow.get_theme_color("font_color", "Label")
	var mid: float = arrow.size.y / 2.0
	var tip := Vector2(arrow.size.x - 1.0, mid)
	arrow.draw_line(Vector2(1.0, mid), tip, colour, 1.5, true)
	arrow.draw_polyline(PackedVector2Array([tip + Vector2(-4.0, -4.0), tip, tip + Vector2(-4.0, 4.0)]),
		colour, 1.5, true)


## A colour's square, as a row shows its lot's.
func _swatch(code: int) -> Panel:
	var swatch := Panel.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(15, 15)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	var color: PartLibrary.BrickColor = library.color(code)
	style.bg_color = color.shown if color != null else Color.MAGENTA
	style.set_corner_radius_all(3)
	if color != null and color.is_transparent():
		style.set_border_width_all(2)
		style.border_color = Color(color.rgb, 1.0).darkened(0.4)
	swatch.add_theme_stylebox_override("panel", style)
	return swatch


## The swap boxes shown, in the list's order.
func _swap_boxes() -> Array:
	var out: Array = []
	for row: Node in _swaps.get_children():
		if row.is_queued_for_deletion() or row.get_child_count() == 0:
			continue
		out.append(row.get_child(0))
	return out


## The swap button's words: how many lots it swaps.
func _say_picked() -> void:
	var picked: int = 0
	for lot: RefCounted in _listed():
		if bool(lot.get("picked")) and bool(lot.call("offered")):
			picked += 1
	if _listing_own:
		_swap_now.text = "Use what I own: 1 lot" if picked == 1 else "Use what I own: %d lots" % picked
	else:
		_swap_now.text = "Swap 1 lot" if picked == 1 else "Swap %d lots" % picked
	_swap_now.disabled = picked == 0
	_swap_now.tooltip_text = "Put the picked swaps in, as one undo step"


## The picked swaps put in as one undo step (RareSwap.swap), said in the
## status bar, and the list taken again: its row says what changed and how
## many lots are still rare. {} when nothing was picked.
func swap_picked() -> Dictionary:
	if _listing_own:
		return await use_own()
	if _swapping or _rare.is_empty() or not can_swap():
		return {}
	_swapping = true
	_swap_now.disabled = true
	var done: Dictionary = await (_swapper as RareSwap).swap(_rare, _finder)
	_swapping = false
	var stayed: PackedStringArray = done["stayed"]
	var words: String = str(done["words"])
	if int(done["changed"]) == 0:
		said.emit("nothing swapped" + (": " + "; ".join(stayed) if not stayed.is_empty() else ""))
		_show_rows()
		return done
	said.emit(Keymap.filled("%s — {undo|takes it back}") % (words
		+ ("" if stayed.is_empty() else "; stayed: " + "; ".join(stayed))))
	var picked_at: int = _was_at
	show_for(_world, library, _scenery, _title)
	_was_at = picked_at
	_swapped_words = "Swapped " + words.trim_prefix("swapped ")
	_say_rare()
	return done
# end rareswap


# -- ownswap (APP_UX10 #2): a model rebuilt from what the person owns -----------------


## The row over the list that says how many lots the person owns too few of,
## and opens their swaps; hidden with no collection, or none short.
func _build_own(column: Container) -> void:
	_own_row = Button.new()
	_own_row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_own_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_own_row.focus_mode = Control.FOCUS_NONE
	_own_row.add_theme_font_size_override("font_size", 12)
	_own_row.add_theme_color_override("font_color", Look.ACCENT)
	_own_row.visible = false
	_own_row.pressed.connect(show_own)
	column.add_child(_own_row)


## The swaps' lots and their words: the person's own while those are listed.
func _listed() -> Array:
	return _own if _listing_own else _rare


func _lister() -> RefCounted:
	return _own_swapper if _listing_own else _swapper


## What the person owns, by part and colour (CollectionStore.on_hand): {} when
## nobody is signed in, the collection is empty, or this is a shared model's
## viewer.
func _pool() -> Dictionary:
	if not can_swap():
		return {}
	var shell: Node = app.get("_shell")
	var store: CollectionStore = shell.get("collection_store") if shell != null else null
	return store.on_hand if store != null else {}


## The lots of the model the person owns too few of, counted again
## (OwnSwap.short_of), and the row that says so.
func _take_own() -> void:
	var pool: Dictionary = _pool()
	if pool.is_empty():
		_own_short = {}
		_own = []
		_say_own()
		return
	if _own_swapper == null:
		_own_swapper = OwnSwap.new(library)
	(_own_swapper as OwnSwap).library = library
	_own_short = (_own_swapper as OwnSwap).short_of(_world, _scenery, pool, _stock)
	_own = _own_short["lots"]
	_say_own()


## The row's words: how many lots are short and the share that is theirs,
## what the last Use what I own did and what is still missing, or nothing.
func _say_own() -> void:
	var words: String = ""
	if not _own_short.is_empty():
		var missing: String = OwnSwap.missing_words(_own_short)
		if not _own_words.is_empty():
			words = _own_words + (". Still missing: %s, which What do I need? lists" % missing
				if not missing.is_empty() else ". Every piece is yours now")
		elif not _own.is_empty():
			words = "%s you own too few of (%s short; %s): rebuild from what you own…" % [
				Counted.of(_own.size(), "lot"), Counted.of(_short_pieces(), "piece"),
				OwnSwap.share_words(_own_short)]
	_own_row.text = words
	_own_row.visible = not words.is_empty()
	_own_row.disabled = _own.is_empty()
	_own_row.tooltip_text = ("Against your collection, as My bricks counts it: each lot you own too few "
		+ "of, with a part or colour of yours that keeps its look, put in as one undo step")


func _short_pieces() -> int:
	var pieces: int = 0
	for lot: RefCounted in _own:
		pieces += int(lot.call("short"))
	return pieces


## Each lot short marked on its own row with how many are not the person's,
## as a lot over the bin is marked over (and not twice where it is).
func _tag_own() -> void:
	var short: Dictionary = {}
	for lot: RefCounted in _own:
		short[lot.get("key")] = int(lot.call("short"))
	for pair: Array in _made:
		var lot: Inventory.Lot = pair[0]
		var button: Button = pair[1]
		var line: HBoxContainer = button.get_child(0)
		var had: Label = button.get_meta("own_tag") if button.has_meta("own_tag") else null
		var key: String = "%s/%d" % [lot.part_id, lot.color_code]
		if not short.has(key) or over_of(lot) > 0:
			if had != null:
				had.queue_free()
				button.remove_meta("own_tag")
			continue
		if had == null:
			had = Label.new()
			had.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			had.add_theme_font_size_override("font_size", 12)
			had.add_theme_color_override("font_color", Look.ACCENT)
			line.add_child(had)
			button.set_meta("own_tag", had)
		had.text = "%d not yours" % int(short[key])


## The lots the person owns too few of, each with its swap from what they own
## or "none you own", in the rows' place, as the rare lots' are shown: worked
## out a slice of a frame at a time (OwnSwap.SLICE_US), the note saying so.
func show_own() -> void:
	if _own.is_empty() or not can_swap() or _swapping:
		return
	if _finder == null:
		_finder = FindReplace.new(app)
	_listing_own = true
	_swapping = true
	_scroll.visible = false
	(_find.get_parent() as Control).visible = false
	_rare_row.visible = false
	_own_row.visible = false
	_swaps_scroll.visible = true
	_swap_bar.visible = true
	_heading.text = "Rebuilt from what you own: %s" % OwnSwap.share_words(_own_short)
	for child: Node in _swaps.get_children():
		_swaps.remove_child(child)
		child.queue_free()
	_swap_note.text = "Finding a part or colour of yours for each…"
	_swap_now.disabled = true
	_offering = true
	await (_own_swapper as OwnSwap).offer_all(_own, _own_short["free"], _finder)
	var slice: int = Time.get_ticks_usec()
	for lot: RefCounted in _own:
		if not _swaps_scroll.visible or not _listing_own:
			break
		_swaps.add_child(_swap_row(lot))
		if Time.get_ticks_usec() - slice > OwnSwap.SLICE_US:
			await get_tree().process_frame
			slice = Time.get_ticks_usec()
	_offering = false
	_swapping = false
	if not _swaps_scroll.visible or not _listing_own:
		for child: Node in _swaps.get_children():
			_swaps.remove_child(child)
			child.queue_free()
		return
	_swap_note.text = ("Only the pieces you are short change, each to one you have free that the rest "
		+ "do not use: the same shape in its colour, or the same part in a colour within ΔE 10 of its "
		+ "finish. A print's plain part waits for you to tick it")
	_say_picked()


## The picked swaps put in as one undo step (OwnSwap.swap), said in the status
## bar, and the list taken again: its row says what changed and what is still
## missing. {} when nothing was picked.
func use_own() -> Dictionary:
	if _swapping or _own.is_empty() or not can_swap():
		return {}
	_swapping = true
	_swap_now.disabled = true
	var done: Dictionary = await (_own_swapper as OwnSwap).swap(_own, _finder)
	_swapping = false
	var stayed: PackedStringArray = done["stayed"]
	var words: String = str(done["words"])
	if int(done["changed"]) == 0:
		said.emit("nothing swapped" + (": " + "; ".join(stayed) if not stayed.is_empty() else ""))
		_show_rows()
		return done
	said.emit(Keymap.filled("%s — {undo|takes it back}") % (words
		+ ("" if stayed.is_empty() else "; stayed: " + "; ".join(stayed))))
	var picked_at: int = _was_at
	show_for(_world, library, _scenery, _title)
	_was_at = picked_at
	_own_words = "Swapped " + words.trim_prefix("swapped ")
	_say_own()
	return done
# end ownswap
