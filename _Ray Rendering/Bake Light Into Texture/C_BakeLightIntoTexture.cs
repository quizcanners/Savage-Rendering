using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public class C_BakeLightIntoTexture : MonoBehaviour, IPEGI
    {
        [SerializeField] private MeshRenderer _rendy;

        private bool _continiousBaking;

        private int _previousSubmesh = 0;

        private readonly OnDemandRenderTexture.Single _texture = new("For Light Bake", 256, isFloat: true, isColor: false, singleChannel: false);

        private readonly ShaderProperty.TextureValue _lightTexture = new("_TracedLightTex");
        void BakeLight()
        {
            if (!Singleton.TryGet<Singleton_QcRendering>(out var rtx))
            {
                Debug.LogError("No Rtx Manager");
                return;
            }

            if (_previousSubmesh >= _rendy.sharedMaterials.Length) 
            {
                _previousSubmesh = 0;
            }

            rtx.TraceIntoMeshTexture.BakeLightFor(_rendy, _texture.GetRenderTexture(), _previousSubmesh);

            _lightTexture.SetOn(_rendy.materials[_previousSubmesh], _texture.GetRenderTexture());
            
            _previousSubmesh++;
        }

        void Update() 
        {
            if (_continiousBaking)
                BakeLight();
        }

        #region Inspector

        public override string ToString() => "Light Bake";

        public void Inspect()
        {
            "Rendy".PegiLabel().Edit_IfNull(ref _rendy, gameObject).Nl();

            if ("Clear".PegiLabel().Click().Nl())
                _texture.Clear();

            "Continious Bake".PegiLabel().ToggleIcon(ref _continiousBaking).Nl();

            if (!_continiousBaking)
                pegi.Click(BakeLight).Nl().Nl();
        }
        #endregion

        void OnDisable() 
        {
            _texture.Clear();
        }
    }

    [PEGI_Inspector_Override(typeof(C_BakeLightIntoTexture))]
    internal class C_BakeLightIntoTextureDrawer : PEGI_Inspector_Override { }
}
