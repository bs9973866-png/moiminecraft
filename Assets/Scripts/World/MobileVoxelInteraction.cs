using System.Collections.Generic;
using UnityEngine;

namespace NovaCraft.World
{
    /// <summary>Simple touch-first block interaction and five-slot hotbar.</summary>
    public sealed class MobileVoxelInteraction : MonoBehaviour
    {
        [SerializeField, Range(2f, 8f)] private float reach = 5f;
        [SerializeField] private int startingStack = 24;

        private static readonly BlockType[] Hotbar =
        {
            BlockType.Stone, BlockType.Dirt, BlockType.Wood, BlockType.Sand, BlockType.Gravel
        };

        private readonly Dictionary<BlockType, int> inventory = new Dictionary<BlockType, int>();
        private Camera playerCamera;
        private VoxelWorld world;
        private int selected;
        private bool hasTarget;
        private RaycastHit targetHit;
        private GUIStyle buttonStyle;
        private GUIStyle labelStyle;

        private void Start()
        {
            playerCamera = GetComponentInChildren<Camera>();
            world = FindObjectOfType<VoxelWorld>();
            foreach (BlockType type in Hotbar) inventory[type] = startingStack;
            buttonStyle = new GUIStyle(GUI.skin.button) { fontSize = Mathf.Max(14, Screen.width / 48), alignment = TextAnchor.MiddleCenter };
            labelStyle = new GUIStyle(GUI.skin.label) { fontSize = Mathf.Max(14, Screen.width / 48), alignment = TextAnchor.MiddleCenter, normal = { textColor = Color.white } };
        }

        private void Update()
        {
            if (playerCamera == null || world == null) return;
            Ray ray = playerCamera.ViewportPointToRay(new Vector3(0.5f, 0.5f, 0f));
            hasTarget = Physics.Raycast(ray, out targetHit, reach, Physics.DefaultRaycastLayers, QueryTriggerInteraction.Ignore);

            if (Application.isEditor)
            {
                for (int i = 0; i < Hotbar.Length; i++)
                    if (Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1 + i))) selected = i;
                if (Input.GetMouseButtonDown(0)) BreakTarget();
                if (Input.GetMouseButtonDown(1)) PlaceBlock();
            }
        }

        private void BreakTarget()
        {
            if (!hasTarget || world == null) return;
            Vector3 point = targetHit.point - targetHit.normal * 0.015f;
            Vector3Int cell = new Vector3Int(Mathf.FloorToInt(point.x), Mathf.FloorToInt(point.y), Mathf.FloorToInt(point.z));
            BlockType block = world.GetBlock(cell);
            if (block == BlockType.Air || block == BlockType.Bedrock) return;
            if (world.SetBlock(cell, BlockType.Air))
            {
                if (!inventory.ContainsKey(block)) inventory[block] = 0;
                inventory[block] = Mathf.Min(999, inventory[block] + 1);
            }
        }

        private void PlaceBlock()
        {
            if (!hasTarget || world == null) return;
            BlockType type = Hotbar[selected];
            if (!inventory.TryGetValue(type, out int count) || count <= 0) return;

            Vector3 point = targetHit.point + targetHit.normal * 0.02f;
            Vector3Int cell = new Vector3Int(Mathf.FloorToInt(point.x), Mathf.FloorToInt(point.y), Mathf.FloorToInt(point.z));
            if (world.GetBlock(cell) != BlockType.Air) return;

            // Do not allow placing a block inside the player's capsule.
            Vector3 center = new Vector3(cell.x + 0.5f, cell.y + 0.5f, cell.z + 0.5f);
            if (Vector3.Distance(center, transform.position + Vector3.up * 0.9f) < 1.15f) return;

            if (world.SetBlock(cell, type)) inventory[type] = count - 1;
        }

        private void OnGUI()
        {
            if (buttonStyle == null) return;
            float scale = Mathf.Clamp(Screen.width / 900f, 0.72f, 1.35f);
            float button = 76f * scale;
            float margin = 18f * scale;

            // Center reticle.
            GUI.Label(new Rect(Screen.width * 0.5f - 12f, Screen.height * 0.5f - 22f, 24f, 44f), "+", labelStyle);

            // Five-slot hotbar, anchored above the bottom safe margin.
            float slot = 66f * scale;
            float total = Hotbar.Length * slot + (Hotbar.Length - 1) * 5f * scale;
            float startX = (Screen.width - total) * 0.5f;
            float y = Screen.height - slot - margin;
            for (int i = 0; i < Hotbar.Length; i++)
            {
                BlockType type = Hotbar[i];
                int amount = inventory.TryGetValue(type, out int value) ? value : 0;
                string caption = (i + 1) + "\\n" + type + "\\n" + amount;
                GUI.backgroundColor = i == selected ? new Color(0.35f, 0.75f, 1f) : new Color(0.22f, 0.24f, 0.30f);
                if (GUI.Button(new Rect(startX + i * (slot + 5f * scale), y, slot, slot), caption, buttonStyle)) selected = i;
            }
            GUI.backgroundColor = Color.white;

            // Action buttons on the right side.
            float actionX = Screen.width - button - margin;
            float breakY = Screen.height - button * 2f - margin * 2f - slot;
            if (GUI.Button(new Rect(actionX, breakY, button, button), "BREAK", buttonStyle)) BreakTarget();
            if (GUI.Button(new Rect(actionX, breakY + button + margin * 0.45f, button, button), "PLACE", buttonStyle)) PlaceBlock();
            if (GUI.Button(new Rect(Screen.width - button * 2f - margin * 1.5f, margin, button, button * 0.72f), "JUMP", buttonStyle))
            {
                MobileVoxelPlayer movement = GetComponent<MobileVoxelPlayer>();
                if (movement != null) movement.RequestJump();
            }
        }
    }
}