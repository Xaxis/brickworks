## How many pieces our check finds a design in, against BrickNet's graph.
##
##   godot --headless --path . --script src/dev/pieces_agree.gd -- MODEL.ldr ...
##
## BrickBench's verify.py counts a build's pieces by BrickNet's connection
## graph (connected_components): two parts are one piece only where a stud
## meets a hole, a hinge its half, an axle its hole. bench164 found the
## outline161 arm's rabbit (brickbench-2026-10-22-m147) in 13 pieces by it,
## twelve 1 x 1 cheese slopes joined to nothing, and our check had told the
## session it held together. Each model is opened as a session's is and
## checked as review_model checks a whole design, on a bare floor; this says
## the check's verdict, what it said of parts held by nothing, and the pieces
## by the exact shapes' connections (Exact.connections, BrickNet's rules),
## each part apart from the largest with where it is. Last, a verdict a
## build: BrickNet's pieces, and those that stay on in the hand (a dish held
## by its tube between four studs, a part caught where it is) against whether
## the check holds it together, and how many of the builds agree; and what
## saving it from outside would say (the save gate: each piece apart that
## stands on another, with where to seat it).
extends SceneTree

var _agreed: int = 0
var _asked: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var files: Array = Array(OS.get_cmdline_user_args())
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("FAIL: no catalogue")
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
	assistant.floor_kind = func() -> String: return ModelFloor.NONE
	for file: Variant in files:
		var text: String = FileAccess.get_file_as_string(str(file))
		store.open_text(text, str(file).get_file())
		var model: Assistant.Model = assistant._model_from_world()
		for placement: Assistant.Placement in model.placements:
			placement.mine = true
		assistant.set("_strict_mine", true)
		var report: Dictionary = assistant._check(model, true)
		assistant.set("_strict_mine", false)
		var exact: ExactCheck = assistant._exact_check_for(model, true)
		for i: int in model.placements.size():
			var p: Assistant.Placement = model.placements[i]
			exact.place(i, p.part, p.exact_at(assistant._joined_at(p, library.mesh_for(p.part), model)))
		var root: PackedInt32Array = exact.pieces([])
		var sizes: Dictionary = {}
		for i: int in root.size():
			sizes[root[i]] = int(sizes.get(root[i], 0)) + 1
		var order: Array = sizes.keys()
		order.sort_custom(func(a: int, b: int) -> bool: return sizes[a] > sizes[b])
		var counts: Array = order.map(func(k: int) -> int: return sizes[k])
		var found: Dictionary = report.get("exact", {})
		print("%s: %d parts; check %s (%s); lattice pieces %d; exact pieces %d %s; not held %d, tips %d, loose %d" % [
			str(file), model.placements.size(), "ok" if report.get("ok", false) else "FAILS",
			report.get("summary", ""), int(report.get("pieces", 0)), order.size(), counts,
			(found.get("not held", []) as Array).size(), (found.get("tips over", []) as Array).size(),
			int(report.get("loose", 0))])
		for k: int in order.slice(1):
			var members: Array = []
			for i: int in root.size():
				if root[i] == k:
					members.append(i)
					var p: Assistant.Placement = model.placements[i]
					var on: int = exact.under(i)
					print("  apart: %s %s, on %s" % [p.part, _where(exact, model, i),
						model.placements[on].part if on >= 0 and on < model.placements.size() else "-"])
			# A part with no exact shape (a car's tyre) is a piece of its own
			# that nothing here can judge.
			members = members.filter(func(i: int) -> bool: return exact.items[i] != null)
			if members.is_empty():
				continue
			print("    rests %s, comes away %s, on a missing stud %s" % [exact.rests(members),
				exact.comes_away(members), exact.on_missing_stud(members)])
			for m: int in members:
				for j: int in Exact._near(exact.items, m, PackedInt32Array(), ExactCheck.TOUCH + Exact.TAU):
					if members.has(j) or exact.items[j] == null:
						continue
					if ExactCheck._tube_grips(exact.items[j], exact.items[m]):
						print("    studs of %s at %s grip a tube of %s" % [model.placements[j].part, (exact.items[j] as Exact.Item).at.origin, model.placements[m].part])
					if ExactCheck._tube_grips(exact.items[m], exact.items[j]):
						print("    studs of %s grip a tube of %s at %s" % [model.placements[m].part, model.placements[j].part, (exact.items[j] as Exact.Item).at.origin])
		# BrickNet's pieces as they hold in the hand: a dish whose tube stands
		# between four studs (connect166) and a part caught where it is, as the
		# orrery's rings are (models175), stay on, and a part with no exact
		# shape is the lattice's to judge (a car's tyre on its wheel).
		var bricknet: int = 1
		for k: int in order.slice(1):
			var those: Array = []
			for i: int in root.size():
				if root[i] == k and exact.items[i] != null:
					those.append(i)
			if not those.is_empty() and (exact.comes_away(those) or not exact.rests(those)):
				bricknet += 1
		# The check's: whole when it finds nothing that comes away, floats,
		# tips or stands loose, and counts one piece.
		var why := PackedStringArray()
		for kind: String in ["not held", "tips over"]:
			if not (found.get(kind, []) as Array).is_empty():
				why.append("%s %d" % [kind, (found.get(kind, []) as Array).size()])
		if int(report.get("loose", 0)) > 0:
			why.append("loose %d" % int(report.get("loose", 0)))
		if not (report.get("resting", []) as Array).is_empty():
			why.append("resting %d, said" % (report.get("resting", []) as Array).size())
		if int(report.get("named", 0)) > 0:
			why.append("named apart %d" % int(report.get("named", 0)))
		var holds: bool = why.is_empty() and int(report.get("pieces", 0)) <= 1
		if why.is_empty() and not holds:
			why.append("%d pieces, passed" % int(report.get("pieces", 0)))
		var agree: bool = (bricknet == 1) == holds
		_agreed += 1 if agree else 0
		_asked += 1
		print("  verdict: BrickNet %d piece%s, %d in the hand; the check %s; %s" % [order.size(),
			"" if order.size() == 1 else "s", bricknet, "holds it together" if holds else "does not (%s)"
				% ", ".join(why), "agree" if agree else "DISAGREE"])
		var lattice_pieces: Array = report.get("each_piece", [])
		lattice_pieces.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
		for piece: Array in lattice_pieces.slice(1):
			print("  lattice apart: %s" % ", ".join(PackedStringArray(piece.map(func(i: int) -> String:
				return "%s %s" % [model.placements[i].part, _where(exact, model, i)]))))
		# What saving from outside says of it (Assistant._held_in_the_hand):
		# each piece apart that stands on another, with where to seat it.
		var held: PackedStringArray = assistant._held_in_the_hand(model)
		print("  the save gate: %s" % ("lets it save" if held.is_empty() else "holds it, %d apart: %s"
			% [held.size(), " | ".join(held)]))
		for sentence: Variant in found.get("not held", []):
			print("  not held: %s" % str(sentence).left(700))
		for line: Variant in report.get("advice", []):
			var s: String = str(line)
			if s.contains("held by nothing") or s.contains("picked up") or s.contains("grips"):
				print("  advice: %s" % s.left(300))
		for clause: Variant in report.get("resting", []):
			print("  resting: %s" % str(clause).left(300))
	print("agree on %d of %d" % [_agreed, _asked])
	quit(0)


## Where part [param i] is: in LDU, or as placed when it has no exact shape,
## which is a piece apart of its own (the car's wheels stopped the run).
func _where(exact: ExactCheck, model: Assistant.Model, i: int) -> String:
	var item: Exact.Item = exact.items[i]
	if item != null:
		return "at LDU %s" % item.at.origin
	var p: Assistant.Placement = model.placements[i]
	return "at x %s y %s z %s, no exact shape" % [p.x, p.y, p.z]
