## A fresh pair of eyes on a new design, once, at its first save.
##
## A session looks at its own build and keeps it: 44 of 45 bench sessions
## called view_model and 42 review_model, and the builds the judge then
## called "a flat tan box with pillars" and "stacked cylinders" were kept as
## they stood. Its review (review_model) is its own, made knowing everything
## it meant the model to be, so it sees what it meant. The bench's judge,
## shown the pictures and nothing else, says at once what reads as a generic
## box and what the subject is missing.
##
## So a new design's first whole save hands the session the design's three
## pictures as the bench takes them (DesignPick.pictures) and the judge's
## question: what makes it read as the subject at a glance, what reads as a
## generic box, and the three changes a set designer would make, the biggest
## first. It answers as a judge shown only the subject and the pictures,
## never what it meant the model to be, with TOOL before any other call goes
## ahead (not_yet), then makes them. It is shown no real set and told of
## none: what the subject needs is its own to say.
##
## A separate Claude Code session asked the same question did no better: on
## one path, one night, 23% against the real sets to the session's own 24%,
## and 49% head to head, for about 40 s a save and a second session
## (design328). So the eyes are the session's own, with Claude Code or without.
##
## Once a subject (Assistant.heard, fresh), whatever comes of it. Only a new
## design submitted from outside (the MCP port, the connector) onto a bare
## baseplate, the example a first visit opens on taken off first
## (Assistant.make_room), and never a chat about a selection. With no
## pictures, the save says what it said before, word for word.
class_name FreshEyes
extends RefCounted

## The tool a session answers the fresh look with ([method definition]).
const TOOL := "fresh_eyes"

## The calls refused while the fresh look is unanswered (not_yet): after
## them it builds on as it would have, so a session is never stuck.
const MOST_REFUSED := 2

## The answer's shape. What it reads as comes first, so the changes are made
## on what was seen.
const SCHEMA: Dictionary = {
	"type": "object",
	"properties": {
		"reads_as": {"type": "string", "description":
			"what it reads as at a glance, and what in it reads as the subject"},
		"generic": {"type": "string", "description":
			"what reads as a generic box, slab or stack rather than as the subject"},
		"changes": {"type": "array", "minItems": 3, "maxItems": 3,
			"items": {"type": "string"}, "description":
				"the three changes that would most make it read as the subject, the "
				+ "biggest first: where on the model, and what to build there"},
	},
	"required": ["reads_as", "generic", "changes"],
	"additionalProperties": false,
}

var assistant: Assistant
## Whether a design of this subject went down on a bare baseplate.
var fresh: bool = false
## Whether the eyes have been asked for this subject: then never again.
var asked: bool = false
## The look asked, {refused}, then answered, {refused, reads_as, generic,
## changes}, or let go of, {refused, unanswered}; {error} with no pictures.
## For the log and a probe.
var last: Dictionary = {}
var _shot: ModelShot = null


## A new subject begins (Assistant.heard, fresh): nothing of the last one's
## carries over.
func begin() -> void:
	fresh = false
	asked = false
	last = {}


## A design from outside stands; [param bare] when nothing stood before it.
## Decided as it is submitted, not as the subject begins: a connector tab
## opens on the example car, which a design takes off (relay, design311).
func designed(bare: bool) -> void:
	fresh = fresh or bare


## What a whole save of a new design says in place of its close looks, the
## first time only: the three pictures and the judge's question, framed as
## the judge is asked it, for the session to answer with TOOL; or "" (and
## the save says what it did).
func after_save() -> Variant:
	if asked or not fresh or assistant == null or assistant._busy \
			or not assistant._outside_standing or assistant.asked_about_selection():
		return ""
	asked = true
	var views: Array = await _pictures()
	if views.is_empty():
		last = {"error": "no pictures"}
		print("fresh eyes: no pictures, nothing said")
		return ""
	last = {"refused": 0}
	print("fresh eyes: the session's own look asked, with %d pictures" % views.size())
	# Saved, as next_review would have marked it.
	assistant._outside_unsaved = false
	return [{"type": "text", "text": OWN_OPENING}] + shown(subject_of(assistant), views) \
		+ [{"type": "text", "text": OWN_ASK % TOOL}]


## The most of the brief the eyes are told, in characters: an idea of the
## owner's kind runs to 350, and was judged on the session's "taco food truck".
const SUBJECT_MOST := 2000


## The subject the eyes are told: the person's request in their own words,
## whole (Assistant.asked, or submit_design's brief from a connector chat).
## Else the brief the session was started on or its first design call named
## (Assistant.heard), else what it was submitted as. Told the session's
## "taco food truck" for a brief of a surfboard on its roof, the eyes said to
## take the surfboard off (ideas-2026-10-27-critic315).
static func subject_of(from: Assistant) -> String:
	for said: String in [from._their_words, from._words_passed, from._heard_fresh,
			from._named, from._heard]:
		if not said.strip_edges().is_empty():
			return said.strip_edges().left(SUBJECT_MOST)
	return "(not said)"


static func prompt(subject: String) -> String:
	return ("A LEGO® model was built to this brief: \"%s\"\n\n" % subject
		+ "Below are three pictures of it, all of the same model. You did not build it "
		+ "and know nothing of how it was made: look at it as a LEGO® set designer would "
		+ "on first sight, from the pictures alone. Picture quality says nothing.\n\n"
		+ "First, what it reads as at a glance, and what in it makes it read as the "
		+ "subject. Then what reads as a generic box, slab, block or stack rather than as "
		+ "the subject: its silhouette, its proportions, the shape of each mass, the "
		+ "features anyone would know the subject by, and its colours.\n\n"
		+ "Then the three changes that would most make it read as the subject at a "
		+ "glance, the biggest first. Each is one concrete change to how it is built, as a "
		+ "set designer would make it: which part of the model, and what to build there, "
		+ "said in bricks, plates, slopes, curves and studs (\"the top storey is as wide "
		+ "as the one under it: step it in one stud on each side\"). Changes to its shape "
		+ "and its features that the subject itself calls for: not more parts, more of "
		+ "what is there or a bigger model.\n\n"
		+ "Everything the brief asks for stays. Each thing it names, and what it says of "
		+ "it (its colour, where it is, what it is doing), is what the person wants: no "
		+ "change takes one away, covers it up or builds it as something else. Where one "
		+ "reads poorly, or stands in another's way, the change makes it read better as "
		+ "what the brief says it is.")


## What the eyes are shown: the question, then the pictures, each with what
## it is.
static func shown(subject: String, views: Array) -> Array:
	var content: Array = [{"type": "text", "text": prompt(subject)}]
	for i: int in views.size():
		content.append({"type": "text", "text": "The %s:" % DesignPick.SAID[DesignPick.VIEWS[i]]})
		content.append(views[i])
	return content


const OWN_OPENING := ("Not finished yet: now look at it with a fresh pair of eyes. A judge "
	+ "is shown only the subject and the three pictures below, never what you meant it to "
	+ "be or how it was made, and asked what follows. Answer as that judge: from the "
	+ "pictures alone, saying what they show, not what you meant each part to be.")

const OWN_ASK := ("Answer before any other call: %s, with reads_as (what it reads as at a "
	+ "glance), generic (what reads as a generic box, slab or stack) and changes (the three, "
	+ "the biggest first). Then make them: edit_model for each (submit_design again when one "
	+ "changes the whole shape), then view_model to see that it reads, then save_model. "
	+ "Where you are sure one is wrong for this subject, say why in a line and make the others.")


## Whether the fresh look waits for its answer.
func waiting() -> bool:
	return last.has("refused") and not last.has("changes") and not last.has("unanswered")


## What a call is told while the session's own look waits for its answer:
## "" when it goes ahead. The answer goes ahead, and so does a save, so
## what stands is never lost; anything else is refused, up to MOST_REFUSED
## times.
func not_yet(tool: String) -> String:
	if not waiting() or tool in [TOOL, "save_model"]:
		return ""
	if int(last["refused"]) >= MOST_REFUSED:
		last["unanswered"] = true
		print("fresh eyes: the session's own look never answered; %s goes ahead" % tool)
		return ""
	last["refused"] = int(last["refused"]) + 1
	print("fresh eyes: %s refused, the session's own look unanswered" % tool)
	return ("Not yet: first answer the fresh look the save asked for. Call %s with "
		% TOOL + "reads_as, generic and the three changes, from the save's three pictures "
		+ "alone, as the judge would; then make the changes.")


## The session's own look, answered with TOOL: kept as the eyes' answer is
## ([member last]), and the changes it named are to be made now.
func answered(input: Dictionary) -> String:
	if not waiting():
		return "Nothing to answer: a new design's first save asks for this, once."
	var changes: Array[String] = []
	for change: Variant in (input.get("changes") as Array if input.get("changes") is Array else []):
		if not str(change).strip_edges().is_empty():
			changes.append(str(change).strip_edges())
	var reads_as: String = str(input.get("reads_as", "")).strip_edges()
	var generic: String = str(input.get("generic", "")).strip_edges()
	if reads_as.is_empty() or generic.is_empty() or changes.size() < 3:
		return ("Answer in full: reads_as, generic, and changes, the three changes, the "
			+ "biggest first.")
	last = {"refused": last["refused"], "reads_as": reads_as,
		"generic": generic, "changes": changes.slice(0, 3)}
	print("fresh eyes: the session's own look (%d refused): %s" % [last["refused"],
		JSON.stringify({"reads_as": reads_as, "generic": generic, "changes": last["changes"]})])
	return ("Now make them, the biggest first: edit_model for each (submit_design again when "
		+ "one changes the whole shape), then view_model to see that it reads, then "
		+ "save_model. Where you are sure one is wrong for this subject, say why in a line "
		+ "and make the others.")


## TOOL, as a session is served it; its annotations are CommandSocket.HINTS'.
static func definition() -> Dictionary:
	return {"name": TOOL, "description": ("Answer the fresh look a new design's first "
		+ "save asks for, from the three pictures it handed you alone: what the model "
		+ "reads as, what reads as a generic box, and the three changes that would most "
		+ "make it read as the subject. Only when a save asks."), "input_schema": SCHEMA}


## The design's three pictures as the bench takes them, as content blocks,
## or [] when they could not be taken.
func _pictures() -> Array:
	if not ModelShot.possible():
		return []
	if _shot == null:
		_shot = ModelShot.new()
		_shot.library = assistant.library
		_shot.give_up_after = 60.0
		assistant.add_child(_shot)
	var images: Array[Image] = await DesignPick.pictures(_shot, assistant.world,
		assistant.scenery, assistant.library)
	if images.size() < DesignPick.VIEWS.size():
		return []
	var views: Array = []
	for image: Image in images:
		views.append(await _shot.encode(image))
	return views
