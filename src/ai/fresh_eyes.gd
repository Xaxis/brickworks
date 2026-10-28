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
##
## And once more, last (final_look): at the first whole save after the
## creative pass, the eyes in the first look's form are shown the model as
## it stands and what they asked first, and say what landed, then done, or
## the one change it most needs. Later looks at the saves that followed the
## first lost head to head: they took the saves where next_review hands
## over the creative pass, and the pass ran in 21 of 44 sessions against 30
## of 41 (design316). So this one comes only after the pass, and joins
## what the save says rather than standing in its place.
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
	final = {}


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


# -- the final look, after the creative pass ----------------------------------


## The tool a session answers its own final look with (final_look), served
## wherever TOOL is ([method final_tools]).
const FINAL_TOOL := "fresh_eyes_final"

## The final look's answer: what landed of what the first look asked, so
## what is asked now is asked of what stands; then done, or the one change.
## One: told three again, relay sessions made one of them or none (design316).
const FINAL: Dictionary = {
	"type": "object",
	"properties": {
		"landed": {"type": "string", "description":
			"for each change the first look asked for: whether it shows in the pictures "
			+ "and whether it worked"},
		"reads_as": SCHEMA["properties"]["reads_as"],
		"generic": SCHEMA["properties"]["generic"],
		"done": {"type": "boolean", "description":
			"true only when it reads as the subject at a glance and nothing in it reads as "
			+ "a generic box, slab or stack; then no change"},
		"change": {"type": "string", "description":
			"the one change that would now most make it read as the subject: where on the "
			+ "model, and what to build there; empty when done"},
	},
	"required": ["landed", "reads_as", "generic", "done", "change"],
}

## The final look: {} until it is asked, once a subject. Then its answer
## {landed, reads_as, generic, done, change}, the session's own {own,
## refused} while it waits for one, or {error}.
var final: Dictionary = {}


## A whole save's answer once the first look is past: next_review's, and
## after it the final look, when the save follows a completed creative pass
## (final_due). What next_review says comes first, the creative pass's line
## and any close look or reminder it hands, and is never left out. Not held
## back for them: of 44 browser-tab sessions (design317t), 30 ended at the
## save after the first look whatever it handed, a close look or the
## surface pass, and 24 of those at the save that said what the pass added.
func reviewed() -> Variant:
	# Whether the pass's result is said at this save (Assistant._creative_passed).
	var closing: bool = not assistant._outside_creative.is_empty()
	var more: Variant = await assistant.next_review()
	if not final_due(closing):
		return more
	var look: Variant = await final_look()
	if look is String and (look as String).is_empty():
		return more
	if more is Array:
		return (more as Array) + (look as Array if look is Array
			else [{"type": "text", "text": str(look)}])
	return Assistant._joined(str(more), look)


## Whether this save's answer gets the final look: the first look named its
## changes; the creative pass was handed and what it added said, at this
## save or before (and at this one not "nothing added", which asks for a
## touch and a save first); and it has not been asked for this subject.
func final_due(closing: bool) -> bool:
	if not final.is_empty() or not fresh or not last.has("changes") \
			or assistant._busy or not assistant._outside_standing \
			or assistant.asked_about_selection():
		return false
	if not assistant._outside_creative_handed or not assistant._outside_creative.is_empty():
		return false
	return not (closing and assistant._creative_record == "nothing added")


## The final look, in the first look's form: the separate eyes, whose one
## change the save says, or the session's own (last's own), handed the
## pictures and the question to answer with FINAL_TOOL. "" when the eyes
## said done, or no picture or answer came: the save says what it would have.
func final_look() -> Variant:
	final = {"asked": true}
	var views: Array = await _pictures()
	if views.is_empty():
		final = {"error": "no pictures"}
		print("fresh eyes: final look, no pictures, nothing said")
		return ""
	var sent: Dictionary = final_message(subject_of(assistant), views, last["changes"])
	if bool(last.get("own", false)):
		final = {"own": true, "refused": 0}
		print("fresh eyes: final look, the session's own, asked after the creative pass "
			+ "(it came to: %s), with %d pictures" % [assistant._creative_record, views.size()])
		return [{"type": "text", "text": FINAL_OPENING}] + (sent["message"]["content"] as Array) \
			+ [{"type": "text", "text": FINAL_ASK % FINAL_TOOL}]
	var started_ms: int = Time.get_ticks_msec()
	var critic := DesignPick.new()
	var thread := Thread.new()
	thread.start(critic.put.bind(sent, FINAL))
	var until: int = Time.get_ticks_msec() + int(MOST_S * 1000.0)
	while thread.is_alive():
		if Time.get_ticks_msec() > until:
			critic.stop()
		await assistant.get_tree().process_frame
	var said: Variant = thread.wait_to_finish()
	final = _final_answer(said if said is Dictionary else {})
	final["seconds"] = (Time.get_ticks_msec() - started_ms) / 1000.0
	if final.has("error"):
		print("fresh eyes: final look, %.1f s, no answer: %s" % [final["seconds"], final["error"]])
		return ""
	print("fresh eyes: final look, %.1f s (%s), after the creative pass (it came to: %s): %s" % [
		final["seconds"], final["model"], assistant._creative_record, _final_json(final)])
	return "" if final["done"] else final_said(final)


## The final look's question: the first's, of the model as it stands, told
## what the first look asked for, to say first what of it landed.
static func final_prompt(subject: String, asked: Array) -> String:
	var listed := PackedStringArray()
	for n: int in asked.size():
		listed.append("  %d. %s" % [n + 1, asked[n]])
	return ("A LEGO® model was built to this brief: \"%s\"\n\n" % subject
		+ "Below are three pictures of it, all of the same model. You did not build it "
		+ "and know nothing of how it was made: look at it as a LEGO® set designer would "
		+ "on first sight, from the pictures alone. Picture quality says nothing.\n\n"
		+ "A first look at an earlier build of it asked for these changes, the biggest "
		+ "first:\n%s\nIt has been changed since, and finished. " % "\n".join(listed)
		+ "First, for each of those changes, whether it shows in the pictures and whether "
		+ "it worked. Then what it reads as at a glance, and what in it makes it read as "
		+ "the subject. Then what still reads as a generic box, slab, block or stack rather "
		+ "than as the subject: its silhouette, its proportions, the shape of each mass, "
		+ "the features anyone would know the subject by, and its colours.\n\n"
		+ "If it reads as the subject at a glance with nothing generic left, say it is done "
		+ "and name no change. Otherwise the one change that would now most make it read "
		+ "as the subject at a glance: one of those that did not land, said again more "
		+ "plainly, or a new one. It is one concrete change to how it is built, as a set "
		+ "designer would make it: which part of the model, and what to build there, said "
		+ "in bricks, plates, slopes, curves and studs (\"the top storey is as wide as the "
		+ "one under it: step it in one stud on each side\"). A change to its shape or its "
		+ "features that the subject itself calls for: not more parts, more of what is "
		+ "there or a bigger model.\n\n"
		+ "Everything the brief asks for stays. Each thing it names, and what it says of "
		+ "it (its colour, where it is, what it is doing), is what the person wants: no "
		+ "change takes one away, covers it up or builds it as something else. Where one "
		+ "reads poorly, or stands in another's way, the change makes it read better as "
		+ "what the brief says it is.")


## The final look's one message: as the first's (message), its question
## final_prompt's.
static func final_message(subject: String, views: Array, asked: Array) -> Dictionary:
	var sent: Dictionary = message(subject, views)
	var content: Array = sent["message"]["content"]
	content[0] = {"type": "text", "text": final_prompt(subject, asked)}
	return sent


## DesignPick.put's answer to the final look read (_final_read), or {error}.
static func _final_answer(said: Dictionary) -> Dictionary:
	if not said.has("result"):
		return {"error": str(said.get("error", "no answer"))}
	var event: Dictionary = said["result"]
	var found: Variant = event.get("structured_output")
	if bool(event.get("is_error", false)) or not (found is Dictionary):
		return {"error": str(event.get("result", "no answer")).left(300)}
	var read: Dictionary = _final_read(found)
	if read.has("error"):
		return read
	read["model"] = str(said.get("model", ""))
	return read


## A final look's answer, the eyes' or the session's own: {landed,
## reads_as, generic, done, change}, done when it said so (then no change),
## or {error} when it left out what it was asked.
static func _final_read(found: Dictionary) -> Dictionary:
	var read: Dictionary = {}
	for key: String in ["landed", "reads_as", "generic", "change"]:
		read[key] = str(found.get(key, "")).strip_edges()
	read["done"] = bool(found.get("done", false))
	if read["done"]:
		read["change"] = ""
	if str(read["landed"]).is_empty() or str(read["reads_as"]).is_empty() \
			or str(read["generic"]).is_empty() or (not read["done"] and str(read["change"]).is_empty()):
		return {"error": "not answered in full"}
	return read


static func _final_json(answer: Dictionary) -> String:
	return JSON.stringify({"landed": answer["landed"], "reads_as": answer["reads_as"],
		"generic": answer["generic"], "done": answer["done"], "change": answer["change"]})


## The eyes' final answer as the save says it to the session.
static func final_said(answer: Dictionary) -> String:
	return "\n".join(PackedStringArray([
		"Not finished yet: the fresh pair of eyes looked once more, now the creative pass is "
		+ "in. Shown only the subject, the changes it asked for first and three pictures of "
		+ "the model as it stands, never what you meant it to be, it says:",
		"  Of what it asked: %s" % answer["landed"],
		"  At a glance: %s" % answer["reads_as"],
		"  Reads as generic: %s" % answer["generic"],
		"The one change that would now most make it read as the subject:",
		"  %s" % answer["change"],
		FINAL_MAKE]))


const FINAL_THEN := ("edit_model, then view_model to see that it reads, then save_model, "
	+ "keeping what the creative pass added. If you are sure it is wrong for this subject, "
	+ "say why in a line.")

const FINAL_MAKE := "Make it now, before you answer: " + FINAL_THEN

const FINAL_OPENING := ("Not finished yet: one last look with the fresh pair of eyes, now "
	+ "the creative pass is in. The judge is shown only the subject, the changes the first "
	+ "look asked for and the three pictures below, never what you meant it to be or how it "
	+ "was made, and asked what follows. Answer as that judge: from the pictures alone, "
	+ "saying what they show, not what you meant each part to be.")

const FINAL_ASK := ("Answer before any other call: %s, with landed (whether each change the "
	+ "first look asked for shows and worked), reads_as, generic, and done: true, with no "
	+ "change, only when nothing in it reads as generic; else change, the one change that "
	+ "would now most make it read as the subject. Then make it: " + FINAL_THEN)


## Whether the session's own final look waits for its answer.
func final_waiting() -> bool:
	return bool(final.get("own", false)) and not final.has("done") \
		and not final.has("unanswered")


## What a call is told while the session's own final look waits, as
## not_yet is for the first: "" when it goes ahead. The answer and a save
## go ahead; anything else is refused, up to MOST_REFUSED times.
func final_not_yet(tool: String) -> String:
	if not final_waiting() or tool in [FINAL_TOOL, "save_model"]:
		return ""
	if int(final["refused"]) >= MOST_REFUSED:
		final["unanswered"] = true
		print("fresh eyes: the session's own final look never answered; %s goes ahead" % tool)
		return ""
	final["refused"] = int(final["refused"]) + 1
	print("fresh eyes: %s refused, the session's own final look unanswered" % tool)
	return ("Not yet: first answer the final fresh look the save asked for. Call %s with "
		% FINAL_TOOL + "landed, reads_as, generic, done and change, from the save's three "
		+ "pictures alone, as the judge would; then make the change.")


## The session's own final look, answered with FINAL_TOOL: kept ([member
## final]); done ends it, and the one change is to be made now.
func final_answered(input: Dictionary) -> String:
	if not final_waiting():
		return "Nothing to answer: the first save after the creative pass asks for this, once."
	var read: Dictionary = _final_read(input)
	if read.has("error"):
		return ("Answer in full: landed, reads_as, generic, and done with change: done true "
			+ "and no change only when nothing reads as generic, else the one change.")
	read["own"] = true
	read["refused"] = final["refused"]
	final = read
	print("fresh eyes: the session's own final look (%d refused): %s" % [final["refused"],
		_final_json(final)])
	if final["done"]:
		return "Then it is finished as it stands: nothing in it reads as generic."
	return "Now make it: %s" % FINAL_THEN


## FINAL_TOOL, for a session to answer its own final look with: served
## wherever TOOL is (tools), and nowhere else.
static func final_tools() -> Array:
	if tools().is_empty():
		return []
	var schema: Dictionary = FINAL.duplicate(true)
	schema["additionalProperties"] = false
	return [{"name": FINAL_TOOL, "description": ("Answer the final fresh look the first "
		+ "save after the creative pass asks for, from the three pictures it handed you "
		+ "alone: what landed of the changes the first look asked for, what the model reads "
		+ "as, what still reads as a generic box, and done, or the one change that would now "
		+ "most make it read as the subject. Only when a save asks."), "input_schema": schema,
		"annotations": {"title": "Say what it reads as now", "readOnlyHint": true,
			"openWorldHint": false}}]
