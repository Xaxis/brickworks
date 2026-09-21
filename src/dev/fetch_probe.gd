## Does everyone who asked for a part hear that it arrived?
##
##   godot --headless --path . --script src/dev/fetch_probe.gd
##
## Fetches are deduplicated by geometry, because different parts share
## it all the time — a brick and its printed variant, a part and the
## same part under another number. The request carried only the first
## asker's id, so a second part was told "coming" and then heard a
## fetched() for a part it had not asked about, and went on waiting for
## one that never came.
##
## What waits on that signal: the ghost that appears when you pick a
## part, and the assistant's check that the geometry for a design has
## landed. Neither says anything while it waits, so the app simply does
## nothing when a part is chosen.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	# Two catalogue entries that are the same geometry. Found rather
	# than assumed: which parts share a mesh is a property of the
	# conversion, not something to hard-code and have go stale.
	var by_hash: Dictionary = {}
	var pair: Array[String] = []
	for part_id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[part_id]
		if by_hash.has(info.mesh_hash):
			pair = [str(by_hash[info.mesh_hash]), part_id]
			break
		by_hash[info.mesh_hash] = part_id

	if pair.is_empty():
		print("  no two parts in this catalogue share geometry")
		quit(0)
		return
	print("  %s and %s are the same geometry" % [pair[0], pair[1]])

	var heard: Dictionary = {}
	library.fetched.connect(func(part_id: String) -> void:
		heard[part_id] = true)

	# Both asked for while the first is still in flight. Simulated by
	# hand rather than over the network: what is being tested is the
	# bookkeeping, and a real fetch would test the network instead.
	var info: PartLibrary.PartInfo = library.parts[pair[0]]
	library._fetching[info.mesh_hash] = [pair[0]]
	library.request_mesh(pair[1])

	var waiting: Array = library._fetching.get(info.mesh_hash, [])
	if waiting.has(pair[0]) and waiting.has(pair[1]):
		print("  ok    both are recorded as waiting for it")
	else:
		_failures += 1
		print("  FAIL  only %s is waiting for it" % [waiting])

	# And when it lands, both are told.
	var asked_for: Array = library._fetching.get(info.mesh_hash, [])
	library._fetching.erase(info.mesh_hash)
	for asked: String in asked_for:
		library.fetched.emit(asked)

	for part_id: String in pair:
		if heard.has(part_id):
			print("  ok    %s heard that it arrived" % part_id)
		else:
			_failures += 1
			print("  FAIL  %s was never told" % part_id)

	print("")
	if _failures == 0:
		print("everyone who asked is told")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
