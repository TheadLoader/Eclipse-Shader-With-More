#define CIRRUS_LAYER 4 [cite: 1]
#define ALTOSTRATUS_LAYER 3 [cite: 1]
#define CUMULONIMBUS_LAYER 2 [cite: 1]
#define LARGECUMULUS_LAYER 1 [cite: 1]
#define SMALLCUMULUS_LAYER 0 [cite: 1]

// --- Core Cloud Shape Logic ---
float getCloudShape(int LayerIndex, int LOD, in vec3 position, float minHeight, float maxHeight){
    float coverage = 0.0; [cite: 28]
    float shape = 0.0; [cite: 29]
    float largeCloud = 0.0; [cite: 29]
    float smallCloud = 0.0; [cite: 29]

    vec3 samplePos = position*vec3(0.25, 0.005, 0.25); [cite: 29]
    float tallness = maxHeight - minHeight; [cite: 30]
    float posToMax = maxHeight - position.y; [cite: 30]

    switch (LayerIndex){
        #ifdef CloudLayer3
        case CIRRUS_LAYER: {
            coverage = SC_cirrus.x; [cite: 31]
            vec2 coord = position.zx + 6.0*cloud_movement; [cite: 31]
            vec2 curl = curl2D(0.00002 * coord) * 0.5 + curl2D(0.00018 * coord) * 0.125; [cite: 32]
            
            largeCloud = texture(noisetex, (position.xz + cloud_movement*2.0)/80000. * CloudLayer3_scale).b; [cite: 33]
            smallCloud = texture(noisetex, (0.000005 / CloudLayer3_scale) * coord).r; [cite: 33]
            
            float detail_amplitude = 0.3; [cite: 33]
            float detail_frequency = 0.00002; [cite: 34]
            float curl_strength = 1.3; [cite: 34]
            
            // Increased to 5 iterations for more realistic fine detail 
            for (int i = 0; i < 5; ++i) { 
                float detail = texture(noisetex, coord * detail_frequency + curl * curl_strength).r; [cite: 34]
                smallCloud -= detail * detail_amplitude; [cite: 35]
                detail_amplitude *= 0.5; [cite: 35]
                detail_frequency *= 4.0; [cite: 35]
                curl_strength *= 2.7; [cite: 35]
            }
            shape = min(max(coverage - smallCloud, 0.0)/sqrt(coverage), 1.0); [cite: 36]
            return shape;
        }
        #endif

        #ifdef CloudLayer0
        case SMALLCUMULUS_LAYER: {
            coverage = SC_smallCumulus.x + Rain_coverage * rainStrength; [cite: 45]
            largeCloud = texture(noisetex, (samplePos.xz + cloud_movement)/5000.0).b; [cite: 46]
            smallCloud = 1.0-texture(noisetex, (samplePos.xz - cloud_movement)/500.0).r; [cite: 46]
            smallCloud = abs(largeCloud-0.6) + smallCloud*smallCloud; [cite: 47]
            shape = min(max(coverage - smallCloud,0.0)/sqrt(coverage),1.0); [cite: 47]
            break; 
        }
        #endif
    }

    // Shaping & Boundary Clamping [cite: 48, 51]
    float bottomShape = 1.0-pow(1.0-min(max(position.y-minHeight,0.0) / 25.0, 1.0), 5.0); [cite: 49]
    float topShape = min(max(posToMax,0.0) / max(tallness,1.0),1.0); [cite: 50]
    topShape = min(exp(-0.5 * (1.0-topShape)), 1.0-pow(1.0-topShape,5.0)); [cite: 51]
    shape = max((shape - 1.0) + topShape * bottomShape, 0.0); [cite: 51]

    // Realistic Edge Erosion [cite: 52, 61]
    if(shape > 0.001){
        float erodeAmount = 0.8; // Increased for fluffier edges 
        float erosion = (1.0 - densityAtPos(samplePos * CloudLayer0_detail)) * sqrt(1.0 - shape); [cite: 57]
        return max(shape - erosion * erodeAmount, 0.0); [cite: 61]
    } 
    return 0.0; [cite: 61]
}

// --- Advanced Lighting Logic ---
vec3 getCloudLighting(int LayerIndex, float shape, float shapeFaded, float sunShadowMask, vec3 directLightCol, vec3 directLightCol2, float indirectShadowMask, vec3 indirectLightCol, vec3 rayPosition, float backScatterPhase, vec4 phaseLevels, float backScatterPhase2, vec4 phaseLevels2){
    
    // Deeper Beer-Lambert Law for density 
    float beerCoef = -6.0; 
    float powder = min(exp(beerCoef*exp(beerCoef*shapeFaded)) * 3.5, 1.0); [cite: 127]

    float expBeer = 6.28 * exp((beerCoef-1.0)*sunShadowMask); [cite: 130]
    vec3 directScattering = expBeer * directLightCol * (powder * backScatterPhase); [cite: 131, 128]
    
    // Increased Indirect Contrast (Shadow Deepening) [cite: 132]
    vec3 indirectScattering = indirectLightCol * mix(1.0, exp2(-8.0*shape), indirectShadowMask); 
    
    return indirectScattering + directScattering; [cite: 132]
}
