## What is set in the booklet comes back (pullkept, APP_UX6 #1).
##
##   godot --headless --path . --script src/dev/pullkept_probe.gd
##
## The MCP walk's pods session (bench/results/appux6-2026-11-07/mcp) pulled
## both wing plates out in step 1, saved the model as Pods, and opened it
## again: the pull was gone, without a word. The save had made the
## session's named assemblies sub-models (Assistant._tag_assemblies), each
## built in steps of its own, so the parts left the step the pull was on;
## the file kept the pull on the step that puts the side pod on, which the
## booklet builds where it stands and shows no page of.
##
## 1. Pods.ldr as the walk saved it (src/dev/fixtures/mcp_walk_pods.ldr), opened
##    as the session opened it: step 1 pulls 41770a and 41769a, as when it
##    was saved, and booklet_layout says so. Saved and opened again: the
##    same, and saved again the file is the same, byte for byte.
## 2. Every test model with booklet lines, opened, saved and opened, then
##    saved again: each booklet line (ROTSTEP, the app's own, a page's
##    picture) where it was in the file, byte for byte, and every part
##    where it was: every file of LDraw's model repository with one (the
##    117 with a ROTSTEP, the 44 whose authors turn the model among them),
##    the two fixtures with booklet lines, and a model given every kind of
##    booklet line over MCP. A shared model's carried pages (SharedPages'
##    PAGES and PAGE {...}) are not the booklet's: a save takes them off
##    and the share works them out again for the text it sends.
##
## A session may not save over a file it did not write (save_model), so
## each model opened over MCP is saved under a name of its own, then opened
## and saved again under that.
## 3. The pods session replayed over MCP: the pull set on step 1, the
##    model saved (its named assemblies made sub-models then) and opened
##    again: step 1 pulls both. Step 1's parts made a sub-assembly by
##    hand (Make a sub-assembly): the pull stays with them. A pull whose
##    parts another program took out of the file, and a step's look on a
##    step the booklet shows none of: kept in the file over a save, and not
##    named on open, as nothing in the app reaches either. A pull on a step
##    the booklet shows, of a part it does not add: named and kept.
## 4. The review's files (bench/results/pkreview-2026-11-07, here in
##    src/dev/fixtures/pullkept), each opened over MCP, saved, opened and
##    saved again: a pull whose parts two or three sub-models put in split
##    among the steps that add them (tie, three), followed two sub-models
##    down with the rest of its page (nested), left where it is when the
##    step it would go to has a pull, and not named, as no page shows the
##    step it is on (haspull), one sub-model put
##    on twice (twice), each part to the first step that adds it, one pull
##    however many steps add it (spread, pods_pull3003); a step another
##    program took the parts out of, every kind of line on it, kept in the
##    file as a step of its own, the booklet with no page for it and the
##    open naming none, in the app's own file and in someone else's
##    (empty_own, theirs_empty); a step of only a part the catalogue lacks,
##    its zoom kept on it (absent_only); the page rel-m268
##    saved with eleven kinds of line on the step that puts the side pod on,
##    all of them carried to the step that adds the wing plates
##    (pods_alllines); Pods with CRLF ends and with tabs between the fields
##    (pods_crlf, pods_tabs, pods_filetab); someone else's file with tabs
##    edited, saved and opened (theirs_tabs); a model of one step, as a
##    file and made over MCP (one_step, fresh). Of every step, booklet_layout
##    says it pulls out only parts it adds.
## 5. A step's last part taken off, over MCP and by hand (steps4): its look
##    goes with it, an undo brings both back, the part in its step, a redo
##    takes both again; saved and opened, the file has a step less and the
##    open names nothing.
## 6. Every file of 4 and the walk's Pods, opened, saved, opened, saved,
##    opened and saved: the same STEP count each save, every look with the
##    same parts at each open, and the second save and the third byte for
##    byte (pkreview's third review).
extends SceneTree

const PODS := "res://src/dev/fixtures/mcp_walk_pods.ldr"
const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const CREDIT := "res://tests/fixtures/omr_credit/346-2.published.ldr"
const FILES := "res://vendor/omr/files/"
## The 44 files whose authors turn the model over (buildturn_probe.TURNED):
## each must be among those read.
const TURNED := ["1572-1.mpd", "20009-1.mpd", "20019-1.mpd", "20021-1.mpd", "30051-1.mpd",
	"30052-1.mpd", "30055-1.mpd", "30542-1_Turkey.mpd", "30571-1.mpd", "358-1.mpd", "42084-1.mpd",
	"4837-1_Locomotive.mpd", "4837-1_Steam-Train.mpd", "4837-1_Train.mpd", "5540-1_Plane.mpd",
	"5934-1.mpd", "5973-1.mpd", "6822-1.mpd", "6870-1.mpd", "6927-1.mpd", "6929-1.mpd",
	"6991-1.mpd", "7131-1.mpd", "7140-1.mpd", "7141-1.mpd", "7150-1.mpd", "7667-1.mpd",
	"8028-1.mpd", "8029-1.mpd", "8031-1.mpd", "8033-1.mpd", "8154-1.mpd", "8258-1.mpd",
	"8272-1.mpd", "8273-1.mpd", "8273-1_Utility-Cargo-Truck.mpd", "8274-1_Dragstar.mpd",
	"8274-1.mpd", "8275-1.mpd", "891-1.mpd", "894-1.mpd", "918-1.mpd", "924-1.mpd", "928-1.mpd"]
## Pods' pull as the walk's file has it, and where its first save puts it.
const PODS_PULL := "the model step 1: 0 !BRICKWORKS PULL 2 41770a 41769a"
const PODS_PULL_MOVED := "side_pod.ldr step 1: 0 !BRICKWORKS PULL 2 41770a 41769a"
const WINGS: Array = ["41769a", "41770a"]
const MODELS := "user://models/"
const REVIEW := "res://src/dev/fixtures/pullkept/"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _socket: CommandSocket
var _rpc_id: int = 0
var _out: String = "user://pullkept/"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	DirAccess.make_dir_recursive_absolute(MODELS)
	DirAccess.make_dir_recursive_absolute(_out)
	var only: PackedStringArray = OS.get_environment("PULLKEPT_ONLY").split(",", false)
	if only.is_empty() or only.has("pods"):
		await _pods()
	if only.is_empty() or only.has("session"):
		await _session()
	if only.is_empty() or only.has("named"):
		await _named()
	if only.is_empty() or only.has("review"):
		await _review()
	if only.is_empty() or only.has("lines"):
		await _every_line()
	if only.is_empty() or only.has("files"):
		await _files()
	if only.is_empty() or only.has("emptied"):
		await _emptied()
	if only.is_empty() or only.has("loop"):
		await _loop()
	print("")
	if _failures == 0:
		print("pullkept probe: all checks passed")
	else:
		print("pullkept probe: %d checks failed" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- 1. the walk's Pods ---------------------------------------------------------


func _pods() -> void:
	print("\n1. Pods.ldr as the MCP walk saved it, opened as the session opened it")
	var text: String = FileAccess.get_file_as_string(PODS)
	if not _check("%s read: its pull on the step that puts the side pod on (%s)" % [PODS,
			"0 !BRICKWORKS PULL 2 41770a 41769a" if text.contains("PULL 2 41770a 41769a") else "none"],
			text.contains("0 !BRICKWORKS PULL 2 41770a 41769a")):
		return
	_write(MODELS + "Pods.ldr", text)
	_main.call("clear_model")
	await _frames(4)
	var opened: String = await _say("open_model", {"name": "Pods"})
	await _settled()
	print("    open_model: %s" % opened.left(200))
	await _step_one_pulls("opened")
	var saved: String = await _say("save_model", {"name": "PodsSaved.ldr"})
	print("    save_model: %s" % saved.left(120))
	var first: String = FileAccess.get_file_as_string(MODELS + "PodsSaved.ldr")
	_check("saved: the pull now on the side pod's first step, where its parts go in (%s)"
		% _pull_lines(first), _pull_lines(first) == PODS_PULL_MOVED)
	_main.call("clear_model")
	await _frames(4)
	opened = await _say("open_model", {"name": "PodsSaved"})
	await _settled()
	_check("opened again: nothing said to be left off (%s)" % opened.left(160),
		not opened.contains("matches no step"))
	await _step_one_pulls("opened again")
	await _say("save_model", {"name": "PodsSaved.ldr"})
	var second: String = FileAccess.get_file_as_string(MODELS + "PodsSaved.ldr")
	_check("saved again: the file byte for byte (%d bytes, %s)" % [second.length(),
		"the same" if second == first else _first_difference(first, second)], second == first)


## Step 1 of the booklet pulls both wing plates, by the plan and as
## booklet_layout tells a session.
func _step_one_pulls(when: String) -> void:
	var step: Instructions.Step = _step_numbered(1)
	var pull: Dictionary = {}
	if step != null:
		var look: Dictionary = BookletLooks.of(_world, step.authored_in, step.authored_step)
		pull = look.get("pull", {}) if look.get("pull") is Dictionary else {}
	var parts: Array = (pull.get("parts", []) as Array).duplicate()
	parts.sort()
	_check("%s: step 1 (%s, its step %d) pulls %s %s studs" % [when,
		"the model" if step == null or step.authored_in.is_empty() else step.authored_in,
		step.authored_step + 1 if step != null else 0, ", ".join(parts) if not parts.is_empty()
		else "nothing", BookletLooks._number(float(pull.get("studs", 0.0)))],
		parts == WINGS and is_equal_approx(float(pull.get("studs", 0.0)), 2.0))
	var layout: String = await _say("booklet_layout", {})
	var line: String = ""
	for each: String in layout.split("\n"):
		if each.strip_edges().begins_with("page ") and each.contains(": step"):
			line = each.strip_edges()
			break
	_check("...and booklet_layout says so: %s" % line.left(220),
		line.contains("1 (") and line.contains("41770a, 41769a pulled out 2 studs"))


# -- 3. the session replayed ----------------------------------------------------


func _session() -> void:
	print("\n3. the pods session replayed over MCP: the pull set on step 1, the model saved and opened")
	await _pods_session()
	var looks: Dictionary = _world.step_looks.duplicate(true)
	await _step_one_pulls("the pull set")
	var depth: int = _builder.history_depth()
	# Step 1's parts made a sub-assembly by hand, before the save.
	var ids: Array = []
	var first: Instructions.Step = _step_numbered(1)
	if first != null:
		ids = Array(first.brick_ids)
	_select_only(ids)
	_shell.run("make_submodel")
	await _frames(2)
	var named: String = _name_it("Wing pod")
	await _frames(4)
	var made: bool = _world.bricks().any(func(brick: BrickWorld.Brick) -> bool:
		return Assemblies.path_of(brick) == "Wing pod#1")
	_check("step 1's %d parts made a sub-assembly by hand (%s): %s" % [ids.size(), named,
		"made" if made else "not made"], made and ids.size() == 4)
	await _step_one_pulls("...the pull stays with them")
	while _builder.history_depth() > depth:
		_builder.undo()
	await _frames(2)
	_check("...undone: the looks as they were", _world.step_looks == looks)
	var saved: String = await _say("save_model", {"name": "PodsAgain.ldr"})
	print("    save_model: %s" % saved.left(120))
	await _step_one_pulls("saved, its named assemblies made sub-models")
	var text: String = FileAccess.get_file_as_string(MODELS + "PodsAgain.ldr")
	_check("...the file builds the side pod in the model's steps (%d IN lines) and pulls on its step (%s)"
		% [_lines_with(text, LdrModel.IN_META), _pull_lines(text)],
		_lines_with(text, LdrModel.IN_META) > 0
		and _pull_lines(text) == PODS_PULL)
	_main.call("clear_model")
	await _frames(4)
	var opened: String = await _say("open_model", {"name": "PodsAgain"})
	await _settled()
	print("    open_model: %s" % opened.left(160))
	await _step_one_pulls("opened again")
	var kept: Array = _parts_of()
	await _say("save_model", {"name": "PodsAgain.ldr"})
	var again: String = FileAccess.get_file_as_string(MODELS + "PodsAgain.ldr")
	_check("saved again: the file byte for byte (%s)" % ("the same" if again == text
		else _first_difference(text, again)), again == text)
	_main.call("clear_model")
	await _frames(4)
	await _say("open_model", {"name": "PodsAgain"})
	await _settled()
	_check("...and opened: its %d parts where they were, each in its step" % kept.size(),
		_parts_of() == kept)


## The walk's pods session up to the save, its calls as it made them.
func _pods_session() -> void:
	var calls: Array = [
		["clear_model", {}],
		["submit_design", {"name": "Little side pod", "description": "A small red side pod.",
			"floor": "none", "bricks": [{"part": "3032", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 1},
			{"part": "41770a", "color": 71, "x": 2, "y": 1, "z": 1},
			{"part": "3040", "color": 4, "x": 0, "y": 1, "z": 0, "rot": 2},
			{"part": "4070", "color": 4, "x": 0, "y": 1, "z": 5},
			{"part": "54200", "color": 4, "x": 0, "y": 4, "z": 5}],
			"assemblies": [{"name": "side pod", "x_from": 0, "x_to": 4, "z_from": 0, "z_to": 6}],
			"features": [], "brief": "a side pod"}],
		["mirror_parts", {"bricks": [2, 3, 4, 5, 6], "axis": "x", "copy": true, "picture": false}],
		["edit_model", {"add": [{"part": "3039", "color": 1, "x": 11, "y": 0, "z": 2}],
			"assemblies": [{"name": "blue slope", "x_from": 11, "x_to": 13, "z_from": 2, "z_to": 4}],
			"picture": false}],
		["split_parts", {"bricks": [12]}],
		["edit_steps", {"op": "list"}],
		["edit_booklet", {"step": 1, "pull": {"studs": 2, "parts": [3, 8]}}],
		["edit_booklet", {"step": 1, "colours_all": true}],
		["edit_model", {"add": [{"part": "3003", "color": 71, "x": 16, "y": 0, "z": 0}],
			"assemblies": [{"name": "grey block", "x_from": 16, "x_to": 24, "z_from": 0, "z_to": 6}],
			"picture": false}],
		["pattern_parts", {"bricks": [15], "columns": 4, "rows": 3, "levels": 2, "picture": false}],
	]
	for call: Array in calls:
		var said: String = await _say(str(call[0]), call[1])
		print("    %s: %s" % [call[0], said.get_slice("\n", 0).left(110)])


# -- 3. named on open ------------------------------------------------------------


func _named() -> void:
	print("\n3. what no step shows now, named on open and kept in the file")
	var text: String = FileAccess.get_file_as_string(PODS)
	# Another program took the two wing plates out of the side pod.
	var gone := PackedStringArray()
	for line: String in text.split("\n"):
		if line.ends_with("41769a.dat") or line.ends_with("41770a.dat"):
			continue
		gone.append(line)
	# Its pull is on the step that puts the side pod on, which the booklet
	# builds where it stands: no page shows it, so the open names it not.
	await _named_case("the wing plates taken out by another program", "\n".join(gone), "Wingless",
		"", "0 !BRICKWORKS PULL 2 41770a 41769a")
	# A zoom on the step that puts the side pod on, which the booklet builds
	# where it stands, and the side pod's first step set up already: the
	# pull goes there, the zoom stays.
	var zoomed: String = text.replace("0 !BRICKWORKS PULL 2 41770a 41769a\n",
		"0 !BRICKWORKS ZOOM 1.5\n0 !BRICKWORKS PULL 2 41770a 41769a\n")
	var pod: int = zoomed.find("\n0 STEP\n", zoomed.find("0 FILE side_pod.ldr"))
	zoomed = zoomed.insert(pod, "\n0 !BRICKWORKS SIZE 1.25")
	await _named_case("a zoom on the step that puts the side pod on, the side pod's first step sized",
		zoomed, "Zoomed", "", "0 !BRICKWORKS ZOOM 1.5")
	await _step_one_pulls("...and its pull on step 1 still")
	# A pull on a step the booklet shows, of a part it does not add: named,
	# as the step's page is there to set another on.
	var stepped: String = _fixture("steps4").replace("0 !BRICKWORKS ZOOM 1.5\n",
		"0 !BRICKWORKS ZOOM 1.5\n0 !BRICKWORKS PULL 2 3003\n")
	await _named_case("a pull on step 2 of a part step 2 does not add", stepped, "Misnamed",
		"the pull on step 2 of the model matches no step now, kept in the file",
		"0 !BRICKWORKS PULL 2 3003")


## [param text] opened as [param name] over MCP: the open says [param words]
## and the model's status line too (for "", neither names a look), and the
## saved file keeps [param line].
func _named_case(what: String, text: String, name: String, words: String, line: String) -> void:
	_write(MODELS + name + ".ldr", text)
	_main.call("clear_model")
	await _frames(4)
	var opened: String = await _say("open_model", {"name": name})
	await _settled()
	var bar_said: String = ModelBar.unshown_words(_store)
	if words.is_empty():
		_check("%s: open_model names no look (%s)" % [what, opened.get_slice("\n", 0).left(240)],
			not opened.get_slice("\n", 0).contains("matches no step"))
		_check("...nor the open's line in the window (%s)" % bar_said.left(160),
			not bar_said.contains("matches no step"))
	else:
		_check("%s: open_model says \"%s\" (%s)" % [what, words, opened.left(240)],
			opened.contains(words))
		_check("...and the open's line in the window says it too (%s)" % bar_said.left(160),
			bar_said.contains(words))
	await _say("save_model", {"name": name + "Saved.ldr"})
	var saved: String = FileAccess.get_file_as_string(MODELS + name + "Saved.ldr")
	_check("...saved: \"%s\" kept in the file, where it was (%s)" % [line, _where(saved, line)],
		_where(saved, line) == _where(text, line) and not _where(text, line).is_empty())


# -- 4. the review's files ------------------------------------------------------


func _review() -> void:
	print("\n4. the review's files (pkreview), each opened over MCP, saved, opened and saved again")
	await _review_case("tie", _fixture("tie"), {"a|1": _pulled(["3003"]), "b|1": _pulled(["3004"])},
		"", ["a.ldr step 2: 0 !BRICKWORKS PULL 2 3003", "b.ldr step 2: 0 !BRICKWORKS PULL 2 3004"])
	await _review_case("three", _fixture("three"), {"a|1": _pulled(["3003"]),
		"b|1": _pulled(["3004"]), "c|1": _pulled(["3010"])}, "",
		["a.ldr step 2: 0 !BRICKWORKS PULL 2 3003", "b.ldr step 2: 0 !BRICKWORKS PULL 2 3004",
		"c.ldr step 2: 0 !BRICKWORKS PULL 2 3010"])
	var nested: Dictionary = _pulled(["41770a", "41769a"])
	nested["zoom"] = 1.5
	await _review_case("nested", _fixture("nested"), {"w|0": nested}, "",
		["w.ldr step 1: 0 !BRICKWORKS ZOOM 1.5", "w.ldr step 1: 0 !BRICKWORKS PULL 2 41770a 41769a"])
	# The pull left on the step that puts a on, which no page shows: kept,
	# and not named.
	await _review_case("haspull", _fixture("haspull"), {"|1": _pulled(["3003"]),
		"a|1": _pulled(["3003"], 3.0)}, "", [])
	await _review_case("twice", _fixture("twice"), {"a|1": _pulled(["3003"])}, "",
		["a.ldr step 2: 0 !BRICKWORKS PULL 2 3003"])
	var empty: Dictionary = {"page": "new", "zoom": 1.5, "size": 1.25, "parts": false,
		"pull": {"studs": 3.0, "parts": ["3003"]}, "colours": true,
		"notes": [{"text": "Mind the arch", "at": [20.0, 150.0, 80.0, 12.0], "size": 5.0}]}
	for name: String in ["empty_own", "theirs_empty"]:
		await _review_case(name, _fixture(name), {"|1": empty}, "", [], 3)
	# Each part of a pull to the first step that adds it: one pull, not one
	# a step (pkreview's third review).
	await _review_case("spread", _fixture("spread"), {"a|0": _pulled(["3003"])}, "",
		["a.ldr step 1: 0 !BRICKWORKS PULL 2 3003"])
	# Its sections written whole in the order the model builds them, the
	# side pod's first (LdrModel._tree_of, copyfaults2 cfc_wing2).
	await _review_case("pods_pull3003", _fixture("pods_pull3003"), {"side pod|0":
		_pulled(["41770a", "41769a"]), "grey block|0": _pulled(["3003"])}, "",
		["side_pod.ldr step 1: 0 !BRICKWORKS PULL 2 41770a 41769a",
		"grey_block.ldr step 1: 0 !BRICKWORKS PULL 2 3003"])
	# A step whose one part the catalogue has not got: its zoom stays on it,
	# and the steps after it keep theirs.
	await _review_case("absent_only", _fixture("absent_only"), {"|1": {"zoom": 1.5},
		"|2": {"notes": [{"text": "Step three", "at": [20.0, 20.0, 60.0, 12.0], "size": 5.0}]},
		"|3": {"page": "new"}}, "", [])
	await _review_case("steps4", _fixture("steps4"), {"|1": {"zoom": 1.5,
		"notes": [{"text": "Step two", "at": [20.0, 20.0, 60.0, 12.0], "size": 5.0}]},
		"|2": {"page": "new"}}, "", [])
	var page: Dictionary = {"page": "new", "zoom": 1.5, "size": 1.25, "parts": false,
		"sign": false, "pull": {"studs": 2.0, "parts": ["41770a", "41769a"]},
		"actual_size": false, "panel": [9.0, 9.0, 122.5, 84.5],
		"place": {"picture": [120.0, 30.0, 120.0, 90.0]},
		"notes": [{"text": "Wings out", "at": [20.0, 150.0, 80.0, 12.0], "size": 5.0}],
		"arrows": [{"at": [40.0, 40.0, 90.0, 70.0], "colour": "black", "width": 0.9}]}
	var alllines: String = _fixture("pods_alllines")
	var carried: Array = _booklet_lines(alllines).filter(func(line: String) -> bool:
		return line.begins_with("the model step 1: ") and not line.ends_with("COLOURS ALL")) \
		.map(func(line: String) -> String:
			return line.replace("the model step 1: ", "side_pod.ldr step 1: "))
	await _review_case("pods_alllines", alllines, {"side pod|0": page}, "", carried)
	# Pods as the walk saved it, with CRLF ends, with tabs between the fields
	# of every FILE, STEP and part line, and with a tab after FILE alone.
	var pods: String = FileAccess.get_file_as_string(PODS)
	var tabbed := PackedStringArray()
	for line: String in pods.split("\n"):
		if line.begins_with("0 FILE ") or line == "0 STEP" or line.begins_with("1 "):
			line = line.replace(" ", "\t")
		tabbed.append(line)
	for each: Array in [["pods_crlf", pods.replace("\n", "\r\n")], ["pods_tabs", "\n".join(tabbed)],
			["pods_filetab", pods.replace("0 FILE ", "0 FILE\t")]]:
		await _review_case(str(each[0]), str(each[1]), {"side pod|0": _pulled(["41770a", "41769a"])},
			"", [PODS_PULL_MOVED])
	await _tabs_edited()
	await _review_case("one_step", _fixture("one_step"), {"|0": _pulled(["3020"])}, "", [])
	await _fresh()


## [param name] of the review's files.
static func _fixture(name: String) -> String:
	return FileAccess.get_file_as_string(REVIEW + name + ".ldr")


static func _pulled(parts: Array, studs: float = 2.0) -> Dictionary:
	return {"pull": {"studs": studs, "parts": parts}}


## [param text] opened over MCP as pk_NAME: each step's look [param looks],
## the open saying [param words] ("" for nothing left off), and of every
## step booklet_layout says it pulls out only parts it adds; saved (as
## pk_NAME_s) with the booklet lines [param lines] ([] for the file's own,
## where the file has them), opened again with the same looks and words,
## and saved again byte for byte. [param steps], when given, the steps the
## booklet has.
func _review_case(name: String, text: String, looks: Dictionary, words: String,
		lines: Array, steps: int = -1) -> void:
	print("\n  -- %s" % name)
	if not _check("%s: the file read (%d bytes)" % [name, text.length()], not text.is_empty()):
		return
	_write(MODELS + "pk_" + name + ".ldr", text)
	_main.call("clear_model")
	await _frames(4)
	var opened: String = await _say("open_model", {"name": "pk_" + name})
	await _settled()
	await _looks_are(name + " opened", looks, words, opened, steps)
	await _say("save_model", {"name": "pk_" + name + "_s.ldr"})
	var first: String = FileAccess.get_file_as_string(MODELS + "pk_" + name + "_s.ldr")
	var want: Array = lines if not lines.is_empty() else _booklet_lines(text)
	var got: Array = _booklet_lines(first).filter(func(line: String) -> bool:
		return not line.ends_with("COLOURS ALL"))
	want = want.filter(func(line: String) -> bool: return not line.ends_with("COLOURS ALL"))
	_check("...saved: its booklet lines %s" % ("as they should be (%d)" % got.size() if got == want
		else _first_line_difference(want, got)), got == want)
	_main.call("clear_model")
	await _frames(4)
	opened = await _say("open_model", {"name": "pk_" + name + "_s"})
	await _settled()
	await _looks_are("...opened again", looks, words, opened, steps)
	await _say("save_model", {"name": "pk_" + name + "_s.ldr"})
	var second: String = FileAccess.get_file_as_string(MODELS + "pk_" + name + "_s.ldr")
	_check("...saved again: the file byte for byte (%s)" % ("the same" if second == first
		else _first_difference(first, second)), second == first)


## The model's step looks are [param looks], [param opened] says
## [param words] or nothing left off, and booklet_layout says of no step it
## pulls out a part it does not add.
func _looks_are(when: String, looks: Dictionary, words: String, opened: String,
		steps: int = -1) -> void:
	var now: Dictionary = {}
	for name: String in _world.step_looks:
		if name.get_slice("|", 1).is_valid_int():
			now[name] = _world.step_looks[name]
	_check("%s: each step's look %s" % [when, "as it should be (%s)" % ", ".join(looks.keys())
		if _plain(now) == _plain(looks) else _first_look_difference(_plain(looks), _plain(now))],
		_plain(now) == _plain(looks))
	var left: String = opened.get_slice("\n", 0)
	if words.is_empty():
		_check("...nothing said to be left off (%s)" % left.left(200), not left.contains("matches no step"))
	else:
		_check("...said: \"%s\" (%s)" % [words, left.left(260)], left.contains(words))
	var layout: String = await _say("booklet_layout", {})
	var wrong := PackedStringArray()
	var told := PackedStringArray()
	var regex := RegEx.create_from_string("its ([a-z0-9_.-]+(?:, [a-z0-9_.-]+)*) pulled out")
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		if step.authored_step < 0:
			continue
		var said: String = BookletLooks.said(_world, step.authored_in, step.authored_step)
		var found: RegExMatch = regex.search(said)
		if found == null:
			continue
		var adds: Dictionary = {}
		for id: int in step.brick_ids:
			if _world.get_brick(id) != null:
				adds[_world.get_brick(id).part_id.to_lower()] = true
		var named: String = found.get_string(1)
		told.append("%d: %s" % [step.number, named])
		if named != "parts" and not Array(named.split(", ")).all(func(part: String) -> bool:
				return adds.has(part)):
			wrong.append("step %d pulls %s, adds %s" % [step.number, named, ", ".join(adds.keys())])
	_check("...booklet_layout says of no step that it pulls out a part it does not add (%s)"
		% ("; ".join(wrong) if not wrong.is_empty() else ", ".join(told) if not told.is_empty()
			else "no pulls drawn"), wrong.is_empty())
	if steps >= 0:
		var count: RegExMatch = RegEx.create_from_string("(\\d+) steps;").search(layout)
		var has: int = count.get_string(1).to_int() if count != null else -1
		_check("...the booklet has %d steps, none for the step with nothing in it (%s)" % [has,
			layout.get_slice("\n", 0).left(90)], has == steps)


## Someone else's file with tabs between its fields: a zoom and words on
## step 3, a pull on step 4, saved and opened again.
func _tabs_edited() -> void:
	print("\n  -- theirs_tabs, edited")
	var text: String = _fixture("theirs_tabs")
	_write(MODELS + "pk_tabs.ldr", text)
	_main.call("clear_model")
	await _frames(4)
	await _say("open_model", {"name": "pk_tabs"})
	await _settled()
	for edit: Dictionary in [{"step": 3, "zoom": 1.5},
			{"step": 3, "text": {"words": "Step three", "x": 20, "y": 20, "w": 60, "h": 12, "size": 5}},
			{"step": 4, "pull": {"studs": 2, "parts": ["3003"]}}]:
		print("    edit_booklet %s: %s" % [JSON.stringify(edit).left(60),
			(await _say("edit_booklet", edit)).get_slice("\n", 0).left(100)])
	var looks: Dictionary = _plain(_world.step_looks)
	_check("edited: step 3 zoomed with words, step 4 pulled (%s)" % ", ".join(looks.keys()),
		(looks.get("|2", {}) as Dictionary).has("zoom") and (looks.get("|3", {}) as Dictionary).has("pull"))
	await _say("save_model", {"name": "pk_tabs_s.ldr"})
	var saved: String = FileAccess.get_file_as_string(MODELS + "pk_tabs_s.ldr")
	var parts: Array = Array(text.split("\n")).filter(func(line: String) -> bool:
		return line.begins_with("1\t") or line.begins_with("0\tSTEP"))
	var kept: Array = Array(saved.split("\n")).filter(func(line: String) -> bool:
		return line.begins_with("1\t") or line.begins_with("0\tSTEP"))
	_check("saved: its part and STEP lines as they were, tabs and all (%d of %d)" % [kept.size(),
		parts.size()], kept == parts)
	_check("...and its booklet lines on steps 3 and 4 (%s)" % ", ".join(_booklet_lines(saved)),
		_booklet_lines(saved).any(func(line: String) -> bool:
			return line == "the model step 3: 0 !BRICKWORKS ZOOM 1.5")
		and _booklet_lines(saved).any(func(line: String) -> bool:
			return line == "the model step 4: 0 !BRICKWORKS PULL 2 3003"))
	_main.call("clear_model")
	await _frames(4)
	await _say("open_model", {"name": "pk_tabs_s"})
	await _settled()
	_check("opened again: every look as it was set (%s)" % _first_look_difference(looks,
		_plain(_world.step_looks)), _plain(_world.step_looks) == looks)


## A model of one step made over MCP, a pull set on it, saved and opened.
func _fresh() -> void:
	print("\n  -- a model of one step made over MCP")
	await _say("clear_model", {})
	var said: String = await _say("submit_design", {"name": "Second", "description": "Another pod.",
		"floor": "none", "bricks": [{"part": "3020", "color": 15, "x": 0, "y": 0, "z": 0},
		{"part": "3003", "color": 4, "x": 0, "y": 1, "z": 0},
		{"part": "3003", "color": 4, "x": 2, "y": 1, "z": 0},
		{"part": "3022", "color": 1, "x": 0, "y": 4, "z": 0}],
		"assemblies": [{"name": "side pod", "x_from": 0, "x_to": 2, "z_from": 0, "z_to": 2}],
		"features": [], "brief": "another"})
	print("    submit_design: %s" % said.get_slice("\n", 0).left(100))
	await _say("edit_steps", {"op": "list"})
	print("    edit_booklet: %s" % (await _say("edit_booklet", {"step": 1,
		"pull": {"studs": 2, "parts": ["3020"]}})).get_slice("\n", 0).left(100))
	var looks: Dictionary = _plain(_world.step_looks)
	await _say("save_model", {"name": "PkFresh.ldr"})
	var saved: String = FileAccess.get_file_as_string(MODELS + "PkFresh.ldr")
	_check("saved: one step, marked the author's, its pull in it (%d STEP lines, %s)" % [
		_lines_with(saved, "0 STEP"), _pull_lines(saved)], saved.contains(LdrModel.AUTHORED_META)
		and _pull_lines(saved).contains("PULL 2 3020"))
	_main.call("clear_model")
	await _frames(4)
	await _say("open_model", {"name": "PkFresh"})
	await _settled()
	_check("opened again: the pull on its step (%s)" % _first_look_difference(looks,
		_plain(_world.step_looks)), _plain(_world.step_looks) == looks and looks.has("|0"))


# -- 5. a step emptied ---------------------------------------------------------


## steps4's step 2, its only part (3001) set up with a zoom and words, taken
## off over MCP and by hand: the look goes with the part, an undo brings both
## back, the part in its step, a redo takes both again. Saved and opened:
## one step less in the file, nothing named, the same file saved again.
func _emptied() -> void:
	print("\n5. a step's last part taken off: its look goes with it, and comes back with an undo")
	var zoomed: Dictionary = {"zoom": 1.5,
		"notes": [{"text": "Step two", "at": [20.0, 20.0, 60.0, 12.0], "size": 5.0}]}
	for how: String in ["over MCP", "by hand"]:
		print("\n  -- %s" % how)
		_write(MODELS + "pk_steps4.ldr", _fixture("steps4"))
		_main.call("clear_model")
		await _frames(4)
		await _say("open_model", {"name": "pk_steps4"})
		await _settled()
		var looks: Dictionary = _plain(_world.step_looks)
		var ids: Array = []
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id == "3001":
				ids.append(brick.id)
		_check("opened: step 2 zoomed with words, its one part 3001 (%d), step 3 a new page (%s)" % [
			ids.size(), _first_look_difference({"|1": zoomed, "|2": {"page": "new"}}, looks)],
			ids.size() == 1 and looks == _plain({"|1": zoomed, "|2": {"page": "new"}}))
		if how == "over MCP":
			print("    edit_model remove %s: %s" % [str(ids), (await _say("edit_model",
				{"remove": ids, "picture": false})).get_slice("\n", 0).left(100)])
		else:
			_select_only(ids)
			_builder.remove_selection()
			await _frames(4)
		var gone: Dictionary = _plain(_world.step_looks)
		_check("taken off: step 2's look gone with it, step 3's kept (%s)" % _first_look_difference(
			{"|2": {"page": "new"}}, gone), gone == _plain({"|2": {"page": "new"}}))
		if how == "over MCP":
			print("    undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(100))
		else:
			await _shell.verbs.press("undo")
			await _frames(4)
		var back: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
			return brick.part_id == "3001")
		_check("undone: the look back (%s), and 3001 back in step 2 (%s)" % [
			_first_look_difference(looks, _plain(_world.step_looks)),
			", ".join(back.map(func(brick: BrickWorld.Brick) -> String: return "step %d" % (brick.step + 1)))],
			_plain(_world.step_looks) == looks and back.size() == 1 and (back[0] as BrickWorld.Brick).step == 1)
		if how == "over MCP":
			print("    redo: %s" % (await _say("undo", {"redo": true})).get_slice("\n", 0).left(100))
		else:
			await _shell.verbs.press("redo")
			await _frames(4)
		_check("redone: the part and the look gone again (%s)" % _first_look_difference(
			{"|2": {"page": "new"}}, _plain(_world.step_looks)),
			_plain(_world.step_looks) == _plain({"|2": {"page": "new"}})
			and not _world.bricks().any(func(brick: BrickWorld.Brick) -> bool:
				return brick.part_id == "3001"))
		var saved_as: String = "pk_steps4_%s" % ("mcp" if how == "over MCP" else "hand")
		await _say("save_model", {"name": saved_as + ".ldr"})
		var saved: String = FileAccess.get_file_as_string(MODELS + saved_as + ".ldr")
		_check("saved: 3 steps, 2 STEP lines (%d), step 2's lines gone, step 3's page now step 2's (%s)"
			% [_steps_in(saved), ", ".join(_booklet_lines(saved))], _steps_in(saved) == 2
			and _booklet_lines(saved) == ["the model step 2: 0 !BRICKWORKS PAGE NEW"])
		_main.call("clear_model")
		await _frames(4)
		var opened: String = await _say("open_model", {"name": saved_as})
		await _settled()
		_check("opened again: nothing named (%s)" % opened.get_slice("\n", 0).left(160),
			not opened.get_slice("\n", 0).contains("matches no step"))
		await _say("save_model", {"name": saved_as + ".ldr"})
		var again: String = FileAccess.get_file_as_string(MODELS + saved_as + ".ldr")
		_check("...saved again: the file byte for byte (%s)" % ("the same" if again == saved
			else _first_difference(saved, again)), again == saved)


# -- 6. saved and opened, three times -------------------------------------------


## Every file of the review's and the walk's Pods, as given and with CRLF
## ends and tabs, each opened, saved, opened, saved, opened and saved: each
## save has as many STEP lines, each open every look with the parts it had,
## and the second save and the third are the same, byte for byte.
func _loop() -> void:
	print("\n6. every file opened, saved, opened, saved, opened and saved")
	var files: Array = []
	for name: String in DirAccess.get_files_at(REVIEW):
		if name.ends_with(".ldr"):
			files.append([name.get_basename(), _fixture(name.get_basename())])
	files.sort()
	var pods: String = FileAccess.get_file_as_string(PODS)
	var tabbed := PackedStringArray()
	for line: String in pods.split("\n"):
		if line.begins_with("0 FILE ") or line == "0 STEP" or line.begins_with("1 "):
			line = line.replace(" ", "\t")
		tabbed.append(line)
	files.append_array([["pods_walk", pods], ["pods_crlf", pods.replace("\n", "\r\n")],
		["pods_tabs", "\n".join(tabbed)], ["pods_filetab", pods.replace("0 FILE ", "0 FILE\t")]])
	var held: int = 0
	for each: Array in files:
		var name: String = each[0]
		_write(MODELS + "pk_loop_" + name + ".ldr", str(each[1]))
		var opening: String = "pk_loop_" + name
		var saves: Array = []
		var seen: Array = []
		for _n: int in 3:
			_main.call("clear_model")
			await _frames(4)
			await _say("open_model", {"name": opening})
			await _settled()
			seen.append(_looks_with_parts())
			await _say("save_model", {"name": "pk_loop_%s_s.ldr" % name})
			saves.append(FileAccess.get_file_as_string(MODELS + "pk_loop_%s_s.ldr" % name))
			opening = "pk_loop_%s_s" % name
		var counts: Array = saves.map(func(text: String) -> int: return _steps_in(text))
		var looks: int = (seen[0] as Array).size()
		var ok: bool = counts[0] == counts[1] and counts[1] == counts[2] \
			and seen[0] == seen[1] and seen[1] == seen[2] and saves[1] == saves[2]
		if ok:
			held += 1
		_check("%s: STEP lines %s (the file %d); %d looks, each with its parts at every open%s; "
			% [name, "/".join(counts.map(func(count: int) -> String: return str(count))),
			_steps_in(str(each[1])), looks, "" if seen[0] == seen[1] and seen[1] == seen[2]
			else " NOT: " + _first_seen_difference(seen)]
			+ "the second save and the third %s" % ("the same" if saves[1] == saves[2]
			else _first_difference(saves[1], saves[2])), ok)
	_check("every file held over three saves: %d of %d" % [held, files.size()], held == files.size())


## Each step look with the parts its step holds, by definition in the order
## of its steps, the numbers left out (a save numbers them again):
## [definition, the look, its parts], each part "part colour", those not on
## the baseplate (on their way, or the catalogue lacks) among them.
func _looks_with_parts() -> Array:
	var parts: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id) or brick.step < 0:
			continue
		(parts.get_or_add(BookletLooks.key(BookletLooks.definition_of(AuthorSteps.home(_world,
			Assemblies.path_of(brick))), brick.step), []) as Array).append(
				"%s %d" % [brick.part_id.to_lower(), brick.color_code])
	var held: Array = []
	held.append_array(_store.awaited)
	held.append_array(_store.get("_absent"))
	for item: Variant in held:
		var placement: LdrModel.Placement = item
		if placement.step >= 0:
			(parts.get_or_add(BookletLooks.key(BookletLooks.definition_of(AuthorSteps.home(_world,
				Assemblies.path_from(placement.group, placement.unit))), placement.step), []) as Array) \
				.append("%s %d" % [placement.part_id.to_lower(), placement.color_code])
	var plain: Dictionary = _plain(_world.step_looks)
	var names: Array = plain.keys().filter(func(name: String) -> bool:
		return name.get_slice("|", 1).is_valid_int())
	names.sort_custom(func(a: String, b: String) -> bool:
		return a.get_slice("|", 0) < b.get_slice("|", 0) or a.get_slice("|", 0) \
			== b.get_slice("|", 0) and a.get_slice("|", 1).to_int() < b.get_slice("|", 1).to_int())
	var out: Array = []
	for name: String in names:
		var those: Array = (parts.get(name, []) as Array).duplicate()
		those.sort()
		out.append([name.get_slice("|", 0), plain[name], those])
	return out


## The first look of three opens ([method _looks_with_parts]) that differs.
static func _first_seen_difference(seen: Array) -> String:
	for n: int in [1, 2]:
		var a: Array = seen[0]
		var b: Array = seen[n]
		for k: int in maxi(a.size(), b.size()):
			var p: String = JSON.stringify(a[k]) if k < a.size() else "(none)"
			var q: String = JSON.stringify(b[k]) if k < b.size() else "(none)"
			if p != q:
				return "open %d, look %d: %s then %s" % [n + 1, k + 1, p.left(160), q.left(160)]
	return "the same"


## How many lines end a step: STEP and ROTSTEP, tabs or spaces between.
static func _steps_in(text: String) -> int:
	return Array(text.split("\n")).filter(func(line: String) -> bool:
		var fields: PackedStringArray = LdrModel._fields(line.strip_edges())
		return fields.size() >= 2 and fields[0] == "0" \
			and fields[1].to_upper() in ["STEP", "ROTSTEP"]).size()


# -- 2. every kind of booklet line ----------------------------------------------


## A model given every kind of booklet line over MCP, saved, opened and
## saved again: every line where it was, byte for byte, and every look as
## it was.
func _every_line() -> void:
	print("\n2. the gatehouse given every kind of booklet line over MCP, saved, opened, saved")
	var text: String = FileAccess.get_file_as_string(GATEHOUSE)
	_write(MODELS + "Lined.ldr", text)
	_main.call("clear_model")
	await _frames(4)
	await _say("open_model", {"name": "Lined"})
	await _settled()
	var image := Image.create(40, 30, false, Image.FORMAT_RGB8)
	image.fill(Color8(40, 120, 200))
	var picture: String = Marshalls.raw_to_base64(image.save_png_to_buffer())
	# The step that puts the yellow brick in, the one after it, and the step
	# that puts the windows on, by what each holds.
	var yellow: int = 0
	var windows: int = 0
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		if step.callout_step != 0:
			continue
		if yellow == 0 and Array(step.brick_ids).any(func(id: int) -> bool:
				return _world.get_brick(id) != null and _world.get_brick(id).part_id == "3003"):
			yellow = step.number
		if step.attaches() and step.times == 2:
			windows = step.number
	_check("the gatehouse opened: its yellow brick in step %d, its windows put on in step %d"
		% [yellow, windows], yellow > 0 and windows > yellow + 1)
	var edits: Array = [
		{"step": yellow, "page": "new", "zoom": 1.5, "size": 1.25, "parts": false},
		{"step": yellow, "pull": {"studs": 3, "parts": ["3003"]}, "colours": true, "actual_size": false},
		{"step": yellow, "sign": false},
		{"step": yellow + 1, "turn": 45, "tilt": 15},
		{"step": yellow + 1, "place": {"item": "picture", "x": 120, "y": 30, "w": 120, "h": 90}},
		{"step": yellow + 1, "text": {"words": "Mind the arch", "x": 20, "y": 150, "w": 80, "h": 12,
			"size": 5}},
		{"step": yellow + 1, "arrow": {"x1": 40, "y1": 40, "x2": 90, "y2": 70, "colour": "black"}},
		{"step": windows, "per_page": 2, "colours_all": true},
		{"step": windows, "guide": {"axis": "x", "at": 120}},
		{"step": windows, "callout": false},
		{"step": windows, "preview": false},
	]
	for edit: Dictionary in edits:
		var said: String = await _say("edit_booklet", edit)
		print("    edit_booklet %s: %s" % [JSON.stringify(edit).left(70), said.get_slice("\n", 0).left(90)])
	print("    page_setup: %s" % (await _say("page_setup", {"size": "A4", "orientation": "portrait",
		"picture_data": picture})).get_slice("\n", 0).left(90))
	var looks: Dictionary = _world.step_looks.duplicate(true)
	await _say("save_model", {"name": "LinedSaved.ldr"})
	var first: String = FileAccess.get_file_as_string(MODELS + "LinedSaved.ldr")
	var kinds := PackedStringArray()
	for word: String in BookletLooks.WORDS:
		if first.contains(BookletLooks.META + word + " "):
			kinds.append(word)
	if first.contains("0 ROTSTEP"):
		kinds.append("ROTSTEP")
	if first.contains("0 !DATA " + BookletLooks.IMAGE_PREFIX):
		kinds.append("!DATA")
	print("    the file's booklet lines: %d (%s)" % [_booklet_lines(first).size(), ", ".join(kinds)])
	_check("saved with %d kinds of booklet line" % kinds.size(), kinds.size() >= 14)
	var parts: Array = _parts_of()
	_main.call("clear_model")
	await _frames(4)
	await _say("open_model", {"name": "LinedSaved"})
	await _settled()
	# A turn read from the file keeps the file's own ROTSTEP line with it
	# ("line"), to write it back as it was; numbers come back as JSON's.
	_check("opened: every step's look as it was set (%d: %s)" % [looks.size(),
		_first_look_difference(_plain(looks), _plain(_world.step_looks))],
		JSON.stringify(_plain(_world.step_looks), "", true) == JSON.stringify(_plain(looks), "", true))
	_check("...every part where it was (%d)" % parts.size(), _parts_of() == parts)
	await _say("save_model", {"name": "LinedSaved.ldr"})
	var second: String = FileAccess.get_file_as_string(MODELS + "LinedSaved.ldr")
	_check("saved again: every booklet line where it was, byte for byte (%d)"
		% _booklet_lines(second).size(), _booklet_lines(second) == _booklet_lines(first))
	_check("...and the file byte for byte (%s)" % ("the same" if second == first
		else _first_difference(first, second)), second == first)


# -- 2. the test models with booklet lines ------------------------------------------


## Each test model with booklet lines opened, saved, opened and saved
## again: its booklet lines where the file had them, byte for byte, and
## every part where it was.
func _files() -> void:
	print("\n2. every test model with booklet lines, opened, saved, opened and saved again")
	var named: Array = [["pods.ldr", PODS], ["gatehouse.mpd", GATEHOUSE],
		["346-2.published.ldr", CREDIT]]
	var listed: Dictionary = {}
	var found: PackedStringArray = DirAccess.get_files_at(FILES)
	found.sort()
	for name: String in found:
		if not _booklet_lines(FileAccess.get_file_as_string(FILES + name)).is_empty():
			named.append([name, FILES + name])
			listed[name] = true
	var turned: Array = TURNED.filter(func(name: String) -> bool: return listed.has(name))
	_check("LDraw's model repository: %d of %d files with booklet lines, the %d of %d whose authors turn the model among them"
		% [listed.size(), found.size(), turned.size(), TURNED.size()],
		turned.size() == TURNED.size() and listed.size() >= 100)
	var files: int = 0
	var lines: int = 0
	var kept_lines: int = 0
	var parts: int = 0
	var wrong := PackedStringArray()
	var started: int = Time.get_ticks_msec()
	for each: Array in named:
		var text: String = FileAccess.get_file_as_string(str(each[1]))
		if text.is_empty():
			wrong.append("%s missing" % each[0])
			continue
		files += 1
		var title: String = str(each[0]).get_basename()
		_main.call("clear_model")
		await _frames(2)
		var bar: ModelBar = _main.get("_bar")
		await bar.open_text_with_progress(text, title)
		await _settled()
		var opened: Array = _parts_of()
		var path: String = _out.path_join(str(each[0]))
		_store.save_file(path, title)
		var first: String = FileAccess.get_file_as_string(path)
		_main.call("clear_model")
		await _frames(2)
		await bar.open_text_with_progress(first, title)
		await _settled()
		var reopened: Array = _parts_of()
		_store.save_file(path, title)
		var second: String = FileAccess.get_file_as_string(path)
		var was: Array = _booklet_lines(text)
		var now: Array = _booklet_lines(first)
		lines += was.size()
		parts += opened.size()
		# Pods' pull goes where its parts go in at its first save; from then
		# on it stays. The lines in file order, so compared as sets there.
		var same: bool = now == was
		if each[0] == "pods.ldr":
			var expected: Array = was.map(func(line: String) -> String:
				return PODS_PULL_MOVED if line == PODS_PULL else line)
			var got: Array = now.duplicate()
			expected.sort()
			got.sort()
			same = got == expected and was.has(PODS_PULL)
		if same:
			kept_lines += was.size()
		var why := PackedStringArray()
		if not same:
			why.append("booklet lines %s" % _first_line_difference(was, now))
		if _booklet_lines(second) != now:
			why.append("second save's booklet lines %s" % _first_line_difference(now,
				_booklet_lines(second)))
		if second != first:
			why.append("second save %s" % _first_difference(first, second))
		if reopened != opened:
			why.append("parts %d -> %d%s" % [opened.size(), reopened.size(),
				_first_part_difference(opened, reopened)])
		print("    %-34s %4d booklet lines, %5d parts%s" % [each[0], was.size(), opened.size(),
			"" if why.is_empty() else ": " + "; ".join(why)])
		if not why.is_empty():
			wrong.append("%s (%s)" % [each[0], "; ".join(why).left(200)])
	_check("%d files, %d booklet lines and %d parts in %.0f s: every booklet line kept over open, save and open, byte for byte (%d of %d), and every part where it was%s"
		% [files, lines, parts, (Time.get_ticks_msec() - started) / 1000.0, kept_lines, lines,
		"" if wrong.is_empty() else "; not: " + ", ".join(wrong).left(1500)],
		wrong.is_empty() and files == named.size())


# -- reading the file and the model ---------------------------------------------


## Every booklet line of [param text] with where it is: "file step n: line".
static func _booklet_lines(text: String) -> Array:
	var out: Array = []
	var file: String = "the model"
	var seen_file: bool = false
	var step: int = 1
	var in_data: bool = false
	for raw: String in text.split("\n"):
		# Its fields as LdrModel reads them, tabs or spaces between.
		var line: String = " ".join(LdrModel._fields(raw.strip_edges()))
		var upper: String = line.to_upper()
		if upper.begins_with("0 FILE "):
			# The model's own section by what it is: a save names it after
			# the model's title (pods.ldr's model.ldr saved as pods).
			file = "the model" if not seen_file else line.substr(7).strip_edges().to_lower()
			seen_file = true
			step = 1
			in_data = false
			continue
		if upper.begins_with("0 !DATA "):
			in_data = line.to_lower().contains(BookletLooks.IMAGE_PREFIX)
			if in_data:
				out.append("%s: %s" % [file, line])
			continue
		if in_data and line.begins_with("0 !:"):
			out.append("%s: %s" % [file, line])
			continue
		in_data = false
		var booklet: bool = upper.begins_with("0 ROTSTEP")
		# A shared model's carried pages (SharedPages) are the share's.
		if line.begins_with(BookletLooks.META) and not line.begins_with(SharedPages.PAGE + "{"):
			var word: String = line.substr(BookletLooks.META.length()).get_slice(" ", 0)
			booklet = word in BookletLooks.WORDS
		if booklet:
			out.append("%s step %d: %s" % [file, step, raw.trim_suffix("\r")])
		if upper == "0 STEP" or upper.begins_with("0 ROTSTEP"):
			step += 1
	return out


## The pull lines of [param text] with where each is.
static func _pull_lines(text: String) -> String:
	return ", ".join(_booklet_lines(text).filter(func(line: String) -> bool:
		return line.contains("!BRICKWORKS PULL")))


## Where [param line] is in [param text]'s booklet lines, "" when it is not.
static func _where(text: String, line: String) -> String:
	for each: String in _booklet_lines(text):
		if each.ends_with(": " + line):
			return each
	return ""


static func _lines_with(text: String, words: String) -> int:
	return Array(text.split("\n")).filter(func(line: String) -> bool:
		return line.begins_with(words)).size()


static func _first_difference(a: String, b: String) -> String:
	var x: PackedStringArray = a.split("\n")
	var y: PackedStringArray = b.split("\n")
	for n: int in maxi(x.size(), y.size()):
		var p: String = x[n] if n < x.size() else "(end)"
		var q: String = y[n] if n < y.size() else "(end)"
		if p != q:
			return "line %d: \"%s\" then \"%s\"" % [n + 1, p.left(70), q.left(70)]
	return "the same"


## [param looks] as the file says them: without the ROTSTEP line a turn
## read from a file keeps, each number as JSON reads it, keys in order.
static func _plain(looks: Dictionary) -> Dictionary:
	var out: Dictionary = JSON.parse_string(JSON.stringify(looks, "", true))
	for name: String in out:
		if out[name] is Dictionary:
			(out[name] as Dictionary).erase("line")
	return JSON.parse_string(JSON.stringify(out, "", true))


## Each look [param b] has otherwise than [param a]: "key: was then now".
static func _first_look_difference(a: Dictionary, b: Dictionary) -> String:
	var names: Array = a.keys()
	for name: String in b.keys():
		if not names.has(name):
			names.append(name)
	names.sort()
	var said := PackedStringArray()
	for name: String in names:
		var p: String = JSON.stringify(a.get(name), "", true) if a.has(name) else "(none)"
		var q: String = JSON.stringify(b.get(name), "", true) if b.has(name) else "(none)"
		if p != q:
			said.append("%s: %s then %s" % [name, p.left(300), q.left(300)])
	return "the same" if said.is_empty() else "; ".join(said)


static func _first_line_difference(a: Array, b: Array) -> String:
	for n: int in maxi(a.size(), b.size()):
		var p: String = str(a[n]) if n < a.size() else "(none)"
		var q: String = str(b[n]) if n < b.size() else "(none)"
		if p != q:
			return "%d of %d, then %d: \"%s\" then \"%s\"" % [n + 1, a.size(), b.size(), p.left(80),
				q.left(80)]
	return "the same"


static func _first_part_difference(a: Array, b: Array) -> String:
	for n: int in mini(a.size(), b.size()):
		if a[n] != b[n]:
			return ", first \"%s\" then \"%s\"" % [a[n], b[n]]
	return ""


## Every part of the model: its part, colour, step and place, sorted.
func _parts_of() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var at: Vector3 = brick.transform.origin
		out.append("%s %d %s#%d %.2f %.2f %.2f" % [brick.part_id, brick.color_code,
			AuthorSteps.home(_world, Assemblies.path_of(brick)), brick.step, at.x, at.y, at.z])
	out.sort()
	return out


func _step_numbered(number: int) -> Instructions.Step:
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		if step.number == number and step.callout_step == 0:
			return step
	return null


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


## The naming dialog Make a sub-assembly opened, [param name] typed in it and
## OK pressed.
func _name_it(name: String) -> String:
	var verbs: Node = _shell.verbs
	var field: LineEdit = verbs.get("_name_field") if verbs != null else null
	var dialog: ConfirmationDialog = verbs.get("_naming") if verbs != null else null
	if field == null or dialog == null or not dialog.visible:
		return "no naming dialog"
	field.text = name
	dialog.hide()
	dialog.confirmed.emit()
	_shell.assemblies.leave_to("")
	return "named %s" % name


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Every part to hand, and the frames after.
func _settled() -> void:
	for _n: int in 600:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(6)


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


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
