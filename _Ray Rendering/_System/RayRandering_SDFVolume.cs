using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        [Serializable]
        public class SDFVolume : IPEGI, IPEGI_ListInspect
        {
            [SerializeField] private Shader bakingShader;

            private readonly OnDemandRenderTexture.Single _renderTexture = new("QcSDF", 1024, isFloat: false, isColor: false);
            private readonly ShaderProperty.TextureValue QC_SDF = new("Qc_SDF_Volume");
            private readonly ShaderProperty.FloatFeature QC_USE_SDF = new(name: "Qc_SDF_Visibility", "QC_USE_SDF_VOL");

            private readonly Gate.Integer generalVersion = new();
            private readonly Gate.Frame _afterEnableGap = new();

            private readonly TracingPrimitives.VolumeTexture_ShaderTransform _transformInShader = new("Qc_SDF");

            private int _bakeCounter;

            public bool Dirty
            {
                get
                {
                    if (generalVersion.IsDirty(VolumeTracing.SceneVersion))
                    {
                        return true;
                    }

                    return false;
                }
                set
                {
                    if (value)
                    {
                        generalVersion.ValueIsDefined = false;
                    } else 
                    {
                        generalVersion.TryChange(VolumeTracing.SceneVersion);
                       
                    }
                }
            }
            internal void ManagedUpdate(out bool sdfUpdated) 
            {
                if (Dirty && _transformInShader.TrySetPositionData())
                {
                    Render();
                }

                sdfUpdated = !Dirty;

                QC_USE_SDF.GlobalValue = QcLerp.LerpBySpeed(QC_USE_SDF.GlobalValue, to: Dirty ? 0 : 1, 1, unscaledTime: true);
            }

            internal void ManagedOnEnable()
            {
                _afterEnableGap.ValueIsDefined = false;
            }

            internal void ManagedOnDisable() 
            {
                QC_USE_SDF.GlobalValue = 0;
                _renderTexture.Clear();
            }

            void Render()
            {
                Dirty = false;
                _bakeCounter++;
                _renderTexture.Blit(bakingShader);
                QC_SDF.GlobalValue = _renderTexture.GetRenderTexture();
            }

            #region Inspector
            void IPEGI.Inspect()
            {
                "Bakes done: {0}".F(_bakeCounter).PegiLabel().Nl();

                "Baking SHader".PegiLabel().Edit(ref bakingShader).Nl();
                if (bakingShader && "Blit".PegiLabel().Click())
                    Render();

                _renderTexture.Nested_Inspect().Nl();

                _transformInShader.Nested_Inspect().Nl();
            }

            public override string ToString() => "SDF Baker";

            public void InspectInList(ref int edited, int index)
            {
                "{0} v.{1}".F(ToString(), _bakeCounter).PegiLabel().ClickEnter(ref edited, index);

                if (Icon.Play.Click())
                    Render();
            }

            #endregion
        }
    }
}