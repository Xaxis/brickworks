## A program for the model's motors, as a hub runs one (APP_UX9 hubprogram):
## what Simulate's program row plays (SimulatePanel), simulate_mechanism's
## program= sets and plays, and the model's file keeps. Brickyard runs a
## program on the screen or a real hub, and Kinebrick Studio's next release
## builds Pybricks ones; here it plays in Simulate, each motor at its rated
## speed (Simulation.MOTORS' speed with no load, at its hub's volts), each move
## stopped where Simulate finds the motion stops: a part meets another, the
## loop it closes goes no further, or the motor stalls under the weight it
## lifts (its torque from spikemotors' table), either way, from anywhere.
##
## The words, a line each, a few a builder reads at a glance, each beside the
## Pybricks call it is (and taken under that name too):
##   to 90° at 50%      to 90° from where it was built   run_target
##   turn -45° at 30%   45° back from where it is        run_angle
##   run 40% for 2 s    on at 40% for 2 s (-40%, back)   run_time
##   wait 1 s           (or "wait 500 ms")               wait
##   repeat 3           the lines indented under it, 3 times
## A speed is a share of the motor's speed with no load, as SPIKE's blocks
## give one: 50% of the SPIKE Prime large motor's 175 rpm is 525°/s. A line
## that gives none goes at 75%, SPIKE's own. "#" begins a note. A line runs
## once the one before it is done, as a hub's run_target waits for its motor.
## Positive is the way Simulate's Play turns the motor.
##
## Which motor. Each motor that plugs into a hub (SPIKE Prime's and Robot
## Inventor's, the Technic angular ones, Powered Up's and Boost's) has a port,
## A to F, in the order the model has them, as a hub's six ports are lettered.
## With one such motor a line needs no port; with two or more, it begins with
## its own ("B to 90°"), and two whose trains turn each other are refused, as
## the one train cannot be held by both. A Power Functions or 9 V motor plugs
## into no hub (a battery box or an IR receiver runs it): a program drives
## none, and Play turns it. A model need not show its hub: LDraw has no SPIKE
## Prime hub to place.
##
## In the file, one line at the end of the model's head (ProgramLine, which
## the first screen compiles; this is loaded by Later). Pure: Simulate says
## where each motor stops.
class_name HubProgram
extends RefCounted

## A hub's ports, lettered as SPIKE Prime's six are.
const PORTS := "ABCDEF"
## Where ports_of puts the motors past a hub's six ports.
const UNPORTED := "+"
## A move's speed when a line gives none, percent: SPIKE's own.
const DEFAULT_SPEED := 75.0
## The most lines, times round a repeat, degrees a line asks, seconds a line
## waits or runs, moves a run makes, and seconds a run takes: a program is
## played on a screen, not left on a shelf.
const MOST_LINES := 200
const MOST_TIMES := 1000
const MOST_DEGREES := 36000.0
const MOST_LINE_SECONDS := 600.0
const MOST_MOVES := 20000
const MOST_SECONDS := 600.0
## The words a line begins with, and the Pybricks names taken for them.
const VERBS: Array[String] = ["to", "turn", "run", "wait", "repeat"]
const PYBRICKS := {"run_target": "to", "run_angle": "turn", "run_time": "run"}
## Motors whose name begins so plug into no hub.
const HUBLESS: Array[String] = ["Power Functions", "9 V"]


## One line of the program.
class Statement extends RefCounted:
	## Its line in the text, from 1.
	var line: int = 0
	## Its port, "A" to "F"; "" for the model's one motor.
	var port: String = ""
	## One of [constant VERBS].
	var verb: String = ""
	var degrees: float = 0.0
	## Percent of the motor's speed with no load; less than 0, back (run).
	var speed: float = DEFAULT_SPEED
	var seconds: float = 0.0
	var times: int = 0
	## A repeat's own lines.
	var inside: Array = []


## The text as written, and what it says: its lines, or why it cannot be run.
var text: String = ""
var lines: Array = []
var errors: PackedStringArray = PackedStringArray()


## [param words] read: its [member lines], or its [member errors], each "Line
## 3: ...".
static func parse(words: String) -> HubProgram:
	var out := HubProgram.new()
	out.text = words
	var rows: PackedStringArray = words.split("\n")
	if rows.size() > MOST_LINES:
		out.errors.append("A program has %d lines at most; this one has %d." % [MOST_LINES, rows.size()])
		return out
	var stack: Array = [[-1, out.lines, null]]
	for n: int in rows.size():
		var row: String = rows[n].trim_suffix("\r")
		var note: int = row.find("#")
		if note >= 0:
			row = row.left(note)
		if row.strip_edges().is_empty():
			continue
		var indent: int = 0
		while indent < row.length() and (row[indent] == " " or row[indent] == "\t"):
			indent += 1
		var said: Variant = _statement(row.strip_edges(), n + 1)
		if said is String:
			out.errors.append("Line %d: %s" % [n + 1, said])
			continue
		var statement: Statement = said
		while stack.size() > 1 and int((stack.back() as Array)[0]) >= indent:
			stack.pop_back()
		((stack.back() as Array)[1] as Array).append(statement)
		if statement.verb == "repeat":
			stack.append([indent, statement.inside, statement])
	out._check_repeats(out.lines)
	return out


func _check_repeats(list: Array) -> void:
	for statement: Statement in list:
		if statement.verb != "repeat":
			continue
		if statement.inside.is_empty():
			errors.append("Line %d: nothing to repeat; indent the lines it repeats under it."
				% statement.line)
		_check_repeats(statement.inside)


## Whether it says nothing to do.
func is_empty() -> bool:
	return lines.is_empty() and errors.is_empty()


## A line's words, without its note, read; or why not (a String).
static func _statement(row: String, number: int) -> Variant:
	var words: PackedStringArray = _words_of(row)
	if words.is_empty():
		return "nothing to read."
	var out := Statement.new()
	out.line = number
	var at: int = 0
	var first: String = words[0]
	if first.length() == 1 and PORTS.to_lower().contains(first) and words.size() > 1:
		out.port = first.to_upper()
		at = 1
	elif first.length() == 1 and first >= "a" and first <= "z":
		return "a hub's ports are A to F, not %s." % first.to_upper()
	var verb: String = words[at]
	verb = str(PYBRICKS.get(verb, verb))
	if not verb in VERBS:
		return "\"%s\" is not one of its words: to, turn, run, wait, repeat." % words[at]
	out.verb = verb
	var rest: PackedStringArray = words.slice(at + 1)
	match verb:
		"to", "turn":
			var degrees: Variant = _number(rest, 0, ["deg"])
			if degrees == null:
				return "%s takes degrees: \"%s 90° at 50%%\"." % [verb, verb]
			# Said as written: 1e400 is past any float, and was "inf".
			if absf(float(degrees)) > MOST_DEGREES:
				return "%s° is more than the %d° a line turns at most." % [rest[0], int(MOST_DEGREES)]
			out.degrees = float(degrees)
			var used: int = _used(rest, 0, ["deg"])
			if used < rest.size():
				if rest[used] != "at":
					return "after the degrees, \"at\" and a speed: \"%s 90° at 50%%\"." % verb
				var speed: Variant = _number(rest, used + 1, ["pct"])
				if speed == null or _used(rest, used + 1, ["pct"]) != rest.size():
					return "a speed is a share of the motor's: \"at 50%\"."
				var refused: String = _speed_refused(float(speed))
				if not refused.is_empty():
					return refused
				out.speed = absf(float(speed))
		"run":
			var speed: Variant = _number(rest, 0, ["pct"])
			var used: int = _used(rest, 0, ["pct"])
			if speed == null or used >= rest.size() or rest[used] != "for":
				return "run takes a speed and a time: \"run 40% for 2 s\"."
			var refused: String = _speed_refused(float(speed))
			if not refused.is_empty():
				return refused
			var seconds: Variant = _seconds(rest, used + 1)
			if seconds is String:
				return seconds
			out.speed = float(speed)
			out.seconds = float(seconds)
		"wait":
			var seconds: Variant = _seconds(rest, 0)
			if seconds is String:
				return seconds
			out.seconds = float(seconds)
			if not out.port.is_empty():
				return "wait waits for no motor: \"wait 1 s\"."
		"repeat":
			if not out.port.is_empty():
				return "repeat repeats the lines under it, for every motor: \"repeat 3\"."
			if rest.is_empty() or not rest[0].is_valid_int() or (rest.size() > 1
					and not (rest.size() == 2 and rest[1] in ["times", "time", "x"])):
				return "repeat takes how many times: \"repeat 3\"."
			out.times = rest[0].to_int()
			if out.times < 1 or out.times > MOST_TIMES:
				return "repeat goes round 1 to %d times." % MOST_TIMES
	return out


## [param row] in lower case, its signs made words: "90°" is "90 deg", "50%"
## "50 pct", "1s" "1 s", "A:" "a".
static func _words_of(row: String) -> PackedStringArray:
	var plain: String = row.to_lower().replace("°", " deg ").replace("%", " pct ").replace(":", " ") \
		.replace(",", " ").replace("(", " ").replace(")", " ").replace("\t", " ")
	var out := PackedStringArray()
	for word: String in plain.split(" ", false):
		# "1s", "500ms", "90deg": the number and its unit apart.
		var k: int = _number_end(word)
		if k > 0 and k < word.length() and word.left(k).is_valid_float():
			out.append(word.left(k))
			out.append(word.substr(k))
		else:
			out.append(word)
	for n: int in out.size():
		if out[n] in ["degree", "degrees", "degs"]:
			out[n] = "deg"
		elif out[n] in ["percent"]:
			out[n] = "pct"
		elif out[n] in ["sec", "secs", "second", "seconds"]:
			out[n] = "s"
	return out


## Where the number [param word] begins with ends: its digits, point and
## sign, and its exponent when one follows ("1e-9", "2e+3"); 0 for none.
## Split at the e, "wait 1e-9 s" was 1 and a unit "e-9" (hpreview F8).
static func _number_end(word: String) -> int:
	var k: int = 0
	while k < word.length() and (word[k].is_valid_int() or word[k] in [".", "-", "+"]):
		k += 1
	if k == 0 or k + 1 >= word.length() or word[k] != "e":
		return k
	var digits: int = k + 2 if word[k + 1] in ["-", "+"] else k + 1
	var end: int = digits
	while end < word.length() and word[end].is_valid_int():
		end += 1
	return end if end > digits else k


## The number at [param at] of [param words], its unit (one of [param units])
## after it or not; null for none. One past any float (1e400) is INF, which
## the range its line has refuses in its own words.
static func _number(words: PackedStringArray, at: int, _units: Array) -> Variant:
	if at >= words.size() or not words[at].is_valid_float():
		return null
	var value: float = words[at].to_float()
	return value if not is_nan(value) else null


## Where the words after that number (and its unit) begin.
static func _used(words: PackedStringArray, at: int, units: Array) -> int:
	var next: int = at + 1
	if next < words.size() and words[next] in units:
		next += 1
	return next


## The seconds at [param at]: "1 s", "1", "500 ms"; or why not.
static func _seconds(words: PackedStringArray, at: int) -> Variant:
	var value: Variant = _number(words, at, ["s", "ms"])
	var unit: String = words[at + 1] if at + 1 < words.size() else "s"
	if value == null or not unit in ["s", "ms"] or at + 2 < words.size():
		return "a time in seconds: \"1 s\", or \"500 ms\"."
	# 0 s too, as Pybricks' wait(0) is: "wait 0 s" was refused in words that
	# said 0 was taken (hpreview F8).
	var seconds: float = float(value) / (1000.0 if unit == "ms" else 1.0)
	if seconds < 0.0 or seconds > MOST_LINE_SECONDS:
		return "a time from 0 to %d s." % int(MOST_LINE_SECONDS)
	return seconds


static func _speed_refused(speed: float) -> String:
	if absf(speed) > 100.0:
		return "a speed is 100% at most, the motor's speed with no load."
	if absf(speed) < 1.0:
		return "a speed of at least 1%, or it never gets there."
	return ""


# -- the motors on the hub's ports -------------------------------------------------------


## The motors among [param motors] (brick id -> its key in
## Simulation.MOTORS) that plug into a hub, each on its port in the order the
## model has them: {port: {key (brick id), part, name, rpm, gives (N·cm),
## volts}}. Those that plug into none are under "" as [[brick id, name]], and
## those past the hub's six ports under [constant UNPORTED], the same.
static func ports_of(motors: Dictionary) -> Dictionary:
	var keys: Array = motors.keys()
	keys.sort()
	var out: Dictionary = {}
	var hubless: Array = []
	var past: Array = []
	for key: Variant in keys:
		var it: Array = Simulation.MOTORS[motors[key]]
		var name: String = str(it[0])
		if HUBLESS.any(func(lead: String) -> bool: return name.begins_with(lead)):
			hubless.append([int(key), name])
			continue
		var count: int = out.size()
		if count >= PORTS.length():
			past.append([int(key), name])
			continue
		out[PORTS[count]] = {"key": int(key), "part": str(motors[key]), "name": name,
			"rpm": float(it[2]), "gives": float(it[1]), "volts": float(it[3])}
	if not hubless.is_empty():
		out[""] = hubless
	if not past.is_empty():
		out[UNPORTED] = past
	return out


## The lettered ports of [param ports] (ports_of) that have a motor, "A" to
## "F" in order.
static func lettered(ports: Dictionary) -> Array:
	var out: Array = []
	for port: String in PORTS:
		if ports.has(port):
			out.append(port)
	return out


## The motors past the hub's six ports, said: up to hpreview a seventh was
## on no port and nothing said so. "" for none.
static func unported_words(ports: Dictionary) -> String:
	var past: Array = ports.get(UNPORTED, [])
	if past.is_empty():
		return ""
	if past.size() == 1:
		return "The %s #%d is on no port: a hub has six, A to F." % [str((past[0] as Array)[1]),
			int((past[0] as Array)[0])]
	var named := PackedStringArray()
	for one: Array in past:
		named.append("#%d" % int(one[0]))
	return "%d motors are on no port (%s): a hub has six, A to F." % [past.size(), ", ".join(named)]


## A port's motor said: "A, the SPIKE Prime large angular motor #12".
static func port_said(port: String, motor: Dictionary) -> String:
	return "%s, the %s #%d" % [port, motor["name"], int(motor["key"])]


## The ports the program names, each its motor's port: [port] in order, or
## a String saying why it cannot run on [param ports] (ports_of).
func ports_used(ports: Dictionary) -> Variant:
	var hub: Array = HubProgram.lettered(ports)
	var used: Array = []
	var why: Array = [""]
	_ports_in(lines, ports, hub, used, why)
	if not str(why[0]).is_empty():
		return str(why[0])
	return used


func _ports_in(list: Array, ports: Dictionary, hub: Array, used: Array, why: Array) -> void:
	for statement: Statement in list:
		if not str(why[0]).is_empty():
			return
		if statement.verb == "repeat":
			_ports_in(statement.inside, ports, hub, used, why)
			continue
		if statement.verb == "wait":
			continue
		var port: String = statement.port
		if hub.is_empty():
			why[0] = HubProgram.no_hub_words(ports)
			return
		if port.is_empty():
			if hub.size() > 1:
				why[0] = ("Line %d names no motor, and %d are on the hub's ports: %s. Begin it "
					+ "with its port: \"%s %s\".") % [statement.line, hub.size(),
					"; ".join(PackedStringArray(hub.map(func(p: String) -> String:
						return HubProgram.port_said(p, ports[p])))), hub[0], statement.verb]
				var past: String = HubProgram.unported_words(ports)
				if not past.is_empty():
					why[0] += " " + past
				return
			port = hub[0]
		elif not ports.has(port):
			why[0] = "Line %d: no motor is on port %s. %s." % [statement.line, port,
				"; ".join(PackedStringArray(hub.map(func(p: String) -> String:
					return HubProgram.port_said(p, ports[p]))))]
			return
		if not port in used:
			used.append(port)


## Why a program drives nothing in a model with [param ports] (ports_of).
static func no_hub_words(ports: Dictionary) -> String:
	var hubless: Array = ports.get("", [])
	if hubless.is_empty():
		return ("No motor here for a program to drive: put in one that plugs into a hub (a "
			+ "SPIKE Prime, Technic or Powered Up motor) with its output on the axle it turns.")
	if hubless.size() == 1:
		return ("The %s #%d plugs into no hub (a battery box or an IR receiver runs it), so a "
			+ "program does not drive it: Play turns it. A SPIKE Prime, Technic or Powered Up "
			+ "motor takes a program.") % [str((hubless[0] as Array)[1]), int((hubless[0] as Array)[0])]
	return ("No motor here plugs into a hub (a battery box or an IR receiver runs each), so a "
		+ "program drives none of them: Play turns them. A SPIKE Prime, Technic or Powered Up "
		+ "motor takes a program.")


# -- running it ---------------------------------------------------------------------------


## The program run on [param ports] (ports_of), each move as far as
## [param reach] lets it: (port, from, to, turns of the motor from where it
## was built) -> {at, why ("" for there)}. {moves: [{line, port, verb, from,
## to, start, end (seconds)}] in order, waits among them with port ""; seconds;
## stopped: {line, port, at, wanted, why, seconds} when a move did not get
## there (the run ends there, as a hub's waits on a motor that cannot);
## refusal: why it cannot run, else ""}. And, to find where it is at a time
## in a step or two however long it is: starts, every move's start in order;
## by_port, {port: [its moves' starts, their numbers in moves]}.
func run(ports: Dictionary, reach: Callable) -> Dictionary:
	begin_run(ports, reach)
	while not run_step(INF):
		pass
	return ran


## The run [method run_step] makes, as [method run] returns it.
var ran: Dictionary = {}
var _ports: Dictionary = {}
var _reach: Callable
var _hub: Array = []
var _state: Dictionary = {}
## The lines it is going through, the innermost repeat's last: [lines, the
## next of them, times round left].
var _stack: Array = []


## Begin running the program on [param ports] (ports_of), each move as far
## as [param reach] lets it, [method run_step] at a time: Simulation's
## begin_stops and stops_step, a program's way. Made in one go, 2,000 moves
## held a frame 174 ms (hpreview F6).
func begin_run(ports: Dictionary, reach: Callable) -> void:
	# Arrays, not packed ones: a packed array read out of the run to append
	# to is a copy, and the run's stayed empty (every motor at 0, line 0).
	ran = {"moves": [], "seconds": 0.0, "stopped": {}, "refusal": "", "starts": [], "by_port": {}}
	_stack = []
	_state = {}
	if not errors.is_empty():
		ran["refusal"] = "\n".join(errors)
		return
	var used: Variant = ports_used(ports)
	if used is String:
		ran["refusal"] = used
		return
	_ports = ports
	_reach = reach
	_hub = HubProgram.lettered(ports)
	_state = {"t": 0.0, "angles": {}}
	for port: String in used:
		_state["angles"][port] = 0.0
		ran["by_port"][port] = [[], []]
	_stack = [[lines, 0, 1]]


## The run taken on for up to [param budget_ms]: true once it is done, to
## its end, where a move stopped, or refused.
func run_step(budget_ms: float) -> bool:
	var began: int = Time.get_ticks_usec()
	var budget_us: float = budget_ms * 1000.0
	while not _stack.is_empty():
		if Time.get_ticks_usec() - began >= budget_us:
			return false
		var top: Array = _stack.back()
		var list: Array = top[0]
		if int(top[1]) >= list.size():
			top[2] = int(top[2]) - 1
			if int(top[2]) > 0:
				top[1] = 0
			else:
				_stack.pop_back()
			continue
		var statement: Statement = list[int(top[1])]
		top[1] = int(top[1]) + 1
		if statement.verb == "repeat":
			_stack.append([statement.inside, 0, statement.times])
			continue
		if not _move(statement):
			_stack.clear()
	ran["seconds"] = float(_state.get("t", 0.0))
	return true


## [param statement] run from where the run is: false once it stops or is
## refused.
func _move(statement: Statement) -> bool:
	var t: float = _state["t"]
	var moves: Array = ran["moves"]
	if moves.size() >= MOST_MOVES or t > MOST_SECONDS:
		ran["refusal"] = ("This program runs past %d moves or %d minutes; Simulate plays one "
			+ "that does less. Repeat it fewer times.") % [MOST_MOVES, int(MOST_SECONDS / 60.0)]
		return false
	if statement.verb == "wait":
		(ran["starts"] as Array).append(t)
		moves.append({"line": statement.line, "port": "", "verb": "wait", "from": 0.0, "to": 0.0,
			"start": t, "end": t + statement.seconds})
		_state["t"] = t + statement.seconds
		return true
	var port: String = statement.port if not statement.port.is_empty() else str(_hub[0])
	var motor: Dictionary = _ports[port]
	var degrees_a_second: float = float(motor["rpm"]) * 6.0 * absf(statement.speed) / 100.0
	var from: float = float(_state["angles"][port])
	var to: float = from
	match statement.verb:
		"to":
			to = statement.degrees / 360.0
		"turn":
			to = from + statement.degrees / 360.0
		"run":
			to = from + signf(statement.speed) * degrees_a_second * statement.seconds / 360.0
	var got: Dictionary = _reach.call(port, from, to)
	var at: float = float(got.get("at", to))
	var why: String = str(got.get("why", ""))
	var seconds: float = absf(at - from) * 360.0 / degrees_a_second if degrees_a_second > 0.0 else 0.0
	if statement.verb == "run" and why.is_empty():
		seconds = statement.seconds
	var mine: Array = ran["by_port"][port]
	(mine[0] as Array).append(t)
	(mine[1] as Array).append(moves.size())
	(ran["starts"] as Array).append(t)
	moves.append({"line": statement.line, "port": port, "verb": statement.verb, "from": from,
		"to": at, "start": t, "end": t + seconds, "speed": statement.speed,
		"wanted": to})
	_state["angles"][port] = at
	_state["t"] = t + seconds
	if not why.is_empty():
		ran["stopped"] = {"line": statement.line, "port": port, "at": at, "wanted": to, "why": why,
			"seconds": t + seconds}
		return false
	return true


## Where each motor of [param ran] (run) stands [param t] seconds in, turns
## from where it was built: {port: turns}. Its last move begun by then, found
## by halves: read from the first move each frame, a long program's last
## seconds cost its frames more and more.
static func angles_at(ran: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	var moves: Array = ran.get("moves", [])
	var by_port: Dictionary = ran.get("by_port", {})
	for port: String in by_port:
		var starts: Array = (by_port[port] as Array)[0]
		var numbers: Array = (by_port[port] as Array)[1]
		if starts.is_empty():
			continue
		var k: int = starts.bsearch(t, false) - 1
		var move: Dictionary = moves[int(numbers[maxi(k, 0)])]
		if k < 0:
			out[port] = float(move["from"])
			continue
		var start: float = move["start"]
		var end: float = move["end"]
		var share: float = 1.0 if end <= start or t >= end else (t - start) / (end - start)
		out[port] = lerpf(float(move["from"]), float(move["to"]), share)
	return out


## The line running [param t] seconds in (from 1), or 0 once it is done:
## the last move begun by then that is still going or takes no time.
static func line_at(ran: Dictionary, t: float) -> int:
	var moves: Array = ran.get("moves", [])
	var starts: Array = ran.get("starts", [])
	var k: int = starts.bsearch(t, false) - 1
	while k >= 0:
		var move: Dictionary = moves[k]
		if t < float(move["end"]) or float(move["end"]) <= float(move["start"]):
			return int(move["line"])
		k -= 1
	return 0


## A turn of a motor in degrees, to a tenth: "90°", "-20.9°".
static func degrees(turns: float) -> String:
	return "%s°" % Simulation.figure(snappedf(turns * 360.0, 0.1))


## What the run did, in a line or two for the person: where it stopped and
## why, or how long it took and where each motor ended.
static func ran_words(ran: Dictionary, ports: Dictionary) -> String:
	if not str(ran.get("refusal", "")).is_empty():
		return str(ran["refusal"])
	var stopped: Dictionary = ran.get("stopped", {})
	if not stopped.is_empty():
		return ("Line %d: %s stops at %s on its way to %s, %s s in: %s.") % [int(stopped["line"]),
			port_said(str(stopped["port"]), ports[stopped["port"]]), degrees(float(stopped["at"])),
			degrees(float(stopped["wanted"])), Simulation.figure(snappedf(float(stopped["seconds"]), 0.01)),
			stopped["why"]]
	# Where each motor ends, a port and its angle ("A 0°, B -45°"): no words
	# for a language to say otherwise.
	var ends := PackedStringArray()
	var at: Dictionary = angles_at(ran, INF)
	for port: String in at:
		ends.append("%s %s" % [port, degrees(float(at[port]))])
	var seconds: String = Simulation.figure(snappedf(float(ran.get("seconds", 0.0)), 0.01))
	var past: String = unported_words(ports)
	if ends.is_empty():
		return ("Ran to its end in %s s." % seconds + (" " + past if not past.is_empty() else ""))
	return "Ran to its end in %s s: %s." % [seconds, ", ".join(ends)] + (" " + past if not past.is_empty() else "")


## The run move by move, for a session: up to [param most] lines, then how
## many more.
static func moves_words(ran: Dictionary, ports: Dictionary, most: int = 14) -> PackedStringArray:
	var out := PackedStringArray()
	var moves: Array = ran.get("moves", [])
	for move: Dictionary in moves.slice(0, most):
		var span: String = "%s-%s s" % [Simulation.figure(snappedf(float(move["start"]), 0.001)),
			Simulation.figure(snappedf(float(move["end"]), 0.001))]
		if str(move["port"]).is_empty():
			out.append("%s line %d: wait" % [span, int(move["line"])])
			continue
		var motor: Dictionary = ports[move["port"]]
		out.append("%s line %d: %s from %s to %s at %s%% (%s°/s)" % [span, int(move["line"]),
			move["port"], degrees(float(move["from"])), degrees(float(move["to"])),
			Simulation.figure(absf(float(move["speed"]))),
			Simulation.figure(snappedf(float(motor["rpm"]) * 6.0 * absf(float(move["speed"])) / 100.0, 0.1))])
	if moves.size() > most:
		out.append("... and %d more" % (moves.size() - most))
	return out


# -- where a move stops ----------------------------------------------------------------------


## [param simulation]'s torque curve (Simulation.asked and asked_back), the
## turns of its driver ascending: what [method reach_in] stalls a move on.
static func curve_of(simulation: Simulation) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(simulation.asked_back)
	out.append_array(simulation.asked)
	out.sort()
	return out


## How far a move of [param simulation]'s driver from [param from] to
## [param to] (turns from where it was built) gets, as Simulate found the
## motion stops (Simulation.begin_stops, done): {at, why, "" when it gets
## there}. Short of what meets, of where the loop it closes goes no further,
## of what was checked; and where the weight asks more of its motor, going
## that way, than the motor gives ([param curve], curve_of), found as
## Simulation finds a stall: between the steps either side.
static func reach_in(simulation: Simulation, curve: PackedVector2Array, from: float, to: float) -> Dictionary:
	if absf(to - from) < 1e-9:
		return {"at": to, "why": ""}
	var way: float = signf(to - from)
	var at: float = to
	var why: String = ""
	var loop: float = simulation.loop_reach.y if way > 0.0 else simulation.loop_reach.x
	var met: Dictionary = simulation.meets if way > 0.0 else simulation.meets_back
	var checked: float = simulation.checked.y if way > 0.0 else simulation.checked.x
	if not met.is_empty() and (float(met["turns"]) - at) * way < 0.0:
		at = float(met["turns"])
		why = "%s meets %s" % [simulation._part_said(int(met["key"])), simulation._part_said(int(met["other"]))]
	if (loop - at) * way < 0.0:
		at = loop
		why = "the loop it closes goes no further"
	if not simulation.periodic and (checked - at) * way < 0.0:
		at = checked
		why = "Simulate checked its turn no further"
	if (at - from) * way < 0.0:
		at = from
	if simulation.motor != 0 and simulation.motors.has(simulation.motor):
		var it: Array = Simulation.MOTORS[simulation.motors[simulation.motor]]
		var gives: float = float(it[1])
		# Found no further than where it stops already (the walk ends there);
		# round a train that comes round whole, its cycle's curve again.
		var stall: float = _stall_round(simulation.asked, simulation.checked.y, gives, from, at, way) \
			if simulation.periodic and simulation.checked.y > 0.0 \
			else _stall_on(curve, gives, from, at, way)
		if not is_nan(stall):
			at = stall
			why = ("its motor stalls: the weight it lifts asks more than the %s N·cm it gives at %s V"
				% [Simulation.figure(gives), Simulation.figure(float(it[3]))])
	return {"at": at, "why": why}


## [method _stall_on] over [param points] (turns within one [param period],
## ascending) repeated round every period, walked from [param from] as the
## move goes rather than laid out first: tiled and sorted over the whole of
## each move, 2,000 moves of 1° held a frame 174 ms and one run of 1,750
## turns 71 (hpreview F6). A cycle walked round whole with nothing over
## [param gives] has none further on: what the weight asks repeats.
static func _stall_round(points: PackedVector2Array, period: float, gives: float, from: float,
		to: float, way: float) -> float:
	var count: int = points.size()
	if count == 0 or period <= 0.0:
		return NAN
	var lap: int = floori(from / period)
	if way > 0.0:
		var g: int = lap * count + points.bsearch(Vector2(from - lap * period, INF), true)
		var prev: Vector2 = _round_point(points, period, g - 1)
		for _n: int in count + 1:
			var point: Vector2 = _round_point(points, period, g)
			if point.x > to:
				return NAN
			if point.y > gives:
				var x: float = point.x
				if point.y > prev.y:
					x = lerpf(prev.x, x, (gives - prev.y) / (point.y - prev.y))
				return maxf(x, from)
			prev = point
			g += 1
		return NAN
	var j: int = lap * count + points.bsearch(Vector2(from - lap * period, -INF), true) - 1
	var after: Vector2 = _round_point(points, period, j + 1)
	var last := Vector2(after.x, -after.y)
	for _n: int in count + 1:
		var point: Vector2 = _round_point(points, period, j)
		if point.x < to:
			return NAN
		var asked: float = -point.y
		if asked > gives:
			var x: float = point.x
			if asked > last.y:
				x = lerpf(last.x, x, (gives - last.y) / (asked - last.y))
			return minf(x, from)
		last = Vector2(point.x, asked)
		j -= 1
	return NAN


## Point [param g] of [param points] repeated round every [param period]:
## point g mod their count, a period on for each time round.
static func _round_point(points: PackedVector2Array, period: float, g: int) -> Vector2:
	var count: int = points.size()
	var lap: int = floori(float(g) / float(count))
	var point: Vector2 = points[g - lap * count]
	return Vector2(point.x + float(lap) * period, point.y)


## The first turn from [param from] towards [param to] where the torque
## going that way ([param points]: turns, N·cm going on, ascending) is more
## than [param gives], found between the points either side as
## Simulation._weigh_step finds a stall; NAN for none.
static func _stall_on(points: PackedVector2Array, gives: float, from: float, to: float, way: float) -> float:
	var count: int = points.size()
	if count == 0:
		return NAN
	var prev := Vector2(NAN, NAN)
	if way > 0.0:
		var k: int = points.bsearch(Vector2(from, INF), true)
		if k > 0:
			prev = points[k - 1]
		while k < count and points[k].x <= to:
			var asked: float = points[k].y
			if asked > gives:
				var x: float = points[k].x
				if not is_nan(prev.y) and asked > prev.y:
					x = lerpf(prev.x, x, (gives - prev.y) / (asked - prev.y))
				return maxf(x, from)
			prev = points[k]
			k += 1
		return NAN
	var j: int = points.bsearch(Vector2(from, -INF), true) - 1
	if j + 1 < count:
		prev = Vector2(points[j + 1].x, -points[j + 1].y)
	while j >= 0 and points[j].x >= to:
		var asked: float = -points[j].y
		if asked > gives:
			var x: float = points[j].x
			if not is_nan(prev.y) and asked > prev.y:
				x = lerpf(prev.x, x, (gives - prev.y) / (asked - prev.y))
			return minf(x, from)
		prev = Vector2(points[j].x, asked)
		j -= 1
	return NAN
