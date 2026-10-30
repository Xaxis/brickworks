---
tool: weakest_joints
example: {"count": 5}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
What gives first in the model as it stands, as View, Stress weighs it and the status bar's verdict says: every joint that alone holds what is past it (a cantilever's root, a part hung under another, a tower's foot), levered about the edge it would turn on, weakest first, each with the part that would come off, what it hangs from or stands on, its studs, the weight past it and its margin against the studs' working load (1 N a stud: under 1 is past it, under 2 within twice it; it lets go at about three times). A touch, one face resting on another with no stud between, carries only what stands on it, so it never shares a joint's load; a piece standing on touches alone past where it touches is said too. Read this instead of rebuilding the model in check_design to weigh it. part= one part's number (look_at_model) for what holds it; count= how many joints (8). Changes nothing.
```
