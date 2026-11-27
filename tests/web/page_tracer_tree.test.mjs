// page_tracer.js's trees (photoreal28): rays walked through pack()'s textures the way
// tracer_port.py's trace() walks them find the same nearest triangle as testing every
// triangle of every instance, for shapes turned, mirrored and placed apart.
// node --test tests/web/page_tracer_tree.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { pack, shapeTree, tree, half } from "../../src/render/page_tracer.js";

function rng(seed) {
	let s = seed >>> 0;
	return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}

function soup(r, count) {
	const points = new Float32Array(count * 9);
	for (let t = 0; t < count; t++) {
		const cx = r() * 40 - 20, cy = r() * 40 - 20, cz = r() * 40 - 20;
		for (let k = 0; k < 3; k++) {
			points[t * 9 + k * 3] = cx + r() * 6 - 3;
			points[t * 9 + k * 3 + 1] = cy + r() * 6 - 3;
			points[t * 9 + k * 3 + 2] = cz + r() * 6 - 3;
		}
	}
	const indices = new Uint32Array(count * 3).map((_, i) => i);
	return { points, normals: new Float32Array(points.length), indices };
}

// The walk, as tracer_port.py's TRACE does it, over the packed arrays.
function walk(p, from, way, mask) {
	const node = (i) => p.nodes.subarray(i * 8, i * 8 + 8);
	const inv = way.map((d) => (Math.abs(d) > 1e-20 ? 1 / d : 1e20));
	let best = 1e7, found = -1, prim = -1;
	const slab = (n, o, iv, far) => {
		let enter = 0, leave = far;
		for (let k = 0; k < 3; k++) {
			const t0 = (n[k] - o[k]) * iv[k], t1 = (n[4 + k] - o[k]) * iv[k];
			enter = Math.max(enter, Math.min(t0, t1));
			leave = Math.min(leave, Math.max(t0, t1));
		}
		return enter <= leave;
	};
	const stack = [p.top];
	while (stack.length) {
		const n = node(stack.pop());
		if (!slab(n, from, inv, best)) continue;
		if (n[7] > 0) {
			const which = n[3];
			const r = p.places.subarray(which * 16, which * 16 + 16);
			if ((r[13] & mask) === 0) continue;
			const o = [0, 1, 2].map((row) => r[row * 4] * from[0] + r[row * 4 + 1] * from[1] + r[row * 4 + 2] * from[2] + r[row * 4 + 3]);
			const d = [0, 1, 2].map((row) => r[row * 4] * way[0] + r[row * 4 + 1] * way[1] + r[row * 4 + 2] * way[2]);
			const dinv = d.map((x) => (Math.abs(x) > 1e-20 ? 1 / x : 1e20));
			const inner = [r[12]];
			while (inner.length) {
				const m = node(inner.pop());
				if (!slab(m, o, dinv, best)) continue;
				if (m[7] > 0) {
					for (let k = 0; k < m[7]; k++) {
						const t = p.tris.subarray((m[3] + k) * 12, (m[3] + k) * 12 + 12);
						const hitT = triangle(o, d, [t[0], t[1], t[2]], [t[4], t[5], t[6]], [t[8], t[9], t[10]]);
						if (hitT > 0 && hitT < best) {
							best = hitT;
							found = which;
							prim = t[3];
						}
					}
				} else {
					inner.push(m[3], m[3] + 1);
				}
			}
		} else {
			stack.push(n[3], n[3] + 1);
		}
	}
	return { t: best, found, prim };
}

const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

function triangle(o, d, v0, e1, e2) {
	const p = cross(d, e2);
	const det = dot(e1, p);
	if (det === 0) return -1;
	const inv = 1 / det;
	const s = [o[0] - v0[0], o[1] - v0[1], o[2] - v0[2]];
	const u = dot(s, p) * inv;
	if (u < 0 || u > 1) return -1;
	const q = cross(s, e1);
	const v = dot(d, q) * inv;
	if (v < 0 || u + v > 1) return -1;
	return dot(e2, q) * inv;
}

function brute(shapes, places, which, from, way, mask) {
	let best = 1e7, found = -1, prim = -1;
	which.forEach((k, n) => {
		const P = places.subarray(n * 16, n * 16 + 16);
		if ((P[12] & mask) === 0) return;
		const s = shapes[k];
		const world = (i) => {
			const x = s.points[i * 3], y = s.points[i * 3 + 1], z = s.points[i * 3 + 2];
			return [0, 1, 2].map((c) => P[c] * x + P[3 + c] * y + P[6 + c] * z + P[9 + c]);
		};
		for (let t = 0; t < s.indices.length / 3; t++) {
			const a = world(s.indices[3 * t]), b = world(s.indices[3 * t + 1]), c = world(s.indices[3 * t + 2]);
			const hitT = triangle(from, way, a, [b[0] - a[0], b[1] - a[1], b[2] - a[2]], [c[0] - a[0], c[1] - a[1], c[2] - a[2]]);
			if (hitT > 0 && hitT < best) {
				best = hitT;
				found = n;
				prim = t;
			}
		}
	});
	return { t: best, found, prim };
}

test("the trees find what testing every triangle finds", () => {
	const r = rng(7);
	const raw = [soup(r, 300), soup(r, 57), soup(r, 1)];
	const shapes = raw.map((s) => ({ ...s, tree: shapeTree(s.points, s.indices) }));
	const which = [0, 1, 0, 2, 1, 0];
	const places = new Float32Array(which.length * 16);
	which.forEach((_, n) => {
		const a = r() * Math.PI * 2, mirror = n === 4 ? -1 : 1, scale = n === 2 ? 1.5 : 1;
		const c = Math.cos(a) * scale, s = Math.sin(a) * scale;
		places.set([c * mirror, 0, -s * mirror, 0, scale, 0, s, 0, c, r() * 80 - 40, r() * 20, r() * 80 - 40, n === 5 ? 4 : 1], n * 16);
	});
	const records = new Uint8Array(which.length * 80);
	const view = new DataView(records.buffer);
	which.forEach((k, n) => view.setUint32(n * 80 + 64, k, true));
	const p = pack(shapes, records, places, which);
	assert.ok(p.top >= 0);
	assert.equal(p.info[4 * 3], 2);
	let hits = 0;
	for (let i = 0; i < 400; i++) {
		const from = [r() * 160 - 80, r() * 60 - 10, r() * 160 - 80];
		const target = [r() * 80 - 40, r() * 20, r() * 80 - 40];
		const d = target.map((x, k) => x - from[k]);
		const len = Math.hypot(...d);
		const way = d.map((x) => x / len);
		const mask = i % 3 === 0 ? 4 : 0xff;
		const a = walk(p, from, way, mask);
		const b = brute(raw, places, which, from, way, mask);
		assert.equal(a.found, b.found, `ray ${i}: instance`);
		if (b.found >= 0) {
			hits++;
			assert.equal(a.prim, b.prim, `ray ${i}: triangle`);
			assert.ok(Math.abs(a.t - b.t) < 1e-3 * Math.max(1, b.t), `ray ${i}: ${a.t} against ${b.t}`);
		}
	}
	assert.ok(hits > 100, `${hits} rays hit something`);
});

test("a tree of one and of none", () => {
	const one = tree(new Float32Array([0, 0, 0]), new Float32Array([1, 1, 1]), new Float32Array([0.5, 0.5, 0.5]), 1, 4);
	assert.equal(one.count, 1);
	assert.equal(one.nodes[7], 1);
	const none = tree(new Float32Array(0), new Float32Array(0), new Float32Array(0), 0, 4);
	assert.equal(none.count, 1);
});

test("half floats round as the card's do", () => {
	assert.equal(half(1), 0x3c00);
	assert.equal(half(-2), 0xc000);
	assert.equal(half(65504), 0x7bff);
	// Past the largest half is the largest, never infinite: a sun stays the brightest, not a NaN.
	assert.equal(half(1e9), 0x7bff);
	assert.equal(half(0), 0);
	assert.equal(half(0.5), 0x3800);
});
