#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Intersect.cginc"
#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_PostEffectBake.cginc"
#include "Assets/Qc_Rendering/Shaders/Savage_Shadowmap.cginc"



//#include "Assets/Qc_Rendering/Shaders/Savage_VolumeSampling.cginc"

// ****************** Intersections

#if RT_MOTION_TRACING
	#define PATH_LENGTH 2
#elif _qc_IGNORE_SKY
	#define PATH_LENGTH 2
#else
	#define PATH_LENGTH 4
#endif

float3 modifyDirectionWithRoughnessFast(in float3 normal, in float3 refl, in float roughness, in float4 seed) {

	return lerp(normalize(normal + seed.wzx), refl, step(seed.y, roughness));

	float2 r = seed.wx;//hash2(seed);

	float nyBig = step(.5, refl.y);

	float3  uu = normalize(cross(refl, float3(nyBig, 1. - nyBig, 0.)));
	float3  vv = cross(uu, refl);

	float a = roughness * roughness;

	float rz = sqrt(abs((1.0 - seed.y) / clamp(1. + (a - 1.) * seed.y, .00001, 1.)));
	float ra = sqrt(abs(1. - rz * rz));
	float preCmp = 6.28318530718 * seed.x;
	float rx = ra * cos(preCmp);
	float ry = ra * sin(preCmp);
	float3 rr = float3(rx * uu + ry * vv + rz * refl);

	return normalize(rr + (seed.xyz - 0.5) * 0.1);
}

void ResampleBakedLight(inout float3 col, inout float3 gatherLight, float3 pos, float3 normal, float roughness)
{
	float RESAMPLE_COEFFICIENT = 
	#if _qc_IGNORE_SKY
	1
	#else
	0.33
	#endif
	;

	#if !qc_NO_VOLUME  && RT_TO_CUBEMAP //&& _qc_IGNORE_SKY
		float outOfBounds;
		float4 postEffect = SampleDirectPostEffects(pos, outOfBounds);
		float ao = postEffect.a; 
		col.rgb *= lerp(1, postEffect.rgb, (1-ao) * (1-outOfBounds));

		float gatheredDiffuse = 0;

		gatheredDiffuse += postEffect.rgb * ao * (1-outOfBounds);
		gatheredDiffuse += RESAMPLE_COEFFICIENT * SampleVolume_CubeMap_Internal(pos, normal);
		gatherLight += col.rgb * gatheredDiffuse;// * roughness;

	#endif
}

void ResampleBakedLight_Specular(inout float3 col, inout float3 gatherLight, float3 pos, float3 normal, float3 rd, float roughness)
{
	float RESAMPLE_COEFFICIENT_SPECULAR = 
	#if _qc_IGNORE_SKY
	1
	#else
	0.33
	#endif
	;

	#if !qc_NO_VOLUME && _qc_IGNORE_SKY && RT_TO_CUBEMAP
		//float angle = abs(dot(rd, normal));// perpendicular would mean no specular

		gatherLight += col.rgb * RESAMPLE_COEFFICIENT_SPECULAR * SampleVolume_CubeMap_Internal(pos, reflect(rd, normal));// * (1-angle);// * RESAMPLE_COEFFICIENT_SPECULAR;// * (1-roughness);
	#endif
}

void ResampleBakedLight_Cascade(float3 col, inout float3 gatherLight, float3 randomPoint, float3 rd, float weight)
{
	#if !qc_NO_VOLUME && RT_TO_CUBEMAP
		gatherLight += col.rgb * weight * SampleVolume_CubeMap_Internal(randomPoint, rd);
	#endif
}

float GetSpecularAttenuation(float3 rd, float3 normal, float roughness, float3 lightDir)
{
	float3 halfDir = normalize(rd + lightDir.xyz);
	float NdotH = max(0.01, dot(normal, halfDir));
	float lh = dot(lightDir.xyz, halfDir);

	float specularTerm = roughness * roughness;
	float d = NdotH * NdotH * (specularTerm - 1.0) + 1.00001;
	float normalizationTerm = roughness * 4.0 + 2.0;
	specularTerm /= (d * d) * max(0.1, lh * lh) * normalizationTerm;

	return specularTerm;
}




float4 render(in float3 ro, in float3 rd, in float4 seed) 
{
	const float MIN_DIST = 0.000001;

	float3 albedo, normal;
	float3 col = 1;
	float3 gatherLight = 0;
	float roughness, type;

	bool isFirst = true;
	float distance = MAX_DIST_EDGE;
	float4 mat = 0;

	float BOUNCED_DIRECT_LIGHT_MULTIPLIER = 1;
	float CELL_SIZE = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;
	float FADE_RAY_AT = CELL_SIZE * 0.5;
	float rayHitDist = FADE_RAY_AT;
	
	float3 directional = GetDirectional();
	

	for (int i = 0; i < PATH_LENGTH; ++i)
	{
		
		float3 res = worldhit(ro, rd, float2(MIN_DIST, MAX_DIST_EDGE), normal, mat);
		roughness = mat.a;
		albedo = mat.rgb;
		type = res.z;
		// res.x =
		// res.y = dist
		// res.z = material

		rayHitDist = res.y;

		if (res.z <= 0.)
		{
			#if _qc_IGNORE_SKY
				return float4(0,0,0, distance);
			#endif

			float3 skyCol = getSkyColor(rd);
			return float4(col * lerp(skyCol * _qc_AmbientColor.rgb, _qc_AmbientColor.rgb, qc_LayeredFog_Alpha)
			, distance);
		}

		//float rndPointWeight = 1/(1+rayHitDist * seed.x * 0.75 / CELL_SIZE);

	//	float3 randomLinePoint = ro + rd * rayHitDist * seed.x * 0.75;

		ro += rd * rayHitDist;

	//	col *= smoothstep(0, FADE_RAY_AT, rayHitDist);





			/*
#define LAMBERTIAN 0.
#define METAL 1.
#define DIELECTRIC 2.


#define GLASS 3.
#define EMISSIVE 4.
#define SUBTRACTIVE 5.*/



UNITY_BRANCH
if (type < DIELECTRIC + 0.5)
{
			UNITY_BRANCH
			if (type < LAMBERTIAN + 0.5) 
			{ 
				
				#if !_qc_IGNORE_SKY
				if (_qc_SunVisibility > 0)
				{
					float attenuationDiffuse = smoothstep(0, 1, dot(qc_SunBackDirection.xyz, normal));
		
                    float shadow = 1;
                   // GetSunShadowsAttenuation(ro); // is the problem

					if (shadow > 0.2 && Raycast(ro + normal*0.01, qc_SunBackDirection.xyz + (seed.zyx-0.5)*0.3, float2(0.0001, MAX_DIST_EDGE)))
					{
						shadow = 0;
					}  
					
					float3 lightDir = -qc_SunBackDirection.xyz;
					float specularTerm = GetSpecularAttenuation( rd,  normal, roughness, lightDir);
					float3 bouncedLight = specularTerm * BOUNCED_DIRECT_LIGHT_MULTIPLIER + roughness * albedo * attenuationDiffuse;
					gatherLight.rgb += col.rgb * bouncedLight * shadow * directional ;
				}
				#endif

				ResampleBakedLight_Specular(col, gatherLight, ro, normal, rd, roughness);
				col *= albedo;
				ResampleBakedLight(col, gatherLight, ro, normal, roughness); 
			

				rd = cosWeightedRandomHemisphereDirection(normal, seed);

			}
			else
			if (type < METAL + 0.5) 
			{ 
				col *= albedo;

				#if !_qc_IGNORE_SKY
				if (_qc_SunVisibility > 0)
				{
                    float shadow = 1; //GetSunShadowsAttenuation(ro);

					if (shadow > 0.2 && Raycast(ro + normal*0.01, qc_SunBackDirection.xyz + (seed.zyx-0.5)*0.3, float2(0.0001, MAX_DIST_EDGE)))
					{
						shadow = 0;
					}

					float3 lightDir = -qc_SunBackDirection.xyz;

					float specularTerm = GetSpecularAttenuation(rd,  normal, roughness, lightDir);

					float3 bouncedLight = specularTerm * BOUNCED_DIRECT_LIGHT_MULTIPLIER;

					gatherLight.rgb += col.rgb * bouncedLight * shadow * directional ;
				}
				#endif
				
				//#if _qc_IGNORE_SKY
				// Is Metal
				col *= albedo;

				ResampleBakedLight_Specular(col, gatherLight, ro, normal, rd, roughness);
				ResampleBakedLight(col, gatherLight, ro, normal, roughness); 
				
				rd = modifyDirectionWithRoughness(normal, reflect(rd, normal), roughness, seed);

				
			} else  //if (type < DIELECTRIC + 0.5)
			{
			
					ro += rd * 0.25;// +(seed.zyx - 0.5) * 0.1;
					normal = -normal;
					
					rd = cosWeightedRandomHemisphereDirection(normal, seed);

					#if !_qc_IGNORE_SKY
					if (_qc_SunVisibility > 0) 
					{
						float toSUn = smoothstep(0, -1, dot(qc_SunBackDirection.xyz, normal));

						float shadow = 1; //GetSunShadowsAttenuation(ro);

						if (shadow > 0.2 && Raycast(ro + normal*0.001, qc_SunBackDirection.xyz + (seed.zyx-0.5)*0.3, float2(0.0001, MAX_DIST_EDGE)))
						{
							shadow = 0;
						}

						gatherLight.rgb += col.rgb * albedo * directional * (1 + toSUn * 16) * shadow;
					}
					#endif
			}
} 
else  
{
//#if RT_USE_DIELECTRIC

			UNITY_BRANCH
			if (type < GLASS + 0.5) //DIELECTRIC + GLASS
			{ 
				float3 normalOut;
				float3 refracted = 0;
				float ni_over_nt, cosine, reflectProb = 1.;
				float theDot = dot(rd, normal);

				if (theDot > 0.) {
					normalOut = -normal;
					ni_over_nt = 1.4;
					cosine = theDot;
					cosine = sqrt(max(0.001, 1. - (1.4*1.4) - (1.4*1.4)*cosine*cosine));
				}
				else {
					normalOut = normal;
					ni_over_nt = 1. / 1.4;
					cosine = -theDot;
				}

				float modRf = modifiedRefract(rd, normalOut, ni_over_nt, refracted);

				float r0 = (1. - ni_over_nt) / (1. + ni_over_nt);
				reflectProb = 
					lerp(reflectProb, FresnelSchlickRoughness(cosine, r0 * r0, roughness), modRf);

				rd = (seed.b) <= reflectProb ? reflect(rd, normal) : refracted;
				rd = modifyDirectionWithRoughnessFast(-normalOut, rd, roughness, seed);
			}
			else if (type < EMISSIVE + 1) // EMISSIVE
			{
				return float4(col * albedo + gatherLight, distance);
			} else // Subtractive
			{
				ro += 0.001 * rd;
				float dist = worldhitSubtractive(ro, rd, float2(MIN_DIST, MAX_DIST_EDGE));
				if (dist < MAX_DIST)
				{
					ro += (dist + 0.001) * rd;
				}
			}
		}
	}

	return float4( gatherLight, distance);
}