## Whether a brief names a word of a vocabulary: a kind of set, a kind of
## subject, a kind of room.
##
## As whole words, with their plurals and simple stems, and never as letters
## inside another word. The kinds were matched by what a word began with,
## so "planet" and "planetarium" were the plane kind, and the owner's orrery
## was reviewed as an aeroplane — told, over and over, to add tail planes and
## jet engines. The same matching made a shopkeeper's shop a tower ("keep"),
## a room on the top storey an armoury ("store") and "inspired" a spire.
## src/dev/subject_words_probe.gd runs every vocabulary against a list of
## such near misses.
class_name SubjectWords
extends RefCounted

## Words that end a word made of two, after a kind: a spaceship is a space
## set's, a firetruck a fire set's. Only these, because "-ship" ends worship
## and hardship as well, and "baseline" is not a base.
const COMPOUND_ENDS: Array[String] = ["ship", "craft", "port", "station", "truck",
	"car", "boat", "plane", "house", "copter", "bike", "mobile", "man", "men"]


## [param text]'s words, lower case: letters and digits, anything else a gap.
static func of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for found: RegExMatch in RegEx.create_from_string("[a-z0-9]+").search_all(text.to_lower()):
		out.append(found.get_string())
	return out


## The forms a word of a brief may be of a vocabulary's word: itself, the
## singular of a plural ("castles", "buses", "bodies"), the possessive's root.
static func forms(word: String) -> PackedStringArray:
	var out := PackedStringArray([word])
	var stemmed: String = RealSnippets.stem(word)
	if not out.has(stemmed):
		out.append(stemmed)
	if word.length() > 4 and word.ends_with("es") and not out.has(word.left(-2)):
		out.append(word.left(-2))
	return out


## Whether [param text] names [param word], a word or a phrase of words, each
## as a whole word or a form of one: "planets" names planet and never plane,
## "tie fighters" names tie fighter. A word alone may begin a word made of two
## ([method kind_of_word]): a spacecraft names space.
static func names(text: String, word: String) -> bool:
	return _names(of(text), of(word))


## The first of [param vocabulary] that [param text] names, or "".
static func first_named(text: String, vocabulary: Array) -> String:
	var said: PackedStringArray = of(text)
	for word: Variant in vocabulary:
		if _names(said, of(str(word))):
			return str(word)
	return ""


static func _names(said: PackedStringArray, wanted: PackedStringArray) -> bool:
	if wanted.is_empty():
		return false
	if wanted.size() == 1:
		for word: String in said:
			if not kind_of_word(word, {wanted[0]: true}).is_empty():
				return true
		return false
	for start: int in range(said.size() - wanted.size() + 1):
		var all: bool = true
		for k: int in wanted.size():
			if not forms(said[start + k]).has(wanted[k]):
				all = false
				break
		if all:
			return true
	return false


## The word of [param vocabulary] (a Dictionary keyed by its words) that one
## word of a brief is, or "": itself or a form of it; or, made of two, a word
## of the vocabulary of four letters or more and one of [constant
## COMPOUND_ENDS] — "spaceship" is space, "planetarium" is nothing.
static func kind_of_word(word: String, vocabulary: Dictionary) -> String:
	for form: String in forms(word):
		if form.length() >= 3 and vocabulary.has(form):
			return form
	for end: String in COMPOUND_ENDS:
		for form: String in forms(word):
			if form.length() > end.length() + 3 and form.ends_with(end):
				var head: String = form.left(-end.length())
				for one: String in forms(head):
					if vocabulary.has(one):
						return one
	return ""
