## A build party (APP_UX5 buildparty, 2026-11-06): one shared model built
## by several phones at once, as families and classes build a set together
## (LEGO Builder's Build Together). Build it, Build together on the model's
## link: one phone starts a party and is given a short code to say across
## the table; up to three more on the same link type it and join, with no
## account (api/together.js, its build party block). The phone that started
## deals the model out once everyone is in; each phone builds its own share
## in Build it, a part at a time, with everyone's progress along its top
## ("Mia 4 of 9"); and once every phone is done, each is shown the step
## that joins the shares.
##
## How it is dealt ([method shares_of]): the model's sub-assemblies, each whole,
## and its main build; while there are fewer of those than phones, the
## biggest is cut in two at the step that halves its parts most nearly, so
## a model with no sub-assemblies (the car) is dealt in runs of its steps.
## Then each goes to the phone with fewest parts so far, biggest first, and
## the phones' shares are numbered by their first step, so the phone that
## started builds the bottom of the model. Every phone works the deal out
## itself from the same steps and the number of phones, so nothing but that
## number is sent. A run is built as a piece of its own and pressed on in
## the joining step; a sub-assembly another phone builds is put on there too
## ([method steps_for]).
##
## The party itself is the relay's log of what each phone said: joined, the
## deal, how far along it is, left. Each phone folds the same words in the
## same order, so all agree on who sits where. A phone keeps a random id of
## its own (in the browser, beside the place kept per link), so one that
## leaves and joins again by the code has its seat, its share and its
## place back.
class_name BuildParty
extends Node

## Anything changed: who is in it, the deal, someone's progress.
signal changed

const PHONES := 4
## The code's letters (api/together.js PARTY_LETTERS): no vowels, no 0, O,
## 1 or I, so it is never a word and never misread.
const LETTERS := "BCDFGHJKLMNPQRSTVWXZ23456789"
## Each seat's colour, as a booklet's callout numbers are lit: yellow, blue,
## red, green.
const COLOURS: Array[Color] = [Color(0.98, 0.78, 0.12), Color(0.24, 0.56, 0.96),
	Color(0.92, 0.26, 0.24), Color(0.30, 0.78, 0.42)]
const KEPT_AS := "brickworks.party"
const NAME_MOST := 20
## How long a poll may wait on the server, and how long after a refusal or
## no answer before asking again.
const POLL_S := 25.0
const AGAIN_MS := 1500

var base_url: String = ""
## The shared model's link (api/share.js id).
var link: String = ""
## This phone's own id, kept for the link's parties; its name to the others.
var phone: String = ""
var called: String = ""
## In a party now, and its code; this phone as the others see it (who).
var live: bool = false
var code: String = ""
var me: String = ""
## Every seat, in the order they joined: {who, name, at: {done, of, page,
## part, finished}, left}.
var seats: Array[Dictionary] = []
## How many phones it was dealt for; 0 until the first phone deals.
var dealt: int = 0
## What went wrong last, in words for a person, or "".
var trouble: String = ""
## The last number heard; when each seat's progress last changed, by who,
## in ms (a check times a part crossing from it).
var seq: int = 0
var heard_at: Dictionary = {}

var _cid: int = 0
var _generation: int = 0
var _sending: bool = false
var _at_wanted: Dictionary = {}
var _at_sent: Dictionary = {}


## A party for [param at_link], its phone and name as this device keeps them.
func setup(at_link: String) -> void:
	link = at_link
	base_url = Deployment.api_base()
	var kept: Dictionary = recall()
	phone = str(kept.get("phone", ""))
	if not RegEx.create_from_string("^[a-z0-9]{6,16}$").search(phone):
		phone = _new_phone()
	called = str(kept.get("name", ""))
	code = str((kept.get("codes", {}) as Dictionary).get(link, "")) if kept.get("codes") is Dictionary else ""
	_keep()


static func _new_phone() -> String:
	var letters := "abcdefghijklmnopqrstuvwxyz0123456789"
	var out: String = ""
	for _n: int in 12:
		out += letters[randi() % letters.length()]
	return out


# -- the party ----------------------------------------------------------------

## Start a party as [param as_name]: "" when it is started, else why not.
func start(as_name: String) -> String:
	called = clean_name(as_name)
	var got: Array = await _ask("party_start", {"link": link, "phone": phone, "name": called})
	return _joined(got, "Starting a build")


## Join the party [param with_code] as [param as_name]: "" when in, else why
## not. A phone that was in it has its seat back.
func join(with_code: String, as_name: String) -> String:
	called = clean_name(as_name)
	var wanted: String = clean_code(with_code)
	if wanted.length() != 4:
		trouble = "A code is four letters and numbers, as the other phone shows it."
		return trouble
	var got: Array = await _ask("party_join", {"link": link, "code": wanted, "phone": phone, "name": called})
	return _joined(got, "Joining the build")


func _joined(got: Array, doing: String) -> String:
	if int(got[0]) != 200:
		trouble = _trouble_of(got, doing)
		changed.emit()
		return trouble
	var body: Dictionary = got[1]
	_generation += 1
	trouble = ""
	live = true
	code = str(body.get("code", ""))
	me = str(body.get("me", ""))
	seats.clear()
	dealt = 0
	seq = 0
	_at_sent = {}
	_fold(body.get("ops", []) as Array)
	seq = maxi(seq, int(body.get("seq", 0)))
	_keep()
	changed.emit()
	_poll_loop(_generation)
	return ""


## Deal it out for everyone in it now: the first phone's to press.
func deal() -> String:
	if not live or seat() != 1 or dealt > 0:
		return "Only the phone that started the build deals it."
	var got: Array = await _send({"deal": seats.size()})
	if int(got[0]) != 200:
		trouble = _trouble_of(got, "Dealing it out")
		changed.emit()
		return trouble
	# Taken at once, not when the poll brings it back.
	if dealt == 0:
		dealt = seats.size()
		changed.emit()
	return ""


## How far along this phone is: [param done] parts of [param of] down, on
## [param page] at [param part], and whether it pressed on past its last.
## Shown here at once; sent as soon as the last send is answered, only the
## newest.
func tell(done: int, of: int, page: int, part: int, finished: bool) -> void:
	if not live:
		return
	var at: Dictionary = {"done": done, "of": of, "page": page, "part": part, "finished": finished}
	var mine: Dictionary = _seat_of(me)
	if not mine.is_empty() and mine.get("at", {}) != at:
		mine["at"] = at
		heard_at[me] = Time.get_ticks_msec()
		changed.emit()
	_at_wanted = at
	if _sending:
		return
	_sending = true
	var generation: int = _generation
	while live and generation == _generation and _at_wanted != _at_sent:
		var sending: Dictionary = _at_wanted.duplicate()
		var got: Array = await _send({"at": sending})
		if int(got[0]) == 200:
			_at_sent = sending
		else:
			await get_tree().create_timer(AGAIN_MS / 1000.0).timeout
	_sending = false


## Leave the party: the others are told; the code is kept, to join again.
func leave() -> void:
	if not live:
		return
	var got: Array = await _send({"left": true})
	if int(got[0]) != 200:
		trouble = _trouble_of(got, "Leaving")
	live = false
	_generation += 1
	changed.emit()


func _send(said: Dictionary) -> Array:
	_cid += 1
	return await _ask("party_send", {"link": link, "code": code, "phone": phone, "cid": _cid, "said": said})


func _poll_loop(generation: int) -> void:
	while live and generation == _generation:
		var got: Array = await _ask("party_poll", {"link": link, "code": code, "after": seq}, POLL_S)
		if not live or generation != _generation:
			return
		if int(got[0]) == 200:
			var body: Dictionary = got[1]
			_fold(body.get("ops", []) as Array)
			seq = maxi(seq, int(body.get("seq", seq)))
			continue
		if int(got[0]) in [404, 410]:
			trouble = _trouble_of(got, "The build")
			live = false
			changed.emit()
			return
		await get_tree().create_timer(AGAIN_MS / 1000.0).timeout


## The words [param ops] said, in their order: seats, the deal, progress.
func _fold(ops: Array) -> void:
	var any: bool = false
	for op: Variant in ops:
		if not op is Dictionary:
			continue
		var number: int = int((op as Dictionary).get("seq", 0))
		if number <= seq and number > 0:
			continue
		seq = maxi(seq, number)
		var who: String = str(op.get("who", ""))
		var said: Dictionary = op.get("said", {}) if op.get("said") is Dictionary else {}
		var seated: Dictionary = _seat_of(who)
		if said.has("join"):
			var given: Dictionary = said["join"] if said["join"] is Dictionary else {}
			# A name a person gave, drawn as it is in every language.
			Language.keep_name(str(given.get("name", "")))
			if seated.is_empty():
				seats.append({"who": who, "name": str(given.get("name", "")), "at": {}, "left": false})
			else:
				seated["name"] = str(given.get("name", ""))
				seated["left"] = false
		elif said.has("deal"):
			if dealt == 0 and not seats.is_empty() and seats[0]["who"] == who:
				dealt = clampi(int(said["deal"]), 1, PHONES)
		elif said.has("at") and not seated.is_empty() and said["at"] is Dictionary:
			if seated["at"] != said["at"]:
				seated["at"] = said["at"]
				heard_at[who] = Time.get_ticks_msec()
		elif said.has("left") and not seated.is_empty():
			seated["left"] = true
		any = true
	if any:
		changed.emit()


func _seat_of(who: String) -> Dictionary:
	for one: Dictionary in seats:
		if one["who"] == who:
			return one
	return {}


# -- what it says ---------------------------------------------------------------

## This phone's seat, from 1; 0 when it has none.
func seat() -> int:
	for n: int in seats.size():
		if seats[n]["who"] == me:
			return n + 1
	return 0


## A seat's name: its own, or "Builder 2".
func name_of(seat_index: int) -> String:
	var given: String = str(seats[seat_index]["name"]) if seat_index < seats.size() else ""
	return given if not given.is_empty() else "Builder %d" % (seat_index + 1)


## This phone's own progress, as last told or heard.
func mine() -> Dictionary:
	var seated: Dictionary = _seat_of(me)
	return seated.get("at", {}) if not seated.is_empty() else {}


## Every phone dealt a share has pressed on past its last part.
func all_finished() -> bool:
	if dealt == 0:
		return false
	for n: int in mini(dealt, seats.size()):
		if not bool((seats[n]["at"] as Dictionary).get("finished", false)):
			return false
	return true


## Each seat as a check and the step player show it: {name, colour, done,
## of, finished, left, me}.
func board() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: int in seats.size():
		var at: Dictionary = seats[n]["at"]
		out.append({"name": name_of(n), "colour": COLOURS[n % COLOURS.size()], "seat": n + 1,
			"done": int(at.get("done", 0)), "of": int(at.get("of", 0)),
			"finished": bool(at.get("finished", false)), "left": bool(seats[n]["left"]),
			"me": seats[n]["who"] == me})
	return out


func page_state() -> Dictionary:
	var shown: Array = []
	for one: Dictionary in board():
		var each: Dictionary = one.duplicate()
		each["colour"] = "#" + (one["colour"] as Color).to_html(false)
		shown.append(each)
	return {"live": live, "code": code, "seat": seat(), "dealt": dealt, "seats": shown,
		"all_finished": all_finished(), "trouble": trouble, "name": called}


## A name as the others are shown it: one line, at most [constant NAME_MOST]
## characters (the server says whether it may be shown).
static func clean_name(said: String) -> String:
	var plain: String = said.replace("\n", " ").replace("\t", " ").strip_edges()
	while plain.contains("  "):
		plain = plain.replace("  ", " ")
	return plain.left(NAME_MOST)


## A code as typed: upper case, spaces and dashes out.
static func clean_code(said: String) -> String:
	return said.to_upper().replace(" ", "").replace("-", "").strip_edges()


static func _trouble_of(got: Array, doing: String) -> String:
	var body: Variant = got[1]
	var why: String = str((body as Dictionary).get("error", "")) if body is Dictionary else ""
	if int(got[0]) == 0:
		return "%s: Brickworks could not be reached. Check the connection and try again." % doing
	if why.is_empty():
		return "%s: the server said %d." % [doing, int(got[0])]
	return why.substr(0, 1).to_upper() + why.substr(1) + ("" if why.ends_with(".") else ".")


# -- kept on this device ----------------------------------------------------------
#
# The phone's id and name, and the last code per link: in the browser's
# localStorage, as the place reached is kept (BuildSteps.remember); off the
# web for this run only, as the viewer writes nothing to disk.

static var _kept_here: Dictionary = {}


static func recall() -> Dictionary:
	if OS.has_feature("web"):
		var text: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem(%s)||''}catch(e){return ''}})()"
			% JSON.stringify(KEPT_AS), true)
		var json := JSON.new()
		return json.data if text is String and json.parse(text) == OK and json.data is Dictionary else {}
	return _kept_here.duplicate(true)


func _keep() -> void:
	var kept: Dictionary = recall()
	var codes: Dictionary = kept.get("codes", {}) if kept.get("codes") is Dictionary else {}
	if not code.is_empty():
		codes[link] = code
	# A handful of links at most: the newest kept.
	while codes.size() > 8:
		codes.erase(codes.keys()[0])
	var now: Dictionary = {"phone": phone, "name": called, "codes": codes}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.setItem(%s,%s)}catch(e){}})()"
			% [JSON.stringify(KEPT_AS), JSON.stringify(JSON.stringify(now))], true)
	else:
		_kept_here = now


# -- the server -------------------------------------------------------------------

## [code, answer]: 0 and {} when nothing came back.
func _ask(op: String, body: Dictionary, timeout: float = 20.0) -> Array:
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var headers := PackedStringArray(["content-type: application/json"])
	var sent: int = http.request("%s/api/together?op=%s" % [base_url, op], headers,
		HTTPClient.METHOD_POST, JSON.stringify(body, "", false, true))
	if sent != OK:
		http.queue_free()
		return [0, {}]
	var done: Array = await http.request_completed
	http.queue_free()
	var json := JSON.new()
	var text: String = (done[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Dictionary = json.data if json.parse(text) == OK and json.data is Dictionary else {}
	return [int(done[1]) if int(done[0]) == HTTPRequest.RESULT_SUCCESS else 0, parsed]


func _exit_tree() -> void:
	_generation += 1


# -- the deal ---------------------------------------------------------------------

## The model dealt out to [param phones] phones: each phone's share, the
## bricks it builds (id -> true), in seat order. [param steps] are the
## model's (StepsBar.steps, as Build it's pages are); [param ground] the
## baseplate's, which nobody builds.
static func shares_of(steps: Array[Instructions.Step], phones: int, ground: Dictionary = {}) -> Array[Dictionary]:
	phones = clampi(phones, 1, PHONES)
	# Each brick on the step that first puts it down.
	var added: Array[PackedInt64Array] = []
	var ranked: Dictionary = {}
	for step: Instructions.Step in steps:
		var fresh := PackedInt64Array()
		for brick_id: int in step.brick_ids:
			if ranked.has(brick_id) or ground.has(brick_id):
				continue
			ranked[brick_id] = true
			fresh.append(brick_id)
		added.append(fresh)
	# The main build, and each sub-assembly built on the side whole: a run
	# of step indices each.
	var units: Array[PackedInt32Array] = [PackedInt32Array()]
	var callouts: Dictionary = {}
	for n: int in steps.size():
		if added[n].is_empty():
			continue
		var step: Instructions.Step = steps[n]
		if step.in_callout():
			if not callouts.has(step.callout):
				callouts[step.callout] = units.size()
				units.append(PackedInt32Array())
			units[int(callouts[step.callout])].append(n)
		else:
			units[0].append(n)
	units.assign(units.filter(func(unit: PackedInt32Array) -> bool: return not unit.is_empty()))
	# Fewer than the phones: the biggest that has two steps or more cut where
	# it halves its parts most nearly, the steps either side in their order.
	while units.size() < phones:
		var biggest: int = -1
		for n: int in units.size():
			if units[n].size() >= 2 and (biggest < 0 or _size_of(units[n], added) > _size_of(units[biggest], added)):
				biggest = n
		if biggest < 0:
			break
		var unit: PackedInt32Array = units[biggest]
		var whole: int = _size_of(unit, added)
		var below: int = 0
		var cut: int = 1
		var best: int = 1 << 30
		for k: int in range(1, unit.size()):
			below += added[unit[k - 1]].size()
			var off: int = absi(whole - 2 * below)
			if off < best:
				best = off
				cut = k
		units[biggest] = unit.slice(0, cut)
		units.insert(biggest + 1, unit.slice(cut))
	# Biggest first, each to the phone with fewest parts so far.
	var order: Array = range(units.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var size_a: int = _size_of(units[a], added)
		var size_b: int = _size_of(units[b], added)
		return size_a > size_b if size_a != size_b else units[a][0] < units[b][0])
	var shares: Array = []
	for _n: int in phones:
		shares.append({"parts": 0, "first": 1 << 30, "bricks": {}})
	for n: int in order:
		var least: int = 0
		for k: int in range(1, phones):
			if int(shares[k]["parts"]) < int(shares[least]["parts"]):
				least = k
		var share: Dictionary = shares[least]
		for index: int in units[n]:
			for brick_id: int in added[index]:
				share["bricks"][brick_id] = true
			share["parts"] = int(share["parts"]) + added[index].size()
			share["first"] = mini(int(share["first"]), index)
	# Numbered by their first step: the first phone builds the bottom.
	shares.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["first"]) < int(b["first"]))
	var out: Array[Dictionary] = []
	for share: Dictionary in shares:
		out.append(share["bricks"])
	return out


static func _size_of(unit: PackedInt32Array, added: Array[PackedInt64Array]) -> int:
	var total: int = 0
	for index: int in unit:
		total += added[index].size()
	return total


## The pages a phone builds [param share] from: the model's steps with only
## its own bricks in them, numbered from 1 among its own, and last the step
## that joins the shares, which puts down everybody else's. A sub-assembly
## of its own is put on where its step says; one another phone builds is
## put on in the joining step, the loose parts beside it still on its own
## page.
static func steps_for(steps: Array[Instructions.Step], share: Dictionary,
		ground: Dictionary = {}) -> Array[Instructions.Step]:
	var out: Array[Instructions.Step] = []
	var theirs := PackedInt64Array()
	var counted: Dictionary = {}
	for step: Instructions.Step in steps:
		var own := PackedInt64Array()
		for brick_id: int in step.brick_ids:
			if share.has(brick_id):
				own.append(brick_id)
			elif not ground.has(brick_id) and not counted.has(brick_id):
				counted[brick_id] = true
				theirs.append(brick_id)
		var puts_own_on: bool = step.attaches() and not step.copies.is_empty()
		for copy: PackedInt64Array in step.copies:
			for brick_id: int in copy:
				if not share.has(brick_id):
					puts_own_on = false
		if own.is_empty() and not puts_own_on:
			continue
		var page := Instructions.Step.new()
		page.index = out.size() + 1
		# Numbered among its own: a callout's step too, which in a booklet
		# carries the number of the step it is built for.
		page.number = page.index
		page.brick_ids = own
		page.unsupported = step.unsupported
		page.section = step.section
		page.authored_in = step.authored_in
		page.authored_step = step.authored_step
		if step.in_callout() or puts_own_on:
			page.assembly = step.assembly
			page.callout = step.callout
			page.callout_step = step.callout_step
			page.callout_steps = step.callout_steps
			page.times = step.times
			page.figure = step.figure
			page.copies = step.copies
			for brick_id: int in step.shown_ids:
				if share.has(brick_id):
					page.shown_ids.append(brick_id)
		out.append(page)
	var joining := Instructions.Step.new()
	joining.index = out.size() + 1
	# "Step 3 of 9": of this phone's own steps, the joining step apart.
	joining.number = maxi(out.size(), 1)
	joining.brick_ids = theirs
	out.append(joining)
	return out
