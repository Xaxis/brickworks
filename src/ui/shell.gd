## The frame round the model: the menus along the top, the toolbar under
## them, the properties of the selection beside the model and the status
## bar along the bottom — the way Studio, Mecabricks and LDCad lay out a
## LEGO CAD program.
##
## Every command lives once, here, with its words, its key and whether it
## can be used now; the menus, the toolbar and the keys all run the same
## one, so they cannot come to do different things. The work itself is
## done where it always was (EditVerbs, the builder, the model bar, the
## app), and this only names it and puts it on screen. Kept out of
## main.gd, which everything else also lives in.
class_name Shell
extends Node

## The app (main.gd), for the things only it can do: turning the model,
## the timeline, the parts list, the minifigure builder.
var app: Node
var bar: ModelBar
var builder: Builder
var verbs: EditVerbs
var camera: CadCamera
var world: BrickWorld
var library: PartLibrary
var store: ModelStore

var toolbar: Toolbar
var status: StatusBar
var inspector: Inspector
var assemblies: Assemblies
var outliner: Outliner
var banner: AssemblyBanner
var grid: StudGrid
var tour: Tour

## name -> Command
var _commands: Dictionary = {}
## Menu ids are indexes into this.
var _ids: Array[String] = []
var _menus: Array[MenuButton] = []
var _save_as: ConfirmationDialog
var _save_as_name: LineEdit
var _about: AcceptDialog


class Command extends RefCounted:
	var name: String
	var words: String
	## A key and its modifiers, as PopupMenu shows it; 0 for none.
	var accel: int = 0
	var run: Callable
	## Whether it can be used now. Always, when not set.
	var can: Callable = Callable()
	## Whether it is ticked, for a setting that is on or off.
	var ticked: Callable = Callable()
	## One of several of which exactly one is on: the tools.
	var radio: bool = false
	var tip: String = ""


const CTRL := KEY_MASK_CMD_OR_CTRL
const SHIFT := KEY_MASK_SHIFT
const ALT := KEY_MASK_ALT

## The menus, in order. "-" is a line between groups; ">name" a submenu.
const MENUS: Array = [
	["File", ["new", "open", ">recent", ">import", "-", "save", "save_as", "-",
		"share", ">export", "instructions", "-", "clear", "account", "quit"]],
	["Edit", ["undo", "redo", ">history", "-", "cut", "copy", "paste", "duplicate",
		"delete", "-", "select_all", "select_none", ">select_by", "-", "hide",
		"isolate", "show_all", "-", "lock", "unlock", "-", "paint", "replace", "mirror",
		"-", "make_submodel", "leave_submodel", "enter_assembly", "leave_assembly",
		"rename_assembly", "make_unique"]],
	["View", ["view_default", "view_front", "view_back", "view_left", "view_right",
		"view_top", "view_bottom", "view_iso", "-", "mode_orbit", "mode_pan", "mode_zoom",
		"fit", "fit_model", "fit_selection",
		"ortho", "grid", "-", "turn_left", "turn_right", "-", "panel_parts",
		"panel_assistant", "panel_properties", "panel_outliner", "panel_keys", "-",
		"full_screen"]],
	["Build", ["timeline", "instructions", "parts_list", "-", "make_submodel",
		"leave_submodel", "enter_assembly", "select_submodel", "-", "minifig", "mosaic",
		"brickify", "part_maker",
		"-", "rotate_held", "tip_held"]],
	["Tools", ["mode_select", "mode_place", "mode_move", "mode_rotate", "mode_hinge",
		"mode_clone", "mode_paint", "mode_hide", "mode_delete", "-", "measure",
		"stability", "reseat", "-", "connector", "settings"]],
	["Help", ["keys", "tour", "-", "website", "about"]],
]

## Submenu rows are numbered from here, clear of the commands.
const SUBMENU_ID := 10000

const SUBMENUS: Dictionary = {
	"import": ["import_ldraw", "import_io", "import_lxf", "import_mesh"],
	"export": ["export_ldraw", "export_picture", "export_bricklink", "export_rebrickable"],
	"select_by": ["select_colour", "select_part", "select_alike", "select_connected",
		"select_submodel", "select_inverse"],
}


## Everything put on screen: the menus into the bar, the toolbar under it,
## the status bar at the foot of ``column``, the model tree and the
## properties in the left-hand column ``stack``, under the parts bin, and
## the banner for a sub-assembly being edited in ``notices``, the strip
## along the top of the model. Nothing of it is laid over the model.
func build(column: Control, stack: PanelStack, notices: Control) -> void:
	bar = app.get("_bar")
	builder = app.get("_builder")
	verbs = app.get("_verbs")
	camera = app.get("_camera")
	world = app.get("_world")
	library = app.get("_library")
	store = app.get("_store")
	# The model's sub-assemblies, read off its bricks: src/assembly/assemblies.gd.
	assemblies = Assemblies.new()
	assemblies.world = world
	assemblies.builder = builder
	assemblies.library = library
	assemblies.scenery = store.scenery
	verbs.assemblies = assemblies
	builder.unit_of = assemblies.unit_of
	builder.copy_group = assemblies.group_for_copy
	# Whatever replaces the model leaves no assembly being edited.
	bar.started_new.connect(func() -> void: assemblies.enter(""))
	bar.cleared.connect(func() -> void: assemblies.enter(""))
	bar.opened.connect(func(_n: int) -> void: assemblies.enter(""))
	_define()

	for menu: Array in MENUS:
		_menus.append(_menu(str(menu[0]), menu[1]))
	for button: MenuButton in _menus:
		bar.menus.add_child(button)

	toolbar = Toolbar.new()
	toolbar.shell = self
	column.add_child(toolbar)
	column.move_child(toolbar, bar.get_index() + 1)

	status = StatusBar.new()
	status.shell = self
	column.add_child(status)
	# The bar's own status line was along the top; what it says now goes
	# here, where every other program says it.
	bar.use_status(status.message)

	# Under the parts bin, the model tree over the properties: everything
	# for building by hand in one column, as Studio keeps its palettes down
	# the left and Blender stacks its outliner over its properties.
	outliner = Outliner.new()
	outliner.shell = self
	outliner.assemblies = assemblies
	stack.add_section(outliner, "tree_height")

	inspector = Inspector.new()
	inspector.shell = self
	stack.add_section(inspector, "properties_height")

	banner = AssemblyBanner.new()
	banner.assemblies = assemblies
	notices.add_child(banner)

	grid = StudGrid.new()
	grid.world = world
	grid.library = library
	grid.scenery = store.scenery
	app.add_child(grid)

	tour = Tour.new()
	tour.shell = self
	app.get_node("HUD").add_child(tour)

	# Every text field gives the keys back: src/ui/focus_guard.gd.
	add_child(FocusGuard.new())

	_save_as = ConfirmationDialog.new()
	_save_as.title = "Save as"
	_save_as.ok_button_text = "Save"
	var asking := VBoxContainer.new()
	var words := Label.new()
	words.text = "What should this copy of the model be called?"
	asking.add_child(words)
	_save_as_name = LineEdit.new()
	_save_as_name.custom_minimum_size = Vector2(320, 0)
	_save_as_name.text_submitted.connect(func(_text: String) -> void:
		_save_as.hide()
		_save_named(_save_as_name.text))
	asking.add_child(_save_as_name)
	_save_as.add_child(asking)
	_save_as.confirmed.connect(func() -> void: _save_named(_save_as_name.text))
	add_child(_save_as)

	_about = AcceptDialog.new()
	_about.title = "About Brickworks"
	add_child(_about)

	# The layout as it was left. Which columns show is the window's to
	# say as well as the person's: Main._fit_panels.
	verbs.set_snap(str(ShellPrefs.value("snap")), false)
	verbs.turn_step = float(ShellPrefs.value("turn_step"))
	set_key_strip(bool(ShellPrefs.value("key_strip")))
	grid.visible = bool(ShellPrefs.value("grid"))
	inspector.set_open(bool(ShellPrefs.value("inspector_open")))
	outliner.set_open(bool(ShellPrefs.value("outliner_open")))


## A section of the left-hand column, from the View menu or the toolbar:
## with its column folded, the column opens with it open (a narrow window
## folds the assistant to make room); else it folds or opens.
func _toggle_section(section: Control) -> void:
	var dock: SideDock = app.get("_bin_dock")
	if not dock.is_open():
		section.call("set_open", true)
		dock.set_open(true)
		return
	section.call("set_open", not bool(section.call("is_open")))


func _section_shown(section: Control) -> bool:
	return (app.get("_bin_dock") as SideDock).is_open() and bool(section.call("is_open"))


## Define one command.
func _add(name: String, words: String, accel: int, run: Callable,
		can: Callable = Callable(), tip: String = "") -> Command:
	var command := Command.new()
	command.name = name
	command.words = words
	command.accel = accel
	command.run = run
	command.can = can
	command.tip = tip
	_commands[name] = command
	return command


func _ticked(name: String, ticked: Callable) -> void:
	(_commands[name] as Command).ticked = ticked


func command(name: String) -> Command:
	return _commands.get(name)


## Run a command by name, when it can be. True when it ran.
func run(name: String) -> bool:
	var found: Command = _commands.get(name)
	if found == null or not can(name):
		return false
	found.run.call()
	return true


func can(name: String) -> bool:
	var found: Command = _commands.get(name)
	if found == null:
		return false
	if read_only and not name in LOOKING:
		return false
	return not found.can.is_valid() or bool(found.can.call())


## Set for a model shared by link and opened to look at (/app?view=<id>):
## then only the commands in [constant LOOKING] can run, from the menus,
## the toolbar or a key — a command that is not here cannot change the
## model, save it or reach the account, whatever asks for it.
var read_only: bool = false

## What a visitor may do with somebody else's model: look at it from any
## side, step through it, read its booklet and its parts list.
const LOOKING: Array[String] = ["view_default", "view_front", "view_back",
	"view_left", "view_right", "view_top", "view_bottom", "view_iso", "fit",
	"fit_model", "ortho", "full_screen", "timeline", "parts_list", "instructions",
	"website", "about"]


## -1 for a command that is not a setting; 0 off, 1 on.
func ticked(name: String) -> int:
	var found: Command = _commands.get(name)
	if found == null or not found.ticked.is_valid():
		return -1
	return 1 if bool(found.ticked.call()) else 0


## What a command's key reads as, for a tooltip: "Ctrl+Z".
func key_words(name: String) -> String:
	var found: Command = _commands.get(name)
	if found == null or found.accel == 0:
		return ""
	return OS.get_keycode_string(found.accel)


func _define() -> void:
	var selected: Callable = func() -> bool: return not builder.selection.is_empty()
	var something: Callable = func() -> bool:
		return world.brick_count() > store.scenery.size()
	# File
	_add("new", "New", CTRL | KEY_N, bar.ask_for_new, Callable(),
		"Start a new model on an empty baseplate")
	_add("open", "Open…", CTRL | KEY_O, bar._on_open, Callable(),
		"Reopen a saved model, an example, or a file from this computer")
	_add("import_ldraw", "LDraw model (.ldr, .mpd)…", 0, bar._import)
	_add("import_io", "BrickLink Studio model (.io)…", 0, bar._import)
	_add("import_lxf", "LEGO Digital Designer model (.lxf) — not yet", 0,
		func() -> void: pass, func() -> bool: return false)
	_add("import_mesh", "3D model to brickify (.obj, .stl, .gltf, .glb)…", 0,
		func() -> void: bar.brickify_wanted.emit(), Callable(),
		"A sculpt, a scan or any 3D model, laid in bricks")
	_add("save", "Save", CTRL | KEY_S, bar._on_save, something,
		"Keep this model under its name")
	_add("save_as", "Save as…", CTRL | SHIFT | KEY_S, _ask_save_as, something,
		"Keep a copy of this model under another name")
	_add("export_ldraw", "LDraw model (.ldr, or .mpd with its sub-models)", 0,
		func() -> void: bar._on_export_chosen(0), something)
	_add("export_picture", "Picture of the model (.png)", 0,
		func() -> void: bar._on_export_chosen(1), something)
	_add("export_bricklink", "BrickLink wanted list (.xml)", 0,
		func() -> void: bar._on_export_chosen(2), something)
	_add("export_rebrickable", "Rebrickable parts list (.csv)", 0,
		func() -> void: bar._on_export_chosen(3), something)
	_add("instructions", "Instructions…", 0, _instructions, something,
		"Building instructions for this model, step by step")
	_add("share", "Share…", 0, func() -> void: app.call("_share_wanted"), something,
		"A link anyone can open to see this model, its steps and its parts list")
	_add("clear", "Clear the baseplate…", 0, bar._ask_to_clear, something,
		"Empty the baseplate. Asks first: it cannot be undone")
	_add("account", "Account…", 0, func() -> void: bar.account_wanted.emit(),
		Callable(), "Who is signed in, and Sign out")
	_add("quit", "Quit", CTRL | KEY_Q, func() -> void: app.get_tree().quit(),
		func() -> bool: return not OS.has_feature("web"))
	# Edit
	_add("undo", "Undo", CTRL | KEY_Z, func() -> void: verbs.press("undo"),
		func() -> bool: return builder.history_depth() > 0, "Take back the last change")
	_add("redo", "Redo", CTRL | SHIFT | KEY_Z, func() -> void: verbs.press("redo"),
		func() -> bool: return not builder._redo.is_empty(), "Put it back")
	_add("cut", "Cut", CTRL | KEY_X, func() -> void: verbs.cut(), selected)
	_add("copy", "Copy", CTRL | KEY_C, func() -> void: verbs.copy(), selected,
		"Copy the selection")
	_add("paste", "Paste", CTRL | KEY_V, func() -> void: verbs.paste(), Callable(),
		"Hold a copy of what was copied: click to put it down, R turns it")
	_add("duplicate", "Duplicate", CTRL | KEY_D, func() -> void: verbs.duplicate_selection(),
		selected, "Hold a copy of the selection, to put down beside it")
	_add("delete", "Delete", KEY_DELETE, func() -> void: verbs.press("delete"), selected,
		"Take the selection off the model")
	_add("select_all", "Select all", CTRL | KEY_A, func() -> void: verbs.select_by("all"),
		something)
	_add("select_none", "Select nothing", 0, func() -> void: verbs.select_by("none"), selected)
	_add("select_colour", "Same colour", 0, func() -> void: verbs.select_by("colour"), selected)
	_add("select_part", "Same part", 0, func() -> void: verbs.select_by("part"), selected)
	_add("select_alike", "Same part and colour", 0, func() -> void: verbs.select_by("alike"),
		selected)
	_add("select_connected", "Everything connected", 0,
		func() -> void: verbs.select_by("connected"), selected)
	_add("select_submodel", "Same sub-model", 0, func() -> void: verbs.select_by("submodel"),
		selected)
	_add("select_inverse", "The opposite", 0, func() -> void: verbs.select_by("inverse"),
		something)
	_add("hide", "Hide", CTRL | KEY_H, func() -> void: verbs.hide_selection(), selected,
		"Hide the selection, to reach what is behind it")
	_add("isolate", "Show only the selection", SHIFT | KEY_H, func() -> void: verbs.isolate(),
		selected, "Hide everything else, to work on just this")
	_add("show_all", "Show everything", ALT | KEY_H, func() -> void: verbs.show_all(),
		func() -> bool: return not builder.lattice.unseen.is_empty(),
		"Bring back whatever is hidden")
	_add("lock", "Lock the selection", KEY_L, func() -> void: verbs.lock(true), selected,
		"Keep the selection from being picked out, moved, painted or taken off")
	_add("unlock", "Unlock everything", SHIFT | KEY_L, func() -> void: verbs.unlock_all(),
		func() -> bool: return not builder.locked.is_empty())
	_add("paint", "Paint the selection", KEY_C, func() -> void: verbs.press("paint"), selected,
		"Paint the selection the colour in hand")
	_add("replace", "Replace with the part in hand", 0, func() -> void: verbs.replace(),
		selected, "Swap the selection for the part you hold, each in its own colour")
	_add("mirror", "Mirror", SHIFT | KEY_M, func() -> void: verbs.mirror(), selected,
		"Make the selection its mirror image, left to right as you see it")
	# View
	for view: Array in [["view_default", "Default view", KEY_0, "default"],
			["view_front", "From the front", KEY_1, "front"],
			["view_back", "From the back", KEY_2, "back"],
			["view_left", "From the left", KEY_3, "left"],
			["view_right", "From the right", KEY_4, "right"],
			["view_top", "From above", KEY_5, "top"],
			["view_bottom", "From below", KEY_6, "bottom"],
			["view_iso", "Isometric", KEY_7, "isometric"]]:
		var named: String = view[3]
		_add(view[0], view[1], view[2], func() -> void: camera.set_view(named),
			Callable(), "Look at the model %s" % str(view[1]).to_lower())
	_add("fit_model", "Fit the model", SHIFT | KEY_F,
		func() -> void: camera.frame(app.call("_built_bounds")), Callable(),
		"Zoom to show the whole model")
	_add("fit_selection", "Fit the selection", 0,
		func() -> void: camera.frame(app.call("_selection_bounds")), selected)
	# F: the selection if there is one, else everything, as every tool with
	# both has it.
	_add("fit", "Fit", KEY_F, func() -> void:
		camera.frame(app.call("_selection_bounds") if not builder.selection.is_empty()
			else app.call("_built_bounds")), Callable(),
		"Zoom to show the selection, or the whole model")
	_add("ortho", "Orthographic", KEY_QUOTELEFT, func() -> void:
		camera.square_on(not camera.is_square_on()), Callable(),
		"Square on, with no perspective: how a CAD drawing is read")
	_ticked("ortho", camera.is_square_on)
	_add("grid", "Stud grid", 0, func() -> void: set_grid(not grid.visible), Callable(),
		"Lines between the studs of the baseplate, for counting them")
	_ticked("grid", func() -> bool: return grid.visible)
	_add("turn_left", "Turn the model left", KEY_Q, func() -> void: app.call("_turn_model", -1),
		something)
	_add("turn_right", "Turn the model right", KEY_E, func() -> void: app.call("_turn_model", 1),
		something)
	_add("panel_parts", "Parts bin", 0, func() -> void:
		(app.get("_bin_dock") as SideDock).toggle())
	_ticked("panel_parts", func() -> bool: return (app.get("_bin_dock") as SideDock).is_open())
	_add("panel_assistant", "Assistant", 0, func() -> void:
		(app.get("_chat_dock") as SideDock).toggle())
	_ticked("panel_assistant", func() -> bool:
		return (app.get("_chat_dock") as SideDock).is_open())
	_add("panel_properties", "Properties", 0, func() -> void: _toggle_section(inspector),
		Callable(),
		"What is selected: its part, colour, where it stands and what it is joined to")
	_ticked("panel_properties", func() -> bool: return _section_shown(inspector))
	_add("panel_keys", "Key strip", 0, func() -> void: set_key_strip(not key_strip_shown()))
	_ticked("panel_keys", key_strip_shown)
	_add("full_screen", "Full screen", KEY_F11, _toggle_full_screen)
	_ticked("full_screen", func() -> bool:
		return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	# Build
	_add("timeline", "Timeline", KEY_B, func() -> void: bar.timeline_wanted.emit(), something,
		"Play the build from an empty baseplate to the finished model and back")
	_ticked("timeline", func() -> bool:
		return (app.get("_steps") as StepsBar).is_playing_back())
	_add("parts_list", "Parts list", KEY_P, func() -> void: bar.parts_wanted.emit(), something,
		"Every part this model needs, by colour and count")
	var assembly: Callable = func() -> bool:
		return not assemblies.selected_assembly().is_empty()
	_add("make_submodel", "Make a sub-assembly…", CTRL | KEY_G,
		func() -> void: verbs.make_submodel(), selected,
		"Name the selection as a sub-assembly: it moves as one, saves as a sub-model, and its copies follow it")
	_add("leave_submodel", "Ungroup", CTRL | SHIFT | KEY_G,
		func() -> void: verbs.leave_submodel(), selected,
		"Take the selected sub-assembly apart one level")
	_add("enter_assembly", "Edit inside the sub-assembly", KEY_ENTER,
		func() -> void: verbs.enter_assembly(), assembly,
		"Work on its parts one by one; what you put down goes into it (double-click does this too)")
	_add("leave_assembly", "Done editing the sub-assembly", 0,
		func() -> void: verbs.leave_assembly(),
		func() -> bool: return not assemblies.entered.is_empty())
	_add("rename_assembly", "Rename the sub-assembly…", KEY_F2,
		func() -> void: verbs.rename_assembly(), assembly)
	_add("make_unique", "Make this copy unique", 0, func() -> void: verbs.make_unique(),
		func() -> bool:
			var path: String = assemblies.selected_assembly()
			return not path.is_empty() and not assemblies.copies_of(path).is_empty(),
		"Cut this copy loose, so editing it changes no other")
	_add("panel_outliner", "Model tree", 0, func() -> void: _toggle_section(outliner),
		Callable(), "The model's sub-assemblies by name, inside one another")
	_ticked("panel_outliner", func() -> bool: return _section_shown(outliner))
	_add("minifig", "Minifigure builder…", KEY_M, func() -> void: bar.minifig_wanted.emit(),
		Callable(), "Make a minifigure from real parts and stand it in the model")
	_add("mosaic", "Mosaic from a picture…", 0,
		func() -> void: bar.mosaic_wanted.emit(), Callable(),
		"Turn a picture into a wall of plates")
	_add("brickify", "Brickify a 3D model…", KEY_I,
		func() -> void: bar.brickify_wanted.emit(), Callable(),
		"Bring in an OBJ, STL or glTF model — a sculpt, a scan, anything — and lay it in bricks at the size you choose")
	_add("part_maker", "Part maker…", 0, func() -> void:
		(app.get("_bin") as PartsBin).make_wanted.emit(), Callable(),
		"Make a part of your own from the part in hand")
	_add("rotate_held", "Turn the part in hand", KEY_R, func() -> void:
		builder.rotate_held(1)
		app.call("_refresh_preview"))
	_add("tip_held", "Tip the part in hand on its side", KEY_T, func() -> void:
		builder.tip_held(1)
		app.call("_refresh_preview"))
	# Tools
	for tool: Array in [["select", "Select", KEY_V], ["place", "Place the part in hand", KEY_Q],
			["move", "Move", 0], ["rotate", "Rotate", 0], ["hinge", "Hinge", 0],
			["clone", "Clone", 0], ["paint", "Paint", 0], ["hide", "Hide", 0],
			["delete", "Delete", 0], ["orbit", "Orbit", KEY_O], ["pan", "Pan", KEY_H],
			["zoom", "Zoom", KEY_Z]]:
		var which: String = tool[0]
		var made: Command = _add("mode_" + which,
			str(tool[1]) + ("" if which == "place" else " tool"), tool[2],
			(func() -> void: verbs.take_last_part()) if which == "place"
				else (func() -> void: verbs.view_tool(which)) if EditVerbs.VIEW_TOOLS.has(which)
				else func() -> void: verbs.set_mode(which))
		made.ticked = func() -> bool: return verbs.mode == which
		made.radio = true
	_add("measure", "Measure", KEY_U, func() -> void: verbs.ruler(), Callable(),
		"A ruler: click two points for the distance in studs, plates and millimetres")
	_ticked("measure", func() -> bool: return verbs.measure != null and verbs.measure.active)
	_add("stability", "Check stability", 0, _check_stability, something,
		"Find the joints that would give way, and select the parts on them")
	_add("reseat", "Seat parts on their studs", 0, _reseat, something,
		"Find parts a fraction of a stud off their studs, and offer to seat them")
	_add("connector", "Claude connector…", 0, func() -> void:
		(app.get("_chat_dock") as SideDock).set_open(true)
		bar.say("the connector is at the foot of the assistant panel"), Callable(),
		"Let Claude build here, from your own Claude account")
	_add("settings", "Settings…", KEY_COMMA, func() -> void: bar.controls_wanted.emit(),
		Callable(), "Which way the wheel zooms, and what the middle button does")
	# Help
	_add("keys", "Keys and controls", KEY_F1, func() -> void: bar.controls_wanted.emit(),
		Callable(),
		"What every button and key does")
	_add("tour", "Take the tour", 0, func() -> void: tour.start())
	_add("website", "Brickworks website", 0,
		func() -> void: OS.shell_open("https://brickworks.diy"))
	_add("about", "About Brickworks", 0, _show_about)


## A menu on the bar, from its list of commands.
func _menu(title: String, items: Array) -> MenuButton:
	var button := MenuButton.new()
	button.text = title
	button.flat = true
	button.switch_on_hover = true
	button.focus_mode = Control.FOCUS_NONE
	# The keys are the app's own (EditVerbs, main), and a menu that also
	# answered them would do everything twice. The menu only shows them.
	button.set_disable_shortcuts(true)
	button.add_theme_font_size_override("font_size", 13)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var face := StyleBoxFlat.new()
		face.bg_color = {"normal": Color(1, 1, 1, 0.0), "hover": Color(1, 1, 1, 0.1),
			"pressed": Color(0.36, 0.6, 1.0, 0.3), "focus": Color(1, 1, 1, 0.0)}[state]
		face.set_corner_radius_all(4)
		face.content_margin_left = 8
		face.content_margin_right = 8
		face.content_margin_top = 3
		face.content_margin_bottom = 3
		button.add_theme_stylebox_override(state, face)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.86))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var popup: PopupMenu = button.get_popup()
	_fill(popup, items)
	popup.id_pressed.connect(_on_id)
	popup.about_to_popup.connect(func() -> void: _refresh(popup))
	return button


func _fill(popup: PopupMenu, items: Array) -> void:
	popup.add_theme_font_size_override("font_size", 13)
	for item: String in items:
		if item == "-":
			popup.add_separator()
		elif item.begins_with(">"):
			var sub := PopupMenu.new()
			var kind: String = item.substr(1)
			sub.name = kind
			sub.add_theme_font_size_override("font_size", 13)
			var words: String = {"recent": "Open recent", "import": "Import",
				"export": "Export", "history": "History",
				"select_by": "Select by"}[kind]
			# An id no command has, so the row is never taken for one.
			popup.add_submenu_node_item(words, sub, SUBMENU_ID + popup.item_count)
			if SUBMENUS.has(kind):
				_fill(sub, SUBMENUS[kind])
				sub.id_pressed.connect(_on_id)
				sub.about_to_popup.connect(func() -> void: _refresh(sub))
			elif kind == "recent":
				sub.about_to_popup.connect(func() -> void: _fill_recent(sub))
				sub.id_pressed.connect(func(id: int) -> void: _open_recent(sub, id))
			elif kind == "history":
				sub.about_to_popup.connect(func() -> void: _fill_history(sub))
				sub.id_pressed.connect(func(id: int) -> void: verbs.go_back(id + 1))
		else:
			var found: Command = _commands.get(item)
			if found == null:
				push_error("no command %s" % item)
				continue
			var id: int = _ids.size()
			_ids.append(item)
			if found.radio:
				popup.add_radio_check_item(found.words, id, found.accel)
			elif found.ticked.is_valid():
				popup.add_check_item(found.words, id, found.accel)
			else:
				popup.add_item(found.words, id, found.accel)
			if not found.tip.is_empty():
				popup.set_item_tooltip(popup.get_item_index(id), found.tip)


## Greyed where it would do nothing, ticked where it is on.
func _refresh(popup: PopupMenu) -> void:
	for index: int in popup.item_count:
		var id: int = popup.get_item_id(index)
		if popup.is_item_separator(index) or id < 0 or id >= _ids.size():
			continue
		var name: String = _ids[id]
		popup.set_item_disabled(index, not can(name))
		var on: int = ticked(name)
		if on >= 0:
			popup.set_item_checked(index, on == 1)


func _on_id(id: int) -> void:
	if id >= 0 and id < _ids.size():
		run(_ids[id])


var _recent: Array[ModelStore.Entry] = []


func _fill_recent(menu: PopupMenu) -> void:
	menu.clear()
	_recent = store.list_saved()
	_recent = _recent.slice(0, 8)
	if _recent.is_empty():
		menu.add_item("nothing saved yet")
		menu.set_item_disabled(0, true)
	for n: int in _recent.size():
		menu.add_item(_recent[n].describe(), n)


func _open_recent(_menu_of: PopupMenu, id: int) -> void:
	if id < 0 or id >= _recent.size():
		return
	bar.opened.emit(store.open(_recent[id].path))


func _fill_history(menu: PopupMenu) -> void:
	menu.clear()
	var said: PackedStringArray = builder.history_words(25)
	if said.is_empty():
		menu.add_item("nothing to go back to yet")
		menu.set_item_disabled(0, true)
	for n: int in said.size():
		menu.add_item("Undo %s" % said[n] if n == 0 else "Back to before: %s" % said[n], n)


# -- what only the shell does ---------------------------------------------------


func _ask_save_as() -> void:
	_save_as_name.text = bar.model_name()
	_save_as.popup_centered()
	_save_as_name.grab_focus()
	_save_as_name.select_all()


func _save_named(name: String) -> void:
	var called: String = name.strip_edges()
	if called.is_empty():
		return
	bar._name.text = called
	bar._name.text_changed.emit(called)
	bar._on_save()


## The booklet, where the app has one of its own to open; the timeline,
## where the booklet is made from, where it does not.
func _instructions() -> void:
	if app.has_method("_booklet_wanted"):
		app.call("_booklet_wanted")
	else:
		app.call("_toggle_steps")


func _check_stability() -> void:
	var stability: Stability = app.get("_stability")
	var report: Stability.Report = stability.check(world)
	if report.risks.is_empty():
		bar.say("it stands up — no joint is carrying more than it can hold")
		return
	builder.selection.clear()
	for risk: Stability.Risk in report.risks:
		if not store.scenery.has(risk.brick_id) and world.get_brick(risk.brick_id) != null:
			builder.selection[risk.brick_id] = true
	builder.selection_changed.emit(builder.selection.size())
	bar.say("%d weak joint%s, selected: %s" % [report.risks.size(),
		"" if report.risks.size() == 1 else "s",
		report.weakest.message if report.weakest != null else ""])


func _reseat() -> void:
	var offer: SeatOffer = app.get("_seat_offer")
	if offer.check() == 0:
		bar.say("every part is on its studs")


func _toggle_full_screen() -> void:
	var full: bool = ticked("full_screen") == 1
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
		else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _show_about() -> void:
	_about.dialog_text = ("Brickworks %s\n\nBuild with real LEGO parts, by hand or with "
		+ "the assistant, on the web or on your own computer.\n\n%s") % [
		BuildInfo.version(), BuildInfo.describe()]
	_about.popup_centered()


func set_grid(on: bool) -> void:
	grid.visible = on
	if on:
		grid.redraw()
	ShellPrefs.put("grid", on)


func key_strip_shown() -> bool:
	var hint: Control = app.get("_hint")
	return hint != null and hint.get_parent() != null and (hint.get_parent() as Control).visible


func set_key_strip(on: bool) -> void:
	var hint: Control = app.get("_hint")
	if hint == null or hint.get_parent() == null:
		return
	(hint.get_parent() as Control).visible = on
	ShellPrefs.put("key_strip", on)


func set_snap(to: String) -> void:
	verbs.set_snap(to)
	ShellPrefs.put("snap", to)


func set_turn_step(degrees: float) -> void:
	verbs.turn_step = degrees
	ShellPrefs.put("turn_step", degrees)


## The keys only the shell answers: full screen, and the controls sheet on F1.
func handle_key(key: InputEventKey) -> bool:
	if key.echo:
		return false
	var held: bool = key.ctrl_pressed or key.meta_pressed
	# Open and Save as, which O (square on) and S alone do not mean.
	if held and key.keycode == KEY_O and not key.shift_pressed:
		run("open")
		return true
	if held and key.shift_pressed and key.keycode == KEY_S:
		run("save_as")
		return true
	match key.keycode:
		KEY_F11:
			run("full_screen")
			return true
		KEY_F1:
			run("keys")
			return true
		KEY_F2:
			if can("rename_assembly"):
				run("rename_assembly")
				return true
		KEY_ENTER, KEY_KP_ENTER:
			if can("enter_assembly") and not held:
				run("enter_assembly")
				return true
	return false


## Whether a point is over the shell's own panels rather than the model.
func covers(point: Vector2) -> bool:
	for panel: Control in [toolbar, inspector, status, outliner, banner]:
		if panel != null and panel.is_visible_in_tree() \
				and panel.get_global_rect().has_point(point):
			return true
	return tour != null and tour.visible


## Where each control is, for a browser test to press it as a person does.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	for button: MenuButton in _menus:
		out["menu_" + button.text.to_lower()] = button
	if toolbar != null:
		out.merge(toolbar.controls_by_name())
	if inspector != null:
		out.merge(inspector.controls_by_name())
	if outliner != null:
		out.merge(outliner.controls_by_name())
	if banner != null:
		out.merge(banner.controls_by_name())
	return out


## A menu on the bar by its title, for a probe to open.
func menu(title: String) -> MenuButton:
	for button: MenuButton in _menus:
		if button.text == title:
			return button
	return null


## The id a command has in the menus, for a probe to press it there.
func menu_id(name: String) -> int:
	return _ids.find(name)
