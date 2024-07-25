Shader "QcRendering/Terrain/Integration Blanket"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SpecularMap("R-Metalic G-Ambient _ A-Specular", 2D) = "black" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BlendHeight("Blend Height", Range(0,100)) = 1
        _BlendSharpness("Blend Sharpness", Range(0,1)) = 0
        _ForceContactBlend("Force Contact Blend", Range(0,1)) = 0.1

        _BlanketOffset("Blanket offset", Range(-1,1)) = 0

        _ForcedDowning("Forced Down Push", Range(0.01,3)) = 0.1

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

            float _BlanketOffset;
            float _ForcedDowning;

            float3 AllignPosition(float3 pos, float3 center)
            {
                float3x3 m = UNITY_MATRIX_M;
                float objectScale = length(float3( m[0][0], m[1][0], m[2][0]));

                _ForcedDowning *= objectScale;

                float deltaY = pos.y - center.y;

                float4 control = Ct_SampleTerrain(pos);
                float height = Ct_HeightRange.x + control.a * Ct_HeightRange.z;
   
                float extraDownPush = smoothstep(_ForcedDowning, 0, deltaY);

                pos.y = height + _BlanketOffset + deltaY - extraDownPush * 2 *_ForcedDowning;
                
                return pos;
            }


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

            #pragma multi_compile ___ _qc_WATER

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

       

            v2f vert (appdata_full v)
            {
                v2f o;

                float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
               
                #if qc_USE_TERRAIN
                    float4 objectOrigin = mul(unity_ObjectToWorld, float4(0.0,0.0,0.0,1.0) );
                    worldPos = AllignPosition(worldPos.xyz, objectOrigin);
                    v.vertex = mul(unity_WorldToObject, float4(worldPos, v.vertex.w));
			    #endif


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

            Texture2D _MainTex;
            float4 _MainTex_TexelSize;
            //float4 _MainTex_ST;
            Texture2D _BumpMap;
            SamplerState sampler_BumpMap;
            Texture2D _SpecularMap;
            float _BlendHeight;
            float _BlendSharpness;
            float _ForceContactBlend;

            fixed4 frag (v2f i) : SV_Target
            {
                float3 viewDir = normalize(i.viewDir);
                float2 screenUv = i.screenPos.xy / i.screenPos.w;

                #if qc_USE_TERRAIN
                    float3 rawTerrainNormal;
                    float4 terrainControl = Ct_SampleTerrainAndNormal(i.worldPos, rawTerrainNormal);

                    float height;
                    GetTerrainHeight(terrainControl, height);

                    float4 terrainMads;
                    float3 terrainNormal;
                    float3 terrainCol;
                    GetTerrainBlend(i.worldPos, terrainControl, rawTerrainNormal , terrainNormal, terrainCol, terrainMads);
                #endif

                float2 uv = i.texcoord;
                smoothedPixelsSampling(uv, _MainTex_TexelSize);

                 fixed4 objTex = _MainTex.Sample(sampler_BumpMap, uv);

                 float3 bump = UnpackNormal(_BumpMap.Sample(sampler_BumpMap, uv));
                 float4 madsMapObj = _SpecularMap.Sample(sampler_BumpMap, uv);

                 float3 objectNormal = i.normal.xyz;
                 ApplyTangent (objectNormal, bump, i.wTangent);

                  float ao = 1;

                   float3 tex;
                   float4 madsMap;
                   float3 rawNormal;
                   float3 normal;

                 #if qc_USE_TERRAIN
                     float showTerrain;
                     float forcedShowTerrain;
                     GetIntegration(terrainControl, terrainMads, madsMapObj, objectNormal, i.worldPos, _BlendHeight, _BlendSharpness, _ForceContactBlend, showTerrain, forcedShowTerrain);

                    tex = lerp( objTex, terrainCol, showTerrain);
                    madsMap = lerp( madsMapObj,terrainMads, showTerrain);
                    rawNormal = normalize( lerp(i.normal.xyz, rawTerrainNormal, showTerrain));
                    normal = normalize(lerp( objectNormal,terrainNormal, showTerrain));

                    madsMap.g = lerp(lerp(terrainMads.g,1,showTerrain) * madsMapObj.g, terrainMads.g, forcedShowTerrain);

                    ao = lerp(ao, 1, forcedShowTerrain);

                  

                #else 
                    tex = objTex;
                    madsMap =  madsMapObj;
                    rawNormal = i.normal.xyz;
                    normal = objectNormal;

                   

                #endif

             

                float rawFresnel = saturate(1- dot(viewDir, rawNormal));

               //ao = min(ao, madsMap.g); //, smoothstep(0.9,1,showTerrain));
                  ao *= madsMap.g + (1-madsMap.g) * rawFresnel;

               
               

                float shadow = SHADOW_ATTENUATION(i);

                float displacement = madsMap.b;

                float4 illumination;




			    ao *= SampleSS_Illumination( screenUv, illumination);

			    shadow *= saturate(1-illumination.b);

            

               // + (1-madsMap.g) * rawFresnel;


            //   return float4(rawNormal,1);

                float metal = 0; // madsMap.r;
				float fresnel =  GetFresnel_FixNormal(normal, rawNormal, viewDir);//GetFresnel(normal, viewDir) * ao;

                 
              // return float4(rawNormal, 1);
                 // return ao;
            //  return madsMap.a;

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
				precomp.metalColor = 0; //lerp(tex, _MetalColor, _MetalColor.a);

				precomp.microdetail.a = 0;
			
				float3 col = GetReflection_ByMaterialType(precomp, normal, rawNormal, viewDir, i.worldPos);


				ApplyBottomFog(col, i.worldPos.xyz, viewDir.y);


                return float4(col,1);
            }

 


            ENDCG
        }

        
			Pass 
			{
				Name "Caster"
				Tags 
				{ 
					"LightMode" = "ShadowCaster" 
				}

				Cull Off//Back
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma target 2.0
				#pragma multi_compile_shadowcaster
				#pragma multi_compile_instancing // allow instanced shadow pass for most of the shaders
				#pragma shader_feature_local ___ _WIND_SHAKE
				#include "UnityCG.cginc"
				
                 #pragma multi_compile ___ qc_USE_TERRAIN

				#include "Assets/Qc_Rendering/Shaders/Savage_Vegetation.cginc"


				struct v2f 
				{
					V2F_SHADOW_CASTER;
					 UNITY_VERTEX_INPUT_INSTANCE_ID 
					//UNITY_VERTEX_OUTPUT_STEREO
				};


				uniform sampler2D _MainTex;
				float4 _MainTex_ST;

				v2f vert( appdata_full v )
				{
					v2f o;

					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_TRANSFER_INSTANCE_ID(v, o);

                    #if qc_USE_TERRAIN
                        float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
                        float4 objectOrigin = mul(unity_ObjectToWorld, float4(0.0,0.0,0.0,1.0) );
                        worldPos = AllignPosition(worldPos.xyz, objectOrigin);
                        v.vertex = mul(unity_WorldToObject, float4(worldPos, v.vertex.w));
                    #endif
					//UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)

					//o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
					return o;
				}

				uniform fixed _Cutoff;
				uniform fixed4 _Color;

				float4 frag( v2f i ) : SV_Target
				{
					UNITY_SETUP_INSTANCE_ID(i);
					SHADOW_CASTER_FRAGMENT(i)
				}
				ENDCG
			}

   UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
