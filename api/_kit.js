// The site's kit (web/kit.js): an avatar made from a handle, the icons and
// an icon button, for the pages the server makes, drawn as a browser draws
// them. In a checkout this passes web/kit.js through; a deployment has no
// web/ beside its functions, so tools/deploy.sh puts web/kit.js here in its
// place, and web/card.js beside it as card.js, which the kit imports.
export * from "../web/kit.js";
