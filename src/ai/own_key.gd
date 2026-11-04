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
##   on the desktop in the system's keychain where one answers, else in a
##   file of the app's own data encrypted to this computer; on the web in
##   the browser's storage for this site, scrambled (KeyStore says where,
##   and why). Anything else running as you could still ask for it, which
##   is worth saying rather than implying: this is convenience, not a vault.
##
##   Forgetting it removes it, from the keychain and the file both.
##   Nothing survives that.
##
## Anthropic's keys are worth spending, so the last of those matters as
## much as the first.
class_name OwnKey
extends RefCounted

## Its file where no keychain answers, and its name in one (KeyStore).
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
	return KeyStore.read(WHERE)


## Whether there is a key, without asking a keychain for it.
static func has_key() -> bool:
	return not _this_visit.is_empty() or KeyStore.kept(WHERE)


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
		KeyStore.remove(WHERE)
		return ""
	_this_visit = ""
	if KeyStore.write(WHERE, tidy).is_empty():
		return "Could not save the key on this device."
	return ""


static func forget() -> void:
	_this_visit = ""
	KeyStore.remove(WHERE)


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
