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


## What a subject is a kind of, where real sets' names do not say it: the
## kinds of set (PartLibrary.kinds, the words of real sets' names) a word is
## filed under by what the thing is — a limousine is a car, a forklift moves
## cargo, a lighthouse is a tower on the coast. Hypernyms, by class: the road,
## the building site, the farm, the railway, the water, the air, space, snow,
## and buildings by what they are for. How a set-knowledge lookup that knew
## "boat" and not "tugboat" falls back (walk180, 2026-10-23); each kind is
## used only where the catalogue has it.
const IS_A: Dictionary = {
	# the road
	"limousine": ["car"], "limo": ["car"], "sedan": ["car"], "saloon": ["car"],
	"taxi": ["car"], "cab": ["car"], "convertible": ["car"], "coupe": ["car"],
	"hatchback": ["car"], "jeep": ["car", "off"], "suv": ["car", "off"],
	"automobile": ["car"], "roadster": ["car", "racer"], "hotrod": ["car", "racer"],
	"dragster": ["racer", "race"], "campervan": ["van", "car"], "camper": ["van", "car"],
	"motorhome": ["van", "car"], "caravan": ["trailer", "van"], "minivan": ["van", "car"],
	"minibus": ["bus"], "coach": ["bus"], "trolleybus": ["bus"],
	"lorry": ["truck"], "semi": ["truck"], "pickup": ["truck", "car"],
	"tipper": ["truck", "construction"], "dumper": ["truck", "construction"],
	"garbage": ["truck"], "dustcart": ["truck"], "wrecker": ["tow", "truck"],
	"motorbike": ["motorcycle", "bike"], "moped": ["scooter", "motorcycle"],
	"dirtbike": ["motorcycle", "bike"], "quad": ["bike", "off"], "atv": ["bike", "off"],
	"bicycle": ["bike"], "tricycle": ["bike"], "chopper": ["motorcycle", "helicopter"],
	"gokart": ["kart"],
	# the building site and the farm
	"bulldozer": ["construction", "loader"], "dozer": ["construction", "loader"],
	"digger": ["excavator", "construction"], "backhoe": ["excavator", "construction"],
	"forklift": ["cargo", "loader"], "steamroller": ["construction"],
	"roller": ["construction"], "grader": ["construction"], "mixer": ["construction", "truck"],
	"scaffold": ["construction"], "crane": ["crane", "construction"],
	"combine": ["farm", "tractor"], "harvester": ["farm", "tractor"],
	"plough": ["farm", "tractor"], "plow": ["farm", "tractor"], "barn": ["farm"],
	"stable": ["farm", "horse"], "silo": ["farm"], "farmhouse": ["farm", "house"],
	"windmill": ["farm", "building"], "watermill": ["farm", "building"], "mill": ["farm", "building"],
	# the railway
	"tram": ["train"], "streetcar": ["train"], "monorail": ["train"], "subway": ["train"],
	"metro": ["train"], "railcar": ["train"], "railway": ["train", "station"],
	"steam": ["locomotive", "train"], "diesel": ["locomotive", "train"],
	# the water
	"speedboat": ["boat"], "motorboat": ["boat"], "powerboat": ["boat"], "yacht": ["boat"],
	"sailboat": ["boat"], "dinghy": ["boat"], "rowboat": ["boat"], "rowing": ["boat"],
	"canoe": ["boat"], "kayak": ["boat"], "raft": ["boat"], "catamaran": ["boat"],
	"trawler": ["boat"], "tug": ["boat"], "tugboat": ["boat"], "barge": ["boat", "cargo"],
	"steamer": ["boat", "ship"], "liner": ["ship"], "cruise": ["ship"],
	"hovercraft": ["boat", "coast"], "jetski": ["boat"], "lifeboat": ["boat", "coast"],
	"submarine": ["sub", "sea"], "galleon": ["ship", "pirate"], "frigate": ["ship"],
	"schooner": ["ship", "boat"], "warship": ["ship"], "harbour": ["boat", "coast"],
	"harbor": ["boat", "coast"], "port": ["boat", "cargo"], "dock": ["boat", "cargo"],
	"pier": ["boat", "beach"], "marina": ["boat"], "lighthouse": ["tower", "coast", "island"],
	# the air
	"airliner": ["plane", "airport"], "jetliner": ["plane", "airport"],
	"aeroplane": ["plane"], "aircraft": ["plane"], "biplane": ["plane"], "glider": ["plane"],
	"seaplane": ["plane", "sea"], "bomber": ["plane"], "airship": ["plane", "sky"],
	"blimp": ["plane", "sky"], "zeppelin": ["plane", "sky"], "balloon": ["sky"],
	"hangar": ["airport"], "gyrocopter": ["helicopter"],
	# space
	"satellite": ["space"], "spacecraft": ["space"], "spaceship": ["space"],
	"starship": ["space"], "ufo": ["space", "alien"], "lander": ["space", "lunar"],
	"moonbase": ["space", "lunar"], "astronaut": ["space"], "telescope": ["space"],
	"observatory": ["space", "building"], "spaceport": ["space"],
	# snow and ice
	"snowmobile": ["snow", "arctic"], "snowplough": ["snow", "truck"], "snowplow": ["snow", "truck"],
	"sled": ["snow", "winter"], "sledge": ["snow", "winter"], "sleigh": ["snow", "winter"],
	"igloo": ["arctic", "snow"], "chalet": ["winter", "house"], "ski": ["snow", "winter"],
	# buildings, by what they are for
	"skyscraper": ["building", "city"], "office": ["building", "city"],
	"apartment": ["building", "city"], "flats": ["building", "city"],
	"hospital": ["building", "ambulance"], "clinic": ["building", "ambulance"],
	"church": ["building", "village"], "cathedral": ["building", "castle"],
	"chapel": ["building", "village"], "abbey": ["building", "castle"],
	"monastery": ["temple", "building"], "mosque": ["temple", "building"],
	"shrine": ["temple"], "pagoda": ["temple"], "pyramid": ["temple", "desert"],
	"cinema": ["building", "street"], "theatre": ["building", "street"],
	"theater": ["building", "street"], "museum": ["building", "city"],
	"library": ["building", "school"], "courthouse": ["building", "town"],
	"town hall": ["building", "town"], "bank": ["building", "street"],
	"hotel": ["building", "house"], "restaurant": ["shop", "street"], "cafe": ["shop", "street"],
	"bakery": ["shop", "street"], "pizzeria": ["shop", "street"], "diner": ["shop", "street"],
	"pub": ["shop", "street"], "inn": ["house", "village"], "tavern": ["house", "village"],
	"supermarket": ["shop", "store"], "mall": ["shop", "store"], "boutique": ["shop", "store"],
	"zoo": ["animals", "park"], "aquarium": ["sea", "animals"], "safari": ["animals", "jungle"],
	"stadium": ["sports"], "arena": ["sports"], "circus": ["park", "show"],
	"fairground": ["park", "ride"], "funfair": ["park", "ride"], "carousel": ["park", "ride"],
	"rollercoaster": ["roller", "park"], "campsite": ["forest", "holiday"],
	"tent": ["forest", "holiday"], "cabin": ["house", "forest"], "hut": ["house"],
	"bungalow": ["house"], "villa": ["house"], "mansion": ["house"], "cottage": ["house"],
	"treehouse": ["tree", "house"], "townhouse": ["house", "street"], "workshop": ["garage"],
	"fort": ["castle"], "fortress": ["castle", "fortress"], "citadel": ["castle"],
	"keep": ["castle"], "manor": ["house", "castle"],
	# the Wild West
	"stagecoach": ["carriage", "horse", "wagon"], "covered wagon": ["wagon", "horse"],
	"saloon bar": ["house", "village"],
}


## Names for one thing said two ways, the plainer second: what a lookup by
## real sets' names reads a subject as. Real sets say fire truck, gas station.
const SAME_AS: Dictionary = {
	"fire engine": "fire truck", "fire tender": "fire truck", "fire appliance": "fire truck",
	"squad car": "police car", "cop car": "police car", "patrol car": "police car",
	"panda car": "police car", "petrol station": "gas station",
	"filling station": "gas station", "service station": "gas station",
	"steam engine": "steam locomotive", "railway engine": "locomotive",
	"jumbo jet": "airliner", "aeroplane": "airplane", "lorry": "truck",
	"motor car": "car", "taxicab": "taxi", "tow truck": "tow truck",
	"recovery truck": "tow truck", "breakdown truck": "tow truck",
	"dump truck": "tipper truck", "dumper truck": "tipper truck",
	"bin lorry": "garbage truck", "dustbin lorry": "garbage truck",
	"refuse truck": "garbage truck", "rubbish truck": "garbage truck",
}


## [param text] in the words real sets' names use (SAME_AS): "fire engine"
## as "fire truck".
static func plainly(text: String) -> String:
	var said: String = " %s " % " ".join(of(text))
	for phrase: String in SAME_AS:
		if said.contains(" %s " % phrase):
			said = said.replace(" %s " % phrase, " %s " % SAME_AS[phrase])
	return said.strip_edges()


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
## word of a brief is, or "": the first of [method kinds_of_word].
static func kind_of_word(word: String, vocabulary: Dictionary) -> String:
	var found: PackedStringArray = kinds_of_word(word, vocabulary)
	return found[0] if not found.is_empty() else ""


## The words of [param vocabulary] that one word of a brief is, what it is
## first: itself or a form of it; or, made of two, a word of the vocabulary
## of four letters or more and one of [constant COMPOUND_ENDS] — "spaceship"
## is space, "planetarium" is nothing. Of a word made of two that are both
## the vocabulary's, the second is what the thing is and the first says
## which kind of it, so the second goes first: a speedboat is a boat before
## it is speed, whose sets are high-speed trains and chases, and a firetruck
## a truck, then a fire set's. Unless what the word is a kind of (IS_A) says
## which: a spaceship is space, and no sea ship.
static func kinds_of_word(word: String, vocabulary: Dictionary) -> PackedStringArray:
	for form: String in forms(word):
		if form.length() >= 3 and vocabulary.has(form):
			return PackedStringArray([form])
	for end: String in COMPOUND_ENDS:
		for form: String in forms(word):
			if form.length() > end.length() + 3 and form.ends_with(end):
				for one: String in forms(form.left(-end.length())):
					if not vocabulary.has(one):
						continue
					if not vocabulary.has(end):
						return PackedStringArray([one])
					var is_a: Array = IS_A.get(form, IS_A.get(word, []))
					if is_a.has(one) != is_a.has(end):
						return PackedStringArray([one if is_a.has(one) else end])
					return PackedStringArray([end, one])
	return PackedStringArray()
