#ifndef QC_SAV_SMP
#define QC_SAV_SMP

#include "PrimitivesScene_Sampler.cginc"
#include "Savage_Geometry_cg.cginc"
#include "Sampler_TopDownLight.cginc"
#include "inc/RayMathHelpers.cginc"
#include "Savage_Sampler_Wetness.cginc"

uniform float _qc_Sun_Atten;

uniform float4 _qc_PointLight_Position;
uniform float4 _qc_PointLight_Color;

// Helper Functions

inline float SampleContactAO(float3 pos, float3 normal)
{
	#if !qc_NO_VOLUME
		float outsideVolume;
		float4 scene = SampleSDF(pos , outsideVolume);
		float coef = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;
		return lerp(sharpstep(-2 * coef,2 * coef, scene.a + dot(normal, scene.xyz)*2 * coef),1, outsideVolume);
	#else 
		return 1;
	#endif
}

void ApplyBottomFog(inout float3 col, float3 worldPos, float viewDirY)
{

	#if _qc_IGNORE_SKY
		return;
	#endif

	if (_qc_FogVisibility == 0)
	{
		return;
	}

	float bottomFog = sharpstep(-0.35, -0.02, viewDirY);

	float3 diff = worldPos - _WorldSpaceCameraPos.xyz;

	float fromCamera = length(diff);

	float dist01 =  sharpstep(0,1, fromCamera * _ProjectionParams.w) ;

	float minFog = sharpstep(50, 150, fromCamera) * sharpstep(fromCamera*0.2, 0, worldPos.y);

	float byHeight = sharpstep(0, -300, worldPos.y);

	float3 fogCol = GetAvarageAmbient(normalize(diff));

	col.rgb = lerp(col.rgb, fogCol, sharpstep(0,1,minFog * 0.5 + byHeight + dist01 * bottomFog * bottomFog) * _qc_FogVisibility);// sharpstep(0, 1, 1)); // dist01* bottomFog + minFog + byHeight));
	
}

float3 SampleAmbientLight(float3 pos, out float ao)
{
		float outOfBounds;
		float3 baked = SampleVolume(_RayMarchingVolume, pos, outOfBounds).rgb;
						
		float valid = (1 - outOfBounds);

		baked =lerp(GetAmbientLight(), baked, valid);

		float3 reflectedTopDown = 0;
		ao = TopDownSample(pos, reflectedTopDown);
		baked += reflectedTopDown * 0.1; 
		baked *= ao;
		return baked;
}

float ApplyTopDownLightAndShadow(float2 topdownUv, float3 normal, float4 bumpMap, float3 worldPos, float gotVolume, float fresnel, inout float4 bake)
{
	float smoothness = bumpMap.b;

	float2 offset = normal.xz * _RayTracing_TopDownBuffer_Position.w;

	//float2 offUv = topdownUv - 0.5;
//	gotVolume = (1 - sharpstep(0.2, 0.25, length(offUv * offUv)));

	float4 topDown = tex2D(_RayTracing_TopDownBuffer, topdownUv + offset * 0.2
	); // *(0.2 + smoothness));
	float4 topDownRefl = tex2Dlod(_RayTracing_TopDownBuffer, float4(topdownUv + offset * (1 + 8 * smoothness)
		, 0, 0));

	TOP_DOWN_ALPHA(topDownVisible, worldPos, topdownUv)

	//float topDownVisible = gotVolume * (1 - fresnel * 0.5) * sharpstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - worldPos.y));
	topDown *= topDownVisible;
	topDownRefl *= topDownVisible;
	float ambientBlock = max(0.25f, 1 - topDown.a);
	//shadow *= ambientBlock;

	float3 light = (topDown.rgb + topDownRefl.rgb) * bumpMap.a;

	float3 mix = light.gbr + light.brg;

	bake *= ambientBlock;
	bake.rgb += light + mix * 0.2f;

	return ambientBlock;
}

float ApplyTopDownLightAndShadow(float2 topdownUv, float3 normal, float3 worldPos, float gotVolume, inout float4 bake)
{

	float4 bumpMap = float4(0.5, 0.5, 1, 0.2);
	float fresnel = 1;

	return ApplyTopDownLightAndShadow(topdownUv, normal, bumpMap, worldPos, gotVolume, fresnel, bake);
}

// Lighting

void MixInSpecular(inout float3 ambCol, float3 reflectionColor, float3 tex, float metal, float reflectivity, float fresnel)
{
	reflectionColor *= lerp(0.5, tex, metal);
	ambCol= lerp(ambCol, reflectionColor, reflectivity);
}

void MixInSpecular_Plastic(inout float3 ambCol, float3 reflectionColor, float reflectivity)
{
	ambCol= lerp(ambCol, reflectionColor, reflectivity);
}

void MixInSpecular_Layer(inout float3 ambCol, float3 reflectionColor, float3 tex, float metal, float specular, float fresnel, float layer)
{
	ambCol *= (1 - metal * 0.9);

	reflectionColor *= lerp(0.5, tex, metal) * 2;

	float showReflection = lerp(specular, 0.05 + fresnel * 0.5, layer);

	ambCol= lerp(ambCol, reflectionColor, showReflection);
}

float AttenuationFromAo(float ao, float3 normal)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	return 1; //sharpstep(1 - ao, 1.5 - ao * 0.5, dot(normal, _WorldSpaceLightPos0.xyz));
}

float GetFresnel_FixNormal(inout float3 normal, float3 rawNormal, float3 viewDir)
{
	float normDiff = dot(normal, viewDir);

//	normal = lerp(normal, perp, normError);

	return pow((1 - saturate(normDiff)), 5);// * (1-normError);
} 

float GetFresnel(float3 normal, float3 viewDir)
{
	return pow((1 - saturate(dot(normal, viewDir))), 5);
} 

float GetSpecular_Plastic(float madsA, float fresnel)
{
	float byFresnel =  pow(madsA,3);
	byFresnel += (1 - byFresnel) * fresnel; 
	return 0.025 + byFresnel * 0.95;
}

float GetSpecular_Metal(float madsA, float fresnel)
{
	return 0.025 + (0.75 + madsA * 0.25) * 0.95;
}

float GetSpecular_Layer(float madsA, float fresnel)
{
	return madsA * fresnel; //0.025 + (0.75 + madsA * 0.25) * 0.95;
}

float GetSpecular(float madsA, float fresnel, float metal)
{
	//float byFresnel =  pow(madsA,3);
	//byFresnel += (1 - byFresnel) * fresnel; 
	return 0.025 + lerp(madsA * (1 + (1-madsA)*fresnel), 0.75 + madsA * 0.25, metal) * 0.95;
}

float3 Savage_GetDirectional_Opaque(inout float shadow, float ao, float3 normal, float3 worldPos)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	float angle =dot(qc_SunBackDirection.xyz, normal);

	/*angle = 1-max(0, angle);
	angle = pow(angle, 0.1+ao * _qc_Sun_Atten);
	float atten = 1-angle;*/
	
	float atten = //saturate(angle);// 
		smoothstep(1, -0.5 + ao*0.5, angle); //

	atten = pow(atten, 0.1 + _qc_Sun_Atten); // shadow

	atten = 1-atten; // light

	/*
	float atten = _qc_Sun_Atten;
	float aoObscuring = sharpstep(1,0,atten) * ao * 0.95;
	angle = smoothstep(aoObscuring,1,angle);
	angle = 1-pow(1-angle,1 + (1-ao) * 2 * atten);
	float blowout = atten * 0.2;
	atten = (angle * (1-blowout) + blowout);
	*/


	return GetDirectional() * shadow * atten;
}

float3 GetVolumeSamplingPosition(float3 worldPos, float3 rawNormal)
{
	return worldPos;
	// + rawNormal.xyz * _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.5;
}

float GetDirectionalSpecular(float3 normal, float3 viewDir, float gloss)
{
#if _SIMPLIFY_SHADER || _qc_IGNORE_SKY
	return 0;
#endif

	//if (_qc_SunVisibility == 0 || qc_KWS_FogAlpha > 0.9)
		//return 0;

	//viewDir.y = -viewDir.y;

	gloss *= 0.95;

	float roughness = pow(1 - gloss, 2);

	float3 lightDir = _WorldSpaceLightPos0.xyz;

	//lightDir.y = -lightDir.y;

	float3 halfDir = normalize(viewDir + lightDir);
	float NdotH = max(0.01, dot(normal, halfDir));
	float lh = dot(lightDir, halfDir);

	float specularTerm = roughness * roughness;

	float d = NdotH * NdotH * (specularTerm - 1.0) + 1.00001;
	float normalizationTerm = roughness * 4.0 + 2.0;

	specularTerm /= (d * d) * max(0.1, lh * lh) * normalizationTerm;
	return specularTerm; //* (1- qc_KWS_FogAlpha);// * (1 + pow(gloss, 8) * 64);
}

float ApplySubSurface(inout float3 col, float4 subSkin, float3 volSamplePos, float3 viewDir, float specular, float rawFresnel, float shadow)
{
	//float4 skin = tex2D(_SkinMask, i.texcoord.xy);
	float subSurface = subSkin.a * (2 - rawFresnel) * 0.5;

	#if !_qc_IGNORE_SKY
		float sun = 1 / (0.1 + 1000 * sharpstep(1, 0, dot(_WorldSpaceLightPos0.xyz, -viewDir)));
	#endif

	col.rgb += subSurface * subSkin.rgb * 

	#if !_qc_IGNORE_SKY
		GetDirectional() * (1 + sun) * shadow
	#else
		SampleVolume_CubeMap(volSamplePos, -viewDir)
	#endif
	;

	return subSurface;
}

void CheckParallax(inout float2 uv, inout float4 madsMap, sampler2D _SpecularMap, float3 tViewDir, float amount, inout float displacement)
{
#	if _PARALLAX

	uv += tViewDir.xy * (displacement - 0.5) * 1 * amount;

	madsMap = tex2D(_SpecularMap, uv);
	displacement = madsMap.b;
	uv += tViewDir.xy * (displacement - 0.5) * 0.5 * amount;

	madsMap = tex2D(_SpecularMap, uv);
	displacement = madsMap.b;

#	endif
}

float3 GetTranslucent_Sun(float3 refractedRay)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	if (_qc_SunVisibility == 0)
		return 0;

	float translucentSun =  sharpstep(0.8,1, dot(_WorldSpaceLightPos0.xyz, refractedRay));
	return translucentSun * 4 * GetDirectional(); 
}

float4 SampleTopDown_Ambient(float2 topdownUv, float3 normal, float3 worldPos)
{
	float2 offset = normal.xz * _RayTracing_TopDownBuffer_Position.w;

	topdownUv += offset * 0.2;

	TOP_DOWN_SAMPLE_LIGHT(topDown, topdownUv);
	TOP_DOWN_ALPHA(gotVolume, worldPos, topdownUv)

	topDown *= gotVolume;
	float ambientBlock = max(0.25f, 1 - topDown.a);

	return float4(topDown.rgb, ambientBlock);
}

float4 SampleTopDown_Specular(float2 topdownUv, float3 reflected, float3 worldPos, float3 rawNormal, float specular)
{
	float2 offset = reflected.xz * _RayTracing_TopDownBuffer_Position.w;

	topdownUv += offset * (1 + specular * specular * 4);

	float4 topDown = tex2D(_RayTracing_TopDownBuffer, topdownUv);

	TOP_DOWN_ALPHA(gotVolume, worldPos, topdownUv)


	topDown *= gotVolume;
	//topDown.rgb *= sharpstep(1, 0, abs(rawNormal.y)); // vertical normal will often result in light leaing trough walls

	float ambientBlock = max(0.2f, 1 - topDown.a);

	return float4(topDown.rgb, ambientBlock);
}

/*

#define GET_AMBIENT_OCCLUSION(ao)\
float ao =1; \
#if _AO_SEPARATE\
#	if _AMBIENT_IN_UV2\
ao = tex2D(_OcclusionMap, i.texcoord1.xy).r;\
#	else\
ao = tex2D(_OcclusionMap, uv).r;\
#endif \
#elif _AO_MADS\
ao = madsMap.g;\
#else\
ao = 1;\
#endif\*/
#endif
