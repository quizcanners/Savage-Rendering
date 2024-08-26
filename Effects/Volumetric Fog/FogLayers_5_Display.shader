Shader "Unlit/Fog Layers Display"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        ZWrite Off

        Pass
        {
         Blend One OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile __ qc_LAYARED_FOG

            #include "UnityCG.cginc"
           
            #include "Assets/Qc_Rendering/Shaders/Savage_Baker_VolumetricFog.cginc"
          	#include "Assets/Qc_Rendering/Shaders/Savage_DepthSampling.cginc"
            #include "Assets/Qc_Rendering/Shaders/Signed_Distance_Functions.cginc"
			#include "Assets/Qc_Rendering/Shaders/RayMarching_Forward_Integration.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            sampler2D qc_DepthMax;
            float4 qc_DepthMax_TexelSize;

            inline float GetDownscaledSceneDepth(float2 uv)
            {
                uv *= qc_DepthMax_TexelSize.zw;
                uv = floor(uv+0.5);
                uv *= qc_DepthMax_TexelSize.xy;
                //return tex2Dlod(_CameraDepthTexture,float4(uv, 0,0));
	            return tex2Dlod(qc_DepthMax, float4(uv, 0,0));
            }

           void SampleWeighted(float2 uvSegment, float2 internal, float2 off, float depth, inout float4 total, inout float totalValidity)
           {
                float2 uv = internal + off * qc_DepthMax_TexelSize.xy;// * 1.7;

                 float4 pix = tex2Dlod(qc_FogLayers, float4(uvSegment + uv/4, 0, 0));

                  float dsDepth = GetDownscaledSceneDepth(uv);

                  float validity = 1/(1+abs(dsDepth-depth) * 10000);

                  total += pix * validity;
                  totalValidity += validity;
           }

            float4 GetAvaragedSampling(float2 uvSegment, float2 internal, float depth)
            {
                  float4 total = 0; 

                  float totalValidity = 0.01;

                  SampleWeighted(uvSegment, internal, float2(0,0) , depth, total, totalValidity);

                  SampleWeighted(uvSegment, internal, float2(1, 0),  depth, total, totalValidity);
                  SampleWeighted(uvSegment, internal, float2(-1, 0), depth, total, totalValidity);
                  SampleWeighted(uvSegment, internal, float2(0, 1),  depth, total, totalValidity);
                  SampleWeighted(uvSegment, internal, float2(0, -1),  depth, total, totalValidity);

                  SampleWeighted(uvSegment, internal, float2(1, 1),  depth, total, totalValidity);
                  SampleWeighted(uvSegment, internal, float2(-1, -1), depth, total, totalValidity);
                  SampleWeighted(uvSegment, internal, float2(-1, 1),  depth, total, totalValidity);
                  SampleWeighted(uvSegment, internal, float2(1, -1),  depth, total, totalValidity);

                  return total/totalValidity;
            }


            float4 SampleLayeredFog_Test(float distance, float2 uv, float depth)
            {
	            #if !qc_LAYARED_FOG
		            return 0;
	            #endif

	            distance = min(distance, qc_LayeredFog_Distance-1);

	            float index;
                float fraction;
                GetFogLayerIndexFromDistance(distance, index, fraction);
	
               // return (index + fraction) /4;

	            float2 internalUv = uv;

	            float y = floor(index/4);
                float x = index - y*4;
	            float4 last = 
                    //tex2Dlod(qc_FogLayers, float4(float2(x,y)*0.25 + internalUv/4, 0, 0));
                     GetAvaragedSampling(float2(x,y)*0.25, internalUv, depth);


	            index--;
	            y = floor(index/4);
                x = index - y*4;
	            float4 previous = 
                   // tex2Dlod(qc_FogLayers, float4(float2(x,y)*0.25 + internalUv/4, 0, 0));
                    GetAvaragedSampling(float2(x,y)*0.25, internalUv, depth);

	            float4 result =  lerp(previous, last, fraction);

	            return result;
            }

            float4 frag (v2f i) : SV_Target
            {
                float depth = tex2Dlod(_CameraDepthTexture, float4(i.uv, 0,0));

             


				float3 finish = ReconstructWorldSpacePositionFromDepth(i.uv, depth); 

                float distance = length(_WorldSpaceCameraPos - finish);

                /*
                float2 off = qc_DepthMax_TexelSize.xy * 1.25;
                float dxDepth = GetDownscaledSceneDepth(i.uv + float2(off.x,0));
                return 1/(1 + abs(depth - dxDepth) * 10000);
           */

                float4 result = SampleLayeredFog_Test(distance, i.uv, depth);

                float4 noise = tex2Dlod(_Global_Noise_Lookup, 
				float4(i.uv * (123.12345678) + float2(_SinTime.x, _CosTime.y + i.uv.y) * 32.12345612, 0, 0));

                float noiseAmount = 0.15;

                result.rgb *= (1 + noiseAmount*0.5 - noise.rgb * noiseAmount);

               // result.a = 0;
              //  result.a = 1;

                return result;
            }
            ENDCG
        }
    }
}
