## The parts like a part: its footprint and its kind (appux B5, "Like this",
## 2026-11-05).
##
## A person swapping a 2 x 4 brick for a 2 x 4 plate, a tile or a printed one
## searched for it by name. Fits answers what goes on a part; nothing answered
## what could stand in its place. Studio has Find alternatives (the search
## filled with the part's traits) and a Replace that offers parts of a similar
## size. This lists, from the catalogue alone, so it answers on the web before
## any geometry is fetched:
## - the part itself, or the plain part a print is of, its prints and moulds
##   with it (the bin folds a print under its part);
## - the parts of its footprint and kind: a 2 x 4 brick's 2 x 4 bricks, a round
##   plate's round plates, a 45's 45s, a beam's beams; of its box first, then
##   of another height;
## - the same footprint in nearby kinds: a round tile and a round brick for a
##   round plate, a plate and a tile for a brick, another window for a window;
## - its kind in the nearest other sizes, so a part with nothing of its size
##   still has an answer: a beam's other beams;
## - and last any part that sits on studs of its footprint.
## Within each, the parts real sets use most come first. A part of a system
## (Technic, Minifig) is not near another of it by that alone: a beam's
## suspension arm of its length is not offered.
##
## A part's footprint is its name's first "N x M"; the size Rebrickable names
## it by where the name gives none or a thickness (32316, Technic Beam 5, and
## 32017, Technic Beam 5 x 0.5, are each a 1 x 5); else its box in studs, which
## counts a brick's side studs and pins. Its kind is its category and the first word of its name that is not
## the category's, a size or a family's (brick, plate, tile): round in "Plate
## 1 x 1 Round", 45 in "Slope Brick 45 2 x 2", beam in "Technic Beam 5", none
## in "Brick 2 x 4 with Pins". What follows "with" is what it has, not what it
## is. A print is its plain part's kind.
class_name PartLike
extends RefCounted

## How alike a part is, best first: the part itself; its kind, footprint and
## box; its kind and footprint; its footprint in a nearby kind; its kind in
## another size; its footprint, a part that sits on studs as it does.
const ITSELF := 6
const SAME_BOX := 5
const SAME_FOOT := 4
const NEARBY := 3
const OTHER_SIZE := 2
const ON_STUDS := 1

## The families a plain part of one is like a plain part of another of the
## same footprint: a 2 x 4 brick, plate and tile.
const BASIC: Array[String] = ["Brick", "Plate", "Tile", "Slope", "Wedge"]
## Kept out: what nobody puts in a part's place.
const LEFT_OUT: Array[String] = ["Sticker", "Sticker Shortcut", "Obsolete", "Moved", "Helper"]
## Where a name begins to say what a part has, not what it is.
const HAS: Array[String] = [" with ", " without ", " w/ ", " and ", " for "]
## What only a name with more than letters, numbers and spaces has, read
## then as the search reads it (PartSearch.words_of): "Technic Pin 1/2".
const MARKS: Array[String] = ["/", ",", "-", "'", "\"", "(", "[", "#", "&", "+", ":"]
## Words of a name that say what is on it, not what it is.
const DECOR: Array[String] = ["pattern", "patt", "sticker", "stickers"]
## A family's word, which says how tall a part is rather than its kind: the
## kind of "Slope Brick 45" is its 45.
const FAMILY: Array[String] = ["brick", "plate", "tile"]
## How far apart two heights may be, in LDU, and be one box.
const SAME_HEIGHT := 2.0

## What a part is, read from the catalogue once.
class Kind extends RefCounted:
	var foot := Vector2.ZERO        ## studs, the smaller side first
	var tall: float = -1.0          ## the third side its name gives, or -1
	var height: float = 0.0         ## its box's, in LDU
	var category: String = ""
	var head: String = ""           ## the word that says its kind, "" for plain
	var shape := PackedStringArray()

	## The kind as one key: category and head.
	func key() -> String:
		return "%s|%s" % [category, head]


var _library: PartLibrary
## The catalogue this was read from (its size), and what it read: id -> Kind,
## a footprint's key -> its parts' ids, a kind's key -> its parts' ids.
var _read_at: int = -1
var _kinds: Dictionary = {}
var _by_foot: Dictionary = {}
var _by_kind: Dictionary = {}
## A category's own words, read once each.
var _words_of_category: Dictionary = {}
## While it reads: the parts to read (the plain ones, then the prints and
## assemblies, which read their part's kind), the next to read, -1 once all
## are; and the parts LDraw keeps only for old files.
var _reading := PackedStringArray()
var _later := PackedStringArray()
var _next: int = -1
var _second: bool = false
var _old: Dictionary = {}


func _init(library: PartLibrary) -> void:
	_library = library


## The parts like [param id], best first, at most [param most]: [param id]'s
## own plain part first. Empty for a part the catalogue does not have.
func like(id: String, most: int = 300) -> Array[PartLibrary.PartInfo]:
	var out: Array[PartLibrary.PartInfo] = []
	for row: Array in ranked(id, most):
		out.append(row[1])
	return out


## [method like] with how alike each is: [[how (ITSELF..ON_STUDS), info]].
## Read whole first, if [method read_some] has not.
func ranked(id: String, most: int = 300) -> Array:
	read_some(INF)
	var info: PartLibrary.PartInfo = _library.parts.get(id)
	if info == null:
		return []
	var base: PartLibrary.PartInfo = info.folds_under() if info.folds_under() != null else info
	var mine: Kind = _kinds.get(id)
	if mine == null:
		mine = _kind_of(base)
	var asked: Dictionary = {}
	for other: String in _by_foot.get(_foot_key(mine.foot), []):
		asked[other] = true
	for other: String in _by_kind.get(mine.key(), []):
		asked[other] = true
	var rows: Array = []     ## [how, near, exact, commonness, id, info]
	for other: String in asked:
		if other == base.id:
			continue
		var theirs: Kind = _kinds[other]
		var them: PartLibrary.PartInfo = _library.parts[other]
		var foot: bool = theirs.foot == mine.foot
		var box: bool = foot and theirs.tall == mine.tall \
			and absf(theirs.height - mine.height) <= SAME_HEIGHT
		var kind: bool = theirs.category == mine.category and theirs.head == mine.head
		var how: int = 0
		var near: float = 0.0
		if kind and box:
			how = SAME_BOX
		elif kind and foot:
			how = SAME_FOOT
		elif foot and _shares_head(mine, theirs):
			# A round tile for a round plate, a plate for a brick, before
			# another of its category.
			how = NEARBY
			near = 2.0
		elif foot and theirs.category == mine.category \
				and (mine.head.is_empty() or theirs.head.is_empty()):
			how = NEARBY
			near = 1.0
		elif kind:
			how = OTHER_SIZE
			near = -(absf(theirs.foot.x - mine.foot.x) + absf(theirs.foot.y - mine.foot.y))
		elif foot and mine.category in PartFits.ON_STUDS and theirs.category in PartFits.ON_STUDS:
			how = ON_STUDS
		else:
			continue
		# Within a tier, its own shape, then the most used: a box alike
		# put Plate 2 x 4 with Towball Socket, a brick's height, before
		# Plate 2 x 4 among a 2 x 4 brick's nearby kinds.
		rows.append([how, near, 1 if theirs.shape == mine.shape else 0,
			them.commonness(), other, them])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		for n: int in 4:
			if a[n] != b[n]:
				return a[n] > b[n]
		return str(a[4]).naturalnocasecmp_to(str(b[4])) < 0)
	# A print after its plain part, before the other prints of it.
	var out: Array = [[ITSELF, base]] if base == info else [[ITSELF, base], [ITSELF, info]]
	for row: Array in rows:
		if out.size() >= most:
			break
		if row[5] != info:
			out.append([row[0], row[5]])
	return out


## A kind's word in common (round and round), or two plain parts of the basic
## families (a 2 x 4 brick and a 2 x 4 plate).
static func _shares_head(mine: Kind, theirs: Kind) -> bool:
	if not mine.head.is_empty():
		return theirs.head == mine.head
	return theirs.head.is_empty() and mine.category in BASIC and theirs.category in BASIC


## Whether the catalogue as it is has been read.
func ready() -> bool:
	return _read_at == _library.ids().size() and _next < 0


## Read the catalogue on, for at most [param budget_ms] of this frame: each
## part's kind, and the parts of each footprint and each kind. A few frames
## for all of it, where at once it was half a second of one on a desktop and
## more on the web. True once all is read; read again for another catalogue.
func read_some(budget_ms: float) -> bool:
	if _read_at != _library.ids().size():
		_read_at = _library.ids().size()
		_kinds.clear()
		_by_foot.clear()
		_by_kind.clear()
		_old = _library.superseded_ids()
		_reading = _library.ids()
		_later = PackedStringArray()
		_second = false
		_next = 0
	if _next < 0:
		return true
	var until: int = Time.get_ticks_usec() + int(minf(budget_ms, 1e9) * 1000.0)
	while true:
		if _next >= _reading.size():
			if _later.is_empty():
				_next = -1
				_reading = PackedStringArray()
				_old = {}
				return true
			# The prints and assemblies, once their parts are read.
			_reading = _later
			_later = PackedStringArray()
			_second = true
			_next = 0
		var id: String = _reading[_next]
		_next += 1
		var info: PartLibrary.PartInfo = _library.parts[id]
		if _second:
			_keep(id, _kind_from(info, info.folds_under()))
		elif _offerable(info, _old):
			if info.folds_under() == null:
				_keep(id, _kind_of(info))
			else:
				_later.append(id)
		if _next % 64 == 0 and Time.get_ticks_usec() >= until:
			return false
	return true


## A print is its part's shape; an assembly drawn whole (a wheel with its
## tyre) its part's kind in a box of its own.
func _kind_from(info: PartLibrary.PartInfo, of: PartLibrary.PartInfo) -> Kind:
	var theirs: Kind = _kinds.get(of.id)
	if theirs == null:
		theirs = _kind_of(of)
	var kind := Kind.new()
	kind.foot = theirs.foot
	kind.tall = theirs.tall
	kind.height = info.size.y
	kind.category = theirs.category
	kind.head = theirs.head
	kind.shape = theirs.shape
	return kind


func _keep(id: String, kind: Kind) -> void:
	_kinds[id] = kind
	for pair: Array in [[_by_foot, _foot_key(kind.foot)], [_by_kind, kind.key()]]:
		var index: Dictionary = pair[0]
		var key: String = pair[1]
		if not index.has(key):
			index[key] = []
		(index[key] as Array).append(id)


static func _foot_key(foot: Vector2) -> String:
	return "%sx%s" % [_num(foot.x), _num(foot.y)]


static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.3f" % value


## Whether a part is one to offer in another's place: placeable in this build,
## made now where LDraw keeps an older number, of the parts people build with;
## printed or stickered as well as plain, but not a sticker itself.
static func _offerable(info: PartLibrary.PartInfo, old: Dictionary) -> bool:
	if info.is_redirect() or not info.reachable or info.category in LEFT_OUT \
			or old.has(info.id) or info.name.begins_with("=") or info.name.begins_with("~"):
		return false
	return (info.decor() & PartLibrary.PartInfo.STICKER) == 0 and not PartSearch._other_line(info)


## What [param info] is, from its name, its size as Rebrickable names it and
## its box.
func _kind_of(info: PartLibrary.PartInfo) -> Kind:
	var kind := Kind.new()
	kind.category = info.family_category()
	kind.height = info.size.y
	# Up to what it has: its kind and size are said first, and what follows
	# is most of the work of reading 20,000 names.
	var name: String = info.name.to_lower()
	for has: String in HAS:
		var at: int = name.find(has)
		if at > 0:
			name = name.left(at)
	if name.contains("(") or name.contains("["):
		name = PartSearch.BRACKETED.sub(name, " ", true)
	var plain: bool = true
	for mark: String in MARKS:
		if name.contains(mark):
			plain = false
			break
	var words: PackedStringArray = name.split(" ", false) if plain else PartSearch.words_of(name)
	var span: Vector2i = _size_span(words)
	var sized: bool = span.y > span.x
	if sized:
		kind.foot = _sides(words[span.x], words[span.x + 2])
		if span.y - span.x == 5:
			kind.tall = words[span.x + 4].to_float()
	# Rebrickable's size where the name's is none, or a beam's thickness (Technic
	# Beam 5 x 0.5, a 1 x 5): a wheel's name says it as it is known.
	if not info.also_size.is_empty() and (not sized or kind.foot.x < 1.0):
		var theirs: PackedStringArray = PartSearch.words_of(info.also_size)
		var also: Vector2i = _size_span(theirs)
		if also.y > also.x:
			kind.foot = _sides(theirs[also.x], theirs[also.x + 2])
			if also.y - also.x == 5:
				kind.tall = theirs[also.x + 4].to_float()
	if kind.foot == Vector2.ZERO:
		var studs: Vector2i = info.footprint_studs()
		kind.foot = Vector2(mini(studs.x, studs.y), maxi(studs.x, studs.y))
	if not _words_of_category.has(kind.category):
		var own: Dictionary = {}
		for word: String in PartSearch.words_of(kind.category):
			own[word] = true
		_words_of_category[kind.category] = own
	var category_words: Dictionary = _words_of_category[kind.category]
	for n: int in words.size():
		if n >= span.x and n < span.y:
			continue
		var word: String = words[n]
		# A length LDraw writes alone is the footprint's: "Technic Beam 5".
		if word in DECOR or (not sized and word.is_valid_float()):
			continue
		kind.shape.append(word)
		if kind.head.is_empty() and not category_words.has(word) and not word in FAMILY:
			kind.head = word
	return kind


## Where the first "N x M", or "N x M x H", is among [param words]: from, to
## (past its end); from == to when there is none.
static func _size_span(words: PackedStringArray) -> Vector2i:
	for n: int in range(1, words.size() - 1):
		if words[n] == "x" and words[n - 1].is_valid_float() and words[n + 1].is_valid_float():
			if n + 3 < words.size() and words[n + 2] == "x" and words[n + 3].is_valid_float():
				return Vector2i(n - 1, n + 4)
			return Vector2i(n - 1, n + 2)
	return Vector2i.ZERO


static func _sides(a: String, b: String) -> Vector2:
	return Vector2(minf(a.to_float(), b.to_float()), maxf(a.to_float(), b.to_float()))
