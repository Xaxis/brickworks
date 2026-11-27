// The page's tracer (src/render/page_tracer.js) on a set the desktop traced
// (photoreal28): photoreal_probe --pt-capture=DIR writes, for each shot, what
// PathTracer gave the card; this hands the same to the page's tracer.
//
//   node tools/web/tracer_bench.mjs pack CAPTURE OUT
//       the set's textures as page_tracer.js packs them (its own trees), into OUT/
//       (each as raw bytes, and pack.json), for a runner off the browser
//   node tools/web/tracer_bench.mjs page CAPTURE OUT.png [--samples=N] [--draw=D] [--width=W]
//       [--seconds=S] [--js=tracer.js]
//       the picture traced in Chromium (SwiftShader, as every browser check here), by
//       page_tracer.js through its own bridge, as the app drives it: the whole picture at
//       first, then the progressive passes with their fences, timed per sample; OUT.json says
//       what it took
//
// CAPTURE is one shot's folder: instances.bin, transforms.bin, meshes.bin, positions.bin,
// normals.bin, indices.bin, scene.bin, surface.bin, picture.json, and ../places/<md5>.bin.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { deflateSync } from "node:zlib";
import { launch } from "./browser.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(here, "../..");

function arg(name, fallback) {
	const found = process.argv.find((a) => a.startsWith(`--${name}=`));
	return found ? found.slice(name.length + 3) : fallback;
}

function f32(path) {
	const b = readFileSync(path);
	return new Float32Array(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength));
}

function u32(path) {
	const b = readFileSync(path);
	return new Uint32Array(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength));
}

// The capture read back: its shapes split out, each instance's shape, and the rest as it is.
export function readCapture(dir) {
	const said = JSON.parse(readFileSync(join(dir, "picture.json"), "utf8"));
	const meshes = u32(join(dir, "meshes.bin"));
	const points = f32(join(dir, "positions.bin"));
	const normals = f32(join(dir, "normals.bin"));
	const indices = u32(join(dir, "indices.bin"));
	const shapes = [];
	const count = meshes.length / 4;
	for (let k = 0; k < count; k++) {
		const v0 = meshes[4 * k], i0 = meshes[4 * k + 1];
		const v1 = k + 1 < count ? meshes[4 * (k + 1)] : points.length / 3;
		const i1 = k + 1 < count ? meshes[4 * (k + 1) + 1] : indices.length;
		shapes.push({
			points: points.slice(v0 * 3, v1 * 3),
			normals: normals.slice(v0 * 3, v1 * 3),
			indices: indices.slice(i0, i1),
		});
	}
	const records = readFileSync(join(dir, "instances.bin"));
	const view = new DataView(records.buffer, records.byteOffset, records.byteLength);
	const which = [];
	for (let n = 0; n < records.byteLength / 80; n++) which.push(view.getUint32(n * 80 + 64, true));
	const places = f32(join(dir, "transforms.bin"));
	const placeDir = join(dir, "..", "places");
	const place = said.place ? f32(join(placeDir, said.place + ".bin")) : new Float32Array([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]);
	const table = said.place ? f32(join(placeDir, said.place + ".table.bin")) : new Float32Array(1);
	const placeSize = said.place ? said.place_size : [2, 2];
	return {
		said, shapes, which, places, place, table, placeSize,
		records: new Uint8Array(records.buffer.slice(records.byteOffset, records.byteOffset + records.byteLength)),
		scene: f32(join(dir, "scene.bin")),
		surface: existsSync(join(dir, "surface.bin")) ? new Uint8Array(readFileSync(join(dir, "surface.bin"))) : new Uint8Array(0),
	};
}

async function packMode(capture, out) {
	const { pack, shapeTree, half } = await import(pathToFileURL(join(ROOT, "src/render/page_tracer.js")).href);
	const c = readCapture(capture);
	const began = performance.now();
	const shapes = c.shapes.map((s) => ({ ...s, tree: shapeTree(s.points, s.indices) }));
	const trees = performance.now() - began;
	const packed = pack(shapes, c.records, c.places, c.which);
	const took = performance.now() - began;
	mkdirSync(out, { recursive: true });
	const put = (name, array) => writeFileSync(join(out, name + ".bin"), Buffer.from(array.buffer, array.byteOffset, array.byteLength));
	for (const name of ["nodes", "tris", "points", "normals", "indices", "meshes", "records", "info", "places"]) put(name, packed[name]);
	const halves = new Uint16Array(c.place.length);
	for (let i = 0; i < c.place.length; i++) halves[i] = half(c.place[i]);
	put("place", halves);
	put("table", c.table);
	put("scene", c.scene);
	put("surface", c.surface);
	writeFileSync(join(out, "pack.json"), JSON.stringify({
		top: packed.top, counts: packed.counts, said: c.said, place_size: c.placeSize,
		trees_ms: Math.round(trees), pack_ms: Math.round(took),
	}, null, 1));
	console.log(`pack: ${capture} -> ${out}: ${packed.counts.instances} instances, ${packed.counts.triangles} triangles, ` +
		`${packed.counts.nodes} nodes, trees ${trees.toFixed(0)} ms, all ${took.toFixed(0)} ms`);
}

async function pageMode(capture, outPng) {
	const js = arg("js", "");
	if (!js || !existsSync(js)) throw new Error("--js=tracer.js (tools/web/tracer_port.py --js) is wanted");
	const c = readCapture(capture);
	const samples = Number(arg("samples", String(c.said.samples || 256)));
	const draw = Number(arg("draw", "0"));
	const seconds = Number(arg("seconds", "0"));
	const width = Number(arg("width", "0"));
	// browser.mjs's launch: SwiftShader as every check here, and its storage mirror (test_storage_mirror).
	const browser = await launch({ signedOut: true, args: ["--ignore-gpu-blocklist"] });
	const page = await browser.newPage();
	const logs = [];
	page.on("console", (m) => logs.push(m.text()));
	page.on("pageerror", (e) => logs.push("pageerror: " + e.message));
	await page.setContent("<html><body></body></html>");
	await page.addScriptTag({ type: "module", content: readFileSync(js, "utf8").replace(/^export /gm, "") + "\nwindow.__tracerModule = { start, can, Tracer, pack, shapeTree };" });
	await page.waitForFunction(() => !!window.__tracerModule, null, { timeout: 60000 });
	const b64 = (a) => Buffer.from(a.buffer, a.byteOffset, a.byteLength).toString("base64");
	const version = c.said.version;
	const result = await page.evaluate(async (given) => {
		const m = window.__tracerModule;
		const can = m.can();
		const t = m.start();
		const marks = {};
		const began = performance.now();
		let state = "";
		while ((state = t.state(given.version)) === "compiling") await new Promise((r) => setTimeout(r, 50));
		marks.compile_ms = performance.now() - began;
		if (state !== "ready") return { can, state, marks };
		const s0 = performance.now();
		given.shapes.forEach((s, k) => t.shape(k, s.points, s.normals, s.indices));
		marks.trees_ms = performance.now() - s0;
		const keys = given.shapes.map((_, k) => k).join(",");
		const staged = t.stage(keys, given.records, given.places, given.which.join(","));
		if (!staged) return { can, state: "stage: " + t.problem(), marks };
		t.tracer.place(given.placeSize[0], given.placeSize[1], given.place, given.table, false);
		t.surface(given.surfaceSize[0], given.surfaceSize[1], given.surface);
		const [w, h] = given.size;
		if (!t.begin(w, h, given.scene, given.version)) return { can, state: "begin: " + t.problem(), marks };
		const gl = t.tracer.gl;
		const fence = () => new Promise((done) => {
			const f = gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0);
			gl.flush();
			const poll = () => (gl.getSyncParameter(f, gl.SYNC_STATUS) === gl.SIGNALED ? (gl.deleteSync(f), done()) : setTimeout(poll, 5));
			poll();
		});
		// The progressive passes, as the app gives them: one a frame, each only once the last is done.
		const t0 = performance.now();
		const gaps = [];
		let last = t0;
		let firstSampleMs = -1;
		while (t.tracer.samples < given.samples) {
			const before = t.tracer.samples;
			t.trace(Math.min(32, given.samples - t.tracer.samples), given.seed, false);
			await new Promise((r) => requestAnimationFrame(r));
			const now = performance.now();
			gaps.push(now - last);
			last = now;
			if (before === 0 && t.tracer.samples > 0) {
				await fence();
				firstSampleMs = performance.now() - t0;
			}
			if (given.seconds > 0 && now - t0 > given.seconds * 1000) break;
		}
		await fence();
		marks.trace_ms = performance.now() - t0;
		marks.first_sample_ms = firstSampleMs;
		marks.samples = t.tracer.samples;
		gaps.sort((a, b) => a - b);
		marks.frame_gap_median_ms = gaps[Math.floor(gaps.length / 2)] || 0;
		marks.frame_gap_p95_ms = gaps[Math.floor(gaps.length * 0.95)] || 0;
		marks.frame_gap_max_ms = gaps[gaps.length - 1] || 0;
		marks.passes = t.tracer.passes;
		const pixels = t.picture(new Float32Array(given.resolve.map((v, i) => (i === 0 ? t.tracer.samples : v))));
		let bin = "";
		for (let i = 0; i < pixels.length; i += 8192) bin += String.fromCharCode.apply(null, pixels.subarray(i, i + 8192));
		return { can, state, marks, stats: JSON.parse(t.stats()), pixels: btoa(bin), size: [w, h] };
	}, {
		version, samples, seed: draw ? 104729 * draw : c.said.seed, seconds,
		shapes: c.shapes.map((s) => ({ points: b64(s.points), normals: b64(s.normals), indices: b64(s.indices) })),
		records: b64(c.records), places: b64(c.places), which: c.which,
		place: b64(c.place), table: b64(c.table), placeSize: c.placeSize,
		surface: b64(c.surface), surfaceSize: c.said.surface_size,
		scene: b64(width ? rescaled(c.scene, c.said.size, width) : c.scene),
		size: width ? [width, Math.round(c.said.size[1] * width / c.said.size[0])] : c.said.size,
		resolve: c.said.resolve,
	});
	await browser.close();
	if (!result.pixels) {
		console.log("page: " + JSON.stringify({ ...result, logs: logs.slice(-20) }));
		process.exit(1);
	}
	const [w, h] = result.size;
	writeFileSync(outPng, png(w, h, new Uint8Array(Buffer.from(result.pixels, "base64"))));
	delete result.pixels;
	writeFileSync(outPng.replace(/\.png$/, ".json"), JSON.stringify({ ...result, logs: logs.slice(-20) }, null, 1));
	console.log(`page: ${outPng} ${w}x${h} ${JSON.stringify(result.marks)}`);
}

// The scene for a picture [width] wide instead: only its size changes (Scene.size, the fifth vec4).
function rescaled(scene, size, width) {
	const out = scene.slice();
	out[16] = width;
	out[17] = Math.round(size[1] * width / size[0]);
	return out;
}

// An RGBA picture as a PNG (8 bits a channel), top row first.
const CRC = Array.from({ length: 256 }, (_, n) => {
	let c = n;
	for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
	return c >>> 0;
});

function crc32(bytes) {
	let c = 0xffffffff;
	for (const b of bytes) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
	return (c ^ 0xffffffff) >>> 0;
}

export function png(width, height, rgba) {
	const chunk = (type, data) => {
		const out = Buffer.alloc(12 + data.length);
		out.writeUInt32BE(data.length, 0);
		out.write(type, 4, "ascii");
		data.copy(out, 8);
		out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
		return out;
	};
	const head = Buffer.alloc(13);
	head.writeUInt32BE(width, 0);
	head.writeUInt32BE(height, 4);
	head[8] = 8;
	head[9] = 6;
	const rows = Buffer.alloc((width * 4 + 1) * height);
	for (let y = 0; y < height; y++) {
		rows[y * (width * 4 + 1)] = 0;
		Buffer.from(rgba.buffer, rgba.byteOffset + y * width * 4, width * 4).copy(rows, y * (width * 4 + 1) + 1);
	}
	return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", head),
		chunk("IDAT", deflateSync(rows)), chunk("IEND", Buffer.alloc(0))]);
}

const [mode, capture, out] = process.argv.slice(2);
if (mode === "pack") await packMode(capture, out);
else if (mode === "page") await pageMode(capture, out);
else {
	console.log("usage: node tools/web/tracer_bench.mjs pack CAPTURE OUT | page CAPTURE OUT.png [--js=..]");
	process.exit(2);
}
