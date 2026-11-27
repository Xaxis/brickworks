// Best, path traced in the visitor's own tab (photoreal28): the desktop's tracer
// (path_tracer.glsl and its resolve) run as WebGL2 fragment shaders on the
// browser's graphics card, given the set the app stages for the desktop's
// (PathTracer, through PageTracer's bridge). tools/web/tracer_port.py writes
// the shaders into SHADERS at the export; nothing here is loaded until Best is
// pressed, so a first visit fetches none of it.
//
// What the card's ray tracing does on the desktop is done here by a tree of
// boxes: one tree of triangles for each distinct shape, in the shape's own
// space (the desktop's BLAS), and one over the instances, each a shape placed
// where its part sits (the TLAS). Both are built here, the shapes' as the app
// hands each over (a few a frame) and the instances' when the set is staged.
//
// A picture is traced a band of rows at a time, as many as the card does
// within a frame's share: a pass is not given until the last one is done
// (its fence), so the page's own frames are never queued behind the tracer's
// and the tab keeps answering. Where the browser times the card's work
// (EXT_disjoint_timer_query_webgl2) each pass is sized to BUDGET_MS of it;
// elsewhere (Firefox, Safari) by the gap between the page's frames: the
// browser holds the next frame until the card has drawn this one, pass and
// all, so a pass is always done by the next frame however long it takes,
// and only the frames' gap says it took too long. It grows while frames come
// within FRAME_GROW_MS and shrinks once they are later than FRAME_SHRINK_MS.
//
// The pure parts (the trees and the textures' packing) take no WebGL, so the
// bench (tools/web/tracer_bench.mjs) builds the very same data under Node.

const SHADERS = null; // tracer_port.py puts the shaders here

// How wide each data texture is (tracer_port.py's WIDE).
export const WIDE = 2048;
// What a pass may take of the card in a frame, where it can be timed.
const BUDGET_MS = 12;
// Where it cannot: the frames' gaps it grows within and shrinks past.
const FRAME_GROW_MS = 22;
const FRAME_SHRINK_MS = 34;
// The most samples one pass gives every pixel (PathTracer.MOST_PER_PASS).
const MOST_PER_PASS = 32;

// -- the trees ------------------------------------------------------------------

// A tree of boxes over [count] things, each its box (lo, hi: 3 floats each)
// and its middle (mid): binned by the surface area heuristic along the
// middles' longest side. Its nodes are 8 floats, two texels: lo.xyz and a,
// hi.xyz and b. A leaf has b things (b > 0) from order[a]; an inner node's
// children are a and a + 1, split along axis -b - 1. With [leafMost] 1 (the
// instances' tree) every leaf holds one thing, and below depth 12 the rest is
// halved by count, so the tree is never deeper than the tracer's stack
// (32: 12 + log2 of the instances).
export function tree(lo, hi, mid, count, leafMost) {
	const single = leafMost === 1;
	const order = new Uint32Array(count);
	for (let i = 0; i < count; i++) order[i] = i;
	const nodes = new Float32Array(Math.max(1, 2 * count) * 8);
	let used = 1;
	const BINS = 12;
	const binLo = new Float32Array(BINS * 3);
	const binHi = new Float32Array(BINS * 3);
	const binCount = new Int32Array(BINS);
	const rightArea = new Float64Array(BINS);
	const rightCount = new Int32Array(BINS);
	const bin = new Int32Array(count);
	const stack = [[0, 0, count, 0]];
	if (count === 0) {
		nodes.set([0, 0, 0, 0, 0, 0, 0, 0]);
		return { nodes: nodes.subarray(0, 8), order, count: 1 };
	}
	while (stack.length) {
		const [node, start, end, depth] = stack.pop();
		let lx = Infinity, ly = Infinity, lz = Infinity, hx = -Infinity, hy = -Infinity, hz = -Infinity;
		let cx0 = Infinity, cy0 = Infinity, cz0 = Infinity, cx1 = -Infinity, cy1 = -Infinity, cz1 = -Infinity;
		for (let i = start; i < end; i++) {
			const t = order[i] * 3;
			if (lo[t] < lx) lx = lo[t];
			if (lo[t + 1] < ly) ly = lo[t + 1];
			if (lo[t + 2] < lz) lz = lo[t + 2];
			if (hi[t] > hx) hx = hi[t];
			if (hi[t + 1] > hy) hy = hi[t + 1];
			if (hi[t + 2] > hz) hz = hi[t + 2];
			const mx = mid[t], my = mid[t + 1], mz = mid[t + 2];
			if (mx < cx0) cx0 = mx;
			if (my < cy0) cy0 = my;
			if (mz < cz0) cz0 = mz;
			if (mx > cx1) cx1 = mx;
			if (my > cy1) cy1 = my;
			if (mz > cz1) cz1 = mz;
		}
		const o = node * 8;
		nodes[o] = lx; nodes[o + 1] = ly; nodes[o + 2] = lz;
		nodes[o + 4] = hx; nodes[o + 5] = hy; nodes[o + 6] = hz;
		const n = end - start;
		const ex = cx1 - cx0, ey = cy1 - cy0, ez = cz1 - cz0;
		const axis = ex >= ey && ex >= ez ? 0 : (ey >= ez ? 1 : 2);
		const extent = axis === 0 ? ex : (axis === 1 ? ey : ez);
		const low = axis === 0 ? cx0 : (axis === 1 ? cy0 : cz0);
		const halve = () => {
			// By count, along the middles' longest side.
			order.subarray(start, end).sort((p, q) => mid[p * 3 + axis] - mid[q * 3 + axis]);
			const cut = start + (n >> 1);
			const left = used;
			used += 2;
			nodes[o + 3] = left;
			nodes[o + 7] = -(axis + 1);
			stack.push([left + 1, cut, end, depth + 1], [left, start, cut, depth + 1]);
		};
		if (n <= leafMost) {
			nodes[o + 3] = start;
			nodes[o + 7] = n;
			continue;
		}
		if (single ? depth >= 12 || !(extent > 0) : depth >= 30 || !(extent > 0)) {
			if (single || depth < 30) {
				halve();
				continue;
			}
			nodes[o + 3] = start;
			nodes[o + 7] = n;
			continue;
		}
		binLo.fill(Infinity);
		binHi.fill(-Infinity);
		binCount.fill(0);
		const scale = BINS / extent;
		for (let i = start; i < end; i++) {
			const t = order[i] * 3;
			let b = Math.floor((mid[t + axis] - low) * scale);
			if (b >= BINS) b = BINS - 1;
			if (b < 0) b = 0;
			bin[i] = b;
			binCount[b]++;
			const q = b * 3;
			for (let k = 0; k < 3; k++) {
				if (lo[t + k] < binLo[q + k]) binLo[q + k] = lo[t + k];
				if (hi[t + k] > binHi[q + k]) binHi[q + k] = hi[t + k];
			}
		}
		const area = (a0, a1, a2, b0, b1, b2) => {
			const dx = b0 - a0, dy = b1 - a1, dz = b2 - a2;
			return dx < 0 ? 0 : dx * dy + dy * dz + dz * dx;
		};
		let rx0 = Infinity, ry0 = Infinity, rz0 = Infinity, rx1 = -Infinity, ry1 = -Infinity, rz1 = -Infinity;
		let rc = 0;
		for (let b = BINS - 1; b > 0; b--) {
			const q = b * 3;
			if (binCount[b]) {
				rx0 = Math.min(rx0, binLo[q]); ry0 = Math.min(ry0, binLo[q + 1]); rz0 = Math.min(rz0, binLo[q + 2]);
				rx1 = Math.max(rx1, binHi[q]); ry1 = Math.max(ry1, binHi[q + 1]); rz1 = Math.max(rz1, binHi[q + 2]);
			}
			rc += binCount[b];
			rightCount[b] = rc;
			rightArea[b] = rc ? area(rx0, ry0, rz0, rx1, ry1, rz1) : 0;
		}
		let best = Infinity, split = -1;
		let lx0 = Infinity, ly0 = Infinity, lz0 = Infinity, lx1 = -Infinity, ly1 = -Infinity, lz1 = -Infinity;
		let lc = 0;
		for (let b = 0; b < BINS - 1; b++) {
			const q = b * 3;
			if (binCount[b]) {
				lx0 = Math.min(lx0, binLo[q]); ly0 = Math.min(ly0, binLo[q + 1]); lz0 = Math.min(lz0, binLo[q + 2]);
				lx1 = Math.max(lx1, binHi[q]); ly1 = Math.max(ly1, binHi[q + 1]); lz1 = Math.max(lz1, binHi[q + 2]);
			}
			lc += binCount[b];
			if (lc === 0 || rightCount[b + 1] === 0) continue;
			const cost = lc * area(lx0, ly0, lz0, lx1, ly1, lz1) + rightCount[b + 1] * rightArea[b + 1];
			if (cost < best) {
				best = cost;
				split = b;
			}
		}
		const whole = area(lx, ly, lz, hx, hy, hz);
		if (split < 0 || (n <= 4 && best >= n * whole)) {
			if (single) {
				halve();
				continue;
			}
			nodes[o + 3] = start;
			nodes[o + 7] = n;
			continue;
		}
		let i = start, j = end - 1;
		while (i <= j) {
			if (bin[i] <= split) {
				i++;
			} else {
				const s = order[i]; order[i] = order[j]; order[j] = s;
				const c = bin[i]; bin[i] = bin[j]; bin[j] = c;
				j--;
			}
		}
		let cut = i;
		if (cut === start || cut === end) cut = start + (n >> 1);
		const left = used;
		used += 2;
		nodes[o + 3] = left;
		nodes[o + 7] = -(axis + 1);
		stack.push([left + 1, cut, end, depth + 1], [left, start, cut, depth + 1]);
	}
	return { nodes: nodes.subarray(0, used * 8), order, count: used };
}

// One shape's tree, in its own space: its triangles in the tree's order, each
// three texels (its first corner and its number in the shape, then its two
// edges), as the closest hit finds a triangle's corners by that number.
export function shapeTree(points, indices) {
	const count = Math.floor(indices.length / 3);
	const lo = new Float32Array(count * 3);
	const hi = new Float32Array(count * 3);
	const mid = new Float32Array(count * 3);
	for (let t = 0; t < count; t++) {
		for (let k = 0; k < 3; k++) {
			const a = points[indices[3 * t] * 3 + k];
			const b = points[indices[3 * t + 1] * 3 + k];
			const c = points[indices[3 * t + 2] * 3 + k];
			lo[3 * t + k] = Math.min(a, b, c);
			hi[3 * t + k] = Math.max(a, b, c);
			mid[3 * t + k] = (a + b + c) / 3;
		}
	}
	const made = tree(lo, hi, mid, count, 4);
	const tris = new Float32Array(Math.max(count, 1) * 12);
	for (let i = 0; i < count; i++) {
		const t = made.order[i];
		const ia = indices[3 * t] * 3, ib = indices[3 * t + 1] * 3, ic = indices[3 * t + 2] * 3;
		const o = i * 12;
		tris[o] = points[ia]; tris[o + 1] = points[ia + 1]; tris[o + 2] = points[ia + 2]; tris[o + 3] = t;
		tris[o + 4] = points[ib] - points[ia]; tris[o + 5] = points[ib + 1] - points[ia + 1];
		tris[o + 6] = points[ib + 2] - points[ia + 2];
		tris[o + 8] = points[ic] - points[ia]; tris[o + 9] = points[ic + 1] - points[ia + 1];
		tris[o + 10] = points[ic + 2] - points[ia + 2];
	}
	return { nodes: made.nodes, tris, triangles: count, vertices: points.length / 3 };
}

// The 3x3 inverse of a basis given by its columns (9 floats from [at]).
function inverse3(m, at) {
	const a = m[at], b = m[at + 3], c = m[at + 6];
	const d = m[at + 1], e = m[at + 4], f = m[at + 7];
	const g = m[at + 2], h = m[at + 5], i = m[at + 8];
	const A = e * i - f * h, B = -(d * i - f * g), C = d * h - e * g;
	const det = a * A + b * B + c * C;
	const s = det !== 0 ? 1 / det : 0;
	// Rows of the inverse.
	return [
		A * s, -(b * i - c * h) * s, (b * f - c * e) * s,
		B * s, (a * i - c * g) * s, -(a * f - c * d) * s,
		C * s, -(a * h - b * g) * s, (a * e - b * d) * s,
	];
}

// Everything a picture's set is on the card as: [shapes] (each shapeTree's,
// with its points, normals and corners) in the order the stage names them,
// [records] the instances' 80 bytes each (PathTracer's Instance), [places]
// 16 floats each (the seated basis's columns, the origin, the mask), [which]
// each instance's shape. Returns the data textures' contents and the top
// tree's root.
export function pack(shapes, records, places, which) {
	const instances = which.length;
	let nodeCount = 0, triCount = 0, vertexCount = 0, indexCount = 0;
	const nodeBase = [], triBase = [], vertexBase = [], indexBase = [];
	for (const s of shapes) {
		nodeBase.push(nodeCount);
		triBase.push(triCount);
		vertexBase.push(vertexCount);
		indexBase.push(indexCount);
		nodeCount += s.tree.nodes.length / 8;
		triCount += s.tree.triangles;
		vertexCount += s.points.length / 3;
		indexCount += s.indices.length;
	}
	// The instances' boxes in the world, each its shape's box turned and placed.
	const lo = new Float32Array(instances * 3), hi = new Float32Array(instances * 3), mid = new Float32Array(instances * 3);
	const placesOut = new Float32Array(instances * 16);
	for (let n = 0; n < instances; n++) {
		const s = shapes[which[n]];
		const p = n * 16;
		const box = s.tree.nodes;
		let x0 = Infinity, y0 = Infinity, z0 = Infinity, x1 = -Infinity, y1 = -Infinity, z1 = -Infinity;
		for (let corner = 0; corner < 8; corner++) {
			const x = corner & 1 ? box[4] : box[0];
			const y = corner & 2 ? box[5] : box[1];
			const z = corner & 4 ? box[6] : box[2];
			const wx = places[p] * x + places[p + 3] * y + places[p + 6] * z + places[p + 9];
			const wy = places[p + 1] * x + places[p + 4] * y + places[p + 7] * z + places[p + 10];
			const wz = places[p + 2] * x + places[p + 5] * y + places[p + 8] * z + places[p + 11];
			x0 = Math.min(x0, wx); y0 = Math.min(y0, wy); z0 = Math.min(z0, wz);
			x1 = Math.max(x1, wx); y1 = Math.max(y1, wy); z1 = Math.max(z1, wz);
		}
		lo.set([x0, y0, z0], n * 3);
		hi.set([x1, y1, z1], n * 3);
		mid.set([(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], n * 3);
		const r = inverse3(places, p);
		const ox = places[p + 9], oy = places[p + 10], oz = places[p + 11];
		for (let row = 0; row < 3; row++) {
			placesOut[p + row * 4] = r[row * 3];
			placesOut[p + row * 4 + 1] = r[row * 3 + 1];
			placesOut[p + row * 4 + 2] = r[row * 3 + 2];
			placesOut[p + row * 4 + 3] = -(r[row * 3] * ox + r[row * 3 + 1] * oy + r[row * 3 + 2] * oz);
		}
		placesOut[p + 12] = nodeBase[which[n]];
		placesOut[p + 13] = places[p + 12];
	}
	const top = tree(lo, hi, mid, instances, 1);
	const topBase = nodeCount;
	const nodes = new Float32Array((nodeCount + top.count) * 8);
	const tris = new Float32Array(Math.max(triCount, 1) * 12);
	const points = new Float32Array(Math.max(vertexCount, 1) * 4);
	const normals = new Float32Array(Math.max(vertexCount, 1) * 4);
	const indices = new Uint32Array(Math.max(indexCount, 1));
	const meshes = new Uint32Array(Math.max(shapes.length, 1) * 4);
	shapes.forEach((s, k) => {
		const nodesHere = s.tree.nodes;
		const at = nodeBase[k] * 8;
		nodes.set(nodesHere, at);
		for (let o = at; o < at + nodesHere.length; o += 8) {
			nodes[o + 3] += nodes[o + 7] > 0 ? triBase[k] : nodeBase[k];
		}
		tris.set(s.tree.tris.subarray(0, s.tree.triangles * 12), triBase[k] * 12);
		for (let v = 0; v < s.points.length / 3; v++) {
			const o = (vertexBase[k] + v) * 4;
			points[o] = s.points[3 * v]; points[o + 1] = s.points[3 * v + 1]; points[o + 2] = s.points[3 * v + 2];
			normals[o] = s.normals[3 * v]; normals[o + 1] = s.normals[3 * v + 1]; normals[o + 2] = s.normals[3 * v + 2];
		}
		indices.set(s.indices, indexBase[k]);
		meshes[4 * k] = vertexBase[k];
		meshes[4 * k + 1] = indexBase[k];
	});
	for (let i = 0; i < top.count; i++) {
		const o = (topBase + i) * 8;
		nodes.set(top.nodes.subarray(i * 8, i * 8 + 8), o);
		// A leaf of the top tree holds one instance: its number, in place of where its list starts.
		nodes[o + 3] = nodes[o + 7] > 0 ? top.order[nodes[o + 3]] : nodes[o + 3] + topBase;
	}
	const recordFloats = new Float32Array(instances * 16);
	const info = new Uint32Array(instances * 4);
	const view = new DataView(records.buffer, records.byteOffset, records.byteLength);
	for (let n = 0; n < instances; n++) {
		for (let k = 0; k < 16; k++) recordFloats[n * 16 + k] = view.getFloat32(n * 80 + k * 4, true);
		for (let k = 0; k < 4; k++) info[n * 4 + k] = view.getUint32(n * 80 + 64 + k * 4, true);
	}
	return {
		top: instances ? topBase : -1,
		nodes, tris, points, normals, indices, meshes,
		records: recordFloats, info, places: placesOut,
		counts: { nodes: nodeCount + top.count, triangles: triCount, vertices: vertexCount, instances },
	};
}

// A float32 to a half float's 16 bits (round to nearest even), for the place's picture.
const f32 = new Float32Array(1);
const u32 = new Uint32Array(f32.buffer);
export function half(value) {
	f32[0] = value;
	const x = u32[0];
	const sign = (x >>> 16) & 0x8000;
	let exp = ((x >>> 23) & 0xff) - 127 + 15;
	let mant = x & 0x7fffff;
	// Past the largest half: the largest (a sun brighter than 65504 is still the brightest there).
	if (exp >= 31) return ((x >>> 23) & 0xff) === 0xff && mant ? sign | 0x7e00 : sign | 0x7bff;
	if (exp <= 0) {
		if (exp < -10) return sign;
		mant = (mant | 0x800000) >>> (1 - exp);
		return sign | ((mant + 0x1000) >>> 13);
	}
	const rounded = sign | (exp << 10) | (mant >>> 13);
	return rounded + (((mant & 0x1fff) > 0x1000 || ((mant & 0x1fff) === 0x1000 && (rounded & 1))) ? 1 : 0);
}

// -- the tracer -------------------------------------------------------------------

function bytesOf(given) {
	if (given instanceof Uint8Array) return given;
	if (given instanceof ArrayBuffer) return new Uint8Array(given);
	if (ArrayBuffer.isView(given)) return new Uint8Array(given.buffer, given.byteOffset, given.byteLength);
	// Base64, as the app's bridge hands bytes over.
	if (typeof Uint8Array.fromBase64 === "function") return Uint8Array.fromBase64(given);
	const text = atob(given);
	const out = new Uint8Array(text.length);
	for (let i = 0; i < text.length; i++) out[i] = text.charCodeAt(i);
	return out;
}

function floats(given) {
	const b = bytesOf(given);
	return new Float32Array(b.buffer.slice(b.byteOffset, b.byteOffset + (b.byteLength & ~3)));
}

function uints(given) {
	const b = bytesOf(given);
	return new Uint32Array(b.buffer.slice(b.byteOffset, b.byteOffset + (b.byteLength & ~3)));
}

export class Tracer {
	// [gl] a WebGL2 context of the tracer's own; [shaders] tracer_port.py's.
	constructor(gl, shaders = SHADERS) {
		this.gl = gl;
		this.shaders = shaders;
		this.programs = {};
		this.shapes = new Map();
		this.textures = {};
		this.samples = 0;
		this.size = [0, 0];
		this.version = "plain";
		this.row = 0;
		this.rows = 16;
		this.perPass = 1;
		this.fence = null;
		this.waits = 0;
		this.passes = 0;
		this.passMs = [];
		this.problem = "";
		this.float = !!gl.getExtension("EXT_color_buffer_float");
		this.parallel = gl.getExtension("KHR_parallel_shader_compile");
		this.timer = gl.getExtension("EXT_disjoint_timer_query_webgl2");
		this.query = null;
		this.most = gl.getParameter(gl.MAX_TEXTURE_SIZE);
		this.vao = gl.createVertexArray();
		this.sceneBuffer = gl.createBuffer();
		this.passBuffer = gl.createBuffer();
		this.resolveBuffer = gl.createBuffer();
		this.top = -1;
	}

	// The shader for [version] ("plain", "marks" or "photo", as PathTracer
	// picks one) and the resolve: compiled beside the page, never holding it.
	// "ready", "compiling" or why it failed.
	prepare(version) {
		const gl = this.gl;
		const out = [];
		for (const name of [version, "resolve"]) {
			let p = this.programs[name];
			if (!p) {
				p = gl.createProgram();
				const vs = gl.createShader(gl.VERTEX_SHADER);
				gl.shaderSource(vs, this.shaders.vertex);
				gl.compileShader(vs);
				const fs = gl.createShader(gl.FRAGMENT_SHADER);
				gl.shaderSource(fs, this.shaders[name]);
				gl.compileShader(fs);
				gl.attachShader(p, vs);
				gl.attachShader(p, fs);
				gl.linkProgram(p);
				this.programs[name] = p;
				p.shaders = [vs, fs];
				p.began = performance.now();
			}
			if (p.state) {
				out.push(p.state);
				continue;
			}
			if (this.parallel && !gl.getProgramParameter(p, this.parallel.COMPLETION_STATUS_KHR)) {
				out.push("compiling");
				continue;
			}
			if (gl.getProgramParameter(p, gl.LINK_STATUS)) {
				p.state = "ready";
				p.compileMs = performance.now() - p.began;
				this.locate(name, p);
			} else {
				p.state = "failed: " + (gl.getShaderInfoLog(p.shaders[1]) || gl.getProgramInfoLog(p) || "no log").slice(0, 400);
			}
			out.push(p.state);
		}
		return out.find((s) => s !== "ready") || "ready";
	}

	locate(name, p) {
		const gl = this.gl;
		p.at = {};
		const n = gl.getProgramParameter(p, gl.ACTIVE_UNIFORMS);
		for (let i = 0; i < n; i++) {
			const u = gl.getActiveUniform(p, i);
			p.at[u.name] = gl.getUniformLocation(p, u.name);
		}
		const blocks = name === "resolve" ? ["Resolve"] : ["Scene", "Pass"];
		p.blocks = {};
		blocks.forEach((block, k) => {
			const index = gl.getUniformBlockIndex(p, block);
			if (index !== gl.INVALID_INDEX) {
				gl.uniformBlockBinding(p, index, k);
				p.blocks[block] = gl.getActiveUniformBlockParameter(p, index, gl.UNIFORM_BLOCK_DATA_SIZE);
			}
		});
	}

	// A shape, by the app's [key]: its points and normals (3 floats each) and
	// its corners (3 indices a triangle), as PathTracer.shape_of reads them.
	shape(key, points, normals, indices) {
		if (this.shapes.has(key)) return this.shapes.get(key).tree.triangles;
		const p = floats(points), nm = floats(normals), ix = uints(indices);
		const made = { points: p, normals: nm.length === p.length ? nm : new Float32Array(p.length), indices: ix, tree: shapeTree(p, ix) };
		this.shapes.set(key, made);
		return made.tree.triangles;
	}

	forget(key) {
		this.shapes.delete(key);
	}

	// The set: [keys] the shapes in the stage's order (PathTracer's shape list),
	// [records] 80 bytes an instance, [places] 16 floats an instance (the seated
	// transform's basis by columns, its origin, its mask), [which] each
	// instance's place in [keys]. False when a shape is missing or the set is
	// more than the card's textures hold.
	stage(keys, records, places, which) {
		const shapes = [];
		for (const key of keys) {
			const s = this.shapes.get(key);
			if (!s) {
				this.problem = "a shape was not handed over: " + key;
				return false;
			}
			shapes.push(s);
		}
		const packed = pack(shapes, bytesOf(records), floats(places), Array.from(which));
		const gl = this.gl;
		const make = (name, data, channels, internal, format, type) => {
			const texels = Math.max(1, Math.ceil(data.length / channels));
			const tall = Math.ceil(texels / WIDE);
			if (tall > this.most) throw new Error(`${name}: ${tall} rows, the card holds ${this.most}`);
			const full = new data.constructor(WIDE * tall * channels);
			full.set(data);
			if (this.textures[name]) gl.deleteTexture(this.textures[name]);
			const t = gl.createTexture();
			gl.bindTexture(gl.TEXTURE_2D, t);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
			gl.texImage2D(gl.TEXTURE_2D, 0, internal, WIDE, tall, 0, format, type, full);
			this.textures[name] = t;
		};
		try {
			make("u_records", packed.records, 4, gl.RGBA32F, gl.RGBA, gl.FLOAT);
			make("u_info", packed.info, 4, gl.RGBA32UI, gl.RGBA_INTEGER, gl.UNSIGNED_INT);
			make("u_meshes", packed.meshes, 4, gl.RGBA32UI, gl.RGBA_INTEGER, gl.UNSIGNED_INT);
			make("u_points", packed.points, 4, gl.RGBA32F, gl.RGBA, gl.FLOAT);
			make("u_normals", packed.normals, 4, gl.RGBA32F, gl.RGBA, gl.FLOAT);
			make("u_indices", packed.indices, 1, gl.R32UI, gl.RED_INTEGER, gl.UNSIGNED_INT);
			make("u_nodes", packed.nodes, 4, gl.RGBA32F, gl.RGBA, gl.FLOAT);
			make("u_tris", packed.tris, 4, gl.RGBA32F, gl.RGBA, gl.FLOAT);
			make("u_places", packed.places, 4, gl.RGBA32F, gl.RGBA, gl.FLOAT);
		} catch (e) {
			this.problem = String(e.message || e);
			return false;
		}
		this.top = packed.top;
		this.counts = packed.counts;
		return true;
	}

	// The photographed place (or the even sky's 2 x 2 white): its picture as
	// half floats (4 a texel) or floats, and its table of shares.
	place(width, height, data, table, isHalf = true) {
		const gl = this.gl;
		let texels;
		if (isHalf) {
			const b = bytesOf(data);
			texels = new Uint16Array(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength));
		} else {
			const f = floats(data);
			texels = new Uint16Array(f.length);
			for (let i = 0; i < f.length; i++) texels[i] = half(f[i]);
		}
		if (this.textures.place_map) gl.deleteTexture(this.textures.place_map);
		const t = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, t);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, width, height, 0, gl.RGBA, gl.HALF_FLOAT, texels);
		this.textures.place_map = t;
		const rows = floats(table);
		const tall = Math.ceil(Math.max(rows.length, 1) / WIDE);
		const full = new Float32Array(WIDE * tall);
		full.set(rows);
		if (this.textures.u_table) gl.deleteTexture(this.textures.u_table);
		const tt = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, tt);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.R32F, WIDE, tall, 0, gl.RED, gl.FLOAT, full);
		this.textures.u_table = tt;
	}

	// What a staged model stands on: a tile, RGBA8 (sRGB, its height in alpha), repeated both ways.
	surface(width, height, data) {
		const gl = this.gl;
		let bytes = bytesOf(data);
		if (!width || !height || bytes.length < width * height * 4) {
			width = 2;
			height = 2;
			bytes = new Uint8Array(16).fill(255);
		}
		if (this.textures.surface_map) gl.deleteTexture(this.textures.surface_map);
		const t = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, t);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
		gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, bytes);
		this.textures.surface_map = t;
	}

	target(width, height) {
		const gl = this.gl;
		const made = (internal, format, type) => {
			const t = gl.createTexture();
			gl.bindTexture(gl.TEXTURE_2D, t);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
			gl.texStorage2D(gl.TEXTURE_2D, 1, internal, width, height);
			return t;
		};
		for (const pair of this.pairs || []) {
			gl.deleteFramebuffer(pair.fb);
			gl.deleteTexture(pair.accum);
			gl.deleteTexture(pair.guide);
		}
		if (this.picturePair) {
			gl.deleteFramebuffer(this.picturePair.fb);
			gl.deleteTexture(this.picturePair.texture);
		}
		this.pairs = [0, 1].map(() => {
			const accum = made(gl.RGBA32F);
			const guide = made(gl.RGBA32F);
			const fb = gl.createFramebuffer();
			gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
			gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, accum, 0);
			gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, guide, 0);
			return { accum, guide, fb };
		});
		const texture = made(gl.RGBA8);
		const fb = gl.createFramebuffer();
		gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
		gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);
		this.picturePair = { texture, fb };
		const ok = gl.checkFramebufferStatus(gl.FRAMEBUFFER) === gl.FRAMEBUFFER_COMPLETE;
		gl.bindFramebuffer(gl.FRAMEBUFFER, this.pairs[0].fb);
		const okFloat = gl.checkFramebufferStatus(gl.FRAMEBUFFER) === gl.FRAMEBUFFER_COMPLETE;
		gl.bindFramebuffer(gl.FRAMEBUFFER, null);
		if (!ok || !okFloat) {
			this.problem = "the card would not draw into float targets";
			return false;
		}
		return true;
	}

	// A picture [width] x [height] begun again, traced by [version] with
	// [scene] (PathTracer's scene: the Scene block's floats).
	begin(width, height, scene, version) {
		const gl = this.gl;
		if (this.prepare(version) !== "ready") {
			this.problem = this.prepare(version);
			return false;
		}
		this.version = version;
		if (width !== this.size[0] || height !== this.size[1] || !this.pairs) {
			if (!this.target(width, height)) return false;
			this.size = [width, height];
		}
		const p = this.programs[version];
		const data = floats(scene);
		const wanted = Math.max(p.blocks.Scene || 0, data.byteLength);
		const full = new Float32Array(Math.ceil(wanted / 16) * 4);
		full.set(data);
		gl.bindBuffer(gl.UNIFORM_BUFFER, this.sceneBuffer);
		gl.bufferData(gl.UNIFORM_BUFFER, full, gl.DYNAMIC_DRAW);
		this.samples = 0;
		this.row = 0;
		this.askedAt = 0;
		this.finishFence();
		return true;
	}

	finishFence() {
		if (this.fence) {
			this.gl.deleteSync(this.fence);
			this.fence = null;
		}
		if (this.query) {
			this.gl.deleteQuery(this.query);
			this.query = null;
		}
	}

	// One pass: [count] samples from sample [first] for the rows [row] to
	// [row] + [rows], into the running sums.
	pass(row, rows, first, count, seed) {
		const gl = this.gl;
		const [w, h] = this.size;
		const p = this.programs[this.version];
		const [from, to] = this.pairs;
		gl.useProgram(p);
		gl.bindVertexArray(this.vao);
		const numbers = new Uint32Array([first, count, seed >>> 0, first === 0 ? 1 : 0, 0, 0, 0, 0]);
		gl.bindBuffer(gl.UNIFORM_BUFFER, this.passBuffer);
		gl.bufferData(gl.UNIFORM_BUFFER, numbers, gl.DYNAMIC_DRAW);
		gl.bindBufferBase(gl.UNIFORM_BUFFER, 0, this.sceneBuffer);
		gl.bindBufferBase(gl.UNIFORM_BUFFER, 1, this.passBuffer);
		const bound = [["u_accum", from.accum], ["u_guide", from.guide], ["u_records"], ["u_info"], ["u_meshes"],
			["u_points"], ["u_normals"], ["u_indices"], ["u_nodes"], ["u_tris"], ["u_places"], ["u_table"],
			["place_map"], ["surface_map"]];
		bound.forEach(([name, texture], unit) => {
			gl.activeTexture(gl.TEXTURE0 + unit);
			gl.bindTexture(gl.TEXTURE_2D, texture || this.textures[name] || null);
			if (p.at[name]) gl.uniform1i(p.at[name], unit);
		});
		if (p.at.u_top) gl.uniform1i(p.at.u_top, this.top);
		gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, to.fb);
		gl.drawBuffers([gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1]);
		gl.viewport(0, 0, w, h);
		gl.enable(gl.SCISSOR_TEST);
		gl.scissor(0, row, w, rows);
		gl.disable(gl.BLEND);
		gl.disable(gl.DEPTH_TEST);
		gl.drawArrays(gl.TRIANGLES, 0, 3);
		// The band back into the sums the next pass reads.
		gl.bindFramebuffer(gl.READ_FRAMEBUFFER, to.fb);
		gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, from.fb);
		gl.readBuffer(gl.COLOR_ATTACHMENT0);
		gl.drawBuffers([gl.COLOR_ATTACHMENT0, gl.NONE]);
		gl.blitFramebuffer(0, row, w, row + rows, 0, row, w, row + rows, gl.COLOR_BUFFER_BIT, gl.NEAREST);
		gl.readBuffer(gl.COLOR_ATTACHMENT1);
		gl.drawBuffers([gl.NONE, gl.COLOR_ATTACHMENT1]);
		gl.blitFramebuffer(0, row, w, row + rows, 0, row, w, row + rows, gl.COLOR_BUFFER_BIT, gl.NEAREST);
		gl.disable(gl.SCISSOR_TEST);
		gl.bindFramebuffer(gl.READ_FRAMEBUFFER, null);
		gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, null);
		this.passes++;
	}

	// [count] samples more. Whole (metering's small pictures): the whole
	// picture at once. Otherwise a band of rows sized to what the card does in
	// a frame, and only once the last band is done: nothing when it is not,
	// and the page draws its frame. The samples so far.
	trace(count, seed, whole) {
		const gl = this.gl;
		const [w, h] = this.size;
		if (whole) {
			this.pass(0, h, this.samples, count, seed);
			this.samples += count;
			return this.samples;
		}
		// The app asks once a frame: the gap since its last asking is the frame's.
		const now = performance.now();
		this.frameGap = this.askedAt ? now - this.askedAt : 0;
		this.askedAt = now;
		if (this.fence) {
			if (gl.getSyncParameter(this.fence, gl.SYNC_STATUS) !== gl.SIGNALED) {
				this.waits++;
				return this.samples;
			}
			gl.deleteSync(this.fence);
			this.fence = null;
			this.adapt(w, h);
		}
		if (this.row === 0) {
			this.blockCount = Math.max(1, Math.min(count, this.perPass));
			this.blockFirst = this.samples;
		}
		const rows = Math.max(1, Math.min(this.rows, h - this.row));
		if (this.timer && !this.query) {
			this.query = gl.createQuery();
			gl.beginQuery(this.timer.TIME_ELAPSED_EXT, this.query);
			this.pass(this.row, rows, this.blockFirst, this.blockCount, seed);
			gl.endQuery(this.timer.TIME_ELAPSED_EXT);
			this.queryWork = rows * w * this.blockCount;
		} else {
			this.pass(this.row, rows, this.blockFirst, this.blockCount, seed);
		}
		this.lastWork = rows * w * this.blockCount;
		this.fence = gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0);
		gl.flush();
		this.row += rows;
		if (this.row >= h) {
			this.row = 0;
			this.samples += this.blockCount;
		}
		return this.samples;
	}

	// The next pass's size from the last one's: by the card's own time where it
	// says, else by whether it was done by the next frame.
	adapt(w, h) {
		const gl = this.gl;
		let work = this.lastWork || w * 16;
		let timed = false;
		if (this.query && this.timer) {
			const ready = gl.getQueryParameter(this.query, gl.QUERY_RESULT_AVAILABLE);
			const disjoint = gl.getParameter(this.timer.GPU_DISJOINT_EXT);
			if (ready) {
				if (!disjoint) {
					const ms = gl.getQueryParameter(this.query, gl.QUERY_RESULT) / 1e6;
					this.passMs.push(ms);
					if (this.passMs.length > 64) this.passMs.shift();
					if (ms > 0) {
						work = this.queryWork * Math.min(Math.max(BUDGET_MS / ms, 0.25), 2);
						timed = true;
					}
				}
				gl.deleteQuery(this.query);
				this.query = null;
			}
		}
		if (!timed) {
			const gap = this.frameGap || 0;
			if (this.waits >= 2 || gap > FRAME_SHRINK_MS) {
				work *= gap > 2 * FRAME_SHRINK_MS ? 0.4 : 0.7;
			} else if (this.waits === 0 && gap > 0 && gap <= FRAME_GROW_MS) {
				work *= 1.25;
			}
		}
		this.waits = 0;
		const whole = w * h;
		if (work >= whole) {
			this.rows = h;
			this.perPass = Math.max(1, Math.min(MOST_PER_PASS, Math.floor(work / whole)));
		} else {
			this.perPass = 1;
			this.rows = Math.max(4, Math.min(h, Math.floor(work / w)));
		}
	}

	// The picture so far through the resolve ([numbers]: PathTracer.picture's
	// sixteen), as RGBA8, top row first.
	picture(numbers) {
		const gl = this.gl;
		const [w, h] = this.size;
		if (!this.pairs || this.samples <= 0) return null;
		if (this.prepare(this.version) !== "ready") return null;
		const p = this.programs.resolve;
		gl.useProgram(p);
		gl.bindVertexArray(this.vao);
		const values = floats(numbers);
		const full = new Float32Array(Math.ceil(Math.max(p.blocks.Resolve || 64, 64) / 4));
		full.set(values.subarray(0, Math.min(values.length, full.length)));
		gl.bindBufferBase(gl.UNIFORM_BUFFER, 0, this.resolveBuffer);
		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_2D, this.pairs[0].accum);
		gl.uniform1i(p.at.u_accum, 0);
		gl.activeTexture(gl.TEXTURE1);
		gl.bindTexture(gl.TEXTURE_2D, this.pairs[0].guide);
		if (p.at.u_guide) gl.uniform1i(p.at.u_guide, 1);
		gl.uniform2i(p.at.u_size, w, h);
		gl.bindFramebuffer(gl.FRAMEBUFFER, this.picturePair.fb);
		gl.drawBuffers([gl.COLOR_ATTACHMENT0]);
		gl.viewport(0, 0, w, h);
		// Midway through a block of samples the rows it has reached hold that
		// many more: each part divided by its own count, or the picture shown
		// while it traces would be banded.
		const parts = this.row > 0 ? [[0, this.row, this.blockCount], [this.row, h, 0]] : [[0, h, 0]];
		gl.enable(gl.SCISSOR_TEST);
		for (const [from, to, more] of parts) {
			full[0] = values[0] + more;
			gl.bindBuffer(gl.UNIFORM_BUFFER, this.resolveBuffer);
			gl.bufferData(gl.UNIFORM_BUFFER, full, gl.DYNAMIC_DRAW);
			gl.scissor(0, from, w, to - from);
			gl.drawArrays(gl.TRIANGLES, 0, 3);
		}
		gl.disable(gl.SCISSOR_TEST);
		const out = new Uint8Array(w * h * 4);
		gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, out);
		gl.bindFramebuffer(gl.FRAMEBUFFER, null);
		return out;
	}

	// The running sum's mean (RGBA floats, top row first), the light before any
	// exposure, for the bench's colour measure.
	mean() {
		const gl = this.gl;
		const [w, h] = this.size;
		if (!this.pairs || this.samples <= 0) return null;
		gl.bindFramebuffer(gl.READ_FRAMEBUFFER, this.pairs[0].fb);
		gl.readBuffer(gl.COLOR_ATTACHMENT0);
		const out = new Float32Array(w * h * 4);
		gl.readPixels(0, 0, w, h, gl.RGBA, gl.FLOAT, out);
		gl.bindFramebuffer(gl.READ_FRAMEBUFFER, null);
		const share = 1 / this.samples;
		for (let i = 0; i < out.length; i++) out[i] *= share;
		return out;
	}

	release() {
		const gl = this.gl;
		this.finishFence();
		for (const t of Object.values(this.textures)) gl.deleteTexture(t);
		this.textures = {};
		for (const pair of this.pairs || []) {
			gl.deleteFramebuffer(pair.fb);
			gl.deleteTexture(pair.accum);
			gl.deleteTexture(pair.guide);
		}
		this.pairs = null;
		this.size = [0, 0];
	}
}

// -- the app's bridge -----------------------------------------------------------

// Whether this browser can trace: WebGL2 with float targets. Software GL (no
// graphics card: SwiftShader, llvmpipe) is said apart, as a picture there takes
// minutes; the app draws Best by frames there unless asked (?tracer=on).
export function can() {
	try {
		const canvas = typeof OffscreenCanvas !== "undefined" ? new OffscreenCanvas(1, 1) : document.createElement("canvas");
		const gl = canvas.getContext("webgl2");
		if (!gl) return "no WebGL2";
		if (!gl.getExtension("EXT_color_buffer_float")) return "no float targets";
		const info = gl.getExtension("WEBGL_debug_renderer_info");
		const name = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : "";
		const lose = gl.getExtension("WEBGL_lose_context");
		if (lose) lose.loseContext();
		return /swiftshader|llvmpipe|software|basic render/i.test(name) ? "software" : "yes";
	} catch (e) {
		return "no WebGL2";
	}
}

// The tracer the app talks to (window.brickworksTracer), on a canvas of its own.
export function start() {
	const canvas = typeof OffscreenCanvas !== "undefined" ? new OffscreenCanvas(16, 16) : document.createElement("canvas");
	const gl = canvas.getContext("webgl2", { antialias: false, depth: false, alpha: true, preserveDrawingBuffer: false,
		powerPreference: "high-performance" });
	if (!gl) {
		window.brickworksTracerState = "failed: no WebGL2";
		return null;
	}
	const tracer = new Tracer(gl);
	if (!tracer.float) {
		window.brickworksTracerState = "failed: no float targets";
		return null;
	}
	const lost = (e) => {
		e.preventDefault && e.preventDefault();
		window.brickworksTracerState = "failed: the graphics card's context was lost";
	};
	if (canvas.addEventListener) canvas.addEventListener("webglcontextlost", lost);
	window.brickworksTracer = {
		state: (version) => (window.brickworksTracerState && window.brickworksTracerState.startsWith("failed")
			? window.brickworksTracerState : tracer.prepare(version || "plain")),
		problem: () => tracer.problem,
		shape: (key, points, normals, indices) => tracer.shape(key, points, normals, indices),
		forget: (key) => tracer.forget(key),
		stage: (keys, records, places, which) => tracer.stage(String(keys).split(",").filter((k) => k !== "").map(Number),
			records, places, String(which).split(",").filter((k) => k !== "").map(Number)),
		place: (width, height, data, table) => tracer.place(width, height, data, table, true),
		surface: (width, height, data) => tracer.surface(width, height, data),
		begin: (width, height, scene, version) => tracer.begin(width, height, scene, version),
		trace: (count, seed, whole) => tracer.trace(count, seed, !!whole),
		between: () => tracer.row === 0,
		picture: (numbers) => tracer.picture(numbers),
		mean: () => tracer.mean(),
		release: () => tracer.release(),
		stats: () => JSON.stringify({ passes: tracer.passes, rows: tracer.rows, perPass: tracer.perPass,
			passMs: tracer.passMs.slice(-8), counts: tracer.counts || null, timer: !!tracer.timer,
			parallel: !!tracer.parallel, compileMs: Object.fromEntries(Object.entries(tracer.programs).map(([k, p]) => [k, p.compileMs || null])) }),
		tracer,
	};
	window.brickworksTracerState = "started";
	return window.brickworksTracer;
}
