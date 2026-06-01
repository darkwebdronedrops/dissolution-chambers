shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float particle_count : hint_range(100.0, 1000.0) = 300.0;
uniform float spread : hint_range(0.1, 2.0) = 1.0;
uniform float speed : hint_range(0.1, 3.0) = 1.5;
uniform float purple_intensity : hint_range(0.5, 1.0) = 0.85;
uniform float fade_start : hint_range(0.0, 1.0) = 0.6;

// Simple pseudo-random
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5, 0.5);
    vec2 from_center = uv - center;
    float dist = length(from_center);
    
    // Break into particles based on progress
    float break_threshold = smoothstep(0.0, 0.4, progress);
    float reform_threshold = smoothstep(0.6, 1.0, progress);
    
    // Particle noise
    vec2 grid_uv = uv * particle_count;
    vec2 grid_id = floor(grid_uv);
    vec2 grid_fract = fract(grid_uv);
    
    float rand = hash(grid_id);
    float rand2 = hash(grid_id + vec2(1.0, 0.0));
    
    // Particle movement: outward during break, inward during reform
    float phase = 0.0;
    if (progress < 0.5) {
        phase = progress * 2.0; // 0 to 1 during break
    } else {
        phase = 1.0 - (progress - 0.5) * 2.0; // 1 to 0 during reform
    }
    
    vec2 particle_offset = vec2(
        sin(rand * 6.283 + TIME * speed) * spread * phase,
        cos(rand2 * 6.283 + TIME * speed * 0.7) * spread * phase
    );
    
    // Distance from original position
    float particle_dist = length(grid_fract - 0.5 + particle_offset);
    float particle_alpha = 1.0 - smoothstep(0.0, 0.5, particle_dist);
    
    // Purple color with bioluminescent gold accents
    vec3 deep_purple = vec3(0.29, 0.055, 0.243); // #4A0E4E
    vec3 mid_purple = vec3(0.545, 0.278, 0.537); // #8B4789
    vec3 gold = vec3(1.0, 0.84, 0.0); // #FFD700
    vec3 soft_lilac = vec3(0.847, 0.643, 0.847); // #D8A4D8
    
    // Color shifts based on particle randomness
    vec3 base_color = mix(deep_purple, mid_purple, rand);
    base_color = mix(base_color, gold, rand2 * 0.3 * phase);
    base_color = mix(base_color, soft_lilac, hash(grid_id + vec2(0.0, 1.0)) * 0.2);
    
    // Overall purple wash
    vec3 wash_color = mix(vec3(0.0), deep_purple, purple_intensity * progress);
    
    // Particle visibility
    float particle_visibility = particle_alpha * (1.0 - smoothstep(fade_start, 1.0, progress));
    
    if (progress < 0.05) {
        // Pre-dissolution: barely visible
        COLOR = vec4(deep_purple, 0.0);
    } else if (progress < 0.5) {
        // Breaking phase: particles form, wash intensifies
        COLOR = vec4(mix(wash_color, base_color, particle_visibility), progress * 0.9);
    } else if (progress < 0.95) {
        // Void phase: particles drift, wash deepens
        COLOR = vec4(mix(wash_color, base_color, particle_visibility * 0.5), 0.8 + rand * 0.15);
    } else {
        // Reform phase: fade to transparent
        COLOR = vec4(wash_color, 1.0 - reform_threshold);
    }
}
