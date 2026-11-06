## A model shared by link, open to look at: /app?view=<id>, which the
## page's shell hands the app as --view=<id>.
##
## The same app, in a read-only mode, rather than a second renderer: the
## model as the builder draws it, turned with the mouse, its steps
## scrubbed on the timeline, the booklet and the parts list as the builder
## makes them. What this adds is the frame round it — the model's name,
## who made it if they said, its part count, and Open in Brickworks — and
## the words for a link that is loading, taken down or wrong.
##
## Build it turns it into a step player for building the model with real
## bricks (BuildMode); the step reached is the one thing the viewer keeps,
## per link, in the browser (BuildSteps.remember).
##
## A link has versions (2026-10-18): publishing again keeps the one
## before. The line under the name says which this is and what changed in
## it ("Version 2: 2 parts added and 2 removed in step 3."), or that it is
## an older one, with the newest a click away. A builder who comes back
## after the model changed is told so when it changed at or before the
## step they reached ("This model changed from step 3"), and offered that
## step; one who had not got that far is left where they were (BuildSteps.
## changed_since).
##
## A version that passed the four tests the app ran as it was published is
## marked Tested beside its name (2026-10-18, api/_tested.js), the four on
## hover and, on a tap, on the version line.
## Comments (2026-10-18): a small count just above the timeline, for the
## step it is on, or for the whole model when it is away or at either end;
## tapped, that step's comments, and a box to add one for somebody who may
## (StepComments). main.gd asks the server for them and sends.
##
## Play (2026-10-19): what moves in the model taken hold of and moved as it
## was built, on the editor's own joints, stops and couplings (Grab): the
## steering by its wheel, a boom on its pin, a door, a gearbox by its input.
## A pill under the bar says what moves ("Moves: steering, boom") and how
## ("Drag a part that moves"; on a touch screen, with a finger), says what a
## drag is doing while it is, and has Reset once something has moved, which
## puts the model back as it was built. Nothing is kept: the model is the
## link's, read-only, and a reload opens it as built. main.gd takes the
## press (_play_press) and works out what moves (Playable).
##
## Its motions (2026-10-20, docs/MOTIONS.md): a model that carries motions
## of its own ("Open the dome", "Extend the telescope") has a button for
## each in the pill, in Reset's face. Pressed, it plays through Grab as the
## builder's Motions panel plays it (main.gd's _play_motion), and stays lit
## while the model stands where it ends; pressed again it plays backwards,
## which takes it back. Reset puts everything back. A drag still moves a
## part as before.
##
## Everything that edits is out of reach from here; main.gd says how
## (_enter_view), and no sign-in is asked for. A visitor who wants the
## model for their own presses Open in Brickworks, which signs them in and
## copies it into their models (/app?copy=<id>).
class_name ShareView
extends Control

signal steps_wanted
## Build it: the step player (BuildMode), to build the model from.
signal build_wanted
signal booklet_wanted
signal parts_wanted
signal copy_wanted
## The newest version, from an older one's version line.
signal newest_wanted
## Build it from [param page]: the step a changed model is offered from.
signal build_from(page: int)
## Reset: what was moved put back as it was built.
signal reset_wanted
## A motion's button: [param name] played, or played backwards when it
## stands where it ends.
signal motion_wanted(name: String)

## loading, parts, ready, gone, failed.
var state: String = "loading"
var model_name: String = ""
var author: String = ""
var parts: int = 0
var link: String = ""
## What the model was remixed from, while that is still shared: {id,
## name, url} (api/share.js), or empty. Said on the about line, which
## then opens that model's link.
var remixed_from: Dictionary = {}
## Which version of the link is open, and how many it has (1 for a link
## with one, or from before versions were kept).
var version: int = 1
var newest: int = 1
var version_said: String = ""
## The Tested mark this version passed (show_tested), or empty.
var tested: Dictionary = {}
## How many devices have built it to its last step (api/share.js ?op=built),
## said on the about line once there is one; -1 not known.
var builds: int = -1
## This run's finish of it, as Main counts it: {sent, counted, builds}.
var built: Dictionary = {"sent": 0, "counted": false, "builds": -1}
var _tested: Button
## The step a builder's place was changed from, while they are told so;
## 0 when it holds.
var changed_from: int = 0
var _kept_at: int = 0

var _bar: PanelContainer
var _name: Label
var _about: Label
var _version: Label
var _place: PanelContainer
var _place_words: Label
var _place_go: Button
var _place_keep: Button
var _steps: Button
var _build: Button
var _booklet: Button
var _parts: Button
var _copy: Button
var _card: PanelContainer
var _card_title: Label
var _card_words: Label
var _card_button: Button
var _card_action: Callable = Callable()
var _hover: Label
## Build it on a phone or a tablet: a big button over the model, above the
## timeline, where the bar's is a word a few points tall (the interface is
## drawn at about two units to the point there). [member floor_at] says how
## far down it may come: the top of the timeline.
var _big: Button
var _narrow: bool = false
var floor_at: Callable = Callable()
## The comments on the step the timeline is on (StepComments): its count
## sits just above the timeline, at the left.
var comments: StepComments
## Play: what moves (Playable's words), whether it is ready to be dragged,
## whether anything has been moved since it was built (and Reset is up),
## and whether this is a touch screen, which is told to use a finger.
var play_moves: PackedStringArray = PackedStringArray()
var play_ready: bool = false
var played: bool = false
var touch: bool = false
var _play: PanelContainer
var _play_title: Label
var _play_words: Label
var _play_reset: Button
var _play_said: String = ""
## The model's own motions, by name, a button each; those standing where
## they end (played and not taken back), by name in lower case.
var play_motions: PackedStringArray = PackedStringArray()
var motions_out: Dictionary = {}
var _motion_row: HFlowContainer
var _motion_buttons: Array[Button] = []
var _play_pt: float = 1.0
var _play_narrow: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bar()
	_build_card()
	_build_place()
	_build_play()
	_build_party()
	_hover = Label.new()
	_hover.add_theme_font_size_override("font_size", 12)
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.06, 0.07, 0.09, 0.86)
	pill.set_corner_radius_all(4)
	pill.content_margin_left = 7
	pill.content_margin_right = 7
	pill.content_margin_top = 2
	pill.content_margin_bottom = 3
	_hover.add_theme_stylebox_override("normal", pill)
	_hover.visible = false
	add_child(_hover)
	_big = Button.new()
	_big.text = "Build it"
	_big.tooltip_text = _build.tooltip_text
	_big.focus_mode = Control.FOCUS_NONE
	_big.visible = false
	_big.pressed.connect(func() -> void: build_wanted.emit())
	add_child(_big)
	comments = StepComments.new()
	comments.prefix = "view"
	add_child(comments)
	# Between the bar and the timeline: where the model is seen.
	comments.area = func() -> Rect2:
		var top: float = _bar.get_global_rect().end.y if _bar.is_visible_in_tree() else 0.0
		var bottom: float = size.y
		if floor_at.is_valid():
			bottom = minf(float(floor_at.call()), size.y)
		return Rect2(0.0, top, size.x, maxf(bottom - top, 1.0))
	comments.pill.visibility_changed.connect(func() -> void:
		set_process(true))
	get_viewport().size_changed.connect(_fit_big)
	_fit_big()


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.10, 0.12, 0.95)
	backing.border_color = Color(1, 1, 1, 0.10)
	backing.border_width_bottom = 1
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 8
	backing.content_margin_bottom = 8
	_bar.add_theme_stylebox_override("panel", backing)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_bar.add_child(row)

	var home := Look.link("Brickworks", 13)
	home.tooltip_text = "Brickworks: design LEGO® models in your browser"
	home.pressed.connect(func() -> void: Outside.open_link(Deployment.api_base() + "/"))
	home.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(home)

	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.clip_contents = true
	row.add_child(words)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 8)
	words.add_child(title)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 16)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text = "A shared model"
	# Small and green, before the name, for a version that passed: after a
	# name that trims to fit, it went to the far end of the bar.
	_tested = Button.new()
	_tested.text = "Tested"
	_tested.focus_mode = Control.FOCUS_NONE
	_tested.add_theme_font_size_override("font_size", 11)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_tested.add_theme_color_override(colour, Color(0.45, 0.85, 0.5))
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(0.45, 0.85, 0.5, 0.12)
	badge.border_color = Color(0.45, 0.85, 0.5, 0.8)
	badge.set_border_width_all(1)
	badge.set_corner_radius_all(8)
	badge.content_margin_left = 7
	badge.content_margin_right = 7
	badge.content_margin_top = 1
	badge.content_margin_bottom = 1
	for look: String in ["normal", "hover", "pressed"]:
		_tested.add_theme_stylebox_override(look, badge)
	_tested.visible = false
	_tested.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A tap says the four on the version line, where a phone has no hover.
	_tested.pressed.connect(func() -> void:
		_version.visible = true
		_version.modulate = Color(0.6, 0.95, 0.65)
		_version.text = _tested.tooltip_text)
	title.add_child(_tested)
	title.add_child(_name)
	_about = Label.new()
	_about.add_theme_font_size_override("font_size", 12)
	_about.modulate = Color(1, 1, 1, 0.7)
	_about.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# A link only when it says what the model was remixed from: a line
	# that trims to fit, where a link button of its own would push the
	# bar's buttons off a phone.
	_about.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_about.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
				and not str(remixed_from.get("url", "")).is_empty():
			Outside.open_link(str(remixed_from["url"])))
	words.add_child(_about)
	# Which version, and what changed in it; on an older one, the way to
	# the newest.
	_version = Label.new()
	_version.add_theme_font_size_override("font_size", 12)
	_version.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_version.visible = false
	_version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_version.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and version < newest:
			newest_wanted.emit())
	words.add_child(_version)

	# First, and bright: on a phone beside a pile of bricks it is what the
	# link was opened for.
	_build = _button(row, "Build it", "Build it with real bricks: one step at a time, "
		+ "full screen, the parts for each step shown")
	_build.pressed.connect(func() -> void: build_wanted.emit())
	for state: String in ["normal", "hover", "pressed"]:
		var lit := StyleBoxFlat.new()
		lit.bg_color = {"normal": Color(0.98, 0.78, 0.12), "hover": Color(1.0, 0.85, 0.3),
			"pressed": Color(0.9, 0.7, 0.08)}[state]
		lit.set_corner_radius_all(5)
		lit.content_margin_left = 12
		lit.content_margin_right = 12
		lit.content_margin_top = 5
		lit.content_margin_bottom = 5
		_build.add_theme_stylebox_override(state, lit)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_build.add_theme_color_override(state, Color(0.1, 0.08, 0.02))
	_steps = _button(row, "Steps", "Step through the build (B)")
	_steps.pressed.connect(func() -> void: steps_wanted.emit())
	_booklet = _button(row, "Booklet", "The building instructions, page by page, to read or print")
	_booklet.pressed.connect(func() -> void: booklet_wanted.emit())
	_parts = _button(row, "Parts list", "Every part, with BrickLink and Rebrickable lists (P)")
	_parts.pressed.connect(func() -> void: parts_wanted.emit())
	_copy = _button(row, "Open in Brickworks",
		"Sign in and get a copy of your own to change — the shared one stays as it is")
	var bright := StyleBoxFlat.new()
	bright.bg_color = Color(0.78, 0.06, 0.18)
	bright.set_corner_radius_all(5)
	bright.content_margin_left = 12
	bright.content_margin_right = 12
	bright.content_margin_top = 5
	bright.content_margin_bottom = 5
	_copy.add_theme_stylebox_override("normal", bright)
	var lit: StyleBoxFlat = bright.duplicate()
	lit.bg_color = Color(0.88, 0.14, 0.26)
	_copy.add_theme_stylebox_override("hover", lit)
	_copy.add_theme_stylebox_override("pressed", lit)
	_copy.pressed.connect(func() -> void: copy_wanted.emit())
	for button: Button in [_build, _steps, _booklet, _parts, _copy]:
		button.disabled = true


func _button(row: Container, words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_face(button)
	row.add_child(button)
	return button


## A face of its own, as the timeline's buttons have: drawn flat, the bar
## read as a line of words and not as things to press.
static func _face(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(1, 1, 1, {"normal": 0.08, "hover": 0.16, "pressed": 0.24,
			"disabled": 0.03}[state])
		face.border_color = Color(1, 1, 1, 0.16)
		face.set_border_width_all(1)
		face.set_corner_radius_all(5)
		face.content_margin_left = 12
		face.content_margin_right = 12
		face.content_margin_top = 5
		face.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, face)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.custom_minimum_size = Vector2(420, 0)
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.97)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 22
	backing.content_margin_right = 22
	backing.content_margin_top = 18
	backing.content_margin_bottom = 18
	_card.add_theme_stylebox_override("panel", backing)
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 17)
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A width to wrap at: measured before layout, a label counts every word
	# as a line and the card came out taller than the window.
	_card_title.custom_minimum_size = Vector2(376, 0)
	column.add_child(_card_title)
	_card_words = Label.new()
	_card_words.custom_minimum_size = Vector2(376, 0)
	_card_words.add_theme_font_size_override("font_size", 13)
	_card_words.modulate = Color(1, 1, 1, 0.75)
	_card_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_card_words)
	_card_button = Button.new()
	_card_button.focus_mode = Control.FOCUS_NONE
	_card_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_face(_card_button)
	_card_button.pressed.connect(func() -> void:
		if _card_action.is_valid():
			_card_action.call())
	column.add_child(_card_button)


## What a builder is told when the model changed at or before the step
## they reached: under the bar, with the step it changed from offered, and
## their own kept if they would rather.
func _build_place() -> void:
	_place = PanelContainer.new()
	_place.visible = false
	_place.mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.16, 0.13, 0.05, 0.96)
	backing.border_color = Color(0.98, 0.78, 0.12, 0.7)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 9
	backing.content_margin_bottom = 9
	_place.add_theme_stylebox_override("panel", backing)
	add_child(_place)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_place.add_child(row)
	_place_words = Label.new()
	_place_words.add_theme_font_size_override("font_size", 13)
	_place_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place_words.custom_minimum_size = Vector2(300, 0)
	_place_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_place_words)
	_place_go = _button(row, "Build from step 1", "Build it from the step it changed at")
	_place_go.pressed.connect(func() -> void:
		var page: int = changed_from
		hide_place()
		build_from.emit(page))
	_place_keep = _button(row, "Keep my step", "Carry on from where you were")
	_place_keep.pressed.connect(hide_place)


## The play pill: what moves, how to move it, and Reset. Under the bar at
## the left, out of the way of the big Build it and the comments' count,
## which are above the timeline.
func _build_play() -> void:
	_play = PanelContainer.new()
	_play.visible = false
	_play.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_play)
	# What moves, and Reset beside it; how to move it, or what the drag is
	# doing, under both. Reset on the first line keeps the pill narrow: on a
	# phone, beside the words, it reached over the view cube.
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	_play.add_child(words)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	words.add_child(head)
	_play_title = Label.new()
	_play_title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.12))
	_play_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_play_title)
	# The model's own motions, a button each, wrapping as the words do.
	_motion_row = HFlowContainer.new()
	_motion_row.visible = false
	words.add_child(_motion_row)
	_play_words = Label.new()
	_play_words.modulate = Color(1, 1, 1, 0.8)
	_play_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_play_words)
	_play_reset = Button.new()
	_play_reset.text = "Reset"
	_play_reset.tooltip_text = "Put everything back as it was built"
	_play_reset.focus_mode = Control.FOCUS_NONE
	_play_reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_play_reset.visible = false
	_face(_play_reset)
	_play_reset.pressed.connect(func() -> void: reset_wanted.emit())
	head.add_child(_play_reset)
	_fit_play(1.0, false)


## The pill's faces and words at [param pt] pixels to the point: a phone's
## interface is drawn at about two units to the point, and words of the
## bar's size there are a few points tall.
func _fit_play(pt: float, narrow: bool) -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.10, 0.12, 0.92)
	backing.border_color = Color(0.98, 0.78, 0.12, 0.45)
	backing.set_border_width_all(maxi(1, roundi(pt)))
	backing.set_corner_radius_all(roundi(8.0 * pt))
	backing.content_margin_left = 12.0 * pt
	backing.content_margin_right = 10.0 * pt
	backing.content_margin_top = 6.0 * pt
	backing.content_margin_bottom = 7.0 * pt
	_play.add_theme_stylebox_override("panel", backing)
	var points: float = 14.0 if narrow else 13.0
	_play_title.add_theme_font_size_override("font_size", roundi(points * pt))
	_play_words.add_theme_font_size_override("font_size", roundi((points - 1.0) * pt))
	_play_reset.add_theme_font_size_override("font_size", roundi(points * pt))
	_play_reset.custom_minimum_size = Vector2(0.0, roundi((34.0 if narrow else 0.0) * pt))
	# Words wrap at most this wide: 380 points on a wide window; on a phone,
	# its width less the view cube's corner (about 150 points) and the
	# gutters, so the pill never covers the cube.
	var room: float = size.x - (180.0 if narrow else 24.0) * pt if size.x > 0.0 else 600.0
	_play_words.custom_minimum_size = Vector2(clampf(room, 140.0 * pt, 380.0 * pt), 0.0)
	_play_pt = pt
	_play_narrow = narrow
	_motion_row.custom_minimum_size = Vector2(_play_words.custom_minimum_size.x, 0.0)
	_motion_row.add_theme_constant_override("h_separation", roundi(6.0 * pt))
	_motion_row.add_theme_constant_override("v_separation", roundi(6.0 * pt))
	for button: Button in _motion_buttons:
		_fit_motion(button)
	_play.reset_size()


## A motion's button at the pill's size: Reset's face and words, a finger's
## height on a phone, and the title's yellow while it stands where it ends.
func _fit_motion(button: Button) -> void:
	var points: float = 14.0 if _play_narrow else 13.0
	button.add_theme_font_size_override("font_size", roundi(points * _play_pt))
	button.custom_minimum_size = Vector2(0.0, roundi((34.0 if _play_narrow else 0.0) * _play_pt))
	for colour: String in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(colour, Color(0.98, 0.78, 0.12))


## What moves, now that its joints are read: [param moves] Playable's words
## ("steering", "boom"), empty when nothing has a name but parts still move;
## [param any] whether anything moves at all. Nothing is said when nothing
## does.
func show_play(moves: PackedStringArray, any: bool, on_touch: bool) -> void:
	play_moves = moves
	play_ready = any
	touch = on_touch
	_say_play()
	_fit_big()


## The model's own motions, by [param names]: a button each, in the order
## the file has them; none for a model without. Each stands as built.
func show_motions(names: PackedStringArray) -> void:
	play_motions = names
	motions_out.clear()
	for button: Button in _motion_buttons:
		button.queue_free()
	_motion_buttons.clear()
	for name: String in names:
		var button := Button.new()
		button.text = name
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Play “%s”" % name
		_face(button)
		_fit_motion(button)
		button.pressed.connect(func() -> void:
			# Lit or not as the model stands, which main.gd says once it plays.
			button.set_pressed_no_signal(motions_out.has(name.to_lower()))
			motion_wanted.emit(name))
		_motion_row.add_child(button)
		_motion_buttons.append(button)
	if not names.is_empty():
		play_ready = true
	_say_play()
	_fit_big()


## [param name] stands where it ends ([param out]: its button lit, and
## pressed again it plays backwards), or back where it began.
func show_motion_out(name: String, out: bool) -> void:
	if out:
		motions_out[name.to_lower()] = true
	else:
		motions_out.erase(name.to_lower())
	for button: Button in _motion_buttons:
		if button.text == name:
			button.set_pressed_no_signal(out)
			button.tooltip_text = ("Play “%s” backwards: put it back" if out else "Play “%s”") % name


## Every motion back where it began: Reset.
func motions_home() -> void:
	for name: String in play_motions:
		show_motion_out(name, false)


func _hint() -> String:
	if not play_motions.is_empty():
		if touch:
			return "Tap one to play it, and again to put it back. Or touch a part that moves and drag it."
		return "Press one to play it, and again to put it back. Or drag a part that moves."
	if touch:
		return "Touch a part that moves and drag it. Drag anywhere else to turn the model."
	return "Drag a part that moves. Drag anywhere else to turn the model."


func _say_play() -> void:
	if not play_motions.is_empty():
		_play_title.text = "Play its motions"
	else:
		_play_title.text = Playable.words(play_moves) if not play_moves.is_empty() else "Parts of it move"
	_motion_row.visible = not play_motions.is_empty()
	_play_words.text = _play_said if not _play_said.is_empty() else _hint()
	_play_reset.visible = played
	_play.reset_size()


## Whether the pill has something to offer: what moves, by name (Playable),
## the model's own motions, or a drag being made or made. A part that only
## turns on its joint, a wheel on its pin or a flag on its clip, can still
## be taken hold of, but is not offered: the castle, whose card says nothing
## moves, said "Parts of it move" (walk180 W5).
func _offers_play() -> bool:
	return not play_moves.is_empty() or not play_motions.is_empty() or played or not _play_said.is_empty()


## What a drag is doing, said in the pill while it is ("" for the hint).
func play_said(words: String) -> void:
	_play_said = words
	if _play != null:
		_say_play()
		_show_pill()


## Something has moved since it was built ([param yes]): Reset is offered.
func show_played(yes: bool) -> void:
	played = yes
	_say_play()
	_show_pill()


## The pill shown or put away when what it offers changes, not every frame
## a drag says something.
func _show_pill() -> void:
	if _play != null and _play.visible != (state == "ready" and _bar.visible and play_ready and _offers_play()):
		_fit_big()


## Tell a builder who had reached step [param at] that the model changed
## from step [param from], and offer it.
func tell_changed(from: int, at: int) -> void:
	changed_from = from
	_kept_at = at
	_place_words.text = "This model changed from step %d since you were on step %d." % [from, at]
	_place_go.text = "Build from step %d" % from
	_place_keep.text = "Keep step %d" % at
	_place.visible = true
	_place.reset_size()
	set_process(true)


func hide_place() -> void:
	changed_from = 0
	_place.visible = false


func _say(title: String, words: String, button: String = "", action: Callable = Callable()) -> void:
	_card.visible = true
	_card_title.text = title
	_card_words.text = words
	_card_words.visible = not words.is_empty()
	_card_button.text = button
	_card_button.visible = not button.is_empty()
	_card_action = action
	# Sized to what it now says, and kept in the middle.
	_card.reset_size()
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func loading() -> void:
	state = "loading"
	_say("Opening the shared model…", "")


func arriving(left: int) -> void:
	state = "parts"
	_say("Fetching its parts…", "%d still on their way." % left)


## The model is open: its name and the rest along the top, and what it
## was remixed from if it was ([param from]: {id, name, url}).
func show_model(shown_name: String, shown_author: String, part_count: int, at: String,
		from: Dictionary = {}) -> void:
	model_name = shown_name
	author = shown_author
	parts = part_count
	link = at
	remixed_from = from if not str(from.get("url", "")).is_empty() else {}
	_name.text = shown_name
	_say_about()
	var linked: bool = not remixed_from.is_empty()
	_about.mouse_filter = Control.MOUSE_FILTER_STOP if linked else Control.MOUSE_FILTER_IGNORE
	_about.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if linked else Control.CURSOR_ARROW
	_about.tooltip_text = ("Open “%s”, the model this one was remixed from" % remixed_from.get("name", "")
		if linked else "")


## The about line: the parts, who made it, how many have built it, and
## what it was remixed from.
func _say_about() -> void:
	_about.text = "%s part%s%s%s%s" % [_count(parts), "" if parts == 1 else "s",
		(" · by " + author) if not author.is_empty() else "",
		(" · %s built" % _count(builds)) if builds > 0 else "",
		(" · remixed from " + str(remixed_from.get("name", ""))) if not remixed_from.is_empty() else ""]


## How many devices have built it to its last step, as the server said.
func show_builds(count: int) -> void:
	builds = count
	if not model_name.is_empty():
		_say_about()


## Which version of the link this is ([param shown] of [param last]), and
## what the server said changed in it.
func show_version(shown: int, last: int, said: String) -> void:
	version = maxi(shown, 1)
	newest = maxi(last, version)
	version_said = said
	_version.visible = newest > 1
	var old: bool = version < newest
	_version.text = ("Version %d of %d, an older one. Open the newest" % [version, newest]) if old \
		else (said if not said.is_empty() else "Version %d" % version)
	_version.modulate = Color(1.0, 0.86, 0.45) if old else Color(1, 1, 1, 0.7)
	_version.mouse_filter = Control.MOUSE_FILTER_STOP if old else Control.MOUSE_FILTER_IGNORE
	_version.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if old else Control.CURSOR_ARROW
	_version.tooltip_text = ("Open version %d, the newest" % newest) if old else ""


## The Tested mark, for a version that passed the four tests the app ran
## as it was published ({said, app, steps}, api/_tested.js): a small mark
## beside the name, the four on hover, or on a tap, which says them on the
## version line. Nothing for any other version.
func show_tested(mark: Dictionary) -> void:
	tested = mark if bool(mark.get("tested", false)) else {}
	_tested.visible = not tested.is_empty()
	var said: Array = tested.get("said", []) if tested.get("said") is Array else []
	_tested.tooltip_text = ("%s. Worked out by the Brickworks app %s as it was published, from its own steps."
		% [" · ".join(PackedStringArray(said.map(func(one: Variant) -> String: return str(one)))),
			str(tested.get("app", ""))]) if not tested.is_empty() else ""


func ready_to_look() -> void:
	state = "ready"
	_card.visible = false
	for button: Button in [_build, _steps, _booklet, _parts, _copy, _party_bar]:
		button.disabled = false
	_fit_big()


## The big Build it, sized in points, on a window under [constant NARROW]
## points across; the bar's own on a wider one.
const NARROW := 1040.0


func _fit_big() -> void:
	if _big == null or not is_inside_tree():
		return
	var across: float = Room.across()
	_narrow = across > 0.0 and across < NARROW
	var pt: float = get_viewport().get_visible_rect().size.x / across if across > 0.0 else 1.0
	for face: String in ["normal", "hover", "pressed"]:
		var lit := StyleBoxFlat.new()
		lit.bg_color = {"normal": Color(0.98, 0.78, 0.12), "hover": Color(1.0, 0.85, 0.3),
			"pressed": Color(0.9, 0.7, 0.08)}[face]
		lit.set_corner_radius_all(roundi(26.0 * pt))
		lit.content_margin_left = 26.0 * pt
		lit.content_margin_right = 26.0 * pt
		lit.shadow_color = Color(0, 0, 0, 0.35)
		lit.shadow_size = roundi(6.0 * pt)
		_big.add_theme_stylebox_override(face, lit)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_big.add_theme_color_override(colour, Color(0.1, 0.08, 0.02))
	_big.add_theme_font_size_override("font_size", roundi(22.0 * pt))
	_big.custom_minimum_size = Vector2(0, 52.0 * pt)
	_big.reset_size()
	var ready: bool = state == "ready" and _bar.visible
	_big.visible = _narrow and ready
	_build.visible = not _narrow and state != "gone"
	# Words a phone can read on a phone; the bar's size on a wide window.
	comments.fit(pt if _narrow else 1.0, 14.0 if _narrow else 12.0)
	comments.pill.reset_size()
	if not ready and comments.is_open():
		comments.close()
	comments.visible = ready
	_play.visible = ready and play_ready and _offers_play()
	_fit_play(pt if _narrow else 1.0, _narrow)
	_party_bar.visible = not _narrow and state != "gone"
	_party_pill.visible = _big.visible
	_fit_party()
	set_process(_big.visible or (_place != null and _place.visible) or _pill_shown() or _play.visible
		or _party_card.visible)
	# Placed now, not next frame: shown, Build it was drawn and told to the
	# page for a frame where it was last, the window's corner the first time.
	_lay_out()


func _process(_delta: float) -> void:
	_lay_out()


## Where everything over the model goes: every frame while any of it is up,
## as the bar and the timeline come and go.
func _lay_out() -> void:
	var below: float = _bar.get_global_rect().end.y + 10.0 if _bar.is_visible_in_tree() else 10.0
	if _place.visible:
		# Just under the bar, in the middle.
		_place.position = Vector2(maxf((size.x - _place.size.x) * 0.5, 6.0), below)
	if _play.visible:
		# Under the bar at the left, below the changed model's words if
		# they are up.
		var top: float = _place.position.y + _place.size.y + 8.0 if _place.visible else below
		var at := Vector2(10.0, top)
		if _play.position != at:
			_play.position = at
		if _play.size != _play.get_combined_minimum_size():
			_play.reset_size()
	var bottom: float = size.y
	if floor_at.is_valid():
		bottom = minf(float(floor_at.call()), size.y)
	if _pill_shown():
		# Just above the timeline, at the left: the big Build it of a phone
		# is in the middle.
		var gap: float = comments.pill.size.y * 0.3
		var at := Vector2(gap, bottom - comments.pill.size.y - gap)
		if comments.pill.position != at:
			comments.pill.position = at
	_lay_party(bottom)
	if not _big.visible:
		if not _place.visible and not _pill_shown() and not _play.visible and not _party_card.visible:
			set_process(false)
		return
	# Build together's pill beside it, the two together in the middle.
	var beside: float = _party_pill.size.x + _big.size.y * 0.2 if _party_pill.visible else 0.0
	var spot := Vector2((size.x - _big.size.x - beside) * 0.5, bottom - _big.size.y - _big.size.y * 0.35)
	if _big.position != spot:
		_big.position = spot
	_lay_party_pill()


## Whether the count is up: once the model is ready, and the bar with it.
func _pill_shown() -> bool:
	return comments != null and comments.visible and comments.pill.visible and state == "ready" \
		and _bar.visible


func gone(title: String, words: String) -> void:
	state = "gone"
	_name.text = title
	_about.text = ""
	# Nothing to step through, read or copy.
	for button: Button in [_build, _steps, _booklet, _parts, _copy, _party_bar]:
		button.visible = false
	comments.show_answer({})
	_fit_big()
	_say(title, words, "Go to Brickworks",
		func() -> void: Outside.open_link(Deployment.api_base() + "/"))


func failed(words: String, again: Callable) -> void:
	state = "failed"
	_say("This model did not open", words, "Try again", again)


## Name the part under the pointer beside it, or nothing.
func hover(words: String, at: Vector2) -> void:
	_hover.visible = not words.is_empty()
	if not _hover.visible:
		return
	_hover.text = words
	_hover.reset_size()
	var spot: Vector2 = at + Vector2(16, 18)
	spot.x = minf(spot.x, size.x - _hover.size.x - 6.0)
	spot.y = minf(spot.y, size.y - _hover.size.y - 6.0)
	_hover.position = spot


## The bar along the top, put at the head of [param column] in place of
## the builder's own bars, so the model's view starts below it.
func put_bar_in(column: Control) -> void:
	column.add_child(_bar)
	column.move_child(_bar, 0)


static func _count(n: int) -> String:
	var digits: String = str(n)
	var out: String = ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += ","
		out += digits[index]
	return out


## The bar along the top, out of sight while the step player has the
## window, and back after.
func show_bar(yes: bool) -> void:
	_bar.visible = yes
	_fit_big()


func covers(point: Vector2) -> bool:
	return (_bar.is_visible_in_tree() and _bar.get_global_rect().has_point(point)) \
		or (_place.is_visible_in_tree() and _place.get_global_rect().has_point(point)) \
		or (_card.is_visible_in_tree() and _card.get_global_rect().has_point(point)) \
		or (_big.is_visible_in_tree() and _big.get_global_rect().has_point(point)) \
		or (_play.is_visible_in_tree() and _play.get_global_rect().has_point(point)) \
		or (_party_card.visible and _party_card.get_global_rect().has_point(point)) \
		or (_party_pill.is_visible_in_tree() and _party_pill.get_global_rect().has_point(point)) \
		or (_pill_shown() and comments.covers(point))


func controls_by_name() -> Dictionary:
	var named: Dictionary = {"view_build": _big if _big.visible else _build,
		"view_steps": _steps, "view_booklet": _booklet,
		"view_parts": _parts, "view_copy": _copy}
	if _card.visible and _card_button.visible:
		named["view_card_button"] = _card_button
	if not remixed_from.is_empty() and _about.is_visible_in_tree():
		named["view_remixed_from"] = _about
	if version < newest and _version.is_visible_in_tree():
		named["view_newest"] = _version
	if _place.is_visible_in_tree():
		named["view_build_from"] = _place_go
		named["view_keep_place"] = _place_keep
	if _pill_shown():
		named.merge(comments.controls_by_name())
	if _play.is_visible_in_tree():
		named["view_play"] = _play
		if _play_reset.visible:
			named["view_reset"] = _play_reset
		for n: int in _motion_buttons.size():
			named["view_motion_%d" % (n + 1)] = _motion_buttons[n]
	_party_controls(named)
	return named


func page_state() -> Dictionary:
	return {"state": state, "name": model_name, "author": author, "parts": parts,
		"link": link, "about": _about.text, "remixed_from": str(remixed_from.get("name", "")),
		"title": _card_title.text if _card.visible else "",
		"says": _card_words.text if _card.visible else "", "hover": _hover.text if _hover.visible else "",
		"version": version, "newest": newest, "version_line": _version.text if _version.visible else "",
		"changed_from": changed_from, "place_says": _place_words.text if _place.visible else "",
		"tested": _tested.visible, "tested_says": _tested.tooltip_text,
		"built": built.duplicate(), "builds": builds,
		"comment_step": comments.step,
		"play": {"ready": play_ready, "shown": _play.is_visible_in_tree(), "moves": Array(play_moves),
			"title": _play_title.text, "says": _play_words.text, "played": played,
			"reset": _play_reset.is_visible_in_tree(), "touch": touch,
			"motions": Array(play_motions), "motions_out": Array(play_motions).filter(
				func(name: String) -> bool: return motions_out.has(name.to_lower()))},
		"party": _party_state()}.merged(
			comments.page_state() if _pill_shown()
			else {"comments": 0, "comments_open": false, "comments_shown": [], "comments_where": [],
				"comment_why_not": "",
				"comment_can_write": false, "comment_said": "", "comment_pill": ""})


# -- Build together: a build party (APP_UX5 buildparty, 2026-11-06) ----------
#
# Several phones build this model together (BuildParty): Build together
# beside Build it (on a phone, a pill beside the big one) opens a card over
# the model. Start a build gives a four-letter code; on another phone, Build
# together, the code and Join. Everyone's name is in the card, each in its
# seat's colour, and the phone that started deals the model out with Start
# building; each phone's Build it opens on its own share at once (main.gd).
# A name is optional ("Builder 2"). Closed mid-build, the card offers the
# way back and Leave; a phone that left joins again with the code kept.

## Build together pressed: main.gd makes the party and shows it here.
signal party_wanted
signal party_start_wanted(as_name: String)
signal party_join_wanted(with_code: String, as_name: String)
signal party_deal_wanted
signal party_leave_wanted
## Back to building its share, after Build it was closed.
signal party_back_wanted

var _party_bar: Button
var _party_pill: Button
var _party_card: PanelContainer
var _party_title: Label
var _party_words: Label
var _party_name: LineEdit
var _party_start: Button
var _party_join_row: HBoxContainer
var _party_code: LineEdit
var _party_join: Button
var _party_seats: VBoxContainer
var _party_deal: Button
var _party_back: Button
var _party_leave: Button
var _party_close: Button
var _party_trouble: Label
## The party as last shown (BuildParty.page_state), and whether a request
## is on its way (its buttons wait).
var _party_said: Dictionary = {}
var _party_busy: bool = false
var _party_pt: float = 1.0


func _build_party() -> void:
	_party_bar = _button(_build.get_parent(), "Build together",
		"Build it with others, each on their own phone: a code to join by, the model dealt out")
	_build.get_parent().move_child(_party_bar, _build.get_index() + 1)
	_party_bar.pressed.connect(func() -> void: party_wanted.emit())
	_party_bar.disabled = true
	_party_pill = Button.new()
	_party_pill.text = "Build together"
	_party_pill.tooltip_text = _party_bar.tooltip_text
	_party_pill.focus_mode = Control.FOCUS_NONE
	_party_pill.visible = false
	_party_pill.pressed.connect(func() -> void: party_wanted.emit())
	add_child(_party_pill)
	_party_card = PanelContainer.new()
	_party_card.visible = false
	_party_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_party_card)
	var column := VBoxContainer.new()
	column.name = "Column"
	_party_card.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	_party_title = Label.new()
	_party_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_party_title)
	_party_close = _party_button(head, "Close", "Put this away: the build goes on")
	_party_close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_party_close.pressed.connect(hide_party)
	_party_words = Label.new()
	_party_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_party_words.modulate = Color(1, 1, 1, 0.78)
	column.add_child(_party_words)
	_party_name = LineEdit.new()
	_party_name.placeholder_text = "Your name (you can leave it out)"
	_party_name.max_length = 20
	column.add_child(_party_name)
	_party_start = _party_button(column, "Start a build", "Start one and get a code for the others")
	_party_start.pressed.connect(func() -> void:
		_party_busy = true
		_fit_party()
		party_start_wanted.emit(_party_name.text))
	_party_join_row = HBoxContainer.new()
	column.add_child(_party_join_row)
	_party_code = LineEdit.new()
	_party_code.placeholder_text = "Code"
	_party_code.max_length = 9
	_party_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_code.text_changed.connect(func(said: String) -> void:
		var upper: String = said.to_upper()
		if upper != said:
			var at: int = _party_code.caret_column
			_party_code.text = upper
			_party_code.caret_column = at)
	_party_code.text_submitted.connect(func(_said: String) -> void: _party_join_pressed())
	_party_join_row.add_child(_party_code)
	_party_join = _party_button(_party_join_row, "Join", "Join the build with the code another phone shows")
	_party_join.pressed.connect(_party_join_pressed)
	_party_seats = VBoxContainer.new()
	column.add_child(_party_seats)
	_party_deal = _party_button(column, "Start building", "Deal the model out to everyone in it now")
	_party_deal.pressed.connect(func() -> void:
		_party_busy = true
		_fit_party()
		party_deal_wanted.emit())
	_party_back = _party_button(column, "Back to building", "Your share, where you were")
	_party_back.pressed.connect(func() -> void: party_back_wanted.emit())
	_party_leave = _party_button(column, "Leave the build", "The others are told; the code stays here to join again")
	_party_leave.pressed.connect(func() -> void: party_leave_wanted.emit())
	_party_trouble = Label.new()
	_party_trouble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_party_trouble.modulate = Color(1.0, 0.62, 0.55)
	column.add_child(_party_trouble)


func _party_button(row: Container, words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_face(button)
	row.add_child(button)
	return button


func _party_join_pressed() -> void:
	if _party_code.text.strip_edges().is_empty():
		return
	_party_busy = true
	_fit_party()
	party_join_wanted.emit(_party_code.text, _party_name.text)


## The party card up, saying [param said] (BuildParty.page_state); [param
## building] whether this phone's share is dealt and Build it is closed.
func show_party(said: Dictionary, code_wanted: String = "") -> void:
	_party_said = said
	_party_busy = false
	if not code_wanted.is_empty() and not bool(said.get("live", false)):
		_party_code.text = code_wanted.to_upper()
	elif _party_code.text.is_empty() and not str(said.get("code", "")).is_empty():
		_party_code.text = str(said["code"])
	if _party_name.text.is_empty():
		_party_name.text = str(said.get("name", ""))
	_party_card.visible = true
	_say_party()


## The party as it is now, while the card is up.
func party_changed(said: Dictionary) -> void:
	_party_said = said
	_party_busy = false
	if _party_card.visible:
		_say_party()


func hide_party() -> void:
	_party_card.visible = false
	_fit_big()


func party_shown() -> bool:
	return _party_card != null and _party_card.visible


func _say_party() -> void:
	var live: bool = bool(_party_said.get("live", false))
	var dealt: int = int(_party_said.get("dealt", 0))
	var seat: int = int(_party_said.get("seat", 0))
	var seats: Array = _party_said.get("seats", [])
	var code: String = str(_party_said.get("code", ""))
	if not live:
		_party_title.text = "Build together"
		_party_words.text = ("Up to four phones build this model at once, each its own part, and put "
			+ "the parts together at the end. One phone starts; the others join with its code. "
			+ "No account needed.")
	elif dealt == 0:
		_party_title.text = "Code: %s" % code
		_party_words.text = ("On each other phone, open this model, press Build together and type %s. "
			% code) + ("Press Start building when everyone is in." if seat == 1
			else "The phone that started deals it out when everyone is in.")
	else:
		_party_title.text = "Building together · %s" % code
		_party_words.text = ("Everyone is done: put the parts together." if bool(_party_said.get(
			"all_finished", false)) else "Each phone builds its own part.")
	_party_name.visible = not live
	_party_start.visible = not live
	_party_join_row.visible = not live
	_party_deal.visible = live and dealt == 0 and seat == 1
	_party_deal.text = "Start building: %d phones" % seats.size() if seats.size() != 1 else "Start building: 1 phone"
	_party_deal.disabled = seats.size() < 2
	_party_back.visible = live and dealt > 0
	_party_leave.visible = live
	for button: Button in [_party_start, _party_join, _party_deal, _party_leave, _party_back]:
		if button != _party_deal:
			button.disabled = _party_busy
	if _party_busy:
		_party_deal.disabled = true
	_party_trouble.text = str(_party_said.get("trouble", ""))
	_party_trouble.visible = not _party_trouble.text.is_empty()
	for child: Node in _party_seats.get_children():
		_party_seats.remove_child(child)
		child.queue_free()
	_party_seats.visible = live
	for one: Variant in seats:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", roundi(8.0 * _party_pt))
		var dot := ColorRect.new()
		dot.color = Color.html(str(one.get("colour", "#f9c71f")))
		dot.custom_minimum_size = Vector2.ONE * roundi(12.0 * _party_pt)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var words := Label.new()
		var who: String = ("%s (you)" % str(one.get("name", ""))) if bool(one.get("me", false)) \
			else str(one.get("name", ""))
		if bool(one.get("left", false)):
			words.text = "%s has left" % who
		elif dealt > 0 and bool(one.get("finished", false)):
			words.text = "%s is done" % who
		else:
			words.text = ("%s %d of %d" % [who, int(one.get("done", 0)), int(one.get("of", 0))]) if dealt > 0 else who
		words.add_theme_font_size_override("font_size", roundi((15.0 if _narrow else 13.0) * _party_pt))
		row.add_child(words)
		_party_seats.add_child(row)
	_fit_party()


## The card and the pill at this window's size: in points on a phone.
func _fit_party() -> void:
	if _party_card == null or not is_inside_tree():
		return
	var across: float = Room.across()
	var pt: float = get_viewport().get_visible_rect().size.x / across if across > 0.0 else 1.0
	_party_pt = pt if _narrow else 1.0
	var p: float = _party_pt
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.97)
	backing.border_color = Color(0.98, 0.78, 0.12, 0.5)
	backing.set_border_width_all(maxi(1, roundi(p)))
	backing.set_corner_radius_all(roundi(10.0 * p))
	backing.set_content_margin_all(16.0 * p)
	_party_card.add_theme_stylebox_override("panel", backing)
	(_party_card.get_node("Column") as VBoxContainer).add_theme_constant_override("separation", roundi(10.0 * p))
	_party_title.add_theme_font_size_override("font_size", roundi((22.0 if _narrow else 18.0) * p))
	_party_words.add_theme_font_size_override("font_size", roundi((15.0 if _narrow else 13.0) * p))
	_party_trouble.add_theme_font_size_override("font_size", roundi((15.0 if _narrow else 13.0) * p))
	# A fingertip each on a phone (44 points), the bar's size on a wide window.
	var tall: float = (44.0 if _narrow else 30.0) * p
	for field: LineEdit in [_party_name, _party_code]:
		field.add_theme_font_size_override("font_size", roundi((17.0 if _narrow else 14.0) * p))
		field.custom_minimum_size = Vector2(0.0, tall)
	for button: Button in [_party_start, _party_join, _party_deal, _party_back, _party_leave, _party_close]:
		button.add_theme_font_size_override("font_size", roundi((17.0 if _narrow else 14.0) * p))
		button.custom_minimum_size = Vector2(tall if button == _party_close else 0.0, tall)
	_party_join_row.add_theme_constant_override("separation", roundi(8.0 * p))
	_party_seats.add_theme_constant_override("separation", roundi(6.0 * p))
	var room: float = size.x - 32.0 * p if size.x > 0.0 else 400.0
	var wide: float = minf(room, 420.0 * p)
	_party_title.custom_minimum_size = Vector2(wide - 32.0 * p - tall - 8.0 * p, 0.0)
	_party_words.custom_minimum_size = Vector2(wide - 32.0 * p, 0.0)
	_party_trouble.custom_minimum_size = _party_words.custom_minimum_size
	_party_card.custom_minimum_size = Vector2(wide, 0.0)
	_party_card.reset_size()
	# The pill beside the big Build it: a word smaller, outlined, not lit.
	for face: String in ["normal", "hover", "pressed"]:
		var outlined := StyleBoxFlat.new()
		outlined.bg_color = Color(0.09, 0.10, 0.12, {"normal": 0.88, "hover": 0.95, "pressed": 1.0}[face])
		outlined.border_color = Color(0.98, 0.78, 0.12)
		outlined.set_border_width_all(maxi(1, roundi(2.0 * pt)))
		outlined.set_corner_radius_all(roundi(26.0 * pt))
		outlined.content_margin_left = 18.0 * pt
		outlined.content_margin_right = 18.0 * pt
		_party_pill.add_theme_stylebox_override(face, outlined)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_party_pill.add_theme_color_override(colour, Color(0.98, 0.78, 0.12))
	_party_pill.add_theme_font_size_override("font_size", roundi(17.0 * pt))
	_party_pill.custom_minimum_size = Vector2(0, 52.0 * pt)
	_party_pill.reset_size()


## Where the card goes, as the rest are placed (_lay_out): in the middle
## of the model's part of the window, above the timeline.
func _lay_party(bottom: float) -> void:
	if not _party_card.visible:
		return
	var top: float = _bar.get_global_rect().end.y if _bar.is_visible_in_tree() else 0.0
	var spot := Vector2(maxf((size.x - _party_card.size.x) * 0.5, 6.0),
		maxf(top + (bottom - top - _party_card.size.y) * 0.5, top + 6.0))
	if _party_card.position != spot:
		_party_card.position = spot


## The pill just right of the big Build it, its middle level with it.
func _lay_party_pill() -> void:
	if not _party_pill.visible:
		return
	var spot := Vector2(_big.position.x + _big.size.x + _big.size.y * 0.2,
		_big.position.y + (_big.size.y - _party_pill.size.y) * 0.5)
	if _party_pill.position != spot:
		_party_pill.position = spot


func _party_controls(named: Dictionary) -> void:
	named["view_together"] = _party_pill if _party_pill.visible else _party_bar
	if not _party_card.visible:
		return
	named["party_close"] = _party_close
	for each: Array in [["party_name", _party_name], ["party_start", _party_start], ["party_code", _party_code],
			["party_join", _party_join], ["party_deal", _party_deal], ["party_back", _party_back],
			["party_leave", _party_leave]]:
		if (each[1] as Control).is_visible_in_tree():
			named[each[0]] = each[1]


func _party_state() -> Dictionary:
	var names: Array = []
	for row: Node in _party_seats.get_children():
		names.append((row.get_child(1) as Label).text)
	return {"shown": _party_card.visible, "title": _party_title.text if _party_card.visible else "",
		"says": _party_words.text if _party_card.visible else "", "seats": names,
		"trouble": _party_trouble.text if _party_trouble.visible else "", "busy": _party_busy,
		"code_typed": _party_code.text, "pill": _party_pill.visible,
		"targets": _party_targets()}


## Every target in the card and the pill, in points: a fingertip each.
func _party_targets() -> Dictionary:
	var out: Dictionary = {}
	var named: Dictionary = {}
	_party_controls(named)
	var pt: float = _party_pt if _narrow else 1.0
	for name: String in named:
		var control: Control = named[name]
		if control.is_visible_in_tree():
			out[name] = [snappedf(control.size.x / pt, 0.1), snappedf(control.size.y / pt, 0.1)]
	return out
