---
tool: mirror_parts
example: {"bricks": [12, 13, 14], "copy": true, "across": 0}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Make parts their mirror image, as the window's Mirror does: each put where its reflection is and turned, a part made in a left and a right hand (a wing, a wedge plate, a door) swapped for its other hand. bricks= the parts; axis "x" mirrors left to right (the default), "z" front to back. In place, across the plane through their middle; copy=true leaves them and puts a mirrored copy beside them, across their far side (+x or +z). across= puts the plane where you say, in studs, a whole or half number: copy=true across=0 makes a model's left half its right half too. All or nothing, one undo step; refused where the mirror image runs into a part not named.
```
