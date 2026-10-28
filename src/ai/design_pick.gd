## Two designs of one brief, and the one to keep.
##
## A design's draw decides more of how it reads than any change made to how
## designs are made, and a look at two side by side, which never sees the
## real set, named the one that did better against it in 52 pairs of 60
## (docs/DESIGN_SCORES.md, "What has moved a verdict"). So a brief can be
## designed twice and this keeps one: Claude Code on the person's
## subscription, shown the brief and each design's three pictures
## (ModelShot's corner, front and close, as content blocks), asked which a
## set designer would rather ship. It has no tools and reads no file: the
## pictures come in the one message it is sent.
##
##   claude -p --input-format stream-json --tools "" ... < that message
##
## The answer can lean on the order it is shown them in, so a caller that
## can spend two asks shows them both ways (run side by side, it waits for
## one) and keeps the first design when the two disagree.
class_name DesignPick
extends RefCounted

const VIEWS: Array[String] = ["corner", "front", "close"]
const SAID: Dictionary = {
	"corner": "corner view",
	"front": "front view",
	"close": "close view, a nearer look at one quarter",
}

## The answer's shape. Saying what each reads as comes before the choice,
## so the choice is made on what was seen.
const SCHEMA: Dictionary = {
	"type": "object",
	"properties": {
		"a": {"type": "string", "description": "what A reads as, and its biggest flaw"},
		"b": {"type": "string", "description": "what B reads as, and its biggest flaw"},
		"keep": {"type": "string", "enum": ["A", "B"]},
		"why": {"type": "string", "description": "one sentence: what decides it"},
	},
	"required": ["a", "b", "keep", "why"],
}

var _pid: int = -1


static func prompt(brief: String) -> String:
	return ("Two designs, A and B, were built in LEGO® bricks to this brief: "
		+ "\"%s\"\n\n" % brief
		+ "Below are three pictures of each, taken by the same camera, so picture "
		+ "quality says nothing, and which is shown first means nothing.\n\n"
		+ "Keep the one a LEGO® set designer would rather ship as this subject. "
		+ "First, which reads at a glance as the subject from every view: its "
		+ "silhouette, proportions and colours, and the features that make it that "
		+ "subject. Then, which hangs together as one finished model, built the way "
		+ "that line's sets are built. A model is not better for being bigger or "
		+ "for having more parts.")


## The one message the session is sent: the prompt, then each design's
## pictures under its letter. [param a] and [param b] are image content
## blocks in VIEWS order (ModelShot.block gives them).
static func message(brief: String, a: Array, b: Array) -> Dictionary:
	var content: Array = [{"type": "text", "text": prompt(brief)}]
	for side: Array in [["A", a], ["B", b]]:
		var views: Array = side[1]
		for i: int in views.size():
			content.append({"type": "text",
				"text": "Design %s, %s:" % [side[0], SAID[VIEWS[i]]]})
			content.append(views[i])
	return {"type": "user", "message": {"role": "user", "content": content}}


## The three pictures a design is chosen by, in VIEWS order, as the bench took
## them (src/dev/bench_views.gd): the corner, the front, and the corner's
## nearest quarter close. Of [param of] without [param skip] (the floor);
## [] when one could not be taken.
static func pictures(shot: ModelShot, of: BrickWorld, skip: Dictionary,
		library: PartLibrary) -> Array[Image]:
	var bounds := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in of.bricks():
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if skip.has(brick.id) or part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		bounds = here if first else bounds.merge(here)
		first = false
	var middle: Vector3 = bounds.get_center()
	var close := AABB(Vector3(middle.x, bounds.position.y, middle.z),
		Vector3(bounds.end.x - middle.x, bounds.size.y, bounds.end.z - middle.z))
	var taken: Array[Image] = []
	for view: Array in [["corner", AABB()], ["front", AABB()], ["corner", close]]:
		var image: Image = await shot.take(of, view[0], skip, view[1])
		if image == null:
			return []
		taken.append(image)
	return taken


## A PNG file as an image content block.
static func picture(path: String) -> Dictionary:
	var png: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if png.is_empty():
		return {}
	return {"type": "image", "source": {"type": "base64", "media_type": "image/png",
		"data": Marshalls.raw_to_base64(png)}}


## How the session is started: no tools at all, none of the person's MCP
## servers or settings, nothing kept afterwards, and the answer in
## [param schema].
static func arguments(schema: Dictionary = SCHEMA) -> PackedStringArray:
	return PackedStringArray([
		"-p",
		"--input-format", "stream-json",
		"--output-format", "stream-json",
		"--verbose",
		"--tools", "",
		"--strict-mcp-config",
		"--restricted",
		"--no-session-persistence",
		"--json-schema", JSON.stringify(schema),
	])


## Ask once, and wait for the answer: meant for a worker thread.
## {keep: "A" or "B", a, b, why, seconds, model, usage}, or {error}.
func ask(brief: String, a: Array, b: Array) -> Dictionary:
	var said: Dictionary = put(message(brief, a, b), SCHEMA)
	if not said.has("result"):
		return said
	var found: Dictionary = _answer(said["result"])
	found["seconds"] = said["seconds"]
	found["model"] = said["model"]
	return found


## [param message] put to a session of its own, its answer in [param schema],
## and waited for: meant for a worker thread. {result: the session's result
## event, seconds, model}, or {error}. FreshEyes asks its question this way.
func put(message: Dictionary, schema: Dictionary) -> Dictionary:
	var claude: String = ClaudeCode.found()
	if claude.is_empty():
		return {"error": "Claude Code is not installed on this machine."}
	var started_ms: int = Time.get_ticks_msec()
	var started: Dictionary = ClaudeCode.start_on_subscription(claude, arguments(schema))
	if not started.has("stdio"):
		return {"error": "Could not start %s." % claude}
	_pid = int(started.get("pid", -1))
	var pipe: FileAccess = started["stdio"]
	pipe.store_string(JSON.stringify(message) + "\n")
	pipe.flush()
	var found: Dictionary = {"error": "Claude Code stopped without an answer."}
	var model: String = ""
	# A session given its message on a pipe waits for the next one when it
	# has answered, so the answer is the end, said by stopping it.
	while pipe.is_open() and not pipe.eof_reached():
		var line: String = pipe.get_line()
		if line.is_empty():
			if not OS.is_process_running(_pid):
				break
			continue
		var event: Variant = JSON.parse_string(line)
		if not (event is Dictionary):
			continue
		if event.get("type") == "system" and event.get("subtype") == "init":
			model = str(event.get("model", ""))
		if event.get("type") == "result":
			found = {"result": event}
			break
	stop()
	found["seconds"] = (Time.get_ticks_msec() - started_ms) / 1000.0
	found["model"] = model
	return found


## Stop the session, if one is going.
func stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1


static func _answer(event: Dictionary) -> Dictionary:
	var whole: Dictionary = event.get("usage", {}) if event.get("usage") is Dictionary else {}
	var usage: Dictionary = {}
	for field: String in ["input_tokens", "cache_creation_input_tokens",
			"cache_read_input_tokens", "output_tokens"]:
		usage[field] = int(whole.get(field, 0))
	var said: Variant = event.get("structured_output")
	if bool(event.get("is_error", false)) or not (said is Dictionary) \
			or not str(said.get("keep", "")) in ["A", "B"]:
		return {"error": str(event.get("result", "no answer")).left(300), "usage": usage}
	return {"keep": str(said["keep"]), "a": str(said.get("a", "")),
		"b": str(said.get("b", "")), "why": str(said.get("why", "")), "usage": usage}
