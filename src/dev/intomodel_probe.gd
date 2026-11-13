## Put one saved model into another (intomodel3), as a person does it, in a
## window: each way in, and what the model is after.
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 \
##       --script src/dev/intomodel_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh intomodel_probe
##
## The ways in: File, Import, Into this model… with a saved model chosen
## from its list; the same list's From a file on this computer… with a file
## chosen in its dialog; the library's Put in this model on a real set's
## card; and a session's open_model into=true. Each puts the model in hand
## (the session's straight down), and a click on a clear spot of the
## baseplate puts it down.
##
## The invariant, each time: one Undo (its key) takes all of it out, the
## model as it was opened, every part, every part the app cannot show and
## every copy's step; Redo (its key) puts it back. Saved and reopened, the
## model has every part of the host, each where it was, in its colour,
## sub-assembly and step, those the app cannot show among them, and exactly
## the parts of each model put in, each where that model has it against the
## others (one placement for all of them), in its colour, sub-assembly and
## step, those the app cannot show among them; each model put in one copy at
## the top under a name of its own, none of its sub-models named as one of
## the host's, its maker in its header; no two sections of the file under one
## name. Saved and reopened again: the same. Compared part by part as the
## app has them after the reopen, not by lines.
##
##   -- case,case   runs only those
extends SceneTree

const CAR := "res://models/car.ldr"
const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const RABBIT := "res://vendor/omr/files/6596-1.mpd"

## Someone's shed: a sub-model called Roof, and a part in each the library
## has not got.
const SHED := """0 FILE shed.ldr
0 Shed
0 Name: shed.ldr
0 Author: A. Builder
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -48 0 1 0 0 0 1 0 0 0 1 zz9001.dat
0 STEP
1 16 80 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr
0 STEP
0 NOFILE
0 FILE roof.ldr
0 Roof
0 Name: roof.ldr
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 zz9002.dat
0 STEP
0 NOFILE
"""

## Someone else's barn, in steps: its own Roof, a part the library has not
## got, and lines of its own.
const BARN := """0 FILE barn.ldr
0 Barn
0 Name: barn.ldr
0 Author: A. Host
0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt
0 // the barn's own note
1 7 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 7 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 1 0 -48 0 1 0 0 0 1 0 0 0 1 zz9005.dat
1 16 20 -48 0 1 0 0 0 1 0 0 0 1 roof.ldr
0 STEP
0 NOFILE
0 FILE roof.ldr
0 Roof
0 Name: roof.ldr
0 Author: A. Host
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
0 STEP
0 NOFILE
"""

## A model the app wrote: its own Roof, and a part the library has not got.
const HOME := """0 FILE home.ldr
0 Home
0 Name: home.ldr
0 Author: Brickworks
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -48 0 1 0 0 0 1 0 0 0 1 zz9006.dat
0 STEP
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr
0 STEP
0 NOFILE
0 FILE roof.ldr
0 Roof
0 Name: roof.ldr
0 Author: Brickworks
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
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
var _camera: Camera3D
var _socket: Variant
var _rpc_id: int = 0
var _pointer := Vector2.ZERO
var _only: PackedStringArray = PackedStringArray()
var _brought: int = 0


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
	_camera = _main.get("_camera")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_store.keeps = false
	CustomParts.dir = OS.get_user_data_dir().path_join("intomodel_parts/")
	CustomParts.keeps = false
	print("window %s" % [DisplayServer.window_get_size()])
	for pair: Array in [["Shed", SHED], ["Barn", BARN], ["Home", HOME]]:
		_keep(ModelStore.saved_path(pair[0]), pair[1])
	for case: String in ["menu_saved", "menu_file", "twice", "library", "session"]:
		if not _only.is_empty() and not _only.has(case):
			continue
		await call("_case_" + case)
	print("")
	print("intomodel: %d models put in, each held to the invariant; %s" % [_brought,
		"all held" if _failures == 0 else "%d FAILED" % _failures])
	quit(1 if _failures > 0 else 0)


# -- cases -------------------------------------------------------------------


## File, Import, Into this model…, the shed from the list, into someone
## else's barn in steps that has a Roof of its own.
func _case_menu_saved() -> void:
	print("\nmenu_saved: File, Import, Into this model…, Shed, into A. Host's barn")
	var shed: Dictionary = await _alone(ModelStore.saved_path("Shed"))
	await _open_path(ModelStore.saved_path("Barn"))
	var host: Dictionary = _state()
	await _from_into_list("Shed")
	await _put_down()
	await _undo_redo(host)
	await _held_to(host, [shed], ["A. Builder"], "Barn with shed", ["0 // the barn's own note"])


## The same list's From a file on this computer…, the shed's file chosen in
## its dialog, into the car (someone else's, no steps).
func _case_menu_file() -> void:
	print("\nmenu_file: File, Import, Into this model…, From a file…, shed.ldr, into the car")
	var shed: Dictionary = await _alone(ModelStore.saved_path("Shed"))
	var file: String = OS.get_user_data_dir().path_join("picked/shed.ldr")
	_keep(file, SHED)
	await _open_path(CAR)
	var host: Dictionary = _state()
	await _into_menu()
	var into: PopupMenu = _bar.get("_into")
	into.id_pressed.emit(ModelBar.IMPORT)
	into.hide()
	await _frames(10)
	var picker: ModelFilePicker = _bar.get("_into_picker")
	var dialog: FileDialog = picker.get("_dialog") if picker != null else null
	if not _check("a file dialog to choose from", dialog != null and dialog.visible):
		return
	dialog.file_selected.emit(file)
	dialog.hide()
	await _until_held()
	await _put_down()
	await _undo_redo(host)
	await _held_to(host, [shed], ["A. Builder"], "Car with shed", ["0 Author: James Jessiman"])


## The shed twice into a model the app wrote that has a Roof of its own:
## three Roofs, three names. The second's Undo takes only the second out.
func _case_twice() -> void:
	print("\ntwice: the shed twice into Home (the app's own, its own Roof)")
	var shed: Dictionary = await _alone(ModelStore.saved_path("Shed"))
	await _open_path(ModelStore.saved_path("Home"))
	var host: Dictionary = _state()
	await _from_into_list("Shed")
	await _put_down()
	var once: Dictionary = _state()
	await _from_into_list("Shed")
	await _put_down()
	await _undo_redo(once)
	await _held_to(host, [shed, shed], ["A. Builder", "A. Builder"], "Home with sheds", [])


## The library's Put in this model, on a real set's card (OMR 6596-1, 900
## lines of someone else's), into the car: its maker credited.
func _case_library() -> void:
	print("\nlibrary: Put in this model on 6596-1's card, into the car")
	var rabbit: Dictionary = await _alone(RABBIT)
	_keep(ModelLibrary.KEPT + "omr/6596-1.mpd", FileAccess.get_file_as_string(RABBIT))
	await _open_path(CAR)
	var host: Dictionary = _state()
	var dialog: Control = _shell.library_dialog
	if dialog.get("books") == null:
		dialog.set("books", _main.get("_model_library"))
	var entry: Dictionary = {"file": ModelLibrary.ROOT + "omr/6596-1.mpd", "name": "Rabbit",
		"set": "6596-1", "author": "Tomas Kralicek [RabbiT_CZ]", "licence": "CCAL 2.0",
		"page": ""}
	var card: Dictionary = {"id": "omr-6596-1", "name": "6596-1 Rabbit", "kind": "set",
		"licence": "CCAL 2.0", "entry": entry}
	var put: Button = dialog.call("_put_button", card)
	_check("Put in this model offered on a CCAL 2.0 set's card", not put.disabled)
	put.pressed.emit()
	await _until_held()
	await _put_down()
	await _undo_redo(host)
	await _held_to(host, [rabbit], ["Tomas Kralicek [RabbiT_CZ]"], "Car with rabbit",
		["0 Author: James Jessiman"])
	put.free()


## A session's open_model into=true, a corner given, into the gatehouse
## (someone else's, in steps, a ROTSTEP).
func _case_session() -> void:
	print("\nsession: open_model into=true name=Shed x=12 z=0, into the gatehouse")
	var shed: Dictionary = await _alone(ModelStore.saved_path("Shed"))
	await _open_path(GATEHOUSE)
	var host: Dictionary = _state()
	var said: String = await _say("open_model", {"into": true, "name": "Shed", "x": 12, "z": 0})
	print("    MCP: " + said.left(300))
	_check("...put down, its parts the app cannot show said kept", said.begins_with("Put Shed")
		and said.contains("not shown, kept"))
	await _undo_redo(host)
	await _held_to(host, [shed], ["A. Builder"], "Gatehouse with shed",
		["0 ROTSTEP 0 45 0 ABS"])


# -- the invariant -----------------------------------------------------------------


## One Undo (its key) takes all of what was put down out: the model is
## [param before] again; Redo (its key) puts it back as it was.
func _undo_redo(before: Dictionary) -> void:
	var after: Dictionary = _state()
	_check("put down: %d parts more than before (%d not shown)" % [
		(after["parts"] as Array).size() - (before["parts"] as Array).size(),
		_unshown(after) - _unshown(before)],
		(after["parts"] as Array).size() > (before["parts"] as Array).size())
	await _key_of("undo")
	var undone: Dictionary = _state()
	_check("one Undo: the model as it was (%s)" % _difference(before, undone),
		_difference(before, undone).is_empty())
	await _key_of("redo")
	var redone: Dictionary = _state()
	_check("Redo: back as it was put down (%s)" % _difference(after, redone),
		_difference(after, redone).is_empty())


## Saved as [param name] and reopened, the model is [param host] and each
## of [param brought] put in whole ([method _invariant]), each credited to
## its maker in [param makers]; the file keeps [param kept], lines of the
## host's own; saved and reopened again, the same.
func _held_to(host: Dictionary, brought: Array, makers: Array, name: String,
		kept: Array) -> void:
	_check("saved as %s" % name, _store.save_as(name))
	var text: String = _file(ModelStore.saved_path(name))
	await _open_path(ModelStore.saved_path(name))
	var now: Dictionary = _state()
	_invariant(host, brought, makers, now, text)
	for line: String in kept:
		_check("the host's own line kept: %s" % line, text.contains(line))
	var files: Dictionary = {}
	var twice: Array = []
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 FILE "):
			var key: String = LdrModel._key(line.substr(7))
			if files.has(key):
				twice.append(line)
			files[key] = true
	_check("no two sections of the file under one name (%d sections; twice: %s)" % [files.size(),
		twice], twice.is_empty())
	_check("saved again", _store.save_as(name + " again"))
	await _open_path(ModelStore.saved_path(name + " again"))
	var again: Dictionary = _state()
	_check("...reopened again: the same (%s)" % _difference(now, again),
		_difference(now, again).is_empty())
	_brought += brought.size()


## The model reopened, [param now], against the host as it opened and each
## model put in as it opens alone.
func _invariant(host: Dictionary, brought: Array, makers: Array, now: Dictionary,
		text: String) -> void:
	var rest: Array = (now["parts"] as Array).duplicate()
	var lost: Array = []
	for part: Dictionary in host["parts"]:
		if _take(rest, part, part["path"], Transform3D.IDENTITY) < 0:
			lost.append(_words(part))
	_check("every part of the host where it was, in its colour, sub-assembly and step "
		+ "(%d, %d not shown; lost %s)" % [(host["parts"] as Array).size(), _unshown(host),
		lost.slice(0, 3)], lost.is_empty())
	var moved: Array = []
	for path: String in host["units"]:
		if (now["units"] as Dictionary).get(path) != host["units"][path]:
			moved.append(path)
	_check("...each of its copies in its step (%d; changed %s)" % [(host["units"] as Dictionary)
		.size(), moved.slice(0, 3)], moved.is_empty())
	var host_tops: Dictionary = {}
	for part: Dictionary in host["parts"]:
		host_tops[_top(part["path"])] = true
	var tops: Dictionary = {}
	for part: Dictionary in rest:
		var top: String = _top(part["path"])
		tops[top] = (tops.get(top, []) as Array) + [part]
	var roots: Array = tops.keys()
	roots.sort()
	if not _check("the rest is %d model(s) put in, each one copy at the top of its own (%s)" % [
			brought.size(), roots], roots.size() == brought.size() and not roots.has("")
			and roots.all(func(r: String) -> bool: return not host_tops.has(r))):
		return
	var taken: Dictionary = {}
	for def: String in _defs(host["parts"], host["units"]):
		taken[def.strip_edges().to_lower()] = true
	for n: int in roots.size():
		var alone: Dictionary = brought[n]
		var copy: String = roots[n]
		var mine: Array = tops[copy]
		var map: Dictionary = {}
		var unnamed: Array = []
		var under: Dictionary = {}
		for part: Dictionary in mine:
			for segment: String in Assemblies.segments(part["path"]).slice(1):
				under[Assemblies.definition(segment)] = true
		for path: String in now["units"]:
			if path.begins_with(copy + "/"):
				for segment: String in Assemblies.segments(path).slice(1):
					under[Assemblies.definition(segment)] = true
		for def: String in _defs(alone["parts"], alone["units"]):
			var named: Array = under.keys().filter(func(d: String) -> bool:
				return d == def or (d.begins_with(def + " ") and d.trim_prefix(def + " ").is_valid_int()))
			if named.size() != 1:
				unnamed.append(def)
			else:
				map[def] = named[0]
		var root_def: String = Assemblies.definition(copy)
		var clash: Array = ([root_def] + map.values()).filter(func(d: String) -> bool:
			return taken.has(d.strip_edges().to_lower()))
		_check("%s: named %s, its sub-models %s; none of them the host's or another's (%s)" % [
			copy, root_def, map, clash], unnamed.is_empty() and clash.is_empty())
		for def: String in [root_def] + map.values():
			taken[def.strip_edges().to_lower()] = true
		# One placement for all of it: from a part it has once, tried
		# against each of the copy's parts like it.
		var parts: Array = alone["parts"]
		var found: bool = false
		var missed: Array = []
		var first: Dictionary = parts[0]
		for candidate: Dictionary in mine:
			if candidate["key"] != first["key"] or candidate["path"] != _mapped(first["path"],
					copy, map) or not _same_step(first["step"], candidate["step"]):
				continue
			var placed: Transform3D = (candidate["at"] as Transform3D) * \
				(first["at"] as Transform3D).affine_inverse()
			var left: Array = mine.duplicate()
			missed = []
			for part: Dictionary in parts:
				if _take(left, part, _mapped(part["path"], copy, map), placed) < 0:
					missed.append(_words(part))
			if missed.is_empty() and left.is_empty():
				found = true
				break
		_check("%s: exactly the %d parts of the model put in (%d not shown), each where it has "
			% [copy, parts.size(), _unshown(alone)] + "it against the others, in its colour, "
			+ "sub-assembly and step (missed %s)" % [missed.slice(0, 3)], found)
		var steps_off: Array = []
		for path: String in alone["units"]:
			var there: String = _mapped(path, copy, map)
			if not (now["units"] as Dictionary).has(there) or not _same_step(
					int(alone["units"][path]), int(now["units"][there])):
				steps_off.append("%s %s -> %s" % [path, alone["units"][path],
					(now["units"] as Dictionary).get(there)])
		_check("%s: each of its copies in its step, the copy itself in step %s (%s)" % [copy,
			(now["units"] as Dictionary).get(copy), steps_off], steps_off.is_empty())
		var header: PackedStringArray = _header_of(text, root_def)
		_check("%s: its maker in its section's header in the file (%s)" % [copy, Array(header)
			.filter(func(l: String) -> bool: return l.begins_with("0 Author:"))],
			header.has("0 Author: %s" % makers[n]))


## The lines before the first part of the section of [param text] titled
## [param def]: where its maker is written (LdrModel._write_one).
static func _header_of(text: String, def: String) -> PackedStringArray:
	var out := PackedStringArray()
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	for n: int in lines.size():
		if not lines[n].begins_with("0 FILE ") or n + 1 >= lines.size() \
				or lines[n + 1].strip_edges() != "0 " + def:
			continue
		for m: int in range(n + 1, lines.size()):
			if lines[m].begins_with("1 ") or lines[m].begins_with("0 NOFILE"):
				break
			out.append(lines[m].strip_edges())
		break
	return out


## Of [param from], the one part like [param part] at [param path], in its
## step and where [param placed] puts it, taken out: its index, -1 for none.
func _take(from: Array, part: Dictionary, path: String, placed: Transform3D) -> int:
	var at: Transform3D = placed * (part["at"] as Transform3D)
	for n: int in from.size():
		var other: Dictionary = from[n]
		if other["key"] == part["key"] and other["path"] == path and other["shown"] == part["shown"] \
				and _same_step(part["step"], other["step"]) and _near(at, other["at"]):
			from.remove_at(n)
			return n
	return -1


## A step as the model put in had it, as it is now: the same, or none (a
## model in no steps) put in the first of a model in steps.
static func _same_step(was: int, now: int) -> bool:
	return was == now or (was < 0 and now == 0)


static func _near(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.05 and a.basis.x.distance_to(b.basis.x) < 0.001 \
		and a.basis.y.distance_to(b.basis.y) < 0.001 and a.basis.z.distance_to(b.basis.z) < 0.001


## [param path], a copy's in the model as it opens alone, as it is under
## [param copy] with its sub-models named by [param map].
static func _mapped(path: String, copy: String, map: Dictionary) -> String:
	var out: String = copy
	for segment: String in Assemblies.segments(path):
		var def: String = Assemblies.definition(segment)
		out = Assemblies.join(out, "%s#%d" % [map.get(def, def), Assemblies.copy_of(segment)])
	return out


static func _top(path: String) -> String:
	return Assemblies.segments(path)[0] if not path.is_empty() else ""


static func _defs(parts: Array, units: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for part: Dictionary in parts:
		for segment: String in Assemblies.segments(part["path"]):
			out[Assemblies.definition(segment)] = true
	for path: String in units:
		for segment: String in Assemblies.segments(path):
			out[Assemblies.definition(segment)] = true
	return out


static func _unshown(state: Dictionary) -> int:
	return (state["parts"] as Array).filter(func(p: Dictionary) -> bool: return not p["shown"]).size()


static func _words(part: Dictionary) -> String:
	return "%s in %s step %d%s" % [part["key"], part["path"], part["step"],
		"" if part["shown"] else " (not shown)"]


## The model as the app has it: each part on the baseplate and each it
## holds and cannot show ({key, path, step, at, shown}), each copy's step,
## and each sub-model's own lines.
func _state() -> Dictionary:
	var parts: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		parts.append({"key": "%s|%d" % [brick.part_id, brick.color_code],
			"path": Assemblies.path_of(brick), "step": brick.step, "at": brick.transform,
			"shown": true})
	# A build before the held parts' kinds (pathcarry) shows none of them.
	for pair: Array in (_store.call("_held_kinds") if _store.has_method("_held_kinds") else []):
		var placement: LdrModel.Placement = pair[0]
		parts.append({"key": "%s|%d" % [placement.part_id, placement.color_code],
			"path": _world.held_path(placement), "step": placement.step,
			"at": _store._held_world(placement, str(pair[1])), "shown": false})
	var lines: Variant = _world.get("section_lines")
	return {"parts": parts, "units": _world.unit_steps.duplicate(),
		"lines": (lines as Dictionary).duplicate(true) if lines is Dictionary else {}}


## What differs between two states, "" for nothing.
static func _difference(a: Dictionary, b: Dictionary) -> String:
	var left: Array = (b["parts"] as Array).duplicate()
	var gone: Array = []
	for part: Dictionary in a["parts"]:
		var found: bool = false
		for n: int in left.size():
			var other: Dictionary = left[n]
			if other["key"] == part["key"] and other["path"] == part["path"] \
					and other["step"] == part["step"] and other["shown"] == part["shown"] \
					and _near(part["at"], other["at"]):
				left.remove_at(n)
				found = true
				break
		if not found:
			gone.append(_words(part))
	var said := PackedStringArray()
	if not gone.is_empty():
		said.append("gone %s" % [gone.slice(0, 3)])
	if not left.is_empty():
		said.append("more %s" % [left.slice(0, 3).map(_words)])
	if a["units"] != b["units"]:
		said.append("steps %s -> %s" % [a["units"], b["units"]])
	if a["lines"] != b["lines"]:
		said.append("lines %s -> %s" % [(a["lines"] as Dictionary).keys(),
			(b["lines"] as Dictionary).keys()])
	return ", ".join(said)


## [param path] opened alone: the model as the app has it.
func _alone(path: String) -> Dictionary:
	await _open_path(path)
	return _state()


# -- acts --------------------------------------------------------------------------


## File, Import, Into this model…: its list open.
func _into_menu() -> void:
	var menu: MenuButton = _shell.menu("File")
	await _click(menu.get_global_rect().get_center())
	var popup: PopupMenu = menu.get_popup()
	var import: PopupMenu = null
	for child: Node in popup.get_children(true):
		if child is PopupMenu and child.name == "import":
			import = child
	var id: int = _shell.menu_id("import_into")
	_check("File, Import has Into this model…", popup.visible and import != null
		and import.get_item_index(id) >= 0
		and import.get_item_text(import.get_item_index(id)) == "Into this model…")
	import.id_pressed.emit(id)
	popup.hide()
	await _frames(10)
	var into: PopupMenu = _bar.get("_into")
	_check("...its list open", into != null and into.visible)


## File, Import, Into this model…, then [param name] from its list: in hand.
func _from_into_list(name: String) -> void:
	await _into_menu()
	var into: PopupMenu = _bar.get("_into")
	var id: int = -1
	for n: int in into.item_count:
		if into.get_item_text(n).begins_with(name + " — "):
			id = into.get_item_id(n)
	_check("...%s in it" % name, id >= 0)
	into.id_pressed.emit(id)
	into.hide()
	await _until_held()


func _until_held() -> void:
	for _n: int in 900:
		if _builder.is_carrying():
			break
		await process_frame
	await _frames(6)
	_check("in hand: %s" % Builder._many(_builder.carrying.items.size()),
		_builder.is_carrying())


## A click on a clear spot of the baseplate beside the model, as a person
## looks for one: the pointer over each spot of the view until the model in
## hand shows it can go down there on the ground, the view zoomed out with
## the wheel when none can.
func _put_down() -> void:
	if not _builder.is_carrying():
		return
	var view: Rect2 = _main.call("_model_rect")
	for zoom: int in 5:
		if await _put_in_view(view):
			return
		for _n: int in 3:
			_press(MOUSE_BUTTON_WHEEL_DOWN, view.get_center(), true)
			_press(MOUSE_BUTTON_WHEEL_DOWN, view.get_center(), false)
			await _frames(4)
		await _frames(20)
	_check("a clear spot to put it down", false)


func _put_in_view(view: Rect2) -> bool:
	var model := AABB()
	var any: bool = false
	for brick: BrickWorld.Brick in _world.bricks():
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null or _store.scenery.has(brick.id):
			continue
		var here: AABB = (brick.transform * mesh.bounds).abs()
		model = here if not any else model.merge(here)
		any = true
	var held: float = 0.0
	for item: Dictionary in _builder.carrying.items:
		var mesh: Lbm.PartMesh = _library.mesh_for(str(item["part"]))
		if mesh != null:
			var box: AABB = ((item["at"] as Transform3D) * mesh.bounds).abs()
			held = maxf(held, maxf(absf(box.end.x), absf(box.position.x)))
			held = maxf(held, maxf(absf(box.end.z), absf(box.position.z)))
	var spots: Array = []
	for along: float in [0.6, 1.0, 1.5, 2.2]:
		for side: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]:
			var reach: float = maxf(model.size.x, model.size.z) * along + held + 40.0
			var at: Vector3 = Vector3(model.get_center().x, 0.0, model.get_center().z) + side * reach
			if not _camera.is_position_behind(at):
				spots.append(_camera.unproject_position(at))
	for y: int in range(1, 8):
		for x: int in range(1, 10):
			spots.append(view.position + view.size * Vector2(x / 10.0, y / 8.0))
	for spot: Vector2 in spots:
		if not view.has_point(spot):
			continue
		await _move(spot)
		if _builder.carrying.can_place() and _on_ground():
			_press(MOUSE_BUTTON_LEFT, spot, true)
			await _frames(2)
			_press(MOUSE_BUTTON_LEFT, spot, false)
			await _frames(12)
			_check("put down with a click at %s of a %s window" % [spot.round(),
				DisplayServer.window_get_size()], not _builder.is_carrying())
			return true
	return false


## Whether the model in hand, where the pointer aims it, stands on the
## ground: its lowest cell on the floor's (Carry.stands_on_ground), read
## here so the probe runs on a build without it.
func _on_ground() -> bool:
	var carrying: Carry = _builder.carrying
	var whole: PackedInt32Array = carrying.call("_covers_for", _builder)[1]
	var frame: Transform3D = carrying.get("_frame")
	return not whole.is_empty() and Carry._lowest(whole) + roundi(frame.origin.y
		/ BrickLattice.CELL) == Builder.GROUND_CELL


func _as_event(at: Vector2) -> Vector2:
	return at * (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)


func _move(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.relative = motion.position - _pointer
	_pointer = motion.position
	Input.parse_input_event(motion)
	await _frames(3)


func _press(button: MouseButton, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_press(MOUSE_BUTTON_LEFT, at, true)
	await _frames(2)
	_press(MOUSE_BUTTON_LEFT, at, false)
	await _frames(8)


## The key the person's keymap gives [param action], pressed.
func _key_of(action: String) -> void:
	var accel: int = Keymap.key_of(action)
	_check("%s has a key" % action, accel != 0)
	var down: InputEventKey = Keymap.press_of(accel)
	Input.parse_input_event(down)
	await process_frame
	var up: InputEventKey = down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(20)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	await _frames(6)
	return text.replace("\n", " | ")


func _open_path(path: String) -> void:
	_builder.cancel_carry()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(10)


func _keep(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _file(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
