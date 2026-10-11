## The line of controls along the bottom.
##
## It has two jobs that pull against each other: be readable over a model
## of any colour, and stay out of the way. Outlined text does neither
## well — a black outline on light text is legible and also the loudest
## thing on screen, which is why the first version read as clutter.
##
## So the keys are drawn as keys: small dark chips with the glyph in
## them, and the verb beside each in plain grey. A chip carries its own
## background, so it is legible over anything without the text needing an
## outline, and the whole strip can sit at a low opacity and still be
## read at a glance.
##
## And the mouse, the trackpad and fingers are drawn as themselves. They
## were chips too, with words in them — "right-drag", "middle-drag" —
## which is a sentence to read where a picture of a mouse with its right
## button lit is understood before it is read. Asked for by the owner:
## "shouldnt their be a list of controls with corresponding icons". The
## pictures are SVGs in assets/ui/controls, drawn by [Icons] at the
## screen's own density.
##
## Everything listed here is bound. A hint that lies is worse than no
## hint, so the bindings live in one table and both the display and the
## handler read from it.
class_name ControlsHint
extends FlowContainer


## What the modifier is called here.
static func _hold() -> String:
	return "Cmd" if OS.get_name() == "macOS" else "Ctrl"


## One control: what to press, what it does, and what the pointer looks
## like while it is happening — a state from [Cursors], or "" for a
## control that does not change it.
class Binding extends RefCounted:
	var keys: PackedStringArray
	var verb: String
	var cursor: String
	## Which part of the full list it belongs in. Only the controls
	## panel shows these.
	var section: String = ""

	func _init(pressed: Array, does: String, shows: String = "") -> void:
		keys = PackedStringArray(pressed)
		verb = does
		cursor = shows


## Ordered by how often a beginner reaches for it, because that is the
## order they are dropped in when the window is too narrow to hold them
## all — the strip wraps to a second line rather than running off the
## edge, and a hint you cannot finish reading is a hint that lies by
## omission.
##
## Turning, sliding and zooming used to be left out on the grounds that
## they are what people try without being told. They are — and what
## people try is a middle button they do not have and a drag that did
## nothing, so the app read as broken with nothing on screen to say
## otherwise. They come second now, after placing and removing.
static func bindings() -> Array[Binding]:
	# A phone has no keyboard, and a strip of keys it cannot press is
	# worse than no strip: it reads as a list of things the app will not
	# let you do.
	#
	# The same question the round buttons ask, so the strip and the
	# buttons cannot disagree. It was a different one, with a different
	# threshold, and a phone held sideways got the buttons and the
	# keyboard list — sixteen shortcuts for keys it does not have,
	# beside four controls it was not told about.
	if TouchTools.wanted():
		return for_touch()
	return for_strip()


## The two lists, each reachable whatever this build is running on.
##
## bindings() answers with one of them, which is right for the app and
## wrong for anything checking them: a probe running on a desktop asks
## bindings() and is handed the keyboard list, so the touch list — the
## one with the arrows in it — was never looked at. That is how the
## glyph check passed with three empty boxes on screen.
static func for_touch() -> Array[Binding]:
	return [
			Binding.new(["tap"], "place"),
			Binding.new(["hold"], "remove"),
			Binding.new(["drag"], "turn"),
			Binding.new(["2 fingers"], "slide and zoom"),
			# The buttons down the left are the rest of it. Saying so
			# is the difference between a control somebody finds and
			# one they never look for.
			Binding.new(["Turn", "Tip"], "the part"),
			Binding.new(["Undo", "Redo"], "a step"),
			Binding.new(["edges"], "panels"),
		]

## Which controls the strip carries, named by the key they are pressed
## with so that the verb beside each still comes from the one list below
## — pick the entries, not the words, and the strip cannot come to say
## something the handler does not do.
##
## Six and a pointer, which fits one row at any width worth supporting.
const ON_THE_STRIP := ["click", "right-click", "right-drag", "drag",
	"middle-drag", "scroll"]


## What the strip along the bottom shows: the handful somebody reaches
## for before they have learned anything, and where the rest live.
##
## It used to show all twenty-two, which wrapped to three rows of chips
## permanently across the bottom of the window — a reference, drawn as
## though it were a reminder, over the model. There is somewhere to read
## the whole list now, so this can go back to being what it says at the
## top of this file it is.
static func for_strip() -> Array[Binding]:
	var short: Array[Binding] = []
	for wanted: String in ON_THE_STRIP:
		for binding: Binding in for_keyboard():
			if binding.keys.has(wanted):
				short.append(binding)
				break
	short.append(Binding.new([","], "all controls"))
	return short


## Every binding there is, for the panel that lists them and for
## anything checking that they are all reachable.
##
## Every one, not the ones that fit. The panel is where somebody goes to
## find out what a key does, and nine of the things this app answers to
## were nowhere on it: redo, select all, Delete, Escape, the numbered
## views, shift with the middle button and with the wheel, double-clicks
## and saving. A control that is not listed is one nobody is told about.
static func for_keyboard() -> Array[Binding]:
	var everything: Array[Binding] = []
	_section(everything, "Building", [
		Binding.new(["click"], "place", "place"),
		Binding.new(["right-click"], "remove", "remove"),
		Binding.new(["R"], "rotate, or turn the selection"),
		Binding.new(["T"], "tip on side"),
		Binding.new(["[", "]"], "colour"),
		Binding.new(["C"], "paint", "paint"),
		Binding.new(["G"], "pick"),
		Binding.new(["X"], "lift, or move the selection"),
		Binding.new(["%s-C" % _hold(), "%s-V" % _hold()], "copy, paste"),
		Binding.new(["%s-D" % _hold()], "duplicate"),
		Binding.new(["%s-X" % _hold()], "cut"),
		Binding.new(["shift-M"], "mirror the selection"),
		Binding.new(["J", "shift-J"], "swing the selection on its hinge"),
		Binding.new(["%s-G" % _hold(), "%s-shift-G" % _hold()], "make a sub-model, or leave one"),
		# The command symbol, U+2318, is not in the font this ships, so
		# it drew as an empty box followed by a Z — which has been on
		# screen since the strip was written. Words render everywhere.
		Binding.new(["%s-Z" % _hold()], "undo"),
		Binding.new(["%s-shift-Z" % _hold()], "redo"),
	])
	_section(everything, "Selecting", [
		# Left drags a box. This strip said shift-drag for a while
		# after plain drag started doing it, which is the exact failure
		# the note at the top of this file is about — so the verb comes
		# from the same place the handler gets it.
		Binding.new(["drag"], "box select", "box"),
		Binding.new(["shift-click"], "add to selection", "select"),
		Binding.new(["shift-double-click"], "every brick like it"),
		Binding.new(["%s-A" % _hold()], "select all"),
		Binding.new(["arrows"], "turn the view, or move a selection"),
		Binding.new(["Delete"], "remove the selection"),
		Binding.new(["H"], "hide the selection; with none, show all"),
		Binding.new(["shift-H"], "show only the selection"),
		Binding.new(["alt-H"], "show everything"),
		Binding.new(["V"], "the Select tool; V again, back to Build"),
		Binding.new(["L", "shift-L"], "lock the selection, unlock everything"),
		Binding.new(["Esc"], "out of whatever is open, then back to Build"),
	])
	_section(everything, "The view", [
		# Turn first among the view verbs, because it is the one people
		# reach for and the one that had nothing bound to it.
		Binding.new(["right-drag", "2 fingers"], "turn", "orbit"),
		Binding.new(["middle-drag"], ViewPrefs.middle_verb(),
			"slide" if ViewPrefs.middle_slides else "orbit"),
		# Shift always gives the one the plain middle drag does not, so
		# this row is the other half of the preference.
		Binding.new(["shift-middle-drag"],
			"turn" if ViewPrefs.middle_slides else "slide",
			"orbit" if ViewPrefs.middle_slides else "slide"),
		Binding.new(["middle double-click"], "turn about that point"),
		Binding.new(["shift-2 fingers"], "slide", "slide"),
		Binding.new(["scroll", "pinch", "+", "-"], "zoom", "zoom_in"),
		Binding.new(["shift-scroll"], "slide", "slide"),
		Binding.new(["shift-arrows"], "slide the view", "slide"),
		Binding.new(["Q", "E"], "turn model"),
		Binding.new(["F"], "frame"),
		Binding.new(["U"], "measure between two points"),
		Binding.new(["O"], "square on"),
		Binding.new(["1", "2", "3", "4", "5", "6", "7"],
			"front, back, left, right, top, bottom, three-quarter"),
		Binding.new(["0"], "the usual view"),
	])
	_section(everything, "The timeline", [
		Binding.new(["B"], "timeline"),
		Binding.new(["space"], "play the timeline"),
		Binding.new(["Home", "End"], "its start and end"),
	])
	var rest: Array[Binding] = [
		Binding.new(["P"], "parts"),
		Binding.new(["M"], "minifigure"),
		Binding.new(["Tab"], "panels"),
		Binding.new(["/"], "search"),
		Binding.new([",", "F1"], "this list"),
		Binding.new(["F11"], "full screen"),
		Binding.new(["%s-S" % _hold()], "save"),
	]
	# The page is closed by its tab, so a browser is not told about a
	# key that does nothing there.
	if not OS.has_feature("web"):
		# Ctrl+N is the browser's new window, and never reaches the page.
		rest.append(Binding.new(["%s-N" % _hold()], "new model"))
		rest.append(Binding.new(["%s-Q" % _hold()], "quit"))
	_section(everything, "Panels", rest)
	return everything


static func _section(into: Array[Binding], named: String,
		these: Array) -> void:
	for binding: Binding in these:
		binding.section = named
		into.append(binding)


# -- drawing a control -------------------------------------------------------

## The gestures that are drawn as pictures rather than as keys, by the
## name the lists above use for them: the picture in assets/ui/controls,
## and anything written after it.
const PICTURED := {
	"click": ["mouse_left", ""],
	"double-click": ["mouse_left", "×2"],
	"right-click": ["mouse_right", ""],
	"drag": ["mouse_left_drag", ""],
	"right-drag": ["mouse_right_drag", ""],
	"middle-drag": ["mouse_middle_drag", ""],
	"middle double-click": ["mouse_middle", "×2"],
	"scroll": ["scroll", ""],
	"2 fingers": ["two_fingers", ""],
	"pinch": ["pinch", ""],
	"arrows": ["arrow_keys", ""],
}

## The same, for the list a touchscreen gets, where a drag is a finger.
const PICTURED_BY_TOUCH := {
	"tap": ["tap", ""],
	"hold": ["hold", ""],
	"drag": ["finger_drag", ""],
	"2 fingers": ["two_fingers", ""],
}

## What a key is called on its cap, where the list's own word is not it.
const CAPS := {"space": "Space", "shift": "Shift", "alt": "Alt"}


## The pieces one key of a binding is drawn with, in order: a cap for
## each modifier held, then the gesture's picture or the key's cap.
##
## Returned as [kind, what, after] triples — "cap" with its text, or
## "picture" with the file and anything written after it — so the strip
## and the panel draw the same thing at their own sizes, and a check can
## ask what a control is drawn as without drawing it.
static func pieces(key: String, by_touch: bool = false) -> Array:
	var out: Array = []
	var rest: String = key
	var holding: Array[String] = ["shift", "alt", _hold()]
	var found: bool = true
	while found:
		found = false
		for modifier: String in holding:
			var prefix: String = modifier + "-"
			if rest.length() > prefix.length() and rest.begins_with(prefix):
				out.append(["cap", CAPS.get(modifier, modifier), ""])
				rest = rest.substr(prefix.length())
				found = true
	var pictured: Dictionary = PICTURED_BY_TOUCH if by_touch else PICTURED
	if pictured.has(rest):
		var what: Array = pictured[rest]
		out.append(["picture", Icons.CONTROLS + str(what[0]) + ".svg", what[1]])
	else:
		out.append(["cap", CAPS.get(rest, rest), ""])
	return out


## One key of a binding, drawn: caps and pictures side by side.
##
## [param chipped] puts each picture on a chip of its own, the same dark
## chip a key is drawn on. The strip needs it: it floats over the model,
## and a pale line drawing of a mouse over the pale sky was not there at
## all in the first picture of it. The panel has its own dark ground and
## draws them bare.
static func draw_key(key: String, tall: float, font_size: int,
		density: float, by_touch: bool = false, chipped: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for piece: Array in pieces(key, by_touch):
		if piece[0] == "picture" and chipped:
			var chip := PanelContainer.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			chip.add_theme_stylebox_override("panel", _chip_style(3, 1))
			chip.add_child(Icons.picture(piece[1], tall - 2.0, density))
			row.add_child(chip)
		elif piece[0] == "picture":
			row.add_child(Icons.picture(piece[1], tall, density))
		else:
			row.add_child(cap(piece[1], tall, font_size))
		if not str(piece[2]).is_empty():
			var after := Label.new()
			after.text = piece[2]
			after.add_theme_font_size_override("font_size", font_size)
			after.add_theme_color_override("font_color", Color(0.88, 0.9, 0.94, 0.85))
			after.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(after)
	return row


## A key drawn as a key. The chip's own background is what makes it
## readable over a bright model without an outline. At least as wide as
## it is tall, so a single letter reads as a key and not as a tag.
static func cap(glyph: String, tall: float, font_size: int) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(tall, tall)

	panel.add_theme_stylebox_override("panel", _chip_style(5, 0))

	var label := Label.new()
	label.text = glyph
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


## The dark chip a key, or a picture on the strip, sits on.
static func _chip_style(across: int, down: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.82)
	style.border_color = Color(1, 1, 1, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = across
	style.content_margin_right = across
	style.content_margin_top = down
	style.content_margin_bottom = down + 1
	return style


# -- the strip ---------------------------------------------------------------

## How tall a key or a picture is on the strip, in interface units.
const STRIP_TALL := 18.0


func _ready() -> void:
	add_theme_constant_override("h_separation", 14)
	add_theme_constant_override("v_separation", 4)
	alignment = FlowContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Quieter than the model, but read over any of it: each control sits
	# on a dark pill of its own (see _make), so this need not fade the
	# words into the sky behind them, which it did at 0.72 — grey on the
	# pale grey of the view, well under the contrast text needs.
	modulate = Color(1, 1, 1, 0.92)

	# The pictures are drawn at the density of the screen, and that
	# changes with the window: the canvas is stretched to fit it.
	get_viewport().size_changed.connect(rebuild)
	rebuild()


## Draw the strip again, for when what a control does has changed.
##
## The middle button is the one that can, and a strip built once at
## startup would go on naming the old verb for the rest of the session.
func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var by_touch: bool = TouchTools.wanted()
	var density: float = Icons.density(self)
	for binding: Binding in bindings():
		add_child(_make(binding, density, by_touch))


func _make(binding: Binding, density: float, by_touch: bool) -> Control:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for key: String in binding.keys:
		group.add_child(draw_key(key, STRIP_TALL, 10, density, by_touch, true))

	var verb := Label.new()
	verb.text = binding.verb
	verb.add_theme_font_size_override("font_size", 12)
	verb.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	verb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(verb)

	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.08, 0.09, 0.11, 0.62)
	backing.set_corner_radius_all(10)
	backing.content_margin_left = 6
	backing.content_margin_right = 8
	backing.content_margin_top = 2
	backing.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", backing)
	pill.add_child(group)
	return pill
