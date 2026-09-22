## Does the request carry only what the chosen model will accept?
##
##   godot --headless --path . --script src/dev/brain_probe.gd
##
## Three models and five levels of effort, and the combinations are not
## all legal. Haiku refuses adaptive thinking and refuses the effort
## parameter, each with a 400 — measured against the live API, not read
## off a page — so a picker that does not know would turn "choose the
## quick model" into "break the assistant".
##
## This builds the actual request body for every combination the app
## can be put into and checks what is in it. It cannot tell whether
## Anthropic would accept it; what it can tell is whether the app kept
## its own promise about what it sends, which is the part that has been
## wrong before.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
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

	# Pretend there is a key, so the body takes the direct-call shape —
	# the one where this app, not the proxy, decides what to send.
	assistant.direct_key = "sk-ant-probe"

	var was: String = Brain.chosen()
	var was_effort: String = Brain.effort()

	for choice: Brain.Choice in Brain.all():
		Brain.choose(choice.id)
		for level: String in Brain.EFFORTS:
			Brain.set_effort(level)
			var body: Dictionary = assistant.request_body()
			_check(choice, level, body)
			_room_to_write(assistant, choice, body)
			_cached_prefix(choice, body)

	print("")
	# Anything in the body that Anthropic does not take is refused
	# outright, which is how design_id once broke every direct call.
	Brain.choose(Brain.DEFAULT_MODEL)
	var plain: Dictionary = assistant.request_body()
	var strange := PackedStringArray()
	for field: String in plain:
		if not Assistant.ANTHROPIC_FIELDS.has(field):
			strange.append(field)
	if strange.is_empty():
		print("  ok    every field in the body is one Anthropic takes")
	else:
		_failures += 1
		print("  FAIL  the body carries %s" % ", ".join(strange))

	# A saved setting naming a model that no longer exists must fall
	# back rather than take the panel down with it.
	Brain.choose("claude-from-the-future")
	if Brain.find(Brain.chosen()).id == Brain.DEFAULT_MODEL:
		print("  ok    a model that no longer exists falls back")
	else:
		_failures += 1
		print("  FAIL  an unknown model was kept: %s" % Brain.chosen())

	Brain.choose(was)
	if not was_effort.is_empty():
		Brain.set_effort(was_effort)

	print("")
	_money()
	_for_this_run_only()

	print("")
	if _failures == 0:
		print("the request carries what the model takes, and nothing else")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _check(choice: Brain.Choice, level: String, body: Dictionary) -> void:
	var what: String = "%s at %s effort" % [choice.name, level]

	if str(body.get("model", "")) != choice.id:
		_failures += 1
		print("  FAIL  %s: the body asks for %s" % [what, body.get("model")])
		return

	var has_thinking: bool = body.has("thinking")
	if has_thinking != choice.adaptive:
		_failures += 1
		print("  FAIL  %s: thinking is %s and the model %s take it" % [
			what, "present" if has_thinking else "absent",
			"does" if choice.adaptive else "does not"])
		return

	var has_effort: bool = body.has("output_config")
	if has_effort != choice.effort:
		_failures += 1
		print("  FAIL  %s: effort is %s and the model %s take it" % [
			what, "present" if has_effort else "absent",
			"does" if choice.effort else "does not"])
		return
	if has_effort and str(body["output_config"].get("effort", "")) != level:
		_failures += 1
		print("  FAIL  %s: the body asks for %s" % [
			what, body["output_config"].get("effort")])
		return
	print("  ok    %s" % what)


## The arithmetic on top of the tokens, against a worked example from
## the published table: 50,000 input and 15,000 output on Opus 5 is
## $0.25 plus $0.375.
func _money() -> void:
	var spend := Brain.Spend.new()
	spend.add({"input_tokens": 50000, "output_tokens": 15000})
	var dollars: float = Brain.cost("claude-opus-5", spend)
	if absf(dollars - 0.625) < 0.0005:
		print("  ok    Opus 5 on 50k in and 15k out is $%.3f" % dollars)
	else:
		_failures += 1
		print("  FAIL  that should be $0.625 and came to $%.4f" % dollars)

	# A cache hit is a tenth of the input price, which is the whole
	# reason the count is kept apart from the fresh one.
	var cached := Brain.Spend.new()
	cached.add({"input_tokens": 10000, "cache_read_input_tokens": 40000,
		"output_tokens": 15000})
	var less: float = Brain.cost("claude-opus-5", cached)
	if absf(less - 0.445) < 0.0005:
		print("  ok    with 40k of it cached, $%.3f" % less)
	else:
		_failures += 1
		print("  FAIL  that should be $0.445 and came to $%.4f" % less)

	for pair: Array in [[0.0, "nothing yet"], [0.004, "under a cent"],
			[0.042, "4¢"], [1.5, "$1.50"]]:
		var said: String = Brain.in_money(float(pair[0]))
		if said == str(pair[1]):
			continue
		_failures += 1
		print("  FAIL  %.3f reads as '%s', wanted '%s'"
			% [pair[0], said, pair[1]])


## A model or an effort named on a command line lasts for that run.
##
## The app remembers what the person chose. A script asking for max
## effort once must not rewrite that, or a single overnight run changes
## what the app opens with — and nothing on screen would say why.
func _for_this_run_only() -> void:
	print("")
	print("  a command line does not rewrite the settings")
	var kept_effort: String = Brain.effort()
	var kept_model: String = Brain.chosen()

	var other: String = "low" if kept_effort != "low" else "high"
	Brain.use_effort(other)
	if Brain.effort() == other:
		print("  ok    the run uses the effort it was given")
	else:
		_failures += 1
		print("  FAIL  asked for %s and got %s" % [other, Brain.effort()])

	Brain.use_effort("")
	if Brain.effort() == kept_effort:
		print("  ok    and the stored one is untouched")
	else:
		_failures += 1
		print("  FAIL  the stored effort became %s" % Brain.effort())

	Brain.use_model("claude-haiku-4-5-20251001")
	var asked: String = Brain.chosen()
	Brain.use_model("")
	if asked != kept_model and Brain.chosen() == kept_model:
		print("  ok    the same for the model")
	else:
		_failures += 1
		print("  FAIL  model went %s -> %s -> %s"
			% [kept_model, asked, Brain.chosen()])


## Enough room to write a set-sized model.
##
## This was a flat 16,000 tokens for every model, which is roughly 380
## bricks of placements — and a real set is five hundred to two
## thousand. Nothing built here had ever been bigger than that, and it
## read as a matter of taste rather than an envelope, because a design
## that ran over came back as a model with no parts in it.
func _room_to_write(assistant: Assistant, choice: Brain.Choice,
		body: Dictionary) -> void:
	var asked: int = int(body.get("max_tokens", 0))
	if asked != choice.most_out:
		_failures += 1
		print("  FAIL  %s streams with max_tokens %d, wanted %d"
			% [choice.name, asked, choice.most_out])
		return
	# A number, not choice.most_out: measured against the value under
	# test, the check passes however low that value goes. The point is
	# that it is big enough to say a set in, and 16,000 is not.
	if asked <= 16000:
		_failures += 1
		print("  FAIL  %s can only write %d tokens, which is a few "
			% [choice.name, asked] + "hundred bricks")
		return
	# And smaller when the reply is not streamed, because that path
	# exists for a connection that has already dropped once.
	assistant.stream_replies = false
	var quieter: int = int(assistant.request_body().get("max_tokens", 0))
	assistant.stream_replies = true
	if quieter > 16000:
		_failures += 1
		print("  FAIL  %s asks for %d tokens unstreamed"
			% [choice.name, quieter])


## The rules are sent every turn and never change.
##
## A design runs to forty-five turns and re-sends the whole conversation
## each time, so the system prompt alone was read and charged for at
## full price forty-five times. It is one literal string — no date, no
## identifier, nothing counted — which is exactly what a cache prefix
## has to be.
func _cached_prefix(choice: Brain.Choice, body: Dictionary) -> void:
	var system: Variant = body.get("system")
	if typeof(system) != TYPE_ARRAY or (system as Array).is_empty():
		_failures += 1
		print("  FAIL  %s sends the rules as a bare string, which "
			% choice.name + "cannot carry a cache mark")
		return
	var first: Dictionary = system[0]
	if not first.has("cache_control"):
		_failures += 1
		print("  FAIL  %s does not mark the rules cacheable"
			% choice.name)
		return
	# The mark has to sit at the end of the last stable thing, and the
	# request renders tools before system — so this one covers both.
	if str(first.get("text", "")).is_empty():
		_failures += 1
		print("  FAIL  %s marks an empty block cacheable" % choice.name)
