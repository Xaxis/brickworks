## Handing a file to the person, on both kinds of build.
##
## On the desktop this is a write to their Downloads folder. In a browser
## a page cannot write to disk at all, so the bytes go to the browser as
## a download instead. Same file, two entirely different mechanisms, and
## every caller that needs one needs the other — which is why this is not
## left at each call site to remember.
class_name Download
extends RefCounted


## Returns a line to show the person, which differs by platform because
## the outcome does: on the desktop there is a path they can go and look
## at, and in a browser there is not.
static func give(text: String, file_name: String, mime: String = "text/plain") -> String:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, mime)
		return "downloaded %s" % file_name

	var folder: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if folder.is_empty():
		folder = OS.get_user_data_dir()
	var path: String = folder.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s (%d)" % [path, FileAccess.get_open_error()])
		return "could not write %s" % file_name
	file.store_string(text)
	file.close()
	return "wrote %s" % path
