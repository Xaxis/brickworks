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
## Sections suggested, broken out, exploded and evaluated: src/ui/sections_ui.gd.
var sections: SectionsUi
var grid: StudGrid
## Build your first model, along the top of the model: src/ui/first_build.gd.
var first_build: FirstBuild
## My collection: src/ui/collection_dialog.gd.
var collection: CollectionDialog
## File, Library…: src/ui/library_dialog.gd.
var library_dialog: LibraryDialog
## The cut-away and x-ray: src/ui/see_inside.gd.
var see_inside: SeeInside
## View, Stress: src/ui/stress_view.gd.
var stress: StressView
## File, Versions…: src/ui/versions_dialog.gd.
var versions: VersionsDialog
## Compare with a save, from Versions… or File, Compare with…:
## src/ui/compare_view.gd.
var compare: CompareView
## Edit, Pattern…: copies in a row, round, or along a hose (Pattern).
var pattern_dialog: PatternDialog
## Help, Send feedback… (FeedbackDialog).
var feedback: FeedbackDialog
## Find a command (Ctrl+/): src/ui/command_palette.gd.
var palette: CommandPalette
## The model's part of the window, which the palette opens over.
var model_area: Control

## name -> Command
var _commands: Dictionary = {}
## Menu ids are indexes into this.
var _ids: Array[String] = []
var _menus: Array[MenuButton] = []
var _save_as: ConfirmationDialog
var _save_as_name: LineEdit
var _about: AcceptDialog
## About's words, beside the mark.
var _about_text: Label
## Its trademark notice, under the credits.
var _about_marks: Label
## Its words, credits and notice, scrolled where the window is short.
var _about_scroll: ScrollContainer
## A licence in full, opened from About, and its words.
var _licence: AcceptDialog
var _licence_text: TextEdit


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
	## Its tooltip, any {command} in it named by its key now (Keymap.filled).
	var tip: String = "":
		get: return Keymap.filled(tip, true)
	## What it waits for while it cannot be used ([method Shell.why_not]).
	var needs: String = ""


const CTRL := KEY_MASK_CMD_OR_CTRL
const SHIFT := KEY_MASK_SHIFT
const ALT := KEY_MASK_ALT

## The menus, in order. "-" is a line between groups; ">name" a submenu.
##
## Each command has one home, as in Studio's menus (appux371 A7): the
## sub-assembly and step commands were in Edit and in Build, Exploded view
## in View and in Build, and Edit was 39 rows, 689 px of a 720 px window.
## Edit keeps the clipboard, the selection, hiding, locking, paint and
## replace; Build the steps, the sub-assemblies and the sections; Make what
## makes something new (a minifigure, a mosaic, a brickified model, a hose,
## a part, a print) and the picture one is built over; Tools the tools, the
## checks and what asks Claude. Find
## a command (CommandPalette) reaches any of them by name.
##
## No menu is more than 25 rows, nor opens taller than 60% of a 720 px
## window, about 20 rows and their lines (keys3): Build grew back to 37 rows
## and scrolled, View was 33, and Edit, with Comments, 25 rows and 486 of a
## 470 unit limit. So the makers and the prints went to Make, the eight
## views and the model's turns to View's Viewpoint, the part in hand's turn
## and tip to Tools beside Place, Comments to File beside Share and Build
## together, My collection and What can I build? beside Library, and What
## do I need? beside the parts list.
const MENUS: Array = [
	["File", ["new", "new_window", "open", "library", "collection", "collection_build", ">recent",
		">import", "-", "save", "save_as", "versions", "compare", "-", "share", "together",
		"comments", ">export", "render", "-", "clear", "quit"]],
	["Edit", ["undo", "redo", ">history", "-", "cut_parts", "copy", "paste", "duplicate",
		"pattern", "delete", "-", "select_all", "select_none", ">select_by", "-", "hide",
		"isolate", "show_all", "lock", "unlock", "-", "paint", "replace", "mirror"]],
	["View", [">viewpoint", "mode_orbit", "mode_pan", "mode_zoom",
		"fit", "fit_model", "fit_selection",
		"ortho", "grid", ">floor", "-", "cut", ">cut_away", "xray", "stress", "-", "panel_parts",
		"panel_assistant", "panel_properties", "panel_outliner", "panel_keys", "-",
		"split_view", "full_screen"]],
	["Build", ["timeline", "step_close", ">steps", "pose", "instructions", ">booklet", "parts_list",
		"collection_need", "-", "make_submodel", "leave_submodel", "enter_assembly",
		"leave_assembly", "rename_assembly", "make_unique", "-", "suggest_sections",
		"evaluate_section", "break_out", "put_back", "explode"]],
	["Make", ["minifig", "mosaic", "brickify", "reference", "-", "flex", "reshape_flex", "-",
		"part_maker", "print_part", "sticker", "printed_versions"]],
	["Tools", ["mode_select", "mode_place", "mode_move", "mode_rotate", "mode_hinge",
		"mode_connect", "mode_clone", "mode_paint", "mode_hide", "mode_delete", "-", "rotate_held",
		"tip_held", "-", "measure", "stability", "simulate", "hidden_colours", "reseat", "-",
		"ask_claude", "connector", "settings"]],
	["Help", ["keys", "tour"]],
]

## The app's own menu, opened from the mark at the far left of the menu
## bar (ModelBar.mark), as Blender's logo and Figma's main menu open
## theirs: the app and a word to the people who make it, finding any
## command, its website and docs (and a tester's Beta hub), your account,
## and in a browser the way back to the site.
const APP_MENU: Array = ["about", "feedback", "-", "palette", "-", "website", "docs", "beta_hub",
	"-", "account", "-", "back_to_site"]

## Commands for a browser alone, in no menu elsewhere.
const WEB_ONLY: Array[String] = ["back_to_site"]

## Submenu rows are numbered from here, clear of the commands.
const SUBMENU_ID := 10000

## The assistant's commands: in no menu, and never run, while it is off
## (Settings, Assistant (AI): ShellPrefs.assistant_shown).
const ASSISTANT_COMMANDS: Array[String] = ["ask_claude", "brace", "panel_assistant", "connector"]

## Whether the assistant is in the window: [method set_assistant].
var assistant_shown: bool = true

## Early features' commands, each by the key that turns it on (api/_early.js
## EARLY): in no menu, and never run, unless the account may use it, a beta
## tester's ([method set_early]).
const EARLY_COMMANDS: Dictionary = {"beta_hub": "beta_hub"}

## The early features this account may use, as the deployment said
## (Account.early).
var early: Array[String] = []

const SUBMENUS: Dictionary = {
	"import": ["import_ldraw", "import_io", "import_lxf", "import_mesh"],
	"export": ["export_ldraw", "export_io", "export_3d", "export_picture", "export_bricklink",
		"export_rebrickable", "-", "export_all"],
	"select_by": ["select_colour", "select_part", "select_alike", "select_find",
		"select_connected", "select_submodel", "select_inverse"],
	"viewpoint": ["view_default", "view_front", "view_back", "view_left", "view_right",
		"view_top", "view_bottom", "view_iso", "-", "turn_left", "turn_right"],
	"cut_away": ["cut_x", "cut_y", "cut_z", "-", "cut_flip", "cut_ghosts"],
	# Next step (E) is in Build itself, over these.
	"steps": ["step_prev", "step_next", "step_to", "step_new", "-", "step_earlier", "step_later",
		"step_merge", "step_delete"],
	"booklet": ["booklet_turn_left", "booklet_turn_right", "booklet_tilt_up",
		"booklet_tilt_down", "booklet_this_view", "booklet_usual_view", "-", "booklet_zoom_in",
		"booklet_zoom_out", "booklet_bigger", "booklet_smaller", "-", "booklet_new_page",
		"booklet_alone", "booklet_parts", "booklet_callout", "booklet_per_page", "-",
		"booklet_lay_out", "booklet_highlight"],
	"floor": ["floor_16", "floor_32", "floor_48", "floor_custom", ">floor_colour", "-",
		"floor_grid", "floor_none", "-", "floor_part", "floor_default"],
	"floor_colour": ["floor_colour_2", "floor_colour_10", "floor_colour_288",
		"floor_colour_19", "floor_colour_28", "floor_colour_71", "floor_colour_72",
		"floor_colour_378", "floor_colour_1", "floor_colour_15", "floor_colour_0",
		"floor_colour_7"],
}

## A submenu's own words, as its row in the menu above says them.
const SUBMENU_WORDS: Dictionary = {"recent": "Open recent", "import": "Import",
	"export": "Export", "history": "History", "select_by": "Select by",
	"viewpoint": "Viewpoint", "cut_away": "Cut along",
	"steps": "Build steps", "booklet": "Booklet page", "floor": "Floor",
	"floor_colour": "Baseplate colour"}


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
	stress = StressView.new()
	stress.world = world
	stress.library = library
	stress.scenery = store.scenery
	stress.say = bar.say
	stress.panel = StressPanel.new()
	stress.panel.view = stress
	add_child(stress)
	# Sections: suggested, broken out, exploded, evaluated (src/assembly/sections.gd).
	sections = SectionsUi.new()
	sections.shell = self
	sections.sections = Sections.new()
	sections.sections.world = world
	sections.sections.library = library
	sections.sections.builder = builder
	sections.sections.assemblies = assemblies
	sections.sections.scenery = store.scenery
	add_child(sections)
	verbs.drawn_pick = sections.pick_drawn
	# A suggestion is of the model it was made for.
	for replaced: Signal in [bar.started_new, bar.cleared]:
		replaced.connect(func() -> void: sections.sections.dismiss())
	bar.opened.connect(func(_n: int) -> void: sections.sections.dismiss())
	_define()

	for menu: Array in MENUS:
		_menus.append(_menu(str(menu[0]), menu[1]))
	for button: MenuButton in _menus:
		bar.menus.add_child(button)
	var app_menu: PopupMenu = bar.mark.get_popup()
	_fill(app_menu, APP_MENU)
	app_menu.id_pressed.connect(_on_id)
	app_menu.about_to_popup.connect(func() -> void: _refresh(app_menu))
	var holds: String = ("About, feedback, finding a command, the website, the docs and your "
		+ "account") + (", and back to brickworks.diy" if OS.has_feature("web") else "")
	bar.mark.tooltip_text = "Brickworks\n" + holds
	bar.mark.accessibility_description = holds

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
	outliner.sections = sections
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
	# View, Stress's legend, count and weakest joints: Main puts it in the
	# column beside the model, with the tools' panels.

	grid = StudGrid.new()
	grid.world = world
	grid.library = library
	grid.scenery = store.scenery
	grid.floor_layer = app.get("_floor")
	app.add_child(grid)

	# Offered once on a first visit, and from Help, Take the tour: in the
	# strip along the top of the model, never over it.
	first_build = FirstBuild.new()
	first_build.shell = self
	notices.add_child(first_build)

	# What the person owns, what this model needs of it, what they could
	# build: src/ui/collection_dialog.gd. The parts list leads there too.
	collection = CollectionDialog.new()
	collection.said.connect(func(text: String) -> void: bar.say(text))
	collection.attach(app)
	var parts_list: Variant = app.get("_inventory")
	if parts_list is InventoryPanel:
		(parts_list as InventoryPanel).need_wanted.connect(func() -> void: collection.open("need"))

	# Any of LDraw's models of real sets, or the community's, opened in a
	# tab of its own: src/ui/library_dialog.gd. File, Open leads there too.
	library_dialog = LibraryDialog.new()
	library_dialog.said.connect(func(text: String) -> void: bar.say(text))
	library_dialog.attach(app)
	bar.library_wanted.connect(func() -> void: library_dialog.open())

	# Every text field gives the keys back, and Tab goes into the frame
	# from the model: src/ui/focus_guard.gd.
	var guard := FocusGuard.new()
	guard.interface_top = column
	add_child(guard)
	# And names for the parts of Godot's own dialogs it leaves unnamed.
	add_child(Access.new())

	_save_as = ConfirmationDialog.new()
	_save_as.title = "Save as"
	_save_as.ok_button_text = "Save"
	var asking := VBoxContainer.new()
	var words := Label.new()
	words.text = "What should this copy of the model be called?"
	asking.add_child(words)
	_save_as_name = LineEdit.new()
	_save_as_name.accessibility_name = "Name of the copy"
	_save_as_name.custom_minimum_size = Vector2(320, 0)
	_save_as_name.text_submitted.connect(func(_text: String) -> void:
		_save_as.hide()
		attend("save", _save_named.bind(_save_as_name.text)))
	asking.add_child(_save_as_name)
	_save_as.add_child(asking)
	_save_as.confirmed.connect(func() -> void:
		attend("save", _save_named.bind(_save_as_name.text)))
	add_child(_save_as)

	versions = VersionsDialog.new()
	versions.store = store
	versions.bar = bar
	add_child(versions)
	# Compare with a save: its panel where View, Stress's is, the two never
	# open at once (_define's stress).
	compare = CompareView.new()
	compare.world = world
	compare.library = library
	compare.store = store
	compare.camera = camera
	compare.assemblies = assemblies
	compare.stress = stress
	compare.say = bar.say
	compare.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	compare.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	compare.offset_right = -14.0
	compare.offset_left = -14.0 - CompareView.WIDE
	compare.offset_top = ViewCube.size_for().y + 26.0
	over_model.add_child(compare)
	versions.compare = func(version: ModelVersions.Version) -> void: compare.open_with(version)
	# A save is of the model it was made of.
	for replaced: Signal in [bar.started_new, bar.cleared]:
		replaced.connect(func() -> void: compare.close(false))
	bar.opened.connect(func(_n: int) -> void: compare.close(false))

	pattern_dialog = PatternDialog.new()
	pattern_dialog.builder = builder
	pattern_dialog.world = world
	pattern_dialog.library = library
	pattern_dialog.say = bar.say
	pattern_dialog.edited = func() -> void: verbs.edited.call()
	pattern_dialog.pattern.builder = builder
	pattern_dialog.pattern.world = world
	pattern_dialog.pattern.library = library
	# Its copies are drawn in the model's world, not the dialog's window.
	add_child(pattern_dialog.pattern)
	add_child(pattern_dialog)

	feedback = FeedbackDialog.new()
	feedback.store = store
	feedback.world = world
	feedback.library = library
	add_child(feedback)
	model_area = over_model
	palette = CommandPalette.new()
	palette.shell = self
	add_child(palette)

	_about = AcceptDialog.new()
	_about.title = "About Brickworks"
	# The mark beside the words, as an About box has it: the app's own icon
	# (assets/icon.png, drawn from web/icon.svg by tools/web/make_icons.mjs).
	var about_row := HBoxContainer.new()
	about_row.add_theme_constant_override("separation", 18)
	var mark := TextureRect.new()
	mark.name = "mark"
	mark.texture = load("res://assets/icon.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(72, 72)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	about_row.add_child(mark)
	# The words, whose work is in Brickworks and on what terms (Credits),
	# and the trademark notice, scrolled: OK stays on a short window's
	# screen and a phone's.
	_about_scroll = ScrollContainer.new()
	_about_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_about_scroll.follow_focus = true
	_about_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about_row.add_child(_about_scroll)
	var about_column := VBoxContainer.new()
	about_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about_column.add_theme_constant_override("separation", 14)
	_about_scroll.add_child(about_column)
	_about_text = Label.new()
	_about_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about_text.custom_minimum_size = Vector2(380, 0)
	_about_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about_column.add_child(_about_text)
	about_column.add_child(_credits())
	_about_marks = Label.new()
	_about_marks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about_marks.add_theme_font_size_override("font_size", 12)
	_about_marks.modulate = Color(1, 1, 1, 0.75)
	about_column.add_child(_about_marks)
	_about.add_child(about_row)
	add_child(_about)

	# The layout as it was left. Which columns show is the window's to
	# say as well as the person's: Main._fit_panels.
	verbs.set_snap(str(ShellPrefs.value("snap")), false)
	verbs.turn_step = float(ShellPrefs.value("turn_step"))
	set_key_strip(bool(ShellPrefs.value("key_strip")))
	grid.visible = bool(ShellPrefs.value("grid"))
	inspector.set_open(bool(ShellPrefs.value("inspector_open")))
	outliner.set_open(bool(ShellPrefs.value("outliner_open")))


## A section of a side column, from the View menu or the toolbar: with its
## column folded, the column opens with it open (a narrow window folds the
## other side to make room); else it folds or opens.
func _toggle_section(section: Control) -> void:
	var dock: SideDock = SideDock.of(section)
	if not dock.is_open():
		section.call("set_open", true)
		dock.set_open(true)
		return
	section.call("set_open", not bool(section.call("is_open")))


func _section_shown(section: Control) -> bool:
	return SideDock.of(section).is_open() and bool(section.call("is_open"))


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
	Keymap.learn(name, words, accel)
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
	attend(name, func() -> void:
		# Asked again: put off a frame, it may not be any more.
		if can(name):
			await found.run.call())
	return true


## What a key the keymap gives runs where no handler answers it
## (Main._key_action): a colour key (ColourKeys), Studio's Shift-V
## ([method cycle_select]), or a command as its menu runs it, and why not
## said when it cannot be: Alt-C with nothing selected says to select a
## part first, where it said nothing.
func run_key(action: String) -> void:
	if ColourKeys.owns(action):
		ColourKeys.press(action, self)
	elif action == "select_cycle":
		await cycle_select()
	elif not run(action) and _commands.has(action):
		var why: String = why_not(action)
		if not why.is_empty():
			bar.say(why[0].to_lower() + why.substr(1))


## Studio's Cycle Select Mode (Shift-V under its keys): from the parts
## selected, each press selects the same colour, the same part, the same
## part and colour, and everything joined to them, then the parts it began
## from again. A selection made any other way starts it again from there.
const CYCLE: Array = [["colour", "the same colour"], ["part", "the same part"],
	["alike", "the same part and colour"], ["connected", "everything joined"]]
var _cycle_from: Array = []
var _cycle_left: Dictionary = {}
var _cycle_at: int = -1


func cycle_select() -> void:
	if read_only:
		return
	if builder.selection != _cycle_left or _cycle_from.is_empty():
		_cycle_from = builder.selection.keys()
		_cycle_at = -1
	_cycle_from = _cycle_from.filter(func(id: int) -> bool: return world.get_brick(id) != null)
	if _cycle_from.is_empty():
		bar.say("select a part first: then each press selects its colour, its part, both, "
			+ "or all joined to it")
		return
	_cycle_at = (_cycle_at + 1) % (CYCLE.size() + 1)
	verbs.select_found(_cycle_from)
	var words: String = "the parts it began from"
	if _cycle_at < CYCLE.size():
		var way: String = CYCLE[_cycle_at][0]
		if way == "connected":
			await verbs.select_connected()
		else:
			verbs.select_by(way)
		words = CYCLE[_cycle_at][1]
	_cycle_left = builder.selection.duplicate()
	bar.say("%s: %s selected" % [words, Counted.of(builder.selection.size(), "part")])


## Do [param work] as command [param name]: said first when it is slow,
## timed, and its words on the bar for as long as it goes on (Working.attend).
## The menus, the toolbar, the keys and the dialogs' buttons all come here.
## [param work] is awaited to its end, so a command awaits the coroutines
## it sets going: one called without await goes on unseen and untimed.
func attend(name: String, work: Callable) -> void:
	var size: int = work_size(name)
	var slow: bool = size >= int(SLOW_FROM.get(name,
		FLOOR_SLOW_FROM if name.begins_with("floor_") else 1 << 30))
	# A step edit is slow the first time, when the model is given the
	# worked-out steps (AuthorSteps.ensure); once it has steps of its own,
	# only on a big model: 22 to 50 ms at a thousand parts, and 1.4 to 2.6 s
	# on the Wizard's Tower's 10,105, taken for quick and never said once it
	# had its own (9d7c5ba3, command_probe).
	if name.begins_with("step_") and world != null and AuthorSteps.any(world, store.scenery):
		slow = size >= STEPPED_SLOW_FROM
	var asks: bool = name in ASKS_WHERE and SaveTo.asks()
	# A browser opens a page a tab only while it still answers the tap that
	# asked: said first, Instructions waited for its busy line to be drawn,
	# and on a slow phone the tap's leave to open the booklet's tab had gone.
	var tab: bool = name in OPENS_A_TAB and OS.has_feature("web")
	Working.attend(name, doing(name), work, name in IN_THE_PRESS or asks or tab, slow, size)


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
const ON_THE_SELECTION: Array[String] = ["mirror", "replace", "duplicate", "pattern", "paint",
	"split_parts", "merge_parts",
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
	"import_mesh", "mosaic", "brickify", "full_screen", "docs", "website", "beta_hub", "quit", "new_window"]

## The commands that open a tab of their own in a browser (BookletMaker):
## run at once there, as those above are.
const OPENS_A_TAB: Array[String] = ["instructions"]

## The commands that on the desktop ask where their file goes (SaveTo)
## before any slow work: run at once like those above, never said first,
## so no "Exporting…" bar sits under the dialog while the person chooses.
## The shop lists are counted before they ask, and are said first as ever.
const ASKS_WHERE: Array[String] = ["save_as", "export_ldraw", "export_io", "export_picture",
	"export_all", "instructions"]

## Laying a floor again under a big model: its plates cover more ground.
const FLOOR_SLOW_FROM := 3000
## A step edit on a model with steps of its own (attend).
const STEPPED_SLOW_FROM := 2000

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
	"mirror": 200, "replace": 200, "duplicate": 300, "pattern": 300, "paste": 300,
	"split_parts": 300, "merge_parts": 300,
	"cut_parts": 600,
	"paint": 600, "hide": 3000, "isolate": 3000, "leave_submodel": 2000,
	"make_unique": 2000,
	"step_close": 300, "step_new": 300, "step_prev": 300, "step_next": 300, "step_earlier": 300,
	"step_later": 300, "step_merge": 300, "step_delete": 300, "step_to": 300,
	"turn_left": 300, "turn_right": 300, "collection_build": 0,
	# What do I need? reads the collection and lays its list out whatever the
	# model's size, and the minifigure builder fills its picker every time it
	# opens: on the example car on a loaded machine, 385 ms and 415 ms, and
	# unsaid the first time (command_probe).
	"collection_need": 0, "minifig": 0,
	# Everything connected walks the model from the part: 464 ms on the
	# 536-part station, unsaid on a device that had not timed it before.
	"stability": 300, "select_connected": 300, "select_all": 2000, "select_colour": 2000, "select_part": 2000,
	"select_alike": 2000, "select_inverse": 2000, "parts_list": 2000, "select_find": 2000,
	"reseat": 2000,
	"export_bricklink": 3000, "export_rebrickable": 3000, "pose": 3000,
	# New first asks whether the model on the baseplate is saved as it is.
	"new": 2000,
	# And the rest command_probe found holding a frame a fifth of a second or
	# more on Orthanc unsaid (2026-10-15, under load): its versions asked
	# whether the model is saved as it is (450 ms), the cut-away along an axis
	# (599), a sub-assembly made or the same sub-model selected of all of it
	# (620, 295), a copy of all of it (289), the controls panel over it (343,
	# and 247 by its keys), Print on a part (228), the tour (212) and its
	# picture (250).
	"versions": 2000, "cut": 3000, "cut_x": 3000, "cut_y": 3000, "cut_z": 3000,
	"make_submodel": 2000, "select_submodel": 2000, "copy": 2000, "settings": 3000,
	"keys": 3000, "print_part": 3000, "tour": 3000, "export_picture": 3000,
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
	"render": "Opening Render…", "pose": "Opening Motions…",
	"instructions": "Making the instructions…", "share": "Opening Share…",
	"undo": "Undoing…", "redo": "Redoing…", "history": "Going back…",
	"cut_parts": "Cutting…", "copy": "Copying…", "paste": "Pasting…",
	"duplicate": "Duplicating…", "delete": "Deleting…",
	"select_all": "Selecting everything…", "select_none": "Selecting nothing…",
	"select_colour": "Selecting the same colour…", "select_part": "Selecting the same part…",
	"select_alike": "Selecting the same part and colour…",
	"select_find": "Listing the parts…",
	"select_connected": "Selecting everything connected…",
	"select_submodel": "Selecting the sub-model…", "select_inverse": "Selecting the opposite…",
	"hide": "Hiding…", "isolate": "Showing only the selection…", "show_all": "Showing everything…",
	"lock": "Locking…", "unlock": "Unlocking…", "paint": "Painting…",
	"replace": "Replacing…", "mirror": "Mirroring…",
	"split_parts": "Splitting…", "merge_parts": "Merging…",
	"make_submodel": "Making a sub-assembly…", "leave_submodel": "Ungrouping…",
	"make_unique": "Making the copy unique…",
	"timeline": "Opening the timeline…", "parts_list": "Listing the parts…",
	"collection": "Opening My collection…", "collection_need": "Working out what you need…",
	"minifig": "Opening the minifigure builder…", "versions": "Opening the versions…",
	"cut_x": "Cutting away…", "cut_y": "Cutting away…", "cut_z": "Cutting away…",
	"settings": "Opening Settings…", "keys": "Opening the keys and controls…",
	"print_part": "Opening Print on a part…", "tour": "Starting the tour…",
	"collection_build": "Working out what you can build…",
	"fit": "Fitting the view…", "fit_model": "Fitting the model…",
	"turn_left": "Turning the model…", "turn_right": "Turning the model…",
	"stability": "Checking stability…", "reseat": "Seating parts on their studs…",
	"simulate": "Reading the mechanism…",
	"cut": "Cutting away…", "xray": "Seeing through…", "grid": "Laying the stud grid…",
	"stress": "Weighing every joint…",
	"step_close": "Making a step…", "step_new": "Making a step…",
	"step_earlier": "Moving the step…",
	"step_later": "Moving the step…", "step_merge": "Merging the steps…",
	"step_delete": "Taking out the step…", "step_to": "Reading the steps…",
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
	# A model being laid over frames is not the model yet: the view of it
	# turns, and nothing reads it or changes it until it is all down.
	if store != null and store.laying and not name in WHILE_LAYING:
		return false
	if not assistant_shown and name in ASSISTANT_COMMANDS:
		return false
	if EARLY_COMMANDS.has(name) and not str(EARLY_COMMANDS[name]) in early:
		return false
	return not found.can.is_valid() or bool(found.can.call())


## Why a command cannot be used now, in a few words: "Select a part
## first". "" when it can. Find a command shows it beside a greyed row
## rather than leave the row out.
func why_not(name: String) -> String:
	var found: Command = _commands.get(name)
	if found == null:
		return "No such command"
	if read_only and not name in LOOKING:
		return "This model is shared to look at"
	if store != null and store.laying and not name in WHILE_LAYING:
		return "The model is still opening"
	if not assistant_shown and name in ASSISTANT_COMMANDS:
		return "The assistant is off in Settings"
	if not found.can.is_valid() or bool(found.can.call()):
		return ""
	return found.needs if not found.needs.is_empty() else "Not now"


## What a command waits for, where its own test does not say
## (_define gives those that wait on a selection or a model theirs).
const NEEDS: Dictionary = {
	"undo": "Nothing to undo yet", "redo": "Nothing to redo",
	"quit": "Close the browser's tab instead",
	"export_all": "No model saved here yet",
	"show_all": "Nothing is hidden", "unlock": "Nothing is locked",
	"printed_versions": "Select a part that was printed",
	"brace": "Select a part View › Stress shows weak",
	"swing": "Select a part on a hinge, clip or turntable",
	"enter_assembly": "Select a sub-assembly first", "rename_assembly": "Select a sub-assembly first",
	"leave_assembly": "Not editing inside a sub-assembly",
	"make_unique": "Select a copy of a sub-assembly",
	"evaluate_section": "Select a section first", "break_out": "Select a section first",
	"put_back": "No section is broken out",
	"xray": "Select a part first", "cut_flip": "Turn on Cut away first",
	"stress": "Put a part on the baseplate first",
	"split_view": "The window is too small for two views",
	"compare": "Save the model first: each save is kept to compare with",
	"reshape_flex": "Select a hose or chain",
	"floor_part": "Stand the model on a baseplate first",
	"back_to_site": "In a browser only",
}


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
	"docs", "website", "beta_hub", "feedback", "about", "back_to_site", "palette"]


## What may be done while a model is being laid (ModelStore.laying): look
## at what is down from another side, and nothing that reads the model.
const WHILE_LAYING: Array[String] = ["view_default", "view_front", "view_back",
	"view_left", "view_right", "view_top", "view_bottom", "view_iso", "fit",
	"ortho", "full_screen", "docs", "website", "beta_hub", "feedback", "about", "back_to_site",
	"palette"]


## -1 for a command that is not a setting; 0 off, 1 on.
func ticked(name: String) -> int:
	var found: Command = _commands.get(name)
	if found == null or not found.ticked.is_valid():
		return -1
	return 1 if bool(found.ticked.call()) else 0


## What a command's key reads as, for a tooltip: "Ctrl+Z". The key the
## person's keymap gives it (Keymap), which is the menus' own until a
## preset or the keys sheet says another.
func key_words(name: String) -> String:
	if not _commands.has(name):
		return ""
	return Keymap.written(name)


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
const SHOWN_AS: Dictionary = {KEY_QUOTELEFT: 0x201B, KEY_COMMA: 0x201A, KEY_SLASH: 0x2215}


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
	# src/parts/tab_session.gd. Ctrl+Shift+N is the browser's own there.
	var web: bool = OS.has_feature("web")
	_add("new_window", "New tab" if web else "New window", 0 if web else CTRL | SHIFT | KEY_N,
		TabSession.open_another, Callable(),
		"Start a new model in a %s of its own" % ("tab" if web else "window"))
	_add("open", "Open…", CTRL | KEY_O, bar._on_open, Callable(),
		"Reopen a saved model, an example, or a file from this computer")
	_add("library", "Library…", 0, func() -> void: library_dialog.open(), Callable(),
		"Any of LDraw's models of real sets, or a model the community shared, opened in a new %s"
		% ("tab" if web else "window"))
	_add("import_ldraw", "LDraw model (.ldr, .mpd)…", 0, bar._import)
	_add("import_io", "BrickLink Studio model (.io)…", 0, bar._import)
	_add("import_lxf", "LEGO® Digital Designer model (.lxf)…", 0, bar._import)
	_add("import_mesh", "3D model to brickify (.obj, .stl, .ply, .3mf, .vox, .fbx, .gltf, .glb)…", 0,
		func() -> void: bar.brickify_wanted.emit(), Callable(),
		"A sculpt, a scan or any 3D model, laid in bricks")
	_add("save", "Save", CTRL | KEY_S, bar._on_save, something,
		"Keep this model under its name")
	_add("save_as", "Save as…", CTRL | SHIFT | KEY_S, _ask_save_as, something,
		"Keep a copy of this model under another name")
	# src/ui/versions_dialog.gd, src/parts/model_versions.gd.
	_add("versions", "Versions…", 0, func() -> void: versions.open(), Callable(),
		"The last %d saves of this model, to open one again or compare it with" % ModelVersions.KEPT)
	# src/ui/compare_view.gd, src/parts/model_diff.gd.
	_add("compare", "Compare with…", 0, func() -> void: versions.open(true),
		func() -> bool: return not store.versions().is_empty(),
		"What changed since one of this model's saves: added green, removed red, moved amber")
	_add("export_ldraw", "LDraw model (.ldr, or .mpd with its sub-models)", 0,
		func() -> void: await bar._on_export(), something)
	_add("export_io", "BrickLink Studio model (.io)", 0,
		func() -> void: await (app.get("_exports") as Exports).studio_io(true), something)
	# src/ui/exports.gd, src/parts/mesh_export.gd.
	_add("export_3d", "3D model (.glb, .gltf, .obj, .stl)…", 0,
		func() -> void: (app.get("_exports") as Exports).ask_model_3d(), something,
		"The model as a 3D file for Blender, AR or a 3D printer")
	_add("export_picture", "Picture of the model (.png)", 0,
		func() -> void: await (app.get("_exports") as Exports).take_picture(true), something)
	_add("export_bricklink", "BrickLink wanted list (.xml)", 0,
		func() -> void: await (app.get("_exports") as Exports).shop_list("bricklink", {}, true),
		something)
	_add("export_all", "All my models (.zip)", 0,
		func() -> void: await (app.get("_exports") as Exports).all_models(true),
		func() -> bool: return ModelStore.any_saved(),
		"Every model saved here, as LDraw files in one .zip: a copy of your own")
	_add("export_rebrickable", "Rebrickable parts list (.csv)", 0,
		func() -> void: await (app.get("_exports") as Exports).shop_list("rebrickable", {}, true),
		something)
	_add("render", "Render…", 0, func() -> void: app.call("open_render"), something,
		"A photo-real picture or turntable of the model, on a backdrop, in studio light")
	# src/ui/pose_panel.gd.
	_add("pose", "Motions…", 0, func() -> void: app.call("open_pose"), something,
		"The model's own movements, Open the doors or Lift the boom: played, recorded by dragging the parts, and rendered")
	_add("instructions", "Instructions…", 0, _instructions, something,
		"Building instructions for this model, step by step")
	_add("share", "Share…", 0, func() -> void: app.call("_share_wanted"), something,
		"A link anyone can open to see this model, its steps and its parts list")
	# src/net/together.gd, src/ui/together_dialog.gd.
	_add("together", "Build together…", 0, func() -> void: app.call("open_together"), Callable(),
		"Build this model with someone else, live, each in their own browser or the app")
	# src/assembly/pinned_comments.gd, src/ui/pins_dialog.gd.
	_add("comments", "Comments…", 0, func() -> void: app.call("open_pins"), Callable(),
		"Comments pinned to the model's parts, kept with it, and a new one on the part selected")
	_add("clear", "Clear the baseplate…", 0, bar._ask_to_clear, something,
		"Empty the baseplate. Asks first: it cannot be undone")
	_add("account", "Account…", 0, func() -> void: bar.account_wanted.emit(),
		Callable(), "Who is signed in, and Sign out")
	_add("quit", "Quit", CTRL | KEY_Q, func() -> void: app.get_tree().quit(),
		func() -> bool: return not OS.has_feature("web"))
	# Edit
	# An open is the oldest step: Undo past every change since brings back
	# the model it took off (ModelStore.reopen).
	_add("undo", "Undo", CTRL | KEY_Z, func() -> void: await verbs.press("undo"),
		func() -> bool: return builder.history_depth() > 0 or store.can_reopen(),
		"Take back the last change")
	_add("redo", "Redo", CTRL | SHIFT | KEY_Z, func() -> void: await verbs.press("redo"),
		func() -> bool: return not builder._redo.is_empty() or store.can_reopen(true), "Put it back")
	# Not "cut": that is the cut-away (K), defined under View, and a second
	# command of one name replaced the first, so Edit, Cut sliced the model
	# open instead of taking the selection off it.
	_add("cut_parts", "Cut", CTRL | KEY_X, func() -> void: verbs.cut(), selected,
		"Take the selection off the model, to paste somewhere else")
	_add("copy", "Copy", CTRL | KEY_C, func() -> void: verbs.copy(), selected,
		"Copy the selection")
	_add("paste", "Paste", CTRL | KEY_V, func() -> void: verbs.paste(), Callable(),
		"Hold a copy of what was copied: click to put it down, {rotate_held|turns it}")
	_add("duplicate", "Duplicate", CTRL | KEY_D, func() -> void: verbs.duplicate_selection(),
		selected, "Hold a copy of the selection, to put down beside it")
	# src/assembly/pattern.gd, src/ui/pattern_dialog.gd.
	_add("pattern", "Pattern…", CTRL | SHIFT | KEY_D, func() -> void:
		if builder.is_carrying():
			verbs.put_away()
		pattern_dialog.open(builder.selection.keys()), selected,
		"Copies of the selection in a row, round, or along a hose, put down at once")
	_add("delete", "Delete", KEY_DELETE, func() -> void: await verbs.press("delete"),
		selected, "Take the selection off the model")
	_add("select_all", "Select all", CTRL | KEY_A, func() -> void: verbs.select_by("all"),
		something)
	_add("select_none", "Select nothing", 0, func() -> void: verbs.select_by("none"), selected)
	_add("select_colour", "Same colour", 0, func() -> void: verbs.select_by("colour"), selected)
	_add("select_part", "Same part", 0, func() -> void: verbs.select_by("part"), selected)
	_add("select_alike", "Same part and colour", 0, func() -> void: verbs.select_by("alike"),
		selected)
	# The parts list with its find: a part's number, name or colour, and
	# Enter selects every one of them.
	_add("select_find", "Part number or name…", 0, func() -> void: app.call("_find_parts"),
		something, "Find a part in the model by its number, its name or its colour")
	_add("select_connected", "Everything connected", 0,
		func() -> void: await verbs.select_connected(), selected)
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
	# The column opened first, as / opens it for the search: typed into a
	# folded one, the name would go to the model as its keys.
	_add("find_colour", "A colour by name or number", SHIFT | KEY_C, func() -> void:
		(app.get("_bin_dock") as SideDock).set_open(true)
		(app.get("_bin") as PartsBin).focus_colour_find(), Callable(),
		"Type a colour's name or number; Enter takes the first")
	_add("paint", "Paint the selection", KEY_C, func() -> void: await verbs.press("paint"),
		selected, "Paint the selection the colour in hand")
	_add("replace", "Replace with the part in hand", 0, func() -> void: verbs.replace(),
		selected, "Swap the selection for the part you hold, each in its own colour")
	# src/prints/printed_versions.gd: the prints the LEGO Group made of it.
	_add("printed_versions", "Printed versions…", 0, func() -> void:
		var studio: PrintStudio = app.get("_studio")
		if studio != null:
			studio.open_versions(),
		func() -> bool:
			var studio: PrintStudio = app.get("_studio")
			return studio != null and studio.offers_versions(),
		"Swap the part for one of the prints or stickered versions the LEGO Group made of it")
	_add("mirror", "Mirror", SHIFT | KEY_M, func() -> void: verbs.mirror(), selected,
		"Make the selection its mirror image, left to right as you see it")
	# src/assembly/split_merge.gd: Studio's Split and Merge, on its keys.
	_add("split_parts", "Split into smaller parts", ALT | KEY_S,
		func() -> void: SplitMerge.split(verbs), selected,
		"Plates, bricks and tiles into 1 x 1s, a 1 x 1 brick into three plates, slopes into 1-wide slopes, on the same studs")
	_add("merge_parts", "Merge into bigger parts", ALT | KEY_M,
		func() -> void: SplitMerge.merge(verbs), selected,
		"The selected plates, bricks and tiles of a colour into the fewest real parts made in it: three plates high a brick")
	# J, which had no command: on the menu on a part, and found by name.
	_add("swing", "Swing on its hinge", KEY_J, func() -> void: verbs.swing(EditVerbs.SWING),
		func() -> bool: return builder.hinge_angle() != null,
		"Swing the selection %d° about the hinge, clip or turntable it hangs from; {swing_back|swings it back}"
		% roundi(EditVerbs.SWING))
	# src/ai/selection_scope.gd: Claude changes these parts and the room round
	# them, and nothing else.
	_add("ask_claude", "Ask Claude about this…", CTRL | KEY_K,
		func() -> void: app.call("ask_about_selection"), selected,
		"Ask Claude to change the selected parts, and only them, or ask about them")
	# On a part View, Stress shows weak: the part and what holds it, asked
	# about with the joint's numbers.
	_add("brace", "Ask Claude to brace this…", 0, _brace,
		func() -> bool: return stress.weakest_of(builder.selection) != 0,
		"Ask Claude to make this joint hold: what it carries, on what, and its margin, asked for you")
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
	# Studio's step button: the parts put down since the last step are a
	# step, and the next part starts another. Nothing to select first.
	_add("step_close", "Next step", KEY_E, func() -> void: edit_steps("close"), something,
		"The parts put down since the last step make a step, and the next part starts another")
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
	# Any step in one go (steps3), as Studio's Move To: the number typed, or
	# the selection dragged onto the timeline's row of steps (StepsBar).
	var timeline: StepsBar = app.get("_steps")
	if timeline != null:
		timeline.shell = self
	_add("step_to", "Move to step…", 0, func() -> void:
		if timeline != null:
			timeline.ask_step_to(), selected,
		"The selected parts into any step, its number typed")
	# How the booklet prints the step the timeline is on (BookletLooks), as
	# Studio's Instruction Maker sets each step's view and page.
	for look: Array in [
			["booklet_turn_left", "Turn the view left", "The model turned 45 degrees for this step's picture, and the steps after it"],
			["booklet_turn_right", "Turn the view right", "The model turned 45 degrees the other way for this step's picture"],
			["booklet_tilt_up", "Look from higher", "This step's picture from 15 degrees higher"],
			["booklet_tilt_down", "Look from lower", "This step's picture from 15 degrees lower"],
			["booklet_this_view", "Use this view for the step", "This step's picture drawn from the angle the window looks from now"],
			["booklet_usual_view", "Usual view", "This step drawn from the booklet's usual angle again"],
			["booklet_zoom_in", "Zoom in", "This step's picture closer in on what it adds"],
			["booklet_zoom_out", "Zoom out", "This step's picture further out"],
			["booklet_bigger", "Bigger on the page", "This step drawn larger, so fewer go on its page"],
			["booklet_smaller", "Smaller on the page", "This step drawn smaller"],
			["booklet_new_page", "Start a new page", "This step at the top of a new page"],
			["booklet_alone", "A page alone", "This step on a page of its own"],
			["booklet_parts", "Parts list", "The box of parts this step adds, shown or left off"],
			["booklet_callout", "Callout", "The sub-assembly this step puts on built in a box beside it, or on pages of its own"],
			["booklet_per_page", "Steps a page", "At most this many steps on a page: as they fit, 1, 2 or 4"],
			["booklet_lay_out", "Lay out the page…", "This step's page by hand: drag its picture, parts list, callout and number where they go, and add words and pictures"],
			["booklet_highlight", "Outline new parts", "The parts each step adds outlined in orange in the booklet, or not"]]:
		var op: String = str(look[0]).trim_prefix("booklet_")
		_add(look[0], look[1], 0, func() -> void: edit_look(op), on_a_step, look[2])
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
		var look: Callable = func() -> void: camera.set_view(named)
		# Turned and framed, so it finds the model again (Main.default_view).
		if named == "default":
			look = func() -> void: app.call("default_view")
		_add(view[0], view[1], view[2], look,
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
	# A picture to build over (src/ui/reference_image.gd).
	_add("reference", "Reference picture…", 0, func() -> void:
		(app.get("_reference") as ReferenceImage).open(), Callable(),
		"A photo, plan or drawing laid on the floor or stood behind the model, to build over")
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
	_add("stress", "Stress", 0, func() -> void:
		# The two draw with one layer (BrickWorld.set_stress): Stress, asked
		# for while comparing, takes over where the comparison is.
		if compare.is_open():
			compare.close(false)
			stress.set_on(true)
			return
		stress.set_on(not stress.on),
		func() -> bool: return stress.on or world.brick_count() > store.scenery.size(),
		"Every part tinted by how near its weakest joint is to letting go: red past its "
		+ "studs' working load, amber within twice it")
	_ticked("stress", func() -> bool: return stress.on)
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
		SideDock.of(inspector).set_open(true)
		inspector.set_open(true), selected,
		"What it is, its colour by every name, where it stands and what it is joined to")
	_add("panel_keys", "Key strip", 0, func() -> void: set_key_strip(not key_strip_shown()))
	_ticked("panel_keys", key_strip_shown)
	# A straight-on view beside the model (SplitView). F8: LDCad's Space,
	# which swaps its split for one large view, is the app's to slide the
	# view and play the timeline, and F8 is no preset's.
	_add("split_view", "Split", KEY_F8, func() -> void:
		var split: SplitView = app.get("_split")
		split.set_on(not split.is_showing()),
		func() -> bool:
			var split: SplitView = app.get("_split")
			return split != null and (split.is_showing() or split.fits()),
		"A second view beside the model, square on from the front, top, side or back")
	_ticked("split_view", func() -> bool:
		var split: SplitView = app.get("_split")
		return split != null and split.is_showing())
	_add("full_screen", "Full screen", KEY_F11, _toggle_full_screen)
	_ticked("full_screen", func() -> bool:
		return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	# Build
	_add("timeline", "Timeline", KEY_B, func() -> void: await app.call("_toggle_steps"),
		something, "Play the build from an empty baseplate to the finished model and back")
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
	# Sections (SectionsUi): the model split as a builder builds it.
	_add("suggest_sections", "Suggest sections", 0, func() -> void: await sections.suggest(),
		something, "How a builder would split this into sections, as a set into bags: "
		+ "shown in the model tree to accept, rename, merge or split")
	_add("evaluate_section", "Evaluate the section…", 0,
		func() -> void: await sections.show_evaluation(), sections.can_target,
		"The selected section on its own: parts, weight, whether it holds together and "
		+ "stands, what joins it to the rest, its own steps")
	_add("break_out", "Break out the section", KEY_Y,
		func() -> void: sections.break_out_or_back(),
		func() -> bool: return sections.can_target() or not world.broken_out.is_empty(),
		"Pull the selected section away from the model to work on it, or put it back "
		+ "exactly where it was ({break_out} again)")
	_add("put_back", "Put every section back", 0, func() -> void: sections.put_back_all(),
		func() -> bool: return not world.broken_out.is_empty(),
		"Every section broken out back exactly where it was")
	_add("explode", "Exploded view", SHIFT | KEY_Y, func() -> void: sections.toggle_explode(),
		something, "Every section drawn apart, and back together ({explode} again)")
	_ticked("explode", func() -> bool: return sections.is_exploded())
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
		"Bring in an OBJ, STL, PLY, 3MF, VOX, FBX or glTF model — a sculpt, a scan, anything — and lay it in bricks at the size you choose")
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
			["connect", "Connect", KEY_N], ["clone", "Clone", 0], ["paint", "Paint", 0], ["hide", "Hide", 0],
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
	_add("simulate", "Simulate mechanism…", 0, func() -> void: await app.call("open_simulate"),
		something, "Turn a gear train from a crank or an axle: how fast each part goes, "
			+ "each arm's period, what locks it, and whether it stays standing as it turns")
	# src/ui/hidden_colours_panel.gd: the parts nobody sees, coloured by
	# section, stage or side as big sets are, after a preview.
	_add("hidden_colours", "Colour the hidden parts…", 0,
		func() -> void: await app.call("open_hidden_colours"), something,
		"Give the parts nobody sees in the finished model a colour for each section, stage "
			+ "or side, as big sets do, so you can find your place while building")
	_add("reseat", "Seat parts on their studs", 0, _reseat, something,
		"Find parts a fraction of a stud off their studs, and offer to seat them")
	_add("connector", "Claude connector…", 0, func() -> void:
		(app.get("_chat_dock") as SideDock).set_open(true)
		bar.say("the connector is at the foot of the assistant panel"), Callable(),
		"Let Claude build here, from your own Claude account")
	_add("settings", "Settings…", KEY_COMMA, func() -> void: bar.controls_wanted.emit(),
		Callable(), "Which way the wheel zooms, and what the middle button does")
	# Help
	_add("keys", "Keys and controls", KEY_F1, func() -> void: (app.get("_controls") as ControlsDialog).open_keys(),
		Callable(),
		"What every button and key does")
	_add("tour", "Take the tour", 0, func() -> void: first_build.start(), Callable(),
		"Build your first model, seven short steps done in the app")
	# src/ui/command_palette.gd: Figma's key for its Actions. Ctrl+Shift+P
	# too on the desktop (handle_key); a browser keeps that one.
	_add("palette", "Find a command…", CTRL | KEY_SLASH, func() -> void: palette.open(), Callable(),
		"Any command by its name or its menu: type a few letters, then Enter")
	# brickworks.diy/docs: every menu, tool and page of the site, written
	# out (docs-site/, tools/docs_site.py). The owner asked for it, 2026-10-29.
	# It opens at the page of the panel in front, where one is (docs_page).
	_add("docs", "Documentation", 0,
		func() -> void: Outside.open_link(DocsPages.SITE + docs_page()), Callable(),
		"How everything in Brickworks works, on brickworks.diy")
	_add("website", "Brickworks website", 0,
		func() -> void: Outside.open_link("https://brickworks.diy"))
	_add("beta_hub", "Beta hub", 0,
		func() -> void: Outside.open_link(DocsPages.SITE + "/beta-hub"), Callable(),
		"For beta testers: what to try, what we know is wrong, and how to tell us")
	_add("feedback", "Send feedback…", 0, _show_feedback, Callable(),
		"Something wrong, an idea or a question, to the people who make Brickworks")
	_add("about", "About Brickworks", 0, _show_about)
	# The web app had no way back to the site but the browser's own Back
	# (brand373). This tab, the site's own address: a preview's on a preview.
	# A model not yet written to the browser's storage holds the page
	# (src/boot/shell.html, beforeunload).
	_add("back_to_site", "Back to brickworks.diy", 0,
		func() -> void: JavaScriptBridge.eval("location.assign('/')", true),
		func() -> bool: return OS.has_feature("web"),
		"Leave the app for the website's home page, in this tab")
	# What a greyed command waits for, said beside it (why_not).
	for found: Command in _commands.values():
		if found.can == selected:
			found.needs = "Select a part first"
		elif found.can == something:
			found.needs = "Put a part on the baseplate first"
		elif found.can == on_a_step:
			found.needs = "Choose a step on the timeline first"
		elif found.name.begins_with("floor_colour_"):
			found.needs = "Stand the model on a baseplate first"
		else:
			found.needs = str(NEEDS.get(found.name, ""))


## What a right click on a part offers: the verbs a person reaches for,
## each the command Edit or Build has, greyed where it would do nothing.
## A right click on a part did nothing (brickworks.diy, 2026-10-12).
## Duplicate, Replace, the same part or colour, the step moves and the
## swing on a hinge each needed a key or a menu (appux371 A8): here, with
## their keys, among what selects, hides, copies and changes the part.
const ON_A_PART: Array = ["ask_claude", "brace", "comments", "-", "select_connected", "select_part",
	"select_colour", "-", "hide", "isolate", "-", "copy", "duplicate", "delete", "-", "paint",
	"split_parts", "merge_parts",
	"replace", "printed_versions", "swing", "-", "step_prev", "step_next", "step_to", "make_submodel", "-",
	"show_properties"]

## A row's words on a part where the menus' would not say it: Select by's
## "Same part" there is the same as the part clicked.
const ON_A_PART_WORDS: Dictionary = {"comments": "Comment on it…",
	"select_connected": "Select everything joined to it",
	"select_part": "Select the same part", "select_colour": "Select the same colour"}
var context: PopupMenu
var _brace_id: int = -1


## The menu for a part, at a point on the screen, for the selection the
## right click left: the part, or the selection it is in.
func open_context(at: Vector2) -> void:
	if context == null:
		context = PopupMenu.new()
		_fill(context, ON_A_PART)
		for name: String in ON_A_PART_WORDS:
			context.set_item_text(item_index(context, name), ON_A_PART_WORDS[name])
		context.id_pressed.connect(_on_id)
		var brace_at: int = item_index(context, "brace")
		_brace_id = context.get_item_id(brace_at) if brace_at != -1 else -1
		add_child(context)
	# Ask Claude to brace this is on the menu only while View, Stress shows
	# the part weak, under Ask Claude about this….
	var bracing: int = item_index(context, "brace")
	if can("brace") and bracing == -1 and _brace_id != -1:
		context.add_item((_commands["brace"] as Command).words, _brace_id)
		context.set_item_tooltip(context.item_count - 1, (_commands["brace"] as Command).tip)
		context.set_item_index(context.item_count - 1, item_index(context, "ask_claude") + 1)
	elif not can("brace") and bracing != -1:
		context.remove_item(bracing)
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
	for item: String in _shown(items):
		if item == "-":
			popup.add_separator()
		elif item.begins_with(">"):
			var sub := PopupMenu.new()
			var kind: String = item.substr(1)
			sub.name = kind
			sub.add_theme_font_size_override("font_size", 13)
			# An id no command has, so the row is never taken for one.
			popup.add_submenu_node_item(SUBMENU_WORDS[kind], sub, SUBMENU_ID + popup.item_count)
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
			# One id a command, in every menu it is in, for good: menus made
			# again (set_assistant) keep the ids those made once hold.
			var id: int = _ids.find(item)
			if id < 0:
				id = _ids.size()
				_ids.append(item)
			if found.radio:
				popup.add_radio_check_item(found.words, id)
			elif found.ticked.is_valid():
				popup.add_check_item(found.words, id)
			else:
				popup.add_item(found.words, id)
			_show_key(popup, popup.get_item_index(id), found)
			if not found.tip.is_empty():
				popup.set_item_tooltip(popup.get_item_index(id), found.tip)


## A menu's rows as the window shows them: without the assistant's while
## it is off, and without the line that set them apart from the rest.
func _shown(items: Array) -> Array:
	var out: Array = []
	for item: String in items:
		if not assistant_shown and item in ASSISTANT_COMMANDS:
			continue
		if item in WEB_ONLY and not OS.has_feature("web"):
			continue
		if EARLY_COMMANDS.has(item) and not str(EARLY_COMMANDS[item]) in early:
			continue
		if item == "-" and (out.is_empty() or out.back() == "-"):
			continue
		out.append(item)
	while not out.is_empty() and out.back() == "-":
		out.pop_back()
	return out


## The menus as a phone's More lists them (PhoneShell). The app's menu's
## rows go under Help too, where About and the docs were before the phone's
## bar had the mark; finding a command by typing is for a keyboard.
static func touch_menus() -> Array:
	var out: Array = []
	for menu: Array in MENUS:
		var items: Array = menu[1]
		if str(menu[0]) == "Help":
			items = items + ["-"] + APP_MENU.filter(func(item: String) -> bool:
				return item != "palette")
		out.append([menu[0], items])
	return out


## Settings, Assistant (AI): the menus and the menu on a part made again,
## with the assistant's commands or without them.
func set_assistant(on: bool) -> void:
	if on == assistant_shown:
		return
	assistant_shown = on
	_fill_again()


## Who designs (Settings, AI), named in the commands that ask it: Ask Claude
## about this…, or Ask GPT-6.1 Sol about this… while a model on the person's
## key designs (ProviderSettings.designer_name).
func name_designer(who: String) -> void:
	var ask: Command = _commands.get("ask_claude")
	if ask == null or ask.words == "Ask %s about this…" % who:
		return
	ask.words = "Ask %s about this…" % who
	ask.tip = "Ask %s to change the selected parts, and only them, or ask about them" % who
	var brace: Command = _commands["brace"]
	brace.words = "Ask %s to brace this…" % who
	brace.tip = ("Ask %s to make this joint hold: what it carries, on what, and its margin, "
		% who + "asked for you")
	_fill_again()


## The account's early features (Account.early): the menus made again with
## the commands of those it may use, and without the others'.
func set_early(keys: Array[String]) -> void:
	if keys == early:
		return
	early = keys.duplicate()
	_fill_again()


## The menus and the menu on a part made again from the commands.
func _fill_again() -> void:
	if _menus.is_empty():
		return
	# The ids stay: the toolbar's Select by and the app's menu, made once,
	# hold them. Cleared, a command's id went to another command: started
	# with the assistant off and then turned on, Select by colour on the
	# toolbar ran Help's Documentation and the rest of it nothing (brand373).
	for n: int in _menus.size():
		var popup: PopupMenu = _menus[n].get_popup()
		popup.clear(true)
		_fill(popup, MENUS[n][1])
	# The app's menu too: Beta hub is in it for a tester alone.
	var app_menu: PopupMenu = bar.mark.get_popup()
	app_menu.clear(true)
	_fill(app_menu, APP_MENU)
	if context != null:
		context.queue_free()
		context = null


## A row's key, as the keymap has it now (Keymap): a key the menu can
## neither name nor draw goes after the row's words, whatever they are.
func _show_key(popup: PopupMenu, index: int, found: Command) -> void:
	var accel: int = Keymap.key_of(found.name)
	var shown: int = menu_accel(accel)
	var words: String = popup.get_item_text(index).get_slice(KEY_AFTER, 0)
	popup.set_item_text(index, words + (KEY_AFTER + key_text(accel)
		if shown == 0 and accel != 0 else ""))
	popup.set_item_accelerator(index, shown)


const KEY_AFTER := "    "


## Greyed where it would do nothing, ticked where it is on, and its key the
## one the keymap gives it now.
func _refresh(popup: PopupMenu) -> void:
	for index: int in popup.item_count:
		var id: int = popup.get_item_id(index)
		if popup.is_item_separator(index) or id < 0 or id >= _ids.size():
			continue
		var name: String = _ids[id]
		_show_key(popup, index, _commands[name])
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
	if not await bar.ask_to_replace("“%s”" % _recent[id].name):
		return
	var placed: int = await bar.open_with_progress(_recent[id].path)
	if placed >= 0:
		bar.opened.emit(placed)


func _fill_history(menu: PopupMenu) -> void:
	menu.clear()
	var said: PackedStringArray = builder.history_words(25)
	# And under them the open they followed, the step before the oldest:
	# going back to before it brings back the model it took off.
	var opened: String = store.reopen_words() if store != null else ""
	if said.is_empty() and opened.is_empty():
		menu.add_item("nothing to go back to yet")
		menu.set_item_disabled(0, true)
	for n: int in said.size():
		menu.add_item("Undo %s" % said[n] if n == 0 else "Back to before: %s" % said[n], n)
	if not opened.is_empty():
		menu.add_item(("Undo %s" if said.is_empty() else "Back to before: %s") % opened,
			builder.history_depth())


# -- what only the shell does ---------------------------------------------------


func _ask_save_as() -> void:
	# The desktop's is the platform's Save dialog, and a file where it says.
	if not OS.has_feature("web"):
		var path: String = await SaveTo.ask(ModelStore._safe_name(bar.model_name())
			+ bar.ldraw_extension(), "", "Save as")
		if not path.is_empty():
			await bar.save_to_file(path)
		return
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
	await bar._on_save()


## The booklet, where the app has one of its own to open; the timeline,
## where the booklet is made from, where it does not.
func _instructions() -> void:
	if app.has_method("_booklet_wanted"):
		await app.call("_booklet_wanted")
	else:
		await app.call("_toggle_steps")


## Tools, Check stability: the joints that would give way, selected, and
## then the balance (Balance) — the margin said here in the status bar, the
## support polygon and the centre of mass drawn on the floor (BalanceMark),
## and the stud joints carrying most against their studs tinted — over every
## pose the Pose panel's animation or its sliders reach.
func _check_stability() -> void:
	var stability: Stability = app.get("_stability")
	stability.floor_ids = store.scenery
	# The status bar's weighing of the model as it is, when it has one: the
	# same check, done already (Main.weighed_now). Else on a worker for a big
	# model, the poses found meanwhile (Stability.check_paced).
	var poses: Array = []
	var report: Stability.Report = app.call("weighed_now") if app.has_method("weighed_now") \
		else null
	if report != null:
		poses = _poses_to_weigh()
	else:
		report = await stability.check_paced(world, func() -> void:
			poses.assign(_poses_to_weigh()))
	if report == null:
		report = stability.check(world)
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
	# With no pose to weigh, the balance as it stands is what the check read
	# its margins from.
	var balance: Balance.Report = await weigh_balance(poses, true, true,
		report.balance if poses.is_empty() else null)
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
## [param weighed_already], with no pose given, is the model weighed as it
## stands already (Stability.Report.balance): shown, not weighed again.
func weigh_balance(given: Variant = null, show: bool = true, tint: bool = true,
		weighed_already: Balance.Report = null) -> Balance.Report:
	if weighed_already != null and given is Array and (given as Array).is_empty():
		return _show_balance(weighed_already, show, tint)
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
		var task: int = WorkerTasks.add(func() -> void:
			weighed[0] = judge.measure(still.bricks(), poses), false, "weigh the balance")
		library.reading_in(task)
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerTasks.collect(task)
		library.end_reading(task)
		still.free()
	job.end()
	return _show_balance(weighed[0], show, tint)


## [param report] drawn on the floor and as tints (see [method weigh_balance]).
func _show_balance(report: Balance.Report, show: bool, tint: bool) -> Balance.Report:
	if report == null or not show:
		return report
	if _balance_mark == null:
		_balance_mark = BalanceMark.new()
		_balance_mark.world = world
		app.add_child(_balance_mark)
	_balance_mark.show_report(report, _tints(report) if tint else {})
	balance_shown = report
	return report


## From this many parts the weighing goes to a worker: it is asked for, and
## Working shows while it runs. The status bar's is on a worker at any size
## (Main._weigh), since it runs after every change.
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


## Ask Claude to brace this: the part on the weakest joint selected with
## what holds it, and the assistant asked about them with the joint's
## numbers.
func _brace() -> void:
	var weakest: int = stress.weakest_of(builder.selection)
	var one: Balance.JointLoad = stress.report.margins.get(weakest) if weakest != 0 else null
	if one == null:
		return
	builder.selection.clear()
	for id: int in [one.beyond, one.held_by]:
		if world.get_brick(id) != null and not store.scenery.has(id):
			builder.selection[id] = true
	builder.selection_changed.emit(builder.selection.size())
	app.call("ask_about_selection", stress.brace_words(weakest))


func _reseat() -> void:
	var offer: SeatOffer = app.get("_seat_offer")
	if offer.check() == 0:
		bar.say("every part is on its studs")


func _toggle_full_screen() -> void:
	var full: bool = ticked("full_screen") == 1
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
		else DisplayServer.WINDOW_MODE_FULLSCREEN)


## About's width, as it was with the mark beside its words.
const ABOUT_WIDE := 600


## The docs page of the panel open in front, as the docs' own heads name
## it (DocsPages, from their `panels:`), or the docs' start with none open.
## The last one open in the window's tree is the one drawn over the others.
func docs_page() -> String:
	var found := "/docs"
	if app == null:
		return found
	for node: Node in app.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		var name: StringName = script.get_global_name() if script != null else &""
		if not DocsPages.PANELS.has(name):
			continue
		var shown: bool = (node as CanvasItem).is_visible_in_tree() if node is CanvasItem \
			else node is Window and (node as Window).visible
		if shown:
			found = DocsPages.PANELS[name]
	return found


## Help, Send feedback…: the window pictured as it is, once the menu has
## gone from it and before the dialog covers it, offered with the report.
func _show_feedback() -> void:
	for _n: int in 2:
		await get_tree().process_frame
	var window: Image = get_viewport().get_texture().get_image()
	feedback.account = app.get("_account")
	feedback.recent = app.get("_log")
	feedback.open(window)


func _show_about() -> void:
	_about_text.text = ("Brickworks %s\n\nA complete CAD for LEGO® models, built by hand"
		+ (" or with the assistant" if assistant_shown else "")
		+ ", on the web or on your own computer.\n\n%s") % [
		BuildInfo.version(), BuildInfo.describe()]
	_about_marks.text = ("LEGO® is a trademark of the LEGO Group of companies which does not sponsor, authorize or endorse this app. "
		+ "LEGO® Art, Technic, the Minifigure and the Brick and Knob configurations are also trademarks of the LEGO Group.")
	_about_scroll.scroll_vertical = 0
	_about_scroll.custom_minimum_size.y = _about_room()
	_about.popup_centered(Vector2i(ABOUT_WIDE, 0))
	if not Phone.on():
		_fit_about.call_deferred()


## What About's words have room for: most of the window's height, the
## rest of them scrolled.
func _about_room() -> float:
	return get_viewport().get_visible_rect().size.y * 0.6


## On a desktop, About only as tall as what it says once that is laid out
## at its width, where the window has room for it all. A phone's sheet
## keeps its room: what it says is always taller there.
func _fit_about() -> void:
	await get_tree().process_frame
	if not _about.visible:
		return
	var said: Control = _about_scroll.get_child(0)
	var tall: float = minf(said.get_combined_minimum_size().y, _about_room())
	if absf(tall - _about_scroll.custom_minimum_size.y) < 1.0:
		return
	_about_scroll.custom_minimum_size.y = tall
	_about.size = Vector2i(ABOUT_WIDE, 0)
	_about.move_to_center()


## Help, About's list of whose work is in Brickworks (Credits): each one's
## name, its licence to read in full or its links, and what of it is here
## on what terms. Each link is a button, so Tab reaches it (Access) and a
## screen reader says its words.
func _credits() -> VBoxContainer:
	var list := VBoxContainer.new()
	list.name = "credits"
	list.add_theme_constant_override("separation", 10)
	var head := Label.new()
	head.text = "Made with"
	head.add_theme_font_size_override("font_size", 12)
	head.modulate = Color(1, 1, 1, 0.75)
	list.add_child(head)
	for one: Dictionary in Credits.LIST:
		var id: String = one["id"]
		var entry := VBoxContainer.new()
		entry.name = "credit_" + id
		entry.add_theme_constant_override("separation", 2)
		var top := HFlowContainer.new()
		top.add_theme_constant_override("h_separation", 14)
		var named := Label.new()
		named.text = one["name"]
		top.add_child(named)
		if not str(one["full"]).is_empty():
			var read: LinkButton = Look.link(one["full"])
			read.name = "read_" + id
			read.pressed.connect(_read_licence.bind(id))
			top.add_child(read)
		for link: Array in one["links"]:
			var address: String = link[1]
			var away: LinkButton = Look.link(str(link[0]))
			away.tooltip_text = address
			away.pressed.connect(func() -> void: Outside.open_link(address))
			top.add_child(away)
		entry.add_child(top)
		var words := Label.new()
		words.text = "%s %s" % [one["what"], one["terms"]]
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_font_size_override("font_size", 12)
		words.modulate = Color(1, 1, 1, 0.75)
		entry.add_child(words)
		list.add_child(entry)
	return list


## A licence in full, over About (Credits.full_text): a page the keys
## scroll and a screen reader reads, the same on the web, where there is
## no file beside the app to open.
func _read_licence(id: String) -> void:
	if _licence == null:
		_licence = AcceptDialog.new()
		_licence.ok_button_text = "Close"
		_licence_text = TextEdit.new()
		_licence_text.editable = false
		_licence_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_licence_text.custom_minimum_size = Vector2(ABOUT_WIDE, 420)
		_licence_text.add_theme_font_size_override("font_size", 12)
		# Read only, not greyed: it is there to be read.
		_licence_text.add_theme_color_override("font_readonly_color",
			_licence_text.get_theme_color("font_color"))
		_licence.add_child(_licence_text)
		# Over About, which holds the keys while it shows.
		_about.add_child(_licence)
	var one: Dictionary = Credits.find(id)
	_licence.title = str(one["full"])
	_licence_text.accessibility_name = str(one["full"])
	_licence_text.text = Credits.full_text(id)
	_licence_text.set_caret_line(0)
	_licence_text.scroll_vertical = 0
	_licence.popup_centered()
	_licence_text.grab_focus.call_deferred()


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
		_floor_wide.accessibility_name = "Studs across"
		_floor_deep.accessibility_name = "Studs deep"
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
	if held and key.shift_pressed and key.keycode == KEY_N and not OS.has_feature("web"):
		run("new_window")
		return true
	match key.keycode:
		KEY_F11:
			run("full_screen")
			return true
		KEY_F8:
			if not held and not key.shift_pressed and not key.alt_pressed:
				return run("split_view")
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
		KEY_SLASH:
			if held and not key.shift_pressed and not key.alt_pressed:
				return run("palette")
		KEY_P:
			# VS Code's key for its palette, on the desktop: Firefox keeps
			# Ctrl+Shift+P for a private window.
			if held and key.shift_pressed and not key.alt_pressed and not OS.has_feature("web"):
				return run("palette")
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
		KEY_Y:
			# Y breaks the selected section out or puts it back; Shift+Y
			# draws every section apart (SectionsUi).
			if not held and not key.alt_pressed:
				return run("explode" if key.shift_pressed else "break_out")
		KEY_C:
			# C alone paints (main); Shift-C asks for a colour by name.
			if key.shift_pressed and not held and not key.alt_pressed:
				return run("find_colour")
		KEY_E:
			# Shift-E turns the model (main); E alone ends the step.
			if not key.shift_pressed and not held and not key.alt_pressed \
					and can("step_close"):
				return run("step_close")
		KEY_D:
			# Ctrl+D alone is Duplicate (EditVerbs); with Shift, its copies
			# laid out at once.
			if held and key.shift_pressed and not key.alt_pressed:
				return run("pattern")
		# Studio's Alt+S and Alt+M (SplitMerge).
		KEY_S, KEY_M:
			if key.alt_pressed and not held and not key.shift_pressed:
				return run("split_parts" if key.keycode == KEY_S else "merge_parts")
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
	if op in ["prev", "next", "new", "to"] and ids.is_empty():
		return "select the parts first"
	if not op in ["prev", "next", "new", "close"] and at == null:
		return "go to a step on the timeline first"
	var steps: StepsBar = app.get("_steps")
	var number: int = at.number if at != null else -1
	var skip: Dictionary = store.scenery
	var level: String = assemblies.entered if assemblies != null else ""
	if op == "close":
		return _close_step(level, skip)
	# Parts of the sub-model whose step the timeline shows are its parts to
	# move, as they are once it is entered: a booklet's steps are a
	# sub-model's steps as often as the model's own.
	if not ids.is_empty() and at != null and at.authored_step >= 0 \
			and at.authored_in != level and Assemblies.within(at.authored_in, level):
		var all_in: bool = true
		for brick_id: Variant in ids:
			var brick: BrickWorld.Brick = world.get_brick(int(brick_id))
			if brick == null or Assemblies.path_of(brick) != at.authored_in:
				all_in = false
				break
		if all_in:
			level = at.authored_in
	# Each step's look goes with its parts (BookletLooks.follow): read before
	# ensure, which numbers the steps again when it gives a part put on since
	# a step, and a step whose parts were all taken off is a number with
	# nothing in it until then. Read after, the next step's parts had that
	# step's look (mcpwalk t2).
	var looked: Dictionary = BookletLooks.items_by_step(world, skip)
	var undo: Array = AuthorSteps.ensure(world, library, skip)
	var where: Array = _step_at(at)
	if op in ["earlier", "later"] and int(where[1]) >= 0:
		var blocked: String = AuthorSteps.blocked_swap(world, str(where[0]), int(where[1]),
			-1 if op == "earlier" else 1, skip)
		if not blocked.is_empty():
			_take_back(undo)
			return blocked
	# Any step, for the selection (steps3): one of the section they are in.
	if op == "to" and (int(where[1]) < 0
			or AuthorSteps.outside(world, ids, level, str(where[0]), skip) > 0):
		_take_back(undo)
		return "step %d builds %s, and the selection is not in it" % [number,
			"the " + at.assembly if not at.assembly.is_empty() else "another sub-model"]
	# What the edit takes out of its step: a step keeps its look with the
	# parts it keeps.
	var taken: Dictionary = {}
	if op in ["prev", "next", "new", "to"]:
		for items: Variant in AuthorSteps._selected(world, ids, level, skip).values():
			for item: Dictionary in items:
				taken[BookletLooks.item_name(item)] = true
	elif op == "delete" and int(where[1]) >= 0:
		for item: Dictionary in AuthorSteps.items_of(world, str(where[0]), skip):
			if int(item["step"]) == int(where[1]):
				taken[BookletLooks.item_name(item)] = true
	var count: int = ids.size()
	var words: String = ""
	match op:
		"prev", "next":
			undo.append_array(AuthorSteps.move(world, ids, -1 if op == "prev" else 1, level, skip))
			words = "moved %s to the %s step" % [_parts(count), "previous" if op == "prev" else "next"]
		"to":
			undo.append_array(AuthorSteps.move_to(world, ids, level, str(where[0]),
				int(where[1]), skip))
			# A step the selection left empty is taken out, and the step it
			# went to is numbered one less for each before it.
			var now: Array = AuthorSteps._selected(world, ids, level, skip).get(str(where[0]), [])
			if str(where[0]).is_empty() and not now.is_empty():
				number -= int(where[1]) - int((now[0] as Dictionary)["step"])
			words = "moved %s to step %d" % [_parts(count), number] if at.callout_step <= 0 \
				else "moved %s to the %s's step %d, in step %d" % [_parts(count), at.assembly,
					at.callout_step, number]
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
	undo.append_array(BookletLooks.follow(world, looked, skip, taken))
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


## A Booklet page command on the step the timeline is on.
func edit_look(op: String) -> void:
	if read_only:
		return
	if op == "lay_out":
		var editor: PageEditor = app.get("_page_editor")
		if editor != null:
			editor.open()
		return
	var steps: StepsBar = app.get("_steps")
	# A view turned on a callout's step poses that step apart from the
	# callout (BookletMaker._callout); the rest is for the page it is on.
	var view: bool = op.begins_with("turn") or op.begins_with("tilt") or op.ends_with("_view")
	bar.say(change_look(op, steps.current_step() if view else steps.booklet_step()))


## The edits of what is on a step's page (the page laid out by hand), which
## keep it with the step's room on the page (change_look's room=).
const PAGE_OPS: Array[String] = ["place", "text", "image", "note", "arrow", "arrow_edit"]


## How the booklet prints step [param at]: [param op] one of the Booklet
## page commands' (turn_left, zoom_in, new_page, ...), or "set" with
## [param fields] as BookletLooks keeps them (a session's edit_booklet).
## One undo, saved with the model; the first on a model with no steps of
## its own gives it the worked-out ones first, as a step edit does.
## Returns what was done, or why nothing was.
func change_look(op: String, at: Instructions.Step, fields: Dictionary = {}) -> String:
	if read_only:
		return "this model is open to look at, not to change"
	if at == null:
		return "go to a step on the timeline first"
	var steps: StepsBar = app.get("_steps")
	var number: int = at.number
	var skip: Dictionary = store.scenery
	# Giving the model's new parts their steps may number the steps again:
	# every step's look goes with its parts first, as a step edit's does.
	var looked: Dictionary = BookletLooks.items_by_step(world, skip)
	var undo: Array = AuthorSteps.ensure(world, library, skip)
	if not undo.is_empty():
		undo.append_array(BookletLooks.follow(world, looked, skip))
	var where: Array = _step_at(at)
	var section: String = str(where[0])
	var step: int = int(where[1])
	if step < 0:
		_take_back(undo)
		return "this step has no parts of its own to set"
	var name: String = BookletLooks.key(BookletLooks.definition_of(section), step)
	var own: Dictionary = BookletLooks.of(world, section, step)
	# The page by hand: what is on the step's page is kept with the room the
	# step has on it now (room=, from the page as laid out), so it goes with
	# the step when its page changes. What was placed in another room is
	# moved into this one first, where the page showed it.
	var room: Rect2 = BookletLooks.rect_of(fields["room"]) \
		if fields.get("room") is Array and op in PAGE_OPS else Rect2()
	if room.size.x > 0.0:
		own = BookletLooks.rebased(own, room)
	var turn: Dictionary = BookletLooks.turn_at(world, section, step)
	var by: Vector3 = BookletLooks._vector(turn.get("turn", [0, 0, 0]))
	var change: Dictionary = {}
	var words: String = ""
	var target: String = name
	match op:
		"set":
			if str(fields.get("turn", "")) == "usual":
				fields = fields.duplicate()
				var before: Dictionary = BookletLooks.turn_at(world, section, step - 1) \
					if step > 0 else {}
				fields["turn"] = "end" if not before.is_empty() else null
			if fields.has("callout"):
				var unit: String = _attached(at, section)
				if unit.is_empty():
					_take_back(undo)
					return "step %d puts no sub-assembly on" % number
				undo.append_array(BookletLooks.change(world,
					BookletLooks.definition_of(unit) + "|*", {"callout": fields["callout"]}))
				fields = fields.duplicate()
				fields.erase("callout")
			if fields.has("per_page"):
				undo.append_array(BookletLooks.change(world, BookletLooks.BOOKLET,
					{"per_page": fields["per_page"]}))
				fields = fields.duplicate()
				fields.erase("per_page")
			change = fields
			words = "set how step %d is printed" % number
		"turn_left", "turn_right":
			by.y = fposmod(by.y + (-45.0 if op == "turn_left" else 45.0) + 180.0, 360.0) - 180.0
			change = {"turn": [by.x, by.y, by.z], "how": str(turn.get("how", "REL"))}
			words = "step %d turned to %d°" % [number, roundi(by.y)]
		"tilt_up", "tilt_down":
			by.x = clampf(by.x + (15.0 if op == "tilt_up" else -15.0), -60.0, 45.0)
			change = {"turn": [by.x, by.y, by.z], "how": str(turn.get("how", "REL"))}
			words = "step %d seen from %d° %s" % [number, absi(roundi(by.x)),
				"higher" if by.x >= 0.0 else "lower"]
		"this_view":
			var seen: Array = BookletLooks.turn_for(camera.global_transform.basis.z) \
				if camera != null else [0.0, 0.0, 0.0]
			change = {"turn": seen, "how": "REL"}
			words = "step %d drawn from this view" % number
		"usual_view":
			var before: Dictionary = BookletLooks.turn_at(world, section, step - 1) \
				if step > 0 else {}
			change = {"turn": "end" if not before.is_empty() else null}
			words = "step %d from the usual angle" % number
		"zoom_in", "zoom_out":
			change = {"zoom": _next_of(BookletLooks.ZOOMS, float(own.get("zoom", 1.0)),
				1 if op == "zoom_in" else -1)}
			words = "step %d zoomed to %sx" % [number, BookletLooks._number(float(change["zoom"]))]
		"bigger", "smaller":
			change = {"size": _next_of(BookletLooks.SIZES, float(own.get("size", 1.0)),
				1 if op == "bigger" else -1)}
			words = "step %d drawn at %sx" % [number, BookletLooks._number(float(change["size"]))]
		"new_page", "alone":
			var page: String = "new" if op == "new_page" else "alone"
			var off: bool = str(own.get("page", "")) == page
			change = {"page": null if off else page}
			words = ("step %d " % number) + ("back with the steps before it" if off
				else ("starts a new page" if page == "new" else "on a page alone"))
		"parts":
			var shown: bool = bool(own.get("parts", true))
			change = {"parts": not shown}
			words = "step %d's parts list %s" % [number, "left off" if shown else "shown"]
		"callout":
			var unit: String = _attached(at, section)
			if unit.is_empty():
				_take_back(undo)
				return "step %d puts no sub-assembly on" % number
			var on: bool = BookletLooks.callout_on(world, unit)
			target = BookletLooks.definition_of(unit) + "|*"
			change = {"callout": not on}
			words = "the %s built %s" % [BookletLooks.definition_of(unit),
				"on pages of its own" if on else "in a callout box"]
		"guide":
			# A guide on every page of the booklet (BookletLooks "guides"),
			# dragged from the page editor's ruler: axis= "x" (upright, at x
			# mm) or "y"; at= where it goes, null to take it off; was= where
			# it was, to move one.
			var axis: String = str(fields.get("axis", ""))
			if not axis in ["x", "y"]:
				_take_back(undo)
				return "a guide is upright (axis x) or across (axis y)"
			var kept: Dictionary = BookletLooks.guides(world)
			var lines: Array = kept[axis]
			if fields.get("was") != null:
				var nearest: int = -1
				for index: int in lines.size():
					if absf(float(lines[index]) - float(fields["was"])) < 0.6 and (nearest < 0
							or absf(float(lines[index]) - float(fields["was"]))
							< absf(float(lines[nearest]) - float(fields["was"]))):
						nearest = index
				if nearest >= 0:
					lines.remove_at(nearest)
			var most: float = Booklet.PAGE.x if axis == "x" else Booklet.PAGE.y
			if fields.get("at") != null and float(fields["at"]) >= 0.0 and float(fields["at"]) <= most:
				lines.append(snappedf(float(fields["at"]), 0.1))
				words = "a guide %s at %s mm" % ["upright" if axis == "x" else "across",
					BookletLooks._number(snappedf(float(fields["at"]), 0.1))]
			else:
				words = "a guide taken off"
			target = BookletLooks.BOOKLET
			change = {"guides": kept}
		"per_page":
			var most: int = int(BookletLooks.booklet(world).get("per_page", 0))
			var next: int = int({0: 1, 1: 2, 2: 4, 4: 0}.get(most, 0))
			target = BookletLooks.BOOKLET
			change = {"per_page": next}
			words = "steps a page: %s" % ("as they fit" if next == 0 else str(next))
		"highlight":
			var on: bool = BookletLooks.highlight_on(world)
			if fields.has("highlight"):
				on = not bool(fields["highlight"])
			target = BookletLooks.BOOKLET
			change = {"highlight": not on}
			words = "the parts each step adds %s" % ("not outlined" if on else "outlined")
		"place":
			# An item of the step's page where it was dragged, in page mm
			# (BookletLooks "place"); at= null puts it back as laid out.
			var item: String = str(fields.get("item", ""))
			if not BookletLooks.ITEMS.has(item):
				_take_back(undo)
				return "the items of a step's page are %s" % ", ".join(BookletLooks.ITEMS.keys())
			var place: Dictionary = (own.get("place", {}) as Dictionary).duplicate(true)
			var spot: Variant = fields.get("at")
			if spot is Array and (spot as Array).size() >= int(BookletLooks.ITEMS[item]):
				var kept: Array = []
				for n: int in int(BookletLooks.ITEMS[item]):
					kept.append(snappedf(float(spot[n]), 0.1))
				place[item] = kept
				words = "step %d's %s at %s, %s mm" % [number, item,
					BookletLooks._number(kept[0]), BookletLooks._number(kept[1])]
			else:
				place.erase(item)
				words = "step %d's %s laid out by the booklet again" % [number, item]
			change = {"place": place}
		"text", "image":
			# Words, or a picture, put on the step's page (BookletLooks "notes").
			var notes: Array = (own.get("notes", []) as Array).duplicate(true)
			var given: Array = fields.get("at", []) if fields.get("at") is Array else []
			var spot: Array = []
			for n: int in 4:
				spot.append(snappedf(float(given[n]), 0.1) if n < given.size()
					else [20.0, 150.0, 80.0, 12.0][n])
			if op == "text":
				var said: String = str(fields.get("text", "")).strip_edges()
				if said.is_empty():
					_take_back(undo)
					return "say the words to put on the page"
				notes.append({"text": said, "at": spot,
					"size": clampf(float(fields.get("size", 4.0)), 1.5, 40.0)})
				words = "words put on step %d's page" % number
			else:
				var data: String = str(fields.get("data", ""))
				if data.is_empty():
					_take_back(undo)
					return "a picture to put on the page"
				var pictures: Dictionary = BookletLooks.images(world).duplicate()
				var made: int = pictures.size() + 1
				var file: String = ""
				while file.is_empty() or pictures.has(file):
					file = "%s%d.%s" % [BookletLooks.IMAGE_PREFIX, made,
						"png" if str(fields.get("kind", "png")) == "png" else "jpg"]
					made += 1
				pictures[file] = data
				undo.append_array(BookletLooks.set_images(world, pictures))
				notes.append({"image": file, "at": spot})
				words = "a picture put on step %d's page" % number
			change = {"notes": notes}
		"sign":
			# The turn sign taken off the step, or put back (BookletLooks
			# "sign"); sign= says which, else it turns over.
			var shown: bool = bool(own.get("sign", true))
			if fields.has("sign"):
				shown = not bool(fields["sign"])
			change = {"sign": not shown}
			words = "step %d's turn sign %s" % [number, "taken off" if shown else "put back"]
		"arrow":
			# An arrow drawn on the step's page (BookletLooks "arrows"): at= [x1,
			# y1, x2, y2] or with a bend [..., bx, by], colour=, width=.
			var given: Array = fields.get("at", []) if fields.get("at") is Array else []
			if given.size() < 4:
				_take_back(undo)
				return "an arrow needs where it starts and where it points: x1, y1, x2, y2 in mm"
			var arrows: Array = (own.get("arrows", []) as Array).duplicate(true)
			var arrow: Dictionary = _arrow_of(given, str(fields.get("colour", "red")),
				float(fields.get("width", 0.9)))
			arrows.append(arrow)
			change = {"arrows": arrows}
			words = "%s drawn on step %d's page" % [BookletLooks.arrow_said(arrow), number]
		"arrow_edit":
			# One of the arrows on the step's page moved, bent, straightened,
			# recoloured, made wider or narrower, or taken off: index= which.
			var arrows: Array = (own.get("arrows", []) as Array).duplicate(true)
			var index: int = int(fields.get("index", -1))
			if index < 0 or index >= arrows.size():
				_take_back(undo)
				return "step %d's page has %d arrows of its own" % [number, arrows.size()]
			var arrow: Dictionary = arrows[index]
			if bool(fields.get("remove", false)):
				arrows.remove_at(index)
				words = "an arrow taken off step %d's page" % number
			else:
				var points: Array = fields["at"] if fields.get("at") is Array \
					and (fields["at"] as Array).size() >= 4 else arrow["at"]
				arrow = _arrow_of(points, str(fields.get("colour", arrow.get("colour", "red"))),
					float(fields.get("width", arrow.get("width", 0.9))))
				arrows[index] = arrow
				words = "step %d's arrow now %s" % [number, BookletLooks.arrow_said(arrow)]
			change = {"arrows": arrows}
		"note":
			# One of the words or pictures on the step's page moved, resized,
			# reworded or taken off: index= which.
			var notes: Array = (own.get("notes", []) as Array).duplicate(true)
			var index: int = int(fields.get("index", -1))
			if index < 0 or index >= notes.size():
				_take_back(undo)
				return "step %d's page has %d of its own words and pictures" % [number, notes.size()]
			var note: Dictionary = notes[index]
			if bool(fields.get("remove", false)):
				notes.remove_at(index)
				words = "%s taken off step %d's page" % ["words" if note.has("text") else "a picture",
					number]
				if note.has("image"):
					var pictures: Dictionary = BookletLooks.images(world).duplicate()
					pictures.erase(str(note["image"]))
					undo.append_array(BookletLooks.set_images(world, pictures))
			else:
				if fields.get("at") is Array and (fields["at"] as Array).size() >= 4:
					note["at"] = (fields["at"] as Array).slice(0, 4).map(
						func(value: Variant) -> float: return snappedf(float(value), 0.1))
				if fields.has("text") and note.has("text"):
					note["text"] = str(fields["text"]).strip_edges()
				if fields.has("size") and note.has("text"):
					note["size"] = clampf(float(fields["size"]), 1.5, 40.0)
				# Turned about its middle and faded, as Studio's page objects are.
				for field: String in ["turn", "opacity"]:
					if fields.has(field):
						note[field] = snappedf(BookletLooks.turn_of({"turn": fields[field]}), 0.1) \
							if field == "turn" else snappedf(BookletLooks.opacity_of(
								{"opacity": fields[field]}), 0.01)
						if note[field] == (0.0 if field == "turn" else 1.0):
							note.erase(field)
				words = "step %d's %s changed" % [number, "words" if note.has("text") else "picture"]
				if fields.has("turn"):
					words = "step %d's %s turned to %s°" % [number, "words" if note.has("text")
						else "picture", BookletLooks._number(BookletLooks.turn_of(note))]
				elif fields.has("opacity"):
					words = "step %d's %s at %d%% opacity" % [number, "words" if note.has("text")
						else "picture", roundi(BookletLooks.opacity_of(note) * 100.0)]
			change = {"notes": notes}
		_:
			_take_back(undo)
			return "no booklet edit called %s" % op
	if room.size.x > 0.0:
		var any: bool = false
		for field: String in ["place", "notes", "arrows"]:
			if not change.has(field) and own.has(field):
				change[field] = own[field]
			var now: Variant = change.get(field)
			if (now is Dictionary or now is Array) and not now.is_empty():
				any = true
		change["panel"] = own.get("panel", BookletLooks.said_rect(room)) if any else null
	if not change.is_empty():
		undo.append_array(BookletLooks.change(world, target, change))
	undo = AuthorSteps.squash(undo)
	if undo.is_empty():
		return "step %d is printed as it was" % number
	builder.record(undo, words)
	store.adopt()
	store.touch()
	steps.refresh(number, at.callout_step)
	# Seen as the booklet will draw it.
	if camera != null and (op.begins_with("turn") or op.begins_with("tilt")
			or op == "usual_view" or op == "set" and fields.has("turn")):
		var now: Dictionary = BookletLooks.turn_at(world, section, step)
		camera.look_from(BookletLooks.direction(now) if not now.is_empty()
			else BookletStudio.FRONT)
	return words


## Many steps' pages laid out at once, as one undo: the page editor's
## Apply to later pages and edit_booklet's follow= (PageEditor
## .later_layout). [param placed] is [[step, place, room]]: what the step
## has placed, {item: [x, y, ...]} as "place" keeps it, in place of what it
## had, in its room on its page now ([x, y, w, h]), where its own words,
## pictures and arrows are moved to first, as change_look moves them.
func place_pages(placed: Array, words: String) -> String:
	if read_only:
		return "this model is open to look at, not to change"
	var undo: Array = []
	var first: int = -1
	for one: Array in placed:
		var at: Instructions.Step = one[0]
		var where: Array = _step_at(at)
		if int(where[1]) < 0:
			continue
		var section: String = str(where[0])
		var step: int = int(where[1])
		var room: Rect2 = BookletLooks.rect_of(one[2])
		var own: Dictionary = BookletLooks.rebased(BookletLooks.of(world, section, step), room)
		var change: Dictionary = {"place": one[1], "notes": own.get("notes"),
			"arrows": own.get("arrows")}
		var any: bool = not (one[1] as Dictionary).is_empty() or own.has("notes") or own.has("arrows")
		change["panel"] = BookletLooks.said_rect(room) if any else null
		undo.append_array(BookletLooks.change(world,
			BookletLooks.key(BookletLooks.definition_of(section), step), change))
		if first < 0:
			first = at.number
	undo = AuthorSteps.squash(undo)
	if undo.is_empty():
		return "the pages were laid out so already"
	builder.record(undo, words)
	store.adopt()
	store.touch()
	(app.get("_steps") as StepsBar).refresh(first)
	return words


## An arrow as a look keeps it: its points to a tenth of a mm (a bend kept
## only where it bends the line by a millimetre or more), its colour one a
## booklet uses and its width the nearest it comes in.
static func _arrow_of(at: Array, colour: String, width: float) -> Dictionary:
	var numbers: Array = []
	for n: int in mini(at.size() - at.size() % 2, (BookletLooks.MOST_BENDS + 2) * 2):
		numbers.append(snappedf(float(at[n]), 0.1))
	var points: Array = BookletLooks.arrow_points({"at": numbers})
	if not points.is_empty():
		# A bend within a millimetre of the line between its neighbours bends
		# nothing: dragged back straight, it is gone.
		var bends: Array = []
		var through: Array = [points[0]] + (points[2] as Array) + [points[1]]
		for index: int in range(1, through.size() - 1):
			var before: Vector2 = bends[-1] if not bends.is_empty() else through[0]
			var bend: Vector2 = through[index]
			if bend.distance_to(Geometry2D.get_closest_point_to_segment(bend, before,
					through[index + 1])) >= 1.0:
				bends.append(bend)
		numbers = BookletLooks.arrow_at([points[0], points[1], bends])
	return {"at": numbers, "colour": colour.to_lower() if BookletLooks.ARROW_COLOURS.has(colour.to_lower())
		else "red", "width": BookletLooks.arrow_width(width)}


## An edit's first half put back when its second is refused: a model given
## the worked-out steps to be edited, and then not edited, keeps none.
func _take_back(undo: Array) -> void:
	for index: int in range(undo.size() - 1, -1, -1):
		builder._apply(undo[index])


## The next of [param values] after [param now], up or down, kept at the ends.
static func _next_of(values: Array[float], now: float, by: int) -> float:
	var at: int = 0
	for index: int in values.size():
		if values[index] <= now + 0.001:
			at = index
	if by < 0 and values[at] < now - 0.001:
		return values[at]
	return values[clampi(at + by, 0, values.size() - 1)]


## The sub-assembly step [param at] puts on, as a path inside [param
## section], or "".
func _attached(at: Instructions.Step, section: String) -> String:
	return BookletLooks.attached(world, at, section)


static func _parts(count: int) -> String:
	return "1 part" if count == 1 else "%d parts" % count


## Edit, Next step: what was put down in [param level] since its last step
## made a step, one undo, said with its number as the timeline counts it.
func _close_step(level: String, skip: Dictionary) -> String:
	var undo: Array = AuthorSteps.close_step(world, level, skip)
	var made: int = AuthorSteps.steps_in(world, level, skip).size()
	if undo.is_empty():
		return ("step %d is done: the next part starts step %d" % [made, made + 1]) \
			if made > 0 else "put a part down first: a step is the parts put down since the last"
	var count: int = 0
	for entry: Dictionary in undo:
		count += 1 if entry.has("brick") else 0
	var words: String = "step %d: %s; the next part starts step %d" % [made,
		_parts(count), made + 1]
	builder.record(undo, words)
	store.adopt()
	store.touch()
	(app.get("_steps") as StepsBar).refresh()
	return words


## Where the timeline's step is among the author's: [section, step], or
## ["", -1]. Read off its first part when it was a worked-out step, which
## giving the model its steps has just made one of the author's.
func _step_at(at: Instructions.Step) -> Array:
	if at == null:
		return ["", -1]
	# Read off its parts as they are now: giving the model's new parts their
	# steps (AuthorSteps.ensure) numbers the steps again where a step's parts
	# were all taken off, and the number the timeline had was the next step's.
	if at.authored_step >= 0 and not at.brick_ids.is_empty():
		var own: BrickWorld.Brick = world.get_brick(at.brick_ids[0])
		if own != null and own.step >= 0 and Assemblies.path_of(own) == at.authored_in:
			return [at.authored_in, own.step]
	if at.authored_step >= 0:
		var unit: String = BookletLooks.attached(world, at, at.authored_in)
		if not unit.is_empty() and world.unit_steps.has(unit):
			return [at.authored_in, int(world.unit_steps[unit])]
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
	return false


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
	if library_dialog != null:
		out.merge(library_dialog.controls_by_name())
	var parts_list: Variant = app.get("_inventory") if app != null else null
	if parts_list is InventoryPanel:
		out.merge((parts_list as InventoryPanel).controls_by_name())
	if see_inside != null:
		out.merge(see_inside.controls_by_name())
	if stress != null and stress.panel != null:
		out.merge(stress.panel.controls_by_name())
	if versions != null:
		out.merge(versions.controls_by_name())
	if compare != null:
		out.merge(compare.controls_by_name())
	if palette != null:
		out.merge(palette.controls_by_name())
	if first_build != null:
		out.merge(first_build.controls_by_name())
	# Save as's question, for tools/web/dialogs_flow.mjs.
	if _save_as != null and _save_as.visible:
		out["save_as_name"] = _save_as_name
		out["save_as_ok"] = _save_as.get_ok_button()
		out["save_as_cancel"] = _save_as.get_cancel_button()
	if feedback != null:
		out.merge(feedback.controls_by_name())
	# About's links to the licences in full, and the licence open.
	if _about != null and _about.visible:
		out["about_ok"] = _about.get_ok_button()
		for one: Dictionary in Credits.LIST:
			var read: Node = _about.find_child("read_" + str(one["id"]), true, false)
			if read != null:
				out["about_" + read.name] = read
	if _licence != null and _licence.visible:
		out["licence_text"] = _licence_text
		out["licence_close"] = _licence.get_ok_button()
	return out


## A menu on the bar by its title, for a probe to open.
func menu(title: String) -> MenuButton:
	for button: MenuButton in _menus:
		if button.text == title:
			return button
	return null


## The id a command has in the menus, for a probe to press it there; -1 while
## it is in none. Its id stays when the assistant is turned off (set_assistant),
## so the id alone does not say it is there.
func menu_id(name: String) -> int:
	return _ids.find(name) if not _shown([name]).is_empty() else -1
