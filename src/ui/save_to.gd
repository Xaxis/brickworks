## Asking a person where a file of theirs goes, on the desktop.
##
## The platform's own Save dialog (FileDialog.use_native_dialog): the
## desktop portal's on Linux, the save panel on macOS, the common file
## dialog on Windows. Each asks before it writes over a file already there;
## so does Godot's own, which is shown instead where the system has no
## portal. It opens in the folder the last file went to, or Documents, with
## the file's name filled in. walk180 (2026-10-23): an .io and the booklet
## went straight into ~/Downloads, with no dialog and nothing on screen
## saying where.
##
## The file written is then the one the status bar offers to show in its
## folder (StatusBar), for as long as the line naming it is up.
class_name SaveTo
extends RefCounted

## The platform's dialog; false is Godot's own, which a probe can answer.
## A probe turns it off: the portal's would open on the desktop its bus
## belongs to, not in the probe's Xvfb, and nothing could answer it there.
static var native: bool = true
## The dialog up now, for a probe to answer; null when none is.
static var showing: FileDialog = null
## The file last written for the person: what Show in folder shows.
static var shown: String = ""
## How a file is opened and shown in its folder: Outside's, which opens
## nothing in a probe. A probe hands in one that fails, to see what is said
## when no browser can be opened.
static var open_with: Callable = Callable(Outside, "open_link")
static var show_with: Callable = Callable(Outside, "show_in_folder")

## What each kind of file is called in the dialog's list of types.
const KINDS: Dictionary = {
	"ldr": "LDraw model", "mpd": "LDraw model with its sub-models",
	"io": "BrickLink Studio model", "glb": "glTF binary", "gltf": "glTF",
	"obj": "OBJ with its colours", "stl": "STL", "png": "PNG picture",
	"xml": "BrickLink wanted list", "csv": "Parts list (CSV)", "txt": "Parts list (text)",
	"html": "Instructions (web page)", "pdf": "PDF document", "zip": "Zip archive",
}


## Whether [method ask] shows a dialog: on the desktop, unless a probe
## pointed every file at a folder of its own (Download.folder).
static func asks() -> bool:
	return not OS.has_feature("web") and Download.folder.is_empty()


## Where [param file_name] goes: the path the person chose, or "" when they
## cancelled. Into [param into], or Download.folder, without asking when
## either is set: a probe's own folder, or where a session's export goes.
static func ask(file_name: String, into: String = "", title: String = "Export") -> String:
	var name: String = file_name.replace("\\", "/").get_file()
	var folder: String = into if not into.is_empty() else Download.folder
	if not folder.is_empty():
		return folder.path_join(name)
	# One at a time: a second export while one is asked waits for none.
	if showing != null:
		# Godot's own is a window here; the platform's is the desktop's.
		if showing.visible:
			showing.grab_focus()
		return ""
	var dialog := FileDialog.new()
	dialog.use_native_dialog = native
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = title
	var extension: String = name.get_extension().to_lower()
	if KINDS.has(extension):
		dialog.add_filter("*." + extension, KINDS[extension])
	dialog.size = Vector2i(760, 520)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)
	dialog.current_dir = start()
	dialog.current_file = name
	var answer := _Answer.new()
	dialog.file_selected.connect(answer.give)
	dialog.canceled.connect(answer.give.bind(""))
	showing = dialog
	Working.asking += 1
	Working.asked += 1
	dialog.popup_centered()
	var path: String = await answer.given
	Working.asking -= 1
	showing = null
	dialog.queue_free()
	if not path.is_empty():
		ShellPrefs.put("save_folder", path.get_base_dir())
	return path


## The folder the dialog opens in: the last one a file was saved in, while
## it is there, or Documents.
static func start() -> String:
	var last: String = str(ShellPrefs.value("save_folder"))
	if not last.is_empty() and DirAccess.dir_exists_absolute(last):
		return last
	var documents: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if not documents.is_empty() and DirAccess.dir_exists_absolute(documents):
		return documents
	return OS.get_environment("USERPROFILE" if OS.get_name() == "Windows" else "HOME")


## [param path] was written for the person: Show in folder shows it.
static func wrote(path: String) -> void:
	shown = path


## Whether [param line] names the file Show in folder shows.
static func names(line: String) -> bool:
	return not shown.is_empty() and line.contains(shown)


## The file manager open on [param path], selected; or its folder, where
## the system cannot select one.
static func show_in_folder(path: String) -> void:
	if show_with.call(path) != OK:
		open_with.call(path.get_base_dir())


## [param path] open in the program the system opens its kind with (a web
## page in the browser). False when none could be started.
static func open(path: String) -> bool:
	return open_with.call("file://" + path) == OK


class _Answer extends RefCounted:
	signal given(path: String)

	func give(path: String) -> void:
		given.emit(path)
