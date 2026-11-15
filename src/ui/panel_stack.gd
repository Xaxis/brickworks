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
## One way to fold and size every section, wherever it is (panelfold,
## 2026-11-13, the owner: "a consistent cohesive ui/ux pattern for our
## advanced panels"). VS Code's sidebar views, Blender's panels, JetBrains'
## tool windows, Figma's Pages and Unity's inspector agree on it, and so
## does it here:
## - Every section wears one header ([Head]): a chevron (pointing down
##   while open, at the name while folded), the name, and its count or
##   state. A click anywhere on it, or Enter or the space bar with the keys
##   on it, folds the section to that header; its tooltip and the name a
##   screen reader hears say Fold or Unfold. Folded, a section sits at its
##   own edge: the colours at the foot of the left column, a header bar
##   only, the bin taking the room; the tree at the top of the right one.
## - Every bar between two open sections ([Bar]) drags the height of the
##   one that does not fill: the resize cursor, its grip lit on hover. It
##   lies over the line between them and takes no room (VS Code's sash),
##   except on a phone, where it is a handle a fingertip tall
##   ([member bar_room]). A section is never dragged shorter than its least
##   (its header and a row, [method least_open]), nor so tall that the one
##   that fills has less than its header and a row ("to an extent": the
##   colours may cover most of the bin, never all of it), nor the colours
##   taller than all their swatches, a blank under them. A double click
##   puts the split back as a first visit has it; with the keys on it (Tab
##   reaches it) the arrows move it, Page Up and Page Down further.
## - Heights and folds are remembered (ShellPrefs), and View, Panels, Reset
##   panel layout puts every section back open at its first height
##   ([method reset]).
##
## The section kept under no name fills what is left (the bin); in a column
## with none, the lowest open one. The colours fill nothing while another
## section is open (never_fills): a phone's drawer has no bin, and its
## colours filled it, 995 px of 1558 with one row of the tree in sight over
## them (treerows, 2026-11-11). They are as tall as the column says
## (PartsBin._fit_palette) until their bar is dragged, and then as tall as
## it was dragged, their swatches flowing into the room; with every other
## section folded they have the column. In a drawer too short for them as
## well as the others at their least, they give the difference ([method
## room_for]), and dragged taller they keep it against the tree's last rows
## but not against the drawer's foot. With nothing open at all, the room
## left over goes under the section that would fill, so a folded Colour
## still sits at the foot.
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
## earlier visit is the split from the start; the colours' is not, being
## no part of the tree's and the properties' split.
class_name PanelStack
extends Container

## The bar between two sections, as tall as a pointer finds it: it lies
## over the line between them, half over each section's margin.
const BAR := 7.0
## The least of a section's own under its header while it is open: a row.
const ROW := 32.0
## How far an arrow key moves a bar, and Page Up or Page Down.
const STEP := 16.0
const PAGE := 96.0

## The room each shown bar takes in the column: none on a desktop, where it
## lies over the line between two sections; a fingertip on a phone (Main
## ._dress_for_phone), where a handle laid over a header took its taps.
var bar_room: float = 0.0

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

## A section's height kept as the person dragged it, or put back.
signal sized(section: Control)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true


## Add a section under the others. ``kept_as`` names its height in
## ShellPrefs; the section kept under no name fills what is left. A section
## that never fills is said so first ([method never_fills]).
func add_section(section: Control, kept_as: String = "") -> void:
	_sections.append(section)
	_kept_as[section] = kept_as
	if not kept_as.is_empty():
		_wanted[section] = float(ShellPrefs.value(kept_as))
		# Only a drag writes it: other than its default, it is the person's.
		if is_sized(section) and not _least.has(section):
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


## [param section] is as tall as it says, or as its bar was dragged, never
## the one that fills what is left while another section is open: the
## colours. Said before it is added, so a height dragged for it on an
## earlier visit does not set the split.
func never_fills(section: Control) -> void:
	_least[section] = true
	queue_sort()


## Whether [param section]'s height is the person's: dragged, now or on an
## earlier visit, and not put back since.
func is_sized(section: Control) -> bool:
	var name: String = str(_kept_as.get(section, ""))
	return not name.is_empty() and not is_equal_approx(float(ShellPrefs.value(name)),
		float(ShellPrefs.DEFAULTS.get(name, 0.0)))


## The header [param section] wears ([Head]), or null.
static func head_of(section: Control) -> Head:
	return section.get("section_head") as Head


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
			bars += bar_room
	var used: float = bars
	for h: float in out:
		used += h
	# Too tall: the open sections give back what they have over their
	# least, the topmost first, so the properties keep their room longest.
	var over: float = used - room
	# The colours dragged taller give way to the column, not to the model
	# tree's last rows: a drag's height is the person's, and the tree
	# scrolls (a phone's drawer, 2026-11-13).
	var whole_over: float = 0.0
	if filler != null and _whole.has(filler):
		whole_over = maxf(0.0, least[_sections.find(filler)]
			- filler.get_combined_minimum_size().y)
	for n: int in _sections.size():
		if over <= 0.0:
			break
		var spare: float = out[n] - least[n]
		if spare <= 0.0 or _sections[n] == filler:
			continue
		var give: float = minf(spare, over)
		if _least.has(_sections[n]):
			give = minf(give, maxf(0.0, over - whole_over))
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


## The least [param section] may be dragged or squeezed to: what it holds
## at its least, and while it is open with something to show, its header
## and a row under it.
func least_open(section: Control) -> float:
	var least: float = section.get_combined_minimum_size().y
	var head: Head = head_of(section)
	if head != null and head.is_visible_in_tree() and _is_open(section) and not _is_idle(section):
		var style: StyleBox = section.get_theme_stylebox(&"panel")
		var margins: float = style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM) \
			if style != null else 0.0
		least = maxf(least, margins + head.get_combined_minimum_size().y + ROW)
	return least


## The tallest [param section] may be dragged: the column, less every other
## section as it is now and the one that fills at its least.
func most_of(section: Control) -> float:
	return maxf(room_for(section), least_open(section))


## The room the column leaves [param section], every other section as it is
## now and the one that fills at its least: under its own least where the
## column is too short for them all (PartsBin._fit_palette).
func room_for(section: Control) -> float:
	var filler: Control = _filler()
	var tall: Array[float] = heights(size.y)
	var room: float = size.y
	for n: int in _sections.size():
		if n < _sections.size() - 1 and _shows_bar(n, filler):
			room -= bar_room
		var other: Control = _sections[n]
		if other != section and other.visible:
			room -= least_open(other) if other == filler else tall[n]
	return room


## Set an open section's height, as a drag of its bar does: never under its
## least, nor over what leaves the one that fills its header and a row.
func set_height(section: Control, height: float) -> void:
	if str(_kept_as.get(section, "")).is_empty():
		return
	var least: float = least_open(section)
	var most: float = most_of(section)
	# The colours dragged no taller than all their swatches: past that, a
	# blank under them. A height dragged earlier is kept as the palette
	# changes under it (a search, All): what the person does moves nothing.
	if _least.has(section):
		most = minf(most, maxf(least, whole_height(section)))
	# A drag never makes it shorter than it stands while it asks for more.
	if height > section.size.y:
		most = maxf(most, section.size.y)
	_wanted[section] = clampf(height, least, maxf(least, most))
	if not _least.has(section):
		_split = true
	else:
		_fit_whole(section)
	queue_sort()


## The colours given room for every swatch lose their scroller, and the
## swatches, wider by its width, take fewer rows: the blank that leaves
## under them goes too, once they are laid out so.
func _fit_whole(section: Control) -> void:
	for _n: int in 2:
		await get_tree().process_frame
	if not is_instance_valid(section) or not _wanted.has(section):
		return
	var whole: float = whole_height(section)
	if float(_wanted[section]) > whole + 0.5 and section.size.y > whole + 0.5 \
			and whole >= least_open(section):
		_wanted[section] = whole
		if is_sized(section):
			keep_height(section)
		queue_sort()


## The drag has ended: keep [param section]'s height for next time.
func keep_height(section: Control) -> void:
	var name: String = str(_kept_as.get(section, ""))
	if not name.is_empty() and _wanted.has(section):
		ShellPrefs.put(name, roundf(float(_wanted[section])))
		sized.emit(section)


## [param section]'s height as a first visit has it (a double click on its
## bar): the split not set unless another height is the person's.
func reset_height(section: Control) -> void:
	var name: String = str(_kept_as.get(section, ""))
	if name.is_empty():
		return
	var first: float = float(ShellPrefs.DEFAULTS.get(name, 0.0))
	_wanted[section] = first
	ShellPrefs.put(name, first)
	_split = false
	for other: Control in _sections:
		if is_sized(other) and not _least.has(other):
			_split = true
	sized.emit(section)
	queue_sort()


## Every section open, at its first height (View, Panels, Reset panel
## layout).
func reset() -> void:
	for section: Control in _sections:
		reset_height(section)
		if section.has_method("set_open") and section.has_method("is_open") \
				and not bool(section.call("is_open")):
			section.call("set_open", true)
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
		var section: Control = _sections[n]
		if _is_open(section) and not _least.has(section) and not _whole.has(section):
			return section
	# Every other section folded: the lowest open one has the column, the
	# colours with the bin folded over them, rather than a blank under them.
	for n: int in range(_sections.size() - 1, -1, -1):
		if _is_open(_sections[n]):
			return _sections[n]
	return null


## Where the room goes with no section open to fill it: under the one that
## would fill, so what is under that (a folded Colour) stays at the foot.
func _home() -> int:
	for n: int in _sections.size():
		if str(_kept_as[_sections[n]]).is_empty() and not _least.has(_sections[n]):
			return n
	for n: int in range(_sections.size() - 1, -1, -1):
		if not _least.has(_sections[n]):
			return n
	return -1


## [param section] has something to show now, or nothing ([param idle]).
func _idled(section: Control, idle: bool) -> void:
	if not idle and not _split:
		_first_fill(section)
	queue_sort()


## The first time [param section] fills with the split not set, the one
## that filled the column while it had nothing to show keeps the height it
## has, and that is the split from then on: nothing in sight moves. A bar
## that comes between them now takes its room from [param section], which
## is changing anyway: taken from the tree, a phone's handle a fingertip
## tall moved its rows up from under the finger that chose one (panelfold,
## tree_rows on a tablet). Then, once [param section] has filled in (the
## signal comes before its fields do), it is given the room the other has
## spare (spare_height: the tree's under its last row), never what it
## shows, as far as all of it (_give_spare). Only in a column laid out
## where it is seen; where the filler is the same either way (the bin, down
## the left), nothing changes.
func _first_fill(section: Control) -> void:
	var was: Control = _filler_but(section)
	if was == null or was == section or _filler() != section or str(_kept_as[was]).is_empty() \
			or not is_visible_in_tree() or was.size.y <= 0.0:
		return
	_split = true
	_wanted[was] = maxf(was.size.y, was.get_combined_minimum_size().y)
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
## with something in it.
func _shows_bar(n: int, filler: Control) -> bool:
	var section: Control = _resized_by(n, filler)
	return section != filler and _is_open(section) and not _is_idle(section) \
		and not str(_kept_as[section]).is_empty()


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var filler: Control = _filler()
	var tall: Array[float] = heights(size.y)
	# Nothing open to fill: the room left over goes under the section that
	# would fill (_home), so a folded Colour stays at the foot.
	var gap: float = 0.0
	var gap_after: int = -1
	if filler == null:
		gap = size.y
		for h: float in tall:
			gap -= h
		gap = maxf(gap, 0.0)
		gap_after = _home()
	var y: float = 0.0
	for n: int in _sections.size():
		var section: Control = _sections[n]
		if section.visible:
			fit_child_in_rect(section, Rect2(0.0, y, size.x, tall[n]))
			y += tall[n]
		if n == gap_after:
			y += gap
		if n < _bars.size():
			var bar: Bar = _bars[n]
			bar.visible = _shows_bar(n, filler)
			if bar.visible:
				bar.resizes = _resized_by(n, filler)
				bar.grows_down = bar.resizes == section
				bar.named()
				if bar_room > 0.0:
					fit_child_in_rect(bar, Rect2(0.0, y, size.x, bar_room))
					y += bar_room
				else:
					fit_child_in_rect(bar, Rect2(0.0, y - BAR * 0.5, size.x, BAR))
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


## The header every section of a column wears: the chevron, the name and
## its count or state, one row that a click folds or unfolds anywhere on
## it. The name is a button, so Tab reaches it and Enter or the space bar
## presses it (FocusGuard.by_keyboard: a click leaves the keys with the
## model). The section keeps whether it is open and says so here
## ([method show_open]).
class Head extends HBoxContainer:
	## A click on the row, or Enter or the space bar on its name.
	signal pressed

	var button: Button
	var arrow: Arrow
	## Its count or state, dimmer, after the name: "3 parts", the colour in
	## hand while the colours are folded.
	var count: Label
	## A swatch beside the state, where the state is a colour.
	var mark: ColorRect
	## The section's name, and what it is: the tooltip's first line.
	var words: String = ""
	var about: String = ""
	var _open: bool = true
	var _folds: bool = true

	func _init(name_words: String, about_words: String = "", font: int = 13) -> void:
		words = name_words
		about = about_words
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_constant_override("separation", 2)
		arrow = Arrow.new()
		arrow.custom_minimum_size = Vector2(font + 1, font + 1)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(arrow)
		button = Button.new()
		button.flat = true
		button.text = name_words
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", font)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		FocusGuard.by_keyboard(button)
		button.pressed.connect(func() -> void:
			if _folds:
				pressed.emit())
		add_child(button)
		mark = ColorRect.new()
		mark.custom_minimum_size = Vector2(12, 12)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.color = Color(0, 0, 0, 0)
		mark.visible = false
		add_child(mark)
		count = Label.new()
		count.add_theme_font_size_override("font_size", maxi(font - 1, 1))
		count.modulate = Color(1, 1, 1, 0.6)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(count)
		show_open(true)

	## A click on the row beside the name: the chevron, the count, the
	## room between.
	func _gui_input(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed \
				and _folds and Rect2(Vector2.ZERO, size).has_point(click.position):
			pressed.emit()
			accept_event()

	## Open or folded: the chevron's way, the tooltip and the name a screen
	## reader hears.
	func show_open(open: bool) -> void:
		_open = open
		arrow.down = open
		arrow.queue_redraw()
		if not _folds:
			return
		var say: String = ("Fold %s" if open else "Unfold %s") % words
		var how: String = "Click to fold it to its header" if open else "Click to open it"
		button.accessibility_name = say
		button.accessibility_description = about
		button.tooltip_text = (about + "\n" + how) if not about.is_empty() else how
		tooltip_text = button.tooltip_text

	func is_open() -> bool:
		return _open

	## A header that folds nothing (the properties under the bin, whose
	## header is the selection's name): no chevron, and a click does nothing.
	func set_folds(folds: bool) -> void:
		_folds = folds
		arrow.visible = folds
		mouse_filter = Control.MOUSE_FILTER_STOP if folds else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if folds \
			else Control.CURSOR_ARROW
		button.mouse_filter = Control.MOUSE_FILTER_STOP if folds else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if folds else Control.FOCUS_NONE
		if not folds:
			button.tooltip_text = ""
			tooltip_text = ""
			button.accessibility_name = ""
		else:
			show_open(_open)


## A small triangle, drawn rather than typeset: the font has no arrows.
## Down while its section is open, at the name while it is folded.
class Arrow extends Control:
	var down: bool = true

	func _draw() -> void:
		var s: Vector2 = size
		var points: PackedVector2Array
		if down:
			points = PackedVector2Array([Vector2(s.x * 0.2, s.y * 0.35),
				Vector2(s.x * 0.8, s.y * 0.35), Vector2(s.x * 0.5, s.y * 0.72)])
		else:
			points = PackedVector2Array([Vector2(s.x * 0.35, s.y * 0.2),
				Vector2(s.x * 0.72, s.y * 0.5), Vector2(s.x * 0.35, s.y * 0.8)])
		draw_colored_polygon(points, Color(1, 1, 1, 0.7))


## A section that folds what it is given ([method folds_away]) under its
## header, which its maker puts where it wants it: the colours under the
## parts bin, their header in the row with their search.
class Fold extends PanelContainer:
	signal toggled(open: bool)

	var section_head: Head
	## The ShellPrefs name whether it is open is kept under.
	var kept_open_as: String = ""
	## Its header's state (count, mark) shown only while it is folded: the
	## colour in hand, said under the swatches while they are open.
	var state_when_folded: bool = false
	var _open: bool = true
	var _folding: Array[Control] = []

	func _init(name_words: String, about_words: String, kept_as: String) -> void:
		kept_open_as = kept_as
		section_head = Head.new(name_words, about_words)
		section_head.pressed.connect(func() -> void: set_open(not _open))
		if not kept_as.is_empty():
			_open = bool(ShellPrefs.value(kept_as))
		section_head.show_open(_open)

	## [param control] shown while the section is open, and only then.
	func folds_away(control: Control) -> void:
		_folding.append(control)
		control.visible = _open
		_show_state()

	func is_open() -> bool:
		return _open

	func set_open(open: bool) -> void:
		_open = open
		for control: Control in _folding:
			control.visible = open
		section_head.show_open(open)
		_show_state()
		if not kept_open_as.is_empty():
			ShellPrefs.put(kept_open_as, open)
		toggled.emit(open)

	## Its state in its header: words, and a swatch where the state is a
	## colour.
	func say_state(words: String, swatch: Color = Color(0, 0, 0, 0)) -> void:
		section_head.count.text = words
		section_head.mark.color = swatch
		_show_state()

	func _show_state() -> void:
		if state_when_folded:
			section_head.count.visible = not _open
			section_head.mark.visible = not _open and section_head.mark.color.a > 0.0


## The bar between two sections, dragged up and down, or moved by the
## arrows with the keys on it; a double click puts its split back.
class Bar extends Control:
	var stack: PanelStack
	## The section whose height a drag sets, and whether it is the one
	## above (a drag down makes it taller) or below (shorter).
	var resizes: Control
	var grows_down: bool = true
	var _dragging: bool = false
	var _hovered: bool = false
	var _grabbed_at: float = 0.0
	var _height_then: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_VSIZE
		FocusGuard.by_keyboard(self)
		tooltip_text = ("Drag to share the column between these panels\n"
			+ "Double-click to put it back as it was at first")

	## Its name for a screen reader, from the section it sizes.
	func named() -> void:
		var head: Head = PanelStack.head_of(resizes) if resizes != null else null
		var say: String = "Resize %s" % head.words if head != null else "Resize the panels"
		if accessibility_name != say:
			accessibility_name = say
		queue_accessibility_update()

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button != null and button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and button.double_click:
				_dragging = false
				if resizes != null:
					stack.reset_height(resizes)
			else:
				_dragging = button.pressed
				if _dragging and resizes != null:
					_grabbed_at = button.global_position.y
					_height_then = resizes.size.y
				elif not _dragging and resizes != null:
					stack.keep_height(resizes)
			accept_event()
			queue_redraw()
			return
		var moved := event as InputEventMouseMotion
		if moved != null and _dragging and resizes != null:
			var by: float = moved.global_position.y - _grabbed_at
			stack.set_height(resizes, _height_then + (by if grows_down else -by))
			accept_event()
			return
		if resizes == null or not event.is_pressed():
			return
		# Up moves the bar up, whichever side it sizes.
		var up: float = 0.0
		if event.is_action("ui_up", true):
			up = STEP
		elif event.is_action("ui_down", true):
			up = -STEP
		elif event.is_action("ui_page_up", true):
			up = PAGE
		elif event.is_action("ui_page_down", true):
			up = -PAGE
		if up == 0.0:
			return
		stack.set_height(resizes, resizes.size.y + (-up if grows_down else up))
		stack.keep_height(resizes)
		accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
			_hovered = what == NOTIFICATION_MOUSE_ENTER
			queue_redraw()
		elif what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()
		elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
			var element: RID = get_accessibility_element()
			AccessibilityServer.update_set_role(element, AccessibilityServer.ROLE_SPLITTER)
			if resizes != null:
				AccessibilityServer.update_set_num_value(element, roundf(resizes.size.y))

	func _draw() -> void:
		var lit: bool = _dragging or _hovered or has_focus()
		var middle: float = size.y * 0.5
		var tint: Color = Look.ACCENT if lit else Color(1, 1, 1, 1)
		if stack != null and stack.bar_room > 0.0:
			# A phone's: a handle in a strip of its own, as a sheet's.
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.1, 1.0))
			var wide: float = minf(size.x * 0.25, size.y * 1.2)
			var thick: float = maxf(4.0, size.y * 0.1)
			draw_rect(Rect2(size.x * 0.5 - wide * 0.5, middle - thick * 0.5, wide, thick),
				Color(tint, 0.75 if lit else 0.35))
			return
		# Over the line between two sections: lit, a line of its own and
		# the grip; at rest, the grip alone over the sections' own line.
		if lit:
			draw_line(Vector2(0, middle), Vector2(size.x, middle), Color(tint, 0.85), 2.0)
		for n: int in 3:
			var x: float = size.x * 0.5 + (n - 1) * 6.0
			draw_circle(Vector2(x, middle), 1.4, Color(tint, 0.9 if lit else 0.3))
