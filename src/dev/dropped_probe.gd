## Does a connection that drops take the whole design with it?
##
##   godot --headless --path . --script src/dev/dropped_probe.gd
##
## A design runs for twenty minutes and holds each connection open for
## up to three, so one of them failing somewhere in the middle is
## ordinary rather than exceptional. It used to ask again exactly once
## and then give up: twenty-four minutes and a finished windmill were
## lost one revision short of done, because a socket closed.
##
## Pointed at a port nothing is listening on, so every attempt really
## does fail. No key is set on this assistant, which matters — a key
## would send the request to the real endpoint instead of this one.
extends SceneTree

var _failures: int = 0
## A field, not a local. A lambda captures by value, so a counter
## incremented inside one and read outside it never moved.
var _tries: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
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

	if not assistant.key_in_use().is_empty():
		print("  FAIL  this assistant has a key, so the request would "
			+ "go to the real endpoint")
		quit(1)
		return

	# Streaming on, because asking again is what happens when a stream
	# fails — with it off the retry path is never reached at all.
	assistant.stream_replies = true
	assistant.endpoint = "http://127.0.0.1:1/none"
	assistant.progress.connect(func(note: String) -> void:
		if note.begins_with("still trying"):
			_tries += 1)

	print("  a design whose connection never comes back")
	if not assistant.design("a rocket"):
		print("  FAIL  the design was refused before it started")
		quit(1)
		return
	var outcome: Array = await assistant.finished

	_check("it gives up in the end", not bool(outcome[0]))
	# A number, not TRIES_WHEN_DROPPED - 1.
	#
	# Written against the constant, this check said "ok, 0 times" when
	# the constant was set to 1 — 0 >= 0 — so the one thing it existed
	# to catch was the one thing it could not. A test measured against
	# the value under test asserts nothing at all.
	_check("it asked again more than once, %d times" % _tries,
		_tries >= 2)
	_check("and says so rather than blaming the model",
		str(outcome[1]).contains("several tries"))

	print("")
	if _failures == 0:
		print("a dropped connection costs tries, not the design")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
