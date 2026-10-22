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
## A run takes minutes, and nothing stops the person building meanwhile. What
## they do has steps of its own, and stays theirs: a part a step of theirs
## names is left out of Claude's, so each Undo takes back one of them.
class_name ClaudeStep
extends RefCounted


## Where the model and its history stand as a run begins, for [method record]
## to make the run's change one step at its end.
static func mark(builder: Builder, world: BrickWorld, scenery: Dictionary,
		words: String) -> Dictionary:
	if builder == null or world == null:
		return {}
	return {"was": SelectionScope.snapshot(world, scenery), "steps": builder.steps_now(),
		"generation": world.generation(), "words": words}


## What changed since [param from] and has no step yet, kept as one step
## called as [param from] says ("Claude's design (12 put down)"), newest or
## [param at] steps deep (Builder.record). Nothing when nothing did, or when
## the model was replaced since (an Open, Brick Art laid): its history went
## with it. True when a step was kept.
static func record(builder: Builder, world: BrickWorld, scenery: Dictionary,
		from: Dictionary, at: int = -1) -> bool:
	if from.is_empty() or builder == null or world == null \
			or world.generation() != int(from["generation"]):
		return false
	var theirs: Dictionary = _named_since(from["steps"], builder.steps_now())
	var off: Dictionary = {}    ## brick id -> its step, put down since
	var back: Array = []
	var steps: Array = []
	for step: Dictionary in SelectionScope.steps_back(from["was"], world, scenery):
		if _theirs(step, theirs):
			continue
		match str(step["undo"]):
			"remove":
				off[int(step["brick"])] = step
			"add":
				back.append(step)
			_:
				steps.append(step)
	# A part taken off and the same put back where it was is no change: a
	# run that failed puts the model back so, under new numbers.
	var standing: Dictionary = {}   ## part, colour and place -> ids put down since
	for brick_id: int in off:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var key: String = "%s|%d" % [_place(brick.part_id, brick.transform), brick.color_code]
		if not standing.has(key):
			standing[key] = []
		(standing[key] as Array).append(brick_id)
	var gone: Array = []
	for step: Dictionary in back:
		var same: Array = standing.get("%s|%d" % [_place(str(step["part"]), step["transform"]),
			int(step["color"])], [])
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


## The bricks the steps taken, undone or redone between [param then] and
## [param now] (each Builder.steps_now) name: by number, and by part and place
## for one taken off.
static func _named_since(then: Array, now: Array) -> Dictionary:
	var named: Dictionary = {"ids": {}, "places": {}}
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
			named["ids"][int(step[key])] = true
	if step.has("part") and step.has("transform"):
		named["places"][_place(str(step["part"]), step["transform"])] = true


static func _theirs(step: Dictionary, theirs: Dictionary) -> bool:
	for key: String in ["brick", "was"]:
		if step.has(key) and (theirs["ids"] as Dictionary).has(int(step[key])):
			return true
	return step.has("part") and step.has("transform") \
		and (theirs["places"] as Dictionary).has(_place(str(step["part"]), step["transform"]))


static func _place(part: String, at: Transform3D) -> String:
	return "%s@%.1f,%.1f,%.1f" % [part, at.origin.x, at.origin.y, at.origin.z]
