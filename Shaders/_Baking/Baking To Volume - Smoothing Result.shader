Shader "QcRendering/Baker/Smoothing Result"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_PreviousTex("Albedo (RGB)", 2D) = "clear" {}
	}

	SubShader
	{
		Tags
		{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}

		ColorMask RGBA
		Cull Off
		ZWrite Off
		ZTest Off

		Pass{

			CGPROGRAM

			#define _qc_AMBIENT_SIMULATION
			#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"
			#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Intersect.cginc"
			#include "UnityCG.cginc"


			#pragma multi_compile ___ RT_TO_CUBEMAP
			#pragma multi_compile ___ _qc_IGNORE_SKY

			#pragma vertex vert
			#pragma fragment frag

			struct v2f {
				float4 pos : 		SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float2 noiseUV :	TEXCOORD1;
			};

			v2f vert(appdata_full v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.texcoord = v.texcoord.xy;
				o.noiseUV = o.texcoord * (123.12345678) + float2(_SinTime.x, _CosTime.y) * 32.12345612;

				return o;
			}

			sampler2D _MainTex;
			sampler2D _PreviousTex;
			uniform sampler2D _Global_Noise_Lookup;
			
			float Qc_SmoothingBakingTransparency;

			inline float3 GET_RANDOM_POINT(float4 rand, float pixelsFromWall, float VOL_SIZE, float3 normalTmp)
			{ 
				if (pixelsFromWall > 1) 
					return randomSpherePoint(rand) * VOL_SIZE * pixelsFromWall;

					return  cosWeightedRandomHemisphereDirection(normalTmp, rand) * 2 * VOL_SIZE;
			}



			float4 frag(v2f o) : COLOR
			{
				float3 worldPos;
				
				#if RT_TO_CUBEMAP
					worldPos = volumeUVto_CubeMap_World(o.texcoord.xy);
				#else 
					worldPos = volumeUVtoWorld(o.texcoord.xy);
				#endif
			

				float4 seed = tex2Dlod(_Global_Noise_Lookup, float4(o.noiseUV, 0, 0));

				seed.a = ((seed.r + seed.b) * 2) % 1;

				float VOL_SIZE =
					#if RT_TO_CUBEMAP
						Qc_CubeLight_VOLUME_POSITION_N_SIZE.w;
					#else 
						_RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;
					#endif
				

				float4 off = (seed - 0.5);

				worldPos += off.rgb * 0.5 * VOL_SIZE;

				float oobSDF;
				float4 normalTmp = SampleSDF(worldPos , oobSDF);

			#if RT_TO_CUBEMAP
				#define SampleCorrespondingVolume(texTs, posTs, oob) Sample_CubeLight_Volume(texTs, posTs, oob)
			#else 
				#define SampleCorrespondingVolume(texTs, posTs, oob) SampleVolume(texTs, posTs, oob)
			#endif

				float4 previous = tex2Dlod(_PreviousTex, float4(o.texcoord.xy, 0, 0));

				float4 total = 0;
				float outOfBounds;
				total += SampleCorrespondingVolume(_MainTex, worldPos, outOfBounds); 

				float pixelsFromWall = normalTmp.w / VOL_SIZE;

				if (pixelsFromWall < 2)
				{
					float3 posToSample = worldPos + GET_RANDOM_POINT(seed.rgba, pixelsFromWall, VOL_SIZE, normalTmp);
					total += SampleCorrespondingVolume(_MainTex, posToSample, outOfBounds);

					 posToSample = worldPos + GET_RANDOM_POINT(seed.gbar, pixelsFromWall, VOL_SIZE, normalTmp);
					total += SampleCorrespondingVolume(_MainTex, posToSample, outOfBounds);

					 posToSample = worldPos + GET_RANDOM_POINT(seed.barg, pixelsFromWall, VOL_SIZE, normalTmp);
					total += SampleCorrespondingVolume(_MainTex, posToSample, outOfBounds);

					 posToSample = worldPos + GET_RANDOM_POINT(seed.argb, pixelsFromWall, VOL_SIZE, normalTmp);
					total += SampleCorrespondingVolume(_MainTex, posToSample, outOfBounds);
				} else 
				{
					pixelsFromWall = min(pixelsFromWall, 3);
					float maxDist = pixelsFromWall + 0.5;

					for (float x = -pixelsFromWall; x<=pixelsFromWall; x++)
					{
						for (float y = -pixelsFromWall; y<=pixelsFromWall; y++)
						{
							for (float z = -pixelsFromWall; z<=pixelsFromWall; z++)
							{
								float3 off = float3(x,y,z);
								float dist = length(off);
								if (dist > maxDist)
									continue;

								float power = 1/(dist*dist + 1);

								float3 posToSample = worldPos + VOL_SIZE * off;
								total += SampleCorrespondingVolume(_MainTex, posToSample, outOfBounds) * power * (1-outOfBounds);
							}
						}
					}
				}
			

				total.rgb /= max(total.a , 1);

				total = lerp(previous, total, total.a / (total.a + previous.a + 1) );

				total = max(0, total); // Fixes some division bug

				return total;
				
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}