#!/usr/bin/env bash
# Describe the real-set index's pieces, on your own Claude subscription.
#
#   tools/snippets.py build                      the index
#   (render the thumbnails: src/dev/snippet_thumbs.gd)
#   tools/snippets.py batches --out DIR          sheets of pictures and part lists
#   tools/describe_snippets.sh DIR [PARALLEL]    one Claude Code session a batch
#   tools/snippets.py texts DIR                  into assets/knowledge/snippet_texts.jsonl.gz
#   tools/snippets.py build                      again, with the descriptions in
#
# The same for families of parts, which have no picture: tools/part_looks.py
# batches --out DIR, this, then tools/part_looks.py merge DIR.
#
# Each session reads one sheet (numbered pictures) and its part list, and
# writes one line a piece saying what it is for and how it is built: the
# `text` the index is searched by. Nothing is billed: Claude Code is started
# without ANTHROPIC_API_KEY, so it runs on the subscription it is signed in
# to, with no tool but Read, confined to the batch's folder, no MCP server
# and none of the person's own settings. A batch that has an answer is not
# asked again.
#
# The whole run holds one slot of ~/.claude/claude-core/bin/heavy, with the
# sessions running side by side inside it: a session spends its time
# waiting on the network, not the CPU, and a slot a batch queued two
# hundred times behind the box's load.
set -u
if [ -z "${DESCRIBE_HELD:-}" ]; then
  DESCRIBE_HELD=1 exec env -u ANTHROPIC_API_KEY ~/.claude/claude-core/bin/heavy "$0" "$@"
fi
dir="${1:?the folder tools/snippets.py batches wrote}"
parallel="${2:-3}"
model="${DESCRIBE_MODEL:-sonnet}"
schema='{"type":"object","properties":{"items":{"type":"array","items":{"type":"object","properties":{"n":{"type":"integer"},"text":{"type":"string"}},"required":["n","text"]}}},"required":["items"]}'

describe() {
  local list="$1" folder name count prompt
  folder="$(dirname "$list")"
  name="$(basename "$list" .txt)"
  [ -s "$folder/$name.json" ] && return 0
  count="$(wc -l < "$folder/$name.ids")"
  if [ ! -f "$folder/$name.png" ]; then
    # Families of parts (tools/part_looks.py): names only, no picture.
    prompt="You are helping a LEGO designer find parts by what they look like in a \
model, not by their catalogue names. Read $name.txt: $count families of LEGO parts, \
numbered, each with a few part numbers and names. For every family write one line of \
8 to 30 words saying what it reads as in a model — the features and textures builders \
use it for, in plain words a designer would search with (e.g. for Plate 1 x 1 with \
Tooth: \"claw, talon, tooth, fang, spike, horn tip, beak point, flame tip, saw edge\"; \
for Cone 1 x 1: \"exhaust, nozzle, nose tip, lamp, bollard, candle, beak, finial\"). \
Lead with the most useful readings. Answer with every number from 1 to $count."
  else
  prompt="You are cataloguing sub-assemblies from real LEGO sets so that a designer \
building a model can find the right technique by what it is for. Read $name.png: \
$count pieces, each numbered in its top-left corner. Read $name.txt: under the same \
numbers, each piece's name in its set, the set, and its parts and colours. For every \
piece write one line of 12 to 35 words: first what it is FOR in a model, as a feature \
a builder would name (an owl's eye, a car's front bumper and grille, a tower's conical \
roof, a dragon's wing, a lamp post), then HOW it is built — the key parts, colours and \
techniques (studs forward on a bracket, hinged, clipped on a bar, curved slopes, \
tiles turned sideways). Example: \"owl eye: white 2x2 round tile ring with a black 1x1 \
round pupil, set studs-forward on a bracket\". Judge by the picture when the name says \
little (step numbers, codes, another language). Answer with every number from 1 to $count."
  fi
  ( cd "$folder" && timeout 900 env -u ANTHROPIC_API_KEY \
      claude -p "$prompt" --model "$model" --tools Read --allowedTools Read \
      --strict-mcp-config --restricted --no-session-persistence \
      --output-format json --json-schema "$schema" > "$name.json.part" 2> "$name.err" \
    && mv "$name.json.part" "$name.json" && echo "described $name" ) \
    || echo "failed $name (see $folder/$name.err)"
}
export -f describe
export schema model
# Again while there are batches without an answer: one that failed is
# asked once more, and batches written while this ran are taken too.
for round in 1 2 3 4; do
  todo=$(for list in "$dir"/batch_*.txt; do
           [ -s "${list%.txt}.json" ] || echo "$list"; done)
  [ -z "$todo" ] && break
  echo "round $round: $(echo "$todo" | wc -l) batches"
  echo "$todo" | xargs -P "$parallel" -I{} bash -c 'describe "$@"' _ {}
done
