## The app's features that its first screen does not need, reached by name
## and loaded the first time something asks for one.
##
## Loading a script compiles every script it names, and theirs, before it
## runs a line (GDScriptCache::finish_compiling). main.gd named 147 classes
## and nearly all of the app's 310 scripts named each other in one cycle,
## so a first visit to the web app compiled all of them, 19.8 MB of tokens,
## before it drew anything: 3.6 s of a warm start's 8.2 on the box, and
## most of a cold start's "scripts" (webstart, 2026-10-30). The assistant
## alone was a quarter of it.
##
## So the first screen's code (main.gd and what it names) never names a
## class in [constant PATHS]: it asks for one here, by that class's name,
## and gets the script, made the first time. A class here may name any
## other, and the core's classes freely; it is only the core naming one of
## these that would bring the compile back, and tests/test_later.py fails
## when it does.
##
## Typed code keeps its types where the core can give one: a variable that
## holds a dialog is a Window, a panel a Control, a helper a RefCounted.
## What a feature does beyond its base is called by name, so a call
## that is misspelled is found when it runs, not when it compiles: the
## probes that drive each feature are what keep those honest.
class_name Later
extends RefCounted

## Each class reached here, by its class_name, and its script.
const PATHS: Dictionary[StringName, String] = {
	# The assistant and what designs with it.
	&"Assistant": "res://src/ai/assistant.gd",
	&"BestOfTwo": "res://src/ai/best_of_two.gd",
	&"DesignerLoop": "res://src/ai/designer_loop.gd",
	&"ModelShot": "res://src/ai/model_shot.gd",
	&"SelectionScope": "res://src/ai/selection_scope.gd",
	&"Sketches": "res://src/ai/sketches.gd",
	&"Style": "res://src/ai/style.gd",
	&"Techniques": "res://src/ai/techniques.gd",
	# Its panel, Claude connected to the tab, and the MCP tools both answer.
	&"ChatPanel": "res://src/ui/chat_panel.gd",
	&"ClaudeConnector": "res://src/net/claude_connector.gd",
	&"CommandSocket": "res://src/net/command_socket.gd",
	# The panels and dialogs over the model and in its columns.
	&"BrickifyDialog": "res://src/ui/brickify_dialog.gd",
	&"ControlsDialog": "res://src/ui/controls_dialog.gd",
	&"ElementDialog": "res://src/ui/element_dialog.gd",
	&"HiddenColoursPanel": "res://src/ui/hidden_colours_panel.gd",
	&"InventoryPanel": "res://src/ui/inventory_panel.gd",
	&"MinifigDialog": "res://src/ui/minifig_dialog.gd",
	&"MosaicDialog": "res://src/ui/mosaic_dialog.gd",
	&"PageEditor": "res://src/ui/page_editor.gd",
	&"PhoneShell": "res://src/ui/phone_shell.gd",
	&"PinsDialog": "res://src/ui/pins_dialog.gd",
	&"PosePanel": "res://src/ui/pose_panel.gd",
	&"PrintStudio": "res://src/prints/print_studio.gd",
	&"RenderDialog": "res://src/ui/render_dialog.gd",
	&"SavedModelsDialog": "res://src/ui/saved_models_dialog.gd",
	&"SharePanel": "res://src/ui/share_panel.gd",
	&"ShareView": "res://src/ui/share_view.gd",
	&"SimulatePanel": "res://src/ui/simulate_panel.gd",
	&"TogetherDialog": "res://src/ui/together_dialog.gd",
	# What they make: Brick Art, figures, motions played, the booklet.
	&"BookletMaker": "res://src/render/booklet_maker.gd",
	&"BookletOut": "res://src/net/booklet_out.gd",
	&"BookletPdf": "res://src/render/booklet_pdf.gd",
	&"BookletPng": "res://src/render/booklet_png.gd",
	&"BookletRead": "res://src/render/booklet_read.gd",
	&"FigureTool": "res://src/minifig/figure_tool.gd",
	&"HeldSteps": "res://src/assembly/held_steps.gd",
	&"MosaicArt": "res://src/assembly/mosaic_art.gd",
	&"MotionPlayer": "res://src/assembly/motion_player.gd",
	&"Tested": "res://src/assembly/tested.gd",
}

## How long each one took to load, in ms, by name, from the first ask:
## what a probe reads to see that the start loaded none of them.
static var took: Dictionary[StringName, int] = {}
## A worker may be the first to ask for one.
static var _lock: Mutex = Mutex.new()


## The script of [param name], loaded and compiled the first time.
static func script(name: StringName) -> GDScript:
	var path: String = PATHS[name]
	if ResourceLoader.has_cached(path):
		return load(path)
	var started: int = Time.get_ticks_msec()
	var loaded: GDScript = load(path)
	_lock.lock()
	if not took.has(name):
		took[name] = Time.get_ticks_msec() - started
	_lock.unlock()
	return loaded


## A new [param name], made with no arguments.
static func make(name: StringName) -> Object:
	return script(name).new()


## Whether [param name] has been loaded: what has nothing to say to a
## feature nobody has opened asks this first, so as not to load it.
static func loaded(name: StringName) -> bool:
	return ResourceLoader.has_cached(PATHS[name])


## [code]thing is name[/code], for a class the core cannot name: false
## for null, and without loading a class nothing has made one of.
static func is_a(thing: Object, name: StringName) -> bool:
	return thing != null and loaded(name) and is_instance_of(thing, script(name))
