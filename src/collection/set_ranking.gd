## Every set Rebrickable lists, ranked by how much of it a person owns: What
## can I build?'s real sets, and parts_list which="buildable"'s block of them
## (setsbuild, docs/APP_UX8.md #12).
##
## tools/collection_data.py writes all_sets.bin beside the set shards: each
## part and colour with the sets it is in, a set's parts counted as What do
## I need? and the bin count them (OwnCounts.set_needs: no sticker, nothing
## nobody owns on its own), a pack as its own parts and the sets in it. Its
## layout is encode_index's. SetInventories reads it as the page opens: from
## the build's own files on the desktop, from the deployment's /sets/ on the
## web, never at start-up.
##
## [method rank] counts, for every set at once, what Collection.coverage
## counts for one: the pieces owned in their colour, another moulding of a
## part in its colour standing in (Collection.allocate), and the pieces owned
## in any colour. It reads only the parts the person owns, family by family,
## so a few sets' worth costs little, and src/dev/setsbuild_probe.gd holds
## it to Collection.coverage set by set.
class_name SetRanking
extends RefCounted

const FILE := "all_sets.bin"
const FORMAT := 1
## A quantity written as this byte is in the "over" list instead.
const OVER := 255
## The smallest set What can I build? lists until another size is chosen,
## and parts_list's block lists: a minifigure, a key chain or a book's two
## bricks would fill the top of every list at 100%.
const FEWEST := 50

## How many sets, and each one's number (lowercased, as the shards key
## them), name, year (0 when not known) and pieces counted.
var sets: int = 0
var numbers: PackedStringArray
var names: PackedStringArray
var years: PackedInt32Array
var pieces: PackedInt32Array
## When tools/collection_data.py wrote it (unix seconds), and its size.
var generated: int = 0
var size: int = 0
## Rebrickable's database sets, in the shards and no sets (collection_data
## NOT_SETS): left out.
var not_sets: PackedStringArray
## The sets with an official LDraw model: number -> [its file under
## vendor/omr/files, its page at the OMR] (models.json's first for the set).
var models: Dictionary = {}
## Each set's name, lowered, for a search; made the first time one is asked.
var _lowered: PackedStringArray

## Every part and colour in a set, by Collection.key_of, family by family.
var _keys: PackedStringArray
## Pair -> its first posting; one more at the end.
var _post: PackedInt32Array
## Each posting: the gap from the last set (low | high << 8), how many.
var _low: PackedByteArray
var _high: PackedByteArray
var _qty: PackedByteArray
var _over: Dictionary = {}
## Family (Collection.family_of) -> Vector2i(its first pair, one past its last).
var _runs: Dictionary = {}
## Set -> its first entry in _up, one more at the end: the packs it is a
## leaf of, each with how many of it the pack holds.
var _up_at: PackedInt32Array
var _up: PackedInt32Array
## A set whose parts are another's exactly: [set, that one, ...].
var _same: PackedInt32Array
var _at: Dictionary = {}


## The file read, or null with [param why] said: a header that is not
## format 1, or a payload that does not unpack.
static func read(bytes: PackedByteArray, why: Array = []) -> SetRanking:
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "BWAS" or bytes[4] != FORMAT \
			or bytes[5] != 1:
		why.append("not an all_sets.bin of format %d" % FORMAT)
		return null
	var raw_size: int = bytes.decode_u32(8)
	var raw: PackedByteArray = bytes.slice(12).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		why.append("all_sets.bin did not unpack (%d of %d bytes)" % [raw.size(), raw_size])
		return null
	var parts: Array[PackedByteArray] = []
	var at: int = 0
	while at + 4 <= raw.size():
		var length: int = raw.decode_u32(at)
		parts.append(raw.slice(at + 4, at + 4 + length))
		at += 4 + length
	if parts.size() < 14:
		why.append("all_sets.bin has %d sections of 14" % parts.size())
		return null
	var made := SetRanking.new()
	made.size = bytes.size()
	var meta: Variant = JSON.parse_string(parts[0].get_string_from_utf8())
	made.generated = int((meta as Dictionary).get("generated", 0)) if meta is Dictionary else 0
	made.not_sets = PackedStringArray((meta as Dictionary).get("not_sets", [])) if meta is Dictionary else []
	var official: Variant = (meta as Dictionary).get("models") if meta is Dictionary else null
	made.models = official if official is Dictionary else {}
	made.numbers = parts[1].get_string_from_utf8().split("\n")
	made.names = parts[2].get_string_from_utf8().split("\n")
	made.sets = made.numbers.size()
	made.years.resize(made.sets)
	for n: int in made.sets:
		made.years[n] = 1940 + parts[3][n] if parts[3][n] > 0 else 0
	made.pieces = _varints(parts[4])
	made._keys = parts[5].get_string_from_utf8().split("\n")
	# A family's name is its first pair's part, less the last letter where
	# that one is another moulding (3794a: 3794).
	var families: PackedInt32Array = _varints(parts[6])
	var pair: int = 0
	for word: int in families:
		var count: int = word >> 1
		var part: String = made._keys[pair].get_slice("/", 0)
		made._runs[part.left(-1) if word & 1 else part] = Vector2i(pair, pair + count)
		pair += count
	var counts: PackedInt32Array = _varints(parts[7])
	made._post.resize(counts.size() + 1)
	var total: int = 0
	for n: int in counts.size():
		made._post[n] = total
		total += counts[n]
	made._post[counts.size()] = total
	made._low = parts[8]
	made._high = parts[9]
	made._qty = parts[10]
	var over: PackedInt32Array = _varints(parts[11])
	var posting: int = 0
	for n: int in range(0, over.size(), 2):
		posting += over[n]
		made._over[posting] = over[n + 1]
	made._read_packs(_varints(parts[12]))
	made._same = _varints(parts[13])
	if made.pieces.size() != made.sets or made._low.size() != total or made._qty.size() != total \
			or made._high.size() != total or made.sets > 0xFFFF:
		why.append("all_sets.bin's sections do not agree")
		return null
	return made


## The packs each set is a leaf of, as _up_at and _up.
func _read_packs(packed: PackedInt32Array) -> void:
	var lists: Dictionary = {}
	var n: int = 0
	while n + 1 < packed.size():
		var pack: int = packed[n]
		var many: int = packed[n + 1]
		n += 2
		for _leaf: int in many:
			var leaf: int = packed[n]
			# A packed array is a value: changed as a copy, put back.
			var held: PackedInt32Array = lists.get(leaf, PackedInt32Array())
			held.append_array(PackedInt32Array([pack, packed[n + 1]]))
			lists[leaf] = held
			n += 2
	_up_at.resize(sets + 1)
	var at: int = 0
	for set_at: int in sets:
		_up_at[set_at] = at
		if lists.has(set_at):
			_up.append_array(lists[set_at])
			at += (lists[set_at] as PackedInt32Array).size()
	_up_at[sets] = at


static func _varints(raw: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	var value: int = 0
	var shift: int = 0
	for byte: int in raw:
		value |= (byte & 0x7F) << shift
		shift += 7
		if byte < 0x80:
			out.append(value)
			value = 0
			shift = 0
	return out


## The sets [param collection] holds, by number (SetInventories.normal) ->
## true: What can I build? leaves them out, as the person has them.
static func owned_sets(collection: Collection) -> Dictionary:
	var own: Dictionary = {}
	for entry: Dictionary in collection.sets:
		if not Collection.is_fig(entry):
			own[SetInventories.normal(str(entry["set"]))] = true
	return own


## Where set [param number] is, -1 for none.
func index_of(number: String) -> int:
	if _at.is_empty():
		for n: int in sets:
			_at[numbers[n]] = n
	return int(_at.get(number.strip_edges().to_lower(), -1))


## What a ranking found: for each set, the pieces owned in their colour (as
## Collection.coverage's "owned") and in any colour (its "shaped"), and the
## sets in order, most of each owned first.
class Ranked:
	extends RefCounted
	var of: SetRanking
	var owned: PackedInt32Array
	var shaped: PackedInt32Array
	## Set indices: the most owned in its colours first, then the most in
	## any colour, then the bigger, then by number.
	var order: PackedInt32Array
	## How long it took, in microseconds, and how much of that was the other
	## mouldings and the ordering.
	var took: int = 0
	var took_moulds: int = 0
	var took_order: int = 0

	## Collection.coverage's "exact": 0 to 1.
	func exact(n: int) -> float:
		return float(owned[n]) / of.pieces[n] if of.pieces[n] > 0 else 0.0

	## Collection.coverage's "any_colour".
	func any_colour(n: int) -> float:
		return float(maxi(shaped[n], owned[n])) / of.pieces[n] if of.pieces[n] > 0 else 0.0

	## Collection.coverage's dictionary, for set [param n].
	func cover(n: int) -> Dictionary:
		return {"pieces": of.pieces[n], "owned": owned[n], "missing": of.pieces[n] - owned[n],
			"exact": exact(n), "any_colour": any_colour(n)}

	## How many of [param listed] are owned at [param share] or more, in
	## their colours.
	func at_least(listed: PackedInt32Array, share: float) -> int:
		var count: int = 0
		for n: int in listed:
			if exact(n) + 0.000001 < share:
				break
			count += 1
		return count

	## The sets to list, in order: none in [param leave_out] (number -> true:
	## the person's own, which they have), none under test in a bench run
	## (DesignMemory.holds: a session is never handed one), of [param fewest]
	## pieces or more, and with [param find] in the number or the name when
	## it is given, the set of that very number first (7140 is 7140-1, not
	## 71402-6, the minifigure ranked above it). The page and parts_list's
	## block list the same.
	func listed(leave_out: Dictionary = {}, fewest: int = 0, find: String = "") -> PackedInt32Array:
		var out := PackedInt32Array()
		var first := PackedInt32Array()
		var held: bool = DesignMemory.holding()
		var word: String = find.strip_edges().to_lower()
		if not word.is_empty() and of._lowered.is_empty():
			of._lowered = PackedStringArray(Array(of.names).map(func(name: String) -> String: return name.to_lower()))
		for n: int in order:
			if of.pieces[n] < fewest or leave_out.has(of.numbers[n]):
				continue
			if not word.is_empty() and not of.numbers[n].begins_with(word) and not of._lowered[n].contains(word):
				continue
			if held and DesignMemory.holds(of.numbers[n], of.names[n]):
				continue
			if not word.is_empty() and (of.numbers[n] == word or of.numbers[n].get_slice("-", 0) == word):
				first.append(n)
			else:
				out.append(n)
		first.append_array(out)
		return first

	## A set as a session hears it: "92% 7140-1 X-wing Fighter (1999): owns
	## 260 of its 282 pieces in their colours, 22 short; 97% in any colour".
	func said(n: int) -> String:
		var whole: int = of.pieces[n]
		var short: int = whole - owned[n]
		return "%d%% %s %s%s: %s%s" % [floori(100.0 * exact(n)), of.numbers[n], of.names[n],
			" (%d)" % of.years[n] if of.years[n] > 0 else "",
			"owns all %s in their colours" % Counted.of(whole, "piece") if short == 0
				else "owns %d of its %s in their colours, %d short" % [owned[n], Counted.of(whole, "piece"), short],
			"" if short == 0 else "; %d%% in any colour" % floori(100.0 * any_colour(n))]


## Every set against [param have], part and colour (Collection.key_of) ->
## how many: OwnCounts.owned of the window's pool.
func rank(have: Dictionary) -> Ranked:
	var started: int = Time.get_ticks_usec()
	var owned := PackedInt32Array()
	owned.resize(sets)
	var shaped := PackedInt32Array()
	shaped.resize(sets)
	# A set's need for the part (acc_k) and for its family (acc_f), counted
	# over its postings and its leaves', and the sets touched, to clear.
	var acc_k := PackedInt32Array()
	acc_k.resize(sets)
	var acc_f := PackedInt32Array()
	acc_f.resize(sets)
	var hit_k := PackedInt32Array()
	hit_k.resize(sets)
	var hit_f := PackedInt32Array()
	hit_f.resize(sets)
	# What they have by family, and by family and colour in the pool's own
	# order (Collection.allocate's siblings are in that order).
	var by_family: Dictionary = {}
	var in_group: Dictionary = {}
	var took_moulds: int = 0
	for key: String in have:
		var count: int = int(have[key])
		var family: String = Collection.family_of(Collection.part_of(key))
		by_family[family] = int(by_family.get(family, 0)) + count
		if count > 0 and _runs.has(family):
			var group: String = "%s/%s" % [family, key.get_slice("/", 1)]
			if not in_group.has(group):
				in_group[group] = []
			(in_group[group] as Array).append(key)
	for family: String in by_family:
		var held: int = int(by_family[family])
		var run: Variant = _runs.get(family)
		if held <= 0 or run == null:
			continue
		var span: Vector2i = run
		# The groups (a colour of this family) where another moulding of a
		# part could stand in: the person has one and a set has another.
		var live: Dictionary = {}
		for p: int in range(span.x, span.y):
			var group: String = "%s/%s" % [family, _keys[p].get_slice("/", 1)]
			if in_group.has(group) and ((in_group[group] as Array).size() > 1 or in_group[group][0] != _keys[p]):
				live[group] = {}
		var touched_f: int = 0
		for p: int in range(span.x, span.y):
			var key: String = _keys[p]
			var h: int = int(have.get(key, 0))
			var group_needs: Variant = null
			if not live.is_empty():
				group_needs = live.get("%s/%s" % [family, key.get_slice("/", 1)])
			var counted: bool = h > 0 or group_needs != null
			var touched_k: int = 0
			var s: int = -1
			for i: int in range(_post[p], _post[p + 1]):
				s += _low[i] + (_high[i] << 8) + 1
				var q: int = _qty[i]
				if q == OVER:
					q = int(_over[i])
				if acc_f[s] == 0:
					hit_f[touched_f] = s
					touched_f += 1
				acc_f[s] += q
				if counted:
					if acc_k[s] == 0:
						hit_k[touched_k] = s
						touched_k += 1
					acc_k[s] += q
				# Every pack this set is a leaf of needs it as many times as it
				# holds the set.
				var u: int = _up_at[s]
				var end: int = _up_at[s + 1]
				while u < end:
					var pack: int = _up[u]
					var times: int = q * _up[u + 1]
					u += 2
					if acc_f[pack] == 0:
						hit_f[touched_f] = pack
						touched_f += 1
					acc_f[pack] += times
					if counted:
						if acc_k[pack] == 0:
							hit_k[touched_k] = pack
							touched_k += 1
						acc_k[pack] += times
			for t: int in touched_k:
				var at: int = hit_k[t]
				var need: int = acc_k[at]
				acc_k[at] = 0
				owned[at] += need if need < h else h
				if group_needs != null:
					var by_set: Dictionary = group_needs
					if not by_set.has(at):
						by_set[at] = {}
					by_set[at][key] = need
		for t: int in touched_f:
			var at: int = hit_f[t]
			var need: int = acc_f[at]
			acc_f[at] = 0
			shaped[at] += need if need < held else held
		var mould_from: int = Time.get_ticks_usec()
		for group: String in live:
			var by_set: Dictionary = live[group]
			for at: int in by_set:
				owned[at] += _moulded(by_set[at], in_group[group], have, group)
		took_moulds += Time.get_ticks_usec() - mould_from
	# A set with another's parts is ranked as that one.
	for n: int in range(0, _same.size(), 2):
		owned[_same[n]] = owned[_same[n + 1]]
		shaped[_same[n]] = shaped[_same[n + 1]]
	var made := Ranked.new()
	made.of = self
	made.owned = owned
	made.shaped = shaped
	var order_from: int = Time.get_ticks_usec()
	made.order = _ordered(owned, shaped)
	made.took_order = Time.get_ticks_usec() - order_from
	made.took_moulds = took_moulds
	made.took = Time.get_ticks_usec() - started
	return made


## The pieces another moulding gives set's [param needs] in one family and
## colour ([param root], "3794/15"), past each part's own: the second half of
## Collection.allocate, for this group alone, which is all it reaches.
## [param owned_keys] are the person's parts in the group, in the pool's order.
static func _moulded(needs: Dictionary, owned_keys: Array, have: Dictionary, root: String) -> int:
	var spare: Dictionary = {}
	for key: String in owned_keys:
		var h: int = int(have[key])
		spare[key] = h - mini(int(needs.get(key, 0)), h)
	var siblings: Array = []
	for key: String in owned_keys:
		if int(spare[key]) > 0 and key != root:
			siblings.append(key)
	var keys: Array = needs.keys()
	keys.sort()
	var given: int = 0
	for key: String in keys:
		var need: int = int(needs[key])
		var left: int = need - mini(need, int(have.get(key, 0)))
		if left <= 0:
			continue
		var others: Array = siblings + ([root] if have.has(root) and root != key else [])
		for other: String in others:
			if left <= 0:
				break
			if other == key:
				continue
			var take: int = mini(left, int(spare.get(other, 0)))
			if take <= 0:
				continue
			spare[other] = int(spare[other]) - take
			given += take
			left -= take
	return given


## The sets in order: the most owned in their colours first (to 1 in
## 50,000), then the most in any colour, then the bigger, then the first in
## the file. One sort of whole numbers, each set's four keys packed into one:
## a comparison of 20,000 sets in GDScript was the slowest part.
func _ordered(owned: PackedInt32Array, shaped: PackedInt32Array) -> PackedInt32Array:
	var keys := PackedInt64Array()
	keys.resize(sets)
	for n: int in sets:
		var whole: int = maxi(1, pieces[n])
		var exact: int = (owned[n] * 50000) / whole
		var any: int = (maxi(owned[n], shaped[n]) * 50000) / whole
		keys[n] = ((50000 - exact) << 47) | ((50000 - any) << 31) | ((32767 - mini(pieces[n], 32767)) << 16) | n
	keys.sort()
	var out := PackedInt32Array()
	out.resize(sets)
	for n: int in sets:
		out[n] = keys[n] & 0xFFFF
	return out
