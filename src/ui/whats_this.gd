## Help, What's This? (Shift+F1): the next click on any control says what it
## does, in a bubble beside it, and does nothing else. LeoCAD's continuous
## build has it, as Qt and Windows always have (APP_UX4 gap 11); F1 stays the
## keys sheet, as there.
##
## A sheet over the whole window takes that click, so no button, field, chip
## or view under it hears it, nor the release after it. The control under the
## pointer is found as the window finds it ([method control_at]), outlined
## while the pointer is over it, and its words are what it already says to a
## person: its tooltip where the pointer is (a row of a list has its own),
## what a screen reader is told of it, or the nearest control round it that
## says anything. To that, what the tooltip cannot know: whether it is on
## now, and why it is greyed when it is (Shell.why_not). The bin's chips,
## whose tooltip is their name, say what a click on one shows. Over the model,
## what the tool in use does there.
##
## Esc, a right click or Shift+F1 again leaves without asking. The bubble goes
## at the next click or key, which then does what it always does.
class_name WhatsThis
extends CanvasLayer

## Over every panel, under the pointer's own sheet (Cursors, 120).
const LAYER := 119
## The bubble's widest, in the window's units.
const WIDEST := 360.0
const EDGE := 8.0

## What the status bar says while the next click is a question.
const ASKING := "What's This: click any button, field or panel to hear what it does · Esc to stop"
## A side panel's strip, whose tooltip is only what a click does to it.
const RAIL_OPEN := "Folds the panel to this strip at its edge, giving the model its room; a click on the strip brings it back"
const RAIL_FOLDED := "Opens the panel this strip stands for; one sharing its edge folds to its own strip"
## A side panel where nothing round the pointer says anything.
const PANEL := "A panel of the window: click a control in it to hear what that does. The strip at its edge folds it away and brings it back"
const NAMED_ONLY := "In the %s panel; it says nothing of itself but its name"

## The one, made at the first ask.
static var one: WhatsThis = null

var shell: Shell
## Whether the next click is a question.
var asking: bool = false
## What the last answer said, title and words on lines of their own, and
## the control it was about (null over the model): for a check to read.
var said: String = ""
var said_of: Control = null

var _sheet: Sheet
var _bubble: PanelContainer
var _title: Label
var _body: Label


## Help, What's This?: the next click a question, or, asked again while it
## is, not.
static func ask(from: Shell) -> void:
	if one == null or not is_instance_valid(one):
		one = WhatsThis.new()
		one.name = "WhatsThis"
		one.shell = from
		from.app.add_child(one)
	if one.asking:
		one.stop()
	else:
		one.start()


## Whether the next click is a question: for the status bar.
static func is_asking() -> bool:
	return one != null and is_instance_valid(one) and one.asking


func _ready() -> void:
	layer = LAYER
	_sheet = Sheet.new()
	_sheet.asker = self
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.visible = false
	add_child(_sheet)
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	var face := StyleBoxFlat.new()
	face.bg_color = Look.FACE
	face.border_color = Look.ACCENT
	face.set_border_width_all(1)
	face.set_corner_radius_all(6)
	face.content_margin_left = 12
	face.content_margin_right = 12
	face.content_margin_top = 8
	face.content_margin_bottom = 10
	face.shadow_color = Color(0, 0, 0, 0.45)
	face.shadow_size = 8
	_bubble.add_theme_stylebox_override("panel", face)
	add_child(_bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Look.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 12)
	_body.add_theme_color_override("font_color", Look.ROW_WORDS)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Read out as it is said, by a screen reader that is running.
	_body.accessibility_live = AccessibilityServer.LIVE_POLITE
	column.add_child(_body)


func start() -> void:
	_put_away()
	asking = true
	_sheet.over = null
	_sheet.visible = true
	_sheet.queue_redraw()


func stop() -> void:
	asking = false
	_sheet.visible = false
	_sheet.over = null


## Ahead of the window: Esc leaves the question, and the bubble goes at the
## next click or key, which then does what it always does.
func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	var pressed: bool = (event is InputEventMouseButton or event is InputEventKey) \
		and event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	if key != null and key.keycode == KEY_ESCAPE and (asking or _bubble.visible):
		stop()
		_put_away()
		get_viewport().set_input_as_handled()
		return
	if _bubble.visible and not asking:
		_put_away()


func _put_away() -> void:
	_bubble.visible = false


## The click that is the question: the control there, its words in the
## bubble beside it, and nothing else done.
func answer(point: Vector2) -> void:
	stop()
	var hit: Control = control_at(point)
	var found: Array = words_at(hit, point)
	var title: String = str(found[0])
	var words: String = str(found[1])
	said_of = found[2]
	said = title if words.is_empty() else (words if title.is_empty() else title + "\n" + words)
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = words
	_body.visible = not words.is_empty()
	var about: Rect2 = _rect_of(said_of) if said_of != null else Rect2(point, Vector2.ONE)
	_show_by(about)


func _show_by(about: Rect2) -> void:
	var room: Rect2 = get_viewport().get_visible_rect()
	var wide: float = minf(WIDEST, room.size.x - EDGE * 2.0)
	for label: Label in [_title, _body]:
		label.custom_minimum_size.x = 0.0
	_bubble.visible = true
	_bubble.reset_size()
	# As wide as its longest line, up to WIDEST: then lines that wide.
	var font_size: int = _body.get_theme_font_size("font_size")
	var longest: float = 0.0
	for label: Label in [_title, _body]:
		if not label.visible:
			continue
		var font: Font = label.get_theme_font("font")
		for line: String in label.atr(label.text).split("\n"):
			longest = maxf(longest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1,
				label.get_theme_font_size("font_size") if label == _title else font_size).x)
	var inner: float = minf(longest + 1.0, wide - 24.0)
	# A wrapping label's height is of the width it last had, which for the
	# first answer was none, a word a line: the window's height. Given the
	# width now, its height is that width's before the bubble is sized.
	for label: Label in [_title, _body]:
		label.custom_minimum_size.x = inner
		label.size = Vector2(inner, label.size.y)
		label.update_minimum_size()
	_bubble.reset_size()
	var size: Vector2 = _bubble.get_combined_minimum_size()
	_bubble.size = size
	# Below the control, or above it where there is no room below.
	var at := Vector2(about.position.x, about.end.y + 6.0)
	if at.y + size.y > room.end.y - EDGE:
		at.y = about.position.y - size.y - 6.0
	at.x = clampf(at.x, room.position.x + EDGE, maxf(room.position.x + EDGE, room.end.x - size.x - EDGE))
	at.y = clampf(at.y, room.position.y + EDGE, maxf(room.position.y + EDGE, room.end.y - size.y - EDGE))
	_bubble.position = at


## Whether the bubble is up: for a check to read.
func answering() -> bool:
	return _bubble.visible


func bubble_rect() -> Rect2:
	return Rect2(_bubble.position, _bubble.size)


# -- what is there ---------------------------------------------------------------


## The control a click at [param point] (the window's units) reaches, as the
## window finds it: the last drawn first, by canvas layer and then by the
## tree, into a control only where it does not clip its children away, past
## what lets the pointer through; null where it reaches the model. The
## window's own hover is a move late, and none at all for a click with no
## move before it, as a finger's or a browser test's.
func control_at(point: Vector2) -> Control:
	var roots: Array = []
	_roots_in(get_tree().root, roots)
	# Drawn in order of layer, then of the tree: the last drawn is on top.
	var order: Array = range(roots.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var la: int = int(roots[a][0])
		var lb: int = int(roots[b][0])
		return la < lb if la != lb else a < b)
	for n: int in range(order.size() - 1, -1, -1):
		var found: Control = _found_in(roots[order[n]][1], point)
		if found != null:
			return found
	return null


## [layer, control] for each control the window picks from first: one whose
## parent is no canvas item, or one drawn as its own top.
func _roots_in(node: Node, out: Array) -> void:
	if node == self:
		return
	if node is Window and node != get_tree().root:
		return
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	if node is Control:
		var control: Control = node
		if not (control.get_parent() is CanvasItem) or control.top_level:
			var layer_node: CanvasLayer = control.get_canvas_layer_node()
			out.append([layer_node.layer if layer_node != null else 0, control])
	for child: Node in node.get_children():
		_roots_in(child, out)


func _found_in(item: CanvasItem, point: Vector2) -> Control:
	if not item.visible:
		return null
	var control: Control = item as Control
	var local: Vector2 = item.get_global_transform_with_canvas().affine_inverse() * point
	if control == null or not control.clip_contents or _has(control, local):
		for n: int in range(item.get_child_count() - 1, -1, -1):
			var child: CanvasItem = item.get_child(n) as CanvasItem
			if child == null or child.top_level:
				continue
			var found: Control = _found_in(child, point)
			if found != null:
				return found
	if control == null or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return null
	return control if _has(control, local) else null


## Whether [param local] is in [param control], as the window asks it: its
## own answer where its script gives one (_has_point), else its rectangle.
static func _has(control: Control, local: Vector2) -> bool:
	if control.has_method(&"_has_point"):
		return bool(control.call(&"_has_point", local))
	return Rect2(Vector2.ZERO, control.size).has_point(local)


## [title, what it does, the control that says it] for a click at
## [param point] on [param hit]: its own words or the nearest round it with
## any; over the model, what the tool in use does there.
func words_at(hit: Control, point: Vector2) -> Array:
	var source: Control = hit
	var tip: String = ""
	while source != null:
		tip = _own_words(source, point)
		if not tip.is_empty():
			break
		source = source.get_parent() as Control
	if source == null:
		return _no_words(hit)
	var lines: PackedStringArray = tip.strip_edges().split("\n")
	var title: String = _name_of(source)
	var words: String = tip.strip_edges()
	# A tooltip that begins with the control's name ("Undo   Ctrl+Z"): its
	# first line is the title.
	if lines.size() > 1 and (title.is_empty() or lines[0].begins_with(title)
			or title.begins_with(lines[0].get_slice("   ", 0))):
		title = lines[0].strip_edges()
		words = "\n".join(lines.slice(1)).strip_edges()
	elif not title.is_empty() and (title == words or words.begins_with(title + "   ")):
		# Its name again, and its key: no more than the name says.
		title = words
		words = ""
	var rail: String = _rail(source)
	if not rail.is_empty():
		title = tip.strip_edges()
		words = rail
	words = _chip(source, title, words)
	var now: String = _state_of(source)
	if not now.is_empty():
		words = (words + "\n" + now) if not words.is_empty() else now
	return [title, words, source]


## What [param control] says of itself, where the pointer is.
func _own_words(control: Control, point: Vector2) -> String:
	var own: String = str(control.get_meta(&"whats_this", ""))
	if not own.is_empty():
		return own
	var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * point
	var tip: String = control.get_tooltip(local).strip_edges()
	if not tip.is_empty():
		return tip
	return control.accessibility_description.strip_edges()


## A control's name as a person reads it on screen: a button's words, or
## what a screen reader calls it.
func _name_of(control: Control) -> String:
	if not control.accessibility_name.strip_edges().is_empty():
		return control.accessibility_name.strip_edges()
	if control is Button and not (control is OptionButton) \
			and not (control as Button).text.strip_edges().is_empty():
		return (control as Button).text.strip_edges()
	if control is LinkButton and not (control as LinkButton).text.strip_edges().is_empty():
		return (control as LinkButton).text.strip_edges()
	return ""


## A side panel's strip, whose tooltip says only "Hide the parts bin": what
## that does to the window.
func _rail(control: Control) -> String:
	var node: Node = control
	while node != null and not (node is SideDock):
		node = node.get_parent()
	if node == null:
		return ""
	var docks: Array = [node]
	docks.append_array(node.get("_edge_mates") as Array)
	for dock: SideDock in docks:
		if dock.rail() == control:
			return RAIL_OPEN if dock.is_open() else RAIL_FOLDED
	return ""


## The parts bin's chips say their category alone: what a click on one shows.
func _chip(control: Control, title: String, words: String) -> String:
	if not control.has_meta(&"category") or control.has_meta(&"shelf"):
		return words
	var category: String = str(control.get_meta(&"category"))
	if words != category and not words.is_empty():
		return words
	if category == "All":
		return "Parts of every kind in the bin, not one kind alone; with a search typed, all it finds"
	return "Only the %s parts in the bin: %d of them" % [category, int(control.get_meta(&"count", 0))]


## Whether a switch is on, and why a greyed one is greyed.
func _state_of(control: Control) -> String:
	var button: BaseButton = control as BaseButton
	if button == null:
		return ""
	if button.disabled:
		var why: String = shell.why_not(_command_of(button)) if shell != null else ""
		return "Greyed now: %s" % why if not why.is_empty() and why != "No such command" \
			else "Greyed now"
	if not button.toggle_mode:
		return ""
	if button.button_group != null:
		return "In use now" if button.button_pressed else ""
	return "On now" if button.button_pressed else "Off now"


## The command a toolbar button runs, or "".
func _command_of(control: Control) -> String:
	if shell == null or shell.toolbar == null:
		return ""
	var named: Dictionary = shell.toolbar.controls_by_name()
	for key: String in named:
		if named[key] == control:
			return key.trim_prefix("tool_")
	return ""


## Where nothing round the pointer says anything: in a side panel, the
## control's name and the panel it is in, or the panel; else the model, and
## what the tool in use does with a click there.
func _no_words(hit: Control) -> Array:
	var node: Node = hit
	var its_name: String = ""
	while node != null:
		if node is SideDock:
			var dock: SideDock = node
			if not its_name.is_empty():
				return [its_name, NAMED_ONLY % dock.title, dock]
			return [dock.title, PANEL, dock]
		if its_name.is_empty() and node is Control:
			its_name = _name_of(node)
		node = node.get_parent()
	var named: Dictionary = shell.toolbar.controls_by_name() if shell.toolbar != null else {}
	var button: Control = named.get("tool_mode_" + shell.verbs.mode)
	var says: String = button.tooltip_text.strip_edges() if button != null else ""
	return ["The model", "A click here does what the tool in use does:\n" + says, null]


## In the window's units, wherever it is.
static func _rect_of(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


## The sheet over the window while the next click is a question: it takes
## the click, outlines what the pointer is over, and marks the pointer with
## a question.
class Sheet extends Control:
	var asker: WhatsThis
	var over: Control = null
	var _point: Vector2 = Vector2(-1, -1)

	func _gui_input(event: InputEvent) -> void:
		var pointer: InputEventMouse = event as InputEventMouse
		if pointer == null:
			return
		accept_event()
		var at: Vector2 = get_global_transform_with_canvas() * pointer.position
		_point = at
		var press: InputEventMouseButton = event as InputEventMouseButton
		if press == null:
			var found: Array = asker.words_at(asker.control_at(at), at)
			over = found[2]
			queue_redraw()
			return
		if not press.pressed:
			return
		if press.button_index == MOUSE_BUTTON_LEFT:
			asker.answer(at)
		elif press.button_index == MOUSE_BUTTON_RIGHT:
			asker.stop()

	func _draw() -> void:
		if over != null and is_instance_valid(over) and over.is_visible_in_tree():
			var rect: Rect2 = get_global_transform_with_canvas().affine_inverse() \
				* WhatsThis._rect_of(over)
			draw_rect(rect.grow(2.0), Look.ACCENT, false, 2.0)
		if _point.x >= 0.0:
			# A question mark beside the pointer, as the system's own help
			# pointer has: the app's pictures hang on that shape (Cursors).
			var spot: Vector2 = get_global_transform_with_canvas().affine_inverse() * _point \
				+ Vector2(16, 18)
			draw_circle(spot, 9.0, Look.STRONG)
			var font: Font = get_theme_default_font()
			draw_string(font, spot + Vector2(-3.5, 5.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color.WHITE)
