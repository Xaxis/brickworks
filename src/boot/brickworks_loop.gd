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
## Without the flag this does nothing and costs one small script's compile:
## the app starts as before, on the desktop and on the web. A probe given
## with --script is its own main loop, so this never runs under one.
class_name BrickworksLoop
extends SceneTree

const THUMBNAIL := "res://src/render/model_thumbnail.gd"
const FLAG := "--thumbnail"

## The scene loaded in the main scene's place, held so the cache keeps it.
var _stand_in: PackedScene = null


func _init() -> void:
	if not asked_for_a_picture():
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
