using System;
using System.Collections.Generic;
using UnityEngine;

namespace NovaCraft.World
{
    /// <summary>Touch-first block interaction, hotbar, 24-slot inventory and lightweight crafting.</summary>
    public sealed class MobileVoxelInteraction : MonoBehaviour
    {
        private const int InventorySize = 24;
        private const int HotbarSize = 5;
        private const int StackLimit = 64;
        private const string SaveKey = "NovaCraft.Inventory.v1";

        [Serializable]
        private sealed class InventorySaveData
        {
            public int[] types;
            public int[] counts;
            public int[] durability;
            public int selected;
        }

        [SerializeField, Range(2f, 8f)] private float reach = 5f;
        [SerializeField] private int startingStack = 24;

        private readonly BlockType[] slotTypes = new BlockType[InventorySize];
        private readonly int[] slotCounts = new int[InventorySize];
        private readonly int[] toolDurability = new int[InventorySize];
        private Camera playerCamera;
        private VoxelWorld world;
        private int selectedSlot;
        private int movingSlot = -1;
        private bool inventoryOpen;
        private bool hasTarget;
        private RaycastHit targetHit;
        private GUIStyle buttonStyle;
        private GUIStyle labelStyle;
        private GUIStyle smallStyle;

        public bool InventoryOpen => inventoryOpen;

        private void Start()
        {
            playerCamera = GetComponentInChildren<Camera>();
            world = FindObjectOfType<VoxelWorld>();
            if (!LoadInventory())
            {
                SetSlot(0, BlockType.Stone, startingStack);
                SetSlot(1, BlockType.Dirt, startingStack);
                SetSlot(2, BlockType.Wood, startingStack);
                SetSlot(3, BlockType.Sand, startingStack);
                SetSlot(4, BlockType.Gravel, startingStack);
                SaveInventory();
            }
            buttonStyle = new GUIStyle(GUI.skin.button)
            {
                fontSize = Mathf.Max(12, Screen.width / 62),
                alignment = TextAnchor.MiddleCenter,
                wordWrap = true
            };
            labelStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = Mathf.Max(13, Screen.width / 58),
                alignment = TextAnchor.MiddleCenter,
                normal = { textColor = Color.white }
            };
            smallStyle = new GUIStyle(labelStyle) { fontSize = Mathf.Max(10, Screen.width / 82) };
        }


        private bool LoadInventory()
        {
            if (!PlayerPrefs.HasKey(SaveKey)) return false;
            try
            {
                InventorySaveData data = JsonUtility.FromJson<InventorySaveData>(PlayerPrefs.GetString(SaveKey));
                if (data == null || data.types == null || data.counts == null ||
                    data.types.Length != InventorySize || data.counts.Length != InventorySize) return false;

                for (int i = 0; i < InventorySize; i++)
                {
                    int rawType = data.types[i];
                    BlockType type = rawType >= 0 && rawType <= byte.MaxValue && Enum.IsDefined(typeof(BlockType), (byte)rawType) ? (BlockType)rawType : BlockType.Air;
                    int count = Mathf.Clamp(data.counts[i], 0, ItemMaxStack(type));
                    slotTypes[i] = count > 0 ? type : BlockType.Air;
                    slotCounts[i] = count;
                    int savedDurability = data.durability != null && data.durability.Length == InventorySize
                        ? data.durability[i] : 0;
                    toolDurability[i] = IsTool(type) && count > 0
                        ? Mathf.Clamp(savedDurability, 1, MaxDurability(type)) : 0;
                }

                selectedSlot = Mathf.Clamp(data.selected, 0, HotbarSize - 1);
                return true;
            }
            catch (Exception)
            {
                PlayerPrefs.DeleteKey(SaveKey);
                return false;
            }
        }

        private void SaveInventory()
        {
            InventorySaveData data = new InventorySaveData
            {
                types = new int[InventorySize],
                counts = new int[InventorySize],
                durability = new int[InventorySize],
                selected = selectedSlot
            };

            for (int i = 0; i < InventorySize; i++)
            {
                data.types[i] = (int)slotTypes[i];
                data.counts[i] = slotCounts[i];
                data.durability[i] = toolDurability[i];
            }

            PlayerPrefs.SetString(SaveKey, JsonUtility.ToJson(data));
            PlayerPrefs.Save();
        }

        private void OnApplicationPause(bool paused)
        {
            if (paused) SaveInventory();
        }

        private void OnApplicationQuit()
        {
            SaveInventory();
        }

        private void Update()
        {
            if (playerCamera == null || world == null) return;
            if (inventoryOpen)
            {
                hasTarget = false;
                return;
            }

            Ray ray = playerCamera.ViewportPointToRay(new Vector3(0.5f, 0.5f, 0f));
            hasTarget = Physics.Raycast(ray, out targetHit, reach, Physics.DefaultRaycastLayers, QueryTriggerInteraction.Ignore);

            if (Application.isEditor)
            {
                for (int i = 0; i < HotbarSize; i++)
                    if (Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1 + i))) { selectedSlot = i; SaveInventory(); }
                if (Input.GetMouseButtonDown(0)) BreakTarget();
                if (Input.GetMouseButtonDown(1)) PlaceBlock();
                if (Input.GetKeyDown(KeyCode.E)) inventoryOpen = !inventoryOpen;
            }
        }

        private void SetSlot(int index, BlockType type, int amount)
        {
            if (index < 0 || index >= InventorySize) return;
            slotTypes[index] = amount > 0 ? type : BlockType.Air;
            slotCounts[index] = Mathf.Clamp(amount, 0, ItemMaxStack(type));
            if (amount > 0 && IsTool(type) && toolDurability[index] <= 0) toolDurability[index] = MaxDurability(type);
            if (amount <= 0) toolDurability[index] = 0;
        }

        private int CountItem(BlockType type)
        {
            int total = 0;
            for (int i = 0; i < InventorySize; i++)
                if (slotTypes[i] == type) total += slotCounts[i];
            return total;
        }

        private bool HasItems(BlockType type, int amount) => CountItem(type) >= amount;

        private bool Consume(BlockType type, int amount)
        {
            if (!HasItems(type, amount)) return false;
            for (int i = InventorySize - 1; i >= 0 && amount > 0; i--)
            {
                if (slotTypes[i] != type) continue;
                int take = Mathf.Min(slotCounts[i], amount);
                slotCounts[i] -= take;
                amount -= take;
                if (slotCounts[i] <= 0) SetSlot(i, BlockType.Air, 0);
            }
            return amount == 0;
        }

        private int AddItem(BlockType type, int amount)
        {
            if (type == BlockType.Air || amount <= 0) return amount;
            for (int i = 0; i < InventorySize && amount > 0; i++)
            {
                if (slotTypes[i] != type || slotCounts[i] >= ItemMaxStack(type)) continue;
                int add = Mathf.Min(ItemMaxStack(type) - slotCounts[i], amount);
                slotCounts[i] += add;
                amount -= add;
            }
            for (int i = 0; i < InventorySize && amount > 0; i++)
            {
                if (slotCounts[i] != 0) continue;
                int add = Mathf.Min(ItemMaxStack(type), amount);
                SetSlot(i, type, add);
                amount -= add;
            }
            return amount;
        }

        private void BreakTarget()
        {
            if (!hasTarget || world == null) return;
            Vector3 point = targetHit.point - targetHit.normal * 0.015f;
            Vector3Int cell = new Vector3Int(Mathf.FloorToInt(point.x), Mathf.FloorToInt(point.y), Mathf.FloorToInt(point.z));
            BlockType block = world.GetBlock(cell);
            if (block == BlockType.Air || block == BlockType.Bedrock || !HasCapacity(block, 1)) return;
            int toolSlot = selectedSlot;
            BlockType tool = slotCounts[toolSlot] > 0 ? slotTypes[toolSlot] : BlockType.Air;
            if (RequiresPickaxe(block) && !CanMineWith(tool, block)) return;
            if (world.SetBlock(cell, BlockType.Air))
            {
                AddItem(block, 1);
                if (IsTool(tool) && IsPickaxeTarget(block)) UseTool(toolSlot);
                SaveInventory();
            }
        }

        private void PlaceBlock()
        {
            if (!hasTarget || world == null) return;
            BlockType type = slotTypes[selectedSlot];
            if (slotCounts[selectedSlot] <= 0 || !CanPlace(type)) return;

            Vector3 point = targetHit.point + targetHit.normal * 0.02f;
            Vector3Int cell = new Vector3Int(Mathf.FloorToInt(point.x), Mathf.FloorToInt(point.y), Mathf.FloorToInt(point.z));
            if (world.GetBlock(cell) != BlockType.Air) return;

            Vector3 center = new Vector3(cell.x + 0.5f, cell.y + 0.5f, cell.z + 0.5f);
            if (Vector3.Distance(center, transform.position + Vector3.up * 0.9f) < 1.15f) return;

            if (world.SetBlock(cell, type))
            {
                slotCounts[selectedSlot]--;
                if (slotCounts[selectedSlot] <= 0) SetSlot(selectedSlot, BlockType.Air, 0);
                SaveInventory();
            }
        }

        private static bool CanPlace(BlockType type)
        {
            return type != BlockType.Air && type != BlockType.Water && type != BlockType.Lava &&
                   type != BlockType.Bedrock && type != BlockType.Stick && !IsTool(type);
        }

        private static bool IsTool(BlockType type)
        {
            return type == BlockType.WoodenPickaxe || type == BlockType.StonePickaxe || type == BlockType.IronPickaxe;
        }

        private static bool IsPickaxeTarget(BlockType type)
        {
            return type == BlockType.Stone || type == BlockType.CoalOre || type == BlockType.IronOre ||
                   type == BlockType.GoldOre || type == BlockType.DiamondOre;
        }

        private static bool RequiresPickaxe(BlockType type) => IsPickaxeTarget(type);

        private static int ItemMaxStack(BlockType type) => IsTool(type) ? 1 : StackLimit;

        private static int MaxDurability(BlockType type)
        {
            switch (type)
            {
                case BlockType.WoodenPickaxe: return 59;
                case BlockType.StonePickaxe: return 131;
                case BlockType.IronPickaxe: return 250;
                default: return 0;
            }
        }

        private static bool CanMineWith(BlockType tool, BlockType block)
        {
            if (!IsPickaxeTarget(block)) return true;
            if (tool == BlockType.WoodenPickaxe)
                return block == BlockType.Stone || block == BlockType.CoalOre;
            if (tool == BlockType.StonePickaxe)
                return block == BlockType.Stone || block == BlockType.CoalOre || block == BlockType.IronOre;
            return tool == BlockType.IronPickaxe;
        }

        private void UseTool(int index)
        {
            if (index < 0 || index >= InventorySize || !IsTool(slotTypes[index])) return;
            toolDurability[index] = Mathf.Max(0, toolDurability[index] - 1);
            if (toolDurability[index] == 0) SetSlot(index, BlockType.Air, 0);
        }

        private bool HasCapacity(BlockType type, int amount)
        {
            int capacity = 0;
            int maxStack = ItemMaxStack(type);
            for (int i = 0; i < InventorySize; i++)
            {
                if (slotCounts[i] == 0) capacity += maxStack;
                else if (slotTypes[i] == type) capacity += maxStack - slotCounts[i];
                if (capacity >= amount) return true;
            }
            return false;
        }

        private void CraftPlanks()
        {
            if (HasItems(BlockType.Wood, 1) && HasCapacity(BlockType.Planks, 4) &&
                Consume(BlockType.Wood, 1))
                AddItem(BlockType.Planks, 4);
            SaveInventory();
        }

        private void CraftWorkbench()
        {
            if (HasItems(BlockType.Planks, 4) && HasCapacity(BlockType.CraftingTable, 1) &&
                Consume(BlockType.Planks, 4))
                AddItem(BlockType.CraftingTable, 1);
            SaveInventory();
        }

        private void CraftSticks()
        {
            if (HasItems(BlockType.Planks, 2) && HasCapacity(BlockType.Stick, 4) &&
                Consume(BlockType.Planks, 2))
                AddItem(BlockType.Stick, 4);
            SaveInventory();
        }

        private void CraftPickaxe(BlockType material)
        {
            BlockType tool = material == BlockType.Planks ? BlockType.WoodenPickaxe :
                material == BlockType.Stone ? BlockType.StonePickaxe : BlockType.IronPickaxe;
            if (!HasItems(material, 3) || !HasItems(BlockType.Stick, 2) || !HasCapacity(tool, 1)) return;
            if (Consume(material, 3) && Consume(BlockType.Stick, 2)) AddItem(tool, 1);
            SaveInventory();
        }

        private void SelectOrMoveSlot(int index)
        {
            if (movingSlot < 0)
            {
                if (slotCounts[index] > 0) movingSlot = index;
                else selectedSlot = index < HotbarSize ? index : selectedSlot;
                return;
            }

            if (movingSlot == index)
            {
                movingSlot = -1;
                return;
            }

            if (slotCounts[index] > 0 && slotTypes[index] == slotTypes[movingSlot] && slotCounts[index] < ItemMaxStack(slotTypes[index]))
            {
                int transfer = Mathf.Min(ItemMaxStack(slotTypes[index]) - slotCounts[index], slotCounts[movingSlot]);
                slotCounts[index] += transfer;
                slotCounts[movingSlot] -= transfer;
                if (slotCounts[movingSlot] <= 0) SetSlot(movingSlot, BlockType.Air, 0);
            }
            else
            {
                BlockType type = slotTypes[index];
                int amount = slotCounts[index];
                int durability = toolDurability[index];
                BlockType movingType = slotTypes[movingSlot];
                int movingAmount = slotCounts[movingSlot];
                int movingDurability = toolDurability[movingSlot];
                SetSlot(index, movingType, movingAmount);
                toolDurability[index] = movingDurability;
                SetSlot(movingSlot, type, amount);
                toolDurability[movingSlot] = durability;
            }

            if (index < HotbarSize) selectedSlot = index;
            else if (movingSlot < HotbarSize) selectedSlot = movingSlot;
            movingSlot = -1;
            SaveInventory();
        }

        private void OnGUI()
        {
            if (buttonStyle == null) return;
            float scale = Mathf.Clamp(Screen.width / 900f, 0.72f, 1.35f);
            float button = 76f * scale;
            float margin = 18f * scale;

            if (inventoryOpen)
            {
                DrawInventory(scale);
                return;
            }

            GUI.Label(new Rect(Screen.width * 0.5f - 12f, Screen.height * 0.5f - 22f, 24f, 44f), "+", labelStyle);

            float slot = 66f * scale;
            float total = HotbarSize * slot + (HotbarSize - 1) * 5f * scale;
            float startX = (Screen.width - total) * 0.5f;
            float y = Screen.height - slot - margin;
            for (int i = 0; i < HotbarSize; i++)
            {
                string caption = (i + 1) + "\n" + (slotCounts[i] > 0 ? ShortName(slotTypes[i]) : "-") + "\n" + slotCounts[i] + (IsTool(slotTypes[i]) ? " / " + toolDurability[i] : "");
                GUI.backgroundColor = i == selectedSlot ? new Color(0.35f, 0.75f, 1f) : new Color(0.22f, 0.24f, 0.30f);
                if (GUI.Button(new Rect(startX + i * (slot + 5f * scale), y, slot, slot), caption, buttonStyle)) { selectedSlot = i; SaveInventory(); }
            }
            GUI.backgroundColor = Color.white;

            float actionX = Screen.width - button - margin;
            float breakY = Screen.height - button * 2f - margin * 2f - slot;
            if (GUI.Button(new Rect(actionX, breakY, button, button), "BREAK", buttonStyle)) BreakTarget();
            if (GUI.Button(new Rect(actionX, breakY + button + margin * 0.45f, button, button), "PLACE", buttonStyle)) PlaceBlock();
            if (GUI.Button(new Rect(Screen.width - button * 2f - margin * 1.5f, margin, button, button * 0.72f), "JUMP", buttonStyle))
            {
                MobileVoxelPlayer movement = GetComponent<MobileVoxelPlayer>();
                if (movement != null) movement.RequestJump();
            }
            if (GUI.Button(new Rect(margin, margin, button * 1.25f, button * 0.72f), "INV", buttonStyle))
            {
                inventoryOpen = true;
                movingSlot = -1;
            }
        }

        private void DrawInventory(float scale)
        {
            float margin = 14f * scale;
            float panelWidth = Mathf.Min(Screen.width - margin * 2f, 620f * scale);
            float panelHeight = Mathf.Min(Screen.height - margin * 2f, 520f * scale);
            float x = (Screen.width - panelWidth) * 0.5f;
            float y = (Screen.height - panelHeight) * 0.5f;
            GUI.color = new Color(0.055f, 0.06f, 0.085f, 0.96f);
            GUI.Box(new Rect(x, y, panelWidth, panelHeight), GUIContent.none);
            GUI.color = Color.white;
            GUI.Label(new Rect(x + 8f, y + 5f, panelWidth - 100f, 32f * scale), "ИНВЕНТАРЬ", labelStyle);
            if (GUI.Button(new Rect(x + panelWidth - 82f * scale, y + 6f, 72f * scale, 30f * scale), "ЗАКРЫТЬ", buttonStyle))
            {
                inventoryOpen = false;
                movingSlot = -1;
                return;
            }

            float gap = 5f * scale;
            float gridTop = y + 45f * scale;
            float cell = Mathf.Min((panelWidth - 28f * scale - gap * 5f) / 6f, 66f * scale);
            float gridWidth = cell * 6f + gap * 5f;
            float gridX = x + (panelWidth - gridWidth) * 0.5f;
            for (int i = 0; i < InventorySize; i++)
            {
                int col = i % 6;
                int row = i / 6;
                Rect rect = new Rect(gridX + col * (cell + gap), gridTop + row * (cell + gap), cell, cell);
                GUI.backgroundColor = i == movingSlot ? new Color(1f, 0.72f, 0.25f) :
                    (i == selectedSlot ? new Color(0.32f, 0.62f, 0.88f) : new Color(0.20f, 0.22f, 0.29f));
                string name = slotCounts[i] > 0 ? ShortName(slotTypes[i]) + "\n" + slotCounts[i] + (IsTool(slotTypes[i]) ? "\n" + toolDurability[i] + "/" + MaxDurability(slotTypes[i]) : "") : "-";
                if (GUI.Button(rect, name, buttonStyle)) SelectOrMoveSlot(i);
            }
            GUI.backgroundColor = Color.white;

            float recipeY = gridTop + 4f * (cell + gap) + 7f * scale;
            float recipeGap = 5f * scale;
            float recipeHeight = Mathf.Max(28f * scale, (panelHeight - (recipeY - y) - 12f * scale - recipeGap) * 0.5f);
            float recipeWidth = (panelWidth - 3f * margin) * 0.5f;
            float rightX = x + margin * 2f + recipeWidth;
            if (GUI.Button(new Rect(x + margin, recipeY, recipeWidth, recipeHeight),
                "ДОСКИ\n1 дерево → 4", buttonStyle)) CraftPlanks();
            if (GUI.Button(new Rect(rightX, recipeY, recipeWidth, recipeHeight),
                "ВЕРСТАК\n4 доски → 1", buttonStyle)) CraftWorkbench();
            if (GUI.Button(new Rect(x + margin, recipeY + recipeHeight + recipeGap, recipeWidth, recipeHeight),
                "ПАЛКИ\n2 доски → 4", buttonStyle)) CraftSticks();
            if (GUI.Button(new Rect(rightX, recipeY + recipeHeight + recipeGap, recipeWidth, recipeHeight),
                "КИРКА\n3 доски/камня/железа + 2 палки", buttonStyle))
            {
                if (HasItems(BlockType.Planks, 3)) CraftPickaxe(BlockType.Planks);
                else if (HasItems(BlockType.Stone, 3)) CraftPickaxe(BlockType.Stone);
                else CraftPickaxe(BlockType.IronOre);
            }
        }

        private static string ShortName(BlockType type)
        {
            switch (type)
            {
                case BlockType.CraftingTable: return "Верстак";
                case BlockType.Stick: return "Палка";
                case BlockType.WoodenPickaxe: return "Дер. кирка";
                case BlockType.StonePickaxe: return "Кам. кирка";
                case BlockType.IronPickaxe: return "Жел. кирка";
                case BlockType.Planks: return "Доски";
                case BlockType.DiamondOre: return "Алмаз";
                case BlockType.IronOre: return "Железо";
                case BlockType.GoldOre: return "Золото";
                case BlockType.CoalOre: return "Уголь";
                default: return type.ToString();
            }
        }
    }
}