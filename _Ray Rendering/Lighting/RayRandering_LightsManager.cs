using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    using Migration;
    using Inspect;
    using Lerp;
    using Utils;
    using QuizCanners.SpecialEffects;
    using QuizCanners.SavageTurret;

    public static partial class QcRender
    {
        [Serializable]
        public class WeatherManager : IPEGI, ILinkedLerping, ICfgCustom, IPEGI_ListInspect
        {
            [SerializeField] internal SO_RayRenderingLightCfgs Configs;
            [SerializeField] private Texture _cloudShadowsTexture;
            [SerializeField] private Material RaySkybox;
            [SerializeField] private SO_HDRsLoading HDRs;


            private readonly LinkedLerp.ShaderColor AMBIENT_COLOR = new("_qc_AmbientColor", Color.clear, maxSpeed: 2f);
            private readonly ShaderProperty.TextureValue CLOUD_SHADOWS_TEXTURE = new("_qc_CloudShadows_Mask");
            private readonly LinkedLerp.ShaderFloatFeature CLOUD_SHADOWS_VISIBILITY = new("_qc_Rtx_CloudShadowsVisibility", "_qc_CLOUD_SHADOWS");
            private readonly LinkedLerp.ShaderFloatFeature SUN_INTENSITY = new(nName: "_qc_SunVisibility", featureDirective: "_qc_USE_SUN");
            private readonly LinkedLerp.ShaderColor SUN_COLOR = new("_qc_SunColor", Color.gray, maxSpeed: 2); //"Sun Colo", maxSpeed: 2);
            private readonly LinkedLerp.ShaderFloat SUN_LIGHT_ATTENUATION = new("_qc_Sun_Atten", initialValue: 1);

            private readonly LinkedLerp.ShaderColor MIN_LIGH_COLOR = new("_RayMarthMinLight", Color.black, 10);
            private readonly LinkedLerp.ShaderFloatFeature STARS_VISIBILITY = new(nName: "_StarsVisibility", featureDirective: "_RAY_MARCH_STARS");
            private readonly ShaderProperty.Feature INDOORS = new("_qc_IGNORE_SKY");
            private readonly LinkedLerp.ColorValue FOG_COLOR = new("Fog", maxSpeed: 1);

            private readonly ShaderProperty.FloatValue CLASSICAL_FOG = new("_qc_FogVisibility");
          
            private bool _artificialLightsExpected;

            public int LightConfigVersion = 0;

            public float SunAttenuation => SUN_LIGHT_ATTENUATION.CurrentValue;

            public bool ArtificialLightsExpected 
            {
                get => _artificialLightsExpected;
                set 
                {
                    _artificialLightsExpected = value;
                    Mgmt.SetBakingDirty("Artificial Lights Chenged", invalidateResult: true);
                }
            }

            public float ClassicalFog 
            {
                get => CLASSICAL_FOG.latestValue;
                set => CLASSICAL_FOG.SetGlobal(value);
            }

            public bool LerpDone { get; private set; }

            private string _weatherDirtyReason;

            private void SetWeatherDirty(string reason) 
            {
                LightConfigVersion++;
                _weatherDirtyReason = reason;
                LerpDone = false;
            }

            protected Singleton_SunAndMoonRotator SunAndMoon => Singleton.Get<Singleton_SunAndMoonRotator>();

            public Color SunColor 
            {
                get => SUN_COLOR.TargetValue;
                set 
                {
                    SUN_COLOR.TargetValue = value;
                }
            }

            public float SunIntensity
            {
                get => SUN_INTENSITY.GlobalValue;
                set => SUN_INTENSITY.GlobalValue = value;
            }

            public Color AmbientColor 
            {
                get => AMBIENT_COLOR.TargetValue;
                set 
                {
                    AMBIENT_COLOR.TargetValue = value;
                    SetWeatherDirty(reason: "Ambient color change");
                }
            }

            void UpdateIndoors() 
            {
                INDOORS.Enabled = SunIntensity == 0 && AmbientColor.r == 0 && AmbientColor.g == 0 && AmbientColor.b == 0;
            }

            public bool Stars 
            {
                get => STARS_VISIBILITY.CurrentValue > 0.2f;
            }

            private float _rainTargetValue;

            public float RainTargetValue
            {
                get => _rainTargetValue;
                set
                {
                    _rainTargetValue = value;
                }
            }

            /*
            protected Vector3 LightDirection 
            {
                get => Sun ? -Sun.transform.forward : Vector3.up;
                set 
                {
                    if (Sun)
                        Sun.transform.forward = -value;
                }
            }*/

            private void UpdateEffectiveSunColor() 
            {
                if (Singleton.TryGet<Singleton_SunAndMoonRotator>(out var s))
                    s.SharedLight.color = SUN_COLOR.CurrentValue;
            }

            internal int MaxRenderFrames = 1500;

            public void AnimateToConfig(string key) 
            {
                if (Configs.ActiveConfiguration != null && Configs.ActiveConfiguration.name == key)
                    return;

                foreach (var c in Configs.configurations) 
                {
                    if (c.name.Equals(key))
                    {
                        Configs.ActiveConfiguration = c;
                        return;
                    }
                }
            }

            #region Encode & Decode

            public void ManagedOnEnable() 
            {
                if (_cloudShadowsTexture)
                    CLOUD_SHADOWS_TEXTURE.GlobalValue = _cloudShadowsTexture;

                if (!Application.isPlaying && Configs && Configs.configurations.Count>0) 
                {
                    Configs.configurations[0].SetAsCurrent();
                }

                UpdateEffectiveSunColor();

                this.SkipLerp();

                if (RenderSettings.ambientMode != UnityEngine.Rendering.AmbientMode.Trilight)
                    RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;

                if (RaySkybox)
                    RenderSettings.skybox = RaySkybox;
            }

            public void ManagedOnDisable()
            {
                Configs.IndexOfActiveConfiguration = -1;
                CLOUD_SHADOWS_VISIBILITY.GlobalValue = 0;
                HDRs.ManagedOnDisable();
            }


            public CfgEncoder EncodeSelectedIndex => Configs.Encode();
            public void DecodeInternal(CfgData data)
            {
                new CfgDecoder(data).DecodeTagsFor(this);
                SetWeatherDirty(reason: "Decoded new config" );
                Mgmt.RequestLerps("Light Decoder");
                LightConfigVersion++;
            }
            public void DecodeTag(string key, CfgData data)
            {
                switch (key)
                {
                    case "col": SUN_COLOR.TargetValue = data.ToColor();  break;
                    case "fog": FOG_COLOR.TargetValue = data.ToColor(); break;
                    case "maxFrms": MaxRenderFrames = data.ToInt(); break;
                    case "ml": MIN_LIGH_COLOR.TargetValue = data.ToColor();   break;
                    case "stars": STARS_VISIBILITY.TargetValue = data.ToFloat(); break;
                    case "Shad": CLOUD_SHADOWS_VISIBILITY.TargetValue = data.ToFloat(); break;
                    case "SnM": SunAndMoon.Decode(data); break;
                    case "Rain": _rainTargetValue = data.ToFloat(); break;
                    case "Amb": AmbientColor = data.ToColor(); break;
                    case "SunInten":  SUN_INTENSITY.TargetValue = data.ToFloat(); break;
                    case "atten": SUN_LIGHT_ATTENUATION.Decode(data); break;
                    case "ArtLights":  ArtificialLightsExpected = data.ToBool(); break;
                    case "hdr": HDRs.CurrentHDR = data.ToString(); break;
                    case "layerFog":
                        if (Singleton.TryGet<Singleton_LayeredVolumetricFog>(out var layerFog))
                            layerFog.Decode(data);
                        else
                            Debug.LogError("Volumetric fog Singleton not ready");
                        break;

                    case "wind":
                        if (Singleton.TryGet<Singleton_WindManager>(out var wind))
                            wind.Decode(data);
                        else
                            Debug.LogError("Wind manager not found");
                        break;
                }
            }

            public CfgEncoder Encode()
            {
                var cody = new CfgEncoder()
                .Add("col", SUN_COLOR.TargetValue)
                .Add("fog", FOG_COLOR.TargetValue)
                .Add("maxFrms", MaxRenderFrames)
                .Add("ml", MIN_LIGH_COLOR.TargetValue)
                .Add("stars", STARS_VISIBILITY.TargetValue)
                .Add("Shad", CLOUD_SHADOWS_VISIBILITY.GlobalValue)
                .Add("SnM", SunAndMoon)
                .Add("Rain", RainTargetValue)
                .Add("Amb", AmbientColor)
                .Add("SunInten", SUN_INTENSITY.TargetValue)
                .Add("atten", SUN_LIGHT_ATTENUATION)
                .Add_Bool("ArtLights", ArtificialLightsExpected)
                .Add_String("hdr", HDRs.CurrentHDR)
                ;

                if (Singleton.TryGet<Singleton_LayeredVolumetricFog>(out var layerFog))
                    cody.Add("layerFog", layerFog);

                if (Singleton.TryGet<Singleton_WindManager>(out var wind))
                    cody.Add("wind", wind);

                return cody;
            }
              

            #endregion

            #region Update

            private readonly LerpData _lerpData = new(unscaledTime: true);

            public void ManagedUpdate() 
            {
                HDRs.ManagedUpdate();

                if (!LerpDone)
                {
                    _lerpData.Update(this, canSkipLerp: false);
                }
            }

            public void Portion(LerpData ld)
            {
                SUN_COLOR.Portion(ld);
                FOG_COLOR.Portion(ld);
                MIN_LIGH_COLOR.Portion(ld);
                STARS_VISIBILITY.Portion(ld);
                AMBIENT_COLOR.Portion(ld);
               // CLOUD_SHADOWS_VISIBILITY.Portion(ld);
                SUN_INTENSITY.Portion(ld);
                SUN_LIGHT_ATTENUATION.Portion(ld);
              //  WIND_DIRECTION.Portion(ld);
            }

            public void Lerp(LerpData ld, bool canSkipLerp)
            {
                SUN_COLOR.Lerp(ld, canSkipLerp);
                FOG_COLOR.Lerp(ld, canSkipLerp);
                MIN_LIGH_COLOR.Lerp(ld, canSkipLerp);
                STARS_VISIBILITY.Lerp(ld, canSkipLerp);
                AMBIENT_COLOR.Lerp(ld, canSkipLerp);
               // CLOUD_SHADOWS_VISIBILITY.Lerp(ld, canSkipLerp);
                SUN_INTENSITY.Lerp(ld, canSkipLerp);
                SUN_LIGHT_ATTENUATION.Lerp(ld, canSkipLerp);
               // WIND_DIRECTION.Lerp(ld, canSkipLerp);


                LerpDone |= ld.IsDone;

                if (LerpDone) 
                {
                    Mgmt.SetBakingDirty(reason: "Weather Manager Lerp Finished after "+ _weatherDirtyReason, invalidateResult: true);
                }

                RenderSettings.fogColor = FOG_COLOR.CurrentValue;

                if (Singleton.TryGet<Singleton_CameraOperatorConfigurable>(out var s))
                    s.MainCam.backgroundColor = FOG_COLOR.CurrentValue;

                if (Singleton.TryGet<Singleton_SunAndMoonRotator>(out var sm))
                    sm.SunIntensity = SUN_INTENSITY.CurrentValue; 

                var ambint = AMBIENT_COLOR.CurrentValue;

                RenderSettings.ambientSkyColor = ambint * 2;
                RenderSettings.ambientEquatorColor = ambint * 1.5f;
                RenderSettings.ambientGroundColor = ambint;

                UpdateEffectiveSunColor();
                UpdateIndoors();
            }


            #endregion

            #region Inspector

            private readonly pegi.EnterExitContext _context = new(playerPrefId: "rtxWthInsp");
           // [SerializeField]private pegi.EnterExitContext 
            void IPEGI.Inspect()
            {
                var changed = pegi.ChangeTrackStart();

                using (_context.StartContext())
                {
                    if (RenderSettings.ambientMode != UnityEngine.Rendering.AmbientMode.Trilight && "Set Ambient to Trilight".PegiLabel().Click().Nl())
                        RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;

                    if (RenderSettings.defaultReflectionMode != UnityEngine.Rendering.DefaultReflectionMode.Custom && "Set Reflection to custom".PegiLabel().Click())
                        RenderSettings.defaultReflectionMode = UnityEngine.Rendering.DefaultReflectionMode.Custom;

                    pegi.Nl();

                    if (_context.IsAnyEntered == false)
                    {
                        ////if (Configs.ActiveConfiguration != null)
                        //   Configs.ActiveConfiguration.name.PegiLabel(pegi.Styles.HeaderText).Nl();

                        "Sky: {0}".F(INDOORS.Enabled ? "HIDDEN" : "RENDERED").PegiLabel(pegi.Styles.BaldText).Nl();

                        Inspect_SelectConfig();
                        pegi.Nl();

                        Material sky = RenderSettings.skybox;

                        if ("Skybox".PegiLabel().Edit(ref sky))
                            RenderSettings.skybox = sky;

                        if (RaySkybox && RaySkybox != sky && "Set Ray Sky".PegiLabel().Click())
                            RenderSettings.skybox = RaySkybox;

                        pegi.Nl();

                        if (!RaySkybox)
                            "Ray Skybox".PegiLabel().Edit(ref RaySkybox).Nl();

                        "Frames needed for baking".PegiLabel().Edit(ref MaxRenderFrames).Nl();

                        var sun = RenderSettings.sun;
                        "Sun (Render Settings)".PegiLabel().Edit(ref sun).OnChanged(() => RenderSettings.sun = sun);

                        pegi.ClickHighlight(sun);

                        pegi.Nl();

                        var col = SUN_COLOR.TargetValue;
                        if ("Light Color".PegiLabel().Edit(ref col, hdr: true).Nl())
                        {
                            SUN_COLOR.TargetValue = col;
                        }

                        var inten = SUN_INTENSITY.TargetValue;
                        if ("Intensity".PegiLabel(70).Edit(ref inten, 0, 5).Nl())
                            SUN_INTENSITY.TargetValue = inten;

                        var atten = SUN_LIGHT_ATTENUATION.TargetValue;
                        if ("Attenuation".PegiLabel(70).Edit(ref atten, 0, 6).Nl())
                            SUN_LIGHT_ATTENUATION.TargetValue = atten;

                        /*
                        col = FOG_COLOR.TargetValue;
                        if ("Fog Color".PegiLabel().Edit(ref col, hdr: true).Nl())
                            FOG_COLOR.TargetValue = col;*/



                        var dc = MIN_LIGH_COLOR.TargetValue;
                        if ("Dark Color".PegiLabel().Edit(ref dc).Nl())
                            MIN_LIGH_COLOR.TargetValue = dc;

                        var amb = AmbientColor;
                        if ("Ambient".PegiLabel().Edit(ref amb, hdr: true).Nl())
                            AmbientColor = amb;

                        "Ambient Alpha -> Modify Skybox".PegiLabel().Write_Hint().Nl();

                        var stars = STARS_VISIBILITY.TargetValue;

                        bool useStars = stars > 0;
                        if (pegi.ToggleIcon(ref useStars))
                            STARS_VISIBILITY.TargetValue = useStars ? 1 : 0;

                        if ("Stars".PegiLabel(60).Edit_01(ref stars).Nl())
                            STARS_VISIBILITY.TargetAndCurrentValue = stars;


                        "Artificial lights".PegiLabel().ToggleIcon(ref _artificialLightsExpected).Nl(()=> ArtificialLightsExpected = _artificialLightsExpected);

                        "Rain".PegiLabel(40).Edit_01(ref _rainTargetValue).Nl();
                        // RAIN.InspectInList_Nested().Nl(()=> RAIN.SetGlobal());

                     

                       // CLOUD_SHADOWS_VISIBILITY.InspectInList_Nested().Nl();


                       // "Cloud Shadows".PegiLabel().Edit(ref _cloudShadowsTexture).Nl().OnChanged(()=> CLOUD_SHADOWS_TEXTURE.GlobalValue = _cloudShadowsTexture);

                        if (changed) 
                        {
                            this.SkipLerp();
                        }

                        pegi.Nl();

                    }

                    if (Singleton.TryGet<Singleton_LayeredVolumetricFog>(out var layerFog))
                        layerFog.Enter_Inspect().Nl();

                    if (Singleton.TryGet<Singleton_WindManager>(out var windMgmt))
                        windMgmt.Enter_Inspect().Nl();

                    if ("Configs".PegiLabel().IsEntered().Nl())
                    {
                        ConfigurationsSO_Base.Inspect(ref Configs).OnChanged(() => Singleton.Try<Singleton_QcRendering>(s => s.SetBakingDirty(reason: "Weather Config changed", invalidateResult: true)));
                    }

                    Singleton.Try<Singleton_SunAndMoonRotator>(s => s.Enter_Inspect().Nl(() =>
                    {
                        Mgmt.SetBakingDirty("Sun and Moon Changed", invalidateResult: false);
                    }));
                    
                    "HDRs".PegiLabel().Edit_Enter_Inspect(ref HDRs).Nl();

                    if (!LerpDone)
                    {
                        if ("Skip Lerp".PegiLabel().Click())
                            this.SkipLerp();

                        _lerpData.Nested_Inspect().Nl();
                    }
                    if (changed)
                    {
                        SetWeatherDirty(reason: "Inspector UI changes");
                        UpdateEffectiveSunColor();
                    }
                }
            }

            public void Inspect_SelectConfig() 
            {
                if (Configs)
                    Configs.Inspect_Select();
            }

            public pegi.ChangesToken Inspect_SelectConfig(ref string key)
            {
                var changes = pegi.ChangeTrackStart();
                if (Configs)
                    Configs.Inspect_Select(ref key);

                return changes;
            }

            public void InspectInList(ref int edited, int ind)
            {
                var changes = pegi.ChangeTrackStart();
                "Weather".PegiLabel().ClickEnter(ref edited, ind);

                if (!Configs)
                    "CFG".PegiLabel(60).Edit(ref Configs);
                else
                    pegi.Nested_Inspect(Configs.InspectShortcut, Configs);

                if (INDOORS.Enabled)
                    "NO SKY".PegiLabel(40).Write();
            }

#endregion
        }
    }
}