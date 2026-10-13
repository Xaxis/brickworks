## The left-hand column: the parts bin, and under it the model tree, the
## properties of what is selected and the colours — everything for building
## by hand in one column, as Studio keeps its palettes down the left with
## the colours at the foot, and the model's structure over the selection's
## properties as Blender stacks its outliner over its properties. The
## assistant has the right-hand column to itself.
##
## The tree and the properties floated over the model's top corners, where
## a click meant for a part landed on a panel, and in a window 1100 across
## they left no room to build. Docked here, the model has the middle.
##
## The tree and the properties fold to their header (a click on its name),
## and the properties fold themselves while nothing is selected. The bar
## between two sections drags the height of the one that is not the bin;
## the bin has whatever is left, so its parts grid takes the room. The
## colours are as tall as the column says (PartsBin._fit_palette), never
## as anything else does. The heights are remembered (ShellPrefs), as the
## folds are.
class_name PanelStack
extends Container

## The bar between two sections: tall enough to find with a pointer.
const BAR := 7.0

## Top to bottom.
var _sections: Array[Control] = []
## section -> the ShellPrefs name its open height is kept under. The one
## section kept under no name fills what is left.
var _kept_as: Dictionary = {}
## section -> its open height, as dragged.
var _wanted: Dictionary = {}
## One bar between each two sections, shown when it can be dragged.
var _bars: Array[Bar] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true


## Add a section under the others. ``kept_as`` names its height in
## ShellPrefs; the section kept under no name fills what is left.
func add_section(section: Control, kept_as: String = "") -> void:
	_sections.append(section)
	_kept_as[section] = kept_as
	if not kept_as.is_empty():
		_wanted[section] = float(ShellPrefs.value(kept_as))
	add_child(section)
	if section.has_signal("toggled"):
		section.connect("toggled", func(_open: bool) -> void: queue_sort())
	if section.has_signal("idled"):
		section.connect("idled", func(_idle: bool) -> void: queue_sort())
	_rebuild_bars()
	queue_sort()


func sections() -> Array[Control]:
	return _sections


## The backing a section of the column wears: the column's own colour,
## with a line over it to part it from the one above.
static func section_style() -> StyleBoxFlat:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.94)
	backing.border_color = Color(1, 1, 1, 0.08)
	backing.border_width_top = 1
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	backing.content_margin_top = 6
	backing.content_margin_bottom = 8
	return backing


static func _is_open(section: Control) -> bool:
	if not section.visible:
		return false
	return bool(section.call("is_open")) if section.has_method("is_open") else true


## Open with nothing to show — the properties with nothing selected — and
## so as tall as its header, the room going to the section that fills.
static func _is_idle(section: Control) -> bool:
	return section.has_method("is_idle") and bool(section.call("is_idle"))


func _rebuild_bars() -> void:
	for bar: Bar in _bars:
		bar.queue_free()
	_bars.clear()
	for n: int in _sections.size() - 1:
		var bar := Bar.new()
		bar.stack = self
		add_child(bar)
		_bars.append(bar)


## The section that fills what is left: the one kept under no name, or
## the lowest open one while that is folded.
func _filler() -> Control:
	for section: Control in _sections:
		if str(_kept_as[section]).is_empty() and _is_open(section):
			return section
	for n: int in range(_sections.size() - 1, -1, -1):
		if _is_open(_sections[n]):
			return _sections[n]
	return null


## The section the bar under section ``n`` resizes: the one on the far
## side of it from the filler, whose edge it is.
func _resized_by(n: int, filler: Control) -> Control:
	var at: int = _sections.find(filler)
	return _sections[n + 1] if at >= 0 and at <= n else _sections[n]


## Only over a section a drag can size: one kept under a name, open, and
## with something in it. A bar over the colours, whose height is the
## column's to say, would take a drag and do nothing.
func _shows_bar(n: int, filler: Control) -> bool:
	var section: Control = _resized_by(n, filler)
	return section != filler and _is_open(section) and not _is_idle(section) \
		and not str(_kept_as[section]).is_empty()


## How tall each section is, top to bottom, in the room there is.
func heights(room: float) -> Array[float]:
	var filler: Control = _filler()
	var out: Array[float] = []
	var least: Array[float] = []
	var bars: float = 0.0
	for n: int in _sections.size():
		var section: Control = _sections[n]
		var floor_of: float = section.get_combined_minimum_size().y if section.visible else 0.0
		least.append(floor_of)
		if not section.visible:
			out.append(0.0)
		elif not _is_open(section) or section == filler or _is_idle(section):
			out.append(floor_of)
		else:
			# Its own height, whatever it shows. A section that grew with
			# the selection moved everything under the parts bin, the
			# colours a click was aimed at among them: the colours are the
			# foot of the column now, under everything that changes.
			out.append(maxf(float(_wanted.get(section, floor_of)), floor_of))
		if n < _sections.size() - 1 and _shows_bar(n, filler):
			bars += BAR
	var used: float = bars
	for h: float in out:
		used += h
	# Too tall: the open sections give back what they have over their
	# least, the topmost first, so the properties keep their room longest.
	var over: float = used - room
	for n: int in _sections.size():
		if over <= 0.0:
			break
		var spare: float = out[n] - least[n]
		if spare <= 0.0 or _sections[n] == filler:
			continue
		var give: float = minf(spare, over)
		out[n] -= give
		over -= give
	if filler != null:
		var index: int = _sections.find(filler)
		var rest: float = room - bars
		for n: int in out.size():
			if n != index:
				rest -= out[n]
		out[index] = maxf(rest, least[index])
	return out


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var filler: Control = _filler()
	var tall: Array[float] = heights(size.y)
	var y: float = 0.0
	for n: int in _sections.size():
		var section: Control = _sections[n]
		if section.visible:
			fit_child_in_rect(section, Rect2(0.0, y, size.x, tall[n]))
			y += tall[n]
		if n < _bars.size():
			var bar: Bar = _bars[n]
			bar.visible = _shows_bar(n, filler)
			if bar.visible:
				bar.resizes = _resized_by(n, filler)
				bar.grows_down = bar.resizes == section
				fit_child_in_rect(bar, Rect2(0.0, y, size.x, BAR))
				y += BAR
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var wide: float = 0.0
	var tall: float = 0.0
	for section: Control in _sections:
		if not section.visible:
			continue
		var least: Vector2 = section.get_combined_minimum_size()
		wide = maxf(wide, least.x)
		tall += least.y
	return Vector2(wide, tall)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.12, 0.14, 0.94))


## Set an open section's height, as a drag of its bar does.
func set_height(section: Control, height: float) -> void:
	if str(_kept_as.get(section, "")).is_empty():
		return
	var least: float = section.get_combined_minimum_size().y
	_wanted[section] = clampf(height, least, maxf(least, size.y - BAR))
	queue_sort()


## The drag has ended: keep the heights for next time.
func keep_heights() -> void:
	for section: Control in _sections:
		var name: String = str(_kept_as.get(section, ""))
		if not name.is_empty() and _wanted.has(section):
			ShellPrefs.put(name, roundf(float(_wanted[section])))


## The bar between two sections, dragged up and down.
class Bar extends Control:
	var stack: PanelStack
	## The section whose height a drag sets, and whether it is the one
	## above (a drag down makes it taller) or below (shorter).
	var resizes: Control
	var grows_down: bool = true
	var _dragging: bool = false
	var _grabbed_at: float = 0.0
	var _height_then: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_VSIZE
		tooltip_text = "Drag to share the column between these panels"

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button != null and button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			if _dragging and resizes != null:
				_grabbed_at = button.global_position.y
				_height_then = resizes.size.y
			elif not _dragging:
				stack.keep_heights()
			accept_event()
			queue_redraw()
			return
		var moved := event as InputEventMouseMotion
		if moved != null and _dragging and resizes != null:
			var by: float = moved.global_position.y - _grabbed_at
			stack.set_height(resizes, _height_then + (by if grows_down else -by))
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
			queue_redraw()

	func _draw() -> void:
		var lit: bool = _dragging or get_global_rect().has_point(get_global_mouse_position())
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.1, 1.0))
		var middle: float = size.y * 0.5
		draw_line(Vector2(0, middle), Vector2(size.x, middle),
			Color(1, 1, 1, 0.28 if lit else 0.1), 1.0)
		# A grip in the middle, so it reads as a thing to take hold of.
		for n: int in 3:
			var x: float = size.x * 0.5 + (n - 1) * 6.0
			draw_circle(Vector2(x, middle), 1.3, Color(1, 1, 1, 0.55 if lit else 0.3))
