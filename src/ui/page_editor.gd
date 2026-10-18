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
## The page shows its boxes at once and the steps' pictures and parts a few
## seconds later, drawn as Instructions draws them (BookletMaker.draw_steps,
## the page's steps alone); a picture is stretched with its box while it is
## dragged and drawn again once it is let go.
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
## The page's steps drawn (BookletMaker.draw_steps): number -> {"picture":
## Texture2D, "cells": [[Texture2D, Rect2 within the callout box]]}; and
## each part's picture by its lot's key. The drawing under way, to cancel
## when the page changes before it is done.
var _shots: Dictionary = {}
var _part_shots: Dictionary = {}
var _drawing: Working.Job = null

var _canvas: Control
var _handle: Control
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
			["page_smaller", "Words smaller", "The selected words smaller"],
			["page_larger", "Words larger", "The selected words larger"],
			["page_put_back", "Put back", "The selected item where the booklet lays it out; "
				+ "words or a picture of your own taken off"],
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
	_handle = Control.new()
	_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_handle.size = Vector2(16, 16)
	_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_handle.gui_input.connect(_on_handle_input)
	_handle.draw.connect(_draw_handle)
	_handle.visible = false
	_canvas.add_child(_handle)
	_picker = PickImage.new()
	add_child(_picker)
	_picker.picked.connect(add_image)
	_picker.failed.connect(func(why: String) -> void: _say(why))


func is_open() -> bool:
	return visible


## Up, on the page the timeline's step is on.
func open() -> void:
	_world = app.get("_world")
	_shell = app.get("_shell")
	_shots.clear()
	_part_shots.clear()
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
	_items.clear()
	_clear_controls()


func _process(_delta: float) -> void:
	if not visible or _laying:
		return
	var builder: Builder = app.get("_builder")
	var now: Array = [builder._history.size(), builder._redo.size()]
	if now != _seen_history and _drag.is_empty():
		# Undone, redone, or changed from the timeline: shown as it is now.
		var number: int = _page_steps()[0] if not _page_steps().is_empty() else -1
		_lay_out(number)


## Escape closes the page, Delete takes the selected item back. Before the
## window's own keys, whose Delete would take the model's selected parts off
## behind the page.
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or _words.has_focus():
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
	_pages = []
	for page: Booklet.Page in pages:
		if page.kind == "steps":
			_pages.append(page)
	_at = 0
	for index: int in _pages.size():
		for entry: Booklet.Entry in _pages[index].entries:
			if entry.number == number:
				_at = index
	var builder: Builder = app.get("_builder")
	_seen_history = [builder._history.size(), builder._redo.size()]
	_laying = false
	_show_page()


## The steps on the page shown, by number.
func _page_steps() -> Array:
	if _at < 0 or _at >= _pages.size():
		return []
	return _pages[_at].entries.map(func(entry: Booklet.Entry) -> int: return entry.number)


func _show_page() -> void:
	var keep: String = _item_name(_selected) if _selected >= 0 else ""
	_items.clear()
	_selected = -1
	_clear_controls()
	if _pages.is_empty():
		_title.text = "No pages of steps"
		_canvas.queue_redraw()
		return
	var page: Booklet.Page = _pages[_at]
	var numbers := PackedStringArray()
	for number: int in _page_steps():
		numbers.append(str(number))
	_title.text = "Page %d (step%s %s)" % [page.number, "" if numbers.size() == 1 else "s",
		", ".join(numbers)]
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
		for at: int in entry.notes.size():
			var note: Dictionary = entry.notes[at]
			var item: Dictionary = _add_item("text" if note.has("text") else "image",
				BookletLooks.rect_of(note.get("at", [])), entry, step)
			item["index"] = at
			item["note"] = note
	for at: int in _items.size():
		if _item_name(at) == keep:
			_select(at)
	if _selected < 0:
		# What was selected is gone (undone, or put back): nothing to type into.
		if _words.has_focus():
			_words.release_focus()
		_select(-1)
	_fit()
	_say_soft("Drag an item to place it; drag its corner to size it. It snaps to the margins and to the other items.")
	_draw_pictures()


## The page's steps drawn as Instructions draws them, in the background;
## the page shows them when they are done. Not headless, where nothing is
## drawn and each picture would be waited for in vain.
func _draw_pictures() -> void:
	if _drawing != null:
		_drawing.cancelled = true
	_drawing = null
	var numbers: Dictionary = {}
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
	maker.queue_free()
	if job.cancelled or not visible or document == null:
		return
	_drawing = null
	for page: Booklet.Page in pages:
		for entry: Booklet.Entry in page.entries:
			if not numbers.has(entry.number) or entry.image.is_empty():
				continue
			var cells: Array = []
			if entry.callout != null and entry.callout.inline:
				for index: int in mini(entry.callout.images.size(), entry.callout.cells.size()):
					var cell: Rect2 = entry.callout.cells[index]
					cells.append([_texture(entry.callout.images[index]),
						Rect2(cell.position - entry.callout.box.position, cell.size)])
			_shots[entry.number] = {"picture": _texture(entry.image), "cells": cells}
	for key: String in document.parts:
		if not _part_shots.has(key):
			_part_shots[key] = _texture(str(document.parts[key]))
	_canvas.queue_redraw()


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
	# Words and pictures of the designer's over the step's own items.
	if kind in ["text", "image"]:
		control.z_index = 1
	_canvas.move_child(_handle, -1)
	return item


func _clear_controls() -> void:
	for child: Node in _canvas.get_children():
		if child != _handle:
			child.queue_free()
			_canvas.remove_child(child)
	_handle.visible = false


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
	var room: Vector2 = holder.size
	var k: float = minf(room.x / Booklet.PAGE.x, room.y / Booklet.PAGE.y)
	_canvas.size = Booklet.PAGE * k
	_canvas.position = (room - _canvas.size) * 0.5
	_place_controls()
	_canvas.queue_redraw()


func _place_controls() -> void:
	var k: float = _scale()
	for item: Dictionary in _items:
		var control: Control = item["control"]
		var rect: Rect2 = item["rect"]
		control.position = rect.position * k
		control.size = rect.size * k
	if _selected >= 0 and _selected < _items.size():
		var rect: Rect2 = _items[_selected]["rect"]
		_handle.position = rect.end * k - _handle.size * 0.5
		_handle.visible = _items[_selected]["kind"] != "number"
	else:
		_handle.visible = false


func _draw_page() -> void:
	var k: float = _scale()
	var font: Font = ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), PAGE_COLOUR)
	var area: Rect2 = Booklet.content()
	_canvas.draw_rect(Rect2(area.position * k, area.size * k), Color(0.24, 0.43, 0.59, 0.35),
		false, 1.0)
	if _at >= 0 and _at < _pages.size():
		var page: Booklet.Page = _pages[_at]
		if not page.banner.is_empty():
			_canvas.draw_rect(Rect2(Vector2(Booklet.MARGIN, Booklet.MARGIN) * k,
				Vector2(area.size.x, Booklet.BANNER - 3.0) * k), Color8(35, 82, 124))
		_canvas.draw_string(font, Vector2(Booklet.PAGE.x - Booklet.MARGIN - 8.0,
			Booklet.PAGE.y - 5.0) * k, str(page.number), HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(3.6 * k), INK)
	for at: int in _items.size():
		_draw_item(_items[at], k, font)
	if _selected >= 0 and _selected < _items.size():
		var rect: Rect2 = _items[_selected]["rect"]
		_canvas.draw_rect(Rect2(rect.position * k, rect.size * k), PICK, false, 2.0)
	for guide: Array in _guides:
		var mm: float = float(guide[1]) * k
		if str(guide[0]) == "x":
			_canvas.draw_line(Vector2(mm, 0), Vector2(mm, _canvas.size.y), GUIDE, 1.0)
		else:
			_canvas.draw_line(Vector2(0, mm), Vector2(_canvas.size.x, mm), GUIDE, 1.0)


func _draw_item(item: Dictionary, k: float, font: Font) -> void:
	var rect := Rect2((item["rect"] as Rect2).position * k, (item["rect"] as Rect2).size * k)
	var entry: Booklet.Entry = item["entry"]
	match str(item["kind"]):
		"picture":
			var drawn: Texture2D = (_shots.get(entry.number, {}) as Dictionary).get("picture")
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
			for cell: Array in (_shots.get(entry.number, {}) as Dictionary).get("cells", []):
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
		"text":
			var note: Dictionary = item["note"]
			var size: int = int(maxf(6.0, float(note.get("size", 4.0)) * k))
			_canvas.draw_multiline_string(font, rect.position + Vector2(0, size * 0.85),
				str(note.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, -1, INK)
			_dashed(rect, Color(0.3, 0.3, 0.3, 0.35))
		"image":
			var texture: Texture2D = _picture(str((item["note"] as Dictionary).get("image", "")))
			if texture != null:
				_canvas.draw_texture_rect(texture, rect, false)
			else:
				_canvas.draw_rect(rect, Color(0.5, 0.5, 0.5, 0.3))


func _draw_handle() -> void:
	_handle.draw_rect(Rect2(Vector2.ZERO, _handle.size), PICK)
	_handle.draw_rect(Rect2(Vector2(3, 3), _handle.size - Vector2(6, 6)), Color.WHITE)


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
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_select(-1)


func _on_item_input(at: int, event: InputEvent) -> void:
	if at >= _items.size():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button: InputEventMouseButton = event
		if button.pressed:
			_select(at)
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


func _select(at: int) -> void:
	_selected = at
	var note: bool = at >= 0 and _items[at]["kind"] == "text"
	_words.editable = note
	_words.text = str((_items[at]["note"] as Dictionary).get("text", "")) if note else ""
	if at >= 0:
		_say_soft("%s: drag to place it, its corner to size it%s." % [_item_name(at).trim_prefix("page_"),
			", type its words above" if note else ""])
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
	var moved: Rect2 = Rect2(was.position + (Vector2.ZERO if resize else by),
		was.size + (by if resize else Vector2.ZERO))
	moved.size = moved.size.max(Vector2(6, 4))
	var others: Array = []
	for at: int in _items.size():
		if at != _selected:
			others.append(_items[at]["rect"])
	var snapped: Dictionary = Booklet.snapped_to(moved, others, resize)
	item["rect"] = snapped["rect"]
	_guides = snapped["lines"]
	_place_controls()
	_canvas.queue_redraw()


## The item dropped where it is: one undo.
func _drop() -> void:
	var item: Dictionary = _items[_selected]
	var was: Rect2 = _drag["rect"]
	_drag = {}
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
	var step: Instructions.Step = item["step"]
	var said: String = ""
	var numbers: Array = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if item.has("index"):
		said = _shell.change_look("note", step, {"index": int(item["index"]), "at": numbers})
	else:
		said = _shell.change_look("place", step, {"item": item["kind"],
			"at": numbers.slice(0, int(BookletLooks.ITEMS[item["kind"]]))})
	_say(said)
	await _lay_out((item["entry"] as Booklet.Entry).number)
	return said


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
		"page_smaller", "page_larger":
			if _selected >= 0 and _items[_selected]["kind"] == "text":
				var item: Dictionary = _items[_selected]
				var size: float = float((item["note"] as Dictionary).get("size", 4.0))
				size = clampf(size * (0.8 if name == "page_smaller" else 1.25), 1.5, 40.0)
				_say(_shell.change_look("note", item["step"], {"index": int(item["index"]),
					"size": snappedf(size, 0.1)}))
				await _lay_out((item["entry"] as Booklet.Entry).number)
		"page_put_back":
			if _selected < 0:
				return
			var item: Dictionary = _items[_selected]
			if item.has("index"):
				_say(_shell.change_look("note", item["step"], {"index": int(item["index"]),
					"remove": true}))
			else:
				_say(_shell.change_look("place", item["step"], {"item": item["kind"], "at": null}))
			_selected = -1
			await _lay_out((item["entry"] as Booklet.Entry).number)


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
	var said: String = _shell.change_look("text", first["step"], {"text": words,
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
	var said: String = _shell.change_look("image", first["step"], {
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
	_say(_shell.change_look("note", item["step"], {"index": int(item["index"]), "text": words}))
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
		# The page's steps whose pictures are drawn on it so far.
		"drawn": _page_steps().filter(func(number: int) -> bool: return _shots.has(number))}


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
