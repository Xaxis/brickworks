---
tool: page_setup
example: {"size": "A4", "orientation": "portrait", "margin": 12}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
The booklet's page, as Build, Booklet page, Page setup… sets it, for the whole booklet and its PDF: size= "booklet" (its own 269 x 199 mm), "A4", "letter" or "A5"; orientation= "portrait" or "landscape"; margin= mm; colour= the page's colour ("#ffffff", "usual" its light blue); picture_url= or picture_data= (base64) a picture behind every page, picture= "none" takes it off; number= the step numbers' height in mm (8 usual); parts= the parts boxes' pictures' size (1 usual, 0.5 to 2); usual=true the booklet's own page again. save_as= keeps the page as a style by that name, style= gives this model a kept style whole, and remove_style= takes a kept style away. One undo step, saved with the model. With nothing, says how the page is set up, its picture's size in the file, and the styles kept.
```
