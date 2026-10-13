// A directory served over http on a spare local port, for looking at the
// site's pages without deploying them.
//
// Not file://: the pages name their stylesheet and pictures from the root
// (/site.css, /img/…), because the 404 page is served at any depth and a
// relative name would resolve under whatever address was mistyped. Opened
// as files they would load unstyled, and a check of their layout would be
// measuring a page nobody sees.
//
//   const site = await serveDir("web");   // site.url is http://127.0.0.1:PORT
//   ...
//   site.close();
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";

const TYPES = {
  ".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "text/javascript",
  ".json": "application/json", ".png": "image/png", ".webp": "image/webp",
  ".svg": "image/svg+xml", ".xml": "application/xml", ".txt": "text/plain",
  ".webmanifest": "application/manifest+json",
};

export async function serveDir(dir) {
  const root = resolve(dir);
  const server = createServer(async (request, response) => {
    let path = decodeURIComponent(new URL(request.url, "http://x").pathname);
    if (path.endsWith("/")) path += "index.html";
    const file = normalize(join(root, path));
    if (!file.startsWith(root)) { response.writeHead(403).end(); return; }
    for (const candidate of [file, file + ".html"]) {
      try {
        const body = await readFile(candidate);
        response.writeHead(200, { "Content-Type": TYPES[extname(candidate)] || "application/octet-stream" });
        response.end(body);
        return;
      } catch { /* the next candidate */ }
    }
    response.writeHead(404, { "Content-Type": "text/plain" }).end("not found");
  });
  await new Promise((done) => server.listen(0, "127.0.0.1", done));
  return { url: `http://127.0.0.1:${server.address().port}`, close: () => server.close() };
}
