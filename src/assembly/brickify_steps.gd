## A Brickify build's own steps, as its file's "0 STEP" lines, so the
## booklet follows them (AuthorSteps, Instructions._authored_plan).
##
## A sculpture is built as its designer drew it in layers: a course at a
## time from the bottom, the sideways panels built in the hand and pressed
## onto the side studs once the core behind them is up. So each course is a
## step, a course of a few parts going in with the next (up to a brick's
## height of them), and each panel (sideways parts held to one another,
## facing one way: a cube shell, Shapes' lay_shell) is a sub-assembly of its
## own, built a layer at a time out from the core and put on in the step its
## core's last part goes in.
##
## Every step's partial build must stand, and where one would not, the
## order changes, never the build:
##   - a part is put in the first step at which something already there
##     holds it (by its studs, the studs of a part on it, or a side stud):
##     an inverted slope hung under a ledge goes in with the ledge, a part
##     resting on a panel with the panel. The step is the least, over every
##     way down to the ground, of the latest step on that way (a bottleneck
##     path, worked out in step order, a bucket a step).
##   - each partial build is weighed (Balance: its centre of mass over what
##     it stands on, no stud joint past its working load, nothing adrift),
##     and a step whose build would not stand goes in with the next, so it
##     is never a place the builder stops at.
##
## Pure: it reads the placements and the library and changes neither, so it
## runs on the worker after Brickify.build.
class_name BrickifySteps
extends RefCounted

## A course of fewer parts goes in with the next, up to THIN_PLATES plates
## of courses in one step.
const FEWEST := 8
const THIN_PLATES := 3
## A plate in the lattice's cells, which are 2 LDU.
const PLATE_CELLS := 4
## A panel of fewer parts is no sub-assembly: a tile on a side stud goes in
## with the course its brick is in.
const PANEL_FEWEST := 2
## Steps not reached, while it is worked out.
const NEVER := 0x7FFFFFFF


## What it came to.
class Plan extends RefCounted:
	## Per placement: its step in the build; for a part of a panel, its
	## step in that panel.
	var step := PackedInt32Array()
	## Per placement: the panel it is in, or -1 for the build itself.
	var panel := PackedInt32Array()
	## Per panel: the build's step it is put on in, its name ("left panel
	## 2"), and how many steps it is built in.
	var panel_step := PackedInt32Array()
	var panel_name := PackedStringArray()
	var panel_steps := PackedInt32Array()
	## The build's steps.
	var steps: int = 0
	## The courses, before any went in with the next.
	var courses: int = 0
	## Partial builds weighed, a course's at a time, and how many of the
	## steps kept stand (all of them, unless the whole build does not).
	var weighed: int = 0
	var stood: int = 0
	## Steps put in with the next because the build up to them would not
	## stand, and what each would have done.
	var merged: int = 0
	var why_merged: PackedStringArray = PackedStringArray()
	## Parts put in a later step than their course, to be held when they go in.
	var later: int = 0
	## Parts nothing holds at any step, by the graph read here: in the last.
	var unheld: int = 0
	## The least margin of any partial build kept, in studs.
	var least_margin: float = INF
	## And the whole build, weighed as it stands.
	var whole_stands: bool = true
	var ms: int = 0

	## In words, for the panel and the session.
	func said() -> String:
		if steps == 0:
			return "no steps"
		var out: String = "%d step%s by courses, bottom up" % [steps, "" if steps == 1 else "s"]
		if not panel_name.is_empty():
			out += ", %d panel%s built on the side" % [panel_name.size(),
				"" if panel_name.size() == 1 else "s"]
		if weighed > 0:
			out += "; every step's build stands" if stood == steps \
				else "; %d of %d steps' builds stand" % [stood, steps]
		if merged > 0:
			out += " (%d course%s put in with the next, which would not have)" % [merged,
				"" if merged == 1 else "s"]
		return out


## The steps for [param model], laid by Brickify.build and checked by
## [param checker]. [param weigh] weighs each partial build (Balance).
static func of(model: Assistant.Model, checker: Assistant, weigh: bool = true) -> Plan:
	var began: int = Time.get_ticks_msec()
	var library: PartLibrary = checker.library
	var plan := Plan.new()
	var count: int = model.placements.size()
	plan.step.resize(count)
	plan.panel.resize(count)
	plan.panel.fill(-1)
	if count == 0:
		return plan

	# Each part where it stands, in a lattice of its own (ids from 1).
	var lattice := BrickLattice.new()
	lattice.keeps_columns = false
	var bricks: Array = []
	var bound: Array[PackedInt32Array] = []
	var out_way: Array[Vector3i] = []      ## which way its studs point
	var lowest: int = NEVER
	for index: int in count:
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		var at := Transform3D()
		var packed := PackedInt32Array()
		if part != null:
			at = checker._transform(placement, part)
			packed = checker.builder.boxes_for(part, at)
		var box := PackedInt32Array()
		if not packed.is_empty():
			lattice.occupy_boxes(index + 1, packed)
			box = _bound_of(packed)
			lowest = mini(lowest, box[1])
		bound.append(box)
		bricks.append(BrickWorld.Brick.new(index + 1, placement.part, placement.color, at))
		out_way.append(Vector3i((at.basis * Vector3.UP).round()))

	# What holds what: a stud pushed into another part, whichever way it
	# points. Not a part resting on another's top: a plate on a tile is held
	# by nothing until what clutches it from above is there.
	var near: Array = []
	for _n: int in count:
		near.append([])
	var side: Dictionary = {}    ## index * count + other -> true, a sideways stud's joint
	var studs_of: Dictionary = {}
	for index: int in count:
		var packed: PackedInt32Array = lattice.boxes_of(index + 1)
		if packed.is_empty():
			continue
		var placement: Assistant.Placement = model.placements[index]
		if not studs_of.has(placement.part):
			var studs: Array = []
			var part: Lbm.PartMesh = library.mesh_for(placement.part)
			if part != null:
				for connector: Lbm.Connector in part.connectors:
					if connector.kind == "stud" and connector.gender == "male":
						studs.append([connector.position + connector.axis.normalized() * 5.0,
							connector.axis.normalized()])
			studs_of[placement.part] = studs
		var at: Transform3D = (bricks[index] as BrickWorld.Brick).transform
		for stud: Array in studs_of[placement.part]:
			var reached: int = lattice.brick_at(BrickLattice.to_cell(at * (stud[0] as Vector3)))
			if reached > 0 and reached - 1 != index:
				_link(near, index, reached - 1)
				# A stud pointing sideways, which what rests on what (Balance's
				# graph) does not see: a tile on a side stud, a panel on a core.
				if absf((at.basis * (stud[1] as Vector3)).normalized().y) < 0.5:
					side[mini(index, reached - 1) * count + maxi(index, reached - 1)] = true

	# The panels: sideways parts held to one another, facing one way.
	var root: PackedInt32Array = PackedInt32Array()
	root.resize(count)
	for index: int in count:
		root[index] = index
	var sideways := func(index: int) -> bool:
		return out_way[index].y == 0 and not bound[index].is_empty()
	for index: int in count:
		if not sideways.call(index):
			continue
		for other: int in near[index]:
			if sideways.call(other) and out_way[other] == out_way[index]:
				_union(root, index, other)
	var groups: Dictionary = {}    ## root -> Array of index
	for index: int in count:
		if sideways.call(index):
			var top: int = _find(root, index)
			if not groups.has(top):
				groups[top] = []
			(groups[top] as Array).append(index)
	var panels: Array = []
	for top: int in groups:
		if (groups[top] as Array).size() >= PANEL_FEWEST:
			panels.append(groups[top])
	# Bottom up, then by where they are, so the names read in order.
	panels.sort_custom(func(a: Array, b: Array) -> bool:
		var la: PackedInt32Array = bound[int(a[0])]
		var lb: PackedInt32Array = bound[int(b[0])]
		return la[1] < lb[1] if la[1] != lb[1] else int(a[0]) < int(b[0]))
	var named: Dictionary = {}
	for number: int in panels.size():
		var members: Array = panels[number]
		var way: Vector3i = out_way[int(members[0])]
		var side_name: String = {Vector3i(1, 0, 0): "right", Vector3i(-1, 0, 0): "left",
			Vector3i(0, 0, 1): "front", Vector3i(0, 0, -1): "back"}.get(way, "side")
		named[side_name] = int(named.get(side_name, 0)) + 1
		plan.panel_name.append("%s panel %d" % [side_name, int(named[side_name])])
		for index: int in members:
			plan.panel[index] = number
	plan.panel_step.resize(panels.size())
	plan.panel_steps.resize(panels.size())

	# The courses: a plate's height each, bottom up, a thin one going in with
	# the next.
	var level := PackedInt32Array()
	level.resize(count)
	var at_level: Dictionary = {}
	for index: int in count:
		var box: PackedInt32Array = bound[index]
		level[index] = 0 if box.is_empty() else floori(float(box[1] - lowest) / PLATE_CELLS)
		if plan.panel[index] < 0:
			at_level[level[index]] = int(at_level.get(level[index], 0)) + 1
	var levels: Array = at_level.keys()
	levels.sort()
	var course_of: Dictionary = {}    ## level -> course
	var course: int = -1
	var began_at: int = 0
	var in_course: int = FEWEST
	for at: int in levels:
		if in_course >= FEWEST or at - began_at >= THIN_PLATES:
			course += 1
			began_at = at
			in_course = 0
		course_of[at] = course
		in_course += int(at_level[at])
	plan.courses = course + 1

	# The step each part can go in: the least, over every way down, of the
	# latest course on it. A panel goes on whole, once every part of the
	# core it is held to is there.
	var dist := PackedInt32Array()
	dist.resize(count)
	dist.fill(NEVER)
	var earliest := PackedInt32Array()
	earliest.resize(count)
	for index: int in count:
		earliest[index] = int(course_of.get(level[index], 0)) if plan.panel[index] < 0 else 0
	var seeds: Dictionary = {}    ## index -> step
	for index: int in count:
		if plan.panel[index] < 0 and not bound[index].is_empty() \
				and bound[index][1] <= lowest + Balance.ON_FLOOR:
			seeds[index] = earliest[index]
	var buckets: Array = []
	for _round: int in 4:
		_reach(near, plan.panel, earliest, seeds, dist, buckets, plan.courses)
		var changed: bool = false
		for number: int in panels.size():
			var attach: int = -1
			for index: int in panels[number]:
				for other: int in near[index]:
					if plan.panel[other] < 0 and dist[other] != NEVER:
						attach = maxi(attach, dist[other])
			if attach < 0:
				continue
			for index: int in panels[number]:
				if int(seeds.get(index, NEVER)) != attach:
					seeds[index] = attach
					changed = true
		if not changed:
			break
	var last: int = plan.courses - 1
	for index: int in count:
		if dist[index] != NEVER:
			last = maxi(last, dist[index])
	for index: int in count:
		if dist[index] == NEVER:
			plan.unheld += 1
			dist[index] = last
		elif plan.panel[index] < 0 and dist[index] > earliest[index]:
			plan.later += 1
	for number: int in panels.size():
		plan.panel_step[number] = dist[int(panels[number][0])]

	# Weighed, a partial build a step, and a step whose build would not stand
	# put in with the next.
	var steps: int = last + 1
	var keep := PackedByteArray()
	keep.resize(steps)
	keep.fill(1)
	if weigh:
		var judge := Stability.new()
		judge.library = library
		judge.lattice = lattice
		var contacts: Dictionary = judge.contacts(bricks)
		var by_step: Array = []
		by_step.resize(steps)
		for n: int in steps:
			by_step[n] = []
		for index: int in count:
			if not bound[index].is_empty():
				(by_step[dist[index]] as Array).append(bricks[index])
		var links: Array = []
		for key: int in side:
			links.append([key / count + 1, key % count + 1])
		var standing: Array = []
		for n: int in steps:
			standing.append_array(by_step[n])
			if (by_step[n] as Array).is_empty():
				keep[n] = 0
				continue
			var balance := Balance.new()
			balance.library = library
			balance.lattice = lattice
			var report: Balance.Report = balance.measure(standing, [], links, contacts)
			if report.empty:
				continue
			plan.weighed += 1
			var stands: bool = report.margin >= 0.0 and report.over == 0 and report.adrift == 0
			if stands:
				plan.stood += 1
			if n == steps - 1:
				plan.whole_stands = stands
				if stands:
					plan.least_margin = minf(plan.least_margin, report.margin)
				continue
			if stands:
				plan.least_margin = minf(plan.least_margin, report.margin)
				continue
			keep[n] = 0
			plan.merged += 1
			if plan.why_merged.size() < 6:
				plan.why_merged.append("step %d: %s" % [n + 1, ("tips, %s studs past the %s edge"
					% [Balance.studs(-report.margin), report.edge]) if report.margin < 0.0
					else ("%d joint%s past its load" % [report.over, "" if report.over == 1
						else "s"]) if report.over > 0 else "%d part%s adrift" % [report.adrift,
						"" if report.adrift == 1 else "s"]])
	var renumber := PackedInt32Array()
	renumber.resize(steps)
	var next: int = 0
	for n: int in steps:
		renumber[n] = next
		if keep[n] == 1 or n == steps - 1:
			next += 1
	# A step put in with the next takes the next's number.
	for n: int in range(steps - 1, -1, -1):
		if keep[n] == 0 and n < steps - 1:
			renumber[n] = renumber[n + 1]
	plan.steps = next
	for index: int in count:
		plan.step[index] = renumber[dist[index]]
	for number: int in panels.size():
		plan.panel_step[number] = renumber[plan.panel_step[number]]

	# Inside each panel: a layer at a time out from the core, a thin layer in
	# with the next.
	for number: int in panels.size():
		var members: Array = panels[number]
		var way: Vector3i = out_way[int(members[0])]
		var out_of: Dictionary = {}
		var least: int = NEVER
		for index: int in members:
			var box: PackedInt32Array = bound[index]
			var out: int = box[0] if way.x > 0 else (-box[3] if way.x < 0
				else (box[2] if way.z > 0 else -box[5]))
			out_of[index] = out
			least = mini(least, out)
		var count_at: Dictionary = {}
		for index: int in members:
			var layer: int = floori(float(int(out_of[index]) - least) / PLATE_CELLS)
			out_of[index] = layer
			count_at[layer] = int(count_at.get(layer, 0)) + 1
		var layers: Array = count_at.keys()
		layers.sort()
		var layer_step: Dictionary = {}
		var at_step: int = -1
		var filled: int = FEWEST
		for layer: int in layers:
			if filled >= FEWEST:
				at_step += 1
				filled = 0
			layer_step[layer] = at_step
			filled += int(count_at[layer])
		plan.panel_steps[number] = at_step + 1
		for index: int in members:
			plan.step[index] = int(layer_step[out_of[index]])
	plan.ms = Time.get_ticks_msec() - began
	return plan


## Bottleneck paths from [param seeds] (index -> the step it may go in at
## the earliest): [param dist] the least, over every way to each part, of the
## latest step on it, never before its own [param earliest]. A panel's parts
## are reached only as seeds, so a panel goes on whole.
static func _reach(near: Array, panel: PackedInt32Array,
		earliest: PackedInt32Array, seeds: Dictionary, dist: PackedInt32Array,
		buckets: Array, courses: int) -> void:
	dist.fill(NEVER)
	buckets.clear()
	var most: int = courses
	for index: int in seeds:
		most = maxi(most, int(seeds[index]) + 1)
	for _n: int in most + 1:
		buckets.append([])
	for index: int in seeds:
		var at: int = maxi(int(seeds[index]), earliest[index])
		if at < dist[index]:
			dist[index] = at
			(buckets[at] as Array).append(index)
	var at: int = 0
	while at < buckets.size():
		var bucket: Array = buckets[at]
		var n: int = 0
		while n < bucket.size():
			var index: int = bucket[n]
			n += 1
			if dist[index] != at:
				continue
			for other: int in near[index]:
				# A panel's parts are reached only as seeds: it goes on whole.
				if panel[other] >= 0:
					continue
				var to: int = maxi(at, earliest[other])
				if to < dist[other]:
					dist[other] = to
					while to >= buckets.size():
						buckets.append([])
					(buckets[to] as Array).append(other)
		at += 1


static func _link(near: Array, a: int, b: int) -> void:
	if not (near[a] as Array).has(b):
		(near[a] as Array).append(b)
	if not (near[b] as Array).has(a):
		(near[b] as Array).append(a)


static func _find(root: PackedInt32Array, index: int) -> int:
	var at: int = index
	while root[at] != at:
		root[at] = root[root[at]]
		at = root[at]
	return at


static func _union(root: PackedInt32Array, a: int, b: int) -> void:
	var one: int = _find(root, a)
	var other: int = _find(root, b)
	if one != other:
		root[maxi(one, other)] = mini(one, other)


static func _bound_of(packed: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array([packed[0], packed[1], packed[2], packed[3], packed[4], packed[5]])
	for n: int in range(6, packed.size(), 6):
		for k: int in 3:
			out[k] = mini(out[k], packed[n + k])
			out[k + 3] = maxi(out[k + 3], packed[n + k + 3])
	return out
