---
tool: compare_with_photo
example: {"photo": "a red and white lighthouse on a cliff, from the side", "is_it": true, "silhouette": "the photograph's tower is six times as tall as it is wide and tapers to the lantern; mine is a straight stack three times as tall", "features": [{"name": "the lantern", "photo": "a glass room a fifth of the height, as wide as the top", "model": "two plates of trans-clear, narrower than the tower", "settle": "rebuild", "why": "it is what the lighthouse is known by"}, {"name": "the stripes", "photo": "three red bands, each a sixth of the height", "model": "three red bands of 3 bricks", "settle": "keep", "why": "they match"}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Answer the look beside a photograph of the real thing that a design's first whole review asks for: what the photograph shows, the silhouettes against each other, and each feature's form and size against the whole in the photograph and in your model, each settled rebuild or keep, and why. Only when a review asks.
```
