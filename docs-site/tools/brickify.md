---
tool: brickify
example: {"url": "https://example.com/teapot.stl", "studs": 32, "up": "+Z"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Lay a 3D model in LEGO® bricks, as Build, Brickify a 3D model… does: an OBJ, STL, glTF/GLB, PLY, 3MF, VOX or FBX laid at the size asked (studs along its longest side) in slopes, curves and tiles, or plain bricks and plates, as one sub-assembly named after the file, beside what is built. file= its path on this computer (the desktop app), or url= an http(s) link to the file, fetched by the app (96 MB at most; an OBJ's .mtl and a .gltf's .bin come from beside it). pick=true opens the window's file dialog for the person to choose one on their computer, and says so; once they have, brickify with neither lays what the panel shows. Laying is a job: the answer is a job number, and job gives the result: whether it is one piece and stands (weighed), on what, any stand it was given, what was joined, and anything left out, where and why; its steps, a course a step with every step's build standing; and how to get its booklet and lists. collection=true lays it from the person's collection: their parts and colours first, then stand-ins, the shortfall said.
```
