## Words a session sent, without the quotes round them. A session sends a
## part number, a colour or a view's name in the quotes a description or a
## refusal showed it in ("\"4070\"", "'4070'", "“Plan”"), and they are JSON's
## or its own, never the part's or the view's (APP_UX6 mcpsee3: two real
## sessions were refused "\"4070\"" and one called it a bug).
##
## Its own class, naming none: SavedViews is on the first screen and
## SeeTools is not, so the helper both use names nothing of Later's.
class_name Quotes
extends RefCounted

## Each pair of quotes, opening then closing, that [method off] takes off.
const PAIRS: Array[String] = ["\"\"", "''", "``", "“”", "‘’", "«»", "„“"]


## [param text] without the quotes round it, and the spaces at its ends,
## taken off as often as they nest ("'\"4070\"'" is 4070). Text with a quote
## at one end only is left as it is.
static func off(text: String) -> String:
	var said: String = text.strip_edges()
	var again: bool = true
	while again and said.length() >= 2:
		again = false
		for pair: String in PAIRS:
			if said.begins_with(pair[0]) and said.ends_with(pair[1]):
				said = said.substr(1, said.length() - 2).strip_edges()
				again = true
				break
	return said
