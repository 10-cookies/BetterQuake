#version 300 es
#ifdef GL_ES
precision mediump float;
#endif

#ifdef DRAW_MODE_line
uniform vec2 u_stageSize;
in vec2 a_lineThicknessAndLength;
in vec4 a_penPoints;
in vec4 a_lineColor;

out vec4 v_lineColor;
out float v_lineThickness;
out float v_lineLength;
out vec4 v_penPoints;

// Add this to divisors to prevent division by 0, which results in NaNs propagating through calculations.
// Smaller values can cause problems on some mobile devices.
const float epsilon = 1e-3;
#endif

#if !(defined(DRAW_MODE_line) || defined(DRAW_MODE_background))
uniform mat4 u_projectionMatrix;
uniform mat4 u_modelMatrix;
in vec2 a_texCoord;
#endif

in vec2 a_position;

out vec2 vUv;

void main() {
	#ifdef DRAW_MODE_line
	// Calculate a rotated ("tight") bounding box around the two pen points.
	// Yes, we're doing this 6 times (once per vertex), but on actual GPU hardware,
	// it's still faster than doing it in JS combined with the cost of uniformMatrix4fv.

	// Expand line bounds by sqrt(2) / 2 each side-- this ensures that all antialiased pixels
	// fall within the quad, even at a 45-degree diagonal
	vec2 position = a_position;
	float expandedRadius = (a_lineThicknessAndLength.x * 0.5) + 1.4142135623730951;

	// The X coordinate increases along the length of the line. It's 0 at the center of the origin point
	// and is in pixel-space (so at n pixels along the line, its value is n).
	vUv.x = mix(0.0, a_lineThicknessAndLength.y + (expandedRadius * 2.0), a_position.x) - expandedRadius;
	// The Y coordinate is perpendicular to the line. It's also in pixel-space.
	vUv.y = ((a_position.y - 0.5) * expandedRadius) + 0.5;

	position.x *= a_lineThicknessAndLength.y + (2.0 * expandedRadius);
	position.y *= 2.0 * expandedRadius;

	// 1. Center around first pen point
	position -= expandedRadius;

	// 2. Rotate quad to line angle
	vec2 pointDiff = a_penPoints.zw;
	// Ensure line has a nonzero length so it's rendered properly
	// As long as either component is nonzero, the line length will be nonzero
	// If the line is zero-length, give it a bit of horizontal length
	pointDiff.x = (abs(pointDiff.x) < epsilon && abs(pointDiff.y) < epsilon) ? epsilon : pointDiff.x;
	// The "normalized" vector holds rotational values equivalent to sine/cosine
	// We're applying the standard rotation matrix formula to the position to rotate the quad to the line angle
	// pointDiff can hold large values so we must divide by u_lineLength instead of calling GLSL's normalize function:
	// https://asawicki.info/news_1596_watch_out_for_reduced_precision_normalizelength_in_opengl_es
	vec2 normalized = pointDiff / max(a_lineThicknessAndLength.y, epsilon);
	position = mat2(normalized.x, normalized.y, -normalized.y, normalized.x) * position;

	// 3. Translate quad
	position += a_penPoints.xy;

	// 4. Apply view transform
	position *= 2.0 / u_stageSize;
	gl_Position = vec4(position, 0, 1);

	v_lineColor = a_lineColor;
	v_lineThickness = a_lineThicknessAndLength.x;
	v_lineLength = a_lineThicknessAndLength.y;
	v_penPoints = a_penPoints;
	#elif defined(DRAW_MODE_background)
	gl_Position = vec4(a_position * 2.0, 0, 1);
	#else
	gl_Position = u_projectionMatrix * u_modelMatrix * vec4(a_position, 0, 1);
	vUv = a_texCoord;
	#endif
}
    `

  //this is the __example__ shader
  const fragmentShaderSource = `
#version 300 es
#ifdef GL_ES
precision mediump float;
#endif

in vec2 vUv;
out vec4 fragColor;
uniform sampler2D tDiffuse;
uniform float time;

uniform vec4 u_color;

void main() {
  fragColor = texture(tDiffuse, vUv) * u_color;
  fragColor.rg *= sin(time);
}