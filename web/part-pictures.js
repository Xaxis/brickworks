// Each lot's picture in a model's Parts list (site304): the part itself, in
// its colour, drawn on the page from the geometry the app draws it from.
//
// A builder scans a parts list by picture, not by name. Until rel-m180 the
// list showed Rebrickable's photos, which had every visitor's browser ask a
// third party for each part; then only a swatch. Pictures made ahead of
// time are out (src/ui/part_thumbnails.gd: 24,731 parts in 322 colours), and
// so is a sheet a publish renders, which every model shared before it would
// lack. What every model's page already has is each part's geometry: content
// named (api/_parts.js gives each lot its mesh), immutable, a year in the
// browser's cache, in the store the app and the viewer fetch it from. So a
// lot is drawn here, as the app's parts bin draws one: a small square,
// orthographic, from the bin's own corner (PartThumbnails._frame), lit by a
// key and a fill as its lights are, each surface in its own colour and
// colour 16 in the lot's. The page's policy needs nothing new for pictures:
// they are drawn on a canvas, not loaded as images, and the store is where
// the page already signs in.
//
// What is drawn, and when, is what is in sight. A row's picture starts as
// its colour's swatch; a row that comes within reach of the screen asks for
// its part's geometry (a few at a time), and a picture is drawn in a frame
// of its own budget, so the list is drawn and scrolls as it did and the
// pictures come in over it. One drawn is kept for the page's life, by part
// and colour, so grouping by Kind and back draws nothing again. A part with
// no geometry (one the file carries), a fetch that fails or a browser with
// no WebGL keeps its swatch: <span class="pic" data-picture="none">. One
// drawn is <span class="pic" data-picture="drawn"><canvas>.
import { INHERIT, parseLbm } from "/lbm.js";

/// The picture's size on the page, as .lot-list .pic in directory.css.
const SHOWN = 48;
/// It is drawn at twice the pixels it is shown at and scaled down, so its
/// lines are half a pixel's weight and every edge smooth.
const OVER = 2;
/// How many parts' geometry is asked for at once.
const AT_ONCE = 6;
/// How long a frame may spend drawing pictures before the rest wait for the
/// next: a list scrolled while they come must not stutter.
const FRAME_MS = 8;
/// How many parts' geometry is kept on the graphics card; a part asked for
/// again after that comes from the browser's cache.
const KEPT = 32;

const unit = (v) => {
  const n = Math.hypot(...v) || 1;
  return v.map((x) => x / n);
};
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
/// Where the camera looks from (PartThumbnails._frame), and the picture's
/// right and up as it sees them.
const EYE = unit([0.72, 0.52, 0.86]);
const RIGHT = unit(cross([-EYE[0], -EYE[1], -EYE[2]], [0, 1, 0]));
const UP = cross(RIGHT, [-EYE[0], -EYE[1], -EYE[2]]);
/// Towards the bin's key and fill lights: DirectionalLight3D turned
/// (-42, -38) and (-14, 132) degrees shine along their -Z.
const towards = (x, y) => {
  const [a, b] = [x * Math.PI / 180, y * Math.PI / 180];
  return unit([Math.sin(b) * Math.cos(a), -Math.sin(a), Math.cos(b) * Math.cos(a)]);
};
const KEY = towards(-42, -38);
const FILL = towards(-14, 132);

const VERTEX = `
attribute vec3 position;
attribute vec3 normal;
uniform mat4 view;
varying vec3 facing;
void main() {
  facing = normal;
  gl_Position = view * vec4(position, 1.0);
}`;
// Its lines, as LDraw draws a part's edges and a builder knows them from
// the instructions: first where every pixel faces and how near it is
// (FACTS, into a texture: the normal across and up the picture in red and
// green, the depth in blue and alpha, none where there is no part), then a
// line wherever that turns (LINES): its outline, a fold between two faces,
// a step from one face to another behind it.
const FACTS = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform vec3 right;
uniform vec3 up;
varying vec3 facing;
void main() {
  vec3 n = normalize(facing);
  if (!gl_FrontFacing) n = -n;
  float near = 0.02 + 0.98 * (1.0 - gl_FragCoord.z);
  float high = floor(near * 255.0) / 255.0;
  gl_FragColor = vec4(dot(n, right) * 0.5 + 0.5, dot(n, up) * 0.5 + 0.5, high, (near - high) * 255.0);
}`;
const FLAT = `
attribute vec2 position;
varying vec2 at;
void main() {
  at = position * 0.5 + 0.5;
  gl_Position = vec4(position, 0.0, 1.0);
}`;
const LINES = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform sampler2D facts;
uniform vec2 texel;
uniform vec4 pen;
varying vec2 at;
vec3 read(vec2 p) {
  vec4 t = texture2D(facts, p);
  return vec3(t.rg * 2.0 - 1.0, t.b + t.a / 255.0);
}
void main() {
  vec3 c = read(at);
  vec3 l = read(at - vec2(texel.x, 0.0));
  vec3 r = read(at + vec2(texel.x, 0.0));
  vec3 d = read(at - vec2(0.0, texel.y));
  vec3 u = read(at + vec2(0.0, texel.y));
  bool here = c.z > 0.0;
  float line = 0.0;
  if (here != (l.z > 0.0) || here != (r.z > 0.0) || here != (u.z > 0.0) || here != (d.z > 0.0)) line = 1.0;
  else if (here) {
    float fold = max(max(distance(c.xy, l.xy), distance(c.xy, r.xy)), max(distance(c.xy, u.xy), distance(c.xy, d.xy)));
    float step = max(abs(l.z + r.z - 2.0 * c.z), abs(u.z + d.z - 2.0 * c.z));
    line = max(smoothstep(0.22, 0.5, fold), smoothstep(0.004, 0.012, step));
  }
  gl_FragColor = pen * line;
}`;
// Lit as the bin lights a part: the face towards the key light in the
// part's own colour, the others a step and two darker, so a brick's top,
// front and side part. A dark part's lit faces are lifted a little and a
// light one's dimmed, as PartThumbnails._light_for tames its lights, or
// black and white would each be one flat shape.
const FRAGMENT = `
precision mediump float;
uniform vec4 ink;
uniform vec3 key;
uniform vec3 fill;
uniform vec3 eye;
varying vec3 facing;
void main() {
  vec3 n = normalize(facing);
  if (!gl_FrontFacing) n = -n;
  float bright = dot(ink.rgb, vec3(0.2126, 0.7152, 0.0722));
  float tame = 1.0 - 0.3 * clamp((bright - 0.6) / 0.4, 0.0, 1.0);
  float k = max(dot(n, key), 0.0);
  float f = max(dot(n, fill), 0.0);
  vec3 lit = ink.rgb * (0.58 + tame * (0.62 * k + 0.3 * f));
  lit += (1.0 - bright) * 0.16 * k;
  float shine = pow(max(dot(n, normalize(key + eye)), 0.0), 48.0) * 0.22;
  gl_FragColor = vec4(min(lit + shine, 1.0) * ink.a, ink.a);
}`;

/// A colour as the page was given it, "rrggbb" or "rrggbbaa", as [r, g, b, a]
/// from 0 to 1; null for anything else.
function inkOf(hex) {
  if (!/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(String(hex || ""))) return null;
  const at = (i) => parseInt(hex.slice(i, i + 2), 16) / 255;
  // You can see through it, and see it: never less than two thirds there.
  return [at(0), at(2), at(4), hex.length === 8 ? Math.max(at(6), 0.66) : 1];
}

/// The lines' colour on a part of colour [ink], premultiplied, as LDraw's
/// edge colours go: grey on black and the darkest colours, a dark shade of
/// the colour on the rest.
function penOf(ink) {
  const bright = 0.2126 * ink[0] + 0.7152 * ink[1] + 0.0722 * ink[2];
  const line = bright < 0.12 ? [0.5, 0.5, 0.5] : ink.slice(0, 3).map((c) => c * 0.4);
  const alpha = 0.9;
  return [...line.map((c) => c * alpha), alpha];
}

/// What draws the list's pictures: geometry from [root] (the store, ending
/// in "/"), a surface's own colour from [colours] ({code: hex}). Null where
/// there is no store to draw from.
export function partPictures(root, colours = {}) {
  if (typeof root !== "string" || !/^(https?:)?\//.test(root)) return null;
  const ratio = Math.min(Math.max(window.devicePixelRatio || 1, 1), 3);
  const px = Math.round(SHOWN * ratio);
  const size = px * OVER;
  const drawn = new Map();      // part:colour -> its canvas
  const jobs = new Map();       // part:colour -> {lot, pics, started}, to be drawn
  const geometry = new Map();   // hash -> Promise of its buffers on the card
  const queue = [];             // keys of rows in reach whose geometry is not asked for yet
  const ready = [];             // [key, part] whose geometry is here, to be drawn
  const wanted = new WeakMap(); // pic -> lot, until its geometry is asked for
  let fetching = 0;
  let framed = false;
  let gl = null;
  let broken = false;
  let shaded = null;            // the programs: the part lit, its facts, its lines
  let facts = null;
  let lines = null;
  let factsTarget = null;       // where its facts are drawn: a texture and a depth
  let corners = null;           // a triangle over the whole picture, for its lines

  // A row in reach of the screen is queued, and one scrolled past before
  // its turn came is taken off again: what is asked for is what is in sight.
  const near = "IntersectionObserver" in window ? new IntersectionObserver((seen) => {
    for (const one of seen) {
      const lot = wanted.get(one.target);
      if (!lot) continue;
      if (one.isIntersecting) ask(one.target, lot);
      else withdraw(one.target, lot);
    }
  }, { rootMargin: "300px 0px" }) : null;

  const giveUp = (pic) => { pic.dataset.picture = "none"; };
  const place = (pic, canvas) => {
    pic.replaceChildren(canvas);
    pic.dataset.picture = "drawn";
  };

  function context() {
    if (gl || broken) return gl;
    const canvas = document.createElement("canvas");
    canvas.width = size;
    canvas.height = size;
    canvas.addEventListener("webglcontextlost", () => {
      broken = true;
      gl = null;
      for (const job of jobs.values()) job.pics.forEach(giveUp);
      jobs.clear();
    });
    const made = canvas.getContext("webgl", { antialias: false, alpha: true, premultipliedAlpha: true, depth: true,
      preserveDrawingBuffer: false, powerPreference: "low-power" });
    if (!made) {
      broken = true;
      return null;
    }
    const shader = (kind, text) => {
      const one = made.createShader(kind);
      made.shaderSource(one, text);
      made.compileShader(one);
      return one;
    };
    const link = (vertex, fragment) => {
      const one = made.createProgram();
      made.attachShader(one, shader(made.VERTEX_SHADER, vertex));
      made.attachShader(one, shader(made.FRAGMENT_SHADER, fragment));
      made.bindAttribLocation(one, 0, "position");
      made.bindAttribLocation(one, 1, "normal");
      made.linkProgram(one);
      if (!made.getProgramParameter(one, made.LINK_STATUS)) throw new Error(made.getProgramInfoLog(one) || "no program");
      const named = { program: one };
      for (let i = 0; i < made.getProgramParameter(one, made.ACTIVE_UNIFORMS); i++) {
        const { name } = made.getActiveUniform(one, i);
        named[name] = made.getUniformLocation(one, name);
      }
      return named;
    };
    try {
      shaded = link(VERTEX, FRAGMENT);
      facts = link(VERTEX, FACTS);
      lines = link(FLAT, LINES);
    } catch {
      broken = true;
      return null;
    }
    made.getExtension("OES_element_index_uint");
    made.useProgram(shaded.program);
    made.uniform3fv(shaded.key, KEY);
    made.uniform3fv(shaded.fill, FILL);
    made.uniform3fv(shaded.eye, EYE);
    made.useProgram(facts.program);
    made.uniform3fv(facts.right, RIGHT);
    made.uniform3fv(facts.up, UP);
    made.useProgram(lines.program);
    made.uniform2f(lines.texel, 1 / size, 1 / size);
    made.uniform1i(lines.facts, 0);
    // The facts' texture, and a depth for drawing into it.
    const texture = made.createTexture();
    made.bindTexture(made.TEXTURE_2D, texture);
    made.texImage2D(made.TEXTURE_2D, 0, made.RGBA, size, size, 0, made.RGBA, made.UNSIGNED_BYTE, null);
    for (const [name, value] of [[made.TEXTURE_MIN_FILTER, made.NEAREST], [made.TEXTURE_MAG_FILTER, made.NEAREST],
      [made.TEXTURE_WRAP_S, made.CLAMP_TO_EDGE], [made.TEXTURE_WRAP_T, made.CLAMP_TO_EDGE]]) {
      made.texParameteri(made.TEXTURE_2D, name, value);
    }
    const depth = made.createRenderbuffer();
    made.bindRenderbuffer(made.RENDERBUFFER, depth);
    made.renderbufferStorage(made.RENDERBUFFER, made.DEPTH_COMPONENT16, size, size);
    factsTarget = made.createFramebuffer();
    made.bindFramebuffer(made.FRAMEBUFFER, factsTarget);
    made.framebufferTexture2D(made.FRAMEBUFFER, made.COLOR_ATTACHMENT0, made.TEXTURE_2D, texture, 0);
    made.framebufferRenderbuffer(made.FRAMEBUFFER, made.DEPTH_ATTACHMENT, made.RENDERBUFFER, depth);
    const whole = made.checkFramebufferStatus(made.FRAMEBUFFER) === made.FRAMEBUFFER_COMPLETE;
    made.bindFramebuffer(made.FRAMEBUFFER, null);
    if (!whole) {
      broken = true;
      return null;
    }
    corners = made.createBuffer();
    made.bindBuffer(made.ARRAY_BUFFER, corners);
    made.bufferData(made.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), made.STATIC_DRAW);
    made.enableVertexAttribArray(0);
    made.blendFunc(made.ONE, made.ONE_MINUS_SRC_ALPHA);
    made.viewport(0, 0, size, size);
    made.clearColor(0, 0, 0, 0);
    gl = made;
    return gl;
  }

  /// A part's geometry on the card, and how it is framed: fetched once,
  /// the least recently drawn let go past KEPT.
  function geometryOf(hash) {
    if (geometry.has(hash)) {
      const kept = geometry.get(hash);
      geometry.delete(hash);
      geometry.set(hash, kept);
      return kept;
    }
    const coming = fetch(`${root}${hash}.lbm`, { cache: "force-cache", credentials: "omit" })
      .then((answer) => {
        if (!answer.ok) throw new Error(`geometry ${answer.status}`);
        return answer.arrayBuffer();
      })
      .then((bytes) => upload(parseLbm(bytes)));
    coming.catch(() => geometry.delete(hash));
    geometry.set(hash, coming);
    return coming;
  }

  /// The least recently drawn parts let go, past KEPT: never one still to
  /// be drawn.
  function trim() {
    const needed = new Set([...jobs.values()].map((job) => job.lot.mesh));
    for (const [hash, going] of geometry) {
      if (geometry.size <= KEPT) break;
      if (needed.has(hash)) continue;
      geometry.delete(hash);
      going.then((one) => one.surfaces.forEach((s) => s.buffers.forEach((b) => gl && gl.deleteBuffer(b))), () => {});
    }
  }

  function upload(part) {
    const gl = context();
    if (!gl) throw new Error("no WebGL");
    // Framed tight round the part as the camera sees it, a little room left.
    const lo = [Infinity, Infinity, Infinity];
    const hi = [-Infinity, -Infinity, -Infinity];
    const surfaces = [];
    for (const surface of part.surfaces) {
      const p = surface.position;
      if (!surface.index.length) continue;
      if (surface.index instanceof Uint32Array && !gl.getExtension("OES_element_index_uint")) throw new Error("too big");
      for (let v = 0; v < p.length; v += 3) {
        const at = [p[v], p[v + 1], p[v + 2]];
        const seen = [dot(at, RIGHT), dot(at, UP), dot(at, EYE)];
        for (let k = 0; k < 3; k++) {
          if (seen[k] < lo[k]) lo[k] = seen[k];
          if (seen[k] > hi[k]) hi[k] = seen[k];
        }
      }
      const buffer = (target, data) => {
        const one = gl.createBuffer();
        gl.bindBuffer(target, one);
        gl.bufferData(target, data, gl.STATIC_DRAW);
        return one;
      };
      surfaces.push({ colour: surface.colour, twoSided: surface.twoSided, count: surface.index.length,
        wide: surface.index instanceof Uint32Array,
        buffers: [buffer(gl.ARRAY_BUFFER, surface.position), buffer(gl.ARRAY_BUFFER, surface.normal),
          buffer(gl.ELEMENT_ARRAY_BUFFER, surface.index)] });
    }
    if (!surfaces.length) throw new Error("nothing to draw");
    const half = Math.max(hi[0] - lo[0], hi[1] - lo[1], 1) * 0.5 * 1.08;
    const deep = Math.max(hi[2] - lo[2], 1) * 0.5 * 1.02;
    const mid = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2];
    // Column by column: x along RIGHT, y along UP, nearer the eye less deep.
    const view = new Float32Array([
      RIGHT[0] / half, UP[0] / half, -EYE[0] / deep, 0,
      RIGHT[1] / half, UP[1] / half, -EYE[1] / deep, 0,
      RIGHT[2] / half, UP[2] / half, -EYE[2] / deep, 0,
      -mid[0] / half, -mid[1] / half, mid[2] / deep, 1,
    ]);
    return { surfaces, view };
  }

  /// Each surface of [part] drawn by [using] (a program with a view), its
  /// colour, where it takes one, [inks][s]; [through]: only those you can
  /// see through, else only those you cannot, or (null) all.
  function surfaces(part, using, inks, through) {
    gl.useProgram(using.program);
    gl.uniformMatrix4fv(using.view, false, part.view);
    gl.enableVertexAttribArray(1);
    for (let s = 0; s < part.surfaces.length; s++) {
      const surface = part.surfaces[s];
      if (through !== null && (inks[s][3] < 1) !== through) continue;
      if (using.ink) gl.uniform4fv(using.ink, inks[s]);
      gl.bindBuffer(gl.ARRAY_BUFFER, surface.buffers[0]);
      gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0);
      gl.bindBuffer(gl.ARRAY_BUFFER, surface.buffers[1]);
      gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 0, 0);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, surface.buffers[2]);
      const type = surface.wide ? gl.UNSIGNED_INT : gl.UNSIGNED_SHORT;
      if (through) {
        gl.enable(gl.BLEND);
        gl.depthMask(false);
        gl.enable(gl.CULL_FACE);
        for (const side of [gl.FRONT, gl.BACK]) {
          gl.cullFace(side);
          gl.drawElements(gl.TRIANGLES, surface.count, type, 0);
        }
        gl.disable(gl.BLEND);
        gl.depthMask(true);
      } else {
        if (surface.twoSided) gl.disable(gl.CULL_FACE);
        else {
          gl.enable(gl.CULL_FACE);
          gl.cullFace(gl.BACK);
        }
        gl.drawElements(gl.TRIANGLES, surface.count, type, 0);
      }
    }
    gl.disableVertexAttribArray(1);
  }

  /// One lot drawn on the card and copied into a canvas of its own.
  function paint(part, lot) {
    const own = inkOf(colours[lot.colour]) || inkOf(lot.hex) || [0.6, 0.6, 0.6, 1];
    const inks = part.surfaces.map((s) => (s.colour === INHERIT ? own : inkOf(colours[s.colour]) || own));
    gl.enable(gl.DEPTH_TEST);
    // Where each pixel faces and how near it is, every surface alike.
    gl.bindFramebuffer(gl.FRAMEBUFFER, factsTarget);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    surfaces(part, facts, inks, null);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    // The part lit: what you cannot see through first, then what you can,
    // its far side before its near, over it.
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    surfaces(part, shaded, inks, false);
    surfaces(part, shaded, inks, true);
    // Its lines over it.
    gl.disable(gl.DEPTH_TEST);
    gl.disable(gl.CULL_FACE);
    gl.enable(gl.BLEND);
    gl.useProgram(lines.program);
    gl.uniform4fv(lines.pen, penOf(own));
    gl.bindBuffer(gl.ARRAY_BUFFER, corners);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    gl.disable(gl.BLEND);
    const canvas = document.createElement("canvas");
    canvas.width = px;
    canvas.height = px;
    canvas.setAttribute("aria-hidden", "true");
    const pen = canvas.getContext("2d");
    pen.imageSmoothingQuality = "high";
    pen.drawImage(gl.canvas, 0, 0, px, px);
    return canvas;
  }

  /// A row's picture, once it nears the screen: its geometry asked for, in
  /// turn, and drawn once it is here.
  function ask(pic, lot) {
    const key = `${lot.mesh}:${lot.colour}`;
    if (drawn.has(key)) {
      settle(pic);
      return place(pic, drawn.get(key));
    }
    if (broken) {
      settle(pic);
      return giveUp(pic);
    }
    const job = jobs.get(key);
    if (job) {
      job.pics.add(pic);
      return;
    }
    jobs.set(key, { lot, pics: new Set([pic]), started: false });
    queue.push(key);
    pump();
  }

  /// A row gone out of reach before its part was asked for.
  function withdraw(pic, lot) {
    const key = `${lot.mesh}:${lot.colour}`;
    const job = jobs.get(key);
    if (!job || job.started) return;
    job.pics.delete(pic);
    if (job.pics.size) return;
    jobs.delete(key);
    queue.splice(queue.indexOf(key), 1);
  }

  /// A row whose picture is under way, or done: no longer watched.
  function settle(pic) {
    wanted.delete(pic);
    near?.unobserve(pic);
  }

  function pump() {
    while (fetching < AT_ONCE && queue.length) {
      const key = queue.shift();
      const job = jobs.get(key);
      if (!job) continue;
      job.started = true;
      job.pics.forEach(settle);
      fetching += 1;
      geometryOf(job.lot.mesh).then((part) => {
        ready.push([key, part]);
        frame();
      }, () => {
        jobs.get(key)?.pics.forEach(giveUp);
        jobs.delete(key);
      }).finally(() => {
        fetching -= 1;
        pump();
      });
    }
  }

  function frame() {
    if (framed) return;
    framed = true;
    requestAnimationFrame(() => {
      framed = false;
      const started = performance.now();
      while (ready.length && !broken && performance.now() - started < FRAME_MS) {
        const [key, part] = ready.shift();
        const job = jobs.get(key);
        jobs.delete(key);
        if (!job) continue;
        let canvas = null;
        try {
          canvas = paint(part, job.lot);
        } catch {
          canvas = null;
        }
        if (!canvas) {
          job.pics.forEach(giveUp);
          continue;
        }
        drawn.set(key, canvas);
        // The row on the page now (a regrouped list makes its rows again).
        const shown = [...job.pics].find((pic) => pic.isConnected) || [...job.pics][0];
        place(shown, canvas);
      }
      trim();
      if (ready.length) frame();
    });
  }

  return {
    /// [pic] (a row's .pic, its swatch in it) is to show [lot]'s part.
    want(pic, lot) {
      if (!lot || !/^[0-9a-f]{8,64}$/.test(String(lot.mesh || ""))) return giveUp(pic);
      const key = `${lot.mesh}:${lot.colour}`;
      if (drawn.has(key)) return place(pic, drawn.get(key));
      if (broken) return giveUp(pic);
      if (!near) return ask(pic, lot);
      wanted.set(pic, lot);
      near.observe(pic);
    },
    /// The rows asked for so far are gone (the list drawn again): none of
    /// them watched any more, nor waiting its turn. A picture under way is
    /// still drawn and kept, for the row that shows its lot now.
    forget() {
      near?.disconnect();
      queue.length = 0;
      for (const [key, job] of jobs) if (!job.started) jobs.delete(key);
    },
  };
}
