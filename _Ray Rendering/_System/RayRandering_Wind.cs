using UnityEngine;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Migration;
using QuizCanners.Utils;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        public class Wind : IPEGI, IPEGI_ListInspect, ICfgCustom, ILinkedLerping
        {
            private readonly LinkedLerp.Vector3Value windLerp = new("Wind Direction", maxSpeed: 1);
            private readonly LinkedLerp.FloatValue windSpeedLerp = new("Wind Speed");

            private Vector3 _windOffset;

            private readonly ShaderProperty.VectorValue windInShader = new("_qc_WindDirection" );


            internal void ManagedUpdate() 
            {
                _windOffset += Time.deltaTime * windLerp.currentValue * windSpeedLerp.CurrentValue;

                windInShader.GlobalValue = _windOffset.ToVector4();
            }

            #region Encode & Decode
            public void DecodeInternal(CfgData data)
            {
                this.DecodeTagsFrom(data);
            }

            public void DecodeTag(string key, CfgData data)
            {
                switch (key)
                {
                    case "wnd": windLerp.Decode(data); break;
                }
            }

            public CfgEncoder Encode()
                => new CfgEncoder().Add("wnd", windLerp);

            #endregion

            public void Clear()
            {
                windInShader.GlobalValue = Vector4.zero;
            }


            #region Inspector

            public override string ToString() => "Wind";

            void IPEGI.Inspect()
            {
                windLerp.Nested_Inspect().Nl();
            }

            void IPEGI_ListInspect.InspectInList(ref int edited, int index)
            {
                ToString().PegiLabel().Write();

              //  pegi.Edit(ref _windIntensity).Nl();

                if (Icon.Enter.Click())
                    edited = index;
            }
            #endregion


            #region Linked Lerp
            public void Portion(LerpData ld)
            {
                windLerp.Portion(ld);
                windSpeedLerp.Portion(ld);
            }

            public void Lerp(LerpData ld, bool canSkipLerp)
            {
                windLerp.Lerp(ld, canSkipLerp: canSkipLerp);



                windSpeedLerp.Lerp(ld, canSkipLerp: canSkipLerp);
            }
            #endregion
        }
    }

}
