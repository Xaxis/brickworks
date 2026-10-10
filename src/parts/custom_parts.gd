## Made parts: making them, keeping them, and carrying them in model files.
##
## A part made in the element maker is an LDraw source and nothing else.
## Everything the app needs — geometry, connectors, collision — is built
## from that source by [PartForge], here, whenever the part is wanted: when
## it is made, when the app starts and finds it kept, and when a model file
## arrives carrying it. Keeping only the source means there is nothing that
## can go stale against it.
##
## Kept in user://custom_parts/, one .dat per part: the app's own folder on
## the desktop and IndexedDB in a browser, as saved models are.
##
## A model that uses a made part carries the part inside it, as LDraw's
## multi-part document spec allows (`0 FILE bw-b2x7x3.dat` and the part's
## own text), so the file opens in LDCad or Studio on a machine that has
## never seen the part, and opens here on one that has not either.
class_name CustomParts
extends RefCounted

## Where made parts are kept. A probe points this elsewhere, so a check
## never adds parts to the person's own bin.
static var dir: String = "user://custom_parts/"


## Make a part from a spec, add it to the library and keep it. Returns
## {"id": the part's id, "problem": why not, or ""}.
##
## The same shape under another name is another part: a designer who calls
## one 2 x 7 brick a sill and another a lintel gets both, numbered apart.
static func make(library: PartLibrary, spec: ElementMaker.Spec,
		keep: bool = true) -> Dictionary:
	var problem: String = ElementMaker.problem(spec)
	if not problem.is_empty():
		return {"id": "", "problem": problem}
	var base: String = ElementMaker.id_for(spec)
	var id: String = base
	var text: String = ElementMaker.dat(spec, id)
	var n: int = 1
	while library.parts.has(id) and library.custom_source(id) != text:
		n += 1
		id = "%s-%d" % [base, n]
		text = ElementMaker.dat(spec, id)
	return add(library, text, id, keep)


## Add a part from its LDraw text: built, registered and, with [param
## keep], written to [member dir]. [param others] are files it may draw on
## from the same model file.
static func add(library: PartLibrary, text: String, id: String, keep: bool = true,
		others: Dictionary = {}) -> Dictionary:
	var built: PartForge.Result = PartForge.build(text, id, others)
	if not built.problem.is_empty():
		return {"id": id, "problem": built.problem}
	library.add_custom(info_for(built), built.mesh, text)
	if keep:
		DirAccess.make_dir_recursive_absolute(dir)
		var file: FileAccess = FileAccess.open(dir + id + ".dat", FileAccess.WRITE)
		if file == null:
			return {"id": id, "problem": "it was made but could not be kept (%d)"
				% FileAccess.get_open_error()}
		file.store_string(text)
		file.close()
	return {"id": id, "problem": ""}


## What the catalogue would say about a built part.
static func info_for(built: PartForge.Result) -> PartLibrary.PartInfo:
	var info := PartLibrary.PartInfo.new()
	info.id = built.id
	info.name = built.name
	info.category = "Custom"
	info.ldraw_category = built.category
	info.custom = true
	info.kind = "Unofficial_Part"
	info.mesh_hash = "custom/" + built.id
	info.triangles = built.triangles
	var lo := Vector3(built.bounds_min[0], built.bounds_min[1], built.bounds_min[2])
	var hi := Vector3(built.bounds_max[0], built.bounds_max[1], built.bounds_max[2])
	info.bounds = AABB(lo, hi - lo)
	info.size = hi - lo
	info.stud_count = int(built.connector_counts.get("stud", 0))
	info.socket_count = built.sockets.size()
	info.box_count = built.boxes.size()
	info.connector_counts = built.connector_counts.duplicate()
	info.recolourable = true
	info.unofficial = true
	info.keywords = PackedStringArray(["custom element", built.category.to_lower()])
	return info


## Every part kept in [member dir], built and added. Returns how many.
static func load_all(library: PartLibrary) -> int:
	var found: int = 0
	if not DirAccess.dir_exists_absolute(dir):
		return 0
	for file_name: String in DirAccess.get_files_at(dir):
		if not file_name.ends_with(".dat"):
			continue
		var id: String = file_name.get_basename()
		var result: Dictionary = add(library,
			FileAccess.get_file_as_string(dir + file_name), id, false)
		if str(result["problem"]).is_empty():
			found += 1
		else:
			push_warning("custom part %s: %s" % [id, result["problem"]])
	return found


## The parts a model file carries, added to the library so the model can
## be opened. A part the library already has as one of LEGO's is left to
## the library: a file cannot redefine 3001. Returns {"added": [ids],
## "problems": [sentences]}.
static func take_from(library: PartLibrary, model: LdrModel) -> Dictionary:
	var added: PackedStringArray = PackedStringArray()
	var problems: PackedStringArray = PackedStringArray()
	for file_name: String in model.embedded_parts:
		var id: String = file_name.get_basename()
		var text: String = model.embedded_parts[file_name]
		var info: PartLibrary.PartInfo = library.parts.get(id)
		if info != null and not info.custom:
			continue
		if info != null and library.custom_source(id) == text:
			continue
		var result: Dictionary = add(library, text, id,
			not FileAccess.file_exists(dir + id + ".dat"), model.embedded_parts)
		if str(result["problem"]).is_empty():
			added.append(id)
		else:
			problems.append("%s: %s" % [id, result["problem"]])
	return {"added": added, "problems": problems}


## The sources of the custom parts among [param part_ids], by file name,
## for writing into a model file.
static func sources_for(library: PartLibrary, part_ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for part_id: Variant in part_ids:
		var text: String = library.custom_source(str(part_id))
		if not text.is_empty():
			out[str(part_id) + ".dat"] = text
	return out
