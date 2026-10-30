## A set's booklet, as its bin follows it: the steps of one of the set's
## official LDraw models (vendor/omr, LDraw's Official Model Repository),
## each the parts it puts in by the set bin's part and colour, in the order
## the booklet shows them.
##
## Building from a set's bin, a person looked for each part among all the
## set's kinds, most held first: 8841-1 has 52, and a fifth of a walk of
## its Balance went on scrolling to parts held once (docs/CADTASK.md
## section 11). Studio's step list and a booklet's parts callout show the
## step's parts and no others; the bin puts them first.
##
## Which step the model is at is never kept: like the bin's counts
## (SetBin.left) it is worked out from what the model uses each time it
## changes, so a part put down, an undo or a delete all turn it alike.
class_name SetBooklet
extends RefCounted

## The model, as a person names it: "Balance", or the set's own name.
var name: String = ""
## Its file in the repository: "8841-1_Balance.mpd".
var file: String = ""
## The steps that put in a part the bin has, in order: each an Array of
## [key, how many], the keys in the set bin's spelling, as the step first
## shows each.
var steps: Array = []
## How many of each key the steps up to each one put in, all told.
var _through: Array = []


## The booklet of [param model] for [param bin]'s set: null when none of
## its steps puts in a part the bin has. A part in a colour the set does not
## hold in it is the set's own colour of that part (5762-1's file has old
## Light Grey where Rebrickable's inventory has Light Bluish Grey): what the
## bin gives for it. A part the set has none of is left out: no tile gives it.
static func make(model: LdrModel, named: String, file_name: String, bin: SetBin,
		library: PartLibrary) -> SetBooklet:
	if model == null or bin == null:
		return null
	var by_part: Dictionary = {}
	for key: String in bin.order:
		var part: String = Collection.part_of(key)
		if not by_part.has(part):
			by_part[part] = key
	var booklet := SetBooklet.new()
	booklet.name = named
	booklet.file = file_name
	var at: Dictionary = {}     ## the model's step -> index in steps
	var seen: Dictionary = {}   ## spelled key -> the bin's key
	for placement: LdrModel.Placement in model.flatten(library.parts):
		var spelled: String = Collection.key_of(placement.part_id, placement.color_code, library)
		var key: String = seen.get(spelled, "")
		if key.is_empty():
			key = spelled if bin.have.has(spelled) \
				else str(by_part.get(Collection.part_of(spelled), ""))
			seen[spelled] = key
		if key.is_empty():
			continue
		if not at.has(placement.step):
			at[placement.step] = booklet.steps.size()
			booklet.steps.append([])
		var step: Array = booklet.steps[at[placement.step]]
		var found: bool = false
		for lot: Array in step:
			if lot[0] == key:
				lot[1] = int(lot[1]) + 1
				found = true
				break
		if not found:
			step.append([key, 1])
	if booklet.steps.is_empty():
		return null
	var all: Dictionary = {}
	for step: Array in booklet.steps:
		for lot: Array in step:
			all[lot[0]] = int(all.get(lot[0], 0)) + int(lot[1])
		booklet._through.append(all.duplicate())
	return booklet


## The first step [param used] (SetBin.used_in) has not built, or the
## number of steps when it has built them all.
func first_open(used: Dictionary) -> int:
	for n: int in steps.size():
		if not left_in(n, used).is_empty():
			return n
	return steps.size()


## What step [param n] still wants put in, as [[key, how many], ...] in
## the order the step shows them: of each part, what the steps up to it
## want and the model does not yet have, at most what the step itself puts
## in.
func left_in(n: int, used: Dictionary) -> Array:
	var out: Array = []
	if n < 0 or n >= steps.size():
		return out
	var through: Dictionary = _through[n]
	for lot: Array in steps[n]:
		var key: String = lot[0]
		var wanted: int = mini(int(lot[1]), int(through[key]) - int(used.get(key, 0)))
		if wanted > 0:
			out.append([key, wanted])
	return out
