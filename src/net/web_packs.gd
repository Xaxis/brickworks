## What the web build keeps apart from the pack the engine waits for
## (tools/web/pck_split.py), fetched by the page (src/boot/shell.html) and
## written into the engine's files under [constant DIR].
##
## A first visit waited for one pack of 8.4 MB before the engine said a
## word, and most of it was not code (webload, 2026-10-30). Now the engine
## waits for the code alone and compiles it while the rest comes:
##
##   [constant DATA]: what the start reads (the catalogue, the models,
##   LDraw's tables), a pack mounted before the catalogue (main.gd's _ready).
##   [constant PRIMITIVES]: LDraw's primitives, the files themselves, read
##   where they are written ([method primitive]), fetched the first time a
##   part is built from LDraw's text (CustomParts, PartForge).
##   [constant HDRI]: Studio's photographed light, each panorama's texture
##   read where it is written ([method hdri]), fetched the first time Studio
##   lights a picture by one (StudioRender).
##
## Only [constant DATA] is a pack: it is mounted before any worker opens a
## file. A pack mounted while the app runs changes the engine's table of
## files while a worker may be reading it. Elsewhere than the web, and in a
## web build whose pack was not split, everything is in res:// and nothing
## is waited for.
class_name WebPacks
extends RefCounted

const DIR := "/packs/"
const DATA := "data"
const PRIMITIVES := "primitives"
const HDRI := "hdri"
## A file each is whole without: how a build that was not split is told.
const _IN_THE_PACK: Dictionary = {
	DATA: "res://assets/web/catalogue.json",
	PRIMITIVES: "res://assets/ldraw/p/stud.dat",
	HDRI: "res://assets/hdri/studio_small_09.hdr",
}

## Those mounted or found here, by name; those that came and would not
## mount. The page's thread only.
static var _here: Dictionary = {}
static var _broken: Dictionary = {}
static var _asked: Dictionary = {}


## Whether [param name] can be read now.
static func here(name: String) -> bool:
	if _here.has(name) or not OS.has_feature("web"):
		return true
	var whole: String = str(_IN_THE_PACK.get(name, ""))
	var in_the_pack: bool = ResourceLoader.exists(whole) if name == HDRI else FileAccess.file_exists(whole)
	if in_the_pack:
		_here[name] = true
		return true
	if _broken.has(name) or not FileAccess.file_exists(DIR + name + ".here"):
		return false
	if name == DATA and not ProjectSettings.load_resource_pack(DIR + "index.data.pck", false):
		push_error("WebPacks: %sindex.data.pck came but would not mount" % DIR)
		_broken[name] = true
		return false
	_here[name] = true
	return true


## Ask the page for [param name], once: it is fetched and written while
## the app goes on. The page's thread only (a worker cannot ask the page).
static func ask(name: String) -> void:
	if _asked.has(name) or here(name):
		return
	_asked[name] = true
	JavaScriptBridge.eval("window.brickworksPack && window.brickworksPack(%s)" % JSON.stringify(name), true)


## Ask for [param name] and wait for it, a frame at a time: true once it
## can be read, false once the page has given up on it (its state is
## window.brickworksPacks[name], which says why).
static func need(name: String) -> bool:
	ask(name)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while not here(name):
		if tree == null or _broken.has(name) or _given_up(name):
			return false
		await tree.process_frame
	return true


static func _given_up(name: String) -> bool:
	return bool(JavaScriptBridge.eval(
		"!!(window.brickworksPacks && window.brickworksPacks[%s] && window.brickworksPacks[%s].gave_up)"
		% [JSON.stringify(name), JSON.stringify(name)], true))


## Where LDraw's primitive [param key] (normalised, under p/) is written on
## the web once [constant PRIMITIVES] has come, or "" elsewhere. Safe on
## any thread: it only names the place.
static func primitive(key: String) -> String:
	return DIR + PRIMITIVES + "/" + key if OS.has_feature("web") else ""


## The panorama [param path] (res://assets/hdri/...) as it can be loaded:
## itself where the build has it, or on the web its texture where
## [constant HDRI] is written.
static func hdri(path: String) -> String:
	if not OS.has_feature("web") or ResourceLoader.exists(path):
		return path
	return DIR + HDRI + "/" + path.get_file() + ".ctex"
