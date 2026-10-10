## What this build says it is: a version, and for a release, which commit
## it was made from and when.
##
## A downloaded build has to be able to say what it is. Without that, a
## bug report says "the desktop app" and nothing else, and nobody can tell
## whether the fix it needs is already out.
##
## The version is project.godot's config/version, which tools/release.py
## keeps equal to VERSION. The stamp is res://release.json, written into
## the copy of the project a release is exported from and never into the
## repository, so a build run from source says it is a development build
## rather than claiming to be a release it is not.
class_name BuildInfo
extends RefCounted

const STAMP := "res://release.json"

static var _stamp: Dictionary = {}
static var _read: bool = false


## "0.1.0".
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## The release stamp, or empty when this build is not a release.
static func stamp() -> Dictionary:
	if _read:
		return _stamp
	_read = true
	if not FileAccess.file_exists(STAMP):
		return _stamp
	var file: FileAccess = FileAccess.open(STAMP, FileAccess.READ)
	if file == null:
		return _stamp
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		_stamp = json.data
	return _stamp


## Whether this is a build tools/release.py made.
static func is_release() -> bool:
	return not stamp().is_empty()


## One line saying what this is, for Help and for --about.
##
##   Brickworks 0.1.0, released 2026-10-10 (3f2a9c1)
##   Brickworks 0.1.0, development build
static func describe() -> String:
	var line: String = "Brickworks %s" % version()
	if is_release():
		var built: String = str(stamp().get("date", ""))
		var commit: String = str(stamp().get("commit", ""))
		return "%s, released %s (%s)" % [line, built, commit]
	if OS.has_feature("web"):
		return line
	return line + ", development build"
