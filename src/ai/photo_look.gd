## A new design's own front and side set beside a photograph of the real
## thing, at its first whole review.
##
## Set beside the real set, our designs lose on one defining feature's form
## far more often than on their box (design16). Asked to look at its named
## features in its own front and side (design17), every session looked,
## named one off and rebuilt it, and the judge named the same features wrong
## all the same: a session reads its pictures against its memory of the
## thing, and memory was wrong. A drum remembered narrow and black was built
## so; wings read as right in studs were slabs to the judge. Only 2 of 5
## sessions had asked find_reference for a photograph, and none was shown
## one beside its own model.
##
## So a design's first whole review (review_model with no assembly) leads
## with the look: a photograph of the real thing, from Wikimedia Commons,
## the one the session found (find_reference) or, when it asked for none,
## one found for it with its own words for the subject; then its model from
## the view the photograph's title names (a three-quarter view, as most are
## taken, when it names none), and from the front and the side.
## It is asked to compare the silhouettes, then each feature's form and size
## against the whole, and settle each difference: rebuild it or keep it, and
## why, answered with TOOL before any other change goes ahead (not_yet).
## What differs and what to do is the session's to say: nothing is changed
## for it. A subject with no photograph is told so, and compares against
## what it knows.
##
## Never a picture of anything built of bricks (ReferenceFinder.of_lego):
## the look is of the real thing, and while a set is held out a builder's
## model of it is the set's answer.
class_name PhotoLook
extends RefCounted

## The tool a session answers the look with ([method definition]).
const TOOL := "compare_with_photo"

## The calls refused while the look is unanswered (not_yet): after them it
## goes ahead, so a session is never stuck.
const MOST_REFUSED := 2

## The calls that go ahead while the look waits: its answer, a save, the
## looks that help it answer, and another photograph.
const GO_AHEAD: Array[String] = [TOOL, "save_model", "view_model", "look_at_model",
	"find_reference"]

## The most searches made for a session that asked for no photograph.
const MOST_SEARCHES := 2

## A view of the model as ModelShot names it, and what it is called.
const CALLED: Dictionary = {
	"corner": "the corner (a three-quarter view, as most photographs are taken)",
	"front": "the front (from +z)",
	"right": "the side (from +x)",
	"back": "the back (from -z)",
	"top": "above",
}

## The calls after which what the answer led to is counted: the review it
## sends the session on to, or a save.
const COUNTED_AT: Array[String] = ["review_model", "save_model"]

var assistant: Assistant
## The pictures the session's own find_reference brought, and its words.
var pictures: Array = []
var asked_for: String = ""
## Its words for the subject, by the tool that took them: plan_scale's
## and how_real_sets_build_this's subject.
var words: Dictionary = {}
## Whether a design of this subject went down on a bare baseplate.
var fresh: bool = false
## The look asked, {refused, photo}, then answered, {refused, photo,
## answer}, or let go of, {refused, photo, unanswered}; {error} with no
## pictures of the model. For the log and a probe.
var last: Dictionary = {}
## The model as it stood when the look was answered, until it is counted.
var _before: Dictionary = {}


## A new subject begins: nothing of the last one's carries over.
func begin() -> void:
	pictures = []
	asked_for = ""
	words = {}
	fresh = false
	last = {}
	_before = {}


## A design from outside stands; [param bare] when nothing stood before it.
func designed(bare: bool) -> void:
	fresh = fresh or bare


## The session's words for its subject, from [param tool].
func heard_from(tool: String, subject: String) -> void:
	if not subject.strip_edges().is_empty():
		words[tool] = subject.strip_edges()


## What the session's find_reference brought back.
func found(subject: String, got: Array) -> void:
	if got.is_empty():
		return
	pictures = got
	asked_for = subject.strip_edges()


## Whether the whole review of the design standing leads with the look.
func due() -> bool:
	if assistant == null or not fresh or not last.is_empty():
		return false
	return not assistant._busy and assistant._outside_standing \
		and assistant._outside_designed and not assistant.asked_about_selection()


## The look, as the whole review's answer, for the session to answer with
## TOOL; or "" when no picture of the model could be taken (the review says
## what it did).
func look() -> Variant:
	# Nothing searched for a model that cannot be drawn: a headless run.
	if not ModelShot.possible() or assistant.world == null:
		last = {"error": "no pictures"}
		print("photo look: no pictures of the model, nothing said")
		return ""
	var photo: Dictionary = await _photo()
	var picture: Dictionary = photo.get("picture", {}) as Dictionary
	# The view its title names, or a three-quarter view, as most are taken.
	var nearest: String = view_for(str(picture.get("title", "")))
	var views: Array[String] = [nearest if not nearest.is_empty() else "corner"]
	for view: String in ["front", "right"]:
		if not view in views:
			views.append(view)
	var shots: Array = await _shots(views)
	if shots.is_empty():
		last = {"error": "no pictures"}
		print("photo look: no pictures of the model, nothing said")
		return ""
	last = {"refused": 0, "photo": str(picture.get("title", ""))}
	print("photo look: asked, %s, the model from %s" % [_said_of(photo), ", ".join(views)])
	var content: Array = [{"type": "text", "text": opening(photo,
		assistant._measured(), assistant._outside_features)}]
	if not picture.is_empty():
		content.append({"type": "text", "text": photo_line(photo)})
		content.append({"type": "image", "source": {"type": "base64",
			"media_type": "image/png", "data": Marshalls.raw_to_base64(picture["bytes"])}})
	for n: int in views.size():
		content.append({"type": "text", "text": "Yours from %s%s:" % [CALLED[views[n]],
			", the view its title names" if n == 0 and not nearest.is_empty() else ""]})
		content.append(shots[n])
	content.append({"type": "text", "text": ASK % TOOL})
	return content


## The photograph to set beside the model: {picture, how, query}; how is
## "asked" (the session's own find_reference), "found" (searched for it
## with query) or "none" (tried, the queries searched).
func _photo() -> Dictionary:
	var own: Dictionary = first_of(pictures)
	if not own.is_empty():
		return {"picture": own, "how": "asked", "query": asked_for}
	var tried := PackedStringArray()
	for query: String in queries(words, assistant._named):
		if tried.size() >= MOST_SEARCHES:
			break
		tried.append(query)
		var got: Dictionary = first_of(await assistant.look_up(query))
		if not got.is_empty():
			return {"picture": got, "how": "found", "query": query}
	return {"how": "none", "tried": tried}


## The first of [param got] that is a photograph of a real thing, not of
## anything built of bricks, or {}.
static func first_of(got: Array) -> Dictionary:
	for one: Variant in got:
		var picture: Dictionary = one
		if not bool(picture.get("lego", false)) \
				and not ReferenceFinder.of_lego(str(picture.get("title", "")), ""):
			return picture
	return {}


## What to search for, from the session's own words for the subject: the
## real thing plan_scale was sized off, what the design was named, and the
## kind how_real_sets_build_this was asked about, cleaned and once each.
static func queries(heard: Dictionary, named: String) -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	for said: String in [str(heard.get("plan_scale", "")), named,
			str(heard.get("how_real_sets_build_this", ""))]:
		var query: String = cleaned(said)
		if not query.is_empty() and not seen.has(query.to_lower()):
			seen[query.to_lower()] = true
			out.append(query)
	return out


## [param said] as words to search Commons with: what a set's brief adds
## ("in the style of LEGO® City sets", "(LEGO Architecture style)") left
## out, for a photograph of the thing rather than of a set.
static func cleaned(said: String) -> String:
	var out: String = said.get_slice("\n", 0)
	out = RegEx.create_from_string("\\([^)]*\\)").sub(out, "", true)
	out = RegEx.create_from_string("(?i),?\\s*in the style of.*$").sub(out, "")
	out = RegEx.create_from_string("(?i)\\bLEGO\\b®?|®").sub(out, "", true)
	out = RegEx.create_from_string("\\s+").sub(out, " ", true)
	return out.strip_edges().trim_suffix(",").trim_suffix(".").strip_edges()


## The model's view nearest a photograph's angle, read off its title, or ""
## when the title names none.
static func view_for(title: String) -> String:
	var said: String = title.to_lower().replace("_", " ")
	for pair: Array in [["three.quarters?|3/4", "corner"],
			["aerial|from above|top view|overhead", "top"],
			["side( view)?|profile", "right"],
			["rear|back view", "back"],
			["front( view)?|frontal", "front"]]:
		if RegEx.create_from_string("\\b(%s)\\b" % pair[0]).search(said) != null:
			return pair[1]
	return ""


## What the look says before its pictures: why, the whole's size, and the
## features the design named, or that it named none.
static func opening(photo: Dictionary, measured: String, features: Array[String]) -> String:
	var said := PackedStringArray()
	said.append(OPENING)
	if str(photo.get("how", "")) == "none":
		var tried: PackedStringArray = photo.get("tried", PackedStringArray())
		said.append(("No photograph of the real thing came back from Wikimedia Commons%s. If it "
			% ("" if tried.is_empty() else " for \"%s\"" % "\", \"".join(tried)))
			+ "exists, find_reference with its own name (the make and model, the building, the "
			+ "animal) brings one to set beside these. Without one, read the pictures against "
			+ "what you know of it, as a judge would.")
	# The whole's size, its first sentence: the layers it goes on to are the
	# massing, not the form.
	var whole: String = measured.strip_edges().get_slice("\n", 0)
	if whole.contains(" Its massing"):
		whole = whole.get_slice(" Its massing", 0)
	if not whole.is_empty():
		said.append(whole)
	if features.is_empty():
		said.append("You named no features with the design: name the two or three the subject "
			+ "is known by in your answer.")
	else:
		said.append("The features you named with the design: %s." % ", ".join(features))
	return "\n\n".join(said)


const OPENING := ("Before the rest of the review: your model against the real thing. Read "
	+ "your model against a photograph of it, not against your memory of the thing: "
	+ "memory gets a feature's form wrong, and a model read against it reads as right. A judge "
	+ "who sets a model beside the real thing names one feature's form far more often than "
	+ "the box it fits in: a round part built too small or half hidden under the body, a thin "
	+ "part built as a thick slab, a part that tapers built blunt, a part the subject is "
	+ "known by left out. So compare form with form: the photograph's silhouette against "
	+ "yours, then each feature's shape and its size against the whole.")


## The photograph's caption: what it is, whose, and how it was found.
static func photo_line(photo: Dictionary) -> String:
	var picture: Dictionary = photo["picture"]
	var how: String = ("from your find_reference" if str(photo["how"]) == "asked"
		else "found for you with \"%s\"" % photo["query"])
	return ("The real thing, %s: %s — %s. Check it is the thing you are building: a name can "
		% [how, picture["title"], picture["credit"]]
		+ "bring back something else that shares it. If it is not, find_reference with the real "
		+ "thing's own name (its make and model, the building's name) and compare with what it "
		+ "brings.")


const ASK := ("Answer before any other change: %s, with photo (what the photograph shows), "
	+ "is_it (true when it is the thing you are building), silhouette (its outline against "
	+ "yours from the nearest view: its length against its height, where its mass sits, what "
	+ "stands out of it, and how yours differs), and features (each the subject is known by: "
	+ "name; photo, its form and its size against the whole as the photograph shows it; "
	+ "model, the same in yours, in studs and plates; settle, rebuild or keep; why, in a "
	+ "line). Then rebuild each you settle to rebuild, the most different first and before "
	+ "any detail: submit_design again when it changes the whole shape, edit_model when it is "
	+ "one part of it. Rebuild a feature to the photograph's form and proportion, not a stud "
	+ "nearer it. Then view_model from the photograph's angle to compare again, and "
	+ "review_model for the rest of the whole review.")


## How the photograph came, for the log.
static func _said_of(photo: Dictionary) -> String:
	match str(photo.get("how", "")):
		"asked":
			return "its own photo \"%s\" (find_reference \"%s\")" % [
				(photo["picture"] as Dictionary)["title"], photo["query"]]
		"found":
			return "a photo found for it \"%s\" (searched \"%s\")" % [
				(photo["picture"] as Dictionary)["title"], photo["query"]]
	return "no photo (searched \"%s\")" % "\", \"".join(
		photo.get("tried", PackedStringArray()) as PackedStringArray)


## Whether the look waits for its answer.
func waiting() -> bool:
	return last.has("refused") and not last.has("answer") and not last.has("unanswered")


## What a call is told while the look waits for its answer: "" when it goes
## ahead. The answer, a save, a look at the model and another photograph go
## ahead, and clearing the model lets the look go; anything else is
## refused, up to MOST_REFUSED times.
func not_yet(tool: String) -> String:
	if not waiting() or tool in GO_AHEAD:
		return ""
	# Taken off to start again: there is nothing left to look at.
	if tool == "clear_model":
		last["unanswered"] = true
		print("photo look: the model taken off, the look let go")
		return ""
	if int(last["refused"]) >= MOST_REFUSED:
		last["unanswered"] = true
		print("photo look: never answered; %s goes ahead" % tool)
		return ""
	last["refused"] = int(last["refused"]) + 1
	print("photo look: %s refused, the look unanswered" % tool)
	return ("Not yet: first answer the look beside the photograph the review asked for. Call "
		+ "%s with what the photograph shows, the silhouettes against each other, and " % TOOL
		+ "each feature's form in the photograph and in yours, settled rebuild or keep; then "
		+ "rebuild what you settled to.")


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
		features.append({"name": name, "photo": str(one.get("photo", "")).strip_edges(),
			"model": str(one.get("model", "")).strip_edges(),
			"settle": str(one.get("settle", "")).strip_edges().to_lower(),
			"why": str(one.get("why", "")).strip_edges()})
	var silhouette: String = str(input.get("silhouette", "")).strip_edges()
	var whole: bool = not features.is_empty() and not silhouette.is_empty()
	var rebuild := PackedStringArray()
	for one: Dictionary in features:
		whole = whole and not str(one["photo"]).is_empty() and not str(one["model"]).is_empty() \
			and str(one["settle"]) in ["rebuild", "keep"] and not str(one["why"]).is_empty()
		if str(one["settle"]) == "rebuild":
			rebuild.append(str(one["name"]))
	if not whole:
		return ("Answer in full: silhouette, and features, each with its name, photo, model, "
			+ "settle (rebuild or keep) and why.")
	var answer: Dictionary = {"photo": str(input.get("photo", "")).strip_edges(),
		"is_it": bool(input.get("is_it", false)), "silhouette": silhouette,
		"features": features}
	last["answer"] = answer
	_before = standing(assistant._bricks_inside({}))
	print("photo look: answered (%d refused), %d to rebuild: %s" % [last["refused"],
		rebuild.size(), JSON.stringify(answer)])
	var then: String = ""
	if not str(last["photo"]).is_empty() and not bool(answer["is_it"]):
		then = (" The photograph was not the thing: find_reference with its own name brings "
			+ "another, to compare with the same way.")
	if rebuild.is_empty():
		return ("Then each reads as the photograph does. Now review_model for the rest of the "
			+ "whole review." + then)
	return ("Now rebuild %s, the most different first and before any detail: " % (
		", ".join(rebuild)) + "submit_design again when it changes the whole shape, edit_model "
		+ "when it is one part of it, to the photograph's form and proportion. Then view_model "
		+ "from the photograph's angle, the front and the side to see each reads as the "
		+ "photograph does, and review_model for the rest of the whole review." + then)


## What the answer led to, said once at the review or save that follows it:
## how many parts the session added and took off since, for the log.
func follow(tool: String) -> void:
	if _before.is_empty() or not tool in COUNTED_AT:
		return
	var now: Dictionary = standing(assistant._bricks_inside({}))
	var moved: Dictionary = changed(_before, now)
	last["rebuilt"] = moved
	print("photo look: since the answer, at %s: %d added, %d taken off, %d kept of %d" % [
		tool, moved["added"], moved["removed"], moved["kept"], moved["before"]])
	_before = {}


## The bricks standing, each by its part, colour and place, counted.
static func standing(bricks: Array[BrickWorld.Brick]) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		var at: Transform3D = brick.transform
		var key: String = "%s %d %.1f %.1f %.1f %.2f %.2f %.2f %.2f" % [brick.part_id,
			brick.color_code, at.origin.x, at.origin.y, at.origin.z, at.basis.x.x, at.basis.x.z,
			at.basis.z.x, at.basis.z.z]
		out[key] = int(out.get(key, 0)) + 1
	return out


## What changed from [param before] to [param now]: {added, removed, kept,
## before}, a part moved counted as one taken off and one added.
static func changed(before: Dictionary, now: Dictionary) -> Dictionary:
	var kept: int = 0
	var was: int = 0
	var is_now: int = 0
	for key: String in before:
		was += int(before[key])
		kept += mini(int(before[key]), int(now.get(key, 0)))
	for key: String in now:
		is_now += int(now[key])
	return {"added": is_now - kept, "removed": was - kept, "kept": kept, "before": was}


## The model from [param views], as content blocks, or [] when they could
## not be taken.
func _shots(views: Array[String]) -> Array:
	if not ModelShot.possible() or assistant.world == null:
		return []
	var shot: ModelShot = assistant._ensure_shot()
	var out: Array = []
	for view: String in views:
		var block: Dictionary = await shot.block(assistant.world, view, assistant.scenery)
		if block.is_empty():
			return []
		out.append(block)
	return out


## TOOL, as a session is served it; its annotations are CommandSocket.HINTS'.
static func definition() -> Dictionary:
	return {"name": TOOL, "description": ("Answer the look beside a photograph of the real "
		+ "thing that a design's first whole review asks for: what the photograph shows, the "
		+ "silhouettes against each other, and each feature's form and size against the whole "
		+ "in the photograph and in your model, each settled rebuild or keep, and why. Only "
		+ "when a review asks."), "input_schema": SCHEMA}


const SCHEMA: Dictionary = {
	"type": "object",
	"properties": {
		"photo": {"type": "string", "description": "what the photograph shows"},
		"is_it": {"type": "boolean", "description":
			"true when the photograph shows the thing you are building"},
		"silhouette": {"type": "string", "description": ("the photograph's outline against "
			+ "your model's from the nearest view: length against height, where the mass "
			+ "sits, what stands out of it, and how yours differs")},
		"features": {"type": "array", "minItems": 1, "items": {
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"photo": {"type": "string", "description":
					"its form and its size against the whole, as the photograph shows it"},
				"model": {"type": "string", "description": ("its form and its size against "
					+ "the whole in your model's pictures, in studs and plates")},
				"settle": {"type": "string", "enum": ["rebuild", "keep"]},
				"why": {"type": "string", "description": "why, in a line"},
			},
			"required": ["name", "photo", "model", "settle", "why"],
			"additionalProperties": false,
		}},
	},
	"required": ["photo", "is_it", "silhouette", "features"],
	"additionalProperties": false,
}
