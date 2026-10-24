## Build together: two people build one model at once, live, each in their
## own browser or desktop app (File, Build together…; api/together.js,
## supabase/together.sql, docs/TOGETHER.md).
##
## The owner starts a session and is given a link; a signed-in person who
## opens it joins, and is given the model as it began and every change since.
## From then on every change either side makes to a part (put down, moved,
## turned, painted, taken off, put in a sub-model or a step) is sent as the
## part's whole state, by an id the session gives it (a uid: who first put
## it down and a count), and the server numbers every change in one order.
##
## Each side puts the numbered changes down in that order, and keeps its own
## changes shown until they come back numbered: a part another moved while
## mine was on its way stays where I put it until mine is numbered, and ends
## where the later of the two put it. So a part two people move at once
## settles the same way on both sides, and once nothing is on its way the
## model is the same everywhere, part for part, and its file byte for byte.
##
## Undo is each person's own. A step undone puts back the parts it changed,
## as they were, only where they are still as that step left them: a part
## somebody else has changed since is theirs now, and is left, and the line
## says so. Nobody's undo takes back anybody else's part.
##
## Nothing here runs outside a session: _process returns at once.
class_name Together
extends Node

## The session started, joined, ended or left, or who is in it changed.
signal changed
## Something to say on the status line: another side changed a part this
## side was changing, an undo left a part somebody changed since.
signal said(words: String)

var world: BrickWorld
var builder: Builder
var store: ModelStore
var account: Account
var bar: ModelBar
var base_url: String = ""
## More headers for every request: a probe's pass through a protected
## preview deployment (src/dev/together_probe.gd).
var extra_headers: PackedStringArray = PackedStringArray()

## In a session now.
var live: bool = false
## This side started it.
var owns: bool = false
## The session's link, to send to the other person.
var link: String = ""
## Who is in it, as the server says: [{who, name, owner, me, here}].
var people: Array = []
## Why the last session stopped, for the panel to say.
var ended_words: String = ""
## The last change number put down here.
var seq: int = 0
## The time from a change sent here to its number coming back, in ms, the
## last [constant TIMES_KEPT]: the panel and tools/web/together_flow.mjs.
var round_trips: Array[int] = []
const TIMES_KEPT := 200

var _token: String = ""
var _client: String = ""
var _cid: int = 0
var _next_uid: int = 0
var _generation: int = -1
## brick id -> uid, and uid -> brick id.
var _uids: Dictionary = {}
var _ids: Dictionary = {}
## uid -> state as the numbered changes have it, every side the same.
var _confirmed: Dictionary = {}
## uid -> state as this world has it: what a change here is told from.
var _shown: Dictionary = {}
## This side's changes not yet back numbered, oldest first: [{cid, changes,
## at}]. The first [member _in_flight] of them are on their way.
var _pending: Array = []
var _in_flight: int = 0
## uid -> state of a part another side put down whose geometry is still on
## its way here (the web fetches what it has not got).
var _awaiting: Dictionary = {}
## Each person's own steps: [{forward: {uid: state}, back: {uid: state}}].
var _undo: Array = []
var _redo: Array = []
var _open_back: Dictionary = {}
var _open_forward: Dictionary = {}
var _open_at: int = 0
var _heard: Array = []
var _polling: int = 0
var _seen: String = ""
var _sending: bool = false
## uid -> when this side's last change to it came back numbered: another's
## change to it numbered within [constant OVERTAKEN_MS] of it was made
## without seeing it (a change takes about that long to reach the other
## side), and is said, so a change overtaken is never silent.
var _mine_at: Dictionary = {}
const OVERTAKEN_MS := 1500

## What the model is besides its parts, carried the same way, each by a key
## of its own with its words as the file has them (_meta_now): its name, the
## floor, the colours of hidden parts, motions, the booklet's looks, the
## steps of sub-assembly copies, and sections broken out. And "~part:<id>":
## the LDraw files of a part made in the app, sent once with the first part
## of it put down, so the other side can draw it.
const META_KEYS: Array[String] = ["~title", "~floor", "~hidden", "~motions", "~looks",
	"~unit_steps", "~broken"]
const MADE_PART := "~part:"
## How often the model's own state is read for a change of it.
const META_MS := 250
var _meta_at: int = 0
var _parts_sent: Dictionary = {}

## The highest cid put down of each copy: a send taken twice (its answer lost
## on the way back, sent again) is put down once, the same everywhere.
var _last_cid: Dictionary = {}

## The chat, oldest first: [{who, name, text, mine}]. Why this person may not
## chat, in words, or "" (api/together.js: comments' rule, and an account
## under 13 is not shown it).
var messages: Array = []
var chat_words: String = ""
const MESSAGES_KEPT := 200

## Where each other person is working, drawn in the view: who -> a marker.
var _markers: Dictionary = {}
var _point_at: int = 0
var _pointed: Variant = null
var _pointing: bool = false
const POINT_MS := 250
const MARKER_COLOURS: Array[Color] = [Color("#e8590c"), Color("#1c7ed6"), Color("#2f9e44"),
	Color("#ae3ec9"), Color("#f08c00"), Color("#0c8599")]

## Whether this copy keeps the session it is in with the tab
## (TabSession.path), so a reload or a restart goes back into it by itself.
var keeps_place: bool = true
const KEPT_FILE := "together.txt"

## A step left open this long with nothing more to it is closed: a change
## that kept no history step of the builder's (a pose, a tool's).
const STEP_IDLE_MS := 1500
const STATE_PARTS := 6


func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		_tell_page()
	if not live:
		return
	# The model was replaced under the session: another opened, New, Clear.
	if world.generation() != _generation:
		_stop("You opened another model, so you left the session." if not owns
			else "You opened another model, so the session ended.", true)
		return
	_capture()
	if not _open_back.is_empty() and Time.get_ticks_msec() - _open_at > STEP_IDLE_MS:
		_close_step()
	_flush()
	_point()


# -- starting, joining, ending ---------------------------------------------

## Start a session on the model on the baseplate. "" when it started, or why
## not.
func start() -> String:
	if live:
		return ""
	if account == null or not account.signed_in():
		return "Sign in to build together."
	if store.laying or not store.awaited.is_empty():
		return "The model is still opening. Try again in a moment."
	_reset()
	_client = _new_client()
	owns = true
	_generation = world.generation()
	# What the lift settles to later would move every part, on every side.
	store._lift_unsure = false
	var bricks: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if store.scenery.has(brick.id):
			continue
		var uid: String = "%s.%d" % [_client, _next_uid]
		_next_uid += 1
		_map(uid, brick.id)
		var state: Array = state_of(brick)
		_shown[uid] = state
		_confirmed[uid] = state
		bricks.append([uid] + state)
	var meta: Dictionary = _meta_now()
	for key: String in meta:
		_shown[key] = meta[key]
		_confirmed[key] = meta[key]
	var snapshot: Dictionary = {"text": store.to_text(store.title), "lift": store.lift().y,
		"bricks": bricks, "meta": meta}
	var got: Array = await _ask("start", {"title": store.title, "snapshot": snapshot})
	if int(got[0]) != 200:
		_reset()
		return _trouble(got, "Could not start the session")
	var body: Dictionary = got[1]
	_token = str(body.get("s", ""))
	link = str(body.get("link", ""))
	_keep_place()
	# Steps from before the session undo nothing in it: they would put back
	# parts somebody else may have changed since.
	builder.forget_history()
	live = true
	_heard = _model_now()
	ended_words = ""
	changed.emit()
	_poll_loop()
	return ""


## Join by a link, or its secret alone. The model here is replaced by the
## session's (asked first when it has changes not saved, but not when
## [param rejoining]: this tab was in that session before a reload or a
## restart, and what is on its baseplate is the session's). "" when joined,
## or why not.
func join(address: String, rejoining: bool = false) -> String:
	var token: String = secret_in(address)
	if token.is_empty():
		return "That is not a Build together link."
	if live:
		if token == _token:
			return ""
		return "Leave this session first."
	if account == null or not account.signed_in():
		return "Sign in to build together."
	var got: Array = await _ask("join", {"s": token})
	if int(got[0]) != 200:
		# Ended, or this account taken out: not gone back into after a reload.
		if int(got[0]) in [403, 404, 410] and secret_in(kept_secret()) == token:
			_forget_place()
		return _trouble(got, "Could not join")
	var body: Dictionary = got[1]
	var snapshot: Variant = body.get("snapshot")
	if not snapshot is Dictionary:
		return "The session sent no model."
	var title: String = str(body.get("title", "Model"))
	if bar != null and not rejoining \
			and not await bar.ask_to_replace("“%s” to build together" % title):
		return "Not joined: the model here is kept."
	var text: String = str((snapshot as Dictionary).get("text", ""))
	if bar != null:
		var opened: Dictionary = await bar.open_text_with_progress(text, title)
		if not str(opened["error"]).is_empty():
			return "Could not open the session's model: %s" % opened["error"]
	else:
		var opened: Dictionary = await store.open_text_fetched(text, title)
		if not str(opened["error"]).is_empty():
			return "Could not open the session's model: %s" % opened["error"]
	# Parts on their way, and a big model laid over frames, down first.
	var until: int = Time.get_ticks_msec() + 90000
	while (store.laying or not store.awaited.is_empty()) and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	_reset()
	_client = _new_client()
	owns = bool(body.get("owner", false))
	_token = token
	link = str(body.get("link", ""))
	_generation = world.generation()
	store._lift_unsure = false
	_lay_snapshot(snapshot as Dictionary)
	# Its floor laid and the view framed on it, as any model opened is.
	if bar != null:
		bar.opened.emit(world.brick_count())
	builder.forget_history()
	people = body.get("people", []) as Array
	_seen = str(body.get("seen", ""))
	chat_words = str(body.get("chat", ""))
	_keep_place()
	live = true
	_heard = _model_now()
	ended_words = ""
	changed.emit()
	_poll_loop()
	return ""


## The owner ends the session for everyone; the model stays the owner's, and
## saves as it always does.
func end() -> void:
	if not live or not owns:
		return
	var token: String = _token
	_capture()
	await _flush_all()
	_stop("You ended the session. The model is yours, as it always was.")
	await _ask("end", {"s": token})


## Leave the session; the model as it stands stays on this baseplate.
func leave() -> void:
	if not live:
		return
	if owns:
		await end()
		return
	var token: String = _token
	_capture()
	await _flush_all()
	_stop("You left the session. What was built is still here, as yours to keep or not.")
	await _ask("leave", {"s": token})


## The owner takes [param who] out of the session: refused from then on.
func remove(who: String) -> void:
	if not live or not owns:
		return
	var got: Array = await _ask("remove", {"s": _token, "who": who})
	if int(got[0]) == 200:
		people = (got[1] as Dictionary).get("people", people) as Array
		changed.emit()


func _stop(words: String, tell_server: bool = false) -> void:
	var token: String = _token
	var was_owner: bool = owns
	live = false
	_forget_place()
	_show_pointers()
	ended_words = words
	_polling += 1
	# Steps from the session undo nothing after it: other people's parts.
	builder.forget_history()
	said.emit(words)
	changed.emit()
	if tell_server and not token.is_empty():
		await _ask("end" if was_owner else "leave", {"s": token})


func _reset() -> void:
	live = false
	owns = false
	link = ""
	people = []
	seq = 0
	_token = ""
	_cid = 0
	_next_uid = 0
	_uids.clear()
	_ids.clear()
	_confirmed.clear()
	_shown.clear()
	_pending.clear()
	_in_flight = 0
	_awaiting.clear()
	_undo.clear()
	_redo.clear()
	_open_back.clear()
	_open_forward.clear()
	_seen = ""
	_polling += 1
	_mine_at.clear()
	_parts_sent.clear()
	_last_cid.clear()
	messages.clear()
	chat_words = ""
	_pointed = null
	round_trips.clear()


## The secret from a Build together link (…/app?together=SECRET), or the
## secret itself; "" when it is neither.
static func secret_in(address: String) -> String:
	var said: String = address.strip_edges()
	var at: int = said.find("together=")
	if at >= 0:
		said = said.substr(at + 9)
		for stop: String in ["&", "#", " "]:
			if said.find(stop) >= 0:
				said = said.substr(0, said.find(stop))
	return said if RegEx.create_from_string("^[A-Za-z0-9_-]{32}$").search(said) != null else ""


static func _new_client() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(5)
	var out: String = ""
	for b: int in bytes:
		out += "%02x" % b
	return out


# -- a part's state ----------------------------------------------------------

## What a part is, as the session sends it: [part, colour, its transform as
## 12 numbers, group, unit, step].
static func state_of(brick: BrickWorld.Brick) -> Array:
	var t: Transform3D = brick.transform
	return [brick.part_id, brick.color_code, [t.basis.x.x, t.basis.x.y, t.basis.x.z,
		t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z,
		t.origin.x, t.origin.y, t.origin.z], brick.group, brick.unit, brick.step]


static func transform_of(numbers: Array) -> Transform3D:
	var n: Array = numbers
	return Transform3D(Basis(Vector3(n[0], n[1], n[2]), Vector3(n[3], n[4], n[5]),
		Vector3(n[6], n[7], n[8])), Vector3(n[9], n[10], n[11]))


## [param state] as JSON gave it back: its numbers as numbers, so it
## compares equal to one read off a part here.
static func _as_state(given: Variant) -> Variant:
	if not given is Array or (given as Array).size() != STATE_PARTS:
		return null
	var s: Array = given
	var numbers: Array = []
	for value: Variant in s[2]:
		numbers.append(float(value))
	return [str(s[0]), int(s[1]), numbers, str(s[3]), str(s[4]), int(s[5])]


func _map(uid: String, brick_id: int) -> void:
	_uids[brick_id] = uid
	_ids[uid] = brick_id


func _unmap(uid: String) -> void:
	_uids.erase(_ids.get(uid, 0))
	_ids.erase(uid)


## The model's parts as the session began, matched to the parts the file
## opened here (by part, colour, sub-model and nearest place), so what the
## file carries beyond its parts (sub-models, motions, the floor) is the
## file's. Then each set exactly as the owner had it, and the lift too.
func _lay_snapshot(snapshot: Dictionary) -> void:
	var lift_here: float = store.lift().y
	var lift_there: float = float(snapshot.get("lift", 0.0))
	var candidates: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if store.scenery.has(brick.id):
			continue
		var key: String = "%s|%d|%s" % [brick.part_id, brick.color_code, brick.unit]
		if not candidates.has(key):
			candidates[key] = []
		(candidates[key] as Array).append(brick.id)
	for entry: Variant in snapshot.get("bricks", []):
		if not entry is Array or (entry as Array).size() != STATE_PARTS + 1:
			continue
		var uid: String = str(entry[0])
		var state: Variant = _as_state((entry as Array).slice(1))
		if state == null:
			continue
		var at: Transform3D = transform_of(state[2])
		var key: String = "%s|%d|%s" % [state[0], state[1], state[4]]
		var best: int = 0
		var best_off: float = INF
		for brick_id: int in candidates.get(key, []):
			var here: Transform3D = world.get_brick(brick_id).transform
			var off: float = (here.origin - Vector3(0, lift_here, 0)).distance_to(
				at.origin - Vector3(0, lift_there, 0)) + (here.basis.x - at.basis.x).length() \
				+ (here.basis.y - at.basis.y).length() + (here.basis.z - at.basis.z).length()
			if off < best_off:
				best_off = off
				best = brick_id
		if best != 0 and best_off < 2.0:
			(candidates[key] as Array).erase(best)
			_map(uid, best)
		_put(uid, state)
		_confirmed[uid] = state
	# What the file had that the owner's model has not: off.
	for key: String in candidates:
		for brick_id: int in candidates[key]:
			builder.lattice.release(brick_id)
			world.remove_brick(brick_id)
	if store._opened_in == world.generation():
		store._lifted_by = lift_there
	# The model's own state as the owner had it, exactly.
	var meta: Dictionary = snapshot.get("meta", {}) as Dictionary
	for key: String in meta:
		if key in META_KEYS:
			_put_meta(key, str(meta[key]))
			_confirmed[key] = str(meta[key])
	var now: Dictionary = _meta_now()
	for key: String in now:
		_shown[key] = now[key]


# -- changes made here --------------------------------------------------------

func _model_now() -> Array:
	return [world.revision, builder.history_depth(), builder.last_step()]


## What changed in the model since it was last looked at, told from what the
## session last had: sent, and kept for this side's undo.
func _capture() -> void:
	var now: Array = _model_now()
	if not _heard.is_empty() and now[0] == _heard[0] and now[1] == _heard[1] \
			and is_same(now[2], _heard[2]):
		# Nothing of the parts: the model's own state, now and then (a name
		# typed changes no part).
		if Time.get_ticks_msec() - _meta_at > META_MS:
			var meta_only: Dictionary = _diff({})
			if not meta_only.is_empty():
				_note_step(meta_only)
				_queue(meta_only)
				_close_step()
		return
	var stepped: bool = _heard.is_empty() or now[1] != _heard[1] or not is_same(now[2], _heard[2])
	# A step of the builder's can change what the world keeps no event for
	# (a part's sub-model, its step): every part looked at then.
	var touched: Variant = null if stepped \
		else _touched_since(int(_heard[0]) if not _heard.is_empty() else -1)
	_heard = now
	var changes: Dictionary = _diff(touched)
	if not changes.is_empty():
		_note_step(changes)
		_queue(changes)
	# A step of the builder's ended: one undo for all of it.
	if stepped and not _open_back.is_empty():
		_close_step()


## The bricks the world says changed since [param revision], or null when it
## cannot say (its history trimmed, or a change it keeps no event for).
func _touched_since(revision: int) -> Variant:
	if revision < 0:
		return null
	var count: int = world.revision - revision
	if count <= 0:
		return {}
	if count > world.history.size() or not world.keeps_history:
		return null
	var out: Dictionary = {}
	for n: int in range(world.history.size() - count, world.history.size()):
		var event: Dictionary = world.history[n]
		if str(event.get("op", "")) == "clear":
			return null
		if event.has("id"):
			out[int(event["id"])] = true
	return out


## {uid: state | null} for what differs from what the session had, among
## [param touched] (brick ids), or every part when that is null. A part put
## down here is given a uid of this side's.
func _diff(touched: Variant) -> Dictionary:
	var changes: Dictionary = {}
	var ids: Array = (touched as Dictionary).keys() if touched is Dictionary else []
	if touched == null:
		for brick: BrickWorld.Brick in world.bricks():
			ids.append(brick.id)
		# Parts gone, the whole way round.
		for uid: String in _shown.keys():
			if uid.begins_with("~"):
				continue
			var brick_id: int = int(_ids.get(uid, 0))
			if brick_id == 0 or world.get_brick(brick_id) == null:
				if not _awaiting.has(uid):
					changes[uid] = null
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var uid: String = str(_uids.get(brick_id, ""))
		if brick == null:
			if not uid.is_empty() and _shown.has(uid):
				changes[uid] = null
			continue
		if store.scenery.has(brick_id):
			continue
		if uid.is_empty():
			uid = "%s.%d" % [_client, _next_uid]
			_next_uid += 1
			_map(uid, brick_id)
		var state: Array = state_of(brick)
		if _shown.get(uid) != state:
			changes[uid] = state
	for uid: String in changes:
		if changes[uid] == null:
			_shown.erase(uid)
			_unmap(uid)
		else:
			_shown[uid] = changes[uid]
	# A part made in the app goes with its first part put down: its files.
	var made: Array = []
	for uid: String in changes:
		if changes[uid] is Array:
			var part: String = str((changes[uid] as Array)[0])
			if not _parts_sent.has(part) and not builder.library.custom_source(part).is_empty():
				_parts_sent[part] = true
				made.append(part)
	for part: String in made:
		changes[MADE_PART + part] = var_to_str(CustomParts.sources_for(builder.library, [part]))
	# And what the model is besides its parts, when it may have changed.
	if touched == null or Time.get_ticks_msec() - _meta_at > META_MS:
		_meta_at = Time.get_ticks_msec()
		var meta: Dictionary = _meta_now()
		for key: String in meta:
			if _shown.get(key) != meta[key]:
				changes[key] = meta[key]
				_shown[key] = meta[key]
	return changes


## [param changes] into the step this side's next undo takes back: what each
## part was before the step, and what the step left it.
func _note_step(changes: Dictionary) -> void:
	for uid: String in changes:
		if uid.begins_with(MADE_PART):
			continue
		if not _open_back.has(uid):
			_open_back[uid] = _was(uid)
		_open_forward[uid] = changes[uid]
	_open_at = Time.get_ticks_msec()
	_redo.clear()


## What [param uid] was before the change being noted: the last state the
## session had of it, from the step open or the steps before, or null.
func _was(uid: String) -> Variant:
	for n: int in range(_pending.size() - 1, -1, -1):
		var earlier: Dictionary = (_pending[n] as Dictionary)["changes"]
		if earlier.has(uid):
			return earlier[uid]
	return _confirmed.get(uid)


func _close_step() -> void:
	if _open_back.is_empty():
		return
	_undo.append({"back": _open_back, "forward": _open_forward})
	_open_back = {}
	_open_forward = {}


func _queue(changes: Dictionary) -> void:
	_pending.append({"cid": _cid, "changes": changes, "at": Time.get_ticks_msec()})
	_cid += 1


## Send what is waiting, as one request, unless one is on its way.
func _flush() -> void:
	if _sending or _in_flight >= _pending.size():
		return
	_sending = true
	# A chat line goes alone, so a line refused takes nothing else with it.
	var going: Array = []
	for n: int in range(_in_flight, mini(_pending.size(), _in_flight + 200)):
		var op: Dictionary = _pending[n]
		var talk: bool = (op["changes"] as Dictionary).has("~chat")
		if talk and not going.is_empty():
			break
		going.append({"cid": op["cid"], "changes": op["changes"]})
		if talk:
			break
	_in_flight += going.size()
	var token: String = _token
	var got: Array = await _ask("send", {"s": token, "client": _client, "ops": going})
	if token != _token or not live:
		_sending = false
		return
	var code: int = int(got[0])
	if code == 410 or code == 403 or code == 404:
		_sending = false
		_stop(_refused_words(code, got))
		return
	if code == 422 and going.size() == 1 and (going[0]["changes"] as Dictionary).has("~chat"):
		# A chat line refused (under 13, words a stranger may not be shown):
		# said, and not sent again.
		_pending.remove_at(_in_flight - 1)
		_in_flight -= 1
		_sending = false
		var why: String = _refused_words(code, got)
		chat_words = why if why.contains("13") else chat_words
		said.emit(why)
		changed.emit()
		return
	if code != 200:
		# Not taken: sent again, from the first not numbered, in a moment.
		_in_flight = maxi(0, _in_flight - going.size())
		said.emit("Could not reach the session; trying again.")
		await get_tree().create_timer(1.0).timeout
	_sending = false


func _flush_all() -> void:
	var until: int = Time.get_ticks_msec() + 8000
	while live and (_sending or _in_flight < _pending.size()) and Time.get_ticks_msec() < until:
		_flush()
		await get_tree().process_frame


# -- changes from the session -------------------------------------------------

func _poll_loop() -> void:
	_polling += 1
	var mine: int = _polling
	var token: String = _token
	while live and mine == _polling:
		var got: Array = await _ask("poll", {"s": token, "after": seq, "seen": _seen}, 30.0)
		if not live or mine != _polling:
			return
		var code: int = int(got[0])
		if code == 200:
			var body: Dictionary = got[1]
			if bool(body.get("ended", false)):
				_stop("The owner ended the session. What was built is still here: a copy, yours to keep or not."
					if not owns else "The session has ended.")
				return
			_seen = str(body.get("seen", _seen))
			if body.has("chat") and str(body["chat"]) != chat_words:
				chat_words = str(body["chat"])
				changed.emit()
			var now: Array = body.get("people", people) as Array
			if now != people:
				# A pointer moving is the view's; the panel redraws only for who
				# is in it, and whether each is here.
				var before: String = _people_words(people)
				people = now
				_show_pointers()
				if _people_words(people) != before:
					changed.emit()
			_take(body.get("ops", []) as Array)
			continue
		if code == 410 or code == 403 or code == 404:
			_stop(_refused_words(code, got))
			return
		await get_tree().create_timer(1.0).timeout


## Numbered changes, put down in their order. Another side's change to a part
## this side has a change of its own on the way for waits: it is shown once
## this side's is numbered after it, or not at all if this side's comes later.
func _take(ops: Array) -> void:
	# What changed here this frame first, so it is not taken for theirs.
	_capture()
	var shown_again: Dictionary = {}
	for item: Variant in ops:
		var op: Dictionary = item
		var number: int = int(op.get("seq", 0))
		if number <= seq:
			continue
		seq = number
		var changes: Dictionary = op.get("changes", {}) as Dictionary
		# A send taken twice: its second time is nothing, on every side.
		var from: String = str(op.get("client", ""))
		var cid_now: int = int(op.get("cid", -1))
		if cid_now <= int(_last_cid.get(from, -1)):
			continue
		_last_cid[from] = cid_now
		if changes.has("~chat"):
			_heard_chat(op, from == _client)
		# A part made in the app, before any part of it is put down.
		for key: String in changes:
			if key.begins_with(MADE_PART):
				_add_made(str(changes[key]))
		if from == _client:
			var cid: int = int(op.get("cid", -1))
			while not _pending.is_empty() and int((_pending[0] as Dictionary)["cid"]) <= cid:
				var done: Dictionary = _pending.pop_front()
				_in_flight = maxi(0, _in_flight - 1)
				if int(done["cid"]) == cid:
					round_trips.append(Time.get_ticks_msec() - int(done["at"]))
					if round_trips.size() > TIMES_KEPT:
						round_trips.pop_front()
			for uid: String in changes:
				if uid == "~chat" or uid.begins_with(MADE_PART):
					continue
				_confirm(uid, changes[uid])
				_mine_at[uid] = Time.get_ticks_msec()
			continue
		for uid: String in changes:
			if uid == "~chat" or uid.begins_with(MADE_PART):
				continue
			_confirm(uid, changes[uid])
			shown_again[uid] = true
			# Mine came back a moment ago and theirs was numbered after it:
			# theirs stands, and the person is told so.
			if Time.get_ticks_msec() - int(_mine_at.get(uid, -OVERTAKEN_MS)) < OVERTAKEN_MS:
				_mine_at.erase(uid)
				said.emit("%s changed a part you had just changed; theirs came after yours, so it stands."
					% _name_of(str(op.get("who", ""))))
	var later: Array = []
	for uid: String in shown_again:
		if _mine_on_the_way(uid):
			continue
		if uid.begins_with("~"):
			later.append(uid)
			continue
		_put(uid, _confirmed.get(uid))
	# The model's own state after its parts: a floor is laid round them.
	for uid: String in later:
		_put(uid, _confirmed.get(uid))
	if not shown_again.is_empty():
		_heard = _model_now()
		builder._living_selection()


static func _people_words(list: Array) -> String:
	return JSON.stringify(list.map(func(one: Variant) -> Array:
		var person: Dictionary = one
		return [person.get("who"), person.get("name"), person.get("here"), person.get("owner")]))


func _name_of(who: String) -> String:
	for person: Variant in people:
		if str((person as Dictionary).get("who", "")) == who:
			return str((person as Dictionary).get("name", "Someone"))
	return "Someone"


func _confirm(uid: String, given: Variant) -> void:
	if uid.begins_with("~"):
		_confirmed[uid] = str(given) if given != null else ""
		return
	var state: Variant = _as_state(given)
	if state == null:
		_confirmed.erase(uid)
	else:
		_confirmed[uid] = state


func _mine_on_the_way(uid: String) -> bool:
	for op: Dictionary in _pending:
		if (op["changes"] as Dictionary).has(uid):
			return true
	return false


## Set [param uid] in the world to [param state] (null: taken off), past the
## builder's history: another side's change is not this side's to undo.
func _put(uid: String, state: Variant) -> void:
	if uid.begins_with("~"):
		_put_meta(uid, str(state) if state != null else "")
		return
	var brick_id: int = int(_ids.get(uid, 0))
	var brick: BrickWorld.Brick = world.get_brick(brick_id) if brick_id != 0 else null
	if state == null:
		_awaiting.erase(uid)
		if brick != null:
			builder.lattice.release(brick_id)
			world.remove_brick(brick_id)
			builder.selection.erase(brick_id)
		_unmap(uid)
		_shown.erase(uid)
		return
	var s: Array = state
	var at: Transform3D = transform_of(s[2])
	if brick != null and brick.part_id != str(s[0]):
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
		_unmap(uid)
		brick = null
	if brick == null:
		brick_id = _scenery_at(str(s[0]), int(s[1]), at)
		if brick_id != 0:
			# The floor's own plate made part of the model on the other side:
			# the same plate here, not a second one on it.
			store.scenery.erase(brick_id)
		else:
			brick_id = world.add_brick(str(s[0]), int(s[1]), at)
		if brick_id == 0:
			# Its geometry is on its way: put down when it comes.
			_awaiting[uid] = s
			_shown[uid] = s
			if builder.library != null:
				builder.library.want([str(s[0])], true)
				if not builder.library.fetched.is_connected(_on_fetched):
					builder.library.fetched.connect(_on_fetched)
			return
		_awaiting.erase(uid)
		brick = world.get_brick(brick_id)
		brick.group = str(s[3])
		brick.unit = str(s[4])
		brick.step = int(s[5])
		if builder.lattice.boxes_of(brick_id).is_empty():
			builder.register(brick_id, brick.part_id, brick.transform)
		_map(uid, brick_id)
	else:
		if brick.transform != at:
			builder.lattice.release(brick_id)
			world.move_brick(brick_id, at)
			builder.register(brick_id, brick.part_id, at)
		if brick.color_code != int(s[1]):
			world.recolor_brick(brick_id, int(s[1]))
		brick.group = str(s[3])
		brick.unit = str(s[4])
		brick.step = int(s[5])
	_shown[uid] = state_of(brick)


func _on_fetched(part_id: String) -> void:
	if not live:
		return
	for uid: String in _awaiting.keys():
		var s: Array = _awaiting[uid]
		if str(s[0]) == part_id:
			_put(uid, s)
	_heard = _model_now()


# -- the model's own state, besides its parts ----------------------------------

## What the model is besides its parts, as words: each as the file has it, or
## as Godot writes the value (var_to_str), the same on every side.
func _meta_now() -> Dictionary:
	return {
		"~title": store.title,
		"~floor": store.model_floor.whole_words() if store.model_floor != null else "",
		"~hidden": var_to_str(store.hidden_scheme),
		"~motions": "\n".join(store._motion_lines()) if world.motions != null else "",
		"~looks": var_to_str(world.step_looks),
		"~unit_steps": var_to_str(world.unit_steps),
		"~broken": _broken_words(),
	}


## Set the model's own state [param key] to [param words], past the history.
func _put_meta(key: String, words: String) -> void:
	match key:
		"~title":
			if words.is_empty() or words == store.title:
				pass
			else:
				store.title = words
				if bar != null:
					bar._name.text = words
					bar.model_named.emit(words)
		"~floor":
			if builder.floor_hook.is_valid():
				builder.floor_hook.call(words)
			else:
				var chosen: ModelFloor = ModelFloor.parse(words)
				if chosen != null:
					store.model_floor = chosen
		"~hidden":
			var scheme: Variant = str_to_var(words)
			store.hidden_scheme = scheme if scheme is Dictionary else {}
		"~motions":
			world.motions = Motions.read(words) if not words.is_empty() else null
		"~looks":
			var looks: Variant = str_to_var(words)
			world.step_looks = looks if looks is Dictionary else {}
		"~unit_steps":
			var steps: Variant = str_to_var(words)
			world.unit_steps = steps if steps is Dictionary else {}
		"~broken":
			_broken_from(words)
	store.touch()
	_shown[key] = _meta_now()[key]


## Sections broken out, their parts named by uid rather than this side's
## numbers.
func _broken_words() -> String:
	var out: Dictionary = {}
	for section: String in world.broken_out:
		var record: Dictionary = (world.broken_out[section] as Dictionary).duplicate(true)
		var home: Dictionary = {}
		for brick_id: Variant in record.get("home", {}):
			home[str(_uids.get(int(brick_id), ""))] = record["home"][brick_id]
		record["home"] = home
		out[section] = record
	return var_to_str(out)


func _broken_from(words: String) -> void:
	var given: Variant = str_to_var(words)
	world.broken_out.clear()
	if not given is Dictionary:
		return
	for section: String in given:
		var record: Dictionary = (given[section] as Dictionary).duplicate(true)
		var home: Dictionary = {}
		for uid: Variant in record.get("home", {}):
			if _ids.has(str(uid)):
				home[int(_ids[str(uid)])] = record["home"][uid]
		record["home"] = home
		world.broken_out[section] = record


## A part made in the app on the other side: its files, added here.
func _add_made(words: String) -> void:
	var files: Variant = str_to_var(words)
	if not files is Dictionary:
		return
	for file: String in files:
		var id: String = file.trim_suffix(".dat")
		if builder.library.parts.has(id):
			continue
		CustomParts.add(builder.library, str(files[file]), id, false, files)
	for uid: String in _awaiting.keys():
		_put(uid, _awaiting[uid])


## A floor's own plate standing exactly where [param at] is, or 0.
func _scenery_at(part: String, colour: int, at: Transform3D) -> int:
	for brick_id: int in store.scenery:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null and brick.part_id == part and brick.color_code == colour \
				and brick.transform.is_equal_approx(at):
			return brick_id
	return 0


# -- chat -----------------------------------------------------------------------

## Say [param words] to the others. "" when sent, or why not.
func chat(words: String) -> String:
	if not live:
		return "Not in a session."
	if not chat_words.is_empty():
		return chat_words
	var line: String = words.strip_edges()
	if line.is_empty():
		return "Say something first."
	_queue({"~chat": line.left(280)})
	return ""


func _heard_chat(op: Dictionary, mine: bool) -> void:
	var line: String = str((op.get("changes", {}) as Dictionary).get("~chat", ""))
	if line.is_empty():
		return
	var name: String = "You" if mine else _name_of(str(op.get("who", "")))
	messages.append({"who": str(op.get("who", "")), "name": name, "text": line, "mine": mine})
	if messages.size() > MESSAGES_KEPT:
		messages.pop_front()
	if not mine:
		said.emit("%s: %s" % [name, line])
	changed.emit()


# -- where each person is working ----------------------------------------------

## Where this person is working, in the model's space: the part in hand's
## ghost, or the part under the pointer; null when neither.
func _pointer_now() -> Variant:
	if builder.has_preview():
		var ghost: Vector3 = builder.ghost_transform().origin
		return [snappedf(ghost.x, 0.1), snappedf(ghost.y, 0.1), snappedf(ghost.z, 0.1)]
	var hovered: int = builder.hovered_brick()
	var brick: BrickWorld.Brick = world.get_brick(hovered) if hovered != 0 else null
	if brick == null:
		return null
	var at: Vector3 = brick.transform.origin
	return [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1)]


## Sent a few times a second while it moves.
func _point() -> void:
	if _pointing or Time.get_ticks_msec() - _point_at < POINT_MS:
		return
	var now: Variant = _pointer_now()
	if now == _pointed:
		return
	_point_at = Time.get_ticks_msec()
	_pointing = true
	_pointed = now
	await _ask("point", {"s": _token, "at": now})
	_pointing = false


## The others' pointers in the view: a dot and their name, in a colour each.
func _show_pointers() -> void:
	var wanted: Dictionary = {}
	if live:
		for n: int in people.size():
			var person: Dictionary = people[n]
			if bool(person.get("me", false)) or not person.get("at") is Array:
				continue
			var at: Array = person["at"]
			wanted[str(person["who"])] = [Vector3(float(at[0]), float(at[1]), float(at[2])),
				str(person.get("name", "")), MARKER_COLOURS[n % MARKER_COLOURS.size()]]
	for who: String in _markers.keys():
		if not wanted.has(who):
			(_markers[who] as Node3D).queue_free()
			_markers.erase(who)
	for who: String in wanted:
		var marker: Node3D = _markers.get(who)
		if marker == null:
			marker = _marker(wanted[who][1], wanted[who][2])
			world.add_child(marker)
			_markers[who] = marker
		marker.position = wanted[who][0] + Vector3(0, 12, 0)
		(marker.get_child(1) as Label3D).text = wanted[who][1]


static func _marker(name: String, colour: Color) -> Node3D:
	var marker := Node3D.new()
	marker.name = "TogetherPointer"
	var dot := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 5.0
	sphere.height = 10.0
	dot.mesh = sphere
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.no_depth_test = true
	paint.render_priority = 10
	dot.material_override = paint
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(dot)
	var label := Label3D.new()
	label.text = name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 28
	label.outline_size = 8
	label.modulate = colour
	label.position = Vector3(0, 10, 0)
	label.render_priority = 11
	marker.add_child(label)
	return marker


## How many of the others' pointers are drawn now.
func pointers_shown() -> int:
	return _markers.size()


# -- going back in after a reload -------------------------------------------------

func _keep_place() -> void:
	if not keeps_place:
		return
	var file := FileAccess.open(TabSession.path(KEPT_FILE), FileAccess.WRITE)
	if file != null:
		file.store_string(_token)
		file.close()


func _forget_place() -> void:
	if keeps_place and FileAccess.file_exists(TabSession.path(KEPT_FILE)):
		DirAccess.remove_absolute(TabSession.path(KEPT_FILE))


## The session this tab was in when it was reloaded or closed, or "".
static func kept_secret() -> String:
	var path: String = TabSession.path(KEPT_FILE)
	if not FileAccess.file_exists(path):
		return ""
	return secret_in(FileAccess.get_file_as_string(path))


# -- each person's own undo ---------------------------------------------------

## Whether this side has a step of its own to undo (or redo).
func can_undo(again: bool = false) -> bool:
	return not (_redo if again else _undo).is_empty() or (not again and not _open_back.is_empty())


## Take back this side's last step, where nobody has changed its parts since.
## What was done, in words, or "" when there was nothing to undo.
func undo(again: bool = false) -> String:
	_capture()
	_close_step()
	var from: Array = _redo if again else _undo
	if from.is_empty():
		return ""
	var step: Dictionary = from.pop_back()
	var forward: Dictionary = step["forward"]
	var back: Dictionary = step["back"]
	var changes: Dictionary = {}
	var left: int = 0
	for uid: String in back:
		var now: Variant = _shown.get(uid)
		if now != forward[uid]:
			left += 1
			continue
		changes[uid] = back[uid]
	var undone_forward: Dictionary = {}
	var undone_back: Dictionary = {}
	for uid: String in changes:
		undone_back[uid] = forward[uid]
		undone_forward[uid] = changes[uid]
		_put(uid, changes[uid])
	_heard = _model_now()
	builder._living_selection()
	if not changes.is_empty():
		_queue(changes)
		(_undo if again else _redo).append({"forward": undone_forward, "back": undone_back})
	var words: String = "%s %s" % ["redid" if again else "undid", _parts(changes.size())]
	if left > 0:
		words += "; left %s somebody else changed since" % _parts(left)
	return words


static func _parts(count: int) -> String:
	return "1 part" if count == 1 else "%d parts" % count


# -- the model as text, for checks --------------------------------------------

## The model's file as it would be saved: what both sides compare.
func model_text() -> String:
	return store.to_text(store.title)


## How many of this side's changes are still on their way.
func waiting() -> int:
	return _pending.size()


## The uid of [param brick_id], or "".
func uid_of(brick_id: int) -> String:
	return str(_uids.get(brick_id, ""))


## The brick of [param uid], or 0.
func brick_of(uid: String) -> int:
	return int(_ids.get(uid, 0))


# -- for checks --------------------------------------------------------------

## The app's own tools, as Claude calls them (CommandSocket.answer_rpc): a
## tool's name and arguments to the words it answers. Set by Main.
var run_tool: Callable = Callable()


## A change made as the keys and the mouse make it, through the builder's own
## place, move, paint and delete, on a part named by its uid; the model's name
## typed; any of the app's tools as Claude calls it ("uid:<uid>" in its
## arguments names a part, "#uid:<uid>" a joint); a chat line; and Undo and
## Redo as the Edit menu has them in a session. What
## tools/web/together_flow.mjs and src/dev/together_probe.gd drive.
func check_edit(edit: Dictionary) -> Dictionary:
	var op: String = str(edit.get("op", ""))
	# The model's own state read at once after this, not a moment later.
	_meta_at = 0
	if op == "tool":
		if not run_tool.is_valid():
			return {"ok": false, "words": "no tools here"}
		var words: String = await run_tool.call(str(edit.get("name", "")),
			_with_bricks(edit.get("arguments", {})))
		_capture()
		return {"ok": true, "words": words}
	if op == "title":
		var name: String = str(edit.get("title", ""))
		if bar != null:
			bar._name.text = name
			bar._name.text_changed.emit(name)
		else:
			store.title = name
		_capture()
		return {"ok": store.title == name}
	if op == "chat":
		var trouble: String = chat(str(edit.get("text", "")))
		return {"ok": trouble.is_empty(), "words": trouble}
	if op == "undo" or op == "redo":
		var words: String = undo(op == "redo")
		return {"ok": not words.is_empty(), "words": words}
	if op == "place":
		var at := Transform3D(Basis.IDENTITY, Vector3(float(edit.get("x", 0)),
			float(edit.get("y", 0)), float(edit.get("z", 0))))
		var brick_id: int = world.add_brick(str(edit.get("part", "3001")), int(edit.get("colour", 4)), at)
		if brick_id == 0:
			return {"ok": false, "words": "no geometry"}
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		builder.lattice.occupy_boxes(brick_id, builder.boxes_for(
			builder.library.mesh_for(brick.part_id), brick.transform))
		builder.record([{"undo": "remove", "brick": brick_id}], "placed %s" % brick.part_id)
		_capture()
		return {"ok": true, "uid": uid_of(brick_id)}
	var brick_id: int = brick_of(str(edit.get("uid", "")))
	if brick_id == 0 or world.get_brick(brick_id) == null:
		return {"ok": false, "words": "no such part"}
	builder.clear_selection()
	builder.select_brick(brick_id, false)
	var done: int = 0
	match op:
		"move":
			var by: Array = edit.get("by", [0, 0, 0])
			done = builder.move_selection(Vector3i(int(by[0]), int(by[1]), int(by[2])))
		"paint":
			done = builder.paint_selection(int(edit.get("colour", 1)))
		"delete":
			done = builder.remove_selection()
	builder.clear_selection()
	_capture()
	return {"ok": done > 0}


## [param value] with each "uid:<uid>" a part's number here, and each
## "#uid:<uid>" a joint's ("#80").
func _with_bricks(value: Variant) -> Variant:
	if value is String:
		var said: String = value
		if said.begins_with("uid:"):
			return brick_of(said.substr(4))
		if said.begins_with("#uid:"):
			return "#%d" % brick_of(said.substr(5))
		return said
	if value is Array:
		return (value as Array).map(func(one: Variant) -> Variant: return _with_bricks(one))
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			out[key] = _with_bricks(value[key])
		return out
	return value


## The uids of the parts, for a check to choose among.
func uids() -> Array:
	var out: Array = []
	for uid: String in _ids:
		out.append(uid)
	out.sort()
	return out


## The model's file and its SHA-256, as the save would write it.
func model_hash() -> String:
	return model_text().sha256_text()


var _page_at: int = 0
var _answering: bool = false


## What a browser check reads (window.brickworksTogether) and asks
## (window.brickworksTogetherAsk: a list of check_edit's edits, or {"text":
## true}; answered in window.brickworksTogetherDone), each frame in a
## session and twice a second out of one.
func _tell_page() -> void:
	var now: int = Time.get_ticks_msec()
	if not live and now - _page_at < 500:
		return
	_page_at = now
	if not _answering:
		_answer_page()
	var trips: Array = round_trips.slice(maxi(0, round_trips.size() - 100))
	JavaScriptBridge.eval("window.brickworksTogether = %s" % JSON.stringify({
		"live": live, "owner": owns, "link": link, "seq": seq, "waiting": waiting(),
		"people": people, "parts": _ids.size(), "trips": trips, "ended": ended_words,
		"can_undo": can_undo(), "messages": messages.slice(maxi(0, messages.size() - 20)),
		"chat_words": chat_words, "pointers": pointers_shown()}), true)


## The page's asks, answered in order; one batch at a time.
func _answer_page() -> void:
	var asked: Variant = JavaScriptBridge.eval(
		"(() => { const a = window.brickworksTogetherAsk; window.brickworksTogetherAsk = undefined;"
		+ " return a === undefined ? '' : JSON.stringify(a); })()", true)
	if asked != null and not str(asked).is_empty():
		var asks: Variant = JSON.parse_string(str(asked))
		var answers: Array = []
		_answering = true
		for ask: Variant in (asks if asks is Array else [asks]):
			if not ask is Dictionary:
				continue
			var one: Dictionary = ask
			if one.has("op"):
				answers.append(await check_edit(one))
			elif bool(one.get("text", false)):
				answers.append({"ok": true, "hash": model_hash(), "text": model_text(),
					"uids": uids(), "seq": seq, "waiting": waiting()})
		JavaScriptBridge.eval("window.brickworksTogetherDone = %s" % JSON.stringify(answers), true)
		_answering = false


# -- the server ---------------------------------------------------------------

func _ask(op: String, body: Dictionary, timeout: float = 20.0) -> Array:
	var session: String = await account.access_token() if account != null else ""
	if session.is_empty():
		return [401, {"error": "Sign in to build together."}]
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var headers := PackedStringArray(["authorization: Bearer " + session,
		"content-type: application/json"])
	headers.append_array(extra_headers)
	var sent: int = http.request("%s/api/together?op=%s" % [base_url, op], headers,
		HTTPClient.METHOD_POST, JSON.stringify(body, "", false, true))
	if sent != OK:
		http.queue_free()
		return [0, {}]
	var done: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	return [int(done[1]) if int(done[0]) == HTTPRequest.RESULT_SUCCESS else 0,
		parsed if parsed is Dictionary else {}]


static func _trouble(got: Array, doing: String) -> String:
	var why: String = str((got[1] as Dictionary).get("error", "")) if got[1] is Dictionary else ""
	if int(got[0]) == 0:
		return "%s: Brickworks could not be reached." % doing
	return "%s: %s." % [doing, why if not why.is_empty() else "the server said %d" % int(got[0])]


static func _refused_words(code: int, got: Array) -> String:
	var why: String = str((got[1] as Dictionary).get("error", "")) if got[1] is Dictionary else ""
	if code == 410:
		return "The owner ended the session. What was built is still here: a copy, yours to keep or not."
	if not why.is_empty():
		return why.substr(0, 1).to_upper() + why.substr(1) + "."
	return "The session refused this copy."
