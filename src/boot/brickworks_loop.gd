## The app's main loop: the engine's own SceneTree, which, asked for a
## picture of a model file (ModelThumbnail.FLAG), draws it and quits without
## starting the app.
##
## The engine makes its main loop before it loads the main scene, and loading
## main.tscn compiles main.gd and nearly every script it names: 3.5 s of the
## installed 0.17.0's start on this box, before a line of the app ran, where a
## file browser waits a few seconds for a picture. An official export template
## takes no other way in: it refuses --script and a scene on the command line
## ("compiled without support for path overrides", measured on 0.17.0). So
## here, given the flag, a scene of one empty node takes the main scene's
## place in the resource cache, the engine loads that instead, and the
## picture is drawn once the loop begins.
##
## Without the flag it compiles the first screen a cycle at a time, where
## the export says how (FIRST_ORDER), and the app starts as before. A probe
## given with --script is its own main loop, so this never runs under one.
class_name BrickworksLoop
extends SceneTree

const THUMBNAIL := "res://src/render/model_thumbnail.gd"
const FLAG := "--thumbnail"
## The first screen's scripts, a script a line, each named after every one
## it names (tools/web/start_closure.py compile_order), written by the web
## export and kept in the pack the engine waits for (tools/web/pck_split.py).
##
## Loading main.tscn compiled all 214 of the first screen's scripts in one
## load, and Godot holds the parse of every script a load compiles until the
## load ends: that was the whole of the page's 432 MB of Wasm memory at the
## start, which a page keeps for good and an iPhone gives about 300 of. Loaded
## a cycle at a time, the largest single compile is the scripts that name
## each other round (78% of them). In pairs at the same moment (webstart12,
## 2026-11-19) the Wasm's height went 432 -> 360 MB on WebKit as an iPhone 13
## and in Chromium, and WebKit started sooner (scripts 7.4 -> 6.4 s, working
## 19.4 -> 17.3); but at a quarter CPU Chromium's scripts took 25.5 s, not
## 22.5: each load parses again what it names that an earlier load compiled.
## So an iPhone or iPad compiles so, where the memory is what is short (the
## shell's own test of one, src/boot/shell.html "apple"), and everything
## else as one. Without the file (a desktop build, a checkout never
## exported) main.tscn compiles them all.
const FIRST_ORDER := "res://assets/web/first_order.txt"

## The scene loaded in the main scene's place, held so the cache keeps it.
var _stand_in: PackedScene = null


func _init() -> void:
	if not asked_for_a_picture():
		compile_first_screen()
		return
	var empty := Node.new()
	empty.name = "Thumbnail"
	_stand_in = PackedScene.new()
	_stand_in.pack(empty)
	empty.free()
	_stand_in.take_over_path(str(ProjectSettings.get_setting("application/run/main_scene")))


func _initialize() -> void:
	if _stand_in == null:
		return
	var drawer: GDScript = load(THUMBNAIL)
	quit(int(drawer.call(&"run", OS.get_cmdline_args() + OS.get_cmdline_user_args())))


static func asked_for_a_picture() -> bool:
	return OS.get_cmdline_args().has(FLAG) or OS.get_cmdline_user_args().has(FLAG)


## The first screen's scripts loaded in FIRST_ORDER's order, before the
## engine loads the main scene: its compile, a cycle at a time. Main.gd,
## last, then finds them all made ("compiled", Main._boot_mark).
##
## Its begin and end are marked on the page as Main's own marks are
## (window.brickworksBoot "layered" and "layers"), so a start timed by
## tools/web/start_phases.mjs says what the cycles took apart from main.gd's
## own compile and whether they ran at all (webstart13). Named here, not
## through Main, which this script must not name: that would compile the
## whole first screen in one load before this runs.
static func compile_first_screen() -> void:
	if not FileAccess.file_exists(FIRST_ORDER) or not _apple():
		return
	_mark("layered")
	for path: String in FileAccess.get_file_as_string(FIRST_ORDER).split("\n", false):
		if path.begins_with("res://") and ResourceLoader.exists(path):
			load(path)
	_mark("layers")


## [param stage] reached, on the page's clock: Main._boot_mark's, for the web.
static func _mark(stage: String) -> void:
	JavaScriptBridge.eval("(window.brickworksBoot = window.brickworksBoot || {})[%s] = performance.now()"
		% JSON.stringify(stage), true)


## An iPhone or iPad's browser, as the shell tells one: an iPad asking for
## the desktop site says it is a Mac, and a Mac has no touch points.
static func _apple() -> bool:
	return OS.has_feature("web") and bool(JavaScriptBridge.eval(
		"/iPhone|iPad|iPod/.test(navigator.userAgent) || "
		+ "(/Macintosh/.test(navigator.userAgent) && navigator.maxTouchPoints > 1)", true))
