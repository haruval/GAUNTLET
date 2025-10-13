shader_type canvas_item;

/* explicit screen sampler (Godot 4+) */
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

/* ===== Retro core (no CRT, no jitter) ===== */
group_uniforms resolution_and_colors;
uniform bool  scale_resolution = true;
uniform int   target_resolution_scale : hint_range(1,32) = 8;   // bigger = chunkier pixels
uniform bool  change_color_depth = true;
uniform int   target_color_depth  : hint_range(1,8) = 2;        // 2 bits/channel = heavy posterize
uniform bool  dithering = false;

/* simple grading */
group_uniforms grading;
uniform float brightness : hint_range(-1.0,1.0) = 0.0;
uniform float contrast   : hint_range(0.5,3.0)  = 1.25;
uniform float saturation : hint_range(0.0,2.0)  = 0.9;

/* film grain (kept subtle) */
group_uniforms film_fx;
uniform bool  noise_enabled        = false;
uniform float noise_strength       : hint_range(0.0,0.5) = 0.03;

/* 🔴 chromatic aberration (ON and stronger by default) */
group_uniforms aberration;
uniform bool  chromab_enabled = true;
uniform float chromab_pixels  : hint_range(0.0,8.0) = 3.5;  // RB shift in pixels (cranked)

/* optional gradient recolor (hue swap) */
group_uniforms gradient_recoloring;
uniform bool       enable_recolor  = false;
uniform sampler2D  to_gradient     : hint_default_black, filter_nearest;

/* optional 4-color palette lock (extreme look) */
group_uniforms palette_lock;
uniform bool  palette_enabled = false;
uniform vec3  pal0 = vec3(0.07, 0.09, 0.12);  // dark
uniform vec3  pal1 = vec3(0.24, 0.45, 0.68);  // mid
uniform vec3  pal2 = vec3(0.68, 0.85, 0.94);  // light
uniform vec3  pal3 = vec3(0.95, 0.98, 1.00);  // highlight

/* ---------- helpers ---------- */

int dither4x4(ivec2 p) {
    const int m[16] = int[16](
        -4,  0, -3,  1,
         2, -2,  3, -1,
        -3,  1, -4,  0,
         3, -1,  2, -2
    );
    return m[(p.y % 4) * 4 + (p.x % 4)];
}

vec3 rgb2hsv(vec3 rgb){
    float r=rgb.r,g=rgb.g,b=rgb.b;
    float cmax=max(r,max(g,b));
    float cmin=min(r,min(g,b));
    float d=cmax-cmin;
    float h=0.0;
    if(d>0.0){
        if(cmax==r)      h=mod((g-b)/d,6.0);
        else if(cmax==g) h=((b-r)/d)+2.0;
        else             h=((r-g)/d)+4.0;
        h*=60.0;
    }
    float s=(cmax>0.0)?(d/cmax):0.0;
    return vec3(h,s,cmax);
}

vec3 hsv2rgb(vec3 hsv){
    float h=hsv.x,s=hsv.y,v=hsv.z;
    float c=v*s;
    float x=c*(1.0-abs(mod(h/60.0,2.0)-1.0));
    float m=v-c;
    vec3 rgb=vec3(0.0);
    if      (h< 60.0) rgb=vec3(c,x,0.0);
    else if (h<120.0) rgb=vec3(x,c,0.0);
    else if (h<180.0) rgb=vec3(0.0,c,x);
    else if (h<240.0) rgb=vec3(0.0,x,c);
    else if (h<300.0) rgb=vec3(x,0.0,c);
    else              rgb=vec3(c,0.0,x);
    return rgb+vec3(m);
}

vec3 apply_grading(vec3 col,float br,float ct,float sat){
    col += br;
    col  = (col - 0.5) * ct + 0.5;
    float luma = dot(col, vec3(0.2126,0.7152,0.0722));
    col  = mix(vec3(luma), col, sat);
    return clamp(col, 0.0, 1.0);
}

vec3 nearest_palette(vec3 c){
    vec3 p0=pal0, p1=pal1, p2=pal2, p3=pal3;
    float d0=distance(c,p0), d1=distance(c,p1), d2=distance(c,p2), d3=distance(c,p3);
    vec3 best=p0; float bd=d0;
    if(d1<bd){best=p1; bd=d1;}
    if(d2<bd){best=p2; bd=d2;}
    if(d3<bd){best=p3; bd=d3;}
    return best;
}

/* ---------- main ---------- */

void fragment(){
    vec2 viewport_size = vec2(textureSize(SCREEN_TEXTURE, 0));
    ivec2 ipx = ivec2(FRAGCOORD.xy);

    // pixel snap
    vec2 uv;
    if (scale_resolution && target_resolution_scale > 1) {
        ivec2 low = ipx / target_resolution_scale;
        vec2 samplep = (vec2(low) + 0.5) * float(target_resolution_scale);
        uv = samplep / viewport_size;
    } else {
        uv = SCREEN_UV;
    }

    // sample scene (strong chromatic aberration)
    vec3 color;
    if (chromab_enabled && chromab_pixels > 0.0) {
        vec2 center_uv = vec2(0.5);
        vec2 dir = normalize(uv - center_uv + 1e-6);
        vec2 px_uv = dir * (chromab_pixels / viewport_size);
        float r = texture(SCREEN_TEXTURE, uv + px_uv).r;
        float g = texture(SCREEN_TEXTURE, uv).g;
        float b = texture(SCREEN_TEXTURE, uv - px_uv).b;
        color = vec3(r,g,b);
    } else {
        color = texture(SCREEN_TEXTURE, uv).rgb;
    }

    // optional hue remap
    if (enable_recolor) {
        vec3 hsv = rgb2hsv(color);
        float hue01 = hsv.x / 360.0;
        vec3 map_rgb = texture(to_gradient, vec2(hue01, 0.5)).rgb;
        hsv.x = rgb2hsv(map_rgb).x;
        color = hsv2rgb(hsv);
    }

    // grading
    color = apply_grading(color, brightness, contrast, saturation);

    // subtle grain
    if (noise_enabled && noise_strength > 0.0) {
        float n = fract(sin(dot(vec2(ipx) + TIME * 121.7, vec2(12.9898,78.233))) * 43758.5453);
        n = n * 2.0 - 1.0;
        color = clamp(color + n * noise_strength, 0.0, 1.0);
    }

    // quantize + ordered dithering
    ivec3 ci = ivec3(round(color * 255.0));
    if (dithering) {
        ci = clamp(ci + ivec3(dither4x4(ipx)), ivec3(0), ivec3(255));
    }

    vec3 quant;
    if (change_color_depth) {
        ci >>= (8 - target_color_depth);
        quant = vec3(ci) / float(1 << target_color_depth);
    } else {
        quant = vec3(ci) / 255.0;
    }

    // optional 4-color palette crush
    if (palette_enabled) {
        quant = nearest_palette(quant);
    }

    COLOR = vec4(quant, 1.0);
}