## Each sub-model as a file of its own (APP_UX7 #19, subexport).
##
##   godot --path . --resolution 1400x900 --script src/dev/subexport_probe.gd [-- --shots=DIR]
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in with a password
## grant (as binrow_probe), the account deleted at the end. Needs .env
## (SUPABASE_URL, SUPABASE_SECRET_KEY). Then on three models:
## - 7140-1 as its author wrote it (someone else's file, kept as written):
##   21 sub-models, nested two deep, the rear engine four times;
## - the castle (models/castle.ldr), the app's own file: ten towers and
##   walls built a course of each in turn, in the castle's steps, so none has
##   a section of its own (AuthorSteps.IN_PARENT);
## - the castle with its steps made its own (one step edit over MCP).
## On each:
## - File › Export › LDraw model's file kept, before anything else;
## - export_model format=ldraw submodels=true over MCP, one call: a .zip of
##   a file for each sub-model, each definition once;
## - export_model submodel=NAME, one call: that one's file, the zip's to the
##   byte; the model tree's row menu, a right click on its row (a picture
##   at 1400 x 900 and at 1280 x 720): Export “NAME” as its own file…, the
##   same file; and on the model's row, Export each sub-model (.zip)…, and
##   File › Export › Each sub-model as its own file (.zip): the same files;
## - each file read line by line against the whole model's: each of its
##   sections the whole file's section of that name, every line, the model's
##   own line saying whose its steps are put in after its author; a copy
##   built in its parent's steps, its parts' lines and its own copies' lines
##   as the whole file has them, in its order, a step for each step of it;
## - each file opened alone in the app: every part of the sub-model there,
##   in its colour, where the whole model has it in the sub-model's own
##   frame, within 0.001 LDU, and nothing more; its tree the sub-model's
##   own sub-models (each one's copies numbered from 1 as a file alone
##   numbers them); an author's steps still the author's, written again
##   step for step as the file has them;
## - File › Export › LDraw model's file again, the same to the byte.
## First, a line for each of sereview's findings (2026-11-09), on models
## made for them:
## - F1, F6: sub-models named with folders, a parent folder, control
##   characters, what Windows refuses or keeps for a device (one with an
##   extension), 304 bytes, nothing but refused characters, two that are
##   one once made safe; and copies built in their parents' steps titled
##   "..\..\evil", "Tårn", "a:b?c": every zip entry a name every system
##   takes, inside the folder it is unzipped in, none twice, the same name
##   by submodel= as in the zip, a built-in copy's Name line its file's;
## - F2: the zip's members flagged UTF-8 in both headers, All my models'
##   too (a model saved as Tårn: run it with a data folder of its own);
## - F3: two sections of one key by folder ("Dup.ldr", "sub\dup.ldr"; 345-1's
##   subparts): each file the twin the model is built of, opened alone to
##   the same parts;
## - F4: the row menu on a model shared to look at, and on one being laid:
##   both items greyed as File › Export's are, and nothing written;
## - F5: a finger held still on a row opens its menu (a tap, or a finger
##   that moves, does not), beside the finger, its lift choosing nothing;
## - F7: export_model with submodel= and submodels=true refused.
## --cases-only runs those alone.
## Pictures go to --shots=DIR, else user://subexport.
extends SceneTree

const SUBJECTS: Array = [
	["7140", "res://vendor/omr/files/7140-1.mpd", false, "Ship", 21],
	["castle", "res://models/castle.ldr", false, "north-east tower", 10],
	["castle_own", "res://models/castle.ldr", true, "gatehouse", 10],
]
const NEAR := 0.001
const SIZES: Array[Vector2i] = [Vector2i(1400, 900), Vector2i(1280, 720)]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _bar: ModelBar
var _socket: CommandSocket
var _rpc_id: int = 0
var _out: String = "user://subexport"
var _files: String = ""
var _email: String = ""
var _password: String = ""
var _table: Array[String] = []
var _cases_only: bool = false


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
		elif arg == "--cases-only":
			_cases_only = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	ShellPrefs.kept_by_a_check = _own_data_folder()
	_files = OS.get_user_data_dir().path_join("subexport_files")
	DirAccess.make_dir_recursive_absolute(_files)
	# Every file a press writes, here and asked nothing (SaveTo.ask).
	Download.folder = _files
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback != null:
		(playback as BuildPlayback).stop()
	if not await _way_in():
		await _finish()
		return
	_world = _main.get("_world")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	await _review_cases()
	for subject: Array in [] if _cases_only else SUBJECTS:
		await _subject(subject)
	print("")
	print("  model        sub-models  files  lines  opened alone  worst LDU  whole export")
	for line: String in _table:
		print("  " + line)
	await _finish()


## The sign-in screen up, a throwaway account signed in, the screen gone.
func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("subexport")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made (as
## binrow_probe).
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


# -- one model -----------------------------------------------------------------


func _subject(subject: Array) -> void:
	var tag: String = subject[0]
	var named: String = subject[3]
	var expected_files: int = subject[4]
	print("\n%s" % tag)
	await _open(FileAccess.get_file_as_string(str(subject[1])), tag)
	if bool(subject[2]):
		var middle: int = _world.bricks()[_world.bricks().size() / 2].id
		var said: String = await _say("edit_steps", {"op": "next", "bricks": [middle]})
		await _frames(4)
		_check("its steps its own: %s" % said.get_slice("\n", 0).left(100),
			AuthorSteps.any(_world, _store.scenery))
	var tree: PackedStringArray = _shell.assemblies.paths()
	# The whole model's file, as File › Export writes it, before and after.
	var read: Array = await _read_whole(tag)
	var whole: String = read[0]
	var before_sha: String = whole.sha256_text()
	print("    the whole model's file: %d bytes, sha256 %s" % [whole.length(), before_sha])
	var parsed: LdrModel = read[1]
	var placed: Array[LdrModel.Placement] = read[2]
	var held: Array = read[3]
	var paths_missing: Array = Array(tree).filter(func(path: String) -> bool:
		return not parsed.unit_steps.has(path))
	_check("every row of the model tree (%d) is a copy the whole file places%s" % [tree.size(),
		"" if paths_missing.is_empty() else ": not " + ", ".join(paths_missing.slice(0, 4))],
		paths_missing.is_empty())

	# Over MCP, each in one call and one by name in one call.
	_clear_files()
	var each_said: String = await _say("export_model", {"format": "ldraw", "submodels": true})
	print("    export_model submodels=true: %s" % each_said.left(220))
	var zip: Dictionary = _zip_members(_newest("zip"))
	_check("%s: one call over MCP writes a .zip of %d files, one for each sub-model (%d)" % [tag,
		zip.size(), expected_files], zip.size() == expected_files)
	_clear_files()
	var one_said: String = await _say("export_model", {"format": "ldraw", "submodel": named})
	print("    export_model submodel=%s: %s" % [named, one_said.left(220)])
	var one_path: String = _newest("ldr") if not _newest("ldr").is_empty() else _newest("mpd")
	var one_text: String = FileAccess.get_file_as_string(one_path) if not one_path.is_empty() else ""
	var in_zip: String = str(zip.get(one_path.get_file(), ""))
	_check("%s: submodel=%s in one call writes %s, the zip's file of that name to the byte" % [tag,
		named, one_path.get_file() if not one_path.is_empty() else "nothing"],
		not one_text.is_empty() and one_text == in_zip)

	# By hand: the model tree's row menu, and File › Export.
	var row: String = _path_named(named, tree)
	var by_menu: String = await _row_menu_one(tag, row)
	_check("%s: the tree's menu on %s, Export as its own file…, writes the same file" % [tag,
		Assemblies.label(row)], not by_menu.is_empty() and by_menu == in_zip)
	var by_menu_each: Dictionary = await _row_menu_each()
	_check("%s: the tree's menu on the model, Export each sub-model (.zip)…, writes the same files"
		% tag, not by_menu_each.is_empty() and by_menu_each == zip)
	var by_file_menu: Dictionary = await _file_export_each()
	_check("%s: File › Export › Each sub-model as its own file (.zip) writes the same files" % tag,
		not by_file_menu.is_empty() and by_file_menu == zip)

	# Each file, line by line against the whole model's file, then opened alone.
	var lines_ok: int = 0
	var alone_ok: int = 0
	var worst: float = 0.0
	var names: Array = zip.keys()
	names.sort()
	var by_path: Dictionary = _paths_by_file(parsed, names, zip)
	for file: String in names:
		var path: String = str(by_path.get(file, ""))
		if path.is_empty():
			_check("%s/%s: the file is one sub-model's" % [tag, file], false)
			continue
		var text: String = zip[file]
		if _same_lines(tag, file, text, whole, parsed, placed, path):
			lines_ok += 1
		var result: Array = await _alone(tag, file, text, parsed, held, path)
		if bool(result[0]):
			alone_ok += 1
		worst = maxf(worst, float(result[1]))

	# And the whole model's file the same as before, to the byte.
	await _open(FileAccess.get_file_as_string(str(subject[1])), tag)
	if bool(subject[2]):
		var middle: int = _world.bricks()[_world.bricks().size() / 2].id
		await _say("edit_steps", {"op": "next", "bricks": [middle]})
		await _frames(4)
	var after: String = await _whole_export(tag)
	_check("%s: File › Export › LDraw model writes the same file after, to the byte (%s)" % [tag,
		after.sha256_text().left(16)], after == whole)
	_table.append("%-12s %10d  %5d  %5s  %12s  %9.6f  %s" % [tag, expected_files, zip.size(),
		"%d/%d" % [lines_ok, zip.size()], "%d/%d" % [alone_ok, zip.size()], worst,
		before_sha.left(16)])


## The whole model's file as File › Export writes it, read: [its text, the
## model it parses to, its placements, and its parts as the app holds them
## (each number as the library resolved it) where the file has them, each
## [path, part, colour, place]].
func _read_whole(tag: String) -> Array:
	var whole: String = await _whole_export(tag)
	var parsed: LdrModel = LdrModel.parse(whole, "model")
	var placed: Array[LdrModel.Placement] = parsed.flatten(_library.parts)
	var back := Transform3D(Basis.IDENTITY, -(_store.call("_lift_now") as Vector3))
	var held: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			held.append([Assemblies.path_of(brick), brick.part_id, brick.color_code,
				back * brick.transform])
	return [whole, parsed, placed, held]


## Which sub-model each file is: the path of the first copy of its section
## (or, for a copy built in its parent's steps, of its name) whose file is
## named so.
func _paths_by_file(parsed: LdrModel, names: Array, zip: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var paths: Array = parsed.unit_steps.keys()
	paths.sort()
	for file: String in names:
		# Its own section: the first, keyed as its FILE or Name line names it;
		# a copy built in its parent's steps, by its title, its first line
		# (its name made safe for a file is not its title's).
		var key: String = str(_sections(str(zip[file])).keys()[0])
		var titled: String = ""
		for line: String in str(zip[file]).split("\n"):
			if LdrModel.section_word(line).is_empty():
				titled = line.strip_edges()
				break
		for path: String in paths:
			var built_within: bool = int(parsed.unit_steps[path]) == LdrModel.IN_PARENT
			if (built_within and titled == "0 " + Assemblies.definition(Assemblies.leaf(path))) \
					or (not built_within and str(parsed.unit_sections.get(path, "")) == key):
				out[file] = path
				break
	return out


# -- what sereview found (2026-11-09), a line each ----------------------------------


## The names a sub-model may have that no system takes for a file as they
## are, each a FILE section's: folders, the folder above, a dot first,
## control characters, what Windows refuses and keeps for its devices (one
## with an extension, one long), 304 bytes, nothing but refused characters,
## dots and spaces at the end, two that are one once made safe, and ones
## every system takes as they are, Tårn, 城, 150°.
const ODD_NAMES: Array[String] = ["../up.ldr", "C:\\win.ldr", "/abs.ldr", "..", "...",
	".hidden.ldr", "what?.ldr", "CON.ldr", "aux.backup.ldr", "LPT1", "a<b>|c*.ldr",
	"<>:|?*.ldr", "\"|\"", "end..", "x. .", "a?b.ldr", "ab.ldr", "Tårn.ldr", "城.ldr",
	"Ferrari 150° Italia.ldr", "..\\..\\..\\evil.ldr"]
const COLOURS: Array[int] = [1, 2, 4, 14, 15, 19, 25, 28, 70, 71, 72]


func _odd_names() -> Array[String]:
	var names: Array[String] = ODD_NAMES.duplicate()
	names.append("ctl" + String.chr(1) + "x" + String.chr(27) + "z.ldr")
	names.append("L".repeat(300) + ".ldr")
	# A device's name made long: the "_" it is given must not take it past 200
	# bytes.
	names.append("aux." + "城".repeat(100) + ".ldr")
	return names


## A model of a sub-model for each of [method _odd_names], one part in each.
func _odd_model() -> String:
	var names: Array[String] = _odd_names()
	var main := PackedStringArray(["0 FILE odd.ldr", "0 Odd names", "0 Name: odd.ldr",
		"0 Author: subexport probe"])
	var rest := PackedStringArray()
	for n: int in names.size():
		main.append("1 16 %d 0 0 1 0 0 0 1 0 0 0 1 %s" % [40 * n, names[n]])
		rest.append_array(["0 FILE " + names[n], "0 Odd %d" % n, "0 Name: " + names[n],
			"0 Author: subexport probe",
			"1 %d 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat" % COLOURS[n % COLOURS.size()], "0 NOFILE"])
	main.append("0 NOFILE")
	return "\n".join(main) + "\n" + "\n".join(rest) + "\n"


## The castle's way, three copies built in the model's own steps (IN_META),
## titled as no file can be called.
const IN_PARENT_MODEL := """0 Castle in steps
0 Name: inparent.ldr
0 Author: Reviewer
0 !BRICKWORKS AUTHORED_STEPS

0 !BRICKWORKS IN ..\\..\\evil#1
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 !BRICKWORKS IN Tårn#1
1 1 200 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 !BRICKWORKS IN a:b?c#1
1 2 400 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 !BRICKWORKS IN ..\\..\\evil#1
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 !BRICKWORKS IN Tårn#1
1 1 200 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 ROTSTEP 0 90 0 REL
0 !BRICKWORKS IN Tårn#1
1 1 200 -72 0 1 0 0 0 1 0 0 0 1 3003.dat
0 !BRICKWORKS IN a:b?c#1
1 2 400 -48 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
"""

## Two sections of one key, by folder: the model is built of the last
## (LdrModel keeps the last of a key), as LDView would take the first.
const TWINS_MODEL := """0 FILE dupmain.ldr
0 Dup main
0 Name: dupmain.ldr
0 Author: Reviewer
1 16 0 0 0 1 0 0 0 1 0 0 0 1 dup.ldr
1 16 100 0 0 1 0 0 0 1 0 0 0 1 other.ldr
0 NOFILE
0 FILE Dup.ldr
0 Dup first
0 Name: Dup.ldr
0 Author: Reviewer
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
0 FILE other.ldr
0 Other
0 Name: other.ldr
0 Author: Reviewer
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 dup.ldr
0 NOFILE
0 FILE sub\\dup.ldr
0 Dup second
0 Name: sub\\dup.ldr
0 Author: Reviewer
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 4 40 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 NOFILE
"""


func _review_cases() -> void:
	print("\nwhat sereview found (2026-11-09), a line each")
	await _odd_names_case()
	await _in_parent_case()
	await _all_models_case()
	await _twins_case()
	await _gates_case()
	await _finger_case()
	await _both_flags_case()


## F6, F1's root, and F2: the odd names' model, each sub-model at once.
func _odd_names_case() -> void:
	await _open(_odd_model(), "odd")
	var tree: PackedStringArray = _shell.assemblies.paths()
	_clear_files()
	await _say("export_model", {"format": "ldraw", "submodels": true})
	var zip_path: String = _newest("zip")
	var zip: Dictionary = _zip_members(zip_path)
	var flags: Array = _utf8_flags(zip_path)
	var unsafe: Array[String] = []
	var seen: Dictionary = {}
	for name: String in zip:
		var why: String = _unsafe(name)
		if not why.is_empty():
			unsafe.append("%s: %s" % [_shown(name), why])
		seen[name.to_lower()] = true
	var names: Array = zip.keys()
	names.sort()
	_check("F6: %d sub-models named as no system takes a file, a .zip of %d, each name one every system takes, none twice: %s%s" % [
		_odd_names().size(), zip.size(), ", ".join(names.map(func(n: String) -> String: return _shown(n))),
		"" if unsafe.is_empty() else "; not so: " + "; ".join(unsafe)],
		zip.size() == _odd_names().size() and unsafe.is_empty() and seen.size() == zip.size())
	# One rule for both ways: each row by submodel= writes a file of the
	# name the zip has for it (or that name's "_2", a twin's).
	var differ: Array[String] = []
	for path: String in tree:
		_clear_files()
		await _say("export_model", {"format": "ldraw", "submodel": path})
		var files: PackedStringArray = DirAccess.get_files_at(_files)
		var one: String = files[0] if files.size() == 1 else ""
		var text: String = FileAccess.get_file_as_string(_files.path_join(one)) if not one.is_empty() else ""
		var found: bool = false
		for name: String in zip:
			if str(zip[name]) == text and (name == one or (name.get_basename().begins_with(
					one.get_basename() + "_") and name.get_extension() == one.get_extension())):
				found = true
		if not found:
			differ.append("%s -> %s" % [Assemblies.label(path), _shown(one) if not one.is_empty()
				else "%d files" % files.size()])
	_check("F6: each of the %d rows by submodel= is named as the zip names it, one rule for both%s" % [
		tree.size(), "" if differ.is_empty() else ": not " + ", ".join(differ.slice(0, 4))],
		differ.is_empty() and not tree.is_empty())
	_check("F2: the zip says its names are UTF-8 (bit 11) in all %d members' own headers (%d) and the directory's (%d), made on Unix (%d), so Tårn.ldr, 城.ldr, 150° read so: %s" % [
		int(flags[0]), int(flags[1]), int(flags[2]), int(flags[3]), ", ".join(["Tårn.ldr", "城.ldr",
		"Ferrari 150° Italia.ldr"].map(func(n: String) -> String: return "%s %s" % [n,
		"in it" if zip.has(n) else "not in it"]))], int(flags[0]) == zip.size()
		and int(flags[1]) == zip.size() and int(flags[2]) == zip.size()
		and int(flags[3]) == zip.size() and zip.has("Tårn.ldr")
		and zip.has("城.ldr") and zip.has("Ferrari 150° Italia.ldr"))


## F1: copies built in their parent's steps, titled as no file is called.
func _in_parent_case() -> void:
	await _open(IN_PARENT_MODEL, "inparent")
	_clear_files()
	await _say("export_model", {"format": "ldraw", "submodels": true})
	var zip: Dictionary = _zip_members(_newest("zip"))
	var names: Array = zip.keys()
	names.sort()
	var evil: String = str(zip.get("evil.ldr", ""))
	_clear_files()
	await _say("export_model", {"format": "ldraw", "submodel": "..\\..\\evil"})
	var files: PackedStringArray = DirAccess.get_files_at(_files)
	var one: String = FileAccess.get_file_as_string(_files.path_join(files[0])) if files.size() == 1 else ""
	# Its names (FILE, Name) are evil.ldr; its first line, the title a reader
	# shows, stays as its author wrote it: "0 ..\..\evil" names no file.
	var name_lines: Array = Array(evil.split("\n")).filter(func(line: String) -> bool:
		return line.begins_with("0 FILE") or line.begins_with("0 Name:"))
	var wrong: Array = []
	if names != ["abc.ldr", "evil.ldr", "tårn.ldr"]:
		wrong.append("the zip's names")
	if name_lines != ["0 Name: evil.ldr"]:
		wrong.append("its name lines %s" % [name_lines])
	if not evil.begins_with("0 ..\\..\\evil\n"):
		wrong.append("its title %s" % _shown(evil.get_slice("\n", 0)))
	if Array(files) != ["evil.ldr"]:
		wrong.append("submodel='s file")
	elif one != evil:
		wrong.append("submodel='s file differs from the zip's")
	_check("F1: a copy built in its parent's steps titled ..\\..\\evil is evil.ldr in the zip (%s), its name lines %s, its title as written, and the same file by submodel= (%s)%s" % [
		", ".join(names.map(func(n: String) -> String: return _shown(n))), name_lines,
		", ".join(Array(files).map(func(n: String) -> String: return _shown(n))),
		"" if wrong.is_empty() else ": not " + ", ".join(wrong)], wrong.is_empty())


## F2: All my models' zip, by the same writer, a model saved as Tårn in it.
func _all_models_case() -> void:
	if not _own_data_folder():
		_check("F2: All my models' zip names Tårn.ldr as UTF-8: run through tools/probe.sh, as it saves a model", false)
		return
	await _open(IN_PARENT_MODEL, "inparent")
	var saved: bool = _store.save_as("Tårn")
	_clear_files()
	var exports: Exports = _main.get("_exports")
	await exports.all_models()
	var zip_path: String = _newest("zip")
	var zip: Dictionary = _zip_members(zip_path)
	var flags: Array = _utf8_flags(zip_path)
	_check("F2: All my models' zip, saved as Tårn (%s): %s, flagged UTF-8 in %d of %d own headers and %d in the directory, %d made on Unix" % [
		saved, ", ".join(zip.keys().map(func(n: String) -> String: return _shown(n))), int(flags[1]), int(flags[0]), int(flags[2]),
		int(flags[3])], saved and zip.has("Tårn.ldr") and int(flags[0]) == zip.size()
		and int(flags[1]) == zip.size() and int(flags[2]) == zip.size() and int(flags[3]) == zip.size())


## F3: of two sections of one key, each file the twin the model is built
## of, opened alone to the same parts: the twins model, and 345-1's House,
## whose part carries two subparts so (s\345 - u9078s01.dat).
func _twins_case() -> void:
	for subject: Array in [["F3 twins", TWINS_MODEL, ["Dup second", "Other"]],
			["F3 345-1", FileAccess.get_file_as_string("res://vendor/omr/files/345-1.mpd"), ["House"]]]:
		var tag: String = subject[0]
		await _open(str(subject[1]), tag)
		var read: Array = await _read_whole(tag)
		var tree: PackedStringArray = _shell.assemblies.paths()
		for named: String in subject[2]:
			var path: String = _path_named(named, tree)
			_clear_files()
			await _say("export_model", {"format": "ldraw", "submodel": named})
			var files: PackedStringArray = DirAccess.get_files_at(_files)
			if files.size() != 1 or path.is_empty():
				_check("%s: submodel=%s writes one file (%s)" % [tag, named, ", ".join(files)], false)
				continue
			var text: String = FileAccess.get_file_as_string(_files.path_join(files[0]))
			await _alone(tag, files[0], text, read[1], read[3], path)
			var unlike: String = _ldraw_unlike(text, str(read[0]))
			_check("%s/%s: each reference LDraw's own rule (LDView's) finds a section for in the whole model's file finds the same lines here%s" % [
				tag, files[0], "" if unlike.is_empty() else ", but not: " + unlike], unlike.is_empty())
			await _open(str(subject[1]), tag)


## F4: the row menu as File › Export: on a model shared to look at, and on
## one still being laid, both items greyed and nothing written; both again
## once it is neither.
func _gates_case() -> void:
	await _open(TWINS_MODEL, "twins")
	var outliner: Outliner = _shell.outliner
	var path: String = _path_named("Other", _shell.assemblies.paths())
	for gate: String in ["shared to look at", "being laid", "neither"]:
		if gate == "shared to look at":
			_shell.read_only = true
		elif gate == "being laid":
			_store.set("_laying_in", _world.generation())
		_clear_files()
		outliner.open_row_menu(path, Vector2(200, 200))
		var menu: PopupMenu = outliner.row_menu
		var items: Array[String] = []
		var enabled: int = 0
		for n: int in menu.item_count:
			items.append("%s %s" % [menu.get_item_text(n), "greyed" if menu.is_item_disabled(n)
				else "enabled"])
			enabled += 0 if menu.is_item_disabled(n) else 1
		menu.hide()
		var file_menu: bool = _shell.can("export_ldraw") or _shell.can("export_submodels")
		if gate != "neither":
			# Pressed though greyed, as a stale menu or a check presses it.
			outliner.call("_on_row_menu", Outliner.MENU_ONE)
			outliner.call("_on_row_menu", Outliner.MENU_EACH)
			for _n: int in 120:
				await process_frame
		var written: PackedStringArray = DirAccess.get_files_at(_files)
		_shell.read_only = false
		_store.set("_laying_in", -1)
		await _frames(4)
		if gate == "neither":
			_check("F4: on a model neither, File › Export's and the menu's both enabled: %s" % " | ".join(items),
				enabled == 2 and file_menu)
		else:
			_check("F4: on a model %s, File › Export refuses (%s) and the row menu greys both and writes nothing: %s; written %s" % [
				gate, not file_menu, " | ".join(items), Array(written)], enabled == 0 and not file_menu
				and written.is_empty() and items.size() == 2)


## F5: a finger on a row of the model tree. A tap, and a finger that moves,
## open nothing; held still, the row's menu, beside the finger, its lift
## choosing nothing; its first item then writes the row's file.
func _finger_case() -> void:
	await _open(TWINS_MODEL, "twins")
	var outliner: Outliner = _shell.outliner
	await _show_tree()
	var path: String = _path_named("Other", _shell.assemblies.paths())
	var rects: Dictionary = await _row_in_sight(outliner, path)
	if not rects.has(path):
		_check("F5: the row of Other is in sight to hold a finger on", false)
		return
	var at: Vector2 = (rects[path] as Rect2).get_center()
	_clear_files()
	# A tap.
	_touch(at, true)
	await _frames(2)
	_touch(at, false)
	await create_timer(0.8).timeout
	var after_tap: bool = outliner.row_menu != null and outliner.row_menu.visible
	# A finger that moves along the row, then stays.
	_touch(at, true)
	for step: int in 6:
		_finger_drag(at + Vector2(8.0 * (step + 1), 0.0))
		await _frames(2)
	await create_timer(0.8).timeout
	var after_move: bool = outliner.row_menu != null and outliner.row_menu.visible
	_touch(at + Vector2(48.0, 0.0), false)
	await _frames(6)
	if outliner.row_menu != null:
		outliner.row_menu.hide()
	# Held still.
	_touch(at, true)
	await create_timer(0.8).timeout
	var menu: PopupMenu = outliner.row_menu
	var shown: bool = menu != null and menu.visible
	var for_row: String = str(outliner.get("_menu_path"))
	var under: bool = shown and Rect2(Vector2(menu.position), Vector2(menu.size)).has_point(at)
	await _shot("finger_menu")
	_touch(at, false)
	await _frames(20)
	var still: bool = menu != null and menu.visible
	var lifted: PackedStringArray = DirAccess.get_files_at(_files)
	_check("F5: a finger held still on Other's row opens its menu (%s, for %s), beside the finger (under it: %s), and lifting chooses nothing (open still %s, written %s); a tap opens none (%s), nor a finger that moved (%s)" % [
		shown, Assemblies.label(for_row) if not for_row.is_empty() else "the model", under, still,
		Array(lifted), after_tap, after_move], shown and for_row == path and not under and still
		and lifted.is_empty() and not after_tap and not after_move)
	if shown:
		menu.id_pressed.emit(menu.get_item_id(0))
		menu.hide()
		await _until_file(["ldr", "mpd"])
		var written: PackedStringArray = DirAccess.get_files_at(_files)
		_check("F5: and its first item, chosen, writes Other's file (%s)" % ", ".join(written),
			Array(written) == ["other.mpd"])


## F7: both flags at once.
func _both_flags_case() -> void:
	await _open(TWINS_MODEL, "twins")
	_clear_files()
	var said: String = await _say("export_model", {"format": "ldraw", "submodels": true, "submodel": "Other"})
	var written: PackedStringArray = DirAccess.get_files_at(_files)
	_check("F7: submodel=Other with submodels=true is refused and writes nothing (%s): %s" % [
		Array(written), said.left(120)], written.is_empty() and said.contains("not both"))


## LDraw's own rule (LDView's, LDCad's): a reference is a section of the
## file when its whole name, case aside and "\\" as "/", is one; else a
## part. Each reference of [param text] that rule finds a section for in
## [param whole], not found so in [param text] or found with other lines:
## "" for none.
static func _ldraw_unlike(text: String, whole: String) -> String:
	var mine: Dictionary = _by_whole_name(text)
	var theirs: Dictionary = _by_whole_name(whole)
	var unlike: Array[String] = []
	for section: String in mine:
		for line: String in mine[section]:
			var fields: PackedStringArray = LdrModel._fields(line.strip_edges())
			if fields.size() < 15 or fields[0] != "1":
				continue
			var named: String = _whole_name(" ".join(fields.slice(14)))
			if theirs.has(named) and (not mine.has(named) or mine[named] != theirs[named]) \
					and not unlike.has(named):
				unlike.append(named)
	return ", ".join(unlike.slice(0, 4))


## Each FILE section of [param text] by its whole name ([method _whole_name]),
## the first of a name as LDView takes it: its lines but FILE and NOFILE,
## blank ones at its end left off; a text of no FILE line, "" its lines.
static func _by_whole_name(text: String) -> Dictionary:
	var out: Dictionary = {}
	var current: String = ""
	var lines: Array = []
	var any: bool = false
	var reading: bool = true
	for line: String in text.split("\n"):
		var word: String = LdrModel.section_word(line)
		if word == "FILE":
			if reading and (any or not lines.is_empty()):
				_keep_section(out, current, lines)
			current = _whole_name(" ".join(LdrModel._fields(line.strip_edges()).slice(2)))
			lines = []
			any = true
			reading = true
			continue
		if word == "NOFILE" or word == "!DATA":
			if reading:
				_keep_section(out, current, lines)
			reading = false
			lines = []
			continue
		if reading:
			lines.append(line)
	if reading:
		_keep_section(out, current, lines)
	return out


## A name as LDraw's rule reads it: lowercase, "\\" as "/".
static func _whole_name(name: String) -> String:
	return name.replace("\\", "/").strip_edges().to_lower()


static func _keep_section(out: Dictionary, name: String, lines: Array) -> void:
	while not lines.is_empty() and str(lines.back()).strip_edges().is_empty():
		lines.pop_back()
	if not out.has(name):
		out[name] = lines.duplicate()


## Why a zip entry is not a name every system takes, or "": a folder, the
## folder above, a dot first (hidden), a control character, what Windows
## refuses or keeps, a dot or space at the end of it or of its stem, more
## than 200 UTF-8 bytes, not .ldr or .mpd.
static func _unsafe(name: String) -> String:
	if name.contains("/") or name.contains("\\"):
		return "a folder in it"
	if name.begins_with("."):
		return "a dot first"
	for n: int in name.length():
		var code: int = name.unicode_at(n)
		if code < 32 or (code >= 127 and code < 160):
			return "a control character"
	for refused: String in ["<", ">", ":", "\"", "|", "?", "*"]:
		if name.contains(refused):
			return "Windows refuses " + refused
	var stem: String = name.get_basename()
	if name.ends_with(".") or name.ends_with(" ") or stem.ends_with(".") or stem.ends_with(" "):
		return "a dot or a space at its end"
	var device: String = name.get_slice(".", 0).strip_edges().to_upper()
	if device in ["CON", "PRN", "AUX", "NUL"] or (device.length() == 4
			and device.left(3) in ["COM", "LPT"] and "0123456789¹²³".contains(device.right(1))):
		return "Windows keeps " + device
	if name.to_utf8_buffer().size() > 200:
		return "%d bytes" % name.to_utf8_buffer().size()
	if not name.get_extension() in ["ldr", "mpd"]:
		return "not .ldr or .mpd"
	return ""


## [param name] shown in a line: its control characters escaped, a long one
## cut.
static func _shown(name: String) -> String:
	var out: String = name.c_escape()
	return out if out.length() <= 40 else "%s… (%d bytes)" % [out.left(24), name.to_utf8_buffer().size()]


## A zip's members, how many of them its own headers and its directory flag
## as named in UTF-8 (bit 11), and how many the directory says were made on
## Unix (unzip reads a name made on MS-DOS as code page 437, bit 11 or
## not), read from its bytes: [members, own, directory, Unix].
static func _utf8_flags(path: String) -> Array:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var own: int = 0
	var at: int = 0
	while at + 30 <= bytes.size() and bytes.decode_u32(at) == 0x04034b50:
		if bytes.decode_u16(at + 6) & 0x0800:
			own += 1
		at += 30 + bytes.decode_u16(at + 26) + bytes.decode_u16(at + 28) + bytes.decode_u32(at + 18)
	var listed: int = 0
	var unix: int = 0
	var members: int = 0
	if bytes.size() >= 22 and bytes.decode_u32(bytes.size() - 22) == 0x06054b50:
		members = bytes.decode_u16(bytes.size() - 22 + 10)
		at = bytes.decode_u32(bytes.size() - 22 + 16)
		for _n: int in members:
			if at + 46 > bytes.size() or bytes.decode_u32(at) != 0x02014b50:
				break
			if bytes.decode_u16(at + 8) & 0x0800:
				listed += 1
			if bytes.decode_u16(at + 4) >> 8 == 3:
				unix += 1
			at += 46 + bytes.decode_u16(at + 28) + bytes.decode_u16(at + 30) + bytes.decode_u16(at + 32)
	return [members, own, listed, unix]


func _touch(at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _finger_drag(at: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _as_event(at)
	Input.parse_input_event(drag)


# -- the file, line by line --------------------------------------------------------


## Each section of [param text] the whole file's section of that name, line
## for line, but for FILE and NOFILE (a plain .ldr has neither) and the
## model's own line saying whose its steps are; a copy built in its parent's
## steps, its lines as the whole file has them, in its order.
func _same_lines(tag: String, file: String, text: String, whole: String, parsed: LdrModel,
		placed: Array[LdrModel.Placement], path: String) -> bool:
	var whole_sections: Dictionary = _sections(whole)
	var own: Dictionary = _sections(text)
	var marker: String = ""
	for line: String in whole.split("\n"):
		if line.strip_edges() == LdrModel.AUTHORED_META or line.strip_edges() == LdrModel.WORKED_META:
			marker = line.strip_edges()
			break
	var differ: Array[String] = []
	var built_within: bool = int(parsed.unit_steps[path]) == LdrModel.IN_PARENT
	var keys: Array = own.keys()
	for key: String in keys:
		if built_within and key == str(own.keys()[0]):
			continue
		if not whole_sections.has(key):
			differ.append("%s: no such section in the whole file" % key)
			continue
		var mine: Array = (own[key] as Array).filter(func(line: String) -> bool:
			return line.strip_edges() != marker or marker.is_empty())
		var theirs: Array = whole_sections[key]
		if mine != theirs:
			var at: int = 0
			while at < mini(mine.size(), theirs.size()) and mine[at] == theirs[at]:
				at += 1
			differ.append("%s line %d: %s / %s" % [key, at + 1,
				str(mine[at]).left(50) if at < mine.size() else "-",
				str(theirs[at]).left(50) if at < theirs.size() else "-"])
	var first: Array = own[keys[0]]
	var marked: bool = marker.is_empty() or first.any(func(line: String) -> bool:
		return line.strip_edges() == marker)
	if built_within:
		# Its parts' lines and its own copies' references, in the whole
		# file's order.
		var home: String = path
		while not home.is_empty() and int(parsed.unit_steps.get(home, 0)) == LdrModel.IN_PARENT:
			home = Assemblies.parent_of(home)
		var lines: PackedStringArray = whole.split("\n")
		var wanted: Dictionary = {}
		for placement: LdrModel.Placement in placed:
			if Assemblies.within(placement.unit, path) and _home_of(parsed, placement.unit) == home:
				wanted[placement.line] = true
		for unit: String in parsed.unit_lines:
			if unit != path and Assemblies.within(unit, path) \
					and int(parsed.unit_steps.get(unit, 0)) != LdrModel.IN_PARENT \
					and _home_of(parsed, Assemblies.parent_of(unit)) == home:
				wanted[int(parsed.unit_lines[unit])] = true
		var order: Array = wanted.keys()
		order.sort()
		var theirs: Array = order.map(func(n: int) -> String: return lines[n])
		var mine: Array = (first as Array).filter(func(line: String) -> bool:
			return line.strip_edges().begins_with("1"))
		if mine != theirs:
			differ.append("its parts' lines: %d here, %d in the whole file" % [mine.size(),
				theirs.size()])
	var ok: bool = differ.is_empty() and marked
	if not ok:
		_check("%s/%s: its lines the whole file's (%s%s)" % [tag, file, "; ".join(differ.slice(0, 2)),
			"" if marked else "; without the model's %s" % marker], false)
	return ok


static func _home_of(parsed: LdrModel, unit: String) -> String:
	var home: String = unit
	while not home.is_empty() and int(parsed.unit_steps.get(home, 0)) == LdrModel.IN_PARENT:
		home = Assemblies.parent_of(home)
	return home


## Each FILE section of [param text], key -> its lines but FILE and NOFILE;
## a text without any, its lines under its first line's title as key.
static func _sections(text: String) -> Dictionary:
	var out: Dictionary = {}
	var current: String = ""
	var any: bool = false
	for line: String in text.split("\n"):
		var word: String = LdrModel.section_word(line)
		if word == "FILE":
			current = LdrModel._key(" ".join(LdrModel._fields(line.strip_edges()).slice(2)))
			out[current] = []
			any = true
			continue
		if word == "NOFILE" or word == "!DATA":
			current = ""
			continue
		if not any and current.is_empty():
			current = "\n"
			out[current] = []
		if not current.is_empty():
			(out[current] as Array).append(line)
	if out.has("\n"):
		# A plain .ldr: keyed as its Name line names it.
		var lines: Array = out["\n"]
		out.erase("\n")
		var key: String = "\n"
		for line: String in lines:
			if line.strip_edges().begins_with("0 Name:"):
				key = LdrModel._key(line.strip_edges().substr(7))
				break
		while not lines.is_empty() and str(lines.back()).strip_edges().is_empty():
			lines.pop_back()
		out[key] = lines
	for key: String in out:
		var lines: Array = out[key]
		while not lines.is_empty() and str(lines.back()).strip_edges().is_empty():
			lines.pop_back()
	return out


# -- the file opened alone -----------------------------------------------------------


## [param text] opened alone in the app: every part of the sub-model at
## [param path] there, in its colour, where the whole model has it in its
## own frame within NEAR, and no other; its tree the sub-model's own, by
## [method _numbered_alone]; an author's steps still the author's. [ok, the
## worst distance].
func _alone(tag: String, file: String, text: String, parsed: LdrModel, held: Array,
		path: String) -> Array:
	var home: String = _home_of(parsed, path)
	var frame: Transform3D = Transform3D.IDENTITY
	var built_within: bool = int(parsed.unit_steps[path]) == LdrModel.IN_PARENT
	if not built_within:
		frame = parsed.unit_frames[path]
	elif not home.is_empty():
		frame = parsed.unit_frames[home]
	var inverse: Transform3D = frame.affine_inverse()
	var wanted: Array = []
	for one: Array in held:
		if Assemblies.within(str(one[0]), path):
			wanted.append([one[1], one[2], inverse * (one[3] as Transform3D)])
	var tree_wanted := PackedStringArray()
	for unit: String in parsed.unit_steps:
		if unit != path and Assemblies.within(unit, path):
			tree_wanted.append(unit.substr(path.length() + 1))
	tree_wanted = _numbered_alone(tree_wanted)
	tree_wanted.sort()
	await _open(text, file.get_basename())
	var back := Transform3D(Basis.IDENTITY, -(_store.call("_lift_now") as Vector3))
	var got: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			got.append([brick.part_id, brick.color_code, back * brick.transform])
	var worst: float = 0.0
	var unmatched: int = 0
	var colour_off: int = 0
	var taken: Dictionary = {}
	for want: Array in wanted:
		var best: int = -1
		var best_far: float = INF
		for n: int in got.size():
			if taken.has(n) or str(got[n][0]) != str(want[0]):
				continue
			var far: float = _apart(got[n][2], want[2])
			if far < best_far:
				best_far = far
				best = n
		if best < 0 or best_far > NEAR:
			if unmatched == 0:
				print("    not there: %s in %d at %s (nearest of that part %.4f LDU)" % [want[0],
					int(want[1]), (want[2] as Transform3D).origin, best_far])
			unmatched += 1
			continue
		taken[best] = true
		worst = maxf(worst, best_far)
		if int(got[best][1]) != int(want[1]):
			colour_off += 1
	var tree_got: PackedStringArray = _numbered_alone(_shell.assemblies.paths())
	tree_got.sort()
	var authored: bool = AuthorSteps.any(_world, _store.scenery)
	var marked: bool = text.contains(LdrModel.AUTHORED_META) or (not text.contains(LdrModel.WORKED_META)
		and LdrModel.parse(text, file).steps_are_authored())
	var steps_ok: bool = authored == marked
	var steps_said: String = ""
	if marked and authored:
		var again: String = _store.to_text(file.get_basename(), true)
		steps_ok = _steps_of(again) == _steps_of(text)
		steps_said = ", its %d steps the author's, written again step for step" % _steps_of(text).size()
	var ok: bool = unmatched == 0 and colour_off == 0 and got.size() == wanted.size() \
		and tree_got == tree_wanted and steps_ok
	if true:
		_check("%s/%s opened alone: %d of %d parts where the whole model has them (worst %.6f LDU), "
			% [tag, file, wanted.size() - unmatched, wanted.size(), worst]
			+ "%d in another colour, %d on the baseplate; its tree %s%s" % [colour_off, got.size(),
				"its own (%d)" % tree_got.size() if tree_got == tree_wanted
				else "%s, not %s" % [tree_got, tree_wanted], steps_said if steps_ok
				else ", its author's steps %s" % ("lost" if marked else "made up")], ok)
	return [ok, worst]


## [param paths] with each sub-model's copies numbered from 1, in the order
## of their numbers: the tree's shape, its copies' numbers left out. Copies
## are numbered across the whole model (Assemblies), so Other's copy of Dup
## is Dup#2 there, after the main model's Dup#1, and Dup#1 in Other's file
## alone; a file the app wrote says each copy's number (COPY_META), which
## its file alone keeps where it is free. Both trees are compared so: the
## same sub-models, nested alike, as many copies of each, in that order.
static func _numbered_alone(paths: PackedStringArray) -> PackedStringArray:
	var numbers: Dictionary = {}     ## a sub-model -> its copies' numbers in [param paths]
	for unit: String in paths:
		for segment: String in Assemblies.segments(unit):
			var kind: String = Assemblies.definition(segment)
			var seen: Array = numbers.get(kind, [])
			if not seen.has(Assemblies.copy_of(segment)):
				seen.append(Assemblies.copy_of(segment))
			numbers[kind] = seen
	for kind: String in numbers:
		(numbers[kind] as Array).sort()
	var out := PackedStringArray()
	for unit: String in paths:
		var segments := PackedStringArray()
		for segment: String in Assemblies.segments(unit):
			var kind: String = Assemblies.definition(segment)
			segments.append("%s#%d" % [kind, (numbers[kind] as Array).find(Assemblies.copy_of(segment)) + 1])
		out.append("/".join(segments))
	return out


## The parts of each step of [param text]'s own model, each "part colour"
## sorted, step by step, its sub-models' sections left out.
static func _steps_of(text: String) -> Array:
	var steps: Array = [[]]
	var any_file: bool = false
	for line: String in text.split("\n"):
		var word: String = LdrModel.section_word(line)
		if word == "FILE":
			if any_file:
				break
			any_file = true
			continue
		if word == "NOFILE":
			break
		var fields: PackedStringArray = LdrModel._fields(line.strip_edges())
		if fields.size() >= 2 and fields[0] == "0" and (fields[1] == "STEP" or fields[1] == "ROTSTEP"):
			if not (steps.back() as Array).is_empty():
				steps.append([])
			continue
		if fields.size() >= 15 and fields[0] == "1":
			(steps.back() as Array).append("%s %s" % [fields[1], " ".join(fields.slice(14))])
	if (steps.back() as Array).is_empty():
		steps.pop_back()
	for step: Array in steps:
		step.sort()
	return steps


static func _apart(a: Transform3D, b: Transform3D) -> float:
	var far: float = a.origin.distance_to(b.origin)
	for axis: int in 3:
		far = maxf(far, (a.basis[axis] - b.basis[axis]).length())
	return far


# -- the ways in ---------------------------------------------------------------------


## File › Export › LDraw model, as its press writes it.
func _whole_export(tag: String) -> String:
	_clear_files()
	var said: String = await _bar.export_now(_files)
	var path: String = said.trim_prefix("wrote ").strip_edges()
	if not FileAccess.file_exists(path):
		_check("%s: File › Export › LDraw model wrote a file (%s)" % [tag, said], false)
		return ""
	return FileAccess.get_file_as_string(path)


## A right click on [param path]'s row in the model tree, its menu pictured,
## then Export as its own file…: the file written.
func _row_menu_one(tag: String, path: String) -> String:
	var outliner: Outliner = _shell.outliner
	if outliner == null or path.is_empty():
		_check("%s: the model tree is in the window" % tag, false)
		return ""
	var menu: PopupMenu = null
	for size: Vector2i in SIZES:
		if root.size != size:
			root.size = size
			await _frames(30)
		await _show_tree()
		_clear_files()
		menu = await _right_click_row(outliner, path)
		if menu == null:
			_check("%s at %dx%d: a right click on %s's row opens a menu" % [tag, size.x, size.y,
				Assemblies.label(path)], false)
			return ""
		var rows: Array[String] = []
		for n: int in menu.item_count:
			rows.append(menu.get_item_text(n))
		var inside: bool = Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(
			Rect2(Vector2(menu.position), Vector2(menu.size)))
		_check("%s at %dx%d: a right click on %s's row opens its menu, in the window: %s" % [tag,
			size.x, size.y, Assemblies.label(path), " | ".join(rows)], rows.size() == 2
			and rows[0] == "Export “%s” as its own file…" % Assemblies.label(path) and inside)
		await _shot("%s_menu_%dx%d" % [tag, size.x, size.y])
		if size != SIZES.back():
			menu.hide()
			await _frames(4)
	menu.id_pressed.emit(menu.get_item_id(0))
	menu.hide()
	await _until_file(["ldr", "mpd"])
	if root.size != SIZES[0]:
		root.size = SIZES[0]
		await _frames(20)
	var written: String = _newest("ldr") if not _newest("ldr").is_empty() else _newest("mpd")
	return FileAccess.get_file_as_string(written) if not written.is_empty() else ""


## The model's row's menu, Export each sub-model (.zip)…: its files.
func _row_menu_each() -> Dictionary:
	var outliner: Outliner = _shell.outliner
	if outliner == null:
		return {}
	await _show_tree()
	_clear_files()
	var menu: PopupMenu = await _right_click_row(outliner, "")
	if menu == null:
		return {}
	menu.id_pressed.emit(menu.get_item_id(menu.item_count - 1))
	menu.hide()
	await _until_file(["zip"])
	return _zip_members(_newest("zip"))


## File › Export › Each sub-model as its own file (.zip): its row there, and
## its press.
func _file_export_each() -> Dictionary:
	_clear_files()
	var listed: bool = (Shell.SUBMENUS["export"] as Array).has("export_submodels")
	if not _check("File › Export lists Each sub-model as its own file (.zip), and it can be pressed",
			listed and _shell.can("export_submodels")):
		return {}
	_shell.run("export_submodels")
	await _until_file(["zip"])
	return _zip_members(_newest("zip"))


## The model tree in sight and open: the right column out by its rail where
## it is folded, as a person opens it.
func _show_tree() -> void:
	var dock: Variant = _main.get("_props_dock")
	if dock is SideDock and not (dock as SideDock).is_open():
		var at: Vector2 = _as_event((dock as SideDock).rail().get_global_rect().get_center())
		for down: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			event.position = at.floor()
			event.global_position = event.position
			Input.parse_input_event(event)
			await _frames(2)
		await _frames(20)
		await create_timer(SideDock.SLIDE_SECONDS + 0.1).timeout
	if not _shell.outliner.is_open():
		_shell.outliner.set_open(true)
	await _frames(10)
	if not _shell.outliner.is_visible_in_tree():
		var hidden: Array[String] = []
		var at: Node = _shell.outliner
		while at != null and at != root:
			if at is CanvasItem and not (at as CanvasItem).visible:
				hidden.append("%s (%s)" % [at.name, at.get_class()])
			at = at.get_parent()
		var chat: Variant = _main.get("_chat_dock")
		print("    the model tree out of sight: the right column %s, the assistant's %s; hidden: %s"
			% ["open" if dock is SideDock and (dock as SideDock).is_open() else "folded",
			"open" if chat is SideDock and (chat as SideDock).is_open() else "folded",
			", ".join(hidden)])


func _right_click_row(outliner: Outliner, path: String) -> PopupMenu:
	var rects: Dictionary = await _row_in_sight(outliner, path)
	if not rects.has(path):
		print("    no row for %s among %d in sight (the tree %s, in the window %s)" % [path,
			rects.size(), "open" if outliner.is_open() else "folded", outliner.is_visible_in_tree()])
		return null
	# Where the row stays: a window just resized lays the column out again
	# over a few frames, and the row measured first was another's by the
	# click (east curtain wall's, at 1280 x 720).
	var held: int = 0
	var last: Rect2 = rects[path]
	for _n: int in 120:
		await _frames(1)
		rects = outliner.row_rects()
		if not rects.has(path):
			rects = await _row_in_sight(outliner, path)
			if not rects.has(path):
				return null
		held = held + 1 if (rects[path] as Rect2).is_equal_approx(last) else 0
		last = rects[path]
		if held >= 8:
			break
	var at: Vector2 = last.get_center()
	# The row's place as the tree says it, and the row its own click finds
	# there: until 2026-11-08 a scrolled tree's rows were said a scroll too
	# high, and the click chose a row above.
	var tree_at: Tree = outliner.get("_tree")
	var found: TreeItem = tree_at.get_item_at_position(
		tree_at.get_global_transform_with_canvas().affine_inverse() * at) if tree_at != null else null
	_check("the tree says %s's row is where its click finds it (scrolled %d px)" % [
		"the model" if path.is_empty() else Assemblies.label(path), roundi(tree_at.get_scroll().y)
		if tree_at != null else 0], found != null and str(found.get_metadata(0)) == path)
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = down
		event.position = _as_event(at).floor()
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(6)
	var menu: Variant = outliner.get("row_menu")
	var tree: Tree = outliner.get("_tree")
	var chosen: TreeItem = tree.get_selected() if tree != null else null
	_check("the right click chose %s's row, as a file manager does" % Assemblies.label(path)
		if not path.is_empty() else "the right click chose the model's row",
		chosen != null and str(chosen.get_metadata(0)) == path)
	return menu if menu is PopupMenu and (menu as PopupMenu).visible else null


## [param path]'s row in sight, the tree scrolled to it with the wheel over it
## as a person scrolls: up to its top, then down a notch at a time.
func _row_in_sight(outliner: Outliner, path: String) -> Dictionary:
	var rects: Dictionary = outliner.row_rects()
	for _n: int in 10:
		if rects.has(path):
			return rects
		await _frames(2)
		rects = outliner.row_rects()
	var tree: Tree = outliner.get("_tree")
	if tree == null or not tree.is_visible_in_tree():
		return rects
	var over: Vector2 = _as_event(tree.get_global_rect().get_center())
	for wheel: MouseButton in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		for _n: int in 40 if wheel == MOUSE_BUTTON_WHEEL_UP else 120:
			if rects.has(path):
				return rects
			var before: float = tree.get_scroll().y
			for down: bool in [true, false]:
				var event := InputEventMouseButton.new()
				event.button_index = wheel
				event.pressed = down
				event.factor = 1.0
				event.position = over
				event.global_position = over
				Input.parse_input_event(event)
			await _frames(2)
			rects = outliner.row_rects()
			if is_equal_approx(before, tree.get_scroll().y):
				break
	return rects


## The first row of the tree [param named] names: its definition's first
## copy, outermost first.
static func _path_named(named: String, tree: PackedStringArray) -> String:
	for path: String in tree:
		if Assemblies.definition(Assemblies.leaf(path)) == named:
			return path
	return ""


# -- files ----------------------------------------------------------------------


func _clear_files() -> void:
	for name: String in DirAccess.get_files_at(_files):
		DirAccess.remove_absolute(_files.path_join(name))


func _newest(extension: String) -> String:
	var best: String = ""
	var best_at: int = -1
	for name: String in DirAccess.get_files_at(_files):
		if name.get_extension().to_lower() != extension:
			continue
		var at: int = FileAccess.get_modified_time(_files.path_join(name))
		if at >= best_at:
			best_at = at
			best = _files.path_join(name)
	return best


func _until_file(extensions: Array) -> void:
	for _n: int in 1200:
		for extension: String in extensions:
			if not _newest(extension).is_empty():
				await _frames(10)
				return
		await process_frame


## A .zip's files: name -> text.
static func _zip_members(path: String) -> Dictionary:
	var out: Dictionary = {}
	if path.is_empty():
		return out
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return out
	for name: String in reader.get_files():
		out[name] = reader.read_file(name).get_string_from_utf8()
	reader.close()
	return out


# -- the app -------------------------------------------------------------------------


func _open(text: String, name: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var opened: Dictionary = await _bar.open_text_with_progress(text, name)
	_bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return "\n".join(lines)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	# No window to scale to without one.
	if window.x <= 0.0 or window.y <= 0.0 or DisplayServer.get_name() == "headless":
		return at
	return at * (window / rect)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	# No frame is drawn without a window, and frame_post_draw never comes.
	if DisplayServer.get_name() == "headless":
		return
	await _frames(10)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	if image != null and image.save_png(path) == OK:
		print("    picture: %s" % path)


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("")
	if _failures == 0:
		print("subexport probe: each sub-model a file of its own, its lines the whole model's, "
			+ "opened alone to the same parts")
	else:
		print("subexport probe: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
