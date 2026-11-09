## A count and what it counts, as a person says them: "1 colour", "3 colours".
##
## walk256 (S3): the bin said "A dot marks the 1 colours 3648a comes in". A
## count put in front of a plural is wrong once in every count that can be
## one: the colours a part comes in, the pieces and lots of a model, the
## constructions a search finds.
class_name Counted
extends RefCounted


## [param count] and [param one], or [param many] (one with an s, if not
## given) for any other count.
static func of(count: int, one: String, many: String = "") -> String:
	return "%d %s" % [count, _word(count, one, many)]


## The same with its thousands grouped as the interface writes a count,
## "1,152 round tiles": for what runs to thousands, a picture's parts. Brick
## Art said "1 stars" and "1 16 × 16 panels" (mosaic3, 2026-11-08).
static func grouped(count: int, one: String, many: String = "") -> String:
	return "%s %s" % [Working.comma(count), _word(count, one, many)]


static func _word(count: int, one: String, many: String) -> String:
	return one if count == 1 else (many if not many.is_empty() else one + "s")
