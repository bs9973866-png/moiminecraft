using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace NovaCraft.World
{
    public sealed class VoxelWorld : MonoBehaviour
    {
        [Header("World")]
        [SerializeField] private int seed = 481516;
        [SerializeField, Range(1, 6)] private int renderDistance = 3;
        [SerializeField, Range(1, 2)] private int chunksPerFrame = 1;
        [SerializeField] private Transform player;
        [SerializeField] private Material chunkMaterial;
        [SerializeField] private Material liquidMaterial;

        private readonly Dictionary<Vector2Int, VoxelChunk> chunks = new Dictionary<Vector2Int, VoxelChunk>();
        private readonly Queue<Vector2Int> pending = new Queue<Vector2Int>();
        private readonly HashSet<Vector2Int> queued = new HashSet<Vector2Int>();
        private readonly HashSet<VoxelChunk> dirtyChunks = new HashSet<VoxelChunk>();
        private float offsetX, offsetZ;
        private Vector2Int lastCenter = new Vector2Int(int.MinValue, int.MinValue);
        public Transform Player { set => player = value; }
        public int Seed => seed;

        private void Start()
        {
            Random.InitState(seed);
            offsetX = Random.Range(-10000f, 10000f);
            offsetZ = Random.Range(-10000f, 10000f);
            if (chunkMaterial == null)
            {
                Shader shader = Shader.Find("NovaCraft/VoxelVertexColor");
                if (shader == null) shader = Shader.Find("Unlit/Color");
                chunkMaterial = new Material(shader);
            }
            if (liquidMaterial == null)
            {
                Shader liquidShader = Shader.Find("NovaCraft/VoxelLiquid");
                liquidMaterial = new Material(liquidShader);
            }
            var fluids = gameObject.AddComponent<FluidSimulation>();
            fluids.Initialize(this);
            RefreshQueue();
            StartCoroutine(GenerateLoop());
        }

        private void Update()
        {
            if (player == null) return;
            Vector2Int center = PlayerChunk();
            if (center != lastCenter)
            {
                lastCenter = center;
                UnloadDistantChunks(center);
                RefreshQueue();
            }
        }

        private Vector2Int PlayerChunk() => new Vector2Int(Mathf.FloorToInt(player.position.x / VoxelChunk.Width), Mathf.FloorToInt(player.position.z / VoxelChunk.Width));

        private void UnloadDistantChunks(Vector2Int center)
        {
            int keepDistance = renderDistance + 1;
            var remove = new List<Vector2Int>();
            foreach (var pair in chunks)
                if ((pair.Key - center).sqrMagnitude > keepDistance * keepDistance) remove.Add(pair.Key);
            foreach (var key in remove)
            {
                Destroy(chunks[key].gameObject);
                chunks.Remove(key);
            }
            int count = pending.Count;
            for (int i = 0; i < count; i++)
            {
                Vector2Int key = pending.Dequeue();
                if ((key - center).sqrMagnitude <= renderDistance * renderDistance) pending.Enqueue(key);
                else queued.Remove(key);
            }
        }

        private void RefreshQueue()
        {
            if (player == null) return;
            Vector2Int center = PlayerChunk();
            var candidates = new List<Vector2Int>();
            for (int x = -renderDistance; x <= renderDistance; x++)
            for (int z = -renderDistance; z <= renderDistance; z++)
            {
                if (x*x + z*z > renderDistance*renderDistance) continue;
                Vector2Int key = new Vector2Int(center.x + x, center.y + z);
                if (!chunks.ContainsKey(key) && queued.Add(key)) candidates.Add(key);
            }
            candidates.Sort((a,b) => (a-center).sqrMagnitude.CompareTo((b-center).sqrMagnitude));
            foreach (var key in candidates) pending.Enqueue(key);
        }

        private IEnumerator GenerateLoop()
        {
            while (true)
            {
                int count = 0;
                while (pending.Count > 0 && count < chunksPerFrame)
                {
                    Vector2Int key = pending.Dequeue();
                    queued.Remove(key);
                    if (!chunks.ContainsKey(key) && player != null &&
                        (key - PlayerChunk()).sqrMagnitude <= (renderDistance + 1) * (renderDistance + 1))
                        CreateChunk(key);
                    count++;
                    yield return null;
                }
                if (dirtyChunks.Count > 0)
                {
                    foreach (var chunk in dirtyChunks) if (chunk != null) chunk.BuildMesh();
                    dirtyChunks.Clear();
                }
                yield return null;
            }
        }

        private void CreateChunk(Vector2Int key)
        {
            var go = new GameObject("Chunk_" + key.x + "_" + key.y);
            go.transform.SetParent(transform, false);
            go.transform.position = new Vector3(key.x * VoxelChunk.Width, 0, key.y * VoxelChunk.Width);
            VoxelChunk chunk = go.AddComponent<VoxelChunk>();
            chunk.Initialize(chunkMaterial, liquidMaterial);

            for (int x = 0; x < VoxelChunk.Width; x++)
            for (int z = 0; z < VoxelChunk.Width; z++)
            {
                int worldX = key.x * VoxelChunk.Width + x;
                int worldZ = key.y * VoxelChunk.Width + z;
                float broad = Mathf.PerlinNoise((worldX + offsetX) * 0.008f, (worldZ + offsetZ) * 0.008f);
                float detail = Mathf.PerlinNoise((worldX + offsetX + 1700f) * 0.035f, (worldZ + offsetZ + 1700f) * 0.035f);
                int surface = Mathf.Clamp(20 + Mathf.RoundToInt(broad * 25f + detail * 5f), 2, VoxelChunk.Height - 2);
                for (int y = 0; y <= surface; y++)
                {
                    BlockType type = y == surface ? BlockType.Grass : y >= surface - 3 ? BlockType.Dirt : BlockType.Stone;
                    chunk.SetBlock(x, y, z, type);
                }

                // Deterministic small forest patches; trees stay inside their owning chunk.
                float forest = Mathf.PerlinNoise((worldX + offsetX + 430f) * 0.045f, (worldZ + offsetZ - 900f) * 0.045f);
                float treeRoll = Mathf.PerlinNoise((worldX + offsetX + 810f) * 0.71f, (worldZ + offsetZ + 250f) * 0.71f);
                if (x >= 2 && x <= 13 && z >= 2 && z <= 13 && surface > 27 && forest > 0.52f && treeRoll > 0.82f)
                {
                    int trunkHeight = 4 + Mathf.FloorToInt(treeRoll * 3f);
                    for (int ty = 1; ty <= trunkHeight; ty++) chunk.SetBlock(x, surface + ty, z, BlockType.Wood);
                    int crownY = surface + trunkHeight;
                    for (int lx = -2; lx <= 2; lx++)
                    for (int lz = -2; lz <= 2; lz++)
                    for (int ly = -1; ly <= 2; ly++)
                    {
                        if (Mathf.Abs(lx) + Mathf.Abs(lz) + Mathf.Abs(ly) > 5) continue;
                        if (chunk.GetBlock(x + lx, crownY + ly, z + lz) == BlockType.Air)
                            chunk.SetBlock(x + lx, crownY + ly, z + lz, BlockType.Leaves);
                    }
                }

                // Sea-level water fills low terrain, forming shallow lakes and shorelines.
                const int seaLevel = 27;
                if (surface < seaLevel)
                    for (int wy = surface + 1; wy <= seaLevel; wy++)
                        chunk.SetBlock(x, wy, z, BlockType.Water);
            }
            chunk.BuildMesh();
            chunks.Add(key, chunk);
        }

        public BlockType GetBlock(Vector3Int worldPosition)
        {
            int cx = Mathf.FloorToInt(worldPosition.x / (float)VoxelChunk.Width);
            int cz = Mathf.FloorToInt(worldPosition.z / (float)VoxelChunk.Width);
            if (!chunks.TryGetValue(new Vector2Int(cx, cz), out VoxelChunk chunk)) return BlockType.Air;
            int lx = worldPosition.x - cx * VoxelChunk.Width;
            int lz = worldPosition.z - cz * VoxelChunk.Width;
            return chunk.GetBlock(lx, worldPosition.y, lz);
        }

        public bool SetBlock(Vector3Int worldPosition, BlockType type)
        {
            if (worldPosition.y < 0 || worldPosition.y >= VoxelChunk.Height) return false;
            int cx = Mathf.FloorToInt(worldPosition.x / (float)VoxelChunk.Width);
            int cz = Mathf.FloorToInt(worldPosition.z / (float)VoxelChunk.Width);
            if (!chunks.TryGetValue(new Vector2Int(cx, cz), out VoxelChunk chunk)) return false;
            int lx = worldPosition.x - cx * VoxelChunk.Width;
            int lz = worldPosition.z - cz * VoxelChunk.Width;
            chunk.SetBlock(lx, worldPosition.y, lz, type);
            dirtyChunks.Add(chunk);
            return true;
        }

        public void MarkChunkDirty(Vector3Int worldPosition)
        {
            int cx = Mathf.FloorToInt(worldPosition.x / (float)VoxelChunk.Width);
            int cz = Mathf.FloorToInt(worldPosition.z / (float)VoxelChunk.Width);
            if (chunks.TryGetValue(new Vector2Int(cx, cz), out VoxelChunk chunk)) dirtyChunks.Add(chunk);
        }
    }
}
