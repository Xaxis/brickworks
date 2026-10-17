## The window's side of sections (Sections): Suggest sections, a section
## broken out and put back, the exploded view, and a section evaluated on
## its own. The model tree (Outliner) shows the suggestions and their
## buttons; these are the commands behind them and the menus' items.
##
## All of it is the CAD's: none of it asks the assistant anything, and it
## is all there with the assistant switched off. The build check a section
## is put through alone is the one Brick Art and check_design use.
class_name SectionsUi
extends Node

## How long the exploded view takes to come apart or go back together.
const EXPLODE_SECONDS := 0.6

var shell: Shell
var sections: Sections

## The exploded view: each part's shift, all the way apart; how far apart
## it is now (0 together, 1 apart) and where it is going.
var _shifts: Dictionary = {}
var _share: float = 0.0
var _goal: float = 0.0
var _revision: int = -1
var _apart_count: int = 0

## The last section evaluated, for the page and a session.
var last_evaluation: Dictionary = {}
var _dialog: AcceptDialog
var _report: Label
var _evaluated: PackedInt64Array = PackedInt64Array()
var _evaluated_name: String = ""


func _ready() -> void:
	set_process(false)


# -- suggesting -----------------------------------------------------------------


## Suggest sections for the model (or the sub-assembly being edited), shown
## in the model tree. What the status bar says.
func suggest() -> String:
	# Said and counted, with Cancel: a big model is read on a worker.
	var job: Working.Job = Working.begin("Suggesting sections…", Sections.PHASES, true)
	await job.shown()
	var made: Array = await sections.suggest(job)
	job.end()
	if shell.outliner != null and not shell.outliner.is_open():
		shell.outliner.set_open(true)
	var said: String
	if made.is_empty():
		said = sections.why_none
	else:
		said = "%d sections suggested, in the model tree: accept, rename, merge or split them" \
			% made.size()
	shell.bar.say(said)
	return said


## Make the suggestions (all, or [param numbers]) sub-assemblies: one undo.
func accept(numbers: Array = []) -> String:
	var made: PackedStringArray = sections.accept(numbers)
	if made.is_empty():
		return "nothing to accept"
	shell.verbs.edited.call()
	var said: String = "made %d section%s: %s" % [made.size(), "" if made.size() == 1 else "s",
		", ".join(Array(made).map(func(path: String) -> String: return Assemblies.label(path)))]
	shell.bar.say(said)
	return said


# -- which section --------------------------------------------------------------


## The section the window's commands act on: the selected sub-assembly, or
## the one directly inside the level being edited that the selection is in.
func target() -> String:
	var assemblies: Assemblies = shell.assemblies
	var chosen: String = assemblies.selected_assembly()
	if not chosen.is_empty():
		return chosen
	var found: String = ""
	for brick_id: int in shell.builder.selection:
		var brick: BrickWorld.Brick = shell.world.get_brick(brick_id)
		if brick == null:
			continue
		var child: String = Sections._child_of(assemblies.entered, Assemblies.path_of(brick))
		if child.is_empty() or (not found.is_empty() and child != found):
			return ""
		found = child
	return found


func can_target() -> bool:
	return not target().is_empty()


# -- breaking out -------------------------------------------------------------------


## Break the chosen section out, or put it back when it is out.
func break_out_or_back(path: String = "") -> String:
	if path.is_empty():
		path = target()
	if path.is_empty():
		var said_none: String = ("select a section (a sub-assembly) to break out"
			if world_out().is_empty() else _put_back_all())
		shell.bar.say(said_none)
		return said_none
	_close_explode()
	var done: Dictionary
	if not sections.out_record(path).is_empty():
		done = sections.put_back(path)
	else:
		done = sections.break_out(path)
	if bool(done.get("ok", false)):
		shell.verbs.edited.call()
		_select(path)
		if done.has("bounds"):
			shell.camera.frame(done["bounds"] as AABB, 1.3)
		else:
			shell.camera.frame(shell.app.call("_built_bounds") as AABB, 1.15)
	shell.bar.say(str(done["words"]))
	return str(done["words"])


func put_back_all() -> String:
	var said: String = _put_back_all()
	shell.bar.say(said)
	return said


func _put_back_all() -> String:
	var names := PackedStringArray()
	for path: String in world_out().keys():
		var done: Dictionary = sections.put_back(path)
		if bool(done.get("ok", false)):
			names.append(Assemblies.label(path))
	if names.is_empty():
		return "nothing is broken out"
	shell.verbs.edited.call()
	shell.camera.frame(shell.app.call("_built_bounds") as AABB, 1.15)
	return "put back %s" % ", ".join(names)


func world_out() -> Dictionary:
	return shell.world.broken_out


func _select(path: String) -> void:
	var builder: Builder = shell.builder
	if Assemblies.parent_of(path) != shell.assemblies.entered:
		shell.assemblies.enter(Assemblies.parent_of(path))
	builder.selection.clear()
	for brick_id: int in shell.assemblies.ids_under(path):
		builder.selection[brick_id] = true
	builder.selection_changed.emit(builder.selection.size())


# -- the exploded view ----------------------------------------------------------------


func is_exploded() -> bool:
	return _goal > 0.0 or _share > 0.0


## Every section apart, animated, or back together.
func toggle_explode() -> String:
	if is_exploded():
		_goal = 0.0
		set_process(true)
		shell.bar.say("back together")
		return "back together"
	var groups: Array = sections.explode_groups()
	if groups.size() < 2:
		var none: String = "no sections to take apart: make sub-assemblies, or Suggest sections first"
		shell.bar.say(none)
		return none
	var apart: Dictionary = sections.exploded(1.0, groups)
	_shifts.clear()
	for brick_id: int in apart:
		var brick: BrickWorld.Brick = shell.world.get_brick(brick_id)
		if brick != null:
			_shifts[brick_id] = (apart[brick_id] as Transform3D).origin - brick.transform.origin
	_apart_count = groups.size()
	_revision = shell.world.revision
	_goal = 1.0
	set_process(true)
	_frame_apart(apart)
	var said: String = "%d sections apart — click one to choose it; the model is as it was. " \
		% groups.size() + "Shift+Y puts them back together"
	shell.bar.say(said)
	return said


## At once, with nothing drawn apart: the model changed under it.
func _close_explode() -> void:
	if not is_exploded():
		return
	_goal = 0.0
	_share = 0.0
	_shifts.clear()
	shell.world.set_drawn({})
	set_process(false)
	_frame_back()


## Where the view was before it was framed on the sections apart:
## [focus, distance, size]; [] when it was not.
var _view_was: Array = []


## The view framed on everything as it is drawn apart: lifted, Sungnyemun's
## roof went off the top of the window.
func _frame_apart(apart: Dictionary) -> void:
	var camera: CadCamera = shell.camera
	if camera == null:
		return
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in shell.world.bricks():
		if shell.store.scenery.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = shell.library.parts.get(brick.part_id)
		if info == null:
			continue
		var at: Transform3D = apart.get(brick.id, brick.transform)
		var drawn: AABB = at * info.bounds
		box = drawn if first else box.merge(drawn)
		first = false
	if first:
		return
	if _view_was.is_empty():
		_view_was = [camera._target_focus, camera._target_distance, camera.size]
	camera.frame(box, 1.15)


## And back to where it was, once together again.
func _frame_back() -> void:
	var camera: CadCamera = shell.camera
	if camera == null or _view_was.is_empty():
		return
	camera._target_focus = _view_was[0]
	camera._target_distance = _view_was[1]
	camera.size = _view_was[2]
	_view_was = []


## The part drawn under a ray while the sections are apart, or -1 when they
## are not: what a click picks (EditVerbs.brick_at), so a section is chosen
## where it is seen. The lattice asked once for each way the sections were
## moved, the ray moved back by it; the nearest part moved that way wins.
func pick_drawn(origin: Vector3, normal: Vector3) -> int:
	if not is_exploded() or _shifts.is_empty():
		return -1
	var eased: float = 1.0 - pow(1.0 - _share, 3.0)
	var by_shift: Dictionary = {Vector3.ZERO: true}
	for brick_id: int in _shifts:
		by_shift[_shifts[brick_id]] = true
	var best: int = 0
	var nearest: float = INF
	for shift: Vector3 in by_shift:
		var hit: BrickLattice.Hit = shell.builder.lattice.raycast(origin - shift * eased, normal)
		if not hit.is_valid() or hit.distance >= nearest:
			continue
		var moved: Vector3 = _shifts.get(hit.brick_id, Vector3.ZERO)
		if moved.is_equal_approx(shift):
			nearest = hit.distance
			best = hit.brick_id
	return best


## Where the section at [param path] is drawn: its box, apart when the view
## is apart. For the page (sections_flow) and a probe to point at.
func drawn_bounds(path: String) -> AABB:
	var box := AABB()
	var first: bool = true
	for brick_id: int in shell.assemblies.ids_under(path):
		var brick: BrickWorld.Brick = shell.world.get_brick(brick_id)
		var info: PartLibrary.PartInfo = shell.library.parts.get(brick.part_id) \
			if brick != null else null
		if info == null:
			continue
		var drawn: AABB = shell.world.drawn_at(brick) * info.bounds
		box = drawn if first else box.merge(drawn)
		first = false
	return box


func _process(delta: float) -> void:
	if _revision != shell.world.revision and is_exploded():
		_close_explode()
		return
	var was: float = _share
	_share = move_toward(_share, _goal, delta / EXPLODE_SECONDS)
	if is_equal_approx(was, _share) and _share == _goal:
		set_process(false)
		return
	if _share <= 0.0:
		shell.world.set_drawn({})
		_shifts.clear()
		set_process(false)
		_frame_back()
		return
	# Eased: quick away, slow to settle.
	var eased: float = 1.0 - pow(1.0 - _share, 3.0)
	var placed: Dictionary = {}
	for brick_id: int in _shifts:
		var brick: BrickWorld.Brick = shell.world.get_brick(brick_id)
		if brick != null:
			placed[brick_id] = brick.transform.translated((_shifts[brick_id] as Vector3) * eased)
	shell.world.set_drawn(placed)
	if _share >= 1.0 and _goal >= 1.0:
		set_process(false)


## Straight to apart or together, unanimated: what a probe draws.
func explode_now(apart: bool) -> void:
	if not apart:
		_goal = 0.0
		_share = 0.0
		_shifts.clear()
		shell.world.set_drawn({})
		set_process(false)
		_frame_back()
		return
	if not is_exploded():
		toggle_explode()
	_share = _goal
	if is_exploded():
		var placed: Dictionary = {}
		for brick_id: int in _shifts:
			var brick: BrickWorld.Brick = shell.world.get_brick(brick_id)
			if brick != null:
				placed[brick_id] = brick.transform.translated(_shifts[brick_id] as Vector3)
		shell.world.set_drawn(placed)
		set_process(false)


# -- evaluating -------------------------------------------------------------------------


## A section's numbers: the sub-assembly at [param path], or suggestion
## [param number]. The build check is run on it alone where the app has one.
func evaluate(path: String = "", number: int = 0) -> Dictionary:
	var ids := PackedInt64Array()
	var name: String = ""
	if number > 0:
		for made: Sections.Suggestion in sections.suggested:
			if made.number == number:
				ids = made.ids
				name = made.name
	else:
		if path.is_empty():
			path = target()
		if not path.is_empty():
			ids = shell.assemblies.ids_under(path)
			name = Assemblies.label(path)
	if ids.is_empty():
		return {}
	var job: Working.Job = Working.begin("Evaluating %s…" % name)
	await job.shown()
	var made: Dictionary = sections.evaluate(ids, name)
	made["path"] = path
	made["number"] = number
	# The build check, on it alone: the one check_design and Brick Art use.
	var assistant: Assistant = shell.app.get("_assistant")
	if assistant != null and int(made.get("parts", 0)) > 0:
		var model: Assistant.Model = assistant._model_from_world()
		var own: Dictionary = {}
		for brick_id: int in ids:
			own[brick_id] = true
		var kept: Array[Assistant.Placement] = []
		for placement: Assistant.Placement in model.placements:
			if own.has(placement.id):
				kept.append(placement)
		model.placements = kept
		var report: Dictionary = await assistant._checked(model, true)
		made["check"] = str(report.get("summary", ""))
		made["check_pieces"] = int(report.get("pieces", made["pieces"]))
		made["check_ok"] = bool(report.get("ok", false))
	job.end()
	last_evaluation = made
	_evaluated = ids
	_evaluated_name = name
	return made


## Evaluate the chosen section and show what it came to.
func show_evaluation(path: String = "", number: int = 0) -> void:
	var made: Dictionary = await evaluate(path, number)
	if made.is_empty():
		shell.bar.say("select a section (a sub-assembly), or a suggested one, to evaluate")
		return
	_open_dialog(made)
	shell.bar.say("%s: %d parts, %s" % [str(made["name"]), int(made["parts"]),
		str(made["weight"])])


func _open_dialog(made: Dictionary) -> void:
	if _dialog == null:
		_dialog = AcceptDialog.new()
		_dialog.ok_button_text = "Close"
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		_report = Label.new()
		_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_report.custom_minimum_size = Vector2(460, 0)
		column.add_child(_report)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var parts_list: Callable = func() -> void: shell.bar.say(write_list("parts"))
		var wanted_list: Callable = func() -> void: shell.bar.say(write_list("bricklink"))
		var its_booklet: Callable = func() -> void:
			_dialog.hide()
			await booklet()
		for button: Array in [["Parts list", "section_parts_list", parts_list],
				["BrickLink wanted list", "section_bricklink", wanted_list],
				["Its booklet", "section_booklet", its_booklet]]:
			var pressed := Button.new()
			pressed.text = str(button[0])
			pressed.name = str(button[1])
			pressed.pressed.connect(button[2])
			row.add_child(pressed)
		column.add_child(row)
		_dialog.add_child(column)
		add_child(_dialog)
	_dialog.title = "Section: %s" % str(made["name"])
	_report.text = Sections.evaluation_words(made)
	_dialog.popup_centered()


func is_showing() -> bool:
	return _dialog != null and _dialog.visible


## Everything of the model but the section last evaluated, and the baseplate.
func _rest() -> Dictionary:
	var own: Dictionary = {}
	for brick_id: int in _evaluated:
		own[brick_id] = true
	var rest: Dictionary = shell.store.scenery.duplicate()
	for brick: BrickWorld.Brick in shell.world.bricks():
		if not own.has(brick.id):
			rest[brick.id] = true
	return rest


## The section's parts list ("parts") or BrickLink wanted list
## ("bricklink"), written where Export writes.
func write_list(kind: String) -> String:
	if _evaluated.is_empty():
		return "evaluate a section first"
	var stock: Inventory = Inventory.of(shell.world, shell.library, _rest())
	if stock.lots.is_empty():
		return "nothing to list"
	var exports: Exports = shell.app.get("_exports")
	var folder: String = exports.folder if exports != null else ""
	var base: String = (shell.bar.model_name() + " " + _evaluated_name).to_snake_case()
	if kind == "bricklink":
		var made: Dictionary = ShopLists.bricklink_xml(stock, shell.library)
		return Exports._give(str(made["text"]), base + "_bricklink.xml", "application/xml",
			folder)
	return Exports._give(stock.to_text(_evaluated_name), base + "_parts.txt", "text/plain",
		folder)


## The section's own booklet: its steps, built on its own.
func booklet(to: String = "") -> String:
	if _evaluated.is_empty():
		return "evaluate a section first"
	if BookletMaker.busy:
		return "already drawing a booklet"
	if OS.has_feature("web") and to.is_empty():
		BookletMaker.open_tab()
	return await shell.app.call("_export_booklet", to, null, _rest(),
		"%s - %s" % [shell.bar.model_name(), _evaluated_name])


# -- for the page -------------------------------------------------------------------


## What a browser check reads (window.brickworksState.sections).
func page_state() -> Dictionary:
	var suggested: Array = []
	for made: Sections.Suggestion in sections.suggested:
		suggested.append(made.to_dict())
	var out: Dictionary = {}
	for path: String in shell.world.broken_out:
		out[path] = [((shell.world.broken_out[path] as Dictionary)["offset"] as Vector3).x,
			((shell.world.broken_out[path] as Dictionary)["offset"] as Vector3).y,
			((shell.world.broken_out[path] as Dictionary)["offset"] as Vector3).z]
	var evaluated: Dictionary = {}
	for key: String in ["name", "parts", "lots", "grams", "pieces", "check_pieces", "stands",
			"steps", "joins", "check"]:
		if last_evaluation.has(key):
			evaluated[key] = last_evaluation[key]
	return {"suggested": suggested, "why_none": sections.why_none, "out": out,
		"exploded": snappedf(_share, 0.01), "apart": _apart_count if is_exploded() else 0,
		"evaluated": evaluated, "report_open": is_showing(), "pose": pose()}


## Where every part stands, in short: the same string for the same places
## to the bit, so a browser check can tell a section put back from one not.
func pose() -> String:
	if _pose_at == shell.world.revision and not _pose.is_empty():
		return _pose
	var all := PackedStringArray()
	for brick: BrickWorld.Brick in shell.world.bricks():
		all.append("%d:%s" % [brick.id, var_to_str(brick.transform)])
	all.sort()
	_pose = "|".join(all).sha256_text().substr(0, 16)
	_pose_at = shell.world.revision
	return _pose


var _pose: String = ""
var _pose_at: int = -1
