using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{

    [Serializable]
    public class TransformToMeshDataBake : IPEGI, INeedAttention
    {
        [SerializeField] public MeshFilter meshFilter;
        [SerializeField] private Mesh originalMesh;
        private Mesh meshInstance;
        private Color _myColor = Color.white;


        public int DataVersion { get; private set; }

        public Color MyColor
        {
            get => _myColor;
            set 
            {
                _myColor = value;
                _position.ValueIsDefined = false;
            }
        }

        public Mesh GetMesh(bool isStatic) 
        {
            if (!meshInstance && Application.isPlaying)
            {
                UpdateMeshData();
            } else if (!isStatic)
                CheckMeshData();

            return meshInstance;
        }

        private void UpdateMeshData()
        {
            if (!meshFilter || !meshFilter.sharedMesh)
                return;

            var go = meshFilter.gameObject;

            if (QcUnity.IsPartOfAPrefab(go))
                return;
                
            var tf = go.transform;

            if (!meshInstance)
            {
                if (meshFilter.sharedMesh.isReadable == false) 
                {
                    QcLog.ChillLogger.LogErrorOnce("Mesh {0} is not readable".F(meshFilter.sharedMesh.name), key: meshFilter.sharedMesh.name, meshFilter.sharedMesh);
                }

                originalMesh = meshFilter.sharedMesh;
                meshInstance = UnityEngine.Object.Instantiate(meshFilter.sharedMesh); // meshFilter.mesh;
                
                meshInstance.name = "Instanciated Mesh";
            }

            var globalScaleInLocalRotation = tf.lossyScale; //tf.rotation * tf.lossyScale;


            meshInstance.SetUVs(0, CreateData(tf.position.ToVector4()));
            meshInstance.SetUVs(1, CreateData(globalScaleInLocalRotation.ToVector4(0))); //tf.localScale.ToVector4(0)));

            var rot = tf.rotation.ToVector4();
            rot = new Vector4(-rot.x, -rot.y, -rot.z, rot.w);

            meshInstance.SetUVs(2, CreateData(rot));
            meshInstance.colors = CreateData(MyColor);
                
            T[] CreateData<T>(T value)
            {
                var arr = new T[meshInstance.vertexCount];
                for (int i = 0; i < arr.Length; i++)
                    arr[i] = value;

                return arr;
            }

            meshFilter.sharedMesh = meshInstance;

            DataVersion++;
            _position.TryChange(tf.position);
            _rotation.TryChange(tf.rotation);
            _sizeGate.TryChange(tf.lossyScale);
        }

        public void Managed_OnDisable() 
        {
            if (meshInstance)
            {
                meshInstance.DestroyWhateverUnityObject();
                meshInstance = null;
            }

            if (originalMesh)
            {
                meshFilter.sharedMesh = originalMesh;
            }
        }

        public void Managed_OnEnable() 
        {
            if (!originalMesh)
            {
                originalMesh = meshFilter.sharedMesh;
            }

            UpdateMeshData();
        }

        private readonly Gate.Vector3Value _position = new();
        private readonly Gate.Vector3Value _sizeGate = new();
        private readonly Gate.QuaternionValue _rotation = new();
        private readonly Gate.Frame _frameGate = new();
        public void Managed_LateUpdate() 
        {
            CheckMeshData();
        }


        private void CheckMeshData() 
        {
            if (!meshFilter)
                return;

            if (!_frameGate.TryEnter())
                return;

            var tf = meshFilter.gameObject.transform;

            if (_position.TryChange(tf.position) | _rotation.TryChange(tf.rotation) | _sizeGate.TryChange(tf.lossyScale))
                UpdateMeshData();
        }

        public void OnReset(Transform parent) 
        {
            meshFilter = parent.GetComponent<MeshFilter>();
        }


        #region Inspector

        public override string ToString() => "Write Transform into Mesh";

        void IPEGI.Inspect()
        {
            var changed = pegi.ChangeTrackStart();

       
            if (!meshFilter)
            {
                pegi.Edit_IfNull(ref meshFilter, (pegi.InspectedUnityObject as Component).gameObject);

                pegi.Nl();
            }
            else
            {
                var go = meshFilter.gameObject;

                if (!Application.isPlaying && QcUnity.IsPartOfAPrefab(go))
                    "Will not modify mesh of a prefab - this will lead to errors".PegiLabel().WriteWarning().Nl();

                if (meshFilter.sharedMesh
                   && meshFilter.sharedMesh.vertexCount >= 3
                    && Application.isPlaying
                 && !QcUnity.IsPartOfAPrefab(go))
                    pegi.Click(UpdateMeshData).Nl();
            }

            "Dynamic batching needs to be enabled for this to work correctly".PegiLabel().Write_Hint().Nl();

            if (changed)
                UpdateMeshData();
        }

        public string NeedAttention()
        {
            if (!meshFilter)
                return "Mesh filter is NULL";

            if (!meshFilter.sharedMesh)
                return "meshFilter.sharedMesh in NULL";

            if (!meshFilter.sharedMesh.isReadable)
                return "mesh isn't readable";

            if (meshFilter.sharedMesh.vertexCount < 3)
                return "There are less then 3 vertices in the mesh. Something went wrong";

            return null;
        }

        #endregion
    }

}