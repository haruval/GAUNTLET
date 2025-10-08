/*shader_type canvas_item;

// Declare the screen texture explicitly (Godot 4+)
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

uniform bool scale_resolution = true;
uniform int target_resolution_scale : hint_range(1,8) = 3;

void fragment() {
    // Compute viewport size without VIEWPORT_SIZE
    vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;

    ivec2 ipx = ivec2(FRAGCOORD.xy);
    vec2 uv;

    if (scale_resolution && target_resolution_scale > 1) {
        ivec2 low = ipx / target_resolution_scale;
        vec2 sample_px = (vec2(low) + 0.5) * float(target_resolution_scale);
        uv = sample_px / viewport_size;
    } else {
        uv = SCREEN_UV;
    }

    COLOR = texture(SCREEN_TEXTURE, uv);
}*/

///////////////////////////////////
//try new stuff here
///////////////////////////////////

shader_type canvas_item;

/* Explicit screen sampler for Godot 4+ */
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

/* ===== Exaggerated retro look (strong defaults) ===== */
group_uniforms resolution_and_colors;
uniform bool  scale_resolution = true;
uniform int   target_resolution_scale : hint_range(1,12) = 6;   // bigger = chunkier pixels

uniform bool  change_color_depth = true;
uniform int   target_color_depth  : hint_range(1,8) = 3;        // 3 bits/channel
uniform bool  dithering = true;

group_uniforms grading;
uniform float brightness : hint_range(-1.0,1.0) = 0.0;
uniform float contrast   : hint_range(0.5,2.0)  = 1.35;
uniform float saturation : hint_range(0.0,2.0)  = 0.9;

group_uniforms crt_styling;
uniform bool  scanlines_enabled = true;
uniform float scanline_strength : hint_range(0.0,1.0) = 0.25;
uniform float scanline_frequency : hint_range(0.5,8.0) = 2.0;

uniform bool  vignette_enabled = true;
uniform float vignette_strength : hint_range(0.0,1.0) = 0.35;
uniform float vignette_softness : hint_range(0.1,1.5) = 0.8;

uniform bool  chromab_enabled = true;
uniform float chromab_pixels  : hint_range(0.0,4.0) = 1.5;      // RB shift in *pixels*

group_uniforms gradient_recoloring;
uniform bool       enable_recolor = false;
uniform sampler2D  to_gradient    : hint_default_black, filter_nearest;

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
    col+=br;
    col=(col-0.5)*ct+0.5;
    float luma=dot(col,vec3(0.2126,0.7152,0.0722));
    col=mix(vec3(luma),col,sat);
    return clamp(col,0.0,1.0);
}

float vignette_mask(vec2 uv,float strength,float softness,vec2 viewport_size){
    vec2 aspect=vec2(1.0,viewport_size.x/viewport_size.y);
    vec2 p=(uv-0.5)*aspect;
    float d=length(p);
    float edge=0.5;
    float v=1.0-smoothstep(edge-softness,edge+softness,d);
    return mix(1.0,v,strength);
}

/* ---------- main ---------- */

void fragment(){
    // Robust viewport size (works across Godot 4.x)
    vec2 viewport_size = vec2(textureSize(SCREEN_TEXTURE, 0));

    ivec2 ipx = ivec2(FRAGCOORD.xy);

    // Pixel snapping for chunky resolution
    vec2 uv;
    if (scale_resolution && target_resolution_scale > 1) {
        ivec2 low     = ipx / target_resolution_scale;
        vec2  samplep = (vec2(low) + 0.5) * float(target_resolution_scale);
        uv = samplep / viewport_size;
    } else {
        uv = SCREEN_UV;
    }

    // Chromatic aberration: shift R/B by N pixels along radial direction
    vec3 color;
    if (chromab_enabled && chromab_pixels > 0.0) {
        vec2 center_uv = vec2(0.5);
        vec2 dir = normalize(uv - center_uv + 1e-6);       // avoid NaN at exact center
        vec2 px_uv = dir * (chromab_pixels / viewport_size);
        float r = texture(SCREEN_TEXTURE, uv + px_uv).r;
        float g = texture(SCREEN_TEXTURE, uv).g;
        float b = texture(SCREEN_TEXTURE, uv - px_uv).b;
        color = vec3(r, g, b);
    } else {
        color = texture(SCREEN_TEXTURE, uv).rgb;
    }

    // Optional hue remap (swap hue using 1D gradient)
    if (enable_recolor) {
        vec3 hsv = rgb2hsv(color);
        float hue01 = hsv.x / 360.0;
        vec3 mapped_rgb = texture(to_gradient, vec2(hue01, 0.5)).rgb;
        vec3 mapped_hsv = rgb2hsv(mapped_rgb);
        hsv.x = mapped_hsv.x;
        color = hsv2rgb(hsv);
    }

    // Filmic pop
    color = apply_grading(color, brightness, contrast, saturation);

    // Posterize + ordered dithering
    ivec3 ci = ivec3(round(color * 255.0));
    if (dithering) {
        ci += ivec3(dither4x4(ipx));
        ci = clamp(ci, ivec3(0), ivec3(255));
    }

    vec3 quant;
    if (change_color_depth) {
        ci >>= (8 - target_color_depth);
        quant = vec3(ci) / float(1 << target_color_depth);
    } else {
        quant = vec3(ci) / 255.0;
    }

    // CRT scanlines (row-based darkening)
    if (scanlines_enabled && scanline_strength > 0.0) {
        float s = 0.5 + 0.5 * sin(float(ipx.y) * 3.14159265 * scanline_frequency);
        quant *= mix(1.0, s, scanline_strength);
    }

    // Vignette
    if (vignette_enabled && vignette_strength > 0.0) {
        float v = vignette_mask(SCREEN_UV, vignette_strength, vignette_softness, viewport_size);
        quant *= v;
    }

    COLOR = vec4(quant, 1.0);
}