## Which key does what: the app's own keys, a preset after the program a
## person comes from (Studio's, Mecabricks', LDCad's), and the keys they
## set themselves in the keys sheet (APP_UX A11).
##
## The app's keys are where they always were, in the handlers that answer
## them (EditVerbs, Shell, Main) and in the menus' table (Shell._define).
## This does not move them: it reads a key as the person's keymap has it
## and hands the handlers the key they know. Studio's C is the Clone tool;
## a press of C is taken here for the Clone tool and run. Studio's right
## arrow turns the part; it reaches the handlers as R, and so turns as R
## does, about a joint, in hand or on the model, with a number typed after
## it. And the key a preset took a command off does nothing, rather than
## what it did before: Studio's L is the Hide tool, never the lock.
##
## Every action is a command of the menus, by its name there, or one of
## [constant KEY_ACTIONS], what a key does that is in no menu (the other
## way of R, the arrows, the colours). Each has the key that does it out of
## the box, which the handlers answer, or none, when it is only run.
##
## Kept on this device with the layout (ShellPrefs "key_preset" and
## "keys"), and with the account for somebody signed in (KeymapSync), so a
## new browser has their keys once they sign in.
class_name Keymap
extends RefCounted

const CTRL := KEY_MASK_CMD_OR_CTRL
const SHIFT := KEY_MASK_SHIFT
const ALT := KEY_MASK_ALT

## The presets, in the order Settings and the keys sheet offer them.
const PRESETS: Array[String] = ["brickworks", "studio", "mecabricks", "ldcad"]
const PRESET_NAMES: Dictionary = {"brickworks": "Brickworks", "studio": "BrickLink Studio",
	"mecabricks": "Mecabricks", "ldcad": "LDCad"}

## What a key does that no menu holds: [name, words, the key that does it].
## A key of 0 is an action no key does out of the box, which a preset or a
## person binds: Studio's arrows turn the part, as R does (Main reads the
## key as R), and Shift with them turns it by 45°, which Main does itself.
const KEY_ACTIONS: Array = [
	["turn_back", "turn the other way", SHIFT | KEY_R],
	["tip_back", "tip it back", SHIFT | KEY_T],
	["swing_back", "swing it back", SHIFT | KEY_J],
	["colour_back", "the colour before", KEY_BRACKETLEFT],
	["colour_on", "the colour after", KEY_BRACKETRIGHT],
	["pick", "take the part under the pointer into hand", KEY_G],
	["lift", "lift the part under the pointer, or the selection, to move it", KEY_X],
	["nudge_forward", "move the selection away; with none, slide the view", KEY_W],
	["nudge_left", "move the selection left; with none, slide the view", KEY_A],
	["nudge_back", "move the selection nearer; with none, slide the view", KEY_S],
	["nudge_right", "move the selection right; with none, slide the view", KEY_D],
	["arrow_up", "move the selection away; with none, tilt the view", KEY_UP],
	["arrow_down", "move the selection nearer; with none, tilt the view", KEY_DOWN],
	["arrow_left", "move the selection left; with none, turn the view", KEY_LEFT],
	["arrow_right", "move the selection right; with none, turn the view", KEY_RIGHT],
	["raise", "raise the selection; with none, zoom in", KEY_PAGEUP],
	["lower", "lower the selection; with none, zoom out", KEY_PAGEDOWN],
	["zoom_in", "zoom in", KEY_EQUAL],
	["zoom_out", "zoom out", KEY_MINUS],
	["search", "search the parts", KEY_SLASH],
	["part_left", "turn the part in hand, or the selection, left", 0],
	["part_right", "turn the part in hand, or the selection, right", 0],
	["part_forward", "tip the part in hand, or the selection, forward", 0],
	["part_back", "tip the part in hand, or the selection, back", 0],
	["part_left_45", "turn the selection 45° left", 0],
	["part_right_45", "turn the selection 45° right", 0],
]

## The key each of those 0s is done by: a press of it reaches the handlers
## as this one.
const DONE_AS: Dictionary = {"part_left": SHIFT | KEY_R, "part_right": KEY_R,
	"part_forward": KEY_T, "part_back": SHIFT | KEY_T}

## Each preset's keys where they are not the app's own: an action and its
## key, or 0 for none. Anything a preset does not name keeps the app's key,
## unless the preset gave that key to something else.
##
## The app's own preset gives the tools that had none theirs: Shift and a
## letter, beside the key that does the same to a selection (X lifts,
## Shift-X the Move tool) or near it.
##
## Studio's are its shortcut page's defaults (studiohelp 5706320095255):
## its tools V, H, C and L, Ctrl-L to hide, its arrows that turn, WASD that
## move, Ctrl-U to release a sub-model and Ctrl-T for a step. Studio leaves
## Paint, Connect and Frame selection with no key, and so does this.
## Mecabricks': W selects, D clones, M moves, F reshapes a flexible part;
## its S, snap, is Connect's. LDCad's (melkert.net/LDCad/docs/keys): M the
## move pin, C centres on the selection, Z fits, V switches the projection,
## H hides, Ctrl-Shift-H shows all, Insert the part again.
##
## Connect is the app's N; Studio's keep that, having none of their own.
## A name no command has is passed over, so a line may go in before its
## command does.
const PRESET_KEYS: Dictionary = {
	"brickworks": {
		"mode_move": SHIFT | KEY_X, "mode_rotate": SHIFT | KEY_O, "mode_hinge": SHIFT | KEY_I,
		"mode_clone": SHIFT | KEY_V, "mode_paint": SHIFT | KEY_P, "mode_hide": SHIFT | KEY_G,
		"mode_delete": SHIFT | KEY_DELETE,
	},
	"studio": {
		"mode_select": KEY_V, "mode_hinge": KEY_H, "mode_clone": KEY_C, "mode_hide": KEY_L,
		"hide": CTRL | KEY_L, "show_all": CTRL | SHIFT | KEY_L,
		"select_inverse": CTRL | SHIFT | KEY_V,
		"make_submodel": CTRL | KEY_G, "leave_submodel": CTRL | KEY_U,
		"step_new": CTRL | KEY_T,
		"part_left": KEY_LEFT, "part_right": KEY_RIGHT,
		"part_forward": KEY_UP, "part_back": KEY_DOWN,
		"part_left_45": SHIFT | KEY_LEFT, "part_right_45": SHIFT | KEY_RIGHT,
		"fit_model": CTRL | KEY_0, "zoom_in": CTRL | KEY_EQUAL, "zoom_out": CTRL | KEY_MINUS,
		"search": CTRL | KEY_F,
		"paint": 0,
	},
	"mecabricks": {
		"mode_select": KEY_W, "mode_clone": KEY_D, "mode_move": KEY_M, "reshape_flex": KEY_F,
		"mode_connect": KEY_S, "nudge_forward": 0, "nudge_left": 0, "nudge_back": 0, "nudge_right": 0,
	},
	"ldcad": {
		"mode_move": KEY_M, "fit_selection": KEY_C, "fit_model": KEY_Z, "ortho": KEY_V,
		"hide": KEY_H, "show_all": CTRL | SHIFT | KEY_H, "select_none": CTRL | SHIFT | KEY_A,
		"leave_assembly": SHIFT | KEY_N, "mode_place": KEY_INSERT,
		"step_close": CTRL | KEY_INSERT,
	},
}

## Keys that are never anybody's to set: out of whatever is open, put down,
## the panels and the keys' way round them, play, the ends of the
## timeline, and this sheet itself, so a person can always find their way
## back to it.
const FIXED: Array[int] = [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_F6, KEY_SPACE,
	KEY_HOME, KEY_END, KEY_F1, KEY_BACKSPACE]

## Keys a browser keeps for itself, which a page never hears: a preset's
## binding to one is passed over there, and a person cannot choose one.
const BROWSER_KEEPS: Array[int] = [CTRL | KEY_N, CTRL | KEY_T, CTRL | KEY_W,
	CTRL | SHIFT | KEY_N, CTRL | SHIFT | KEY_T, CTRL | SHIFT | KEY_W, CTRL | KEY_TAB,
	CTRL | SHIFT | KEY_TAB, CTRL | KEY_R, CTRL | SHIFT | KEY_R]

## The keys a timeline being played answers, whatever the keymap: its own.
const TIMELINE_KEYS: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_SPACE]

## What Shift makes of a key, as a browser names it: back to the key.
const UNSHIFTED: Dictionary = {KEY_BRACELEFT: KEY_BRACKETLEFT, KEY_BRACERIGHT: KEY_BRACKETRIGHT,
	KEY_PLUS: KEY_EQUAL, KEY_UNDERSCORE: KEY_MINUS, KEY_ASCIITILDE: KEY_QUOTELEFT,
	KEY_EXCLAM: KEY_1, KEY_AT: KEY_2, KEY_NUMBERSIGN: KEY_3, KEY_DOLLAR: KEY_4,
	KEY_PERCENT: KEY_5, KEY_ASCIICIRCUM: KEY_6, KEY_AMPERSAND: KEY_7, KEY_ASTERISK: KEY_8,
	KEY_PARENLEFT: KEY_9, KEY_PARENRIGHT: KEY_0, KEY_COLON: KEY_SEMICOLON,
	KEY_QUOTEDBL: KEY_APOSTROPHE, KEY_LESS: KEY_COMMA, KEY_GREATER: KEY_PERIOD,
	KEY_QUESTION: KEY_SLASH, KEY_BAR: KEY_BACKSLASH}

## Every action's key out of the box (the handlers' own) and its words.
static var _native: Dictionary = {}
static var _words: Dictionary = {}
## Now: each action's key (0 for none), and each key's action.
static var _bound: Dictionary = {}
static var _by_key: Dictionary = {}
## Each key's action out of the box.
static var _native_of: Dictionary = {}
static var _built: bool = false
## The web, where the browser keeps some keys: set by a check to try them.
static var web: bool = OS.has_feature("web")


## A command of the menus' table and its key (Shell._add).
static func learn(name: String, words: String, accel: int) -> void:
	_native[name] = accel
	_words[name] = words.trim_suffix("…")
	_built = false


static func _learn_own() -> void:
	if _words.has(KEY_ACTIONS[0][0]):
		return
	for action: Array in KEY_ACTIONS:
		_native[action[0]] = action[2]
		_words[action[0]] = action[1]


## The preset chosen: one of [constant PRESETS].
static func preset() -> String:
	var chosen: String = str(ShellPrefs.value("key_preset"))
	return chosen if chosen in PRESETS else "brickworks"


## The keys a person set themselves: action -> key, 0 for none.
static func own() -> Dictionary:
	return ShellPrefs.value("keys")


static func use(chosen: String) -> void:
	if not chosen in PRESETS:
		return
	ShellPrefs.put("key_preset", chosen)
	_changed()


## Whether [param action] is one this knows: a command, or a key's own.
static func has(action: String) -> bool:
	_learn_own()
	return _words.has(action)


static func words(action: String) -> String:
	_learn_own()
	return str(_words.get(action, action))


## The key [param action] has now; 0 for none.
static func key_of(action: String) -> int:
	_build()
	return int(_bound.get(action, 0))


## The action [param accel] is the key of now, or "".
static func action_of(accel: int) -> String:
	_build()
	return str(_by_key.get(accel, ""))


## The action [param accel] is the key of out of the box, or "".
static func native_action(accel: int) -> String:
	_build()
	return str(_native_of.get(accel, ""))


## As the menus write it: "Ctrl+Z"; "" for none.
static func written(action: String) -> String:
	return Shell.key_text(key_of(action))


## As the keys list writes it: "Ctrl-shift-S", "shift-R", "F2"; "" for none.
static func listed(action: String) -> String:
	return listed_key(key_of(action))


const NAMED: Dictionary = {KEY_PAGEUP: "Page Up", KEY_PAGEDOWN: "Page Down",
	KEY_ESCAPE: "Esc", KEY_LEFT: "Left", KEY_RIGHT: "Right", KEY_UP: "Up", KEY_DOWN: "Down"}


static func listed_key(accel: int) -> String:
	if accel == 0:
		return ""
	var code: int = accel & KEY_CODE_MASK
	var parts: PackedStringArray = Shell.key_text(accel & ~KEY_CODE_MASK | KEY_A).split("+")
	parts[parts.size() - 1] = str(NAMED[code]) if NAMED.has(code) else Shell.key_text(code)
	for n: int in parts.size() - 1:
		if parts[n] != EditVerbs.held_key():
			parts[n] = parts[n].to_lower()
	return "-".join(parts)


## A key press as a key and its modifiers: Shift with a symbol is the key
## under it, as the desktop names it and a browser does not.
static func accel_of(key: InputEventKey) -> int:
	var code: int = key.keycode
	if key.shift_pressed and UNSHIFTED.has(code):
		code = UNSHIFTED[code]
	var accel: int = code
	if key.ctrl_pressed or key.meta_pressed:
		accel |= CTRL
	if key.shift_pressed:
		accel |= SHIFT
	if key.alt_pressed:
		accel |= ALT
	return accel


## What a key press is to the handlers, as the keymap has it:
## - the press itself, when it is the key it always was;
## - another press, the key that does what this one is bound to;
## - a String, an action to run that no key does out of the box;
## - null, a key this keymap took off what it did and gave to nothing.
## [param timeline]: a timeline is being played, which keeps its own keys.
static func read(key: InputEventKey, timeline: bool = false) -> Variant:
	_build()
	if key.keycode in [KEY_SHIFT, KEY_CTRL, KEY_META, KEY_ALT]:
		return key
	if key.keycode in FIXED or (timeline and key.keycode in TIMELINE_KEYS):
		return key
	var pressed: int = accel_of(key)
	var action: String = str(_by_key.get(pressed, ""))
	if action.is_empty():
		var was: String = str(_native_of.get(pressed, _native_of.get(pressed & KEY_CODE_MASK, "")))
		if not was.is_empty() and int(_bound.get(was, 0)) != int(_native[was]):
			return null
		return key
	var does: int = int(DONE_AS.get(action, _native.get(action, 0)))
	if does == 0:
		return action
	if does == pressed:
		return key
	return press_of(does, key)


## A press of [param accel], held as [param like] is (down or up, a repeat).
static func press_of(accel: int, like: InputEventKey = null) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = accel & KEY_CODE_MASK
	event.physical_keycode = event.keycode
	event.pressed = like == null or like.pressed
	event.echo = like != null and like.echo
	if accel & CTRL:
		if EditVerbs.on_mac():
			event.meta_pressed = true
		else:
			event.ctrl_pressed = true
	event.shift_pressed = accel & SHIFT != 0
	event.alt_pressed = accel & ALT != 0
	return event


## Whether a key held down still does what it always did: the view's keys
## held (Main._steer_from_keys) ask, and a key a preset gave to a tool
## does not slide the view while it is held.
static func held_as_ever(keycode: int) -> bool:
	_build()
	var was: String = str(_native_of.get(keycode, ""))
	if _by_key.has(keycode) and str(_by_key[keycode]) != was:
		return false
	return was.is_empty() or int(_bound.get(was, 0)) == keycode


## Set [param action]'s key, or none with 0. "" when it is set, or why not
## in a few words: the key is another's, or the browser's, or not to be set.
static func bind(action: String, accel: int) -> String:
	_build()
	if not has(action):
		return "No such command"
	var trouble: String = why_not(action, accel)
	if not trouble.is_empty():
		return trouble
	var mine: Dictionary = own().duplicate()
	mine[action] = accel
	ShellPrefs.put("keys", mine)
	_changed()
	return ""


## Why [param accel] cannot be [param action]'s key; "" when it can.
static func why_not(action: String, accel: int) -> String:
	if accel == 0:
		return ""
	var code: int = accel & KEY_CODE_MASK
	if code in FIXED or code in [KEY_SHIFT, KEY_CTRL, KEY_META, KEY_ALT]:
		return "%s is kept for itself" % listed_key(accel)
	if not settable(action):
		return "%s stays %s" % [words(action), listed_key(int(_native[action]))]
	if web and accel in BROWSER_KEEPS:
		return "the browser keeps %s for itself" % listed_key(accel)
	var holder: String = action_of(accel)
	if not holder.is_empty() and holder != action:
		return "%s is already the key for %s" % [listed_key(accel), words(holder)]
	return ""


## Whether a person may set [param action]'s key: not one done by a key
## that is never anybody's (Enter into a sub-assembly, F1 for this sheet).
static func settable(action: String) -> bool:
	_learn_own()
	return has(action) and not (int(_native.get(action, 0)) & KEY_CODE_MASK) in FIXED


## Back to the preset's keys alone.
static func reset() -> void:
	ShellPrefs.put("keys", {})
	_changed()


## A change made here: when, for the newer of this device's keys and the
## account's to win (KeymapSync).
static func _changed() -> void:
	ShellPrefs.put("keys_at", Time.get_unix_time_from_system())
	_built = false


## The keys as the account keeps them: the preset, the keys set over it,
## and when.
static func kept() -> Dictionary:
	return {"preset": preset(), "own": own(), "at": float(ShellPrefs.value("keys_at"))}


## The account's keys, taken here as they are (KeymapSync). False when
## what came is not keys.
static func take(theirs: Dictionary) -> bool:
	var chosen: String = str(theirs.get("preset", ""))
	var keys: Variant = theirs.get("own")
	if not chosen in PRESETS or not keys is Dictionary:
		return false
	var mine: Dictionary = {}
	for action: Variant in keys:
		var key: Variant = (keys as Dictionary)[action]
		if action is String and (key is int or key is float):
			mine[action] = int(key)
	ShellPrefs.put("key_preset", chosen)
	ShellPrefs.put("keys", mine)
	ShellPrefs.put("keys_at", float(theirs.get("at", 0.0)))
	_built = false
	return true


## Who has which key: the person's own first, then the preset's, then the
## app's tools', then each action's own key. A key taken higher up is no
## longer what it was lower down: Studio's C is the Clone tool, and paint
## has none.
static func _build() -> void:
	if _built:
		return
	_learn_own()
	_built = true
	_bound.clear()
	_by_key.clear()
	_native_of.clear()
	for action: String in _native:
		var native: int = int(_native[action])
		if native != 0 and not _native_of.has(native):
			_native_of[native] = action
	var layers: Array = [own(), PRESET_KEYS[preset()]]
	if preset() != "brickworks":
		layers.append(PRESET_KEYS["brickworks"])
	layers.append(_native)
	for at: int in layers.size():
		var layer: Dictionary = layers[at]
		for action: String in layer:
			if _bound.has(action) or not _native.has(action):
				continue
			var key: int = int(layer[action])
			# The app's own keys are what the browser lets it have already.
			if key != 0 and web and key in BROWSER_KEEPS and at < layers.size() - 1:
				continue
			if key != 0 and _by_key.has(key):
				key = 0
			_bound[action] = key
			if key != 0:
				_by_key[key] = action


## Every action, for the sheet and the checks: commands first, as the
## menus' table has them, then the keys' own.
static func actions() -> Array[String]:
	_learn_own()
	var out: Array[String] = []
	for action: String in _native:
		out.append(action)
	return out

