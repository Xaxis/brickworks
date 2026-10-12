## Write the parts lists of the official LDraw set models (vendor/omr) for
## "What can I build?".
##
##   godot --headless --path . --script src/dev/collection_models.gd
##
## The models themselves stay in vendor/, which no build ships; what "What
## can I build?" needs of each is its parts and colours and how many, and
## that is small enough to ship. Counted with the app's own LDraw reader
## (LdrModel.flatten) rather than a second one in Python, so a model counts
## the same here as it does when opened — collection_probe holds that.
##
## Writes assets/generated/sets/models.json:
##   {"models": [{"n": name, "set": "10237-1", "file": "10237-1.mpd",
##                "y": year, "t": theme, "g": its page at library.ldraw.org/omr/sets/,
##                "p": [[part, colour, qty], ...]}]}
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
	for file_name: String in files:
		var text: String = FileAccess.get_file_as_string(OMR + "files/" + file_name)
		var needs: Dictionary = Collection.needs_of_ldraw(text, library)
		if needs.is_empty():
			continue
		var number: String = file_name.get_basename().get_slice("_", 0).to_lower()
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
	var out: FileAccess = FileAccess.open(SetInventories.ROOT + "models.json", FileAccess.WRITE)
	if out == null:
		print("FAIL could not write %smodels.json" % SetInventories.ROOT)
		quit(1)
		return
	out.store_string(JSON.stringify({"source": "LDraw Official Model Repository (vendor/omr)",
		"models": models}))
	out.close()
	print("ok wrote %d official models, %d pieces, to %smodels.json"
		% [models.size(), pieces, SetInventories.ROOT])
	quit(0)
