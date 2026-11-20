---
tool: pose_model
example: {"joint": "boom", "degrees": 30}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Swing a part about its joint, as Build, Pose does: a sub-assembly on a hinge, a turntable or a clip on a bar, or on a ball (three joints: its turns about x, y and z through the ball); and a part on a click hinge, a hinge or a turntable as a drag finds it, with no assembly named on it. With no joint it lists them, numbered, with the angle each is at. joint= (number or name) and degrees= (from where it was built, -180 to 180) swings it as far as it has room; the answer says where it stopped if something is in the way, and whether the pose holds its own weight: each friction joint (a Technic ball, a friction pin) that droops under what hangs on it, with the share it holds, and the joints whose hold nobody has measured. lock=true locks the joint (after degrees=, if given): it keeps its angle and its slide, and a drag of either part, R, a handle, Simulate's driver, move_part and pose_model are refused until lock=false unlocks it; saved with the model, and the answer says what a turn of it now does (it tries one). A model with one joint needs no joint= and no list first: {"lock": true} locks it, {"degrees": 45, "lock": true} sets it and locks it there. A drag's joint may be named by a part of it (#12).
```
