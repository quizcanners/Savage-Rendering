using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public class C_BlanketShaderColliderAlligner : MonoBehaviour, IPEGI
    {
        [SerializeField] private MeshCollider _collider;

        private Mesh _originalMesh;

        public void AllignCollider() 
        {
            if (QcUnity.IsPartOfAPrefab(gameObject))
                return;

            var terrainMgmt = Singleton.Get<TerrainManagerBase>(); //.s_baseInstance;

            if (!terrainMgmt) 
            {
                Debug.LogError("No terrain");
                return;
            }

            if (!_originalMesh)
                _originalMesh = _collider.sharedMesh;

            Vector3[] verts;
            int[] tris;

            try
            {
                List<Vector3> vertsList = new();
                _originalMesh.GetVertices(vertsList);
                verts = vertsList.ToArray();
                tris = _originalMesh.GetTriangles(0);
            }
            catch (Exception ex)
            {
                Debug.LogException(ex);
                return;
            }

            var scale = transform.lossyScale;
            var objectPosition = transform.position;

            for (int i = 0; i < verts.Length; i++)
            {
                var local = verts[i];
                // var scaledLocalPos = Vector3.Scale(verts[i], scale);
                var terrainHeight = terrainMgmt.GetTerrainHeight(transform.TransformPoint(local));
                local.y += (terrainHeight - objectPosition.y) / scale.y;
                verts[i] = local;
            }

            var mesh = new Mesh
            {
                vertices = verts,
                triangles = tris
            };

            _collider.sharedMesh = mesh;
         
        }

        private void Reset()
        {
            _collider = GetComponent<MeshCollider>();
        }

        private void OnEnable()
        {
            TerrainBaking.EmbankmentManagement.s_colliderAlligners.Add(this);
        }

        private void OnDisable()
        {
            TerrainBaking.EmbankmentManagement.s_colliderAlligners.Remove(this);
            if (_originalMesh)
            {
                _collider.sharedMesh = _originalMesh;
                _originalMesh = null;
            }
        }

        public void Inspect()
        {
            pegi.Click(AllignCollider);

        }
    }

    [PEGI_Inspector_Override(typeof(C_BlanketShaderColliderAlligner))]
    internal class C_BlanketShaderColliderAllignerDrawer : PEGI_Inspector_Override { }
}
