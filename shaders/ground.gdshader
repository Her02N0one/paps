shader_type spatial;
// Optional: Use 'render_mode unshaded;' if you want it to glow exactly 
// like Shadertoy without being affected by 3D scene lighting.
// render_mode unshaded;

// Exposed parameters you can tweak in the material inspector
uniform vec2 uv_scale = vec2(3.0, 3.0);
uniform float time_scale = 1.0;

float colormap_red(float x) {
    if (x < 0.0) {
        return 54.0 / 255.0;
    } else if (x < 20049.0 / 82979.0) {
        return (829.79 * x + 54.51) / 255.0;
    } else {
        return 1.0;
    }
}

float colormap_green(float x) {
    if (x < 20049.0 / 82979.0) {
        return 0.0;
    } else if (x < 327013.0 / 810990.0) {
        return (8546482679670.0 / 10875673217.0 * x - 2064961390770.0 / 10875673217.0) / 255.0;
    } else if (x <= 1.0) {
        return (103806720.0 / 483977.0 * x + 19607415.0 / 483977.0) / 255.0;
    } else {
        return 1.0;
    }
}

float colormap_blue(float x) {
    if (x < 0.0) {
        return 54.0 / 255.0;
    } else if (x < 7249.0 / 82979.0) {
        return (829.79 * x + 54.51) / 255.0;
    } else if (x < 20049.0 / 82979.0) {
        return 127.0 / 255.0;
    } else if (x < 327013.0 / 810990.0) {
        return (792.02249341361393720147485376583 * x - 64.364790735602331034989206222672) / 255.0;
    } else {
        return 1.0;
    }
}

vec4 colormap(float x) {
    return vec4(colormap_red(x), colormap_green(x), colormap_blue(x), 1.0);
}

float rand(vec2 n) { 
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 p){
    vec2 ip = floor(p);
    vec2 u = fract(p);
    u = u*u*(3.0-2.0*u);

    float res = mix(
        mix(rand(ip),rand(ip+vec2(1.0,0.0)),u.x),
        mix(rand(ip+vec2(0.0,1.0)),rand(ip+vec2(1.0,1.0)),u.x),u.y);
    return res*res;
}

// Godot accepts matrix construction using column vectors
const mat2 mtx = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));

// Passing 'time' as an argument is safer for custom functions in Godot
float fbm(vec2 p, float time)
{
    float f = 0.0;
    f += 0.500000*noise( p + time ); p = mtx*p*2.02;
    f += 0.031250*noise( p ); p = mtx*p*2.01;
    f += 0.250000*noise( p ); p = mtx*p*2.03;
    f += 0.125000*noise( p ); p = mtx*p*2.01;
    f += 0.062500*noise( p ); p = mtx*p*2.04;
    f += 0.015625*noise( p + sin(time) );

    return f/0.96875;
}

float pattern(in vec2 p, float time)
{
    return fbm(p + fbm(p + fbm(p, time), time), time);
}

void fragment()
{
    // Use the mesh's UV coordinates instead of screen space
    vec2 uv = UV * uv_scale;
    float scaled_time = TIME * time_scale;
    
    float shade = pattern(uv, scaled_time);
    vec4 color_output = colormap(shade);
    
    ALBEDO = color_output.rgb;
    
    // The original script mapped 'shade' to the alpha channel.
    // If you want transparency on your mesh, set your material's 
    // transparency mode to Alpha and uncomment the line below:
    // ALPHA = shade;
}