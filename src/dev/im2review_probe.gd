## Independent review of intomodel2 (4f8b8dc3): a model brought in, then
## edited, saved and reopened. Each case prints what the reopened file has.
##
##   godot --headless --path . --script src/dev/im2review_probe.gd
##
## `-- case,case` runs only those.
extends SceneTree

const CAR := "res://models/car.ldr"
const CASTLE := "res://models/castle.ldr"
const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const RABBIT := "res://vendor/omr/files/6596-1.mpd"

const SHED := """0 FILE shed.ldr
0 Shed
0 Name: shed.ldr
0 Author: A. Builder
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -48 0 1 0 0 0 1 0 0 0 1 zz9001.dat
1 16 80 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr
0 NOFILE
0 FILE roof.ldr
0 Roof
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 zz9002.dat
0 NOFILE
"""

const PANE := """0 FILE pane.ldr
0 Pane
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 14 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

## Someone else's lodge: a top-level part the library has not got, a hidden
## sub-model, comments and meta lines a source write keeps.
const LODGE := """0 FILE lodge.ldr
0 Lodge
0 Name: lodge.ldr
0 Author: A. Host
0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt
0 !HISTORY 2020-01-01 [host] first
0 // the lodge's own note
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 40 -48 0 1 0 0 0 1 0 0 0 1 zz9004.dat
1 0 0 -24 80 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Frame
0 Name: window.ldr
0 Author: A. Host
0 // a note in the frame
1 1 0 0 0 1 0 0 0 1 0 0 0 1 zz9003.dat
0 NOFILE
"""

const ODD := """0 FILE odd.ldr
0 Odd
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 oddpart.dat
0 NOFILE
0 FILE oddpart.dat
0 Odd part
0 Name: oddpart.dat
0 Author: A. Builder
0 !LDRAW_ORG Unofficial_Part
1 16 0 0 0 1 0 0 0 1 0 0 0 1 nosuchprim.dat
0 NOFILE
"""

## Another model whose own oddpart.dat is another shape.
const ODD2 := """0 FILE odd2.ldr
0 Odd Two
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 oddpart.dat
0 NOFILE
0 FILE oddpart.dat
0 Odd part of another maker
0 Name: oddpart.dat
0 Author: C. Other
0 !LDRAW_ORG Unofficial_Part
1 16 0 0 0 1 0 0 0 1 0 0 0 1 otherprim.dat
0 NOFILE
"""

## Someone else's model carrying its own oddpart.dat the app cannot build.
const HOSTODD := """0 FILE lab.ldr
0 Lab
0 Name: lab.ldr
0 Author: A. Host
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -48 0 1 0 0 0 1 0 0 0 1 oddpart.dat
0 NOFILE
0 FILE oddpart.dat
0 The lab's own odd part
0 Name: oddpart.dat
0 Author: A. Host
0 !LDRAW_ORG Unofficial_Part
1 16 0 0 0 1 0 0 0 1 0 0 0 1 hostprim.dat
0 NOFILE
"""

## Someone else's model carrying its own oddpart.dat the app can build.
const HOSTMADE := """0 FILE works.ldr
0 Works
0 Name: works.ldr
0 Author: A. Host
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -48 0 1 0 0 0 1 0 0 0 1 oddpart.dat
0 NOFILE
0 FILE oddpart.dat
0 The works' own odd part
0 Name: oddpart.dat
0 Author: A. Host
0 !LDRAW_ORG Unofficial_Part
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 NOFILE
"""

## A model carrying a part of its own called window.dat the app cannot build.
const SILL := """0 FILE sill.ldr
0 Sill
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 window.dat
0 NOFILE
0 FILE window.dat
0 A window part
0 Name: window.dat
0 Author: S. Maker
0 !LDRAW_ORG Unofficial_Part
1 16 0 0 0 1 0 0 0 1 0 0 0 1 sillprim.dat
0 NOFILE
"""

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _store: ModelStore
var _bar: ModelBar
var _shell: Shell
var _socket: Variant
var _rpc_id: int = 0
var _only: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		_only = arg.split(",", false)
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_store = _main.get("_store")
	_bar = _main.get("_bar")
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_store.keeps = false
	CustomParts.dir = OS.get_user_data_dir().path_join("im2review_parts/")
	CustomParts.keeps = false
	for pair: Array in [["Shed", SHED], ["Pane", PANE], ["Lodge", LODGE], ["Odd", ODD],
			["Odd Two", ODD2], ["Lab", HOSTODD], ["Sill", SILL], ["Works", HOSTMADE], ["Gatehouse", _file(GATEHOUSE)], ["Rabbit", _file(RABBIT)],
			["Castle", _file(CASTLE)]]:
		_keep(pair[0], pair[1])
	for case: String in ["real", "lodge", "renamed", "moved", "copied", "deleted", "twoodd",
			"opened_after", "undone", "hostodd", "ungrouped", "pane_deleted", "windowdat", "large"]:
		if not _only.is_empty() and not _only.has(case):
			continue
		await call("_case_" + case)
	print("")
	print("im2review: %s" % ("all held" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- cases -------------------------------------------------------------------


## Someone else's real .mpd (OMR 6596-1): which of its own lines a save keeps
## with nothing brought, with a model brought whose parts all show, and with
## one that has parts the app cannot show.
func _case_real() -> void:
	print("\nreal: OMR 6596-1, saved plain / with Pane brought / with Shed brought")
	var original: String = _file(RABBIT)
	var host_counts: Dictionary = _counts(original)
	for which: String in ["", "Pane", "Shed"]:
		await _open_path(ModelStore.saved_path("Rabbit"))
		if not which.is_empty():
			print("    MCP: " + (await _say("open_model", {"into": true, "name": which})).left(200))
		await _frames(4)
		var name: String = "Rabbit with " + (which if not which.is_empty() else "nothing")
		_check("saved as %s" % name, _store.save_as(name))
		var text: String = _file(ModelStore.saved_path(name))
		var lost: Array = _lost_lines(original, text)
		print("    %s: %d of the original's %d non-blank lines missing from the save (%d bytes -> %d)" % [
			name, lost.size(), _lines(original).size(), original.length(), text.length()])
		var kinds: Dictionary = {}
		for line: String in lost:
			var kind: String = "type 1 line" if line.begins_with("1 ") else (line.split(" ")[1]
				if line.split(" ").size() > 1 else line)
			kinds[kind] = int(kinds.get(kind, 0)) + 1
		print("      by kind: %s" % kinds)
		for line: String in lost.slice(0, 12):
			print("      - " + line.left(110))
		var counts: Dictionary = _counts(text)
		var want: Dictionary = host_counts.duplicate()
		if which == "Shed":
			for key: String in _counts(SHED):
				want[key] = int(want.get(key, 0)) + int(_counts(SHED)[key])
		elif which == "Pane":
			for key: String in _counts(PANE):
				want[key] = int(want.get(key, 0)) + int(_counts(PANE)[key])
		_check("...%s: parts host + brought (%s)" % [name, _difference(want, counts)], counts == want)
		var heads: Dictionary = _heads(text)
		print("      section authors in the save: %s" % _authors(heads))


## Someone else's lodge with a top-level part and a sub-model the library has
## not got, the shed brought in: every part, and the lodge's own lines.
func _case_lodge() -> void:
	print("\nlodge: A. Host's lodge (zz9004 top level, Frame of zz9003, comments), the shed brought in")
	for which: String in ["Pane", "Shed"]:
		await _open_path(ModelStore.saved_path("Lodge"))
		await _say("open_model", {"into": true, "name": which})
		var text: String = await _save_reopen("Lodge with " + which)
		var trees: Dictionary = _trees(text)
		print("    trees: %s" % trees)
		_check("...%s: zz9004 top level, zz9003 in Frame (%s, %s)" % [which, trees.get("zz9004|1"),
			trees.get("zz9003|1")], trees.get("zz9004|1", []) == [""]
			and trees.get("zz9003|1", []) == ["Frame"])
		var lost: Array = _lost_lines(LODGE, text)
		_check("...%s: the lodge's own lines kept (missing: %s)" % [which, lost], lost.is_empty())


## The brought shed renamed Barn: are its unshown parts in Barn after a save?
func _case_renamed() -> void:
	print("\nrenamed: the shed into the car, renamed Barn, saved, reopened")
	await _open_path(CAR)
	await _say("open_model", {"into": true, "name": "Shed"})
	var assemblies: Assemblies = _shell.assemblies
	var path: String = _path_to("Shed", 1)
	var named: String = assemblies.rename(path, "Barn")
	await _frames(4)
	print("    renamed %s -> %s; held: %s" % [path, named, _held()])
	var text: String = await _save_reopen("Car barn")
	var trees: Dictionary = _trees(text)
	print("    trees: 3001|4 %s 3003|2 %s zz9001|1 %s zz9002|14 %s" % [trees.get("3001|4"),
		trees.get("3003|2"), trees.get("zz9001|1"), trees.get("zz9002|14")])
	_check("zz9001 in Barn with its brick, zz9002 in Barn/Roof", trees.get("zz9001|1", []) == ["Barn"]
		and trees.get("zz9002|14", []) == ["Barn/Roof"])
	_offsets(text)


## The brought shed taken apart (its parts loose in the car): where are its
## unshown parts after a save?
func _case_ungrouped() -> void:
	print("\nungrouped: the shed into the car, taken apart, saved, reopened")
	await _open_path(CAR)
	await _say("open_model", {"into": true, "name": "Shed"})
	var assemblies: Assemblies = _shell.assemblies
	var n: int = assemblies.ungroup(_path_to("Shed", 1))
	await _frames(4)
	print("    ungrouped %d; paths now %s; held %s" % [n, _paths(), _held()])
	var text: String = await _save_reopen("Car shed apart")
	var trees: Dictionary = _trees(text)
	print("    trees: 3001|4 %s 3003|2 %s zz9001|1 %s zz9002|14 %s" % [trees.get("3001|4"),
		trees.get("3003|2"), trees.get("zz9001|1"), trees.get("zz9002|14")])
	_check("zz9001 loose with its brick, zz9002 in Roof with its brick",
		trees.get("zz9001|1", []) == trees.get("3001|4", [])
		and trees.get("zz9002|14", []) == trees.get("3003|2", []))


## The pane (all shown) into the car, its parts taken off: is the car still
## written as its file was (to tell the shed's whole write from the base's)?
func _case_pane_deleted() -> void:
	print("\npane_deleted: the pane into the car, its parts taken off, saved")
	await _open_path(CAR)
	await _say("open_model", {"into": true, "name": "Pane"})
	_select(_under("Pane#1"))
	print("    took off %d" % _builder.remove_selection())
	await _frames(4)
	var text: String = await _save_reopen("Car pane gone")
	var lost: Array = _lost_lines(_file(CAR), text)
	_check("car.ldr's own lines kept (%d missing: %s)" % [lost.size(), lost.slice(0, 3)], lost.is_empty())


## Sill (carries window.dat it cannot build) into the lodge (hidden Frame in
## window.ldr): both kept, each its own?
func _case_windowdat() -> void:
	print("\nwindowdat: Sill (its own window.dat) into the lodge (its Frame in window.ldr)")
	await _open_path(ModelStore.saved_path("Lodge"))
	print("    " + (await _say("open_model", {"into": true, "name": "Sill"})).left(200))
	var text: String = await _save_reopen("Lodge with Sill")
	print("    FILE lines: %s" % [Array(text.split("\n")).filter(func(l: String) -> bool:
		return l.begins_with("0 FILE"))])
	var trees: Dictionary = _trees(text)
	print("    trees: %s" % trees)
	_check("zz9003 still in the lodge's Frame (%s)" % [trees.get("zz9003|1")],
		trees.get("zz9003|1", []) == ["Frame"])
	_check("the sill's window part kept, drawn from sillprim (%s)" % [trees.get("window|2")],
		text.contains("sillprim.dat") and trees.has("window|2"))


## The brought shed moved: do its unshown parts move with it?
func _case_moved() -> void:
	print("\nmoved: the shed into the car, then moved 10 cells along x, saved, reopened")
	await _open_path(CAR)
	await _say("open_model", {"into": true, "name": "Shed"})
	_select(_under("Shed#1"))
	# As a person's arrow keys move it (Main._nudge_by): the move, then the
	# app's after-edit (Main._on_model_edited).
	var steps: int = (_builder.get("_history") as Array).size()
	_main.call("_nudge_by", Vector3i(10, 0, 0))
	await _frames(4)
	print("    moved: %d step(s) more in the history" % ((_builder.get("_history") as Array).size() - steps))
	var text: String = await _save_reopen("Car shed moved")
	_offsets(text)


## The brought shed copied and pasted beside: each copy's unshown parts.
func _case_copied() -> void:
	print("\ncopied: the shed into the car, copied, pasted beside, saved, reopened")
	await _open_path(CAR)
	await _say("open_model", {"into": true, "name": "Shed"})
	_select(_under("Shed#1"))
	var copied: int = _builder.copy_selection()
	_builder.hold_copy(Carry.clipboard)
	var down: Variant = await _put_beside()
	print("    copied %d, put down: %s; paths now %s" % [copied, down, _paths()])
	var text: String = await _save_reopen("Car two sheds")
	var trees: Dictionary = _trees(text)
	print("    trees: 3001|4 %s 3003|2 %s zz9001|1 %s zz9002|14 %s" % [trees.get("3001|4"),
		trees.get("3003|2"), trees.get("zz9001|1"), trees.get("zz9002|14")])
	var counts: Dictionary = _counts(text)
	_check("as many of zz9001 and zz9002 as of their bricks, or one each (%s)" % [[counts.get("3001|4"),
		counts.get("zz9001|1"), counts.get("3003|2"), counts.get("zz9002|14")]],
		int(counts.get("zz9001|1", 0)) >= 1 and int(counts.get("zz9002|14", 0)) >= 1)
	_offsets(text)


## The brought shed's shown parts all taken off: what does a save write?
func _case_deleted() -> void:
	print("\ndeleted: the shed into the car, its parts all taken off, saved")
	await _open_path(CAR)
	var plain: String = _store.to_text("Car")
	await _say("open_model", {"into": true, "name": "Shed"})
	_select(_under("Shed#1"))
	var gone: int = _builder.remove_selection()
	await _frames(4)
	print("    took off %d; held: %s" % [gone, _held()])
	var text: String = await _save_reopen("Car shed gone")
	var counts: Dictionary = _counts(text)
	_check("no part of the shed in the save (%s)" % _difference(_counts(plain), counts),
		counts == _counts(plain))
	var lost: Array = _lost_lines(_file(CAR), text)
	print("    car.ldr lines missing from the save: %d (plain save: %d)" % [lost.size(),
		_lost_lines(_file(CAR), plain).size()])
	for line: String in lost.slice(0, 8):
		print("      - " + line)


## Two models each carrying their own oddpart.dat, both brought in.
func _case_twoodd() -> void:
	print("\ntwoodd: Odd and Odd Two (each its own oddpart.dat) into the car")
	await _open_path(CAR)
	print("    " + (await _say("open_model", {"into": true, "name": "Odd"})).left(160))
	print("    " + (await _say("open_model", {"into": true, "name": "Odd Two"})).left(160))
	var text: String = await _save_reopen("Car two odds")
	var model: LdrModel = LdrModel.parse(text, "x.ldr")
	var odd: String = str(model.embedded_parts.get("oddpart.dat", ""))
	print("    oddpart.dat sections in the save: %d; the one kept draws on %s" % [
		text.count("0 FILE oddpart.dat"), "nosuchprim" if odd.contains("nosuchprim") else (
		"otherprim" if odd.contains("otherprim") else "?")])
	_check("Odd Two's oddpart (otherprim.dat, C. Other) is in the save",
		text.contains("otherprim.dat"))
	_check("Odd's oddpart (nosuchprim.dat) is in the save", text.contains("nosuchprim.dat"))


## The shed brought in, then another model opened: nothing of the shed in it.
func _case_opened_after() -> void:
	print("\nopened_after: the shed into the car, then the lodge opened and saved")
	await _open_path(CAR)
	await _say("open_model", {"into": true, "name": "Shed"})
	await _open_path(ModelStore.saved_path("Lodge"))
	var text: String = await _save_reopen("Lodge after")
	_check("the lodge's parts only (%s)" % _difference(_counts(LODGE), _counts(text)),
		_counts(text) == _counts(LODGE))
	_check("...and its lines (missing: %s)" % [_lost_lines(LODGE, text)],
		_lost_lines(LODGE, text).is_empty())


## A host carrying its own oddpart.dat (unbuildable, then buildable), Odd
## Two (its own oddpart.dat, unbuildable) brought in: whose survives?
func _case_hostodd() -> void:
	for host: String in ["Lab", "Works"]:
		print("\nhostodd: Odd Two into %s, each with its own oddpart.dat" % host)
		await _open_path(ModelStore.saved_path(host))
		print("    " + (await _say("open_model", {"into": true, "name": "Odd Two"})).left(200))
		var text: String = await _save_reopen("%s with Odd Two" % host)
		print("    oddpart.dat sections: %d; draws on hostprim %s, 3003 %s, otherprim %s" % [
			text.count("0 FILE oddpart.dat"), text.contains("hostprim.dat"),
			text.contains("1 16 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat"), text.contains("otherprim.dat")])
		_check("%s: the host's own oddpart kept" % host, text.contains("hostprim.dat")
			or text.contains("1 16 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat"))
		_check("%s: Odd Two's oddpart kept" % host, text.contains("otherprim.dat"))


## The shed brought into the car and undone: the car saved as it was?
func _case_undone() -> void:
	print("\nundone: the shed (and the pane) into the car, undone, saved")
	for which: String in ["Pane", "Shed"]:
		await _open_path(CAR)
		await _say("open_model", {"into": true, "name": which})
		_builder.undo()
		await _frames(4)
		var text: String = await _save_reopen("Car undone " + which)
		_check("%s: the car's parts (%s)" % [which, _difference(_counts(_file(CAR)), _counts(text))],
			_counts(text) == _counts(_file(CAR)))
		var lost: Array = _lost_lines(_file(CAR), text)
		_check("%s: car.ldr's own lines kept (%d missing: %s)" % [which, lost.size(), lost.slice(0, 3)],
			lost.is_empty())


## The castle (2507 parts): the shed, then the castle itself, brought in.
func _case_large() -> void:
	print("\nlarge: the castle, the shed and then the castle itself brought in")
	await _open_path(ModelStore.saved_path("Castle"))
	var parts: int = _model().size()
	var t9: int = Time.get_ticks_usec()
	_store.save_as("Castle plain")
	print("    plain castle save: %.0f ms" % ((Time.get_ticks_usec() - t9) / 1000.0))
	for which: String in ["Shed", "Castle"]:
		var t0: int = Time.get_ticks_usec()
		var said: String = await _say("open_model", {"into": true, "name": which})
		var t1: int = Time.get_ticks_usec()
		print("    %s in: %.0f ms over MCP: %s" % [which, (t1 - t0) / 1000.0, said.left(140)])
		t0 = Time.get_ticks_usec()
		_builder.undo()
		print("    undo: %.0f ms (%d parts)" % [(Time.get_ticks_usec() - t0) / 1000.0, _model().size()])
		t0 = Time.get_ticks_usec()
		_builder.redo()
		print("    redo: %.0f ms (%d parts)" % [(Time.get_ticks_usec() - t0) / 1000.0, _model().size()])
		await _frames(4)
	var t2: int = Time.get_ticks_usec()
	var assemblies: Assemblies = _shell.assemblies
	var next: String = assemblies.next_copy("Tower")
	print("    next_copy: %.1f ms (%s)" % [(Time.get_ticks_usec() - t2) / 1000.0, next])
	t2 = Time.get_ticks_usec()
	_check("saved", _store.save_as("Castle twice"))
	print("    save: %.0f ms" % ((Time.get_ticks_usec() - t2) / 1000.0))
	var text: String = _file(ModelStore.saved_path("Castle twice"))
	var want: Dictionary = _counts(_file(CASTLE))
	for key: String in _counts(_file(CASTLE)):
		want[key] = int(want[key]) * 2
	for key: String in _counts(SHED):
		want[key] = int(want.get(key, 0)) + int(_counts(SHED)[key])
	_check("castle x2 + shed (%d parts before) (%s)" % [parts, _difference(want, _counts(text))],
		_counts(text) == want)


# -- helpers -----------------------------------------------------------------


## Where each unshown part sits against its sub-model's shown brick, in the
## reopened file's coordinates: the shed has zz9001 24 above 3001|4, and
## zz9002 24 above 3003|2.
func _offsets(text: String) -> void:
	var placed: Array = _placed(text)
	var own: Array = _placed(SHED)
	var want: Dictionary = {}
	for pair: Array in [["3001|4", "zz9001|1"], ["3003|2", "zz9002|14"]]:
		var a: Array = own.filter(func(e: Dictionary) -> bool: return e["key"] == pair[0])
		var b: Array = own.filter(func(e: Dictionary) -> bool: return e["key"] == pair[1])
		want[pair[1]] = (b[0]["at"] as Transform3D).origin - (a[0]["at"] as Transform3D).origin
	for pair: Array in [["3001|4", "zz9001|1"], ["3003|2", "zz9002|14"]]:
		var bricks: Array = placed.filter(func(e: Dictionary) -> bool: return e["key"] == pair[0])
		var kept: Array = placed.filter(func(e: Dictionary) -> bool: return e["key"] == pair[1])
		var seen: Array = []
		for k: Dictionary in kept:
			var best: Vector3 = Vector3(INF, INF, INF)
			for b: Dictionary in bricks:
				var off: Vector3 = (k["at"] as Transform3D).origin - (b["at"] as Transform3D).origin
				if off.length() < best.length():
					best = off
			seen.append(best)
		var wanted: Vector3 = want[pair[1]]
		_check("%s each where the shed has it against a %s, %s (nearest offsets %s)" % [pair[1],
			pair[0], wanted, seen], not seen.is_empty() and seen.all(func(v: Vector3) -> bool:
				return v.is_equal_approx(wanted)))


func _held() -> Array:
	return _store._held_placements().map(func(p: LdrModel.Placement) -> String:
		return "%s in %s" % [p.part_id, _world.held_path(p)])


func _paths() -> Array:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _model():
		out[Assemblies.path_of(brick)] = true
	return out.keys()


func _under(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		var at: String = Assemblies.path_of(brick)
		if at == path or at.begins_with(path + "/"):
			out.append(brick.id)
	print("    (%d parts under %s; selected %d)" % [out.size(), path, _builder.selection.size()])
	return out


static func _lines(text: String) -> Array:
	var out: Array = []
	for raw: String in text.split("\n"):
		var line: String = " ".join(LdrModel._fields(raw.strip_edges()))
		if not line.is_empty():
			out.append(line)
	return out


## The non-blank lines of [param original] (as a multiset) [param text] has not.
static func _lost_lines(original: String, text: String) -> Array:
	var have: Dictionary = {}
	for line: String in _lines(text):
		have[line.to_lower()] = int(have.get(line.to_lower(), 0)) + 1
	var out: Array = []
	for line: String in _lines(original):
		var key: String = line.to_lower()
		if int(have.get(key, 0)) > 0:
			have[key] = int(have[key]) - 1
		else:
			out.append(line)
	return out


func _path_to(def: String, copy: int) -> String:
	for brick: BrickWorld.Brick in _model():
		var parts: PackedStringArray = Assemblies.segments(Assemblies.path_of(brick))
		for n: int in parts.size():
			if Assemblies.definition(parts[n]) == def and Assemblies.copy_of(parts[n]) == copy:
				return "/".join(parts.slice(0, n + 1))
	return ""


func _keep(name: String, text: String) -> void:
	var path: String = ModelStore.saved_path(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _file(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _open_path(path: String) -> void:
	_builder.cancel_carry()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(10)


func _save_reopen(name: String) -> String:
	await _frames(4)
	_check("saved as %s" % name, _store.save_as(name))
	var text: String = _file(ModelStore.saved_path(name))
	await _open_path(ModelStore.saved_path(name))
	return text


func _placed(text: String) -> Array:
	var model: LdrModel = LdrModel.parse(text, "model.ldr")
	CustomParts.take_into([], _library, model, null)
	var out: Array = []
	var authored: bool = model.steps_are_authored()
	for placement: LdrModel.Placement in model.flatten(_library.parts):
		var part: String = ModelStore.studio_part(_library.resolve(placement.part_id), _library)
		out.append({"key": "%s|%d" % [part, placement.color_code],
			"chain": _chain(Assemblies.path_from(placement.group, placement.unit)),
			"at": placement.transform, "step": placement.step if authored else -1})
	return out


func _chain(path: String) -> String:
	return "/".join(Array(Assemblies.segments(path)).map(func(s: String) -> String:
		return Assemblies.definition(s)))


func _counts(text: String) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in _placed(text):
		out[entry["key"]] = int(out.get(entry["key"], 0)) + 1
	return out


static func _difference(a: Dictionary, b: Dictionary) -> String:
	var said: Array = []
	for key: Variant in a:
		if int(a[key]) != int(b.get(key, 0)):
			said.append("%s %d/%d" % [key, int(a[key]), int(b.get(key, 0))])
	for key: Variant in b:
		if not a.has(key):
			said.append("%s 0/%d" % [key, int(b[key])])
	return "same" if said.is_empty() else ", ".join(said)


func _trees(text: String) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in _placed(text):
		out[entry["key"]] = (out.get(entry["key"], []) as Array) + [entry["chain"]]
	return out


static func _heads(text: String) -> Dictionary:
	var out: Dictionary = {}
	var title: String = ""
	var head: bool = false
	var after_file: bool = false
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 FILE "):
			after_file = true
			head = true
			title = line.substr(7)
			out[title] = []
			continue
		if line.begins_with("1 ") or SourceFile._is_step(line) or line == "0 NOFILE":
			head = false
		if head and not title.is_empty() and (line.begins_with("0 Author:") or line.begins_with("0 !LICENSE")):
			(out[title] as Array).append(line)
	return out


static func _authors(heads: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for title: String in heads:
		for line: String in heads[title]:
			if line.begins_with("0 Author:"):
				var by: String = line.substr(9).strip_edges()
				out[by] = int(out.get(by, 0)) + 1
	return out


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _select(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: Variant in ids:
		_builder.selection[int(brick_id)] = true
	_builder.selection_changed.emit(_builder.selection.size())
	print("    (selected %d of %d)" % [_builder.selection.size(), ids.size()])


func _put_beside() -> Variant:
	var model := AABB()
	var any: bool = false
	for brick: BrickWorld.Brick in _model():
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var here: AABB = (brick.transform * mesh.bounds).abs()
		model = here if not any else model.merge(here)
		any = true
	for tries: int in 30:
		var at := Vector3(model.end.x + 200.0 + 40.0 * tries, model.end.y + 600.0, model.get_center().z)
		_builder.carrying.aim(_builder.lattice, _builder, at, Vector3.DOWN)
		if _builder.carrying.can_place():
			var first: int = _builder.place()
			await _frames(4)
			return first if first != 0 else null
	print("    (nowhere to put it down)")
	return null


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	await _frames(6)
	return text.replace("\n", " | ")


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
