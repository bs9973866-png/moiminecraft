using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace NovaCraft.World
{
    [RequireComponent(typeof(MeshFilter), typeof(MeshRenderer), typeof(MeshCollider))]
    public sealed class VoxelChunk : MonoBehaviour
    {
        public const int Width = 16;
        public const int Height = 64;
        private BlockType[,,] blocks;
        private MeshFilter meshFilter;
        private MeshCollider meshCollider;
        private Mesh mesh;
        private MeshFilter liquidFilter;
        private MeshRenderer liquidRenderer;
        private Mesh liquidMesh;

        public void Initialize(Material solidMaterial, Material liquidMaterial)
        {
            meshFilter = GetComponent<MeshFilter>();
            meshCollider = GetComponent<MeshCollider>();
            GetComponent<MeshRenderer>().sharedMaterial = solidMaterial;
            blocks = new BlockType[Width, Height, Width];

            var liquidObject = new GameObject("LiquidSurface");
            liquidObject.transform.SetParent(transform, false);
            liquidFilter = liquidObject.AddComponent<MeshFilter>();
            liquidRenderer = liquidObject.AddComponent<MeshRenderer>();
            liquidRenderer.sharedMaterial = liquidMaterial;
        }

        public void SetBlock(int x, int y, int z, BlockType type)
        {
            if (Inside(x, y, z)) blocks[x, y, z] = type;
        }

        public BlockType GetBlock(int x, int y, int z)
        {
            return Inside(x, y, z) ? blocks[x, y, z] : BlockType.Air;
        }

        public void BuildMesh()
        {
            var solidV = new List<Vector3>(10000);
            var solidT = new List<int>(15000);
            var solidC = new List<Color>(10000);
            var liquidV = new List<Vector3>(1500);
            var liquidT = new List<int>(2200);
            var liquidC = new List<Color>(1500);

            for (int x = 0; x < Width; x++)
            for (int y = 0; y < Height; y++)
            for (int z = 0; z < Width; z++)
            {
                BlockType block = blocks[x, y, z];
                if (block == BlockType.Air) continue;
                if (block == BlockType.Water || block == BlockType.Lava)
                    AddLiquidFaces(x, y, z, block, liquidV, liquidT, liquidC);
                else
                    AddSolidFaces(x, y, z, block, solidV, solidT, solidC);
            }

            mesh = ReplaceMesh(mesh, solidV, solidT, solidC, "VoxelSolidMesh");
            meshFilter.sharedMesh = mesh;
            meshCollider.sharedMesh = null;
            meshCollider.sharedMesh = mesh;
            liquidMesh = ReplaceMesh(liquidMesh, liquidV, liquidT, liquidC, "VoxelLiquidMesh");
            liquidFilter.sharedMesh = liquidMesh;
        }

        private Mesh ReplaceMesh(Mesh oldMesh, List<Vector3> vertices, List<int> triangles, List<Color> colors, string meshName)
        {
            if (oldMesh != null) Destroy(oldMesh);
            var result = new Mesh { indexFormat = vertices.Count > 65000 ? IndexFormat.UInt32 : IndexFormat.UInt16, name = meshName };
            result.SetVertices(vertices);
            result.SetTriangles(triangles, 0, true);
            result.SetColors(colors);
            // Both voxel materials are unlit; skipping normal generation saves CPU time on mobile.
            return result;
        }

        private void AddSolidFaces(int x, int y, int z, BlockType block, List<Vector3> v, List<int> t, List<Color> c)
        {
            Color tint;
            switch (block)
            {
                case BlockType.Grass: tint = new Color(0.42f, 0.72f, 0.28f); break;
                case BlockType.Dirt: tint = new Color(0.48f, 0.31f, 0.18f); break;
                case BlockType.Sand: tint = new Color(0.82f, 0.75f, 0.49f); break;
                case BlockType.Wood: tint = new Color(0.42f, 0.27f, 0.13f); break;
                case BlockType.Leaves: tint = new Color(0.20f, 0.48f, 0.17f); break;
                case BlockType.Gravel: tint = new Color(0.48f, 0.47f, 0.45f); break;
                case BlockType.CoalOre: tint = new Color(0.22f, 0.23f, 0.25f); break;
                case BlockType.IronOre: tint = new Color(0.70f, 0.48f, 0.37f); break;
                case BlockType.GoldOre: tint = new Color(0.95f, 0.72f, 0.16f); break;
                case BlockType.DiamondOre: tint = new Color(0.18f, 0.86f, 0.83f); break;
                case BlockType.Bedrock: tint = new Color(0.16f, 0.16f, 0.18f); break;
                default: tint = new Color(0.52f, 0.53f, 0.56f); break;
            }
            if (IsTransparentOrAir(GetBlock(x, y + 1, z))) Face(new Vector3(x,y+1,z), new Vector3(x,y+1,z+1), new Vector3(x+1,y+1,z+1), new Vector3(x+1,y+1,z), tint, v,t,c);
            if (IsTransparentOrAir(GetBlock(x, y - 1, z))) Face(new Vector3(x,y,z), new Vector3(x+1,y,z), new Vector3(x+1,y,z+1), new Vector3(x,y,z+1), tint * 0.72f, v,t,c);
            if (IsTransparentOrAir(GetBlock(x - 1, y, z))) Face(new Vector3(x,y,z), new Vector3(x,y,z+1), new Vector3(x,y+1,z+1), new Vector3(x,y+1,z), tint * 0.86f, v,t,c);
            if (IsTransparentOrAir(GetBlock(x + 1, y, z))) Face(new Vector3(x+1,y,z+1), new Vector3(x+1,y,z), new Vector3(x+1,y+1,z), new Vector3(x+1,y+1,z+1), tint * 0.86f, v,t,c);
            if (IsTransparentOrAir(GetBlock(x, y, z - 1))) Face(new Vector3(x+1,y,z), new Vector3(x,y,z), new Vector3(x,y+1,z), new Vector3(x+1,y+1,z), tint * 0.92f, v,t,c);
            if (IsTransparentOrAir(GetBlock(x, y, z + 1))) Face(new Vector3(x,y,z+1), new Vector3(x+1,y,z+1), new Vector3(x+1,y+1,z+1), new Vector3(x,y+1,z+1), tint * 0.92f, v,t,c);
        }

        private void AddLiquidFaces(int x, int y, int z, BlockType block, List<Vector3> v, List<int> t, List<Color> c)
        {
            Color tint = block == BlockType.Water ? new Color(0.16f, 0.48f, 0.92f, 0.68f) : new Color(1f, 0.30f, 0.035f, 0.90f);
            if (GetBlock(x, y + 1, z) != block) Face(new Vector3(x,y+0.88f,z), new Vector3(x,y+0.88f,z+1), new Vector3(x+1,y+0.88f,z+1), new Vector3(x+1,y+0.88f,z), tint, v,t,c);
            if (GetBlock(x - 1, y, z) != block) Face(new Vector3(x,y,z), new Vector3(x,y,z+1), new Vector3(x,y+0.88f,z+1), new Vector3(x,y+0.88f,z), tint, v,t,c);
            if (GetBlock(x + 1, y, z) != block) Face(new Vector3(x+1,y,z+1), new Vector3(x+1,y,z), new Vector3(x+1,y+0.88f,z), new Vector3(x+1,y+0.88f,z+1), tint, v,t,c);
            if (GetBlock(x, y, z - 1) != block) Face(new Vector3(x+1,y,z), new Vector3(x,y,z), new Vector3(x,y+0.88f,z), new Vector3(x+1,y+0.88f,z), tint, v,t,c);
            if (GetBlock(x, y, z + 1) != block) Face(new Vector3(x,y,z+1), new Vector3(x+1,y,z+1), new Vector3(x+1,y+0.88f,z+1), new Vector3(x,y+0.88f,z+1), tint, v,t,c);
        }

        private static bool IsTransparentOrAir(BlockType type) => type == BlockType.Air || type == BlockType.Water || type == BlockType.Lava || type == BlockType.Leaves;

        private static void Face(Vector3 a, Vector3 b, Vector3 c0, Vector3 d, Color color, List<Vector3> vertices, List<int> triangles, List<Color> colors)
        {
            int i = vertices.Count;
            vertices.Add(a); vertices.Add(b); vertices.Add(c0); vertices.Add(d);
            triangles.Add(i); triangles.Add(i + 1); triangles.Add(i + 2);
            triangles.Add(i); triangles.Add(i + 2); triangles.Add(i + 3);
            colors.Add(color); colors.Add(color); colors.Add(color); colors.Add(color);
        }

        private static bool Inside(int x, int y, int z) => x >= 0 && x < Width && y >= 0 && y < Height && z >= 0 && z < Width;

        private void OnDestroy()
        {
            if (mesh != null) Destroy(mesh);
            if (liquidMesh != null) Destroy(liquidMesh);
        }
    }
}
