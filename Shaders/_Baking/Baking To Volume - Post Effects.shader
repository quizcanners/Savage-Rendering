Shader "QcRendering/Baker/Post Effects"
{
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_PreviousTex("Albedo (RGB)", 2D) = "clear" {}
		[Toggle(_DEBUG)] debugOn("Debug", Float) = 0
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
		Blend One Zero//One Zero 

		Pass
		{

			CGPROGRAM

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_PostEffectBake.cginc"
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile __ RT_TO_CUBEMAP 

			struct v2f 
			{
				float4 pos : 		SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float3 viewDir: 	TEXCOORD1;
			};

			float4 _Effect_Time;
	
			v2f vert(appdata_full v) 
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
				o.texcoord = v.texcoord.xy;
				return o;
			}


			sampler2D _MainTex;
			sampler2D _PreviousTex;
			float4 _RT_CubeMap_Direction;

			float4 _RayMarchingVolumeVOLUME_POSITION_N_SIZE_PREVIOUS;
			float4 _RayMarchingVolumeVOLUME_H_SLICES_PREVIOUS;

			sampler2D _Global_Noise_Lookup;

			float4 frag(v2f o) : SV_TARGET 
			{
				float3 worldPos;

				#if RT_TO_CUBEMAP
					worldPos = volumeUVto_CubeMap_World(o.texcoord.xy);
				#else 
					worldPos = volumeUVtoWorld(o.texcoord.xy);
				#endif

				float outOfBounds;
				//	float VOL_SIZE = Qc_Direct_VOLUME_POSITION_N_SIZE.w;
				/*
				float4 vol = SampleVolume(_MainTex, worldPos
					, _RayMarchingVolumeVOLUME_POSITION_N_SIZE_PREVIOUS
					, _RayMarchingVolumeVOLUME_H_SLICES_PREVIOUS, outOfBounds);
					*/

				float4 previous = tex2Dlod(_PreviousTex, float4(o.texcoord.xy, 0, 0));

				float VOL_SIZE =
					#if RT_TO_CUBEMAP
						Qc_CubeLight_VOLUME_POSITION_N_SIZE.w;
					#else 
						_RayMarchingVolumeVOLUME_POSITION_N_SIZE.w;
					#endif

				float4 sdf = SampleSDF(worldPos, outOfBounds);

				//float blackPixel = smoothstep(0, -0.01, sdf.a) * (1-outOfBounds);
				
				float3 postCol;
				float ao;

					float4 noise = tex2Dlod(_Global_Noise_Lookup, 
					float4(o.texcoord * (123.12345678) + float2(sin(_Effect_Time.x), 
					cos(_Effect_Time.x*1.23)) * 123.12345612 * (1 + o.texcoord.y) ,0, 0));

				float useRandomOffset = smoothstep(VOL_SIZE, VOL_SIZE*2, sdf.a);

				worldPos += lerp((sdf.rgb * (1-outOfBounds) + (noise.rgb-0.5)) * 0.5, (noise.rgb - 0.5), useRandomOffset) * VOL_SIZE;

				float3 aoColor;

				#if RT_TO_CUBEMAP
					SamplePostEffects(worldPos,_RT_CubeMap_Direction.xyz, postCol, aoColor, ao);
					
					float blackPixel = (1-saturate(dot(sdf.xyz, _RT_CubeMap_Direction.xyz))) 
					* smoothstep(VOL_SIZE*3, 0, sdf.a) * (1-outOfBounds);
				
					postCol = lerp(postCol,0, blackPixel);
					aoColor = lerp(aoColor,0, blackPixel);

				#else
					SamplePostEffects(worldPos, postCol, aoColor, ao);
				#endif

				float4 col = float4(ao * postCol, previous.a);

				col.rgb += previous.rgb * lerp(aoColor, 1, ao);
				
				#if RT_TO_CUBEMAP
					col = lerp(col, previous, 0.75); // Applied in 4 steps
				#endif



				return col;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}