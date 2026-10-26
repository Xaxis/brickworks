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
	return "%d %s" % [count, one if count == 1 else (many if not many.is_empty() else one + "s")]
