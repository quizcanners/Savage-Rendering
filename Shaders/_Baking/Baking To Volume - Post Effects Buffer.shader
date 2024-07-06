Shader "QcRendering/Baker/Direct Post Effects"
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
		Blend One Zero 

		Pass
		{

			CGPROGRAM

			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_PostEffectBake.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_VolumeSampling.cginc"
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


			float3 Direct_VolumeUVtoWorld(float2 uv) 
			{
				if (Qc_Direct_USE_DYNAMIC_RTX_VOLUME > 0)
				{
					float4 zeroPos = float4(0,0,0, Qc_Direct_VOLUME_POSITION_N_SIZE.w);
					float3 localPos = volumeUVtoWorld(uv, zeroPos, Qc_Direct_VOLUME_H_SLICES);

					return mul(Qc_Direct_LocalToWorld, float4(localPos,1)).xyz;
				}

				return volumeUVtoWorld(uv, Qc_Direct_VOLUME_POSITION_N_SIZE, Qc_Direct_VOLUME_H_SLICES);
			}

			sampler2D _Global_Noise_Lookup;


			float4 frag(v2f o) : SV_TARGET 
			{
				float3 worldPos = Direct_VolumeUVtoWorld(o.texcoord.xy);

				float outOfBounds;

				float VOL_SIZE = Qc_Direct_VOLUME_POSITION_N_SIZE.w;

				float4 sdf = SampleSDF(worldPos, outOfBounds);

				float3 postCol;
				float ao;
				float4 noise = tex2Dlod(_Global_Noise_Lookup, 
					float4(o.texcoord * (123.12345678) + float2(sin(_Effect_Time.x), 
					cos(_Effect_Time.x*1.23)) * 123.12345612 * (1 + o.texcoord.y) ,0, 0));

				//noise.a = ((noise.r + noise.b) * 2) % 1;


				worldPos += (noise.rgb - 0.5) * VOL_SIZE;

				float3 aoColor;

				UNITY_BRANCH
				if (sdf.a > VOL_SIZE * 2)
					SamplePostEffects(worldPos, postCol, aoColor, ao);
				else 
					SamplePostEffects(worldPos, sdf.xyz, postCol, aoColor, ao);
				//SamplePostEffects(float3 pos, float3 dir, out float3 col, out float ao, float4 seed)
				

				return float4(postCol, ao);
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders/Transparent/VertexLit"
}