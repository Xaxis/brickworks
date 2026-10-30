## A booklet page laid out by hand, as Studio's Instruction Maker lays one
## out: the page the timeline's step is on, drawn to scale, and on it each
## step's picture, its parts box, its callout and its number, to drag where
## the designer wants them and to resize by the corner; words and a picture
## of their own to add. An item dragged snaps to the page's margins and
## middle and to the other items' edges (Booklet.snapped_to), a guide drawn
## along what it snapped to.
##
## Every drop is one undo (Shell.change_look, "place", "text", "image" and
## "note"), kept in the model's file as the app's own lines on the step
## (BookletLooks), and the booklet's PDF lays the page out the same way
## (Booklet._by_hand). What was never dragged stays where the booklet lays
## it, so a file without those lines prints as it did.
##
## Apply to later pages lays out every later page with as many steps as
## this one does, as Studio's page design applies a layout to "followings"
## ([method later_layout]): a 40-page booklet laid out from its first page.
##
## The page shows its boxes at once and the steps' pictures and parts a few
## seconds later, drawn as Instructions draws them (BookletMaker.draw_steps,
## the page's steps alone); a picture is stretched with its box while it is
## dragged and drawn again once it is let go.
##
## Words and pictures of the designer's turn and fade, as Studio's page
## objects do: by the knob above the selected one (whole degrees, and the
## fifteens it comes near), or Turn and Opacity typed in. An arrow bends
## through as many points as are pulled out of it: a handle in the middle of
## each stretch of it pulls a new one, a bend's own handle moves it, and a
## double-click takes it off. Guides are dragged onto the page from its
## rulers, on every page of the booklet, and what is dragged snaps to them
## before anything else; dragged off the page, a guide is gone. Each is one
## undo, and printed as the page shows it (Booklet.note_style,
## BookletLooks.arrow_line); the guides are not printed.
class_name PageEditor
extends Control

## The window's own things, read from Main.
var app: Node

var _world: BrickWorld
var _shell: Shell
var _pages: Array[Booklet.Page] = []
var _plan: Array[Instructions.Step] = []
## Which of [member _pages] is shown.
var _at: int = -1
## The items on the page: {kind, rect (page mm), entry, step (Instructions
## .Step), index (a note's), note, control}.
var _items: Array[Dictionary] = []
var _selected: int = -1
## A drag under way: {mode "move" or "resize", from (the pointer, canvas
## px), rect (page mm, as it began)}.
var _drag: Dictionary = {}
## Guides to draw while dragging: [["x" or "y", mm]].
var _guides: Array = []
var _laying: bool = false
## The undo history's length when last laid out: an undo or a redo made
## while the page is up shows on it.
var _seen_history: Array = []
var _pictures: Dictionary = {}
## The items of the page shown that were on top of another, by name: true
## where the page moved them off it.
var _overlapped: Dictionary = {}
## The page's steps drawn (BookletMaker.draw_steps): number -> {"picture":
## Texture2D, "cells": [[Texture2D, Rect2 within the callout box]]}; and
## each part's picture by its lot's key. The drawing under way, to cancel
## when the page changes before it is done.
var _shots: Dictionary = {}
var _part_shots: Dictionary = {}
## A callout's own page, by number -> the number of the model's step that
## puts the callout on, whose drawing draws the callout's pages.
var _attach_of: Dictionary = {}
## The callout's own page shown, by number, or -1.
var _callout_shown: int = -1
## The item the one being dragged is over, or -1.
var _over: int = -1
var _drawing: Working.Job = null

var _canvas: Control
var _handle: Control
## The selected word's or picture's turning knob.
var _knob: Control
## The selected arrow's handles: "start", "end", "bend_N" (the Nth point it
## bends through) and "add_N" (the middle of its Nth stretch, to bend it
## there) -> Control.
var _ends: Dictionary = {}
## The rulers along the page's top and left, to drag guides from.
var _ruler_top: Control
var _ruler_left: Control
## The booklet's guides (BookletLooks.guides), and the one being dragged:
## {axis "x" or "y", at (mm, or null off the page), was (mm, or null for a
## new one)}.
var _guide_lines: Dictionary = {"x": [], "y": []}
var _guide_drag: Dictionary = {}
var _turn_box: SpinBox
var _opacity_box: SpinBox
## Draw an arrow pressed: the next drag on the page draws one. The arrow
## being drawn, [start, end] in page mm, while it is.
var _arrow_mode: bool = false
var _sketch: Array = []
var _title: Label
var _words: LineEdit
var _said: Label
var _picker: PickImage
var _named: Dictionary = {}

const PAGE_COLOUR := Color8(220, 236, 248)
const PARTS_COLOUR := Color8(188, 218, 241)
const PARTS_LINE := Color8(61, 111, 151)
const CALLOUT_COLOUR := Color8(255, 243, 200)
const INK := Color8(21, 25, 30)
const PICK := Color(0.16, 0.45, 0.95)
const GUIDE := Color(0.92, 0.18, 0.62)
const OVERLAPPED := Color(0.86, 0.1, 0.1)
## A guide dragged from a ruler, and the rulers: their width in pixels.
const RULER_GUIDE := Color(0.0, 0.62, 0.86)
const RULER := 18.0
## How far in pixels the knob stands above what it turns, and how near in
## degrees a turn comes to a fifteen to land on it.
const KNOB_STEM := 22.0
const KNOB_SNAP := 3.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.08, 0.1, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 16
	column.offset_right = -16
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	column.add_child(row)
	_title = Label.new()
	_title.text = "Page"
	_title.add_theme_font_size_override("font_size", 14)
	row.add_child(_title)
	for spec: Array in [
			["page_prev", "Previous page", "The page before"],
			["page_next", "Next page", "The page after"],
			["page_add_text", "Add words", "Words of your own on this page; drag them where they go"],
			["page_add_image", "Add a picture…", "A picture of your own on this page, from a file"],
			["page_add_arrow", "Draw an arrow", "Then drag on the page from where the arrow "
				+ "starts to where it points; drag its middle to bend it"],
			["page_arrow_colour", "Arrow colour", "The selected arrow red, as a booklet points "
				+ "where a part goes in, or black, as its callout arrows are"],
			["page_arrow_width", "Arrow width", "The selected arrow thin, as the booklet's own, "
				+ "or broad"],
			["page_smaller", "Words smaller", "The selected words smaller"],
			["page_larger", "Words larger", "The selected words larger"],
			["page_put_back", "Put back", "The selected item where the booklet lays it out; "
				+ "words or a picture of your own taken off"],
			["page_apply_later", "Apply to later pages", "This page's layout on every later page "
				+ "with as many steps: each step's picture, parts list, number and callout where "
				+ "this page has them"],
			["page_done", "Done", "Back to the model"]]:
		var button := Button.new()
		button.text = spec[1]
		button.tooltip_text = spec[2]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		row.add_child(button)
		_named[spec[0]] = button
		var name: String = spec[0]
		button.pressed.connect(func() -> void: _pressed(name))
	_words = LineEdit.new()
	_words.placeholder_text = "the selected words"
	_words.custom_minimum_size = Vector2(240, 0)
	_words.editable = false
	# Enter sets the words and gives the keys back to the window, whose
	# Ctrl-Z is the model's undo and not the box's.
	_words.text_submitted.connect(func(_text: String) -> void: _words.release_focus())
	_words.focus_exited.connect(_reword)
	row.add_child(_words)
	_named["page_words"] = _words
	# The selected words' or picture's turn and opacity, typed in.
	_turn_box = _number_box("Turn ", "°", -180.0, 180.0,
		"The selected words or picture turned about their middle, in degrees clockwise")
	_turn_box.value_changed.connect(func(value: float) -> void: _set_note("turn", value))
	row.add_child(_turn_box)
	_named["page_turn"] = _turn_box
	_opacity_box = _number_box("Opacity ", "%", BookletLooks.FAINTEST * 100.0, 100.0,
		"How solid the selected words or picture are printed: 100% solid, less to fade them")
	_opacity_box.value_changed.connect(func(value: float) -> void: _set_note("opacity", value / 100.0))
	row.add_child(_opacity_box)
	_named["page_opacity"] = _opacity_box
	_said = Label.new()
	_said.add_theme_font_size_override("font_size", 11)
	_said.modulate = Color(1, 1, 1, 0.75)
	_said.text = "Drag an item to place it; drag its corner to size it."
	column.add_child(_said)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_page)
	_canvas.gui_input.connect(_on_canvas_input)
	holder.add_child(_canvas)
	holder.resized.connect(_fit)
	_named["page_canvas"] = _canvas
	# The rulers, in millimetres of page, to drag a guide from: the top one
	# a guide across, the left one a guide upright.
	for axis: String in ["y", "x"]:
		var ruler := Control.new()
		ruler.mouse_filter = Control.MOUSE_FILTER_STOP
		ruler.mouse_default_cursor_shape = Control.CURSOR_VSPLIT if axis == "y" else Control.CURSOR_HSPLIT
		ruler.tooltip_text = "Drag onto the page for a guide %s, which what you drag snaps to" % (
			"across it" if axis == "y" else "up it")
		ruler.draw.connect(func() -> void: _draw_ruler(ruler, axis))
		ruler.gui_input.connect(func(event: InputEvent) -> void: _on_ruler_input(axis, event))
		holder.add_child(ruler)
		if axis == "y":
			_ruler_top = ruler
		else:
			_ruler_left = ruler
	_named["page_ruler_top"] = _ruler_top
	_named["page_ruler_left"] = _ruler_left
	_handle = Control.new()
	_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_handle.size = Vector2(16, 16)
	_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_handle.gui_input.connect(_on_handle_input)
	_handle.draw.connect(_draw_handle)
	_handle.visible = false
	_canvas.add_child(_handle)
	_knob = Control.new()
	_knob.mouse_filter = Control.MOUSE_FILTER_STOP
	_knob.size = Vector2(16, 16)
	_knob.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_knob.tooltip_text = "Drag round to turn it"
	_knob.gui_input.connect(_on_knob_input)
	_knob.draw.connect(func() -> void:
		_knob.draw_circle(_knob.size * 0.5, 8.0, PICK)
		_knob.draw_arc(_knob.size * 0.5, 4.0, -PI * 0.9, PI * 0.4, 12, Color.WHITE, 1.6, true))
	_knob.visible = false
	_canvas.add_child(_knob)
	_picker = PickImage.new()
	add_child(_picker)
	_picker.picked.connect(add_image)
	_picker.failed.connect(func(why: String) -> void: _say(why))


## A box a number is typed into, with its unit, off until something it sets
## is selected.
func _number_box(prefix: String, suffix: String, least: float, most: float,
		tip: String) -> SpinBox:
	var box := SpinBox.new()
	box.prefix = prefix
	box.suffix = suffix
	box.min_value = least
	box.max_value = most
	box.step = 1.0
	box.editable = false
	box.tooltip_text = tip
	box.custom_minimum_size = Vector2(124, 0)
	box.add_theme_font_size_override("font_size", 12)
	box.get_line_edit().add_theme_font_size_override("font_size", 12)
	# Enter sets it and gives the keys back to the window, as the words do.
	box.get_line_edit().text_submitted.connect(func(_text: String) -> void:
		box.get_line_edit().release_focus.call_deferred())
	return box


## One of the selected arrow's handles: [param which] "start", "end",
## "bend_N" or "add_N" (see [member _ends]).
func _point(which: String) -> Control:
	var point := Control.new()
	point.mouse_filter = Control.MOUSE_FILTER_STOP
	point.size = Vector2(14, 14)
	point.mouse_default_cursor_shape = Control.CURSOR_CROSS
	point.gui_input.connect(func(event: InputEvent) -> void: _on_point_input(which, event))
	var adds: bool = which.begins_with("add_")
	point.tooltip_text = "Drag to bend the arrow here" if adds else (
		"Drag to move this bend; double-click to take it off" if which.begins_with("bend_") else "")
	point.draw.connect(func() -> void:
		if adds:
			point.draw_circle(point.size * 0.5, 5.0, Color(PICK, 0.55))
			point.draw_circle(point.size * 0.5, 3.0, Color.WHITE)
		else:
			point.draw_circle(point.size * 0.5, 7.0, PICK)
			point.draw_circle(point.size * 0.5, 4.0, PICK.lightened(0.6) if which.begins_with("bend_")
				else Color.WHITE))
	_canvas.add_child(point)
	_ends[which] = point
	return point


func is_open() -> bool:
	return visible


## Up, on the page the timeline's step is on.
func open() -> void:
	_world = app.get("_world")
	_shell = app.get("_shell")
	_shots.clear()
	_part_shots.clear()
	_callout_shown = -1
	visible = true
	var steps: StepsBar = app.get("_steps")
	var at: Instructions.Step = steps.booklet_step() if steps != null else null
	await _lay_out(at.number if at != null else -1)


func close() -> void:
	visible = false
	if _drawing != null:
		_drawing.cancelled = true
		_drawing = null
	_drag = {}
	_guide_drag = {}
	_items.clear()
	_selected = -1
	_arrow_mode = false
	_sketch = []
	_clear_controls()


func _process(_delta: float) -> void:
	if not visible or _laying:
		return
	var builder: Builder = app.get("_builder")
	var now: Array = [builder._history.size(), builder._redo.size()]
	if now != _seen_history and _drag.is_empty() and _guide_drag.is_empty():
		# Undone, redone, or changed from the timeline: shown as it is now.
		var number: int = _page_steps()[0] if not _page_steps().is_empty() else -1
		_lay_out(number)


## Escape closes the page, Delete takes the selected item back. Before the
## window's own keys, whose Delete would take the model's selected parts off
## behind the page.
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed \
			or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var key: InputEventKey = event
	if key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif key.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		if _selected >= 0:
			_pressed("page_put_back")
		get_viewport().set_input_as_handled()


# -- laying the page out ---------------------------------------------------------


## The booklet laid out as it would print now (BookletMaker.lay_out_only),
## shown at the page with step [param number] on it.
func _lay_out(number: int) -> void:
	if _laying:
		return
	_laying = true
	_say_soft("Laying the page out…")
	var store: ModelStore = app.get("_store")
	var maker := BookletMaker.new()
	maker.library = app.get("_library")
	app.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, store.scenery, "Model")
	_plan = maker.plan
	maker.queue_free()
	# A picture kept for a page and number that another step has now.
	for page: Booklet.Page in pages:
		for entry: Booklet.Entry in page.entries:
			var key: String = _shot_key(page.number, entry.number)
			if _shots.has(key) and str((_shots[key] as Dictionary).get("of", "")) \
					!= _step_said(entry, _plan):
				_shots.erase(key)
	_pages = []
	# The pages of steps, and a sub-assembly's own pages (a callout built on
	# pages of its own), each with the step of the model that puts it on.
	_attach_of.clear()
	var attaching: Dictionary = {}
	for page: Booklet.Page in pages:
		for entry: Booklet.Entry in page.entries:
			if entry.callout != null and not entry.callout.inline:
				for step: Booklet.Entry in entry.callout.steps:
					attaching[step] = entry.number
	for page: Booklet.Page in pages:
		if page.kind == "steps" or page.kind == "callout":
			_pages.append(page)
			if page.kind == "callout" and not page.entries.is_empty():
				_attach_of[page.number] = int(attaching.get(page.entries[0], -1))
	# The page of steps the step is on; a callout's own page shown stays
	# shown, its steps being numbered from 1 again.
	_at = 0
	for index: int in _pages.size():
		if _pages[index].kind != "steps":
			continue
		for entry: Booklet.Entry in _pages[index].entries:
			if entry.number == number:
				_at = index
	for index: int in _pages.size():
		if _pages[index].kind == "callout" and _pages[index].number == _callout_shown:
			_at = index
	var builder: Builder = app.get("_builder")
	_seen_history = [builder._history.size(), builder._redo.size()]
	_guide_lines = BookletLooks.guides(_world)
	_laying = false
	_show_page()


## The steps on the page shown, by number.
func _page_steps() -> Array:
	if _at < 0 or _at >= _pages.size():
		return []
	return _pages[_at].entries.map(func(entry: Booklet.Entry) -> int: return entry.number)


func _show_page() -> void:
	# What was selected, kept selected when it is on the page again; nothing
	# when the page was closed since (its items are gone).
	var keep: String = _item_name(_selected) if _selected >= 0 and _selected < _items.size() else ""
	_items.clear()
	_selected = -1
	_clear_controls()
	if _pages.is_empty():
		_title.text = "No pages of steps"
		_canvas.queue_redraw()
		return
	var page: Booklet.Page = _pages[_at]
	_callout_shown = page.number if page.kind == "callout" else -1
	var numbers := PackedStringArray()
	for number: int in _page_steps():
		numbers.append(str(number))
	_title.text = "Page %d (%sstep%s %s)" % [page.number,
		("the %s, built on its own: " % page.name) if page.kind == "callout" else "",
		"" if numbers.size() == 1 else "s", ", ".join(numbers)]
	for entry: Booklet.Entry in page.entries:
		var index: int = int(entry.get_meta("step", -1))
		var step: Instructions.Step = _plan[index] if index >= 0 and index < _plan.size() else null
		_add_item("picture", entry.rect, entry, step)
		if not entry.lots.is_empty():
			_add_item("parts", entry.parts_rect, entry, step)
		if entry.callout != null and entry.callout.inline:
			_add_item("callout", entry.callout.box, entry, step)
		_add_item("number", Rect2(entry.number_at, Vector2(
			entry.number_size * 0.62 * str(entry.number).length() + 1.0, entry.number_size)),
			entry, step)
		# The turn sign under the number where the view turns; taken off, a
		# faint one to put back.
		if entry.turned or entry.sign_off:
			_add_item("sign", Booklet.sign_rect(entry), entry, step)
		for at: int in entry.notes.size():
			var note: Dictionary = entry.notes[at]
			var item: Dictionary = _add_item("text" if note.has("text") else "image",
				BookletLooks.rect_of(note.get("at", [])), entry, step)
			item["index"] = at
			item["note"] = note
			item["turn"] = BookletLooks.turn_of(note)
			item["opacity"] = BookletLooks.opacity_of(note)
		for at: int in entry.drawn_arrows.size():
			var points: Array = BookletLooks.arrow_points(entry.drawn_arrows[at])
			if points.is_empty():
				continue
			var item: Dictionary = _add_item("arrow", _arrow_box(points), entry, step)
			item["index"] = at
			item["arrow"] = entry.drawn_arrows[at]
			item["points"] = points
			item["base"] = item["rect"]
	for at: int in _items.size():
		if _item_name(at) == keep:
			_select(at)
	if _selected < 0:
		# What was selected is gone (undone, or put back): nothing to type into.
		if _words.has_focus():
			_words.release_focus()
		_select(-1)
	_fit()
	# What would have printed on top of something else, and was moved off it
	# (Booklet._settle): outlined in red, and said.
	_overlapped.clear()
	for one: Dictionary in page.overlaps:
		_overlapped["page_%s_%d%s" % [one["item"], int(one["step"]),
			("_%d" % int(one["index"])) if one.has("index") else ""]] = bool(one["moved"])
	if page.overlaps.is_empty():
		_say_soft("Drag an item to place it; drag its corner to size it. It snaps to the margins and to the other items.")
	else:
		_say_soft("Overlapping: " + Booklet.overlaps_said(page) + ".")
	_draw_pictures()


## The page's steps drawn as Instructions draws them, in the background;
## the page shows them when they are done. Not headless, where nothing is
## drawn and each picture would be waited for in vain.
func _draw_pictures() -> void:
	if _drawing != null:
		_drawing.cancelled = true
	_drawing = null
	var numbers: Dictionary = {}
	var shown: Booklet.Page = _pages[_at] if _at >= 0 and _at < _pages.size() else null
	if shown != null and shown.kind == "callout":
		# A callout's own page is drawn with the step that puts it on.
		if int(_attach_of.get(shown.number, -1)) >= 0:
			numbers[int(_attach_of[shown.number])] = true
	else:
		for number: int in _page_steps():
			numbers[number] = true
	if numbers.is_empty() or DisplayServer.get_name() == "headless":
		return
	var job := Working.Job.new()
	_drawing = job
	var store: ModelStore = app.get("_store")
	var maker := BookletMaker.new()
	maker.library = app.get("_library")
	maker.job = job
	app.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.draw_steps(_world, store.scenery, "Model", numbers)
	var document: Booklet.Document = maker.document
	var drawn: Array[Instructions.Step] = maker.plan
	maker.queue_free()
	if job.cancelled or not visible or document == null:
		return
	_drawing = null
	for page: Booklet.Page in pages:
		if shown == null or page.number != shown.number:
			continue
		for entry: Booklet.Entry in page.entries:
			if entry.image.is_empty():
				continue
			var cells: Array = []
			if entry.callout != null and entry.callout.inline:
				for index: int in mini(entry.callout.images.size(), entry.callout.cells.size()):
					var cell: Rect2 = entry.callout.cells[index]
					cells.append([_texture(entry.callout.images[index]),
						Rect2(cell.position - entry.callout.box.position, cell.size)])
			_shots[_shot_key(page.number, entry.number)] = {"picture": _texture(entry.image),
				"cells": cells, "of": _step_said(entry, drawn)}
	for key: String in document.parts:
		if not _part_shots.has(key):
			_part_shots[key] = _texture(str(document.parts[key]))
	_canvas.queue_redraw()


## The drawn pictures of step [param number] on page [param page]: a
## callout's own pages number their steps from 1 again.
static func _shot_key(page: int, number: int) -> String:
	return "%d:%d" % [page, number]


## Which step [param entry] of [param plan] is, by its parts: a picture kept
## under its page and number is of another step once the steps have moved
## (Earlier, a merge, undone), and is not shown while its own is drawn.
static func _step_said(entry: Booklet.Entry, plan: Array[Instructions.Step]) -> String:
	var index: int = int(entry.get_meta("step", -1))
	if index < 0 or index >= plan.size():
		return ""
	return "%s|%s" % [str(plan[index].brick_ids), str(plan[index].copies)]


## A picture as a data URI, as a texture.
static func _texture(uri: String) -> Texture2D:
	var comma: int = uri.find(",")
	if comma < 0:
		return null
	var bytes: PackedByteArray = Marshalls.base64_to_raw(uri.substr(comma + 1))
	var image := Image.new()
	var read: int = ERR_FILE_UNRECOGNIZED
	if uri.begins_with("data:image/jpeg"):
		read = image.load_jpg_from_buffer(bytes)
	elif uri.begins_with("data:image/webp"):
		read = image.load_webp_from_buffer(bytes)
	else:
		read = image.load_png_from_buffer(bytes)
	return ImageTexture.create_from_image(image) if read == OK else null


func _add_item(kind: String, rect: Rect2, entry: Booklet.Entry, step: Instructions.Step) -> Dictionary:
	var control := Control.new()
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_MOVE
	var item: Dictionary = {"kind": kind, "rect": rect, "entry": entry, "step": step,
		"control": control}
	_items.append(item)
	var at: int = _items.size() - 1
	control.gui_input.connect(func(event: InputEvent) -> void: _on_item_input(at, event))
	_canvas.add_child(control)
	# Words and pictures of the designer's over the step's own items, and
	# arrows over all.
	if kind in ["text", "image"]:
		control.z_index = 1
	elif kind == "arrow":
		control.z_index = 2
	# Drawing an arrow: the page under the pointer, not the item.
	if _arrow_mode:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.move_child(_handle, -1)
	_canvas.move_child(_knob, -1)
	for point: Control in _ends.values():
		_canvas.move_child(point, -1)
	return item


## The box round an arrow's points, to pick it up by: [from, to, bends].
static func _arrow_box(points: Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO).expand(points[1])
	for bend: Vector2 in points[2]:
		box = box.expand(bend)
	return box.grow(2.5)


## Item [param item]'s arrow as it is shown now: [from, to, bends], moved
## with its box while it is dragged.
static func _shown_points(item: Dictionary) -> Array:
	var points: Array = item["points"]
	var by: Vector2 = (item["rect"] as Rect2).position - (item["base"] as Rect2).position
	return [points[0] + by, points[1] + by, (points[2] as Array).map(
		func(bend: Vector2) -> Vector2: return bend + by)]


func _clear_controls() -> void:
	for child: Node in _canvas.get_children():
		if child != _handle and child != _knob:
			child.queue_free()
			_canvas.remove_child(child)
	_ends.clear()
	_handle.visible = false
	_knob.visible = false


## The item's name, for the page to find it and a check to press it:
## "page_picture_5", "page_parts_5", "page_text_5_0" (step 5's first note).
func _item_name(at: int) -> String:
	var item: Dictionary = _items[at]
	var number: int = (item["entry"] as Booklet.Entry).number
	if item.has("index"):
		return "page_%s_%d_%d" % [item["kind"], number, int(item["index"])]
	return "page_%s_%d" % [item["kind"], number]


# -- drawing -----------------------------------------------------------------------


## Pixels a millimetre of page, and where the page is on the canvas.
func _scale() -> float:
	return _canvas.size.x / Booklet.PAGE.x


func _fit() -> void:
	var holder: Control = _canvas.get_parent()
	# The rulers along the top and the left, the page in what they leave.
	var room: Vector2 = holder.size - Vector2(RULER, RULER)
	var k: float = minf(room.x / Booklet.PAGE.x, room.y / Booklet.PAGE.y)
	_canvas.size = Booklet.PAGE * k
	_canvas.position = Vector2(RULER, RULER) + (room - _canvas.size) * 0.5
	_ruler_top.position = _canvas.position - Vector2(0.0, RULER)
	_ruler_top.size = Vector2(_canvas.size.x, RULER)
	_ruler_left.position = _canvas.position - Vector2(RULER, 0.0)
	_ruler_left.size = Vector2(RULER, _canvas.size.y)
	_ruler_top.queue_redraw()
	_ruler_left.queue_redraw()
	_place_controls()
	_canvas.queue_redraw()


func _place_controls() -> void:
	var k: float = _scale()
	for item: Dictionary in _items:
		var control: Control = item["control"]
		var rect: Rect2 = item["rect"]
		control.position = rect.position * k
		control.size = rect.size * k
		# A word or picture turned is picked up where it is drawn.
		control.pivot_offset = control.size * 0.5
		control.rotation = deg_to_rad(float(item.get("turn", 0.0)))
	var selected: Dictionary = _items[_selected] if _selected >= 0 and _selected < _items.size() else {}
	if not selected.is_empty():
		var rect: Rect2 = selected["rect"]
		_handle.position = _turned_point(selected, rect.end) * k - _handle.size * 0.5
		_handle.visible = not selected["kind"] in ["number", "arrow"]
	else:
		_handle.visible = false
	_knob.visible = not selected.is_empty() and selected["kind"] in ["text", "image"]
	if _knob.visible:
		_knob.position = _knob_at(selected) - _knob.size * 0.5
	var arrow: bool = not selected.is_empty() and selected["kind"] == "arrow"
	if not arrow:
		for which: String in _ends.keys():
			(_ends[which] as Control).queue_free()
			_ends.erase(which)
		return
	var shown: Array = _shown_points(selected)
	var bends: Array = shown[2]
	if _drag.get("mode", "") == "point":
		# Bending: only the handle in hand moves, the others are laid out
		# again when it is let go.
		var held: Control = _ends.get(str(_drag["which"]))
		var at: Variant = _drag.get("at")
		if held != null and at is Vector2:
			held.position = (at as Vector2) * k - held.size * 0.5
		return
	var wanted: Dictionary = {"start": shown[0], "end": shown[1]}
	for index: int in bends.size():
		wanted["bend_%d" % (index + 1)] = bends[index]
	if bends.size() < BookletLooks.MOST_BENDS:
		var head: float = BookletLooks.arrow_width(float((selected["arrow"] as Dictionary)
			.get("width", 0.9))) * 2.9 * 2.3
		for span: int in bends.size() + 1:
			wanted["add_%d" % (span + 1)] = BookletLooks.span_middle(shown, head, span)
	for which: String in _ends.keys():
		if not wanted.has(which):
			(_ends[which] as Control).queue_free()
			_ends.erase(which)
	for which: String in wanted:
		var point: Control = _ends[which] if _ends.has(which) else _point(which)
		point.position = (wanted[which] as Vector2) * k - point.size * 0.5
		point.visible = true


## [param point] (page mm) on [param item] as it is drawn: turned with it
## about its middle.
static func _turned_point(item: Dictionary, point: Vector2) -> Vector2:
	var turn: float = float(item.get("turn", 0.0))
	if is_zero_approx(turn):
		return point
	var middle: Vector2 = (item["rect"] as Rect2).get_center()
	return middle + (point - middle).rotated(deg_to_rad(turn))


## Where the knob that turns [param item] is, in the canvas's pixels: above
## the middle of its top, turned with it.
func _knob_at(item: Dictionary) -> Vector2:
	var k: float = _scale()
	var rect: Rect2 = item["rect"]
	var up: Vector2 = Vector2(0.0, -(rect.size.y * k * 0.5 + KNOB_STEM)).rotated(
		deg_to_rad(float(item.get("turn", 0.0))))
	return rect.get_center() * k + up


## The box [param item] takes on the page as it is drawn, in page mm: a turned
## word or picture's whole turned box.
static func _box_of(item: Dictionary) -> Rect2:
	var rect: Rect2 = item["rect"]
	if is_zero_approx(float(item.get("turn", 0.0))):
		return rect
	var box := Rect2(_turned_point(item, rect.position), Vector2.ZERO)
	for corner: Vector2 in [Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		box = box.expand(_turned_point(item, corner))
	return box


func _draw_page() -> void:
	var k: float = _scale()
	var font: Font = ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), PAGE_COLOUR)
	var area: Rect2 = Booklet.content()
	_canvas.draw_rect(Rect2(area.position * k, area.size * k), Color(0.24, 0.43, 0.59, 0.35),
		false, 1.0)
	if _at >= 0 and _at < _pages.size():
		var page: Booklet.Page = _pages[_at]
		if page.kind == "callout":
			# A sub-assembly's own page: its frame, as Booklet._page draws it.
			_canvas.draw_rect(Rect2(page.frame.position * k, page.frame.size * k), Color8(255, 248, 222))
			_canvas.draw_rect(Rect2(page.frame.position * k, page.frame.size * k), INK, false,
				maxf(1.0, 0.5 * k))
		if not page.banner.is_empty():
			_canvas.draw_rect(Rect2(Vector2(Booklet.MARGIN, Booklet.MARGIN) * k,
				Vector2(area.size.x, Booklet.BANNER - 3.0) * k), Color8(35, 82, 124))
		_canvas.draw_string(font, Vector2(Booklet.PAGE.x - Booklet.MARGIN - 8.0,
			Booklet.PAGE.y - 5.0) * k, str(page.number), HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(3.6 * k), INK)
	for at: int in _items.size():
		_draw_item(_items[at], k, font)
		if _overlapped.has(_item_name(at)) or at == _over and not _drag.is_empty():
			_outline(_items[at], OVERLAPPED, k)
	if _selected >= 0 and _selected < _items.size():
		_outline(_items[_selected], PICK, k)
		if _knob.visible:
			# The knob's stem, from the middle of the top it stands over.
			var item: Dictionary = _items[_selected]
			var rect: Rect2 = item["rect"]
			_canvas.draw_line(_turned_point(item, Vector2(rect.get_center().x, rect.position.y)) * k,
				_knob_at(item), PICK, 1.5, true)
	if _sketch.size() == 2:
		_draw_arrow([_sketch[0], _sketch[1], []], "red", 0.9, k)
	# The booklet's guides, across the whole page, and the one in hand.
	for axis: String in ["x", "y"]:
		for mm: Variant in _guide_lines.get(axis, []):
			if not _guide_drag.is_empty() and str(_guide_drag["axis"]) == axis \
					and _guide_drag.get("was") != null and is_equal_approx(float(mm), float(_guide_drag["was"])):
				continue
			_guide_line(axis, float(mm) * k, RULER_GUIDE)
	if not _guide_drag.is_empty() and _guide_drag.get("at") != null:
		_guide_line(str(_guide_drag["axis"]), float(_guide_drag["at"]) * k, RULER_GUIDE.lightened(0.3))
	for guide: Array in _guides:
		var mm: float = float(guide[1]) * k
		if str(guide[0]) == "x":
			_canvas.draw_line(Vector2(mm, 0), Vector2(mm, _canvas.size.y), GUIDE, 1.0)
		else:
			_canvas.draw_line(Vector2(0, mm), Vector2(_canvas.size.x, mm), GUIDE, 1.0)


## A guide [param axis] "x" (upright) or "y" (across), [param at] pixels in.
func _guide_line(axis: String, at: float, colour: Color) -> void:
	if axis == "x":
		_canvas.draw_line(Vector2(at, 0), Vector2(at, _canvas.size.y), colour, 1.0)
	else:
		_canvas.draw_line(Vector2(0, at), Vector2(_canvas.size.x, at), colour, 1.0)


## [param item]'s box outlined in [param colour], turned as it is drawn.
func _outline(item: Dictionary, colour: Color, k: float) -> void:
	var rect: Rect2 = item["rect"]
	var turn: float = float(item.get("turn", 0.0))
	if is_zero_approx(turn):
		_canvas.draw_rect(Rect2(rect.position * k, rect.size * k), colour, false, 2.0)
		return
	_canvas.draw_set_transform(rect.get_center() * k, deg_to_rad(turn))
	_canvas.draw_rect(Rect2(-rect.size * k * 0.5, rect.size * k), colour, false, 2.0)
	_canvas.draw_set_transform(Vector2.ZERO)


func _draw_item(item: Dictionary, k: float, font: Font) -> void:
	var rect := Rect2((item["rect"] as Rect2).position * k, (item["rect"] as Rect2).size * k)
	var entry: Booklet.Entry = item["entry"]
	if item["kind"] in ["text", "image"]:
		_draw_note(item, rect, font)
		return
	match str(item["kind"]):
		"picture":
			var drawn: Texture2D = (_shots.get(_shot_key(entry.page, entry.number), {}) as Dictionary).get("picture")
			if drawn != null:
				# As Instructions draws it, stretched with its box while dragged.
				_canvas.draw_texture_rect(drawn, rect, false)
				_dashed(rect, Color(0.24, 0.43, 0.59, 0.5))
				return
			_canvas.draw_rect(rect, Color(1, 1, 1, 0.28))
			_dashed(rect, Color(0.24, 0.43, 0.59, 0.8))
			# The model's room in it, at the size it is drawn, until it is drawn.
			var need: Vector2 = entry.subject.size * entry.scale
			var free: Rect2 = Rect2(rect.get_center() - need * k * 0.5, need * k) \
				if entry.place.has("picture") \
				else Rect2(rect.position + (entry.free.position - entry.rect.position) * k,
					entry.free.size * k)
			_canvas.draw_rect(free, Color(0.24, 0.43, 0.59, 0.16))
			_canvas.draw_string(font, free.get_center() + Vector2(-free.size.x * 0.5, 4),
				"Step %d's picture (drawing…)" % entry.number, HORIZONTAL_ALIGNMENT_CENTER,
				free.size.x, int(clampf(3.4 * k, 9, 18)), Color(0.15, 0.3, 0.45))
		"parts":
			_canvas.draw_rect(rect, PARTS_COLOUR)
			_canvas.draw_rect(rect, PARTS_LINE, false, maxf(1.0, 0.35 * k))
			# The parts in the rows the booklet puts them in (Booklet._entry).
			var y: float = (item["rect"] as Rect2).position.y + Booklet.PAD
			for row: Array in Booklet._rows(entry.lots, entry.parts_width):
				var x: float = (item["rect"] as Rect2).position.x + Booklet.PAD
				var tallest: float = float(row[2])
				for lot: Booklet.Lot in row[0]:
					var cell: float = maxf(lot.size.x, Booklet.QUANTITY * 2.0)
					var spot := Rect2(Vector2(x + (cell - lot.size.x) * 0.5,
						y + tallest - lot.size.y) * k, lot.size * k)
					var part: Texture2D = _part_shots.get(lot.key)
					if part != null:
						_canvas.draw_texture_rect(part, spot, false)
					else:
						_canvas.draw_rect(spot, Color(1, 1, 1, 0.5))
					_canvas.draw_string(font, Vector2(x, y + tallest + Booklet.QUANTITY) * k,
						"%dx" % lot.count, HORIZONTAL_ALIGNMENT_LEFT, -1,
						int(maxf(8, Booklet.QUANTITY * 0.82 * k)), INK)
					x += cell + Booklet.PAD
				y += tallest + Booklet.QUANTITY + 1.0
		"callout":
			_canvas.draw_rect(rect, CALLOUT_COLOUR)
			_canvas.draw_rect(rect, INK, false, maxf(1.0, 0.4 * k))
			var scale_by: Vector2 = (item["rect"] as Rect2).size \
				/ entry.callout.box.size.max(Vector2(1, 1))
			for cell: Array in (_shots.get(_shot_key(entry.page, entry.number), {}) as Dictionary).get("cells", []):
				if cell[0] != null:
					var at: Rect2 = cell[1]
					_canvas.draw_texture_rect(cell[0], Rect2(rect.position + at.position * scale_by * k,
						at.size * scale_by * k), false)
			_canvas.draw_string(font, rect.position + Vector2(6, 16), "%s%s" % [
				entry.callout.name, (" %dx" % entry.callout.times) if entry.callout.times > 1 else ""],
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 12, INK)
		"number":
			_canvas.draw_string(font, rect.position + Vector2(0, entry.number_size * k * 0.82),
				str(entry.number), HORIZONTAL_ALIGNMENT_LEFT, -1, int(entry.number_size * k), INK)
		"arrow":
			var arrow: Dictionary = item["arrow"]
			_draw_arrow(_shown_points(item), str(arrow.get("colour", "red")),
				float(arrow.get("width", 0.9)), k)
		"sign":
			if entry.turned:
				# As the booklet prints it (Booklet._turn_sign), drawn plainly.
				_canvas.draw_rect(rect, Color.WHITE)
				_canvas.draw_rect(rect, INK, false, maxf(1.0, 0.35 * k))
				var centre: Vector2 = rect.get_center()
				var r: float = rect.size.x * 0.36
				for radii: Vector2 in [Vector2(r * 0.4, r), Vector2(r, r * 0.4)]:
					var ring := PackedVector2Array()
					for n: int in 33:
						var t: float = TAU * n / 32.0
						ring.append(centre + Vector2(cos(t) * radii.x, sin(t) * radii.y))
					_canvas.draw_polyline(ring, INK, maxf(1.0, rect.size.x * 0.06), true)
			else:
				_dashed(rect, Color(0.3, 0.3, 0.3, 0.5))
				_canvas.draw_string(font, rect.position + Vector2(2, rect.size.y * 0.55), "sign off",
					HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 2, int(clampf(2.4 * k, 8, 12)),
					Color(0.3, 0.3, 0.3, 0.8))


## Words or a picture of the designer's in [param rect] (canvas pixels),
## turned about its middle and as faint as it prints (Booklet.note_style).
func _draw_note(item: Dictionary, rect: Rect2, font: Font) -> void:
	var note: Dictionary = item["note"]
	var turn: float = float(item.get("turn", 0.0))
	var alpha: float = float(item.get("opacity", 1.0))
	if not is_zero_approx(turn):
		_canvas.draw_set_transform(rect.get_center(), deg_to_rad(turn))
		rect = Rect2(-rect.size * 0.5, rect.size)
	if item["kind"] == "text":
		var size: int = int(maxf(6.0, float(note.get("size", 4.0)) * _scale()))
		_canvas.draw_multiline_string(font, rect.position + Vector2(0, size * 0.85),
			str(note.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, -1,
			Color(INK, alpha))
		_dashed(rect, Color(0.3, 0.3, 0.3, 0.35))
	else:
		var texture: Texture2D = _picture(str(note.get("image", "")))
		if texture != null:
			_canvas.draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))
		else:
			_canvas.draw_rect(rect, Color(0.5, 0.5, 0.5, 0.3))
	_canvas.draw_set_transform(Vector2.ZERO)


## An arrow as the booklet prints it (Booklet.drawn_arrow): through its
## bends as a curve (BookletLooks.arrow_line), a white edge under it, and
## its head.
func _draw_arrow(points: Array, colour: String, width: float, k: float) -> void:
	var to: Vector2 = points[1]
	var head: float = BookletLooks.arrow_width(width) * 2.9
	var drawn: Dictionary = BookletLooks.arrow_line(points, head * 2.3)
	if drawn.is_empty():
		return
	var way: Vector2 = drawn["way"]
	var base: Vector2 = to - way * head * 2.3
	var line := PackedVector2Array()
	for point: Vector2 in drawn["line"]:
		line.append(point * k)
	var ink := Color(str(BookletLooks.ARROW_COLOURS.get(colour, BookletLooks.ARROW_COLOURS["red"])))
	_canvas.draw_polyline(line, Color.WHITE, maxf(1.0, (width + 0.7) * k), true)
	_canvas.draw_polyline(line, ink, maxf(1.0, width * k), true)
	var side := Vector2(-way.y, way.x)
	_canvas.draw_colored_polygon(PackedVector2Array([to * k, (base + side * head) * k,
		(base - side * head) * k]), ink)


func _draw_handle() -> void:
	_handle.draw_rect(Rect2(Vector2.ZERO, _handle.size), PICK)
	_handle.draw_rect(Rect2(Vector2(3, 3), _handle.size - Vector2(6, 6)), Color.WHITE)


## A ruler in millimetres of page: a tick each 5, a longer one each 10, a
## number each 50, and a mark where each guide is.
func _draw_ruler(ruler: Control, axis: String) -> void:
	var k: float = _scale()
	var font: Font = ThemeDB.fallback_font
	var along: bool = axis == "y"
	ruler.draw_rect(Rect2(Vector2.ZERO, ruler.size), Color(0.15, 0.17, 0.2))
	var length: float = Booklet.PAGE.x if along else Booklet.PAGE.y
	var ink := Color(0.78, 0.82, 0.88)
	for mm: int in range(0, int(length) + 1, 5):
		var tick: float = RULER * (0.6 if mm % 50 == 0 else (0.4 if mm % 10 == 0 else 0.22))
		var at: float = mm * k
		if along:
			ruler.draw_line(Vector2(at, RULER), Vector2(at, RULER - tick), ink, 1.0)
		else:
			ruler.draw_line(Vector2(RULER, at), Vector2(RULER - tick, at), ink, 1.0)
		if mm % 50 == 0 and mm > 0:
			ruler.draw_string(font, Vector2(at + 2.0, 9.0) if along else Vector2(1.0, at - 2.0),
				str(mm), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ink)
	# The guides, by the other ruler: a ruler along the top marks the upright
	# ones, which are measured along it.
	for mm: Variant in _guide_lines.get("x" if along else "y", []):
		var at: float = float(mm) * k
		ruler.draw_colored_polygon(PackedVector2Array([Vector2(at - 4.0, RULER), Vector2(at + 4.0, RULER),
			Vector2(at, RULER - 6.0)]) if along else PackedVector2Array([Vector2(RULER, at - 4.0),
			Vector2(RULER, at + 4.0), Vector2(RULER - 6.0, at)]), RULER_GUIDE)


## A drag from a ruler onto the page: a new guide, across from the top
## ruler and upright from the left one, where it is let go on the page.
func _on_ruler_input(axis: String, event: InputEvent) -> void:
	if not visible or _pages.is_empty():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_guide_drag = {"axis": axis, "at": null, "was": null}
		elif not _guide_drag.is_empty():
			_let_guide_go()
		accept_event()
	elif event is InputEventMouseMotion and not _guide_drag.is_empty():
		_guide_moved(event as InputEventMouse)
		accept_event()


## The guide in hand where the pointer is: on the page, or off it (null),
## where letting go takes it off.
func _guide_moved(event: InputEventMouse) -> void:
	var on: Vector2 = _on_canvas(event) / _scale()
	var axis: String = str(_guide_drag["axis"])
	var mm: float = on.x if axis == "x" else on.y
	var most: float = Booklet.PAGE.x if axis == "x" else Booklet.PAGE.y
	_guide_drag["at"] = snappedf(mm, 0.1) if mm >= 0.0 and mm <= most else null
	_say_soft(("A guide %s at %s mm: let go to put it there." % ["upright" if axis == "x" else "across",
		BookletLooks._number(float(_guide_drag["at"]))]) if _guide_drag["at"] != null
		else "Let go off the page and the guide is taken off.")
	_canvas.queue_redraw()


## The guide in hand put where it was let go: one undo (Shell.change_look
## "guide"), on every page.
func _let_guide_go() -> void:
	var drag: Dictionary = _guide_drag
	_guide_drag = {}
	_canvas.queue_redraw()
	if drag.get("at") == null and drag.get("was") == null:
		_say_soft("Drag from a ruler onto the page for a guide.")
		return
	if drag.get("at") != null and drag.get("was") != null \
			and absf(float(drag["at"]) - float(drag["was"])) < 0.05:
		return
	_say(guide(str(drag["axis"]), drag.get("at"), drag.get("was")))


## A guide on the booklet's pages: [param axis] "x" (upright) or "y"
## (across) at [param at] mm, null to take it off; [param was] the one it
## moves, null for a new one. One undo.
func guide(axis: String, at: Variant, was: Variant = null) -> String:
	var first: Dictionary = _first()
	if first.is_empty():
		return "no page to put a guide on"
	var said: String = _shell.change_look("guide", first["step"], {"axis": axis, "at": at, "was": was})
	_guide_lines = BookletLooks.guides(_world)
	_ruler_top.queue_redraw()
	_ruler_left.queue_redraw()
	_canvas.queue_redraw()
	return said


## The guide [param at] (canvas pixels) is on, within 4 px: [axis, mm], or [].
func _guide_under(at: Vector2) -> Array:
	var k: float = _scale()
	for axis: String in ["x", "y"]:
		for mm: Variant in _guide_lines.get(axis, []):
			if absf((at.x if axis == "x" else at.y) - float(mm) * k) <= 4.0:
				return [axis, float(mm)]
	return []


func _dashed(rect: Rect2, colour: Color) -> void:
	for side: Array in [[rect.position, Vector2(rect.end.x, rect.position.y)],
			[Vector2(rect.end.x, rect.position.y), rect.end],
			[rect.end, Vector2(rect.position.x, rect.end.y)],
			[Vector2(rect.position.x, rect.end.y), rect.position]]:
		_canvas.draw_dashed_line(side[0], side[1], colour, 1.0, 5.0)


## A picture of the designer's, decoded once.
func _picture(name: String) -> Texture2D:
	if _pictures.has(name):
		return _pictures[name]
	var data: String = str(BookletLooks.images(_world).get(name, ""))
	if data.is_empty():
		# Undone a moment ago, before the page was laid out again.
		return null
	var image := Image.new()
	var bytes: PackedByteArray = Marshalls.base64_to_raw(data)
	var failed: int = image.load_png_from_buffer(bytes) if name.ends_with(".png") \
		else image.load_jpg_from_buffer(bytes)
	var texture: Texture2D = ImageTexture.create_from_image(image) if failed == OK else null
	_pictures[name] = texture
	return texture


# -- the pointer ---------------------------------------------------------------------


func _on_canvas_input(event: InputEvent) -> void:
	if _arrow_mode:
		_drawing_arrow(event)
		return
	# A guide picked up where nothing is over it, and moved, or dragged off.
	if not _guide_drag.is_empty():
		if event is InputEventMouseMotion:
			_guide_moved(event as InputEventMouse)
		elif event is InputEventMouseButton and not event.pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_let_guide_go()
		accept_event()
		return
	var near: Array = _guide_under(_on_canvas(event as InputEventMouse)) \
		if event is InputEventMouse else []
	if event is InputEventMouseMotion:
		_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW if near.is_empty() \
			else (Control.CURSOR_HSPLIT if near[0] == "x" else Control.CURSOR_VSPLIT)
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not near.is_empty():
			_guide_drag = {"axis": near[0], "at": near[1], "was": near[1]}
			accept_event()
			return
		_select(-1)


## Draw an arrow: pressed where it starts, dragged to where it points, let
## go there; each end snapped as an item snaps. One undo, on the step whose
## room it points into (the page's first step where it points into none).
func _drawing_arrow(event: InputEvent) -> void:
	var k: float = _scale()
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = _snap_point(_on_canvas(event as InputEventMouse) / k)
		if (event as InputEventMouseButton).pressed:
			_sketch = [at, at]
		elif _sketch.size() == 2:
			var from: Vector2 = _sketch[0]
			_sketch = []
			_guides = []
			_canvas.queue_redraw()
			if from.distance_to(at) < 3.0:
				return
			_arrow_mode = false
			add_arrow(from, at)
		accept_event()
	elif event is InputEventMouseMotion and _sketch.size() == 2:
		_sketch[1] = _snap_point(_on_canvas(event as InputEventMouse) / k)
		_canvas.queue_redraw()
		accept_event()


## [param at] (page mm) snapped to the margins, the page's middle and the
## items' edges and middles within Booklet.SNAP, the guides it snapped to
## shown.
func _snap_point(at: Vector2) -> Vector2:
	var others: Array = []
	for item: Dictionary in _items:
		if item["kind"] != "arrow":
			others.append(item["rect"])
	var snapped: Dictionary = Booklet.snapped_to(Rect2(at, Vector2.ZERO), others, false, _guide_lines)
	_guides = snapped["lines"]
	return (snapped["rect"] as Rect2).position


## An arrow of the designer's drawn on the page shown, from [param from] to
## [param to] (page mm) through [param bends], red and as wide as the
## booklet's red pointer: one undo.
func add_arrow(from: Vector2, to: Vector2, bends: Array = []) -> String:
	var owner: Dictionary = _first()
	for item: Dictionary in _items:
		if item["kind"] == "picture" and (item["entry"] as Booklet.Entry).panel.has_point(to):
			owner = item
			break
	if owner.is_empty():
		return "no page to draw on"
	var said: String = _change("arrow", owner, {"at": BookletLooks.arrow_at([from, to, bends]),
		"colour": "red", "width": 0.9})
	_say(said)
	await _lay_out((owner["entry"] as Booklet.Entry).number)
	# The new arrow selected, to bend or recolour.
	for n: int in range(_items.size() - 1, -1, -1):
		if _items[n]["kind"] == "arrow" and (_items[n]["points"][1] as Vector2).distance_to(to) < 0.6:
			_select(n)
			break
	return said


## A drag of one of the selected arrow's handles: its start or end, a point
## it bends through, or the middle of a stretch of it, which bends it there
## (a new point, after the stretch's first). A double-click on a bend takes
## it off. One undo each.
func _on_point_input(which: String, event: InputEvent) -> void:
	if _selected < 0 or _selected >= _items.size() or _items[_selected]["kind"] != "arrow":
		return
	var item: Dictionary = _items[_selected]
	var k: float = _scale()
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button: InputEventMouseButton = event
		if button.pressed and button.double_click and which.begins_with("bend_"):
			_drag = {}
			var points: Array = (item["points"] as Array).duplicate(true)
			(points[2] as Array).remove_at(which.trim_prefix("bend_").to_int() - 1)
			_say(_change("arrow_edit", item, {"index": int(item["index"]),
				"at": BookletLooks.arrow_at(points)}))
			await _lay_out((item["entry"] as Booklet.Entry).number)
		elif button.pressed:
			var points: Array = (item["points"] as Array).duplicate(true)
			if which.begins_with("add_"):
				# A new bend where the handle is, after the stretch's first point.
				var span: int = which.trim_prefix("add_").to_int() - 1
				(points[2] as Array).insert(span, _on_canvas(button) / k)
			_drag = {"mode": "point", "which": which, "points": points, "moved": false}
		elif not _drag.is_empty():
			var points: Array = item["points"]
			var moved: bool = bool(_drag.get("moved", false))
			_drag = {}
			_guides = []
			if moved:
				_say(_change("arrow_edit", item, {"index": int(item["index"]),
					"at": BookletLooks.arrow_at(points)}))
			await _lay_out((item["entry"] as Booklet.Entry).number)
		accept_event()
	elif event is InputEventMouseMotion and not _drag.is_empty() and _drag.get("mode") == "point":
		var at: Vector2 = _on_canvas(event as InputEventMouse) / k
		var points: Array = (_drag["points"] as Array).duplicate(true)
		if which == "start":
			at = _snap_point(at)
			points[0] = at
		elif which == "end":
			at = _snap_point(at)
			points[1] = at
		else:
			# The bend in hand: an added one is the stretch's new point.
			var number: int = which.trim_prefix("bend_").trim_prefix("add_").to_int() - 1
			(points[2] as Array)[number] = at
		_drag["at"] = at
		_drag["moved"] = true
		item["points"] = points
		item["rect"] = _arrow_box(points)
		item["base"] = item["rect"]
		_place_controls()
		_canvas.queue_redraw()
		accept_event()


func _on_item_input(at: int, event: InputEvent) -> void:
	if at >= _items.size():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button: InputEventMouseButton = event
		if button.pressed:
			_select(at)
			# The turn sign stays under its number: selected, to take off.
			if _items[at]["kind"] != "sign":
				_drag = {"mode": "move", "from": _on_canvas(button),
					"rect": _items[at]["rect"]}
		elif not _drag.is_empty():
			_drop()
		accept_event()
	elif event is InputEventMouseMotion and not _drag.is_empty():
		_dragged(event as InputEventMouse)
		accept_event()


func _on_handle_input(event: InputEvent) -> void:
	if _selected < 0:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_drag = {"mode": "resize", "from": _on_canvas(event as InputEventMouse),
				"rect": _items[_selected]["rect"]}
		elif not _drag.is_empty():
			_drop()
		accept_event()
	elif event is InputEventMouseMotion and not _drag.is_empty():
		_dragged(event as InputEventMouse)
		accept_event()


## The knob over the selected words or picture, dragged round: turned to
## where it points, in whole degrees, onto a fifteen it comes within
## KNOB_SNAP of (0, 15, 30, 45 ...). One undo when it is let go.
func _on_knob_input(event: InputEvent) -> void:
	if _selected < 0 or _selected >= _items.size() or not _items[_selected]["kind"] in ["text", "image"]:
		return
	var item: Dictionary = _items[_selected]
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_drag = {"mode": "turn", "turn": float(item.get("turn", 0.0))}
		elif not _drag.is_empty():
			var was: float = float(_drag["turn"])
			_drag = {}
			if not is_equal_approx(float(item.get("turn", 0.0)), was):
				await _set_note("turn", float(item["turn"]))
		accept_event()
	elif event is InputEventMouseMotion and _drag.get("mode") == "turn":
		var way: Vector2 = _on_canvas(event as InputEventMouse) - (item["rect"] as Rect2).get_center() * _scale()
		if way.length() > 4.0:
			item["turn"] = knob_turn(way)
			_turn_box.set_value_no_signal(float(item["turn"]))
			_say_soft("Turned to %s°: let go to keep it." % BookletLooks._number(float(item["turn"])))
			_place_controls()
			_canvas.queue_redraw()
		accept_event()


## The turn the knob gives pointing [param way] from the middle (canvas
## pixels, down the page positive): 0 straight up, clockwise, in whole
## degrees, a fifteen when it is within KNOB_SNAP of one.
static func knob_turn(way: Vector2) -> float:
	var turn: float = rad_to_deg(atan2(way.x, -way.y))
	var fifteen: float = roundf(turn / 15.0) * 15.0
	turn = fifteen if absf(turn - fifteen) <= KNOB_SNAP else roundf(turn)
	return fposmod(turn + 180.0, 360.0) - 180.0 if turn != 180.0 else 180.0


## The selected words or picture turned ([param field] "turn", degrees) or
## faded ("opacity", 0.05 to 1), as Turn, Opacity or the knob sets it: one
## undo, kept selected.
func _set_note(field: String, value: float) -> String:
	if _selected < 0 or _selected >= _items.size() or not _items[_selected]["kind"] in ["text", "image"]:
		return "select words or a picture of your own first"
	var item: Dictionary = _items[_selected]
	var keep: String = _item_name(_selected)
	var said: String = _change("note", item, {"index": int(item["index"]), field: value})
	_say(said)
	await _lay_out((item["entry"] as Booklet.Entry).number)
	var again: int = item_named(keep)
	if again >= 0:
		_select(again)
	return said


func _select(at: int) -> void:
	_selected = at
	var note: bool = at >= 0 and _items[at]["kind"] == "text"
	_words.editable = note
	_words.text = str((_items[at]["note"] as Dictionary).get("text", "")) if note else ""
	var own: bool = at >= 0 and _items[at]["kind"] in ["text", "image"]
	_turn_box.editable = own
	_opacity_box.editable = own
	_turn_box.set_value_no_signal(float(_items[at].get("turn", 0.0)) if own else 0.0)
	_opacity_box.set_value_no_signal(roundf(float(_items[at].get("opacity", 1.0)) * 100.0) if own else 100.0)
	if at >= 0 and _items[at]["kind"] == "arrow":
		_say_soft("%s: drag to move it, its ends to point it, a dot along it to bend it there, a bend to move it (double-click takes it off); Arrow colour, Arrow width." \
			% _item_name(at).trim_prefix("page_"))
	elif at >= 0:
		_say_soft("%s: drag to place it, its corner to size it%s%s." % [_item_name(at).trim_prefix("page_"),
			", the knob above to turn it" if own else "", ", type its words above" if note else ""])
	_place_controls()
	_canvas.queue_redraw()


## Where [param event] is on the page's canvas, in its pixels: read off the
## event, which a real pointer and one a check sends both carry, and not the
## viewport's own idea of where the mouse is, which a sent one does not move.
func _on_canvas(event: InputEventMouse) -> Vector2:
	return _canvas.get_global_transform().affine_inverse() * event.global_position


## The item under the pointer where the drag has it now, snapped.
func _dragged(event: InputEventMouse) -> void:
	var item: Dictionary = _items[_selected]
	var k: float = _scale()
	var by: Vector2 = (_on_canvas(event) - (_drag["from"] as Vector2)) / k
	var was: Rect2 = _drag["rect"]
	var resize: bool = _drag["mode"] == "resize"
	var turn: float = deg_to_rad(float(item.get("turn", 0.0)))
	var others: Array = []
	for at: int in _items.size():
		if at != _selected:
			others.append(_box_of(_items[at]))
	if not is_zero_approx(turn):
		# Turned: sized along its own sides, the corner across from the
		# handle staying where it is; moved by its turned box, which snaps.
		if resize:
			var size: Vector2 = (was.size + by.rotated(-turn)).max(Vector2(6, 4))
			var middle: Vector2 = was.get_center() + ((size - was.size) * 0.5).rotated(turn)
			item["rect"] = Rect2(middle - size * 0.5, size)
			_guides = []
		else:
			item["rect"] = Rect2(was.position + by, was.size)
			var box: Rect2 = _box_of(item)
			var snapped: Dictionary = Booklet.snapped_to(box, others, false, _guide_lines)
			var onto: Rect2 = _on_page(snapped["rect"], false)
			item["rect"] = Rect2((item["rect"] as Rect2).position + onto.position - box.position, was.size)
			_guides = snapped["lines"]
	else:
		var moved: Rect2 = Rect2(was.position + (Vector2.ZERO if resize else by),
			was.size + (by if resize else Vector2.ZERO))
		moved.size = moved.size.max(Vector2(6, 4))
		var snapped: Dictionary = Booklet.snapped_to(_on_page(moved, resize), others, resize, _guide_lines)
		# Kept on the page as the booklet keeps it (Booklet._on_page), so what is
		# dragged is where it prints.
		item["rect"] = _on_page(snapped["rect"], resize)
		_guides = snapped["lines"]
	# Over another thing as it is dragged: said, and outlined, before it is
	# let go (Booklet._settle moves one of them off the other when it is).
	_over = -1
	for at: int in _items.size():
		if at == _selected or _items[at]["kind"] in ["arrow", "sign"]:
			continue
		var solid: Rect2 = _items[at]["rect"]
		if _items[at]["kind"] == "picture":
			solid = Booklet.ink_of(_items[at]["entry"])
		var shared: Rect2 = (item["rect"] as Rect2).intersection(solid)
		if shared.size.x > Booklet.OVERLAP and shared.size.y > Booklet.OVERLAP:
			_over = at
			break
	if _over >= 0:
		_say_soft("Over step %d's %s: let go here and one of them is moved off the other." % [
			(_items[_over]["entry"] as Booklet.Entry).number, Booklet._thing_word(str(_items[_over]["kind"]))])
	_place_controls()
	_canvas.queue_redraw()


## [param rect] on the page: moved onto it, or, [param resize]d by its far
## corner, no larger than reaches the page's edge.
static func _on_page(rect: Rect2, resize: bool) -> Rect2:
	var size: Vector2 = rect.size.min(Booklet.PAGE)
	if resize:
		return Rect2(rect.position, size.min(Booklet.PAGE - rect.position))
	return Rect2(rect.position.clamp(Vector2.ZERO, Booklet.PAGE - size), size)


## The item dropped where it is: one undo.
func _drop() -> void:
	var item: Dictionary = _items[_selected]
	var was: Rect2 = _drag["rect"]
	_drag = {}
	_over = -1
	_guides = []
	var rect: Rect2 = item["rect"]
	if rect.position.distance_to(was.position) < 0.05 and rect.size.distance_to(was.size) < 0.05:
		_canvas.queue_redraw()
		return
	place(_selected, rect)


## Item [param at] placed at [param rect] (page mm): one undo, and the page
## laid out again from what the booklet now says.
func place(at: int, rect: Rect2) -> String:
	var item: Dictionary = _items[at]
	var said: String = ""
	var numbers: Array = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if item["kind"] == "arrow":
		# Moved whole, by as much as its box was.
		item["rect"] = rect
		said = _change("arrow_edit", item, {"index": int(item["index"]),
			"at": BookletLooks.arrow_at(_shown_points(item))})
	elif item.has("index"):
		said = _change("note", item, {"index": int(item["index"]), "at": numbers})
	else:
		said = _change("place", item, {"item": item["kind"],
			"at": numbers.slice(0, int(BookletLooks.ITEMS[item["kind"]]))})
	_say(said)
	await _lay_out((item["entry"] as Booklet.Entry).number)
	return said


## A change to what is on [param item]'s step's page (Shell.change_look),
## kept with the room the step has on the page now, so that it goes with
## the step when the page changes round it.
func _change(op: String, item: Dictionary, fields: Dictionary) -> String:
	fields["room"] = BookletLooks.said_rect((item["entry"] as Booklet.Entry).panel)
	return _shell.change_look(op, item["step"], fields)


func _pressed(name: String) -> void:
	match name:
		"page_done":
			close()
		"page_prev", "page_next":
			if _pages.is_empty():
				return
			_at = clampi(_at + (-1 if name == "page_prev" else 1), 0, _pages.size() - 1)
			_selected = -1
			_show_page()
		"page_add_text":
			add_text("Your words", Rect2(Vector2(Booklet.PAGE.x * 0.5 - 40.0, 150.0), Vector2(80, 12)))
		"page_add_image":
			_picker.ask()
		"page_apply_later":
			await apply_to_later()
		"page_add_arrow":
			_arrow_mode = not _arrow_mode
			_select(-1)
			for item: Dictionary in _items:
				(item["control"] as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE \
					if _arrow_mode else Control.MOUSE_FILTER_STOP
			_say_soft("Drag on the page from where the arrow starts to where it points."
				if _arrow_mode else "Drag an item to place it; drag its corner to size it.")
		"page_arrow_colour", "page_arrow_width":
			if _selected < 0 or _items[_selected]["kind"] != "arrow":
				_say_soft("Select an arrow first.")
				return
			var item: Dictionary = _items[_selected]
			var arrow: Dictionary = item["arrow"]
			var fields: Dictionary = {"index": int(item["index"])}
			if name == "page_arrow_colour":
				fields["colour"] = "black" if str(arrow.get("colour", "red")) == "red" else "red"
			else:
				var widths: Array[float] = BookletLooks.ARROW_WIDTHS
				var now: int = widths.find(BookletLooks.arrow_width(float(arrow.get("width", 0.9))))
				fields["width"] = widths[(now + 1) % widths.size()]
			var keep: String = _item_name(_selected)
			_say(_change("arrow_edit", item, fields))
			await _lay_out((item["entry"] as Booklet.Entry).number)
			var again: int = item_named(keep)
			if again >= 0:
				_select(again)
		"page_smaller", "page_larger":
			if _selected >= 0 and _items[_selected]["kind"] == "text":
				var item: Dictionary = _items[_selected]
				var size: float = float((item["note"] as Dictionary).get("size", 4.0))
				size = clampf(size * (0.8 if name == "page_smaller" else 1.25), 1.5, 40.0)
				_say(_change("note", item, {"index": int(item["index"]),
					"size": snappedf(size, 0.1)}))
				await _lay_out((item["entry"] as Booklet.Entry).number)
		"page_put_back":
			if _selected < 0:
				return
			var item: Dictionary = _items[_selected]
			if item["kind"] == "sign":
				_say(_shell.change_look("sign", item["step"]))
			elif item["kind"] == "arrow":
				_say(_change("arrow_edit", item, {"index": int(item["index"]), "remove": true}))
			elif item.has("index"):
				_say(_change("note", item, {"index": int(item["index"]),
					"remove": true}))
			else:
				_say(_change("place", item, {"item": item["kind"], "at": null}))
			_selected = -1
			await _lay_out((item["entry"] as Booklet.Entry).number)


## This page's layout on the later pages with as many steps (Shell
## .place_pages): one undo. Says what it did, and what the pages then had
## to move off something else.
func apply_to_later() -> String:
	if _at < 0 or _at >= _pages.size():
		return "no page to lay out from"
	var later: Dictionary = later_layout(_pages, _at, _plan)
	var laid: Array = later["laid"]
	var said: String = ""
	if not bool(later["placed_any"]):
		said = "Nothing on this page is placed by hand yet: drag its things where they go first."
	elif laid.is_empty():
		said = "No later page has %d step%s." % [_pages[_at].entries.size(),
			"" if _pages[_at].entries.size() == 1 else "s"]
	else:
		said = _shell.place_pages(later["placed"], "page %d's layout on %d later page%s" % [
			_pages[_at].number, laid.size(), "" if laid.size() == 1 else "s"])
		# Their pictures drawn for their old boxes are drawn again when shown.
		_shots.clear()
		var left: Array = later["left"]
		if not left.is_empty():
			said += "; %d with another number of steps left as %s (page%s %s)" % [left.size(),
				"it was" if left.size() == 1 else "they were", "" if left.size() == 1 else "s",
				", ".join(PackedStringArray(left.map(func(page: int) -> String: return str(page))))]
		var number: int = _page_steps()[0] if not _page_steps().is_empty() else -1
		await _lay_out(number)
		var moved: Array = []
		for page: Booklet.Page in _pages:
			if page.number in laid and not page.overlaps.is_empty():
				moved.append(page.number)
		if not moved.is_empty():
			said += "; on page%s %s a thing was moved off another" % [
				"" if moved.size() == 1 else "s",
				", ".join(PackedStringArray(moved.map(func(page: int) -> String: return str(page))))]
	_say(said)
	return said


## The layout of [param pages]' page [param at] for each later page of the
## same kind with as many steps (a callout's own page: the same callout's),
## its step in each place laid out as this page's step in that place is:
## what that step has placed (picture, parts list, number, callout), moved
## into the later step's room as a step's own things move with it
## (BookletLooks.rebased), and nothing else placed, so what this page
## leaves to the booklet the later page does too. A parts list or callout
## goes only where the later step has one, the list as wide as its own
## parts need and kept to its side of the page, the picture's box cut to
## what the list leaves of it ([method clear_of]). A placed picture is the
## box its model is drawn in; on a later page the model is drawn no larger than
## the booklet draws a step (ten millimetres a stud, its size and zoom
## aside), its page's steps alike, centred where this page has it: an
## early step's two bricks are not blown up to fill a box made for the
## finished model. Returns {placed: [[Instructions.Step, place, room]] for
## Shell.place_pages, laid: the pages laid out, left: the later pages of
## another number of steps, placed_any: whether this page has anything
## placed}.
static func later_layout(pages: Array[Booklet.Page], at: int,
		plan: Array[Instructions.Step]) -> Dictionary:
	var source: Booklet.Page = pages[at]
	var placed_any: bool = source.entries.any(func(entry: Booklet.Entry) -> bool:
		return not entry.place.is_empty())
	var out: Dictionary = {"placed": [], "laid": [], "left": [], "placed_any": placed_any}
	if not placed_any:
		return out
	for index: int in range(at + 1, pages.size()):
		var page: Booklet.Page = pages[index]
		if page.kind != source.kind or page.kind == "callout" and page.name != source.name:
			continue
		if page.entries.size() != source.entries.size():
			(out["left"] as Array).append(page.number)
			continue
		var places: Array = []
		# The page's steps drawn at one scale where their pictures are
		# placed, as the booklet draws a page's steps.
		var scale: float = INF
		for slot: int in page.entries.size():
			var from: Booklet.Entry = source.entries[slot]
			var to: Booklet.Entry = page.entries[slot]
			var place: Dictionary = BookletLooks.rebased({"place": from.place,
				"panel": BookletLooks.said_rect(from.panel)}, to.panel).get("place", {})
			if to.lots.is_empty():
				place.erase("parts")
			elif place.has("parts"):
				# As wide as its own parts need, wrapped no narrower than this
				# page's list or the booklet's own: a step of twenty parts in a
				# list made for two would run down the page. Kept to the side
				# it was put on, so a list at the right grows to the left.
				# Never narrower than the booklet draws one (Booklet._by_hand).
				var list: Array = place["parts"]
				var wide: float = maxf(Booklet._parts_size(to.lots, maxf(float(list[2]),
					Booklet._parts_width(to, to.panel))).x, 12.0)
				var x: float = float(list[0])
				if x + float(list[2]) * 0.5 > Booklet.PAGE.x * 0.5:
					x += float(list[2]) - wide
				place["parts"] = [snappedf(x, 0.1), list[1], snappedf(wide, 0.1)]
			if to.callout == null or not to.callout.inline:
				place.erase("callout")
			if place.has("picture"):
				var size: Vector2 = to.subject.size.max(Vector2.ONE)
				# A list grown for a step of many parts runs into the box: the
				# model goes in what the list leaves of it.
				var box: Rect2 = clear_of(BookletLooks.rect_of(place["picture"]),
					list_rect(to, place), size)
				place["picture"] = BookletLooks.said_rect(box)
				var fits: float = minf(box.size.x * 0.94 / size.x, box.size.y * 0.94 / size.y)
				scale = minf(scale, minf(fits, Booklet._most(to) * Booklet._grown(to))
					/ Booklet._grown(to))
			places.append(place)
		for slot: int in page.entries.size():
			var to: Booklet.Entry = page.entries[slot]
			var place: Dictionary = places[slot]
			if place.has("picture"):
				var centre: Vector2 = BookletLooks.rect_of(place["picture"]).get_center()
				var need: Vector2 = to.subject.size.max(Vector2.ONE) * scale * Booklet._grown(to) / 0.94
				place["picture"] = BookletLooks.said_rect(Rect2(centre - need * 0.5, need))
			var step_index: int = int(to.get_meta("step", -1))
			if step_index < 0 or step_index >= plan.size():
				continue
			(out["placed"] as Array).append([plan[step_index], place,
				BookletLooks.said_rect(to.panel)])
		(out["laid"] as Array).append(page.number)
	return out


## The parts list [param place] puts [param entry]'s parts in, with its
## number under it when the number is not placed on its own; an empty
## rect where it places none.
static func list_rect(entry: Booklet.Entry, place: Dictionary) -> Rect2:
	if not place.has("parts") or entry.lots.is_empty():
		return Rect2()
	var at: Rect2 = BookletLooks.rect_of(place["parts"])
	var size: Vector2 = Booklet._parts_size(entry.lots, maxf(at.size.x, 12.0))
	size.x = maxf(size.x, at.size.x)
	if not place.has("number"):
		size.y += entry.number_size + 1.6
	return Rect2(at.position, size)


## Room between a step's parts list and its picture, in mm.
const LIST_GAP := 2.0

## What [param list] leaves of [param box], LIST_GAP clear of it: the side of
## it above, below, left or right of the list a model of [param size] is
## drawn largest in. The box itself where the list is not on it, or covers
## all of it.
static func clear_of(box: Rect2, list: Rect2, size: Vector2) -> Rect2:
	var cover: Rect2 = list.grow(LIST_GAP)
	if list.size.x <= 0.0 or not box.intersects(cover):
		return box
	var best := Rect2()
	var most: float = 0.0
	for side: Rect2 in [Rect2(box.position.x, cover.end.y, box.size.x, box.end.y - cover.end.y),
			Rect2(box.position, Vector2(box.size.x, cover.position.y - box.position.y)),
			Rect2(box.position, Vector2(cover.position.x - box.position.x, box.size.y)),
			Rect2(cover.end.x, box.position.y, box.end.x - cover.end.x, box.size.y)]:
		var fits: float = minf(side.size.x / size.x, side.size.y / size.y)
		if side.size.x > 0.0 and side.size.y > 0.0 and fits > most:
			best = side
			most = fits
	return best if most > 0.0 else box


## The page's first step: where words and a picture added to the page go.
func _first() -> Dictionary:
	for item: Dictionary in _items:
		if item["kind"] == "picture":
			return item
	return {}


## Words of the designer's on the page shown, at [param rect]: one undo.
func add_text(words: String, rect: Rect2, size: float = 4.0) -> String:
	var first: Dictionary = _first()
	if first.is_empty():
		return "no page to put words on"
	var said: String = _change("text", first, {"text": words,
		"at": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "size": size})
	_say(said)
	await _lay_out((first["entry"] as Booklet.Entry).number)
	# The new words selected, to type over.
	for at: int in range(_items.size() - 1, -1, -1):
		if _items[at]["kind"] == "text":
			_select(at)
			_words.grab_focus()
			_words.select_all()
			break
	return said


## A picture of the designer's on the page shown, no wider than 60 mm,
## kept small enough for the file: one undo.
func add_image(image: Image) -> String:
	var first: Dictionary = _first()
	if first.is_empty() or image == null or image.get_width() < 1:
		return "no page to put a picture on"
	var longest: int = maxi(image.get_width(), image.get_height())
	if longest > 900:
		var k: float = 900.0 / float(longest)
		image.resize(maxi(1, roundi(image.get_width() * k)), maxi(1, roundi(image.get_height() * k)),
			Image.INTERPOLATE_LANCZOS)
	var clear: bool = image.detect_alpha() != Image.ALPHA_NONE
	var bytes: PackedByteArray = image.save_png_to_buffer() if clear \
		else image.save_jpg_to_buffer(0.86)
	var wide: float = 60.0
	var high: float = wide * float(image.get_height()) / float(image.get_width())
	if high > 80.0:
		wide *= 80.0 / high
		high = 80.0
	var said: String = _change("image", first, {
		"data": Marshalls.raw_to_base64(bytes), "kind": "png" if clear else "jpg",
		"at": [Booklet.PAGE.x - Booklet.MARGIN - wide, Booklet.content().end.y - high, wide, high]})
	_say(said)
	_pictures.clear()
	await _lay_out((first["entry"] as Booklet.Entry).number)
	return said


func _reword() -> void:
	if _selected < 0 or _selected >= _items.size() or _items[_selected]["kind"] != "text":
		return
	var item: Dictionary = _items[_selected]
	var words: String = _words.text.strip_edges()
	if words.is_empty() or words == str((item["note"] as Dictionary).get("text", "")):
		return
	_say(_change("note", item, {"index": int(item["index"]), "text": words}))
	_lay_out((item["entry"] as Booklet.Entry).number)


func _say(words: String) -> void:
	_said.text = words
	if _shell != null and _shell.bar != null:
		_shell.bar.say(words)


func _say_soft(words: String) -> void:
	_said.text = words


# -- for the page and a check ---------------------------------------------------------


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = _named.duplicate()
	for at: int in _items.size():
		out[_item_name(at)] = _items[at]["control"]
	if _handle.visible:
		out["page_resize"] = _handle
	if _knob.visible:
		out["page_turn_knob"] = _knob
	for which: String in _ends:
		if (_ends[which] as Control).visible:
			out["page_arrow_" + which] = _ends[which]
	return out


## What the page shows: its number, steps and each item's place in mm.
func page_state() -> Dictionary:
	if not visible:
		return {}
	var items: Dictionary = {}
	for at: int in _items.size():
		var rect: Rect2 = _items[at]["rect"]
		items[_item_name(at)] = [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1),
			snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)]
	return {"page": _pages[_at].number if _at >= 0 and _at < _pages.size() else 0,
		"steps": _page_steps(), "items": items, "laying": _laying,
		"selected": _item_name(_selected) if _selected >= 0 else "",
		"guides": _guides.size(),
		# What was on top of something else, by name (true: moved off it),
		# and the page's words for it.
		"overlaps": _overlapped.duplicate(), "said": _said.text,
		# The arrows on it, by name: [x1, y1, x2, y2 (, bx, by ...)], colour, width.
		"arrows": _arrows_state(), "arrow_mode": _arrow_mode,
		# Its words and pictures of the designer's, by name: turn (degrees)
		# and opacity (0 to 1); and the booklet's guides, {x: [mm], y: [mm]}.
		"notes": _notes_state(), "ruler_guides": _guide_lines.duplicate(true),
		# The page's steps whose pictures are drawn on it so far.
		"drawn": _page_steps().filter(func(number: int) -> bool:
			return _shots.has(_shot_key(_pages[_at].number if _at >= 0 and _at < _pages.size() else 0, number))),
		"kind": _pages[_at].kind if _at >= 0 and _at < _pages.size() else ""}


func _arrows_state() -> Dictionary:
	var out: Dictionary = {}
	for at: int in _items.size():
		if _items[at]["kind"] != "arrow":
			continue
		var arrow: Dictionary = _items[at]["arrow"]
		out[_item_name(at)] = {"at": arrow.get("at", []), "colour": arrow.get("colour", "red"),
			"width": arrow.get("width", 0.9)}
	return out


func _notes_state() -> Dictionary:
	var out: Dictionary = {}
	for at: int in _items.size():
		if _items[at]["kind"] in ["text", "image"]:
			out[_item_name(at)] = {"turn": float(_items[at].get("turn", 0.0)),
				"opacity": float(_items[at].get("opacity", 1.0))}
	return out


## Item [param name]'s index, -1 when the page has none.
func item_named(name: String) -> int:
	for at: int in _items.size():
		if _item_name(at) == name:
			return at
	return -1


## The page shown, or [param page] of the booklet's pages of steps.
func show_page_numbered(page: int) -> void:
	for index: int in _pages.size():
		if _pages[index].number == page:
			_at = index
			_show_page()
			return
