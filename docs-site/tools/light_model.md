---
tool: light_model
example: {"op": "add", "kind": "spot", "over": [3, 4], "cone": 30, "strength": 2}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
The lights kept with the model, as Render's Lights in the model keeps them: a spot over a cockpit, a bulb in a lamp post, a low sun, a panel of light over a room. render_model and render_queue draw them over the studio in every quality, and with light=dark they and the plastics that glow are all that lights the model. With no op it lists them, numbered, and changes nothing. op add puts one in: kind spot (the default), point (a bulb), directional (a sun) or area (a square panel of light), set over the parts numbered in over= (look_at_model numbers them; the whole model when omitted) as a photographer first sets one, or placed by at= and aim=. op change changes light number= (any of over, at, aim, colour, strength, cone, size, shadows); op remove takes light number= out. at and aim are in LDU in the file's coordinates, LDraw's: y down, so a light above the model has a smaller y than its top, and aim [0, 1, 0] shines straight down. strength 1 lights a face 100 LDU from a lamp, or any face turned to a sun, as the window's key light does, and a lamp lights four times as brightly at half the distance. cone is a spot's whole angle in degrees, 2 to 160; size a bulb's radius or a panel's side in LDU. At most 8, 4 of them suns (the studio's three lights, its sky and four suns are the eight a renderer draws). Kept in the model's file, saved with it, not an undo step.
```
