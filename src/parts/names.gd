## One namespace for every name a model defines, and one rule for a free
## one. A model's file names its sub-models, the parts it carries, the
## files those are drawn from and its pictures, and LDraw reads each by its
## name as written, its extension with it, as it compares file names: no
## case, either slash ("window.ldr" and "window.dat" are two files, a
## sub-model and a part). The app names a sub-model by its definition
## ("Window"), and its file by that or by the name the file gave it
## (BrickWorld.section_files). Two names are one where [method key] says so,
## and every place that decides whether a name is taken (a Make, a rename,
## a copy made one of its own, a paste's figure, a model put into this one)
## asks [method free_name] for one against the model's names
## (Assemblies.names_taken). Up to 2026-11-12 each place had its own list: a
## sub-model only parts the app could not show were in, a section the file
## kept as it was, a part file the model carried and a picture were in none
## of them, and a model put in took those names and the host's own were
## lost (imreview, im2review).
class_name Names
extends RefCounted

## The extensions a file name ends with: a sub-model's, a part's and a
## multi-part file's.
const EXTENSIONS: Array[String] = [".ldr", ".dat", ".mpd"]


## [param name] as two names are compared: LDraw's way (no space at its
## ends, "\\" as "/", no case).
static func key(name: String) -> String:
	return LdrModel._key(name)


## Whether [param name] is one of [param taken] ([method key]'s keys).
static func is_taken(name: String, taken: Dictionary) -> bool:
	return taken.has(key(name))


## [param name] taken into [param taken].
static func take(name: String, taken: Dictionary) -> void:
	if not name.strip_edges().is_empty():
		taken[key(name)] = true


## [param file], the name of a file a model holds, taken into [param taken],
## and a sub-model file's name without its extension too: the lodge's Frame
## in window.ldr is "window.ldr" in LDCad's and Studio's lists of its
## sub-models, so a sub-model of the app's called Window there would read as
## a second of it (into_kept names).
static func take_file(file: String, taken: Dictionary) -> void:
	take(file, taken)
	if [".ldr", ".mpd"].has(("." + file.get_extension()).to_lower()):
		take(file.get_basename(), taken)


## A name of [param wanted]'s that [param taken] has not got, taken into it:
## [param wanted] itself, else "Wing 2", "Wing 3" for a sub-model's (as the
## app numbers a second of anything), and with [param file] "wing_2.ldr",
## "wing_3.ldr" for a file's, the number before its extension. A sub-model's
## name has no "/" or "#", which a path uses ("House#1/Wing#2").
static func free_name(wanted: String, taken: Dictionary, file: bool = false,
		otherwise: String = "Sub-assembly") -> String:
	var base: String = wanted.strip_edges()
	if not file:
		base = base.replace("/", "-").replace("#", "").strip_edges()
	if base.is_empty():
		base = otherwise
	var name: String = base
	var n: int = 2
	while is_taken(name, taken):
		name = _numbered(base, n, file)
		n += 1
	take(name, taken)
	return name


static func _numbered(base: String, n: int, file: bool) -> String:
	if not file:
		return "%s %d" % [base, n]
	var extension: String = base.get_extension()
	if extension.is_empty() or not EXTENSIONS.has("." + extension.to_lower()) \
			and extension.to_lower() != "png":
		return "%s_%d" % [base, n]
	return "%s_%d.%s" % [base.get_basename(), n, extension]
