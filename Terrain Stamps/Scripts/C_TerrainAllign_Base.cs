using QuizCanners.Inspect;
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    public abstract class C_TerrainAllign_Base : MonoBehaviour, IPEGI
    {
    
        public abstract void AllignToTerrain();


        protected virtual void OnEnable()
        {
            TerrainBaking.s_allignToTerrainTargets.Add(this);
            TerrainBaking.AllignToTerrainVersion++;
        }

        protected virtual void OnDisable()
        {
            TerrainBaking.s_allignToTerrainTargets.Remove(this);
        }

        public virtual void Inspect()
        {
            pegi.Click(AllignToTerrain).Nl();

            pegi.TryDefaultInspect(this);
        }
    }
}
