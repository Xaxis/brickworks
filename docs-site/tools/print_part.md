---
tool: print_part
example: {"brick": 12, "sticker": true, "side": "+z", "svg": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 16\"><rect width=\"40\" height=\"16\" fill=\"#c91a09\"/><text x=\"20\" y=\"11\" font-size=\"8\" text-anchor=\"middle\" fill=\"#fff\">FIRE</text></svg>"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Print a picture on a part of the model, or stick it on as a sticker, as Build, Print on a part… and Put a sticker on… do. brick= the part's number in look_at_model. A print goes on one of the part's printable areas (area=, the first when omitted; a wrong one is answered with its areas), and the printed part takes the part's place in its colour, a part of its own from then on. sticker=true makes a sticker the size of the part's side= face (up, down, +x, -x, +z, -z), running over the faces in the same plane beside it unless span=false, and sticks it on. The picture: svg= drawn by you (a whole <svg> with a viewBox in the face's proportions; flat colours print best), picture_data= a picture's own bytes as base64 or a data: URI (a PNG or JPEG the person gave you in the conversation; at most 2 MB, smaller is quicker), or picture_url= an http(s) link to a PNG, JPEG, WebP or SVG. Or the LEGO Group's own, as Edit, Printed versions… does: version= one of the part's printed or stickered versions from the library (versions="words" lists them) swaps the part for it where it stands; sticker_part= a sticker the library has (search_parts "sticker") sticks it on the side= face, lying on it.
```
