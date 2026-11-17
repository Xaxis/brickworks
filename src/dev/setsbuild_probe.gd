## What can I build? ranks every set Rebrickable lists (setsbuild,
## docs/APP_UX8.md #12): the index tools/collection_data.py writes, and the
## ranking read from it, held to Collection's own sums set by set.
##
##   godot --headless --path . --script src/dev/setsbuild_probe.gd
##
## 1. all_sets.bin reads, under the 2 MB the web fetches as the page opens.
## 2. Every set's parts, put back together from it, are OwnCounts.set_needs
##    of the set's own record in the shards, as this app's library counts
##    them: every set, packs too. So Python's reading of the catalogue
##    (collection_data._Owning) is the app's.
## 3. Against a pool of three sets and loose parts in other mouldings, every
##    set's owned and any-colour pieces are Collection.coverage's of its
##    record: all 20,000. Against a pool of 60 sets, a sample of 2,000.
## 4. Ten sets counted by hand: a plain loop, lot by lot, the pool's count
##    or the lot's, whichever is less, printed for reading.
## 5. How long a ranking takes, of the small pool and the big.
## 6. OwnCounts.set_needs and What do I need? for a set agree with its row.
##
## Writes nothing.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _records: Dictionary = {}


func _initialize() -> void:
	_run()


func _ok(good: bool, what: String) -> void:
	print(("  ok   " if good else "  FAIL ") + what)
	if not good:
		_failures += 1


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("FAIL no catalogue")
		quit(1)
		return
	print("\n1. the index")
	var path: String = SetInventories.ROOT + SetRanking.FILE
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var started: int = Time.get_ticks_usec()
	var why: Array = []
	var index: SetRanking = SetRanking.read(bytes, why)
	var read_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	_ok(index != null, "%s reads (%s), in %.0f ms" % [path, Counted.grouped(bytes.size(), "byte"), read_ms]
		+ ("" if why.is_empty() else ": " + str(why[0])))
	if index == null:
		quit(1)
		return
	_ok(bytes.size() <= 2000000, "it is under 2 MB: %s" % Counted.grouped(bytes.size(), "byte"))
	_ok(index.sets > 20000, "%s ranked, every set with a piece anybody owns" % Counted.grouped(index.sets, "set"))

	print("\n2. every set's parts, as this app counts them")
	for file: String in DirAccess.get_files_at(SetInventories.ROOT):
		if file.length() == 8 and file.ends_with(".json") and file.left(3).is_valid_int():
			var shard: Variant = JSON.parse_string(FileAccess.get_file_as_string(SetInventories.ROOT + file))
			_records.merge((shard as Dictionary).get("sets", {}))
	var parts: Array = _parts_of(index)
	var wrong := PackedStringArray()
	for n: int in index.sets:
		var record: Dictionary = _records.get(index.numbers[n], {})
		var needs: Dictionary = OwnCounts.set_needs(record, _library)
		if needs != parts[n]:
			wrong.append(index.numbers[n])
		var whole: int = 0
		for key: String in needs:
			whole += int(needs[key])
		if whole != index.pieces[n]:
			wrong.append(index.numbers[n] + " (pieces)")
	_ok(wrong.is_empty(), "every set's parts read back (%s) are OwnCounts.set_needs of its record%s"
		% [Counted.grouped(index.sets, "set"), "" if wrong.is_empty() else ": not " + ", ".join(wrong.slice(0, 8))])
	var unranked := PackedStringArray()
	var empty: int = 0
	for number: String in _records:
		if index.index_of(number) >= 0:
			continue
		if OwnCounts.set_needs(_records[number], _library).is_empty():
			empty += 1
		elif not number in index.not_sets:
			unranked.append(number)
	_ok(unranked.is_empty(), ("no set with a piece anybody owns is left out; %d with none are (books, gear, "
		+ "sticker sheets), and %d of Rebrickable's database sets%s") % [empty, index.not_sets.size(),
		"" if unranked.is_empty() else ": " + ", ".join(unranked.slice(0, 8))])

	print("\n3. the ranking against Collection.coverage")
	var small: Dictionary = _pool(["6020-1", "6080-1", "10696-1"], [["3794a", 15, 6], ["3794b", 15, 3],
		["3062a", 4, 8], ["3062b", 1, 5], ["2412a", 72, 4], ["3001", 14, 20], ["4073", 0, 30],
		["3069a", 0, 10], ["3070a", 71, 10], ["3068a", 72, 6]])
	var ranked: SetRanking.Ranked = index.rank(small)
	print("     the small pool: %s, %d keys; ranked in %d ms (moulds %d, order %d)" % [
		Counted.grouped(_count(small), "piece"), small.size(), ranked.took / 1000, ranked.took_moulds / 1000,
		ranked.took_order / 1000])
	var off := PackedStringArray()
	var moulded: int = 0
	for n: int in index.sets:
		var cover: Dictionary = Collection.coverage(OwnCounts.set_needs(_records[index.numbers[n]], _library), small)
		if int(cover["owned"]) != ranked.owned[n] or not is_equal_approx(float(cover["any_colour"]), ranked.any_colour(n)):
			off.append("%s %d/%d against %d/%.3f" % [index.numbers[n], ranked.owned[n], index.pieces[n],
				int(cover["owned"]), float(cover["any_colour"])])
		if not (Collection.allocate(OwnCounts.set_needs(_records[index.numbers[n]], _library), small)["moulds"]
				as Dictionary).is_empty():
			moulded += 1
	_ok(off.is_empty(), "every set's owned and any-colour pieces are Collection.coverage's%s"
		% ("" if off.is_empty() else ": not " + ", ".join(off.slice(0, 6))))
	_ok(moulded > 50, "...%d of them with another moulding standing in, as Collection.allocate gives it" % moulded)
	var whole_owned := PackedStringArray()
	for number: String in ["6020-1", "6080-1", "10696-1"]:
		whole_owned.append("%s %d%%" % [number, roundi(ranked.exact(index.index_of(number)) * 100.0)])
	_ok(ranked.at_least(ranked.order, 1.0) >= 3 and ranked.exact(index.index_of("6080-1")) == 1.0,
		"the sets they own are 100%% (%s); %d sets in all at 100%%, the first %s %s" % [", ".join(whole_owned),
		ranked.at_least(ranked.order, 1.0), index.numbers[ranked.order[0]], index.names[ranked.order[0]]])
	var ordered: bool = true
	for k: int in range(1, index.sets):
		if ranked.exact(ranked.order[k]) > ranked.exact(ranked.order[k - 1]) + 0.00003:
			ordered = false
	_ok(ordered, "most owned first, all %s" % Counted.grouped(index.sets, "set"))

	var big_sets: Array = []
	var picked: int = 0
	for n: int in index.sets:
		if index.pieces[n] >= 300 and n % 97 == 3:
			big_sets.append(index.numbers[n])
			picked += 1
		if picked >= 60:
			break
	var big: Dictionary = _pool(big_sets, [])
	var big_ranked: SetRanking.Ranked = index.rank(big)
	print("     the big pool: %d sets, %s, %d keys; ranked in %d ms (moulds %d, order %d)" % [big_sets.size(),
		Counted.grouped(_count(big), "piece"), big.size(), big_ranked.took / 1000, big_ranked.took_moulds / 1000,
		big_ranked.took_order / 1000])
	off = PackedStringArray()
	var checked: int = 0
	for n: int in range(0, index.sets, 10):
		checked += 1
		var cover: Dictionary = Collection.coverage(OwnCounts.set_needs(_records[index.numbers[n]], _library), big)
		if int(cover["owned"]) != big_ranked.owned[n] or not is_equal_approx(float(cover["any_colour"]),
				big_ranked.any_colour(n)):
			off.append("%s %d against %d" % [index.numbers[n], big_ranked.owned[n], int(cover["owned"])])
	_ok(off.is_empty(), "against the big pool, %s of them are Collection.coverage's%s" % [
		Counted.grouped(checked, "set"), "" if off.is_empty() else ": not " + ", ".join(off.slice(0, 6))])
	var top := PackedStringArray()
	for k: int in 5:
		var n: int = big_ranked.order[k]
		top.append("%d%% %s %s" % [roundi(big_ranked.exact(n) * 100.0), index.numbers[n], index.names[n]])
	print("     its top five: " + "; ".join(top))
	_ok(big_ranked.at_least(big_ranked.order, 1.0) >= big_sets.size(), "each of its %d sets is 100%% (%d at 100%%)"
		% [big_sets.size(), big_ranked.at_least(big_ranked.order, 1.0)])

	print("\n4. ten sets counted by hand, against the small pool")
	var hand: Array = ["6020-1", "6080-1", "7140-1", "10237-1", "30263-1", "3931-1", "8880-1", "6086-1",
		"10696-1", "75192-1"]
	for number: String in hand:
		var n: int = index.index_of(number)
		var record: Dictionary = _records.get(number, {})
		var pieces: int = 0
		var have: int = 0
		var lots: int = 0
		var by_key: Dictionary = {}
		for row: Variant in record.get("p", []):
			var lot: Array = row
			var key: String = Collection.key_of(str(lot[0]), int(lot[1]), _library)
			if not Collection.ownable(Collection.part_of(key), _library):
				continue
			by_key[key] = int(by_key.get(key, 0)) + int(lot[2])
		for key: String in by_key:
			lots += 1
			pieces += int(by_key[key])
			have += mini(int(by_key[key]), int(small.get(key, 0)))
		var moulds: int = ranked.owned[n] - have if n >= 0 else 0
		_ok(n >= 0 and pieces == index.pieces[n] and have + moulds == ranked.owned[n] and moulds >= 0,
			"%s %s: %d lots, %d pieces, %d owned lot by lot%s; the page says %d%%" % [number,
			str(record.get("n", "")), lots, pieces, have, " and %d more in another moulding" % moulds if moulds > 0
			else "", roundi(ranked.exact(n) * 100.0) if n >= 0 else -1])

	print("\n5. what do I need? for one of them")
	var row: int = index.index_of("7140-1")
	var needs: Dictionary = OwnCounts.set_needs(_records["7140-1"], _library)
	var plan: Array = Collection.plan(needs, small, _library)
	var short: int = 0
	for one: Dictionary in plan:
		short += int(one["short"])
	_ok(short == index.pieces[row] - ranked.owned[row], "7140-1's What do I need? is short %d pieces, its row %d"
		% [short, index.pieces[row] - ranked.owned[row]])

	if _failures == 0:
		print("setsbuild probe: every set ranked as Collection counts it")
	else:
		print("setsbuild probe: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## The pool of [param numbers]' sets and [param loose] lots ([part, colour,
## qty]), as CollectionStore makes it.
func _pool(numbers: Array, loose: Array) -> Dictionary:
	var mine := Collection.new()
	for number: String in numbers:
		mine.sets.append({"set": number, "qty": 1, "spares": false})
	for lot: Array in loose:
		mine.parts.append({"part": lot[0], "colour": lot[1], "qty": lot[2]})
	var found: Dictionary = {}
	for number: String in numbers:
		found[number] = _records[number]
	return mine.pool(found, _library)


static func _count(pool: Dictionary) -> int:
	var total: int = 0
	for key: String in pool:
		total += int(pool[key])
	return total


## Every set's parts, put back together from the index: its postings, its
## leaves' times how many, the set it is the same as.
static func _parts_of(index: SetRanking) -> Array:
	var own: Array = []
	for n: int in index.sets:
		own.append({})
	for p: int in index._keys.size():
		var s: int = -1
		for i: int in range(index._post[p], index._post[p + 1]):
			s += index._low[i] + (index._high[i] << 8) + 1
			var q: int = index._qty[i]
			if q == SetRanking.OVER:
				q = int(index._over[i])
			own[s][index._keys[p]] = q
	var whole: Array = []
	for n: int in index.sets:
		whole.append((own[n] as Dictionary).duplicate())
	for leaf: int in index.sets:
		for u: int in range(index._up_at[leaf], index._up_at[leaf + 1], 2):
			var pack: int = index._up[u]
			for key: String in own[leaf]:
				whole[pack][key] = int(whole[pack].get(key, 0)) + int(own[leaf][key]) * index._up[u + 1]
	for k: int in range(0, index._same.size(), 2):
		whole[index._same[k]] = (whole[index._same[k + 1]] as Dictionary).duplicate()
	return whole
