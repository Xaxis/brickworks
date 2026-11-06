## A new design measured against a photograph of the real thing, at its
## first whole review: each feature's length, width and height as a share
## of the whole, read off the photograph by the session first, then measured
## off its model by the app, side by side.
##
## Set beside the real set, our designs lose on one defining feature's size
## against the whole far more often than on anything else (design16). Shown
## a photograph beside its own front and side (design18), every session
## looked and answered, and won nothing back: it read the photograph and did
## not measure it. A roller's session wrote that the real drum is "30% of
## the length" and kept its own drum, a sixth of it; a tower named its T plan
## against the photograph's Y and kept it. Two of five photographs, found
## with the set's own title, were not the thing at all: a crowd that shared
## a photographer's name, and a 1918 biplane for a modern mail plane.
##
## So the look goes in steps, each answered with TOOL:
## 1. name: the session names the real thing by its own name, the make and
##    model, not the title it was given, or "none" when it has none. The
##    photograph is searched for with those words only.
## 2. find: the next whole review sets the photograph beside the model from
##    the view its title names, the front and the side.
## 3. read: the session says whether it is the thing (not, and the look ends
##    with nothing to measure against), then reads the shares off it: the
##    whole's length, width and height as fractions of its longest, and each
##    feature's as fractions of the whole's, each with its box in the model.
## 4. settle: the app measures the same shares off the model, the bricks
##    whose middle is in each box, and sets them beside the photograph's.
##    Each more than a quarter off (and a stud or more) the session settles:
##    rebuild, or keep and say why.
## 5. again: rebuilt, it gives each feature's box as it is now, and sees its
##    shares again; the next whole review asks once if it has not.
## The session decides throughout: nothing is changed for it, nothing is
## tuned to a subject. While a step waits, other changes are refused, twice
## at most.
##
## Never a picture of anything built of bricks (ReferenceFinder.of_lego):
## the look is of the real thing, and while a set is held out a builder's
## model of it is the set's answer.
class_name PhotoLook
extends RefCounted

## The tool a session answers each step with ([method definition]).
const TOOL := "compare_with_photo"

## The calls refused while a step waits (not_yet): after them it goes
## ahead, so a session is never stuck.
const MOST_REFUSED := 2

## The calls that go ahead while a step waits: its answer, a save, the
## looks that help it answer, and another photograph.
const GO_AHEAD: Array[String] = [TOOL, "save_model", "view_model", "look_at_model",
	"find_reference"]

## The most searches made with the session's words for the real thing.
const MOST_SEARCHES := 2

## Over the line: a share more than this far off the photograph's, as a
## fraction of the photograph's ...
const OFF_BY := 0.25
## ... and at least this far in LDU on the model (a stud), so a share no
## brick could close is not called off.
const OFF_LDU := 20.0

const STUD := 20.0
const PLATE := 8.0

## A view of the model as ModelShot names it, and what it is called.
const CALLED: Dictionary = {
	"corner": "the corner (a three-quarter view, as most photographs are taken)",
	"front": "the front (from +z)",
	"right": "the side (from +x)",
	"back": "the back (from -z)",
	"top": "above",
}

## The steps that wait for an answer, refusing other changes.
const WAITS: Array[String] = ["name", "read", "settle"]

## The calls after which what the settling led to is counted: the review it
## sends the session on to, or a save.
const COUNTED_AT: Array[String] = ["review_model", "save_model"]

## The dimensions a share is read in, and the axis each lies on.
const DIMENSIONS: Array[String] = ["length", "width", "height"]

var assistant: Assistant
## The pictures the session's own find_reference brought, and its words.
var pictures: Array = []
var asked_for: String = ""
## Whether a design of this subject went down on a bare baseplate.
var fresh: bool = false
## The look, step by step: {step, refused, ...} with step one of name,
## find, read, settle, rebuild, again, done; what was said at each, for the
## log and a probe. {error} with no pictures of the model.
var last: Dictionary = {}
## The model as it stood when the settling was answered, until it is counted.
var _before: Dictionary = {}


## A new subject begins: nothing of the last one's carries over.
func begin() -> void:
	pictures = []
	asked_for = ""
	fresh = false
	last = {}
	_before = {}


## A design from outside stands; [param bare] when nothing stood before it.
func designed(bare: bool) -> void:
	fresh = fresh or bare


## What the session's find_reference brought back.
func found(subject: String, got: Array) -> void:
	if got.is_empty():
		return
	pictures = got
	asked_for = subject.strip_edges()


func step() -> String:
	return str(last.get("step", ""))


## Whether the whole review of the design standing leads with the look.
func due() -> bool:
	if assistant == null or not fresh or not last.is_empty():
		return false
	return not assistant._busy and assistant._outside_standing \
		and assistant._outside_designed and not assistant.asked_about_selection()


## What a whole review says instead of the review, or "" for the review:
## the first asks for the real thing's name; the one after the name sets the
## photograph beside the model; the one after a rebuild asks it measured again.
func at_review() -> Variant:
	if due():
		return ask_name()
	match step():
		"find":
			return await look()
		"rebuild":
			last["step"] = "again"
			print("photo look: asked again at the review, the rebuilt: %s"
				% ", ".join(rebuilt_names()))
			return ASK_AGAIN % [TOOL, ", ".join(rebuilt_names())]
	return ""


## Step 1: the real thing's own name, to search for its photograph with.
func ask_name() -> String:
	# Nothing asked of a model that cannot be drawn: a headless run.
	if not ModelShot.possible() or assistant.world == null:
		last = {"error": "no pictures"}
		print("photo look: no pictures of the model, nothing said")
		return ""
	last = {"step": "name", "refused": 0}
	print("photo look: asked the real thing's name")
	var features: Array[String] = assistant._outside_features
	return "\n\n".join([OPENING, ASK_NAME % TOOL, ("You named no features with the design: "
		+ "name the two or three the subject is known by when you read the photograph.")
		if features.is_empty() else "The features you named with the design: %s." % (
		", ".join(features))])


## Step 2: the photograph found with the session's words, beside the model
## from the view its title names, the front and the side; or, with none, so.
func look() -> Variant:
	var photo: Dictionary = await _photo(str(last.get("real_thing", "")))
	var picture: Dictionary = photo.get("picture", {}) as Dictionary
	if picture.is_empty():
		last["step"] = "done"
		last["photo"] = ""
		print("photo look: %s" % _said_of(photo))
		return NO_PHOTO % ("\", \"".join(photo.get("tried", PackedStringArray()) as
			PackedStringArray))
	var nearest: String = view_for(str(picture.get("title", "")))
	var views: Array[String] = [nearest if not nearest.is_empty() else "corner"]
	for view: String in ["front", "right"]:
		if not view in views:
			views.append(view)
	# Not drawn in time, as behind a busy graphics card: the photograph still
	# goes, and the session takes its own pictures.
	var shots: Array = await _shots(views)
	last["step"] = "read"
	last["refused"] = 0
	last["photo"] = str(picture.get("title", ""))
	print("photo look: shown, %s, the model from %s" % [_said_of(photo),
		", ".join(views) if not shots.is_empty() else "nothing: not drawn in time"])
	var content: Array = [{"type": "text", "text": photo_line(photo)},
		{"type": "image", "source": {"type": "base64", "media_type": "image/png",
			"data": Marshalls.raw_to_base64(picture["bytes"])}}]
	if shots.is_empty():
		content.append({"type": "text", "text": UNDRAWN})
	for n: int in shots.size():
		content.append({"type": "text", "text": "Yours from %s%s:" % [CALLED[views[n]],
			", the view its title names" if n == 0 and not nearest.is_empty() else ""]})
		content.append(shots[n])
	content.append({"type": "text", "text": ASK_READ % [TOOL, axes_line(whole_size())]})
	return content


## The photograph to set beside the model: {picture, how, query}; how is
## "asked" (the session's own find_reference, when it searched the same
## words), "found" (searched for with its words) or "none" ({tried}).
func _photo(real_thing: String) -> Dictionary:
	var own: Dictionary = first_of(pictures)
	if not own.is_empty() and cleaned(asked_for).to_lower() == cleaned(real_thing).to_lower():
		return {"picture": own, "how": "asked", "query": asked_for}
	var tried := PackedStringArray()
	for query: String in queries(real_thing):
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


## What to search for, from the session's own name for the real thing: the
## words cleaned, then, if they are more than a name, the name alone (before
## a comma, a dash or "such as").
static func queries(real_thing: String) -> PackedStringArray:
	var out := PackedStringArray()
	var first: String = cleaned(real_thing)
	if first.is_empty():
		return out
	out.append(first)
	var short: String = RegEx.create_from_string("(?i)\\s*(,|;| - | – | — |\\bsuch as\\b|\\blike\\b"
		+ "|\\bwith\\b).*$").sub(first, "")
	short = RegEx.create_from_string("(?i)^(an?|the)\\s+").sub(short, "").strip_edges()
	if not short.is_empty() and short.to_lower() != first.to_lower():
		out.append(short)
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


## Whether the session said its subject has no real counterpart.
static func none_said(real_thing: String) -> bool:
	var said: String = real_thing.strip_edges().to_lower().trim_suffix(".")
	return said in ["", "none", "no", "n/a", "nothing", "no real counterpart"]


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


const OPENING := ("Before the rest of the review: your model measured against a photograph of "
	+ "the real thing. A judge who sets a model beside the real thing names one feature's size "
	+ "against the whole far more often than anything else: a round part a third the size it "
	+ "should be, a thin part built twice as thick, a tall thing built squat. Read against "
	+ "memory, or even against a photograph, each looks right; measured, it is not. So the "
	+ "look measures: you read each feature's share of the whole off the photograph, and the "
	+ "app measures the same share off your model.")

const ASK_NAME := ("First, the real thing to search for, answered with %s {real_thing}: its "
	+ "own name in a few words, as a search for its photograph: a machine's or vehicle's make "
	+ "and model, a building's name, an animal's species. Not the title you were given, which "
	+ "can name something else (a photographer, an event, a set). If your subject has no real "
	+ "counterpart (a scene from a story, a made-up craft), real_thing \"none\", and the review "
	+ "goes on.")

const NO_PHOTO := ("No photograph came back from Wikimedia Commons for \"%s\", so there is "
	+ "nothing to measure against. review_model again for the rest of the whole review.")

const ASK_READ := ("Read the photograph first, before you see your model's numbers, and "
	+ "answer with %s:\n"
	+ "- photo: what it shows; is_it: true only when it is the thing itself, not something "
	+ "that shares its name. When it is not, the look ends: there is nothing to measure "
	+ "against.\n"
	+ "- whole: the real thing's length, width and height, each as a fraction of the longest "
	+ "of the three, as the photograph shows them (e.g. 1, 0.4, 0.3).\n"
	+ "- features: each the subject is known by, with where (its box in your model, in studs "
	+ "and plates, as look_at_model takes one) and its length, width and height as fractions "
	+ "of the whole's own length, width and height, read off the photograph (a part as tall "
	+ "as half the whole is height 0.5). Leave out a dimension the photograph does not show.\n"
	+ "%s")

const UNDRAWN := ("Your model's pictures could not be drawn in time just now. Take them "
	+ "yourself before you answer: view_model from the corner, the front and the side, and "
	+ "set each beside the photograph.")

const ASK_AGAIN := ("Before the rest of the review: measure what you rebuilt beside the "
	+ "photograph again. Answer with %s {again}: each of %s, with where, its box in your model "
	+ "as it is now (the whole needs none). Then review_model for the rest of the whole "
	+ "review.")


## Which way the model's length, width and height run, without their sizes:
## the session reads the photograph before it sees the model's numbers.
static func axes_line(size: Vector3) -> String:
	var along_x: bool = size.x >= size.z
	return ("In your model the length runs along %s, the width along %s, and the height up."
		% ["x" if along_x else "z", "z" if along_x else "x"])


## The photograph's caption: what it is, whose, and how it was found.
static func photo_line(photo: Dictionary) -> String:
	var picture: Dictionary = photo["picture"]
	var how: String = ("from your find_reference" if str(photo["how"]) == "asked"
		else "found for you with \"%s\"" % photo["query"])
	return "The real thing, %s: %s — %s." % [how, picture["title"], picture["credit"]]


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


## Whether a step waits for its answer.
func waiting() -> bool:
	return step() in WAITS


## What a call is told while a step waits for its answer: "" when it goes
## ahead. The answer, a save, a look at the model and another photograph go
## ahead, and clearing the model lets the look go; anything else is
## refused, up to MOST_REFUSED times.
func not_yet(tool: String) -> String:
	if not waiting() or tool in GO_AHEAD:
		return ""
	# Taken off to start again: there is nothing left to look at.
	if tool == "clear_model":
		_let_go("the model taken off, the look let go")
		return ""
	if int(last.get("refused", 0)) >= MOST_REFUSED:
		_let_go("never answered at %s; %s goes ahead" % [step(), tool])
		return ""
	last["refused"] = int(last.get("refused", 0)) + 1
	print("photo look: %s refused at %s" % [tool, step()])
	return ("Not yet: first answer the look beside the photograph with %s: " % TOOL
		+ str(NOT_YET.get(step(), "")))


const NOT_YET: Dictionary = {
	"name": "real_thing, the real thing's own name to search for its photograph, or \"none\".",
	"read": ("photo, is_it, and the shares you read off the photograph: whole, and each "
		+ "feature with where and its length, width and height."),
	"settle": "settled, each share over the line rebuild or keep, and why.",
}


func _let_go(why: String) -> void:
	last["unanswered"] = step()
	last["step"] = "done"
	print("photo look: %s" % why)


## The session's answer, with TOOL, at whichever step waits: what comes next.
func answered(input: Dictionary) -> String:
	match step():
		"name":
			return _named(input)
		"read":
			return _read(input)
		"settle":
			return _settled(input)
		"rebuild", "again":
			return _again(input)
	return "Nothing to answer: a design's first whole review asks for this."


## Step 1 answered: the real thing's own name, or none.
func _named(input: Dictionary) -> String:
	if not input.has("real_thing"):
		return "Answer with real_thing: the real thing's own name in a few words, or \"none\"."
	var real_thing: String = str(input.get("real_thing", "")).strip_edges()
	last["real_thing"] = real_thing
	if none_said(real_thing):
		last["step"] = "done"
		print("photo look: named none, no real counterpart")
		return "Then there is no photograph to measure against. review_model for the whole review."
	last["step"] = "find"
	print("photo look: named \"%s\"" % real_thing)
	return ("Now review_model: it sets a photograph of %s beside your model, to read and "
		% real_thing + "measure.")


## Step 3 answered: whether it is the thing, and the shares off the
## photograph; the same measured off the model, and the differences over
## the line to settle.
func _read(input: Dictionary) -> String:
	if not input.has("is_it"):
		return "Answer with photo and is_it first: whether the photograph is the thing itself."
	last["is_it"] = bool(input.get("is_it", false))
	last["photo_said"] = str(input.get("photo", "")).strip_edges()
	if not bool(last["is_it"]):
		last["step"] = "done"
		print("photo look: not the thing: %s" % last["photo_said"])
		return ("Then there is no photograph to measure against, and the look ends. "
			+ "review_model for the rest of the whole review.")
	var whole: Dictionary = shares_of(input.get("whole"))
	var features: Array[Dictionary] = []
	var given: Variant = input.get("features")
	for raw: Variant in (given as Array if given is Array else []):
		if not raw is Dictionary:
			continue
		var one: Dictionary = raw
		var name: String = str(one.get("name", "")).strip_edges()
		var where: Dictionary = box_of(one.get("where"))
		var shares: Dictionary = shares_of(one)
		if name.is_empty() or where.is_empty() or shares.is_empty():
			continue
		features.append({"name": name, "where": where, "photo": shares})
	if whole.size() < 2 or features.is_empty():
		return ("Answer in full: whole, with at least two of length, width and height as "
			+ "fractions of its longest; and features, each with its name, where (its box in "
			+ "your model) and its length, width or height as fractions of the whole's.")
	var size: Vector3 = whole_size()
	var rows: Array[Dictionary] = [{"name": "the whole", "photo": whole,
		"model": whole_shares(size), "whole": true}]
	for one: Dictionary in features:
		var measured: Dictionary = measure(one["where"])
		rows.append({"name": one["name"], "where": one["where"], "photo": one["photo"],
			"model": feature_shares(measured, size), "count": int(measured.get("count", 0)),
			"size": measured.get("size", Vector3.ZERO)})
	var offs: Array[Dictionary] = offs_of(rows, size)
	last["rows"] = rows
	last["offs"] = offs
	print("photo look: read %d features, %d over the line: %s" % [features.size(), offs.size(),
		JSON.stringify(_logged(rows, offs))])
	var said: String = table(rows, offs, size)
	if offs.is_empty():
		last["step"] = "done"
		return (said + "\n\nEach is within a quarter of the photograph's share. review_model "
			+ "for the rest of the whole review.")
	last["step"] = "settle"
	last["refused"] = 0
	return said + "\n\n" + ASK_SETTLE % TOOL


const ASK_SETTLE := ("Settle each over the line, answered with %s {settled}: each feature's "
	+ "name (the whole as \"the whole\"), settle (rebuild or keep) and why, in a line. "
	+ "Rebuild it to the photograph's share, not a stud nearer it; keep it only for a reason "
	+ "you can say.")


## Step 4 answered: each feature over the line settled; what to rebuild.
func _settled(input: Dictionary) -> String:
	var settled: Dictionary = {}
	var given: Variant = input.get("settled")
	for raw: Variant in (given as Array if given is Array else []):
		if not raw is Dictionary:
			continue
		var one: Dictionary = raw
		var settle: String = str(one.get("settle", "")).strip_edges().to_lower()
		var name: String = str(one.get("name", "")).strip_edges()
		if not name.is_empty() and settle in ["rebuild", "keep"]:
			settled[name.to_lower()] = {"name": name, "settle": settle,
				"why": str(one.get("why", "")).strip_edges()}
	var open := PackedStringArray()
	for name: String in off_names():
		if not settled.has(name.to_lower()):
			open.append(name)
	if not open.is_empty():
		return "Settle each over the line: %s, each rebuild or keep, and why." % ", ".join(open)
	last["settled"] = settled.values()
	var rebuild := PackedStringArray()
	for one: Dictionary in settled.values():
		if str(one["settle"]) == "rebuild":
			rebuild.append(str(one["name"]))
	print("photo look: settled, %d to rebuild: %s" % [rebuild.size(),
		JSON.stringify(settled.values())])
	if rebuild.is_empty():
		last["step"] = "done"
		return "Then review_model for the rest of the whole review."
	last["step"] = "rebuild"
	_before = standing(assistant._bricks_inside({}))
	return ("Now rebuild %s, the most different first and before any detail, to these: %s. "
		% [", ".join(rebuild), "; ".join(targets(rebuild))]
		+ "submit_design again when it changes the whole shape, edit_model when it is one part "
		+ "of it. Then %s {again}, each with where, its box as it is now, to measure it " % TOOL
		+ "beside the photograph again, and review_model for the rest of the whole review.")


## Step 5 answered: the rebuilt measured again, beside the photograph and
## beside what they were.
func _again(input: Dictionary) -> String:
	var rows: Array[Dictionary] = []
	var given: Variant = input.get("again")
	var size: Vector3 = whole_size()
	var was: Dictionary = {}
	for row: Dictionary in last.get("rows", []):
		was[str(row["name"]).to_lower()] = row
	for raw: Variant in (given as Array if given is Array else []):
		if not raw is Dictionary:
			continue
		var one: Dictionary = raw
		var name: String = str(one.get("name", "")).strip_edges()
		var where: Dictionary = box_of(one.get("where"))
		var before: Dictionary = was.get(name.to_lower(), {})
		if before.is_empty():
			continue
		# The whole is the whole, wherever it was said to be.
		if bool(before.get("whole", false)):
			rows.append({"name": before["name"], "photo": before["photo"],
				"model": whole_shares(size), "before": before["model"], "whole": true})
			continue
		if where.is_empty():
			continue
		var measured: Dictionary = measure(where)
		rows.append({"name": before["name"], "where": where, "photo": before["photo"],
			"model": feature_shares(measured, size), "before": before["model"],
			"count": int(measured.get("count", 0)), "size": measured.get("size", Vector3.ZERO)})
	if rows.is_empty():
		return ("Answer with again: each feature you rebuilt (%s), with where, its box in your "
			% ", ".join(rebuilt_names()) + "model as it is now.")
	follow("again")
	var offs: Array[Dictionary] = offs_of(rows, size)
	last["again"] = rows
	last["step"] = "done"
	print("photo look: measured again, %d still over the line: %s" % [offs.size(),
		JSON.stringify(_logged(rows, offs))])
	var said: String = table(rows, offs, size)
	if offs.is_empty():
		return (said + "\n\nEach is now within a quarter of the photograph's share. review_model "
			+ "for the rest of the whole review.")
	return said + ("\n\nStill over the line: %s. Rebuild once more if you will; then " % (
		", ".join(_off_said(offs))) + "review_model for the rest of the whole review.")


## The names of the features over the line, once each.
func off_names() -> PackedStringArray:
	var out := PackedStringArray()
	for off: Dictionary in last.get("offs", []):
		if not out.has(str(off["name"])):
			out.append(str(off["name"]))
	return out


## The features settled to rebuild.
func rebuilt_names() -> PackedStringArray:
	var out := PackedStringArray()
	for one: Dictionary in last.get("settled", []):
		if str(one["settle"]) == "rebuild":
			out.append(str(one["name"]))
	return out


## What to rebuild each of [param names] to: its off dimensions as sizes on
## the model, the photograph's share of the whole's.
func targets(names: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var size: Vector3 = whole_size()
	for name: String in names:
		var dims := PackedStringArray()
		for off: Dictionary in last.get("offs", []):
			if str(off["name"]).to_lower() != name.to_lower():
				continue
			dims.append("%s %s (%s now)" % [off["dimension"], _sized(float(off["photo"]),
				str(off["dimension"]), size, bool(off.get("whole", false))),
				_sized(float(off["model"]), str(off["dimension"]), size,
					bool(off.get("whole", false)))])
		out.append("%s: %s" % [name, ", ".join(dims)])
	return out


## The shares in [param rows] more than OFF_BY off the photograph's, by at
## least OFF_LDU on the model, each {name, dimension, photo, model, whole}.
static func offs_of(rows: Array[Dictionary], size: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in rows:
		var photo: Dictionary = row["photo"]
		var model: Dictionary = row["model"]
		for dimension: String in DIMENSIONS:
			if not photo.has(dimension) or not model.has(dimension):
				continue
			var p: float = float(photo[dimension])
			var m: float = float(model[dimension])
			if p <= 0.0:
				continue
			var whole: bool = bool(row.get("whole", false))
			var across: float = (_longest_ldu(size) if whole else _ldu(dimension, size))
			if absf(m - p) / p > OFF_BY and absf(m - p) * across >= OFF_LDU:
				out.append({"name": row["name"], "dimension": dimension, "photo": p,
					"model": m, "whole": whole})
	return out


## The whole's size in studs, plates and studs (x, y, z): every part of the
## model but a baseplate it stands on.
func whole_size() -> Vector3:
	return measure({}).get("size", Vector3.ZERO)


## The bricks of the model whose middle is inside [param where] (every one
## when it is empty), and the space they take up between them: {count,
## size, low}, in studs and plates.
func measure(where: Dictionary) -> Dictionary:
	if assistant == null or assistant.world == null:
		return {"count": 0, "size": Vector3.ZERO}
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var count: int = 0
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		if assistant._floor_plate(brick):
			continue
		var corners: Array = assistant._corners_in_studs(brick)
		if corners.is_empty():
			continue
		var near: Vector3 = corners[0]
		var far: Vector3 = corners[1]
		if not where.is_empty() and not Assistant._inside((near + far) * 0.5, where):
			continue
		low = low.min(near)
		high = high.max(far)
		count += 1
	if count == 0:
		return {"count": 0, "size": Vector3.ZERO}
	return {"count": count, "size": high - low, "low": low}


## The whole's length, width and height as fractions of its longest.
static func whole_shares(size: Vector3) -> Dictionary:
	var longest: float = _longest_ldu(size)
	if longest <= 0.0:
		return {}
	return {"length": _ldu("length", size) / longest, "width": _ldu("width", size) / longest,
		"height": _ldu("height", size) / longest}


## A feature's length, width and height as fractions of the whole's.
static func feature_shares(measured: Dictionary, whole: Vector3) -> Dictionary:
	if int(measured.get("count", 0)) == 0:
		return {}
	var size: Vector3 = measured["size"]
	var out: Dictionary = {}
	for dimension: String in DIMENSIONS:
		var of_whole: float = _ldu(dimension, whole)
		if of_whole > 0.0:
			out[dimension] = _along(dimension, size, whole) / _along(dimension, whole, whole)
	return out


## [param size]'s extent along [param dimension] of a whole of [param
## whole]: the length is the longer way across the ground, the width the
## shorter, the height up.
static func _along(dimension: String, size: Vector3, whole: Vector3) -> float:
	var along_x: bool = whole.x >= whole.z
	match dimension:
		"length":
			return size.x if along_x else size.z
		"width":
			return size.z if along_x else size.x
	return size.y


## The whole's extent along [param dimension], in LDU.
static func _ldu(dimension: String, whole: Vector3) -> float:
	return _along(dimension, whole, whole) * (PLATE if dimension == "height" else STUD)


static func _longest_ldu(whole: Vector3) -> float:
	return maxf(maxf(_ldu("length", whole), _ldu("width", whole)), _ldu("height", whole))


## A share of the whole as a size on the model: "7.5 studs", "12 plates".
static func _sized(share: float, dimension: String, whole: Vector3, of_longest: bool) -> String:
	var ldu: float = share * (_longest_ldu(whole) if of_longest else _ldu(dimension, whole))
	if dimension == "height":
		return "%s plates" % _number(ldu / PLATE)
	return "%s studs" % _number(ldu / STUD)


static func _number(value: float) -> String:
	var rounded: float = snappedf(value, 0.5)
	return str(int(rounded)) if is_equal_approx(rounded, roundf(rounded)) else "%.1f" % rounded


## A box as look_at_model takes one, from what a session gave, or {}.
static func box_of(given: Variant) -> Dictionary:
	if not given is Dictionary:
		return {}
	var out: Dictionary = {}
	for key: String in ["x_from", "x_to", "y_from", "y_to", "z_from", "z_to"]:
		var value: Variant = (given as Dictionary).get(key)
		if value is float or value is int:
			out[key] = float(value)
	return out


## The shares of length, width and height a session gave: fractions, or
## percentages read as fractions; a dimension left out or not a number is
## not there.
static func shares_of(given: Variant) -> Dictionary:
	if not given is Dictionary:
		return {}
	var out: Dictionary = {}
	for dimension: String in DIMENSIONS:
		var value: Variant = (given as Dictionary).get(dimension)
		var share: float = -1.0
		if value is float or value is int:
			share = float(value)
		elif value is String and (value as String).strip_edges().trim_suffix("%").is_valid_float():
			share = float((value as String).strip_edges().trim_suffix("%"))
			if (value as String).strip_edges().ends_with("%"):
				share /= 100.0
		if share > 1.0 + 0.0001:
			share /= 100.0
		if share > 0.0:
			out[dimension] = share
	return out


## The shares side by side, the photograph's and the model's, with what is
## over the line marked; each feature's box said, and how many of its parts
## were measured.
static func table(rows: Array[Dictionary], offs: Array[Dictionary], size: Vector3) -> String:
	var off_at: Dictionary = {}
	for off: Dictionary in offs:
		off_at["%s|%s" % [off["name"], off["dimension"]]] = true
	var again: bool = false
	for row: Dictionary in rows:
		again = again or row.has("before")
	var lines := PackedStringArray()
	lines.append("Measured off your model (the parts whose middle is inside each box you gave), "
		+ "beside the shares you read off the photograph. Each cell: the photograph's share, "
		+ "then yours%s." % (", then what it was" if again else ""))
	lines.append("")
	lines.append("| | length | width | height |")
	lines.append("|---|---|---|---|")
	for row: Dictionary in rows:
		var whole: bool = bool(row.get("whole", false))
		var cells := PackedStringArray()
		var label: String = ("the whole, of its longest" if whole
			else "%s (%d part%s)" % [row["name"], int(row.get("count", 0)),
				"" if int(row.get("count", 0)) == 1 else "s"])
		cells.append(label)
		for dimension: String in DIMENSIONS:
			var photo: Dictionary = row["photo"]
			var model: Dictionary = row["model"]
			if not photo.has(dimension):
				cells.append("—")
				continue
			if not model.has(dimension):
				cells.append("%s, yours not measured" % _percent(float(photo[dimension])))
				continue
			var cell: String = "%s, yours %s" % [_percent(float(photo[dimension])),
				_percent(float(model[dimension]))]
			if row.has("before") and (row["before"] as Dictionary).has(dimension):
				cell += " (was %s)" % _percent(float((row["before"] as Dictionary)[dimension]))
			if off_at.has("%s|%s" % [row["name"], dimension]):
				cell = "**%s: off**, the photograph's is %s" % [cell, _sized(float(
					photo[dimension]), dimension, size, whole)]
			cells.append(cell)
		lines.append("| %s |" % " | ".join(cells))
	var empty := PackedStringArray()
	for row: Dictionary in rows:
		if not bool(row.get("whole", false)) and int(row.get("count", 0)) == 0:
			empty.append(str(row["name"]))
	if not empty.is_empty():
		lines.append("")
		lines.append("No part of yours has its middle inside the box given for %s: look_at_model "
			% ", ".join(empty) + "to find it.")
	lines.append("")
	lines.append("Your whole: %s studs long, %s wide, %s plates high. Over the line: a share "
		% [_number(_along("length", size, size)), _number(_along("width", size, size)),
			_number(size.y)] + "more than a quarter off the photograph's, by a stud or more.")
	return "\n".join(lines)


static func _percent(share: float) -> String:
	return "%d%%" % int(roundf(share * 100.0))


static func _off_said(offs: Array[Dictionary]) -> PackedStringArray:
	var out := PackedStringArray()
	for off: Dictionary in offs:
		out.append("%s's %s" % [off["name"], off["dimension"]])
	return out


## The rows and what was off, as the log keeps them.
static func _logged(rows: Array[Dictionary], offs: Array[Dictionary]) -> Dictionary:
	var out: Array = []
	for row: Dictionary in rows:
		out.append({"name": row["name"], "photo": row["photo"], "model": row["model"],
			"before": row.get("before", {}), "parts": row.get("count", 0),
			"where": row.get("where", {})})
	return {"rows": out, "off": offs}


## What the settling led to, said once at the review or save that follows
## it, or at the answer measured again: how many parts the session added and
## took off since, and each rebuilt feature in its first box now, for the log.
func follow(tool: String) -> void:
	if _before.is_empty() or not (tool in COUNTED_AT or tool == "again"):
		return
	var now: Dictionary = standing(assistant._bricks_inside({}))
	var moved: Dictionary = changed(_before, now)
	last["rebuilt"] = moved
	print("photo look: since the settling, at %s: %d added, %d taken off, %d kept of %d" % [
		tool, moved["added"], moved["removed"], moved["kept"], moved["before"]])
	var size: Vector3 = whole_size()
	var names: PackedStringArray = PackedStringArray(Array(rebuilt_names()).map(
		func(name: String) -> String: return name.to_lower()))
	var rows: Array[Dictionary] = []
	for row: Dictionary in last.get("rows", []):
		if str(row["name"]).to_lower() in names:
			var measured: Dictionary = measure(row["where"])
			rows.append({"name": row["name"], "photo": row["photo"], "before": row["model"],
				"model": feature_shares(measured, size), "count": measured.get("count", 0),
				"where": row["where"]})
	if not rows.is_empty():
		print("photo look: in their first boxes now: %s" % JSON.stringify(
			_logged(rows, offs_of(rows, size))))
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
	return {"name": TOOL, "description": ("Answer each step of the look a design's first "
		+ "whole review asks for, measuring the model against a photograph of the real thing: "
		+ "real_thing (its own name, to search for the photograph), then photo, is_it and the "
		+ "shares read off the photograph (whole, and features each with where), then settled "
		+ "(each share over the line rebuild or keep, and why), then again (each rebuilt "
		+ "feature's box now). Only when a review asks."), "input_schema": SCHEMA}


const SHARE := {"type": "number", "minimum": 0, "maximum": 1}

const BOX: Dictionary = {"type": "object", "description":
	"its box in your model, in studs and plates, as look_at_model takes one",
	"properties": {
		"x_from": {"type": "number"}, "x_to": {"type": "number"},
		"y_from": {"type": "number"}, "y_to": {"type": "number"},
		"z_from": {"type": "number"}, "z_to": {"type": "number"},
	},
	"additionalProperties": false}

const SCHEMA: Dictionary = {
	"type": "object",
	"properties": {
		"real_thing": {"type": "string", "description": ("the real thing's own name in a few "
			+ "words, to search for its photograph: make and model, a building's name, a "
			+ "species; \"none\" when it has no real counterpart")},
		"photo": {"type": "string", "description": "what the photograph shows"},
		"is_it": {"type": "boolean", "description":
			"true only when the photograph shows the thing itself"},
		"whole": {"type": "object", "description": ("the real thing's length, width and height "
			+ "as fractions of the longest of the three, read off the photograph"),
			"properties": {"length": SHARE, "width": SHARE, "height": SHARE},
			"additionalProperties": false},
		"features": {"type": "array", "items": {
			"type": "object",
			"description": ("a feature the subject is known by: its length, width and height "
				+ "as fractions of the whole's, read off the photograph"),
			"properties": {
				"name": {"type": "string"},
				"where": BOX,
				"length": SHARE, "width": SHARE, "height": SHARE,
			},
			"required": ["name", "where"],
			"additionalProperties": false,
		}},
		"settled": {"type": "array", "items": {
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"settle": {"type": "string", "enum": ["rebuild", "keep"]},
				"why": {"type": "string", "description": "why, in a line"},
			},
			"required": ["name", "settle", "why"],
			"additionalProperties": false,
		}},
		"again": {"type": "array", "items": {
			"type": "object",
			"description": "a feature you rebuilt, and its box as it is now",
			"properties": {"name": {"type": "string"}, "where": BOX},
			"required": ["name"],
			"additionalProperties": false,
		}},
	},
	"additionalProperties": false,
}
