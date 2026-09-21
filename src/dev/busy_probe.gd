## What happens when a second design is asked for during the first?
##
##   godot --headless --path . --script src/dev/busy_probe.gd
##
## It used to clear the conversation and then discover the loop was
## busy, which leaves the worst of both: the old run still going, with
## no history behind it, appending its next turn to nothing.
##
## That shipped a wrong model. The example generator gave up waiting on
## a boat that had run long, asked for a rocket, and the boat's loop
## carried on into the cleared history — went on talking about
## bowsprits, rebuilt itself into the cleared baseplate, and was written
## to disk under the other name. models/rocket.ldr was a boat.
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

	# Pretend a design is running. No network: what is being tested is
	# the bookkeeping around the loop, not the loop.
	assistant._busy = true
	assistant._messages = [{"role": "user", "content": "a boat"}]

	var took: bool = assistant.design("a rocket")
	_check("a second design is refused while one is running", not took)
	_check("and the conversation it would have replaced is still there",
		assistant.has_conversation())
	_check("...with the boat still in it",
		str(assistant._messages[0].get("content", "")) == "a boat")

	var revised: bool = assistant.revise("make it red")
	_check("a revision is refused too", not revised)
	_check("and left the conversation alone", assistant.has_conversation())

	# And once it is over, both work again.
	assistant._busy = false
	assistant._messages.clear()
	# design() sends. Pointed at a port nothing is listening on, so the
	# request fails quietly a moment later rather than complaining on
	# the console about a hostname that is not one.
	assistant.stream_replies = false
	assistant.endpoint = "http://127.0.0.1:1/none"
	_check("a design is accepted once the loop is free",
		assistant.design("a rocket"))

	print("")
	if _failures == 0:
		print("a second design cannot damage the first")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
