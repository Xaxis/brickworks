# Changelog

What changed in each release of the desktop app, newest first. The web
build at brickworks.diy is deployed continuously and is not versioned
here; a desktop release is a snapshot of it, with the whole part library
inside so it works offline.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and versions follow [Semantic Versioning](https://semver.org/). New
entries go under `[Unreleased]`; `tools/release.py version --set X.Y.Z`
moves them into a section for the release. `docs/RELEASING.md` is the
whole cycle.

## [Unreleased]

## [0.1.0] - 2026-10-10

The first desktop release: Brickworks for Linux, macOS and Windows, with
all 28,319 parts on disk, so building, saving and the instructions need
no network at all. Designing with Claude still does, on your own API key
or Claude plan. The macOS and Windows builds are not yet signed by Apple
or Microsoft, so each asks once before it first opens; the download page
says how.

### Added

- Every part in the LDraw library that can be placed, at true size on a
  2 LDU lattice: 28,319 parts in 322 colours, searchable by name, number
  and the sets they came in.
- Building by hand: place against any face, box select, paint, nudge,
  rotate, lift and move, undo and redo, and a build timeline to drag
  along or play either way.
- Designing with Claude from a sentence, on an Anthropic API key of your
  own or your own Claude plan through Connect Claude. The key goes only to
  Anthropic.
- Build steps recovered from the geometry, a parts list by colour (CSV),
  printable instructions, photo mosaics, and LDraw `.ldr` / `.mpd` in and
  out.
- An MCP port (`--mcp`) so a Claude Code session can drive the app.
- The version in the window title and in Help (`,`), and `--about` on the
  command line, so a downloaded build can say which release it is.
