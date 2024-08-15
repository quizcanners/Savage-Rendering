using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;


namespace QuizCanners.VolumeBakedRendering
{
    [ExecuteAlways]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/Ray Tracing/Camera And Output")]
    public class Singleton_RayRenderingCameraAndOutput : Singleton.BehaniourBase
    {
        public Camera WorldCamera;
        public GameObject RayTracingOutput;

        private readonly ShaderProperty.TextureValue ScreenGrabTexture = new("qc_GeometryRender");

        [SerializeField] internal LayerMask rayTracingResultUiMask;
        [SerializeField] internal LayerMask defaultCameraMask;

        [SerializeField] private CameraClearFlags _defaultClearFlags = CameraClearFlags.Skybox;

        [NonSerialized] private int _oldFlags;

        public CameraOutputMode Mode { get; private set; }

        private RenderTexture _targetTexture;

        public enum CameraOutputMode 
        {
            Standard,
            TracingResult,
            ToRenderTexture
        }

        private readonly Gate.Bool _showingTracing = new();

        public bool TryRenderTo(RenderTexture texture) 
        {
            if (_showingTracing.CurrentValue)
                return false;

            _targetTexture = texture;
            WorldCamera.targetTexture = _targetTexture;
            Mode = CameraOutputMode.ToRenderTexture;
            ScreenGrabTexture.GlobalValue = texture;
            return true;
        }

        public void StopRenderingToRenderTexture() 
        {
            if (_showingTracing.CurrentValue)
                return;

            _targetTexture = null;
            WorldCamera.targetTexture = null;
            Mode = CameraOutputMode.Standard;
        }

        public bool ShowTracing
        {
            set
            {
                if (!_showingTracing.TryChange(value))
                    return;

                if (value)
                    Mode = CameraOutputMode.ToRenderTexture;
                else
                    Mode = _targetTexture ? CameraOutputMode.ToRenderTexture : CameraOutputMode.Standard;

                if (!RayTracingOutput)
                    QcLog.ChillLogger.LogErrorOnce("{0} is missing".F(nameof(RayTracingOutput)), key: "noRtOpt", this);
                else
                    RayTracingOutput.SetActive(value);

                if (!WorldCamera)
                {
                    QcLog.ChillLogger.LogErrorOnce("{0} is missing".F(nameof(WorldCamera)), key: "noWCOpt", this);
                    return;
                }

                WorldCamera.cullingMask = value ? rayTracingResultUiMask : defaultCameraMask; 
                WorldCamera.clearFlags = value ? CameraClearFlags.Nothing : _defaultClearFlags;

                if (!value)
                    WorldCamera.targetTexture = _targetTexture;
            }
        }

        protected override void OnAfterEnable()
        {
            if (WorldCamera)
            {
                _oldFlags = WorldCamera.cullingMask;
            }
            else
            {
                Debug.LogError("{0} service not found. default Flags not set correctly".F(nameof(Singleton_CameraOperatorConfigurable)));
            }
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            if (!WorldCamera) 
            {
                Debug.LogError("World Camera is not found", this);
                return;
            }

            WorldCamera.enabled = true;
            WorldCamera.targetTexture = null;
            WorldCamera.cullingMask = _oldFlags;
            WorldCamera.clearFlags = _defaultClearFlags;
        }

        private void Reset()
        {
            WorldCamera = GetComponent<Camera>();

        }

        #region Inspector

        public override string InspectedCategory => nameof(VolumeBakedRendering);

        public override string ToString() => "Baker Camera";

        public override string NeedAttention()
        {
            if (Application.isPlaying && !WorldCamera)
                return "{0} Not Assigned".F(nameof(WorldCamera));

            if (!RayTracingOutput)
                return "{0} Not Assigned".F(nameof(RayTracingOutput));
            return null; 
        }

        public override void Inspect()
        {
            "Tracing Quad".PegiLabel(pegi.Styles.ListLabel).Nl();

            "Camera".PegiLabel(60).Edit_IfNull(ref WorldCamera, gameObject).Nl();

            "Default Clear flags".PegiLabel().Edit_Enum(ref _defaultClearFlags);

            if (WorldCamera)
            {
                if ((_defaultClearFlags != WorldCamera.clearFlags) && Icon.Refresh.Click())
                    _defaultClearFlags = WorldCamera.clearFlags;
                pegi.Nl();

                var depthMode = WorldCamera.depthTextureMode;

                if ("Depth Mode".PegiLabel(90).Edit_EnumFlags(ref depthMode).Nl())
                    WorldCamera.depthTextureMode = depthMode;
            }

            pegi.Nl();

            //   "A UI Layer that is used when Main Camera is used for Tracing (Maybe create one) ".PegiLabel().edit_Property(() => rayTracingResultUiMask, this).nl();

            Icon.Refresh.Click(()=> rayTracingResultUiMask = WorldCamera.cullingMask);
            Icon.Play.Click(()=> WorldCamera.cullingMask = rayTracingResultUiMask);

            "Ray Traced Result".PegiLabel(70).Edit_Property(()=> rayTracingResultUiMask, this).Nl();

            Icon.Refresh.Click(() => defaultCameraMask = WorldCamera.cullingMask);
            Icon.Play.Click(() => WorldCamera.cullingMask = defaultCameraMask);

            "Geometry".PegiLabel(70).Edit_Property(() => defaultCameraMask, this);
           
     

            pegi.Nl();

            if (RayTracingOutput)
            {
                if (!rayTracingResultUiMask.Contains(RayTracingOutput.layer))
                {
                    "Tracing Result Mask Doesn't Contain Tracer's Layer".PegiLabel().WriteWarning();
                    pegi.ClickHighlight(RayTracingOutput);
                    pegi.Nl();
                }
            }
            else 
                "Output".PegiLabel().Edit(ref RayTracingOutput).Nl();
        }

        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_RayRenderingCameraAndOutput))] internal class RayRenderingTracingCameraVisualizerDrawer : PEGI_Inspector_Override { }
}