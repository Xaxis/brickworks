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
		out.store_line(JSON.stringify({"file": file, "placed": placed,
			"ok": verdict["ok"], "summary": verdict["summary"],
			"why": str(verdict.get("feedback", "")).substr(0, 600),
			"bricks": bricks}))
	out.close()
	print("%d of %d build; refused: %s" % [passed, seen, str(refused)])
	quit(0)


func _clear(world: BrickWorld, builder: Builder) -> void:
	for brick: BrickWorld.Brick in world.bricks():
		builder.lattice.release(brick.id)
	world.clear()
