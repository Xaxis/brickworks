## The last saves of each model, kept as versions: File, Versions… opens one.
##
## A saved model was one file, and each Save wrote over it. One save of the
## wrong thing (a model opened short of parts, a slip of the mouse before
## Save) and the model it replaced was gone, with no copy anywhere: on the
## web a person's models live only in the browser (supabase/schema.sql
## keeps no table of them). Studio keeps backups of a model for the same
## reason.
##
## So every save is also kept here, under user://versions/<model>/, the last
## [constant KEPT] of each model. Gzipped, since nobody opens these but the
## app: Orthanc's 722 KB is 59 KB. And all of them together are kept under
## [member most_bytes], so versions cannot fill a browser's storage, which on
## the web the engine also reads into memory as the page starts: over it,
## the oldest go first, though never a model's newest. A save that changes
## nothing keeps no second copy of the same thing.
##
## Each file is named for when it was saved, how many parts it holds and its
## size, so the list and the total are read without opening anything:
## user://versions/My House/1791991181492-120-5321.ldr.gz.
class_name ModelVersions
extends RefCounted

const ROOT := "user://versions/"
## How many saves of each model are kept.
const KEPT := 20
## How much every model's versions may take together, compressed. A probe
## lowers it.
static var most_bytes: int = 16 * 1024 * 1024

## The last stamp handed out, so two saves in one millisecond are in order.
static var _last_stamp: int = 0


class Version extends RefCounted:
	var path: String
	## Unix milliseconds.
	var at: int
	var parts: int
	## Its size as kept, compressed.
	var bytes: int

	## "Today at 14:05:09 — 120 parts", or "11 Oct at 09:30:00 — …".
	func describe() -> String:
		var said: String = when()
		return "%s — %d part%s" % [said.left(1).to_upper() + said.substr(1), parts,
			"" if parts == 1 else "s"]

	## "today at 14:05:09", or "11 Oct at 09:30:00", or with its year.
	func when() -> String:
		var local: int = at / 1000 + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var then: Dictionary = Time.get_datetime_dict_from_unix_time(local)
		var now: Dictionary = Time.get_datetime_dict_from_system()
		var day: String = "today"
		if then.year != now.year or then.month != now.month or then.day != now.day:
			var months: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
				"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
			day = "%d %s" % [then.day, months[int(then.month) - 1]]
			if then.year != now.year:
				day += " %d" % then.year
		return "%s at %02d:%02d:%02d" % [day, then.hour, then.minute, then.second]


## Where the versions of the model saved as [param stem] (its file's name
## without .ldr) are kept.
static func folder(stem: String) -> String:
	return ROOT + stem + "/"


## Keep [param text], just saved as [param stem], as its newest version.
## The version's path, or "" when nothing was written: the same as the
## newest already, or not writable.
static func keep(stem: String, text: String) -> String:
	if stem.is_empty():
		return ""
	var had: Array[Version] = of(stem)
	if not had.is_empty() and read(had[0].path) == text:
		return ""
	DirAccess.make_dir_recursive_absolute(folder(stem))
	var stamp: int = maxi(int(Time.get_unix_time_from_system() * 1000.0), _last_stamp + 1)
	_last_stamp = stamp
	var packed: PackedByteArray = text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var path: String = folder(stem) + "%013d-%d-%d.ldr.gz" % [stamp, ModelStore.count_in(text),
		packed.size()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("could not keep a version of %s (%d)" % [stem, FileAccess.get_open_error()])
		return ""
	file.store_buffer(packed)
	file.close()
	_prune(stem)
	return path


## The versions of the model saved as [param stem], newest first.
static func of(stem: String) -> Array[Version]:
	var found: Array[Version] = []
	if stem.is_empty() or not DirAccess.dir_exists_absolute(folder(stem)):
		return found
	var names: PackedStringArray = DirAccess.get_files_at(folder(stem))
	var sorted: Array = Array(names)
	sorted.sort()
	sorted.reverse()
	for name: String in sorted:
		var version: Version = _parse(folder(stem) + name)
		if version != null:
			found.append(version)
	return found


## A version's model, as LDraw text: "" when it cannot be read.
static func read(path: String) -> String:
	var packed: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if packed.is_empty():
		return ""
	return packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()


static func _parse(path: String) -> Version:
	var name: String = path.get_file()
	if not name.ends_with(".ldr.gz"):
		return null
	var fields: PackedStringArray = name.trim_suffix(".ldr.gz").split("-")
	if fields.size() != 3:
		return null
	for field: String in fields:
		if not field.is_valid_int():
			return null
	var version := Version.new()
	version.path = path
	version.at = fields[0].to_int()
	version.parts = fields[1].to_int()
	version.bytes = fields[2].to_int()
	return version


## The model's oldest past [constant KEPT], then everybody's oldest while all
## of them take more than [member most_bytes]: never a model's newest.
static func _prune(stem: String) -> void:
	var mine: Array[Version] = of(stem)
	for old: Version in mine.slice(KEPT):
		DirAccess.remove_absolute(old.path)
	var all: Array = []
	var total: int = 0
	for model: String in DirAccess.get_directories_at(ROOT):
		var versions: Array[Version] = of(model)
		for n: int in versions.size():
			total += versions[n].bytes
			if n > 0:
				all.append([versions[n].at, versions[n].path, versions[n].bytes])
	if total <= most_bytes:
		return
	all.sort()
	for old: Array in all:
		if total <= most_bytes:
			break
		DirAccess.remove_absolute(str(old[1]))
		total -= int(old[2])


## How much every version takes now, in bytes.
static func total_bytes() -> int:
	var total: int = 0
	if not DirAccess.dir_exists_absolute(ROOT):
		return 0
	for model: String in DirAccess.get_directories_at(ROOT):
		for version: Version in of(model):
			total += version.bytes
	return total
