## wingfix2's pictures: both twins of a part in hand over a wing placed
## straight and mirrored, aimed a stud along the mirror's axis (red, the
## bar's words) and along the axis it keeps (green), each before the click.
##
##   godot --path . --resolution 1280x800 --script src/dev/wf2_shots_probe.gd
##
## The pictures go to ROOM_SHOTS (a folder) or res://shots/wf2.
extends "res://src/dev/wf2_probe.gd"


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(900.0).timeout.connect(func() -> void:
		print("wf2 shots: not finished in time")
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_bar_main = _main.get("_bar")
	_tree = _shell.assemblies
	var size: Vector2 = root.get_visible_rect().size
	for spec: Array in [["along_the_mirror", Vector3(20, 0, 0)], ["along_its_keep", Vector3(0, 0, 20)]]:
		await _open(_wing_file([STRAIGHT, MIRRORED]))
		await _frames(30)
		var frames: Array = [_placed_by(STRAIGHT), _placed_by(MIRRORED)]
		var ids: Array = []
		for f: Transform3D in frames:
			ids.append(_in(_copy_at(f), "3004").id)
		_pick(ids)
		_builder.lift_selection()
		await _edited()
		await _frames(2)
		var carry: Carry = _builder.carrying
		carry.stand_where_lifted(_builder.lattice, _builder)
		carry.pin()
		carry.show_moved(Transform3D(Basis.IDENTITY, spec[1]), _builder.lattice, _builder)
		for _n: int in 200:
			_builder.call("_ask_copies")
			if (_builder.get("_copies_ask") as Dictionary).is_empty():
				break
		await _frames(20)
		var red: String = str(_builder.get("copies_refuse"))
		_check("%s at %dx%d: the ghost %s (\"%s\")" % [spec[0], size.x, size.y,
			"red" if not red.is_empty() else "green", red.left(80)],
			red.is_empty() == (spec[0] == "along_its_keep"))
		await _picture("%s_%d" % [spec[0], int(size.x)])
		_builder.cancel_carry()
		await _edited()
	print("\nwf2 shots: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


func _picture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("ROOM_SHOTS")
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("res://shots/wf2")
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join("%s.png" % name)
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)
