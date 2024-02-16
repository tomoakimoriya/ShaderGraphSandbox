#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

struct ToonLightingData {
    // Position and orientation
    float3 positionWS;
    float3 normalWS;
    float3 viewDirectionWS;
    float4 shadowCoord;

    // Surface attributes
    float3 albedo;
    float3 ambientcolor;
    float3 specularcolor;
    float smoothness;
    float3 rimcolor;
    float rimamount;
    float rimthreshold;
};

// Translate a [0, 1] smoothness value to an exponent 
float GetSmoothnessPower(float rawSmoothness) {
    return exp2(10 * rawSmoothness + 1);
}

#ifndef SHADERGRAPH_PREVIEW
float3 CustomLightHandling(ToonLightingData d, Light light) {

    //float3 radiance = light.color * light.shadowAttenuation;

    //float diffuse = saturate(dot(d.normalWS, light.direction));
    //float specularDot = saturate(dot(d.normalWS, normalize(light.direction + d.viewDirectionWS)));
    //float specular = pow(specularDot, GetSmoothnessPower(d.smoothness)) * diffuse;

    //float3 color = d.albedo * radiance * (diffuse + specular);

    float3 normal = normalize(d.normalWS);
    float NdotL = dot(light.direction, normal);

    float shadow = light.shadowAttenuation;

    float lightIntensity = smoothstep(0, 0.01, NdotL * shadow);
    float3 toonlight = lightIntensity * light.color;
    
    float3 viewDir = normalize(d.viewDirectionWS);
    float3 halfVector = normalize(light.direction + viewDir);
    float NdotH = dot(normal, halfVector);
    
    float specularIntensity = pow(NdotH * lightIntensity, d.smoothness * d.smoothness);
    float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity);
    float3 specular = specularIntensitySmooth * d.specularcolor;
    
    float3 rimDot = 1 - dot(viewDir, normal);
    float rimIntensity = rimDot * pow(NdotL, d.rimthreshold);
    rimIntensity = smoothstep(d.rimamount - 0.01, d.rimamount + 0.01, rimIntensity);
    float3 rim = rimIntensity * d.rimcolor; 

    float3 color = (d.ambientcolor + toonlight + specular + rim) * d.albedo;

    return color;
}
#endif

float3 CalculateToonLighting(ToonLightingData d) {
#ifdef SHADERGRAPH_PREVIEW
    // In preview, estimate diffuse + specular
    float3 lightDir = float3(0.5, 0.5, 0);
    float intensity = saturate(dot(d.normalWS, lightDir)) + pow(saturate(dot(d.normalWS, normalize(d.viewDirectionWS + lightDir))), GetSmoothnessPower(d.smoothness));
    return d.albedo * intensity;
#else
    // Get the main light. Located in URP/ShaderLibrary/Lighting.hlsl
    Light mainLight = GetMainLight(d.shadowCoord, d.positionWS, 1);

    float3 color = 0;
    // Shade the main light
    color += CustomLightHandling(d, mainLight);

    return color;
#endif
}

void CalculateToonLighting_float(float3 Position, float3 Normal, float3 Albedo, float3 ViewDirection, float Smoothness, 
    float3 AmbientColor, float3 SpecularColor, float3 RimColor, float RimAmount, float RimThreshold,
    out float3 Color) {

    ToonLightingData d;
    d.positionWS = Position;
    d.normalWS = Normal;
    d.viewDirectionWS = ViewDirection;
    d.albedo = Albedo;
    d.smoothness = Smoothness;
    d.ambientcolor = AmbientColor;
    d.specularcolor = SpecularColor;
    d.rimcolor = RimColor;
    d.rimamount = RimAmount;
    d.rimthreshold = RimThreshold;

#ifdef SHADERGRAPH_PREVIEW
    // In preview, there's no shadows or bakedGI
    d.shadowCoord = 0;
#else
    // Calculate the main light shadow coord
    // There are two types depending on if cascades are enabled
    float4 positionCS = TransformWorldToHClip(Position);
    #if SHADOWS_SCREEN
        d.shadowCoord = ComputeScreenPos(positionCS);
    #else
        d.shadowCoord = TransformWorldToShadowCoord(Position);
    #endif
#endif


    Color = CalculateToonLighting(d);
}

#endif