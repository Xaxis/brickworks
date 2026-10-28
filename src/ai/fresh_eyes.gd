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
## So at a new design's first save, Claude Code on the person's subscription,
## a session of its own that never saw the designing, is shown the subject
## and the design's three pictures as the bench takes them (DesignPick.
## pictures), and asked what makes it read as the subject at a glance, what
## reads as a generic box, and the three changes a set designer would make,
## the biggest first. That save's answer carries them, where a session acts.
## It is shown no real set and told of none: what the subject needs is its
## own to say.
##
## Once a subject (Assistant.heard, fresh), whatever comes of it. Only a new
## design submitted from outside (the MCP port, the connector) onto a bare
## baseplate, the example a first visit opens on taken off first
## (Assistant.make_room), and never a chat about a selection. With no pictures,
## or no answer in time, the save says what it said before, word for word.
##
## With no Claude Code here (a browser tab, as the owner designs from
## claude.ai, or a machine without it) the only eyes at hand are the
## session's own (own_look): the save hands it the same three pictures and
## the eyes' own question, to answer as the eyes would, from the pictures
## alone, with TOOL before it builds on.
class_name FreshEyes
extends RefCounted

## The tool a session answers its own look with (own_look), served only
## where no Claude Code is found ([method tools]).
const TOOL := "fresh_eyes"

## The calls refused while the session's own look is unanswered (not_yet):
## after them it builds on as it would have, so a session is never stuck.
const MOST_REFUSED := 2

## The most the save waits for an answer. The session's call waits on it,
## and Claude Code's own limit for one is ten minutes (ClaudeCode.TOOL_TIMEOUT_MS).
const MOST_S := 240.0

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
}

var assistant: Assistant
## Whether a design of this subject went down on a bare baseplate.
var fresh: bool = false
## Whether the eyes have been asked for this subject: then never again.
var asked: bool = false
## The last answer, {reads_as, generic, changes, seconds, model} or {error},
## for the log and a probe.
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
## first time only: the three changes, the session's own look to answer
## (own_look), or "" (and the save says what it did).
func after_save() -> Variant:
	if asked or not fresh or assistant == null or assistant._busy \
			or not assistant._outside_standing or assistant.asked_about_selection():
		return ""
	asked = true
	if ClaudeCode.found().is_empty():
		return await own_look()
	if not ModelShot.possible():
		return ""
	var subject: String = subject_of(assistant)
	var started_ms: int = Time.get_ticks_msec()
	if _shot == null:
		_shot = ModelShot.new()
		_shot.library = assistant.library
		_shot.give_up_after = 60.0
		assistant.add_child(_shot)
	var images: Array[Image] = await DesignPick.pictures(_shot, assistant.world,
		assistant.scenery, assistant.library)
	if images.size() < DesignPick.VIEWS.size():
		last = {"error": "no pictures"}
		print("fresh eyes: no pictures, nothing said")
		return ""
	var views: Array = []
	for image: Image in images:
		views.append(await _shot.encode(image))
	var critic := DesignPick.new()
	var thread := Thread.new()
	thread.start(critic.put.bind(message(subject, views), SCHEMA))
	var until: int = Time.get_ticks_msec() + int(MOST_S * 1000.0)
	while thread.is_alive():
		if Time.get_ticks_msec() > until:
			critic.stop()
		await assistant.get_tree().process_frame
	var said: Variant = thread.wait_to_finish()
	last = _answer(said if said is Dictionary else {})
	last["seconds"] = (Time.get_ticks_msec() - started_ms) / 1000.0
	if last.has("error"):
		print("fresh eyes: %.1f s, no answer: %s" % [last["seconds"], last["error"]])
		return ""
	print("fresh eyes: %.1f s (%s): %s" % [last["seconds"], last["model"],
		JSON.stringify({"reads_as": last["reads_as"], "generic": last["generic"],
			"changes": last["changes"]})])
	# Saved, as next_review would have marked it.
	assistant._outside_unsaved = false
	return said_to_session(last)


## The subject the eyes are told: the brief the session was started on or
## its first design call named (Assistant.heard), else what it was submitted as.
static func subject_of(from: Assistant) -> String:
	for said: String in [from._heard_fresh, from._named, from._heard]:
		if not said.strip_edges().is_empty():
			return said.strip_edges().left(400)
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
		+ "what is there or a bigger model.")


## The one message the eyes are sent: the prompt, then the pictures, each
## with what it is.
static func message(subject: String, views: Array) -> Dictionary:
	var content: Array = [{"type": "text", "text": prompt(subject)}]
	for i: int in views.size():
		content.append({"type": "text", "text": "The %s:" % DesignPick.SAID[DesignPick.VIEWS[i]]})
		content.append(views[i])
	return {"type": "user", "message": {"role": "user", "content": content}}


## DesignPick.put's answer read: {reads_as, generic, changes, model} or {error}.
static func _answer(said: Dictionary) -> Dictionary:
	if not said.has("result"):
		return {"error": str(said.get("error", "no answer"))}
	var event: Dictionary = said["result"]
	var found: Variant = event.get("structured_output")
	if bool(event.get("is_error", false)) or not (found is Dictionary) \
			or not (found.get("changes") is Array) or (found["changes"] as Array).is_empty():
		return {"error": str(event.get("result", "no answer")).left(300)}
	var changes: Array[String] = []
	for change: Variant in found["changes"]:
		if not str(change).strip_edges().is_empty():
			changes.append(str(change).strip_edges())
	if changes.is_empty():
		return {"error": "no changes named"}
	return {"reads_as": str(found.get("reads_as", "")).strip_edges(),
		"generic": str(found.get("generic", "")).strip_edges(),
		"changes": changes.slice(0, 3), "model": str(said.get("model", ""))}


## The answer as the save says it to the session.
static func said_to_session(answer: Dictionary) -> String:
	var lines := PackedStringArray([
		"Not finished yet: a fresh pair of eyes looked at it. Another Claude, shown only "
		+ "the subject and three pictures of the model, never what you meant it to be, says:",
		"  At a glance: %s" % answer["reads_as"],
		"  Reads as generic: %s" % answer["generic"],
		"The changes that would most make it read as the subject, the biggest first:"])
	var changes: Array = answer["changes"]
	for n: int in changes.size():
		lines.append("  %d. %s" % [n + 1, changes[n]])
	lines.append("Make them now, before you answer: edit_model for each (submit_design "
		+ "again when one changes the whole shape), then view_model to see that it reads, "
		+ "then save_model. Where you are sure one is wrong for this subject, say why in a "
		+ "line and make the others.")
	return "\n".join(lines)


## Where no Claude Code is found, the eyes are the session's own. The save
## hands it the three pictures and the eyes' own question, framed as the
## eyes are asked it: a judge shown only the subject and the pictures,
## never what it meant the model to be. Every other call waits for the
## answer (not_yet), in the eyes' shape (TOOL), and then the session makes
## the changes it named. "" when no picture could be taken, and the save
## says what it said before.
func own_look() -> Variant:
	var views: Array = await _pictures()
	if views.is_empty():
		last = {"error": "no pictures"}
		print("fresh eyes: no Claude Code here and no pictures, nothing said")
		return ""
	last = {"own": true, "refused": 0}
	print("fresh eyes: no Claude Code here (ClaudeCode.found() is empty): the session's "
		+ "own look asked, with %d pictures" % views.size())
	# Saved, as next_review would have marked it.
	assistant._outside_unsaved = false
	var content: Array = (message(subject_of(assistant), views)["message"]["content"] as Array)
	return [{"type": "text", "text": OWN_OPENING}] + content \
		+ [{"type": "text", "text": OWN_ASK % TOOL}]


const OWN_OPENING := ("Not finished yet: now look at it with a fresh pair of eyes. A judge "
	+ "is shown only the subject and the three pictures below, never what you meant it to "
	+ "be or how it was made, and asked what follows. Answer as that judge: from the "
	+ "pictures alone, saying what they show, not what you meant each part to be.")

const OWN_ASK := ("Answer before any other call: %s, with reads_as (what it reads as at a "
	+ "glance), generic (what reads as a generic box, slab or stack) and changes (the three, "
	+ "the biggest first). Then make them: edit_model for each (submit_design again when one "
	+ "changes the whole shape), then view_model to see that it reads, then save_model. "
	+ "Where you are sure one is wrong for this subject, say why in a line and make the others.")


## Whether the session's own look waits for its answer.
func waiting() -> bool:
	return bool(last.get("own", false)) and not last.has("changes") \
		and not last.has("unanswered")


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
	last = {"own": true, "refused": last["refused"], "reads_as": reads_as,
		"generic": generic, "changes": changes.slice(0, 3)}
	print("fresh eyes: the session's own look (%d refused): %s" % [last["refused"],
		JSON.stringify({"reads_as": reads_as, "generic": generic, "changes": last["changes"]})])
	return ("Now make them, the biggest first: edit_model for each (submit_design again when "
		+ "one changes the whole shape), then view_model to see that it reads, then "
		+ "save_model. Where you are sure one is wrong for this subject, say why in a line "
		+ "and make the others.")


## TOOL, for a session to answer its own look with: served only where no
## Claude Code is found, so where it is the tools are main's.
static func tools() -> Array:
	if not ClaudeCode.found().is_empty():
		return []
	var schema: Dictionary = SCHEMA.duplicate(true)
	schema["additionalProperties"] = false
	return [{"name": TOOL, "description": ("Answer the fresh look a new design's first "
		+ "save asks for, from the three pictures it handed you alone: what the model "
		+ "reads as, what reads as a generic box, and the three changes that would most "
		+ "make it read as the subject. Only when a save asks."), "input_schema": schema,
		"annotations": {"title": "Say what it reads as", "readOnlyHint": true,
			"openWorldHint": false}}]


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
