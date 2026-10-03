## Can the designer see the thing it was asked to build?
##
##   godot --headless --path . --script src/dev/reference_lookup_probe.gd
##
## Needs the internet: it really asks Wikimedia Commons. In the suite it
## runs only with --network, beside the other two that go out.
##
## A designer given "a lighthouse" has one in front of them. This one had
## the word and whatever it could recall of it, which is every lighthouse
## and no lighthouse — a tapering tower with a light on top. A picture
## says how many times its own width this one stands and where its
## gallery sits, and proportions are decided before the first brick.
##
## What it cannot do is as important: Commons carries what is free to
## use, so a spaceship from a film is not there and a search for one
## comes back with whatever shares its name. Every picture is named and
## credited in the answer so the model can see that and say so.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame

	print("  a thing that exists")
	var answer: Variant = await assistant._run_tool({
		"name": "find_reference", "input": {"subject": "lighthouse tower"}})
	_check("the answer is blocks, not a sentence", answer is Array)
	if answer is Array:
		var blocks: Array = answer
		var pictures: int = 0
		var named: int = 0
		for block: Variant in blocks:
			var one: Dictionary = block
			if str(one.get("type", "")) == "image":
				pictures += 1
				var data: String = str(
					(one.get("source", {}) as Dictionary).get("data", ""))
				# A picture nobody can decode is not a picture.
				var bytes: PackedByteArray = Marshalls.base64_to_raw(data)
				var image := Image.new()
				if image.load_png_from_buffer(bytes) != OK:
					_failures += 1
					print("  FAIL  a block says image and will not decode")
				elif image.get_width() < 200:
					_failures += 1
					print("  FAIL  a picture came back %d wide, too small to "
						% image.get_width() + "read a shape off")
			elif str(one.get("text", "")).contains("—"):
				named += 1
		_check("it brought back pictures, %d" % pictures, pictures > 0)
		# Named and credited, because the model has to be able to tell
		# that it has been handed the wrong thing.
		_check("each one says what it is and whose it is, %d" % named,
			named >= pictures)

	# And it is still there when the detailing starts.
	#
	# Old pictures are swept out of the conversation as they age, which
	# is right for drafts — a dozen views of a model that no longer
	# exists is most of a context window spent on nothing — and exactly
	# wrong for the subject. The designer stops looking at the thing at
	# the moment it starts getting the details wrong.
	print("")
	print("  and it survives the sweep that drops old drafts")
	if answer is Array:
		assistant._messages = [
			{"role": "user", "content": [{"type": "text", "text": "build it"}]},
			{"role": "user", "content": [
				{"type": "tool_result", "content": answer},
				{"type": "image", "source": {"type": "base64",
					"media_type": "image/png", "data": "a-draft"}},
			]},
		]
		assistant._forget_old_pictures()
		var kept: int = 0
		var dropped: int = 0
		var later: Array = assistant._messages[1]["content"]
		for block: Variant in (later[0] as Dictionary)["content"]:
			if str((block as Dictionary).get("type", "")) == "image":
				kept += 1
		if str((later[1] as Dictionary).get("type", "")) != "image":
			dropped += 1
		_check("the pictures of the subject are still there, %d" % kept,
			kept > 0)
		_check("...and the draft beside them is not, %d dropped" % dropped,
			dropped == 1)

	print("")
	print("  and a thing that is not free to use")
	# Commons will not have a copyrighted spaceship. What matters is that
	# the answer says what it does have rather than passing it off.
	var fiction: Variant = await assistant._run_tool({
		"name": "find_reference",
		"input": {"subject": "USS Voyager Star Trek starship"}})
	var said: String = ""
	if fiction is String:
		said = fiction
	elif fiction is Array:
		for block: Variant in fiction as Array:
			said += str((block as Dictionary).get("text", ""))
	_check("the answer warns that a name can bring back something else",
		said.contains("shares it") or said.contains("Build it from what"))

	print("")
	print("  and an empty question")
	var nothing: Variant = await assistant._run_tool({
		"name": "find_reference", "input": {"subject": "   "}})
	_check("an empty subject is answered, not searched for",
		nothing is String and (nothing as String).contains("Say what"))

	print("")
	if _failures == 0:
		print("the designer can look at the thing it was asked for")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)
