## Build your first model: seven short steps, each done in the app rather
## than read about (docs/APP_UX.md A12). Along the top of the model, never
## over it: one line saying one thing to do, a frame round what to do it
## with (the bin, a colour, a tool on the toolbar, the view cube, Save),
## and the key the person's keys give it (Keymap), never a fixed one.
##
## A step moves on when the app has done it, whatever way it was asked for:
## a key, a click, a menu, Find a command or a number typed. So this does not
## listen to the input at all. It looks at the model as the step began and as
## it is now (a part more, a part turned or recoloured, one moved, one more of
## a part and colour already there), at the view's turn and tilt, and for the
## model's save.
##
## It replaced an eight-card tour that pointed at the panels and changed
## nothing. Studio opens with a tutorial at first launch; this is shorter and
## never stands in the way of somebody who knows what they are doing:
## offered once, on a first visit, with nothing changed until Start (so the
## example car is still there to look at), one click on Skip ends it, and it
## never comes back uninvited. Help, Take the tour brings it back.
class_name FirstBuild
extends PanelContainer

## The steps, in order, and their names on the line.
const STEPS: Array[String] = ["put", "turn", "colour", "move", "copy", "view", "save"]
const TITLES: Dictionary = {"put": "Put a part down", "turn": "Turn it", "colour": "Colour it",
	"move": "Move it", "copy": "Copy it", "view": "Turn the view", "save": "Save it"}
## What the model is called, a number after it where a saved one has it
## already (ModelStore.begin).
const MODEL_NAME := "My first model"
## How far the view must turn or tilt for the view's step: 1 to 7 from the
## view a model opens at are 13 degrees or more.
const VIEW_TURN := deg_to_rad(10.0)
## How long a first visit waits, once signed in, for the account to say
## whether there is a model of the person's to open instead (Main._open_theirs).
const LOOK_WAIT_MS := 6000
## Under this much room across, the line goes without its title.
const NARROW := 560.0

## A probe about the first visit offers it for itself, as one about the
## assistant's offer does (Main.offer_for_probe). Any other run under
## --script is a tool or a test, and nobody is offered anything.
static var offered_for_probe: bool = false

var shell: Shell

## Where it is: -1 the offer, a step's index, or STEPS.size() for the end.
var _at: int = -1
## Each part of the model as the step began: id -> [part, colour, place].
var _was: Dictionary = {}
## The view's turn and tilt as the step began.
var _view_was: Vector2 = Vector2.ZERO
## Whether the model was saved since the step began.
var _saved: bool = false
## Start asked File, New for a baseplate of its own; begun when it is.
var _waiting_for_new: bool = false
## Whether this start has decided whether to offer it.
var _decided: bool = false
## When the window was first there to use, signed in: -1 until it is.
var _since: int = -1
## Offered by itself, not asked for from Help.
var _by_itself: bool = false
## Frames since a step was last measured: the model is read every few.
var _tick: int = 0
var _title: Label
var _words: Label
var _go: Button
var _skip: Button
## What a step points at, drawn over the window but taking no click.
var _frame: Frame


class Frame extends Control:
	var lit: Rect2 = Rect2()

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func light(rect: Rect2) -> void:
		if rect.is_equal_approx(lit):
			return
		lit = rect
		queue_redraw()

	func _draw() -> void:
		if not lit.has_area():
			return
		var edge := StyleBoxFlat.new()
		edge.bg_color = Color(Look.ACCENT, 0.08)
		edge.border_color = Color(Look.ACCENT, 0.95)
		edge.set_border_width_all(2)
		edge.set_corner_radius_all(6)
		draw_style_box(edge, lit)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	backing.border_color = Color(Look.ACCENT, 0.55)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 14
	backing.content_margin_right = 10
	backing.content_margin_top = 6
	backing.content_margin_bottom = 6
	add_theme_stylebox_override("panel", backing)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_title = Label.new()
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Look.ACCENT)
	row.add_child(_title)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size = Vector2(160, 0)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	row.add_child(_words)
	_go = _button("Start", true)
	_go.pressed.connect(_on_go)
	row.add_child(_go)
	_skip = _button("Skip", false)
	_skip.tooltip_text = "End it here. Help, Take the tour brings it back."
	_skip.pressed.connect(func() -> void: stop("skipped"))
	row.add_child(_skip)
	_frame = Frame.new()
	_frame.visible = false
	shell.app.get_node("HUD").add_child(_frame)
	shell.store.saved.connect(func(_name: String) -> void: _saved = true)
	# A new model or another one opened under a step: what it is measured
	# against starts again from there, or every part of it reads as new.
	shell.store.begun.connect(func(_name: String) -> void:
		if visible:
			_snap())
	shell.store.loaded.connect(func(_name: String, _bricks: int) -> void:
		# A model of the person's came back after it was offered by itself
		# (the account's, once it answered): the offer was not for them.
		if visible and _at == -1 and _by_itself:
			visible = false
		elif visible:
			_snap())
	shell.bar.started_new.connect(func() -> void:
		if _waiting_for_new and visible and _at == -1:
			_waiting_for_new = false
			_room_made())


## The same look as the other lines over the model (SeatOffer).
func _button(words: String, main: bool) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		var base: Color = Color(0.29, 0.5, 0.92) if main else Color(1, 1, 1, 0.08)
		face.bg_color = base.lightened(0.12) if state == "hover" else (
			base.darkened(0.12) if state == "pressed" else base)
		face.set_corner_radius_all(6)
		face.content_margin_left = 12
		face.content_margin_right = 12
		face.content_margin_top = 4
		face.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, face)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	return button


## Help, Take the tour: the offer again, with Start and Skip. Already under
## way, it carries on where it is.
func start() -> void:
	if visible:
		return
	_by_itself = false
	_offer()


func stop(how: String = "skipped") -> void:
	visible = false
	_frame.visible = false
	_waiting_for_new = false
	ShellPrefs.put("first_build", how)


func is_running() -> bool:
	return visible


## Where it is, for a check: "offer", a step's name, "end", or "" when it
## is not showing.
func step_name() -> String:
	if not visible:
		return ""
	if _at < 0:
		return "offer"
	return STEPS[_at] if _at < STEPS.size() else "end"


## Every line it can say, as [title, words], for a check of its words: the
## offer, each step as it reads with nothing in hand or selected, the end.
func cards() -> Array:
	var out: Array = [["Build your first model", _offer_words()]]
	for step: String in STEPS:
		out.append([TITLES[step], _step_words(step, "")])
	out.append([_end_title(), _end_words()])
	return out


## Its buttons, for a browser check to press them as a person does.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = {"first_build_go": _go}
	if _skip.visible:
		out["first_build_skip"] = _skip
	return out


func _offer() -> void:
	_at = -1
	_title.text = "Build your first model"
	_words.text = _offer_words()
	_go.text = "Start"
	_go.visible = true
	_skip.visible = true
	_frame.visible = false
	visible = true
	set_process(true)


func _offer_words() -> String:
	return "Seven short steps on a new baseplate, done in the app itself: about two minutes."


func _on_go() -> void:
	if _at >= STEPS.size():
		stop("done")
		return
	if _at >= 0:
		return
	# A baseplate of its own: the example car of a first visit, untouched,
	# comes off (Main._make_room); somebody's model stays, and File, New
	# asks first when it is not saved as it is.
	if _room_here():
		_room_made()
		return
	_waiting_for_new = true
	shell.bar.ask_for_new()


## Whether the baseplate holds nothing of the person's.
func _room_here() -> bool:
	if bool(shell.app.get("_sample_untouched")) and shell.builder.history_depth() == 0:
		return true
	return _model().is_empty() and shell.store.title == ModelStore.UNTITLED


func _room_made() -> void:
	shell.app.call("_make_room", MODEL_NAME)
	shell.bar.say("started “%s” on a baseplate of its own" % shell.store.title)
	_step(0)


func _step(at: int) -> void:
	_at = at
	_go.visible = _at >= STEPS.size()
	_skip.visible = _at < STEPS.size()
	_snap()
	if _at >= STEPS.size():
		_title.text = _end_title()
		_words.text = _end_words()
		_go.text = "Done"
		_frame.visible = false
		ShellPrefs.put("first_build", "done")
		return
	# The bin, for a part and for a colour: out of its fold where the window
	# shows one column at a time.
	if STEPS[_at] in ["put", "colour"]:
		var dock: SideDock = shell.app.get("_bin_dock")
		if dock != null and not dock.is_open():
			dock.set_open(true)
	_follow()


func _snap() -> void:
	_was = _model()
	_view_was = Vector2(shell.camera.yaw_turned(), shell.camera.pitch_now())
	_saved = false


func _process(_delta: float) -> void:
	if not _decided:
		_decide()
	if not visible:
		_frame.visible = false
		if _decided:
			set_process(false)
		return
	# A window narrowed under it keeps the line and its buttons in it: the
	# words say what to do, the title only where there is room for it.
	_title.visible = (get_parent() as Control).size.x >= NARROW
	if _at < 0 or _at >= STEPS.size():
		return
	_tick += 1
	if _tick % 6 == 0 and _done(STEPS[_at]):
		_step(_at + 1)
		return
	_follow()


# -- offered on a first visit ----------------------------------------------------

## Offered once, on the first visit to this device, to a person in front of
## the window, once they are signed in and the baseplate still holds the
## example car: never over a model of theirs, which a person who has built
## here before comes back to.
func _decide() -> void:
	if not _wanted():
		_decided = true
		return
	if bool(shell.app.call("_gated")) or shell.store.laying:
		_since = -1
		return
	if _since < 0:
		_since = Time.get_ticks_msec()
	var cloud: Node = shell.app.get("_cloud")
	if cloud != null and str(cloud.get("state")).is_empty() \
			and Time.get_ticks_msec() - _since < LOOK_WAIT_MS:
		return
	_decided = true
	if not bool(shell.app.get("_sample_untouched")) or bool(shell.app.get("_theirs_opened")) \
			or shell.builder.history_depth() > 0:
		return
	ShellPrefs.put("first_build", "offered")
	_by_itself = true
	_offer()


func _wanted() -> bool:
	if not str(ShellPrefs.value("first_build")).is_empty() or shell.read_only:
		return false
	if not (offered_for_probe or bool(shell.app.call("_gate_wanted"))):
		return false
	# Not a shared model's viewer, a model opened from a link, or a phone or
	# a window a phone's width, whose finger has none of the keys the steps
	# name and whose strip has no room for the line.
	for opened: String in ["_viewing", "_copying", "_from_library"]:
		if not str(shell.app.get(opened)).is_empty():
			return false
	return shell.app.get("_phone") == null and str(shell.app.get("_columns")) != "drawers"


# -- what each step says, and points at ------------------------------------------

func _follow() -> void:
	var step: String = STEPS[_at]
	var title: String = "%d of %d · %s" % [_at + 1, STEPS.size(), TITLES[step]]
	if _title.text != title:
		_title.text = title
	var words: String = _step_words(step, _hand())
	if _words.text != words:
		_words.text = words
	var target: Control = _target(step)
	_frame.visible = target != null and target.is_visible_in_tree()
	if _frame.visible:
		var inverse: Transform2D = _frame.get_global_transform().affine_inverse()
		_frame.light((inverse * target.get_global_rect()).grow(3.0))


## What the person has: "placing" a part from the bin, "carrying" a copy or
## a selection picked up, "selected", or "" for nothing.
func _hand() -> String:
	if shell.builder.is_carrying():
		return "carrying"
	if shell.verbs.shows_ghost():
		return "placing"
	return "selected" if not shell.builder.selection.is_empty() else ""


func _step_words(step: String, hand: String) -> String:
	var turn: String = _key("rotate_held", "the Rotate tool")
	var copy: String = _key("duplicate", "Edit, Duplicate")
	var moves: String = _move_keys()
	var let_go: String = "Press Esc to let go of the part in hand, then click a part to select it."
	match step:
		"put":
			return "Choose a part in the bin, then click the baseplate to put it down."
		"turn":
			if hand == "placing" or hand == "carrying":
				return "Press %s to turn the part in hand, then click to put it down." % turn
			if hand == "selected":
				return "Press %s to turn the selected part." % turn
			return "Click a part to select it, then press %s to turn it." % turn
		"colour":
			if hand == "placing":
				return "Click a colour under the parts, then click to put a part down in it."
			if hand == "selected":
				return "Click a colour under the parts to paint the selected part."
			return "Click a part to select it, then click a colour under the parts."
		"move":
			if hand == "placing":
				return let_go
			if hand == "selected":
				return "Press %s to move the selected part, or drag it." % moves
			return "Click a part to select it, then press %s to move it." % moves
		"copy":
			if hand == "carrying":
				return "Click to put the copy down."
			if hand == "placing":
				return let_go
			if hand == "selected":
				return "Press %s to copy the selected part, then click to put the copy down." % copy
			return "Click a part to select it, then press %s to copy it." % copy
		"view":
			return "%s to turn the view%s." % [_turning_drag(), _view_keys()]
		"save":
			var save: String = Keymap.written("save")
			if save.is_empty():
				return "Click Save on the toolbar to save “%s”." % shell.bar.model_name()
			return "Press %s to save “%s”." % [save, shell.bar.model_name()]
	return ""


## The key an action has in this person's keys, or [param otherwise] when
## they gave it none.
func _key(action: String, otherwise: String) -> String:
	var key: String = Keymap.written(action)
	return key if not key.is_empty() else otherwise


## The keys that move a selection: W, A, S and D out of the box, the arrows
## where a preset took those (Mecabricks'), or a drag.
func _move_keys() -> String:
	for keys: Array in [["nudge_forward", "nudge_left", "nudge_back", "nudge_right"],
			["arrow_up", "arrow_left", "arrow_down", "arrow_right"]]:
		var written: Array[String] = []
		for action: String in keys:
			written.append(Keymap.written(action))
		if not written.has(""):
			return "%s, %s, %s or %s" % written
	return "a drag"


## The drag that turns the view in the person's way of driving it (Settings:
## Studio's, Blender's or Mecabricks').
func _turning_drag() -> String:
	if ViewPrefs.drag_verb(MOUSE_BUTTON_RIGHT) == "turn":
		return "Drag with the right mouse button"
	if ViewPrefs.drag_verb(MOUSE_BUTTON_MIDDLE) == "turn":
		return "Drag with the middle mouse button"
	return "Drag on empty space"


func _view_keys() -> String:
	var first: String = Keymap.written("view_front")
	var last: String = Keymap.written("view_iso")
	if first == "1" and last == "7":
		return ", or press 1 to 7"
	return ", or press %s" % last if not last.is_empty() else ""


func _end_title() -> String:
	return "Your first model is saved"


func _end_words() -> String:
	var words: String = "Every command is in Find a command (%s), and every key in Help, Keys and controls (%s)." \
		% [_key("palette", "the app menu"), _key("keys", "F1")]
	if shell.assistant_shown:
		words += " Or describe a model to the assistant, and Claude builds it with you."
	return words


## What a step points at: the bin, its colours, a tool, the view cube, Save.
func _target(step: String) -> Control:
	var tools: Dictionary = shell.toolbar.controls_by_name() if shell.toolbar != null else {}
	var bin: PartsBin = shell.app.get("_bin")
	var named: Dictionary = bin.controls_by_name() if bin != null else {}
	match step:
		"put":
			return named.get("parts list")
		"colour":
			return named.get("palette")
		"turn":
			return tools.get("tool_mode_rotate")
		"move":
			return tools.get("tool_mode_move")
		"copy":
			return tools.get("tool_mode_clone")
		"view":
			return shell.app.get("_gizmo")
		"save":
			return tools.get("save")
	return null


# -- whether a step is done -------------------------------------------------------

## The model's parts as they are: id -> [part, colour, place], the
## baseplate it stands on left out.
func _model() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in shell.world.bricks():
		if not shell.store.scenery.has(brick.id):
			out[brick.id] = [brick.part_id, brick.color_code, brick.transform]
	return out


## Whether the model, the view or the store show [param step] done since it
## began, by any way of doing it.
func _done(step: String) -> bool:
	match step:
		"view":
			return _view_turned()
		"save":
			return _saved
	var now: Dictionary = _model()
	var fresh: Array = now.keys().filter(func(id: int) -> bool: return not _was.has(id))
	var gone: Array = _was.keys().filter(func(id: int) -> bool: return not now.has(id))
	match step:
		"put":
			return not fresh.is_empty()
		"turn":
			# One on the model turned where it stands, or one put down at a
			# turn none of the model had (turned in hand, or lifted and
			# turned).
			var turns: Array[Basis] = [Basis.IDENTITY]
			for id: int in _was:
				var basis: Basis = (_was[id][2] as Transform3D).basis
				if now.has(id) and not basis.is_equal_approx((now[id][2] as Transform3D).basis):
					return true
				turns.append(basis)
			for id: int in fresh:
				var basis: Basis = (now[id][2] as Transform3D).basis
				if not turns.any(func(seen: Basis) -> bool: return seen.is_equal_approx(basis)):
					return true
		"colour":
			var colours: Array[int] = []
			for id: int in _was:
				if now.has(id) and int(now[id][1]) != int(_was[id][1]):
					return true
				colours.append(int(_was[id][1]))
			for id: int in fresh:
				if not colours.has(int(now[id][1])):
					return true
		"move":
			# Moved where it stands, or lifted and put down again elsewhere.
			for id: int in _was:
				if now.has(id) and (now[id][2] as Transform3D).origin.distance_to(
						(_was[id][2] as Transform3D).origin) > 1.0:
					return true
			for id: int in fresh:
				if gone.any(func(was: int) -> bool: return _was[was][0] == now[id][0]):
					return true
		"copy":
			# One more of a part and colour the model had.
			var had: Dictionary = _counts(_was)
			var has: Dictionary = _counts(now)
			for kind: String in has:
				if had.has(kind) and int(has[kind]) > int(had[kind]):
					return true
	return false


static func _counts(model: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: int in model:
		var kind: String = "%s/%d" % [model[id][0], int(model[id][1])]
		out[kind] = int(out.get(kind, 0)) + 1
	return out


func _view_turned() -> bool:
	var now: Vector3 = _looking(shell.camera.yaw_turned(), shell.camera.pitch_now())
	return now.angle_to(_looking(_view_was.x, _view_was.y)) >= VIEW_TURN


static func _looking(yaw: float, pitch: float) -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
