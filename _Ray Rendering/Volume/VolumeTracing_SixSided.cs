using PainterTool;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{

    public partial class Singleton_VolumeTracingBaker
    {
        [Serializable]
        private class BakerConfig
        {
            [SerializeField] public LogicWrappers.CountDownFromMax FramesToBake = new(100);
            [SerializeField] public LogicWrappers.CountDownFromMax FramesToSmooth = new(16);
            [SerializeField] public LogicWrappers.CountDownFromMax FramesToLight = new(4);

            public float Progress01 => 1f - 0.5f * (FramesToBake.Remaining01 + FramesToSmooth.Remaining01);

            public void Restart() 
            {
                FramesToBake.Restart();
                FramesToSmooth.Restart();
                FramesToLight.Restart();
            }
        }

        [Serializable]
        public class CubeMapped 
        {
            public bool IsActive = true;
           // public bool UsingTextureArray = false;

            internal static ShaderProperty.Feature RT_CUBEMAP_BAKING = new("RT_TO_CUBEMAP");
            internal ShaderProperty.VectorValue RT_CUBEMAP_BAKING_DIR = new("_RT_CubeMap_Direction");
            internal static ShaderProperty.FloatFeature RT_CUBEMAP_FADEIN = new(name: "_RT_CubeMap_FadeIn", featureDirective: "RT_FROM_CUBEMAP");
            [NonSerialized] private readonly ShaderProperty.FloatValue SMOOTHING_BAKING_TRANSPARENCY = new("Qc_SmoothingBakingTransparency");
            [NonSerialized] private bool readyToShow;
            [NonSerialized] public BakeStage Stage = BakeStage.Undefined;
            [NonSerialized] public int BakedTextureIndex;

            [SerializeField] private BakerConfig _fistPassBaking = new();
            [SerializeField] private BakerConfig _secondPassBaking = new();

            private readonly TracingPrimitives.VolumeTexture_ShaderTransform _transformInShader = new("Qc_CubeLight");


            private BakerConfig BakerConfig => readyToShow ? _secondPassBaking : _fistPassBaking;

            public enum BakeStage { Undefined, Invalidated, BakingEarlyPass, BakingSecondPass, PostEffects, Finished }

            public void Invalidate(Singleton_VolumeTracingBaker parent)
            {
               
                Stage = BakeStage.Invalidated;

                RT_CUBEMAP_FADEIN.GlobalValue = 0;

                for (int t = 0; t < 6; t++)
                {
                    var enm = (VolumeCubeMapped.Direction)t;
                    C_VolumeTexture.CubeSide tex = parent.volume[enm];
                    tex.IsDirty.CreateRequest();
                }
            }

            bool TryClearIfDirty(Singleton_VolumeTracingBaker parent, VolumeCubeMapped.Direction dir)
            {
                BakedTextureIndex = (int)dir;
                C_VolumeTexture.CubeSide tex = parent.volume[dir];

                if (tex.IsDirty.TryUseRequest())
                {
                    RenderTextureBuffersManager.Blit(Color.clear, tex.GetTexture() as RenderTexture);
                    return true;
                }

                return false;
            }

            void StartBakeSide(Singleton_VolumeTracingBaker parent, VolumeCubeMapped.Direction dir)
            {
                BakedTextureIndex = (int)dir;
                C_VolumeTexture.CubeSide tex = parent.volume[dir];

                parent.ClearDoubleBuffer();

                if (tex.IsDirty.TryUseRequest())
                {
                    RenderTextureBuffersManager.Blit(Color.clear, tex.GetTexture() as RenderTexture);
                }

                if (readyToShow)
                    Stage = BakeStage.BakingSecondPass;
                else
                    Stage = BakeStage.BakingEarlyPass;

                BakerConfig.Restart();
            }

            internal void OffsetResults(Singleton_VolumeTracingBaker parent) 
            {
                if (!IsActive)
                    return;

                using (RT_CUBEMAP_BAKING.EnableDisposible())
                {
                    for (int t = 0; t < 6; t++)
                    {
                        var enm = (VolumeCubeMapped.Direction)t;
                        C_VolumeTexture.CubeSide tex = parent.volume[enm];
                        if (!tex.IsDirty.IsRequested)
                        {
                            tex.SetTexture_AndShaderProperty(parent.volume, enm, parent._doubleBuffer.RenderFromAndSwapIn(tex.GetTexture() as RenderTexture, parent.offsetShader, andRelease: true));
                        }
                    }
                }

                Stage = BakeStage.Invalidated;

                parent.volume.ToTextureArray();
            }
            internal void UpdateVisibility() 
            {
                float target = (IsActive && readyToShow) ? 1 : 0; // ;  RT_CUBEMAP_FADEIN.GlobalValue = IsActive ? 1 : 0;

                if (RT_CUBEMAP_FADEIN.GlobalValue != target)
                    RT_CUBEMAP_FADEIN.GlobalValue = QcLerp.LerpBySpeed_Unscaled(RT_CUBEMAP_FADEIN.GlobalValue, target, 1);
            }

            internal void ManagedUpdate(Singleton_VolumeTracingBaker parent) 
            {
                UpdateVisibility();

                switch (Stage) 
                {
                    case BakeStage.Invalidated:

                        RT_CUBEMAP_FADEIN.GlobalValue = 0;
                        readyToShow = false;

                        for (int i=0; i < 6; i++) 
                        {
                            if (TryClearIfDirty(parent, (VolumeCubeMapped.Direction)i))
                                return;
                        }

                        if (!_transformInShader.TrySetPositionData())
                            return;

                        if (IsActive)
                        {
                            StartBakeSide(parent, 0);
                        }

                        break;

                    case BakeStage.BakingEarlyPass:
                    case BakeStage.BakingSecondPass:

                        if (!IsActive)
                            return;

                        var dir = (VolumeCubeMapped.Direction)BakedTextureIndex;
                        C_VolumeTexture.CubeSide tex = parent.volume[dir];

                        if (!BakerConfig.FramesToBake.IsFinished)
                        {
                            BakerConfig.FramesToBake.RemoveOne();
                            Bake();
                            break;
                        }

                        
                        if (!BakerConfig.FramesToSmooth.IsFinished)
                        {
                            Smooth();
                            BakerConfig.FramesToSmooth.RemoveOne();
                            break;
                        }

                        Stage = BakeStage.PostEffects;

                        break;

                        void Smooth() 
                        {
                            var tmp = tex.GetTexture() as RenderTexture;
                            SMOOTHING_BAKING_TRANSPARENCY.GlobalValue = 1f/(1+ BakerConfig.FramesToSmooth.CompletedCount);
                            RT_CUBEMAP_BAKING.Enabled = true;
                            parent._doubleBuffer.BlitTargetWithPreviousAndSwap(ref tmp, parent.smoothingShader, andRelease: true);
                            RT_CUBEMAP_BAKING.Enabled = false;
                            tex.SetTexture_AndShaderProperty(parent.volume, dir, tmp);
                        }

                        void Bake()
                        {
                            var bakeVector = (VolumeCubeMapped.Direction)BakedTextureIndex;

                            RT_CUBEMAP_BAKING_DIR.GlobalValue = bakeVector.ToVector().ToVector4(0);
                            RT_CUBEMAP_BAKING.Enabled = true;

                            try 
                            {
                                parent.Blit(null, parent._doubleBuffer.Target, parent.bakingShader);
                            } catch (Exception ex) 
                            {
                                Debug.LogException(ex);
                            }

                            RT_CUBEMAP_BAKING.Enabled = false;
                        }

                    case BakeStage.PostEffects:

                        var dir2 = (VolumeCubeMapped.Direction)BakedTextureIndex;
                        C_VolumeTexture.CubeSide volSide = parent.volume[dir2];

                        if (!BakerConfig.FramesToLight.IsFinished)
                        {
                            var tmp = volSide.GetTexture() as RenderTexture;
                            RT_CUBEMAP_BAKING.Enabled = true;
                            parent._doubleBuffer.BlitTargetWithPreviousAndSwap(ref tmp, parent.postEffectsShader, andRelease: true);
                            RT_CUBEMAP_BAKING.Enabled = false;
                            volSide.SetTexture_AndShaderProperty(parent.volume, dir2, tmp);
                            BakerConfig.FramesToLight.RemoveOne();
                            break;
                        }
                        else
                        {
                            parent.volume.ToTextureArray(BakedTextureIndex, volSide.GetTexture());
                        }

                        if (BakedTextureIndex < 5)
                        {
                            StartBakeSide(parent, (VolumeCubeMapped.Direction)(BakedTextureIndex + 1));
                            break;
                        }

                        if (readyToShow)
                        {
                            Stage = BakeStage.Finished;
                        }
                        else
                        {
                            readyToShow = true;
                            StartBakeSide(parent, 0);
                        }

                        break;

                  

                }
            }

            public void ManagedOnEnable() 
            {

            }

            public void ManagedOnDisable() 
            {
                RT_CUBEMAP_FADEIN.GlobalValue = 0;
            }



            #region Inspector

            private readonly pegi.EnterExitContext context = new();

            public void Inspect(Singleton_VolumeTracingBaker parent)
            {
                using (context.StartContext()) 
                {
                    if (context.IsAnyEntered == false)
                    {
                        if (QualitySettings.anisotropicFiltering == AnisotropicFiltering.ForceEnable)
                        {
                            "Anisotropic filtering should be PER TEXTURE to avoid artifacts".PegiLabel().Write_Hint().Nl();
                        }

                        "Is Active".PegiLabel().ToggleIcon(ref IsActive);
                      
                        RT_CUBEMAP_FADEIN.Nested_Inspect();

                        pegi.Nl();

                      //  "Texture Array".PegiLabel().ToggleIcon(ref UsingTextureArray).Nl();

                        if ("Copy to Texture Array".PegiLabel().Click().Nl())
                            parent.volume.ToTextureArray();

                        if (IsActive && "Restart All".PegiLabel().Click().Nl())
                            Invalidate(parent);

                        switch (Stage)
                        {
                            case BakeStage.Finished:
                                Icon.Done.Draw();
                                if ("Bake More".PegiLabel().Click())
                                    StartBakeSide(parent, 0);
                                break;

                            case BakeStage.BakingEarlyPass:

                                goto case BakeStage.BakingSecondPass;

                            case BakeStage.BakingSecondPass:

                                var enm = (VolumeCubeMapped.Direction)BakedTextureIndex;

                                float progress = Stage == BakeStage.BakingEarlyPass ? 0 : 0.5f;

                                progress += (BakedTextureIndex + BakerConfig.Progress01) / 6f * 0.5f;

                                "Baking {0} ({1})".F(enm, BakedTextureIndex).PegiLabel().DrawProgressBar(progress);

                                C_VolumeTexture.CubeSide side = parent.volume[enm];

                                pegi.Nl();

                                if (BakerConfig.FramesToBake.IsFinished)
                                {
                                   // if (UsingTextureArray)
                                   // {
                                        var arr = parent.volume.cubeArray;
                                        if (arr)
                                            pegi.TryDefaultInspect(arr);
                                   /* }
                                    else
                                    {
                                        pegi.Draw(side.GetTexture(), 256).Nl();
                                    }*/
                                } else 
                                {
                                    pegi.Draw(parent._doubleBuffer.Target, 256).Nl();
                                }

                                break;


                            default:
                                Stage.ToString().PegiLabel(pegi.Styles.BaldText).Nl();
                                break;
                        }

                        pegi.Nl();
                    }

                    if ("Cubemap".PegiLabel().IsEntered().Nl())
                    {
                        for (int t = 0; t < 6; t++)
                        {
                            var enm = (VolumeCubeMapped.Direction)t;
                            C_VolumeTexture.CubeSide tex = parent.volume[enm];

                            switch (Stage)
                            {
                                case BakeStage.BakingEarlyPass:
                                case BakeStage.BakingSecondPass:

                                    if (BakedTextureIndex < t)
                                        Icon.Wait.Draw();
                                    else if (BakedTextureIndex == t)
                                    {
                                        "Baking".PegiLabel().DrawProgressBar(BakerConfig.FramesToBake.Remaining01);
                                    }
                                    else
                                        (tex.IsDirty.IsRequested ? Icon.Empty : Icon.Done).Draw();

                                    break;

                            }


                            if (BakedTextureIndex != t && "Bake".PegiLabel().Click())
                                StartBakeSide(parent, enm);

                            enm.ToString().PegiLabel().Nl();
                            tex.Nested_Inspect().Nl();
                        }
                    }

                    _transformInShader.Enter_Inspect().Nl();
                }

            }
            #endregion
        }
    }
}
