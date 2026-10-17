## Prove a file's carried parts build on the web from LDraw text fetched as it
## is needed (CustomParts.fetch_sources).
##
##   godot --headless --path . --script src/dev/carried_fetch_probe.gd [-- FILE ...]
##   godot --headless --path . --script src/dev/carried_fetch_probe.gd -- --census OUT.json [FILE ...]
##   godot --headless --path . --script src/dev/carried_fetch_probe.gd -- --timing FILE ...
##
## The checkout's library is withheld as a build has it (PartForge.withheld:
## the primitives every build ships and nothing else), and the library's parts/
## is served over HTTP on 127.0.0.1:8841 by python3's http.server, laid out as
## the parts bucket has it under ldraw/ (tools/storage_ldraw.py). Then, for
## 42082-1 and each FILE:
##
## - with nowhere to fetch from, the parts drawn from a library file are said
##   not shown, as a build without this said them;
## - fetched through the same path the web takes (ModelStore.open_text_fetched),
##   no carried part is left out, each built as the desktop builds it from
##   vendor/ldraw (the same faces and bounds), and only what the file names
##   and what those draw on is fetched;
## - answers heard in whatever order they come;
## - opened again, nothing is fetched and no frame is waited for;
## - the working model put back at start-up fetches what it needs as well;
## - a file that carries nothing, or the desktop with its library, waits for
##   no frame and fetches nothing;
## - a file the server has not got is said not shown, with why (HTTP 404),
##   and a web page that comes back is not taken for LDraw.
##
## --timing opens each FILE five times each way, alternately, from a fresh
## session each time and the library withheld: as the web opens it (what it
## needs looked for first, CustomParts.unreached_by) and with nothing looked
## for, as before; and says the median of each. For a file that needs nothing
## fetched, what looking costs.
##
## --census reads every file in vendor/omr/files (or the FILEs) as the web
## build would: which carry parts it could not build without the library's
## files, which files those are (official subparts, official parts, or
## nowhere), and what fetching them would take, each file on its own.
extends SceneTree

const PORT := 8841
const LIBRARY_DIR := "res://vendor/"
const SET := "res://vendor/omr/files/42082-1.mpd"

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _server: int = -1


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	CustomParts.dir = OS.get_user_data_dir().path_join("carried_fetch_probe_parts/")
	CustomParts.keeps = false
	Download.folder = OS.get_user_data_dir().path_join("carried_fetch_probe_downloads/")
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("carriedfetch: FAIL the catalogue does not load")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--census":
		_census(args[1], args.slice(2))
		quit(0)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.builder = _builder
	_store.library = _library
	_store.keeps = false
	await process_frame

	if args.size() >= 2 and args[0] == "--timing":
		await _timing(args.slice(1))
		quit(0)
		return
	if not await _serve():
		print("carriedfetch: FAIL could not serve the library on port %d" % PORT)
		quit(1)
		return
	await _nothing_to_fetch()
	await _any_order()
	await _fetched_as_the_web_does(SET)
	for path: String in args:
		await _fetched_as_the_web_does(path)
	await _one_session(PackedStringArray([SET, "res://vendor/omr/files/42115-1.mpd"]))
	await _restored()
	await _kept()
	await _kept_own()
	await _not_there()
	_web_page()
	OS.kill(_server)
	print("carriedfetch: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _expect(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## python3's http.server over the checkout's vendor/, so the library's parts/
## is at /ldraw/parts/ as the bucket has it. True once it answers.
func _serve() -> bool:
	_server = OS.create_process("python3", ["-m", "http.server", str(PORT), "--bind",
		"127.0.0.1", "--directory", ProjectSettings.globalize_path(LIBRARY_DIR)])
	if _server <= 0:
		return false
	for n: int in 50:
		var request := HTTPRequest.new()
		get_root().add_child(request)
		request.request("http://127.0.0.1:%d/ldraw/parts/s/3001s01.dat" % PORT)
		var result: Array = await request.request_completed
		request.queue_free()
		if int(result[1]) == 200:
			return true
		await create_timer(0.2).timeout
	return false


func _root() -> String:
	return "http://127.0.0.1:%d/" % PORT


## The web's state at the start of a session: nothing fetched, nothing
## refused, no file's parts built yet.
func _fresh() -> void:
	PartForge._fetched_lock.lock()
	PartForge._fetched.clear()
	PartForge._fetched_lock.unlock()
	CustomParts._unfetched.clear()
	CustomParts._skins_of_body.clear()
	CustomParts.skins.clear()
	_world.clear()
	for id: String in _library.custom.keys():
		var info: PartLibrary.PartInfo = _library.parts.get(id)
		if info != null:
			_library._custom_meshes.erase(info.mesh_hash)
		_library.parts.erase(id)
		_library.custom.erase(id)


func _open(text: String, name: String) -> Dictionary:
	_world.clear()
	return await _store.open_text_fetched(text, name)


## The carried parts and skins said not shown, by id.
static func _carried_unshown(opened: Dictionary, model: LdrModel) -> Array:
	var out: Array = []
	for id: String in (opened.get("unshown", {}) as Dictionary):
		if model.embedded_parts.has(id + ".dat") or id.contains("(flexible)"):
			out.append(id)
	return out


func _nothing_to_fetch() -> void:
	print("carriedfetch: nothing fetched or waited for where nothing is needed")
	_fresh()
	PartForge.withheld = true
	CustomParts.sources_from = _root()
	var frame: int = Engine.get_process_frames()
	var opened: Dictionary = await _open(FileAccess.get_file_as_string("res://models/house.ldr"),
		"house")
	_expect(int(opened["placed"]) > 0 and Engine.get_process_frames() == frame
		and PartForge._fetched.is_empty(),
		"a file that carries nothing: opened in the same frame, nothing fetched (%d parts)"
			% int(opened["placed"]))
	# The desktop: its library to hand, nowhere to fetch from.
	PartForge.withheld = false
	CustomParts.sources_from = ""
	var text: String = FileAccess.get_file_as_string(SET)
	frame = Engine.get_process_frames()
	opened = await _open(text, "42082-1")
	var model: LdrModel = LdrModel.parse(text, "42082-1")
	_expect(Engine.get_process_frames() == frame and PartForge._fetched.is_empty()
		and _carried_unshown(opened, model).is_empty(),
		"the desktop opens 42082-1 from its library, in the same frame, nothing fetched: %s"
			% [_carried_unshown(opened, model)])


## Answers come in any order (in a browser they did): a big file asked for
## first and three small ones after, each must be heard. Awaited one after
## another, an answer that came while an earlier one was awaited was never
## heard, and 21321-1 never opened in a browser.
func _any_order() -> void:
	print("carriedfetch: answers in any order")
	_fresh()
	var keys := PackedStringArray(["4510086c.dat", "s/3001s01.dat", "3004.dat", "79.dat"])
	var done: Array = [false]
	var fetch: Callable = func() -> void:
		await CustomParts._fetch_each(self, _root(), keys)
		done[0] = true
	fetch.call()
	var began: int = Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - began < 40000:
		await process_frame
	var heard: int = Array(keys).filter(func(key: String) -> bool:
		return not PartForge.fetched(key).is_empty()).size()
	_expect(done[0] and heard == keys.size(),
		"a 1.9 MB file first and three small: all %d heard, in %d ms (%d of them)"
			% [keys.size(), Time.get_ticks_msec() - began, heard])
	# What a fetched file names is fetched as it arrives, in the same batch:
	# nothing left for another pass.
	var left: PackedStringArray = PackedStringArray()
	for key: String in keys:
		left.append_array(PartForge.unreached(PartForge.fetched(key)))
	_expect(done[0] and left.is_empty(), "and what they name, as each came: %d files in all, %s left"
		% [PartForge._fetched.size(), left])
	_fresh()


func _fetched_as_the_web_does(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var name: String = path.get_file().get_basename()
	var model: LdrModel = LdrModel.parse(text, name)
	print("carriedfetch: %s" % path.get_file())
	# What the desktop builds from its library, to hold the web's to.
	_fresh()
	PartForge.withheld = false
	CustomParts.sources_from = ""
	var desktop: Dictionary = {}
	var carried: Dictionary = model.embedded_parts.duplicate()
	carried.merge(model.embedded_sources)
	for file_name: String in CustomParts._to_build(_library, model):
		if PartPrints.has_pictures(model.embedded_parts[file_name]) \
				or CustomParts.is_skin_text(model.embedded_parts[file_name]):
			continue
		var built: PartForge.Result = PartForge.build(model.embedded_parts[file_name],
			file_name.get_basename(), carried, true, null, false)
		if built.problem.is_empty():
			desktop[file_name.get_basename()] = built
	var opened: Dictionary = await _open(text, name)
	var on_desktop: Array = _carried_unshown(opened, model)

	# Withheld, with nowhere to fetch from: as the web was.
	_fresh()
	PartForge.withheld = true
	CustomParts.sources_from = ""
	var needs: PackedStringArray = CustomParts.unreached_by(_library, model)
	opened = await _open(text, name)
	var before: Array = _carried_unshown(opened, model)
	print("  note without the library's files: %d carried parts not shown (%s), %d files named"
		% [before.size(), ", ".join(PackedStringArray(before.slice(0, 5))), needs.size()])

	# Fetched, as the web does.
	_fresh()
	PartForge.withheld = true
	CustomParts.sources_from = _root()
	var began: int = Time.get_ticks_msec()
	opened = await _open(text, name)
	var took: int = Time.get_ticks_msec() - began
	var after: Array = _carried_unshown(opened, model)
	var fetched: Array = PartForge._fetched.keys()
	print("  note fetched %d files (%s) and opened in %d ms; %s"
		% [fetched.size(), ", ".join(PackedStringArray(fetched.slice(0, 4))), took,
			_store.open_phases])
	_expect(after == on_desktop, "fetched, the carried parts not shown are the desktop's: %s (desktop %s)"
		% [after, on_desktop])
	_expect(needs.is_empty() or not fetched.is_empty(),
		"what it named was fetched: %d named, %d fetched" % [needs.size(), fetched.size()])
	for key: String in fetched:
		if not FileAccess.file_exists(LIBRARY_DIR + "ldraw/parts/" + key):
			_expect(false, "fetched only the library's files: %s is not one" % key)
	var same: int = 0
	var differ := PackedStringArray()
	for id: String in desktop:
		var info: PartLibrary.PartInfo = _library.parts.get(id)
		var want: PartForge.Result = desktop[id]
		if info != null and info.triangles == want.triangles \
				and info.bounds.size.is_equal_approx(Vector3(want.bounds_max[0] - want.bounds_min[0],
					want.bounds_max[1] - want.bounds_min[1], want.bounds_max[2] - want.bounds_min[2])):
			same += 1
		else:
			differ.append(id)
	_expect(differ.is_empty(), "each carried part built as the desktop builds it: %d the same%s"
		% [same, "" if differ.is_empty() else ", not " + ", ".join(differ.slice(0, 5))])

	# Again: kept for the session.
	var frame: int = Engine.get_process_frames()
	var count: int = PartForge._fetched.size()
	opened = await _open(text, name)
	_expect(Engine.get_process_frames() == frame and PartForge._fetched.size() == count
		and _carried_unshown(opened, model) == on_desktop,
		"opened again: nothing fetched, no frame waited for")
	PartForge.withheld = false
	CustomParts.sources_from = ""


## Files opened one after another in one session, as a person does: each
## with every part it carries (a browser left 42115-1's out after 42082-1).
func _one_session(paths: PackedStringArray) -> void:
	print("carriedfetch: one file after another in one session")
	_fresh()
	PartForge.withheld = true
	CustomParts.sources_from = _root()
	for path: String in paths:
		var text: String = FileAccess.get_file_as_string(path)
		var name: String = path.get_file().get_basename()
		var opened: Dictionary = await _open(text, name)
		var out: Array = _carried_unshown(opened, LdrModel.parse(text, name))
		_expect(out.is_empty(), "%s: every part it carries shown (%d parts, %d files fetched so far): %s"
			% [name, int(opened["placed"]), PartForge._fetched.size(), out])
	PartForge.withheld = false
	CustomParts.sources_from = ""


## The working model, put back at start-up (Main: ModelStore.restore_fetched),
## is a file opened like any other: what its carried parts need fetched first.
func _restored() -> void:
	print("carriedfetch: the working model put back at start-up")
	TabSession.use("carriedfetchprobe")
	var path: String = ModelStore.autosave()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/21321-1.mpd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_fresh()
	PartForge.withheld = true
	CustomParts.sources_from = _root()
	var placed: int = await _store.restore_fetched()
	var out: Array = _carried_unshown({"unshown": _store.unshown}, LdrModel.parse(text, "21321-1"))
	_expect(placed > 0 and out.is_empty() and not PartForge._fetched.is_empty(),
		"21321-1 restored with every part it carries: %d parts, %d files fetched, not shown %s"
			% [placed, PartForge._fetched.size(), out])
	DirAccess.remove_absolute(path)
	PartForge.withheld = false
	CustomParts.sources_from = ""


## A carried part kept from a file (CustomParts.dir), drawn from a library
## subpart: built at start-up once that is fetched, not said not to build.
func _kept() -> void:
	print("carriedfetch: a part kept from a file, at start-up")
	_fresh()
	PartForge.withheld = true
	CustomParts.sources_from = _root()
	DirAccess.make_dir_recursive_absolute(CustomParts.dir)
	var path: String = CustomParts.dir + "probe-wall.dat"
	var model: LdrModel = LdrModel.parse(WALL, "wall")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(str(model.embedded_parts["probe-wall.dat"]))
	file.close()
	CustomParts.load_all(_library)
	var began: int = Time.get_ticks_msec()
	while not _library.parts.has("probe-wall") and Time.get_ticks_msec() - began < 20000:
		await process_frame
	_expect(_library.parts.has("probe-wall") and not PartForge.fetched("s/3001s01.dat").is_empty(),
		"built once its subpart came, in %d ms" % (Time.get_ticks_msec() - began))
	DirAccess.remove_absolute(path)
	PartForge.withheld = false
	CustomParts.sources_from = ""


## A carried part drawn from a subpart its own file carries, kept: at the
## next start, the file gone, it is built from what was kept beside it with
## nothing to fetch, and a model saved then carries the subpart again. Kept
## as the part alone, 19 of the sets' carried parts were not built at the
## next start (2026-10-17).
func _kept_own() -> void:
	print("carriedfetch: a part kept with the subpart its file carried")
	_fresh()
	CustomParts.drawn_from.clear()
	CustomParts.keeps = true
	var taken: Dictionary = CustomParts.take_from(_library, LdrModel.parse(GATE, "gate"))
	CustomParts.keeps = false
	var beside: String = CustomParts.dir + "probe-gate" + CustomParts.NEEDS
	_expect((taken["added"] as PackedStringArray).has("probe-gate"),
		"built from the file it came in: %s" % [taken["problems"]])
	_expect(FileAccess.file_exists(beside), "kept with its subpart beside it")
	# The next start: the file gone, and the library and what each part was
	# drawn from forgotten; only the server to fetch from, as on the web.
	_fresh()
	CustomParts.drawn_from.clear()
	PartForge.withheld = true
	CustomParts.sources_from = _root()
	CustomParts.load_all(_library)
	var began: int = Time.get_ticks_msec()
	while not _library.parts.has("probe-gate") and Time.get_ticks_msec() - began < 20000:
		await process_frame
	_expect(_library.parts.has("probe-gate"),
		"built at the next start from what was kept, in %d ms" % (Time.get_ticks_msec() - began))
	var drawn: Dictionary = CustomParts.drawn_from.get("probe-gate", {})
	_expect(drawn.has("s/probe-gate-s01.dat"),
		"and a model saved now carries its subpart: %s" % [drawn.keys()])
	DirAccess.remove_absolute(CustomParts.dir + "probe-gate.dat")
	DirAccess.remove_absolute(beside)
	PartForge.withheld = false
	CustomParts.sources_from = ""


## A carried part drawn from a subpart of the file's own.
const GATE := """0 FILE gate.ldr
0 Gate
0 Name: gate.ldr
0 Author: Somebody Else
1 4 0 0 0 1 0 0 0 1 0 0 0 1 probe-gate.dat
0 NOFILE
0 FILE probe-gate.dat
0 A gate drawn from its file's own subpart
0 Name: probe-gate.dat
0 Author: Somebody Else
0 !LDRAW_ORG Unofficial_Part
0 BFC CERTIFY CCW
1 16 0 0 0 1 0 0 0 1 0 0 0 1 s/probe-gate-s01.dat
0 NOFILE
0 FILE s/probe-gate-s01.dat
0 A gate's post
0 Name: s/probe-gate-s01.dat
0 Author: Somebody Else
0 !LDRAW_ORG Unofficial_Subpart
0 BFC CERTIFY CCW
1 16 0 0 0 4 0 0 0 24 0 0 0 4 4-4cyli.dat
0 NOFILE
"""


## A carried part drawn from a library subpart the server has not got.
const WALL := """0 FILE wall.ldr
0 Wall
0 Name: wall.ldr
0 Author: Somebody Else
1 4 0 0 0 1 0 0 0 1 0 0 0 1 probe-wall.dat
1 4 40 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
0 FILE probe-wall.dat
0 A wall drawn from a library subpart
0 Name: probe-wall.dat
0 Author: Somebody Else
0 !LDRAW_ORG Unofficial_Part
0 BFC CERTIFY CCW
1 16 0 0 0 1 0 0 0 1 0 0 0 1 s/3001s01.dat
0 NOFILE
"""


func _not_there() -> void:
	print("carriedfetch: a file the server has not got")
	_fresh()
	PartForge.withheld = true
	CustomParts.sources_from = _root() + "nowhere/"
	var opened: Dictionary = await _open(WALL, "wall")
	var unshown: Dictionary = opened.get("unshown", {})
	_expect(unshown.has("probe-wall") and int(opened["placed"]) == 1,
		"the part drawn from it said not shown, the rest opened: %s" % unshown)
	var why: Array = CustomParts._unfetched.get("s/3001s01.dat", ["", false])
	_expect(str(why[0]) == "not there (HTTP 404)" and not bool(why[1]),
		"why kept, and not asked again this session: %s" % [why])
	var problem: String = CustomParts._with_why(
		"it uses parts this build does not have: s/3001s01.dat")
	_expect(problem.contains("not there (HTTP 404)"), "and said with the part: %s" % problem)
	# Served, it builds.
	CustomParts.sources_from = _root()
	CustomParts._unfetched.clear()
	opened = await _open(WALL, "wall")
	_expect(int(opened["placed"]) == 2 and (opened.get("unshown", {}) as Dictionary).is_empty(),
		"from where it is: both parts, nothing said not shown")
	PartForge.withheld = false
	CustomParts.sources_from = ""


func _web_page() -> void:
	print("carriedfetch: a web page is not LDraw")
	var page: PackedByteArray = "<!doctype html><html><body>Brickworks</body></html>".to_utf8_buffer()
	_expect(CustomParts._fetch_problem(HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(["Content-Type: text/html; charset=utf-8"]), page) != "",
		"a page said to be HTML, status 200: refused")
	_expect(CustomParts._fetch_problem(HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(["Content-Type: application/octet-stream"]), page) != "",
		"a page said to be anything else: refused by what it is")
	_expect(CustomParts._fetch_problem(HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(["Content-Type: text/plain"]), "0 ~Subpart\n".to_utf8_buffer()) == "",
		"LDraw text: taken")


# -- what looking costs --------------------------------------------------------


func _timing(paths: PackedStringArray) -> void:
	PartForge.withheld = true
	for path: String in paths:
		var text: String = FileAccess.get_file_as_string(path)
		var name: String = path.get_file().get_basename()
		var ways: Dictionary = {"looked": [], "not": []}
		var looks: Array = []
		for n: int in 10:
			var looking: bool = n % 2 == 0
			_fresh()
			# Somewhere to fetch from that is never reached: a file that needs
			# nothing asks nothing of it.
			CustomParts.sources_from = "http://127.0.0.1:9/" if looking else ""
			var began: int = Time.get_ticks_usec()
			var opened: Dictionary = await _open(text, name)
			var ms: float = (Time.get_ticks_usec() - began) / 1000.0
			(ways["looked" if looking else "not"] as Array).append(ms)
			if looking:
				looks.append(float(_store.open_phases.get("fetch", 0.0)))
			if not CustomParts._unfetched.is_empty():
				print("  note %s needs files fetched: %s" % [name, CustomParts._unfetched.keys()])
		for way: String in ways:
			(ways[way] as Array).sort()
		looks.sort()
		print("carriedfetch timing: %s opened in %.0f ms looking first, %.0f ms not (medians of 5; looking itself %.1f ms)"
			% [name, ways["looked"][2], ways["not"][2], looks[2]])
	PartForge.withheld = false
	CustomParts.sources_from = ""


# -- the census ---------------------------------------------------------------


func _census(out: String, files: PackedStringArray) -> void:
	if files.is_empty():
		for file_name: String in DirAccess.get_files_at("res://vendor/omr/files/"):
			if file_name.get_extension().to_lower() in ["mpd", "ldr"]:
				files.append("res://vendor/omr/files/" + file_name)
	var rows: Array = []
	var kinds: Dictionary = {}           ## kind -> {name: files using it}
	var all_fetched: Dictionary = {}     ## name -> bytes
	var started: int = Time.get_ticks_msec()
	var slowest: Array = [0.0, ""]
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		var model: LdrModel = LdrModel.parse(text, path.get_file().get_basename())
		if model == null or (model.embedded_parts.is_empty() and model.generated.is_empty()):
			continue
		PartForge._fetched.clear()
		PartForge.withheld = true
		var began: int = Time.get_ticks_usec()
		var named: PackedStringArray = CustomParts.unreached_by(_library, model)
		var spent: float = (Time.get_ticks_usec() - began) / 1000.0
		if spent > float(slowest[0]):
			slowest = [spent, path.get_file()]
		if named.is_empty():
			continue
		# Which parts it leaves out, and how many copies of each.
		var carried: Dictionary = model.embedded_parts.duplicate()
		carried.merge(model.embedded_sources)
		var out_ids: Dictionary = {}
		for file_name: String in CustomParts._to_build(_library, model):
			if not PartForge.unreached(model.embedded_parts[file_name], carried).is_empty():
				out_ids[file_name.get_basename()] = 0
		var skins_out: Array = _skins_out(model)
		var copies: int = 0
		for placement: LdrModel.Placement in model.flatten(_library.parts):
			if out_ids.has(placement.part_id):
				out_ids[placement.part_id] = int(out_ids[placement.part_id]) + 1
				copies += 1
		# What fetching takes: rounds until nothing more can be had.
		var fetched: Dictionary = {}
		var nowhere: Dictionary = {}
		for _pass: int in 32:
			var more: bool = false
			for key: String in CustomParts.unreached_by(_library, model):
				if fetched.has(key) or nowhere.has(key):
					continue
				var source: String = LIBRARY_DIR + "ldraw/parts/" + key
				if FileAccess.file_exists(source):
					var body: String = FileAccess.get_file_as_string(source)
					PartForge.keep_fetched(key, body)
					fetched[key] = FileAccess.get_file_as_bytes(source).size()
					all_fetched[key] = fetched[key]
					more = true
				else:
					nowhere[key] = _kind(key)
			if not more:
				break
		for key: String in named:
			var kind: String = _kind(key)
			if not kinds.has(kind):
				kinds[kind] = {}
			(kinds[kind] as Dictionary)[key] = int((kinds[kind] as Dictionary).get(key, 0)) + 1
		# And the desktop's, for the same file: what it cannot build either.
		PartForge._fetched.clear()
		PartForge.withheld = false
		var on_desktop: PackedStringArray = CustomParts.unreached_by(_library, model)
		var bytes: int = 0
		for key: String in fetched:
			bytes += int(fetched[key])
		rows.append({"file": path.get_file(), "named": named, "parts_out": out_ids,
			"copies_out": copies, "skins_out": skins_out,
			"fetched": fetched.size(), "fetched_bytes": bytes,
			"nowhere": nowhere, "desktop_unreached": on_desktop, "unreached_ms": spent})
	PartForge._fetched.clear()
	PartForge.withheld = false
	var parts_out: int = 0
	var copies_out: int = 0
	var skins: int = 0
	var all_bytes: int = 0
	for row: Dictionary in rows:
		parts_out += (row["parts_out"] as Dictionary).size()
		copies_out += int(row["copies_out"])
		skins += (row["skins_out"] as Array).size()
	for key: String in all_fetched:
		all_bytes += int(all_fetched[key])
	var summary: Dictionary = {"files_read": files.size(), "files_short": rows.size(),
		"carried_parts_out": parts_out, "copies_out": copies_out, "skins_out": skins,
		"names_by_kind": {}, "fetch_all_files": all_fetched.size(), "fetch_all_bytes": all_bytes,
		"slowest_unreached_ms": slowest, "seconds": (Time.get_ticks_msec() - started) / 1000.0}
	for kind: String in kinds:
		summary["names_by_kind"][kind] = (kinds[kind] as Dictionary).size()
	print("carriedfetch census: %d files read, %d carry parts the web cannot build without the library's files"
		% [files.size(), rows.size()])
	print("  %d carried parts, %d copies of them, %d flexible parts; files named: %s" % [parts_out,
		copies_out, skins, summary["names_by_kind"]])
	print("  fetching all of it: %d files, %.1f MB; slowest look %.1f ms (%s)" % [all_fetched.size(),
		all_bytes / 1e6, float(slowest[0]), slowest[1]])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["copies_out"]) > int(b["copies_out"]))
	for row: Dictionary in rows.slice(0, 25):
		print("  %-36s %3d parts %4d copies %2d skins, fetch %3d files %6.1f KB, nowhere %s, desktop %s" % [
			row["file"], (row["parts_out"] as Dictionary).size(), row["copies_out"],
			(row["skins_out"] as Array).size(), row["fetched"],
			int(row["fetched_bytes"]) / 1024.0, (row["nowhere"] as Dictionary).keys(),
			row["desktop_unreached"]])
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"summary": summary, "rows": rows}, " "))
		file.close()
		print("  wrote %s" % out)


## The sub-models whose flexible part's skin draws on a file this build
## cannot read, as CustomParts.unreached_by finds them.
func _skins_out(model: LdrModel) -> Array:
	var out: Array = []
	var sources: Dictionary = model.section_texts.duplicate()
	sources.merge(model.embedded_sources)
	var pieces: Dictionary = {}
	for key: String in model.generated:
		var sub: LdrModel.SubModel = model.submodels.get(key)
		if sub == null:
			continue
		var made_of: Dictionary = CustomParts._skin_text(_library, model, sub,
			str(model.section_texts.get(sub.name.to_lower(), "")), pieces)
		if not made_of.is_empty() and not PartForge.unreached(str(made_of["text"]), sources).is_empty():
			out.append(sub.name)
	return out


## What kind of file [param key] is in the checkout's library.
static func _kind(key: String) -> String:
	if FileAccess.file_exists(LIBRARY_DIR + "ldraw/parts/" + key):
		return "official subpart" if key.begins_with("s/") else "official part"
	if FileAccess.file_exists(LIBRARY_DIR + "ldraw/p/" + key):
		return "primitive"
	if FileAccess.file_exists(LIBRARY_DIR + "ldraw/unofficial/parts/" + key) \
			or FileAccess.file_exists(LIBRARY_DIR + "ldraw/unofficial/p/" + key):
		return "unofficial library"
	return "nowhere"
