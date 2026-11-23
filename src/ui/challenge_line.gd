## The challenge open now, said in one small line with the model's other
## notices (challengestudio, 2026-11-23): its name and its days left, and,
## pressed, its rules ticked on the model as it is built.
##
## Entering used to mean building here, publishing, then finding the
## challenge's page on the site and pressing Enter: nothing in the studio
## said a challenge was open, nor whether the model kept its rules, until
## the site refused it. Every other contest checks entries after the fact
## (a forum's jury reads the rules, a print site's staff do); here the
## rules the site checks on the stored model (supabase/challenges.sql
## challenge_check) are ticked on the model open, by the same rules ported
## exactly (ChallengeRules), each failed one saying what to change. Share
## then says Enter when they pass (SharePanel), and one press publishes
## and enters.
##
## Which challenge: this week's quick build when the model is a copy of its
## template (ModelStore.prompt_now, which Main and Share ask of
## ?op=prompt_of), once its brief above the model has been read (Got it):
## a quick build has no rules, so the line names it and the day to publish
## by. Else the month's challenge open now (?op=challenge_rules), asked as
## the app starts and again each hour, and with the sign-in once it is
## known, for a test account's is the checks' own.
##
## Above the model as every notice is (Main._notices), never over it: one
## line at its narrowest, its name cut short before the days left are.
## Hide takes it away for this challenge, and the next one is said again
## (kept on this machine, [member where]).
##
## The parts and the set are ticked live: each time the model changes, at
## most once a second, from the text a publish would send, read off the
## main thread when it is big (ChallengeRules.read). Tested is the four
## tests a publish runs: run here with Test it, or found by the last
## publish, and kept until the model changes.
class_name ChallengeLine
extends PanelContainer

## Where Hide is kept: the challenges hidden, by id. A probe points it at a
## file of its own.
var where: String = "user://challenge_line.cfg"
## The rules were ticked again, or a Tested finding came (Share's Enter follows).
signal ticked
var store: ModelStore
var library: PartLibrary
var shared: SharedModels
var account: Account
## Opens Share (Main): the line's Publish to enter.
var open_share: Callable = Callable()
## Draws a control for a finger on a phone (Main._for_a_finger), else unset.
var for_a_finger: Callable = Callable()
## A probe's "today" ("2026-11-23"), else the day it is in UTC.
var today_for_probe: String = ""

## The month's challenge open now (ChallengeRules.rules_in), {} for none.
var challenge: Dictionary = {}
## What its rules said of the model at [member checked_revision]
## (ChallengeRules.check), {} before the first.
var checked: Dictionary = {}
var checked_revision: int = -1
## The model's Tested finding, its four tests ({name: {ok, why}}), at
## [member tested_revision]; null when not known for the model as it is.
var tested_tests: Variant = null
var tested_revision: int = -1
## Whether its rules are shown.
var open_rules: bool = false

var _toggle: Button
var _hide: Button
var _details: VBoxContainer
var _test: Button
var _go: Button
var _page: Button
var _checking: bool = false
var _testing: bool = false
var _last_check_ms: int = -100000
var _asked_ms: int = -1
var _asked_with: String = "-"
var _timer: Timer

## Asked again after this long.
const ASK_EVERY_MS := 3600000
## The rules ticked again at most this often while the model changes.
const CHECK_EVERY_MS := 1000
## A text this long is read on a worker (ChallengeRules.read).
const READ_ON_A_WORKER := 120000
const GOLD := Color(1.0, 0.82, 0.42)
const TICK: Texture2D = preload("res://assets/ui/tools/accept.svg")
const KEPT := Color(0.55, 0.85, 0.55)
const BROKEN := Color(1.0, 0.62, 0.55)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.15, 0.13, 0.08, 0.97)
	backing.border_color = Color(1.0, 0.82, 0.42, 0.45)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 6
	backing.content_margin_right = 6
	backing.content_margin_top = 2
	backing.content_margin_bottom = 2
	add_theme_stylebox_override("panel", backing)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	_toggle = Button.new()
	_toggle.flat = true
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toggle.clip_text = true
	_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toggle.custom_minimum_size = Vector2(180, 0)
	_toggle.add_theme_font_size_override("font_size", 13)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_toggle.add_theme_color_override(state, GOLD)
	_toggle.pressed.connect(func() -> void: show_rules(not open_rules))
	row.add_child(_toggle)
	_hide = Button.new()
	_hide.flat = true
	_hide.text = "×"
	_hide.focus_mode = Control.FOCUS_NONE
	_hide.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hide.add_theme_font_size_override("font_size", 15)
	_hide.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_hide.pressed.connect(hide_for_now)
	row.add_child(_hide)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 3)
	_details.visible = false
	column.add_child(_details)
	_timer = Timer.new()
	_timer.wait_time = 0.25
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()


## The month's challenge asked of the server: as the app starts, each
## hour, and again with the sign-in once it is known.
func ask() -> void:
	if shared == null:
		return
	var token: String = ""
	if account != null and account.signed_in():
		token = await account.access_token()
	_asked_ms = Time.get_ticks_msec()
	_asked_with = token
	var answer: Dictionary = await shared.challenge_rules(token)
	var got: Dictionary = ChallengeRules.rules_in(answer)
	# Nothing answered: the challenge said before stays said.
	if int(answer.get("code", 0)) != 200 and not challenge.is_empty():
		return
	tell(got)


## Say [param given] (ChallengeRules.rules_in's), {} for none.
func tell(given: Dictionary) -> void:
	if not given.is_empty() and str(given.get("id")) != str(challenge.get("id")):
		checked = {}
		checked_revision = -1
	challenge = given
	if not challenge.is_empty():
		Language.keep_name(str(challenge["title"]))
	_redraw_line()
	_check_soon()
	ticked.emit()


## This week's quick build the model is a copy of (ModelStore.prompt_now),
## {} for none.
func prompt() -> Dictionary:
	return store.prompt_now() if store != null else {}


## What the line is about: {"kind": "prompt"|"month", "id", "title",
## "day"}, or {} for nothing to say.
func about() -> Dictionary:
	var week: Dictionary = prompt()
	if not week.is_empty():
		return {"kind": "prompt", "id": int(week["id"]), "title": str(week["title"]),
			"day": str(week["ends_on"]), "brief": str(week.get("brief", "")), "page": str(week.get("page", ""))}
	if challenge.is_empty() or not bool(challenge.get("entering", true)):
		return {}
	return {"kind": "month", "id": int(challenge["id"]), "title": str(challenge["title"]),
		"day": ChallengeRules.last_day(challenge), "brief": str(challenge.get("brief", "")),
		"page": str(challenge.get("page", ""))}


## The quick build's brief above the model (Main._prompt_notice) is the
## line until its Got it: while it shows, the line waits.
var prompt_notice: Control = null


func _redraw_line() -> void:
	if _toggle == null:
		return
	var said: Dictionary = about()
	var hidden_now: bool = said.is_empty() or is_hidden(said) \
		or (str(said["kind"]) == "prompt" and prompt_notice != null and prompt_notice.visible)
	if hidden_now:
		visible = false
		return
	var days: int = ChallengeRules.days_left(str(said["day"]), _today())
	var left: String = "last day" if days == 1 else ("%d days left" % days if days > 1 else "")
	var named: String = ("Quick build: %s" % said["title"]) if str(said["kind"]) == "prompt" else str(said["title"])
	var kept: String = _kept_words()
	var bits := PackedStringArray()
	for bit: String in [named, left, kept]:
		if not bit.is_empty():
			bits.append(bit)
	_toggle.text = " · ".join(bits)
	_toggle.tooltip_text = "Its rules, ticked on this model" if str(said["kind"]) == "month" \
		else "This week's quick build"
	_toggle.accessibility_name = "%s: %s. %s" % [
		("This week's quick build, %s" % said["title"]) if str(said["kind"]) == "prompt"
			else ("This month's challenge, %s" % said["title"]),
		left if not left.is_empty() else "ends today",
		("Hide its rules" if open_rules else "Show its rules") if str(said["kind"]) == "month"
			else ("Hide its brief" if open_rules else "Show its brief")]
	_hide.tooltip_text = "Hide this line for %s" % said["title"]
	_hide.accessibility_name = "Hide the line for %s" % said["title"]
	visible = true
	_details.visible = open_rules
	if open_rules:
		_fill(said)


## "2 of 3 rules kept", or "" while nothing is ticked yet or there are no rules.
func _kept_words() -> String:
	if str(about().get("kind", "")) != "month" or not ChallengeRules.has_rules(challenge):
		return ""
	var rows: Array[Dictionary] = ChallengeRules.rows(challenge, checked, tested_now(), library)
	var ok: int = 0
	for one: Dictionary in rows:
		ok += 1 if one["state"] == "ok" else 0
	if rows.size() == 1:
		return "rule kept" if ok == 1 else "rule not kept yet"
	return "%d of %d rules kept" % [ok, rows.size()]


## The list under the line: the brief, each rule ticked with what to change,
## and the ways on.
func _fill(said: Dictionary) -> void:
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	_test = null
	_go = null
	if str(said["kind"]) == "prompt":
		_add_words("“%s”" % said["brief"] if not str(said["brief"]).is_empty() else "", 12, Color(0.95, 0.92, 0.85))
		_add_words("No rules: publish this copy in the gallery by %s and it is entered."
			% SharedModels.day_words(str(said["day"])), 12, Color(0.95, 0.92, 0.85, 0.8))
	elif not ChallengeRules.has_rules(challenge):
		_add_words("No rules but its theme: publish it in the gallery with your name on it, then "
			+ "Enter in Share.", 12, Color(0.95, 0.92, 0.85, 0.85))
	else:
		for one: Dictionary in ChallengeRules.rows(challenge, checked, tested_now(), library):
			_add_rule(one)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	_details.add_child(buttons)
	if str(said["kind"]) == "month" and bool(challenge.get("rules", {}).get("tested", false)) \
			and not tested_now() is Dictionary:
		_test = ReloadOffer.button("Testing…" if _testing else "Test it", false)
		_test.tooltip_text = "Run the four tests a publish runs: it stands at every step, every step " \
			+ "reachable, every part made in its colour, nothing loose"
		_test.disabled = _testing
		_test.pressed.connect(run_tested)
		buttons.add_child(_test)
	if str(said["kind"]) == "month" and open_share.is_valid():
		_go = ReloadOffer.button("Publish to enter", passes())
		_go.tooltip_text = "Open Share: Enter there publishes and enters it in one press"
		_go.pressed.connect(func() -> void: open_share.call())
		buttons.add_child(_go)
	if not str(said["page"]).is_empty():
		_page = ReloadOffer.button("See the challenge", false)
		_page.tooltip_text = str(said["page"]).trim_prefix("https://")
		_page.pressed.connect(func() -> void: Outside.open_link(str(said["page"])))
		buttons.add_child(_page)
	if for_a_finger.is_valid():
		for_a_finger.call(self)


func _add_words(text: String, size: int, colour: Color) -> Label:
	if text.is_empty():
		return null
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(200, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	_details.add_child(label)
	return label


## One rule's row: its mark (a tick, a cross, a ring while not known), its
## words, and under them what to change.
func _add_rule(one: Dictionary) -> void:
	var state: String = one["state"]
	var colour: Color = KEPT if state == "ok" else (BROKEN if state == "no" else Color(0.95, 0.92, 0.85, 0.85))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_details.add_child(row)
	if state == "ok":
		var tick := TextureRect.new()
		tick.texture = TICK
		tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tick.custom_minimum_size = Vector2(14, 14)
		tick.modulate = KEPT
		row.add_child(tick)
	else:
		var mark := Label.new()
		mark.text = "×" if state == "no" else "○"
		mark.add_theme_font_size_override("font_size", 14)
		mark.add_theme_color_override("font_color", colour)
		mark.custom_minimum_size = Vector2(14, 0)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(mark)
	var label := Label.new()
	label.text = str(one["words"])
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(180, 0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", colour)
	row.add_child(label)
	label.name = "rule_%s" % one["rule"]
	label.accessibility_name = "%s: %s%s" % [one["words"],
		"kept" if state == "ok" else ("not kept" if state == "no" else "not known yet"),
		(". " + str(one["fix"])) if not str(one["fix"]).is_empty() else ""]
	if not str(one["fix"]).is_empty():
		var fix: Label = _add_words(str(one["fix"]), 12, Color(0.95, 0.92, 0.85, 0.8))
		fix.name = "fix_%s" % one["rule"]


## Show or hide the rules under the line.
func show_rules(on: bool) -> void:
	open_rules = on
	_redraw_line()
	if on:
		_check_soon()


## Hide the line for this challenge: kept, so it stays hidden until the
## next one.
func hide_for_now() -> void:
	var said: Dictionary = about()
	if said.is_empty():
		return
	var kept := ConfigFile.new()
	kept.load(where)
	var hidden_ids: Array = kept.get_value("hidden", str(said["kind"]), [])
	if not int(said["id"]) in hidden_ids:
		hidden_ids.append(int(said["id"]))
	kept.set_value("hidden", str(said["kind"]), hidden_ids.slice(-20))
	kept.save(where)
	open_rules = false
	_redraw_line()


func is_hidden(said: Dictionary) -> bool:
	var kept := ConfigFile.new()
	if kept.load(where) != OK:
		return false
	return int(said["id"]) in (kept.get_value("hidden", str(said["kind"]), []) as Array)


func _today() -> String:
	return today_for_probe if not today_for_probe.is_empty() else ChallengeRules.today()


# -- ticked live ---------------------------------------------------------------

func _tick() -> void:
	if not is_inside_tree():
		return
	# The sign-in came or went, or an hour went by: asked again.
	var now: int = Time.get_ticks_msec()
	if shared != null and not _checking and (_asked_ms < 0 or now - _asked_ms > ASK_EVERY_MS
			or (account != null and account.signed_in() != (_asked_with != "") and not account.renewing)):
		if _asked_ms < 0 or now - _asked_ms > 5000:
			ask()
	_draw_if_moved()
	if store == null or challenge.is_empty() or not ChallengeRules.has_rules(challenge):
		return
	if store.world.revision != checked_revision and now - _last_check_ms >= CHECK_EVERY_MS:
		check_now()


## The quick build came or went with the copy, or its brief was read: the
## line drawn again.
var _drawn_about: String = ""
func _draw_if_moved() -> void:
	var said: String = str(about()) + str(prompt_notice.visible if prompt_notice != null else false)
	if said != _drawn_about:
		_drawn_about = said
		_redraw_line()


func _check_soon() -> void:
	if store != null and not challenge.is_empty() and ChallengeRules.has_rules(challenge) and not _checking:
		_last_check_ms = mini(_last_check_ms, Time.get_ticks_msec() - CHECK_EVERY_MS)


## Tick the rules on the model as it is now: its text as a publish would
## write it (the autosave's, a big one over frames), read as checkModel reads
## it, on a worker when it is big, spelled and checked here.
func check_now() -> void:
	if _checking or store == null or challenge.is_empty():
		return
	_checking = true
	_last_check_ms = Time.get_ticks_msec()
	var revision: int = store.world.revision
	var text: String = await store.text_for_rules()
	# Changed while it was written: ticked again on the next round.
	if text.is_empty():
		_checking = false
		return
	var read_out: Dictionary = {}
	if text.length() >= READ_ON_A_WORKER:
		var holder: Array = [{}]
		var task: int = WorkerThreadPool.add_task(func() -> void: holder[0] = ChallengeRules.read(text))
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		read_out = holder[0]
	else:
		read_out = ChallengeRules.read(text)
	_checking = false
	if challenge.is_empty():
		return
	var facts: Dictionary = read_out if read_out.has("error") \
		else {"parts": read_out["parts"], "needs": ChallengeRules.spelled_needs(read_out["needs"], library)}
	_kept_facts = facts
	# An empty baseplate has no parts to tick: every rule waits.
	checked = {} if facts.has("error") else ChallengeRules.check(challenge["rules"], facts, tested_now() is Dictionary
		and _passed(tested_now()))
	checked_revision = revision
	if revision != tested_revision:
		tested_tests = null
	_redraw_line()
	ticked.emit()


## The Tested finding for the model as it is now, else null.
func tested_now() -> Variant:
	if store == null or tested_revision != store.world.revision:
		return null
	return tested_tests


static func _passed(tests: Variant) -> bool:
	if not tests is Dictionary:
		return false
	for test: String in ["stands", "steps", "parts", "whole"]:
		var one: Variant = (tests as Dictionary).get(test)
		if not one is Dictionary or not bool((one as Dictionary).get("ok", false)):
			return false
	return true


## Test it: the four tests a publish runs (SharedPages.attach_tested), on the
## model as it is; kept until it changes.
func run_tested() -> void:
	if _testing or store == null:
		return
	_testing = true
	_redraw_line()
	var revision: int = store.world.revision
	var title: String = store.title if not store.title.is_empty() else "Model"
	var text: String = await store.text_for_file(title, "Writing “%s” to test it…" % title)
	var job: Working.Job = Working.begin("Testing “%s” as a publish would…" % title)
	await job.shown()
	var made: Dictionary = await SharedPages.attach_tested(text, library, store, job)
	job.end()
	_testing = false
	var found: Dictionary = made.get("tested", {})
	if found.has("tests") and store.world.revision == revision:
		found_tested(found["tests"], revision)
	_redraw_line()


## A finding of the four tests for the model at [param revision]: from Test
## it, or from a publish (SharePanel).
func found_tested(tests: Dictionary, revision: int) -> void:
	tested_tests = tests
	tested_revision = revision
	if checked_revision == revision and not challenge.is_empty():
		checked = {} if _kept_facts.has("error") or _kept_facts.is_empty() \
			else ChallengeRules.check(challenge["rules"], _kept_facts, _passed(tests))
	_redraw_line()
	ticked.emit()


## The parts and needs last ticked (ChallengeRules.facts_of's).
var _kept_facts: Dictionary = {}


## Whether the month's challenge's rules pass on the model as it is now, a
## Tested not known counted as passing (a publish tests it, and the site
## says why when it does not): what Share says Enter on.
func passes() -> bool:
	if challenge.is_empty():
		return false
	if not ChallengeRules.has_rules(challenge):
		return true
	if store == null or checked_revision != store.world.revision or checked.is_empty():
		return false
	for one: Dictionary in ChallengeRules.rows(challenge, checked, tested_now(), library):
		if one["state"] == "no" or (one["state"] == "unknown" and one["rule"] != "tested"):
			return false
	return true


## What to change for the first rule the model does not keep (its fix,
## which names the rule: "Take 12 parts away: it has 162, and the most is
## 150."), its words when it has none; "" when none fails.
func first_failed() -> String:
	for one: Dictionary in ChallengeRules.rows(challenge, checked, tested_now(), library):
		if one["state"] == "no":
			return str(one["fix"]) if not str(one["fix"]).is_empty() else str(one["words"])
	return ""


## For a probe and for the page (Main._tell_page): what the line says.
func page_state() -> Dictionary:
	return {"shown": visible, "about": about(), "text": _toggle.text if _toggle != null else "",
		"open": open_rules, "checked": checked.duplicate(true), "checked_revision": checked_revision,
		"passes": passes(), "first_failed": first_failed(),
		"rows": ChallengeRules.rows(challenge, checked, tested_now(), library) if not challenge.is_empty() else []}


func controls_by_name() -> Dictionary:
	var named: Dictionary = {}
	if visible:
		named["challenge_line"] = _toggle
		named["challenge_hide"] = _hide
	if _details != null and _details.visible:
		if _test != null:
			named["challenge_test"] = _test
		if _go != null:
			named["challenge_publish"] = _go
		if _page != null and is_instance_valid(_page) and _page.get_parent() != null:
			named["challenge_page"] = _page
	return named
