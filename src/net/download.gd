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
	return _write(text, into.path_join(file_name.replace("\\", "/").get_file()))


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
	return "wrote %s" % path
