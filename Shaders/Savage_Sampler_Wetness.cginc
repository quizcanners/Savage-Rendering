#ifndef QC_SAV_WET
#define QC_SAV_WET

uniform float4 _qc_BloodColor;
uniform float _qc_RainVisibility;

float GetRain(float3 worldPos, float3 normal, float3 rawNormal, float shadow)
{
#if _qc_IGNORE_SKY
	return 0;
#endif

	if (_qc_RainVisibility == 0)
	{
		return 0;
	}

	float vis = _qc_RainVisibility;

	float3 avgNormal = normalize(rawNormal + normal);

	vis*= shadow;
	/*
#	if !_DYNAMIC_OBJECT && !_SIMPLIFY_SHADER
	vis *= RaycastStaticPhisics(worldPos + avgNormal * 0.5, float3(0, 1, 0), float2(0.0001, MAX_DIST_EDGE)) ? 0 : 1;
#	endif*/

	vis *= (1 + sharpstep(0, 1, avgNormal.y))* 0.5;

	return vis;
}

float ApplyBlood(float4 mask, inout float water, inout float3 tex, inout float4 madsMap, float displacement)
{
	float bloodAmount = mask.r - displacement;
	
	const float SHOW_RED_AT = 0.01;
	//const float SHOW_BLOOD_AT = 0.4;

	float showRed = sharpstep(SHOW_RED_AT, SHOW_RED_AT + 0.1 + water, bloodAmount);

	water += showRed * mask.r;

	float3 bloodColor = _qc_BloodColor.rgb *(1 - 0.5 * sharpstep(0, 1, water));//(0.75 + showRed * 0.25);

	tex.rgb = lerp(tex.rgb, bloodColor, showRed);

	madsMap.r = lerp(madsMap.r, 0.98, showRed );

	return showRed;
}

const float SHOW_WET = 0.2;
const float WET_DARKENING = 0.5;

void ModifyColorByWetness(inout float3 col, float water, float smoothness)
{
#if _REFLECTIVITY_METAL
	return;
#endif
	float darken = 	WET_DARKENING;// * (1-smoothness);
	col *= (1-darken) + sharpstep(SHOW_WET + 0.01, SHOW_WET, water) * darken;
}

void ModifyColorByWetness(inout float3 col, float water, float smoothness, float4 dirtColor)
{
	col = lerp(col, dirtColor.rgb, sharpstep(0, 2, water) * dirtColor.a);

	ModifyColorByWetness(col, water, smoothness);
	//float darken = WET_DARKENING * (1-smoothness);

	//col *= (1-darken) + sharpstep(SHOW_WET + 0.01, SHOW_WET, water) * darken;
}

float4 GetRainNoise(float3 worldPos, float displacement, float up, float rain)
{
#if !_SIMPLIFY_SHADER && !_DYNAMIC_OBJECT

	if (_qc_RainVisibility == 0)
	{
		return 0.5;
	}

	worldPos.y *= 0.1;

	float4 noise = Noise3D(worldPos * 0.5 + worldPos.yzx * 0.1 + float3(0, _Time.x * 4 + (up - displacement) * 0.2, 0));
	noise = lerp(0.5, noise, (1 + rain) * 0.5);

	return noise;

#else
	return 0.5;
#endif

	
}

float ApplyWater(inout float water, float rain, inout float ao, float displacement, inout float4 madsMap, float4 noise)
{
	const float FLATTEN_AT = 0.9;
	const float WET_GAP = FLATTEN_AT - SHOW_WET;

	water += rain;
	water = max(0, water - displacement * ao);
	float dynamicLevel = FLATTEN_AT + (2 * noise.b - 1) * 0.5 * WET_GAP;
	madsMap.ra = lerp(madsMap.ra, float2(0, 0.975), sharpstep(SHOW_WET, FLATTEN_AT, water));
	float flattenSurface = sharpstep(dynamicLevel - 0.01 - noise.r
	, dynamicLevel, water);
	madsMap.gb = lerp(madsMap.gb, float2(1, 1), flattenSurface);
	ao = lerp(ao, 1, flattenSurface);
	return flattenSurface;
}


#endif
