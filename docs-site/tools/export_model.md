---
tool: export_model
example: {"format": "studio"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Write the model out as File, Export does, where Export writes (the Downloads folder; a download on the web): format ldraw (.ldr, or .mpd with its sub-models, with its build steps), studio (a BrickLink Studio .io), a 3D file at real size — glb (one file: Blender, three.js, AR; any size of model), gltf (the same as text), obj (with an .mtl of its colours) or stl (one mesh in mm, Z up, to 3D print); obj and stl hold every triangle and are capped — picture (.png), bricklink (a wanted list), rebrickable (a parts list .csv), or instructions (the building instructions as a booklet to print); all_models is every model the person saved, as LDraw in one .zip (File, Export, All my models). studio, picture and instructions are jobs: the answer is a job number at once, and job gives the result.
```
