## Write the parts lists of the official LDraw set models (vendor/omr) for
## "What can I build?".
##
##   godot --headless --path . --script src/dev/collection_models.gd
##
## The models themselves stay in vendor/, which no build ships; what "What
## can I build?" needs of each is its parts and colours and how many, and
## that is small enough to ship. Counted with the app's own LDraw reader
## (LdrModel.flatten) rather than a second one in Python, and then matched
## to what its own set holds (Collection.as_its_set, from the set's
## inventory beside it, so run tools/collection_data.py first): an
## official model is that set, and owning the set builds it. collection_
## probe counts each again the same way and holds the two equal.
##
## Writes assets/generated/sets/models.json:
##   {"models": [{"n": name, "set": "10237-1", "file": "10237-1.mpd",
##                "y": year, "t": theme, "g": its page at library.ldraw.org/omr/sets/,
##                "p": [[part, colour, qty], ...], "c": its part count}]}
## One entry per file: a set with a B-model has two.
extends SceneTree

const OMR := "res://vendor/omr/"


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("FAIL no catalogue")
		quit(1)
		return
	var about: Dictionary = {}
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(OMR + "index.json"))
	if typeof(index) == TYPE_ARRAY:
		for entry: Variant in index:
			about[str((entry as Dictionary).get("number", ""))] = entry
	var files: PackedStringArray = DirAccess.get_files_at(OMR + "files")
	if files.is_empty():
		print("FAIL no models in %sfiles (tools/omr.py fetch)" % OMR)
		quit(1)
		return
	var models: Array = []
	var pieces: int = 0
	var matched: int = 0
	for file_name: String in files:
		var number: String = file_name.get_basename().get_slice("_", 0).to_lower()
		var needs: Dictionary = listed(file_name, number, library)
		if needs.is_empty():
			continue
		matched += int(_held(number, library).size() > 0)
		var said: Dictionary = about.get(number, {})
		var name: String = str(said.get("name", number))
		if file_name.get_basename().contains("_"):
			name += " — " + file_name.get_basename().get_slice("_", 1).replace("-", " ")
		var rows: Array = []
		var keys: Array = needs.keys()
		keys.sort()
		for key: String in keys:
			rows.append([Collection.part_of(key), Collection.colour_of(key), int(needs[key])])
			pieces += int(needs[key])
		models.append({"n": name, "set": number, "file": file_name,
			"y": int(str(said.get("year", "0"))), "t": str(said.get("theme", "")),
			"g": str(said.get("page", "")), "p": rows})
	# And each one's part count as a builder counts it, which the Library's
	# card says (tools/library_build.py): the lots above are what of its set's
	# box it uses, which left out the 1,679 parts the Cat D11 carries. After
	# every list, since counting reads a file as opening it does and puts the
	# parts it carries in the library, where a B-model's list would find its
	# A-model's; and nothing kept of them.
	CustomParts.keeps = false
	for model: Dictionary in models:
		model["c"] = Inventory.count_of_text(
			FileAccess.get_file_as_string(OMR + "files/" + str(model["file"])), library)
	var out: FileAccess = FileAccess.open(SetInventories.ROOT + "models.json", FileAccess.WRITE)
	if out == null:
		print("FAIL could not write %smodels.json" % SetInventories.ROOT)
		quit(1)
		return
	out.store_string(JSON.stringify({"source": "LDraw Official Model Repository (vendor/omr)",
		"models": models}))
	out.close()
	print("ok wrote %d official models, %d matched to their set's inventory, %d pieces, to %smodels.json"
		% [models.size(), matched, pieces, SetInventories.ROOT])
	quit(0)


## A model's parts as models.json lists them: the file's, counted as the app
## counts a model it opens, matched to its own set where the set's inventory
## is here.
static func listed(file_name: String, number: String, library: PartLibrary) -> Dictionary:
	var needs: Dictionary = Collection.needs_of_ldraw(
		FileAccess.get_file_as_string(OMR + "files/" + file_name), library)
	var held: Dictionary = _held(number, library)
	if needs.is_empty() or held.is_empty():
		return needs
	return Collection.as_its_set(needs, held, drawn_with, library)


## Everything the set's box holds, its spares too.
static func _held(number: String, library: PartLibrary) -> Dictionary:
	var shard: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		SetInventories.ROOT + "%03d.json" % SetInventories.shard_of(number)))
	if typeof(shard) != TYPE_DICTIONARY:
		return {}
	var mine := Collection.new()
	mine.sets = [{"set": number, "qty": 1, "spares": true}]
	return mine.pool((shard as Dictionary).get("sets", {}), library)


## What an LDraw shortcut or alias file places: [[part, colour]].
static var _drawn: Dictionary = {}


static func drawn_with(part: String) -> Array:
	if _drawn.has(part):
		return _drawn[part]
	var out: Array = []
	for folder: String in ["res://vendor/ldraw/parts/", "res://vendor/ldraw/unofficial/parts/"]:
		if not FileAccess.file_exists(folder + part + ".dat"):
			continue
		for line: String in FileAccess.get_file_as_string(folder + part + ".dat").split("\n"):
			var words: PackedStringArray = line.strip_edges().split(" ", false)
			if words.size() >= 15 and words[0] == "1" and words[1].is_valid_int():
				out.append([" ".join(words.slice(14)).to_lower().trim_suffix(".dat"), words[1].to_int()])
		break
	_drawn[part] = out
	return out
