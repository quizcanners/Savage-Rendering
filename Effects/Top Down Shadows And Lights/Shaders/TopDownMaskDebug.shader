Shader "QcRendering/Debug/Show Lighting"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        [KeywordEnum(Light, Sdf)]	VIEW ("Debug view", Float) = 0


       
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass {

            CGPROGRAM
       //     #include "Assets/The-Fire-Below/Common/Shaders/quizcanners_built_in.cginc"
            	#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
				
           #pragma vertex vert
           #pragma fragment frag

           #pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
		   #pragma multi_compile ___ _qc_IGNORE_SKY 

            #pragma shader_feature_local  ___ VIEW_LIGHT VIEW_SDF  

           struct v2f {
                    float4 pos : 		SV_POSITION;
                    float3 viewDir: 	TEXCOORD0;
                    float2 texcoord : TEXCOORD1;
                    float3 worldPos : TEXCOORD2;
                    float3 normal	: TEXCOORD3;
                };




            v2f vert(appdata_full v) 
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.texcoord = (o.worldPos.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;
              	o.normal.xyz = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag(v2f i) : COLOR
            {
                float3 viewDir = normalize(i.viewDir.xyz);

                float fresnel = 1-saturate(dot(viewDir, i.normal));

                float3 col=1;

                #if VIEW_LIGHT
                col = SampleVolume_CubeMap(i.worldPos, i.normal);// tex2Dlod(_RayTracing_TopDownBuffer, float4(o.texcoord,0,0));
                  
                float3 refl = SampleVolume_CubeMap(i.worldPos, reflect(-viewDir,i.normal));

                col = lerp(col, refl, fresnel);
                #endif

                #if VIEW_SDF
                float outOfBounds;
                float4 sdf = SampleSDF(i.worldPos,  outOfBounds);

                col = sdf.rgb * (1-outOfBounds);

                col = lerp( col, 1, saturate(dot(-sdf.xyz, i.normal)));


               

                #endif

                return float4(col,1);
            }

            ENDCG
        }
    }
    FallBack "Diffuse"
}
