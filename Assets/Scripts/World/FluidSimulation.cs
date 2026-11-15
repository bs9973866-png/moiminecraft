using System.Collections.Generic;
using UnityEngine;

namespace NovaCraft.World
{
    /// <summary>
    /// Lightweight cellular-automata liquid simulation. It is intentionally tick- and
    /// budget-limited for mobile CPUs; it is gameplay fluid, not a full Navier-Stokes solver.
    /// </summary>
    public sealed class FluidSimulation : MonoBehaviour
    {
        [SerializeField, Range(8, 128)] private int cellsPerTick = 32;
        [SerializeField, Range(0.05f, 1f)] private float waterTickSeconds = 0.25f;
        [SerializeField, Range(0.2f, 3f)] private float lavaTickSeconds = 1.1f;

        private struct FluidCell
        {
            public Vector3Int position;
            public BlockType type;
            public byte level;
            public bool source;
        }

        private VoxelWorld world;
        private readonly Queue<FluidCell> waterQueue = new Queue<FluidCell>();
        private readonly Queue<FluidCell> lavaQueue = new Queue<FluidCell>();
        private readonly Dictionary<Vector3Int, byte> waterLevels = new Dictionary<Vector3Int, byte>();
        private readonly Dictionary<Vector3Int, byte> lavaLevels = new Dictionary<Vector3Int, byte>();
        private float waterTimer;
        private float lavaTimer;

        public void Initialize(VoxelWorld owner) { world = owner; }

        public void AddSource(Vector3Int position, BlockType type)
        {
            if (type != BlockType.Water && type != BlockType.Lava) return;
            if (!world.SetBlock(position, type)) return;
            var levels = type == BlockType.Water ? waterLevels : lavaLevels;
            var queue = type == BlockType.Water ? waterQueue : lavaQueue;
            levels[position] = 0;
            queue.Enqueue(new FluidCell { position = position, type = type, level = 0, source = true });
        }

        private void Update()
        {
            if (world == null) return;
            waterTimer += Time.deltaTime;
            lavaTimer += Time.deltaTime;
            if (waterTimer >= waterTickSeconds)
            {
                waterTimer = 0f;
                Simulate(waterQueue, waterLevels, BlockType.Water, 5);
            }
            if (lavaTimer >= lavaTickSeconds)
            {
                lavaTimer = 0f;
                Simulate(lavaQueue, lavaLevels, BlockType.Lava, 3);
            }
        }

        private void Simulate(Queue<FluidCell> queue, Dictionary<Vector3Int, byte> levels, BlockType type, byte maxLevel)
        {
            int budget = cellsPerTick;
            while (budget-- > 0 && queue.Count > 0)
            {
                FluidCell cell = queue.Dequeue();
                if (world.GetBlock(cell.position) != type) continue;

                Vector3Int below = cell.position + Vector3Int.down;
                if (below.y >= 0 && TryFlow(below, type, cell.level, true, levels, queue))
                {
                    EnqueueNeighbors(cell.position, type, cell.level, cell.source, queue);
                    continue;
                }

                if (cell.level >= maxLevel) continue;
                TryFlow(cell.position + Vector3Int.left, type, (byte)(cell.level + 1), false, levels, queue);
                TryFlow(cell.position + Vector3Int.right, type, (byte)(cell.level + 1), false, levels, queue);
                TryFlow(cell.position + new Vector3Int(0, 0, -1), type, (byte)(cell.level + 1), false, levels, queue);
                TryFlow(cell.position + new Vector3Int(0, 0, 1), type, (byte)(cell.level + 1), false, levels, queue);
            }
        }

        private bool TryFlow(Vector3Int target, BlockType type, byte level, bool falling,
            Dictionary<Vector3Int, byte> levels, Queue<FluidCell> queue)
        {
            if (target.y < 0 || target.y >= VoxelChunk.Height) return false;
            BlockType existing = world.GetBlock(target);
            if (existing == BlockType.Water || existing == BlockType.Lava)
            {
                if (existing != type)
                {
                    world.SetBlock(target, BlockType.Stone);
                    waterLevels.Remove(target);
                    lavaLevels.Remove(target);
                    return false;
                }
                return false;
            }
            if (existing != BlockType.Air) return false;
            if (!world.SetBlock(target, type)) return false;
            levels[target] = level;
            queue.Enqueue(new FluidCell { position = target, type = type, level = level, source = false });
            return true;
        }

        private void EnqueueNeighbors(Vector3Int position, BlockType type, byte level, bool source, Queue<FluidCell> queue)
        {
            queue.Enqueue(new FluidCell { position = position + Vector3Int.left, type = type, level = (byte)Mathf.Min(level + 1, 255), source = false });
            queue.Enqueue(new FluidCell { position = position + Vector3Int.right, type = type, level = (byte)Mathf.Min(level + 1, 255), source = false });
            queue.Enqueue(new FluidCell { position = position + new Vector3Int(0, 0, -1), type = type, level = (byte)Mathf.Min(level + 1, 255), source = false });
            queue.Enqueue(new FluidCell { position = position + new Vector3Int(0, 0, 1), type = type, level = (byte)Mathf.Min(level + 1, 255), source = false });
        }
    }
}
