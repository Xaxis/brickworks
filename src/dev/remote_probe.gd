## Fetch geometry the way the web build has to.
##
##   godot --headless --path . --script src/dev/remote_probe.gd
##
## The web build ships a few hundred parts and asks for the rest. That
## path is easy to get wrong in ways nothing local notices: a relative
## URL that HTTPRequest refuses, a host that answers a missing object
## with a page instead of a 404, a fetch that goes out before anything
## has said where to send it. Each of those has happened here.
##
## So this loads the *web* catalogue on the desktop, points it at the
## real bucket, and asks for parts that are deliberately not in the pack.
extends SceneTree

var _library: PartLibrary
var _arrived: PackedStringArray = PackedStringArray()
var _failed: PackedStringArray = PackedStringArray()
var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var host := Node.new()
	root.add_child(host)

	_library = PartLibrary.new()
	# Pinned to the pack, not left to resolve. On the desktop the full
	# library is right there, so every part would load locally and the
	# remote path — the only one the browser has — would never run.
	_library._root = PartLibrary.PACK_ROOT
	if not _library.load_catalogue():
		print("no web pack — tools/web_pack.py")
		quit(1)
		return
	_library.set_fetch_host(host)
	_library.remote_parts = _parts_url()
	print("  catalogue: %d parts, fetching from %s"
		% [_library.parts.size(), _library.remote_parts])

	_library.fetched.connect(func(part_id: String) -> void: _arrived.append(part_id))
	_library.fetch_failed.connect(func(part_id: String, why: String) -> void:
		_failed.append("%s (%s)" % [part_id, why]))

	# Parts the pack does not carry. Picked across the size range,
	# because the old arrangement cut the large ones first and those are
	# exactly the ones nobody noticed were missing.
	var wanted: Array[String] = []
	for id: String in _library.ids():
		var info: PartLibrary.PartInfo = _library.parts[id]
		if info.is_redirect() or _library.is_resident(id):
			continue
		wanted.append(id)
		if wanted.size() >= 12:
			break

	if wanted.is_empty():
		print("  every part is already resident — nothing to prove")
		quit(0)
		return

	for part_id: String in wanted:
		_library.request_mesh(part_id)

	var deadline: int = Time.get_ticks_msec() + 90_000
	while _arrived.size() + _failed.size() < wanted.size():
		if Time.get_ticks_msec() > deadline:
			break
		await process_frame

	print("")
	# A 400 from the bucket is "no such object", which during an upload
	# means "not there yet" rather than "broken". Worth separating: the
	# failure this probe exists to catch is the one where something
	# answers 200 with a page, and that shows up as a parse error.
	var absent: int = 0
	for line: String in _failed:
		if line.contains("HTTP 400") or line.contains("HTTP 404"):
			absent += 1
		else:
			print("      failed: %s" % line)

	_check("nothing failed for a reason other than being absent (%d absent)"
		% absent, _failed.size() == absent)
	_check("%d of %d asked for arrived" % [_arrived.size(), wanted.size()],
		_arrived.size() > 0)
	if absent > 0:
		print("      (%d not in the bucket yet — re-run once the upload "
			% absent + "has finished and this should be zero)")

	# Arriving is not the same as being usable.
	var usable: int = 0
	for part_id: String in _arrived:
		var mesh: Lbm.PartMesh = _library.mesh_for(part_id)
		if mesh != null and not mesh.surfaces.is_empty():
			usable += 1
	_check("%d of %d parse into geometry" % [usable, _arrived.size()],
		usable == _arrived.size() and usable > 0)

	print("")
	print("%d failed" % _failures if _failures else "the remote fetch path works")
	quit(1 if _failures else 0)


static func _parts_url() -> String:
	var file: FileAccess = FileAccess.open("res://.env", FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with("PARTS_URL="):
			return line.substr(10).strip_edges()
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
