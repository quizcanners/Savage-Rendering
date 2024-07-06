using PainterTool;
using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{

    public static partial class TracingPrimitives
    {
        public class VolumeTexture_ShaderTransform : IPEGI
        {
            private string _name;

            private readonly ShaderProperty.MatrixValue DYMANIC_VOLUME_WTL_MATRIX;
            private readonly ShaderProperty.MatrixValue DYMANIC_VOLUME_LTW_MATRIX;
            private readonly ShaderProperty.FloatValue USE_DYNAMIC_VOLUME;

            private ShaderProperty.VectorValue _slicesInShader;
            private ShaderProperty.VectorValue _positionNsizeInShader;


            private ShaderProperty.VectorValue SlicesShadeProperty
            {
                get
                {
                    if (_slicesInShader != null)
                        return _slicesInShader;

                    _slicesInShader = new ShaderProperty.VectorValue(_name + "_VOLUME_H_SLICES");

                    return _slicesInShader;
                }
            }
            private ShaderProperty.VectorValue PositionAndScaleProperty
            {
                get
                {
                    if (_positionNsizeInShader != null)
                        return _positionNsizeInShader;

                    _positionNsizeInShader = new ShaderProperty.VectorValue(_name + "_VOLUME_POSITION_N_SIZE");

                    return _positionNsizeInShader;
                }
            }

            public bool TrySetPositionData() 
            {
                if (!Singleton.TryGet<Singleton_VolumeTracingBaker>(out var bkr))
                    return false;

                if (bkr.IsDymanicVolume)
                {
                    var inst = VolumeTracing.Stack.TryGetLast();

                    if (!inst)
                        return false;

                    SetDynamic_Internal(inst);
                    return true;
                }

                SetStatic_Internal(bkr.volume);
                return true;

                void SetDynamic_Internal(Inst_RtxVolumeSettings root)
                {
                    var tf = root.transform;
                    DYMANIC_VOLUME_WTL_MATRIX.GlobalValue = tf.worldToLocalMatrix;
                    DYMANIC_VOLUME_LTW_MATRIX.GlobalValue = tf.localToWorldMatrix;
                    USE_DYNAMIC_VOLUME.GlobalValue = 1;
                }

                void SetStatic_Internal(C_VolumeTexture tex)
                {
                    USE_DYNAMIC_VOLUME.GlobalValue = 0;
                    Vector4 res = tex.GetPositionAndSizeForShader();
                    PositionAndScaleProperty.SetGlobal(res);
                    SlicesShadeProperty.SetGlobal(tex.GetSlices4Shader());
                }

            }

            #region Inspector

            public override string ToString() => "{0} {1}".F(_name, USE_DYNAMIC_VOLUME.latestValue > 0.5f ? "Dynamic" : "Static");

            public void Inspect()
            {
                DYMANIC_VOLUME_WTL_MATRIX.Nested_Inspect().Nl();
                DYMANIC_VOLUME_LTW_MATRIX.Nested_Inspect().Nl();
                USE_DYNAMIC_VOLUME.Nested_Inspect().Nl();
                SlicesShadeProperty.Nested_Inspect().Nl();
                PositionAndScaleProperty.Nested_Inspect().Nl();
            }
            #endregion

            public VolumeTexture_ShaderTransform(string name) 
            {
                _name = name;

                DYMANIC_VOLUME_WTL_MATRIX = new(name: name + "_WorldToLocal");
                DYMANIC_VOLUME_LTW_MATRIX = new(name: name + "_LocalToWorld");
                USE_DYNAMIC_VOLUME = new(name: name + "_USE_DYNAMIC_RTX_VOLUME");
            }





        }
    }
}