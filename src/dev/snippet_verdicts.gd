## Whether each piece of the real-set index lays as it stands.
##
##   godot --headless --path . --script src/dev/snippet_verdicts.gd -- [--index=FILE] [--out=FILE]
##
## A real sub-model is not always a thing on its own: a part held by
## something outside it floats once it is cut out, and the checker
## refuses some real constructions (a curved slope seated on a stud of the
## part below, a clip on a bar). A design told to place_technique a piece
## that is then refused has spent a turn on it. So every piece square to
## the grid is read into placements the way place_technique reads it
## (Assistant._snippet_bricks), checked alone on an empty baseplate
## (Assistant._check), and the verdict written a line a piece to
## vendor/omr/snippet_verdicts.jsonl — {"id", "ok", "why"} — which
## tools/snippets.py build reads into the index as `lays`, and search
## ranks first. Not in the suite: a few minutes over the whole index.
extends SceneTree

var _index: String = RealSnippets.INDEX
var _out: String = "res://vendor/omr/snippet_verdicts.jsonl"


func _initialize() -> void:
	_run()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--index="):
			_index = argument.trim_prefix("--index=")
		elif argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	var document: Dictionary = RealSnippets.read(_index)
	if document.is_empty():
		print("no index at %s" % _index)
		quit(1)
		return
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
	await process_frame

	var out := FileAccess.open(_out, FileAccess.WRITE)
	var lays: int = 0
	var seen: int = 0
	var why_not: Dictionary = {}
	var started: int = Time.get_ticks_msec()
	for raw: Variant in document.get("entries", []):
		var entry: Dictionary = raw
		if not bool(entry.get("square", true)):
			continue
		seen += 1
		var laid: Variant = await assistant._snippet_bricks(entry, Vector3.ZERO, 0, {})
		var ok: bool = false
		var why: String = ""
		if laid is String:
			why = "unreadable"
		else:
			var model := Assistant.Model.new()
			for brick: Variant in laid:
				model.placements.append(Assistant.Placement.from_dict(brick))
			var verdict: Dictionary = assistant._check(model)
			ok = bool(verdict["ok"]) and int(verdict["pieces"]) == 1
			if not ok:
				var kinds: Array = verdict.get("kinds", [])
				why = ", ".join(PackedStringArray(kinds)) if not kinds.is_empty() \
					else "%d pieces" % int(verdict["pieces"])
		if ok:
			lays += 1
		else:
			why_not[why] = int(why_not.get(why, 0)) + 1
		out.store_line(JSON.stringify({"id": entry["id"], "ok": ok, "why": why}))
		if seen % 1000 == 0:
			print("  %d checked, %d lay, %.0f ms each" % [seen, lays,
				float(Time.get_ticks_msec() - started) / seen])
	out.close()
	print("%d of %d square pieces lay whole as they stand; the rest: %s"
		% [lays, seen, str(why_not)])
	quit(0)
