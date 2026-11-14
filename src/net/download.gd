## Handing a file to the person, on both kinds of build.
##
## On the desktop this is a write to their Downloads folder, or where they
## choose when they pressed for it ([method save]). In a browser
## a page cannot write to disk at all, so the bytes go to the browser as
## a download instead. Same file, two entirely different mechanisms, and
## every caller that needs one needs the other — which is why this is not
## left at each call site to remember.
class_name Download
extends RefCounted


## Where a file handed over on the desktop goes: their Downloads folder, or
## [member folder] when set (a probe points it at a scratch folder, so that
## timing every command never writes into a person's Downloads).
static var folder: String = ""


## A run that is not the person's own app (Outside.held) writes into a
## folder of its own data instead, as it opens no link: an MCP session's
## render from the app an agent started for appux3's walk landed in the
## owner's own ~/Downloads (2026-10-30). Every file the app writes without
## asking comes through here.
static func downloads() -> String:
	if not folder.is_empty():
		return folder
	if Outside.held():
		var own: String = OS.get_user_data_dir().path_join("downloads")
		DirAccess.make_dir_recursive_absolute(own)
		return own
	var found: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	return found if not found.is_empty() else OS.get_user_data_dir()


## Returns a line to show the person, which differs by platform because
## the outcome does: on the desktop there is a path they can go and look
## at, and in a browser there is not.
static func give(text: String, file_name: String, mime: String = "text/plain") -> String:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, mime)
		return "downloaded %s" % file_name

	var into: String = downloads()
	# The name comes from the model's title, which a design names: only
	# its last part, so no title can put a file outside the folder.
	return _write(text, unused(into.path_join(file_name.replace("\\", "/").get_file())))


## [param path], or on the desktop the next name beside it nothing has when
## something is there already: pods_render.png, then pods_render_2.png,
## pods_render_3.png. Every file the app writes where nobody was asked
## takes one, so nothing of the person's is written over unasked: a
## session's picture and its 3MF each replaced the last of their name without
## a word (APP_UX8's MCP walk, x4 and x5; mcpreach). An underscore, as every
## name the app gives a file joins its words (SubmodelFile.titled), so a
## script or a slicer's command line takes it whole. [param beside]: what is
## written under the same name with another ending, each free too (an OBJ's
## ".mtl"). A browser numbers its own downloads, so there it is [param path].
static func unused(path: String, beside: PackedStringArray = PackedStringArray()) -> String:
	if OS.has_feature("web"):
		return path
	var dot: String = _dot(path)
	var endings := PackedStringArray([dot])
	endings.append_array(beside)
	return free_stem(path.left(path.length() - dot.length()), endings) + dot


## [param stem] (a path without its ending), or the next free one, "_2",
## "_3", when a file or a folder is there under it with any of
## [param endings] ("" the stem itself): a turntable's .webp, .gif, .mp4
## and its frames' folder are one name (RenderOutput).
static func free_stem(stem: String, endings: PackedStringArray) -> String:
	if OS.has_feature("web"):
		return stem
	var named: String = stem
	var n: int = 2
	while not _there(named, endings).is_empty():
		named = "%s_%d" % [stem, n]
		n += 1
	if named != stem:
		_was[named] = _there(stem, endings)
	return named


## The first file or folder there under [param stem] with one of
## [param endings], by its name; "" for none.
static func _there(stem: String, endings: PackedStringArray) -> String:
	for ending: String in endings:
		if FileAccess.file_exists(stem + ending) or DirAccess.dir_exists_absolute(stem + ending):
			return (stem + ending).get_file()
	return ""


## ".png" of a path's file name, "" when it has none.
static func _dot(path: String) -> String:
	var file: String = path.get_file()
	return "." + file.get_extension() if file.contains(".") else ""


## What was there under the name each stem [method free_stem] gave in its
## place was taken from: the chosen stem -> that file's name.
static var _was: Dictionary = {}


## What to say after "wrote [param path]" when [method unused] or
## [method free_stem] gave it a name of its own: " — pods_render.png was
## there already, and is kept", so the person and a session hear that the
## earlier file is still there; "" when it took the name asked. Said once,
## with the first file written under the name.
static func kept_note(path: String) -> String:
	var stem: String = path.left(path.length() - _dot(path).length())
	if not _was.has(stem):
		return ""
	var earlier: String = str(_was[stem])
	_was.erase(stem)
	return " — %s was there already, and is kept" % earlier


## [method give] from a person's own press: on the desktop written where
## they choose (SaveTo), and "" when they cancel.
static func save(text: String, file_name: String, mime: String = "text/plain") -> String:
	if OS.has_feature("web"):
		return give(text, file_name, mime)
	var path: String = await SaveTo.ask(file_name)
	return _write(text, path) if not path.is_empty() else ""


static func _write(text: String, path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s (%d)" % [path, FileAccess.get_open_error()])
		return "could not write %s" % path.get_file()
	file.store_string(text)
	file.close()
	SaveTo.wrote(path)
	return "wrote %s%s" % [path, kept_note(path)]
