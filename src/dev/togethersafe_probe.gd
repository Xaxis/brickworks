## A Build together peer's words are data (togethersafe): what another copy
## of the app sends is read as plain values and made precise, never made
## into objects or files of the sender's choosing (src/net/together_words.gd).
##
##   godot --headless --path . --script src/dev/togethersafe_probe.gd
##   ... -- --write=FILE   keep this build's words for each kind in FILE
##   ... -- --old=FILE     and read FILE, the words another build kept so
##
## No server: sides of a session as the app has them (a world, a builder, a
## model store and Together), each kind of the model's state handed to what
## a numbered change reaches (Together._put_meta, _add_made, _heard_people)
## as it comes from the session.
##
## 1. Words Godot's own reader would make an object of, a kind at a time: a
## plain RefCounted with a marker in its metadata, never a script; for a
## made part's files a plain Node, which stays where it is made, so its
## making is counted. None may reach the model's state, none may be made,
## and the session's other state is as it was and good words still land.
## 2. A made part whose print's picture is named by a path out of the
## parts store, and one whose words carry a second part: neither reaches
## past the part its key names. 3. A part's state of the wrong shape is no
## state, and a person's place of the wrong shape is none.
## 4. Each kind as one side writes it, read by another: the second side's
## words for it byte for byte the first's, and a made print's text and
## picture the same. With --old, the same for words an older build wrote.
##
## Made parts go to user://togethersafe_parts/, never the person's own.
extends SceneTree

var _failures: int = 0

const PARTS_DIR := "user://togethersafe_parts/"
const OUTSIDE_DIR := "user://togethersafe_outside/"
const KINDS: Array[String] = ["~hidden", "~looks", "~unit_steps", "~broken"]
const UIDS: Array[String] = ["probe1.0", "probe1.1", "probe1.2"]


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool, more: String = "") -> void:
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "  (%s)" % more if not more.is_empty() else ""])
	if not ok:
		_failures += 1


static func _arg(name: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(name + "="):
			return argument.substr(name.length() + 1)
	return ""


func _run() -> void:
	await process_frame
	for dir: String in [PARTS_DIR, OUTSIDE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)
	CustomParts.dir = PARTS_DIR
	var library: PartLibrary = _library()
	if library == null:
		print("togethersafe probe: no catalogue")
		quit(1)
		return
	var a: Dictionary = _side(library)
	var state: Dictionary = _build_state(a)
	if state.is_empty():
		print("togethersafe probe: could not build the state to send")
		quit(1)
		return
	print("1. words that would be objects")
	_objects_refused(_side(library), state)
	print("2. a made part's files")
	_made_files(_side(library), state)
	print("3. a part's state, a person's place")
	_shapes(_side(library))
	print("4. each kind from one side to another")
	_carried(_side(_library()), state, "this build's")
	if not _arg("--write").is_empty():
		var file: FileAccess = FileAccess.open(_arg("--write"), FileAccess.WRITE)
		file.store_string(JSON.stringify(state, "  "))
		file.close()
		print("  (this build's words kept in %s)" % _arg("--write"))
	if not _arg("--old").is_empty():
		print("5. an older build's words")
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(_arg("--old")))
		_check("the older build's words are there", old is Dictionary, _arg("--old"))
		if old is Dictionary:
			_carried(_side(_library()), old, "the older build's")
	print("")
	print("togethersafe probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)


func _library() -> PartLibrary:
	var library := PartLibrary.new()
	return library if library.load_catalogue() else null


## One side of a session, with no server: as Main has it.
func _side(library: PartLibrary) -> Dictionary:
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	var together := Together.new()
	together.world = world
	together.builder = builder
	together.store = store
	together.keeps_place = false
	root.add_child(together)
	# Three parts the session knows by uid.
	for n: int in UIDS.size():
		var brick_id: int = world.add_brick("3001", 4, Transform3D(Basis.IDENTITY,
			Vector3(n * 80.0, 0, 0)))
		together._map(UIDS[n], brick_id)
	return {"world": world, "builder": builder, "store": store, "together": together,
		"library": library}


## Every kind of the model's state set on side [param a] as a person sets
## it, and its words as the session sends them: {"words": {key: words},
## "part": the made print's id, "text": its file, "pictures": {name: base64}}.
func _build_state(a: Dictionary) -> Dictionary:
	var world: BrickWorld = a["world"]
	var store: ModelStore = a["store"]
	var together: Together = a["together"]
	var library: PartLibrary = a["library"]
	var sign := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	sign.fill(Color(0.9, 0.2, 0.1))
	var sign_png: String = Marshalls.raw_to_base64(sign.save_png_to_buffer())
	store.hidden_scheme = {"mode": "sections", "groups": [{"label": "inside", "colour": 15,
		"also": [71], "sections": ["House"]}]}
	world.step_looks = {
		"|1": {"turn": [20.0, -45.0, 0.0], "how": "REL", "zoom": 1.5, "size": 1.25, "page": "new",
			"parts": false, "place": {"picture": [10.0, 20.0, 100.0, 80.0], "number": [5.0, 5.0]},
			"notes": [{"text": "Mind the gap", "at": [10.0, 150.0, 60.0, 20.0], "size": 4.0, "turn": 15.0},
				{"image": "brickworks-page-sign.png", "at": [100.0, 100.0, 40.0, 40.0], "opacity": 0.5}],
			"arrows": [{"at": [10.0, 10.0, 50.0, 50.0, 60.0, 20.0], "colour": "red", "width": 0.9}],
			"panel": [9.0, 9.0, 251.0, 181.0], "sign": false,
			"pull": {"studs": 2.0, "parts": ["3001"]}, "colours": true, "actual_size": ["3705"],
			"preview": false, "section": "island"},
		"|2": {"turn": "end", "line": "0 ROTSTEP END"},
		"Window|3": {"turn": [0.0, 180.0, 180.0], "how": "ABS", "zoom": 2},
		"Window|*": {"callout": false},
		"|booklet": {"per_page": 2, "highlight": false, "colours_all": true,
			"guides": {"x": [120.0], "y": [40.5]},
			"sheet": {"paper": "a4", "portrait": true, "margin": 12.0}},
		"|data": {"brickworks-page-sign.png": sign_png}}
	world.unit_steps = {"House#1": 2, "House#1/Window#1": 1}
	var ids: Array = UIDS.map(func(uid: String) -> int: return together.brick_of(uid))
	world.broken_out = {"House": {"offset": Vector3(0, 0, -80),
		"home": {ids[0]: world.get_brick(ids[0]).transform,
			ids[1]: Transform3D(Basis(Vector3.UP, 0.3), Vector3(80, 24, 0))},
		"touching": {ids[2]: true}}}
	var words: Dictionary = {}
	var now: Dictionary = together._meta_now()
	for key: String in KINDS:
		words[key] = now[key]
	# A print made in the app: a sign on a 2 x 2 tile.
	var areas: Array = PartPrints.areas_for(library, "3068b")
	if areas.is_empty():
		return {}
	var drawn := Image.create_empty(areas[0].size.x, areas[0].size.y, false, Image.FORMAT_RGBA8)
	drawn.fill_rect(Rect2i(Vector2i(4, 4), Vector2i(areas[0].size) - Vector2i(8, 8)), Color.BLACK)
	var made: Dictionary = PartPrints.make(library, "3068b", areas.slice(0, 1), {"top": drawn},
		"Togethersafe Sign", false)
	if (made["ids"] as Array).size() != 1:
		print("  (no print: %s)" % made)
		return {}
	var part: String = made["ids"][0]
	words["~part:" + part] = var_to_str(CustomParts.sources_for(library, [part]))
	var pictures: Dictionary = {}
	var mesh: Lbm.PartMesh = library.mesh_for(part)
	for name: String in mesh.print_files:
		pictures[name] = Marshalls.raw_to_base64(mesh.print_files[name])
	return {"words": words, "part": part, "text": library.custom_source(part), "pictures": pictures}


func _put(side: Dictionary, key: String, words: String) -> void:
	var together: Together = side["together"]
	if key.begins_with("~part:"):
		# One build named the part by its key, the one before by its files.
		var part: String = key.substr("~part:".length())
		together.callv("_add_made", [part, words] if together.get_method_argument_count("_add_made") == 2
			else [words])
	else:
		together._put_meta(key, words)


static func _state_of(side: Dictionary, key: String) -> Variant:
	match key:
		"~hidden":
			return (side["store"] as ModelStore).hidden_scheme
		"~looks":
			return (side["world"] as BrickWorld).step_looks
		"~unit_steps":
			return (side["world"] as BrickWorld).unit_steps
		"~broken":
			return (side["world"] as BrickWorld).broken_out
	return null


## The objects anywhere in [param value], each by its marker.
static func _objects_in(value: Variant) -> Array:
	var out: Array = []
	if value is Object:
		out.append(str((value as Object).get_meta("togethersafe", "an object")) if is_instance_valid(value)
			else "a freed object")
	elif value is Dictionary:
		for key: Variant in value:
			out.append_array(_objects_in(key))
			out.append_array(_objects_in(value[key]))
	elif value is Array:
		for item: Variant in value:
			out.append_array(_objects_in(item))
	return out


## Words Godot's reader would build an object of: [param inner] holds the
## marker's place, the object written as Godot writes one.
static func _with_object(inner: String, kind: String, marker: String) -> String:
	return inner.replace("@", "Object(%s,\"metadata/togethersafe\":\"%s\")" % [kind, marker])


func _objects_refused(side: Dictionary, state: Dictionary) -> void:
	var together: Together = side["together"]
	var world: BrickWorld = side["world"]
	var store: ModelStore = side["store"]
	store.title = "Probe house"
	together._put_meta("~floor", "BASEPLATE 32 32 2")
	var words: Dictionary = state["words"]
	var crafted: Dictionary = {
		"~hidden": _with_object("{\"groups\": [@], \"mode\": \"sections\"}", "RefCounted",
			"hidden colours"),
		"~looks": _with_object("{\"|1\": {\"notes\": [{\"at\": [1, 2, 3, 4], \"text\": @}]}}",
			"RefCounted", "booklet looks"),
		"~unit_steps": _with_object("{\"House#1\": @}", "RefCounted", "unit steps"),
		"~broken": _with_object("{\"House\": {\"home\": {}, \"offset\": Vector3(0, 0, -80), "
			+ "\"touching\": @}}", "RefCounted", "broken out"),
	}
	for key: String in crafted:
		# Its good words first, as the session had them.
		together._put_meta(key, words[key])
		var others: Dictionary = together._meta_now()
		others.erase(key)
		var parts: int = world.brick_count()
		together._put_meta(key, crafted[key])
		var found: Array = _objects_in(_state_of(side, key))
		_check("%s: words that would be an object make none in the model" % key, found.is_empty(),
			", ".join(found) if not found.is_empty() else "")
		var after: Dictionary = together._meta_now()
		after.erase(key)
		_check("...the session's other state as it was, its parts too", after == others
			and world.brick_count() == parts and store.title == "Probe house")
		together._put_meta(key, words[key])
		_check("...and its good words land after them", together._meta_now()[key] == words[key])
	# A made part's files: a Node is made and left where it is, so it is counted.
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_put(side, "~part:bw-togethersafe-a", _with_object("{\"bw-togethersafe-a.dat\": \"0 a part\\n\", "
		+ "\"bw-togethersafe-a.png\": @}", "Node", "made part"))
	var made: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - orphans
	_check("~part: a made part's files that would be an object make none", made == 0,
		"%d made" % made if made != 0 else "")


func _made_files(side: Dictionary, state: Dictionary) -> void:
	var library: PartLibrary = side["library"]
	var text: String = state["text"]
	var pictures: Dictionary = state["pictures"]
	# A picture outside the parts store, and a print whose words name it by a
	# path there but do not carry it.
	var outside := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	outside.fill(Color(0.1, 0.6, 0.2))
	var outside_png: PackedByteArray = outside.save_png_to_buffer()
	var kept: FileAccess = FileAccess.open(OUTSIDE_DIR + "marker.png", FileAccess.WRITE)
	kept.store_buffer(outside_png)
	kept.close()
	var reaching: String = text
	for name: String in pictures:
		reaching = reaching.replace(name, "../togethersafe_outside/marker.png")
	var id: String = "bw-3068b-ptsafe1"
	_put(side, "~part:" + id, var_to_str({id + ".dat": reaching}))
	var mesh: Lbm.PartMesh = library.mesh_for(id) if library.parts.has(id) else null
	var read_out: bool = mesh != null and mesh.print_files.values().has(outside_png)
	_check("a made print naming a picture by a path out of the parts store never reads it",
		not read_out, "built with the picture from outside" if read_out else
		("not built" if mesh == null else "built without it"))
	# One made part's words carrying a second part.
	var first: String = "bw-3068b-ptsafe2"
	var second: String = "bw-3068b-ptsafe3"
	var files: Dictionary = {first + ".dat": text, second + ".dat": text}
	for name: String in pictures:
		files[name] = Marshalls.base64_to_raw(pictures[name])
	_put(side, "~part:" + first, var_to_str(files))
	_check("a made part's words add the part its key names", library.parts.has(first))
	_check("...and no other part they carry", not library.parts.has(second))


func _shapes(side: Dictionary) -> void:
	var place: Array = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 80.0, 24.0, -40.0]
	var bad: Dictionary = {
		"its place in words": ["3001", 4.0, "twelve numbers", "", "", 0.0],
		"three numbers for its place": ["3001", 4.0, [1.0, 0.0, 0.0], "", "", 0.0],
		"its place not finite": ["3001", 4.0, place.slice(0, 11) + [NAN], "", "", 0.0],
		"its part a path": ["../../3001", 4.0, place, "", "", 0.0],
		"its colour in words": ["3001", "red", place, "", "", 0.0],
	}
	for what: String in bad:
		var read: Variant = Together._as_state(bad[what])
		_check("a part's state with %s is no state" % what, read == null, str(read) if read != null else "")
	# As JSON gives it back: its numbers as numbers.
	var read: Variant = Together._as_state(["3001", 4.0, place, "", "House#1", 2.0])
	_check("a part's state as the session sends it is read", read == ["3001", 4, place, "", "House#1", 2],
		str(read))
	var together: Together = side["together"]
	together._heard_people({"people": [{"who": "0123abcd", "name": "Them", "here": true,
		"at": [1.0], "sel": ["probe1.0", 5], "view": {"yaw": "far"}}, {"who": 5}]}, 0)
	var people: Array = together.people
	_check("a person's place of the wrong shape is none, and what is not a person is no one",
		people.size() == 1 and (people[0] as Dictionary).get("at") == null
			and (people[0] as Dictionary).get("sel") == ["probe1.0"]
			and (people[0] as Dictionary).get("view") == null, str(people))


## Side [param side] given each kind of [param state] (its words as another
## side sent them): its own words for each are the same, byte for byte, and
## the made print is the one sent.
func _carried(side: Dictionary, state: Dictionary, whose: String) -> void:
	var together: Together = side["together"]
	var library: PartLibrary = side["library"]
	var words: Dictionary = state["words"]
	for key: String in KINDS:
		_put(side, key, str(words.get(key, "")))
		var now: String = str(together._meta_now().get(key, ""))
		_check("%s %s read here, and written back byte for byte" % [whose, key],
			now == str(words.get(key, "")) and not now.is_empty(),
			"%d and %d characters" % [now.length(), str(words.get(key, "")).length()])
	var part: String = str(state.get("part", ""))
	_put(side, "~part:" + part, str(words.get("~part:" + part, "")))
	var mesh: Lbm.PartMesh = library.mesh_for(part) if library.parts.has(part) else null
	var same: bool = mesh != null and library.custom_source(part) == str(state.get("text", ""))
	for name: Variant in state.get("pictures", {}):
		same = same and mesh.print_files.get(name) == Marshalls.base64_to_raw(state["pictures"][name])
	_check("%s made print %s built here from its words, its file and picture the same" % [whose, part],
		same and not (state.get("pictures", {}) as Dictionary).is_empty())
