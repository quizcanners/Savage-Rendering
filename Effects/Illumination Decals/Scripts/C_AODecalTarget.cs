using QuizCanners.Inspect;
using QuizCanners.Utils;
using QuizCanners.VolumeBakedRendering;
using UnityEngine;

namespace QuizCanners.SpecialEffects
{
    [ExecuteAlways]
    public class C_AODecalTarget : MonoBehaviour, IPEGI, INeedAttention
    {
        [SerializeField] private TransformToMeshDataBake _meshDataBake = new();
        [SerializeField] private MeshRenderer _renderer;
        public IlluminationDecals.AoMode Mode;
        [SerializeField] private Color _color = Color.white;

        public Color IlluminationData
        {
            get => _color;
            set
            {
                _color = value;
                _meshDataBake.MyColor = _color;
            }
        }

        public float Ambient
        {
            get => IlluminationData.g;
            set
            {
                var col = IlluminationData;
                col.g = value;
                IlluminationData = col;
            }
        }

        public float Boxing
        {
            get => IlluminationData.r;
            set
            {
                var col = IlluminationData;
                col.r = value;
                IlluminationData = col;
            }
        }

        public float Shadow
        {
            get => IlluminationData.b;
            set
            {
                var col = IlluminationData;
                col.b = value;
                IlluminationData = col;
            }
        }

        public int Version => _meshDataBake.DataVersion;

        public Mesh GetMesh(Mesh backupMesh)
        {
            if (_meshDataBake.meshFilter.sharedMesh == null) 
            {
                _meshDataBake.meshFilter.sharedMesh = backupMesh;
            }

            return _meshDataBake.GetMesh(gameObject.isStatic);//baker.GetMesh();
        }
        private void OnEnable()
        {
            _meshDataBake.MyColor = _color;
            _meshDataBake.Managed_OnEnable();

            if (Application.isPlaying)
            {
                if (gameObject.isStatic)
                    IlluminationDecals.s_staticAoDecalTargets.Add(this);
                else
                    IlluminationDecals.s_dynamicAoDecalTargets.Add(this);

                SetDirty();
                if (_renderer)
                    _renderer.enabled = false;
                else
                    Debug.LogError("Renderer not assigned", this);
            }
        }

        private void SetDirty()
        {
            if (gameObject.isStatic)
                IlluminationDecals.StaticDecalsVersion++;
            else
                IlluminationDecals.DynamicDecalsVersion++;
        }

        private void LateUpdate()
        {
            if (!gameObject.isStatic || !Application.isPlaying)
                _meshDataBake.Managed_LateUpdate();

#if UNITY_EDITOR
            if (_bakerVersion.TryChange(Version))
                SetDirty();
#endif
        }

        private void OnDisable()
        {
            _meshDataBake.Managed_OnDisable();

            if (Application.isPlaying)
            {
                if (gameObject.isStatic)
                    IlluminationDecals.s_staticAoDecalTargets.Remove(this);
                else
                    IlluminationDecals.s_dynamicAoDecalTargets.Remove(this);

                SetDirty();
            }
        }

        private readonly Gate.Integer _bakerVersion = new();

        void IPEGI.Inspect()
        {
            if (!Application.isPlaying && !gameObject.isStatic)
            {
                "Will be rendered s Dynamic Decal since object is not static".PegiLabel().Nl();
                if ("Make Static".PegiLabel().Click().Nl())
                    gameObject.isStatic = true;
            }

            if (!Application.isPlaying)
                _meshDataBake.Nested_Inspect().Nl();

            "Renderer".PegiLabel().Edit_IfNull(ref _renderer, gameObject).Nl();

            if (_meshDataBake.meshFilter && !_meshDataBake.meshFilter.sharedMesh && Singleton.TryGet<Singleton_IlluminationDecals>(out var mgmt)) 
            {
                if ("Fix mesh".PegiLabel().Click())
                    _meshDataBake.meshFilter.sharedMesh = mgmt.GetCubeMesh();
            }

            "Mode".PegiLabel(50).Edit_Enum(ref Mode).Nl();

            var box = Boxing;
            "Boxing (R)".PegiLabel(60).Edit_01(ref box).Nl(()=>
            {
                Boxing = box;
                _renderer.sharedMaterial.SetFloat("_Box", box);
            });

            float ao = Ambient; 
            "Ambient (G)".PegiLabel(50).Edit(ref ao, 0, 1).Nl(() => Ambient = ao);

            float shad = Shadow;
            "Shadow (B)".PegiLabel(50).Edit(ref shad, 0, 1).Nl(() => Shadow = shad);            
        }

        void Reset() 
        {
            _renderer = GetComponent<MeshRenderer>();
            _meshDataBake.OnReset(transform);
        }

        public string NeedAttention()
        {
            if (_meshDataBake.TryGetAttentionMessage(out var msg))
                return msg;

            if (!_renderer)
                return "Renderer not assigned";
            if (Shadow < 0.01f && Ambient < 0.01f)
                return "Values are low, no result will be visible";

            return null;
        }
    }

    [PEGI_Inspector_Override(typeof(C_AODecalTarget))]
    internal class C_AODecalTargetDrawer : PEGI_Inspector_Override { }
}
