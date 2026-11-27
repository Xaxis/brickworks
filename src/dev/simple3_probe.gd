## simple3: Simple's own placing context (SimpleLayer._set_full_aside and
## _put_full_back). Full's settings that Simple neither shows nor can change
## are set aside on the way in and put back on the way out: the sub-assembly
## Full is editing inside, its snap and turn, its tool, the way the part in
## hand faces, the ruler, an x-ray of the sub-assembly. simplereview3's probe
## holds T1-T4 and the way back's frames; this holds the rest of the list.
##
##   godot --path . --resolution 390x844 --script src/dev/simple3_probe.gd
##   godot --headless --path . --script src/dev/simple3_probe.gd -- --headless-ok
##   PROBE_SIZE=390x844 tools/probe.sh simple3_probe -- --pictures=DIR
##   PROBE_SIZE=1280x800 tools/probe.sh simple3_probe -- --desktop --pictures=DIR
##
## --case= context, chosen (all when not said);
##   context  Full inside the sub-assembly with Half chosen on the toolbar (and
##            so in the prefs), a 45 degree turn, Paint, the part in hand on its
##            side, x-ray on: into Simple, each Simple's own; a brick from the
##            tray on a plain brick goes into the model, upright, on the studs;
##            back in Full each of Full's as it was, the prefs still Half.
##   chosen   the same, a part chosen in Simple: back in Full that part
##            selected at the model's top, not inside the sub-assembly.
##   hover    (a window with a mouse; headless picks nothing under a pointer)
##            Full at the model's top, the pointer on a part of a sub-assembly:
##            Full's hover outlines the whole sub-assembly; into Simple, nothing
##            outlined, through the lens easing in; back in Full, outlined again
##            with the pointer not moved.
## Exits non-zero when a check fails.
extends "res://src/dev/simplereview3_probe.gd"


func _run() -> void:
	if not await _start("context,chosen,hover"):
		return
	for one: String in ["context", "chosen", "hover"]:
		if not _cases.has(one):
			continue
		print("\n== %s" % one)
		match one:
			"context":
				await _case_context(false)
			"chosen":
				await _case_context(true)
			"hover":
				await _case_hover()
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


func _probe_name() -> String:
	return "simple3_probe"


## Full set up as a person who has used it would leave it: inside the
## sub-assembly, every setting changed from its first. [wing, plain red brick].
func _full_set_up() -> Array:
	await _from_full_open()
	var shell: Shell = _main.get("_shell")
	var wing_part: int = 0
	var plain: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		if wing_part == 0 and not Assemblies.path_of(brick).is_empty():
			wing_part = brick.id
		if plain == 0 and Assemblies.path_of(brick).is_empty() and brick.color_code == 4:
			plain = brick.id
	_builder.clear_selection()
	_builder.select_brick(wing_part, false)
	var wing: String = shell.assemblies.selected_assembly()
	_builder.clear_selection()
	shell.assemblies.enter(wing)
	shell.set_snap("half")
	_verbs.turn_step = 45.0
	shell.see_inside.set_xray(true)
	_main.call("_on_part_chosen", "3004")
	_builder.held_face = "+x"
	_builder.held_rotation = 1
	await _frames(4)
	return [wing, plain]


func _full_now() -> Dictionary:
	var shell: Shell = _main.get("_shell")
	return {"entered": shell.assemblies.entered, "place_group": _builder.place_group, "snap": _verbs.snap,
		"across": _builder.snap_across, "turn": _verbs.turn_step, "mode": _verbs.mode,
		"held": [_builder.held_part, _builder.held_color, _builder.held_face, _builder.held_rotation],
		"xray": shell.see_inside.seeing_through, "prefs_snap": str(ShellPrefs.value("snap"))}


func _case_context(choose: bool) -> void:
	var set_up: Array = await _full_set_up()
	var wing: String = set_up[0]
	var plain: int = set_up[1]
	if not _check("Full inside the sub-assembly \"%s\", a plain red 2 x 4 (%d)" % [wing, plain],
			not wing.is_empty() and plain != 0):
		return
	# Paint last: choosing a part puts Place in hand.
	_verbs.set_mode("paint")
	await _frames(2)
	var full: Dictionary = _full_now()
	_note2("in Full: %s" % str(full))
	var banner: AssemblyBanner = _banner()
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	var simple: Dictionary = _full_now()
	_note2("in Simple: %s" % str(simple))
	_check("in Simple a part goes into the model, not \"%s\" (editing inside \"%s\", place_group \"%s\")"
		% [wing, simple["entered"], simple["place_group"]], simple["entered"] == "" and simple["place_group"] == "")
	_check("...Full's banner for the sub-assembly put away (%s)" % (banner.visible if banner != null else "none"),
		banner == null or not banner.visible)
	_check("...on the studs, a quarter turn (snap %s, %.0f across, turn %.0f)" % [simple["snap"], simple["across"],
		simple["turn"]], simple["snap"] == "stud" and is_equal_approx(float(simple["across"]), 20.0)
		and is_equal_approx(float(simple["turn"]), 90.0))
	_check("...with Select, not Full's Paint (%s)" % simple["mode"], simple["mode"] == "select")
	_check("...no x-ray (%s)" % simple["xray"], not bool(simple["xray"]))
	_check("...and the prefs keep Full's Half (%s)" % simple["prefs_snap"], simple["prefs_snap"] == "half")
	var at: Vector2 = _point_on(plain)
	if not _check("the plain 2 x 4 on the screen", at.x < INF):
		return
	var put: int = await _put("3001", 14, at)
	await _seat_done()
	if _check("a 2 x 4 from the tray put down on it (%d)" % put, put != 0):
		var brick: BrickWorld.Brick = _world.get_brick(put)
		var joined: int = SelectBy.connected(_world, _builder.lattice, [put], _store.scenery, 2).size() - 1
		_check("...in the model (group \"%s\"), upright and on a quarter (left alone \"%s\"), joined (%d)"
			% [brick.group, str(_simple.call("left_alone", put)), joined],
			brick.group.is_empty() and str(_simple.call("left_alone", put)).is_empty() and joined > 0)
	if choose and put != 0:
		_simple.call("_pick", [put])
		await _frames(2)
	_main.call("use_controls", &"full")
	await _frames(6)
	var back: Dictionary = _full_now()
	_note2("back in Full: %s; selected %s" % [str(back), str(_builder.selection.keys())])
	if choose:
		_check("back in Full with a part chosen in Simple: at the model's top (\"%s\"), that part selected (%s)"
			% [back["entered"], str(_builder.selection.keys())],
			back["entered"] == "" and _builder.selection.size() == 1 and _builder.selection.has(put))
	else:
		_check("back in Full: inside \"%s\" again (\"%s\", place_group \"%s\")" % [wing, back["entered"],
			back["place_group"]], back["entered"] == wing and back["place_group"] == wing)
		_check("...its banner shown again (%s)" % (banner.visible if banner != null else "none"),
			banner == null or banner.visible)
		_check("...x-ray on again (%s)" % back["xray"], bool(back["xray"]))
	for key: String in ["snap", "across", "turn", "mode", "held", "prefs_snap"]:
		_check("...Full's %s as it was: %s (was %s)" % [key, str(back[key]), str(full[key])],
			str(back[key]) == str(full[key]))
	await _shot("s3_context_%s" % ("chosen" if choose else "back"))
	# Full as it starts, for whatever runs next.
	var shell: Shell = _main.get("_shell")
	shell.see_inside.set_xray(false)
	shell.assemblies.leave_to("")
	shell.set_snap("stud")
	_verbs.turn_step = 90.0
	_verbs.set_mode("select")
	_builder.held_face = "up"
	_builder.held_rotation = 0
	_builder.clear_selection()
	await _frames(2)


## Full's hover outline is Full's: none under Simple, and Full's again after.
func _case_hover() -> void:
	if DisplayServer.get_name() == "headless" or Phone.on():
		_note2("hover: a window with a mouse only (headless picks nothing under a pointer)")
		return
	await _from_full_open()
	var shell: Shell = _main.get("_shell")
	shell.assemblies.leave_to("")
	_verbs.set_mode("select")
	_builder.clear_selection()
	await _frames(3)
	var outline: Node3D = _main.get("_hover_outline")
	var at := Vector2.INF
	var part: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id) or Assemblies.path_of(brick).is_empty():
			continue
		at = _point_on(brick.id)
		if at.x < INF:
			part = brick.id
			break
	if not _check("a part of a sub-assembly on the screen (%d)" % part, part != 0):
		return
	_mouse_move(at)
	await _frames(4)
	var takes: int = _builder.takes(part).size()
	_check("in Full the pointer on it outlines what a click takes: hovered %d, %d parts, outline shown %s"
		% [int(_main.get("_hovered")), takes, outline.visible],
		int(_main.get("_hovered")) != 0 and outline.visible and takes > 1)
	_main.call("use_controls", &"simple")
	var shown_in_simple: int = 0
	for _n: int in 40:
		await process_frame
		if outline.visible or int(_main.get("_hovered")) != 0:
			shown_in_simple += 1
	await _settle()
	_check("in Simple nothing outlined in any of 40 frames from the press, the lens easing in (%d with one)"
		% shown_in_simple, shown_in_simple == 0 and not outline.visible)
	_main.call("use_controls", &"full")
	await _frames(6)
	_check("back in Full, the pointer not moved: outlined again (hovered %d, outline shown %s)"
		% [int(_main.get("_hovered")), outline.visible], int(_main.get("_hovered")) != 0 and outline.visible)
	await _shot("s3_hover_back")


func _banner() -> AssemblyBanner:
	for node: Node in _main.find_children("*", "AssemblyBanner", true, false):
		return node as AssemblyBanner
	return null
