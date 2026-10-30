---
tool: list_motions
example: {}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
The model's own motions, kept in its file ("Open the doors", "Steer left and right"): each with its joints as move_part names them, their keys (seconds, and places from where the model was built: degrees turned, or studs slid), its driver, or the motions it plays in order (a sequence), and what it was last found to do: where each joint ended, or where it stopped and on what. A joint whose part is gone, or a sequence's motion that is gone, is said so. Then motions suggested from what moves (doors, steering, a boom, a turntable, gears, a rack), each tried for room, which define_motion keeps. Changes nothing.
```
