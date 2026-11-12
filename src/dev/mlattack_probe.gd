## mlcheck's attack on the app's own lines (mlcheck, fixed by mlfix): two
## lines the same, the first read and the second not; lines no reader read,
## through every edit, of the person's own model and of someone else's;
## each feature edited alone; a step's look lines it cannot read through
## edits; and 66 files of other programs and by hand saved unedited, byte for
## byte (src/dev/fixtures/mlattack). Every save copied to MLA_OUT for a byte
## diff by the file's readers.
##   tools/probe.sh mlattack_probe
##   MLA_CASES=dupsame,dups,unread,features,badlooks,files   MLA_OUT=/abs/dir
##   MLA_FILES=/abs/dir (default the fixtures)   MLA_AUTHORS=own   MLA_EDITS=move,make
extends SceneTree

const MODELS := "user://models/"
const WATCHDOG := 3000.0

const HEAD_THEIRS := "0 FILE main.ldr\n0 Attack model\n0 Name: main.ldr\n0 Author: %s\n"
const A_VIEW := "0 !BRICKWORKS VIEW {\"distance\":400,\"focus\":[0,0,0],\"name\":\"A\",\"pitch\":-25,\"yaw\":30}"
const ORBIT := "0 !BRICKWORKS VIEW {\"name\":\"orbit\",\"path\":[[0,0,0],[40,0,0]],\"kind\":\"orbit\",\"speed\":2}"
const B_VIEW := "0 !BRICKWORKS VIEW {\"distance\":300,\"focus\":[0,0,0],\"name\":\"B\",\"pitch\":-10,\"yaw\":90}"
const A2_VIEW := "0 !BRICKWORKS VIEW {\"distance\":500,\"focus\":[0,0,0],\"name\":\"A\",\"pitch\":-40,\"yaw\":200}"
const SPOT := "0 !BRICKWORKS LIGHT {\"aim\":[0,1,0],\"at\":[0,-200,0],\"colour\":\"#ffffff\",\"cone\":30,\"kind\":\"spot\",\"shadows\":true,\"size\":4,\"strength\":1}"
const LASER := "0 !BRICKWORKS LIGHT {\"kind\":\"laser\",\"at\":[0,-200,0]}"
const FUTURE := "0 !BRICKWORKS FUTURE_KIND one two"
const SPRING := "0 !BRICKWORKS MOTION_KEY \"Lift\" 1 1 45 SPRING"
const MOTION := "0 !BRICKWORKS MOTION \"Lift\" AFTER \"\" SECONDS 2\n0 !BRICKWORKS MOTION_TRACK \"Lift\" 1 TURN AT 0 JOINT PART 3004 14 0 -48 0\n0 !BRICKWORKS MOTION_KEY \"Lift\" 1 0 0 EASE\n" + SPRING + "\n0 !BRICKWORKS MOTION_KEY \"Lift\" 1 2 90 EASE"
const SUBVIEW := "0 !BRICKWORKS VIEW {\"distance\":200,\"focus\":[0,0,0],\"name\":\"subview\",\"pitch\":-10,\"yaw\":45}"
const CUT1 := "0 !BRICKWORKS CUT_AWAY {\"at\":11.0,\"away\":1,\"axis\":\"x\",\"ghosts\":false,\"shape\":\"plane\"}"
const CUT2 := "0 !BRICKWORKS CUT_AWAY {\"at\":20.0,\"away\":1,\"axis\":\"z\",\"ghosts\":false,\"shape\":\"plane\"}"
const HID1 := "0 !BRICKWORKS HIDDEN_COLOURS {\"groups\":[{\"also\":[],\"colour\":4,\"label\":\"base\",\"sections\":[\"base\"]}],\"mode\":\"sections\"}"
const HID2 := "0 !BRICKWORKS HIDDEN_COLOURS {\"groups\":[{\"also\":[],\"colour\":2,\"label\":\"top\",\"sections\":[\"top\"]}],\"mode\":\"sections\"}"
const SHARE1 := "0 !BRICKWORKS SHARE abc123shar"
const SHARE2 := "0 !BRICKWORKS SHARE zzz999shar"
const PARTS := "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 14 0 -48 0 1 0 0 0 1 0 0 0 1 3004.dat\n1 2 80 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 1 160 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n1 16 0 -24 80 1 0 0 0 1 0 0 0 1 sub.ldr\n0 STEP\n0 NOFILE\n"
const SUB := "0 FILE sub.ldr\n0 Sub\n0 Name: sub.ldr\n0 Author: %s\n" + SUBVIEW + "\n1 14 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat\n1 15 40 0 0 1 0 0 0 1 0 0 0 1 3003.dat\n0 NOFILE\n"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _socket: CommandSocket
var _rpc_id: int = 0
var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(WATCHDOG * 2.0).timeout.connect(func() -> void:
		print("mlattack probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_out = OS.get_environment("MLA_OUT")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELS))
	print("BUILD has MetaIndex: %s" % ResourceLoader.exists("res://src/parts/meta_index.gd"))
	var cases: Array = ["dupsame", "dups", "unread", "features", "badlooks", "files"] \
		if OS.get_environment("MLA_CASES").is_empty() \
		else Array(OS.get_environment("MLA_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		var before: int = _failures
		match name:
			"dupsame": await _case_dupsame()
			"regrow": await _case_regrow()
			"dups": await _case_dups()
			"unread": await _case_unread()
			"features": await _case_features()
			"badlooks": await _case_badlooks()
			"files": await _case_files()
			_: _check("no such case %s" % name, false)
		print("CASE %s: %s" % [name, "green" if _failures == before
			else "red, %d failed" % (_failures - before)])
	print("\nmlattack probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


static func _base(author: String, extra: String) -> String:
	return HEAD_THEIRS % author + "0 !BRICKWORKS FLOOR BASEPLATE 32 32 2\n" + A_VIEW + "\n" \
		+ ORBIT + "\n" + B_VIEW + "\n" + SPOT + "\n" + LASER + "\n" + FUTURE + "\n" + MOTION \
		+ "\n" + extra + PARTS + SUB % author


# -- regrow: a light the two readers place apart, saved three times ---------------


func _case_regrow() -> void:
	var dir: String = OS.get_environment("MLA_FILES")
	for name: String in ["h_after_nofile.mpd", "h_lower_words.ldr"]:
		var text: String = FileAccess.get_file_as_string(dir.path_join(name))
		var counts := PackedStringArray()
		for round: int in 3:
			await _open("mla_regrow_%s_%d" % [name.get_basename(), round], text)
			var lights: int = _world.scene_lights.size()
			text = await _bar_save("regrow_%s_%d" % [name.get_basename(), round])
			counts.append("open %d: %d lights, saved with %d LIGHT lines" % [round, lights,
				text.countn("BRICKWORKS LIGHT")])
		print("  %s: %s" % [name, "; ".join(counts)])
		_check("%s: three saves keep the file's one light line (%s)" % [name, counts[2]],
			text.countn("BRICKWORKS LIGHT") == 1)


# -- dupsame: two identical lines, the value changed -------------------------------


func _case_dupsame() -> void:
	for author: String in ["Someone Else", "Brickworks"]:
		var tag: String = "theirs" if author != "Brickworks" else "own"
		var floor2: String = "0 !BRICKWORKS FLOOR GRID\n0 !BRICKWORKS FLOOR GRID\n"
		var text: String = HEAD_THEIRS % author + floor2 + A_VIEW + "\n" + A_VIEW + "\n" \
			+ PARTS + SUB % author
		await _open("mla_dupsame_floor_" + tag, text)
		print("  %s floor read: %s" % [tag, _store.model_floor.to_meta()])
		print("  set_floor: %s" % (await _say("set_floor", {"kind": "baseplate", "across": 16}))
			.get_slice("\n", 0).left(80))
		var saved: String = await _bar_save("dupsame_floor_%s" % tag)
		await _open("mla_dupsame_floor_%s_again" % tag, saved)
		_check("%s: two FLOOR GRID lines, the floor set to a baseplate and saved: reopened on it (%s)"
			% [tag, _store.model_floor.to_meta()], _store.model_floor.to_meta().contains("BASEPLATE 16"))
		await _open("mla_dupsame_view_" + tag, text)
		var views: Array = _world.saved_views.duplicate(true)
		print("  %s views read: %d" % [tag, views.size()])
		if not views.is_empty():
			views[0]["yaw"] = 123.0
		_world.saved_views = views
		saved = await _bar_save("dupsame_view_%s" % tag)
		await _open("mla_dupsame_view_%s_again" % tag, saved)
		var yaw: float = float(_world.saved_views[0].get("yaw", 0.0)) if not _world.saved_views.is_empty() else -1.0
		_check("%s: two identical views A, A turned and saved: reopened turned (yaw %.1f)" % [tag, yaw],
			absf(yaw - 123.0) < 0.01)
	# Someone else's file a live save gave two TITLE lines: renamed.
	var titled: String = "0 FILE main.ldr\n0 !BRICKWORKS TITLE Old name\n0 Attack model\n0 Name: main.ldr\n" \
		+ "0 Author: Someone Else\n0 !BRICKWORKS TITLE Old name\n" + PARTS + SUB % "Someone Else"
	await _open("mla_dupsame_title", titled)
	print("  title read: %s" % _store.title)
	_store.save_as("New name")
	await _frames(6)
	var bar: ModelBar = _main.get("_bar")
	var named: String = _text_kept(MODELS + bar.model_name() + ".ldr")
	_keep("dupsame_title_saved_as.ldr", named)
	await _open("mla_dupsame_title_again", named)
	_check("two TITLE lines, Save As \"New name\": reopened as it (%s)" % _store.title,
		_store.title == "New name")


# -- dups: two lines saying one thing, the family emptied --------------------------


func _case_dups() -> void:
	for author: String in ["Someone Else", "Brickworks"]:
		var tag: String = "theirs" if author != "Brickworks" else "own"
		# Two views named A: all views deleted.
		await _open("mla_dupview_" + tag, _base(author, A2_VIEW + "\n"))
		print("  %s dup views read: %d" % [tag, _world.saved_views.size()])
		_world.saved_views = []
		var saved: String = await _bar_save("dupview_%s" % tag)
		await _open("mla_dupview_%s_again" % tag, saved)
		_check("%s: every view deleted and saved: none comes back on reopen (%d: %s)" % [tag,
			_world.saved_views.size(), _view_names()], _world.saved_views.is_empty())
		# Two cuts: the cut cleared.
		await _open("mla_dupcut_" + tag, _base(author, CUT1 + "\n" + CUT2 + "\n"))
		print("  %s dup cut read: %s" % [tag, JSON.stringify(_world.cut_kept)])
		_world.cut_kept = {}
		saved = await _bar_save("dupcut_%s" % tag)
		await _open("mla_dupcut_%s_again" % tag, saved)
		_check("%s: the cut cleared and saved: none on reopen (%s)" % [tag,
			JSON.stringify(_world.cut_kept)], _world.cut_kept.is_empty())
		# Two hidden-colour schemes: cleared.
		await _open("mla_duphid_" + tag, _base(author, HID1 + "\n" + HID2 + "\n"))
		print("  %s dup hidden read: %s" % [tag, JSON.stringify(_store.hidden_scheme).left(80)])
		_store.hidden_scheme = {}
		saved = await _bar_save("duphid_%s" % tag)
		await _open("mla_duphid_%s_again" % tag, saved)
		_check("%s: hidden colours cleared and saved: none on reopen (%s)" % [tag,
			JSON.stringify(_store.hidden_scheme).left(80)],
			(_store.hidden_scheme.get("groups", []) as Array).is_empty())
		# Two share links: unshared.
		await _open("mla_dupshare_" + tag, _base(author, SHARE1 + "\n" + SHARE2 + "\n"))
		print("  %s dup share read: %s" % [tag, _store.share_id])
		_store.share_id = ""
		saved = await _bar_save("dupshare_%s" % tag)
		await _open("mla_dupshare_%s_again" % tag, saved)
		_check("%s: the link cleared and saved: none on reopen (\"%s\")" % [tag, _store.share_id],
			_store.share_id.is_empty())
		# One view, the last, deleted: its line goes and only its line.
		var one: String = HEAD_THEIRS % author + A_VIEW + "\n" + PARTS + SUB % author
		await _open("mla_lastview_" + tag, one)
		_world.saved_views = []
		saved = await _bar_save("lastview_%s" % tag)
		_check("%s: the last view deleted: its line gone, the sub-model's kept (%d, %d)" % [tag,
			saved.count("\"name\":\"A\""), saved.count("subview")], saved.count("\"name\":\"A\"") == 0
			and saved.count("subview") == 1)
		_check("%s: ...and only its line (%s)" % [tag, _first_unlike(one.replace(A_VIEW + "\n", ""),
			saved)], tag == "own" or saved == one.replace(A_VIEW + "\n", ""))


# -- unread: lines no reader reads, through every kind of edit ----------------------


func _case_unread() -> void:
	var authors: Array = ["Someone Else", "Brickworks"]
	if OS.get_environment("MLA_AUTHORS") == "own":
		authors = ["Brickworks"]
	for author: String in authors:
		var tag: String = "theirs" if author != "Brickworks" else "own"
		var text: String = _base(author, "")
		var edits: Array = ["none", "move", "ungroup", "make", "rename_sub", "paste",
				"delete_sub", "clear_undo", "undo_open", "save_as", "views_gone", "rename_model"]
		if not OS.get_environment("MLA_EDITS").is_empty():
			edits = Array(OS.get_environment("MLA_EDITS").split(",", false))
		for edit: String in edits:
			var name: String = "mla_unread_%s_%s" % [tag, edit]
			if edit == "undo_open":
				_store.keeps = true
			await _open(name, text)
			var said: String = await _edit(edit)
			print("    %s %s: %s" % [tag, edit, said.get_slice("\n", 0).left(110)])
			var saved: String
			if edit == "save_as":
				_store.save_as("Attack renamed " + tag)
				await _frames(6)
				var bar: ModelBar = _main.get("_bar")
				saved = _text_kept(MODELS + bar.model_name() + ".ldr")
				_keep("unread_%s_%s.ldr" % [tag, edit], saved)
			else:
				saved = await _bar_save("unread_%s_%s" % [tag, edit])
			_store.keeps = false
			var lines: PackedStringArray = saved.split("\n")
			var bad := PackedStringArray()
			for line: String in [ORBIT, LASER, FUTURE, SPRING]:
				if saved.count(line + "\n") != 1:
					bad.append("%s x%d" % [line.get_slice(" ", 2) + line.substr(14, 30), saved.count(line + "\n")])
			_check("%s %s: the 4 unread lines each kept once%s" % [tag, edit,
				"" if bad.is_empty() else " (" + ", ".join(bad) + ")"], bad.is_empty())
			var zero: int = _index_of(lines, "MOTION_KEY \"Lift\" 1 0 0 EASE")
			var spring: int = lines.find(SPRING)
			var ninety: int = _index_of(lines, "MOTION_KEY \"Lift\" 1 2 90 EASE")
			_check("%s %s: SPRING between its keys (%d < %d < %d)" % [tag, edit, zero, spring, ninety],
				zero >= 0 and zero < spring and spring < ninety)
			var a: int = _index_of(lines, "\"name\":\"A\"")
			var orbit: int = lines.find(ORBIT)
			var b: int = _index_of(lines, "\"name\":\"B\"")
			_check("%s %s: the orbit view between A and B (%d < %d < %d)" % [tag, edit, a, orbit, b],
				edit == "views_gone" or (a >= 0 and a < orbit and orbit < b))
			var file_at: int = -1
			for n: int in lines.size():
				if lines[n].begins_with("0 FILE ") and n > 0:
					file_at = n
					break
			_check("%s %s: unread lines in the model's own section (%d %d before FILE %d)" % [tag,
				edit, orbit, spring, file_at], file_at < 0 or (orbit < file_at and spring < file_at
				and lines.find(LASER) < file_at and lines.find(FUTURE) < file_at))
			await _reopen_same("unread_%s_%s" % [tag, edit], saved)


func _edit(edit: String) -> String:
	match edit:
		"none":
			return "nothing"
		"move":
			var id: int = _id_of_colour("3001", 1)
			return await _say("edit_model", {"move": [{"bricks": [id], "dz": 2}]})
		"ungroup":
			var path: String = _path_named("sub")
			return "ungrouped %s: %d" % [path, _shell.assemblies.ungroup(path)]
		"make":
			_select_ids([_id_of_colour("3001", 2), _id_of_colour("3001", 1)])
			var made: String = _shell.assemblies.make("Made group")
			_main.call("_on_model_edited")
			await _frames(6)
			return "made " + made
		"rename_sub":
			var path: String = _path_named("sub")
			var renamed: String = _shell.assemblies.rename(path, "Renamed sub")
			_main.call("_on_model_edited")
			await _frames(6)
			return "renamed %s: %s" % [path, renamed]
		"paste":
			_select_ids([_id_of_colour("3001", 2)])
			var copied: int = _builder.copy_selection()
			_builder.clear_selection()
			_builder.hold_copy(Carry.clipboard)
			var put: int = await _put_down()
			return "copied %d put %d" % [copied, put]
		"delete_sub":
			var path: String = _path_named("sub")
			var ids: Array = Array(_shell.assemblies.ids_under(path))
			_select_ids(ids)
			_shell.call("run", "delete")
			await _frames(10)
			return "deleted %s (%d parts)" % [path, ids.size()]
		"clear_undo":
			var said: String = await _say("clear_model", {})
			await _frames(4)
			var back: String = await _say("undo", {})
			await _frames(6)
			return said.get_slice("\n", 0).left(50) + " / " + back.get_slice("\n", 0).left(50)
		"undo_open":
			_put("mla_other", "0 Other\n0 Name: mla_other.ldr\n0 Author: Someone\n"
				+ "1 1 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
			await _say("open_model", {"name": "mla_other"})
			await _settled()
			var bar: ModelBar = _main.get("_bar")
			var back: bool = await bar.reopen()
			await _settled()
			return "reopened %s" % back
		"save_as":
			return "save as"
		"views_gone":
			_world.saved_views = []
			return "views deleted"
		"rename_model":
			_store.title = "Renamed model"
			return "title set"
	return "?"


# -- features: each edited once, only its lines change ------------------------------


func _case_features() -> void:
	for author: String in ["Someone Else", "Brickworks"]:
		var tag: String = "theirs" if author != "Brickworks" else "own"
		var text: String = _base(author, CUT1 + "\n" + HID1 + "\n" + SHARE1 + "\n"
			+ "0 !BRICKWORKS FROM_SET 6780-1\n")
		# Opened and saved once first: the app's own is written whole, and that
		# first save is the file each edit is compared with.
		await _open("mla_feat_%s_base" % tag, text)
		var base: String = await _bar_save("feat_%s_base" % tag)
		await _open("mla_feat_%s_base_again" % tag, base)
		var again: String = await _bar_save("feat_%s_base_again" % tag)
		_check("%s: the first save saved again unedited, byte for byte%s" % [tag,
			_first_unlike(base, again)], again == base)
		for edit: String in ["floor", "view", "light", "step_name", "page", "hidden", "cut", "set",
				"share", "pin_gone"]:
			await _open("mla_feat_%s_%s" % [tag, edit], base)
			var said: String = await _feature(edit)
			print("    %s %s: %s" % [tag, edit, said.get_slice("\n", 0).left(100)])
			var saved: String = await _bar_save("feat_%s_%s" % [tag, edit])
			var read: String = _readback()
			await _open("mla_feat_%s_%s_again" % [tag, edit], saved)
			var read_again: String = _readback()
			_check("%s %s: reopened, every feature reads back what was saved (%s)" % [tag, edit,
				"same" if read == read_again else read.left(200) + " | " + read_again.left(200)],
				read == read_again)
			var twice: String = await _bar_save("feat_%s_%s_again" % [tag, edit])
			_check("%s %s: saved again, byte for byte%s" % [tag, edit, _first_unlike(saved, twice)],
				twice == saved)


func _feature(edit: String) -> String:
	match edit:
		"floor":
			return await _say("set_floor", {"kind": "baseplate", "across": 16})
		"view":
			return await _say("save_view", {"name": "New view"})
		"light":
			return await _say("light_model", {"op": "add", "kind": "point"})
		"step_name":
			return await _say("edit_steps", {"op": "name", "step": 1, "name": "First named"})
		"page":
			return await _say("page_setup", {"size": "A5"})
		"hidden":
			_store.hidden_scheme = HiddenColours.typed(JSON.parse_string(HID2.substr(29)))
			return "hidden " + JSON.stringify(_store.hidden_scheme).left(60)
		"cut":
			_world.cut_kept = {"shape": "plane", "axis": "y", "at": 5.0, "away": -1, "ghosts": true}
			return "cut set"
		"set":
			_store.from_set = "10497-1"
			return "set"
		"share":
			_store.share_id = "qqq111shar"
			return "share"
		"pin_gone":
			_world.saved_views = _world.saved_views.slice(0, 1)
			return "views but the first deleted"
	return "?"


## What every feature holds, in words, to compare an open with the next.
func _readback() -> String:
	return JSON.stringify({"floor": _store.model_floor.to_meta() if _store.model_floor != null else "",
		"views": _view_names(), "lights": _world.scene_lights.size(),
		"cut": _world.cut_kept, "hidden": _store.hidden_scheme, "share": _store.share_id,
		"set": _store.from_set, "title": _store.title,
		"motions": _world.motions.lines().size() if _world.motions != null else 0,
		"looks": _world.step_looks.size()})


# -- badlooks: a step's look lines no reader can read, through edits ---------------


const BAD_LOOKS := """0 FILE looks.ldr
0 Looks by hand
0 Name: looks.ldr
0 Author: Hand Writer
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 !BRICKWORKS ZOOM banana
0 !BRICKWORKS PAGE FUTURE 3
0 !BRICKWORKS STEP_NAME First
0 STEP
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 !BRICKWORKS ZOOM 1.5
0 !BRICKWORKS FUTURE_STEP_WORD x y
0 STEP
0 NOFILE
"""


## A ZOOM that is no number and a PAGE of a kind the build has not got are
## the step's lines still: kept in their step through a save unedited, a
## part moved, a group made, the model renamed and the step renamed, in a
## file of LF and of CRLF (mlcheck: both went at every save).
func _case_badlooks() -> void:
	for crlf: bool in [false, true]:
		var text: String = BAD_LOOKS.replace("\n", "\r\n") if crlf else BAD_LOOKS
		var tag: String = "crlf" if crlf else "lf"
		for edit: String in ["none", "move", "make", "rename_model", "step_name"]:
			var name: String = "mla_badlooks_%s_%s" % [tag, edit]
			await _open(name, text)
			var said: String
			match edit:
				"none":
					said = "nothing"
				"move":
					said = await _say("edit_model", {"move": [{"bricks": [_id_of_colour("3003", 1)],
						"dz": 2}]})
				"make":
					_select_ids([_id_of_colour("3001", 4), _id_of_colour("3003", 1)])
					said = "made " + _shell.assemblies.make("Made group")
					_main.call("_on_model_edited")
					await _frames(6)
				"rename_model":
					_store.title = "Renamed looks"
					said = "title set"
				"step_name":
					said = await _say("edit_steps", {"op": "name", "step": 2, "name": "Second"})
			print("    %s %s: %s" % [tag, edit, said.get_slice("\n", 0).left(110)])
			var saved: String = await _bar_save("badlooks_%s_%s" % [tag, edit])
			var lines: PackedStringArray = saved.replace("\r\n", "\n").split("\n")
			var steps: Array = []
			for n: int in lines.size():
				if lines[n].strip_edges() == "0 STEP":
					steps.append(n)
			var bad := PackedStringArray()
			for pair: Array in [["ZOOM banana", 0], ["PAGE FUTURE 3", 0],
					["FUTURE_STEP_WORD x y", 1]]:
				var at: int = _index_of(lines, "!BRICKWORKS " + str(pair[0]))
				var step: int = int(pair[1])
				var low: int = -1 if step == 0 or steps.size() < step else int(steps[step - 1])
				var high: int = int(steps[step]) if steps.size() > step else lines.size()
				if saved.count(str(pair[0])) != 1 or at <= low or at >= high:
					bad.append("%s x%d at %d (step %d: %d..%d)" % [pair[0], saved.count(str(pair[0])),
						at, step + 1, low, high])
			_check("%s %s: the step's unread look lines kept once, in their step%s" % [tag, edit,
				"" if bad.is_empty() else " (" + ", ".join(bad) + ")"], bad.is_empty())
			if crlf:
				_check("%s %s: no LF alone" % [tag, edit],
					saved.count("\n") == saved.count("\r\n"))
			await _reopen_same("badlooks_%s_%s" % [tag, edit], saved)


# -- files: other programs' and hand-written, saved unedited ------------------------


func _case_files() -> void:
	var dir: String = OS.get_environment("MLA_FILES")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("res://src/dev/fixtures/mlattack")
	var same: int = 0
	var all: int = 0
	for name: String in DirAccess.get_files_at(dir):
		var raw: PackedByteArray = FileAccess.get_file_as_bytes(dir.path_join(name))
		var bom: bool = raw.size() >= 3 and raw[0] == 0xEF and raw[1] == 0xBB and raw[2] == 0xBF
		var text: String = ("﻿" if bom else "") + raw.get_string_from_utf8()
		var file := FileAccess.open(MODELS + "mla_file_" + name.get_basename() + ".ldr", FileAccess.WRITE)
		file.store_buffer(raw)
		file.close()
		_main.call("clear_model")
		await _frames(4)
		print("  open %s: %s" % [name, (await _say("open_model", {"name": "mla_file_"
			+ name.get_basename()})).get_slice("\n", 0).left(120)])
		await _settled()
		var saved: String = await _bar_save("file_" + name.get_basename())
		all += 1
		if saved == text:
			same += 1
		_check("%s: saved unedited, byte for byte%s" % [name, _first_unlike(text, saved)],
			saved == text)
	print("  unedited files byte for byte: %d of %d" % [same, all])


# -- helpers ------------------------------------------------------------------------


func _view_names() -> String:
	var names := PackedStringArray()
	for view: Dictionary in _world.saved_views:
		names.append(str(view.get("name", "")))
	return ",".join(names)


func _path_named(definition: String) -> String:
	for path: String in _shell.assemblies.paths():
		if Assemblies.definition(Assemblies.leaf(path)).to_lower() == definition.to_lower():
			return path
	return ""


func _select_ids(ids: Array) -> void:
	_builder.clear_selection()
	var selection: Dictionary = {}
	for id: Variant in ids:
		selection[int(id)] = true
	_builder.selection = selection
	_builder.selection_changed.emit(ids.size())


func _id_of_colour(part: String, colour: int) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and brick.color_code == colour:
			return brick.id
	return 0


func _put_down() -> int:
	var carry: Carry = _builder.carrying
	if carry == null:
		return 0
	var low := Vector3(INF, INF, INF)
	var high := -low
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			low = low.min(brick.transform.origin)
			high = high.max(brick.transform.origin)
	carry.stand_where_lifted(_builder.lattice, _builder)
	carry.pin()
	for k: int in 6:
		var by := Vector3(high.x - low.x + 4.0 * BrickLattice.STUD * (k + 1), 0.0, 0.0)
		if carry.show_moved(Transform3D(Basis.IDENTITY, by), _builder.lattice, _builder):
			var put: int = _builder.place()
			await _frames(4)
			_builder.cancel_carry()
			return put
	_builder.cancel_carry()
	return 0


static func _text_kept(path: String) -> String:
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var bom: bool = raw.size() >= 3 and raw[0] == 0xEF and raw[1] == 0xBB and raw[2] == 0xBF
	return ("﻿" if bom else "") + raw.get_string_from_utf8()


func _put(name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(MODELS + name + ".ldr", FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _open(name: String, text: String) -> void:
	_put(name, text)
	_keep(name + "_in.ldr", text)
	_main.call("clear_model")
	await _frames(4)
	print("  open %s: %s" % [name, (await _say("open_model", {"name": name})).get_slice("\n", 0)
		.left(140)])
	await _settled()


func _settled() -> void:
	for _n: int in 900:
		if not _store.laying and _store.awaited.is_empty():
			break
		await process_frame
	await _frames(8)


func _bar_save(label: String) -> String:
	var bar: ModelBar = _main.get("_bar")
	var ok: bool = await bar._on_save()
	await _frames(4)
	var text: String = _text_kept(MODELS + bar.model_name() + ".ldr")
	print("  bar save %s as %s: %s (%d bytes)" % [label, bar.model_name(), ok, text.length()])
	_keep(label + ".ldr", text)
	return text


func _reopen_same(label: String, saved: String) -> void:
	await _open("mla_%s_again" % label, saved)
	var again: String = await _bar_save(label + "_again")
	_check("...opened again and saved again, byte for byte%s" % _first_unlike(saved, again),
		again == saved)


func _keep(name: String, text: String) -> void:
	if _out.is_empty():
		return
	var file: FileAccess = FileAccess.open(_out.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


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


static func _index_of(lines: PackedStringArray, piece: String) -> int:
	for n: int in lines.size():
		if lines[n].contains(piece):
			return n
	return -1


static func _first_unlike(a: String, b: String) -> String:
	if a == b:
		return ""
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for n: int in maxi(la.size(), lb.size()):
		var x: String = la[n] if n < la.size() else "<none>"
		var y: String = lb[n] if n < lb.size() else "<none>"
		if x != y:
			return " (line %d: %s | %s)" % [n + 1, x.c_escape().left(90), y.c_escape().left(90)]
	return " (the same lines, %d and %d bytes)" % [a.length(), b.length()]


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
