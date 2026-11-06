## Open real sets' sub-models in the app and ask whether they build.
##
##   tools/omr.py harvest lamp tree --out DIR
##   godot --headless --path . --script src/dev/harvest_probe.gd -- DIR
##
## Each .ldr in DIR is opened as a model, read back as the placements a
## design would write — studs, plates, face and turn — rebuilt from those
## on an empty baseplate and checked like a design. Writes
## DIR/verdicts.jsonl, one line a file, with the placements: a passing one
## is a worked example ready to copy into src/ai/techniques.gd.
##
## Not part of the suite: it needs the repository's files, which are not
## fetched by default. What it found, 2026-10-09: 96 of 162 real
## sub-models passed at first; the rest were real LEGO constructions the
## checker refused, so its false positives, listed. Most of the floating
## ones were plates hung under an overhang, which led to support being
## walked out from the ground; 110 pass now. The overlaps left are clips
## on bars and hollow studs, which the parts pipeline gives no connector.
##
## 2026-11-05, over the whole repository (1,056 sub-models, each stood on
## its lowest cell): 917 passed. A pane or a drawer in a frame its cover
## fills, and a part held by a joint BrickNet has no label for, were most of
## the rest; with the frame's air (ExactCheck.drop_in_air) and those joints
## in the exact graph, 939, none newly refused. Each verdict's "met" says
## which parts' overlaps and collisions refused it (docs/ROADMAP.md, "Round
## joints again").
extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("give the folder tools/omr.py harvest wrote, after --")
		quit(2)
		return
	var dir: String = args[0]
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	await process_frame

	var out := FileAccess.open(dir.path_join("verdicts.jsonl"), FileAccess.WRITE)
	var passed: int = 0
	var seen: int = 0
	var refused: Dictionary = {}
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".ldr"):
			continue
		_clear(world, builder)
		var placed: int = store.open(dir.path_join(file))
		for _n: int in 30:
			await process_frame
		var bricks: Array = []
		for put: Assistant.Placement in assistant._model_from_world().placements:
			bricks.append({"part": put.part, "color": put.color,
				"x": snappedf(put.x, 0.01), "y": snappedf(put.y, 0.01),
				"z": snappedf(put.z, 0.01), "face": put.face, "rot": put.rot})
		# Stood on its lowest cell. tools/omr.py lowers a sub-model onto its
		# lowest point, which leaves it off the 2 LDU grid, and read back
		# every part comes down to the cell under it: 61 of 1,056 stood a
		# cell below the floor, refused for it and for what stood on them,
		# and 10 hung above it (2026-11-05). The floor is the harvest's, not
		# the set's: the set has no floor there.
		var lowest: float = INF
		for raw: Dictionary in bricks:
			lowest = minf(lowest, float(raw["y"]))
		if not bricks.is_empty() and lowest != 0.0:
			for raw: Dictionary in bricks:
				raw["y"] = snappedf(float(raw["y"]) - lowest, 0.01)
		# Checked as a design on an empty baseplate. Read back from the
		# world they are bricks that were already standing, and the check
		# excuses those — every one of them passed that way.
		_clear(world, builder)
		var fresh := Assistant.Model.new()
		for raw: Dictionary in bricks:
			fresh.placements.append(Assistant.Placement.from_dict(raw))
		var verdict: Dictionary = assistant._check(fresh)
		seen += 1
		if bool(verdict["ok"]):
			passed += 1
		else:
			var why: String = str(verdict["summary"]).get_slice("(", 1).get_slice(" ", 0)
			refused[why] = int(refused.get(why, 0)) + 1
		# What met what, as part numbers: an overlap in the lattice, then a
		# collision of the exact shapes, [part, part it met] each, for the
		# record to count refusals by the kind of joint they are.
		var met: Array = []
		var overlapping: Dictionary = verdict.get("overlapping", {})
		for index: Variant in overlapping:
			var other: int = int(overlapping[index]) - 1
			if other >= 0 and other < bricks.size():
				met.append(["overlap", bricks[int(index)]["part"], bricks[other]["part"]])
		# The exact check says its pairs only in words: "brick 3 (3937 ...)
		# and brick 4 (3938 ...): their real shapes overlap".
		var pair := RegEx.create_from_string("^brick (\\d+) \\(\\S+ .*? and brick (\\d+) \\(")
		for said: Variant in (verdict.get("exact", {}) as Dictionary).get("collision", []):
			var found: RegExMatch = pair.search(str(said))
			if found != null:
				met.append(["collision", bricks[int(found.get_string(1))]["part"],
					bricks[int(found.get_string(2))]["part"]])
		out.store_line(JSON.stringify({"file": file, "placed": placed,
			"ok": verdict["ok"], "summary": verdict["summary"],
			"why": str(verdict.get("feedback", "")).substr(0, 600),
			"met": met, "bricks": bricks}))
	out.close()
	print("%d of %d build; refused: %s" % [passed, seen, str(refused)])
	quit(0)


func _clear(world: BrickWorld, builder: Builder) -> void:
	for brick: BrickWorld.Brick in world.bricks():
		builder.lattice.release(brick.id)
	world.clear()
