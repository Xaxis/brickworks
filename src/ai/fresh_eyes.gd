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
## (Assistant.make_room), and never a chat about a selection. With no Claude Code here
## (a browser, or a machine without it), no pictures, or no answer in time,
## the save says what it said before, word for word.
class_name FreshEyes
extends RefCounted

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
## first time only: the three changes, or "" (and the save says what it did).
func after_save() -> String:
	if asked or not fresh or assistant == null or assistant._busy \
			or not assistant._outside_standing or assistant.asked_about_selection():
		return ""
	asked = true
	if ClaudeCode.found().is_empty() or not ModelShot.possible():
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
