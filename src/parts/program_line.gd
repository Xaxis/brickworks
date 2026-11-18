## The model's program in its file (hubprogram): one line at the end of its
## head, the program's text as JSON:
##   0 !BRICKWORKS PROGRAM {"text":"repeat 3\n  to 90° at 50%\n  wait 1 s\n  to 0° at 50%"}
## Read and written with the model, so it lives here, apart from HubProgram,
## which plays it and names Simulation: ModelStore, which the first screen
## compiles, naming HubProgram brought Simulation and Linkage into the start
## (tests/test_later.py). An older build keeps the line as a later build's
## (MetaIndex.unclaimed) and writes it back as it was.
class_name ProgramLine
extends RefCounted

const META := "0 !BRICKWORKS PROGRAM "
const WORD := "PROGRAM"


## The model's line for [param words], "" for none (a program of blanks).
static func line_of(words: String) -> String:
	if words.strip_edges().is_empty():
		return ""
	return META + JSON.stringify({"text": words})


## The program the model's own lines keep (MetaIndex), the first that reads,
## taken; "" for none.
static func read_from(metas: MetaIndex) -> String:
	var found: Variant = metas.first_read(WORD, ProgramLine.parsed)
	return str(found) if found != null else ""


## The text a line says after its word, or null for one this cannot read.
static func parsed(words: String) -> Variant:
	var raw: Variant = JSON.parse_string(words)
	if not (raw is Dictionary) or not ((raw as Dictionary).get("text") is String):
		return null
	var said: String = (raw as Dictionary)["text"]
	return said if not said.strip_edges().is_empty() else null


## What of the model's program this build cannot run, said where an open says
## what it left out: [param unread], the model's PROGRAM lines it could not
## read (a later build's form of it), or what [param text], the program it
## read, says that it does not know (a later build's word), and that either
## is kept in the file as written. "" for nothing. So a build before the one
## that adds a word names the program it cannot run, and keeps it. A model
## with a program is one Simulate is for, so its words are read by
## HubProgram, loaded then (Later).
static func unread_words(text: String, unread: PackedStringArray) -> String:
	if not unread.is_empty():
		return "a program for its motors this build cannot read, kept in the file as it is"
	if text.strip_edges().is_empty():
		return ""
	var errors: PackedStringArray = Later.script(&"HubProgram").call("parse", text).get("errors")
	if errors.is_empty():
		return ""
	return "its program has words this build cannot run (%s), kept as written" % errors[0]
