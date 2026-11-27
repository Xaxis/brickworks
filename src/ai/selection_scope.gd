## What a person asked Claude about: the parts they had selected, and the
## room a change to them may use.
##
## Asked about a wing, a design that may reach the whole model is free to
## rebuild the plane round it, and an edit that changes a dozen parts
## nobody mentioned is the one thing a person editing their own model
## cannot have. So a change about a selection may take off, paint, move or
## put down parts only inside the selection's box and a margin round it,
## or a box the person allowed when Claude asked for one. Everything else
## stays where it is. A change that reaches outside is refused whole,
## naming the parts that did, and a change inside it is still checked as
## any design is: the model must hold together and stay in one piece.
##
## Kept apart from the assistant: what is here is the region, the test and
## the one history step its changes gather into, and none of it needs a
## conversation.
class_name SelectionScope
extends RefCounted

## Room round the selection, in LDU: two studs each way across, three
## plates above and below. Enough to curve a wing's edge outward or lay a
## course of detail on a wall's face, and not enough to reach the next
## assembly over.
const MARGIN := Vector3(40.0, 24.0, 40.0)
## How far a part may poke past the region and still be inside it: the
## rounding of a turned part's bounds, which is a fraction of an LDU.
const SLACK := 2.0

## The parts asked about, brick id -> true. Kept up to date as edits take
## parts off and put new ones down, so a second request about "it" is
## about what it now is.
var ids: Dictionary = {}
## The selected parts' own box, LDU.
var box := AABB()
## Where a change may reach, LDU: the box and the margin, or more where the
## person said yes.
var region := AABB()
## The sub-assembly every part asked about is in, or "" when they are not
## all in one. New parts go into it.
var path: String = ""
## A picture of the selection picked out in the model, as it was asked
## about: the "before" of what changed.
var before: Image = null
## The history step every change about this selection gathers into, so one
## undo takes the whole request back.
var step: Dictionary = {}
## Parts changed, all told, for the panel.
var changed: int = 0
## The steps of [member step] that are the change itself, without the
## other copies of the sub-assembly built again after it, which are said
## apart; and how many copies the last change brought along.
var own_steps: Array = []
var followed: int = 0


## The scope of a selection, or null when none of it is a part that can be
## changed (scenery, or gone).
static func of(selected: Array, world: BrickWorld, library: PartLibrary,
		scenery: Dictionary) -> SelectionScope:
	var scope := SelectionScope.new()
	var paths: Dictionary = {}
	var first: bool = true
	for raw: Variant in selected:
		var brick_id: int = int(raw)
		if scenery.has(brick_id):
			continue
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var here: AABB = box_of(brick.part_id, brick.transform, library)
		if not here.has_volume():
			continue
		scope.ids[brick_id] = true
		scope.box = here if first else scope.box.merge(here)
		first = false
		paths[Assemblies.path_of(brick)] = true
	if scope.ids.is_empty():
		return null
	scope.region = AABB(scope.box.position - MARGIN, scope.box.size + MARGIN * 2.0)
	scope.path = str(paths.keys()[0]) if paths.size() == 1 else ""
	return scope


## Where a part is in the world, as a box in LDU.
static func box_of(part_id: String, at: Transform3D, library: PartLibrary) -> AABB:
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	if mesh == null:
		return AABB()
	return (at * mesh.bounds).abs()


## Whether a part's box is inside the room a change may use.
func holds(where: AABB) -> bool:
	return region.grow(SLACK).encloses(where)


## Whether this is the same selection: the same parts.
func same(selected: Array) -> bool:
	if selected.size() != ids.size():
		return false
	for raw: Variant in selected:
		if not ids.has(int(raw)):
			return false
	return true


## The room grown to take in [param more] as well, as the person allowed.
func allow(more: AABB) -> void:
	region = region.merge(more)


## What the steps did, the way round a person reads it: "4 painted, 2 put
## down, 1 taken off".
static func words_for(steps: Array) -> String:
	var counts: Dictionary = {"remove": 0, "move": 0, "recolor": 0, "add": 0}
	for step: Dictionary in steps:
		var kind: String = str(step.get("undo", ""))
		counts[kind] = int(counts.get(kind, 0)) + 1
	var said := PackedStringArray()
	for pair: Array in [["remove", "put down"], ["recolor", "painted"],
			["move", "moved"], ["add", "taken off"]]:
		var count: int = int(counts[pair[0]])
		if count > 0:
			said.append("%d %s" % [count, pair[1]])
	return ", ".join(said)
