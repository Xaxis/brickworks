## Where a file chooser opens on the desktop: the folder the last file of
## its kind was chosen from, while it is there; else where a person keeps
## that kind. Godot's own dialog opens in the folder the app was started
## from, which is its install folder: the photo search's did, and so did
## every other (walk256 DS1, 2026-10-25).
##
##   picture  Pictures: the photo search's, Print's, the page editor's,
##            LEGO Art's
##   model    the folder the last export or Save as went to (SaveTo),
##            where the person's model files are; else Documents
##   mesh     Downloads: a 3D model to brickify is most often downloaded
##   list     Downloads: a shop's list (Rebrickable, BrickLink) is too
##
## Choosers of one kind share it (ShellPrefs open_folders).
class_name OpenFrom
extends RefCounted

## Each kind's first place, before anything of it has been chosen.
const FIRST: Dictionary = {
	"picture": OS.SYSTEM_DIR_PICTURES,
	"model": OS.SYSTEM_DIR_DOCUMENTS,
	"mesh": OS.SYSTEM_DIR_DOWNLOADS,
	"list": OS.SYSTEM_DIR_DOWNLOADS,
}


## [param dialog] popped up where [param kind] opens, and the folder of the
## file chosen in it kept for the next chooser of that kind.
static func ask(dialog: FileDialog, kind: String) -> void:
	if not dialog.has_meta(&"open_from"):
		dialog.set_meta(&"open_from", kind)
		dialog.file_selected.connect(OpenFrom._chosen.bind(kind))
	dialog.current_dir = start(kind)
	dialog.popup_centered()


## The folder a chooser of [param kind] opens in.
static func start(kind: String) -> String:
	var kept: Dictionary = ShellPrefs.value("open_folders")
	var places := PackedStringArray([str(kept.get(kind, ""))])
	if kind == "model":
		places.append(str(ShellPrefs.value("save_folder")))
	places.append(OS.get_system_dir(FIRST.get(kind, OS.SYSTEM_DIR_DOCUMENTS)))
	for place: String in places:
		if not place.is_empty() and DirAccess.dir_exists_absolute(place):
			return place
	return OS.get_environment("USERPROFILE" if OS.get_name() == "Windows" else "HOME")


static func _chosen(path: String, kind: String) -> void:
	var kept: Dictionary = (ShellPrefs.value("open_folders") as Dictionary).duplicate()
	kept[kind] = path.get_base_dir()
	ShellPrefs.put("open_folders", kept)
