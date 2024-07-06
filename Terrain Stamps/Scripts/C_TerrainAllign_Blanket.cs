using QuizCanners.Inspect;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    [SelectionBase]
    [ExecuteAlways]
    public class C_TerrainAllign_Blanket : C_TerrainAllign_Base, IPEGI
    {
        [SerializeField] private List<Renderer> _rendys;

        protected override void OnEnable()
        {
            base.OnEnable();
        }

        private void Reset()
        {

            var lod = GetComponent<LODGroup>();

            if (lod) 
            {
                foreach (var l in lod.GetLODs()) 
                {
                    foreach (var r in l.renderers)
                        _rendys.Add(r);
                }

                return;
            }

            _rendys = new()
            {
                GetComponent<Renderer>()
            };
        }

        public override void AllignToTerrain()
        {
            TerrainBaking.AllignToTerrain(transform, allignRotation: false, yOffset: 0);

            foreach (var r in _rendys)
            {
                if (!r)
                    continue;

                r.ResetBounds();

                if (Application.isPlaying)
                {
                    var newBounds = r.bounds;
                    var ext = newBounds.extents;
                    ext.y = Mathf.Max(ext.y * 2, ext.x, ext.z);
                    newBounds.extents = ext;
                    r.bounds = newBounds;
                }
            }
        }


        public void OnDrawGizmosSelected()
        {
            if (_rendys == null || _rendys.Count==0)
                return;

            var first = _rendys[0];

            if (!first)
                return;

            var bounds = first.bounds;
            Gizmos.matrix = Matrix4x4.identity;
            Gizmos.color = Color.blue;
            Gizmos.DrawWireCube(bounds.center, bounds.extents * 2);
        }

    }

    [PEGI_Inspector_Override(typeof(C_TerrainAllign_Blanket))]
    internal class C_TerrainAllign_BlanketDrawer : PEGI_Inspector_Override { }
}
