## What Claude's design loop in the app changes, as one step of the history
## named as Claude's.
##
## The loop puts its work down without the builder, which is what keeps the
## history, so a design or a revision asked in the panel went into no history
## at all: the person's Undo after it took back their own last part, or did
## nothing, and Claude's work stood. A session from outside has one step a
## call (CommandSocket._one_step); a request in the panel is one step too,
## taken when its run ends.
##
## A run takes minutes, and nothing stops the person building meanwhile, nor
## their Claude calling beside it. A run's or a call's step holds only what
## its own code changed, part by part, as that code made each change
## (BrickWorld.Ledger, Builder.naming): never whatever else changed while it
## was open. It was the model's difference over that time, so a chat's
## review_model took 916 parts of the person's own panel design into its
## steps, and the chat's undo took them (savereview5 F1).
class_name ClaudeStep
extends RefCounted


## A run or a call of [param by]'s beginning (else whoever is
## [member Builder.acting]), for [method record] to make what its code
## changes with no step one step as it ends; or [method drop].
static func mark(builder: Builder, world: BrickWorld, scenery: Dictionary,
		words: String, by: Variant = null) -> Dictionary:
	if builder == null or world == null:
		return {}
	var who: String = Builder.acting if by == null else str(by)
	return {"ledger": world.open_ledger(who, scenery), "steps": builder.steps_now(),
		"words": words}


## A [method mark] let go of with no step: nothing more is noted for it.
static func drop(world: BrickWorld, from: Dictionary) -> void:
	if world != null and not from.is_empty():
		world.close_ledger(from["ledger"])


## What the code of [param from]'s run or call changed with no step of its
## own, kept as one step called as [param from] says ("Claude's design (12
## put down)"), newest or [param at] steps deep (Builder.record); its mark
## let go of. Nothing when it changed nothing. True when a step was kept.
## After a clear (or a model opened) since the mark, only what it changed
## since, on the model there now: what it laid before went with the model
## the clear took off, in the clear's own step (savereview5 F2).
##
## [param pair] false keeps every part taken off and put down as it is, by
## number: a call's own change, where a part taken off and the same put
## back is a re-lay asked for, and its undo gives the old number back
## (copyfaults twin_relaid; savereview4 F2). True, a run's: one that failed
## puts the model back under new numbers, and a part put back as it was, in
## its sub-model, step and group, is no change.
static func record(builder: Builder, world: BrickWorld, scenery: Dictionary,
		from: Dictionary, at: int = -1, pair: bool = true) -> bool:
	if from.is_empty() or builder == null or world == null:
		return false
	var ledger: BrickWorld.Ledger = from["ledger"]
	world.close_ledger(ledger)
	# A step its own code kept stays that step: what it names is left out.
	var theirs: Dictionary = _named_since([[], []] if ledger.begun_again else from["steps"],
		builder.steps_now())
	var off: Dictionary = {}    ## brick id -> its step, put down since
	var back: Array = []
	var steps: Array = []
	for step: Dictionary in steps_of(ledger, world, scenery):
		if _theirs(step, theirs):
			continue
		match str(step["undo"]):
			"remove":
				off[int(step["brick"])] = step
			"add":
				back.append(step)
			_:
				steps.append(step)
	if not pair:
		steps = off.values() + steps + back
		if steps.is_empty():
			return false
		builder.record(steps, "%s (%s)" % [from["words"], SelectionScope.words_for(steps)], at)
		return true
	# A part taken off and the same put back where it was is no change: a
	# run that failed puts the model back so, under new numbers. The same
	# only in its sub-model, step and group too: one moved into another at
	# the same place is a change, and its undo takes it back.
	var standing: Dictionary = {}   ## part, colour, place, sub-model, step, group -> ids
	for brick_id: int in off:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var key: String = _same(brick.part_id, brick.transform, brick.color_code, brick.unit,
			brick.step, brick.group)
		if not standing.has(key):
			standing[key] = []
		(standing[key] as Array).append(brick_id)
	var gone: Array = []
	for step: Dictionary in back:
		var same: Array = standing.get(_same(str(step["part"]), step["transform"],
			int(step["color"]), str(step.get("unit", "")), int(step.get("step", -1)),
			str(step.get("group", ""))), [])
		var matched: int = 0
		for brick_id: int in same:
			if world.get_brick(brick_id).transform.is_equal_approx(step["transform"]):
				matched = brick_id
				break
		if matched != 0:
			same.erase(matched)
			off.erase(matched)
		else:
			gone.append(step)
	steps = off.values() + steps + gone
	if steps.is_empty():
		return false
	builder.record(steps, "%s (%s)" % [from["words"], SelectionScope.words_for(steps)], at)
	return true


## The history steps that take back what [param ledger] noted, in the order
## undo applies them: each part it put down taken off, each it moved or
## painted put back as it was, each it took off put down again under its own
## number. Part by part as the maker changed each, so nothing anyone else
## changed meanwhile is among them; a floor's plate never is.
static func steps_of(ledger: BrickWorld.Ledger, world: BrickWorld,
		scenery: Dictionary) -> Array:
	var off: Array = []
	var moved: Array = []
	var painted: Array = []
	var back_on: Array = []
	for brick_id: int in ledger.was:
		if scenery.has(brick_id):
			continue
		var then: Variant = ledger.was[brick_id]
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if then == null:
			# Put down here: taken off again, if it still stands.
			if brick != null:
				off.append({"undo": "remove", "brick": brick_id})
			continue
		var was: Array = then
		var put_back: Dictionary = {"undo": "add", "part": was[0], "color": was[1],
			"transform": was[2], "group": was[3], "unit": was[4], "was": brick_id,
			"step": int(was[5])}
		if brick == null:
			back_on.append(put_back)
			continue
		if was[0] != brick.part_id:
			# Not a part the edit can turn into another under one number;
			# it takes one off and puts one down. Said so, in case.
			off.append({"undo": "remove", "brick": brick_id})
			put_back.erase("was")
			back_on.append(put_back)
			continue
		if not (was[2] as Transform3D).is_equal_approx(brick.transform):
			moved.append({"undo": "move", "brick": brick_id, "transform": was[2]})
		if int(was[1]) != brick.color_code:
			painted.append({"undo": "recolor", "brick": brick_id, "color": was[1]})
	return off + moved + painted + back_on


## Whether the history step [param step] put any part down: the step that
## takes one back off is a "remove". What a step of Claude's lays makes the
## model one made with the assistant (ModelStore.laid_by); a part it only
## moved or painted is still whoever laid it.
static func lays(step: Dictionary) -> bool:
	if str(step.get("undo", "")) == "remove":
		return true
	for inner: Variant in step.get("steps", []):
		if inner is Dictionary and lays(inner):
			return true
	return false


## The bricks the steps taken, undone or redone between [param then] and
## [param now] (each Builder.steps_now) name, by number.
static func _named_since(then: Array, now: Array) -> Dictionary:
	var named: Dictionary = {}
	for stack: int in 2:
		var before: Array = then[stack]
		var after: Array = now[stack]
		var same: int = 0
		while same < mini(before.size(), after.size()) and is_same(before[same], after[same]):
			same += 1
		for step: Variant in before.slice(same) + after.slice(same):
			_name(step, named)
	return named


static func _name(step: Dictionary, named: Dictionary) -> void:
	for inner: Variant in step.get("steps", []):
		_name(inner, named)
	for key: String in ["brick", "was"]:
		if step.has(key):
			named[int(step[key])] = true


static func _theirs(step: Dictionary, theirs: Dictionary) -> bool:
	for key: String in ["brick", "was"]:
		if step.has(key) and theirs.has(int(step[key])):
			return true
	return false


static func _place(part: String, at: Transform3D) -> String:
	return "%s@%.1f,%.1f,%.1f" % [part, at.origin.x, at.origin.y, at.origin.z]


## What a part put back must share with one taken off to be the same part
## ([method record]'s pairing): its place, colour, sub-model, step and group.
static func _same(part: String, at: Transform3D, color: int, unit: String, step: int,
		group: String) -> String:
	return "%s|%d|%s|%d|%s" % [_place(part, at), color, unit, step, group]
