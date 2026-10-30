## The app's last log lines, kept so Help, Send feedback… can offer them
## with a report ([FeedbackDialog]): what the app was doing when something
## went wrong, which nobody can be asked to dig out of a file (and on the
## web there is no file). Kept in memory only, the last [constant KEPT]
## lines, and sent only when the person ticks it, having been able to read
## every one.
##
## The engine calls a logger from whichever thread printed, so every write
## and every read holds the lock.
class_name RecentLog
extends Logger

const KEPT := 200
## Characters of one line kept: a stack of numbers printed in one line is
## not worth the rest.
const WIDEST := 400
const KINDS: Array[String] = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]

var _lines: PackedStringArray = []
var _lock := Mutex.new()


func _log_message(message: String, error: bool) -> void:
	_keep(("ERROR: " if error else "") + message)


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	_keep("%s: %s (%s:%d, %s)" % [KINDS[clampi(error_type, 0, KINDS.size() - 1)],
		rationale if not rationale.is_empty() else code, file.get_file(), line, function])


func _keep(said: String) -> void:
	var lines: PackedStringArray = said.strip_edges(false, true).split("\n", false)
	_lock.lock()
	for one: String in lines:
		_lines.append(one.left(WIDEST))
	if _lines.size() > KEPT:
		_lines = _lines.slice(_lines.size() - KEPT)
	_lock.unlock()


## The last [param most] lines, oldest first.
func last(most: int = KEPT) -> PackedStringArray:
	_lock.lock()
	var out: PackedStringArray = _lines.slice(maxi(0, _lines.size() - most))
	_lock.unlock()
	return out
