package beap.platforms;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.project.ProjectConfig;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import sys.io.Process;

/**
 * SDL-aware Android Platform
 * Supports both SDL2 and SDL3 with automatic binary downloading
 */
class AndroidPlatformSDL implements Platform {
    
    var projectConfig:ProjectConfig;
    
    public function new(config:ProjectConfig) {
        this.projectConfig = config;
    }
    
    public function getName():String return "android";
    
    public function getDescription():String {
        var sdl = projectConfig.sdlVersion;
        return "Android APK (HashLink/C native, " + sdl + ")";
    }
    
    public function isAvailable():Bool {
        if (getAndroidSdk() != null && getAndroidNdk() != null) {
            return true;
        }
        return false;
    }
    
    public function build(config:Config, ?consoleMode:Bool = false):Bool {
        Console.println(Lang.get("build_android"), ConsoleColor.BOLD);
        Console.info("Using SDL: " + projectConfig.sdlVersion);

        var platform = getName();
        config.ensureDirectories(platform);

        // 1. Generate C code from Haxe
        if (!generateCCode(config)) {
            return false;
        }

        // 2. Create Android project from template + copy Haxe C output + patch configs
        createAndroidProject(config);

        // 3. Copy resources (assets)
        copyResources(config);

        // 4. Build with Gradle (CMake compiles native code from source)
        if (!buildWithGradle(config)) {
            return false;
        }

        Console.success(Lang.get("build_success", [config.getOutputPath(platform, ".apk")]));
        return true;
    }
    
    public function run(config:Config, ?showOutput:Bool = false):Void {
        var platform = getName();
        var apkPath = config.getOutputPath(platform, ".apk");
        
        if (!FileSystem.exists(apkPath)) {
            Console.info("APK not found, building first...");
            if (!build(config)) {
                Console.error("Build failed, cannot run");
                return;
            }
        }
        
        var adbPath = getAdbPath();
        if (adbPath == "" || !FileSystem.exists(adbPath)) {
            Console.error("ADB not found! Check Android SDK installation.");
            return;
        }
        
        Console.info("Installing APK...");
        var installProc = new Process(adbPath, ["install", "-r", apkPath]);
        var exitCode = installProc.exitCode();
        installProc.close();
        
        if (exitCode != 0) {
            Console.error("Installation failed!");
            return;
        }
        
        Console.info("Starting application...");
        var packageName = getPackageName(config);
        var startProc = new Process(adbPath, [
            "shell", "am", "start", 
            "-n", packageName + "/" + packageName + ".MainActivity"
        ]);
        startProc.close();
        
        Console.success("Application started!");
        
        Console.info("Showing logcat (Ctrl+C to stop)...");
        Sys.command(adbPath, ["logcat", "-c"]);
        Sys.command(adbPath, ["logcat", "-s", "Heaps:D", "SDL:D", "AndroidRuntime:E"]);
    }
    
    // ==================== Core Build Steps ====================
    
    function generateCCode(config:Config):Bool {
        Console.info("Step 1: Generating C code from Haxe...");
        
        var platform = getName();
        var outDir = config.getOutDir(platform);
        var cFile = outDir + "/" + config.projectName + ".c";
        
        if (!FileSystem.exists(outDir)) {
            FileSystem.createDirectory(outDir);
        }
        
        var hxmlContent = getBuildHxml(config, platform);
        var hxmlPath = config.getBuildDir(platform) + "/build-android.hxml";
        File.saveContent(hxmlPath, hxmlContent);
        
        var exitCode = Sys.command("haxe", [hxmlPath]);
        if (exitCode != 0) {
            Console.error("Haxe compilation failed!");
            return false;
        }
        
        if (!FileSystem.exists(cFile)) {
            var rootCFile = config.projectName + ".c";
            if (FileSystem.exists(rootCFile)) {
                File.copy(rootCFile, cFile);
                FileSystem.deleteFile(rootCFile);
            } else {
                Console.error("C file not generated: " + cFile);
                return false;
            }
        }
        
        Console.success("C code generated: " + cFile);
        return true;
    }
    
    function createAndroidProject(config:Config):Void {
        Console.info("Step 2: Setting up Android project from template...");

        var platform = getName();
        var androidDir = config.getOutDir(platform) + "/android";
        var beapHome = getBeapHome();
        var sdl = projectConfig.sdlVersion;
        var templateDir = beapHome + "/templates/android/" + sdl + "/template";

        if (!FileSystem.exists(templateDir)) {
            Console.error("Template not found: " + templateDir);
            return;
        }

        if (FileSystem.exists(androidDir)) {
            deleteDirectory(androidDir);
        }

        copyDirectory(templateDir, androidDir);
        Console.info("Template copied: " + templateDir);

        // Copy Haxe C output into app/jni/src/
        copyHaxeCOutput(config, androidDir);

        // Patch app/build.gradle with project values
        patchAppBuildGradle(config, androidDir);

        // Update HashLinkActivity getLibraries() with project name
        patchHashLinkActivity(config, androidDir);

        // Fix jni/CMakeLists.txt to only build src (remove SDL ref if not present)
        patchJniCMakeLists(androidDir);
    }

    function copyHaxeCOutput(config:Config, androidDir:String):Void {
        var platform = getName();
        var outDir = config.getOutDir(platform);
        var srcDir = androidDir + "/app/jni/src";

        if (!FileSystem.exists(srcDir)) {
            FileSystem.createDirectory(srcDir);
        }

        copyDirectoryRecursive(outDir, srcDir);

        Console.info("Haxe C output copied to: " + srcDir);
    }

    function copyDirectoryRecursive(source:String, destination:String):Void {
        if (!FileSystem.exists(destination)) {
            FileSystem.createDirectory(destination);
        }
        
        for (item in FileSystem.readDirectory(source)) {
            var sourcePath = source + "/" + item;
            var destPath = destination + "/" + item;

            if (item == "android") continue;
            
            if (FileSystem.isDirectory(sourcePath)) {
                copyDirectoryRecursive(sourcePath, destPath);
            } else {
                File.copy(sourcePath, destPath);
            }
        }
    }

    function patchAppBuildGradle(config:Config, androidDir:String):Void {
        var gradlePath = androidDir + "/app/build.gradle";
        if (!FileSystem.exists(gradlePath)) return;

        var content = File.getContent(gradlePath);
        var packageName = getPackageName(config);
        var abiFilters = projectConfig.androidAbiFilters.join("', '");

        // Replace namespace
        content = StringTools.replace(content, 'namespace = "org.libsdl.app"', 'namespace = "' + packageName + '"');
        content = StringTools.replace(content, "org.libsdl.app", packageName);
        content = StringTools.replace(content, "SDL2", "sdl");

        // Update abiFilters
        var abiPattern = ~/abiFilters '([^']*)'/;
        if (abiPattern.match(content)) {
            content = abiPattern.replace(content, "abiFilters '" + abiFilters + "'");
        }

        // Update sdk versions
        content = StringTools.replace(content, "compileSdkVersion 35", "compileSdkVersion " + projectConfig.androidTargetSdk);
        content = StringTools.replace(content, "minSdkVersion 21", "minSdkVersion " + projectConfig.androidMinSdk);
        content = StringTools.replace(content, "targetSdkVersion 35", "targetSdkVersion " + projectConfig.androidTargetSdk);
        content = StringTools.replace(content, 'versionName "1.0"', 'versionName "' + projectConfig.version + '"');
        content = StringTools.replace(content, 'ndkVersion = "29.0.14206865"', 'ndkVersion = "' + projectConfig.androidNdkVersion + '"');

        // Point CMake at jni directory (relative to app/)
        //content = StringTools.replace(content, "path 'src/main/cpp/CMakeLists.txt'", "path 'jni/CMakeLists.txt'");

        File.saveContent(gradlePath, content);
        Console.info("Patched app/build.gradle");
    }

    function patchHashLinkActivity(config:Config, androidDir:String):Void {
        var activityPath = androidDir + "/app/src/main/java/org/haxe/HashLinkActivity.java";
        if (!FileSystem.exists(activityPath)) return;

        var content = File.getContent(activityPath);

        File.saveContent(activityPath, content);
        Console.info("Patched HashLinkActivity.java");
    }

    function patchJniCMakeLists(androidDir:String):Void {
        var cmakePath = androidDir + "/app/jni/CMakeLists.txt";
        if (!FileSystem.exists(cmakePath)) return;

        var content = File.getContent(cmakePath);
        // Remove add_subdirectory(SDL) if SDL source directory doesn't exist
        if (!FileSystem.exists(androidDir + "/app/jni/SDL")) {
            var sdlLine = ~/add_subdirectory\(SDL\)\s*\n?/;
            content = sdlLine.replace(content, "");
        }
        File.saveContent(cmakePath, content);
    }

    function deleteDirectory(path:String):Void {
        if (!FileSystem.exists(path)) return;
        for (file in FileSystem.readDirectory(path)) {
            var fullPath = path + "/" + file;
            if (FileSystem.isDirectory(fullPath)) {
                deleteDirectory(fullPath);
            } else {
                try { FileSystem.deleteFile(fullPath); } catch (e:Dynamic) {}
            }
        }
        try { FileSystem.deleteDirectory(path); } catch (e:Dynamic) {}
    }

    function copyResources(config:Config):Void {
        Console.info("Step 3: Copying resources...");

        var platform = getName();
        var assetsDir = config.getOutDir(platform) + "/android/app/src/main/assets";

        if (!FileSystem.exists(assetsDir)) {
            FileSystem.createDirectory(assetsDir);
        }

        if (FileSystem.exists("res")) {
            copyDirectory("res", assetsDir + "/res");
        }

        if (FileSystem.exists("assets")) {
            copyDirectory("assets", assetsDir);
        }
    }

    function buildWithGradle(config:Config):Bool {
        Console.info("Step 4: Building APK with Gradle...");

        var platform = getName();
        var androidDir = config.getOutDir(platform) + "/android";
        var currentDir = Sys.getCwd();

        if (!createLocalProperties(androidDir)) {
            return false;
        }

        Sys.setCwd(androidDir);

        var gradleCmd = #if windows "gradlew.bat" #else "./gradlew" #end;

        if (!FileSystem.exists(gradleCmd)) {
            Console.error("gradlew not found in " + androidDir);
            Console.info("Make sure the template has gradlew (or run 'beap setup' first)");
            Sys.setCwd(currentDir);
            return false;
        }

        Console.info("Running: " + gradleCmd + " assembleDebug");
        var result = Sys.command(gradleCmd, ["assembleDebug", "--no-daemon"]);

        Sys.setCwd(currentDir);

        if (result != 0) {
            Console.error("Gradle build failed! Exit code: " + result);
            return false;
        }

        var apkSource = androidDir + "/app/build/outputs/apk/debug/app-debug.apk";
        var apkTarget = config.getOutputPath(platform, ".apk");

        if (FileSystem.exists(apkSource)) {
            // Copy to output
            var outDir = config.getOutDir(platform);
            File.copy(apkSource, apkTarget);
            Console.success("APK built: " + apkTarget);
            return true;
        }

        Console.error("APK not found after build at: " + apkSource);
        return false;
    }

    // ==================== Helper Methods ====================
    
    function getBuildHxml(config:Config, platform:String):String {
        var outDir = config.getOutDir(platform);
        var cFile = outDir + "/" + config.projectName + ".c";
        
        // Use project config to generate HXML
        return projectConfig.generateHxml(platform, false) + 
               '-hl ${cFile}\n' +
               '-D resourcesPath=res\n';
    }
    
    function createLocalProperties(androidDir:String):Bool {
        var sdkPath = projectConfig.androidSdkPath != "" ? projectConfig.androidSdkPath : getAndroidSdk();

        if (sdkPath == null || sdkPath == "") {
            Console.error("Android SDK not found!");
            Console.info("Please set android sdk in project.xml or run: beap setup android");
            return false;
        }

        var sdkPathFormatted = StringTools.replace(sdkPath, "\\", "/");
        // Only write sdk.dir — ndkVersion is set in build.gradle, AGP finds NDK automatically
        var props = 'sdk.dir=' + sdkPathFormatted + '\n';

        File.saveContent(androidDir + "/local.properties", props);
        Console.info("Created local.properties with SDK: " + sdkPathFormatted);
        return true;
    }
    
    function getBeapHome():String {
        try {
            var proc = new Process("haxelib", ["path", "beap"]);
            var output = proc.stdout.readAll().toString();
            proc.close();
            
            var lines = output.split("\n");
            for (line in lines) {
                line = StringTools.trim(line);
                if (line != "" && !StringTools.startsWith(line, "-D")) {
                    line = StringTools.replace(line, "\r", "");
                    return line;
                }
            }
        } catch (e:Dynamic) {}
        return "";
    }
    
    function getAndroidSdk():String {
        // 1. Check project.xml config
        if (projectConfig.androidSdkPath != "" && FileSystem.exists(projectConfig.androidSdkPath))
            return projectConfig.androidSdkPath;

        // 2. Check environment variables
        var androidHome = Sys.getEnv("ANDROID_HOME");
        if (androidHome == null) androidHome = Sys.getEnv("ANDROID_SDK_ROOT");
        if (androidHome != null && FileSystem.exists(androidHome)) return androidHome;

        // 3. Check common paths
        var commonPaths = [
            "C:/Users/" + Sys.getEnv("USERNAME") + "/AppData/Local/Android/Sdk",
            "C:/Program Files (x86)/Android/android-sdk",
            "C:/Android/Sdk",
            "D:/Android/Sdk",
            Sys.getEnv("LOCALAPPDATA") + "/Android/Sdk"
        ];

        for (path in commonPaths) {
            if (path != null && FileSystem.exists(path)) return path;
        }

        return null;
    }
    
    function getAndroidNdk():String {
        // 1. Check project.xml config
        if (projectConfig.androidNdkPath != "" && FileSystem.exists(projectConfig.androidNdkPath))
            return projectConfig.androidNdkPath;

        // 2. Check environment variables
        var ndkHome = Sys.getEnv("ANDROID_NDK_HOME");
        if (ndkHome == null) ndkHome = Sys.getEnv("NDK_HOME");
        if (ndkHome != null && FileSystem.exists(ndkHome)) return ndkHome;

        // 3. Search under SDK directory (prefer version from project.xml)
        var sdk = getAndroidSdk();
        if (sdk != null) {
            var ndkPath = sdk + "/ndk";
            if (FileSystem.exists(ndkPath)) {
                // Try the specific version from project.xml first
                var ndkVer = projectConfig.androidNdkVersion;
                if (ndkVer != "" && FileSystem.exists(ndkPath + "/" + ndkVer))
                    return ndkPath + "/" + ndkVer;
                // Fall back to any installed version
                var versions = FileSystem.readDirectory(ndkPath);
                if (versions.length > 0) return ndkPath + "/" + versions[0];
            }
            var bundlePath = sdk + "/ndk-bundle";
            if (FileSystem.exists(bundlePath)) return bundlePath;
        }

        return null;
    }
    
    function getAdbPath():String {
        var sdk = getAndroidSdk();
        if (sdk != null) {
            var adb = sdk + "/platform-tools/adb";
            #if windows
            adb += ".exe";
            #end
            if (FileSystem.exists(adb)) return adb;
        }
        return "adb";
    }
    
    function getPackageName(config:Config):String {
        return projectConfig.packageName;
    }
    
    function copyDirectory(src:String, dst:String):Void {
        if (!FileSystem.exists(src)) return;
        if (!FileSystem.exists(dst)) FileSystem.createDirectory(dst);
        
        for (file in FileSystem.readDirectory(src)) {
            var srcPath = src + "/" + file;
            var dstPath = dst + "/" + file;
            
            if (FileSystem.isDirectory(srcPath)) {
                copyDirectory(srcPath, dstPath);
            } else {
                File.copy(srcPath, dstPath);
            }
        }
    }
}
