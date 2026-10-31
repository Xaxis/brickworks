## The interface in German, French or Spanish, or in English as it is
## written (Settings, Language), as Mecabricks offers eight and LeoCAD six.
##
## Every word the app puts on screen is written in English, and Godot draws
## a control's words through the translation the TranslationServer holds for
## its locale. So a language is one file, locale/<code>.po, loaded when it is
## chosen and not before: a first visit in English reads none of them. Each
## control's text stays the English it was given and only what is drawn
## changes, so a probe or a browser check reading a label, a menu row or a
## tooltip reads English in any language, and the app's own code still
## compares English.
##
## Kept on this device (ShellPrefs "language"), and applied at the settings'
## first read, before anything is drawn. An address can ask for one, as it
## can for the assistant: brickworks.diy/app?lang=de (a browser hands its
## query to the app as --lang=de), kept as if chosen.
##
## Words made at the moment ("Press Ctrl+S to save “Car”", a tool's tooltip
## with its key after it) are matched as patterns: an entry whose English has
## %s or %d in it takes any words, or a number, in that place, and they go
## into the translation's own place for them ("%2$s" names which), translated
## themselves when they are words of the interface. A key after a row's words
## (three spaces or more, then the key) and a tooltip's lines are found one
## by one. A part's, a colour's or a model's name is in no file, and is drawn
## as it is.
class_name Language
extends Node

## The choices, each in its own language, as every program lists them.
const CHOICES: Array = [["en", "English"], ["de", "Deutsch"], ["fr", "Français"],
	["es", "Español"]]

## The languages that keep a row's capital where English lowers it, as the
## keys sheet does a menu row's ("zoom in"): German capitalises its nouns,
## and its lists start with a capital.
const CAPITALISED: Array[String] = ["de"]

## The one in use: "en" until another is applied.
static var _code: String = "en"
## Its words, while one other than English is in use.
static var _words: Words = null


## The language in use, as its code: "en", "de", "fr" or "es".
static func current() -> String:
	return _code


static func codes() -> Array[String]:
	var out: Array[String] = []
	for choice: Array in CHOICES:
		out.append(str(choice[0]))
	return out


## The settings' first read (ShellPrefs): the language an address asks for,
## kept as the choice, then the choice applied.
static func start() -> void:
	var asked: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--lang="):
			asked = argument.trim_prefix("--lang=").to_lower().left(2)
	if asked in codes():
		ShellPrefs.put("language", asked)
		# Out of the address once read, so a reload after another choice in
		# Settings keeps that one.
		if OS.has_feature("web"):
			JavaScriptBridge.eval("""(function () {
				var here = new URL(location.href);
				here.searchParams.delete("lang");
				history.replaceState(history.state, "", here.pathname + here.search + here.hash);
			})()""", true)
	apply(str(ShellPrefs.value("language")))


## Settings, Language: [param code] used from now on, and kept.
static func choose(code: String) -> void:
	ShellPrefs.put("language", code if code in codes() else "en")
	apply(code)


## Every word drawn from now on in [param code]'s language; English for a
## code there is no file for.
static func apply(code: String) -> void:
	if not code in codes():
		code = "en"
	if code == _code:
		return
	if _words != null:
		TranslationServer.remove_translation(_words)
		_words = null
	_code = "en"
	if code != "en":
		var source: Translation = load("res://locale/%s.po" % code) as Translation
		if source == null:
			push_error("language: no locale/%s.po" % code)
		else:
			_words = Words.new(source)
			_words.locale = code
			_words.capitals = code in CAPITALISED
			TranslationServer.add_translation(_words)
			_code = code
			_keep_until_exit()
	TranslationServer.set_locale(_code)


## What [param text] is drawn as in the language in use, or "" when it has no
## translation there (always "" in English): for a check of the words.
static func says(text: String) -> String:
	return _words.find(text) if _words != null else ""


## Taken out of the TranslationServer as the window closes, while the
## scripts are still there to free it: a translation made by a script and
## left in the server crashes the engine at exit (4.7.2), as a probe's
## lambda left in a static does.
static func _keep_until_exit() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.has_node("Language"):
		return
	var keeper := Language.new()
	keeper.name = "Language"
	tree.root.add_child.call_deferred(keeper)


func _exit_tree() -> void:
	if Language._words != null:
		TranslationServer.remove_translation(Language._words)
		Language._words = null


## One language's words: its file's, and its patterns.
class Words extends Translation:
	var _source: Translation
	## Whether a row's words lowered keep the translation's capital.
	var capitals: bool = false
	## A pattern's first word -> its patterns, as [RegEx, translation, how
	## many of its letters are its own]; those that start with what they
	## take, under "".
	var _patterns: Dictionary = {}
	## What each text was found as, "" for nothing: a part's name is asked
	## for every time a list row is drawn.
	var _found: Dictionary = {}
	var _lock := Mutex.new()
	var _places: RegEx = RegEx.create_from_string(r"%(?:(\d+)\$)?[sd]")
	var _key_after: RegEx = RegEx.create_from_string(r"^(.*?\S)( {3,}\S.*)$")

	func _init(source: Translation) -> void:
		_source = source
		for english: String in source.get_message_list():
			if _places.search(english) == null:
				continue
			var translated: String = String(source.get_message(english))
			if translated.is_empty():
				continue
			var expression: String = "^"
			var at: int = 0
			for place: RegExMatch in _places.search_all(english):
				expression += _escaped(english.substr(at, place.get_start() - at))
				expression += "(-?\\d+)" if place.get_string().ends_with("d") else "(.+?)"
				at = place.get_end()
			expression += _escaped(english.substr(at)) + "$"
			# Its first word, where the words before its first place have one.
			var before: String = english.substr(0, _places.search(english).get_start())
			var first: String = before.get_slice(" ", 0) if " " in before else ""
			if not _patterns.has(first):
				_patterns[first] = []
			(_patterns[first] as Array).append([RegEx.create_from_string(expression), translated,
				_places.sub(english, "", true).length()])
		# The most particular first: "press %s, %s, %s or %s to move it" before
		# "press %s to move it", which would take the four keys as one.
		for first: String in _patterns:
			(_patterns[first] as Array).sort_custom(func(a: Array, b: Array) -> bool:
				return int(a[2]) > int(b[2]))

	func _get_message(src_message: StringName, _context: StringName) -> StringName:
		return StringName(find(String(src_message)))

	## [param text] in this language, or "" when there is no translation.
	func find(text: String) -> String:
		_lock.lock()
		var known: Variant = _found.get(text)
		_lock.unlock()
		if known != null:
			return known
		var out: String = _find(text, 0)
		_lock.lock()
		if _found.size() > 40000:
			_found.clear()
		_found[text] = out
		_lock.unlock()
		return out

	func _find(text: String, depth: int) -> String:
		if text.is_empty() or depth > 3:
			return ""
		var whole: String = String(_source.get_message(text))
		if not whole.is_empty():
			return whole
		# Its lines, one by one: a tooltip's words and key, then what it does.
		if "\n" in text:
			var lines: PackedStringArray = text.split("\n")
			var any: bool = false
			for n: int in lines.size():
				var line: String = _find(lines[n], depth + 1)
				if not line.is_empty():
					lines[n] = line
					any = true
			return "\n".join(lines) if any else ""
		var edges: String = text.strip_edges()
		if edges != text:
			var inner: String = _find(edges, depth + 1)
			return text.replace(edges, inner) if not inner.is_empty() else ""
		# A row's words and its key after them: the words, the key as it is.
		var keyed: RegExMatch = _key_after.search(text)
		if keyed != null:
			var words: String = _find(keyed.get_string(1), depth + 1)
			return words + keyed.get_string(2) if not words.is_empty() else ""
		var matched: String = _matched(text, depth)
		if not matched.is_empty():
			return matched
		# The words a menu row ends with "…" for, said without it (Toolbar).
		var dotted: String = String(_source.get_message(text + "…"))
		if not dotted.is_empty():
			return dotted.trim_suffix("…")
		# A row's words with their first letter lowered (the keys sheet's
		# "zoom in"): the row's translation, lowered too where the language
		# lowers it.
		var first: String = text.left(1)
		if first != first.to_upper():
			var raised: String = _find(first.to_upper() + text.substr(1), depth + 1)
			if not raised.is_empty():
				return raised if capitals else raised.left(1).to_lower() + raised.substr(1)
		return ""

	func _matched(text: String, depth: int) -> String:
		var first: String = text.get_slice(" ", 0)
		for key: String in [first, ""]:
			for pattern: Array in _patterns.get(key, []):
				var found: RegExMatch = (pattern[0] as RegEx).search(text)
				if found == null:
					continue
				var taken: Array[String] = []
				for n: int in range(1, found.get_group_count() + 1):
					var said: String = found.get_string(n)
					var own: String = _find(said, depth + 1)
					taken.append(own if not own.is_empty() else said)
				return _filled(str(pattern[1]), taken)
		return ""

	## [param translated] with what was taken in its places: in order, or
	## where "%2$s" names one.
	func _filled(translated: String, taken: Array[String]) -> String:
		var out: String = ""
		var at: int = 0
		var next: int = 0
		for place: RegExMatch in _places.search_all(translated):
			out += translated.substr(at, place.get_start() - at)
			at = place.get_end()
			var which: int = next
			if not place.get_string(1).is_empty():
				which = int(place.get_string(1)) - 1
			else:
				next += 1
			out += taken[which] if which >= 0 and which < taken.size() else ""
		return out + translated.substr(at)

	static func _escaped(literal: String) -> String:
		var out: String = ""
		for c: String in literal:
			out += ("\\" + c) if c in ".^$*+?()[]{}|\\/" else c
		return out
