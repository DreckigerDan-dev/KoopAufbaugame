shader_type spatial;
// Schmutz/Grime-Overlay (2026-08-04, Nutzerfrage "shader statt mehr Blender-
// Detail") — reiner Zusatz-Pass (siehe World._apply_grime_overlay(),
// next_pass), verändert die eigentliche Material-Farbe NICHT, legt nur
// fleckige dunkle Patches drüber. Objekt-lokale Vertex-Position statt
// Welt-Position für Noise UND Höhen-Falloff, damit das Muster unabhängig
// von der Platzierung auf der Karte ist und "unten dunkler" (Verwitterung
// sammelt sich am Boden) relativ zur eigenen Objekthöhe funktioniert, egal
// wie hoch ein Gebäude ist oder wo es auf der Karte steht.
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform float noise_scale : hint_range(0.05, 2.0) = 0.35;
uniform float dirt_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec3 dirt_color : source_color = vec3(0.07, 0.06, 0.05);
uniform float height_falloff : hint_range(0.0, 3.0) = 1.2;
uniform float seed = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973) + seed);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

void fragment() {
	float n = value_noise(local_pos * noise_scale);
	n = smoothstep(0.35, 0.85, n);
	// Höhen-Maske über den tatsächlichen Höhenbereich DIESES Meshes
	// (min/max lassen sich im Shader nicht kennen, deshalb einfacher
	// exponentieller Falloff ab lokalem Y=0 statt einer festen Objekthöhe
	// — bei einem an der Basis modellierten Asset (Y=0 unten, siehe
	// World._model_min_y()) ergibt das trotzdem "unten stärker, oben
	// schwächer").
	float height_mask = clamp(1.0 - local_pos.y * height_falloff * 0.15, 0.0, 1.0);
	ALBEDO = dirt_color;
	ALPHA = n * dirt_strength * height_mask;
}
