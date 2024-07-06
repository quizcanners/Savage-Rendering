using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    [ExecuteAlways]
    public class C_RayT_PostAffector : MonoBehaviour, IPEGI, INeedAttention
    {
        public TracingPrimitives.PostBakingEffects.ElementType Type;
        public Color LightColor;
        public float Angle = 0.5f;

        void OnEnable() 
        {
            TracingPrimitives.s_postEffets.Register(this);
        }

        void OnDisable() 
        {
            TracingPrimitives.s_postEffets.UnRegister(this);
        }

        #region Inspector

        public override string ToString() => Type.ToString() + " " + gameObject.name;

        private readonly Gate.Vector3Value _position = new();


        void IPEGI.Inspect()
        {
            var changes = pegi.ChangeTrackStart();
            "Type".PegiLabel(50).Edit_Enum(ref Type).Nl();
            "Color".PegiLabel(60).Edit(ref LightColor, hdr: true).Nl();

            if (Type == TracingPrimitives.PostBakingEffects.ElementType.Projector)
            {
                "Angle".PegiLabel().Edit(ref Angle, 0f, 1f).Nl();
            }

            if (_position.TryChange(transform.position) || changes) 
            {
                TracingPrimitives.OnArrangementChanged();
            }
        }

        public string NeedAttention()
        {
            if (transform.lossyScale.x > 20f)
                return "The scale is " + transform.lossyScale.x;

            return null;
        }
        #endregion
    }

    [PEGI_Inspector_Override(typeof(C_RayT_PostAffector))]
    internal class C_RayT_PostAffector_EnvironmentElementDrawer : PEGI_Inspector_Override { }
}
