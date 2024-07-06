#ifndef QC_VOL_SAMP
#define QC_VOL_SAMP

uniform float qc_VolumeAlpha;

uniform sampler2D _RayMarchingVolume;

uniform float4 _RayMarchingVolumeVOLUME_POSITION_N_SIZE;
uniform float4 _RayMarchingVolumeVOLUME_H_SLICES;
uniform float4 _RayMarchingVolumeVOLUME_POSITION_OFFSET; // For preserving previous bake data

uniform float4x4 qc_RtxVolumeWorldToLocal;
uniform float4x4 qc_RtxVolumeLocalToWorld;
uniform float qc_USE_DYNAMIC_RTX_VOLUME;


// SDF
uniform float Qc_SDF_Visibility;
uniform Texture2D Qc_SDF_Volume;
uniform SamplerState sampler_Qc_SDF_Volume;
uniform float4 Qc_SDF_VOLUME_POSITION_N_SIZE;
uniform float4 Qc_SDF_VOLUME_H_SLICES;

uniform float4x4  Qc_SDF_WorldToLocal;
uniform float4x4  Qc_SDF_LocalToWorld;
uniform float Qc_SDF_USE_DYNAMIC_RTX_VOLUME;


// Direct Light
uniform sampler2D Qc_DirectLights_Volume;
uniform float4 Qc_Direct_VOLUME_POSITION_N_SIZE;
uniform float4 Qc_Direct_VOLUME_H_SLICES;

uniform float4x4  Qc_Direct_WorldToLocal;
uniform float4x4  Qc_Direct_LocalToWorld;
uniform float Qc_Direct_USE_DYNAMIC_RTX_VOLUME;

// Cube Light
uniform float4 Qc_CubeLight_VOLUME_POSITION_N_SIZE;
uniform float4 Qc_CubeLight_VOLUME_H_SLICES;

uniform float4x4  Qc_CubeLight_WorldToLocal;
uniform float4x4  Qc_CubeLight_LocalToWorld;
uniform float Qc_CubeLight_USE_DYNAMIC_RTX_VOLUME;


// ******************************* COMMON VOLUME METHODS

float GetAlphaToHideForUvBorders(float2 uv) 
{
	float2 offUv = uv - 0.5;
	offUv = pow(offUv,4);
	float len = offUv.x + offUv.y;
	return smoothstep(0.0625, 0.04, len);
}

float3 volumeUVtoWorld(float2 uv, float4 VOLUME_POSITION_N_SIZE, float4 VOLUME_H_SLICES) 
{

	// H Slices:
	//hSlices, w * 0.5f, 1f / w, 1f / hSlices

	float hy = floor(uv.y*VOLUME_H_SLICES.x);
	float hx = floor(uv.x*VOLUME_H_SLICES.x);

	float2 xz = uv * VOLUME_H_SLICES.x;

	xz.x -= hx;
	xz.y -= hy;

	xz =  (xz*2.0 - 1.0) *VOLUME_H_SLICES.y;

	//xz *= VOLUME_H_SLICES.y*2;
	//xz -= VOLUME_H_SLICES.y;

	float h = hy * VOLUME_H_SLICES.x + hx;

	float3 bsPos = float3(xz.x, h, xz.y) * VOLUME_POSITION_N_SIZE.w;

	float3 worldPos = VOLUME_POSITION_N_SIZE.xyz + bsPos;

	return worldPos;
}

float4 InVolumePositionToSamplingUVs(float3 bsPos, float4 VOLUME_H_SLICES, out float upperFraction, out float outOfBounds)
{
	float2 posToUvUnclamped = (bsPos.xz + VOLUME_H_SLICES.y) * VOLUME_H_SLICES.z;

	bsPos.xz = saturate(posToUvUnclamped);

	float maxHeight = VOLUME_H_SLICES.x * VOLUME_H_SLICES.x - 1;

	float h = clamp(bsPos.y, 0, maxHeight);

	float hIn = smoothstep(25, 0, -bsPos.y) * smoothstep(0, 10, maxHeight - bsPos.y);

	outOfBounds = 1 - GetAlphaToHideForUvBorders(posToUvUnclamped) * hIn;

	bsPos.xz *= VOLUME_H_SLICES.w;

	float sectorY = floor(h * VOLUME_H_SLICES.w);
	float sectorX = floor(h - sectorY * VOLUME_H_SLICES.x);
	float2 sectorUnclamped = float2(sectorX, sectorY) * VOLUME_H_SLICES.w;


	float4 volumeUvs;

	volumeUvs.xy = float4(saturate(sectorUnclamped) + bsPos.xz, 0, 0);

	h += 1;

	sectorY = floor(h * VOLUME_H_SLICES.w);
	sectorX = floor(h - sectorY * VOLUME_H_SLICES.x);
	sectorUnclamped = float2(sectorX, sectorY) * VOLUME_H_SLICES.w;

	volumeUvs.zw = saturate(sectorUnclamped) + bsPos.xz;

	upperFraction = frac(h);

	return volumeUvs;
}

float4 SampleVolume_Internal(sampler2D volume, float4 uvs, float upperFraction)
{
	float4 bake = tex2Dlod(volume, float4(uvs.xy, 0, 0));
	float4 bakeUp = tex2Dlod(volume, float4(uvs.zw, 0, 0));
	return lerp(bake, bakeUp, upperFraction);
}



// *************************************** SDF Volume Methods

float4 WorldPosTo_SDF_VolumeUV(float3 worldPos, out float upperFraction, out float outOfBounds)
{
	float size = Qc_SDF_VOLUME_POSITION_N_SIZE.w;

	float3 bsPos; 
	
	if (Qc_SDF_USE_DYNAMIC_RTX_VOLUME > 0.5)
	{
		float3 localPos = mul(Qc_SDF_WorldToLocal, float4(worldPos,1)).xyz;
		bsPos = localPos / size;
	} 
	else 
	{
		bsPos = (worldPos.xyz - Qc_SDF_VOLUME_POSITION_N_SIZE.xyz) / size;
	}

	return InVolumePositionToSamplingUVs(bsPos, Qc_SDF_VOLUME_H_SLICES, upperFraction, outOfBounds);
}

float4 SampleSDF(float3 pos, out float outOfBounds)
{
	if (Qc_SDF_Visibility == 0)
	{
		outOfBounds = 1;
		return 0;
	}

	float upperFraction;
	float4 uvs = WorldPosTo_SDF_VolumeUV(pos, upperFraction, outOfBounds);
	
	float4 bake = Qc_SDF_Volume.SampleLevel(sampler_Qc_SDF_Volume, uvs.xy, 0);
	float4 bakeUp = Qc_SDF_Volume.SampleLevel(sampler_Qc_SDF_Volume, uvs.zw, 0);
	return lerp(bake, bakeUp, upperFraction);
	//return SampleVolume_Internal(Qc_SDF_Volume, uvs, upperFraction);
}

// ************************************** Direct Volume Methods

float4 WorldPosTo_Direct_VolumeUV(float3 worldPos, out float upperFraction, out float outOfBounds)
{
	float size = Qc_Direct_VOLUME_POSITION_N_SIZE.w;

	float3 bsPos; 
	
	if (Qc_Direct_USE_DYNAMIC_RTX_VOLUME > 0.5)
	{
		float3 localPos = mul(Qc_Direct_WorldToLocal, float4(worldPos,1)).xyz;
		bsPos = localPos / size;
	} 
	else 
	{
		bsPos = (worldPos.xyz - Qc_Direct_VOLUME_POSITION_N_SIZE.xyz) / size;
	}

	return InVolumePositionToSamplingUVs(bsPos, Qc_Direct_VOLUME_H_SLICES, upperFraction, outOfBounds);
}

float4 SampleDirectPostEffects(float3 pos, out float outOfBounds)
{
	float upperFraction;
	float4 uvs = WorldPosTo_Direct_VolumeUV(pos, upperFraction, outOfBounds);
	return SampleVolume_Internal(Qc_DirectLights_Volume, uvs, upperFraction);
}

// ************************************* Cube Light Methods

float4 WorldPosTo_CubeLight_VolumeUV(float3 worldPos, out float upperFraction, out float outOfBounds)
{
	//Qc_CubeLight_VOLUME_POSITION_N_SIZE
	float size = Qc_CubeLight_VOLUME_POSITION_N_SIZE.w;

	float3 bsPos; 
	
	if (Qc_CubeLight_USE_DYNAMIC_RTX_VOLUME > 0.5)
	{
		float3 localPos = mul(Qc_CubeLight_WorldToLocal, float4(worldPos,1)).xyz;
		bsPos = localPos / size;
	} 
	else 
	{
		bsPos = (worldPos.xyz - Qc_CubeLight_VOLUME_POSITION_N_SIZE.xyz) / size;
	}

	return InVolumePositionToSamplingUVs(bsPos, Qc_CubeLight_VOLUME_H_SLICES, upperFraction, outOfBounds);
}

float3 volumeUVto_CubeMap_World(float2 uv) 
{
	if (Qc_CubeLight_USE_DYNAMIC_RTX_VOLUME > 0)
	{
		float4 zeroPos = float4(0,0,0, Qc_CubeLight_VOLUME_POSITION_N_SIZE.w);
		float3 localPos = volumeUVtoWorld(uv, zeroPos, Qc_CubeLight_VOLUME_H_SLICES);

		return mul(Qc_CubeLight_LocalToWorld, float4(localPos,1)).xyz;
	}

	return volumeUVtoWorld(uv, Qc_CubeLight_VOLUME_POSITION_N_SIZE, Qc_CubeLight_VOLUME_H_SLICES);
}

float4 Sample_CubeLight_Volume(sampler2D tex, float3 worldPos, out float outOfBounds)
{
	float upperFraction;
	float4 uvs = WorldPosTo_CubeLight_VolumeUV(worldPos, upperFraction, outOfBounds);
	return SampleVolume_Internal(tex, uvs, upperFraction);
}

// ******************************* BAKED LIGHT VOLUMES TRANSFORM

float3 volumeUVtoWorld(float2 uv) 
{
	if (qc_USE_DYNAMIC_RTX_VOLUME > 0)
	{
		float4 zeroPos = float4(0,0,0, _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w);
		float3 localPos = volumeUVtoWorld(uv, zeroPos, _RayMarchingVolumeVOLUME_H_SLICES);

		return mul(qc_RtxVolumeLocalToWorld, float4(localPos,1)).xyz;
	}

	return volumeUVtoWorld(uv, _RayMarchingVolumeVOLUME_POSITION_N_SIZE, _RayMarchingVolumeVOLUME_H_SLICES);
}

float4 WorldPosToVolumeUV(float3 worldPos, float4 VOLUME_POSITION_N_SIZE, float4 VOLUME_H_SLICES, out float upperFraction, out float outOfBounds)
{
	float size = VOLUME_POSITION_N_SIZE.w;

	float3 bsPos; 
	
	if (qc_USE_DYNAMIC_RTX_VOLUME > 0.5)
	{
		float3 localPos = mul(qc_RtxVolumeWorldToLocal, float4(worldPos,1)).xyz;
		bsPos = localPos / size;
	} 
	else 
	{
		bsPos = (worldPos.xyz - VOLUME_POSITION_N_SIZE.xyz) / size;
	}

	return InVolumePositionToSamplingUVs(bsPos, VOLUME_H_SLICES, upperFraction, outOfBounds);
}

float4 SampleVolume(sampler2D volume, float3 worldPos, float4 VOLUME_POSITION_N_SIZE, float4 VOLUME_H_SLICES, out float outOfBounds)
{
	float upperFraction;
	float4 uvs = WorldPosToVolumeUV(worldPos, VOLUME_POSITION_N_SIZE, VOLUME_H_SLICES, upperFraction, outOfBounds);
	return SampleVolume_Internal(volume, uvs, upperFraction);
}

float4 SampleVolume(float3 pos, out float outOfBounds)
{
	#if !qc_NO_VOLUME
		float4 bake = SampleVolume(_RayMarchingVolume, pos
			, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
			, _RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

	if (qc_VolumeAlpha<0.99)
	{	
		float directOOb;
		float3 directSample = SampleDirectPostEffects(pos, directOOb).rgb;

		bake.rgb = lerp(bake.rgb, directSample.rgb, (1-qc_VolumeAlpha)*(1-directOOb));
	}

		return bake;
	#endif

	outOfBounds = 1;
	return 0;
	
}

float4 SampleVolume(sampler2D tex, float3 pos, out float outOfBounds)
{
	float4 bake = SampleVolume(tex, pos
		, _RayMarchingVolumeVOLUME_POSITION_N_SIZE
		, _RayMarchingVolumeVOLUME_H_SLICES, outOfBounds);

	return bake;
}


#endif