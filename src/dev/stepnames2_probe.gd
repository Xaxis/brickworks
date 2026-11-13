## stepnames2: a step's name shown wherever its number is, each name edit
## one undo, a name of nothing to see refused, a letter of many marks kept,
## and the first step edit of a stepless file numbering what it holds and
## does not show with the parts it came with (bench/results/stepnames2-
## 2026-11-11; sncheck's F7, F8, N2, N3 and hsfix's Sb).
##
##   godot --headless --path . --script src/dev/stepnames2_probe.gd
##
## SN2_ONLY=letters,refuse,undo,sub,held runs those parts alone.
##
##   letters  N3, N2: BookletLooks.name_of keeps a letter of a hundred marks
##            as the letter and four, counts 80 letters as a reader sees
##            them (an emoji of several, a letter and its accent, each one),
##            and makes a name of only characters that draw nothing none.
##   refuse   N2: a name of zero-width and direction characters alone is
##            refused, saying why, over MCP and in Name the step…, which
##            stays up; no undo step, the file as it was.
##   undo     F7: each name set, changed and taken off, over MCP and by hand,
##            on five, theirs_odd (two name lines in a step), a stepless file
##            (its first edit gives it steps) and sub.ldr (a wing placed
##            twice): one undo step, Undo gives back the steps and the file
##            as the plain save; Redo the edit and its file. The same name
##            again is no edit and no undo step.
##   sub      F8: sub.ldr's main step 2, "Both wings on", which only puts on
##            the two wings built where they stand, said on the first step
##            built in it: the plan, edit_steps' list, the timeline's caption
##            and tip, Build it and the booklet's step heading; saved and
##            opened, the same.
##   held     hsfix Sb: the first step edit of a stepless file numbers the
##            part it holds and does not show with the part before it in the
##            file, not in a step of its own first; Undo gives the stepless
##            file back. Brickworks' own and another author's.
extends SceneTree

const FIX := "res://src/dev/fixtures/stepnames/"
const MODELS := "user://models/"
const META := "0 !BRICKWORKS STEP_NAME"
const WATCHDOG := 1800.0
## The most code points one letter of a name keeps (BookletLooks.LETTER_MOST).
const LETTER_MOST := 16

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _steps: StepsBar
var _socket: CommandSocket
var _rpc_id: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _info(what: String) -> void:
	print("  info  %s" % what)


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("stepnames2_probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_steps = _main.get("_steps")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	DirAccess.make_dir_recursive_absolute(MODELS)
	var only: PackedStringArray = OS.get_environment("SN2_ONLY").split(",", false)
	if only.is_empty() or only.has("letters"):
		_part_letters()
	if only.is_empty() or only.has("refuse"):
		await _part_refuse()
	if only.is_empty() or only.has("undo"):
		await _part_undo()
	if only.is_empty() or only.has("sub"):
		await _part_sub()
	if only.is_empty() or only.has("held"):
		await _part_held()
	print("\nstepnames2_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures else 0)


# -- letters: N3 and N2 in name_of ---------------------------------------------------------


func _part_letters() -> void:
	print("\nletters: BookletLooks.name_of, letter by letter")
	var zalgo: String = "Z" + "\u0301".repeat(100)
	var four: String = "Z" + "\u0301".repeat(4)
	var thai: String = "ส" + "\u0E49".repeat(30)
	var family: String = "\U01F468\u200D\U01F469\u200D\U01F467"
	var accented: String = "e\u0301"
	var chain: String = ("\U01F468\u200D").repeat(40) + "\U01F467"
	var cases: Array = [
		# [what, given, wanted]
		["a letter of 101 code points", zalgo, four],
		["...and words after it", zalgo + " and more words", four + " and more words"],
		["Thai, a letter and 30 tone marks", thai, "ส" + "\u0E49".repeat(4)],
		["79 letters and a family of faces: 80 letters", "a".repeat(79) + family,
			"a".repeat(79) + family],
		["80 e's, each with its accent (160 code points)", accented.repeat(90), accented.repeat(80)],
		["a Devanagari conjunct kept whole", "क\u094Dषत\u094Dरिय", "क\u094Dषत\u094Dरिय"],
		["a Persian word's zero-width non-joiner kept", "می\u200Cخواهم", "می\u200Cخواهم"],
		["a flag and a keycap kept", "🇬🇧 1\uFE0F\u20E3", "🇬🇧 1\uFE0F\u20E3"],
		["zero-width spaces alone", "\u200B\u200B", ""],
		["a byte-order mark alone", "\uFEFF", ""],
		["word joiner and ZWNJ alone", "\u2060\u200C", ""],
		["a soft hyphen alone", "\u00AD", ""],
		["bidi controls alone", "\u202E\u202C\u2066\u2069\u200F", ""],
		["a tag alone", "\U0E0001", ""],
		["a Hangul filler alone", "\u3164", ""],
		["accents with no letter", "\u0301\u0301", ""],
		["zero-width words round a word", "\u200B Hello \u200B\u200D", "Hello"],
	]
	for case: Array in cases:
		var got: String = BookletLooks.name_of(case[1])
		_check("%s: %d code points, %d letters (%s)" % [case[0], got.length(), _letters(got),
			"as wanted" if got == str(case[2]) else "wanted %d code points: %s" % [str(case[2]).length(),
				_codes(got)]], got == str(case[2]))
	var long: String = BookletLooks.name_of(chain)
	_check("a chain of 40 faces joined in one letter: one letter of %d code points (at most %d)"
		% [long.length(), LETTER_MOST], _letters(long) == 1
		and long.length() <= LETTER_MOST and not long.is_empty())
	var step := Instructions.Step.new()
	step.name = BookletLooks.name_of(zalgo + " and more words")
	_check("the timeline's 40 of that name: \"%s\"" % step.shortened_name(40).c_escape(),
		not step.name.is_empty() and step.shortened_name(40) == step.name)


# -- refuse: N2 over MCP and by hand -------------------------------------------------------


func _part_refuse() -> void:
	print("\nrefuse: a name of nothing to see, over MCP and in Name the step…")
	var fixture: String = FileAccess.get_file_as_string(FIX + "five.ldr")
	await _open_text(fixture, "f_refuse.ldr")
	var plain: String = await _save("f_refuse_plain.ldr")
	var before: String = _steps_said()
	for given: String in ["\u200B\u200B", "\u202E\uFEFF\u2060", "\u0301"]:
		var depth: int = _builder.history_depth()
		var reply: String = await _say("edit_steps", {"op": "name", "step": 2, "name": given})
		var saved: String = await _save("f_refuse_saved.ldr")
		_check("edit_steps name %s: \"%s\"; no undo step (%d), the steps as they were (%s), the file too (%s)"
			% [given.c_escape(), reply.get_slice("\n", 0), _builder.history_depth() - depth,
				"the same" if _steps_said() == before else _steps_said(),
				"the same" if saved == plain else " ; ".join(_diff(plain, saved))],
			reply.contains("draw nothing") and _builder.history_depth() == depth
			and _steps_said() == before and saved == plain)
	# By hand: Name the step… on step 2, those typed, Return.
	var at: Instructions.Step = _plan()[1]
	var depth: int = _builder.history_depth()
	var dialog: ConfirmationDialog = await _ask_name(at)
	var field: LineEdit = _steps.get("_naming_field")
	field.text = "\u200B\u200D\u200B"
	field.text_submitted.emit(field.text)
	await _frames(4)
	var why: String = _visible_words(dialog)
	_check("Name the step…: zero-width characters typed, Return: the dialog stays (%s), says why (\"%s\"), no undo step (%d)"
		% ["up" if dialog.visible else "gone", why, _builder.history_depth() - depth],
		dialog.visible and why.contains("draw nothing") and _builder.history_depth() == depth)
	field.text = "Z" + "\u0301".repeat(100)
	field.text_submitted.emit(field.text)
	await _settled()
	var named: String = _plan()[1].name
	_check("...then a letter of a hundred accents: named \"%s\" (%d code points), the dialog gone (%s), one undo step (%d)"
		% [named.c_escape(), named.length(), "up" if dialog.visible else "gone",
			_builder.history_depth() - depth], named == "Z" + "\u0301".repeat(4)
		and not dialog.visible and _builder.history_depth() == depth + 1)
	_shell.run("undo")
	await _settled()


# -- undo: F7, each name edit one undo -----------------------------------------------------


## [file, what, how ("mcp" or "hand"), the step's number, the name].
const UNDO_CASES: Array = [
	["five.ldr", "step 3 renamed", "mcp", 3, "Third, renamed"],
	["five.ldr", "step 4's name taken off", "mcp", 4, ""],
	["five.ldr", "step 2 renamed", "hand", 2, "By hand"],
	["five.ldr", "step 5's name taken off", "hand", 5, ""],
	["row.ldr", "step 3, unnamed, named", "mcp", 3, "Now named"],
	["row.ldr", "step 3, unnamed, named", "hand", 3, "Now named by hand"],
	["theirs_odd.ldr", "step 3, two name lines, renamed", "mcp", 3, "Only one"],
	["theirs_odd.ldr", "step 3, two name lines, taken off", "hand", 3, ""],
	["nosteps.ldr", "step 2 of a stepless file named", "mcp", 2, "First of its steps"],
	["nosteps.ldr", "step 1 of a stepless file named", "hand", 1, "By hand, stepless"],
	["nosteps_theirs.ldr", "step 2 of another author's stepless file named", "mcp", 2, "Theirs named"],
	["sub.ldr", "the wing's step 1 (both copies) renamed", "mcp", 2, "Wing renamed"],
	["sub.ldr", "the wing's step 2 (both copies) named off", "hand", 5, ""],
	["sub.ldr", "the main model's last step renamed", "hand", 6, "Top renamed"],
]


func _part_undo() -> void:
	print("\nundo: each name edit, one undo step, undone to the model and the file as before")
	for case: Array in UNDO_CASES:
		var file: String = case[0]
		print("  -- %s: %s, %s" % [file, case[1], "over MCP" if case[2] == "mcp" else "by hand"])
		var fixture: String = FileAccess.get_file_as_string(FIX + file)
		await _open_text(fixture, "u_" + file)
		var before: String = _steps_said()
		var plain: String = await _save("u_plain_" + file)
		await _open_text(fixture, "u_" + file)
		var depth: int = _builder.history_depth()
		var reply: String = await _name(case[2], int(case[3]), str(case[4]))
		var made: int = _builder.history_depth() - depth
		var after: String = _steps_said()
		var called: String = _name_of_step(int(case[3]))
		_info("reply: %s; then %s" % [reply.get_slice("\n", 0).left(120), after])
		var edited: String = await _save("u_edited_" + file)
		_check("...one undo step (%d), step %d now \"%s\"" % [made, int(case[3]), called],
			made == 1 and called == str(case[4]))
		_shell.run("undo")
		await _settled()
		var undone: String = _steps_said()
		var undone_text: String = await _save("u_undone_" + file)
		_check("...undone: the steps as it opened (%s), the file as the plain save (%s)" % [
			"the same" if undone == before else undone,
			"the same" if undone_text == plain else " ; ".join(_diff(plain, undone_text)).left(300)],
			undone == before and undone_text == plain)
		_shell.run("redo")
		await _settled()
		var redone_text: String = await _save("u_redone_" + file)
		_check("...redone: as after the edit (%s), its file too (%s)" % [
			"the same" if _steps_said() == after else _steps_said(),
			"the same" if redone_text == edited else " ; ".join(_diff(edited, redone_text)).left(300)],
			_steps_said() == after and redone_text == edited)
	# The same name again: no edit, no undo step.
	await _open_text(FileAccess.get_file_as_string(FIX + "five.ldr"), "u_same.ldr")
	for how: String in ["mcp", "hand"]:
		var depth: int = _builder.history_depth()
		var reply: String = await _name(how, 3, "Charlie one")
		_check("step 3 named \"Charlie one\" again, %s: no undo step (%d), \"%s\"" % [how,
			_builder.history_depth() - depth, reply.get_slice("\n", 0)],
			_builder.history_depth() == depth and reply.to_lower().contains("as it was"))


# -- sub: F8, a step with no step of its own --------------------------------------------------


func _part_sub() -> void:
	for file: String in ["sub.ldr"]:
		print("\nsub: %s, the main model's step 2 puts on two wings built where they stand" % file)
		var fixture: String = FileAccess.get_file_as_string(FIX + file)
		await _open_text(fixture, "s_" + file)
		_sub_said(file, "as opened")
		var saved: String = await _save("s_saved_" + file)
		_check("...saved: its line kept (%d)" % _count(saved, META + " Both wings on"),
			_count(saved, META + " Both wings on") == 1)
		await _open_text(saved, "s_open_" + file)
		_sub_said(file, "saved and opened")
		var listed: String = await _say("edit_steps", {})
		var line: String = ""
		for one: String in listed.split("\n"):
			if one.strip_edges().begins_with("2 "):
				line = one.strip_edges()
		_check("...edit_steps' list says it at step 2 (%s)" % line, line.contains("\"Both wings on\""))
		await _booklet_said()
		# Named over MCP, the wing's step keeps the main step's name before it.
		await _say("edit_steps", {"op": "name", "step": 2, "name": "Over MCP"})
		var step: Instructions.Step = _plan()[1]
		_check("...its wing step renamed \"Over MCP\": \"%s\"" % step.caption(6),
			step.caption(6).contains("Both wings on · Over MCP"))
		_shell.run("undo")
		await _settled()


## The plan, the timeline's caption and tip, and Build it at [param file]'s
## step 2, each saying "Both wings on"; steps 3 to 5 not.
func _sub_said(file: String, when: String) -> void:
	var plan: Array[Instructions.Step] = _plan()
	var second: Instructions.Step = plan[1] if plan.size() > 1 else null
	var later := PackedStringArray()
	for index: int in range(2, plan.size()):
		if _called(plan[index]).contains("Both wings on"):
			later.append(str(plan[index].number))
	_check("%s, %s: step 2 called \"%s\", in its caption \"%s\"; no later step (%s)" % [file, when,
		_called(second) if second != null else "", second.caption(plan[-1].number) if second != null
			else "", ", ".join(later) if not later.is_empty() else "none"],
		second != null and _called(second).begins_with("Both wings on")
		and second.caption(plan[-1].number).contains("Both wings on") and later.is_empty())
	# Build it's words for its page (BuildSteps.caption), page 2 step 2.
	var build := BuildSteps.new()
	build.steps = plan
	var said: String = build.caption(2)
	_check("...Build it at step 2: \"%s\"" % said.c_escape(), said.contains("\nBoth wings on"))


## The booklet's step 2 heading, laid out.
func _booklet_said() -> void:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, "Sub")
	maker.queue_free()
	var named := PackedStringArray()
	for page: Booklet.Page in pages:
		for entry: Booklet.Entry in page.entries:
			if not entry.name.is_empty():
				named.append("%d \"%s\"" % [entry.number, entry.name])
	var said: String = " | ".join(named)
	_check("...the booklet's headings: %s" % said, said.contains("2 \"Both wings on · Wing plate\""))


# -- held: hsfix Sb, the first step edit of a stepless file -----------------------------------


func _part_held() -> void:
	for file: String in ["held_nosteps.ldr", "held_nosteps_theirs.ldr"]:
		print("\nheld: %s, a part the app cannot show between the 3020 and the 3003" % file)
		var fixture: String = FileAccess.get_file_as_string(FIX + file)
		await _open_text(fixture, "h_" + file)
		_info("as opened: %s" % _steps_said())
		var plain: String = await _save("h_plain_" + file)
		await _open_text(fixture, "h_" + file)
		var reply: String = await _say("edit_steps", {"op": "next", "bricks": [_id_of("3001")]})
		_info("3001 to the next step: %s; then %s" % [reply.get_slice("\n", 0), _steps_said()])
		var saved: String = await _save("h_saved_" + file)
		var blocks: Array = _blocks(saved)
		_info("saved: %s" % " | ".join(blocks))
		var held_in: String = ""
		for block: String in blocks:
			if block.contains("hsnosuch"):
				held_in = block
		_check("...the held part in the step of the 3020 before it (%s), not one of its own first"
			% held_in, held_in == "3020,hsnosuch")
		await _open_text(saved, "h_open_" + file)
		var again: String = await _save("h_again_" + file)
		_check("...opened and saved again byte for byte (%s)" % ("the same" if again == saved
			else " ; ".join(_diff(saved, again))), again == saved)
		await _open_text(fixture, "h_" + file)
		await _say("edit_steps", {"op": "next", "bricks": [_id_of("3001")]})
		_shell.run("undo")
		await _settled()
		var undone: String = await _save("h_undone_" + file)
		_check("...undone: the stepless file as the plain save (%s)" % ("the same" if undone == plain
			else " ; ".join(_diff(plain, undone))), undone == plain)


## Each step of [param text]'s main model, its parts' numbers in file order.
static func _blocks(text: String) -> Array:
	var out: Array = []
	var parts := PackedStringArray()
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 NOFILE"):
			break
		if line == "0 STEP":
			out.append(",".join(parts))
			parts = PackedStringArray()
			continue
		if line.begins_with("1 "):
			parts.append(line.get_slice(" ", 14).get_basename())
	if not parts.is_empty():
		out.append(",".join(parts))
	return out


# -- helpers -----------------------------------------------------------------------------


## Name step [param number] [param name]: over MCP, or by hand in Name the
## step… (the timeline's Name…), typed and Return.
func _name(how: String, number: int, name: String) -> String:
	if how == "mcp":
		return await _say("edit_steps", {"op": "name", "step": number, "name": name})
	var at: Instructions.Step = null
	for step: Instructions.Step in _plan():
		if step.number == number and not step.in_callout():
			at = step
	if at == null:
		return "no step %d" % number
	var heard: Array = []
	var bar: ModelBar = _main.get("_bar")
	var hear := func(text: String) -> void: heard.append(text)
	bar.said.connect(hear)
	await _ask_name(at)
	var field: LineEdit = _steps.get("_naming_field")
	field.text = name
	field.text_submitted.emit(name)
	await _settled()
	bar.said.disconnect(hear)
	return str(heard[-1]) if not heard.is_empty() else ""


## Name the step… up for [param at], as the timeline's Name… puts it up
## on the step it is at (StepsBar.ask_step_name), its words chosen.
func _ask_name(at: Instructions.Step) -> ConfirmationDialog:
	if _steps.get("_naming") == null:
		_steps.call("_make_naming")
	_steps.set("_naming_step", at)
	var dialog: ConfirmationDialog = _steps.get("_naming")
	var field: LineEdit = _steps.get("_naming_field")
	field.text = at.name
	dialog.popup_centered()
	await _frames(4)
	return dialog


func _visible_words(dialog: ConfirmationDialog) -> String:
	var out := PackedStringArray()
	for label: Node in dialog.find_children("*", "Label", true, false):
		if (label as Label).visible and not (label as Label).text.is_empty():
			out.append((label as Label).text)
	return " / ".join(out)


func _name_of_step(number: int) -> String:
	for step: Instructions.Step in _plan():
		if step.number == number and not step.in_callout():
			return step.name
	return "(no step %d)" % number


func _open_text(text: String, file: String) -> void:
	var writing: FileAccess = FileAccess.open(MODELS + file, FileAccess.WRITE)
	writing.store_string(text)
	writing.close()
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", MODELS + file)
	await _settled()


func _save(file: String) -> String:
	var said: String = await _say("save_model", {"name": file})
	var text: String = FileAccess.get_file_as_string(MODELS + file)
	if text.is_empty():
		_info("save_model %s said: %s" % [file, said.left(200)])
	return text


func _plan() -> Array[Instructions.Step]:
	return Instructions.plan(_world, _library, _store.scenery, {}, true)


func _steps_said() -> String:
	var out := PackedStringArray()
	for step: Instructions.Step in _plan():
		var parts := PackedStringArray()
		for id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			if brick != null:
				parts.append("%s/%d" % [brick.part_id.get_basename(), brick.color_code])
		parts.sort()
		var label: String = ("%d.%d" % [step.number, step.callout_step]) if step.in_callout() \
			else str(step.number)
		out.append("%s[%s]%s" % [label, ",".join(parts), (" \"%s\"" % _called(step))
			if not _called(step).is_empty() else ""])
	return " | ".join(out)


func _id_of(part: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and brick.part_id.get_basename() == part:
			return brick.id
	return -1


## What [param step] is called where it is shown (Step.called), its own name
## on a build without it.
static func _called(step: Instructions.Step) -> String:
	return str(step.call("called")) if step.has_method("called") else step.name


static func _letters(text: String) -> int:
	if text.is_empty():
		return 0
	return TextServerManager.get_primary_interface().string_get_character_breaks(text, "en").size()


static func _codes(text: String) -> String:
	var out := PackedStringArray()
	for at: int in mini(text.length(), 12):
		out.append("%04X" % text.unicode_at(at))
	return " ".join(out) + (" ..." if text.length() > 12 else "")


static func _count(text: String, line: String) -> int:
	var count: int = 0
	for raw: String in text.split("\n"):
		if raw.strip_edges() == line:
			count += 1
	return count


static func _diff(before: String, after: String) -> PackedStringArray:
	var count: Dictionary = {}
	for line: String in before.split("\n"):
		count[line] = int(count.get(line, 0)) + 1
	var out := PackedStringArray()
	for line: String in after.split("\n"):
		if int(count.get(line, 0)) > 0:
			count[line] = int(count[line]) - 1
		else:
			out.append("+ " + line.c_escape())
	for line: String in count:
		for _n: int in int(count[line]):
			out.append("- " + line.c_escape())
	return out


func _settled() -> void:
	for _n: int in 600:
		if _store == null or _store.awaited.is_empty():
			break
		await process_frame
	await _frames(10)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	if text.is_empty() and (answer as Dictionary).has("error"):
		text = str((answer as Dictionary)["error"])
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return "\n".join(lines)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
