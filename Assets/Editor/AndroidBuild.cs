#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using NovaCraft.World;

namespace NovaCraft.Editor
{
    public static class AndroidBuild
    {
        public static void Build()
        {
            const string scenePath = "Assets/Scenes/Main.unity";
            const string outputPath = "Build/NovaCraft.apk";

            Directory.CreateDirectory("Assets/Scenes");
            Directory.CreateDirectory("Build");

            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            GameObject bootstrap = new GameObject("WorldBootstrap");
            bootstrap.AddComponent<WorldBootstrap>();
            if (!EditorSceneManager.SaveScene(scene, scenePath))
                throw new Exception("Could not save generated startup scene.");

            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(scenePath, true)
            };

            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.novacraft.voxelsandbox");
            PlayerSettings.productName = "NovaCraft";
            PlayerSettings.companyName = "NovaCraft";
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel23;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;

            BuildPlayerOptions options = new BuildPlayerOptions
            {
                scenes = new[] { scenePath },
                locationPathName = outputPath,
                target = BuildTarget.Android,
                options = BuildOptions.None
            };

            BuildReport report = BuildPipeline.BuildPlayer(options);
            if (report.summary.result != BuildResult.Succeeded)
                throw new Exception("Android build failed: " + report.summary.result +
                    " (" + report.summary.totalErrors + " errors).");
            Debug.Log("NovaCraft APK created: " + Path.GetFullPath(outputPath));
        }
    }
}
#endif
