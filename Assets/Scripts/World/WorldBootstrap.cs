using UnityEngine;

namespace NovaCraft.World
{
    public sealed class WorldBootstrap : MonoBehaviour
    {
        private void Awake()
        {
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            QualitySettings.shadows = ShadowQuality.Disable;
            QualitySettings.antiAliasing = 0;

            var player = new GameObject("Player");
            player.transform.position = new Vector3(8, 70, 8);
            var controller = player.AddComponent<CharacterController>();
            controller.height = 1.8f;
            controller.radius = 0.32f;
            controller.center = new Vector3(0, 0.9f, 0);

            var cameraObject = new GameObject("Main Camera");
            cameraObject.tag = "MainCamera";
            cameraObject.transform.SetParent(player.transform, false);
            cameraObject.transform.localPosition = new Vector3(0, 1.55f, 0);
            cameraObject.AddComponent<Camera>();
            cameraObject.AddComponent<AudioListener>();

            player.AddComponent<MobileVoxelPlayer>();
            player.AddComponent<MobileVoxelInteraction>();

            var worldObject = new GameObject("VoxelWorld");
            var world = worldObject.AddComponent<VoxelWorld>();
            world.Player = player.transform;
        }
    }

    public sealed class MobileVoxelPlayer : MonoBehaviour
    {
        [SerializeField] private float moveSpeed = 5f;
        [SerializeField] private float lookSensitivity = 0.12f;
        [SerializeField] private float gravity = -22f;
        private CharacterController controller;
        private Transform view;
        private float pitch;
        private float verticalVelocity;
        private int lookFinger = -1;
        private bool jumpRequested;

        public void RequestJump() { jumpRequested = true; }

        private void Start()
        {
            controller = GetComponent<CharacterController>();
            view = GetComponentInChildren<Camera>().transform;
            if (Application.isEditor) Cursor.lockState = CursorLockMode.Locked;
        }

        private void Update()
        {
            Vector2 move = Vector2.zero;
            Vector2 look = Vector2.zero;
            if (Application.isEditor)
            {
                move = new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
                look = new Vector2(Input.GetAxis("Mouse X") * 3f, Input.GetAxis("Mouse Y") * 3f);
                if (Input.GetKeyDown(KeyCode.Space)) jumpRequested = true;
            }
            else
            {
                for (int i = 0; i < Input.touchCount; i++)
                {
                    Touch touch = Input.GetTouch(i);
                    if (touch.position.x < Screen.width * 0.45f)
                    {
                        Vector2 p = new Vector2(touch.position.x / Screen.width, touch.position.y / Screen.height);
                        move = Vector2.ClampMagnitude(new Vector2((p.x - 0.22f) * 4f, (p.y - 0.28f) * 4f), 1f);
                    }
                    else
                    {
                        if (touch.phase == TouchPhase.Began) lookFinger = touch.fingerId;
                        if (touch.fingerId == lookFinger)
                        {
                            look += touch.deltaPosition * lookSensitivity;
                            if (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled) lookFinger = -1;
                        }
                    }
                }
            }

            if (jumpRequested && controller.isGrounded) verticalVelocity = 7f;
            jumpRequested = false;

            transform.Rotate(0, look.x, 0);
            pitch = Mathf.Clamp(pitch - look.y, -85f, 85f);
            view.localRotation = Quaternion.Euler(pitch, 0, 0);
            if (controller.isGrounded && verticalVelocity < 0) verticalVelocity = -2f;
            verticalVelocity += gravity * Time.deltaTime;
            Vector3 direction = transform.right * move.x + transform.forward * move.y;
            controller.Move((direction * moveSpeed + Vector3.up * verticalVelocity) * Time.deltaTime);
        }
    }
}