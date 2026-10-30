---
tool: play_motion
example: {"name": "Open the doors", "view": "hero"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Play one of the model's motions (list_motions) through its real joints, as a drag moves them: a joint stops where it meets the model, and gears, racks and linkages follow. The model is left where the motion ends, one undo step. reverse=true plays it backwards (closes what it opened; a driver turns back; a sequence plays its motions in reverse order). sequence=true plays the chain an older file's AFTER lines put it in. The answer says where each joint ended or stopped and on what, how the model then stands, and carries a picture of its frames from the view that sees most of what moves (or view=), and says which.
```
