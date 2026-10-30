---
tool: pose_model
example: {"joint": "boom", "degrees": 30}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Swing a part about its joint, as Build, Pose does: a sub-assembly on a hinge, a turntable or a clip on a bar. With no joint it lists them, numbered, with the angle each is at. joint= (number or name) and degrees= (from where it was built, -180 to 180) swings it as far as it has room; the answer says where it stopped if something is in the way.
```
