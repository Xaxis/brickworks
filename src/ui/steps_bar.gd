## The model's timeline: the whole build, from an empty baseplate to the
## finished model and back, brick by brick, to scrub through or play.
##
## It was a booklet stepper — Back, Play, Next and a slider over the
## steps, forward only, behind the B key — and the owner asked for what
## every CAD and animation tool has: a timeline to drag along and to play
## either way, "the entire history of the build from start to finish and
## back to start". So the slider is over bricks, not steps; it plays
## forwards and backwards at four speeds; and it shows either order the
## model has:
##
##   Build order   how you would put it together on a table — the order
##                 the printable booklet uses, bottom up, each brick on
##                 something already there (Instructions.plan)
##   As made       the order the bricks still standing were placed: by
##                 hand, the order you placed them; by Claude, the order it
##                 thought of them, base first and detail last
##   History       every change since the baseplate was last cleared,
##                 removals included: a design's first draft going up and
##                 being replaced, a wall taken down and built again. What
##                 is no longer there is put back for the timeline to show
##                 (BrickWorld.history) and taken away again after
##   Author's steps  the steps the model's author gave it, in Studio, LDCad
##                 or here (AuthorSteps): the order a model that has them
##                 opens in. Its own row of buttons changes them — a step
##                 earlier or later, merged with the next, taken out — and
##                 Edit's Move to previous/next step and New step from
##                 selection put the selected parts in another
##
## Under the slider, a row of the steps themselves, one cell a step: the
## step showing lit, the steps the selection is in marked in the selection's
## yellow. The selection dragged from its mark onto any other step goes
## there in one drag, as in Studio's step list, and a click on a step shows
## it (steps3). Edit's Move to step… does the same with the number typed.
##
## Shown only while it is on, because it is a mode: while it is up the
## model on screen is not the whole model, and something has to say so
## plainly or the missing bricks read as a bug.
##
## The parts for the current step are named rather than only counted. A
## step that says "3 pieces" tells you nothing you cannot see; one that
## says "2 × Brick 2 x 4" is the line a real booklet prints beside the
## picture, and it is what lets someone follow along with bricks in front
## of them.
class_name StepsBar
extends PanelContainer

## How long the whole build takes to play at 1x, in seconds, kept within
## these whatever its size: a six-brick model is not over before the eye
## finds it, and a four-thousand-brick one does not take a quarter hour.
const SHORTEST := 6.0
const LONGEST := 40.0
const PER_BRICK := 0.04
const SPEEDS: Array[float] = [0.5, 1.0, 2.0, 4.0]

var _slider: HSlider
var _caption: Label
var _pieces: Label
var _play: Button
var _reverse: Button
var _speed: Button
var _order_button: Button
var _steps: Array[Instructions.Step] = []
var _library: PartLibrary
var _world: BrickWorld
var _scenery: Dictionary = {}
## Every brick, in the order being shown.
var _order: Array[int] = []
## [member _order] as reveal_upto hands it out, and its key.
var _order_packed := PackedInt64Array()
var _order_key: int = 0
var _reshowing: bool = false
## For the build order: where each step ends, as a count of bricks.
var _step_ends: Array[int] = []
## Bricks on screen, from 0 (an empty baseplate) to all of them.
var _shown: int = 0
## +1 playing forward, -1 backward, 0 stopped.
var _playing: int = 0
## Fractional bricks owed by the clock, so a slow speed still moves.
var _owed: float = 0.0
var _speed_at: int = 1
## 0 the build order, 1 as made, 2 the history, 3 the author's steps.
var _mode: int = 0
const MODES: Array[String] = ["Build order", "As made", "History", "Author's steps"]
const AUTHORS := 3
## The model has steps its author gave it, so the fourth order is offered.
var _authored: bool = false
## The row of step edits, shown in the author's steps (_line).
var _edits: Container
## The slider's least width, beside the step's words: narrower, the words
## go under it rather than the slider to a sliver.
const SLIDER_LEAST := 120.0
## Go to a step's chips on a long model come this many at a time.
const GO_RUN := 50
## The most of a step's name its words say, on one line beside the slider
## (stepnames): a longer one is cut with an ellipsis, and Name… shows it whole.
const NAME_SHOWN := 40
## How the booklet prints the step showing (BookletLooks): its own row
## (_line).
var _looks: Container
var _look_said: Label
var _look_toggles: Dictionary = {}
var _per_page: Button
## Whether the steps may be changed here: not for a model shared by link
## and opened to look at.
var editable: bool = true
## History: the changes, each [add or remove, key], or ["clear", ""].
var _events: Array = []
## History: which brick in the world shows a key — the brick itself while
## it stands, or one put back for the timeline when it does not.
var _drawn_as: Dictionary = {}
var _ghosts: Array[int] = []
var _ghost_set: Dictionary = {}

## Which bricks should be on screen. Empty means the whole model.
signal reveal(brick_ids: Dictionary)
## In the orders that are a list of the bricks (the build order, as made,
## the author's steps): the first [param count] of [param order] on screen
## and the rest of it not, everything else as it is; [param key] is new
## each time the order is worked out (Main shows it by
## BrickWorld.reveal_upto, a count a batch). [signal reveal] says the
## history's and the end's.
signal reveal_upto(order: PackedInt64Array, count: int, key: int)
## Someone wants the booklet as a file. The bar does not write it: the
## pictures come from the main viewport, which the bar is sitting on.
signal export_wanted()
## A step edit pressed on the bar: "earlier", "later", "merge", "delete" or
## "new" (Shell.edit_steps does it, on the step showing).
signal edit_wanted(op: String)
## A Booklet page command for the step showing: "turn_left", "zoom_in",
## "new_page" ... (Shell.edit_look does it).
signal look_wanted(op: String)
signal closed
## Stepped forward onto the last step from the step before it (step_forward).
signal stepped_to_end
## Stepped forward or back, by Next, Back or the arrow keys.
signal stepped

## Its buttons and the slider by name, for the page to find (controls_by_name).
var _named: Dictionary = {}
## The shell, for the selection and the step edits a drop and Move to step…
## make (Shell._define sets it).
var shell: Shell:
	set(value):
		shell = value
		if shell != null and shell.builder != null \
				and not shell.builder.selection_changed.is_connected(_on_selection_changed):
			shell.builder.selection_changed.connect(_on_selection_changed)
## The row of steps, and which of [member _steps] each part is in, by id.
var _row: StepRow
var _step_of: Dictionary = {}
## The steps the selection is in, by their place in [member _steps].
var _marked: Dictionary = {}
## The step the row was last pressed on.
var _row_from: int = -1
## Move to step…, made the first time it is asked for.
var _ask: ConfirmationDialog
var _ask_number: SpinBox
var _ask_words: Label
var _ask_of: Label
var _ask_ids: Array = []
var _ask_steps: Array[Instructions.Step] = []
## The steps being worked out (start), until they are.
var _job: Working.Job = null
## Find a step (stepsearch): the field, the line under it that lists the
## steps found, its words and its buttons, one a step (made as wanted and
## kept for the next find). On a phone or a tablet the field and the list
## are in a sheet Find… opens (_find_sheet).
var _find: LineEdit
## What of the find stands in the row of buttons: the field's FindSlot, or
## on a phone or a tablet Find…; shown in the orders that have steps.
var _find_in_row: Control
var _found_line: Container
var _found_said: Label
var _found_chips: Array[Button] = []
var _find_box: VBoxContainer
var _find_sheet: AcceptDialog
## What the find found: each step that places it, [its place in [member
## _steps], how many, part id -> how many], in step order; and by place.
var _hits: Array = []
var _hit_set: Dictionary = {}
## Each step's parts by part and colour (step_lots), made at the first find
## after the steps are worked out.
var _lots: Array[Dictionary] = []
## A find waiting for the parts' search to be made (PartLibrary.search_ready).
var _find_waiting: bool = false
## The most steps listed, the rest marked on the row and gone to by Enter:
## a word every step answers lists hundreds on a big model, a wall of
## numbers that says less than the row.
const FOUND_MOST := 40
const FOUND_MOST_PHONE := 12

# -- a phone's bar (ux15) -----------------------------------------------------------
#
# On a phone, held either way (not a tablet), the bar is what a person
# following a build reaches with one thumb: the step, the next step and the
# parts for this one. At 390 points the desktop's bar was 14 buttons in three
# rows and two rows that slid sideways, Turn right cut off at the edge, and in
# a shared model's viewer 11 buttons 28 by 12 points over most of the foot
# (bench/results/ux15-2026-11-23/WALK.md). LEGO Builder's 3D instructions put
# a step forward under the thumb and leave the rest a tap away; reviews of it
# ask for a swipe and a quick jump to a step, which it lacks.
#
# So the bar is one row of five, each a fingertip: Back, the step's number
# ("Step 12 of 35", tapped: every step, to go to any), Next, Parts (the
# step's parts as pictures with how many, over the row, on or off) and More,
# a sheet with the rest: the timeline's slider, Start, Play, End, the orders,
# Find, Instructions, Done, the step edits and the booklet's look. Over the
# row, the row of steps drawn as a strip a finger drags along, and the step's
# words. A thumb swiped along the bar turns the page, left for Next, as Build
# it's bars do. Sized in points here, as Build it is, so the bar is the same
# in the studio and in a shared model's viewer, which has no TouchSizing.

## A phone held either way: the bar laid out for a thumb.
var _compact: bool = false
var _at_button: Button
var _parts_button: Button
var _more_button: Button
## What More opens: everything but the five, made into a sheet the first
## time it is asked for.
var _more_box: VBoxContainer
var _more_sheet: AcceptDialog
## Go to a step: the step's number tapped.
var _go_sheet: AcceptDialog
var _go_grid: GridContainer
## Step number -> its chip, for the steps shown.
var _go_chips: Dictionary = {}
## On a long model, the runs of GO_RUN steps, a chip each, over the grid.
var _go_runs: HFlowContainer
## Step number -> the index of its first step, and the numbers in order.
var _go_first: Dictionary = {}
var _go_numbers: PackedInt32Array = []
## Where in _go_numbers the run shown starts.
var _go_from: int = 0
## The step's parts as pictures, each with how many.
var _strip_slide: ScrollContainer
var _strip: HBoxContainer
var _tiles: Array[ThumbTile] = []
## The parts' pictures (Main's), for the strip.
var thumbnails: PartThumbnails
## Whether the strip shows, kept for the next time the bar opens.
static var _parts_on: bool = true
## A swipe along the bar: where the finger came down, or x < 0.
var _swipe_from := Vector2(-1, -1)
## Points, as Build it's: how far a thumb goes for a swipe, and a picture.
const SWIPE := 56.0
const PICTURE := 40.0
## The step each model was left at, by what its steps are (_kept_key), for
## the timeline opened again on it to come back there, as a booklet stays
## open at its page.
static var _kept_at: Dictionary = {}


func _ready() -> void:
	visible = false
	set_process(true)
	_build()
	if _compact:
		get_viewport().size_changed.connect(_fit_compact, CONNECT_DEFERRED)
		_fit_compact.call_deferred()


func _build() -> void:
	_compact = Phone.on() and not Phone.wide()
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.10, 0.12, 0.93)
	backing.border_color = Color(1, 1, 1, 0.12)
	backing.border_width_top = 1
	backing.content_margin_left = 12
	backing.content_margin_right = 12
	backing.content_margin_top = 7
	backing.content_margin_bottom = 7
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)

	# The timeline itself, the width of the window: what is being dragged
	# is the whole build, and a short slider makes a brick a pixel.
	#
	# Every row of the bar wraps where the model's room is narrower than
	# the row, as its booklet row does: in one line each, the bar's least
	# width was the whole row of buttons, and with the bin, Stress and the
	# assistant beside the model it held the layout wider than a laptop's
	# window, Done and Instructions past its right edge (APP_UX6
	# timelinefit). Here the step's words go under the slider.
	var line := HFlowContainer.new()
	line.add_theme_constant_override("h_separation", 10)
	line.add_theme_constant_override("v_separation", 2)
	column.add_child(line)
	_slider = HSlider.new()
	_slider.accessibility_name = "Timeline: the step shown"
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Its line's height, its track drawn down the middle of it: a flow lays
	# a child that does not fill at the top of its line.
	_slider.size_flags_vertical = Control.SIZE_FILL
	_slider.custom_minimum_size = Vector2(SLIDER_LEAST, 0)
	_slider.min_value = 0
	_slider.step = 1
	_slider.focus_mode = Control.FOCUS_NONE
	# Dragging is a deliberate move; it stops the playback rather than
	# fighting it for the next frame.
	_slider.value_changed.connect(func(value: float) -> void:
		if int(value) != _shown:
			_stop_play()
			_show(int(value)))
	line.add_child(_slider)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 12)
	_caption.custom_minimum_size = Vector2(190, 0)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(_caption)

	_row = StepRow.new()
	_row.bar = self
	_row.custom_minimum_size = Vector2(0, StepRow.TALL)
	_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_row.accessibility_name = "Steps: drag the selection onto one to move it there"
	_row.tooltip_text = " "
	column.add_child(_row)

	# What the step adds, on a line of its own the width of the bar. It
	# sat between the buttons, where at 1600 wide it was cut off after
	# three parts ("1 × Plate 6 x 6, 1 × Brick 1 x 3, 1").
	_pieces = Label.new()
	_pieces.add_theme_font_size_override("font_size", 12)
	_pieces.modulate = Color(1, 1, 1, 0.72)
	_pieces.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pieces.clip_text = true
	_pieces.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pieces.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_pieces)

	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	column.add_child(row)

	var start := _button("Start", "An empty baseplate (Home)")
	start.pressed.connect(to_start)
	row.add_child(start)
	_named["steps_start"] = start
	var back := _button("Back", "The step before (left arrow)")
	back.pressed.connect(step_back)
	row.add_child(back)
	_named["steps_back"] = back
	_reverse = _button("Reverse", "Play it coming apart, back to the start")
	_reverse.pressed.connect(func() -> void: _toggle(-1))
	row.add_child(_reverse)
	_play = _button("Play", "Play the build (space)")
	_play.pressed.connect(func() -> void: _toggle(1))
	row.add_child(_play)
	_named["steps_play"] = _play
	var forward := _button("Next", "The step after (right arrow)")
	forward.pressed.connect(step_forward)
	row.add_child(forward)
	_named["steps_next"] = forward
	var end := _button("End", "The finished model (End)")
	end.pressed.connect(to_end)
	row.add_child(end)
	_named["steps_end"] = end
	_speed = _button("1x", "How fast it plays")
	_speed.pressed.connect(func() -> void:
		_speed_at = (_speed_at + 1) % SPEEDS.size()
		_speed.text = _speed_name())
	row.add_child(_speed)
	_order_button = _button("Build order", "Build order: how you would put it "
		+ "together. As made: the order what stands was placed in. History: "
		+ "every change, removals included — how it was really made. Author's "
		+ "steps: the steps the model came with, or that you gave it")
	_order_button.custom_minimum_size = Vector2(92, 0)
	_order_button.pressed.connect(func() -> void: set_mode(_next_mode()))
	row.add_child(_order_button)
	_named["steps_order"] = _order_button
	_build_find(row, column)

	# Instructions and Done together at the right-hand end of whichever line
	# they fall on: the rest of that line is theirs to stand at the end of.
	var ends := HBoxContainer.new()
	ends.add_theme_constant_override("separation", 6)
	ends.alignment = BoxContainer.ALIGNMENT_END
	ends.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ends)

	var save := _button("Instructions",
		"These steps as a printable booklet, pictures and parts included")
	save.pressed.connect(func() -> void: export_wanted.emit())
	ends.add_child(save)
	_named["steps_booklet"] = save

	var close := _button("Done", "Back to the whole model")
	close.pressed.connect(stop)
	ends.add_child(close)
	_named["steps_done"] = close
	_named["steps_slider"] = _slider

	# Changing the author's steps, on the step showing: as LeoCAD and Studio
	# keep theirs beside the step list. Shown in the author's steps only.
	_edits = _line(column)
	_edits.visible = false
	for edit: Array in [
			["earlier", "Earlier", "This step before the one ahead of it ({step_earlier})"],
			["later", "Later", "This step after the one that follows it ({step_later})"],
			["merge", "Merge with next", "This step and the next made one ({step_merge})"],
			["delete", "Delete step", "Take this step out; its parts join the step before. "
				+ "No part is taken off ({step_delete})"],
			["new", "New step from selection", "The selected parts in a step of their own, "
				+ "after this one ({step_new})"],
			["to", "Move to step…", "The selected parts into any step, its number typed "
				+ "({step_to}), or dragged from their yellow mark above onto the step"],
			# stepkeep2: a model opens in the steps it was saved in, and they
			# are worked out again only when the person asks.
			["plan", "Plan steps", "Work the steps out again from the model as it is, "
				+ "in place of these. One undo"]]:
		var op: String = edit[0]
		var made: Button = _button(edit[1], "")
		Keymap.tell(made, edit[2])
		if op == "to":
			made.pressed.connect(ask_step_to)
		else:
			made.pressed.connect(func() -> void: edit_wanted.emit(op))
		_edits.add_child(made)
		_named["steps_" + op] = made
	_named["steps_row"] = _row

	# How the booklet prints the step showing, as Studio's Instruction Maker
	# sets a step's view and page beside its step list: the step showing is
	# the one changed, and the line at the end says how it is set.
	# Wrapping onto a second line where the window is narrow: in one line it
	# was wider than the timeline at 1280 x 800, and pushed the bar's own
	# Instructions and Done off the window.
	_looks = _line(column)
	_looks.visible = false
	var title := Label.new()
	title.text = "Booklet:"
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(1, 1, 1, 0.72)
	_looks.add_child(title)
	for look: Array in [
			["turn_left", "Turn left", "This step's picture with the model turned 45 degrees, and the steps after it until turned again"],
			["turn_right", "Turn right", "Turned 45 degrees the other way"],
			["tilt_up", "Higher", "Seen from 15 degrees higher"],
			["tilt_down", "Lower", "Seen from 15 degrees lower"],
			["this_view", "This view", "This step drawn from the angle the window looks from now"],
			["usual_view", "Usual view", "Back to the booklet's usual angle from this step"],
			["zoom_in", "Zoom in", "Closer in on what this step adds"],
			["zoom_out", "Zoom out", "Further out"],
			["bigger", "Bigger", "Drawn larger on the page, so fewer steps share it"],
			["smaller", "Smaller", "Drawn smaller on the page"],
			["new_page", "New page", "This step at the top of a new page"],
			["alone", "Alone", "This step on a page of its own"],
			["parts", "Parts list", "The box of the parts this step adds"],
			["callout", "Callout", "The sub-assembly this step puts on built in a box beside it; "
				+ "off, on pages of its own"],
			["highlight", "Outline new", "The parts each step adds outlined in orange, in the "
				+ "whole booklet"],
			["lay_out", "Lay out page…", "This step's page by hand: drag its picture, parts list, "
				+ "callout and number, and add words and pictures"]]:
		var op: String = look[0]
		var made: Button = _button(look[1], look[2])
		if op in ["new_page", "alone", "parts", "callout", "highlight"]:
			made.toggle_mode = true
			_look_toggles[op] = made
			made.toggled.connect(func(_on: bool) -> void: look_wanted.emit(op))
		else:
			made.pressed.connect(func() -> void: look_wanted.emit(op))
		_looks.add_child(made)
		_named["booklet_" + op] = made
	_per_page = _button("Per page: as fit", "At most this many steps on a page: as they fit, 1, 2 or 4")
	_per_page.pressed.connect(func() -> void: look_wanted.emit("per_page"))
	_looks.add_child(_per_page)
	_named["booklet_per_page"] = _per_page
	# stepnames (APP_UX6 #9): the step showing named, as Studio names a step,
	# said beside its number here, in Build it and in the booklet. First in
	# the row, before how its picture is drawn: what a step is comes first.
	var naming: Button = _button("Name…", "")
	Keymap.tell(naming, "What this step is called (\"Build the cockpit\"): said beside its "
		+ "number here, in Build it and in the booklet ({step_name})")
	naming.pressed.connect(ask_step_name)
	_looks.add_child(naming)
	_looks.move_child(naming, 1)
	_named["steps_name"] = naming
	# On a phone the row slides, and what is in sight without a slide is
	# what a finger reaches first: the page laid out by hand, where each of
	# the rest is done by dragging, after the step's name.
	if _looks.get_parent() is ScrollContainer:
		_looks.move_child(_named["booklet_lay_out"], 2)
	_look_said = Label.new()
	_look_said.add_theme_font_size_override("font_size", 11)
	_look_said.modulate = Color(1, 1, 1, 0.72)
	_look_said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_look_said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_look_said.custom_minimum_size = Vector2(160, 0)
	_look_said.clip_text = true
	_look_said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_looks.add_child(_look_said)
	_named["booklet_said"] = _look_said
	if _compact:
		_lay_compact(column, line, row, back, forward)


## A row of choices, wrapped onto as many lines as it needs. On a phone held
## upright these rows are in More's sheet, which scrolls down (_lay_compact):
## there they slid sideways in one line before ux15, under the five.
func _line(column: Container) -> Container:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	column.add_child(flow)
	return flow


## The bar for a thumb (_compact): the desktop's rows of buttons, the slider
## and the rows of step edits and booklet looks go in More's sheet, and the
## five go along the foot, under the row of steps, the step's parts and its
## words.
func _lay_compact(column: VBoxContainer, line: Container, row: Container, back: Button,
		forward: Button) -> void:
	_more_box = VBoxContainer.new()
	_more_box.add_theme_constant_override("separation", 10)
	row.remove_child(back)
	row.remove_child(forward)
	for moved: Control in [line, row, _edits, _looks]:
		column.remove_child(moved)
		_more_box.add_child(moved)
	# The step's words over the slider, the sheet's width, wrapped: beside it,
	# 190 wide, they ran past the sheet's edge.
	line.remove_child(_caption)
	_more_box.add_child(_caption)
	_more_box.move_child(_caption, 0)
	_caption.custom_minimum_size = Vector2.ZERO
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A step chosen in the sheet puts it away, as a menu goes once a row is
	# chosen; how the booklet looks, the order and the speed leave it open,
	# to be set and seen.
	for name: String in ["steps_start", "steps_play", "steps_end", "steps_find", "steps_booklet",
			"steps_done", "steps_earlier", "steps_later", "steps_merge", "steps_delete", "steps_new",
			"steps_to", "steps_plan", "steps_name", "booklet_lay_out"]:
		var button: BaseButton = _named.get(name) as BaseButton
		if button != null:
			button.pressed.connect(_close_more)
	_reverse.pressed.connect(_close_more)
	# The row of steps first, a strip the width of the bar a finger drags
	# along; the parts' pictures; the step's words; then the five.
	_strip_slide = ScrollContainer.new()
	_strip_slide.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_strip_slide.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_strip_slide.mouse_filter = Control.MOUSE_FILTER_PASS
	_strip = HBoxContainer.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	_strip_slide.add_child(_strip)
	column.add_child(_strip_slide)
	column.move_child(_strip_slide, _pieces.get_index())
	_named["steps_strip"] = _strip_slide
	var thumb := HBoxContainer.new()
	thumb.add_theme_constant_override("separation", 6)
	column.add_child(thumb)
	thumb.add_child(back)
	_at_button = _button("Step 1 of 1", "Go to a step: every step, to tap one")
	_at_button.accessibility_name = "Go to a step"
	_at_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_at_button.clip_text = true
	_at_button.pressed.connect(open_go_to)
	_at_button.resized.connect(_fit_at_words)
	thumb.add_child(_at_button)
	thumb.add_child(forward)
	_parts_button = _button("Parts", "This step's parts as pictures, how many of each beside them")
	_parts_button.toggle_mode = true
	_parts_button.set_pressed_no_signal(_parts_on)
	_parts_button.toggled.connect(func(on: bool) -> void:
		_parts_on = on
		_lay_strip())
	thumb.add_child(_parts_button)
	_more_button = _button("More", "Play, Start and End, the order, Find, Instructions, "
		+ "Done and how the booklet prints the step")
	_more_button.pressed.connect(open_more)
	thumb.add_child(_more_button)
	_named["steps_at"] = _at_button
	_named["steps_parts"] = _parts_button
	_named["steps_more"] = _more_button
	_named["steps_thumb_row"] = thumb
	# Sized by the bar itself, in points (_fit_compact): TouchSizing grows
	# what it is handed from the desktop's sizes, and the viewer has none.
	for control: Control in [back, forward, _at_button, _parts_button, _more_button, _row, _pieces,
			_strip_slide]:
		control.set_meta(&"for_a_finger", true)


## The five a fingertip each and their words in points, the row of steps a
## finger's height, the parts' pictures a size to pick from: as the window's
## points to the unit are now (a phone turned, a browser's zoom).
func _fit_compact() -> void:
	if not _compact or not is_inside_tree():
		return
	var pt: float = Phone.per_point(get_viewport())
	var least: float = Phone.TARGET * pt
	for name: String in ["steps_back", "steps_at", "steps_next", "steps_parts", "steps_more"]:
		var button: Button = _named[name]
		button.custom_minimum_size = Vector2(0.0 if button == _at_button else least, least)
		button.add_theme_font_size_override("font_size", roundi(15.0 * pt))
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var face := StyleBoxFlat.new()
			var lit: bool = button == _named["steps_next"] or (button == _parts_button
				and state in ["pressed", "hover_pressed"])
			face.bg_color = Look.STRONG if lit else Color(1, 1, 1, {"normal": 0.08, "hover": 0.16,
				"pressed": 0.24, "hover_pressed": 0.24, "disabled": 0.03}[state])
			if lit and state in ["hover", "hover_pressed"]:
				face.bg_color = Look.STRONG_HOVER
			face.border_color = Color(1, 1, 1, 0.14)
			face.set_border_width_all(maxi(1, roundi(pt)))
			face.set_corner_radius_all(roundi(8.0 * pt))
			face.content_margin_left = 10.0 * pt
			face.content_margin_right = 10.0 * pt
			button.add_theme_stylebox_override(state, face)
	_pieces.add_theme_font_size_override("font_size", roundi(13.0 * pt))
	# The row of steps a selection is dropped on, where the studio shows it:
	# a fingertip tall, to drop on and to scrub along.
	_row.custom_minimum_size = Vector2(0, least)
	_lay_strip()
	_fit_at_words.call_deferred()


## What the step's number button says: the whole of it where it fits, else
## shorter ("Step 12 of 35", "12 of 35", "12/35").
var _at_words: Array[String] = ["", "", ""]


func _fit_at_words() -> void:
	if _at_button == null:
		return
	var font: Font = _at_button.get_theme_font("font")
	var font_size: int = _at_button.get_theme_font_size("font_size")
	var room: float = _at_button.size.x - _at_button.get_theme_stylebox("normal").get_minimum_size().x
	for words: String in _at_words:
		if font.get_string_size(_at_button.tr(words), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room:
			_at_button.text = words
			return
	_at_button.text = _at_words[-1]


## The five's words for the place showing.
func _show_compact() -> void:
	var at: Instructions.Step = current_step()
	if at != null:
		var last: int = _steps[-1].number
		_at_words = ["Step %d of %d" % [at.number, last], "%d of %d" % [at.number, last],
			"%d/%d" % [at.number, last]]
		if not at.called().is_empty():
			_pieces.text = at.shortened_name(NAME_SHOWN) + " · " + _pieces.text
	elif (_mode == 0 or _mode == AUTHORS) and not _steps.is_empty():
		var steps: int = _steps[-1].number
		_at_words = ["%d steps" % steps, "%d steps" % steps, str(steps)]
	else:
		_at_words = ["%d of %d" % [_shown, _length()], "%d of %d" % [_shown, _length()],
			"%d/%d" % [_shown, _length()]]
	_at_button.tooltip_text = _caption.text
	_fit_at_words()
	_lay_strip()


## The step's parts as a booklet's callout has them: a picture of each part
## in its colour, how many beside it, the most first. None at the start, in
## the orders with no steps, or with Parts off; a step that puts on a
## finished sub-assembly shows the parts that go on beside it.
func _lay_strip() -> void:
	if _strip == null:
		return
	# Laid again only for another step: playback shows a brick a frame.
	var at: Instructions.Step = current_step()
	var key: String = "%s|%s|%s|%.3f" % [at.get_instance_id() if at != null else 0, _parts_on, visible,
		Phone.per_point(get_viewport()) if is_inside_tree() else 1.0]
	if key == _strip_key:
		return
	_strip_key = key
	for child: Node in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	_tiles.clear()
	var lots: Array[Dictionary] = []
	if _parts_on and at != null and visible:
		lots = step_lots_of(at)
	_strip_slide.visible = not lots.is_empty()
	if lots.is_empty():
		if thumbnails != null:
			thumbnails.watch(self, [] as Array[ThumbTile])
		return
	var pt: float = Phone.per_point(get_viewport()) if is_inside_tree() else 1.0
	for lot: Dictionary in lots:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", roundi(2.0 * pt))
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.tooltip_text = "%d × %s, %s" % [int(lot["count"]), lot["name"], lot["colour_name"]]
		var tile := ThumbTile.new(str(lot["part"]), int(lot["colour"]))
		tile.custom_minimum_size = Vector2.ONE * PICTURE * pt
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		var ready: Texture2D = thumbnails.peek(tile.part_id, tile.color_code) if thumbnails != null else null
		if ready != null:
			tile.show_picture(ready, false)
		else:
			ThumbTile.sketch_for(tile, thumbnails)
		cell.add_child(tile)
		var count := Label.new()
		count.text = "%dx" % int(lot["count"])
		count.add_theme_font_size_override("font_size", roundi(15.0 * pt))
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(count)
		# Sized here in points, not grown again as the bar's desktop sizes are.
		for sized: Control in [cell, tile, count]:
			sized.set_meta(&"for_a_finger", true)
		_strip.add_child(cell)
		_tiles.append(tile)
	if thumbnails != null:
		_watch_tiles()


## The pictures asked for once the step itself is drawn, as Build it's are.
func _watch_tiles() -> void:
	_tiles_laid += 1
	var laid: int = _tiles_laid
	await RenderingServer.frame_post_draw
	if laid == _tiles_laid and thumbnails != null and is_instance_valid(self):
		thumbnails.watch(self, _tiles if visible else ([] as Array[ThumbTile]))


var _tiles_laid: int = 0
## The step, the switch and the size the strip was last laid for.
var _strip_key: String = ""


## [param at]'s parts, one entry a part in a colour, the most first, as Build
## it's callout lists them: {"part", "colour", "count", "name", "colour_name"}.
func step_lots_of(at: Instructions.Step) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if at == null or _world == null or _library == null:
		return out
	var counts: Dictionary = {}
	for brick_id: int in at.brick_ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null or _scenery.has(brick_id):
			continue
		var key: String = "%s|%d" % [brick.part_id, brick.color_code]
		if not counts.has(key):
			var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
			var name: String = info.name.strip_edges() if info != null else brick.part_id
			while name.contains("  "):
				name = name.replace("  ", " ")
			counts[key] = {"part": brick.part_id, "colour": brick.color_code, "count": 0,
				"name": name, "colour_name": _library.color(brick.color_code).name}
		counts[key]["count"] = int(counts[key]["count"]) + 1
	for lot: Dictionary in counts.values():
		out.append(lot)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["count"]) != int(b["count"]):
			return int(a["count"]) > int(b["count"])
		return str(a["name"]) < str(b["name"]))
	return out


## What the strip shows, for a check: its pictures, and how many are drawn.
func parts_state() -> Dictionary:
	var drawn: int = 0
	for tile: ThumbTile in _tiles:
		if is_instance_valid(tile) and tile.state == ThumbTile.State.READY:
			drawn += 1
	return {"on": _parts_on, "pictures": _tiles.size() if _strip_slide != null and _strip_slide.visible else 0,
		"drawn": drawn}


## More: the rest of the bar, in a sheet from the foot.
func open_more() -> void:
	if _more_sheet == null:
		_more_sheet = AcceptDialog.new()
		_more_sheet.title = "Steps"
		_more_sheet.ok_button_text = Look.CLOSE
		var slide := ScrollContainer.new()
		slide.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		slide.add_child(_more_box)
		_more_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_more_sheet.add_child(slide)
		(shell if shell != null else self as Node).add_child(_more_sheet)
	# Half the screen, the model above it: sized by what the box asked for,
	# the sheet was 40 points tall the first time, its rows laid out only
	# once shown, and held the slider alone (ux15's walk, p18).
	var room: Vector2 = get_viewport().get_visible_rect().size
	var slide: ScrollContainer = _more_box.get_parent() as ScrollContainer
	slide.custom_minimum_size = Vector2(minf(room.x * 0.9, 560.0 * Phone.per_point(get_viewport())),
		room.y * 0.5)
	_more_sheet.popup_centered()


func _close_more() -> void:
	if _more_sheet != null and _more_sheet.visible:
		_more_sheet.hide()


## Go to a step: every step's number, a tap each, the one showing lit. A
## step built in a callout is gone to at the first of its own steps. A long
## model's steps come GO_RUN at a time, its runs chips over them ("51-100"),
## the run with the step showing first: Orthanc's thousand chips made at once
## took a phone's frame for themselves.
func open_go_to() -> void:
	if _steps.is_empty() or _step_ends.is_empty():
		open_more()
		return
	if _go_sheet == null:
		_go_sheet = AcceptDialog.new()
		_go_sheet.title = "Go to a step"
		_go_sheet.ok_button_text = Look.CLOSE
		var column := VBoxContainer.new()
		_go_runs = HFlowContainer.new()
		column.add_child(_go_runs)
		var slide := ScrollContainer.new()
		slide.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_go_grid = GridContainer.new()
		_go_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slide.add_child(_go_grid)
		column.add_child(slide)
		_go_sheet.add_child(column)
		(shell if shell != null else self as Node).add_child(_go_sheet)
	_go_first.clear()
	_go_numbers.clear()
	for index: int in _steps.size():
		var number: int = _steps[index].number
		if not _go_first.has(number):
			_go_first[number] = index
			_go_numbers.append(number)
	var lit: Instructions.Step = current_step()
	var at: int = maxi(0, _go_numbers.find(lit.number)) if lit != null else 0
	_go_from = at - at % GO_RUN if _go_numbers.size() > GO_RUN + GO_RUN / 5 else 0
	_lay_go_runs()
	_lay_go_chips()
	_go_sheet.popup_centered()


## The runs' chips, the one shown lit; none on a model short enough for one.
func _lay_go_runs() -> void:
	for child: Node in _go_runs.get_children():
		_go_runs.remove_child(child)
		child.queue_free()
	var pt: float = Phone.per_point(get_viewport())
	_go_runs.add_theme_constant_override("h_separation", roundi(6.0 * pt))
	_go_runs.add_theme_constant_override("v_separation", roundi(6.0 * pt))
	_go_runs.visible = _go_numbers.size() > GO_RUN + GO_RUN / 5
	if not _go_runs.visible:
		return
	for from: int in range(0, _go_numbers.size(), GO_RUN):
		var to: int = mini(from + GO_RUN, _go_numbers.size()) - 1
		var run := Button.new()
		run.text = "%d-%d" % [_go_numbers[from], _go_numbers[to]]
		run.focus_mode = Control.FOCUS_NONE
		run.toggle_mode = true
		run.set_pressed_no_signal(from == _go_from)
		run.custom_minimum_size = Vector2(0, Phone.TARGET * pt)
		run.add_theme_font_size_override("font_size", roundi(15.0 * pt))
		run.set_meta(&"for_a_finger", true)
		var first: int = from
		run.pressed.connect(func() -> void:
			_go_from = first
			_lay_go_runs.call_deferred()
			_lay_go_chips.call_deferred())
		_go_runs.add_child(run)


## The steps of the run shown, a chip each, the one showing lit.
func _lay_go_chips() -> void:
	for child: Node in _go_grid.get_children():
		_go_grid.remove_child(child)
		child.queue_free()
	_go_chips.clear()
	var pt: float = Phone.per_point(get_viewport())
	var room: Vector2 = get_viewport().get_visible_rect().size
	var across: float = minf(room.x * 0.9, 560.0 * pt)
	var chip_size: float = (Phone.TARGET + 8.0) * pt
	_go_grid.columns = maxi(1, int(across / (chip_size + 6.0 * pt)))
	_go_grid.add_theme_constant_override("h_separation", roundi(6.0 * pt))
	_go_grid.add_theme_constant_override("v_separation", roundi(6.0 * pt))
	var lit: Instructions.Step = current_step()
	var last: int = _steps[-1].number
	var upto: int = mini(_go_from + GO_RUN, _go_numbers.size()) if _go_runs.visible else _go_numbers.size()
	for k: int in range(_go_from, upto):
		var number: int = _go_numbers[k]
		var index: int = _go_first[number]
		var chip := Button.new()
		chip.text = str(number)
		chip.focus_mode = Control.FOCUS_NONE
		chip.toggle_mode = true
		chip.set_pressed_no_signal(lit != null and lit.number == number)
		chip.custom_minimum_size = Vector2(chip_size, chip_size)
		chip.add_theme_font_size_override("font_size", roundi(16.0 * pt))
		chip.tooltip_text = _steps[index].caption(last)
		chip.set_meta(&"for_a_finger", true)
		chip.pressed.connect(func() -> void:
			_show_cell(index)
			stepped.emit()
			_go_sheet.hide())
		_go_grid.add_child(chip)
		_go_chips[number] = chip
	var slide: ScrollContainer = _go_grid.get_parent() as ScrollContainer
	var rows: int = ceili(float(_go_chips.size()) / _go_grid.columns)
	slide.custom_minimum_size = Vector2(across, minf(rows * (chip_size + 6.0 * pt), room.y * 0.5))
	# The step showing in sight.
	var shown: Variant = _go_chips.get(lit.number if lit != null else -1)
	if shown is Control:
		slide.ensure_control_visible.call_deferred(shown)


## The go-to sheet's button for step [param number], while it is open.
func go_to_step_control(number: int) -> Control:
	if _go_sheet == null or not _go_sheet.visible:
		return null
	return _go_chips.get(number) as Control


## A thumb drawn along the bar turns the page, left for Next and right for
## Back, as Build it's bars do; across, and far enough, so a tap that wobbles
## is still a tap. Not on the row of steps, which a drag scrubs, nor on the
## parts' pictures, which slide. Read before the buttons have it: a swipe
## that ends on the button it began on is no press of it.
func _input(event: InputEvent) -> void:
	if not _compact or not visible:
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_swipe_from = button.position if _swipes_at(button.position) else Vector2(-1, -1)
			return
		if _swipe_from.x < 0.0:
			return
		var moved: Vector2 = button.position - _swipe_from
		_swipe_from = Vector2(-1, -1)
		var reach: float = SWIPE * Phone.per_point(get_viewport())
		if absf(moved.x) < reach or absf(moved.x) < absf(moved.y) * 1.5:
			return
		get_viewport().set_input_as_handled()
		_let_go_of_presses()
		if moved.x < 0.0:
			step_forward()
		else:
			step_back()


func _swipes_at(point: Vector2) -> bool:
	if not get_global_rect().has_point(point):
		return false
	for away: Control in [_row, _strip_slide]:
		if away != null and away.is_visible_in_tree() and away.get_global_rect().has_point(point):
			return false
	return true


## The press a swipe began on a button let go of, unpressed: the release that
## would have pressed it was the swipe's.
func _let_go_of_presses() -> void:
	var row: Control = _named.get("steps_thumb_row")
	if row == null:
		return
	for child: Node in row.get_children():
		var pressed := child as BaseButton
		if pressed != null and not pressed.disabled:
			pressed.disabled = true
			pressed.disabled = false


## What a model's steps are, as a key to keep the step it was left at by:
## the same model opened again lays out the same steps (Instructions.plan).
func _kept_key() -> String:
	var parts: Array = []
	for step: Instructions.Step in _steps:
		parts.append(step.parts)
	return "%d|%d|%d|%d" % [_mode, _steps.size(), _order.size(), hash(parts)]


## Words, not symbols.
##
## These were ❮ ▶ ❚❚ ✕, which the desktop found in a system font and the
## browser did not — there is no fallback there, so every one of them
## rendered as a missing-glyph box. A box reads as something broken; a
## word reads as what it does, and "Play" is not less clear than a
## triangle.
func _button(label: String, tip: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.custom_minimum_size = Vector2(52, 0)
	# A face of their own: drawn flat, the row read as a line of words,
	# and nothing said which of them could be pressed.
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(1, 1, 1, {"normal": 0.08, "hover": 0.16, "pressed": 0.24}[state])
		face.border_color = Color(1, 1, 1, 0.14)
		face.set_border_width_all(1)
		face.set_corner_radius_all(4)
		face.content_margin_left = 9
		face.content_margin_right = 9
		face.content_margin_top = 3
		face.content_margin_bottom = 3
		button.add_theme_stylebox_override(state, face)
	return button


## Work out the build order for what is in the world and show the first
## step. Returns false when there is nothing to step through, or when it
## was cancelled or stopped before it was worked out.
##
## A slice at a time, with the status bar saying how far it has got
## (Working): on Orthanc the order is seconds of work in a browser, and it
## held the page on one frame with nothing on screen to say so.
func start(world: BrickWorld, library: PartLibrary,
		scenery: Dictionary = {}, resume: bool = false) -> bool:
	if _job != null:
		return false
	_library = library
	_world = world
	_scenery = scenery
	if not world.reveal_ended.is_connected(_on_reveal_ended):
		world.reveal_ended.connect(_on_reveal_ended)
	# A model with its author's steps opens in them; one without has none
	# to show.
	_authored = AuthorSteps.any(world, scenery)
	# Set every time, not only on a change of order: the rows it shows
	# follow whether the model has steps too, and a fresh model's build
	# order kept the row of steps and the Booklet row (Lay out the page…)
	# hidden from the bar's making until another order was chosen
	# (phonepanels, smalls2).
	var mode: int = _mode
	if _authored and mode == 0:
		mode = AUTHORS
	elif not _authored and mode == AUTHORS:
		mode = 0
	_set_mode_quietly(mode)
	var job: Working.Job = Working.begin("Laying out %s parts in steps…"
		% Working.comma(Inventory.pieces_in(world, library, scenery)), 0, true)
	_job = job
	await job.shown()
	var steps: Array[Instructions.Step] = await Instructions.plan_paced(
		world, library, scenery, {}, job, _mode == AUTHORS)
	if not job.cancelled and not steps.is_empty():
		job.say("Showing the first step…")
		job.count(0, 0)
		# In a frame of its own: the last of the laying out and the first
		# step shown were one frame, 263 ms of a browser's on Orthanc, over
		# the 250 the progress check allows (2026-10-15).
		await job.next()
	_job = null
	if job.cancelled or steps.is_empty():
		job.end()
		return false
	_steps = steps
	visible = true
	_reorder()
	# The first step, as the booklet opens: an empty baseplate is a page
	# with nothing on it. Opened again by the person on the same model, the
	# step they left it at (ux15: a phone's thumb put the steps away to
	# build, and came back to step 1 of 35).
	var kept: int = int(_kept_at.get(_kept_key(), -1)) if resume else -1
	if kept > 0 and kept <= _length():
		_show(kept)
	else:
		_show(_step_ends[0] if (_mode == 0 or _mode == AUTHORS) and not _step_ends.is_empty()
			else 1)
	job.end()
	return true


## The steps laid out again a slice at a time, from the first step, as the
## timeline opens: after Plan steps took the model's own off, they are
## worked out afresh from the model as it is, and in one go Orthanc's were a
## frame of seconds (stepkeep2). Nothing while the timeline is put away.
func replan() -> void:
	if not visible or _world == null:
		return
	await start(_world, _library, _scenery)


## [method start] with the steps already worked out, by whoever shared the
## model (SharedPages): nothing worked out here, in [param mode].
func start_from(steps: Array[Instructions.Step], mode: int, world: BrickWorld,
		library: PartLibrary, scenery: Dictionary = {}) -> bool:
	if _job != null or steps.is_empty():
		return false
	_library = library
	_world = world
	_scenery = scenery
	if not world.reveal_ended.is_connected(_on_reveal_ended):
		world.reveal_ended.connect(_on_reveal_ended)
	_authored = mode == AUTHORS
	_set_mode_quietly(mode)
	_steps = steps
	visible = true
	_reorder()
	_show(_step_ends[0] if not _step_ends.is_empty() else 1)
	return true


## Whether the steps are being worked out: pressing Timeline again then
## cancels it.
func is_starting() -> bool:
	return _job != null


func cancel_start() -> void:
	if _job != null:
		_job.cancelled = true


func stop() -> void:
	cancel_start()
	_stop_play()
	# Where it was left, for the same model's steps opened again.
	if visible and (_mode == 0 or _mode == AUTHORS) and _shown > 0 and not _steps.is_empty():
		_kept_at[_kept_key()] = _shown
	_close_more()
	if _go_sheet != null:
		_go_sheet.hide()
	_forget_ghosts()
	# The find goes with the timeline: opened again, on this model or the
	# next, it starts empty rather than with a list for steps no longer up.
	clear_find()
	visible = false
	if _compact:
		_lay_strip()
	# An empty set means "all of it" — leaving playback has to put the
	# model back, or the bricks after the current step stay missing.
	reveal.emit({})
	closed.emit()


func is_playing_back() -> bool:
	return visible


## The steps worked out at [method start], in the build order: the step
## player (BuildSteps) builds from these, so it numbers them as this does.
func steps() -> Array[Instructions.Step]:
	return _steps


## Its controls, for the page to find, while it is up.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named: Dictionary = _named.duplicate()
	# Go to a step's chips while it is open: steps_go_<number>.
	if _go_sheet != null and _go_sheet.visible:
		for number: int in _go_chips:
			named["steps_go_%d" % number] = _go_chips[number]
		if _go_runs.visible:
			for run: Node in _go_runs.get_children():
				named["steps_go_run_%s" % (run as Button).text.get_slice("-", 0)] = run
	return named


## What a person reads on it, for a browser check; nothing while it is down.
func page_state() -> Dictionary:
	if not visible:
		return {}
	return {"order": MODES[_mode], "caption": _caption.text, "pieces": _pieces.text,
		"at": [_shown, _length()],
		# How the booklet prints the step showing, as the Booklet row says.
		"look": _look_said.text if _looks != null and _looks.visible else "",
		# What the find says, and each step it lists (stepsearch).
		"find": _find.text, "found": _found_said.text if _found_said.is_visible_in_tree() else "",
		"found_steps": found_steps()}


## How many places along the timeline there are, and which is showing.
func timeline_at() -> Vector2i:
	return Vector2i(_shown, _length())


## Which order the timeline runs in: as made, or the build order.
func set_as_made(yes: bool) -> void:
	set_mode(1 if yes else 0)


## 0 the build order, 1 as made, 2 the history, 3 the author's steps.
func set_mode(mode: int) -> void:
	if mode == _mode:
		return
	var planned_by: bool = _mode == AUTHORS
	_set_mode_quietly(mode)
	if visible:
		_stop_play()
		var share: float = float(_shown) / maxf(_length(), 1.0)
		if planned_by != (mode == AUTHORS):
			_steps = _plan()
		_reorder()
		_show(int(round(share * _length())))


func _set_mode_quietly(mode: int) -> void:
	_mode = mode
	_order_button.text = MODES[mode]
	_edits.visible = mode == AUTHORS and editable
	# The row of steps for the steps a drop changes: the author's, or the
	# worked-out ones of a model that has none of its own yet.
	_row.visible = editable and (mode == AUTHORS or (mode == 0 and not _authored))
	# The booklet follows the build order or the author's steps, and an
	# edit of how a step is printed gives a model the worked-out steps
	# first, as a step edit does.
	_looks.visible = (mode == AUTHORS or mode == 0) and editable
	# A step found by what it places: in the orders that have steps.
	var stepped: bool = mode == AUTHORS or mode == 0
	_find_in_row.visible = stepped
	if not stepped:
		_found_line.visible = false
		if _find_sheet != null:
			_find_sheet.hide()


## The order after this one, the author's steps only for a model that has them.
func _next_mode() -> int:
	var next: int = (_mode + 1) % MODES.size()
	if next == AUTHORS and not _authored:
		next = 0
	return next


func mode() -> int:
	return _mode


## The steps for the order showing.
func _plan() -> Array[Instructions.Step]:
	return Instructions.plan(_world, _library, _scenery, {}, _mode == AUTHORS)


## The step the timeline is on, in the build order or the author's steps:
## the one whose end it shows, or is past the start of. Null in the other
## orders, and at an empty baseplate.
func current_step() -> Instructions.Step:
	var step: int = _current_index()
	return _steps[step] if step >= 0 else null


## Where [method current_step] is in [member _steps], or -1.
func _current_index() -> int:
	if not visible or _shown == 0 or _step_ends.is_empty() or not (_mode == 0 or _mode == AUTHORS):
		return -1
	var step: int = 0
	while step < _step_ends.size() - 1 and _step_ends[step] < _shown:
		step += 1
	# A callout's last step and the step that puts it on end together when
	# that step has no parts of its own: it is the step of the model that an
	# edit of "this step" means.
	while step < _step_ends.size() - 1 and _step_ends[step + 1] == _step_ends[step]:
		step += 1
	return step


## The step of the booklet's pages the timeline is on: the current step,
## or, inside a callout, the step that puts it on, whose page shows the
## callout and is the page a page break or a view is for.
func booklet_step() -> Instructions.Step:
	var at: Instructions.Step = current_step()
	if at == null or not at.in_callout():
		return at
	for step: Instructions.Step in _steps:
		if step.number == at.number and step.callout_step == 0:
			return step
	return at


## The step a part put down by hand goes in (Builder.place_step): the one
## showing, in the author's steps, when the part goes where that step is.
func place_step(path: String) -> int:
	if _mode != AUTHORS:
		return -1
	var at: Instructions.Step = current_step()
	if at == null or at.authored_step < 0 or at.authored_in != AuthorSteps.home(_world, path):
		return -1
	return at.authored_step


## The steps worked out again after the model or its steps changed, in the
## author's steps when it now has them, showing the end of the main step
## numbered [param number] (the one showing, when -1), or of its callout's
## step [param inside]. [param planned] is the author's steps planned
## already, as a step edit plans them to say where its parts went.
func refresh(number: int = -1, inside: int = 0,
		planned: Array[Instructions.Step] = []) -> void:
	if not visible:
		return
	var at: Instructions.Step = current_step()
	if number < 0:
		number = at.number if at != null else -1
	_authored = AuthorSteps.any(_world, _scenery)
	if _authored and _mode == 0:
		_set_mode_quietly(AUTHORS)
	_steps = planned if not planned.is_empty() and _mode == AUTHORS else _plan()
	if _steps.is_empty():
		stop()
		return
	_reorder()
	if _mode != 0 and _mode != AUTHORS:
		_show(_shown)
		return
	var end: int = -1
	for index: int in _steps.size():
		if _steps[index].number <= number:
			end = _step_ends[index]
		if inside > 0 and _steps[index].number == number and _steps[index].callout_step == inside:
			break
	_show(end if end >= 0 else (_step_ends[0] if not _step_ends.is_empty() else 0))


## How many places there are along the timeline.
## The order the world is shown it in, a count at a time, and the key
## it is shown by (BrickWorld.reveal_upto): the step player turns its pages
## by the same order, so the world the timeline laid out is laid out for it.
func reveal_order() -> Array:
	return [_order_packed, _order_key]


func _length() -> int:
	return _events.size() if _mode == 2 else _order.size()


func _reorder() -> void:
	_order.clear()
	_step_ends.clear()
	_step_of.clear()
	_events.clear()
	_forget_ghosts()
	if _mode == 2:
		_read_history()
	elif _mode == 1:
		# Brick numbers are handed out as bricks are placed, so in
		# number order is in the order they were placed.
		for step: Instructions.Step in _steps:
			for brick_id: int in step.brick_ids:
				_order.append(brick_id)
		_order.sort()
	else:
		# The build order, or the author's steps.
		for index: int in _steps.size():
			for brick_id: int in _steps[index].brick_ids:
				_order.append(brick_id)
				_step_of[brick_id] = index
			_step_ends.append(_order.size())
	_order_packed = PackedInt64Array(_order)
	_order_key += 1
	_slider.max_value = _length()
	_mark()
	# Found again in the steps as they are now: an edit moves what a step
	# places, and another order has other steps.
	_lots.clear()
	if _find != null and not _find.text.strip_edges().is_empty():
		_find_now()


## The changes since the baseplate was last cleared, and a brick for every
## one no longer standing, put back unseen for the timeline to show.
func _read_history() -> void:
	if _world == null:
		return
	var log: Array = _world.history
	var from: int = 0
	for n: int in log.size():
		if str((log[n] as Dictionary).get("op", "")) == "clear":
			from = n + 1
	# The baseplate is the ground, not part of the story.
	var ground_parts: Dictionary = {}
	for brick_id: int in _scenery:
		var one: BrickWorld.Brick = _world.get_brick(brick_id)
		if one != null:
			ground_parts[one.part_id] = true
	var standing: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		standing[_world.key_of(brick.id)] = brick.id
	var added: Dictionary = {}
	for n: int in range(from, log.size()):
		var event: Dictionary = log[n]
		var op: String = str(event.get("op", ""))
		if op == "add":
			if ground_parts.has(str(event["part"])):
				continue
			added[event["key"]] = event
			_events.append(["add", event["key"]])
		elif op == "remove" and added.has(event.get("key", "")):
			_events.append(["remove", event["key"]])
	for key: Variant in added:
		if standing.has(key):
			_drawn_as[key] = standing[key]
			continue
		var event: Dictionary = added[key]
		var ghost: int = _world.add_ghost(str(event["part"]), int(event["colour"]),
			event["at"])
		if ghost != 0:
			_ghosts.append(ghost)
			_ghost_set[ghost] = true
			_drawn_as[key] = ghost


## Take away the bricks put back for the history, and stop drawing them.
func _forget_ghosts() -> void:
	if _world != null:
		_world.clear_ghosts()
	_ghosts.clear()
	_ghost_set.clear()
	_drawn_as.clear()


## The next step's end in the build order; ten bricks on, as made.
func step_forward() -> void:
	_stop_play()
	var from: int = _shown
	_show(_next_stop(1))
	# The last step put on, a step forward from the step before it: the
	# model built to its end along its steps (Main counts it, for a link).
	# Never the timeline opening on the finished model, a jump to the end,
	# a drag or playback: those are looking, not building.
	if (_mode == 0 or _mode == AUTHORS) and not _step_ends.is_empty() \
			and _shown >= _length() and from < _length() \
			and from >= (_step_ends[-2] if _step_ends.size() >= 2 else 0):
		stepped_to_end.emit()
	stepped.emit()


func step_back() -> void:
	_stop_play()
	_show(_next_stop(-1))
	stepped.emit()


func to_start() -> void:
	_stop_play()
	_show(0)


func to_end() -> void:
	_stop_play()
	_show(_length())


## Play, or pause if already playing.
func toggle_play() -> void:
	_toggle(1)


func _next_stop(direction: int) -> int:
	if (_mode != 0 and _mode != AUTHORS) or _step_ends.is_empty():
		return _shown + 10 * direction
	if direction > 0:
		for end: int in _step_ends:
			if end > _shown:
				return end
		return _order.size()
	var stop_at: int = 0
	for end: int in _step_ends:
		if end >= _shown:
			break
		stop_at = end
	return stop_at


func _toggle(direction: int) -> void:
	if _playing == direction:
		_stop_play()
		return
	# Played from where it would have nothing to do, it starts from the
	# other end: forward from finished means from the start.
	if direction > 0 and _shown >= _length():
		_show(0)
	elif direction < 0 and _shown <= 0:
		_show(_length())
	_playing = direction
	set_process(true)
	_owed = 0.0
	_play.text = "Pause" if direction > 0 else "Play"
	_reverse.text = "Pause" if direction < 0 else "Reverse"


func _stop_play() -> void:
	_playing = 0
	if _play != null:
		_play.text = "Play"
		_reverse.text = "Reverse"


func is_playing() -> bool:
	return _playing != 0


func _speed_name() -> String:
	var speed: float = SPEEDS[_speed_at]
	return ("%dx" % int(speed)) if speed >= 1.0 else "%sx" % str(speed)


## Bricks a second at this speed.
func rate() -> float:
	var seconds: float = clampf(_length() * PER_BRICK, SHORTEST, LONGEST)
	return _length() / seconds * SPEEDS[_speed_at]


func _process(delta: float) -> void:
	# A find typed before the parts' search was made, made now.
	if _find_waiting and visible and _library != null and _library.search_ready():
		_find_now()
	if _playing == 0 or not visible:
		# Asleep unless playing or a find waits for the search (Wake).
		if not _find_waiting:
			Wake.rest(self)
		return
	_owed += delta * rate()
	var whole: int = int(_owed)
	if whole == 0:
		return
	_owed -= whole
	var to: int = _shown + whole * _playing
	if to >= _length() or to <= 0:
		_show(clampi(to, 0, _length()))
		_stop_play()
		return
	_show(to)


func shown() -> int:
	return _shown


func _show(count: int) -> void:
	if _mode == 2:
		_show_history(count)
		return
	if _order.is_empty():
		return
	_shown = clampi(count, 0, _order.size())
	_slider.set_value_no_signal(_shown)

	var of: String = "%d of %d bricks" % [_shown, _order.size()]
	if _mode == 1 or _step_ends.is_empty():
		_caption.text = of
		_pieces.text = "As made: the order the bricks standing were placed in" \
			if _mode == 1 else ""
	else:
		var step: int = 0
		while step < _step_ends.size() - 1 and _step_ends[step] < _shown:
			step += 1
		# Numbered as the booklet numbers them, so "step 12" here is step
		# 12 on the page: a callout's steps carry the number of the step
		# its assembly goes on in, and are counted inside it.
		var at: Instructions.Step = _steps[step]
		# A person's words, as they wrote them in every language: each name
		# said, the step's own and the one it starts (Step.called).
		for name: String in at.shortened_name(NAME_SHOWN).split(" · ", false):
			Language.keep_name(name)
		_caption.text = "%s · %s" % [at.caption(_steps[-1].number, " · ", NAME_SHOWN), of]
		if _shown == 0:
			_pieces.text = "An empty baseplate" + (": the steps are the author's"
				if _mode == AUTHORS else "")
		else:
			_pieces.text = at.summary(_library)
			# A callout is built on the side in the booklet; here it goes
			# up where it will stand, the only place the world can show it.
			if at.in_callout() and at.callout_step == at.callout_steps:
				_pieces.text += " — then put %s on" % ("them" if at.times > 1 else "it")
			if at.unsupported:
				# Worth saying. The alternative is a step that looks wrong
				# to anyone following it with real bricks in their hands.
				_pieces.text += "  (hold this one in place)"
	if _compact:
		_show_compact()
	_pieces.tooltip_text = _pieces.text
	_row.queue_redraw()
	_light_found()
	_show_look()
	# Everything up to here, as a count of the order: going backwards is the
	# same path as forwards. It was every brick up to here gathered again,
	# and every brick in the model asked whether it was among them.
	reveal_upto.emit(_order_packed, _shown, _order_key)


## How the booklet prints the step showing: the toggles as it is set, and
## a line saying so.
func _show_look() -> void:
	if _looks == null or not _looks.visible:
		return
	var at: Instructions.Step = booklet_step()
	var section: String = at.authored_in if at != null else ""
	var step: int = at.authored_step if at != null else -1
	var own: Dictionary = BookletLooks.of(_world, section, step) if step >= 0 else {}
	(_look_toggles["new_page"] as Button).set_pressed_no_signal(str(own.get("page", "")) == "new")
	(_look_toggles["alone"] as Button).set_pressed_no_signal(str(own.get("page", "")) == "alone")
	(_look_toggles["parts"] as Button).set_pressed_no_signal(bool(own.get("parts", true)))
	var unit: String = BookletLooks.attached(_world, at, section) if at != null else ""
	var callout: Button = _look_toggles["callout"]
	callout.disabled = unit.is_empty()
	callout.set_pressed_no_signal(not unit.is_empty() and BookletLooks.callout_on(_world, unit))
	(_look_toggles["highlight"] as Button).set_pressed_no_signal(BookletLooks.highlight_on(_world))
	var most: int = int(BookletLooks.booklet(_world).get("per_page", 0))
	_per_page.text = "Per page: %s" % ("as fit" if most == 0 else str(most))
	var said: String = BookletLooks.said(_world, section, step) if step >= 0 else ""
	_look_said.text = said if not said.is_empty() else "as the booklet chooses"
	# A callout's step: its own view first, which the view buttons turn.
	var inside: Instructions.Step = current_step()
	if inside != null and inside.in_callout():
		var turned: String = BookletLooks.turn_said(_world, inside.authored_in, inside.authored_step) \
			if inside.authored_step >= 0 else ""
		_look_said.text = "%s step %d %s; step %d %s" % [inside.assembly, inside.callout_step,
			turned if not turned.is_empty() else "as the callout faces", at.number, _look_said.text]
	_look_said.tooltip_text = _look_said.text


## The world stopped showing the order a count at a time: something changed
## a batch of it, or a cut or x-ray went on. Shown again as it was, once
## whatever changed it has finished.
func _on_reveal_ended() -> void:
	if visible and _mode != 2 and not _order.is_empty() and not _reshowing:
		_reshowing = true
		_reshow.call_deferred()


func _reshow() -> void:
	_reshowing = false
	if visible and _mode != 2 and not _order.is_empty():
		_show(_shown)


## The history up to the [param count]th change: what was standing then,
## including what has since been taken away.
func _show_history(count: int) -> void:
	if _events.is_empty():
		return
	_shown = clampi(count, 0, _events.size())
	_slider.set_value_no_signal(_shown)
	var alive: Dictionary = {}
	for n: int in _shown:
		var event: Array = _events[n]
		if event[0] == "add":
			alive[event[1]] = true
		else:
			alive.erase(event[1])
	var showing: Dictionary = _scenery.duplicate()
	var gone: int = 0
	for key: Variant in alive:
		if _drawn_as.has(key):
			showing[_drawn_as[key]] = true
			if _ghost_set.has(int(_drawn_as[key])):
				gone += 1
	_caption.text = "Change %d of %d · %d standing" % [_shown, _events.size(), alive.size()]
	_pieces.text = ("History: every change, removals included" + (
		" — %d of these were taken out later" % gone if gone > 0 else ""))
	if _compact:
		_show_compact()
	_pieces.tooltip_text = _pieces.text
	reveal.emit(showing)


# -- any step in one go (steps3) ----------------------------------------------


## The row of steps under the slider, one cell a step: drawn here, and its
## clicks, drags and drops answered here.
class StepRow extends Control:
	const TALL := 16.0
	var bar: StepsBar
	## The step the selection is being dragged over, or -1.
	var over: int = -1

	func _draw() -> void:
		bar._draw_row(self)

	func _gui_input(event: InputEvent) -> void:
		bar._row_input(self, event)

	func _get_drag_data(at: Vector2) -> Variant:
		return bar._row_drag(self, at)

	func _can_drop_data(at: Vector2, data: Variant) -> bool:
		return bar._row_can_drop(self, at, data)

	func _drop_data(at: Vector2, data: Variant) -> void:
		bar._row_drop(self, at, data)

	func _get_tooltip(at: Vector2) -> String:
		return bar._row_tip(self, at)

	func _notification(what: int) -> void:
		if what in [NOTIFICATION_DRAG_END, NOTIFICATION_MOUSE_EXIT] and over >= 0:
			over = -1
			queue_redraw()


func _on_selection_changed(_count: int) -> void:
	if visible:
		_mark()


## The steps the selection is in, marked on the row.
func _mark() -> void:
	_marked.clear()
	if shell != null and visible:
		for brick_id: Variant in shell.builder.selection:
			if _step_of.has(brick_id):
				_marked[_step_of[brick_id]] = true
	_row.queue_redraw()


## The step under [param at] on the row, by its place in [member _steps].
func _cell_at(row: StepRow, at: Vector2) -> int:
	return clampi(int(at.x / maxf(row.size.x, 1.0) * _steps.size()), 0, _steps.size() - 1)


func _draw_row(row: StepRow) -> void:
	if _steps.is_empty() or _step_ends.is_empty():
		return
	var wide: float = row.size.x / _steps.size()
	var tall: float = row.size.y
	var lit: int = _current_index()
	var font: Font = row.get_theme_default_font()
	var gap: float = 1.0 if wide >= 4.0 else 0.0
	var words_room: float = 0.0
	for index: int in _steps.size():
		var step: Instructions.Step = _steps[index]
		var box := Rect2(index * wide, 0.0, maxf(wide - gap, 1.0), tall)
		# A callout's steps are built on the side: shorter than the model's.
		if step.in_callout():
			box = box.grow_individual(0.0, -3.0, 0.0, 0.0)
		var fill: Color = Color(1, 1, 1, 0.16) if lit >= 0 and index < lit else Color(1, 1, 1, 0.07)
		if index == lit:
			fill = Look.CHOSEN
		if index == row.over:
			fill = Look.STRONG
		row.draw_rect(box, fill)
		# A step the find found, marked along its top, as the selection's
		# steps are along their foot.
		if _hit_set.has(index):
			row.draw_rect(Rect2(box.position.x, 0.0, box.size.x, 3.0), Look.ACCENT)
		if _marked.has(index):
			row.draw_rect(Rect2(box.position.x, tall - 4.0, box.size.x, 4.0), SelectionOutline.SELECTED)
		if index == row.over:
			row.draw_rect(box, Look.ACCENT, false, 1.0)
		# Its number on the first cell of the number, where there is room
		# for it before the next number's.
		words_room -= wide
		if index > 0 and _steps[index - 1].number == step.number:
			continue
		# Measured only where a number could fit: a big model's hundreds of
		# steps a pixel or two wide are drawn a frame at a time in playback.
		if words_room > 0.0 or _cell_span(index) * wide < 10.0:
			continue
		var text: String = str(step.number)
		var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		if size.x + 4.0 > _cell_span(index) * wide:
			continue
		var baseline: float = (tall - 4.0 + font.get_ascent(10) - font.get_descent(10)) / 2.0
		row.draw_string(font, Vector2(box.position.x + 2.0, baseline), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.82))
		words_room = size.x + 4.0


## How many cells from [param index] carry its number: a callout's steps
## and the step that puts it on.
func _cell_span(index: int) -> int:
	var span: int = 1
	while index + span < _steps.size() and _steps[index + span].number == _steps[index].number:
		span += 1
	return span


## A click on a step shows it; dragged along with nothing taken, the row
## scrubs as the slider does.
func _row_input(row: StepRow, event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_row_from = _cell_at(row, button.position)
		_show_cell(_row_from)
		row.accept_event()
	# Not from the selection's mark, which is the start of a drag of it.
	elif motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT != 0 \
			and not _marked.has(_row_from) and not row.get_viewport().gui_is_dragging():
		_show_cell(_cell_at(row, motion.position))
		row.accept_event()


func _show_cell(index: int) -> void:
	if index < 0 or index >= _step_ends.size():
		return
	if _step_ends[index] != _shown:
		_stop_play()
		_show(_step_ends[index])


## The selection taken from its mark: what a drop moves.
func _row_drag(row: StepRow, at: Vector2) -> Variant:
	if not editable or shell == null or shell.read_only or shell.builder.selection.is_empty():
		return null
	if not _marked.has(_cell_at(row, at)):
		return null
	_stop_play()
	var ids: Array = shell.builder.selection.keys()
	var tag := Label.new()
	tag.add_theme_font_size_override("font_size", 12)
	var face := StyleBoxFlat.new()
	face.bg_color = Look.FACE
	face.border_color = SelectionOutline.SELECTED
	face.set_border_width_all(1)
	face.set_corner_radius_all(4)
	face.content_margin_left = 8
	face.content_margin_right = 8
	face.content_margin_top = 3
	face.content_margin_bottom = 3
	tag.add_theme_stylebox_override("normal", face)
	tag.text = "Move %s to a step" % _parts_words(ids.size())
	tag.position = Vector2(14, -30)
	var holder := Control.new()
	holder.add_child(tag)
	row.set_drag_preview(holder)
	return {"steps_to": ids, "tag": tag}


func _row_can_drop(row: StepRow, at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and (data as Dictionary).has("steps_to")):
		return false
	var index: int = _cell_at(row, at)
	if row.over != index:
		row.over = index
		row.queue_redraw()
		var tag: Variant = data.get("tag")
		if is_instance_valid(tag):
			(tag as Label).text = "Move %s to %s" % [_parts_words((data["steps_to"] as Array).size()),
				_step_words(_steps[index])]
	return true


## The selection put in the step it was dropped on: one undo, the booklet's
## plan and each step's look following (Shell.change_steps).
func _row_drop(row: StepRow, at: Vector2, data: Variant) -> void:
	row.over = -1
	var said: String = shell.change_steps("to", data["steps_to"], _steps[_cell_at(row, at)])
	shell.bar.say(said)


func _row_tip(row: StepRow, at: Vector2) -> String:
	if _steps.is_empty():
		return ""
	var index: int = _cell_at(row, at)
	var step: Instructions.Step = _steps[index]
	var said: String = step.caption(_steps[-1].number)
	if _marked.has(index):
		return said + ": the selection is in it. Drag it from here onto another step to move it there"
	var adds: String = step.summary(_library) if _library != null else ""
	return said + (": " + adds if not adds.is_empty() else "") + ". Click to show it"


static func _parts_words(count: int) -> String:
	return "1 part" if count == 1 else "%d parts" % count


static func _step_words(step: Instructions.Step) -> String:
	if step.in_callout():
		return "the %s's step %d, in step %d" % [step.assembly, step.callout_step, step.number]
	return "step %d" % step.number


## Move to step…: the selection into the step whose number is typed,
## however far it is, as Studio's Move To. The number starts as the step
## they are in, chosen, so a number typed replaces it; Return moves them.
func ask_step_to() -> void:
	if shell == null or shell.read_only:
		return
	var ids: Array = shell.builder.selection.keys()
	if ids.is_empty():
		shell.bar.say("select the parts first")
		return
	var steps: Array[Instructions.Step] = _steps if visible and _row.visible \
		else Instructions.plan(shell.world, shell.library, shell.store.scenery, {}, true)
	if steps.is_empty():
		shell.bar.say("there is nothing built to have steps")
		return
	if _ask == null:
		_make_ask()
	_ask_ids = ids
	_ask_steps = steps
	var from: int = steps[0].number
	for step: Instructions.Step in steps:
		if step.brick_ids.has(int(ids[0])):
			from = step.number
			break
	_ask_words.text = "Move %s to step" % _parts_words(ids.size())
	_ask_of.text = "of %d" % steps[-1].number
	_ask_number.max_value = steps[-1].number
	_ask_number.value = from
	_ask.popup_centered()
	# After the dialog has given its own button the focus, as it does when shown.
	var typed: LineEdit = _ask_number.get_line_edit()
	typed.grab_focus.call_deferred()
	typed.select_all.call_deferred()


func _make_ask() -> void:
	_ask = ConfirmationDialog.new()
	_ask.title = "Move to step"
	_ask.ok_button_text = "Move"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_ask_words = Label.new()
	row.add_child(_ask_words)
	_ask_number = SpinBox.new()
	_ask_number.min_value = 1
	_ask_number.step = 1
	_ask_number.rounded = true
	_ask_number.update_on_text_changed = true
	_ask_number.custom_minimum_size = Vector2(90, 0)
	_ask_number.accessibility_name = "Step"
	row.add_child(_ask_number)
	_ask_of = Label.new()
	row.add_child(_ask_of)
	_ask.add_child(row)
	_ask.register_text_enter(_ask_number.get_line_edit())
	_ask.confirmed.connect(_move_asked)
	shell.add_child(_ask)


func _move_asked() -> void:
	var number: int = int(_ask_number.value)
	var at: Instructions.Step = null
	for step: Instructions.Step in _ask_steps:
		if step.number == number and (at == null or step.callout_step == 0):
			at = step
	if at == null:
		shell.bar.say("there is no step %d: the steps run 1 to %d" % [number, _ask_steps[-1].number])
		return
	shell.bar.say(shell.change_steps("to", _ask_ids, at))


## Name the step… (stepnames, APP_UX6 #9): the step the timeline is on given
## a name, typed, as Studio names a step; said beside its number here, in
## Build it and in the booklet, and kept in the file. The words start as its
## name, chosen, so what is typed replaces it; Return names it, and an empty
## name takes it off. One of only what draws nothing is refused where it was
## typed: the dialog stays, saying why (sncheck N2).
var _naming: ConfirmationDialog
var _naming_field: LineEdit
var _naming_words: Label
var _naming_why: Label
var _naming_step: Instructions.Step


func ask_step_name() -> void:
	if shell == null or shell.read_only or not editable:
		return
	var at: Instructions.Step = current_step()
	if at == null:
		shell.bar.say("go to a step on the timeline first")
		return
	if _naming == null:
		_make_naming()
	_naming_step = at
	_naming_words.text = ("Step %d, %s %d of %d, is called" % [at.number, at.assembly,
		at.callout_step, at.callout_steps]) if at.in_callout() else "Step %d is called" % at.number
	_naming_field.text = at.name
	_naming_why.visible = false
	_naming.popup_centered()
	_naming_field.grab_focus.call_deferred()
	_naming_field.select_all.call_deferred()


func _make_naming() -> void:
	_naming = ConfirmationDialog.new()
	_naming.title = "Name the step"
	_naming.ok_button_text = "Save"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_naming_words = Label.new()
	column.add_child(_naming_words)
	_naming_field = LineEdit.new()
	_naming_field.placeholder_text = "Build the cockpit"
	_naming_field.max_length = BookletLooks.NAME_MOST
	_naming_field.custom_minimum_size = Vector2(320, 0)
	_naming_field.accessibility_name = "The step's name"
	column.add_child(_naming_field)
	_naming_why = Label.new()
	_naming_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_naming_why.custom_minimum_size = Vector2(320, 0)
	_naming_why.visible = false
	column.add_child(_naming_why)
	_naming.add_child(column)
	# Put away by hand once named, so a refused name keeps it up.
	_naming.dialog_hide_on_ok = false
	_naming.register_text_enter(_naming_field)
	_naming.confirmed.connect(_name_asked)
	shell.add_child(_naming)


func _name_asked() -> void:
	if _naming_step == null:
		return
	var refused: String = BookletLooks.name_refused(_naming_field.text)
	_naming_why.text = refused
	_naming_why.visible = not refused.is_empty()
	if not refused.is_empty():
		_naming_field.grab_focus()
		_naming_field.select_all()
		return
	_naming.hide()
	shell.bar.say(shell.change_look("name", _naming_step, {"name": _naming_field.text}))


## Its row of steps, for a check: each cell's place, and which are marked.
func row_state() -> Dictionary:
	return {"shown": _row.visible and visible, "cells": _steps.size(), "rect": _row.get_global_rect(),
		"marked": _marked.keys(), "lit": _current_index(), "found": _hit_set.keys()}


# -- find a step by what it places (stepsearch, APP_UX9 #13) -------------------
#
# A builder hunting the step that put on a red 2 x 4 paged through every
# step; LPub3D and Studio's instructions editor find no step by its parts
# either. Here a part's number, its name or its colour typed in the bar lists
# every step that places one, as it is typed, each a button that goes there
# as Next goes to a step (on a shared link's timeline its new parts outlined
# and in view, Main._light_step). The row of steps
# marks them along their top, and Enter goes to each in turn (Shift+Enter
# back), Escape clears it.
#
# The words are read as Edit, Select by, Part number or name and the parts
# list's find read them (SelectBy.wanted): a number ("3001", 3023 for 3023b
# too), a name in the catalogue's words or a builder's ("brick 2 x 4", "2x4
# brick"), a colour the model has by LDraw's or LEGO's name ("red", "dark
# bluish grey"), or a colour and a part together ("red 3001"), every word
# needed. A part in a sub-model is found in the sub-model's own step that
# puts it on, in the callout ("12 · Wing 2/3") or built where it stands ("12 ·
# Wing"), counted for every copy, never in the step that puts the finished
# sub-model on, which places the sub-model and not the part. Nothing found
# says so, and where the part is in the model in another colour, which.
#
# On a phone or a tablet the on-screen keyboard covers the foot of the
# screen, where the bar is: there Find… opens the field and its list in a
# sheet, which the layout for a finger keeps above the keyboard
# (TouchSizing), as it does Move to step… and Name….
#
# In the row of buttons the field is as wide as the row has room for, from
# FindSlot.LEAST to FindSlot.MOST, its words cut to "Find a step" where the
# whole of them would not show. At a fixed 200 it wrapped Instructions and
# Done onto a second line at 1280 x 720 with the bin open, the window a
# first visit gets (smalls6; the row's least was 859 units of its 817).


## The find's field in the row of buttons: no less than LEAST wide, so the
## row's least width (where the flow wraps it) has it at LEAST; as wide as
## the row leaves it, up to MOST, with the rest of the line beyond it, so
## Instructions and Done stay at the line's right-hand end. Its placeholder
## the whole of its words where they show whole, else the short ones.
class FindSlot extends Container:
	const LEAST := 120.0
	const MOST := 240.0
	var field: LineEdit
	var words: String = ""
	var short: String = ""

	func _get_minimum_size() -> Vector2:
		return Vector2(LEAST, field.get_combined_minimum_size().y if field != null else 0.0)

	func _notification(what: int) -> void:
		# Another language's words, or another size of them, need their own
		# width: laid out again.
		if what in [NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_THEME_CHANGED]:
			queue_sort()
			return
		if what != NOTIFICATION_SORT_CHILDREN or field == null:
			return
		var wide: float = clampf(size.x, LEAST, MOST)
		fit_child_in_rect(field, Rect2(0.0, 0.0, wide, size.y))
		var font: Font = field.get_theme_font("font")
		var needs: float = font.get_string_size(field.tr(words), HORIZONTAL_ALIGNMENT_LEFT, -1,
			field.get_theme_font_size("font_size")).x \
			+ field.get_theme_stylebox("normal").get_minimum_size().x
		field.placeholder_text = words if wide >= needs else short


func _build_find(row: Container, column: Container) -> void:
	_find = LineEdit.new()
	_find.placeholder_text = "Find a step by part or colour"
	_find.accessibility_name = "Find a step by part or colour"
	_find.tooltip_text = ("The steps that place a part, found by its number (3001), its name "
		+ "(brick 2 x 4), its colour (red) or both (red 3001). Enter goes to each in turn, "
		+ "Escape clears it")
	_find.clear_button_enabled = true
	# Enter again goes to the next, so the field stays being typed in (and
	# keeps the keys: FocusGuard lets a field go on Enter).
	_find.keep_editing_on_text_submit = true
	_find.set_meta("keep_focus_on_enter", true)
	# Escape empties it and keeps the keys for the next words, as the
	# library's search does, and empty is any field's Escape (FocusGuard:
	# given on, the first Escape had put the timeline away with the find).
	_find.set_meta(FocusGuard.CLEAR_ON_ESCAPE, true)
	_find.add_theme_font_size_override("font_size", 11)
	_find.text_changed.connect(func(_text: String) -> void: _find_now())
	_find.text_submitted.connect(func(_text: String) -> void: find_next(1))
	_find.gui_input.connect(_find_key)
	_found_line = HFlowContainer.new()
	_found_line.add_theme_constant_override("h_separation", 4)
	_found_line.add_theme_constant_override("v_separation", 4)
	_found_line.visible = false
	_found_said = Label.new()
	_found_said.add_theme_font_size_override("font_size", 11)
	_found_said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_found_line.add_child(_found_said)
	_named["steps_found"] = _found_line
	if not Phone.on():
		var slot := FindSlot.new()
		slot.field = _find
		slot.words = _find.placeholder_text
		slot.short = "Find a step"
		# The line's room beyond the buttons is the field's, as far as MOST,
		# before Instructions and Done take what is left at its end.
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_stretch_ratio = 100.0
		slot.add_child(_find)
		row.add_child(slot)
		_find_in_row = slot
		_named["steps_find"] = _find
		column.add_child(_found_line)
		return
	var open: Button = _button("Find…", "Find the steps that place a part, by its number, "
		+ "its name or its colour")
	open.pressed.connect(open_find)
	row.add_child(open)
	_find_in_row = open
	_named["steps_find"] = open
	_find.custom_minimum_size = Vector2(260, 0)
	_find_box = VBoxContainer.new()
	_find_box.add_theme_constant_override("separation", 6)
	_find_box.add_child(_find)
	_find_box.add_child(_found_line)


## On a phone or a tablet, Find…: the field and its list in a sheet above the
## keyboard, the field ready to type in. Done puts it away, and the steps
## it found stay marked on the row.
func open_find() -> void:
	if _find_sheet == null:
		_find_sheet = AcceptDialog.new()
		_find_sheet.title = "Find a step"
		_find_sheet.ok_button_text = "Done"
		_find_sheet.add_child(_find_box)
		var holder: Node = self
		if shell != null:
			holder = shell
		holder.add_child(_find_sheet)
	_find_sheet.popup_centered()
	_find.grab_focus.call_deferred()


## The field emptied, and with it the list and the row's marks.
func clear_find() -> void:
	if _find == null:
		return
	_find.text = ""
	_find_now()


## Shift+Enter goes back to the step found before (Escape is FocusGuard's).
func _find_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.shift_pressed \
			and key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		find_next(-1)
		_find.accept_event()


## The steps that place what the field says, listed and marked: at every key,
## within the frame it was typed in.
func _find_now() -> void:
	_find_waiting = false
	var said: String = _find.text.strip_edges()
	if said.is_empty() or _steps.is_empty() or _step_ends.is_empty() or _world == null \
			or _library == null:
		_hits = []
		_hit_set = {}
		_found_line.visible = false
		_row.queue_redraw()
		return
	# Names are found by the parts' search, made ahead as the app starts (the
	# bin asks for it); one typed before it is made waits for it, a frame at a
	# time, rather than hold the window while it is made (_process).
	if not _library.search_ready():
		_library.prepare_search(true)
		_find_waiting = true
		set_process(true)
		_hits = []
		_hit_set = {}
		_say_found("Reading the parts…", false)
		for chip: Button in _found_chips:
			chip.visible = false
		_row.queue_redraw()
		return
	if _lots.is_empty():
		_lots = step_lots(_steps, _world)
	var found: Dictionary = find_in(_lots, _library, said)
	_hits = found["hits"]
	_hit_set = {}
	for hit: Array in _hits:
		_hit_set[int(hit[0])] = true
	var most: int = FOUND_MOST_PHONE if Phone.on() and not Phone.wide() else FOUND_MOST
	var words: String = ""
	if _hits.is_empty():
		words = none_words(_library, said, found["other"])
	elif _hits.size() == 1:
		words = "“%s” is placed in 1 step" % said
	elif _hits.size() <= most:
		words = "“%s” is placed in %d steps: Enter goes to each in turn" % [said, _hits.size()]
	else:
		words = "“%s” is placed in %d steps, the first %d here: Enter goes to each in turn" % [
			said, _hits.size(), most]
	_say_found(words, _hits.is_empty())
	var last: int = _steps[-1].number
	var listed: int = mini(_hits.size(), most)
	for n: int in listed:
		var hit: Array = _hits[n]
		var step: Instructions.Step = _steps[int(hit[0])]
		var chip: Button = _chip(n)
		chip.text = found_words(step, int(hit[1]))
		var placed := Instructions.Step.new()
		placed.parts = hit[2]
		chip.tooltip_text = "%s: %s. Click to show it" % [step.caption(last), placed.summary(_library)]
		chip.set_meta("step", int(hit[0]))
		chip.visible = true
	for n: int in range(listed, _found_chips.size()):
		_found_chips[n].visible = false
	_light_found()
	_row.queue_redraw()


## Nothing found: said so, and where what was asked is in the model in
## another colour, in which ("red 3001" where the 3001s are blue); [param
## other] is find_in's.
static func none_words(library: PartLibrary, said: String, other: Dictionary) -> String:
	if other.size() == 1:
		var colour: PartLibrary.BrickColor = library.color(int(other.keys()[0]))
		if colour != null:
			return "No step places “%s”: the model has it in %s" % [said,
				colour.name.replace("_", " ")]
	if other.size() > 1:
		return "No step places “%s”: the model has it in %d other colours" % [said, other.size()]
	return "No step places “%s”" % said


func _say_found(words: String, none: bool) -> void:
	_found_said.text = words
	_found_said.modulate = Color(1.0, 0.78, 0.6) if none else Color(1, 1, 1, 0.82)
	_found_line.visible = true
	if none:
		for chip: Button in _found_chips:
			chip.visible = false


## The [param n]th of the list's buttons, made the first time it is wanted.
func _chip(n: int) -> Button:
	while _found_chips.size() <= n:
		var chip: Button = _button("", "")
		chip.toggle_mode = true
		chip.custom_minimum_size = Vector2(28, 0)
		chip.pressed.connect(func() -> void: go_to_found(int(chip.get_meta("step", -1))))
		_found_line.add_child(chip)
		_found_chips.append(chip)
	return _found_chips[n]


## How the list names a step found: its number as the booklet prints it, a
## sub-model's step with the sub-model and its place in its own steps, and
## how many it places where that is more than one: "12 · Wing 2/3 ×4".
static func found_words(step: Instructions.Step, count: int) -> String:
	var said: String = str(step.number)
	if step.in_callout():
		Language.keep_name(step.assembly)
		said += " · %s %d/%d" % [step.assembly, step.callout_step, step.callout_steps]
	elif step.callout == 0 and step.authored_step >= 0 and not step.authored_in.is_empty():
		var named: String = Instructions._name_of(step.authored_in)
		Language.keep_name(named)
		said += " · %s" % named
	if count > 1:
		said += " ×%d" % count
	return said


## The found step at [param index] in [member _steps] shown, as Next shows a
## step: the model built to its end ([signal stepped]: a shared link's
## viewer outlines its new parts and frames them).
func go_to_found(index: int) -> void:
	if index < 0 or index >= _step_ends.size():
		return
	_stop_play()
	_show(_step_ends[index])
	stepped.emit()


## Enter: the next step found after the one showing, round to the first;
## Shift+Enter ([param direction] -1) the one before it.
func find_next(direction: int) -> void:
	if _hits.is_empty():
		return
	var at: int = _current_index()
	var pick: int = int(_hits[0][0]) if direction > 0 else int(_hits[-1][0])
	if direction > 0:
		for hit: Array in _hits:
			if int(hit[0]) > at:
				pick = int(hit[0])
				break
	else:
		for n: int in range(_hits.size() - 1, -1, -1):
			if int(_hits[n][0]) < at:
				pick = int(_hits[n][0])
				break
	go_to_found(pick)


## The list's button for the step showing pressed in, the rest not.
func _light_found() -> void:
	if _found_chips.is_empty():
		return
	var lit: int = _current_index()
	for chip: Button in _found_chips:
		if chip.visible:
			chip.set_pressed_no_signal(int(chip.get_meta("step", -1)) == lit)


## What the find lists, for a check: each step found, in step order, with
## its place in the steps, its number, its place in a callout (0 for none),
## how many it places, and its button's words ("" past those listed).
func found_steps() -> Array:
	var out: Array = []
	for n: int in _hits.size():
		var hit: Array = _hits[n]
		var step: Instructions.Step = _steps[int(hit[0])]
		var chip: Button = _found_chips[n] if n < _found_chips.size() else null
		out.append({"index": int(hit[0]), "step": step.number, "inside": step.callout_step,
			"count": int(hit[1]), "words": chip.text if chip != null and chip.visible else ""})
	return out


## The field, or on a phone the sheet's, for a check to type in.
func find_field() -> LineEdit:
	return _find


## Each of [param steps]' parts by part and colour, a Dictionary a step in
## their order: part id -> {LDraw colour -> how many}. A callout's step has
## every copy's (Step.brick_ids); the step that puts a sub-model on, only
## the parts it puts on beside it.
static func step_lots(steps: Array[Instructions.Step], world: BrickWorld) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for step: Instructions.Step in steps:
		var lots: Dictionary = {}
		for brick_id: int in step.brick_ids:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick == null:
				continue
			if not lots.has(brick.part_id):
				lots[brick.part_id] = {}
			var colours: Dictionary = lots[brick.part_id]
			colours[brick.color_code] = int(colours.get(brick.color_code, 0)) + 1
		out.append(lots)
	return out


## The steps of [param lots] (step_lots) that place what [param said] asks
## for, read as SelectBy.wanted reads it with the model's colours: {"hits":
## each such step, [its place, how many it places, part id -> how many], in
## their order; "other": where a part was asked in a colour and no step
## places it in that one, each other colour the model has it in -> how many;
## "parts": the model's part ids that answer -> true; "colour": the LDraw
## colour asked, or -1 for any}.
static func find_in(lots: Array[Dictionary], library: PartLibrary, said: String) -> Dictionary:
	var colours: Dictionary = {}
	var ids: Dictionary = {}
	for step_lots: Dictionary in lots:
		for part_id: String in step_lots:
			ids[part_id] = true
			for code: int in step_lots[part_id]:
				colours[code] = true
	# SelectBy is compiled at its first use, not with the window (Later): the
	# timeline is on the first screen. Its Wanted read by name.
	var wanted: RefCounted = Later.script(&"SelectBy").wanted(library, said, colours)
	var any_part: bool = bool(wanted.get("any_part"))
	var wanted_parts: Dictionary = wanted.get("parts")
	var wanted_colour: int = int(wanted.get("colour"))
	# The model's numbers that answer: as they are, or as the number a part
	# moved to (a file's 3794 is 15573).
	var takes: Dictionary = {}
	for part_id: String in ids:
		if any_part or wanted_parts.has(part_id) or wanted_parts.has(library.resolve(part_id)):
			takes[part_id] = true
	var hits: Array = []
	var other: Dictionary = {}
	for index: int in lots.size():
		var count: int = 0
		var parts: Dictionary = {}
		for part_id: String in lots[index]:
			if not takes.has(part_id):
				continue
			var by_colour: Dictionary = lots[index][part_id]
			for code: int in by_colour:
				if wanted_colour < 0 or code == wanted_colour:
					count += int(by_colour[code])
					parts[part_id] = int(parts.get(part_id, 0)) + int(by_colour[code])
				elif not any_part:
					other[code] = int(other.get(code, 0)) + int(by_colour[code])
		if count > 0:
			hits.append([index, count, parts])
	return {"hits": hits, "other": other if hits.is_empty() else {}, "parts": takes,
		"colour": wanted_colour}
