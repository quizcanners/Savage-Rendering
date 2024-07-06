using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.SpecialEffects
{
    [ExecuteAlways]
    public class Singleton_IlluminationDecals : Singleton.BehaniourBase, IPEGI
    {
        public Camera Camera;
        [SerializeField] private DecalIlluminationPass IlluminationDecals = new();

        public Mesh GetCubeMesh() => IlluminationDecals.mesh;

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();
            if (Application.isPlaying)
                IlluminationDecals.OnEnable();
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            base.OnBeforeOnDisableOrEnterPlayMode(afterEnableCalled);

            if (Application.isPlaying)
                IlluminationDecals.OnDisable();
        }

        void OnPreRender()
        {
            if (Application.isPlaying)
                IlluminationDecals.OnPreRender();
        }

        void OnPostRender() 
        {
            if (Application.isPlaying)
                IlluminationDecals.OnPostRender();
        }

        #region Inspector

        public override void Inspect()
        {
            "Camera".PegiLabel().Edit_IfNull(ref Camera, gameObject).Nl();
            IlluminationDecals.Nested_Inspect();
        }

        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_IlluminationDecals))]
    internal class Singleton_IlluminationDecalsDrawer : PEGI_Inspector_Override { }
}
