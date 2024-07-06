using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        [Serializable]
        public class DirectLightsVolume : IPEGI, IPEGI_ListInspect
        {
            [SerializeField] private Shader bakingShader;
            private readonly OnDemandRenderTexture.Single _renderTexture = new("QcDirect", 1024, isFloat: false, isColor: false);

            private readonly ShaderProperty.TextureValue QC_DIRECT = new("Qc_DirectLights_Volume");

            private readonly TracingPrimitives.VolumeTexture_ShaderTransform _transformInShader = new("Qc_Direct");


            private int _bakeCounter;
            private readonly Gate.Integer generalVersion = new();

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
                    }
                    else
                    {
                        generalVersion.TryChange(VolumeTracing.SceneVersion);

                    }
                }
            }

            void Render()
            {
                Dirty = false;
                _bakeCounter++;
                TracingPrimitives.s_postEffets.UpdateDataInGPU();
                _renderTexture.Blit(bakingShader);
                QC_DIRECT.GlobalValue = _renderTexture.GetRenderTexture();
            }

            internal void ManagedUpdate(bool sdfUpdated)
            {
                if (!sdfUpdated)
                    return;

                if (Dirty && _transformInShader.TrySetPositionData())
                {
                    Render();
                }
            }

            internal void ManagedOnDisable()
            {
                _renderTexture.Clear();
            }

            internal void ManagedOnEnable()
            {

            }

         



            #region Inspector

            public override string ToString() => "Direct lights";

            public void Inspect()
            {
                "Bakes done: {0}".F(_bakeCounter).PegiLabel().Nl();

                "Baking SHader".PegiLabel().Edit(ref bakingShader).Nl();
                if (bakingShader && "Blit".PegiLabel().Click())
                    Render();

                _renderTexture.Nested_Inspect();

                _transformInShader.Nested_Inspect().Nl();
            }

            public void InspectInList(ref int edited, int index)
            {
                if (Icon.Enter.Click() | "{0} v.{1}".F(ToString(), _bakeCounter).PegiLabel().ClickLabel())
                    edited = index;


                if (Icon.Play.Click())
                    Render();
            }

    
            #endregion
        }
    }
}
