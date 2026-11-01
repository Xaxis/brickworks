## Does a real set under test reach a design run by any path?
##
##   godot --headless --path . --script src/dev/holdout_probe.gd
##
## tools/bench/realset.py judges a design against the real set of its brief
## and starts the app with --held-out=<the set's number> and
## --held-out-name=<its name>. Every path that hands a session a real set's
## facts has to leave that set out, and any set of the same name under
## another number: 21004-1 is the Solomon R. Guggenheim Museum as much as
## 21035-1 is. plan_scale told 7242-1's session "7242 Street Sweeper 15"
## (2026-10-31) and 7992-1's its own two models' lengths (2026-10-30), from
## an index that never asked what was held out.
##
## Held out here as the bench holds them, four sets by number and name.
## 21035-1 is in no index of its own: only its name keeps 21004-1 out. Each
## path is asked about them, and about a set not held, which must still answer:
##   plan_scale's official models (SetKnowledge.sizes)
##   the technique library's worked examples (Techniques: a fence from 3189,
##     a stone wall from 9471)
##   the real-set index of pieces (RealSnippets: find_techniques,
##     place_technique, how_real_sets_build_this, the feature pass)
##   the library shelf (ModelLibrary: gallery library=, open_model library=)
##   the catalogue's sets with no model (gallery library=, its parts lists)
##   the official models a collection is measured against (SetInventories)
##   the gallery's shared copies of LDraw's models (gallery search and open)
##   the pictures of the real thing (find_reference: no photograph of a set)
extends SceneTree

## The sets under test: number -> name, as realset.py passes them.
const HELD := {"7242-1": "Street Sweeper", "3189-1": "Heartlake Stables", "9471-1": "Uruk-hai Army",
	"21035-1": "Solomon R. Guggenheim Museum"}
## The museum's name: 21004-1 has it too.
const NAMED := "Solomon R. Guggenheim Museum"
## Numbers that must never be said: the sets held and those of their names.
const NEVER := ["7242", "6645", "6649", "3189", "9471", "21035", "21004"]

var _failures: int = 0


## The gallery's own deployment, answered here with a canned catalogue.
class Catalogue extends GalleryTool:
	var body: Dictionary = {}

	func _ask(_path: String, _most: int, _token: String = "") -> Dictionary:
		return {"code": 200, "bytes": JSON.stringify(body).to_utf8_buffer()}


## The set inventories' models.json, canned.
class Inventories extends SetInventories:
	var models: Array = []

	func _read(_file_name: String) -> Variant:
		return {"models": models}


## Commons' search, answered with canned pages; nothing is fetched.
class Commons extends ReferenceFinder:
	func _fetch_next() -> void:
		pass

	func titles() -> PackedStringArray:
		var out := PackedStringArray()
		for one: Dictionary in _pending:
			out.append(str(one["title"]))
		return out


func _initialize() -> void:
	_run()


func _run() -> void:
	# Before any index is read: each leaves out what is held as it is read.
	DesignMemory.hold_out(PackedStringArray(HELD.keys()))
	var named: bool = _hold_names(HELD.values())
	_ok(named, "the bench can hold a set out by its name (DesignMemory.hold_name)")
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("FAIL no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame

	print("── plan_scale: the official models of the kind ──")
	var swept: String = assistant._plan_scale({"longest_metres": 6.0, "subject": "street sweeper"})
	_never(swept, "plan_scale of a street sweeper")
	var stacker: String = assistant._plan_scale({"longest_metres": 11.0, "subject": "reach stacker"})
	_ok(stacker.contains("7992"), "...and a set not held still answers: %s" % _around(stacker, "7992"))

	print("── the technique library ──")
	var cited := PackedStringArray()
	for one: Variant in Techniques.all():
		var why: String = str((one as Dictionary).get("why", ""))
		for number: String in NEVER:
			if why.contains("built it in %s " % number):
				cited.append("%s (%s)" % [(one as Dictionary)["name"], number])
	_ok(cited.is_empty(), "no worked example of a held set: %s" % (", ".join(cited)
		if not cited.is_empty() else "none"))
	_never(assistant._show_technique("fence"), "show_technique fence")
	_never(assistant._show_technique("weathered stone wall"), "show_technique weathered stone wall")
	_ok(not Techniques.named("staggered wall").is_empty(), "...and one of no set is still there")

	print("── the real-set index of pieces ──")
	var pieces: Array = RealSnippets.document().get("entries", [])
	var from_held := PackedStringArray()
	for raw: Variant in pieces:
		var number: String = str((raw as Dictionary).get("set", "")).get_slice("-", 0)
		if NEVER.has(number) and not from_held.has(number):
			from_held.append(number)
	_ok(not pieces.is_empty() and from_held.is_empty(), "%d pieces, none of a held set: %s" % [
		pieces.size(), ", ".join(from_held) if not from_held.is_empty() else "none"])
	for query: String in ["street sweeper", "Guggenheim museum rotunda", "horse stable fence"]:
		var found: Array = RealSnippets.search(query, 0.0, [], 12)
		var said := PackedStringArray()
		for row: Variant in found:
			var entry: Dictionary = (row as Array)[1] if row is Array else row
			said.append(RealSnippets.credit(entry))
		_never("\n".join(said), "find_techniques \"%s\" (%d found)" % [query, found.size()])
	var known: bool = not RealSnippets.search("container stacker", 0.0, [], 12).is_empty()
	_ok(known, "...and a subject not held still finds pieces")

	print("── the library shelf ──")
	var shelf := ModelLibrary.new()
	var kept: Array = shelf.shelved([
		_omr("7242-1", "Street Sweeper"), _omr("6645-1", "Street Sweeper"),
		_omr("21004-1", NAMED), _omr("3189-1", "Heartlake Stables"),
		_omr("7992-1", "Container Stacker")], DesignMemory.held_out())
	var on_shelf := PackedStringArray()
	for entry: Dictionary in kept:
		on_shelf.append(str(entry["set"]))
	_ok(on_shelf == PackedStringArray(["7992-1"]), "the shelf keeps only the set not held: %s"
		% ", ".join(on_shelf))
	shelf.free()

	print("── the catalogue's sets with no model ──")
	var catalogue := Catalogue.new()
	catalogue.body = {"with_3d": 0, "models": [
		_card("7242-1", "Street Sweeper"), _card("6649-1", "Street Sweeper"),
		_card("21035-1", NAMED), _card("60073-1", "Service Truck")]}
	var listed: String = "\n".join(await catalogue._catalogue_sets("street sweeper"))
	_never(listed, "gallery library= sets with no model")
	_ok(listed.contains("60073"), "...and a set not held is still listed")

	print("── the official models a collection is measured against ──")
	var inventories := Inventories.new()
	inventories.models = [{"n": "Street Sweeper", "set": "7242-1", "p": []},
		{"n": NAMED, "set": "21004-1", "p": []}, {"n": "Container Stacker", "set": "7992-1", "p": []}]
	var official := PackedStringArray()
	for model: Dictionary in await inventories.official_models():
		official.append(str(model["set"]))
	_ok(official == PackedStringArray(["7992-1"]), "only the set not held: %s" % ", ".join(official))
	inventories.free()

	print("── the gallery's shared copies of LDraw's models ──")
	var copy := {"name": "Street Sweeper", "parts": 112, "modelled_by": {"name": "Someone"},
		"licence": "cc-by"}
	var own := {"name": "My street sweeper", "parts": 90, "author": "a builder", "licence": "cc-by"}
	catalogue.body = {"models": [copy, own], "more": false}
	var searched: String = str(await catalogue.run({"q": "street sweeper"}))
	_ok(not searched.contains("modelled by Someone") and searched.contains("My street sweeper"),
		"a search lists a builder's own design, not LDraw's model of the set: %s"
			% searched.get_slice("\n", 1).left(80))

	print("── pictures of the real thing ──")
	var commons := Commons.new()
	get_root().add_child(commons)
	var request := HTTPRequest.new()
	get_root().add_child(request)
	commons._on_searched(0, 200, PackedStringArray(), JSON.stringify({"query": {"pages": [
		_page("File:LEGO 7242 Street Sweeper.jpg"), _page("File:Lego city street sweeper set.jpg"),
		_page("File:Street sweeper in Paris.jpg")]}}).to_utf8_buffer(), request)
	var titles: PackedStringArray = commons.titles()
	_ok(titles == PackedStringArray(["Street sweeper in Paris.jpg"]),
		"find_reference shows the street, not a set: %s" % ", ".join(titles))

	print("")
	if _failures == 0:
		print("holdout: no held-out set reaches a design run")
	else:
		print("holdout: %d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


## The method is there on this code, and holds [param names] out.
func _hold_names(names: Array) -> bool:
	for method: Dictionary in (DesignMemory as Script).get_script_method_list():
		if str(method["name"]) == "hold_name":
			for name: Variant in names:
				Callable(DesignMemory, "hold_name").call(str(name))
			return true
	return false


## No held set's number in [param text].
func _never(text: String, what: String) -> void:
	var said := PackedStringArray()
	for number: String in NEVER:
		if RegEx.create_from_string("(?<![0-9])%s(?![0-9])" % number).search(text) != null:
			said.append(_around(text, number))
	_ok(said.is_empty(), "%s names no held set%s" % [what,
		": " + " | ".join(said) if not said.is_empty() else ""])


func _around(text: String, what: String) -> String:
	var at: int = text.find(what)
	return text.substr(maxi(0, at - 30), 70).replace("\n", " ") if at >= 0 else "(not said)"


func _omr(number: String, name: String) -> Dictionary:
	return {"id": "omr-" + number, "set": number, "name": name, "theme": "Town", "year": 2005,
		"parts": 100, "file": "library/omr/%s.mpd" % number, "author": "a modeller", "licence": "CC BY 2.0"}


func _card(number: String, name: String) -> Dictionary:
	return {"name": name, "parts": 100,
		"library": {"set": number, "theme": "Town", "year": 2005, "model3d": false}}


func _page(title: String) -> Dictionary:
	return {"title": title, "imageinfo": [{"thumburl": "https://upload.example.invalid/%s"
		% title.trim_prefix("File:").uri_encode(), "extmetadata": {}}]}


func _ok(passed: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", what])
	if not passed:
		_failures += 1
