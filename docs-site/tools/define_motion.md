---
tool: define_motion
example: {"name": "Open the doors", "tracks": [{"joint": "left door", "keys": [{"t": 0, "place": 0}, {"t": 1.5, "place": 90}]}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Keep a named motion in the model, as a builder names it ("Open the dome"), played by the real joints as a drag moves them. tracks= each a joint (a part's number "#80" or a sub-assembly's name, as move_part names them) and its keys: t= seconds, place= degrees turned from where the model was built (studs slid, with slide=true), how= ease (the default), linear or hold. Or driver= a joint turned turns= times over seconds=, from where it stands: what it drives through gears, racks and linkages follows. Or sequence= the model's motions by name, in order ("Show it all": ["Open the dome", "Extend the telescope"]): a motion made of motions, each played from where the one before left the model, backwards in reverse order. suggested=true keeps list_motions' suggestion of that name; remove=true takes a motion out. It is saved with the model (its autosave, a save, an export, a shared link), one undo step, and answers by playing it once and putting the model back: where each joint ended, or stopped and on what.
```
