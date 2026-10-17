// The model, shown in Claude beside the call that built it: MCP Apps.
//
// Since 2026-01-26 a server can show its own page inline in a Claude
// conversation, on the web, the desktop and the phone (the MCP Apps
// extension, io.modelcontextprotocol/ui; spec 2026-01-26,
// github.com/modelcontextprotocol/ext-apps, specification/2026-01-26/apps.mdx).
// The page is a ui:// resource of mimeType text/html;profile=mcp-app, read
// with resources/read, and a tool names it in its _meta (ui.resourceUri,
// and the older flat "ui/resourceUri" that hosts still read). The host
// draws it in a sandboxed frame and hands it the call's whole result over
// postMessage (ui/notifications/tool-result).
//
// This is that page (2026-10-15): the real model in 3D, from the part
// geometry the app itself loads, with Check, Instructions, Parts and Open
// in Brickworks, a part picked told to Claude, and full screen. Its source
// is tools/viewer/; tools/viewer/build.mjs bundles it, three.js and all,
// into one self-contained page, api/_viewer_page.js.
//
// What it shows comes two ways. A session whose client says it shows such
// pages has the model packed into the answer's _meta ("brickworks/view",
// src/net/model_views.gd), which no client hands the model. And whatever
// the host hands it, the card asks the tab itself, through the host:
// tools/call to tools only an app may call (_meta.ui.visibility ["app"],
// listed only to such a session: VIEWER_ONLY), or, from a host that will
// not call a tool its model was not given, resources/read of
// brickworks://viewer/<what> (viewerAsked). Both reach the tab as a call
// of src/net/viewer_tools.gd's. Every other client sees what it saw before:
// the same tools, the same words, the same pictures.
//
// The page fetches each part's geometry from where the app fetches it,
// the one origin it declares (_meta.ui.csp.connectDomains); nothing else.

import { VIEWER_HTML } from "./_viewer_page.js";

export { VIEWER_HTML };
export const EXTENSION = "io.modelcontextprotocol/ui";
export const VIEWER_URI = "ui://brickworks/model.html";
export const VIEWER_MIME = "text/html;profile=mcp-app";
// The tools whose answer is the model as it now stands (ModelViews.TOOLS).
export const VIEWER_TOOLS = ["submit_design", "look_at_model", "view_model", "edit_model", "open_model", "brickify"];
// What a call carries to the tab to ask for the viewer's share of its answer.
export const ASK_VIEWS = "brickworks/views";
// The calls that ask for it: those, and the job tool (src/net/tool_jobs.gd),
// whose answer once a call has become a job and ended is that call's, the
// viewer's share and all; and the card beside the call that became one asks
// it for that, through the host (_meta "brickworks/job").
export const asksViews = (name) => VIEWER_TOOLS.includes(name) || name === "job";

const ONLY_APP = { ui: { resourceUri: VIEWER_URI, visibility: ["app"] } };
const LOOKS = (title) => ({ title, readOnlyHint: true, openWorldHint: false });

// The card's own tools (src/net/viewer_tools.gd), for the app alone.
export const VIEWER_ONLY = [
  {
    name: "viewer_scene",
    description: "The model as it stands in the Brickworks tab, packed for the viewer to draw in 3D, "
      + "with its parts count; views: true for pictures too.",
    inputSchema: { type: "object", properties: { views: { type: "boolean" } }, additionalProperties: false },
    annotations: LOOKS("The model, for the viewer"),
    _meta: ONLY_APP,
  },
  {
    name: "viewer_check",
    description: "Tools, Check stability, for the viewer: the weak joints, and the stud joints carrying "
      + "half their working load or more, by part number.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    annotations: LOOKS("Check, for the viewer"),
    _meta: ONLY_APP,
  },
  {
    name: "viewer_steps",
    description: "The model's build steps as the booklet sets them out, for the viewer to step through.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    annotations: LOOKS("The steps, for the viewer"),
    _meta: ONLY_APP,
  },
  {
    name: "viewer_parts",
    description: "The parts list and the BrickLink wanted list, for the viewer.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    annotations: LOOKS("The parts, for the viewer"),
    _meta: ONLY_APP,
  },
  {
    name: "viewer_pick",
    description: "Select the part the person picked in the viewer in their Brickworks tab (brick 0 lets go), "
      + "if the tab's model is still the viewer's (of).",
    inputSchema: { type: "object", properties: { brick: { type: "integer" }, of: { type: "string" } },
      required: ["brick"], additionalProperties: false },
    annotations: { title: "Select the picked part", readOnlyHint: false, destructiveHint: false,
      idempotentHint: true, openWorldHint: false },
    _meta: ONLY_APP,
  },
];
export const isViewerOnly = (name) => VIEWER_ONLY.some((tool) => tool.name === name);

// What a host may read in place of calling them: brickworks://viewer/scene,
// /check, /steps and /parts (?views=1 on the scene). The call it stands
// for, or null for any other address.
const ASKED = /^brickworks:\/\/viewer\/(scene|check|steps|parts)(?:\?(.*))?$/;
export function viewerAsked(uri) {
  const found = ASKED.exec(String(uri || ""));
  if (!found) return null;
  const args = {};
  if (found[1] === "scene" && new URLSearchParams(found[2] || "").get("views") === "1") args.views = true;
  return { name: `viewer_${found[1]}`, arguments: args };
}

// A part's geometry, through the host, for a page whose host will not let
// it fetch from the origin it declares: brickworks://viewer/part/<hash>,
// read here from where the app reads it. The hash, or null.
const PART = /^brickworks:\/\/viewer\/part\/([0-9a-f]{12,64})$/;
export function viewerPart(uri) {
  const found = PART.exec(String(uri || ""));
  return found ? found[1] : null;
}
export async function partRead(hash, uri, env = process.env) {
  const root = partsRoot(env);
  if (!root) return null;
  const answer = await fetch(`${root}${hash}.lbm`);
  if (!answer.ok) return null;
  const bytes = Buffer.from(await answer.arrayBuffer());
  return { contents: [{ uri, mimeType: "application/octet-stream", blob: bytes.toString("base64") }] };
}

// A call's answer as resources/read gives it: the structuredContent as JSON,
// or the call's words as an error.
export function asRead(answer, uri) {
  const result = answer && answer.result;
  if (!result || typeof result !== "object") return answer;
  const words = (Array.isArray(result.content) ? result.content : [])
    .filter((b) => b && b.type === "text").map((b) => String(b.text)).join(" ").trim();
  if (result.isError || !result.structuredContent) {
    return { jsonrpc: "2.0", id: answer.id, error: { code: -32000, message: words || "Brickworks did not answer." } };
  }
  return { jsonrpc: "2.0", id: answer.id, result: { contents: [{ uri, mimeType: "application/json",
    text: JSON.stringify(result.structuredContent) }] } };
}

// The tool as tools/list gives it, naming the viewer when it is one of its.
export function withViewer(tool) {
  if (!tool || !VIEWER_TOOLS.includes(tool.name)) return tool;
  const meta = tool._meta && typeof tool._meta === "object" ? tool._meta : {};
  const ui = meta.ui && typeof meta.ui === "object" ? meta.ui : {};
  return { ...tool, _meta: { ...meta, ui: { ...ui, resourceUri: VIEWER_URI }, "ui/resourceUri": VIEWER_URI } };
}

// Whether a client shows such pages: said in its capabilities at
// initialize, or, from protocol 2026-07-28, in every request's _meta.
export function showsApps(message) {
  const params = message && typeof message.params === "object" && message.params ? message.params : {};
  const said = message && message.method === "initialize" ? params.capabilities
    : params._meta && params._meta["io.modelcontextprotocol/clientCapabilities"];
  const ui = said && said.extensions && said.extensions[EXTENSION];
  return Boolean(ui && (!Array.isArray(ui.mimeTypes) || ui.mimeTypes.includes(VIEWER_MIME)));
}

// The session id handed out at initialize says which kind of client it was
// given to, so the relay, which keeps no connection, knows on every call
// after: 32 characters for one that does not show pages, "app" and 32 for
// one that does.
export function sessionFor(shows, random) {
  return shows ? `app${random}` : random;
}
export function sessionShows(session) {
  return typeof session === "string" && session.length === 35 && session.startsWith("app");
}

// Where the part geometry is served from (api/account.js's parts_url), as
// an origin: the one the page may fetch from.
export function partsOrigin(env = process.env) {
  const named = partsRoot(env);
  try {
    return named ? new URL(named).origin : "";
  } catch {
    return "";
  }
}

// Where the part geometry is, ending in "/": the deployment's PARTS_URL,
// else its Supabase bucket, else "" (a deployment serving its own).
export function partsRoot(env = process.env) {
  const named = env.PARTS_URL || (env.SUPABASE_URL ? `${env.SUPABASE_URL.replace(/\/+$/, "")}/storage/v1/object/public/parts/` : "");
  return named ? named.replace(/\/?$/, "/") : "";
}

// A tool's answer with each model scene in it (viewer_scene's
// structuredContent, a look's _meta["brickworks/view"].scene) reading its
// geometry from partsRoot: the one origin the page may fetch from. The tab
// learns where parts are only once its deployment answers; asked before
// that, under load, it said "next to the app", which the page's policy
// refuses, and every part went through the host instead (2026-10-15).
export function withPartsRoot(answer, env = process.env) {
  const root = partsRoot(env);
  const result = answer && answer.result;
  if (!root || !result || typeof result !== "object") return answer;
  const fix = (scene) => {
    if (scene && typeof scene === "object" && typeof scene.root === "string" && "step" in scene) scene.root = root;
  };
  fix(result.structuredContent);
  const view = result._meta && result._meta["brickworks/view"];
  if (view && typeof view === "object") fix(view.scene);
  return answer;
}

function resourceMeta() {
  const origin = partsOrigin();
  return {
    ui: {
      // The geometry, fetched; the page itself, three.js and all, is inline.
      csp: { connectDomains: origin ? [origin] : [], resourceDomains: [] },
      // The page draws its own card.
      prefersBorder: false,
    },
  };
}

export function viewerListed() {
  return {
    uri: VIEWER_URI,
    name: "model",
    title: "The model",
    description: "The Brickworks model as it now stands, in 3D: turn it, pick a part, check it, step through "
      + "its instructions and its parts list.",
    mimeType: VIEWER_MIME,
    _meta: resourceMeta(),
  };
}

// resources/read's answer, or null for an address that is not the viewer's.
export function viewerRead(uri) {
  if (uri !== VIEWER_URI) return null;
  return { contents: [{ uri: VIEWER_URI, mimeType: VIEWER_MIME, text: VIEWER_HTML, _meta: resourceMeta() }] };
}
