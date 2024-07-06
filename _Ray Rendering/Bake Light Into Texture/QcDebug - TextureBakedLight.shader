Shader "QcRendering/Debug/Show Qc Lightmap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _TracedLightTex ("Traced Light", 2D) = "gray" {}
    }
    SubShader
    {
        Tags 
        { 
        //"RenderType"="Opaque" 
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 texcoord1	: TEXCOORD1;
                UNITY_FOG_COORDS(2)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata_full v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.texcoord1 = v.texcoord1;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            sampler2D _TracedLightTex;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                col.rg = i.texcoord1.xy;
                col.b = 0;

                float4 light = tex2D(_TracedLightTex, i.texcoord1);

                return float4(light.rgb/(0.01 + light.a),1);
            }
            ENDCG
        }
     
    }
       Fallback "Diffuse"
}
