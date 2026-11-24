---
tool: edit_model
example: {"recolor": [{"bricks": [3, 4], "color": 1}], "move": [{"bricks": [7], "dx": 1}]}
---

While the person's timeline shows a step, a call naming a part of a later step, not on their screen yet, is refused before anything changes, and the parts are named. Send `all_steps: true` only when the person has asked for the whole model; `"true"`, `1` and `"1"` read as true, and anything but true or false is refused with nothing changed. `mirror_parts`, `split_parts`, `merge_parts`, `pattern_parts`, `print_part`, `make_unique` and `move_part` refuse the same way; `replace_parts` leaves those parts out and counts them.

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Change what is already built without describing it again. Takes the numbers look_at_model prints beside each brick. Use this for any change to an existing model — moving a wall, recolouring a roof, taking a chimney off, adding a door — and only use submit_design when starting something new. Everything is checked together before any of it is applied, so a change that would not hold together changes nothing.
```
