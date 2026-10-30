## The row of tools under the menus.
##
## The file, the history, the tools a click acts through, the clipboard,
## what a part snaps to and how far a turn goes, and the view — each a
## button whose tooltip says what it does and what its key is, each
## running the same command its menu item and its key run (Shell). The
## tool in use is the one that stays lit.
##
## On a screen too narrow for all of it, the groups that are also in the
## menus fold away first, least used first, so the row never runs off the
## side: the tools and the file stay.
class_name Toolbar
extends PanelContainer

const TOOLS := "res://assets/ui/tools/"
const BUTTON := 30.0
const ICON := 20.0

## A button's face in each state: nothing until pointed at, and the tool
## in use lit.
const FACES := {
	"normal": Color(1, 1, 1, 0.0),
	"hover": Color(1, 1, 1, 0.12),
	"pressed": Color(0.36, 0.6, 1.0, 0.38),
	"disabled": Color(1, 1, 1, 0.0),
	"focus": Color(1, 1, 1, 0.0),
}

## Each group: how long it stays when room runs short (higher stays), and
## its items as [command, icon]. "snap" and "turn" are the two choosers;
## "history" and "select" open menus.
const GROUPS: Array = [
	[9, [["new", "new"], ["open", "open"], ["save", "save"], ["share", "share"]]],
	[7, [["undo", "undo"], ["redo", "redo"], ["history", "history"]]],
	[10, [["mode_select", "pointer"], ["mode_place", "build"], ["mode_move", "move"],
		["mode_rotate", "rotate"], ["mode_hinge", "swing"], ["mode_connect", "connect"],
		["mode_clone", "clone"],
		["mode_paint", "paint"], ["mode_hide", "hide"], ["mode_delete", "delete"]]],
	# Copy and paste are Ctrl-C and Ctrl-V and in Edit; showing everything is
	# H and in Edit. Off the bar so it stays whole at 1280 wide once the cut,
	# x-ray and render came.
	[3, [["mirror", "mirror"], ["select", "select"], ["make_submodel", "submodel"]]],
	[5, [["snap", "snap"], ["turn", "angle"]]],
	# The view's own tools, labelled as such: a left drag with one of these
	# on only moves the view. Asked for by the owner, for a mouse or a
	# trackpad with no middle button.
	# The straight-on views and square-on are the view cube's and the View
	# menu's now (and the number keys and `), which is what keeps the
	# toolbar whole on a 1280-wide screen.
	# The stud grid and the properties panel are the View menu's; the panel
	# folds by its own header.
	[8, [["mode_orbit", "orbit"], ["mode_pan", "pan"], ["mode_zoom", "zoom"], ["fit", "fit"],
		["cut", "cut"], ["xray", "xray"]], "View"],
	[6, [["measure", "measure"]]],
	[4, [["timeline", "timeline"], ["instructions", "booklet"], ["render", "render"],
		["parts_list", "parts_list"]]],
]

## What a tool button's tooltip says beyond its name, where the command's
## own words are not enough.
const SAYS: Dictionary = {
	"mode_place": "The last part back in hand: a click puts one down, and the next; a drag turns the view and puts nothing down. Esc or a right click lets go",
	"mode_select": "Where the app rests. Click a part to select it, drag it to move it (Ctrl-drag copies it), drag anywhere else to turn the view, Ctrl-drag a box round several, Alt-click takes a part into hand",
	"mode_move": "Click a part for its arrows and drag one to slide it along that axis; click it again to pick it up — the whole selection, if it is in it — and put it down elsewhere",
	"mode_rotate": "Click a part for its rings and drag one to turn it about that axis, finer further out; click it again to turn it by the turn step, Shift-click back",
	"mode_hinge": "Click a part on a hinge, clip or turntable to swing it about the joint",
	"mode_connect": "A point on the part, then the point it goes on: with a part in hand, click the pin, hole or bar it goes on by, then the one it goes on. With nothing in hand, click a part of the model first",
	"mode_clone": "Click a part to hold a copy of it, then click where the copy goes",
	"mode_paint": "Click a part to paint it the colour in hand",
	"mode_hide": "Click a part to hide it, to reach what is behind it",
	"mode_delete": "Click a part to take it off",
	"mode_orbit": "A left drag turns the view, wherever it starts. Esc or {mode_select} is back to Select",
	"mode_pan": "A left drag slides the view, wherever it starts. Esc or {mode_select} is back to Select",
	"mode_zoom": "A left drag up or down zooms; a click zooms in, Shift-click out. Esc or {mode_select} is back to Select",
	"fit": "Zoom to show the selection, or the whole model",
	"history": "Every change so far, newest first: choose one to go back to before it",
	"select": "Select by colour, by part, everything connected, or the opposite",
	"snap": "What a part snaps to as it is put down, and how far the arrow keys move a selection",
	"turn": "How far {rotate_held} and the Rotate tool turn a selection",
}

const SNAP_CHOICES: Array = [["stud", "Stud"], ["half", "½ stud"],
	["half_plate", "½ plate"], ["free", "Free"]]
const TURN_CHOICES: Array = [90.0, 45.0, 15.0, 5.0]

var shell: Shell

var _row: HBoxContainer
var _buttons: Dictionary = {}   ## command or chooser -> Control
var _groups: Array = []         ## [priority, Array[Control] including its line]
var _snap: OptionButton
var _turn: OptionButton
var _tools := ButtonGroup.new()
var _drawn_at: float = 0.0
var _looked_at: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.135, 0.145, 0.17, 0.97)
	backing.border_color = Color(1, 1, 1, 0.08)
	backing.border_width_bottom = 1
	backing.border_width_top = 1
	backing.content_margin_left = 8
	backing.content_margin_right = 8
	backing.content_margin_top = 3
	backing.content_margin_bottom = 3
	add_theme_stylebox_override("panel", backing)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 2)
	add_child(_row)
	for group: Array in GROUPS:
		var members: Array[Control] = []
		if _row.get_child_count() > 0:
			var line := VSeparator.new()
			line.add_theme_constant_override("separation", 10)
			line.modulate = Color(1, 1, 1, 0.45)
			_row.add_child(line)
			members.append(line)
		if group.size() > 2:
			var caption := Label.new()
			caption.text = str(group[2])
			caption.add_theme_font_size_override("font_size", 11)
			caption.modulate = Color(1, 1, 1, 0.55)
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_row.add_child(caption)
			members.append(caption)
		for item: Array in group[1]:
			var made: Control = _item(str(item[0]), str(item[1]))
			_row.add_child(made)
			members.append(made)
		_groups.append([int(group[0]), members])
	shell.verbs.mode_changed.connect(func(_mode: String) -> void: _show_state())
	get_viewport().size_changed.connect(_draw_icons)
	get_viewport().size_changed.connect(_fit, CONNECT_DEFERRED)
	resized.connect(_fit, CONNECT_DEFERRED)
	_draw_icons.call_deferred()
	_fit.call_deferred()
	_show_state.call_deferred()


func _item(name: String, icon: String) -> Control:
	if name == "snap":
		_snap = _chooser(icon)
		for choice: Array in SNAP_CHOICES:
			_snap.add_item(str(choice[1]))
		_snap.item_selected.connect(func(index: int) -> void:
			shell.set_snap(str(SNAP_CHOICES[index][0])))
		_snap.tooltip_text = "Snap\n" + SAYS["snap"]
		# Said as "Snap: Stud", the choice after its name.
		_snap.accessibility_name = "Snap"
		_snap.accessibility_description = SAYS["snap"]
		_buttons["snap"] = _snap
		return _snap
	if name == "turn":
		_turn = _chooser(icon)
		for degrees: float in TURN_CHOICES:
			_turn.add_item("%d°" % roundi(degrees))
		_turn.item_selected.connect(func(index: int) -> void:
			shell.set_turn_step(TURN_CHOICES[index]))
		_turn.accessibility_description = SAYS["turn"]
		_buttons["turn"] = _turn
		_tell("turn")
		return _turn
	var button: Button
	if name == "history":
		var menu := MenuButton.new()
		var steps: PopupMenu = menu.get_popup()
		steps.about_to_popup.connect(func() -> void:
			shell._fill_history(steps)
			_open_below(menu, steps))
		steps.id_pressed.connect(func(id: int) -> void:
			shell.attend("history", shell.verbs.go_back.bind(id + 1)))
		button = menu
	elif name == "select":
		var menu := MenuButton.new()
		# Its rows' keys are the keymap's, as the menus' are (Shell._menu):
		# answered here too, Alt-C with nothing selected ran Same colour
		# from this menu, greyed and silent, and never reached the keys.
		menu.set_disable_shortcuts(true)
		var choices: PopupMenu = menu.get_popup()
		shell._fill(choices, Shell.SUBMENUS["select_by"] + ["-", "select_all", "select_none"])
		choices.id_pressed.connect(shell._on_id)
		choices.about_to_popup.connect(func() -> void:
			shell._refresh(choices)
			_open_below(menu, choices))
		button = menu
	else:
		button = Button.new()
		button.pressed.connect(func() -> void: shell.run(name))
	if name.begins_with("mode_"):
		button.toggle_mode = true
		button.button_group = _tools
	_face(button)
	button.set_meta("icon", icon)
	_buttons[name] = button
	_tell(name)
	return button


## A button's tooltip and what a screen reader says on it: its words and
## its key ("Select, V"), then what it does. Told again when the keys
## change (Keymap): a key set in the keys sheet is the one shown.
func _tell(name: String) -> void:
	var button: Control = _buttons[name]
	if name == "turn":
		var turn: String = shell.key_words("rotate_held")
		button.tooltip_text = "Turn step%s\n%s" % [("   " + turn) if not turn.is_empty() else "",
			Keymap.filled(SAYS["turn"], true)]
		button.accessibility_name = "Turn step" + ((", " + turn) if not turn.is_empty() else "")
		return
	if name == "snap":
		return
	var command: Shell.Command = shell.command(name)
	var words: String = command.words if command != null else {
		"history": "History", "select": "Select by"}.get(name, name)
	words = words.trim_suffix("…").trim_suffix(" tool")
	var key: String = shell.key_words(name)
	var says: String = Keymap.filled(SAYS.get(name, command.tip if command != null else ""), true)
	button.tooltip_text = "%s%s%s" % [words, ("   " + key) if not key.is_empty() else "",
		("\n" + says) if not says.is_empty() else ""]
	button.accessibility_name = words + ((", " + key) if not key.is_empty() else "")
	button.accessibility_description = says


func tell_keys() -> void:
	for name: String in _buttons:
		_tell(name)
		_buttons[name].remove_meta("for_part")


func _face(button: Button) -> void:
	# Tab and the arrows reach it; a click leaves the keys with the model,
	# or the next press of the space bar would run whatever was clicked.
	FocusGuard.by_keyboard(button)
	button.custom_minimum_size = Vector2(BUTTON, BUTTON)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in FACES:
		var face := StyleBoxFlat.new()
		face.bg_color = FACES[state]
		face.set_corner_radius_all(5)
		face.set_content_margin_all(4)
		if state == "pressed":
			face.border_color = Color(0.56, 0.74, 1.0, 0.9)
			face.set_border_width_all(1)
		button.add_theme_stylebox_override(state, face)
	button.add_theme_stylebox_override("focus", FocusGuard.ring())
	# A lit tool stays lit under the pointer.
	button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))


func _chooser(icon: String) -> OptionButton:
	var chooser := OptionButton.new()
	FocusGuard.by_keyboard(chooser)
	chooser.fit_to_longest_item = true
	chooser.custom_minimum_size = Vector2(0, BUTTON)
	chooser.add_theme_font_size_override("font_size", 13)
	chooser.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chooser.add_theme_stylebox_override("focus", FocusGuard.ring())
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(1, 1, 1, 0.06 if state == "normal" else 0.12)
		# Its edge 3:1 on the bar (Look.OUTLINE); at 12% white it was 2.8:1.
		face.border_color = Look.OUTLINE
		face.set_border_width_all(1)
		face.set_corner_radius_all(5)
		face.content_margin_left = 6
		face.content_margin_right = 6
		face.content_margin_top = 2
		face.content_margin_bottom = 2
		chooser.add_theme_stylebox_override(state, face)
	chooser.set_meta("icon", icon)
	chooser.get_popup().add_theme_font_size_override("font_size", 13)
	return chooser


## A menu dropped under its button and kept inside the window.
func _open_below(button: Control, menu: PopupMenu) -> void:
	var scale: Vector2 = button.get_global_transform_with_canvas().get_scale()
	menu.reset_size()
	var at: Vector2 = button.get_screen_position() + Vector2(0.0, button.size.y * scale.y + 4.0)
	var room: float = get_viewport().get_visible_rect().size.x * scale.x
	at.x = minf(at.x, maxf(room - menu.size.x - 8.0, 0.0))
	menu.position = Vector2i(at)


## The icons at the screen's own density: sharp at 1x and at 2x alike.
func _draw_icons() -> void:
	var density: float = Icons.density(self)
	if is_equal_approx(density, _drawn_at):
		return
	_drawn_at = density
	for name: String in _buttons:
		var button: Button = _buttons[name]
		var texture: ImageTexture = Icons.icon_for(
			TOOLS + str(button.get_meta("icon")) + ".svg", ICON, density)
		if button is OptionButton:
			# A chooser shows the picture of the item chosen, so every item
			# carries it.
			var chooser: OptionButton = button
			for index: int in chooser.item_count:
				chooser.set_item_icon(index, texture)
			chooser.select(chooser.selected)
		else:
			button.icon = texture
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Fold groups away, least needed first, until the row fits the window.
func _fit() -> void:
	var room: float = get_viewport().get_visible_rect().size.x - 16.0
	var order: Array = _groups.duplicate()
	order.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for group: Array in _groups:
		for control: Control in group[1]:
			control.visible = true
	var wide: float = _row.get_combined_minimum_size().x
	for group: Array in order:
		if wide <= room:
			break
		for control: Control in group[1]:
			if control.visible:
				wide -= control.get_combined_minimum_size().x + 2.0
				control.visible = false


## Lit, ticked and greyed as things stand. Read a few times a second, which
## is often enough for a button and cheap.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _looked_at < 200:
		return
	_looked_at = now
	_show_state()


func _show_state() -> void:
	if shell == null:
		return
	for name: String in _buttons:
		var button: Button = _buttons[name]
		if button is OptionButton:
			continue
		var usable: bool = name in ["history", "select"] or shell.can(name)
		if button.disabled == usable:
			button.disabled = not usable
			button.modulate = Color(1, 1, 1, 1.0 if usable else 0.38)
		if button.toggle_mode or name.begins_with("mode_"):
			button.set_pressed_no_signal(shell.ticked(name) == 1)
		elif shell.ticked(name) >= 0:
			# A setting that is on is drawn as pressed, without being a toggle.
			var lit: bool = shell.ticked(name) == 1
			if bool(button.get_meta("lit", false)) != lit:
				button.set_meta("lit", lit)
				button.add_theme_stylebox_override("normal",
					button.get_theme_stylebox("pressed") if lit else _plain())
	# The Place button names the part it puts back in hand.
	var place: Button = _buttons.get("mode_place")
	var held: String = shell.builder.held_part
	if place != null and str(place.get_meta("for_part", "")) != held:
		place.set_meta("for_part", held)
		var info: PartLibrary.PartInfo = shell.library.parts.get(held)
		var key: String = shell.key_words("mode_place")
		place.tooltip_text = "Place %s%s\n%s" % [Inventory._tidy(info.name) if info != null else held,
			("   " + key) if not key.is_empty() else "", SAYS["mode_place"]]
		place.accessibility_name = "Place %s%s" % [Inventory._tidy(info.name) if info != null else held,
			(", " + key) if not key.is_empty() else ""]
	var snap_at: int = SNAP_CHOICES.map(func(c: Array) -> String: return str(c[0])).find(
		shell.verbs.snap)
	if _snap != null and snap_at >= 0 and _snap.selected != snap_at:
		_snap.select(snap_at)
	var turn_at: int = TURN_CHOICES.find(shell.verbs.turn_step)
	if _turn != null and turn_at >= 0 and _turn.selected != turn_at:
		_turn.select(turn_at)


func _plain() -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = FACES["normal"]
	face.set_corner_radius_all(5)
	face.set_content_margin_all(4)
	return face


## Where each control is, for a browser test to press it the way a person
## does: "new", "save", "open", and "tool_" and the command for the rest.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _buttons:
		var key: String = name if name in ["new", "open", "save"] else "tool_" + name
		out[key] = _buttons[name]
	# The booklet's own flow presses "instructions" (tools/web).
	if _buttons.has("instructions"):
		out["instructions"] = _buttons["instructions"]
	return out
