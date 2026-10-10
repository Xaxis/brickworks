## An Anthropic key belonging to the person using the app.
##
## The assistant runs on real money and there is no payment system here
## yet, so it runs on your key. What that has to mean, exactly:
##
##   The key never reaches our server. Requests made with it go straight
##   from this machine to api.anthropic.com. There is no proxy in the
##   path, nothing to log it, and no copy of it anywhere we control.
##
##   It is kept on this device so it does not have to be typed again —
##   in the app's own data directory on the desktop, and in the
##   browser's storage for this site on the web. Both are readable by
##   anything else running as you, which is worth saying rather than
##   implying: this is convenience, not a vault.
##
##   Forgetting it removes it. Nothing survives that.
##
## Anthropic's keys are worth spending, so the last of those matters as
## much as the first.
class_name OwnKey
extends RefCounted

const WHERE := "user://anthropic.key"

## Keys look like this. Checked before the first request rather than
## after, because a typo comes back as a 401 several seconds later and
## reads as "the assistant is broken".
const PREFIX := "sk-ant-"


## A key kept for this visit only, never written anywhere. Chosen by
## unticking "Remember on this device": a key in the browser's storage
## outlives the tab, and on a shared computer that is the wrong default to
## force on anyone.
static var _this_visit: String = ""

## A Claude subscription's sign-in token, which is not an API key and must
## never be used as one: Anthropic does not allow a product to route
## requests through a plan's credentials. Someone who pastes one is told
## how to use their plan the allowed way instead.
const SUBSCRIPTION_PREFIX := "sk-ant-oat"


## The key in use, or empty: this visit's if there is one, else the one
## kept on this device.
static func load_key() -> String:
	if not _this_visit.is_empty():
		return _this_visit
	var file: FileAccess = FileAccess.open(WHERE, FileAccess.READ)
	if file == null:
		return ""
	var key: String = file.get_as_text().strip_edges()
	file.close()
	return key


static func has_key() -> bool:
	return not load_key().is_empty()


## What is wrong with a key as typed, or empty when it looks like one.
static func problem_with(key: String) -> String:
	var tidy: String = key.strip_edges()
	if tidy.is_empty():
		return "Paste a key first."
	if tidy.begins_with(SUBSCRIPTION_PREFIX):
		return ("That is a Claude subscription's sign-in token, not an API "
			+ "key, and Anthropic does not allow apps to use one. To design "
			+ "on your plan, connect Claude to Brickworks instead.")
	if not tidy.begins_with(PREFIX):
		return "An Anthropic key starts with %s." % PREFIX
	if tidy.length() < 40:
		return "That looks too short to be a whole key."
	return ""


## Keep it, on this device or for this visit only. Returns something to
## show on failure.
static func remember(key: String, on_device: bool = true) -> String:
	var problem: String = problem_with(key)
	if not problem.is_empty():
		return problem
	var tidy: String = key.strip_edges()
	if not on_device:
		# Not written anywhere, and nothing older left behind to be used
		# in its place on the next visit.
		_this_visit = tidy
		if FileAccess.file_exists(WHERE):
			DirAccess.remove_absolute(WHERE)
		return ""
	_this_visit = ""

	var file: FileAccess = FileAccess.open(WHERE, FileAccess.WRITE)
	if file == null:
		return "Could not save the key on this device."
	file.store_string(tidy)
	file.close()
	return ""


static func forget() -> void:
	_this_visit = ""
	if not FileAccess.file_exists(WHERE):
		return
	# On the web this path lives in the browser's storage rather than on
	# a disk, and DirAccess handles both.
	DirAccess.remove_absolute(WHERE)


## Enough of the key to recognise it, and not enough to use it. Shown
## instead of the key itself so a screenshot of the panel is not a
## leaked credential.
static func fingerprint() -> String:
	var key: String = load_key()
	if key.is_empty():
		return ""
	if key.length() < 12:
		return "…"
	return "%s…%s" % [key.substr(0, 11), key.substr(key.length() - 4)]
