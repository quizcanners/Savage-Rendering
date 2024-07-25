using QuizCanners.Inspect;
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    [SelectionBase]
    [ExecuteAlways]
    public class C_TerrainAllign : C_TerrainAllign_Base
    {
        [SerializeField] private bool _allowUnderwater;

        private bool _randomizationApplied;

        [Header("Allignment Configuration")]
      
        [SerializeField] private float _yOffset;
        [SerializeField] private bool _allignRotation;
        [SerializeField] private float _randomizeSize01;
        [SerializeField] private bool _randomizeRotation;
        [SerializeField] private float _randomizedYaw01;
        [SerializeField] private bool _preserveScale;
     //   [SerializeField] private float _scale = 1;

       

        public override void AllignToTerrain()
        {
            if (!_randomizationApplied) 
            {
                _randomizationApplied = true;
                if (_randomizeRotation)
                {
                    _randomizeRotation = false;
                    var randDirection = Random.insideUnitSphere;
                    randDirection.y *= _randomizedYaw01;
                    transform.LookAt(randDirection);
                }

                if (_randomizeSize01 > 0)
                {
                    transform.localScale *= Mathf.Lerp(1, 0.75f + (Random.value) * 1.25f, _randomizeSize01);
                    _randomizeSize01 = 0;
                }
            }

            TerrainBaking.AllignToTerrain(transform, allignRotation: _allignRotation, yOffset: _yOffset * transform.lossyScale.y);

            if (_preserveScale) 
            {
               
               // transform.SetLossyScale(Vector3.one * _scale);
            }

            /*
            if (Application.isPlaying && !_allowUnderwater && transform.position.y < TerrainManagerBase.s_baseInstance._baker.GetWaterLevel)
            {
                gameObject.SetActive(false);
            }
            */
        }

        public override void Inspect()
        {
            base.Inspect();

            pegi.Click(SetOffsetFromBoundingBox).Nl();

            void SetOffsetFromBoundingBox() 
            {
                var mr = GetComponent<Renderer>();

                if (!mr) 
                {
                    var lods = GetComponent<LODGroup>();

                    if (!lods)
                    {
                        Debug.LogError("No Mesh Renderer or LOD Group");
                        return;
                    }

                    mr = lods.GetLODs()[0].renderers[0];
                }

                _yOffset =  -(mr.bounds.min.y - transform.position.y) / transform.lossyScale.y;

            }
                
            

        }


    }


    [PEGI_Inspector_Override(typeof(C_TerrainAllign))]
    internal class C_TerrainAllignDrawer : PEGI_Inspector_Override { }
}
