Shader "QcRendering/Terrain/Integration"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BlendHeight("Blend Height", Range(0,100)) = 1
        _BlendSharpness("Blend Sharpness", Range(0,1)) = 0
        _FoceContactBlend("Force Contact Blend", Range(0,1)) = 0.1
    }
    SubShader
    {
        Tags 
        { 
        "RenderType"="Geometry" 
        "Queue" = "Geometry+10"
        }
        LOD 100

        CGINCLUDE

            #include "Qc_TerrainCommon.cginc"
            #include "UnityCG.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_Standard.cginc"
			#include "Assets/Qc_Rendering/Shaders/Savage_Sampler_VolumetricFog.cginc"
        ENDCG


        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fwdbase
            #pragma skip_variants LIGHTPROBE_SH LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING

            #pragma multi_compile ___ _qc_USE_RAIN 
			#pragma multi_compile qc_NO_VOLUME qc_GOT_VOLUME 
			#pragma multi_compile ___ _qc_IGNORE_SKY 

             #pragma multi_compile ___ qc_USE_TERRAIN

            struct v2f
            {
                float4 pos			: SV_POSITION;
                float2 texcoord : TEXCOORD0;
                float3 worldPos : 	TEXCOORD1;
                float4 wTangent		: TEXCOORD2;
                float3 normal		: TEXCOORD3;
                float3 viewDir : TEXCOORD4;
                 float4 screenPos :		TEXCOORD5;
                SHADOW_COORDS(6)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata_full v)
            {
                v2f o;
               
                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                o.normal.xyz = UnityObjectToWorldNormal(v.normal);
                o.viewDir.xyz = WorldSpaceViewDir(v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.texcoord;
                TRANSFER_SHADOW(o);
                o.worldPos = worldPos;
                TRANSFER_WTANGENT(o);
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            Texture2D _BumpMap;
            SamplerState sampler_BumpMap;
            Texture2D _SpecularMap;
            float _BlendHeight;
            float _BlendSharpness;
            float _FoceContactBlend;

            fixed4 frag (v2f i) : SV_Target
            {
                float3 viewDir = normalize(i.viewDir);
                float2 screenUv = i.screenPos.xy / i.screenPos.w;

                 fixed4 tex = tex2D(_MainTex, i.texcoord);
                 float3 bump = UnpackNormal(_BumpMap.Sample(sampler_BumpMap, i.texcoord));
                 float4 madsMapObj = _SpecularMap.Sample(sampler_BumpMap, i.texcoord);

                    float3 normal = i.normal.xyz;
                 ApplyTangent (normal, bump, i.wTangent);

                      float ao = 1;
                      float3 rawNormal =i.normal.xyz;

                 float4 madsMap;

                 #if qc_USE_TERRAIN
                    float3 rawTerrainNormal;
                    float4 terrainControl = Ct_SampleTerrainAndNormal(i.worldPos, rawTerrainNormal);

                    float height;
                    GetTerrainHeight(terrainControl, height);

                    float4 terrainMads;
                    float3 terrainNormal;
                    float3 terrainCol;
                    GetTerrainBlend(i.worldPos, terrainControl, rawTerrainNormal , terrainNormal, terrainCol, terrainMads);

                     float showTerrain;
                     float forcedShowTerrain;
                     GetIntegration(terrainControl, terrainMads, madsMapObj, rawNormal, i.worldPos, _BlendHeight, _BlendSharpness, _FoceContactBlend, showTerrain, forcedShowTerrain);

                    tex.rgb = lerp( tex.rgb, terrainCol, showTerrain);
                    madsMap = lerp( madsMapObj,terrainMads, showTerrain);
                    rawNormal = normalize( lerp(rawNormal, rawTerrainNormal, showTerrain));
                    normal = normalize(lerp( normal,terrainNormal, showTerrain));
                 
                     madsMap.g = lerp(lerp(terrainMads.g,1,showTerrain) * madsMapObj.g, terrainMads.g, forcedShowTerrain);

                    ao = lerp(ao, 1, forcedShowTerrain);

                #else
                    madsMap =  madsMapObj;
                #endif

                   float rawFresnel = saturate(1- dot(viewDir, rawNormal));
               // ao = min(ao, madsMap.g); //, smoothstep(0.9,1,showTerrain));

              

                float shadow = SHADOW_ATTENUATION(i);

                float displacement = madsMap.b;

                float4 illumination;

			    ao *= SampleSS_Illumination( screenUv, illumination);
			    shadow *= saturate(1-illumination.b);
                 ao *= madsMap.g + (1-madsMap.g) * rawFresnel;
 
              //  return ao;


                float metal = 0; 
				float fresnel =  GetFresnel_FixNormal(normal, rawNormal, viewDir);

				MaterialParameters precomp;
					
				precomp.shadow = shadow;
				precomp.ao = ao;
				precomp.fresnel = fresnel;
				precomp.tex = tex;
				
				precomp.reflectivity = 1;
				precomp.metal = metal;
				precomp.traced = 0;
				precomp.water = 0;
				precomp.smoothsness = madsMap.a;

				precomp.microdetail = 0.5;
				precomp.metalColor = 0;

				precomp.microdetail.a = 0;
			
				float3 col = GetReflection_ByMaterialType(precomp, normal, rawNormal, viewDir, i.worldPos);

				ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);


                return float4(col,1);
            }

 


            ENDCG
        }

   UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
