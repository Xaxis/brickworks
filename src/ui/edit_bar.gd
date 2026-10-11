## The editing verbs on screen, down the left of the model.
##
## Everything here was a key and only a key: rotate, tip, paint, lift,
## delete, and from now copy, paste, duplicate, hide. The strip along the
## bottom names six things, so the rest were found by reading the controls
## list or not at all — and Studio and Mecabricks are both learned from a
## row of tools whose tooltips say what each does and what its key is.
##
## Each button calls the same function its key does, through [EditVerbs],
## so the two cannot drift. A button that needs a selection is drawn
## faint until there is one, and says so when pointed at.
class_name EditBar
extends PanelContainer

const TOOLS := "res://assets/ui/tools/"
## A button, in interface units: big enough for a mouse, small enough
## that sixteen of them fit down a laptop's screen.
const BUTTON := 30.0
const ICON := 20.0
## A button's face in each state: nothing until pointed at.
const FACES := {
	"normal": Color(1, 1, 1, 0.0),
	"hover": Color(1, 1, 1, 0.12),
	"pressed": Color(0.36, 0.6, 1.0, 0.35),
	"disabled": Color(1, 1, 1, 0.0),
	"focus": Color(1, 1, 1, 0.0),
}

var verbs: EditVerbs
var builder: Builder

var _buttons: Dictionary = {}   ## name -> Button
var _needs_selection: Array[String] = []
var _select_menu: MenuButton
var _history_menu: MenuButton
var _drawn_at: float = 0.0
var _last_state: String = ""


## [name, words, key, needs a selection, what it does]
static func tools() -> Array:
	var hold: String = ControlsHint._hold()
	return [
		["undo", "Undo", "%s-Z" % hold, false, "Take back the last change"],
		["redo", "Redo", "%s-Shift-Z" % hold, false, "Put it back"],
		["history", "History", "", false,
			"Every change so far, newest first: choose one to go back to before it"],
		[],
		["rotate", "Rotate", "R", false,
			"Turn the part in hand a quarter, or the selection where it stands (Shift-R the other way)"],
		["tip", "Tip on its side", "T", false,
			"Roll the part in hand onto its next face, studs forward, down or to the side"],
		[],
		["move", "Move", "X", true,
			"Pick the selection up: it follows the pointer, a click puts it down, Esc puts it back"],
		["copy", "Copy", "%s-C" % hold, true, "Copy the selection"],
		["paste", "Paste", "%s-V" % hold, false,
			"Hold a copy of what was copied: click to put it down, R turns it"],
		["duplicate", "Duplicate", "%s-D" % hold, true,
			"Hold a copy of the selection, to put down beside it"],
		["paint", "Paint", "C", true, "Paint the selection the colour you hold"],
		["swing", "Swing on its joint", "J", true,
			"Turn the selection 15° about the hinge, clip or turntable it hangs from (Shift-J back)"],
		["mirror", "Mirror", "Shift-M", true,
			"Make the selection its mirror image, left to right as you see it; a left-hand part becomes a right-hand one"],
		["replace", "Replace", "", true,
			"Swap the selection for the part you hold, each in its own colour, where it stands"],
		["delete", "Remove", "Delete", true, "Take the selection off the model"],
		[],
		["select", "Select", "", false,
			"Select by colour, by part, everything connected, or the opposite"],
		["hide", "Hide", "H", true, "Hide the selection, to reach what is behind it"],
		["isolate", "Show only the selection", "Shift-H", true,
			"Hide everything else, to work on just this"],
		["show_all", "Show everything", "Alt-H", false, "Bring back whatever is hidden"],
	]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.9)
	backing.border_color = Color(1, 1, 1, 0.1)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.set_content_margin_all(4)
	add_theme_stylebox_override("panel", backing)
	# A grid of one column, or two where the window is too short for one:
	# a toolbar that ran off the bottom of a laptop's screen would hide
	# its last tools, and one that scrolled would hide them better.
	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	add_child(_grid)
	for tool: Array in tools():
		if tool.is_empty():
			var gap := HSeparator.new()
			gap.add_theme_constant_override("separation", 6)
			gap.modulate = Color(1, 1, 1, 0.5)
			_grid.add_child(gap)
			_gaps.append(gap)
			continue
		_grid.add_child(_button(tool))
	get_viewport().size_changed.connect(_draw_icons)
	get_viewport().size_changed.connect(_fit, CONNECT_DEFERRED)
	_draw_icons.call_deferred()
	_fit.call_deferred()
	if get_parent() is Control:
		(get_parent() as Control).resized.connect(_fit)


var _grid: GridContainer
var _gaps: Array[Control] = []


## One column if it fits the room the model has, two if not.
func _fit() -> void:
	var room: Control = get_parent() as Control
	if room == null or _grid == null:
		return
	var tall: float = 8.0
	for child: Node in _grid.get_children():
		tall += (child as Control).get_combined_minimum_size().y + 2.0
	var two: bool = tall > room.size.y - 16.0
	_grid.columns = 2 if two else 1
	for gap: Control in _gaps:
		gap.visible = not two
	reset_size()


func _button(tool: Array) -> Control:
	var name: String = tool[0]
	var words: String = tool[1]
	var key: String = tool[2]
	var does: String = tool[4]
	var button: Button
	if name == "history":
		_history_menu = MenuButton.new()
		button = _history_menu
		var steps: PopupMenu = _history_menu.get_popup()
		steps.about_to_popup.connect(func() -> void:
			steps.clear()
			var said: PackedStringArray = builder.history_words(25)
			if said.is_empty():
				steps.add_item("nothing to go back to yet")
				steps.set_item_disabled(0, true)
			for n: int in said.size():
				steps.add_item("Undo %s" % said[n] if n == 0
					else "Back to before: %s" % said[n], n)
			_open_beside(_history_menu, steps))
		steps.id_pressed.connect(func(id: int) -> void: verbs.go_back(id + 1))
	elif name == "select":
		_select_menu = MenuButton.new()
		button = _select_menu
		var menu: PopupMenu = _select_menu.get_popup()
		menu.add_item("Same colour", 0)
		menu.add_item("Same part", 1)
		menu.add_item("Same part and colour", 2)
		menu.add_item("Everything connected", 3)
		menu.add_separator()
		menu.add_item("The opposite", 4)
		menu.add_item("Everything   %s-A" % ControlsHint._hold(), 5)
		menu.add_item("Nothing   Esc", 6)
		menu.id_pressed.connect(func(id: int) -> void:
			verbs.select_by(["colour", "part", "alike", "connected", "inverse",
				"all", "none"][id]))
		menu.about_to_popup.connect(func() -> void:
			var some: bool = not builder.selection.is_empty()
			for id: int in [0, 1, 2, 3]:
				menu.set_item_disabled(menu.get_item_index(id), not some)
			_open_beside(_select_menu, menu))
	else:
		button = Button.new()
		button.pressed.connect(func() -> void: verbs.press(name))
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(BUTTON, BUTTON)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = false
	button.tooltip_text = "%s%s\n%s" % [words,
		("   " + key) if not key.is_empty() else "", does]
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var face := StyleBoxFlat.new()
		face.bg_color = FACES[state]
		face.set_corner_radius_all(5)
		face.set_content_margin_all(4)
		button.add_theme_stylebox_override(state, face)
	button.set_meta("tool", name)
	if bool(tool[3]):
		_needs_selection.append(name)
	_buttons[name] = button
	return button


## A menu opened beside its button rather than under it, and kept inside
## the window: the bar runs down the side of the model, so a menu dropped
## below its lower buttons ran off the bottom with half its items gone.
func _open_beside(button: Control, menu: PopupMenu) -> void:
	var scale: Vector2 = button.get_global_transform_with_canvas().get_scale()
	menu.reset_size()
	var at: Vector2 = button.get_screen_position() + Vector2(button.size.x * scale.x + 6.0, 0.0)
	var below: float = (get_viewport().get_visible_rect().end.y
		- button.get_global_rect().position.y) * scale.y - 8.0
	if menu.size.y > below:
		at.y -= menu.size.y - below
	menu.position = Vector2i(at)


## The icons at the screen's own density: sharp at 1x and at 2x alike.
func _draw_icons() -> void:
	var density: float = Icons.density(self)
	if is_equal_approx(density, _drawn_at):
		return
	_drawn_at = density
	for name: String in _buttons:
		var texture: ImageTexture = Icons.texture_for(TOOLS + name + ".svg", ICON, density)
		var button: Button = _buttons[name]
		button.icon = texture
		# One texel to a pixel, as Icons draws everything.
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if texture != null:
			button.add_theme_constant_override("icon_max_width",
				roundi(texture.get_width() / density))


## Faint where it would do nothing. Read off the builder each frame and
## acted on only when it changes, which is nearly never.
func _process(_delta: float) -> void:
	if builder == null:
		return
	var some: bool = not builder.selection.is_empty()
	var state: String = "%s|%s|%s" % [some, builder.is_carrying(),
		builder.lattice.unseen.is_empty()]
	if state == _last_state:
		return
	_last_state = state
	for name: String in _needs_selection:
		var button: Button = _buttons[name]
		button.disabled = not some
		button.modulate = Color(1, 1, 1, 1.0 if some else 0.38)
	var hidden_any: bool = not builder.lattice.unseen.is_empty()
	var show_all: Button = _buttons.get("show_all")
	if show_all != null:
		show_all.disabled = not hidden_any
		show_all.modulate = Color(1, 1, 1, 1.0 if hidden_any else 0.38)


## Where each button is, for a browser test to press it the way a person
## does: "tool_copy" and so on.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _buttons:
		out["tool_" + name] = _buttons[name]
	return out
