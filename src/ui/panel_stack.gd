## A column of panels, one under another. Down the left, the parts bin and
## its colours under it, as Studio keeps its parts palette down the left
## with the colours at the foot. Down the right, the model tree over the
## properties of what is selected, as Blender stacks its outliner over its
## properties, and Figma, Blender and Onshape all keep the inspector on the
## right (Main). A phone keeps the tree and the properties in its drawer
## down the left, over the colours.
##
## The tree and the properties floated over the model's top corners, where
## a click meant for a part landed on a panel, and in a window 1100 across
## they left no room to build. Then they shared the left column with the
## bin, which at 1280 x 720 left it 8 parts in sight and the properties
## their X and Y, the rest behind a scroller (appux371, 2026-10-30).
##
## The tree and the properties fold to their header (a click on its name).
## The bar between two sections drags the height of the one that does not
## fill. The section kept under no name fills what is left (the bin); in a
## column with none, the lowest open one. The colours are as tall as the
## column says (PartsBin._fit_palette), never as anything else does, and
## never fill (never_fills): a phone's drawer has no bin, and its colours
## filled it, 995 px of 1558 with one row of the tree in sight over them
## (treerows, 2026-11-11). The heights are remembered (ShellPrefs), as the
## folds are.
##
## A choice never moves the split: only the person's own drag of the bar
## does. Properties filled in as a row was chosen and took the tree's height
## for themselves, kept whole (keep_whole): the tree went from 425 px to 110
## at 1280 x 720, the row chosen went up 128 px from under the pointer, and
## a double click on it opened its parent or another sub-model (tdcheck,
## 2026-11-11), as Blender's outliner and properties, Studio's and Unity's
## panels never move for a selection. Until the split is set, the properties
## are as tall as their header and what the model stands on while nothing
## is selected, the tree having the rest; the first time they fill, they
## have the room the tree has spare (none of its rows in sight), as far as
## all of them (keep_whole), and that is the split from then on, a section
## with nothing to show keeping its room (_split). A height dragged on an
## earlier visit is the split from the start.
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
## The sections kept whole: section -> true.
var _whole: Dictionary = {}
## Whether the split is set: by a drag of a bar, now or on an earlier visit,
## or by a first fill (_first_fill). Set, the lowest open section fills
## whether it has something to show or not, and none is made taller to be
## kept whole: a choice moves nothing.
var _split: bool = false
## The sections that never fill: section -> true ([method never_fills]).
var _least: Dictionary = {}


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
		# Only a drag writes it: other than its default, it is the person's.
		if not is_equal_approx(float(ShellPrefs.value(kept_as)),
				float(ShellPrefs.DEFAULTS.get(kept_as, 0.0))):
			_split = true
	add_child(section)
	if section.has_signal("toggled"):
		section.connect("toggled", func(_open: bool) -> void: queue_sort())
	if section.has_signal("idled"):
		section.connect("idled", func(idle: bool) -> void: _idled(section, idle))
	_rebuild_bars()
	queue_sort()


func sections() -> Array[Control]:
	return _sections


## Keep [param section] whole while it is open: as tall as all it holds
## where the column has room, the others giving theirs back. The properties
## a part is moved by typing into, every field of them in sight, not the
## model tree kept at the height it was dragged to with Turn and Roll behind
## a scroller.
func keep_whole(section: Control) -> void:
	_whole[section] = true
	queue_sort()


## [param section] is as tall as it says, never the one that fills what is
## left: the colours, whose height is the column's to say.
func never_fills(section: Control) -> void:
	_least[section] = true
	queue_sort()


## How tall [param section] is with nothing behind a scroller: its least,
## and what each scroller in it holds beyond what it shows at its least.
static func whole_height(section: Control) -> float:
	var tall: float = section.get_combined_minimum_size().y
	var looking: Array[Node] = [section]
	while not looking.is_empty():
		for child: Node in looking.pop_back().get_children():
			var scroll := child as ScrollContainer
			if scroll == null:
				if child is Control and (child as Control).visible:
					looking.append(child)
			elif scroll.visible and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
					and scroll.get_child_count() > 0 and scroll.get_child(0) is Control:
				tall += maxf(0.0, (scroll.get_child(0) as Control).get_combined_minimum_size().y
					- scroll.get_combined_minimum_size().y)
	return tall


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
## the lowest open one while that is folded. Until the split is set, the
## lowest open one with something to show: Properties with nothing selected
## give the column to the model tree over them.
func _filler() -> Control:
	return _filler_but(null)


## [method _filler], [param idle] counted as having nothing to show.
func _filler_but(idle: Control) -> Control:
	for section: Control in _sections:
		if str(_kept_as[section]).is_empty() and _is_open(section) and not _least.has(section):
			return section
	for n: int in range(_sections.size() - 1, -1, -1):
		var section: Control = _sections[n]
		if _is_open(section) and not _least.has(section) \
				and (_split or (section != idle and not _is_idle(section))):
			return section
	for n: int in range(_sections.size() - 1, -1, -1):
		if _is_open(_sections[n]) and not _least.has(_sections[n]):
			return _sections[n]
	return null


## [param section] has something to show now, or nothing ([param idle]).
func _idled(section: Control, idle: bool) -> void:
	if not idle and not _split:
		_first_fill(section)
	queue_sort()


## The first time [param section] fills with the split not set, the one
## that filled the column while it had nothing to show keeps the height it
## has, less the bar that comes between them now, and that is the split
## from then on: nothing in sight moves. Then, once [param section] has
## filled in (the signal comes before its fields do), it is given the room
## the other has spare (spare_height: the tree's under its last row), never
## what it shows, as far as all of it (_give_spare). Only in a column laid
## out where it is seen; where the filler is the same either way (the bin,
## down the left), nothing changes.
func _first_fill(section: Control) -> void:
	var was: Control = _filler_but(section)
	if was == null or was == section or _filler() != section or str(_kept_as[was]).is_empty() \
			or not is_visible_in_tree() or was.size.y <= 0.0:
		return
	var bars_before: float = 0.0
	for bar: Bar in _bars:
		if bar.visible:
			bars_before += BAR
	_split = true
	var filler: Control = _filler()
	var bars_after: float = 0.0
	for n: int in _bars.size():
		if _shows_bar(n, filler):
			bars_after += BAR
	_wanted[was] = maxf(was.size.y - (bars_after - bars_before), was.get_combined_minimum_size().y)
	_give_spare.call_deferred(was, section)


func _give_spare(was: Control, section: Control) -> void:
	if not is_instance_valid(was) or not is_instance_valid(section) or _filler() != section \
			or _is_idle(section):
		return
	var room: float = heights(size.y)[_sections.find(section)]
	var want: float = whole_height(section) if _whole.has(section) \
		else float(_wanted.get(section, room))
	var spare: float = float(was.call("spare_height")) if was.has_method("spare_height") else 0.0
	var give: float = clampf(minf(spare, want - room), 0.0,
		maxf(0.0, float(_wanted[was]) - was.get_combined_minimum_size().y))
	if give > 0.0:
		_wanted[was] = float(_wanted[was]) - give
		queue_sort()


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
		# Kept whole by the others' room, until the split is set: then the
		# filler has what the split leaves it, its scroller the rest.
		if _whole.has(section) and _is_open(section) and not _is_idle(section) \
				and not (_split and section == filler):
			floor_of = maxf(floor_of, whole_height(section))
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
		# A filler kept whole in a column too short for all of it has what
		# there is, its scroller showing the rest.
		out[index] = maxf(rest, least[index] if not _whole.has(filler)
			else filler.get_combined_minimum_size().y)
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
	_split = true
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
