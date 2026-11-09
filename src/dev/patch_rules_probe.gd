## The patch of someone else's file and its gate, at their rules
## (keeptext5, kt5review's six fixes): SourceFile.patch and gate given a
## file and the parts as an edit left them.
##
##   godot --headless --path . --script src/dev/patch_rules_probe.gd
##
## 1. a copy of a sub-model named with two spaces in a row moved, then
##    turned: its line names it as the file does;
## 2. the gate holds a line to the file as written: a part painted black
##    written as 16 (which reads as 0 at the top of a file), its name
##    collapsed, its place's numbers written anew where it did not move, a
##    new part's colour as 16: each refused, the patch itself let through;
## 3. a comment saying START and END round a part ("0 Engine START") is no
##    pair: the part deleted, both kept; LeoCAD's GROUP BEGIN and END round
##    the only part of a group go with it;
## 4. the only copy of a sub-model deleted, and every part deleted: no
##    patch (live's write takes the sub-model out);
## 5. the first of two copies deleted (the second opens again as the
##    first): no patch; the second deleted: a patch the gate lets through;
## 6. a source patched on a worker and on this thread at once, this one
##    begun as the worker's has, each the first patch of the source, 24
##    times: the two the same each time. Read on first use, the second
##    found the tables being filled and patched from them half made.
extends SceneTree

var _fails: int = 0


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


## [param text] as an open makes it: its source and its parts as bricks.
func _opened(text: String) -> Array:
	var model: LdrModel = LdrModel.parse(text, "model")
	var placements: Array = model.flatten()
	var source: SourceFile = SourceFile.make(text, model, placements, {}, true)
	var bricks: Array = []
	for item: Variant in placements:
		var placement: LdrModel.Placement = item
		var brick := BrickWorld.Brick.new(bricks.size() + 1, placement.part_id,
			placement.color_code, placement.transform)
		brick.unit = placement.unit
		brick.group = placement.group
		brick.step = placement.step
		brick.origin = placement.origin
		bricks.append(brick)
	return [source, bricks, model.unit_steps.duplicate()]


## The patch's text for [param bricks], and the gate's word on it.
func _patched(source: SourceFile, bricks: Array, steps: Dictionary) -> Array:
	var plan: SourceFile.Plan = source.patch(bricks, Vector3.ZERO, {}, null, steps)
	if not plan.why.is_empty():
		return ["", plan.why]
	# As the store joins them (ModelStore._source_written).
	var text: String = "\n".join(plan.out)
	return [text, source.gate(plan, text, null, {}, steps)]


func _in(bricks: Array, unit: String) -> Array:
	return bricks.filter(func(b: BrickWorld.Brick) -> bool:
		return b.unit == unit or b.unit.begins_with(unit + "/"))


func _initialize() -> void:
	_names()
	_as_written()
	_pairs()
	_unplaced()
	_renumbered()
	_race()
	print("patch_rules probe: %s" % ("all checks passed" if _fails == 0 else "%d failed" % _fails))
	quit(1 if _fails > 0 else 0)


var WING: String = "\n".join(["0 FILE main.ldr", "0 Main", "0 Name: main.ldr",
	"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 16 0 -24 0 1 0 0 0 1 0 0 0 1 wing  part.ldr", "0 STEP", "0 NOFILE",
	"0 FILE wing  part.ldr", "0 Wing", "0 Name: wing  part.ldr",
	"1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat", "0 STEP", "0 NOFILE", ""])


func _names() -> void:
	var opened: Array = _opened(WING)
	var bricks: Array = opened[1]
	var wing: Array = _in(bricks, "Wing#1")
	for brick: BrickWorld.Brick in wing:
		brick.transform = Transform3D(brick.transform.basis, brick.transform.origin + Vector3(0, 0, 20))
	var got: Array = _patched(opened[0], bricks, opened[2])
	var moved: String = str(got[0]).split("\n")[4] if not str(got[0]).is_empty() else ""
	_check("a copy of \"wing  part.ldr\" moved: its line names it as the file does, the gate lets it through (%s: %s)"
		% [got[1], moved], got[1] == "" and moved == "1 16 0 -24 -20 1 0 0 0 1 0 0 0 1 wing  part.ldr")
	opened = _opened(WING)
	bricks = opened[1]
	for brick: BrickWorld.Brick in _in(bricks, "Wing#1"):
		brick.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, -24, 0)) \
			* Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)) * brick.transform
	got = _patched(opened[0], bricks, opened[2])
	var line: String = str(got[0]).split("\n")[4] if not str(got[0]).is_empty() else ""
	_check("the copy turned: its line written anew still names \"wing  part.ldr\" (%s: %s)" % [got[1], line],
		got[1] == "" and line.ends_with(" wing  part.ldr")
		and line != "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 wing  part.ldr")


func _as_written() -> void:
	var opened: Array = _opened(WING)
	var source: SourceFile = opened[0]
	var bricks: Array = opened[1]
	(bricks[0] as BrickWorld.Brick).color_code = 0
	var got: Array = _patched(source, bricks, opened[2])
	_check("a part painted black: its line says 0, the gate lets it through (%s)" % got[1],
		got[1] == "" and str(got[0]).contains("\n1 0 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"))
	var text: String = got[0]
	for wrong: Array in [
			["written as 16, which reads as 0 at the top of a file",
				"1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"],
			["its number written in capitals", "1 0 0 0 0 1 0 0 0 1 0 0 0 1 3001.DAT"],
			["its place written anew where it did not move", "1 0 0.0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"],
			["its turn written anew, turned as it was", "1 0 0 0 0 1.000 0 0 0 1 0 0 0 1 3001.dat"]]:
		var why: String = source.checked(text.replace("1 0 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", wrong[1]),
			bricks, Vector3.ZERO, {}, null, opened[2])
		_check("refused: %s (%s)" % [wrong[0], why], not why.is_empty())
	var moved: Array = _opened(WING)
	var copy: Array = _in(moved[1], "Wing#1")
	for brick: BrickWorld.Brick in copy:
		brick.transform = Transform3D(brick.transform.basis, brick.transform.origin + Vector3(0, 0, 20))
	var moved_text: String = _patched(moved[0], moved[1], moved[2])[0]
	var why: String = (moved[0] as SourceFile).checked(
		moved_text.replace(" -20 1 0 0 0 1 0 0 0 1 wing  part.ldr", " -20 1 0 0 0 1 0 0 0 1 wing part.ldr"),
		moved[1], Vector3.ZERO, {}, null, moved[2])
	_check("refused: the moved copy's name collapsed to \"wing part.ldr\" (%s)" % why, not why.is_empty())
	# A new part, black, at the top of the file.
	var fresh: Array = _opened(WING)
	var added := BrickWorld.Brick.new(99, "3005", 0, Transform3D(Basis.IDENTITY, Vector3(40, 0, 0)))
	added.step = 0
	(fresh[1] as Array).append(added)
	var fresh_got: Array = _patched(fresh[0], fresh[1], fresh[2])
	_check("a new black part: its line says 0, the gate lets it through (%s)" % fresh_got[1],
		fresh_got[1] == "" and str(fresh_got[0]).contains("1 0 40 0 0 1 0 0 0 1 0 0 0 1 3005.dat"))
	why = (fresh[0] as SourceFile).checked(str(fresh_got[0]).replace("1 0 40 0 0", "1 16 40 0 0"),
		fresh[1], Vector3.ZERO, {}, null, fresh[2])
	_check("refused: the new black part written as 16 (%s)" % why, not why.is_empty())


func _pairs() -> void:
	var file := "\n".join(["0 Pairs", "0 Name: pairs.ldr", "0 Engine START",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 Engine END",
		"1 4 80 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"0 !LEOCAD GROUP BEGIN Roof", "1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"0 !LEOCAD GROUP END", "1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP", ""])
	var opened: Array = _opened(file)
	var bricks: Array = (opened[1] as Array).filter(func(b: BrickWorld.Brick) -> bool:
		return not b.transform.origin.is_equal_approx(Vector3.ZERO))
	var got: Array = _patched(opened[0], bricks, opened[2])
	var text: String = got[0]
	_check("the part between \"0 Engine START\" and \"0 Engine END\" deleted: both kept (%s)" % got[1],
		got[1] == "" and text.contains("0 Engine START\n0 Engine END\n"))
	opened = _opened(file)
	bricks = (opened[1] as Array).filter(func(b: BrickWorld.Brick) -> bool:
		return b.color_code != 2)
	got = _patched(opened[0], bricks, opened[2])
	text = got[0]
	_check("the only part of LeoCAD's group Roof deleted: its BEGIN and END go with it (%s)" % got[1],
		got[1] == "" and not text.contains("GROUP BEGIN Roof") and not text.contains("GROUP END"))


func _unplaced() -> void:
	var opened: Array = _opened(WING)
	var bricks: Array = (opened[1] as Array).filter(func(b: BrickWorld.Brick) -> bool:
		return b.unit.is_empty())
	var got: Array = _patched(opened[0], bricks, opened[2])
	_check("the only copy of a sub-model deleted: no patch (%s)" % got[1],
		str(got[1]).contains("placed by no line"))
	opened = _opened("\n".join(["0 One", "0 Name: one.ldr", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP", ""]))
	got = _patched(opened[0], [], opened[2])
	_check("every part deleted: no patch (%s)" % got[1], str(got[1]).contains("no part is left"))
	# A sub-model the file never placed stays, and is no reason.
	var unused: String = WING + "\n".join(["0 FILE spare.ldr", "0 Spare",
		"1 7 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat", "0 NOFILE", ""])
	opened = _opened(unused)
	bricks = opened[1]
	(bricks[0] as BrickWorld.Brick).color_code = 14
	got = _patched(opened[0], bricks, opened[2])
	_check("a file with a sub-model it never placed, a part painted: a patch, the sub-model kept (%s)" % got[1],
		got[1] == "" and str(got[0]).contains("0 FILE spare.ldr"))


func _renumbered() -> void:
	var two := WING.replace("1 16 0 -24 0 1 0 0 0 1 0 0 0 1 wing  part.ldr\n",
		"1 16 0 -24 0 1 0 0 0 1 0 0 0 1 wing  part.ldr\n1 16 80 -24 0 1 0 0 0 1 0 0 0 1 wing  part.ldr\n")
	var opened: Array = _opened(two)
	var bricks: Array = (opened[1] as Array).filter(func(b: BrickWorld.Brick) -> bool:
		return not b.unit.begins_with("Wing#1"))
	var got: Array = _patched(opened[0], bricks, opened[2])
	_check("the first of two copies deleted, the second left to open as the first: no patch (%s)" % got[1],
		str(got[1]).contains("numbered one less"))
	opened = _opened(two)
	bricks = (opened[1] as Array).filter(func(b: BrickWorld.Brick) -> bool:
		return not b.unit.begins_with("Wing#2"))
	got = _patched(opened[0], bricks, opened[2])
	_check("the second deleted: a patch the gate lets through, the first's line kept (%s)" % got[1],
		got[1] == "" and str(got[0]).contains("1 16 0 -24 0 1 0 0 0 1 0 0 0 1 wing  part.ldr")
		and not str(got[0]).contains("1 16 80 -24 0"))


func _race() -> void:
	var lines := PackedStringArray(["0 FILE main.ldr", "0 Big", "0 Name: main.ldr"])
	for n: int in 4000:
		lines.append("1 %d %d %d 0 1 0 0 0 1 0 0 0 1 3001.dat" % [n % 15 + 1, (n % 40) * 40, -24 * (n / 40)])
		if n % 100 == 99:
			lines.append("0 STEP")
	lines.append("0 NOFILE")
	lines.append("")
	var text: String = "\n".join(lines)
	var differ: int = 0
	var refused: int = 0
	for round: int in 24:
		var opened: Array = _opened(text)
		var source: SourceFile = opened[0]
		var bricks: Array = opened[1]
		(bricks[round * 7] as BrickWorld.Brick).color_code = 14
		# This thread's patch begun just after the worker's has: on a source
		# read on first use, as the worker fills its tables.
		var on_worker: Array = [null]
		var started := Semaphore.new()
		var task: int = WorkerThreadPool.add_task(func() -> void:
			started.post()
			on_worker[0] = _patched(source, bricks, opened[2]))
		started.wait()
		var here: Array = _patched(source, bricks, opened[2])
		WorkerThreadPool.wait_for_task_completion(task)
		if here != on_worker[0]:
			differ += 1
		if not str(here[1]).is_empty() or not str((on_worker[0] as Array)[1]).is_empty():
			refused += 1
	_check("a source patched on a worker and here at once, 24 times: the two texts the same each time "
		+ "(%d differ) and each a patch (%d refused)" % [differ, refused], differ == 0 and refused == 0)
