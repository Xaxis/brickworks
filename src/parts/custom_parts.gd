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

## Whether a part a model file carries is kept for next time. Off for a
## model shared by link and opened to look at: somebody else's parts
## are built for this visit only, and nothing is written.
static var keeps: bool = true


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


## Make a part by changing one that exists (see [PartEditor]), add it to
## the library and keep it. The part's geometry has to be to hand
## ([method PartLibrary.mesh_for]); on the web that can mean fetching it
## first. Returns {"id", "problem"}, as [method make] does.
static func make_modified(library: PartLibrary, edit: PartEditor.Edit,
		keep: bool = true) -> Dictionary:
	var result: Dictionary = modified_text(library, edit)
	if not str(result["problem"]).is_empty():
		return {"id": "", "problem": result["problem"]}
	return add(library, result["text"], result["id"], keep)


## The part file an edit makes, under an id no other part has unless it is
## this very part: {"text", "id", "problem"}.
static func modified_text(library: PartLibrary, edit: PartEditor.Edit) -> Dictionary:
	var info: PartLibrary.PartInfo = library.parts.get(edit.from)
	if info == null:
		return {"text": "", "id": "", "problem": "there is no part %s" % edit.from}
	var mesh: Lbm.PartMesh = library.mesh_for(edit.from)
	var category: String = info.ldraw_category if info.custom else info.category
	var base: String = PartEditor.id_for(edit)
	var id: String = base
	var made: Dictionary = PartEditor.make_dat(edit, mesh, info.name, category, id)
	var n: int = 1
	while made["problem"] == "" and library.parts.has(id) \
			and library.custom_source(id) != str(made["text"]):
		n += 1
		id = "%s-%d" % [base, n]
		made = PartEditor.make_dat(edit, mesh, info.name, category, id)
	return {"text": made["text"], "id": id, "problem": made["problem"]}


## Add a part from its LDraw text: built, registered and, with [param
## keep], written to [member dir]. [param others] are files it may draw on
## from the same model file. [param built]: the part built already
## ([method _built_at_once]), or null to build it here.
static func add(library: PartLibrary, text: String, id: String, keep: bool = true,
		others: Dictionary = {}, built: PartForge.Result = null) -> Dictionary:
	if built == null:
		built = _built(library, text, id, others)
	if not built.problem.is_empty():
		return {"id": id, "problem": built.problem}
	var base: String = PartPrints.base_in(text)
	if not base.is_empty():
		PartPrints.bases[id] = base
	var info: PartLibrary.PartInfo = info_for(built)
	# Prints and stickers in bins of their own, as the bin shows them.
	info.category = PartPrints.bin_for(text)
	var skin: bool = is_skin_text(text)
	if skin:
		# A file's hose, not a part to pick from the bin, and not kept.
		info.category = SKIN_CATEGORY
		info.reachable = false
		info.keywords = PackedStringArray(["flexible", "ldcad"])
	library.add_custom(info, built.mesh, text)
	if keep and not skin:
		DirAccess.make_dir_recursive_absolute(dir)
		var file: FileAccess = FileAccess.open(dir + id + ".dat", FileAccess.WRITE)
		if file == null:
			return {"id": id, "problem": "it was made but could not be kept (%d)"
				% FileAccess.get_open_error()}
		file.store_string(text)
		file.close()
		_keep_needs(id, needs(text, others))
		for name: String in built.mesh.print_files:
			var picture: FileAccess = FileAccess.open(dir + name, FileAccess.WRITE)
			if picture != null:
				picture.store_buffer(built.mesh.print_files[name])
				picture.close()
	return {"id": id, "problem": ""}


## Beside a kept part, the subparts and parts it is drawn from that the file
## it came in carried ([method needs]), as one file of FILE sections; none
## when it needs nothing of the file's. Kept as the part alone, it was not
## built at the next start (the file was gone), and a model saved after
## that went out without them: 19 of the sets' carried parts (2026-10-17).
static func _keep_needs(id: String, needed: Dictionary) -> void:
	var path: String = dir + id + NEEDS
	if needed.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	var out := PackedStringArray()
	for name: String in needed:
		out.append("0 FILE %s" % name)
		out.append(str(needed[name]).strip_edges(false, true))
		out.append("0 NOFILE")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(out) + "\n")
		file.close()


## What [method _keep_needs] kept for [param id]: name -> text, or {}.
static func _kept_needs(id: String) -> Dictionary:
	var path: String = dir + id + NEEDS
	if not FileAccess.file_exists(path):
		return {}
	var out: Dictionary = {}
	var name: String = ""
	var lines := PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("0 FILE "):
			name = line.trim_prefix("0 FILE ").strip_edges()
			lines = PackedStringArray()
		elif line.strip_edges() == "0 NOFILE" and not name.is_empty():
			out[name] = "\n".join(lines) + "\n"
			name = ""
		elif not name.is_empty():
			lines.append(line)
	return out


## The file beside a kept part that holds what it is drawn from.
const NEEDS := ".needs.ldr"


## A part built from its LDraw text, as [method add] builds it.
static func _built(library: PartLibrary, text: String, id: String,
		others: Dictionary) -> PartForge.Result:
	# A print drawn here carries pictures (PartPrints): from the model file
	# it came in, or kept beside it.
	var pictures: Dictionary = {}
	var sources: Dictionary = {}
	for name: String in others:
		if others[name] is PackedByteArray:
			pictures[name.to_lower()] = others[name]
		else:
			sources[name] = others[name]
	var built: PartForge.Result
	if PartPrints.has_pictures(text):
		for name: String in PartPrints.pictures_named(text):
			if not pictures.has(name.to_lower()) and FileAccess.file_exists(dir + name):
				pictures[name.to_lower()] = FileAccess.get_file_as_bytes(dir + name)
			if pictures.has(name.to_lower()):
				pictures[name] = pictures[name.to_lower()]
		built = PartPrints.build(text, id, pictures, library, sources)
	elif is_skin_text(text):
		built = PartForge.build_skin(text, id, sources)
	else:
		built = PartForge.build(text, id, sources)
	return built


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
## On the web one drawn from LDraw's own files is built once they are
## fetched ([method _load_later]): a carried part a file brought, kept, was
## said at every start not to build.
static func load_all(library: PartLibrary) -> int:
	var found: int = 0
	if not DirAccess.dir_exists_absolute(dir):
		return 0
	var texts: Dictionary = {}
	## file name -> what it was kept with (_keep_needs), for those kept so.
	var sources: Dictionary = {}
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".dat"):
			texts[file_name] = FileAccess.get_file_as_string(dir + file_name)
			var needed: Dictionary = _kept_needs(file_name.get_basename())
			if not needed.is_empty():
				sources[file_name] = needed
				drawn_from[file_name.get_basename()] = needed
	var later: Dictionary = {}
	if OS.has_feature("web") or not sources_from.is_empty():
		for file_name: String in texts.keys():
			if not PartForge.unreached(texts[file_name], sources.get(file_name, {})).is_empty():
				later[file_name] = texts[file_name]
				texts.erase(file_name)
	if not later.is_empty():
		_load_later(library, later, sources)
	# Those kept with sources are built each with its own: two files may
	# carry a subpart of one name drawn two ways.
	var alone: Dictionary = {}
	for file_name: String in sources:
		if texts.has(file_name):
			alone[file_name] = texts[file_name]
			texts.erase(file_name)
	var built: Dictionary = _built_at_once(texts, {})
	for file_name: String in alone:
		var id: String = file_name.get_basename()
		var result: Dictionary = add(library, alone[file_name], id, false, sources[file_name])
		if str(result["problem"]).is_empty():
			found += 1
		else:
			push_warning("custom part %s: %s" % [id, result["problem"]])
	for file_name: String in texts:
		var id: String = file_name.get_basename()
		var result: Dictionary = add(library, texts[file_name], id, false, {},
			built.get(file_name))
		if str(result["problem"]).is_empty():
			found += 1
		else:
			push_warning("custom part %s: %s" % [id, result["problem"]])
	return found


## The kept parts [param texts] (file name -> text) draw on files of LDraw's
## own: fetched, once the deployment says where from, then built and added.
static func _load_later(library: PartLibrary, texts: Dictionary,
		sources: Dictionary = {}) -> void:
	await _fetch_until(library, func() -> PackedStringArray:
		var named: Dictionary = {}
		for file_name: String in texts:
			for key: String in PartForge.unreached(texts[file_name], sources.get(file_name, {})):
				named[key] = true
		return PackedStringArray(named.keys()))
	for file_name: String in texts:
		var id: String = file_name.get_basename()
		if library.parts.has(id):
			continue
		var result: Dictionary = add(library, texts[file_name], id, false,
			sources.get(file_name, {}))
		if not str(result["problem"]).is_empty():
			push_warning("custom part %s: %s" % [id, result["problem"]])


## The parts a model file carries, added to the library so the model can
## be opened. A part the library already has as one of LEGO's is left to
## the library: a file cannot redefine 3001. Returns {"added": [ids],
## "problems": [sentences]}.
static func take_from(library: PartLibrary, model: LdrModel) -> Dictionary:
	var added: PackedStringArray = PackedStringArray()
	var problems: PackedStringArray = PackedStringArray()
	# Everything a part may be drawn from: the other parts, and the subparts
	# and primitives the file carries for them (LdrModel.embedded_sources).
	var carried: Dictionary = model.embedded_parts.duplicate()
	carried.merge(model.embedded_sources)
	carried.merge(model.embedded_data)
	var wanted: PackedStringArray = PackedStringArray()
	# LDCad's skins first, each on a thread of its own: built while the parts
	# the file carries are built here, and in the model before it opens.
	var skins_begun: Array = begin_skins(library, model, problems)
	wanted = _to_build(library, model)
	var texts: Dictionary = {}
	for file_name: String in wanted:
		texts[file_name] = model.embedded_parts[file_name]
	var built: Dictionary = _built_at_once(texts, carried)
	for file_name: String in wanted:
		var id: String = file_name.get_basename()
		var text: String = model.embedded_parts[file_name]
		var result: Dictionary = add(library, text, id,
			keeps and not FileAccess.file_exists(dir + id + ".dat"), carried,
			built.get(file_name))
		if str(result["problem"]).is_empty():
			added.append(id)
			drawn_from[id] = needs(text, model.embedded_sources)
			# One kept before its sources were kept beside it gets them now,
			# from the file it came in.
			if keeps and not FileAccess.file_exists(dir + id + NEEDS) \
					and FileAccess.file_exists(dir + id + ".dat") \
					and FileAccess.get_file_as_string(dir + id + ".dat") == text:
				_keep_needs(id, needs(text, carried))
		else:
			problems.append("%s: %s" % [id, _with_why(str(result["problem"]))])
	var flexible: PackedStringArray = end_skins(library, model, skins_begun, problems)
	return {"added": added, "problems": problems, "skins": flexible}


## The parts [param model] carries that [method take_from] builds, by file
## name: not one of the library's own, and not one built already as it is.
static func _to_build(library: PartLibrary, model: LdrModel) -> PackedStringArray:
	var wanted := PackedStringArray()
	for file_name: String in model.embedded_parts:
		var id: String = file_name.get_basename()
		var text: String = model.embedded_parts[file_name]
		var info: PartLibrary.PartInfo = library.parts.get(id)
		if info != null and not info.custom:
			continue
		if info != null and library.custom_source(id) == text:
			continue
		# A part Studio drew itself that LDraw has since drawn (bl_5095 is
		# 5095): the library's, as ModelStore.studio_part reads the name.
		var plain: PartLibrary.PartInfo = library.parts.get(id.trim_prefix("bl_"))
		if id.begins_with("bl_") and plain != null and not plain.custom:
			continue
		wanted.append(file_name)
	return wanted


# -- The library's own files, fetched -----------------------------------------
#
# A part a file carries is drawn from LDraw text: the file's own sections,
# the primitives every build ships (PartForge.SHIPPED), and often the
# library's own subparts and parts, which a desktop reads from vendor/ldraw
# and no build ships (parts/ is 34,000 files, 601 MB). 42082-1's three
# 13971 are drawn from s\13971s01.dat. So the web fetches the ones a file
# needs, from beside the geometry (tools/storage_ldraw.py put the library's
# parts/ there, under ldraw/), before the file opens, and keeps them for the
# session.


## Where the library's files are fetched from: "" for the default, which is
## beside the geometry on the web (PartLibrary.remote_parts) and nowhere on
## the desktop, which reads them from vendor/ldraw. A probe points it at a
## server of its own.
static var sources_from: String = ""
## Under the root: the library's parts/ as LDraw lays it out.
const SOURCES_DIR := "ldraw/parts/"
## Fetches open at once, as PartLibrary.MAX_IN_FLIGHT.
const MOST_FETCHES := 6
## How long a file waits for the deployment to say where geometry lives,
## at start-up, before its carried parts are built without what it names.
const DEPLOYMENT_WAIT_MS := 20000
## Names that could not be fetched -> [why, whether to ask again]: not
## there (asked once a session), or the network failing (asked next time).
static var _unfetched: Dictionary = {}


## The root the library's files are fetched from, or "" for nowhere.
static func fetch_root(library: PartLibrary) -> String:
	if not sources_from.is_empty():
		return sources_from.rstrip("/") + "/"
	if OS.has_feature("web") and not library.remote_parts.is_empty():
		return library.remote_parts.rstrip("/") + "/"
	return ""


## The files the parts [param model] carries and its flexible parts are drawn
## from that this build cannot read (PartForge.unreached), each once: what
## [method take_from] would leave them out for. On the desktop, with the
## library to hand, only what is nowhere.
static func unreached_by(library: PartLibrary, model: LdrModel) -> PackedStringArray:
	var found: Dictionary = {}
	var wanted: PackedStringArray = _to_build(library, model)
	if not wanted.is_empty():
		var carried: Dictionary = {}
		for name: String in model.embedded_parts:
			carried[name] = model.embedded_parts[name]
		carried.merge(model.embedded_sources)
		for file_name: String in wanted:
			for key: String in PartForge.unreached(model.embedded_parts[file_name], carried):
				found[key] = true
	if not model.generated.is_empty():
		var sources: Dictionary = model.section_texts.duplicate()
		sources.merge(model.embedded_sources)
		var pieces: Dictionary = {}
		for key: String in model.generated:
			var sub: LdrModel.SubModel = model.submodels.get(key)
			if sub == null:
				continue
			var body: String = str(model.section_texts.get(sub.name.to_lower(), ""))
			var seen: Array = _skins_of_body.get(body, [])
			if not seen.is_empty() and (str(seen[0]).is_empty() or library.parts.has(seen[0])):
				continue
			if not model.skin_texts.has(body):
				model.skin_texts[body] = _skin_text(library, model, sub, body, pieces)
			var made_of: Dictionary = model.skin_texts[body]
			if made_of.is_empty():
				continue
			made_of["unreached"] = PartForge.unreached(str(made_of["text"]), sources)
			for name: String in made_of["unreached"]:
				found[name] = true
	return PackedStringArray(found.keys())


## Fetch what [param model]'s carried parts and flexible parts are drawn from
## that this build has not got, before it opens ([method unreached_by]):
## a few at a time, from [method fetch_root], and again for what those draw
## on, the status bar saying so while it waits. Kept for the session
## (PartForge.keep_fetched). One that cannot be had is left, and the part
## drawn from it is said not shown when the file opens, with why. Nothing
## to do, and nothing waited for, on the desktop or for a file that needs
## nothing.
static func fetch_sources(library: PartLibrary, model: LdrModel) -> void:
	if model == null or (model.embedded_parts.is_empty() and model.generated.is_empty()):
		return
	await _fetch_until(library, func() -> PackedStringArray:
		return unreached_by(library, model))


## Fetch what [param named] (a callable giving the names still unreached)
## names, until it names nothing that can be had: [method fetch_sources]'s
## loop, for a file or for kept parts.
static func _fetch_until(library: PartLibrary, named: Callable) -> void:
	if not OS.has_feature("web") and sources_from.is_empty():
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	# The network's failures of last time are asked again.
	for key: String in _unfetched.keys():
		if bool(_unfetched[key][1]):
			_unfetched.erase(key)
	var job: Working.Job = null
	var waited_from: int = Time.get_ticks_msec()
	# What the files fetched draw on is fetched as each arrives
	# (_fetch_each); a pass after looks again, for what failed. Bounded, as a
	# reference that loops would not be.
	for _pass: int in 32:
		var wanted := PackedStringArray()
		for key: String in named.call():
			if not _unfetched.has(key):
				wanted.append(key)
		if wanted.is_empty():
			break
		if job == null:
			job = Working.begin("Fetching the LDraw files carried parts are drawn from…")
		# At start-up the deployment may not have said where yet.
		while fetch_root(library).is_empty() \
				and Time.get_ticks_msec() - waited_from < DEPLOYMENT_WAIT_MS:
			await tree.process_frame
		var root: String = fetch_root(library)
		if root.is_empty():
			for key: String in wanted:
				_unfetched[key] = ["nowhere to fetch it from yet", true]
			break
		await _fetch_each(tree, root, wanted, job)
	if job != null:
		job.end()


## Fetch [param keys] from [param root], [constant MOST_FETCHES] at a time,
## and what each names that is not here yet as it arrives: a subpart's own
## subparts, asked for at once rather than after the rest (a frame drawing a
## big model in software can take seconds, and each request is polled once
## a frame). [param job] says how many. How many arrived.
##
## Each answer is taken by a callable of its own, whenever it comes. Awaited
## one after another, an answer that came while an earlier one was awaited
## was never heard, and in a browser, where answers come in any order,
## 21321-1 waited for ever before it opened.
static func _fetch_each(tree: SceneTree, root: String, keys: PackedStringArray,
		job: Working.Job = null) -> int:
	var arrived: Array = [0]
	var going: Array = [0]
	var todo: Array = Array(keys)
	var asked: Dictionary = {}
	for key: String in keys:
		asked[key] = true
	var say: Callable = func() -> void:
		if job != null:
			job.say("Fetching %d LDraw %s carried parts are drawn from…"
				% [asked.size(), "file" if asked.size() == 1 else "files"])
	say.call()
	while not todo.is_empty() or int(going[0]) > 0:
		while not todo.is_empty() and int(going[0]) < MOST_FETCHES:
			var key: String = todo.pop_front()
			# No time limit, as the geometry's fetches have none. One is polled
			# once a frame, and a frame drawing a big model in software can take
			# seconds: 42115-1 opened after 42082-1 had all six of its files
			# arrive in the browser and given up on by a 30 s limit.
			var request := HTTPRequest.new()
			tree.root.add_child(request)
			request.request_completed.connect(func(result: int, code: int,
					headers: PackedStringArray, body: PackedByteArray) -> void:
				request.queue_free()
				going[0] = int(going[0]) - 1
				if not _took(key, result, code, headers, body):
					return
				arrived[0] = int(arrived[0]) + 1
				for named: String in PartForge.unreached(PartForge.fetched(key)):
					if not asked.has(named) and not _unfetched.has(named):
						asked[named] = true
						todo.append(named)
						say.call(), CONNECT_ONE_SHOT)
			if request.request(root + SOURCES_DIR + key.uri_encode().replace("%2F", "/")) != OK:
				_unfetched[key] = ["the request could not start", true]
				request.queue_free()
				continue
			going[0] = int(going[0]) + 1
		await tree.process_frame
	return int(arrived[0])


## Keep what came for [param key], or why it is not LDraw. Whether it was.
static func _took(key: String, result: int, code: int, headers: PackedStringArray,
		body: PackedByteArray) -> bool:
	var why: String = _fetch_problem(result, code, headers, body)
	if not why.is_empty():
		# Not there is so for the session; the network may come back.
		_unfetched[key] = [why, code == 0 or code >= 500]
		push_warning("could not fetch the LDraw file %s: %s" % [key, why])
		return false
	PartForge.keep_fetched(key, body.get_string_from_utf8())
	return true


## Why a fetched body is not an LDraw file, or "". A missing file is a
## status (Supabase says 400 for one), and a web page is not LDraw even with
## 200: a missing part once came back as the landing page.
static func _fetch_problem(result: int, code: int, headers: PackedStringArray,
		body: PackedByteArray) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "the network failed (%d)" % result
	if code != 200:
		return "not there (HTTP %d)" % code
	for header: String in headers:
		if header.to_lower().begins_with("content-type:") and header.to_lower().contains("html"):
			return "a web page came back, not LDraw"
	var start: String = body.slice(0, 64).get_string_from_utf8().strip_edges()
	if body.is_empty() or start.begins_with("<"):
		return "a web page came back, not LDraw" if not body.is_empty() else "it came back empty"
	return ""


## [param problem] with why each file it names could not be fetched, where
## one was asked for.
static func _with_why(problem: String) -> String:
	var why := PackedStringArray()
	for key: String in _unfetched:
		if problem.contains(key):
			why.append("%s: %s" % [key, _unfetched[key][0]])
	return problem if why.is_empty() else "%s (fetching %s)" % [problem, "; ".join(why)]


# -- LDCad's flexible parts --------------------------------------------------
#
# LDCad keeps the path a hose, a band, a rope or a string follows in meta
# lines, and writes what it draws along it below them, after a line `0
# !LDCAD GENERATED`: primitives bent along the path a segment at a time
# (`4-4cyli.dat` 886 times for 42082's rope), pieces of a donor section the
# file carries, or the polygons themselves; and the parts at its ends (a
# pneumatic tube's 165, a string's 572a) as parts. None of the skin is a
# part, so none of it was drawn: 225 of the repository's 1,576 files have
# one, and a builder opening a Technic set saw its hoses missing
# (docs/CADTASK.md).
#
# Each such sub-model's skin is made here one part of its own, drawn as the
# file has it (its primitives and its colours, where it puts them), built on
# another thread while the file's carried parts are, and put in the
# sub-model as one piece, where its GENERATED line is: one piece
# a copy of the sub-model, to select, hide and see in its step. The parts at
# its ends stay parts. The file is not changed: the piece is paired with that
# meta line (SourceFile), so a save writes the section as it was, and a
# change to the piece writes the model whole, the skin carried as a part.


## Skin part id -> the key of the sub-model it is the skin of.
static var skins: Dictionary = {}
## A generated sub-model's text -> [its skin's id, the skin's text], or
## ["", ""] for one that draws only parts: what begin_skins made of it.
static var _skins_of_body: Dictionary = {}


## Whether [param part_id] is a flexible part's skin built from a file.
static func is_skin(part_id: String) -> bool:
	return skins.has(part_id)


## Start building each flexible part's skin [param model] carries (see
## above): one entry for [method end_skins] each, its build on a worker
## thread when the library has not got it built already. A skin that draws
## on a file this build has not got is left as it was, kept in the file and
## said, with why in [param problems].
##
## On a thread because a skin is new work at every first open: 42082's four
## took a second, and on a small model that was a third more than its open.
## Begun before the parts the file carries are built (take_from builds
## those here, seconds of a big set's first open), it is mostly done by the
## time it is wanted.
static func begin_skins(library: PartLibrary, model: LdrModel,
		problems: PackedStringArray) -> Array:
	var begun: Array = []
	if model.generated.is_empty():
		return begun
	var sources: Dictionary = {}
	var pieces: Dictionary = {}     ## reference key -> whether it is a piece
	for key: String in model.generated:
		var sub: LdrModel.SubModel = model.submodels.get(key)
		if sub == null:
			continue
		var body: String = str(model.section_texts.get(sub.name.to_lower(), ""))
		# A sub-model seen before this session is not read again: its skin,
		# or that it has none (42058's hose is 15,760 lines: read again on
		# every open, 40 ms of a 150 ms one).
		var seen: Array = _skins_of_body.get(body, [])
		if not seen.is_empty() and (str(seen[0]).is_empty() or (library.parts.has(seen[0])
				and library.custom_source(seen[0]) == str(seen[1]))):
			if not str(seen[0]).is_empty():
				begun.append({"key": key, "sub": sub, "id": seen[0], "text": seen[1],
					"sources": {}, "pieces": pieces, "task": -1, "built": [null]})
			continue
		var made_of: Dictionary = model.skin_texts[body] if model.skin_texts.has(body) \
			else _skin_text(library, model, sub, body, pieces)
		if made_of.is_empty():
			_skins_of_body[body] = ["", ""]
			continue
		if sources.is_empty():
			sources = model.section_texts.duplicate()
			sources.merge(model.embedded_sources)
		var text: String = made_of["text"]
		var id: String = _skin_id(library, key, text)
		_skins_of_body[body] = [id, text]
		var entry: Dictionary = {"key": key, "sub": sub, "id": id, "text": text,
			"sources": sources, "pieces": pieces, "task": -1, "built": [null]}
		if not (library.parts.has(id) and library.custom_source(id) == text):
			# Found already where the web looked before it opened (unreached_by).
			var unreached: PackedStringArray = made_of["unreached"] if made_of.has("unreached") \
				else PartForge.unreached(text, sources)
			if not unreached.is_empty():
				problems.append(_with_why("%s (flexible): it uses files this build does not have: %s"
					% [sub.name, ", ".join(unreached)]))
				continue
			# Its own copy of what it reads, and nothing it shares
			# (PartForge.build_skin): it is read on another thread.
			var given: Dictionary = sources.duplicate()
			var built: Array = entry["built"]
			var build: Callable = func() -> void:
				built[0] = PartForge.build_skin(text, id, given, true, false)
			if OS.has_feature("web") and not OS.has_feature("threads"):
				build.call()
			else:
				# The pool's high side, as the carried parts are built
				# (_built_at_once): the app's own checks of the last model
				# keep its low side busy for seconds. The forge run once here
				# first, as there (WorkerTasks.first_here): the skins of a
				# file all start it at once, and the carried parts with them.
				WorkerTasks.first_here("the forge", PartForge.warm)
				entry["task"] = WorkerThreadPool.add_task(build, true, "build a flexible part")
		begun.append(entry)
	return begun


## The skins [method begin_skins] began, waited for, added to the library and
## put in their sub-models: one piece a copy, where the GENERATED line is,
## and the skin's own references out of the sub-model (each was a part the
## library has not got). Returns the skins' ids.
static func end_skins(library: PartLibrary, model: LdrModel, begun: Array,
		problems: PackedStringArray) -> PackedStringArray:
	var made := PackedStringArray()
	for entry: Dictionary in begun:
		if int(entry["task"]) >= 0:
			WorkerThreadPool.wait_for_task_completion(int(entry["task"]))
		var sub: LdrModel.SubModel = entry["sub"]
		var id: String = entry["id"]
		var text: String = entry["text"]
		var built: PartForge.Result = (entry["built"] as Array)[0]
		if built != null:
			built = PartForge.with_mesh(built)
			if not built.problem.is_empty():
				problems.append("%s (flexible): %s" % [sub.name, built.problem])
				continue
			var info: PartLibrary.PartInfo = info_for(built)
			info.category = SKIN_CATEGORY
			info.reachable = false
			info.keywords = PackedStringArray(["flexible", "ldcad"])
			library.add_custom(info, built.mesh, text)
		var key: String = entry["key"]
		skins[id] = key
		if not drawn_from.has(id) or not (entry["sources"] as Dictionary).is_empty():
			drawn_from[id] = needs(text, entry["sources"])
		var kept: Array[LdrModel.Placement] = []
		for placement: LdrModel.Placement in sub.placements:
			if _is_piece(library, model, LdrModel._key(placement.part_id), entry["pieces"]):
				kept.append(placement)
		var at: Array = model.generated[key]
		var piece := LdrModel.Placement.new(id, 16, Transform3D.IDENTITY, int(at[1]))
		piece.line = int(at[0])
		kept.append(piece)
		sub.placements = kept
		made.append(id)
	return made


## The part file a sub-model's skin is: its own lines without the parts and
## sub-models in it (its ends, its other skins), under a header that says it
## is a part. With the path's meta lines where nothing but the skin is in
## it, so a file written whole keeps the path LDCad can open again. {"text"}
## or {} when it draws nothing.
static func _skin_text(library: PartLibrary, model: LdrModel, sub: LdrModel.SubModel,
		body: String, pieces: Dictionary) -> Dictionary:
	var kept := PackedStringArray()
	var faces: int = 0
	var with_pieces: bool = false
	var author: String = model.author
	var licence: String = ""
	var first: bool = true
	# By each line's first character, split only where a reference is read:
	# 42058's hose is 15,760 lines, and reading every one a character at a
	# time (LdrModel._fields) took a second of every open.
	for raw: String in body.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		var kind: String = line.left(1) if line.length() == 1 or line[1] == " " \
			or line[1] == "\t" else ""
		if kind == "0":
			var said: String = line.substr(1).strip_edges()
			var lower: String = said.to_lower()
			var title_line: bool = first and not said.begins_with("!") \
				and not said.begins_with("//") and not lower.begins_with("name:")
			first = false
			if lower.begins_with("author:"):
				author = said.substr(7).strip_edges()
				continue
			if said.begins_with("!LICENSE"):
				licence = line
				continue
			if title_line or lower.begins_with("name:") or said.begins_with("!LDRAW_ORG") \
					or said.begins_with("!CATEGORY"):
				continue
			kept.append(line)
			continue
		first = false
		if kind == "1":
			var words: PackedStringArray = line.replace("\t", " ").split(" ", false)
			if words.size() < 15:
				continue
			if _is_piece(library, model, LdrModel._key(" ".join(words.slice(14))), pieces):
				with_pieces = true
				# An INVERTNEXT goes with the reference it stood before.
				if not kept.is_empty() and kept[kept.size() - 1].to_upper() \
						.replace("\t", " ").begins_with("0 BFC INVERTNEXT"):
					kept.remove_at(kept.size() - 1)
				continue
			faces += 1
		elif kind == "3" or kind == "4":
			faces += 1
		kept.append(line)
	if faces == 0:
		return {}
	if with_pieces:
		# The path is the whole flexible part's, its ends with it: not this.
		kept = PackedStringArray(Array(kept).filter(func(l: String) -> bool:
			return not l.begins_with("0 !LDCAD")))
	var title: String = sub.title if not sub.title.is_empty() else LdrModel._key(sub.name)
	var head := PackedStringArray([
		"0 %s (flexible)" % title,
		"0 Name: %s-flex.dat" % LdrModel._key(sub.name),
		"0 Author: %s" % (author if not author.is_empty() else "LDCad"),
		"0 !LDRAW_ORG Unofficial_Part"])
	if not licence.is_empty():
		head.append(licence)
	head.append(SKIN_MARK)
	return {"text": "\n".join(head + kept) + "\n"}


## The line a skin's part file says what it is by: opened again from a file
## a skin was written whole into, it is built as a skin, not voxelised.
const SKIN_MARK := "0 !CATEGORY Flexible"
const SKIN_CATEGORY := "Flexible"


## Whether a part's text is a flexible part's skin ([method _skin_text]).
static func is_skin_text(text: String) -> bool:
	return text.contains("\n" + SKIN_MARK + "\n")


## An id for a sub-model's skin no other part has, unless it is this very
## skin: its key and "-flex".
static func _skin_id(library: PartLibrary, key: String, text: String) -> String:
	var base: String = key + "-flex"
	var id: String = base
	var n: int = 1
	while library.parts.has(id) and library.custom_source(id) != text:
		n += 1
		id = "%s-%d" % [base, n]
	return id


## Whether a reference in a flexible part's sub-model is a piece of its own
## rather than skin: a part (the library's, or one the file carries), a
## sub-model with a part in it, or another skin. A primitive, a donor
## section of nothing but drawing, or a file nobody has, is skin.
static func _is_piece(library: PartLibrary, model: LdrModel, key: String,
		pieces: Dictionary, depth: int = 0) -> bool:
	if pieces.has(key):
		return pieces[key]
	var piece: bool = false
	if library.parts.has(key) or model.embedded_parts.has(key + ".dat"):
		piece = true
	elif model.generated.has(key) and model.submodels.has(key):
		piece = true
	elif model.submodels.has(key) and depth < 16:
		pieces[key] = false     # a section that refers to itself
		for placement: LdrModel.Placement in (model.submodels[key] as LdrModel.SubModel).placements:
			if _is_piece(library, model, LdrModel._key(placement.part_id), pieces, depth + 1):
				piece = true
				break
	pieces[key] = piece
	return piece


## The parts [param texts] holds (file name -> LDraw text), drawn from
## [param others] as [method add] has them, built all at once on the
## engine's worker threads as [method add] would build each, their meshes
## made here: file name -> PartForge.Result. Built one after another they
## were most of opening a file that carries parts (42082-1: 1.8 s of 4.3),
## and of starting the app after opening one ([method load_all]). A print is
## left out (PartPrints builds it with the library), and so is everything on
## a build without threads.
static func _built_at_once(texts: Dictionary, others: Dictionary) -> Dictionary:
	if texts.size() < 2 or (OS.has_feature("web") and not OS.has_feature("threads")) \
			or OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {}
	var sources: Dictionary = {}
	for name: String in others:
		if not others[name] is PackedByteArray:
			sources[name] = others[name]
	var plain: PackedStringArray = PackedStringArray()
	for file_name: String in texts:
		if not PartPrints.has_pictures(texts[file_name]):
			plain.append(file_name)
	if plain.size() < 2:
		return {}
	var made: Array = []
	made.resize(plain.size())
	var writing := Mutex.new()
	# The forge run once here first: every worker starting it at once, the
	# first time it ran, crashed the app (WorkerTasks.first_here).
	WorkerTasks.first_here("the forge", PartForge.warm)
	var task: int = WorkerThreadPool.add_group_task(func(n: int) -> void:
		var result: PartForge.Result = PartForge.build(texts[plain[n]],
			plain[n].get_basename(), sources, true, null, false)
		writing.lock()
		made[n] = result
		writing.unlock(),
		plain.size(), -1, true, "carried parts")
	WorkerThreadPool.wait_for_group_task_completion(task)
	var out: Dictionary = {}
	for n: int in plain.size():
		out[plain[n]] = PartForge.with_mesh(made[n])
	return out


## The subparts and primitives a part a model file carried is drawn from,
## that the file carried with it: part id -> {name as the part refers to
## it -> its text}. Written back with the part (sources_for), or a file
## saved here carried 3315's parts without what they are drawn from, and
## they were gone when it was opened again (docs/CADTASK.md, 2026-10-16).
static var drawn_from: Dictionary = {}


## The files of [param carried] (LdrModel.embedded_sources) that [param
## text] refers to, and those they refer to, by the name as referred to.
static func needs(text: String, carried: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var todo: Array = [text]
	while not todo.is_empty():
		for raw: String in str(todo.pop_back()).split("\n"):
			var line: String = raw.strip_edges()
			# Only a reference names a file: the rest unread (a skin's
			# polygons are thousands of lines).
			if not line.begins_with("1 ") and not line.begins_with("1\t"):
				continue
			var words: PackedStringArray = LdrModel._fields(line)
			if words.size() < 15 or words[0] != "1":
				continue
			var named: String = " ".join(words.slice(14))
			var key: String = named.replace("\\", "/").to_lower()
			if out.has(named):
				continue
			var found: Variant = carried.get(key, carried.get(key.get_file(), null))
			if found == null:
				continue
			out[named] = str(found)
			todo.append(str(found))
	return out


## The sources of the custom parts among [param part_ids], by file name,
## for writing into a model file: each part's text, and each print's
## pictures as PNG bytes.
static func sources_for(library: PartLibrary, part_ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for part_id: Variant in part_ids:
		var text: String = library.custom_source(str(part_id))
		if not text.is_empty():
			out[str(part_id) + ".dat"] = text
			var needed: Dictionary = drawn_from.get(str(part_id), {})
			for named: String in needed:
				out[named] = needed[named]
			# And a print's pictures, which go in as !DATA sections.
			var mesh: Lbm.PartMesh = library.mesh_for(str(part_id))
			if mesh != null:
				for name: String in mesh.print_files:
					out[name] = mesh.print_files[name]
	return out
