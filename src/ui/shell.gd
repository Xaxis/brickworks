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
## My collection: src/ui/collection_dialog.gd.
var collection: CollectionDialog
## The cut-away and x-ray: src/ui/see_inside.gd.
var see_inside: SeeInside

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
		"share", ">export", "render", "instructions", "-", "clear", "account", "quit"]],
	["Edit", ["undo", "redo", ">history", "-", "cut_parts", "copy", "paste", "duplicate",
		"delete", "-", "select_all", "select_none", ">select_by", "-", "hide",
		"isolate", "show_all", "-", "lock", "unlock", "-", "paint", "replace", "mirror",
		"-", "ask_claude", "-", "make_submodel", "leave_submodel", "enter_assembly", "leave_assembly",
		"rename_assembly", "make_unique", "-", ">steps", "-", "reshape_flex"]],
	["View", ["view_default", "view_front", "view_back", "view_left", "view_right",
		"view_top", "view_bottom", "view_iso", "-", "mode_orbit", "mode_pan", "mode_zoom",
		"fit", "fit_model", "fit_selection",
		"ortho", "grid", ">floor", "-", "cut", ">cut_away", "xray", "-", "turn_left", "turn_right", "-", "panel_parts",
		"panel_assistant", "panel_properties", "panel_outliner", "panel_keys", "-",
		"full_screen"]],
	["Build", ["timeline", "pose", "instructions", "parts_list", "-", "collection", "collection_need",
		"collection_build", "-", "make_submodel",
		"leave_submodel", "enter_assembly", "select_submodel", "-", "flex", "minifig", "mosaic",
		"brickify", "part_maker", "print_part", "sticker",
		"-", "rotate_held", "tip_held"]],
	["Tools", ["mode_select", "mode_place", "mode_move", "mode_rotate", "mode_hinge",
		"mode_clone", "mode_paint", "mode_hide", "mode_delete", "-", "measure",
		"stability", "simulate", "reseat", "-", "connector", "settings"]],
	["Help", ["keys", "tour", "-", "website", "about"]],
]

## Submenu rows are numbered from here, clear of the commands.
const SUBMENU_ID := 10000

const SUBMENUS: Dictionary = {
	"import": ["import_ldraw", "import_io", "import_lxf", "import_mesh"],
	"export": ["export_ldraw", "export_io", "export_3d", "export_picture", "export_bricklink",
		"export_rebrickable"],
	"select_by": ["select_colour", "select_part", "select_alike", "select_connected",
		"select_submodel", "select_inverse"],
	"cut_away": ["cut_x", "cut_y", "cut_z", "-", "cut_flip", "cut_ghosts"],
	"steps": ["step_prev", "step_next", "step_new", "-", "step_earlier", "step_later",
		"step_merge", "step_delete"],
	"floor": ["floor_16", "floor_32", "floor_48", "floor_custom", ">floor_colour", "-",
		"floor_grid", "floor_none", "-", "floor_part", "floor_default"],
	"floor_colour": ["floor_colour_2", "floor_colour_10", "floor_colour_288",
		"floor_colour_19", "floor_colour_28", "floor_colour_71", "floor_colour_72",
		"floor_colour_378", "floor_colour_1", "floor_colour_15", "floor_colour_0",
		"floor_colour_7"],
}


## Everything put on screen: the menus into the bar, the toolbar under it,
## the status bar at the foot of ``column``, the model tree and the
## properties in the left-hand column ``stack``, under the parts bin, and
## the banner for a sub-assembly being edited in ``notices``, the strip
## along the top of the model. Nothing of it is laid over the model.
func build(column: Control, stack: PanelStack, notices: Control, over_model: Control) -> void:
	bar = app.get("_bar")
	builder = app.get("_builder")
	verbs = app.get("_verbs")
	camera = app.get("_camera")
	world = app.get("_world")
	library = app.get("_library")
	store = app.get("_store")
	bar.attend = attend
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
	see_inside = SeeInside.new()
	see_inside.world = world
	see_inside.builder = builder
	see_inside.assemblies = assemblies
	see_inside.camera = camera
	see_inside.scenery = store.scenery
	see_inside.say = bar.say
	see_inside.bounds_of_model = func() -> AABB: return app.call("_built_bounds")
	add_child(see_inside)
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
	# The cut-away's strip floats over the model's foot, above the key
	# strip and the timeline it keeps clear of.
	over_model.add_child(see_inside.bar)
	see_inside.below.append(app.get("_hint"))
	see_inside.below.append(app.get("_steps"))

	grid = StudGrid.new()
	grid.world = world
	grid.library = library
	grid.scenery = store.scenery
	grid.floor_layer = app.get("_floor")
	app.add_child(grid)

	tour = Tour.new()
	tour.shell = self
	app.get_node("HUD").add_child(tour)

	# What the person owns, what this model needs of it, what they could
	# build: src/ui/collection_dialog.gd. The parts list leads there too.
	collection = CollectionDialog.new()
	collection.said.connect(func(text: String) -> void: bar.say(text))
	collection.attach(app)
	var parts_list: Variant = app.get("_inventory")
	if parts_list is InventoryPanel:
		(parts_list as InventoryPanel).need_wanted.connect(func() -> void: collection.open("need"))

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
		attend("save", _save_named.bind(_save_as_name.text)))
	asking.add_child(_save_as_name)
	_save_as.add_child(asking)
	_save_as.confirmed.connect(func() -> void:
		attend("save", _save_named.bind(_save_as_name.text)))
	add_child(_save_as)

	_about = AcceptDialog.new()
	_about.title = "About Brickworks"
	_about.dialog_autowrap = true
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
	# Two commands of one name: the second replaced the first, and its
	# menu item ran the other one (Edit, Cut ran the cut-away).
	if _commands.has(name):
		push_error("two commands are named %s" % name)
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


## Run a command by name, when it can be. True when it ran, or will in a
## frame: one known to be slow is said on the status bar first (Working).
func run(name: String) -> bool:
	var found: Command = _commands.get(name)
	if found == null or not can(name):
		return false
	attend(name, func() -> Variant:
		# Asked again: put off a frame, it may not be any more.
		return found.run.call() if can(name) else null)
	return true


## Do [param work] as command [param name]: said first when it is slow,
## timed, and its words on the bar for as long as it goes on (Working.attend).
## The menus, the toolbar, the keys and the dialogs' buttons all come here.
func attend(name: String, work: Callable) -> void:
	var size: int = work_size(name)
	var slow: bool = size >= int(SLOW_FROM.get(name,
		FLOOR_SLOW_FROM if name.begins_with("floor_") else 1 << 30))
	# A step edit is slow only the first time, when the model is given the
	# worked-out steps (AuthorSteps.ensure).
	if name.begins_with("step_") and world != null:
		slow = slow and not AuthorSteps.any(world, store.scenery)
	Working.attend(name, doing(name), work, name in IN_THE_PRESS, slow, size)


## How much a command has to do: the selection, for one that changes the
## selection; what is in hand, for Paste; otherwise the model. Its costs
## are kept by this (Working.attend): mirroring all of Orthanc is seconds,
## and three of its parts nothing, and the bar must not flash for the three.
func work_size(name: String) -> int:
	if world == null:
		return 0
	if name in ON_THE_SELECTION:
		return builder.selection.size()
	if name == "paste":
		return Carry.clipboard.size()
	return world.brick_count() - store.scenery.size()


## The commands whose work grows with the selection rather than the model.
const ON_THE_SELECTION: Array[String] = ["mirror", "replace", "duplicate", "paint",
	"cut_parts", "copy", "delete", "hide", "isolate", "lock", "make_submodel",
	"leave_submodel", "make_unique", "rotate_held", "tip_held"]


## What the bar says while a command works: "Saving…".
func doing(name: String) -> String:
	if DOING.has(name):
		return str(DOING[name])
	var found: Command = _commands.get(name)
	var words: String = found.words.trim_suffix("…") if found != null else name
	return "Working on %s…" % words.to_lower()


## The commands a browser lets do what they do only inside the press
## itself — open a file dialog, go full screen, open a page — which are
## never put off a frame to say so first. (The clipboard is not among
## them: in a browser the app keeps its own, EditVerbs.copy.)
const IN_THE_PRESS: Array[String] = ["open", "import_ldraw", "import_io", "import_lxf",
	"import_mesh", "mosaic", "brickify", "full_screen", "website", "quit"]

## Laying a floor again under a big model: its plates cover more ground.
const FLOOR_SLOW_FROM := 3000

## Known to be slow from this much to do ([method work_size]), before they
## have ever been timed here. From src/dev/command_probe.gd on Orthanc
## (9,429 parts), where on the desktop these held one frame for one to four
## seconds (mirror, replace, a first step edit, turning the model, the
## collection, the stability check, a copy in hand) or a fifth of a second
## to one second (painting, the selections, hiding, the lists, Cut): a
## browser drawing in software takes several times longer. What can I
## build? reads the collection against every set, whatever is on the
## baseplate.
const SLOW_FROM: Dictionary = {
	"mirror": 200, "replace": 200, "duplicate": 300, "paste": 300, "cut_parts": 600,
	"paint": 600, "hide": 3000, "isolate": 3000, "leave_submodel": 2000,
	"make_unique": 2000,
	"step_new": 300, "step_prev": 300, "step_next": 300, "step_earlier": 300,
	"step_later": 300, "step_merge": 300, "step_delete": 300,
	"turn_left": 300, "turn_right": 300, "collection_build": 0, "collection_need": 1000,
	"stability": 300, "select_all": 2000, "select_colour": 2000, "select_part": 2000,
	"select_alike": 2000, "select_inverse": 2000, "parts_list": 2000, "reseat": 2000,
	"export_bricklink": 3000, "export_rebrickable": 3000, "pose": 3000,
	# New first asks whether the model on the baseplate is saved as it is.
	"new": 2000,
}

## What the bar says for the commands that can take a while.
const DOING: Dictionary = {
	"new": "Starting a new model…", "save": "Saving…", "save_as": "Saving…",
	"save_new": "Saving, then starting a new model…",
	"clear": "Clearing the baseplate…",
	"export_ldraw": "Exporting the model…", "export_io": "Exporting the Studio model…",
	"export_picture": "Taking a picture of the model…",
	"export_bricklink": "Exporting the BrickLink wanted list…",
	"export_rebrickable": "Exporting the parts list…",
	"render": "Opening Render…", "pose": "Opening Pose and animate…",
	"instructions": "Making the instructions…", "share": "Opening Share…",
	"undo": "Undoing…", "redo": "Redoing…", "history": "Going back…",
	"cut_parts": "Cutting…", "copy": "Copying…", "paste": "Pasting…",
	"duplicate": "Duplicating…", "delete": "Deleting…",
	"select_all": "Selecting everything…", "select_none": "Selecting nothing…",
	"select_colour": "Selecting the same colour…", "select_part": "Selecting the same part…",
	"select_alike": "Selecting the same part and colour…",
	"select_connected": "Selecting everything connected…",
	"select_submodel": "Selecting the sub-model…", "select_inverse": "Selecting the opposite…",
	"hide": "Hiding…", "isolate": "Showing only the selection…", "show_all": "Showing everything…",
	"lock": "Locking…", "unlock": "Unlocking…", "paint": "Painting…",
	"replace": "Replacing…", "mirror": "Mirroring…",
	"make_submodel": "Making a sub-assembly…", "leave_submodel": "Ungrouping…",
	"make_unique": "Making the copy unique…",
	"timeline": "Opening the timeline…", "parts_list": "Listing the parts…",
	"collection": "Opening My collection…", "collection_need": "Working out what you need…",
	"collection_build": "Working out what you can build…",
	"fit": "Fitting the view…", "fit_model": "Fitting the model…",
	"turn_left": "Turning the model…", "turn_right": "Turning the model…",
	"stability": "Checking stability…", "reseat": "Seating parts on their studs…",
	"simulate": "Reading the mechanism…",
	"cut": "Cutting away…", "xray": "Seeing through…", "grid": "Laying the stud grid…",
	"step_new": "Making a step…", "step_earlier": "Moving the step…",
	"step_later": "Moving the step…", "step_merge": "Merging the steps…",
	"step_delete": "Taking out the step…",
}


## The command a key is the shortcut of, or "": for timing and saying a
## key the way the same command is from a menu.
func command_for_key(key: InputEventKey) -> String:
	if _by_key.is_empty():
		for name: String in _commands:
			var accel: int = (_commands[name] as Command).accel
			if accel != 0 and not _by_key.has(accel):
				_by_key[accel] = name
		# Two keys for one thing.
		_by_key[KEY_BACKSPACE] = "delete"
	var accel: int = key.keycode
	if key.ctrl_pressed or key.meta_pressed:
		accel |= CTRL
	if key.shift_pressed:
		accel |= SHIFT
	if key.alt_pressed:
		accel |= ALT
	return str(_by_key.get(accel, ""))


var _by_key: Dictionary = {}


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
	if found == null:
		return ""
	return key_text(found.accel)


## The keys the engine names by what its source calls them — "QuoteLeft",
## "Comma" — as a person writes them on a key or in a manual.
const WRITTEN: Dictionary = {KEY_QUOTELEFT: "`", KEY_COMMA: ",", KEY_PERIOD: ".",
	KEY_SLASH: "/", KEY_BACKSLASH: "\\", KEY_MINUS: "-", KEY_EQUAL: "=",
	KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]", KEY_SEMICOLON: ";",
	KEY_APOSTROPHE: "'"}


## A key and its modifiers as a person writes them: "Ctrl+Z", "Shift+Q",
## "`". The menus showed the orthographic key as "QuoteLeft", and turning
## the model as Q when it is Shift-Q (brickworks.diy, 2026-10-12).
static func key_text(accel: int) -> String:
	if accel == 0:
		return ""
	var parts := PackedStringArray()
	if accel & KEY_MASK_CMD_OR_CTRL or accel & KEY_MASK_CTRL:
		parts.append(EditVerbs.held_key())
	if accel & KEY_MASK_ALT:
		parts.append("Alt")
	if accel & KEY_MASK_SHIFT:
		parts.append("Shift")
	var code: int = accel & KEY_CODE_MASK
	parts.append(str(WRITTEN[code]) if WRITTEN.has(code) else OS.get_keycode_string(code))
	return "+".join(parts)


## What a menu is given to show for a key. The menu writes a key with the
## engine's own name for it and has no way to be told other words; for a
## key it misnames, the character it would draw for itself. The menus never
## answer a key (Shell._menu), so this is only ever read, never pressed.
const SHOWN_AS: Dictionary = {KEY_QUOTELEFT: 0x201B, KEY_COMMA: 0x201A}


## Keys with no look-alike the menus' font has (the step keys, Shift-[ and
## Shift-]): none, and the menu writes the key into the line instead.
const UNDRAWN: Array[int] = [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]


static func menu_accel(accel: int) -> int:
	var code: int = accel & KEY_CODE_MASK
	if code in UNDRAWN:
		return 0
	if not SHOWN_AS.has(code):
		return accel
	return (accel & ~KEY_CODE_MASK) | int(SHOWN_AS[code])


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
	_add("import_lxf", "LEGO® Digital Designer model (.lxf)…", 0, bar._import)
	_add("import_mesh", "3D model to brickify (.obj, .stl, .gltf, .glb)…", 0,
		func() -> void: bar.brickify_wanted.emit(), Callable(),
		"A sculpt, a scan or any 3D model, laid in bricks")
	_add("save", "Save", CTRL | KEY_S, bar._on_save, something,
		"Keep this model under its name")
	_add("save_as", "Save as…", CTRL | SHIFT | KEY_S, _ask_save_as, something,
		"Keep a copy of this model under another name")
	_add("export_ldraw", "LDraw model (.ldr, or .mpd with its sub-models)", 0,
		func() -> void: bar._on_export_chosen(0), something)
	_add("export_io", "BrickLink Studio model (.io)", 0,
		func() -> void: bar._on_export_chosen(4), something)
	# src/ui/exports.gd, src/parts/mesh_export.gd.
	_add("export_3d", "3D model (.glb, .gltf, .obj, .stl)…", 0,
		func() -> void: (app.get("_exports") as Exports).ask_model_3d(), something,
		"The model as a 3D file for Blender, AR or a 3D printer")
	_add("export_picture", "Picture of the model (.png)", 0,
		func() -> void: bar._on_export_chosen(1), something)
	_add("export_bricklink", "BrickLink wanted list (.xml)", 0,
		func() -> void: bar._on_export_chosen(2), something)
	_add("export_rebrickable", "Rebrickable parts list (.csv)", 0,
		func() -> void: bar._on_export_chosen(3), something)
	_add("render", "Render…", 0, func() -> void: app.call("open_render"), something,
		"A photo-real picture or turntable of the model, on a backdrop, in studio light")
	# src/ui/pose_panel.gd.
	_add("pose", "Pose and animate…", 0, func() -> void: app.call("open_pose"), something,
		"A slider for every part on a hinge or a turntable, and keys made an animation")
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
	# Not "cut": that is the cut-away (K), defined under View, and a second
	# command of one name replaced the first, so Edit, Cut sliced the model
	# open instead of taking the selection off it.
	_add("cut_parts", "Cut", CTRL | KEY_X, func() -> void: verbs.cut(), selected,
		"Take the selection off the model, to paste somewhere else")
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
		func() -> void: verbs.select_connected(), selected)
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
	# src/ai/selection_scope.gd: Claude changes these parts and the room round
	# them, and nothing else.
	_add("ask_claude", "Ask Claude about this…", CTRL | KEY_K,
		func() -> void: app.call("ask_about_selection"), selected,
		"Ask Claude to change the selected parts, and only them, or ask about them")
	# The author's steps: src/assembly/author_steps.gd. The selection, then
	# the step the timeline is on.
	_add("step_prev", "Move to previous step", SHIFT | KEY_BRACKETLEFT,
		func() -> void: edit_steps("prev"), selected,
		"The selected parts a step earlier in the build steps")
	_add("step_next", "Move to next step", SHIFT | KEY_BRACKETRIGHT,
		func() -> void: edit_steps("next"), selected,
		"The selected parts a step later in the build steps, in a new step from the last")
	_add("step_new", "New step from selection", SHIFT | KEY_N,
		func() -> void: edit_steps("new"), selected,
		"The selected parts in a step of their own, after the step the timeline is on")
	var on_a_step: Callable = func() -> bool:
		return (app.get("_steps") as StepsBar).current_step() != null
	_add("step_earlier", "Step earlier", 0, func() -> void: edit_steps("earlier"), on_a_step,
		"The step the timeline is on, before the one ahead of it")
	_add("step_later", "Step later", 0, func() -> void: edit_steps("later"), on_a_step,
		"The step the timeline is on, after the one that follows it")
	_add("step_merge", "Merge with the next step", 0, func() -> void: edit_steps("merge"),
		on_a_step, "The step the timeline is on and the next made one")
	_add("step_delete", "Delete the step", 0, func() -> void: edit_steps("delete"), on_a_step,
		"Take out the step the timeline is on; its parts join the step before")
	# src/ui/flex_tool.gd.
	_add("flex", "Hose, tube or chain…", 0, func() -> void: app.call("open_flex"), Callable(),
		"Lay a hose, a tube, a string or a chain from one connector to another, along a curve")
	_add("reshape_flex", "Reshape the hose or chain", 0, func() -> void: app.call("reshape_flex"),
		func() -> bool: return bool(app.call("can_reshape_flex")),
		"Drag the selected hose's bend, or put its chain round other sprockets")
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
	_define_floor()
	_add("cut", "Cut away", KEY_K, func() -> void: see_inside.set_cut(not see_inside.cutting),
		something, "A plane through the model, dragged along X, Y or Z, to see and work inside it")
	_ticked("cut", func() -> bool: return see_inside.cutting)
	for along: int in 3:
		var which: int = along
		_add("cut_" + SeeInside.AXES[along].to_lower(), "Along %s" % SeeInside.AXES[along], 0,
			func() -> void: see_inside.cut_along(which), something)
		_ticked("cut_" + SeeInside.AXES[along].to_lower(), func() -> bool:
			return see_inside.cutting and see_inside.axis == which)
	_add("cut_flip", "Cut away the other side", SHIFT | KEY_K, func() -> void: see_inside.flip(),
		func() -> bool: return see_inside.cutting)
	_add("cut_ghosts", "Leave a ghost of what is cut away", 0,
		func() -> void: see_inside.set_ghosts(not see_inside.leaves_ghosts), Callable())
	_ticked("cut_ghosts", func() -> bool: return see_inside.leaves_ghosts)
	_add("xray", "X-ray", KEY_I, func() -> void: see_inside.set_xray(not see_inside.seeing_through),
		func() -> bool: return (see_inside.seeing_through or not builder.selection.is_empty()
			or not assemblies.entered.is_empty()),
		"Everything but the selection, or the sub-assembly being edited, see-through")
	_ticked("xray", func() -> bool: return see_inside.seeing_through)
	# Shift: Q alone takes the last part back into hand (Tools, Place).
	_add("turn_left", "Turn the model left", SHIFT | KEY_Q,
		func() -> void: app.call("_turn_model", -1), something)
	_add("turn_right", "Turn the model right", SHIFT | KEY_E,
		func() -> void: app.call("_turn_model", 1), something)
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
	_add("show_properties", "Properties", 0, func() -> void:
		(app.get("_bin_dock") as SideDock).set_open(true)
		inspector.set_open(true), selected,
		"What it is, its colour by every name, where it stands and what it is joined to")
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
	_add("collection", "My collection…", 0, func() -> void: collection.open("own"), Callable(),
		"The sets and parts you own: from Rebrickable, BrickLink, or typed in")
	_add("collection_need", "What do I need?…", 0, func() -> void: collection.open("need"),
		something, "What this model uses that you do not own, and what could stand in")
	_add("collection_build", "What can I build?…", 0, func() -> void: collection.open("build"),
		Callable(), "Models ranked by how much of each you already own")
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
	_add("brickify", "Brickify a 3D model…", CTRL | KEY_I,
		func() -> void: bar.brickify_wanted.emit(), Callable(),
		"Bring in an OBJ, STL or glTF model — a sculpt, a scan, anything — and lay it in bricks at the size you choose")
	_add("part_maker", "Part maker…", 0, func() -> void:
		(app.get("_bin") as PartsBin).make_wanted.emit(), Callable(),
		"Make a part of your own from the part in hand")
	# The parts bin's Print… and its sticker sheet's Draw a sticker, in the
	# menus too: every command a session can match is one the menus have.
	_add("print_part", "Print on a part…", 0, func() -> void:
		(app.get("_studio") as PrintStudio).print_part(builder.held_part), Callable(),
		"Draw a print on the part selected, printed where it stands, or on the part in hand")
	_add("sticker", "Put a sticker on…", 0, func() -> void:
		(app.get("_studio") as PrintStudio).sticker(), Callable(),
		"Click a face of the model, then draw the sticker that goes on it")
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
	# src/ui/simulate_panel.gd. Beside Check stability rather than with Pose
	# under Build: both read the model as it is built and change none of it,
	# where every pose a slider sets is a step to undo.
	_add("simulate", "Simulate mechanism…", 0, func() -> void: app.call("open_simulate"),
		something, "Turn a gear train from a crank or an axle: how fast each part goes, "
			+ "each arm's period, what locks it, and whether it stays standing as it turns")
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


## What a right click on a part offers: the verbs a person reaches for,
## each the command Edit or Build has, greyed where it would do nothing.
## A right click on a part did nothing (brickworks.diy, 2026-10-12).
const ON_A_PART: Array = ["ask_claude", "-", "select_connected", "-", "hide", "isolate", "-", "paint",
	"copy", "delete", "-", "make_submodel", "-", "show_properties"]
var context: PopupMenu


## The menu for a part, at a point on the screen, for the selection the
## right click left: the part, or the selection it is in.
func open_context(at: Vector2) -> void:
	if context == null:
		context = PopupMenu.new()
		_fill(context, ON_A_PART)
		context.set_item_text(item_index(context, "select_connected"),
			"Select everything joined to it")
		context.id_pressed.connect(_on_id)
		add_child(context)
	_refresh(context)
	# Painting is with the colour in hand: which one, said.
	context.set_item_text(item_index(context, "paint"),
		"Paint with %s" % library.color(builder.held_color).name)
	context.reset_size()
	var room: Vector2 = app.get_viewport().get_visible_rect().size
	var corner: Vector2 = Vector2(minf(at.x, room.x - context.size.x - 4.0),
		minf(at.y, room.y - context.size.y - 4.0))
	context.position = Vector2i(corner.max(Vector2.ZERO))
	context.popup()


## Where a command is in one menu: each menu that lists a command has an
## id of its own for it.
func item_index(popup: PopupMenu, name: String) -> int:
	for index: int in popup.item_count:
		var id: int = popup.get_item_id(index)
		if id >= 0 and id < _ids.size() and _ids[id] == name:
			return index
	return -1


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
				"select_by": "Select by", "cut_away": "Cut along", "steps": "Build steps",
				"floor": "Floor", "floor_colour": "Baseplate colour"}[kind]
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
				sub.id_pressed.connect(func(id: int) -> void:
					attend("history", verbs.go_back.bind(id + 1)))
		else:
			var found: Command = _commands.get(item)
			if found == null:
				push_error("no command %s" % item)
				continue
			var id: int = _ids.size()
			_ids.append(item)
			var shown: int = menu_accel(found.accel)
			# A key the menu can neither name nor draw goes in the words.
			var words: String = found.words
			if shown == 0 and found.accel != 0:
				words += "    " + key_text(found.accel)
			if found.radio:
				popup.add_radio_check_item(words, id, shown)
			elif found.ticked.is_valid():
				popup.add_check_item(words, id, shown)
			else:
				popup.add_item(words, id, shown)
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
	bar.opened.emit(await bar.open_with_progress(_recent[id].path))


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


## Tools, Check stability: the joints that would give way, selected, and
## then the balance (Balance) — the margin said here in the status bar, the
## support polygon and the centre of mass drawn on the floor (BalanceMark),
## and the stud joints carrying most against their studs tinted — over every
## pose the Pose panel's animation or its sliders reach.
func _check_stability() -> void:
	var stability: Stability = app.get("_stability")
	stability.floor_ids = store.scenery
	var report: Stability.Report = stability.check(world)
	var said: String = "it stands up — no joint is carrying more than it can hold"
	# The joints Stability finds weak, apart from tipping, which the
	# balance says better.
	var weak: Array = report.risks.filter(func(risk: Stability.Risk) -> bool:
		return risk.kind != "tips")
	if not weak.is_empty():
		builder.selection.clear()
		for risk: Stability.Risk in weak:
			if not store.scenery.has(risk.brick_id) and world.get_brick(risk.brick_id) != null:
				builder.selection[risk.brick_id] = true
		builder.selection_changed.emit(builder.selection.size())
		said = "%d weak joint%s, selected: %s" % [weak.size(), "" if weak.size() == 1 else "s",
			(weak[0] as Stability.Risk).message]
	bar.say(said)
	var balance: Balance.Report = await weigh_balance()
	if balance != null and not balance.empty:
		bar.say(balance.words() if weak.is_empty() else "%s. %s" % [said, balance.words()])


var _balance_mark: BalanceMark = null
## The last balance weighed, for a probe.
var balance_shown: Balance.Report = null


## The balance readout while its marks are on the floor: what the status
## bar's line says once the message has gone (StatusBar), so the words stay
## as long as the picture of them does.
func balance_line() -> String:
	if _balance_mark == null or _balance_mark.report == null:
		return ""
	return _balance_mark.report.words()


## Whether the model stands on what it stands on (Balance), over the poses
## [method _poses_to_weigh] gives, and shown: on the floor, and as tints. On
## a worker for a big model, and Working shown either way, since the sweep
## alone can take more than a frame. A mechanism's cycle (SimulatePanel)
## gives its own, [param given]; [param show] false weighs without drawing,
## and [param tint] false leaves the parts' tints to the caller.
func weigh_balance(given: Variant = null, show: bool = true, tint: bool = true) -> Balance.Report:
	var job: Working.Job = Working.begin("Weighing the model…")
	await job.shown()
	var poses: Array = given if given is Array else _poses_to_weigh()
	var judge := Balance.new()
	judge.library = library
	judge.floor_ids = store.scenery
	var weighed: Array = [null]
	if world.brick_count() < WEIGH_OFF_THREAD_FROM or OS.has_feature("nothreads"):
		judge.lattice = builder.lattice
		weighed[0] = judge.measure(world.bricks(), poses)
	else:
		judge.lattice = builder.lattice.copy_for_reading()
		var still: BrickWorld = world.copy_for_reading()
		library.begin_reading()
		var task: int = WorkerThreadPool.add_task(func() -> void:
			weighed[0] = judge.measure(still.bricks(), poses), false, "weigh the balance")
		library.reading_in(task)
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		library.end_reading(task)
		still.free()
	job.end()
	var report: Balance.Report = weighed[0]
	if report == null or not show:
		return report
	if _balance_mark == null:
		_balance_mark = BalanceMark.new()
		_balance_mark.world = world
		app.add_child(_balance_mark)
	_balance_mark.show_report(report, _tints(report) if tint else {})
	balance_shown = report
	return report


## From this many parts the weighing goes to a worker, as the status bar's
## does (Main.WEIGH_OFF_THREAD_FROM).
const WEIGH_OFF_THREAD_FROM := 600


## The poses to weigh: the Pose panel's, while its joints still stand as it
## set them — its animation's frames when it has keys, otherwise every joint
## swung through its reach (Poser.sweep) — or the joints found afresh.
func _poses_to_weigh() -> Array:
	var panel: PosePanel = app.get("_pose")
	var poser: Poser = panel.poser if panel != null else null
	if poser != null and poser.world != null and not poser.joints.is_empty() and poser.holds():
		return poser.sweep(panel.animation)
	poser = Poser.new()
	poser.world = world
	poser.builder = builder
	poser.library = library
	poser.assemblies = assemblies
	poser.find()
	return poser.sweep()


## The part past each stud joint carrying half its working load or more —
## the one that would come off — amber at half and red at all of it.
func _tints(report: Balance.Report) -> Dictionary:
	var tints: Dictionary = {}
	for one: Balance.JointLoad in report.joints:
		if one.ratio < 0.5 or store.scenery.has(one.beyond):
			continue
		tints[one.beyond] = BalanceMark.CLOSE.lerp(BalanceMark.TIPS,
			clampf((one.ratio - 0.5) * 2.0, 0.0, 1.0))
	return tints


func _reseat() -> void:
	var offer: SeatOffer = app.get("_seat_offer")
	if offer.check() == 0:
		bar.say("every part is on its studs")


func _toggle_full_screen() -> void:
	var full: bool = ticked("full_screen") == 1
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
		else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _show_about() -> void:
	_about.dialog_text = ("Brickworks %s\n\nBuild with real LEGO® parts, by hand or with "
		+ "the assistant, on the web or on your own computer.\n\n%s\n\n"
		+ "Part geometry from the LDraw™ Parts Library, CC BY 4.0.\n"
		+ "LEGO® is a trademark of the LEGO Group of companies which does not sponsor, authorize or endorse this app. "
		+ "LEGO® Art, Technic, the Minifigure and the Brick and Knob configurations are also trademarks of the LEGO Group.") % [
		BuildInfo.version(), BuildInfo.describe()]
	_about.popup_centered(Vector2i(460, 0))


## View, Floor: what the model stands on (ModelFloor, FloorLayer). Each a
## step of the history, and none of them moves what is built.
func _define_floor() -> void:
	var floor_layer: FloorLayer = app.get("_floor")
	var plate: Callable = func() -> bool: return store.model_floor.is_plate()
	for studs: int in ModelFloor.SIZES:
		var side: int = studs
		var made: Command = _add("floor_%d" % side, "Baseplate %d × %d" % [side, side], 0,
			func() -> void:
				var chosen: ModelFloor = store.model_floor.copy()
				chosen.kind = ModelFloor.BASEPLATE
				chosen.across = side
				chosen.deep = side
				app.call("choose_floor", chosen), Callable(),
			"Stand the model on a %d by %d baseplate" % [side, side])
		made.ticked = func() -> bool:
			return store.model_floor.is_plate() and store.model_floor.across == side \
				and store.model_floor.deep == side
		made.radio = true
	var custom: Command = _add("floor_custom", "Baseplate, other size…", 0, _ask_floor_size,
		Callable(), "A baseplate of any size in eights of studs, cut from the ones the LEGO Group sells")
	custom.ticked = func() -> bool:
		return store.model_floor.is_plate() and not (store.model_floor.across == store.model_floor.deep
			and ModelFloor.SIZES.has(store.model_floor.across))
	custom.radio = true
	for kind: Array in [[ModelFloor.GRID, "Grid floor",
			"No baseplate: a faint ground with a line between the studs, as Studio has"],
			[ModelFloor.NONE, "No floor",
			"Nothing under the model, as a car or a ship stands on a table"]]:
		var which: String = kind[0]
		var made: Command = _add("floor_" + which, str(kind[1]), 0, func() -> void:
			var chosen: ModelFloor = store.model_floor.copy()
			chosen.kind = which
			app.call("choose_floor", chosen), Callable(), str(kind[2]))
		made.ticked = func() -> bool: return store.model_floor.kind == which
		made.radio = true
	for pair: Array in ModelFloor.COLOURS:
		var code: int = pair[0]
		var made: Command = _add("floor_colour_%d" % code, str(pair[1]), 0, func() -> void:
			var chosen: ModelFloor = store.model_floor.copy()
			chosen.colour = code
			app.call("choose_floor", chosen), plate)
		made.ticked = func() -> bool:
			return store.model_floor.is_plate() and store.model_floor.colour == code
		made.radio = true
	_add("floor_part", "The baseplate is part of the model", 0, func() -> void:
		app.call("floor_part_of_model", not floor_layer.has_own_plate()),
		func() -> bool: return store.model_floor.is_plate() or floor_layer.has_own_plate(),
		"Counted in the parts list and the shop lists, saved with the model and the first step of the booklet")
	_ticked("floor_part", floor_layer.has_own_plate)
	_add("floor_default", "Start new models on this floor", 0, func() -> void:
		ModelFloor.prefer(store.model_floor)
		bar.say("New models start on %s." % store.model_floor.words().to_lower()),
		Callable(), "What New, and a model opened from a file that does not say, stand on")
	_ticked("floor_default", func() -> bool:
		return store.model_floor.same_as(ModelFloor.preferred()))


var _floor_size: ConfirmationDialog
var _floor_wide: SpinBox
var _floor_deep: SpinBox


## View, Floor, Baseplate, other size: across and deep, in studs.
func _ask_floor_size() -> void:
	if _floor_size == null:
		_floor_size = ConfirmationDialog.new()
		_floor_size.title = "Baseplate size"
		_floor_size.ok_button_text = "Use it"
		var asking := VBoxContainer.new()
		var words := Label.new()
		words.text = "How big, in studs? Baseplates are cut in eights."
		asking.add_child(words)
		var row := HBoxContainer.new()
		asking.add_child(row)
		_floor_wide = SpinBox.new()
		_floor_deep = SpinBox.new()
		for spin: SpinBox in [_floor_wide, _floor_deep]:
			spin.min_value = ModelFloor.LEAST
			spin.max_value = ModelFloor.MOST
			spin.step = 8
			spin.custom_minimum_size = Vector2(90, 0)
		row.add_child(_floor_wide)
		var by := Label.new()
		by.text = " × "
		row.add_child(by)
		row.add_child(_floor_deep)
		_floor_size.add_child(asking)
		_floor_size.confirmed.connect(func() -> void:
			var chosen: ModelFloor = store.model_floor.copy()
			chosen.kind = ModelFloor.BASEPLATE
			chosen.across = int(_floor_wide.value)
			chosen.deep = int(_floor_deep.value)
			app.call("choose_floor", chosen))
		add_child(_floor_size)
	_floor_wide.value = store.model_floor.across
	_floor_deep.value = store.model_floor.deep
	_floor_size.popup_centered()


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
		KEY_K:
			if not held:
				return run("cut_flip" if key.shift_pressed else "cut")
			# Ctrl+K: ask Claude about the selection, the key other editors
			# give asking AI about what is selected.
			if not key.shift_pressed:
				return run("ask_claude")
		KEY_I:
			# Straight to it rather than through the command, which is
			# greyed with nothing selected: the key says what to select.
			if not held and not key.shift_pressed:
				see_inside.set_xray(not see_inside.seeing_through)
				return true
		KEY_F2:
			if can("rename_assembly"):
				run("rename_assembly")
				return true
		KEY_ENTER, KEY_KP_ENTER:
			if can("enter_assembly") and not held:
				run("enter_assembly")
				return true
		# Shift with the colour keys, as Studio's step keys: with nothing
		# selected [ and ] still change the colour in hand. A browser names
		# the key by what Shift makes of it, { and }.
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_BRACELEFT, KEY_BRACERIGHT:
			if key.shift_pressed and not held and can("step_prev"):
				return run("step_prev" if key.keycode in [KEY_BRACKETLEFT, KEY_BRACELEFT]
					else "step_next")
		KEY_N:
			if key.shift_pressed and not held and can("step_new"):
				return run("step_new")
	return false


## A step edit: the selection moved a step or into a new one, or the step
## the timeline is on moved, merged or taken out. One undo, and the first
## edit of a model with no steps of its own gives it the worked-out ones
## first, in the same undo (AuthorSteps.ensure).
func edit_steps(op: String) -> void:
	# The bar's buttons come here without asking can(): a model shared to
	# look at is not to be changed, and the selection's edits need one.
	if read_only:
		return
	var steps: StepsBar = app.get("_steps")
	bar.say(change_steps(op, Array(builder.selection.keys()), steps.current_step()))


## The same edit for [param ids], or the step [param at]: what the
## selection and the timeline give, or what a session over MCP names by
## number (AppTools). Returns what was done, or why nothing was.
func change_steps(op: String, ids: Array, at: Instructions.Step) -> String:
	if read_only:
		return "this model is open to look at, not to change"
	if op in ["prev", "next", "new"] and ids.is_empty():
		return "select the parts first"
	if not op in ["prev", "next", "new"] and at == null:
		return "go to a step on the timeline first"
	var steps: StepsBar = app.get("_steps")
	var number: int = at.number if at != null else -1
	var skip: Dictionary = store.scenery
	var undo: Array = AuthorSteps.ensure(world, library, skip)
	var where: Array = _step_at(at)
	var level: String = assemblies.entered if assemblies != null else ""
	var count: int = ids.size()
	var words: String = ""
	match op:
		"prev", "next":
			undo.append_array(AuthorSteps.move(world, ids, -1 if op == "prev" else 1, level, skip))
			words = "moved %s to the %s step" % [_parts(count), "previous" if op == "prev" else "next"]
		"new":
			undo.append_array(AuthorSteps.new_step(world, ids, level, str(where[0]),
				int(where[1]), skip))
			words = "made a new step of %s" % _parts(count)
			number += 1
		"earlier", "later":
			if int(where[1]) >= 0:
				undo.append_array(AuthorSteps.swap(world, str(where[0]), int(where[1]),
					-1 if op == "earlier" else 1, skip))
			words = "put step %d %s" % [number, "earlier" if op == "earlier" else "later"]
			number += -1 if op == "earlier" else 1
		"merge":
			if int(where[1]) >= 0:
				undo.append_array(AuthorSteps.merge(world, str(where[0]), int(where[1]), skip))
			words = "merged step %d with the next" % number
		"delete":
			if int(where[1]) >= 0:
				undo.append_array(AuthorSteps.remove(world, str(where[0]), int(where[1]), skip))
			words = "took out step %d; its parts are in the step %s" % [number,
				"before" if int(where[1]) > 0 else "after"]
			number = maxi(number - 1, 1)
	undo = AuthorSteps.squash(undo)
	if undo.is_empty():
		return "the steps are as they were"
	builder.record(undo, words)
	# Saved with the model, as any edit is (not _on_model_edited, which
	# would work the timeline out a second time).
	store.adopt()
	store.touch()
	steps.refresh(number)
	return words


static func _parts(count: int) -> String:
	return "1 part" if count == 1 else "%d parts" % count


## Where the timeline's step is among the author's: [section, step], or
## ["", -1]. Read off its first part when it was a worked-out step, which
## giving the model its steps has just made one of the author's.
func _step_at(at: Instructions.Step) -> Array:
	if at == null:
		return ["", -1]
	if at.authored_step >= 0:
		return [at.authored_in, at.authored_step]
	var ids: PackedInt64Array = at.brick_ids if not at.brick_ids.is_empty() \
		else (at.copies[0] if not at.copies.is_empty() else PackedInt64Array())
	if ids.is_empty():
		return ["", -1]
	var brick: BrickWorld.Brick = world.get_brick(ids[0])
	if brick == null or brick.step < 0:
		return ["", -1]
	# A step that puts a sub-assembly on is a step of the model, where the
	# copy goes on.
	if at.attaches() and at.brick_ids.is_empty():
		var top: String = Assemblies.segments(Assemblies.path_of(brick))[0]
		return ["", int(world.unit_steps.get(top, 0))]
	return [Assemblies.path_of(brick), brick.step]


## Whether a point is over the shell's own panels rather than the model.
func covers(point: Vector2) -> bool:
	for panel: Control in [toolbar, inspector, status, outliner, banner, see_inside.bar]:
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
	if collection != null:
		out.merge(collection.controls_by_name())
	var parts_list: Variant = app.get("_inventory") if app != null else null
	if parts_list is InventoryPanel:
		out.merge((parts_list as InventoryPanel).controls_by_name())
	if see_inside != null:
		out.merge(see_inside.controls_by_name())
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
