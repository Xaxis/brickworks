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
## Everything listed here is bound. A hint that lies is worse than no
## hint, so the bindings live in one table and both the display and the
## handler read from it.
class_name ControlsHint
extends FlowContainer





## What the modifier is called here.
static func _hold() -> String:
	return "Cmd" if OS.get_name() == "macOS" else "Ctrl"


## One control: what to press, and what it does.
class Binding extends RefCounted:
	var keys: PackedStringArray
	var verb: String

	func _init(pressed: Array, does: String) -> void:
		keys = PackedStringArray(pressed)
		verb = does


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
		return [
			Binding.new(["tap"], "place"),
			Binding.new(["hold"], "remove"),
			Binding.new(["drag"], "turn"),
			Binding.new(["2 fingers"], "slide and zoom"),
			# The buttons down the left are the rest of it. Saying so
			# is the difference between a control somebody finds and
			# one they never look for.
			Binding.new(["⟳ ⤿"], "turn and tip the part"),
			Binding.new(["↶ ↷"], "undo"),
			Binding.new(["◀ ▶"], "panels"),
		]

	return [
		Binding.new(["click"], "place"),
		Binding.new(["right-click"], "remove"),
		# Turn first among the view verbs, because it is the one people
		# reach for and the one that had nothing bound to it.
		Binding.new(["right-drag", "2 fingers"], "turn"),
		Binding.new(["shift-2 fingers"], "slide"),
		Binding.new(["scroll", "pinch"], "zoom"),
		Binding.new(["R"], "rotate"),
		Binding.new(["T"], "tip on side"),
		Binding.new(["[", "]"], "colour"),
		Binding.new(["Q", "E"], "turn model"),
		Binding.new(["B"], "steps"),
		Binding.new(["P"], "parts"),
		Binding.new(["C"], "paint"),
		Binding.new(["G"], "pick"),
		Binding.new(["X"], "lift"),
		Binding.new(["shift-click"], "select"),
		Binding.new(["arrows"], "move selection"),
		Binding.new(["Tab"], "panels"),
		Binding.new(["/"], "search"),
		Binding.new(["F"], "frame"),
		Binding.new(["O"], "square on"),
		# The command symbol, U+2318, is not in the font this ships, so
		# it drew as an empty box followed by a Z — which has been on
		# screen since the strip was written. Words render everywhere.
		Binding.new(["%s-Z" % _hold()], "undo"),
	]


func _ready() -> void:
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 4)
	alignment = FlowContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 0.72)

	for binding: Binding in bindings():
		add_child(_make(binding))


func _make(binding: Binding) -> Control:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for key: String in binding.keys:
		group.add_child(_chip(key))

	var verb := Label.new()
	verb.text = binding.verb
	verb.add_theme_font_size_override("font_size", 11)
	verb.add_theme_color_override("font_color", Color(0.88, 0.9, 0.94, 0.85))
	verb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(verb)
	return group


## A key drawn as a key. The chip's own background is what makes it
## readable over a bright model without an outline.
func _chip(glyph: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.82)
	style.border_color = Color(1, 1, 1, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = glyph
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel
