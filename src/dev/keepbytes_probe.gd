## keepbytes: a person's file never changes from an ordinary save or undo,
## read byte for byte (FileAccess.get_file_as_string drops a leading BOM, so
## s6review's sweep took h_bom_crlf's kept BOM for one put in). Each file
## opened and saved; (A) nothing to lose right after, what Save would write
## the bytes it wrote; (B) a part deleted and undone, the same bytes and
## nothing to lose, redone, work not saved; (C) reopened and saved, the same
## bytes. sculpt170-042 and pagoda are app files whose steps the build order
## works out: it went by the order the file listed their parts, which was
## the order of its own last plan, so each save planned them again from the
## last (sculpt170-042's potato body came back built in the model's steps,
## pagoda's pond in other steps) until the third. Then (D) a BOM file
## deleted from the saved models and put back by Undo, and renamed and
## renamed back, byte for byte: both read it as text and lost the mark.
## (F) kbkeep: the app's own models a save plans (Author: Brickworks, no
## steps of an author's) opened and saved with no edit are their files byte
## for byte, twice, and nothing said: m267's model an older build planned
## (rel-m315 held on it coming back in a new order), the pagoda with no
## STEP lines, and swapfind's car. Saved as another name unedited, its
## parts in its file's order. A part deleted and saved, its steps worked out
## again and said once where the order moved; saved again, the same bytes
## and nothing said.
## (A0) a file that began with a BOM saves with it (mkreview's bk_bom_open,
## with no last line end). A redo that leaves the model empty (the part
## deleted was of a sub-model that is the whole model, and took the copy)
## is counted "emptied", not B2: an empty model is nothing to lose. (E) a
## set from the library that begins with a BOM keeps it through a save.
##
##   godot --headless --path . --script src/dev/keepbytes_probe.gd
##
## KB_ALL=1 sweeps every fixture under src/dev/fixtures instead, and the
## files KB_FILES names (spaces between; alone, those only); KB_SAVE=DIR
## writes each file's first and second save there, named the same in any
## snapshot, to diff two builds.
extends SceneTree

const NAME := "Keepbytes Probe"
const FILES: Array = [
	"res://src/dev/fixtures/bench/sculpt170-042.ldr",
	"res://src/dev/fixtures/house/pagoda.ldr",
	"res://src/dev/fixtures/mlattack/h_bom_crlf.ldr",
	"res://src/dev/fixtures/keepbytes/bk_bom_open.mpd",
]
const BOM_FILE := "res://src/dev/fixtures/mlattack/h_bom_crlf.ldr"
var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _bar: ModelBar
var _verbs: EditVerbs
var _save: String = OS.get_environment("KB_SAVE")
var _counts: Dictionary = {"files": 0, "A": 0, "A0": 0, "B": 0, "B2": 0, "emptied": 0, "C": 0, "D": 0,
	"E": 0, "F": 0, "skipped": 0}


func _initialize() -> void:
	_run()


func _fixtures(dir: String, into: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_fixtures(dir.path_join(sub), into)
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension().to_lower() in ["ldr", "mpd"]:
			into.append(dir.path_join(file))


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_bar = _main.get("_bar")
	_verbs = _main.get("_verbs")
	_store.keeps = true
	var files := PackedStringArray(FILES)
	var named: PackedStringArray = OS.get_environment("KB_FILES").split(" ", false)
	var sweep: bool = OS.get_environment("KB_ALL") == "1" or not named.is_empty()
	if sweep:
		files = PackedStringArray()
		if OS.get_environment("KB_ALL") == "1":
			_fixtures("res://src/dev/fixtures", files)
			files.sort()
		files.append_array(named)
	if not _save.is_empty():
		DirAccess.make_dir_recursive_absolute(_save)
	for path: String in files:
		await _one(path)
	if not sweep:
		await _bom_kept()
		await _library_bom()
		await _planned_kept()
	for name: String in [NAME, NAME + " 2"]:
		if FileAccess.file_exists(ModelStore.saved_path(name)):
			DirAccess.remove_absolute(ModelStore.saved_path(name))
	print("\nRESULT %s" % JSON.stringify(_counts))
	print("keepbytes probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures else 0)


func _one(path: String) -> void:
	var began: int = Time.get_ticks_msec()
	if _store.open(path) <= 0:
		_counts["skipped"] += 1
		print("  skip %s: did not open" % path)
		return
	_bar.opened.emit(_parts())
	await _settle()
	if _parts() < 2:
		_counts["skipped"] += 1
		print("  skip %s: fewer than two parts" % path)
		return
	var opened: int = Time.get_ticks_msec() - began
	_counts["files"] += 1
	began = Time.get_ticks_msec()
	if not await _save_now():
		_fail(path, "save refused")
		return
	var saved: int = Time.get_ticks_msec() - began
	var file: PackedByteArray = _bytes()
	_keep(path, "first", file)
	var ok: bool = true
	# (A0) A file that began with a BOM saves with it (mkreview's
	# bk_bom_open: a BOM and no last line end).
	var mark := PackedByteArray([0xEF, 0xBB, 0xBF])
	if FileAccess.get_file_as_bytes(path).slice(0, 3) == mark and file.slice(0, 3) != mark:
		_counts["A0"] += 1
		ok = _fail(path, "A0 began with a BOM, saved without it")
	if _store.has_unsaved_work() or _store.saved_text().to_utf8_buffer() != file:
		_counts["A"] += 1
		ok = _fail(path, "A right after Save: unsaved %s, what Save writes is the file %s; differ: %s" % [
			_store.has_unsaved_work(), _store.saved_text().to_utf8_buffer() == file,
			_diff(file, _store.saved_text().to_utf8_buffer())])
	var first: BrickWorld.Brick = _first_part()
	var had: int = _parts()
	_builder.select_brick(first.id, false)
	await _verbs.press("delete")
	await _settle()
	var gone: int = had - _parts()
	await _verbs.press("undo")
	await _settle()
	var back: PackedByteArray = _store.saved_text().to_utf8_buffer()
	if back != file or _store.has_unsaved_work():
		_counts["B"] += 1
		ok = _fail(path, "B after delete and undo: bytes same %s, unsaved %s; differ: %s" % [back == file,
			_store.has_unsaved_work(), _diff(file, back)])
	await _verbs.press("redo")
	await _settle()
	# A part of a sub-model that is the whole model takes the whole copy
	# with it, and an empty model is nothing to lose (has_unsaved_work: an
	# empty baseplate), the saved file holding it all still.
	if _parts() == 0:
		_counts["emptied"] += 1
	elif not _store.has_unsaved_work():
		_counts["B2"] += 1
		ok = _fail(path, "B2 redone, %d of %d parts gone (%d by the delete; first %s %s in “%s”), yet nothing to lose"
			% [had - _parts(), had, gone, first.part_id, first.id, Assemblies.path_of(first)])
	await _verbs.press("undo")
	await _settle()
	began = Time.get_ticks_msec()
	await _bar.open_with_progress(ModelStore.saved_path(NAME))
	_bar.opened.emit(_parts())
	await _settle()
	var reopened: int = Time.get_ticks_msec() - began
	await _save_now()
	var again: PackedByteArray = _bytes()
	_keep(path, "second", again)
	if again != file:
		_counts["C"] += 1
		ok = _fail(path, "C reopened and saved, bytes differ: %s" % _diff(file, again))
	if ok:
		print("  ok   %s (%d parts; open %d ms, save %d ms, reopen %d ms)" % [path, _parts(), opened, saved,
			reopened])


## (D) The BOM file saved, deleted from the saved models and put back, then
## renamed and renamed back: its bytes each time.
func _bom_kept() -> void:
	if _store.open(BOM_FILE) <= 0:
		_fail(BOM_FILE, "D did not open")
		return
	_bar.opened.emit(_parts())
	await _settle()
	await _save_now()
	var was: PackedByteArray = _bytes()
	if was.slice(0, 3) != PackedByteArray([0xEF, 0xBB, 0xBF]):
		_counts["D"] += 1
		_fail(BOM_FILE, "D its save has no BOM")
		return
	var kept: String = _store.delete_saved(NAME)
	var name: String = _store.put_back(kept) if not kept.is_empty() else ""
	var put: PackedByteArray = FileAccess.get_file_as_bytes(ModelStore.saved_path(NAME))
	if name != NAME or put != was:
		_counts["D"] += 1
		_fail(BOM_FILE, "D deleted and put back as “%s”: bytes same %s; differ: %s" % [name, put == was,
			_diff(was, put)])
	var renamed: String = _store.rename_saved(NAME, NAME + " 2")
	var other: PackedByteArray = FileAccess.get_file_as_bytes(ModelStore.saved_path(NAME + " 2"))
	var back: String = _store.rename_saved(NAME + " 2", NAME) if renamed.is_empty() else renamed
	var home: PackedByteArray = FileAccess.get_file_as_bytes(ModelStore.saved_path(NAME))
	if not renamed.is_empty() or not back.is_empty() or other.slice(0, 3) != was.slice(0, 3) or home != was:
		_counts["D"] += 1
		_fail(BOM_FILE, "D renamed (%s) and back (%s): BOM kept %s, bytes back %s; differ: %s" % [
			renamed, back, other.slice(0, 3) == was.slice(0, 3), home == was, _diff(was, home)])
	else:
		print("  ok   %s: deleted and put back, renamed and back, byte for byte" % BOM_FILE)


## (E) A set from the library that begins with a BOM (4558-1, as the
## library's fetch gives it) opens with it and saves with it: read as text
## it lost the mark, and the save wrote the file a mark shorter.
func _library_bom() -> void:
	var library: ModelLibrary = _main.get("_model_library")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://vendor/omr/files/4558-1.mpd")
	var got: Dictionary = library._text_of({"file": "4558-1.mpd"}, {"code": 200, "bytes": bytes})
	var text: String = str(got["text"])
	if not text.begins_with(LdrModel.bom()) or text.length() < 2:
		_counts["E"] += 1
		_fail("4558-1.mpd", "E the library's text has no BOM")
		return
	var opened: Dictionary = await _bar.open_text_with_progress(text, "4558-1")
	_bar.opened.emit(int(opened.get("placed", 0)))
	await _settle()
	await _save_now()
	var saved: PackedByteArray = _bytes()
	if saved.slice(0, 3) != PackedByteArray([0xEF, 0xBB, 0xBF]):
		_counts["E"] += 1
		_fail("4558-1.mpd", "E opened from the library and saved, the BOM gone")
	else:
		print("  ok   4558-1.mpd from the library: opened and saved with its BOM")


## (F) The app's own models whose steps a save works out, kept as their
## files until edited.
func _planned_kept() -> void:
	var pagoda: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string("res://src/dev/fixtures/house/pagoda.ldr").split("\n"):
		if line.strip_edges() != "0 STEP":
			pagoda.append(line)
	for each: Array in [
			["m267_own_worked", FileAccess.get_file_as_string("res://src/dev/fixtures/mlattack/m267_own_worked.mpd"), true],
			["pagoda with no steps", "\n".join(pagoda), false],
			["swapfind's car", FileAccess.get_file_as_string("res://src/dev/fixtures/swapfind_car.mpd"), false]]:
		await _planned_one(each[0], each[1], each[2])


func _planned_one(what: String, text: String, moves: bool) -> void:
	var said: String = ModelStore.title_in(text, "")
	var opened: Dictionary = await _bar.open_text_with_progress(text, said if not said.is_empty() else "model")
	_bar.opened.emit(int(opened.get("placed", 0)))
	await _settle()
	var title: String = _store.title
	var ok: bool = true
	if not _store.call("_keeps_order"):
		_counts["F"] += 1
		_fail(what, "F not a model whose steps a save works out")
		return
	for n: int in 2:
		_store.save_as(title)
		var got: String = FileAccess.get_file_as_string(ModelStore.saved_path(title))
		if got != text or not _store.order_words.is_empty():
			_counts["F"] += 1
			ok = _fail(what, "F unedited save %d: byte for byte %s, said “%s”; differ: %s" % [n + 1, got == text,
				_store.order_words, _diff(text.to_utf8_buffer(), got.to_utf8_buffer())])
		var again: Dictionary = await _bar.open_text_with_progress(got, title)
		_bar.opened.emit(int(again.get("placed", 0)))
		await _settle()
	_store.save_as(NAME)
	var other: String = FileAccess.get_file_as_string(ModelStore.saved_path(NAME))
	if ModelStore.order_moved(text, other) or not _store.order_words.is_empty():
		_counts["F"] += 1
		ok = _fail(what, "F saved as another name unedited: its parts moved %s, said “%s”" % [
			ModelStore.order_moved(text, other), _store.order_words])
	_store.save_as(title)
	_builder.select_brick(_first_part().id, false)
	await _verbs.press("delete")
	await _settle()
	_store.save_as(title)
	var edited: String = FileAccess.get_file_as_string(ModelStore.saved_path(title))
	var moved: bool = ModelStore.order_moved(text, edited)
	if moved != (_store.order_words == ModelStore.ORDER_WORDS) or moves and not moved:
		_counts["F"] += 1
		ok = _fail(what, "F a part deleted and saved: order moved %s (expected %s), said “%s”" % [moved,
			moves, _store.order_words])
	_store.save_as(title)
	var next: String = FileAccess.get_file_as_string(ModelStore.saved_path(title))
	if next != edited or not _store.order_words.is_empty():
		_counts["F"] += 1
		ok = _fail(what, "F saved again: byte for byte %s, said “%s”" % [next == edited, _store.order_words])
	if FileAccess.file_exists(ModelStore.saved_path(title)):
		DirAccess.remove_absolute(ModelStore.saved_path(title))
	if ok:
		print("  ok   %s: unedited saves byte for byte twice, nothing said; another name keeps its order; a part deleted, steps worked out again%s; saved again, the same"
			% [what, ", said once" if moved else ""])


## Save as the bar's Save does (ModelBar._on_save): a model it says it is
## writing has its order worked out a slice at a time (save_as_paced).
func _save_now() -> bool:
	if not _store.says_writing():
		return _store.save_as(NAME)
	var job: Working.Job = Working.begin("Saving", 0, true)
	var saved: bool = await _store.save_as_paced(NAME, job)
	job.end()
	return saved


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(ModelStore.saved_path(NAME))


func _keep(path: String, what: String, bytes: PackedByteArray) -> void:
	if _save.is_empty():
		return
	var name: String = path.trim_prefix("res://").replace("/", "_") + "." + what
	var file := FileAccess.open(_save.path_join(name), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## The lines one side has that the other has not, and where the bytes first
## differ when no line does (a line end, a BOM, the order).
func _diff(a: PackedByteArray, b: PackedByteArray) -> String:
	var la: PackedStringArray = a.get_string_from_utf8().split("\n")
	var lb: PackedStringArray = b.get_string_from_utf8().split("\n")
	var out := PackedStringArray()
	for line: String in la:
		if not lb.has(line):
			out.append("-" + line.left(70))
	for line: String in lb:
		if not la.has(line):
			out.append("+" + line.left(70))
	if out.is_empty():
		var at: int = 0
		while at < mini(a.size(), b.size()) and a[at] == b[at]:
			at += 1
		return "no line differs; %d and %d bytes, first apart at byte %d" % [a.size(), b.size(), at]
	return " | ".join(out.slice(0, 6)) + (" (+%d)" % (out.size() - 6) if out.size() > 6 else "")


func _fail(path: String, what: String) -> bool:
	_failures += 1
	print("  FAIL %s: %s" % [path, what])
	return false


func _first_part() -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			return brick
	return null


func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


func _settle() -> void:
	for _n: int in 40:
		if not _store.laying and _store.awaited.is_empty():
			break
		await process_frame
	for _n: int in 6:
		await process_frame
