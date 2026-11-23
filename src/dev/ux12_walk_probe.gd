## Ten people's first use of the app, pictured step by step. Units ux12
## (bench/results/ux12-2026-11-23/WALK.md): a first-time visitor who wants a
## car, a LEGO® fan rebuilding a set from its number (6080-1), a Technic
## builder wiring a motor, a parent printing instructions, and someone
## remixing a model (p1 to p5). And ux13 (bench/results/ux13-2026-11-23/
## WALK.md): someone opening a Studio .io a friend sent, a builder making a
## sub-assembly and using it again, a MOC designer checking stability and
## fixing what floats, someone making instructions and their PDF, and a
## teenager on a phone making a minifigure and sharing it (p6 to p10).
## Research, not in the suite: its "UX12 check" and "UX13 check" lines judge
## the fixes, and it exits 0 once every step is pictured, 1 when the app
## never came up.
##
##   godot --path . --resolution 1280x800 --script src/dev/ux12_walk_probe.gd -- [--phone] [--pictures=DIR] [--only=p6,p7] [--studio-file=PATH]
##
## --phone lays the app out for a phone at a browser's scale, by fingers, as
## phonepanels_probe holds it (run it in a 390x844 window). Each step prints
## one line: what share of the model's room is covered and by what
## (Main.model_cover), the status bar's words, the windows and sheets open,
## and on a phone every control in sight under a fingertip (Phone.TARGET).
## Pictures in --pictures=DIR (else user://ux12_walk), named by step.
extends SceneTree

const SET := "omr-6080-1"

var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _shell: Shell
var _store: ModelStore
var _bin: PartsBin
var _bar: ModelBar
var _phone: Node
var _on_phone: bool = false
var _out: String = "user://ux12_walk"
var _only: PackedStringArray = []
## The Studio file the friend sent (p6): a fixture unless one is given.
var _studio_file: String = "res://tests/fixtures/studio/decor_2025.io"
var _steps: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()
	# Never left running: a step that hangs is cut off and the run says so.
	create_timer(1500.0).timeout.connect(func() -> void:
		print("UX12 cut off after 1500 s at step %d" % _steps)
		quit(2))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ux12_walk_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pictures="):
			_out = arg.trim_prefix("--pictures=")
		elif arg == "--phone":
			_on_phone = true
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--studio-file="):
			_studio_file = arg.trim_prefix("--studio-file=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if _on_phone:
		Phone._on = 1
		Phone._wide = false
		Input.emulate_touch_from_mouse = true
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	if not bool(_main.get("_built")):
		print("ux12_walk_probe: the app never came up")
		quit(1)
		return
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_phone = _main.get("_phone")
	if _on_phone:
		if _phone != null:
			_phone.set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
		await _frames(20)
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_bin = _main.get("_bin")
	_bar = _main.get("_bar")
	_store.keeps = false
	var size: Vector2i = DisplayServer.window_get_size()
	print("UX12 walk in a %d x %d window%s" % [size.x, size.y, ", laid out for a phone"
		if _on_phone else ""])
	await _frames(60)
	if _runs("p1"):
		await _visitor()
	if _runs("p2"):
		await _fan()
	if _runs("p3"):
		await _technic()
	if _runs("p4"):
		await _parent()
	if _runs("p5"):
		await _remixer()
	if _runs("p6"):
		await _studio_friend()
	if _runs("p7"):
		await _sub_assembly()
	if _runs("p8"):
		await _stability()
	if _runs("p9"):
		await _booklet_pdf()
	if _runs("p10"):
		await _figure_on_a_phone()
	await _checks()
	print("UX12 done: %d steps pictured, %d check(s) failed" % [_steps, _failures])
	quit(0)


## The fixes judged in the app as it runs, one "UX12 check" line each: run
## on the code before them, these are the frictions; after, the fixes.
func _checks() -> void:
	print("\nUX12 checks")
	if _on_phone and _phone != null:
		var buttons: Dictionary = _phone.get("_tool_buttons")
		var bare: Array = []
		for tool: Array in PhoneShell.TOOLS:
			var button: Button = buttons.get(str(tool[0]))
			if button != null and button.text.is_empty():
				bare.append(str(tool[1]))
		_check("the phone row says its words (bare: %s)" % ", ".join(bare), bare.is_empty())
	var maker: Shell.Command = _shell.command("part_maker")
	_check("Make's row names the part maker as the bin does (%s)" % maker.words,
		maker.words == "Make a part…")
	var flex: Shell.Command = _shell.command("flex")
	_check("the flex tool is named for a cable (%s)" % flex.words, flex.words.begins_with("Cable"))
	_check("Instructions under File, Export", (Shell.SUBMENUS["export"] as Array).has("instructions"))
	var clear: ConfirmationDialog = _bar.get("_confirm")
	_check("Clear it is red (%s)" % clear.get_ok_button().theme_type_variation,
		clear.get_ok_button().theme_type_variation == &"DangerButton")
	var dialog: Node = _shell.get("library_dialog")
	dialog.call("open", "sets")
	await _frames(20)
	var search: LineEdit = dialog.get("_search")
	var shown: String = search.placeholder_text
	var font: Font = search.get_theme_font("font")
	var room: float = search.size.x - search.get_theme_stylebox("normal").get_minimum_size().x \
		- (search.right_icon.get_width() if search.right_icon != null else 0)
	var needs: float = font.get_string_size(search.tr(shown), HORIZONTAL_ALIGNMENT_LEFT, -1,
		search.get_theme_font_size("font_size")).x
	_check("Library's search says it takes a set's number, whole (%s: %.0f of %.0f)" % [shown,
		needs, room], shown.begins_with("Set number") and needs <= room)
	await _close_all()
	_bar.call("_on_open")
	await _frames(10)
	var saves: PopupMenu = _bar.get("_saves")
	var first: String = saves.get_item_text(0) if saves.item_count > 0 else ""
	_check("Open's first row: %s" % first, first.begins_with("From a file ("))
	saves.hide()
	await _frames(5)
	await _checks13()


## ux13's fixes of ux12's four left, judged in the app as it runs (WALK.md).
func _checks13() -> void:
	print("\nUX13 checks")
	await _close_all()
	# 1. "motor" is a motor first, not a jackhammer its inventories call one.
	await _search_bin("motor", "", "")
	var first: PackedStringArray = _bin.first_found(3)
	var library: PartLibrary = _main.get("_library")
	var names: Array = []
	for id: String in first:
		var info: PartLibrary.PartInfo = library.parts.get(id)
		names.append("%s %s" % [id, info.name if info != null else "?"])
	var head: String = ""
	if not first.is_empty() and library.parts.has(first[0]):
		head = (library.parts[first[0]] as PartLibrary.PartInfo).name.to_lower().get_slice(" with ", 0)
	_check13("the bin's motor is a motor first (%s)" % "; ".join(names),
		not first.has("30228") and head.contains("motor"))
	await _search_bin("", "", "")
	# 2. An official set opens as it is; a person's own file with the same
	# renumbered parts is offered them, once.
	await _close_all()
	_main.set("_from_library", SET)
	_main.call("_maybe_open_library")
	await _answer_dont_save()
	await _until_still(240)
	var offer: MovedOffer = _shell.get("moved_offer")
	var renumbered: int = MovedParts.renumbered_count(_store.moved)
	_check13("an official set opens as it is: %d renumbered, no strip" % renumbered,
		not offer.visible)
	var own: String = "user://ux13_own_6080.ldr"
	var text: String = _store.saved_text()
	var file: FileAccess = FileAccess.open(own, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var seen: Array = []
	for _again: int in 2:
		var placed: int = await _bar.open_with_progress(own)
		if placed >= 0:
			_bar.opened.emit(placed)
			_bar.offer_moved(true, own)
		await _frames(10)
		seen.append(offer.visible)
		if offer.visible:
			await _step("ux13_moved_own", "a person's own file with renumbered parts: the strip")
		offer.dismiss()
	_check13("a person's own file is offered them once (%s)" % str(seen),
		renumbered == 0 or seen == [true, false])
	# 3. The strip of controls: one row, and gone once each is learned.
	var hint: ControlsHint = _main.get("_hint")
	if hint != null and not _on_phone:
		var rows: Dictionary = {}
		var shown: Array = []
		for pill: Node in hint.get_children():
			if (pill as Control).visible:
				rows[roundi((pill as Control).position.y)] = true
				var words: Label = (pill as Control).find_children("*", "Label", true, false).back()
				shown.append(words.text)
		await _step("ux13_strip", "the strip of controls along the model's foot")
		_check13("the strip is one row (%s)" % ", ".join(shown), rows.size() == 1)
		for key: String in ControlsHint.ON_THE_STRIP:
			for _n: int in ControlsHint.LEARNED_AFTER:
				hint.learn(key)
		await _frames(10)
		var area: Control = hint.get_parent()
		await _step("ux13_strip_learned", "every control on the strip used three times")
		_check13("learned, the strip and its room go (%d pills, room %.0f)" % [
			hint.get_child_count(), area.custom_minimum_size.y],
			hint.is_empty() and area.custom_minimum_size.y == 0.0)
		_shell.call("set_key_strip", true, true)
		await _frames(10)
		_check13("View, Panels, Key strip brings it back whole (%d pills)" % hint.get_child_count(),
			hint.get_child_count() == ControlsHint.ON_THE_STRIP.size() + 1)
	# The bin's word on a sub-assembly, read on the largest model at the first
	# keystroke after an edit: inside a frame (self_attack, Time).
	await _open_model("res://models/orthanc.ldr", "Orthanc")
	_bin.set("_assembly_names_at", -1)
	var began: int = Time.get_ticks_usec()
	_bin.call("_own_assembly_named", "tower")
	var took: float = (Time.get_ticks_usec() - began) / 1000.0
	_check13("the bin reads Orthanc's %d parts for its sub-assemblies in %.1f ms" % [
		_world.bricks().size(), took], took < 16.0)
	# 4. Every window and panel closes with Close.
	for panel: Array in [["library", "library_dialog", ""], ["collection", "collection", ""],
			["parts_list", "", "_inventory"], ["keys", "", "_controls"],
			["account", "", "_account_panel"], ["share", "", "_share_panel"]]:
		await _close_all()
		if panel[0] == "library":
			(_shell.get("library_dialog") as Node).call("open", "sets")
		elif _shell.can(panel[0]):
			_shell.run(panel[0])
		await _frames(30)
		var node: Variant = _shell.get(panel[1]) if not str(panel[1]).is_empty() \
			else _main.get(panel[2])
		var closers: Array = _closers(node) if node is Node else []
		_check13("%s closes with Close (%s)" % [panel[0], ", ".join(closers)],
			closers.has("Close") and not closers.has("Done") and not closers.has("OK"))
	await _close_all()


func _check13(what: String, ok: bool) -> void:
	print("UX13 check %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## The words of the buttons under [param node] that close something.
func _closers(node: Node) -> Array:
	var out: Array = []
	for button: Node in node.find_children("*", "Button", true, false):
		var words: String = (button as Button).text
		if words in ["Done", "Close", "OK", "×", "Got it"] and not words in out:
			out.append(words)
	return out


func _check(what: String, ok: bool) -> void:
	print("UX12 check %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _runs(section: String) -> bool:
	return _only.is_empty() or _only.has(section)


# -- 1. a first-time visitor who wants a car --------------------------------------


func _visitor() -> void:
	print("\nUX12 p1: a first-time visitor who wants a car")
	await _step("p1_01_first_open", "the app as it first opens")
	await _menu("Help", "p1_02_help_menu", "where to start: the Help menu")
	await _run_command("tour", "p1_03_tour", "Help, Take the tour", 90)
	await _close_all()
	await _run_command("panel_assistant", "p1_04_assistant", "the assistant, asked for a car", 60)
	await _close_all()
	await _run_command("panel_assistant", "", "", 10)
	await _run_command("new", "p1_05_new", "File, New: an empty baseplate", 60)
	await _search_bin("car", "p1_06_bin_car", "the parts bin's search: car")
	await _search_bin("wheel", "p1_07_bin_wheel", "the parts bin's search: wheel")
	await _library("car", "sets", "p1_08_library_car", "File, Library: car")
	await _close_all()


# -- 2. a LEGO fan rebuilding a set from its number -------------------------------


func _fan() -> void:
	print("\nUX12 p2: a LEGO fan rebuilding %s from its number" % SET)
	await _search_bin("6080", "p2_01_bin_6080", "the set's number in the parts bin's search")
	await _library("6080", "sets", "p2_02_library_6080", "File, Library: 6080")
	await _close_all()
	# As a new window opens it (?library=): not awaited, so a question over
	# work not saved is answered Don't save here rather than waited on.
	_main.set("_from_library", SET)
	_main.call("_maybe_open_library")
	for _n: int in 120:
		await process_frame
		var asking: Variant = _bar.get("_confirm_open")
		if asking is Window and (asking as Window).visible:
			print("UX12 p2: asked to save what was there first; answered Don't save")
			(asking as Window).hide()
			_bar.emit_signal("_replace_answered", "discard")
			break
	await _until_still(240)
	await _step("p2_03_set_open", "the set opened, as Library's Open opens it")
	await _run_command("instructions", "p2_04_instructions", "File, Instructions", 120)
	await _close_all()
	await _run_command("step_next", "p2_05_step_next", "the next step", 30)
	await _run_command("parts_list", "p2_06_parts_list", "View, Parts list", 60)
	await _close_all()
	await _run_command("collection_need", "p2_07_need", "What do I need?", 60)
	await _close_all()


# -- 3. a Technic builder wiring a motor --------------------------------------------


func _technic() -> void:
	print("\nUX12 p3: a Technic builder wiring a motor")
	_main.call("clear_model")
	await _frames(30)
	await _search_bin("motor", "p3_01_bin_motor", "the parts bin's search: motor")
	await _take_first_tile("p3_02_motor_in_hand", "the first motor tile pressed")
	await _put_down(Vector3(-40, 0, 0), "p3_03_motor_down", "the motor put on the baseplate")
	await _search_bin("battery box", "p3_04_bin_battery", "the parts bin's search: battery box")
	await _take_first_tile("", "")
	await _put_down(Vector3(80, 0, 0), "p3_05_battery_down", "the battery box put down")
	await _search_bin("cable", "p3_06_bin_cable", "the parts bin's search: cable")
	await _search_bin("wire", "p3_07_bin_wire", "the parts bin's search: wire")
	await _run_command("flex", "p3_08_flex", "Make, Cable, hose or chain", 60)
	await _close_all()
	await _run_command("simulate", "p3_09_simulate", "Tools, Simulate mechanism", 90)
	await _close_all()


# -- 4. a parent printing instructions ----------------------------------------------


func _parent() -> void:
	print("\nUX12 p4: a parent printing instructions")
	await _open_model("res://models/car.ldr", "Car")
	await _step("p4_01_car", "the car open")
	await _menu("File", "p4_02_file_menu", "where printing would be: File")
	await _run_command("instructions", "p4_03_instructions", "File, Instructions", 150)
	await _step("p4_04_instructions_later", "the instructions a moment later")
	await _run_command("booklet_page_setup", "p4_05_page_setup", "Page setup", 60)
	await _close_all()
	await _close_all()


# -- 5. remixing a model from the gallery ----------------------------------------------


func _remixer() -> void:
	print("\nUX12 p5: remixing a model from the gallery")
	await _library("", "community", "p5_01_library_community", "File, Library, Community")
	await _close_all()
	await _open_model("res://models/house.ldr", "House")
	_store.remixed_from = "abcdefgh"
	await _step("p5_02_copy_open", "a copy of someone's model open")
	await _run_command("panel_properties", "p5_03_properties", "Properties: whose it was", 40)
	await _run_command("save", "p5_04_saved", "File, Save", 60)
	await _close_all()
	await _run_command("share", "p5_05_share", "File, Share", 60)
	await _close_all()


# -- 6. a Studio file a friend sent ---------------------------------------------------


func _studio_friend() -> void:
	print("\nUX12 p6: a Studio file a friend sent (%s)" % _studio_file.get_file())
	await _open_menu("p6_01_open_menu", "File, Open")
	_bar.call("_import")
	await _frames(20)
	await _step("p6_02_picker", "From a file: the file dialog")
	var picker: Variant = _bar.get("_picker")
	var dialog: Variant = picker.get("_dialog") if picker is Node else null
	if dialog is FileDialog:
		(dialog as FileDialog).hide()
		(dialog as FileDialog).file_selected.emit(ProjectSettings.globalize_path(_studio_file))
	else:
		print("UX12 p6: no file dialog to choose in")
	await _answer_dont_save()
	await _until_still(240)
	var store_moved: Dictionary = _store.moved
	print("UX12 p6 opened: %d parts, %d renumbered, %d not shown" % [_world.bricks().size(),
		MovedParts.renumbered_count(store_moved), _store.unshown.size()])
	await _step("p6_03_opened", "the friend's model open")
	var offer: MovedOffer = _shell.get("moved_offer")
	_check13("a friend's Studio file opens with no LDraw renumbering strip (%d renumbered)" % (
		MovedParts.renumbered_count(store_moved)), not offer.visible)
	await _run_command("parts_list", "p6_04_parts_list", "View, Parts list", 60)
	var marked: Array = []
	var inventory: Variant = _main.get("_inventory")
	if inventory is Node:
		for label: Node in (inventory as Node).find_children("*", "Label", true, false):
			var said: String = (label as Label).text
			if said.begins_with("=") or said.begins_with("~"):
				marked.append(said)
	_check13("the parts list names no part by LDraw's marks (%s)" % ", ".join(marked.slice(0, 3)),
		inventory is Node and marked.is_empty())
	await _close_all()
	_shell.run("timeline")
	var widest: float = 0.0
	var busy: bool = false
	for _n: int in 40:
		await process_frame
		busy = busy or Working.is_busy()
		var status: Control = _shell.get("status")
		widest = maxf(widest, status.get_combined_minimum_size().x)
	await _step("p6_05_timeline", "Build, Timeline: Studio's steps")
	var window: float = root.get_visible_rect().size.x
	_check13("while it works (%s), the status bar stays inside the window (%.0f of %.0f)" % [
		"seen" if busy else "not seen", widest, window], widest <= window)
	await _run_command("timeline", "", "", 10)
	await _run_command("panel_outliner", "p6_06_model_tree", "the model tree: Studio's sub-models", 30)
	await _run_command("panel_outliner", "", "", 10)
	SaveTo.native = false
	_shell.run("export_io")
	await _frames(30)
	await _step("p6_07_export_io", "File, Export, Studio .io, to send it back")
	if SaveTo.showing != null:
		SaveTo.showing.canceled.emit()
	await _frames(10)
	await _close_all()


# -- 7. a sub-assembly made and used again ----------------------------------------------


func _sub_assembly() -> void:
	print("\nUX12 p7: a sub-assembly made and used again")
	await _open_model("res://models/car.ldr", "Car")
	# The car's front: the parts nearest its nose, as a box drawn round them.
	var bricks: Array = _world.bricks()
	bricks.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.transform.origin.z > b.transform.origin.z)
	_builder.clear_selection()
	for brick: BrickWorld.Brick in bricks.slice(0, 8):
		_builder.select_brick(brick.id, true)
	await _frames(10)
	await _step("p7_01_selected", "eight parts of the front selected")
	await _run_command("make_submodel", "p7_02_name_it", "Build, Make a sub-assembly", 20)
	var verbs: Variant = _shell.get("verbs")
	var naming: Variant = verbs.get("_naming") if verbs is Node else null
	if naming is ConfirmationDialog and (naming as ConfirmationDialog).visible:
		(verbs.get("_name_field") as LineEdit).text = "Bumper"
		(naming as ConfirmationDialog).hide()
		verbs.call("_named", "Bumper")
	await _frames(30)
	await _step("p7_03_made", "the sub-assembly made")
	await _run_command("panel_outliner", "p7_04_model_tree", "the model tree", 30)
	await _search_bin("Bumper", "p7_05_bin_bumper", "the parts bin's search for it, to place another")
	var bin_said: String = (_bin.get("_status") as Label).text
	_check13("the bin searched for the sub-assembly says where another comes from (%s)" % (
		bin_said.get_slice("\n", 0)), bin_said.contains("is a sub-assembly of this model"))
	await _run_command("duplicate", "p7_06_duplicate", "Edit, Duplicate: a second one in hand", 20)
	await _put_down(Vector3(0, 0, -160), "p7_07_second_down", "the second one put down")
	await _run_command("enter_assembly", "p7_08_inside", "Build, Edit inside the sub-assembly", 30)
	await _run_command("leave_assembly", "p7_09_done_inside", "Done editing the sub-assembly", 30)
	await _run_command("panel_outliner", "", "", 10)
	await _close_all()


# -- 8. stability checked, and what floats fixed ----------------------------------------


func _stability() -> void:
	print("\nUX12 p8: a MOC's stability checked, and what floats fixed")
	await _open_model("res://models/house.ldr", "House")
	# One part lifted off its studs, as a slip of Page Up leaves one.
	var top: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and (top == null
				or brick.transform.origin.y > top.transform.origin.y):
			top = brick
	if top != null:
		_builder.clear_selection()
		_builder.select_brick(top.id, true)
		print("UX12 p8 lifted %s by 40 LDU: %d moved" % [top.part_id,
			_builder.move_selection_by(Vector3(0, 40, 0))])
		_builder.clear_selection()
	await _frames(20)
	await _step("p8_01_floating", "a part left floating over the roof")
	await _run_command("stability", "p8_02_check", "Tools, Check stability", 120)
	var said: String = _bar.status_text()
	_check13("Check stability says the part in the air and selects it (%s)" % said.left(90),
		top != null and said.contains("floats in the air") and _builder.selection.has(top.id))
	await _run_command("stress", "p8_03_stress", "View, Stress", 40)
	var stress_panel: Variant = (_shell.get("stress") as Node).get("panel") if _shell.get("stress") != null else null
	var stress_tips: String = ""
	if stress_panel is Node:
		for label: Node in (stress_panel as Node).find_children("*", "Label", true, false):
			if (label as Label).visible and (label as Label).text.begins_with("In the air"):
				stress_tips = (label as Label).text
	_check13("View, Stress says it (%s)" % stress_tips.left(90), not stress_tips.is_empty())
	await _run_command("stress", "", "", 10)
	await _menu("Tools", "p8_04_tools_menu", "Tools: what fixes a part off its studs")
	_builder.clear_selection()
	await _run_command("reseat", "p8_05_reseat", "Tools, Seat parts on their studs", 120)
	said = _bar.status_text()
	_check13("Seat parts says the part in the air, not that every part is seated (%s)" % said.left(90),
		said.contains("floats in the air") and top != null and _builder.selection.has(top.id))
	await _run_command("stability", "p8_06_check_again", "Check stability again", 120)
	await _close_all()


# -- 9. instructions and their PDF ---------------------------------------------------------


func _booklet_pdf() -> void:
	print("\nUX12 p9: instructions made and saved as a PDF")
	await _open_model("res://models/car.ldr", "Car")
	await _run_command("timeline", "p9_01_timeline", "Build, Timeline: the steps", 40)
	await _run_command("timeline", "", "", 10)
	await _menu("Build", "p9_02_build_menu", "Build: the booklet's commands")
	SaveTo.native = false
	var booklet: Variant = Later.script(&"BookletMaker")
	booklet.open_when_written = false
	var out: String = ProjectSettings.globalize_path(_out.path_join("car_instructions.html"))
	_shell.run("instructions")
	await _frames(30)
	await _step("p9_03_save_dialog", "File, Instructions: where to save them")
	if SaveTo.showing != null:
		SaveTo.showing.file_selected.emit(out)
	for _n: int in 240:
		await create_timer(0.5).timeout
		if FileAccess.file_exists(out.get_basename() + ".pdf") and not Working.is_busy():
			break
	await _frames(30)
	await _step("p9_04_written", "the instructions written, and their PDF")
	await _run_command("booklet_page_setup", "p9_05_page_setup", "Build, Booklet page, Page setup", 40)
	await _close_all()


# -- 10. a teenager on a phone: a minifigure, shared -----------------------------------------


func _figure_on_a_phone() -> void:
	print("\nUX12 p10: a minifigure made on a phone and shared")
	_main.call("clear_model")
	await _frames(30)
	await _menu("Make", "p10_01_make", "where a figure is made")
	await _run_command("minifig", "p10_02_builder", "Make, Minifigure builder", 60)
	var figures: Variant = _main.get("_figures")
	if figures is Control:
		for slot: Array in [["torso", "space", "p10_03_torso"], ["headwear", "helmet", "p10_04_helmet"]]:
			var button: Variant = (figures.get("_slot_buttons") as Dictionary).get(slot[0])
			if button is BaseButton:
				(button as BaseButton).pressed.emit()
				await _frames(10)
			var search: LineEdit = figures.get("_search")
			search.text = slot[1]
			search.text_changed.emit(slot[1])
			await create_timer(0.6).timeout
			await _frames(20)
			var grid: GridContainer = figures.get("_grid")
			if grid.get_child_count() > 0:
				(grid.get_child(0) as BaseButton).pressed.emit()
				await _frames(20)
			await _step(slot[2], "the figure's %s: %s" % [slot[0], slot[1]])
			if slot[0] == "torso":
				var first: String = str(grid.get_child(0).get_meta("part", "")) \
					if grid.get_child_count() > 0 else ""
				var info: PartLibrary.PartInfo = (_main.get("_library") as PartLibrary).parts.get(first)
				_check13("the torso searched for space is one named so (%s %s)" % [first,
					info.name if info != null else "?"],
					info != null and info.name.to_lower().contains("space"))
		var name: LineEdit = figures.get("_name")
		name.text = "Nova"
		name.text_changed.emit("Nova")
		figures.call("_place")
		await _frames(30)
		await _step("p10_05_in_hand", "Place in model: the figure in hand")
		await _put_down(Vector3(0, 0, 0), "p10_06_stood", "the figure stood on the baseplate")
	await _run_command("share", "p10_07_share", "Share", 60)
	var share: Variant = _main.get("_share_panel")
	if share is Node and (share as Control).visible:
		var called: String = ((share as Node).get("_name") as LineEdit).text
		_check13("Share names the model for its one figure (%s)" % called, called == "Nova")
	await _close_all()


func _open_menu(shot: String, what: String) -> void:
	_bar.call("_on_open")
	await _frames(10)
	await _step(shot, what)
	var saves: Variant = _bar.get("_saves")
	if saves is PopupMenu:
		(saves as PopupMenu).hide()
	await _frames(5)


## A question over work not saved, answered Don't save, as a walk opening
## another model would.
func _answer_dont_save() -> void:
	for _n: int in 60:
		await process_frame
		var asking: Variant = _bar.get("_confirm_open")
		if asking is Window and (asking as Window).visible:
			print("UX12: asked to save what was there first; answered Don't save")
			(asking as Window).hide()
			_bar.emit_signal("_replace_answered", "discard")
			return


# -- acts ------------------------------------------------------------------------------


func _run_command(name: String, shot: String, what: String, frames: int) -> void:
	if _shell.command(name) == null:
		print("UX12 %s: no command %s" % [shot, name])
		return
	if not _shell.can(name):
		print("UX12 %s: %s greyed" % [shot, name])
		if not shot.is_empty():
			await _step(shot, what + " (greyed)")
		return
	_shell.run(name)
	await _frames(frames)
	if not shot.is_empty():
		await _step(shot, what)


func _menu(title: String, shot: String, what: String) -> void:
	if _on_phone:
		var more: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_more")
		if more is Control:
			await _tap((more as Control).get_global_rect().get_center())
			await _frames(30)
			await _step(shot, what + " (More)")
		await _close_all()
		return
	for menu: MenuButton in _shell.get("_menus"):
		if menu.text == title:
			menu.show_popup()
			await _frames(20)
			await _step(shot, what)
			menu.get_popup().hide()
			await _frames(5)


func _search_bin(words: String, shot: String, what: String) -> void:
	var dock: SideDock = _main.get("_bin_dock")
	if dock != null and not dock.is_open():
		dock.set_open(true)
		await _frames(20)
	if _on_phone:
		var parts: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_parts")
		if parts is Control and _phone_sheet() != "Parts":
			await _tap((parts as Control).get_global_rect().get_center())
			await _frames(30)
	var search: LineEdit = _bin.get("_search")
	search.grab_focus()
	search.text = words
	search.text_changed.emit(words)
	await create_timer(0.6).timeout
	await _frames(20)
	if not shot.is_empty():
		var grid: GridContainer = _bin.get("_grid")
		var first: Array = []
		for n: int in mini(6, grid.get_child_count()):
			var tile: Node = grid.get_child(n)
			first.append(str(tile.get_meta("part", tile.get_meta("key", "?"))))
		print("UX12 %s first tiles: %s" % [shot, ", ".join(first)])
		await _step(shot, what)


func _take_first_tile(shot: String, what: String) -> void:
	var grid: GridContainer = _bin.get("_grid")
	for tile: Node in grid.get_children():
		var control := tile as Control
		if control != null and control.is_visible_in_tree() and tile.has_meta("part"):
			if _on_phone:
				await _tap(control.get_global_rect().get_center())
			else:
				await _click(control.get_global_rect().get_center())
			await _frames(10)
			break
	print("UX12 in hand: %s" % _builder.is_carrying())
	if not shot.is_empty():
		await _step(shot, what)


func _put_down(at: Vector3, shot: String, what: String) -> void:
	if _on_phone and _phone_sheet() != "":
		var done: Variant = (_phone.call("controls_by_name") as Dictionary).get(
			"phone_sheet_" + _phone_sheet().to_lower().replace(" ", "_") + "_done")
		if done is Control:
			await _tap((done as Control).get_global_rect().get_center())
			await _frames(20)
	var spot: Vector2 = _camera.unproject_position(at + Vector3(0, 8, 0))
	if _on_phone:
		await _tap(spot)
	else:
		await _move(spot)
		await _move(spot + Vector2(1, 0))
		await _click(spot + Vector2(1, 0))
		await _key(KEY_ESCAPE)
	await _frames(20)
	print("UX12 parts now: %d" % _world.bricks().size())
	if not shot.is_empty():
		await _step(shot, what)


func _library(words: String, source: String, shot: String, what: String) -> void:
	var dialog: Node = _shell.get("library_dialog")
	dialog.call("open", source)
	await _frames(30)
	var search: Variant = dialog.get("_search")
	if search is LineEdit and not words.is_empty():
		var field := search as LineEdit
		field.text = words
		field.text_changed.emit(words)
	for _n: int in 40:
		await create_timer(0.25).timeout
	await _step(shot, what)


func _open_model(path: String, name: String) -> void:
	await _close_all()
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))
	var result: Dictionary = await _bar.open_text_with_progress(text, name)
	# As every open of the app's says it, so the view frames it (Main).
	_bar.opened.emit(int(result.get("placed", 0)))
	await _until_still(120)


# -- what each step sees -------------------------------------------------------------


func _step(shot: String, what: String) -> void:
	_steps += 1
	await _frames(6)
	var cover: Dictionary = _main.call("model_cover", 24, 16)
	var covered: Array = cover["covered"]
	var by: Dictionary = {}
	for point: Dictionary in covered:
		by[str(point["by"])] = int(by.get(str(point["by"]), 0)) + 1
	var by_words: Array = []
	for name: String in by:
		by_words.append("%s %d" % [name, by[name]])
	var status: StatusBar = _shell.get("status")
	var said: String = status.message.text if status != null and status.message != null else ""
	var windows: Array = []
	for window: Window in _windows(root):
		if window.visible:
			windows.append(window.title if not window.title.is_empty() else str(window.name))
	print("UX12 step %s | %s | covered %d%% (%s) | status: %s | windows: %s%s" % [shot, what,
		roundi(100.0 * covered.size() / maxf(1.0, float(cover["samples"]))), ", ".join(by_words),
		said.replace("\n", " "), ", ".join(windows), (" | sheet: " + _phone_sheet())
		if _on_phone else ""])
	if _on_phone:
		var small: Array = _small_targets()
		print("UX12 small %s: %d under %d points%s" % [shot, small.size(), int(Phone.TARGET),
			(": " + ", ".join(small.slice(0, 40))) if not small.is_empty() else ""])
	await _shot(shot)


## Every control a finger presses, in sight, under a fingertip across or down.
func _small_targets() -> Array:
	var out: Array = []
	var pt: float = Phone.per_point(root)
	_small_in(root, pt, out)
	return out


func _small_in(node: Node, pt: float, out: Array) -> void:
	for child: Node in node.get_children(true):
		if child is Window and not (child as Window).visible:
			continue
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		var control := child as Control
		if control != null and (control is BaseButton or control is LineEdit or control is Range
				and not control is ScrollBar and not control is ProgressBar) \
				and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and control.is_visible_in_tree() and _in_sight(control):
			var size: Vector2 = control.get_global_rect().size / pt
			if minf(size.x, size.y) < Phone.TARGET - 0.5:
				out.append("%s %.0fx%.0f" % [_name(control), size.x, size.y])
		_small_in(child, pt, out)


func _name(control: Control) -> String:
	var words: String = ""
	if control is Button:
		words = (control as Button).text
	elif control is LineEdit:
		words = (control as LineEdit).placeholder_text
	if words.is_empty():
		words = control.tooltip_text.get_slice("\n", 0).left(30)
	if words.is_empty():
		words = str(control.name)
	return "[%s]" % words.left(30)


func _in_sight(control: Control) -> bool:
	var clip: Rect2 = root.get_visible_rect()
	var up: Node = control.get_parent()
	while up != null and up is Control:
		if up is ScrollContainer or (up as Control).clip_contents:
			clip = clip.intersection((up as Control).get_global_rect())
		up = up.get_parent()
	return clip.grow(1.0).encloses(control.get_global_rect())


func _phone_sheet() -> String:
	if _phone == null or not _phone.has_method("state"):
		return ""
	return str((_phone.call("state") as Dictionary).get("sheet", ""))


func _close_all() -> void:
	for panel_name: String in ["library_dialog", "collection"]:
		var panel: Variant = _shell.get(panel_name)
		if panel is CanvasItem and (panel as CanvasItem).visible:
			(panel as CanvasItem).hide()
	for window: Window in _windows(root):
		if window != root and window.visible:
			window.hide()
	if _on_phone and _phone != null:
		for _n: int in 3:
			var sheet: String = _phone_sheet()
			if sheet.is_empty():
				break
			var done: Variant = (_phone.call("controls_by_name") as Dictionary).get(
				"phone_sheet_" + sheet.to_lower().replace(" ", "_") + "_done")
			if done is BaseButton:
				(done as BaseButton).pressed.emit()
			await _frames(15)
	await _key(KEY_ESCAPE)
	await _frames(10)
	var finder: Variant = _main.get("_find_replace_made")
	if finder is Control and (finder as Control).visible:
		(finder as Control).hide()
	var first: Variant = _shell.get("first_build")
	if first is Node and (first as Node).has_method("stop"):
		(first as Node).call("stop")
	await _frames(10)


func _windows(node: Node) -> Array:
	var out: Array = []
	for child: Node in node.get_children():
		if child is Window:
			out.append(child)
		out.append_array(_windows(child))
	return out


func _until_still(most: int) -> void:
	var last: int = -1
	var same: int = 0
	for _n: int in most:
		await _frames(5)
		var now: int = _world.bricks().size()
		if now == last and (_store.awaited.is_empty()):
			same += 1
			if same >= 6:
				break
		else:
			same = 0
		last = now
	await _frames(30)


# -- input ------------------------------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _tap(at: Vector2) -> void:
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = _as_event(at)
		Input.parse_input_event(touch)
		await _frames(3)
	await _frames(6)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	if name.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	if image != null and image.save_png(path) == OK:
		print("UX12 picture %s" % path)
