## The model as a 3MF for a printer that prints in several colours (APP_UX6
## #18, print3mf), read back by a strict reader.
##
##   godot --headless --path . --script src/dev/print3mf_probe.gd
##
## On the real scene: the example car opened, File, Export, 3D model…
## pressed, 3MF chosen in the dialog and Export pressed, and the file read
## back by tools/print3mf/check_3mf.py: its package, the 3MF core's own XSD,
## the core's rules no schema states, and lib3mf (the 3MF Consortium's
## library) reading it in strict mode, with no error from any of them. Then
## the bar: one object a colour the car's parts are placed in, each named
## for it with its RGB from PartLibrary.color as its base material's
## displaycolor; every triangle winding outward (none empty behind and
## filled in front, by the core's positive fill rule along three rays each
## side, against its own part); its size in millimetres the model's within
## 0.1 mm on each axis, standing on the bed in the positive octant.
## export_model's 3mf writes the same model.
##
## Every object a closed solid (APP_UX7 #12, print3mf2): lib3mf's
## IsManifoldAndOriented true for each, every edge (by vertex index) shared
## by exactly two triangles going opposite ways round, as the core's 4.1
## asks, where the parts as LDraw draws them close none (read here with the
## closing turned off); and the triangles no more than twice the parts'.
##
## Then a model of the cases the car has none of: a printed tile, whose
## print is painted on it (each print triangle naming its colour, in the
## tile's object) and whose body stays one object; a part placed mirrored;
## and a part from an LDraw file that is not BFC-certified, whose triangles
## are counted facing in as LDraw draws them and then none facing in as
## written. Then the reader is shown strict: a 3MF with one triangle
## turned, one with an object turned inside out, one with a colour that is
## no colour, and one with a corner past its vertices are each refused or
## counted.
##
## GLB and STL unchanged to the byte: --hashes=FILE writes the car's GLB and
## STL's SHA-256 to FILE, and --same-as=FILE checks this build's against
## them (run on the build before this one, then on this one).
##
## The reader runs under uvx with lib3mf 2.5.0, xmlschema 4.3.2 and numpy
## 2.5.4, from uv's cache once fetched.
extends SceneTree

const CHECKER := "res://tools/print3mf/check_3mf.py"
## The model part, as the 3MF core names it.
const MODEL := "3D/3dmodel.model"
## The writer, named by path so this probe runs (and fails) on a build
## without it.
const WRITER := "res://src/parts/mesh_3mf.gd"
const READER_WITH: PackedStringArray = ["--with", "lib3mf==2.5.0", "--with", "xmlschema==4.3.2",
	"--with", "numpy==2.5.4"]

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _store: ModelStore
var _library: PartLibrary
var _exports: Exports
var _next: int = 0
var _out: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_exports = _main.get("_exports")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_out = OS.get_user_data_dir().path_join("print3mf_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	for file_name: String in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out.path_join(file_name))
	_exports.folder = _out

	var said: String = await _say("open_model", {"name": "Car", "discard_changes": true})
	_check("the example car opens: %s" % said.left(60), said.begins_with("Opened"))
	await _unchanged()
	var path: String = await _from_the_menu()
	if not path.is_empty():
		await _the_car(path)
		await _as_drawn()
		await _over_mcp(path)
		await _strict(path)
	await _cases()
	_done()


# -- the car from the menu ------------------------------------------------------------


## File, Export, 3D model…, 3MF chosen, Export: the file it wrote.
func _from_the_menu() -> String:
	print("── File, Export, 3D model…, 3MF ──")
	var shell: Shell = _main.get("_shell")
	_check("File, Export's row names 3MF: \"%s\"" % shell.command("export_3d").words,
		shell.command("export_3d").words.contains(".3mf"))
	_check("...and it runs", shell.run("export_3d"))
	var dialog: ConfirmationDialog = _exports.get("_model_3d")
	var choice: OptionButton = _exports.get("_format_choice")
	var note: Label = _exports.get("_format_note")
	var at: int = MeshExport.FORMATS.find("3mf")
	_check("the dialog offers 3MF: \"%s\"" % (choice.get_item_text(at) if at >= 0 else "-"),
		at >= 0 and choice.get_item_text(at).contains("3MF"))
	if at < 0:
		return ""
	choice.select(at)
	choice.item_selected.emit(at)
	_check("...saying what it is for, its cap and this model's count: \"%s\"" % note.text,
		note.text.contains("own filament") and note.text.contains("Up to 1,000,000 triangles; this model is"))
	var bar: ModelBar = _main.get("_bar")
	var path: String = _out.path_join(MeshExport._file_base(bar.model_name()) + ".3mf")
	var began: int = Time.get_ticks_msec()
	dialog.get_ok_button().pressed.emit()
	var writing: bool = Exports._writing
	while Exports._writing and Time.get_ticks_msec() - began < 60000:
		await process_frame
	var status: Label = bar.get("_status")
	_check("Export wrote %s in %d ms: \"%s\"" % [path.get_file(), Time.get_ticks_msec() - began,
		status.text], writing and FileAccess.file_exists(path)
		and status.text.begins_with("wrote " + path) and status.text.contains("colours, an object each"))
	return path if FileAccess.file_exists(path) else ""


## The bar on the car's file.
func _the_car(path: String) -> void:
	print("── the car, read back strictly ──")
	var report: Dictionary = _read(path)
	_check_strict(report, "the car")
	var objects: Array = report.get("objects", [])
	# The colours the car's parts are placed in, and its moulded wheel's.
	var wanted: Dictionary = {}
	var triangles: Dictionary = {}
	for brick: BrickWorld.Brick in _parts():
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		for n: int in part.surfaces.size():
			var code: int = brick.color_code if part.surface_colors[n] == Lbm.COLOR_INHERIT \
				else part.surface_colors[n]
			wanted[code] = true
			triangles[code] = int(triangles.get(code, 0)) + _sound(part.surfaces[n])
	var named: Dictionary = {}
	var wrong: PackedStringArray = []
	for object: Dictionary in objects:
		named[object["name"]] = object
	for code: int in wanted:
		var colour: PartLibrary.BrickColor = _library.color(code)
		var object: Dictionary = named.get(colour.name, {})
		if object.is_empty():
			wrong.append("no object for %s" % colour.name)
		elif str(object["colour"]) != _display(colour):
			wrong.append("%s is %s, not %s" % [colour.name, object["colour"], colour.rgb.to_html(false)])
		elif int(object["triangles"]) < int(triangles[code]) or int(object["triangles"]) > 2 * int(triangles[code]):
			wrong.append("%s has %d triangles, its parts %d" % [colour.name, object["triangles"],
				triangles[code]])
	# Closed, an object has its parts' triangles and the caps and splits
	# that close them: no fewer, and no more than twice as many.
	_check("one object a colour, %d for the car's %d, each its colour's RGB and its parts' triangles closed: %s%s"
		% [objects.size(), wanted.size(), ", ".join(objects.map(func(o: Dictionary) -> String:
			return "%s %s (%d)" % [o["name"], o["colour"], o["triangles"]])),
		"" if wrong.is_empty() else " — " + "; ".join(wrong)],
		objects.size() == wanted.size() and wrong.is_empty())
	var wheel: Dictionary = named.get(_library.color(0).name, {})
	_check("...the steering wheel moulded black in black's object, its stand in red's (%d black triangles, the black parts' %d)"
		% [int(wheel.get("triangles", 0)), int(triangles.get(0, -1))],
		int(wheel.get("triangles", 0)) >= int(triangles.get(0, -1)) and int(triangles.get(0, -1)) > 0)
	_winding(report, "the car's")
	var parts: int = 0
	for code: int in triangles:
		parts += int(triangles[code])
	var written: int = _sum(report, "triangles")
	_check("...its %d triangles no more than twice its parts' %d (%.2f times)" % [written, parts,
		float(written) / maxf(parts, 1)], written >= parts and written <= 2 * parts)
	_closed(report, "the car's", wanted.size())
	# The model's size: every vertex of every part where it stands, in mm on
	# the printer's axes (x across, y deep, z up).
	var box: AABB = _exact_box()
	var want := Vector3(box.size.x, box.size.z, box.size.y) * MeshExport.MILLIMETRES
	var size: Array = report.get("size", [0, 0, 0])
	var got := Vector3(size[0], size[1], size[2])
	var low: Array = report.get("low", [1, 1, 1])
	var stated: AABB = ModelSize.of_model(_world, _library, _store.scenery).box
	_check("its size %.2f x %.2f x %.2f mm, the model's %.2f x %.2f x %.2f within 0.1 (%.4f off; the status bar's box %.2f x %.2f x %.2f)"
		% [got.x, got.y, got.z, want.x, want.y, want.z, (got - want).abs()[(got - want).abs().max_axis_index()],
		stated.size.x * 0.4, stated.size.z * 0.4, stated.size.y * 0.4],
		absf(got.x - want.x) <= 0.1 and absf(got.y - want.y) <= 0.1 and absf(got.z - want.z) <= 0.1)
	_check("...on the bed in the positive octant: its box starts at (%.4f, %.4f, %.4f)" % [low[0],
		low[1], low[2]], absf(low[0]) < 1e-3 and absf(low[1]) < 1e-3 and absf(low[2]) < 1e-3)
	_check("...in millimetres, its unit stated: %s" % report.get("unit_attr", "-"),
		report.get("unit_attr", "") == "millimeter")


## The car as LDraw draws its parts, with the closing turned off: how many
## of its objects a strict reader finds closed then.
func _as_drawn() -> void:
	print("── the car as LDraw draws it, not closed ──")
	var writer: Script = load(WRITER) if ResourceLoader.exists(WRITER) else null
	if writer == null or writer.get("close_up") == null:
		_check("the writer can be asked not to close its pieces", false)
		return
	writer.set("close_up", false)
	var report: Dictionary = _read(_written(await _say("export_model", {"format": "3mf"})))
	writer.set("close_up", true)
	var objects: Array = report.get("objects", [])
	_check("as drawn, %d of %d objects closed, %d edges not shared by two triangles" % [
		objects.filter(func(o: Dictionary) -> bool: return o["manifold_and_oriented"]).size(),
		objects.size(), _sum(report, "edges_not_two")],
		objects.size() > 0 and _sum(report, "edges_not_two") > 0)


## Every object closed: lib3mf's IsManifoldAndOriented, and the core's
## rules counted by vertex index.
func _closed(report: Dictionary, what: String, wanted: int) -> void:
	var objects: Array = report.get("objects", [])
	var closed: Array = objects.filter(func(o: Dictionary) -> bool: return o["manifold_and_oriented"])
	var open: Array = objects.filter(func(o: Dictionary) -> bool: return not o["manifold_and_oriented"])
	_check("%s objects closed: %d of %d manifold and oriented by lib3mf%s" % [what, closed.size(),
		objects.size(), "" if open.is_empty() else " (not: %s)" % ", ".join(open.map(
			func(o: Dictionary) -> String: return o["name"]))],
		objects.size() == wanted and closed.size() == wanted)
	_check("...every edge shared by exactly two triangles, opposite ways round: %d of %d edges not, %d one way"
		% [_sum(report, "edges_not_two"), _sum(report, "edges"), _sum(report, "edges_one_way")],
		report.has("objects") and _sum(report, "edges") > 0 and _sum(report, "edges_not_two") == 0
		and _sum(report, "edges_one_way") == 0)


## export_model's 3mf: the same model part as the dialog's file.
func _over_mcp(path: String) -> void:
	print("── export_model 3mf ──")
	var listed: Array = []
	for tool: Dictionary in (await _rpc("tools/list", {})).get("tools", []):
		if str(tool.get("name", "")) == "export_model":
			listed = tool.get("inputSchema", {}).get("properties", {}).get("format", {}).get("enum", [])
	_check("export_model offers 3mf: %s" % ", ".join(listed), listed.has("3mf"))
	var said: String = await _say("export_model", {"format": "3mf"})
	var again: String = _written(said)
	_check("it writes one: %s" % said, again.ends_with(".3mf") and said.contains("an object each"))
	var a: PackedByteArray = _member(path, MODEL)
	var b: PackedByteArray = _member(again, MODEL)
	_check("...the same model as the dialog's, byte for byte (%d bytes)" % b.size(),
		not a.is_empty() and a == b)


## The reader refuses what it should: a triangle turned, a colour that is
## none, a corner past the vertices.
func _strict(path: String) -> void:
	print("── the reader is strict ──")
	var model: String = _member(path, MODEL).get_string_from_utf8()
	var first: RegExMatch = RegEx.create_from_string(
		"<triangle v1=\"(\\d+)\" v2=\"(\\d+)\" v3=\"(\\d+)\"/>").search(model)
	var turned: String = model.substr(0, first.get_start()) + "<triangle v1=\"%s\" v2=\"%s\" v3=\"%s\"/>" % [
		first.get_string(1), first.get_string(3), first.get_string(2)] + model.substr(first.get_end())
	var report: Dictionary = _read(_repacked(path, turned, "turned.3mf"))
	_check("one triangle turned in: %d counted facing in" % _sum(report, "inward"),
		_sum(report, "inward") >= 1)
	# The smallest object turned inside out, as a part placed mirrored would
	# be if its triangles were not turned back.
	var spans: Array = []
	var at: int = model.find("<object ")
	while at >= 0:
		var end: int = model.find("</object>", at)
		spans.append([at, end])
		at = model.find("<object ", end)
	var small: Array = spans[0]
	for span: Array in spans:
		if span[1] - span[0] < small[1] - small[0]:
			small = span
	var body: String = model.substr(small[0], small[1] - small[0])
	var name: String = RegEx.create_from_string("name=\"([^\"]*)\"").search(body).get_string(1)
	var count: int = body.count("<triangle ")
	var inside_out: String = RegEx.create_from_string(
		"<triangle v1=\"(\\d+)\" v2=\"(\\d+)\" v3=\"(\\d+)\"").sub(body, "<triangle v1=\"$1\" v2=\"$3\" v3=\"$2\"", true)
	report = _read(_repacked(path, model.substr(0, small[0]) + inside_out + model.substr(small[1]),
		"inside_out.3mf"))
	var facing_in: int = 0
	for object: Dictionary in report.get("objects", []):
		if object["name"] == name:
			facing_in = int(object["inward"])
	_check("%s's object turned inside out: %d of its %d triangles counted facing in" % [name, facing_in,
		count], facing_in * 2 > count)
	var colourless: String = model.replace("displaycolor=\"#", "displaycolor=\"#G")
	report = _read(_repacked(path, colourless, "colourless.3mf"))
	_check("a displaycolor that is no colour: %d schema errors, refused: %s" % [
		int(report.get("schema_errors", 0)), str(report.get("errors", [""])[0]).left(90) if not
		(report.get("errors", []) as Array).is_empty() else "-"], int(report.get("schema_errors", 0)) > 0)
	var vertices: int = model.substr(0, model.find("</vertices>")).count("<vertex ")
	var past: String = model.substr(0, first.get_start()) + "<triangle v1=\"%s\" v2=\"%s\" v3=\"%d\"/>" % [
		first.get_string(1), first.get_string(2), vertices] + model.substr(first.get_end())
	report = _read(_repacked(path, past, "past.3mf"))
	var errors: Array = report.get("errors", [])
	_check("a corner past the object's %d vertices: refused by the rules and lib3mf: %s" % [vertices,
		"; ".join(errors.map(func(e: String) -> String: return e.left(70)))],
		errors.any(func(e: String) -> bool: return e.begins_with("rules:"))
		and errors.any(func(e: String) -> bool: return e.begins_with("lib3mf:")))


# -- what the car has none of ---------------------------------------------------------


## A printed tile, a part placed mirrored, and a part LDraw draws with no
## front known.
func _cases() -> void:
	print("── a print, a mirror, a part with no front ──")
	_main.call("clear_model")
	var builder: Builder = _main.get("_builder")
	# 3068bp01 is printed black and yellow; 3005 placed mirrored; 6170752c
	# is drawn by an LDraw file that is not BFC-certified, 12 of its
	# triangles facing in as it draws them.
	for placed: Array in [["3068bp01", 15, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))],
			["3005", 4, Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3(60, 0, 0))],
			[TWO_SIDED, 1, Transform3D(Basis.IDENTITY, Vector3(0, 0, 60))]]:
		var brick_id: int = _world.add_brick(placed[0], placed[1], placed[2])
		builder.register(brick_id, placed[0], placed[2])
	await process_frame
	var part: Lbm.PartMesh = _library.mesh_for(TWO_SIDED)
	var two: int = 0
	for n: int in part.surfaces.size():
		if part.surface_two_sided[n] == 1:
			two += _sound(part.surfaces[n])
	var writer: Script = load(WRITER) if ResourceLoader.exists(WRITER) else null
	if writer != null:
		writer.set("face_out", false)
		writer.set("close_up", false)
	var drawn: Dictionary = _read(_written(await _say("export_model", {"format": "3mf"})))
	if writer != null:
		writer.set("face_out", true)
		writer.set("close_up", true)
	var said: String = await _say("export_model", {"format": "3mf"})
	var report: Dictionary = _read(_written(said))
	_check_strict(report, "the print, the mirror and the part with no front")
	var tile: Dictionary = {}
	for object: Dictionary in report.get("objects", []):
		if object["name"] == _library.color(15).name:
			tile = object
	var painted: Dictionary = tile.get("painted", {})
	_check("the tile's print painted on it, in its object: %s" % JSON.stringify(painted),
		painted.has(_display(_library.color(0))) and painted.has(_display(_library.color(14))))
	_check("...its objects White, Red and Blue, the print's colours none: %s" % ", ".join(
		report.get("objects", []).map(func(o: Dictionary) -> String: return o["name"])),
		(report.get("objects", []) as Array).size() == 3)
	_check("%s, %d of its triangles two-sided: %d facing in as LDraw draws them, %d once turned"
		% [TWO_SIDED, two, _sum(drawn, "inward"), _sum(report, "inward")],
		_sum(drawn, "inward") > 0 and _sum(report, "inward") == 0)
	_winding(report, "the print, the mirror and the part with no front:")
	_closed(report, "the print, the mirror and the part with no front:", 3)


## A sticker whose LDraw file is not BFC-certified: its print drawn with no
## front, some of it facing in.
const TWO_SIDED := "6170752c"


# -- GLB and STL unchanged ------------------------------------------------------------


## The car's GLB and STL, hashed; written to --hashes, checked against
## --same-as.
func _unchanged() -> void:
	print("── GLB and STL, as they were ──")
	var hashes: Dictionary = {}
	for format: String in ["glb", "stl"]:
		var path: String = _written(await _say("export_model", {"format": format}))
		hashes[format] = FileAccess.get_sha256(path) if not path.is_empty() else ""
		print("  %s %s %s" % [format, hashes[format], path.get_file()])
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hashes="):
			var file := FileAccess.open(argument.trim_prefix("--hashes="), FileAccess.WRITE)
			file.store_string(JSON.stringify(hashes))
			file.close()
		elif argument.begins_with("--same-as="):
			var before: Variant = JSON.parse_string(FileAccess.get_file_as_string(
				argument.trim_prefix("--same-as=")))
			_check("the car's GLB and STL the same to the byte as the build before's: %s" % JSON.stringify(before),
				before is Dictionary and not str(hashes["glb"]).is_empty()
				and (before as Dictionary).get("glb") == hashes["glb"]
				and (before as Dictionary).get("stl") == hashes["stl"])


# -- reading ----------------------------------------------------------------------


## check_3mf.py's report on [param path].
func _read(path: String) -> Dictionary:
	if path.is_empty():
		return {"errors": ["nothing written"]}
	var json: String = path.get_basename() + "_check.json"
	var out: Array = []
	var arguments := PackedStringArray(["--offline"])
	arguments.append_array(READER_WITH)
	arguments.append_array(["python3", "-I", ProjectSettings.globalize_path(CHECKER), path,
		"--json=" + json])
	var began: int = Time.get_ticks_msec()
	var code: int = OS.execute("uvx", arguments, out, true)
	if not FileAccess.file_exists(json):
		# Not fetched yet: once from the index, and kept in uv's cache.
		arguments.remove_at(0)
		code = OS.execute("uvx", arguments, out, true)
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(json)) \
		if FileAccess.file_exists(json) else null
	if not report is Dictionary:
		print("  the reader said: %s" % "".join(out).right(600))
		return {"errors": ["the reader did not run (exit %d)" % code]}
	(report as Dictionary)["unit_attr"] = _unit(path)
	print("    read in %d ms: exit %d, lib3mf %s" % [Time.get_ticks_msec() - began, code,
		(report as Dictionary).get("version", "-")])
	return report


func _check_strict(report: Dictionary, what: String) -> void:
	var errors: Array = report.get("errors", [])
	_check("%s: the package, the core XSD (%d errors), the core's rules and lib3mf %s in strict mode, none with an error%s"
		% [what, int(report.get("schema_errors", -1)), report.get("version", "-"),
		"" if errors.is_empty() else " — " + "; ".join(errors.slice(0, 4))],
		errors.is_empty() and report.has("objects"))


## Every triangle facing out: none filled in front and empty behind, none
## in a shell turned inside out, none with no area. Internal ones (filled
## both sides, where LDraw's shapes overlap) are solid whichever way they
## face, and are counted apart.
func _winding(report: Dictionary, what: String) -> void:
	var objects: Array = report.get("objects", [])
	var total: int = 0
	for field: String in ["outward", "inward", "internal", "flat"]:
		total += _sum(report, field)
	_check("%s every triangle winds outward: %d of %d, %d inside the solid both sides, %d facing in, %d with no area (%d shells, %d of %d objects manifold)"
		% [what, _sum(report, "outward"), total, _sum(report, "internal"), _sum(report, "inward"),
		_sum(report, "flat"), _sum(report, "shells"), objects.filter(func(o: Dictionary) -> bool:
			return o["manifold_and_oriented"]).size(), objects.size()],
		total > 0 and _sum(report, "inward") == 0 and _sum(report, "flat") == 0)


## A colour as the core states one: #RRGGBB from PartLibrary.color, and a
## see-through colour's alpha after it.
static func _display(colour: PartLibrary.BrickColor) -> String:
	var rgb: String = "#" + colour.rgb.to_html(false).to_upper()
	return rgb + ("%02X" % colour.alpha if colour.is_transparent() else "")


static func _sum(report: Dictionary, field: String) -> int:
	var total: int = 0
	for object: Dictionary in report.get("objects", []):
		total += int(object.get(field, 0))
	return total


## The model's unit, as its model part states it.
static func _unit(path: String) -> String:
	var text: String = _member(path, MODEL).get_string_from_utf8()
	var found: RegExMatch = RegEx.create_from_string("<model[^>]* unit=\"([a-z]+)\"").search(text)
	return found.get_string(1) if found != null else ""


static func _member(path: String, name: String) -> PackedByteArray:
	var zip := ZIPReader.new()
	if path.is_empty() or zip.open(path) != OK:
		return PackedByteArray()
	var bytes: PackedByteArray = zip.read_file(name)
	zip.close()
	return bytes


## [param path] with its model part replaced by [param model], as
## [param file_name] beside it.
func _repacked(path: String, model: String, file_name: String) -> String:
	var members: Array = []
	for name: String in ["[Content_Types].xml", "_rels/.rels"]:
		members.append([name, _member(path, name)])
	members.append([MODEL, model.to_utf8_buffer()])
	var to: String = path.get_base_dir().path_join(file_name)
	var file := FileAccess.open(to, FileAccess.WRITE)
	file.store_buffer(StudioIo.zip(members))
	file.close()
	return to


## A surface's triangles a 3MF can hold: three corners in three places,
## at the 1/64 LDU the parts are drawn to.
static func _sound(mesh: ArrayMesh) -> int:
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count: int = 0
	for i: int in range(0, index.size() - 2, 3):
		var a := Vector3i((v[index[i]] * 64.0).round())
		var b := Vector3i((v[index[i + 1]] * 64.0).round())
		var c := Vector3i((v[index[i + 2]] * 64.0).round())
		if a != b and b != c and a != c:
			count += 1
	return count


## Round every vertex of every part, where it stands, in LDU.
func _exact_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _parts():
		for surface: ArrayMesh in _library.mesh_for(brick.part_id).surfaces:
			var points: PackedVector3Array = brick.transform * \
				(surface.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			for p: Vector3 in points:
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box


## The parts the file should hold: the model's, not the baseplate.
func _parts() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append(brick)
	return out


static func _written(said: String) -> String:
	if not said.begins_with("Wrote "):
		return ""
	return said.trim_prefix("Wrote ").get_slice(" — ", 0).get_slice(" and ", 0).trim_suffix(".")


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	var result: Dictionary = await _rpc("tools/call", {"name": tool, "arguments": arguments})
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("the model comes out as a 3MF a printer reads in its colours")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
