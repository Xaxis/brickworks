---
tool: add_rooms
example: {"where": {"x_from": 0, "x_to": 12, "y_from": 3, "y_to": 60, "z_from": 0, "z_to": 12}, "floors": [{"room": "hall"}, {"room": "library", "stair": true}, {"room": "lookout"}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Floors and furnished rooms inside a building that already stands — a tower, a keep, a house — in one call, as a real set opens at the back onto them (10237 Orthanc: a library, Saruman's chamber, a dungeon, the palantír). Give the building's box (where) or, for a prism, the prism's own at, sides and radius (prism), and the floors bottom up, each a kind of room: library, study, bedchamber, hall, throne room, forge, armoury, dungeon, kitchen, lookout, palantir room, stair. Each floor is laid as plates and tiles held up on columns; each room is furnished from the worked examples real sets built — bookcases, a fireplace, an anvil, a four-poster bed, lamps, chests, barrels — against its walls and facing in, varied by the seed; stair: true climbs to the next floor. The shell is left as it is and the edit is checked like any other, so build it open at the back (a prism's open, or no back wall) for the rooms to be seen. This is where a real set's different pieces and colours are, and a solid shell has none of them.
```
