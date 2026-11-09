## View, Stress's panel, over the model's right edge under the view cube
## while the view is on: what its colours mean, how many joints are past
## their working load and how many near it, and the weakest, worst first, to
## step through. Each selects its part and frames it with what holds it, and
## says why in the words pointing at it says (StressView.part_words) and what
## would fix it as the designer is told (StressView.fix_words).
##
## Studio's stability check colours parts red and pink and lists them; on
## walk180's 3,164-part hotel this view drew everything pale with nothing to
## say it stands (bench/results/walk180-2026-10-23, A9). It reads the
## weighing the view draws (StressView.ranked), so it says what a session's
## weakest_joints says, and it costs nothing more than filling its rows when
## a weighing comes in.
##
## And for the one stepped to, past its working load or near it, the fewest
## parts that make it hold (Strengthen): a plate across the seam, a brick
## under it or a second pin, shown as a ghost where it would go, and put
## down by Strengthen as one step to undo. With From my bricks, from the
## parts the person owns, as the parts bin counts them.
class_name StressPanel
extends PanelContainer

const WIDE := 300.0
## The list: every part red or amber, and the weakest of the rest to make
## this many; past MOST, how many more it leaves out.
const AT_LEAST := 8
const MOST := 100
## Room left under it for the key strip and the timeline.
const FOOT := 72.0
## Each colour as the legend shows it: the view's red and amber, and a part
## drawn faded, as clay.
const SAFE := Color(0.78, 0.76, 0.72)

var view: StressView
## Main's: [param ids] selected, and framed with [param around] (part ids).
var show_part: Callable = func(_ids: Array, _around: Array) -> void: pass
## Main's: what finds a joint's fix and puts it down; null where the panel
## has no model to change.
var fixer: Strengthen = null
## Main's: called once a fix is down, as after an edit by hand.
var edited: Callable = func() -> void: pass
## Main's: what the person owns, "part/colour" -> count
## (CollectionStore.on_hand); empty with no collection.
var owned: Callable = func() -> Dictionary: return {}
## The fix for the one stepped to, once found; null while it is looked for,
## or when there is none.
var fix: Strengthen.Fix = null

## What is listed, worst first (StressView.Weak), and the one stepped to,
## -1 for none.
var entries: Array = []
var chosen: int = -1

var _close: Button
var _count: Label
var _tips: Label
var _of: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _row_buttons: Array[Button] = []
var _picks := ButtonGroup.new()
var _more: Label
var _why: Label
var _fix: Label
var _previous: Button
var _next: Button
var _at: Label
var _chips: Dictionary = {}
## A row's looks, one of each for every row.
var _faces: Dictionary = {}
var _offer: Label
var _strengthen: Button
var _mine: CheckBox
var _ghost: MeshInstance3D = null
## The newest look for a fix: an older one coming in late is dropped.
var _looking: int = 0
## Whether a look for a fix is under way.
var _finding: bool = false


func _ready() -> void:
	visible = false
	_build()
	var parent: Control = get_parent() as Control
	if parent != null:
		parent.resized.connect(_fit_later)
	visibility_changed.connect(func() -> void:
		if not visible:
			_forget_fix())


## The list of [param weak] (StressView.ranked), the count over it; empty
## while the weighing is still to come in. The one stepped to stays chosen
## when it is still listed.
func show_weak(weak: Array) -> void:
	var was: int = (entries[chosen] as StressView.Weak).id if chosen >= 0 else 0
	var listed: Array = []
	for one: StressView.Weak in weak:
		if listed.size() >= MOST or (one.margin >= StressView.CLOSE and listed.size() >= AT_LEAST):
			break
		listed.append(one)
	entries = listed
	chosen = -1
	var weighed: bool = view != null and view.report != null
	var counted: Array = StressView.tally(weak)
	_count.text = StressView.count_words(weak) if weighed else "Weighing every joint…"
	_tips.visible = false
	if weighed:
		for risk: Stability.Risk in view.report.risks:
			if risk.kind == "tips":
				_tips.text = "The whole model tips over: %s." % risk.message
				_tips.visible = true
	var joints: int = StressView.joints_in(view.report, view.world, view.scenery) if weighed else 0
	_of.visible = weighed
	_of.text = "Weakest first, of %d joint%s that each alone hold what is past them." % [joints,
		"" if joints == 1 else "s"] if joints > 0 \
		else "No joint alone holds what is past it: every part is held more than one way."
	# The rows kept from one weighing to the next, each said again: made
	# afresh after every change, they were most of the time it took to show.
	while _row_buttons.size() < entries.size():
		_row_buttons.append(_row(_row_buttons.size()))
	for n: int in _row_buttons.size():
		_row_buttons[n].visible = n < entries.size()
		_row_buttons[n].set_pressed_no_signal(false)
		if n < entries.size():
			_say_row(_row_buttons[n], entries[n])
	var left: int = counted[0] + counted[1] - entries.filter(func(one: StressView.Weak) -> bool:
		return one.margin < StressView.CLOSE).size()
	_more.visible = left > 0
	_more.text = "…and %d more red or amber, not listed" % left
	_scroll.visible = not entries.is_empty()
	for n: int in entries.size():
		if (entries[n] as StressView.Weak).id == was:
			_choose(n, false)
	_say_chosen()
	_fit_later()


## Step to the next one listed ([param by] 1) or the one before (-1), from
## the first when none is chosen; selected and framed.
func step(by: int) -> void:
	if entries.is_empty():
		return
	_choose(0 if chosen < 0 else posmod(chosen + by, entries.size()))


func _choose(n: int, framed: bool = true) -> void:
	chosen = n
	for at: int in _row_buttons.size():
		_row_buttons[at].set_pressed_no_signal(at == n)
	_say_chosen()
	if n < 0 or n >= entries.size():
		return
	_scroll.ensure_control_visible.call_deferred(_row_buttons[n])
	if framed:
		var one: StressView.Weak = entries[n]
		show_part.call(one.ids, [one.around] if one.around > 0 else [])


func _say_chosen() -> void:
	var one: StressView.Weak = entries[chosen] if chosen >= 0 and chosen < entries.size() else null
	_why.visible = one != null
	_fix.visible = false
	_previous.disabled = entries.size() < 2
	_next.disabled = entries.is_empty()
	_at.text = "%d of %d" % [chosen + 1, entries.size()] if one != null else ""
	if one == null:
		_forget_fix()
		_offer.visible = false
		_strengthen.visible = false
		_mine.visible = false
		return
	_why.text = view.words(one.id) if view != null else ""
	_fix.text = StressView.fix_words(one, view.library if view != null else null)
	_fix.visible = not _fix.text.is_empty()
	_look_for_fix(one)
	# Its words take room from the list, not from under the key strip.
	_fit_later()


# -- Strengthen ------------------------------------------------------------------


## Look for [param one]'s fix, past its working load or near it: the one
## found for it is kept while the model is as it was.
func _look_for_fix(one: StressView.Weak) -> void:
	var wanted: bool = fixer != null and view != null and view.report != null \
		and one.margin < StressView.CLOSE
	var theirs: Dictionary = owned.call() if wanted else {}
	_mine.visible = wanted and not theirs.is_empty()
	_offer.visible = wanted
	_strengthen.visible = wanted
	if not wanted:
		_forget_fix()
		return
	if fix != null and fix.weak == one.id and fix.revision == view.world.revision:
		return
	_forget_fix()
	_looking += 1
	var asked: int = _looking
	_finding = true
	_offer.text = "Looking for the fewest parts that make it hold…"
	_strengthen.disabled = true
	fixer.scenery = view.scenery
	fixer.owned = theirs if _mine.visible and _mine.button_pressed else {}
	var found: Strengthen.Fix = await fixer.find(view.report, one)
	if asked != _looking:
		return
	_finding = false
	fix = found
	if found == null:
		_offer.text = "No fix of up to three parts has room here: %s" % (
			"brace it by hand." if one.joint != null else "hold it with studs by hand.")
		_fit_later()
		return
	_offer.text = "Strengthen adds %s. %s.%s" % [found.what, Strengthen.held_words(found),
		"" if fixer.owned.is_empty() else (" All from your bricks." if found.mine
			else " Not all from your bricks: you have none of one left.")]
	_strengthen.disabled = false
	_show_ghost(found)
	_fit_later()


## Put the fix down, one step to undo, and the parts it adds selected.
func strengthen() -> void:
	if fix == null or fixer == null:
		return
	var put: Strengthen.Fix = fix
	var made: PackedInt64Array = fixer.place(put)
	_forget_fix()
	if made.is_empty():
		view.say.call("the model changed: its fix is looked for again")
		var one: StressView.Weak = entries[chosen] if chosen >= 0 and chosen < entries.size() else null
		if one != null:
			_look_for_fix(one)
		return
	fixer.builder.selection.clear()
	for id: int in made:
		fixer.builder.selection[id] = true
	fixer.builder.selection_changed.emit(fixer.builder.selection.size())
	view.say.call(Keymap.filled("strengthened: %s — {undo|takes it back}") % put.what)
	edited.call()


func _show_ghost(found: Strengthen.Fix) -> void:
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fixer.builder.add_child(_ghost)
	_ghost.mesh = Strengthen.ghost_mesh(found.parts, view.library)
	_ghost.visible = true


func _forget_fix() -> void:
	_looking += 1
	_finding = false
	fix = null
	if _ghost != null:
		_ghost.visible = false
	if _strengthen != null:
		_strengthen.disabled = true


## The row for the [param n]th listed.
func _row(n: int) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _picks
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 12)
	if _faces.is_empty():
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var face := StyleBoxFlat.new()
			face.bg_color = {"normal": Color(1, 1, 1, 0.0), "hover": Color(1, 1, 1, 0.08),
				"pressed": Color(0.36, 0.6, 1.0, 0.35), "hover_pressed": Color(0.36, 0.6, 1.0, 0.45)}[state]
			face.set_corner_radius_all(4)
			face.content_margin_left = 6
			face.content_margin_right = 6
			face.content_margin_top = 2
			face.content_margin_bottom = 2
			_faces[state] = face
	for state: String in _faces:
		button.add_theme_stylebox_override(state, _faces[state])
	button.pressed.connect(func() -> void: _choose(n))
	_rows.add_child(button)
	return button


func _say_row(button: Button, one: StressView.Weak) -> void:
	button.icon = _chip(_colour_of(one))
	var brick: BrickWorld.Brick = view.world.get_brick(one.id) if view != null else null
	var name: String = StressView._named(view.library, brick.part_id) if brick != null else "#%d" % one.id
	# The margin first: a long name is cut short, never the number.
	button.text = "%s · %s" % ["on a touch" if one.joint == null
		else "margin " + StressView.margin_words(one.margin), name]
	button.tooltip_text = view.words(one.id) if view != null else ""


static func _colour_of(one: StressView.Weak) -> Color:
	if one.margin < StressView.WEAK:
		return StressView.RED
	return StressView.AMBER if one.margin < StressView.CLOSE else SAFE


## A square of [param colour], as the legend and each row show it.
func _chip(colour: Color) -> Texture2D:
	var key: String = colour.to_html()
	if not _chips.has(key):
		var image := Image.create(10, 10, false, Image.FORMAT_RGBA8)
		image.fill(colour)
		_chips[key] = ImageTexture.create_from_image(image)
	return _chips[key]


func _fit_later() -> void:
	_fit.call_deferred()


## The list as tall as its rows, or as the room under the panel leaves for it
## above the key strip, scrolling past that.
func _fit() -> void:
	if not visible or _scroll == null:
		return
	var parent: Control = get_parent() as Control
	var tall: float = parent.size.y if parent != null else get_viewport_rect().size.y
	_scroll.custom_minimum_size.y = 0.0
	var wanted: float = _rows.get_combined_minimum_size().y
	var others: float = get_combined_minimum_size().y
	var room: float = tall - offset_top - FOOT - others
	_scroll.custom_minimum_size.y = clampf(wanted, minf(wanted, 48.0), maxf(room, 48.0))
	reset_size()


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.95)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 11
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDE, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Stress"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close = _button(header, "Close", func() -> void:
		if view != null:
			view.set_on(false), "Stress off: every part in its own colour again (View, Stress)")
	_count = _words(column, 13, 1.0)
	_tips = _words(column, 12, 1.0)
	_tips.add_theme_color_override("font_color", StressView.RED.lightened(0.25))
	_tips.visible = false
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 2)
	column.add_child(legend)
	for each: Array in [[StressView.RED, "Past its working load: the first to give"],
			[StressView.AMBER, "Near it: holds it less than twice over"],
			[SAFE, "Holds it twice over, or shares its load: faded"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		legend.add_child(row)
		var chip := TextureRect.new()
		chip.texture = _chip(each[0])
		chip.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(chip)
		var words := Label.new()
		words.text = each[1]
		words.add_theme_font_size_override("font_size", 11)
		words.modulate = Color(1, 1, 1, 0.75)
		row.add_child(words)
	column.add_child(HSeparator.new())
	_of = _words(column, 11, 0.65)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 1)
	_scroll.add_child(_rows)
	_more = _words(column, 11, 0.65)
	_why = _words(column, 12, 0.95)
	_fix = _words(column, 12, 0.8)
	_offer = _words(column, 12, 0.95)
	_offer.visible = false
	var fixing := HBoxContainer.new()
	fixing.add_theme_constant_override("separation", 10)
	column.add_child(fixing)
	_strengthen = _button(fixing, "Strengthen", strengthen,
		"Put the parts shown down: the joint then holds. One step to undo")
	_strengthen.visible = false
	_strengthen.disabled = true
	_mine = CheckBox.new()
	_mine.text = "From my bricks"
	_mine.tooltip_text = "Make the fix of parts you own, in colours you have one of left"
	_mine.focus_mode = Control.FOCUS_NONE
	_mine.add_theme_font_size_override("font_size", 12)
	_mine.visible = false
	_mine.toggled.connect(func(_on: bool) -> void:
		_forget_fix()
		var one: StressView.Weak = entries[chosen] if chosen >= 0 and chosen < entries.size() else null
		if one != null:
			_look_for_fix(one))
	fixing.add_child(_mine)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 8)
	column.add_child(steps)
	_previous = _button(steps, "Previous", func() -> void: step(-1),
		"The joint before this one in the list, selected and in view")
	_next = _button(steps, "Next", func() -> void: step(1),
		"The next weakest joint, selected and in view")
	_at = Label.new()
	_at.add_theme_font_size_override("font_size", 11)
	_at.modulate = Color(1, 1, 1, 0.65)
	_at.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_at.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	steps.add_child(_at)
	show_weak([])


func _words(into: Control, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDE - 28.0, 0)
	label.modulate = Color(1, 1, 1, alpha)
	into.add_child(label)
	return label


func _button(into: Control, words: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	into.add_child(button)
	return button


## What it shows, for a probe to read as a person would.
func fields() -> Dictionary:
	var rows: Array = []
	for n: int in entries.size():
		rows.append(_row_buttons[n].text)
	return {"count": _count.text, "tips": _tips.text if _tips.visible else "", "of": _of.text,
		"rows": rows, "more": _more.text if _more.visible else "",
		"why": _why.text if _why.visible else "", "fix": _fix.text if _fix.visible else "",
		"at": _at.text, "offer": _offer.text if _offer.visible else "",
		"strengthen": _strengthen.visible and not _strengthen.disabled,
		"finding": _finding, "mine": _mine.visible and _mine.button_pressed}


## Where each control is, for a probe or a browser test to press.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = {"stress_close": _close, "stress_previous": _previous,
		"stress_next": _next, "stress_strengthen": _strengthen, "stress_mine": _mine}
	for n: int in mini(entries.size(), 12):
		out["stress_row_%d" % n] = _row_buttons[n]
	return out
