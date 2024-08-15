using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.SavageTurret
{
    [ExecuteAlways]
    public class Singleton_WindManager : Singleton.BehaniourBase, ICfg
    {
        private readonly ShaderProperty.VectorValue WIND_DIRECTION = new("qc_WindDirection");
        private readonly ShaderProperty.VectorValue WIND_PARAMETERS = new("qc_WindParameters");
        private readonly ShaderProperty.VectorValue WIND_PUSH_POSITION = new("_qc_WindPush_Position");
        private readonly ShaderProperty.VectorValue EXPLOSION_DYNAMICS = new("_qc_WindPush_Dynamics");


        public Vector3 Position 
        {
            get => WIND_PUSH_POSITION.latestValue;
            set => WIND_PUSH_POSITION.GlobalValue = value;
        }

        public float Force
        {
            get => EXPLOSION_DYNAMICS.latestValue.x;
            set => EXPLOSION_DYNAMICS.GlobalValue = EXPLOSION_DYNAMICS.latestValue.X(value);
        }

        public float Radius
        {
            get => EXPLOSION_DYNAMICS.latestValue.y;
            set => EXPLOSION_DYNAMICS.GlobalValue = EXPLOSION_DYNAMICS.latestValue.Y(value);
        }

        public Vector3 Direction
        {
            get => WIND_DIRECTION.latestValue;
            set => WIND_DIRECTION.SetGlobal(value.ToVector4(WIND_DIRECTION.latestValue.w));
        }

        public float WindIntensity
        {
            get => WIND_PARAMETERS.latestValue.y;
            set => WIND_PARAMETERS.GlobalValue = WIND_PARAMETERS.latestValue.Y(value);
        }

        private bool Active 
        {
            get => WindIntensity > 0;
            set => WindIntensity = value ? 0.75f : 0f;
        }

        public float WindFrequency 
        {
            get => WIND_PARAMETERS.latestValue.x;
            set => WIND_PARAMETERS.GlobalValue = WIND_PARAMETERS.latestValue.X(value);
        }

        public float WindSpeed
        {
            get => WIND_PARAMETERS.latestValue.z;
            set => WIND_PARAMETERS.GlobalValue = WIND_PARAMETERS.latestValue.Z(value);
        }

        public void PlayExplosion(Vector3 center, float force) 
        {

        }

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();

            Direction = Vector3.forward;
            WindFrequency = 0.1f;
        }

        #region Encode & Decode

        public CfgEncoder Encode() => new CfgEncoder()
            .Add("int", WindIntensity)
            .Add("Frq", WindFrequency)
            .Add("Speed", WindSpeed)
            .Add("Dir", WIND_DIRECTION.GlobalValue);

        public void DecodeTag(string key, CfgData data)
        {
            switch (key) 
            {
                case "int": WindIntensity = data.ToFloat(); break;
                case "Frq": WindFrequency = data.ToFloat(); break;
                case "Speed": WindSpeed = data.ToFloat(); break;
                case "Dir": WIND_DIRECTION.GlobalValue = data.ToVector3(); break;
            }
        }

        #endregion

        #region Inspector

        public override void Inspect()
        {
            var dir = Direction;
            "Direction".PegiLabel().Edit(ref dir).Nl(()=> Direction = dir );

            float intn = WindIntensity;
            "Intensity".PegiLabel().Edit_01(ref  intn).Nl(()=> WindIntensity = intn);

            float spd = WindSpeed;
            "Speed".PegiLabel().Edit(ref spd).Nl(() => WindSpeed = spd);

            float frq = WindFrequency;
            "Frequancy".PegiLabel().Edit(ref frq).Nl(() => WindFrequency = frq );
        }

        public override void InspectInList(ref int edited, int ind)
        {
            var act = Active;

            pegi.ToggleIcon(ref act).OnChanged(()=> Active = act);

            base.InspectInList(ref edited, ind);
        }

        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_WindManager))]
    internal class Singleton_WindManagerDrawer : PEGI_Inspector_Override { }
}
