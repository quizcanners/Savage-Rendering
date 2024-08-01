Shader "Unlit/Append To Front"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "Assets/Qc_Rendering/Shaders/Savage_Baker_VolumetricFog.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float index;
                float2 uv = GetLayerUvs (i.uv, index); 

               // float4 col;

                float remainingAlpha = 1;

                float distCurve = 3 - qc_LayeredFog_Alpha * 2;

                // Not accurate method as we increase Alpha over distance, thus increasing the brighntness of previously accumulated samples

                float3 light = 0;
                float obscurance = 0;
                 
                 int DISTANCE_IMPORTANCE = 6;

                 float MIN_LAYER_ALPHA = 2048;

                int MAX_DIST_POWER = pow(15,DISTANCE_IMPORTANCE) + MIN_LAYER_ALPHA;//16; //(1 + i)

                

                float transprencyStep = qc_LayeredFog_Alpha / pow(MAX_DIST_POWER, distCurve);

                for (float i = 0; i<=index; i++)
                {
                    float y = floor(i/4); //floor(index/4);
                    float x = i - y * 4;

                    float pixel = _MainTex_TexelSize.xy;

                    float4 checking = tex2Dlod(_MainTex, float4((float2(x,y) + uv) * 0.25,0,0));

                    float brightness = checking.a; //* saturate(10 * length(checking.rgb));

                    float DIST_POWER = pow(i,DISTANCE_IMPORTANCE) + MIN_LAYER_ALPHA;

                  //  checking.rgb *= checking.a;
                    float layerAlpha = remainingAlpha * brightness *  transprencyStep * pow(DIST_POWER, distCurve);

                    remainingAlpha -= layerAlpha;

                    obscurance += layerAlpha;
                    light += checking.rgb * layerAlpha;

                    //col+= checking;
                }

                return float4(light, obscurance);
            }
            ENDCG
        }
    }
}
