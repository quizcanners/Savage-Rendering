using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        [Serializable]
        public class TraceToMeshTexture : IPEGI
        {
            [SerializeField] private Shader _bakeMeshToTexture;

            [SerializeField] private MaterialInstancer.ByShader _material = new();

            Matrix4x4 _objectPositionMatrix;
            Matrix4x4 _cameraViewMatrix;
            Matrix4x4 _cameraProjectionMatrix;
            UnityEngine.Rendering.CommandBuffer _commandBuffer;
            private readonly Gate.Bool _initialized = new();

            void CheckInitialized() 
            {
                if (!_initialized.TryChange(true))
                    return;

                _objectPositionMatrix = Matrix4x4.TRS(Vector3.forward, Quaternion.identity, Vector3.one);

                _commandBuffer = new UnityEngine.Rendering.CommandBuffer
                {
                    name = "Bake Light buffer"
                };

                _cameraViewMatrix = Matrix4x4.TRS(new Vector3(0,0,-10),Quaternion.identity, Vector3.one);

                _cameraProjectionMatrix = Matrix4x4.Ortho(0, 1, 0, 1, 0.1f, 100f);
            }


           

            public void BakeLightFor(MeshRenderer _rendy, RenderTexture _texture, int _submesh) 
            {
                CheckInitialized();

                _commandBuffer.Clear();

                _commandBuffer.SetViewMatrix(_cameraViewMatrix);
                _commandBuffer.SetProjectionMatrix(_cameraProjectionMatrix);

                _commandBuffer.SetRenderTarget(_texture);

                _commandBuffer.DrawRenderer(_rendy, _material.Get(_bakeMeshToTexture), _submesh);

                Graphics.ExecuteCommandBuffer(_commandBuffer);
            }

            #region Inspector

            public override string ToString() => "Trace to Mesh";

            public void Inspect()
            {
                "Baker Shader".PegiLabel().Edit(ref _bakeMeshToTexture).Nl();   
            }
            #endregion
        }
    }
}
