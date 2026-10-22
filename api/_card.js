// The site's one model card (web/card.js), for the pages the server makes.
// In a checkout this passes web/card.js through; a deployment has no web/
// beside its functions, so tools/deploy.sh puts web/card.js here in its
// place, and the server and the browser draw a card from the same file.
export * from "../web/card.js";
