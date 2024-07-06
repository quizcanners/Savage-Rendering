Shader "Unlit/Bake To Mesh - Traced Light"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        ColorMask RGBA
		Cull off
		ZTest off
		ZWrite off
        Blend One One

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define _qc_AMBIENT_SIMULATION
            #pragma multi_compile ___ _qc_IGNORE_SKY
			#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 

            #include "UnityCG.cginc"
            #include "Assets/Qc_Rendering/Shaders/PrimitivesScene_RayBaking.cginc"

            struct v2f 
            {
				float4 pos : POSITION;
                float2 texcoord : TEXCOORD0;
				float4 worldPos : TEXCOORD1;
                float3 normal : TEXCOORD2;
			};

            sampler2D _MainTex;
            float4 _MainTex_ST;

            uniform sampler2D _Global_Noise_Lookup;

            v2f vert (appdata_full v)
            {
                v2f o;

                o.normal = UnityObjectToWorldNormal(v.normal);

               	float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));
			    o.worldPos = worldPos;
               
                float2 uv = v.texcoord1.xy;

                worldPos.z = 0;
				worldPos.xy = uv.xy;

                v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, v.vertex.w));
				o.pos = UnityObjectToClipPos(v.vertex);

                o.texcoord = v.texcoord.xy;

                return o;
            }

            uniform float4 _Effect_Time;

            fixed4 frag (v2f i) : SV_Target
            {
                float4 noise = tex2Dlod(_Global_Noise_Lookup, 
                    float4(i.texcoord * (123.12345678) + 
                    float2(sin(_Effect_Time.x), cos(_Effect_Time.x*1.23)) * 123.12345612 * (1 + i.texcoord.y),0, 0));
                
                noise.a = ((noise.r + noise.b) * 2) % 1;
				float4 rand = (noise - 0.5) * 2;

                float outOfBounds;
                float4 sdf0 = SampleSDF(i.worldPos, outOfBounds);

                float3 rayDirection = normalize(lerp(rand.xyz, i.normal, 0.75));

                float4 col = render(i.worldPos, rayDirection, noise);

				col.a = 1;

              //  col.rgb *= saturate(sdf0.a);

                return col;//float4(sdf0.a/0.2, 0,0,1);
            }
            ENDCG
        }
    }
}
