## View, Stress against real sets that stand: how many of each set's parts
## read red (a joint past its working load) and amber (within twice it), and
## which, so each can be looked at.
##
##   godot --headless --path . --script src/dev/stress_sets.gd -- FILE.mpd ...
##
## Each file is opened as File, Open opens it and weighed as View, Stress
## weighs it (Stability.check with its margins). One line a set, then a line
## for each part that reads red or amber: the part, what it carries, on what,
## and where. A tool for measuring, not a check: it passes or fails nothing.
extends SceneTree

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
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
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	for path: String in OS.get_cmdline_user_args():
		if path.begins_with("--"):
			continue
		_weigh(path)
	quit(0)


func _weigh(path: String) -> void:
	_store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	var judge := Stability.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	judge.floor_ids = _store.scenery
	var began: int = Time.get_ticks_msec()
	var plain: Stability.Report = judge.check(_world)
	var plain_ms: int = Time.get_ticks_msec() - began
	judge.with_margins = true
	began = Time.get_ticks_msec()
	var weighed: Stability.Report = judge.check(_world)
	var margins_ms: int = Time.get_ticks_msec() - began
	var red: Array = []
	var amber: Array = []
	for id: int in weighed.margins:
		var one: Balance.JointLoad = weighed.margins[id]
		if one.ratio > 1.0:
			red.append(one)
		elif one.ratio > 0.5:
			amber.append(one)
	var held: Dictionary = {}
	for id: Variant in weighed.held:
		held[weighed.held[id]] = int(held.get(weighed.held[id], 0)) + 1
	print("%s: %d parts, %d bridge stud joints, %d red, %d amber, held otherwise %s; %s; check %d ms, with its margins %d ms" % [
		path.get_file(), _world.brick_count() - _store.scenery.size(), weighed.margins.size(),
		red.size(), amber.size(), JSON.stringify(held), plain.summary(), plain_ms, margins_ms])
	for one: Balance.JointLoad in red + amber:
		var brick: BrickWorld.Brick = _world.get_brick(one.beyond)
		print("    %s %s #%d (%s) %s %s #%d (%s): %.1f g on %d stud%s, margin %.2f, at %s%s" % [
			"RED  " if one.ratio > 1.0 else "amber", one.beyond_part, one.beyond,
			_name(one.beyond_part), "hanging from" if one.hangs else "on", one.held_part,
			one.held_by, _name(one.held_part), one.grams, one.studs, "" if one.studs == 1 else "s",
			1.0 / maxf(one.ratio, 0.000001), str(one.at.round()),
			" in %s" % Assemblies.path_of(brick) if brick != null and not Assemblies.path_of(brick).is_empty() else ""])
	for risk: Stability.Risk in plain.risks:
		print("    stability: %s %s" % [risk.kind, risk.message])


func _name(part_id: String) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(part_id)
	return info.name.strip_edges() if info != null else part_id
