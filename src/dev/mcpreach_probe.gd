## Is the person's Claude told what the window does (APP_UX8 #11, mcpreach)?
##
##   godot --path . --resolution 1400x900 --script src/dev/mcpreach_probe.gd
##
## Needs a window: the booklet's and the renders' pictures are drawn. Every
## call is a session's, through CommandSocket's tools/call, a job followed
## with the job tool as a session follows it, and the calls counted. Through
## the way in first, as a person comes: the sign-in screen up over the app
## (gate_for_probe), a throwaway account signed in by the admin key and a
## password (no code spent at the per-IP limit), the account deleted at the
## end. Needs .env (SUPABASE_URL, SUPABASE_SECRET_KEY).
##
## APP_UX8's MCP walk found a session told less than the window shows, and
## so telling the person wrong. Each of its four, on the walk's own Pods
## (tests/fixtures/mcpreach/pods.ldr):
##
##  n7  Asked to set up building with a friend, it said there was no way.
##      Does export_model's description, which every session is given, and
##      read_guide("app")'s first lines name Build together, Share, Import
##      and Comments, each with where it is, and is each "File › …" the
##      window's own menu row (Shell)? Does no tool open any of them?
##  x2  The booklet could not be handed over as a PDF. page_setup's cover in
##      Russian and Greek, then export_model pdf: a PDF where Export writes,
##      the answer saying every letter is in the type it carries, read back
##      by pdftotext as typed with no "?", in three calls with the job's,
##      its cover pictured in the answer as the PDF prints it (kept as
##      pdf_cover.png in shots/mcpreach/, or MCPREACH_OUT); no HTML page left
##      beside it. The walk's session looked at the cover in a fourth call.
##  x4  A picture replaced the last of its name. render_model, a spotlight
##      hung (light_model), render_model light=dark: the second is
##      pods_render_2.png, the answer naming it and that pods_render.png is
##      kept, and pods_render.png is byte for byte as it was. The same for
##      every other export a session writes twice: picture, ldraw, 3mf, stl,
##      obj with its .mtl, studio, bricklink, rebrickable, instructions, pdf;
##      and a turntable's name is free whole (its WebP, GIF, MP4 and frames).
##  x5  A solid 3MF was said to need repair. export_model 3mf's answer says
##      whether each object is a closed solid, and lib3mf (the 3MF
##      Consortium's reader, as print3mf_probe runs it) agrees object for
##      object: the Pods' and the example car's every object closed; the car
##      with the closing turned off (as LDraw draws it), none, each named.
##      An STL's answer says it is not closed, with the parts, as a reading
##      of its triangles here finds.
##
## And a person's own File › Export, with its save dialog, unchanged: the
## dialog offers the model's own name with that file there, asks whether to
## replace it, and writes over it when the person says so, with no second
## file.
extends SceneTree

const PODS := "res://tests/fixtures/mcpreach/pods.ldr"
## x2's cover, as the walk's prompt gave it.
const TITLE := "Двойные капсулы"
const SUBTITLE := "Δύο κάψουλες"
const CHECKER := "res://tools/print3mf/check_3mf.py"
const READER_WITH: PackedStringArray = ["--with", "lib3mf==2.5.0", "--with", "xmlschema==4.3.2",
	"--with", "numpy==2.5.4"]
## The window's own rows each "File › …" names (Shell.MENUS, its labels).
const NAMED: Array = [["together", "Build together (File › Build together…)", "Build together…"],
	["share", "Share (File › Share…)", "Share…"], ["comments", "Comments (File › Comments…", "Comments…"]]

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _out: String = ""
var _email: String = ""
## The picture the last answer carried; null for none.
var _seen: Image = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	SaveTo.native = false
	Account.where = "user://probe_session.json"
	Account._clear()
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")) and _main.get("_shell") != null and _main.get("_bar") != null:
			break
	await _frames(30)
	if not await _way_in():
		_quit()
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	# Where a session's files go with nobody to ask: a held run's own
	# Downloads (Download.downloads), never the owner's.
	_out = Download.downloads()
	for file: String in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out.path_join(file))
	print("  files go to %s" % _out)

	await _persons_own()
	if await _pods():
		await _pdf()
		await _pictures()
		await _twice()
		await _turntable()
		await _closed_pods()
	await _closed_car()
	await _asked()
	_check("no tool opened Build together, Share or Comments", _nothing_opened())
	_quit()


# -- n7: what only the person does, named where a session reads ---------------------


func _persons_own() -> void:
	print("")
	print("n7: Build together, Share, Import and Comments, named with where each is")
	var described: String = ""
	for tool: Dictionary in (await _rpc("tools/list", {})).get("tools", []):
		if str(tool.get("name", "")) == "export_model":
			described = str(tool.get("description", ""))
	var guide: String = await _say("read_guide", {"section": "app"})
	var head: String = guide.left(1600)
	var shell: Shell = _main.get("_shell")
	var file_menu: Array = Shell.MENUS[0][1]
	for named: Array in NAMED:
		var id: String = named[0]
		var row: String = shell.command(id).words if shell.command(id) != null else "-"
		_check("%s: export_model's description and the guide's first lines say \"%s\", the File menu's row \"%s\""
			% [id, named[1], row], described.contains(named[1]) and head.contains(named[1])
			and Shell.MENUS[0][0] == "File" and file_menu.has(id) and row == named[2])
	_check("import: both say \"Import (File › Import)\", File's submenu \"%s\""
		% Shell.SUBMENU_WORDS.get("import", "-"), described.contains("Import (File › Import)")
		and head.contains("Import (File › Import)") and file_menu.has(">import")
		and Shell.SUBMENU_WORDS.get("import", "") == "Import")
	_check("comments: both name a part's right-click row \"%s\"" % Shell.ON_A_PART_WORDS.get("comments", "-"),
		described.contains("Comment on it…") and head.contains("Comment on it…")
		and Shell.ON_A_PART_WORDS.get("comments", "") == "Comment on it…")
	_check("...and say never to call them impossible: \"%s\"" % "never says they cannot be done",
		described.contains("never says they cannot be done") and head.contains("never says they cannot be done"))
	var done_by: PackedStringArray = []
	for id: String in ["together", "share", "comments", "import_ldraw", "import_io"]:
		if AppTools.COMMANDS.has(id):
			done_by.append(id)
	_check("no tool does any of them: each is WINDOW_ONLY%s" % ("" if done_by.is_empty()
		else ", but COMMANDS has " + ", ".join(done_by)), done_by.is_empty()
		and AppTools.WINDOW_ONLY.has("together") and AppTools.WINDOW_ONLY.has("share")
		and AppTools.WINDOW_ONLY.has("comments") and AppTools.WINDOW_ONLY.has("import_*"))
	print("    the guide's first lines: %s" % head.substr(head.find(" - ") + 3, 320).replace("\n", " "))


func _nothing_opened() -> bool:
	var together: Node = _main.get("_together_made")
	return together == null or not bool(together.get("live"))


# -- the walk's Pods -----------------------------------------------------------------


func _pods() -> bool:
	print("")
	var models: String = OS.get_user_data_dir().path_join("mcpreach_models")
	DirAccess.make_dir_recursive_absolute(models)
	var path: String = models.path_join("pods.ldr")
	var copy: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	copy.store_buffer(FileAccess.get_file_as_bytes(PODS))
	copy.close()
	_main.call("_open", path)
	var store: Object = _main.get("_store")
	for _n: int in 600:
		if (store.get("awaited") as Array).is_empty():
			break
		await process_frame
	await _frames(20)
	var world: BrickWorld = _main.get("_world")
	var name: String = (_main.get("_bar") as ModelBar).model_name()
	print("the walk's Pods: %d parts, named %s" % [world.brick_count(), name])
	return _check("it opens", world.brick_count() >= 12 and name.to_lower() == "pods")


# -- x2: the booklet as a PDF ----------------------------------------------------------


func _pdf() -> void:
	print("")
	print("x2: a cover in Russian and Greek, saved as a PDF")
	var setup: String = await _say("page_setup", {"title": TITLE, "subtitle": SUBTITLE})
	print("    page_setup: %s" % setup.left(140).replace("\n", " "))
	var made: Array = await _called("export_model", {"format": "pdf"})
	var said: String = made[0]
	var calls: int = 1 + int(made[1])
	print("    export_model pdf, then job: %s" % said.right(260).replace("\n", " "))
	var pdf: String = _wrote(said, "pdf")
	_check("export_model pdf writes the PDF where Export writes: %s" % pdf.get_file(),
		not pdf.is_empty() and pdf.get_base_dir() == _out and FileAccess.file_exists(pdf))
	_check("...saying every letter is in the type it carries, none missing",
		said.contains("the booklet as Instructions prints it, every letter in the type the PDF carries, none missing"))
	_check("...in %d calls with page_setup's and the job's (3 or fewer)" % calls, calls <= 3)
	# The cover pictured in the same answer, so the session needs no fourth
	# call to see the letters (the walk's x2 looked with booklet_page).
	var cover: Image = _seen
	var shots: String = OS.get_environment("MCPREACH_OUT") if not OS.get_environment(
		"MCPREACH_OUT").is_empty() else ProjectSettings.globalize_path("res://shots/mcpreach")
	DirAccess.make_dir_recursive_absolute(shots)
	if cover != null:
		cover.save_png(shots.path_join("pdf_cover.png"))
	_check("...and the answer shows its cover as the PDF prints it, %s (%s)"
		% ["%d x %d" % [cover.get_width(), cover.get_height()] if cover != null else "none",
		shots.path_join("pdf_cover.png")],
		cover != null and cover.get_width() > cover.get_height() and cover.get_width() >= 1000
		and said.contains("Its cover, as the PDF prints it"))
	if pdf.is_empty():
		return
	var read: Array = []
	OS.execute("pdftotext", [pdf, "-"], read)
	var words: String = "".join(read)
	_check("pdftotext reads the title as typed: \"%s\"" % TITLE, words.contains(TITLE))
	_check("pdftotext reads the subtitle as typed: \"%s\"" % SUBTITLE, words.contains(SUBTITLE))
	_check("...with %d \"?\" in the whole PDF's words" % words.count("?"), words.count("?") == 0)
	var pages: Array = []
	OS.execute("pdfinfo", [pdf], pages)
	print("    %s" % "".join(pages).get_slice("Pages:", 1).strip_edges().get_slice("\n", 0) + " pages")
	var left: Array = Array(DirAccess.get_files_at(_out)).filter(func(file: String) -> bool:
		return file.ends_with(".html"))
	var page_dir: String = OS.get_user_data_dir().path_join("booklet_pdf")
	var kept: Array = Array(DirAccess.get_files_at(page_dir)) if DirAccess.dir_exists_absolute(page_dir) else []
	_check("...and no booklet page left beside it, or where it was drawn (%s)"
		% ", ".join(left + kept), left.is_empty() and kept.is_empty())
	var before: String = FileAccess.get_sha256(pdf)
	var again: String = (await _called("export_model", {"format": "pdf"}))[0]
	var second: String = _wrote(again, "pdf")
	_check("again: %s, \"%s\"" % [second.get_file(), _kept_words(again)],
		second.get_file() == "pods_instructions_2.pdf"
		and again.contains("pods_instructions.pdf was there already, and is kept"))
	_check("...and the first PDF is byte for byte as it was", FileAccess.get_sha256(pdf) == before)


# -- x4: a picture, then a picture in the dark -------------------------------------------


func _pictures() -> void:
	print("")
	print("x4: a picture, a spotlight hung over the pods, a picture in the dark")
	var first: String = (await _called("render_model", {"quality": "quick"}))[0]
	var picture: String = _wrote(first, "png")
	_check("render_model: %s" % picture.get_file(), picture.get_file() == "pods_render.png"
		and FileAccess.file_exists(picture))
	if picture.is_empty():
		return
	var before: String = FileAccess.get_sha256(picture)
	var count: int = (_main.get("_world") as BrickWorld).brick_count()
	var all: Array = range(1, count + 1)
	var hung: String = await _say("light_model", {"op": "add", "kind": "spot", "over": all})
	print("    light_model: %s" % hung.left(140).replace("\n", " "))
	var dark: String = (await _called("render_model", {"quality": "quick", "light": "dark"}))[0]
	var second: String = _wrote(dark, "png")
	_check("render_model light=dark: %s, \"%s\"" % [second.get_file(), _kept_words(dark)],
		second.get_file() == "pods_render_2.png" and FileAccess.file_exists(second)
		and dark.contains("pods_render.png was there already, and is kept"))
	_check("...and pods_render.png is byte for byte as it was", FileAccess.get_sha256(picture) == before)
	await _say("undo", {})


# -- every other export a session writes twice -------------------------------------------


func _twice() -> void:
	print("")
	print("each export again, beside the first")
	for format: Array in [["picture", "pods.png", "pods_2.png"], ["ldraw", "pods.mpd", "pods_2.mpd"],
			["3mf", "pods.3mf", "pods_2.3mf"], ["stl", "pods.stl", "pods_2.stl"],
			["obj", "pods.obj", "pods_2.obj"], ["studio", "pods.io", "pods_2.io"],
			["bricklink", "pods_bricklink.xml", "pods_bricklink_2.xml"],
			["rebrickable", "pods_rebrickable.csv", "pods_rebrickable_2.csv"],
			["instructions", "pods_instructions.html", "pods_instructions_2.html"]]:
		var first: String = _wrote((await _called("export_model", {"format": format[0]}))[0],
			str(format[1]).get_extension())
		if first.is_empty() or first.get_file() != format[1]:
			_check("%s: the first is %s (%s)" % [format[0], format[1], first.get_file()], false)
			continue
		var before: String = FileAccess.get_sha256(first)
		var said: String = (await _called("export_model", {"format": format[0]}))[0]
		var second: String = _wrote(said, str(format[2]).get_extension())
		var also: String = ""
		if format[0] == "obj":
			# Its colours beside it under the same new name.
			also = " and %s" % second.get_basename().get_file() + ".mtl"
			second = second if FileAccess.file_exists(second.get_basename() + ".mtl") else ""
		_check("%s again: %s%s, \"%s\"; the first byte for byte as it was" % [format[0],
			second.get_file(), also, _kept_words(said)], second.get_file() == format[2]
			and said.contains("%s was there already, and is kept" % format[1])
			and FileAccess.get_sha256(first) == before)


func _turntable() -> void:
	# A turntable is its WebP or GIF, its MP4 and its frames' folder, one name.
	var output := RenderOutput.new()
	output.folder = _out
	for taken: Array in [["pods_turntable", true], ["pods_turntable_2.mp4", false],
			["pods_turntable_3.gif", false]]:
		if bool(taken[1]):
			DirAccess.make_dir_recursive_absolute(_out.path_join(taken[0]))
		else:
			FileAccess.open(_out.path_join(taken[0]), FileAccess.WRITE).close()
	output.begin_turntable("Pods", RenderSettings.new())
	_check("a turntable with its frames' folder, an MP4 _2 and a GIF _3 there takes %s"
		% output.base_name(), output.base_name() == "pods_turntable_4")


# -- x5: closed solids -------------------------------------------------------------------


func _closed_pods() -> void:
	print("")
	print("x5: the Pods as a 3MF for a slicer")
	var said: String = (await _called("export_model", {"format": "3mf"}))[0]
	print("    %s" % said.right(200))
	var path: String = _wrote(said, "3mf")
	_check("the answer says every object is a closed solid",
		said.contains("every object a closed solid, with nothing for a slicer to repair"))
	_agrees(path, said, "the Pods'")


func _closed_car() -> void:
	print("")
	print("the example car as a 3MF, closed and as LDraw draws it, and as an STL")
	var opened: String = await _say("open_model", {"name": "Car", "discard_changes": true})
	_check("the example car opens: %s" % opened.left(60), opened.begins_with("Opened"))
	await _frames(20)
	var said: String = (await _called("export_model", {"format": "3mf"}))[0]
	print("    %s" % said.right(200))
	_check("the answer says every object is a closed solid",
		said.contains("every object a closed solid, with nothing for a slicer to repair"))
	_agrees(_wrote(said, "3mf"), said, "the car's")
	Mesh3mf.close_up = false
	var drawn: String = (await _called("export_model", {"format": "3mf"}))[0]
	Mesh3mf.close_up = true
	print("    as drawn: %s" % drawn.right(320))
	_check("as LDraw draws it, the answer says so: \"%s\"" % drawn.get_slice(" — ", 4).left(90),
		drawn.contains("0 of 7 objects closed solids; not closed: "))
	_agrees(_wrote(drawn, "3mf"), drawn, "the car's as drawn")
	var stl: String = (await _called("export_model", {"format": "stl"}))[0]
	print("    stl: %s" % stl.right(260))
	var file: String = _wrote(stl, "stl")
	var open: int = _stl_open_edges(file)
	_check("an STL says it is not a closed solid, naming its parts, as its triangles read here are open (%d edges)"
		% open, stl.contains("not a closed solid: ") and stl.contains("parts are open as LDraw draws them (")
		and open > 0)


## lib3mf's IsManifoldAndOriented for each object of [param path], against
## what [param said] says of each.
func _agrees(path: String, said: String, what: String) -> void:
	var report: Dictionary = _read(path)
	var objects: Array = report.get("objects", [])
	var wrong: PackedStringArray = []
	var closed: int = 0
	for object: Dictionary in objects:
		var whole: bool = bool(object.get("manifold_and_oriented", false))
		closed += 1 if whole else 0
		var named_open: bool = said.contains("not closed: ") \
			and said.get_slice("not closed: ", 1).get_slice(", from ", 0).split(", ").has(str(object["name"]))
		var all_closed: bool = said.contains("every object a closed solid")
		if whole == named_open or (not whole and all_closed):
			wrong.append("%s: lib3mf %s" % [object["name"], "closed" if whole else "open"])
	_check("%s objects: lib3mf finds %d of %d closed, and the answer says the same of each%s"
		% [what, closed, objects.size(), "" if wrong.is_empty() else ": " + "; ".join(wrong)],
		not objects.is_empty() and wrong.is_empty())


## The STL's open edges, read here from its triangles: corners welded to
## 1/64 LDU (0.00625 mm), each edge wanted once each way round.
static func _stl_open_edges(path: String) -> int:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 84:
		return -1
	var count: int = bytes.decode_u32(80)
	var weld: Dictionary = {}
	var halves: Dictionary = {}
	for t: int in count:
		var ids: Array = []
		for c: int in 3:
			var at: int = 84 + t * 50 + 12 + c * 12
			var key := Vector3i(roundi(bytes.decode_float(at) * 160.0), roundi(bytes.decode_float(at + 4) * 160.0),
				roundi(bytes.decode_float(at + 8) * 160.0))
			if not weld.has(key):
				weld[key] = weld.size()
			ids.append(weld[key])
		if ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2]:
			continue
		for e: int in 3:
			var half: Vector2i = Vector2i(ids[e], ids[(e + 1) % 3])
			halves[half] = int(halves.get(half, 0)) + 1
	var open: int = 0
	for half: Vector2i in halves:
		if int(halves[half]) != 1 or int(halves.get(Vector2i(half.y, half.x), 0)) != 1:
			open += 1
	return open


# -- a person's own File › Export --------------------------------------------------------


func _asked() -> void:
	print("")
	print("a person's File › Export › 3D model…, with its save dialog, as before")
	var exports: Exports = _main.get("_exports")
	var there: String = _out.path_join("car.3mf")
	if not FileAccess.file_exists(there):
		_check("car.3mf is there to write over", false)
		return
	var before: int = DirAccess.get_files_at(_out).size()
	var line: Array = [""]
	var press := func() -> void: line[0] = await exports.model_3d("3mf", true)
	press.call()
	var dialog: FileDialog = null
	for _n: int in 1200:
		await process_frame
		if SaveTo.showing != null and SaveTo.showing.visible:
			dialog = SaveTo.showing
			break
	_check("the save dialog asks, offering \"%s\" with car.3mf there"
		% (dialog.current_file if dialog != null else "-"), dialog != null and dialog.current_file == "car.3mf")
	if dialog == null:
		return
	dialog.current_dir = _out
	dialog.current_file = "car.3mf"
	await _frames(2)
	dialog.get_ok_button().pressed.emit()
	# The dialog asks first whether to replace what is there, as it always
	# has: the person's yes is the second press.
	var replace: ConfirmationDialog = null
	for _n: int in 600:
		await process_frame
		replace = _replace_asked(dialog)
		if replace != null:
			break
	_check("...asking first whether to replace car.3mf: \"%s\""
		% (replace.dialog_text if replace != null else "-"), replace != null)
	if replace != null:
		replace.get_ok_button().pressed.emit()
	for _n: int in 3600:
		if not str(line[0]).is_empty():
			break
		await process_frame
	_check("...and writes over it when the person says so, no second file: \"%s\"" % str(line[0]).left(120),
		str(line[0]).begins_with("wrote " + there + " — ") and not str(line[0]).contains("was there already")
		and DirAccess.get_files_at(_out).size() == before)


## The file dialog's own "replace it?" question, once it shows.
static func _replace_asked(dialog: FileDialog) -> ConfirmationDialog:
	for child: Node in dialog.get_children(true):
		if child is ConfirmationDialog and (child as ConfirmationDialog).visible:
			return child
	return null


# -- helpers -----------------------------------------------------------------------------


## A session's call, its job followed to the end with the job tool as a
## session follows it: [the answer's words, the calls it took].
func _called(tool: String, arguments: Dictionary) -> Array:
	var said: String = await _say(tool, arguments)
	var calls: int = 1
	var job := RegEx.create_from_string("^Started job (\\d+)")
	var found: RegExMatch = job.search(said)
	while found != null and calls < 60:
		said = await _say("job", {"id": int(found.get_string(1))})
		calls += 1
		if not said.contains("is still going"):
			break
	return [said, calls]


## The file [param said] says it wrote, ending in [param ending]; "" for none.
static func _wrote(said: String, ending: String) -> String:
	var found: RegExMatch = RegEx.create_from_string("[Ww]rote (\\S+\\.%s)\\b" % ending).search(said)
	return found.get_string(1) if found != null else ""


static func _kept_words(said: String) -> String:
	var at: int = said.find(" was there already, and is kept")
	if at < 0:
		return "-"
	return said.substr(said.rfind(" — ", at) + 3, at - said.rfind(" — ", at) - 3) + " was there already, and is kept"


func _read(path: String) -> Dictionary:
	if path.is_empty():
		return {"errors": ["nothing written"]}
	var json: String = path.get_basename() + "_check.json"
	var out: Array = []
	var arguments := PackedStringArray(["--offline"])
	arguments.append_array(READER_WITH)
	arguments.append_array(["python3", "-I", ProjectSettings.globalize_path(CHECKER), path,
		"--json=" + json])
	OS.execute("uvx", arguments, out, true)
	if not FileAccess.file_exists(json):
		arguments.remove_at(0)
		OS.execute("uvx", arguments, out, true)
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(json)) \
		if FileAccess.file_exists(json) else null
	DirAccess.remove_absolute(json)
	if not report is Dictionary:
		print("    the reader said: %s" % "".join(out).right(400))
		return {}
	return report


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	var result: Dictionary = await _rpc("tools/call", {"name": tool, "arguments": arguments})
	var text: String = ""
	_seen = null
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
		if str(block.get("type", "")) == "image":
			_seen = Image.new()
			if _seen.load_png_from_buffer(Marshalls.base64_to_raw(
					str((block.get("source", {}) as Dictionary).get("data", "")))) != OK:
				_seen = null
	return text



func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("mcpreach")
	var password: String = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": _email, "password": password,
			"email_confirm": true}))
	var problem: String = ""
	if int(made.get("code", 0)) != 200:
		problem = "the account was not made: %d" % int(made.get("code", 0))
	else:
		var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
			PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
			HTTPClient.METHOD_POST, JSON.stringify({"email": _email, "password": password}))
		if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
			problem = "no session: %d" % int(reply.get("code", 0))
		else:
			account._keep(reply["body"])
			account.state = Account.State.SIGNED_IN
			account.changed.emit()
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _quit() -> void:
	Mesh3mf.close_up = true
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("  (removed %d throwaway account(s))" % gone)
	print("mcpreach_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
