// Which numbers a picture of codes holds, marked by the graphics card
// itself: what SeenParts reads, without reading the picture back.
//
// Drawn as points, one a pixel of the picture (codes): a point's column is
// its vertex's x, its row its instance. Each moves to the cell of the
// number its pixel holds and marks it, red, adding up over every picture
// drawn into the tally since it was cleared. Only the first pixel of a run
// of one number along a row marks it: the rest would mark the same cell,
// one after another. A side has rows of its own (SeenParts._read_tally
// lays them over each other for the parts seen from any side). A pixel
// holding no part, and the corner where the token is, mark nothing.
//
// A number is read from a pixel as SeenParts._values reads it: 24 levels a
// channel from 64 up (seen_codes.gdshaderinc), rounded half away from zero.

shader_type canvas_item;
render_mode blend_add, unshaded, skip_vertex_transform;

uniform sampler2D codes : filter_nearest;
// The part of the picture this side drew, in pixels from its top left.
uniform ivec2 size = ivec2(0, 0);
// Numbers before this pass's (SeenParts.SPAN a pass).
uniform int first = 0;
// Cells a row of the tally.
uniform int width = 2048;
// The first row of this side's cells.
uniform int side_row = 0;

int level(float value) {
	float x = (round(value * 255.0) - 64.0) / 8.0;
	return int(sign(x) * floor(abs(x) + 0.5));
}

// The number a pixel holds, 0 for none.
int number_at(ivec2 at) {
	vec4 pixel = texelFetch(codes, at, 0);
	vec3 bytes = round(pixel.rgb * 255.0);
	if (bytes.r < 40.0 || bytes.g < 40.0 || bytes.b < 40.0) {
		return 0;
	}
	return max(level(pixel.r) + 24 * level(pixel.g) + 576 * level(pixel.b), 0);
}

void vertex() {
	int row = INSTANCE_ID;
	int column = int(VERTEX.x + 0.5);
	VERTEX = vec2(-16.0, -16.0);
	POINT_SIZE = 1.0;
	if (column < size.x && row < size.y && !(column < 8 && row < 8)) {
		int number = number_at(ivec2(column, row));
		// The first of a run: after the edge, the token's corner or another number.
		bool starts = column == 0 || (column == 8 && row < 8)
			|| number_at(ivec2(column - 1, row)) != number;
		if (number > 0 && starts) {
			int cell = number + first;
			int at = side_row + cell / width;
			VERTEX = vec2(float(cell % width) + 0.5, float(at) + 0.5);
		}
	}
}

void fragment() {
	COLOR = vec4(1.0, 0.0, 0.0, 1.0);
}
