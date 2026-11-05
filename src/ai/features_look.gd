## The two or three features a subject is known by, planned before its
## first brick, and looked at in its own front and side once it stands.
##
## Set beside the real set, our designs lose on one defining feature's form
## far more often than on their box: a roller's drum small, narrow and half
## hidden under a boxy body; wings built as thick slabs; a blunt nose; a
## grille that is not there; a brick-built horse (design16). Three levers on
## the massing moved no one: a fill against its kind was heard as advice, a
## check of the build against its own plan of boxes measured consistency,
## and a plan of boxes built boxes. The sessions' own looks (fresh_eyes) said
## "the big grey drum at the front" of a drum the judge called small and
## half hidden: they looked at what they meant, never at its size against
## the real thing. Where a session did reason a feature's proportion against
## the real one ("a spire a quarter of the height, as the real one is"), it
## rebuilt it.
##
## So a session names, before building (plan_features), the features anyone
## would know the subject by, each one's proportion against the whole from
## its own knowledge of the real thing, and the technique its form needs.
## Its first whole review (review_model with no assembly) then leads with
## the look: the model from the front and the side, what it planned, and the
## question, each feature as the pictures show it against what it named, to
## answer with TOOL before any other change goes ahead (not_yet), and the
## one most off rebuilt before any detail. What is off, and whether to
## rebuild it, is the session's to say: nothing is changed for it. It is
## shown no real set and told of none.
class_name FeaturesLook
extends RefCounted

## The tool a session plans the features with ([method plan_definition]).
const PLAN_TOOL := "plan_features"
## The tool a session answers the look with ([method definition]).
const TOOL := "features_look"

## The most features kept: the two or three a subject is known by, and one
## more for a subject that has it.
const MOST := 4

## The calls refused while the look is unanswered (not_yet): after them it
## goes ahead, so a session is never stuck.
const MOST_REFUSED := 2

## The calls that go ahead while the look waits: its answer, a save, and
## the looks that help it answer.
const GO_AHEAD: Array[String] = [TOOL, "save_model", "view_model", "look_at_model"]

## The most times it is asked of one subject: again only when the build it
## was asked of had none of the features yet (a first build of one part).
const MOST_ASKED := 2

## The pictures, as ModelShot's views and what each is called.
const VIEWS: Array = [["front", "the front (from +z)"], ["right", "the side (from +x)"]]

var assistant: Assistant
## What plan_features named, each {name, proportion, technique}, or [].
var planned: Array[Dictionary] = []
## Whether a design of this subject went down on a bare baseplate.
var fresh: bool = false
## How many times the look has been asked for this subject.
var asks: int = 0
## The look asked, {refused}, then answered, {refused, features, rebuild},
## or let go of, {refused, unanswered}; {error} with no pictures. For the log
## and a probe.
var last: Dictionary = {}


## A new subject begins: nothing of the last one's carries over.
func begin() -> void:
	planned = []
	fresh = false
	asks = 0
	last = {}


## A design from outside stands; [param bare] when nothing stood before it.
func designed(bare: bool) -> void:
	fresh = fresh or bare


## plan_features: the features read and kept for the look, and said back.
func plan(args: Dictionary) -> String:
	var read: Array[Dictionary] = parse(args.get("features"))
	if read.is_empty():
		return ("Name the two or three features anyone would know the subject by, each with "
			+ "name, proportion (its size against the whole, from the real thing) and "
			+ "technique (how its form is built).")
	planned = read
	print("features planned: %s" % JSON.stringify(planned))
	var said := PackedStringArray()
	said.append("Planned, the features it will be known by:")
	said.append(listed(planned))
	said.append(PLANNED_THEN)
	return "\n".join(said)


const PLANNED_THEN := ("Build each to that proportion in the first build, with the technique "
	+ "its form needs: a judge sets these beside the real thing before the box they fit in. "
	+ "Once the model stands, the whole review (review_model) shows you its front and its "
	+ "side to read each one against what you named here, before any detail.")


## [param given] as plan_features takes it: each {name, proportion,
## technique}, blanks and repeats dropped, at most MOST.
static func parse(given: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not given is Array:
		return out
	var seen: Dictionary = {}
	for raw: Variant in given:
		if not raw is Dictionary:
			continue
		var name: String = str((raw as Dictionary).get("name", "")).strip_edges()
		var proportion: String = str((raw as Dictionary).get("proportion", "")).strip_edges()
		if name.is_empty() or proportion.is_empty() or seen.has(name.to_lower()):
			continue
		seen[name.to_lower()] = true
		out.append({"name": name, "proportion": proportion,
			"technique": str((raw as Dictionary).get("technique", "")).strip_edges()})
		if out.size() >= MOST:
			break
	return out


## The planned features, a line each.
static func listed(features: Array[Dictionary]) -> String:
	var lines := PackedStringArray()
	for n: int in features.size():
		var one: Dictionary = features[n]
		lines.append("  %d. %s: %s%s" % [n + 1, one["name"], one["proportion"],
			"" if str(one["technique"]).is_empty() else "; built as %s" % one["technique"]])
	return "\n".join(lines)


## Whether the whole review of the design standing leads with the look.
func due() -> bool:
	if assistant == null or not fresh or asks >= MOST_ASKED or not last.is_empty():
		return false
	return not assistant._busy and assistant._outside_standing \
		and assistant._outside_designed and not assistant.asked_about_selection()


## The look, as the whole review's answer: the front and the side, what was
## planned, and the question, for the session to answer with TOOL; or ""
## when no picture could be taken (the review says what it did).
func look() -> Variant:
	asks += 1
	var views: Array = await _pictures()
	if views.is_empty():
		last = {"error": "no pictures"}
		print("features look: no pictures, nothing said")
		return ""
	last = {"refused": 0}
	print("features look: asked, %d planned, with %d pictures" % [planned.size(), views.size()])
	var content: Array = [{"type": "text", "text": opening(planned, assistant._measured())}]
	for n: int in views.size():
		content.append({"type": "text", "text": "The model from %s:" % VIEWS[n][1]})
		content.append(views[n])
	content.append({"type": "text", "text": ASK % TOOL})
	return content


## What the look says before its pictures: why, the whole's size, and what
## was planned, or that nothing was.
static func opening(features: Array[Dictionary], measured: String) -> String:
	var said := PackedStringArray()
	said.append(OPENING)
	if not measured.strip_edges().is_empty():
		said.append(measured.strip_edges().get_slice("\n", 0))
	if features.is_empty():
		said.append("You planned none with %s: name the two or three now, from what you know "
			% PLAN_TOOL + "of the real thing, each with its proportion against the whole.")
	else:
		said.append("What you planned, from the real thing:\n" + listed(features))
	return "\n\n".join(said)


const OPENING := ("Before the rest of the review: the features it will be known by, against "
	+ "the real thing. A judge who sets a model beside the real one names one feature's form "
	+ "far more often than the box it fits in: a round part built too small or half hidden "
	+ "under the body, a part that is thin built as a thick slab, a part that tapers built "
	+ "blunt, a part the subject is known by left out. Below are the model from the front and "
	+ "from the side, rulers in studs. Look at each feature as the judge would, from these "
	+ "pictures alone: its size against the whole, not what you meant it to be.")

const ASK := ("Answer before any other change: %s, with features (each: name; real, its "
	+ "proportion against the whole on the real thing; seen, what these two pictures show of "
	+ "it against the whole, in studs and plates; off, true when seen is not real) and rebuild "
	+ "(the one most off and how you will build it to its real proportion, with the technique "
	+ "its form needs; empty when none is off). Then rebuild it before any detail: "
	+ "submit_design again when it changes the whole shape, edit_model when it is one part of "
	+ "it; view_model from the front and the side to see it reads as you named; then "
	+ "review_model for the rest of the whole review.")


## Whether the look waits for its answer.
func waiting() -> bool:
	return last.has("refused") and not last.has("features") and not last.has("unanswered")


## What a call is told while the look waits for its answer: "" when it goes
## ahead. The answer, a save and a look at the model go ahead; anything else
## is refused, up to MOST_REFUSED times.
func not_yet(tool: String) -> String:
	if not waiting() or tool in GO_AHEAD:
		return ""
	if int(last["refused"]) >= MOST_REFUSED:
		last["unanswered"] = true
		print("features look: never answered; %s goes ahead" % tool)
		return ""
	last["refused"] = int(last["refused"]) + 1
	print("features look: %s refused, the look unanswered" % tool)
	return ("Not yet: first answer the look at its features the review asked for. Call %s "
		% TOOL + "with each feature's real proportion and what the front and side pictures "
		+ "show of it, and the one to rebuild; then rebuild it.")


## The session's answer, with TOOL: kept ([member last]), and what comes next.
func answered(input: Dictionary) -> String:
	if not waiting():
		return "Nothing to answer: a design's first whole review asks for this."
	var features: Array[Dictionary] = []
	var given: Variant = input.get("features")
	for raw: Variant in (given as Array if given is Array else []):
		if not raw is Dictionary:
			continue
		var one: Dictionary = raw
		var name: String = str(one.get("name", "")).strip_edges()
		if name.is_empty():
			continue
		features.append({"name": name, "real": str(one.get("real", "")).strip_edges(),
			"seen": str(one.get("seen", "")).strip_edges(), "off": bool(one.get("off", false)),
			"built": bool(one.get("built", true))})
	var whole: bool = not features.is_empty()
	var built: bool = false
	var off: bool = false
	for one: Dictionary in features:
		whole = whole and not str(one["real"]).is_empty() and not str(one["seen"]).is_empty()
		built = built or bool(one["built"])
		off = off or bool(one["off"])
	if not whole:
		return ("Answer in full: features, each with its name, real and seen, and off; and "
			+ "rebuild, the one most off or empty.")
	var rebuild: String = str(input.get("rebuild", "")).strip_edges()
	last = {"refused": last["refused"], "features": features, "rebuild": rebuild}
	print("features look: answered (%d refused): %s" % [last["refused"],
		JSON.stringify({"features": features, "rebuild": rebuild})])
	if planned.is_empty():
		var named: Array[Dictionary] = []
		for one: Dictionary in features:
			named.append({"name": one["name"], "proportion": one["real"], "technique": ""})
		planned = named
	# Asked of a build that had none of them yet: asked again of the next.
	if not built:
		last = {}
		return ("None of them is built yet: build them to what you named, and the next whole "
			+ "review (review_model) looks at them again.")
	if rebuild.is_empty() and not off:
		return "Then each reads as the real one. Now review_model for the rest of the whole review."
	return ("Now rebuild it, before any detail: submit_design again when it changes the whole "
		+ "shape, edit_model when it is one part of it. Then view_model from the front and from "
		+ "the side to see it reads as you named, and review_model for the rest of the whole "
		+ "review. Where you are sure it is right as it stands, say why in a line and go on.")


## The look's pictures, as content blocks, or [] when they could not be taken.
func _pictures() -> Array:
	if not ModelShot.possible() or assistant.world == null:
		return []
	var shot: ModelShot = assistant._ensure_shot()
	var views: Array = []
	for view: Array in VIEWS:
		var block: Dictionary = await shot.block(assistant.world, str(view[0]), assistant.scenery)
		if block.is_empty():
			return []
		views.append(block)
	return views


## PLAN_TOOL, as a session is served it.
static func plan_definition() -> Dictionary:
	return {
		"name": PLAN_TOOL,
		"description": ("The two or three features anyone would know the subject by, "
			+ "planned before its first brick: not its box, but what a person names it by "
			+ "(a lighthouse's lantern, an elephant's ears and trunk, a galleon's masts), "
			+ "each with its proportion against the whole, from what you know of the real "
			+ "thing (a lantern as wide as the tower's top and a fifth of its height; ears as "
			+ "tall as the head; masts taller than the hull is long), and the technique its "
			+ "form needs (round: a body of revolution; thin: plates and wedge plates; curved: "
			+ "curved slopes; smooth: SNOT; a moulded part where real sets use one). Call it "
			+ "after how_real_sets_build_this and before the first submit_design. Once the "
			+ "model stands, the whole review shows its front and side to read each against "
			+ "this."),
		"input_schema": {
			"type": "object",
			"properties": {
				"subject": {"type": "string"},
				"features": {"type": "array", "minItems": 1, "maxItems": MOST,
					"description": "the two or three the subject is known by",
					"items": {
						"type": "object",
						"properties": {
							"name": {"type": "string", "description":
								"what a person would call it"},
							"proportion": {"type": "string", "description": ("its size "
								+ "against the whole on the real thing: how wide, tall or "
								+ "long against the body, where it sits, how it tapers")},
							"technique": {"type": "string", "description":
								"how its form is built"},
						},
						"required": ["name", "proportion", "technique"],
						"additionalProperties": false,
					}},
			},
			"required": ["subject", "features"],
			"additionalProperties": false,
		},
	}


## TOOL, as a session is served it; its annotations are CommandSocket.HINTS'.
static func definition() -> Dictionary:
	return {"name": TOOL, "description": ("Answer the look at its features a design's "
		+ "first whole review asks for, from the front and side pictures it handed you: each "
		+ "feature's proportion on the real thing, what the pictures show of it against the "
		+ "whole, whether it is off, and the one to rebuild. Only when a review asks."),
		"input_schema": SCHEMA}


const SCHEMA: Dictionary = {
	"type": "object",
	"properties": {
		"features": {"type": "array", "minItems": 1, "items": {
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"real": {"type": "string", "description":
					"its proportion against the whole on the real thing"},
				"seen": {"type": "string", "description": ("what the front and side "
					+ "pictures show of it against the whole, in studs and plates, as a judge "
					+ "shown only the pictures would say it")},
				"off": {"type": "boolean", "description": "true when seen is not real"},
				"built": {"type": "boolean", "description":
					"false when this build has none of it yet"},
			},
			"required": ["name", "real", "seen", "off"],
			"additionalProperties": false,
		}},
		"rebuild": {"type": "string", "description": ("the one most off, and how you will "
			+ "build it to its real proportion with the technique its form needs; empty when "
			+ "none is off")},
	},
	"required": ["features", "rebuild"],
	"additionalProperties": false,
}
