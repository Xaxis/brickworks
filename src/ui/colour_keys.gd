## Colours on keys (APP_UX2 gap 2, keys3): ten favourite colours and the
## model's ten most used, a key each, that paint the selection or are the
## colour of the part in hand, as a swatch clicked in the palette is.
##
## A colour was up to five presses of [ and ] and a C, and none of a
## person's own colours was on a key. Studio has nine favourite colours to
## bind (FavoriteColor_1 to 9, with no key out of the box), Mecabricks and
## LDCad none.
##
## The keys are the digit row's: Shift with 1 to 0 for the favourites, and
## Ctrl and Shift with them for the model's most used, 1 the most. Neither
## is a browser's: Ctrl with 1 to 8 switches tabs in every browser, and Alt
## with 1 to 9 does in Firefox on Linux. The digits alone are the views. The
## app's own keys (Keymap.PRESET_KEYS' "brickworks") have them; under
## Studio's they start with none, as Studio's do, and the keys sheet sets
## any of them under any preset.
##
## The favourites are set in the keys sheet (ControlsDialog) and kept with
## the keys (ShellPrefs "favourite_colours", and the account's, KeymapSync).
class_name ColourKeys
extends RefCounted

const COUNT := 10

## Out of the box: the colours LEGO® sets use most, by Rebrickable's
## inventories, the most first: Black, Light Bluish Grey, White, Dark
## Bluish Grey, Red, Yellow, Blue, Tan, Reddish Brown and Green.
const FAVOURITES: Array[int] = [0, 71, 15, 72, 4, 14, 1, 19, 70, 2]

## The digit row in order, 1 to 9 then 0.
const DIGITS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

## LDraw's "inherit" codes: no part is made in them.
const NOT_A_COLOUR: Array[int] = [16, 24]

const FAVOURITE := "favourite_"
const MOST_USED := "most_used_"

## Every colour key's action, the favourites first: favourite_1 to 10,
## most_used_1 to 10.
static var ACTIONS: Array[String] = _actions()


static func _actions() -> Array[String]:
	var out: Array[String] = []
	for prefix: String in [FAVOURITE, MOST_USED]:
		for n: int in COUNT:
			out.append(prefix + str(n + 1))
	return out


## Whether [param action] is one of these keys.
static func owns(action: String) -> bool:
	return action in ACTIONS


## Its place, 0 to 9.
static func place(action: String) -> int:
	return int(action.get_slice("_", action.get_slice_count("_") - 1)) - 1


## Its words, as the keys sheet and a refusal name it: "favourite colour 3",
## "the model's 2nd most used colour".
static func words(action: String) -> String:
	var n: int = place(action) + 1
	if action.begins_with(FAVOURITE):
		return "favourite colour %d" % n
	return "the model's most used colour" if n == 1 \
		else "the model's %s most used colour" % nth(n)


static func nth(n: int) -> String:
	var tail: String = "th"
	if n % 100 < 11 or n % 100 > 13:
		tail = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, tail]


## A preset's keys for these, as Keymap layers them: the app's own gives
## the digit row; Studio's none, as Studio leaves its favourites unbound;
## the others nothing of their own, so they have the app's.
static func preset_keys(preset: String) -> Dictionary:
	var out: Dictionary = {}
	if preset == "studio":
		for action: String in ACTIONS:
			out[action] = 0
	elif preset == "brickworks":
		for n: int in COUNT:
			out[FAVOURITE + str(n + 1)] = KEY_MASK_SHIFT | DIGITS[n]
			out[MOST_USED + str(n + 1)] = KEY_MASK_CMD_OR_CTRL | KEY_MASK_SHIFT | DIGITS[n]
	return out


## The ten favourites, as kept: anything kept that is not a colour code is
## the one out of the box in its place.
static func favourites() -> Array[int]:
	var kept: Variant = ShellPrefs.value("favourite_colours")
	var out: Array[int] = []
	for n: int in COUNT:
		var code: int = FAVOURITES[n]
		if kept is Array and n < (kept as Array).size():
			var one: Variant = (kept as Array)[n]
			if (one is int or one is float) and int(one) >= 0:
				code = int(one)
		out.append(code)
	return out


## Favourite [param n] (0 to 9) is [param code] from now on, here and on
## the account (Keymap.touched).
static func set_favourite(n: int, code: int) -> void:
	if n < 0 or n >= COUNT or code < 0:
		return
	var kept: Array = []
	for one: int in favourites():
		kept.append(one)
	kept[n] = code
	ShellPrefs.put("favourite_colours", kept)
	Keymap.touched()


## The favourites as the account sends them (Keymap.take): ten colour
## codes, else nothing changes. True when they were taken.
static func take(theirs: Variant) -> bool:
	if not theirs is Array or (theirs as Array).size() != COUNT:
		return false
	var kept: Array = []
	for one: Variant in theirs:
		if not (one is int or one is float) or int(one) < 0:
			return false
		kept.append(int(one))
	ShellPrefs.put("favourite_colours", kept)
	return true


## The colours of [param world]'s parts, the most used first, with how many
## of each: [[code, count], ...]. The baseplate and other scenery are not
## the model's. Ties go to the lower code, so a key keeps its colour.
static func most_used(world: BrickWorld, scenery: Dictionary) -> Array:
	var counts: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id) or brick.color_code in NOT_A_COLOUR:
			continue
		counts[brick.color_code] = int(counts.get(brick.color_code, 0)) + 1
	var codes: Array = counts.keys()
	codes.sort_custom(func(a: int, b: int) -> bool:
		return counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
	var out: Array = []
	for code: int in codes.slice(0, COUNT):
		out.append([code, counts[code]])
	return out


## The colour [param action] is now; -1 for a place the model has no
## colour in.
static func colour_of(action: String, world: BrickWorld, scenery: Dictionary) -> int:
	var n: int = place(action)
	if action.begins_with(FAVOURITE):
		return favourites()[n]
	var used: Array = most_used(world, scenery)
	return int(used[n][0]) if n < used.size() else -1


## The key pressed: its colour chosen as a swatch is clicked (PartsBin
## .choose_colour), which paints the selection, one undo, or is the colour
## of the part in hand and of the next one (Main._on_swatch_pressed).
static func press(action: String, shell: Shell) -> void:
	if shell.read_only:
		return
	var code: int = colour_of(action, shell.world, shell.store.scenery)
	if code < 0:
		var has: int = most_used(shell.world, shell.store.scenery).size()
		shell.bar.say("this model has %s, so %s has none" % [Counted.of(has, "colour"),
			Keymap.listed(action)] if has > 0 else "this model has no colours yet")
		return
	if not shell.library.colors.has(code):
		shell.bar.say("colour %d is not in this parts library" % code)
		return
	var paints: bool = bool(shell.app.call("_swatch_paints"))
	(shell.app.get("_bin") as PartsBin).choose_colour(code)
	if not paints:
		shell.bar.say("%s in hand" % shell.library.color(code).name)
