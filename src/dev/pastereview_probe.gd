## pastereview: a paste from another browser tab (appwalk 099695588) against a
## paste in the same tab. The same tab holds Carry.clipboard as it was
## gathered. The other tab holds the copy as this site's tabs keep it
## (Carry.whole_text), pasted in a tab that copied nothing
## (EditVerbs.paste_from), as paste() does on the web. Each is put down at the
## same spot and compared part by part and by sub-assembly, undone, saved and
## reopened.
##
## pastereview's own probe read the other tab's copy as LDraw (Carry.as_file
## in, Carry.from_ldraw out), as appwalk kept it, and found the parts the app
## can't show and the sub-assemblies lost (F3). appfix keeps the clipboard
## whole for the other tabs; this is that probe with its other tab's read
## changed to the one paste() makes now, structure checked, not noted, and
## three cases more: a copy made by one account and pasted by another or after
## a sign-out (F2), and a copy one of whose parts can't be had (F1's refusal).
##
##   godot --headless --path . --script src/dev/pastereview_probe.gd
##
## Made parts go to user://pastereview_probe/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://pastereview_probe/"
const PART := "bw-pastereview-s000001"
const TEXT := """0 Custom Shape Pastereview Probe
0 Name: bw-pastereview-s000001.dat
0 Author: pastereview_probe
0 !LDRAW_ORG Unofficial_Part

0 BFC CERTIFY CCW

3 16 -10 0 -10 10 0 -10 10 0 10
3 16 -10 0 -10 10 0 10 -10 0 10
3 16 -10 8 -10 10 8 10 10 8 -10
3 16 -10 8 -10 -10 8 10 10 8 10
3 16 -10 0 -10 -10 8 -10 10 8 -10
3 16 -10 0 -10 10 8 -10 10 0 -10
3 16 -10 0 10 10 0 10 10 8 10
3 16 -10 0 10 10 8 10 -10 8 10
3 16 -10 0 -10 -10 0 10 -10 8 10
3 16 -10 0 -10 -10 8 10 -10 8 -10
3 16 10 0 -10 10 8 -10 10 8 10
3 16 10 0 -10 10 8 10 10 0 10
0
"""
const UNKNOWN := "zzzpastereview"
const HELD_MODEL := """0 FILE pr_unknown.ldr
0 pr_unknown
0 Name: pr_unknown.ldr
0 Author: pastereview_probe
1 16 0 0 0 1 0 0 0 1 0 0 0 1 pr_sub.ldr
1 16 200 0 0 1 0 0 0 1 0 0 0 1 pr_sub.ldr
0 NOFILE
0 FILE pr_sub.ldr
0 pr_sub
0 Name: pr_sub.ldr
0 Author: pastereview_probe
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 zzzpastereview.dat
0 NOFILE
"""

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _verbs: EditVerbs
var _store: ModelStore
var _failures: int = 0
var _notes: int = 0


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	_forget(PROBE_DIR)
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(240)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	print("clipboard feature here: %s, web: %s" % [DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD),
		OS.has_feature("web")])
	await _case_car()
	await _case_minifig()
	await _case_big()
	await _case_made()
	await _case_unknown()
	await _case_other_model()
	await _case_accounts()
	await _case_cannot_have()
	_finish()


# -- the cases ------------------------------------------------------------------


func _case_car() -> void:
	print("\n1. the car: three parts of different colours")
	await _open("res://models/car.ldr")
	var ids: Array = []
	var colours: Dictionary = {}
	for brick: BrickWorld.Brick in _shown():
		if not colours.has(brick.color_code) and _library.mesh_for(brick.part_id) != null:
			colours[brick.color_code] = true
			ids.append(brick.id)
		if ids.size() == 3:
			break
	await _compare("car", ids, true)


func _case_minifig() -> void:
	print("\n2. 7140-1: a minifig whole and two loose parts")
	await _open("res://vendor/omr/files/7140-1.mpd")
	var ids: Array = _minifig_and_loose()
	await _compare("7140", ids, true)


func _case_big() -> void:
	print("\n3. 10030-1: every part")
	await _open("res://vendor/omr/files/10030-1.mpd")
	# What a save and a reopen alone do to it, with no paste: the drift that
	# is there already.
	var untouched: Array = _records_all()
	var base_at: String = ProjectSettings.globalize_path(PROBE_DIR + "10030-untouched.mpd")
	_main.call("save_model", base_at)
	await _open(base_at)
	_same_place("10030 untouched, saved and reopened (no paste)", untouched, _records_all(),
		_centre(_records_all()) - _centre(untouched))
	await _open("res://vendor/omr/files/10030-1.mpd")
	var ids: Array = []
	for brick: BrickWorld.Brick in _shown():
		ids.append(brick.id)
	await _compare("10030", ids, true)


func _case_made() -> void:
	print("\n4. a made part, a sticker and a car part")
	await _open("res://models/car.ldr")
	var made: Dictionary = CustomParts.add(_library, TEXT, PART, true)
	_ok(str(made["problem"]).is_empty() and _library.parts.has(PART), "the part made: %s" % [made["problem"]])
	_builder.held_part = PART
	_builder.held_color = 4
	var made_id: int = await _place_at(Vector3(300, 0, 300))
	_ok(made_id != 0, "the made part placed (%d parts now)" % _shown().size())
	_builder.held_part = ""
	var sticker: String = ""
	if _library.parts.has("003238a") and _library.mesh_for("003238a") != null:
		sticker = "003238a"
	else:
		for id: String in _library.parts:
			var info: PartLibrary.PartInfo = _library.parts[id]
			if info.category == "Sticker" and _library.mesh_for(id) != null:
				sticker = id
				break
	var sticker_id: int = 0
	if not sticker.is_empty():
		sticker_id = _world.add_brick(sticker, 15, Transform3D(Basis.IDENTITY, Vector3(-300, 8, 300)))
	_ok(sticker_id != 0, "a sticker (%s) put in the model" % sticker)
	var car_id: int = 0
	for brick: BrickWorld.Brick in _shown():
		if brick.id != made_id and brick.id != sticker_id:
			car_id = brick.id
			break
	var ids: Array = [made_id, sticker_id, car_id].filter(func(id: int) -> bool: return id != 0)
	# The copy as the other tab gets it, read where the part was never made:
	# another tab's library.
	_select(ids)
	_verbs.copy()
	var text: String = Carry.whole_text("", "made-1", _library)
	await _fresh_read("made, as copied", text, Carry.clipboard, sticker)
	await _compare("made", ids, true)
	# The model saved and reopened (in _compare): the same three copied again.
	var again: Array = []
	for brick: BrickWorld.Brick in _shown():
		if brick.part_id == PART or brick.part_id == sticker:
			again.append(brick.id)
	for brick: BrickWorld.Brick in _shown():
		if not again.has(brick.id) and brick.part_id != PART and brick.part_id != sticker:
			again.append(brick.id)
			break
	_select(again)
	_verbs.copy()
	var parts_now := PackedStringArray()
	for item: Dictionary in Carry.clipboard:
		parts_now.append(str(item["part"]))
	var after_text: String = Carry.whole_text("", "made-2", _library)
	var info: PartLibrary.PartInfo = _library.parts.get(PART)
	print("  (after the save and reopen: copied %s; the made part's source %d chars, custom %s, source_path '%s')"
		% [", ".join(parts_now), _library.custom_source(PART).length(), info.custom if info != null else "no info",
			info.source_path if info != null else ""])
	await _fresh_read("made, copied after the model was saved and reopened", after_text, Carry.clipboard, sticker)


## [param text] (the copy of [param items] as the site's tabs keep it) read by
## Carry.from_whole in a library that never made the part, as another tab's is.
func _fresh_read(tag: String, text: String, items: Array, sticker: String) -> void:
	print("  (%s: the text %d chars, FILE sections %d, the made part's own text %s)" % [tag, text.length(),
		text.count("0 FILE "), "in it" if text.contains("0 FILE %s.dat" % PART) else "NOT in it"])
	var where: String = PROBE_DIR + "fresh-%d/" % Time.get_ticks_usec()
	CustomParts.dir = where
	var fresh := PartLibrary.new()
	fresh.load_catalogue()
	var read: Array = Carry.from_whole(text, "", fresh).get("items", [])
	CustomParts.dir = PROBE_DIR
	var want: Dictionary = _part_colours_of_items(items)
	var got: Dictionary = _part_colours_of_items(read)
	_ok(want == got and fresh.mesh_for(PART) != null,
		"%s, read in a library that never made it: %d of %d parts (%s), the made part %s, sticker %s"
		% [tag, read.size(), items.size(), _diff_counts(want, got), "built" if fresh.mesh_for(PART) != null
			else "NOT built", "there" if got.has("%s:15" % sticker) else "MISSING"])
	await _frames(1)


func _case_unknown() -> void:
	print("\n5. a sub-model holding a part the library lacks, placed twice")
	var path: String = PROBE_DIR + "pr_unknown.mpd"
	_write(path, HELD_MODEL)
	await _open(path)
	var shown: Array = _shown()
	_ok(shown.size() == 2, "opened: %d parts shown (2 bricks; the 2 %s held)" % [shown.size(), UNKNOWN])
	if shown.is_empty():
		return
	var one: int = shown[0].id
	_builder.clear_selection()
	_builder.select_brick(one, false)
	var ids: Array = _builder.selection.keys()
	var base_path: String = ProjectSettings.globalize_path(PROBE_DIR + "unknown-before.mpd")
	_main.call("save_model", base_path)
	var before_count: int = _leaves(FileAccess.get_file_as_string(base_path)).get(UNKNOWN, 0)
	_ok(before_count == 2, "saved before any paste: the file places %s %d times" % [UNKNOWN, before_count])
	await _compare("unknown", ids, false, func(stage: String) -> void:
		var at: String = ProjectSettings.globalize_path(PROBE_DIR + "unknown-%s.mpd" % stage)
		_main.call("save_model", at)
		var count: int = _leaves(FileAccess.get_file_as_string(at)).get(UNKNOWN, 0)
		print("  NOTE  saved %s: the file places %s %d times (before: %d)" % [stage, UNKNOWN, count, before_count])
		if stage == "cross-tab paste" and count < 3:
			_ok(false, "the cross-tab paste of a copy holding %s: %d placed against the same tab's 3"
				% [UNKNOWN, count])
		elif stage == "same-tab paste":
			_ok(count == 3, "the same tab's paste carries the held part: %d placed" % count)
		elif stage.begins_with("undone"):
			_ok(count == 2, "%s: %d placed, as before" % [stage, count]))


func _case_other_model() -> void:
	print("\n6. copied in 7140-1, pasted into the car (another tab's model)")
	await _open("res://vendor/omr/files/7140-1.mpd")
	var ids: Array = _minifig_and_loose()
	var copied: Array = _records(ids)
	_select(ids)
	var count: int = _verbs.copy()
	var text: String = Carry.whole_text("", "other-model", _library)
	_ok(count == ids.size(), "copied %d parts (%d chars)" % [count, text.length()])
	await _open("res://models/car.ldr")
	# A fresh tab: nothing copied in it.
	_fresh_tab()
	var before: Array = _records_all()
	var held: int = _verbs.paste_from(text)
	_ok(held == count, "the other tab holds %d of %d" % [held, count])
	var put: Dictionary = await _put(_spots_for(before, copied))
	var pasted: Array = _records(put["ids"])
	_ok(pasted.size() == copied.size(), "put down in the car: %d of %d parts at %s" % [pasted.size(), copied.size(),
		put["spot"]])
	_ok(_part_colours(pasted) == _part_colours(copied), "part:colour as copied (%s)"
		% _diff_counts(_part_colours(copied), _part_colours(pasted)))
	if not pasted.is_empty():
		_same_place("the same layout as the copy (moved as one)", copied, pasted, _centre(pasted) - _centre(copied))
	var structure_c: Dictionary = _units(copied)
	var structure_p: Dictionary = _units(pasted)
	_ok(structure_c == structure_p, "structure: copied in %s, pasted in %s" % [structure_c, structure_p])
	var after: Array = _records_all()
	var saved_at: String = ProjectSettings.globalize_path(PROBE_DIR + "other-model.mpd")
	_main.call("save_model", saved_at)
	await _open(saved_at)
	var back: Array = _records_all()
	_reopen_check("the car with the paste", after, back)
	var p: Dictionary = _pair(before, back, _centre(back) - _centre(after))
	_ok(int(p["unpaired_a"]) == 0 and float(p["origin"]) <= 0.5 and float(p["basis"]) <= 0.01,
		"every car part still there in place and colour after reopening: %d of %d unpaired, most apart %.5f LDU"
		% [int(p["unpaired_a"]), before.size(), float(p["origin"])])


func _case_accounts() -> void:
	print("\n7. a copy is its account's: another account never reads it, and a sign-out forgets it (F2)")
	await _open("res://models/car.ldr")
	var account: Account = _main.get("_account")
	var said: Array = [""]
	var was_say: Callable = _verbs.say
	_verbs.say = func(words: String) -> void:
		said[0] = words
		was_say.call(words)
	account.user_id = "probe-account-a"
	var one: int = _shown()[0].id
	_select([one])
	_ok(_verbs.copy() == 1, "account A copied 1 part")
	var kept: String = Carry.whole_text(str(_verbs.get("_copied_by")), "accounts-1", _library)
	_ok(str(Carry.whole_account(kept)) == "probe-account-a", "the kept copy names account A: %s"
		% [Carry.whole_account(kept)])
	_ok(Carry.from_whole(kept, "probe-account-b", _library).is_empty()
		and not Carry.from_whole(kept, "probe-account-a", _library).is_empty(),
		"account B reads nothing of it, account A reads it")
	# Another tab where B is signed in: A's copy kept for the tabs pastes nothing.
	_fresh_tab()
	account.user_id = "probe-account-b"
	_ok(_verbs.paste_from(kept) == 0 and not _builder.is_carrying() and str(said[0]).begins_with("nothing copied"),
		"another tab signed in as B: A's copy not pasted (\"%s\")" % said[0])
	# The same tab: A copies, then B is signed in without a sign-out.
	account.user_id = "probe-account-a"
	_select([one])
	_verbs.copy()
	account.user_id = "probe-account-b"
	_ok(_verbs.paste() == 0 and not _builder.is_carrying() and Carry.clipboard.is_empty(),
		"the same tab, B in after A copied: nothing pasted, the clipboard forgotten (\"%s\")" % said[0])
	# A signs in, copies, signs out (Account._forget, as sign_out does): forgotten.
	account.user_id = "probe-account-a"
	_select([one])
	_verbs.copy()
	_ok(not Carry.clipboard.is_empty(), "A copied again")
	account.call("_forget", "")
	account.changed.emit()
	_ok(Carry.clipboard.is_empty() and str(_verbs.get("_copied_by")).is_empty(),
		"A signed out: the copy forgotten (%d parts kept)" % Carry.clipboard.size())
	_ok(_verbs.paste() == 0 and not _builder.is_carrying(), "a paste after the sign-out holds nothing (\"%s\")"
		% said[0])
	_verbs.say = was_say
	account.user_id = ""


func _case_cannot_have() -> void:
	print("\n8. a copy one of whose parts can't be had: nothing held, nothing put down, said (F1)")
	await _open("res://models/car.ldr")
	var said: Array = [""]
	var was_say: Callable = _verbs.say
	_verbs.say = func(words: String) -> void:
		said[0] = words
		was_say.call(words)
	var one: int = _shown()[0].id
	_select([one])
	_verbs.copy()
	var real: Dictionary = (Carry.clipboard[0] as Dictionary).duplicate()
	var lacking: Dictionary = real.duplicate()
	lacking["part"] = "zzzpastereviewnone"
	lacking["at"] = (real["at"] as Transform3D).translated(Vector3(40, 0, 0))
	Carry.clipboard = [real, lacking]
	var kept: String = Carry.whole_text("", "cannot-have", _library)
	_fresh_tab()
	var before: int = _shown().size()
	var held: int = _verbs.paste_from(kept)
	await _frames(5)
	_ok(held == 0 and not _builder.is_carrying(), "held %d, carrying %s" % [held, _builder.is_carrying()])
	_ok(str(said[0]).begins_with("could not paste: 1 part did not load"), "said: \"%s\"" % said[0])
	_builder.place()
	await _frames(3)
	_ok(_shown().size() == before, "nothing put down: %d parts, %d before" % [_shown().size(), before])
	_verbs.say = was_say


# -- the comparison ---------------------------------------------------------------


## [param ids] copied; the same tab's paste put down, recorded and undone; the
## other tab's paste put down at the same spot, recorded, compared; [param
## also] called after each put and undo with the stage; when [param reopen],
## the model saved with the other tab's paste and reopened.
func _compare(tag: String, ids: Array, reopen: bool, also: Callable = Callable()) -> void:
	if ids.is_empty():
		_ok(false, "%s: nothing to copy" % tag)
		return
	var before: Array = _records_all()
	var copied: Array = _records(ids)
	_select(ids)
	var count: int = _verbs.copy()
	var began: int = Time.get_ticks_usec()
	var text: String = Carry.as_file(Carry.clipboard, _library)
	var as_file_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	_ok(count == copied.size() and Carry.clipboard.size() == count, "%s: copied %d parts; the text %d chars, as_file %.1f ms"
		% [tag, count, text.length(), as_file_ms])
	# The same tab.
	_builder.clear_selection()
	var held: int = _verbs.paste()
	_ok(held == count, "same tab: paste() holds %d of %d" % [held, count])
	var spots: Array = _spots_for(before, copied)
	var same_put: Dictionary = await _put(spots)
	var same: Array = _records(same_put["ids"])
	_ok(same.size() == count, "same tab: put down %d of %d at %s" % [same.size(), count, same_put["spot"]])
	if also.is_valid():
		also.call("same-tab paste")
	_builder.undo()
	await _frames(3)
	_ok(_keys(_records_all(), Vector3.ZERO, 0.01) == _keys(before, Vector3.ZERO, 0.01),
		"same tab: undone, the model as before (%d parts)" % _records_all().size())
	if also.is_valid():
		also.call("undone same-tab paste")
	# The other tab: the copy as the site's tabs keep it, pasted in a tab
	# that copied nothing, as paste() pastes another tab's copy.
	began = Time.get_ticks_usec()
	var kept: String = Carry.whole_text("", "other-tab", _library)
	var whole_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	_fresh_tab()
	began = Time.get_ticks_usec()
	var parts: int = _verbs.paste_from(kept)
	var from_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	_ok(parts == count and _builder.is_carrying() and _builder.carrying.count() == count,
		"other tab: paste_from holds %d of %d parts (kept %d chars in %.1f ms, read and held in %.1f ms)"
		% [parts, count, kept.length(), whole_ms, from_ms])
	var spot_list: Array = [same_put["spot"]] if same_put["spot"] is Vector3 else spots
	var cross_put: Dictionary = await _put(spot_list)
	var cross: Array = _records(cross_put["ids"])
	_ok(cross.size() == count, "other tab: put down %d of %d at %s" % [cross.size(), count, cross_put["spot"]])
	var pc_same: Dictionary = _part_colours(same)
	var pc_cross: Dictionary = _part_colours(cross)
	_ok(pc_same == pc_cross, "part:colour, other tab against same tab (%s)" % _diff_counts(pc_same, pc_cross))
	_same_place("place, other tab against same tab at the same spot", same, cross, Vector3.ZERO)
	if not cross.is_empty() and not copied.is_empty():
		_same_place("layout, other tab's paste against the copied parts (moved as one)", copied, cross,
			_centre(cross) - _centre(copied))
		_same_place("layout, same tab's paste against the copied parts (moved as one)", copied, same,
			_centre(same) - _centre(copied))
	var st_same: Dictionary = _units(same)
	var st_cross: Dictionary = _units(cross)
	_ok(st_same == st_cross, "structure: same tab %s; other tab %s" % [st_same, st_cross])
	_ok(_unit_keys(same) == _unit_keys(cross), "each part in the same sub-assembly and group as the same tab's paste")
	if also.is_valid():
		also.call("cross-tab paste")
	var after: Array = _records_all()
	_builder.undo()
	await _frames(3)
	_ok(_keys(_records_all(), Vector3.ZERO, 0.01) == _keys(before, Vector3.ZERO, 0.01),
		"other tab: undone, the model as before (%d parts)" % _records_all().size())
	if also.is_valid():
		also.call("undone cross-tab paste")
	if not reopen:
		return
	_builder.redo()
	await _frames(3)
	_ok(_keys(_records_all(), Vector3.ZERO, 0.01) == _keys(after, Vector3.ZERO, 0.01),
		"other tab: redone, the paste back (%d parts)" % _records_all().size())
	var saved_at: String = ProjectSettings.globalize_path(PROBE_DIR + "%s-cross.mpd" % tag)
	var saved: bool = bool(_main.call("save_model", saved_at))
	_ok(saved, "saved with the other tab's paste")
	await _open(saved_at)
	_reopen_check(tag, after, _records_all())


func _reopen_check(tag: String, before: Array, back: Array) -> void:
	var offset: Vector3 = _centre(back) - _centre(before) if not back.is_empty() and not before.is_empty() \
		else Vector3.ZERO
	_ok(_part_colours(before) == _part_colours(back), "%s: reopened %d parts against %d saved; part:colour %s"
		% [tag, back.size(), before.size(), _diff_counts(_part_colours(before), _part_colours(back))])
	_same_place("%s: reopened, in place (whole model offset %s)" % [tag, offset], before, back, offset)


# -- records ------------------------------------------------------------------------


func _shown() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append(brick)
	return out


func _records_all() -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in _shown():
		ids.append(brick.id)
	return _records(ids)


func _records(ids: Array) -> Array:
	var out: Array = []
	for id: Variant in ids:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick == null:
			continue
		out.append({"part": brick.part_id, "color": brick.color_code, "at": brick.transform,
			"unit": brick.unit, "group": brick.group, "id": brick.id})
	return out


func _part_colours(records: Array) -> Dictionary:
	var out: Dictionary = {}
	for one: Dictionary in records:
		var key: String = "%s:%d" % [one["part"], int(one["color"])]
		out[key] = int(out.get(key, 0)) + 1
	return out


func _part_colours_of_items(items: Array) -> Dictionary:
	var out: Dictionary = {}
	for one: Dictionary in items:
		var key: String = "%s:%d" % [str(one["part"]), int(one["color"])]
		out[key] = int(out.get(key, 0)) + 1
	return out


static func _num(value: float, step: float) -> String:
	var snapped: float = snappedf(value, step)
	if absf(snapped) < step * 0.5:
		snapped = 0.0
	return ("%.2f" if step < 0.1 else "%.1f") % snapped


func _key(one: Dictionary, offset: Vector3, step: float) -> String:
	var at: Transform3D = one["at"]
	var b: Basis = at.basis
	var o: Vector3 = at.origin - offset
	var nums := PackedStringArray()
	for v: float in [o.x, o.y, o.z, b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z]:
		nums.append(_num(v, step))
	return "%s:%d@%s" % [one["part"], int(one["color"]), " ".join(nums)]


func _keys(records: Array, offset: Vector3, step: float) -> Array:
	var out: Array = []
	for one: Dictionary in records:
		out.append(_key(one, offset, step))
	out.sort()
	return out


## Keys with each record's place from the group's lowest corner.
func _relative_keys(records: Array, step: float) -> Array:
	if records.is_empty():
		return []
	var low := Vector3(INF, INF, INF)
	for one: Dictionary in records:
		var o: Vector3 = (one["at"] as Transform3D).origin
		low = Vector3(minf(low.x, o.x), minf(low.y, o.y), minf(low.z, o.z))
	return _keys(records, low, step)


func _centre(records: Array) -> Vector3:
	var sum := Vector3.ZERO
	for one: Dictionary in records:
		sum += (one["at"] as Transform3D).origin
	return sum / maxf(1.0, records.size())


## Each record of [param a] paired with the nearest unpaired one of [param b]
## of its part and colour, [param b] moved by -[param offset] first:
## {unpaired_a, unpaired_b, origin (most LDU apart), basis (most apart, any
## element), over (pairs more than 0.01 LDU or 0.0001 apart), worst}.
func _pair(a: Array, b: Array, offset: Vector3) -> Dictionary:
	var buckets: Dictionary = {}
	for one: Dictionary in b:
		var key: String = "%s:%d" % [one["part"], int(one["color"])]
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(one)
	var unpaired_a: int = 0
	var most_origin: float = 0.0
	var most_basis: float = 0.0
	var over: int = 0
	var worst: String = ""
	for one: Dictionary in a:
		var key: String = "%s:%d" % [one["part"], int(one["color"])]
		var bucket: Array = buckets.get(key, [])
		var at: Transform3D = one["at"]
		var best: int = -1
		var best_d: float = INF
		for n: int in bucket.size():
			var there: Transform3D = (bucket[n] as Dictionary)["at"]
			var d: float = at.origin.distance_to(there.origin - offset)
			if d < best_d:
				best_d = d
				best = n
		if best < 0:
			unpaired_a += 1
			continue
		var other: Transform3D = (bucket[best] as Dictionary)["at"]
		bucket.remove_at(best)
		var db: float = 0.0
		for row: int in 3:
			for col: int in 3:
				db = maxf(db, absf(at.basis[row][col] - other.basis[row][col]))
		if best_d > 0.01 or db > 0.0001:
			over += 1
		if best_d > most_origin or db > most_basis:
			if best_d > most_origin:
				most_origin = best_d
			if db > most_basis:
				most_basis = db
			worst = "%s at %s vs %s, basis %s vs %s" % [key, at.origin, other.origin - offset, at.basis, other.basis]
	var unpaired_b: int = 0
	for key: String in buckets:
		unpaired_b += (buckets[key] as Array).size()
	return {"unpaired_a": unpaired_a, "unpaired_b": unpaired_b, "origin": most_origin, "basis": most_basis,
		"over": over, "worst": worst}


## A check that [param b] has [param a]'s parts where [param a] has them: a
## part not paired, or one more than half an LDU or 0.01 of a turn out, fails.
func _same_place(said: String, a: Array, b: Array, offset: Vector3) -> void:
	var p: Dictionary = _pair(a, b, offset)
	var bad: bool = int(p["unpaired_a"]) > 0 or int(p["unpaired_b"]) > 0 or float(p["origin"]) > 0.5 \
		or float(p["basis"]) > 0.01
	_ok(not bad, "%s: %d against %d parts; unpaired %d/%d; most apart %.5f LDU, rotation element %.7f; %d pairs past 0.01 LDU or 0.0001"
		% [said, a.size(), b.size(), int(p["unpaired_a"]), int(p["unpaired_b"]), float(p["origin"]),
			float(p["basis"]), int(p["over"])])
	if int(p["over"]) > 0:
		print("        worst: %s" % p["worst"])


func _matches(a: Array, b: Array) -> int:
	var pool: Dictionary = {}
	for key: String in a:
		pool[key] = int(pool.get(key, 0)) + 1
	var out: int = 0
	for key: String in b:
		if int(pool.get(key, 0)) > 0:
			pool[key] = int(pool[key]) - 1
			out += 1
	return out


func _diff_counts(a: Dictionary, b: Dictionary) -> String:
	var out := PackedStringArray()
	for key: String in a:
		if int(b.get(key, 0)) != int(a[key]):
			out.append("%s %d/%d" % [key, int(b.get(key, 0)), int(a[key])])
	for key: String in b:
		if not a.has(key):
			out.append("%s %d/0" % [key, int(b[key])])
	return "same" if out.is_empty() else ", ".join(out.slice(0, 12))


## This tab as another tab is: nothing copied in it, its clipboard empty.
func _fresh_tab() -> void:
	_builder.cancel_carry()
	Carry.clipboard = []
	Carry.clipboard_lines = {}
	Carry.clipboard_frames = {}
	Carry.clipboard_held = []
	_verbs.set("_copy_stamp", "")
	_verbs.set("_copied_by", "")


## Each record's part, colour, group and sub-assembly path, sorted.
func _unit_keys(records: Array) -> Array:
	var out: Array = []
	for one: Dictionary in records:
		out.append("%s:%d|%s|%s" % [one["part"], int(one["color"]), one["group"], one["unit"]])
	out.sort()
	return out


## How many parts are in a sub-assembly and how many paths there are.
func _units(records: Array) -> Dictionary:
	var paths: Dictionary = {}
	var inside: int = 0
	for one: Dictionary in records:
		var path: String = "%s|%s" % [one["group"], one["unit"]]
		paths[path] = true
		if not str(one["unit"]).is_empty() or not str(one["group"]).is_empty():
			inside += 1
	return {"in_sub_assemblies": inside, "paths": paths.size()}


# -- choosing, selecting, putting down ------------------------------------------------


## A minifig whole (the sub-assembly select_brick takes, of 4 to 12 parts)
## and two parts in no sub-assembly.
func _minifig_and_loose() -> Array:
	var fig: Array = []
	for brick: BrickWorld.Brick in _shown():
		if str(brick.unit).is_empty():
			continue
		var members: PackedInt64Array = _builder.takes(brick.id)
		if members.size() >= 4 and members.size() <= 12:
			fig = Array(members)
			print("  (the sub-assembly: %d parts, unit %s, group %s)" % [fig.size(), brick.unit, brick.group])
			break
	var loose: Array = []
	for brick: BrickWorld.Brick in _shown():
		if str(brick.unit).is_empty() and str(brick.group).is_empty() and not fig.has(brick.id):
			loose.append(brick.id)
		if loose.size() == 2:
			break
	if loose.size() < 2:
		# None loose: two parts of another sub-assembly, selected as they are.
		for brick: BrickWorld.Brick in _shown():
			if not fig.has(brick.id) and not loose.has(brick.id):
				loose.append(brick.id)
			if loose.size() == 2:
				break
		print("  (no loose parts: two of another sub-assembly instead)")
	_ok(not fig.is_empty(), "a minifig-sized sub-assembly found (%d parts) and %d more" % [fig.size(), loose.size()])
	return fig + loose


func _select(ids: Array) -> void:
	_builder.clear_selection()
	for id: Variant in ids:
		_builder.selection[int(id)] = true
	_builder.selection_changed.emit(_builder.selection.size())


## Spots on the ground clear of [param model], with room for [param copied].
func _spots_for(model: Array, copied: Array) -> Array:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for one: Dictionary in model:
		var o: Vector3 = (one["at"] as Transform3D).origin
		low = Vector3(minf(low.x, o.x), minf(low.y, o.y), minf(low.z, o.z))
		high = Vector3(maxf(high.x, o.x), maxf(high.y, o.y), maxf(high.z, o.z))
	var c_low := Vector3(INF, INF, INF)
	var c_high := Vector3(-INF, -INF, -INF)
	for one: Dictionary in copied:
		var o: Vector3 = (one["at"] as Transform3D).origin
		c_low = Vector3(minf(c_low.x, o.x), minf(c_low.y, o.y), minf(c_low.z, o.z))
		c_high = Vector3(maxf(c_high.x, o.x), maxf(c_high.y, o.y), maxf(c_high.z, o.z))
	if model.is_empty():
		low = Vector3.ZERO
		high = Vector3.ZERO
	var half: Vector3 = (c_high - c_low) / 2.0 if not copied.is_empty() else Vector3.ZERO
	var mid: Vector3 = (low + high) / 2.0
	var out: Array = []
	for margin: float in [200.0, 400.0, 800.0]:
		for spot: Vector3 in [Vector3(high.x + half.x + margin, 0, mid.z), Vector3(low.x - half.x - margin, 0, mid.z),
				Vector3(mid.x, 0, high.z + half.z + margin), Vector3(mid.x, 0, low.z - half.z - margin)]:
			out.append(Vector3(snappedf(spot.x, 20.0), 0.0, snappedf(spot.z, 20.0)))
	return out


## What is in hand put down at the first of [param spots] that takes it:
## {spot, ids}.
func _put(spots: Array) -> Dictionary:
	var had: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		had[brick.id] = true
	for spot: Vector3 in spots:
		for _n: int in 6:
			_builder.update_preview(spot + Vector3(0, 4000, 0), Vector3.DOWN)
			await process_frame
		var put: int = _builder.place()
		if put != 0:
			await _frames(3)
			var ids: Array = []
			for brick: BrickWorld.Brick in _world.bricks():
				if not had.has(brick.id):
					ids.append(brick.id)
			return {"spot": spot, "ids": ids}
	_builder.cancel_carry()
	return {"spot": null, "ids": []}


func _place_at(at: Vector3) -> int:
	for dx: int in [0, 40, 80, -40, 120, 160]:
		for dz: int in [0, 60, -60, 120]:
			var spot: Vector3 = at + Vector3(dx, 0, dz)
			for _n: int in 6:
				_builder.update_preview(spot + Vector3(0, 600, 0), Vector3.DOWN)
				await process_frame
			var id: int = _builder.place()
			if id != 0:
				await _frames(3)
				return id
	return 0


func _open(path: String) -> void:
	_builder.cancel_carry()
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(3)
	var began: int = Time.get_ticks_msec()
	_main.call("_open", ProjectSettings.globalize_path(path))
	var stable: int = 0
	var last: int = -1
	for _n: int in 20000:
		await process_frame
		var count: int = _world.brick_count()
		if _store.awaited.is_empty() and not _store.laying and count > 0:
			stable = stable + 1 if count == last else 0
			if stable >= 10:
				break
		last = count
		if Time.get_ticks_msec() - began > 600000:
			print("  --    still opening %s after 600 s" % path)
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
		await _frames(3)
	_builder.forget_history()
	_verbs.set_mode("select")
	_builder.clear_selection()
	print("  (opened %s: %d parts shown, %d ms)" % [path.get_file(), _shown().size(), Time.get_ticks_msec() - began])


# -- a file's parts, resolved by its FILE sections -------------------------------------


## Each leaf a file places (not one of its own FILE sections), lower case
## without ".dat" -> how many times, through every sub-model it places.
func _leaves(text: String) -> Dictionary:
	var sections: Dictionary = {}
	var order: Array = []
	var current: String = ""
	for raw: String in text.replace("\r", "").split("\n"):
		var line: String = raw.strip_edges()
		var words: PackedStringArray = line.split(" ", false)
		if words.size() >= 3 and words[0] == "0" and words[1].to_upper() == "FILE":
			current = " ".join(words.slice(2)).to_lower()
			sections[current] = []
			order.append(current)
			continue
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "NOFILE":
			continue
		if words.size() >= 15 and words[0] == "1":
			if current.is_empty():
				current = "(main)"
				sections[current] = []
				order.append(current)
			(sections[current] as Array).append(" ".join(words.slice(14)).to_lower())
	var out: Dictionary = {}
	if order.is_empty():
		return out
	_count_into(out, sections, order[0], 1, 0)
	return out


func _count_into(out: Dictionary, sections: Dictionary, name: String, times: int, depth: int) -> void:
	if depth > 30:
		return
	for ref: String in sections.get(name, []):
		if sections.has(ref):
			_count_into(out, sections, ref, times, depth + 1)
		else:
			var leaf: String = ref.trim_suffix(".dat")
			out[leaf] = int(out.get(leaf, 0)) + times


# -- the rest ---------------------------------------------------------------------------


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _finish() -> void:
	_forget(PROBE_DIR)
	print("\npastereview_probe: %d failed, %d notes" % [_failures, _notes])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _note(said: String) -> void:
	print("  NOTE  %s" % said)
	_notes += 1


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir + name + "/")
	DirAccess.remove_absolute(dir)
