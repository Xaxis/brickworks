## Work a session asks for that takes longer than the session will wait.
##
## A Claude session waits about three minutes for a tool's answer, and the
## web connector's relay four. A turntable of Orthanc, or its booklet, takes
## longer than that, so the session was told the call had timed out while
## the app was still drawing, and asked again, and the second one waited
## behind the first. So a call that can run past about 20 s is a job: it
## answers with the job's number and what it is doing, the work goes on in
## the app, and the [code]job[/code] tool says how far it has got, gives the
## answer when it is done, and stops it.
##
## Two kinds. A call known to be long (long_call: a render, a booklet, a
## Studio file, make_art) is a job at once. Any other call is answered as
## it always was, unless it is still going after AFTER_S: then it becomes a
## job where it stands. Timed on Orthanc (9,429 parts) in a window drawn in
## software, the first view_model took over 75 s and check_design of a
## 4,242-part design over it 43 s; on a small model both take a moment, and
## a session looking at its work every few calls should not have to poll.
##
## A job is the same Working job the person sees along the foot of the
## window (src/ui/working.gd): one line, one count, one Cancel. The window's
## Cancel stops the session's job, and the session's cancel takes the
## window's bar away, because there is only one of each.
##
## A job holds the app as a call does (CommandSocket's turn), from its start
## to its end: a turntable draws the model as it stands, and a booklet reads
## it step by step. Any other call while it runs is answered at once with
## what the job is doing, rather than queued behind it for minutes.
class_name ToolJobs
extends RefCounted

const TOOL := "job"
## Jobs whose answers are kept to be asked for, newest last.
const KEPT := 12

## How long [code]job[/code] waits for the work to end before saying how far it
## has got: a session calling it again and again then asks about every ten
## seconds, and has the answer within a moment of the work's end.
var wait_s: float = 10.0
## How long a call not known to be long is waited for before it becomes a
## job. Both variables so that a probe can shorten them.
var after_s: float = 20.0


## One piece of work a session started.
class Entry extends RefCounted:
	var id: int = 0
	var tool: String = ""
	## What the person sees, and what the session is told. Null while a
	## call not known to be long is still being waited for.
	var work: Working.Job = null
	var answer: Variant = null
	var finished: bool = false
	var began_ms: int = 0
	var ended_ms: int = 0

	func seconds() -> int:
		return roundi(float((ended_ms if finished else Time.get_ticks_msec()) - began_ms) / 1000.0)


var _entries: Array[Entry] = []
var _next_id: int = 1


static func definition() -> Dictionary:
	return {
		"name": TOOL,
		"description": ("How a long piece of work is going: a call that answered with a "
			+ "job number (a render, a turntable, a booklet, a Studio file, a LEGO® Art "
			+ "picture, a brickify, or any call still going after 20 s). It waits up to "
			+ "10 s for the work to end, then says how far it has got; once done it gives "
			+ "the work's answer, picture and all, or why it stopped. cancel=true stops "
			+ "it, as Cancel in the window does. id= the job's number; the latest when "
			+ "omitted."),
		"input_schema": {"type": "object", "additionalProperties": false, "properties": {
			"id": {"type": "integer", "description": "the number the call answered with"},
			"cancel": {"type": "boolean", "description": "stop it, where it can be stopped"},
		}},
	}


## The job running now, or null.
func running() -> Entry:
	for entry: Entry in _entries:
		if not entry.finished:
			return entry
	return null


## Whether [param tool] with [param input] is a call that can run past
## about 20 s on a big model, and so a job from the start: {"words": what the
## person and the session are told it is doing, "cancel": whether it can be
## stopped part way}, or empty when it is not. A call that is going to be
## refused at once (nothing built, nothing to draw with) is not a job, so
## its refusal comes back as the answer.
static func long_call(tool: String, input: Dictionary, app: Node) -> Dictionary:
	if app == null:
		return {}
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var bar: ModelBar = app.get("_bar")
	var built: bool = world != null and store != null \
		and world.brick_count() - store.scenery.size() > 0
	var model: String = bar.model_name() if bar != null else "the model"
	var drawn: bool = StudioRender.possible()
	match tool:
		"render_model":
			if not built or not drawn:
				return {}
			var turning: bool = str(input.get("kind", "picture")) == "turntable"
			return {"words": "Rendering %s of %s…" % ["a turntable" if turning else "a picture",
				model], "cancel": true}
		"animate_model":
			if not drawn or not bool(input.get("render", true)):
				return {}
			return {"words": "Rendering %s's animation…" % model, "cancel": true}
		"export_model":
			if not built:
				return {}
			match str(input.get("format", "")):
				"instructions":
					if DisplayServer.get_name() == "headless" or BookletMaker.busy:
						return {}
					return {"words": "Drawing the booklet of %s…" % model, "cancel": true}
				"studio":
					return {"words": "Writing %s as a Studio file…" % model, "cancel": false}
				"picture":
					if DisplayServer.get_name() == "headless":
						return {}
					return {"words": "Taking a picture of %s…" % model, "cancel": false}
		"brickify":
			# A link fetched and laid, or the model the panel shows laid; not
			# the file dialog opened for the person, which is at once.
			var dialog: BrickifyDialog = app.get("_brickify")
			if dialog == null or dialog.is_busy() or bool(input.get("pick", false)):
				return {}
			var url: String = str(input.get("url", "")).strip_edges()
			var file: String = url.get_slice("?", 0).get_slice("#", 0).get_file().uri_decode()
			if url.is_empty() and (dialog.model() == null or not dialog.visible):
				return {}
			if not url.is_empty() and (not url.to_lower().begins_with("http")
					or not file.get_extension().to_lower() in MeshFile.KINDS):
				return {}
			return {"words": "Brickifying %s…" % (file if not url.is_empty()
				else dialog.model().name), "cancel": true}
		"make_art":
			# A plan that will be refused, or no picture to lay, is answered
			# at once, every fault named.
			var assistant: Assistant = app.get("_assistant")
			if assistant == null or not ArtPlan.parse(input, app.get("_library")).ok() \
					or (not input.has("svg") and assistant.art_picture() == null):
				return {}
			return {"words": "Laying out a LEGO® Art picture…", "cancel": false}
	return {}


## Run [param run] for [param tool]: it takes the Working job it reports to
## (null when there is none) and returns the tool's answer.
##
## [param long] (long_call) not empty: a job at once. The work starts on the
## next frame, so this answer is on its way to the session before the
## work's first slow step.
##
## Otherwise the answer itself, unless it has none after [member after_s]:
## then a job from there, said in [param doing]'s words (what the work is
## saying it is doing), which cannot be stopped part way.
func call_tool(tool: String, long: Dictionary, run: Callable, doing: Callable) -> Variant:
	var entry := Entry.new()
	entry.tool = tool
	entry.began_ms = Time.get_ticks_msec()
	if not long.is_empty():
		entry.work = Working.begin(str(long["words"]), 0, bool(long.get("cancel", false)))
		_keep(entry)
		_go(entry, run)
		return _started(entry)
	_go(entry, run)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var until: int = entry.began_ms + roundi(after_s * 1000.0)
	while not entry.finished and Time.get_ticks_msec() < until:
		await tree.process_frame
	if entry.finished:
		return entry.answer
	entry.work = Working.begin(str(doing.call()), 0, false)
	_keep(entry)
	return _started(entry)


func _keep(entry: Entry) -> void:
	entry.id = _next_id
	_next_id += 1
	_entries.append(entry)
	while _entries.size() > KEPT:
		_entries.pop_front()


func _started(entry: Entry) -> String:
	var after: String = ""
	if entry.seconds() >= 1:
		after = " (still going after %d s)" % entry.seconds()
	return ("Started job %d%s: %s It runs in the app, where the person sees it, and takes "
		% [entry.id, after, _sentence(entry.work.words)]
		+ "longer than a call waits. Call job {\"id\": %d} about every 10 s (each call " % entry.id
		+ "waits up to 10 s for it to end) until it gives the answer%s. Nothing else can be "
			% (", or {\"id\": %d, \"cancel\": true} to stop it" % entry.id
				if entry.work.can_cancel else "")
		+ "done in the app until it ends.")


func _go(entry: Entry, run: Callable) -> void:
	if entry.work != null:
		await entry.work.shown()
	var answer: Variant = await run.call(entry.work)
	entry.answer = answer
	entry.finished = true
	entry.ended_ms = Time.get_ticks_msec()
	# A call that became a job part way was given its bar later: read here.
	if entry.work != null:
		entry.work.end()


## The job tool: how one is going, its answer, or it stopped.
func answer(input: Dictionary) -> Variant:
	if _entries.is_empty():
		return ("There are no jobs. A call that takes a long time (render_model, a booklet, "
			+ "a Studio file, make_art, or anything still going after 20 s) answers with a "
			+ "job number to ask about here.")
	var entry: Entry = _entries[-1]
	if input.has("id"):
		entry = null
		for one: Entry in _entries:
			if one.id == int(input["id"]):
				entry = one
		if entry == null:
			return "No job %d. %s" % [int(input["id"]), _listing()]
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if bool(input.get("cancel", false)) and not entry.finished:
		if not entry.work.can_cancel:
			return ("Job %d cannot be stopped part way: %s It ends by itself; job {\"id\": %d} "
				% [entry.id, _sentence(entry.work.line()), entry.id] + "gives its answer.")
		entry.work.cancel()
	var until: int = Time.get_ticks_msec() + roundi(wait_s * 1000.0)
	while not entry.finished and Time.get_ticks_msec() < until:
		await tree.process_frame
	if not entry.finished:
		var share: String = ""
		if entry.work.total > 0:
			share = " (%d%%)" % roundi(100.0 * entry.work.done / entry.work.total)
		return ("Job %d (%s) is still going, %d s in%s: %s Call job {\"id\": %d} again in "
			% [entry.id, entry.tool, entry.seconds(), share, _sentence(entry.work.line()),
				entry.id]
			+ "about 10 s%s." % (", or with cancel=true to stop it" if entry.work.can_cancel
				and not entry.work.cancelled else ""))
	var said: String
	if entry.answer == null:
		return ("Job %d (%s) failed after %d s: it stopped without an answer (the app's log "
			% [entry.id, entry.tool, entry.seconds()] + "says why).")
	if entry.work.cancelled:
		said = "Job %d (%s) was cancelled after %d s, so it stopped part way: " % [entry.id,
			entry.tool, entry.seconds()]
	else:
		said = "Job %d (%s) is done, after %d s:\n" % [entry.id, entry.tool, entry.seconds()]
	if entry.answer is Array:
		return [{"type": "text", "text": said.strip_edges()}] + (entry.answer as Array)
	return said + str(entry.answer)


## What the job holding the app is doing, for a call made meanwhile.
func busy(entry: Entry) -> String:
	return ("The app is busy with job %d (%s, %d s in): %s Call job {\"id\": %d} until it "
		% [entry.id, entry.tool, entry.seconds(), _sentence(entry.work.line()), entry.id]
		+ "gives its answer%s, then this." % (", or cancel it" if entry.work.can_cancel else ""))


func _listing() -> String:
	var rows := PackedStringArray()
	for entry: Entry in _entries:
		rows.append("%d (%s, %s)" % [entry.id, entry.tool, "done" if entry.finished else "going"])
	return "Jobs: %s." % ", ".join(rows)


## A line from the bar as a sentence: "Rendering… 3 of 36" ends in a full stop.
static func _sentence(line: String) -> String:
	var said: String = line.strip_edges()
	if said.ends_with("…") or said.ends_with("."):
		return said
	return said + "."
