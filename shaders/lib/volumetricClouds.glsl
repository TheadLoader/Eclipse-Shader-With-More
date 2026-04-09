#define CIRRUS_LAYER 4
#define ALTOSTRATUS_LAYER 3
#define CUMULONIMBUS_LAYER 2
#define LARGECUMULUS_LAYER 1
#define SMALLCUMULUS_LAYER 0

#ifndef VOXY_PROGRAM
uniform float thunderStrength;
uniform int worldDay;
uniform int worldTime;
uniform float moonElevation;
uniform float worldTimeSmooth;
uniform float cloudTime;
#endif

// --- Movement & Lightning Timers ---
#if CLOUD_MOVEMENT_TYPE == 0
    float cloud_movement = (worldTimeSmooth + mod(worldDay,100)*24000.0) / 24.0 * Cloud_Speed;
#else
    float cloud_movement = cloudTime * Cloud_Speed;
#endif

float lightningFlashTimer = floor(frameTimeCounter * 11.0);
float randomSeed = fract(sin(dot(vec2(lightningFlashTimer), vec2(12.9898,78.233))) * 43758.5453);
float lightningFlash = mix(0.1, 2.5, randomSeed);

#if CUMULONIMBUS > 0
    float lightningDuration = 0.75 + CUMULONIMBUS_LIGHTNING_DELAY;
    float lightningTimer = floor(frameTimeCounter / lightningDuration);
    float timeInLightning = (frameTimeCounter / (lightningDuration) - lightningTimer) * lightningDuration;
    float lightningFade = smoothstep(0.6, 0.22, timeInLightning);
#endif

// --- Core Density Logic ---
float densityAtPos(in vec3 pos){
    pos /= 18.;
    pos.xz *= 0.5;
    vec3 p = floor(pos);
    vec3 f = fract(pos);
    vec2 uv = p.xz + f.xz + p.y * vec2(0.0,193.0);
    vec2 coord = uv / 512.0;
    vec2 xy = texture(noisetex, coord).yx;
    return mix(xy.r, xy.g, f.y);
}

// --- Enhanced Shape Function (With Shearing) ---
float getCloudShape(int LayerIndex, int LOD, in vec3 position, float minHeight, float maxHeight){
    float coverage = 0.0;
    float shape = 0.0;
    float tallness = maxHeight - minHeight;
    float heightPercent = clamp((position.y - minHeight) / tallness, 0.0, 1.0);

    // BETTER IDEA: Wind Shear (Clouds stretch horizontally as they go higher)
    vec3 windOffset = vec3(heightPercent * 120.0, 0.0, 0.0);
    vec3 samplePos = (position + windOffset) * vec3(0.25, 0.005, 0.25);

    switch (LayerIndex){
        case CIRRUS_LAYER: {
            coverage = SC_cirrus.x;
            vec2 coord = position.zx + 6.0 * cloud_movement;
            float detail = texture(noisetex, coord * 0.00002).r;
            shape = smoothstep(1.0 - coverage, 1.0, detail);
            return shape;
        }
        case SMALLCUMULUS_LAYER: {
            coverage = SC_smallCumulus.x + rainStrength * 0.2;
            float base = texture(noisetex, (samplePos.xz + cloud_movement)/5000.0).b;
            float erode = texture(noisetex, (samplePos.xz - cloud_movement)/500.0).r;
            shape = max(0.0, base - erode * 0.4);
            shape = smoothstep(1.0 - coverage, 1.1 - coverage, shape);
            break;
        }
    }

    // Dynamic Vertical Profile: Flat bottoms, puffy mid, tapered tops
    float verticalProfile = smoothstep(0.0, 0.15, heightPercent) * smoothstep(1.0, 0.7, heightPercent);
    shape *= verticalProfile;

    // Advanced Erosion Logic
    if(shape > 0.001){
        float erosion = (1.0 - densityAtPos(samplePos * 2.0)) * sqrt(1.0 - shape);
        shape = max(shape - erosion * 0.7, 0.0);
    }
    return shape;
}

// --- Advanced Lighting (Silver-Lining & Lightning) ---
vec3 getCloudLighting(int LayerIndex, float shape, vec3 rayPosition, vec3 sunVec, vec3 sunCol, vec3 moonCol){
    vec3 lightVec = sunElevation > 0.0 ? sunVec : -sunVec;
    vec3 lightCol = sunElevation > 0.0 ? sunCol : moonCol;

    // Mie Scattering (The "Silver Lining" effect)
    float cosTheta = dot(normalize(rayPosition - cameraPosition), lightVec);
    float silverLining = pow(clamp(cosTheta * 0.5 + 0.5, 0.0, 1.0), 10.0) * 3.0;
    
    // Beer-Lambert with Powder Effect
    float beer = exp(-shape * 4.0);
    float powder = 1.0 - exp(-shape * 2.0);
    vec3 mainLight = lightCol * beer * powder * (1.0 + silverLining);

    // BETTER IDEA: Internal Lightning Glow
    #if CUMULONIMBUS > 0
    float dToLightning = length(rayPosition - (lightningBoltPosition.xyz - cameraPosition));
    float lightningScattering = exp(-dToLightning * 0.02) * lightningFade * 15.0;
    mainLight += vec3(0.7, 0.8, 1.0) * lightningScattering * shape;
    #endif

    // Ambient/Indirect light
    vec3 ambient = lightCol * 0.15 * (1.0 - shape);
    
    return mainLight + ambient;
}

// --- Main Raymarch (Truncated for Clarity - Place inside your loop) ---
// This uses your existing totalAbsorbance logic but injects the new lighting.
/*
    for(int i=0; i<samples; i++) {
        float shape = getCloudShape(LARGECUMULUS_LAYER, 0, rayPos, minH, maxH);
        if(shape > 0.01) {
            vec3 lighting = getCloudLighting(LARGECUMULUS_LAYER, shape, rayPos, sunVector, sunScattering, moonScattering);
            color += lighting * totalAbsorbance * shape;
            totalAbsorbance *= exp(-shape * densityStep);
        }
        rayPos += rayDir;
    }
*/
