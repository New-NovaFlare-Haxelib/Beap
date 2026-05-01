package beap.platforms;

import beap.Config;
import beap.Console;
import beap.Lang;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import sys.io.Process;

import beap.commands.SetupCommand;

/**
 * Android Platform - HashLink/C (HLC) target
 */
class AndroidPlatform implements Platform {
    
    // 支持的 ABI
    static final ABIS = ["arm64-v8a", "armeabi-v7a", "x86_64"];
    static final DEFAULT_ABI = "arm64-v8a";
    
    public function new() {}
    
    public function getName():String return "android";
    
    public function getDescription():String {
        return "Android APK (HashLink/C native)";
    }
    
    public function isAvailable():Bool {
        if (getAndroidSdk() != null && getAndroidNdk() != null) {
            return true;
        }
        
        var sdk = SetupCommand.getConfigValue("android_sdk");
        var ndk = SetupCommand.getConfigValue("android_ndk");
        
        return sdk != null && sdk != "" && ndk != null && ndk != "";
    }
    
    public function build(config:Config):Bool {
        Console.println(Lang.get("build_android"), ConsoleColor.BOLD);
        
        var platform = getName();
        config.ensureDirectories(platform);
        
        // 1. 生成 C 代码
        if (!generateCCode(config)) {
            return false;
        }
        
        // 2. 创建 Android 项目结构
        createAndroidProject(config);
        
        // 3. 复制 HashLink 运行时库
        if (!copyHashLinkLibraries(config)) {
            return false;
        }
        
        // 4. 复制资源
        copyResources(config);
        
        // 5. 使用 Gradle + NDK 构建
        if (!buildWithGradle(config)) {
            return false;
        }
        
        Console.success(Lang.get("build_success", [config.getOutputPath(platform, ".apk")]));
        return true;
    }
    
    public function run(config:Config):Void {
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
        
        // 可选：查看日志
        Console.info("Showing logcat (Ctrl+C to stop)...");
        Sys.command(adbPath, ["logcat", "-c"]); // 清除旧日志
        Sys.command(adbPath, ["logcat", "-s", "Heaps:D", "SDL:D", "AndroidRuntime:E"]);
    }
    
    // ==================== 核心构建步骤 ====================
    
    function generateCCode(config:Config):Bool {
        Console.info("Step 1: Generating C code from Haxe...");
        
        var platform = getName();
        var outDir = config.getOutDir(platform);
        var cFile = outDir + "/" + config.projectName + ".c";
        
        // 确保输出目录存在
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
        
        // 验证 C 文件生成
        if (!FileSystem.exists(cFile)) {
            // Haxe 可能生成在根目录
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
        Console.info("Step 2: Creating Android project structure...");
        
        var platform = getName();
        var androidDir = config.getOutDir(platform) + "/android";
        var packageName = getPackageName(config);
        var packagePath = StringTools.replace(packageName, ".", "/");
        
        // 创建目录结构
        var dirs = [
            androidDir,
            androidDir + "/app/src/main/java/" + packagePath,
            androidDir + "/app/src/main/cpp",           // C 代码目录
            androidDir + "/app/src/main/jniLibs/" + DEFAULT_ABI,
            androidDir + "/app/src/main/res/values",
            androidDir + "/gradle/wrapper"
        ];
        
        for (dir in dirs) {
            if (!FileSystem.exists(dir)) {
                FileSystem.createDirectory(dir);
            }
        }
        
        // 生成构建文件
        generateGradleFiles(config, androidDir);
        generateCMakeLists(config, androidDir);
        generateManifest(config, androidDir, packageName);
        generateMainActivity(config, androidDir, packageName);
        generateNativeBridge(config, androidDir);  // JNI 桥接层
        generateStrings(config, androidDir);
    }
    
function copyHashLinkLibraries(config:Config):Bool {
    Console.info("Step 3: Copying HashLink native libraries...");

    var platform = getName();
    var androidDir = config.getOutDir(platform) + "/android";
    var jniLibsDir = androidDir + "/app/src/main/jniLibs/" + DEFAULT_ABI;

    var hlLibs = findHashLinkAndroidLibs();
    if (hlLibs == null) {
        Console.error("HashLink Android libraries not found!");
        return false;
    }

    // 你的实际库文件名
    var requiredLibs = [
        "libhl.so",      // HashLink 核心
        "libfmt.so",     // 格式化
        "libSDL2.so",    // SDL2（注意大小写！）
        "libopenal.so",  // 音频
        "libssl.so",     // SSL（如果需要）
        "libuv.so"       // UV（如果需要）
    ];

    var copied = 0;
    for (lib in requiredLibs) {
        var srcPath = hlLibs + "/" + lib;
        var dstPath = jniLibsDir + "/" + lib;

        if (FileSystem.exists(srcPath)) {
            File.copy(srcPath, dstPath);
            Console.info("  Copied: " + lib);
            copied++;
        } else {
            Console.warning("  Missing: " + lib);
        }
    }

    if (copied < 4) {  // 至少需要核心库
        Console.error("Too few libraries copied!");
        return false;
    }

    return true;
}
    
    function copyResources(config:Config):Void {
        Console.info("Step 4: Copying resources...");
        
        var platform = getName();
        var assetsDir = config.getOutDir(platform) + "/android/app/src/main/assets";
        
        if (!FileSystem.exists(assetsDir)) {
            FileSystem.createDirectory(assetsDir);
        }
        
        // 复制 res 目录
        if (FileSystem.exists("res")) {
            copyDirectory("res", assetsDir + "/res");
        }
        
        // 复制其他资源
        if (FileSystem.exists("assets")) {
            copyDirectory("assets", assetsDir);
        }
    }
    
function buildWithGradle(config:Config):Bool {
    Console.info("Step 5: Building APK with Gradle...");

    var platform = getName();
    var androidDir = config.getOutDir(platform) + "/android";
    trace(androidDir);
    var currentDir = Sys.getCwd();

    if (!createLocalProperties(androidDir)) {
        return false;
    }

    // 创建 Gradle Wrapper（下载 wrapper.jar）
    if (!createGradleWrapper(androidDir)) {
        Console.error("Failed to create Gradle Wrapper!");
        return false;
    }

    // 验证 wrapper 是否存在
    var wrapperJar = androidDir + "/gradle/wrapper/gradle-wrapper.jar";
    if (!FileSystem.exists(wrapperJar)) {
        Console.error("Gradle Wrapper JAR not found after creation!");
        return false;
    }

    // 切换到 Android 目录并构建
    Sys.setCwd(androidDir);

    var gradleCmd = #if windows "gradlew.bat" #else "./gradlew" #end;
    
    Console.info("Running: " + gradleCmd + " assembleDebug");
    var result = Sys.command(gradleCmd, ["assembleDebug", "--no-daemon"]);

    Sys.setCwd(currentDir);

    if (result != 0) {
        Console.error("Gradle build failed! Exit code: " + result);
        return false;
    }

    // 复制 APK 到输出目录
    var apkSource = androidDir + "/app/build/outputs/apk/debug/app-debug.apk";
    var apkTarget = config.getOutputPath(platform, ".apk");

    if (FileSystem.exists(apkSource)) {
        File.copy(apkSource, apkTarget);
        Console.success("APK built: " + apkTarget);
        return true;
    }

    Console.error("APK not found after build at: " + apkSource);
    return false;
}
    
    // ==================== 文件生成器 ====================
    
    function generateGradleFiles(config:Config, androidDir:String):Void {
        // settings.gradle
        File.saveContent(androidDir + "/settings.gradle", 
            'rootProject.name = "${config.projectName}"\ninclude ":app"\n'
        );
        
        // build.gradle (项目级)
        File.saveContent(androidDir + "/build.gradle", 
            'buildscript {\n' +
            '    repositories { google(); mavenCentral() }\n' +
            '    dependencies { classpath "com.android.tools.build:gradle:8.1.4" }\n' +
            '}\n\n' +
            'allprojects {\n' +
            '    repositories { google(); mavenCentral() }\n' +
            '}\n'
        );
        
        // app/build.gradle
        var packageName = getPackageName(config);
        var appGradle = 
            'plugins { id "com.android.application" }\n\n' +
            'android {\n' +
            '    namespace "${packageName}"\n' +
            '    compileSdk 34\n\n' +
            '    defaultConfig {\n' +
            '        applicationId "${packageName}"\n' +
            '        minSdk 24\n' +
            '        targetSdk 34\n' +
            '        versionCode 1\n' +
            '        versionName "1.0"\n\n' +
            '        ndk { abiFilters "${DEFAULT_ABI}" }\n' +
            '    }\n\n' +
            '    externalNativeBuild {\n' +
            '        cmake {\n' +
            '            path "src/main/cpp/CMakeLists.txt"\n' +
            '            version "3.22.1"\n' +
            '        }\n' +
            '    }\n\n' +
            '    buildTypes {\n' +
            '        release { minifyEnabled false }\n' +
            '        debug { debuggable true }\n' +
            '    }\n\n' +
            '    sourceSets {\n' +
            '        main { jniLibs.srcDirs = ["src/main/jniLibs"] }\n' +
            '    }\n' +
            '}\n\n' +
            'dependencies {\n' +
            '    implementation "androidx.appcompat:appcompat:1.6.1"\n' +
            '}';
        
        File.saveContent(androidDir + "/app/build.gradle", appGradle);
        
        // gradle.properties
        File.saveContent(androidDir + "/gradle.properties", 
            'android.useAndroidX=true\n' +
            'android.enableJetifier=true\n' +
            'org.gradle.jvmargs=-Xmx2048m\n'
        );
    }
    
    function generateCMakeLists(config:Config, androidDir:String):Void {
        var cppDir = androidDir + "/app/src/main/cpp";
        var platform = getName();
        var outDir = config.getOutDir(platform);
        
        var cmakeContent = 
            'cmake_minimum_required(VERSION 3.22.1)\n' +
            'project(${config.projectName} C)\n\n' +
            'set(CMAKE_C_STANDARD 11)\n' +
            'set(CMAKE_C_STANDARD_REQUIRED ON)\n\n' +
            '# 关闭 C++ 扩展（纯 C 项目）\n' +
            'set(CMAKE_CXX_EXTENSIONS OFF)\n\n' +
            '# 源文件：主 C 文件 + 生成的 C 文件目录\n' +
            'set(HL_SRC\n' +
            '    ${outDir}/${config.projectName}.c\n' +
            '    ${cppDir}/native_bridge.c\n' +  // JNI 桥接
            ')\n\n' +
            '# 添加库\n' +
            'add_library(${config.projectName} SHARED $${HL_SRC})\n\n' +
            '# 包含目录\n' +
            'target_include_directories(${config.projectName} PRIVATE\n' +
            '    ${cppDir}\n' +
            '    ${cppDir}/hashlink\n' +
            ')\n\n' +
            '# 预处理器定义\n' +
            'target_compile_definitions(${config.projectName} PRIVATE\n' +
            '    -D_GNU_SOURCE\n' +
            '    -D__ANDROID__\n' +
            '    -DHL_ANDROID\n' +
            '    -DPCRE2_CODE_UNIT_WIDTH=16\n' +
            ')\n\n' +
            '# 查找系统库\n' +
            'find_library(LOG_LIB log)\n' +
            'find_library(ANDROID_LIB android)\n' +
            'find_library(EGL_LIB EGL)\n' +
            'find_library(GLES_LIB GLESv2)\n' +
            'find_library(OPENSL_LIB OpenSLES)\n\n' +
            '# 导入 HashLink 库\n' +
            'add_library(hl SHARED IMPORTED)\n' +
            'set_target_properties(hl PROPERTIES\n' +
            '    IMPORTED_LOCATION ${cppDir}/../jniLibs/$${ANDROID_ABI}/libhl.so)\n\n' +
            'add_library(sdl SHARED IMPORTED)\n' +
            'set_target_properties(sdl PROPERTIES\n' +
            '    IMPORTED_LOCATION ${cppDir}/../jniLibs/$${ANDROID_ABI}/libsdl.so)\n\n' +
            'add_library(openal SHARED IMPORTED)\n' +
            'set_target_properties(openal PROPERTIES\n' +
            '    IMPORTED_LOCATION ${cppDir}/../jniLibs/$${ANDROID_ABI}/libopenal.so)\n\n' +
            'add_library(fmt SHARED IMPORTED)\n' +
            'set_target_properties(fmt PROPERTIES\n' +
            '    IMPORTED_LOCATION ${cppDir}/../jniLibs/$${ANDROID_ABI}/libfmt.so)\n\n' +
            '# 链接\n' +
            'target_link_libraries(${config.projectName}\n' +
            '    hl sdl openal fmt\n' +
            '    $${LOG_LIB} $${ANDROID_LIB} $${EGL_LIB} $${GLES_LIB} $${OPENSL_LIB}\n' +
            '    m dl\n' +
            ')';
        
        File.saveContent(cppDir + "/CMakeLists.txt", cmakeContent);
    }
    
    function generateManifest(config:Config, androidDir:String, packageName:String):Void {
        var manifest = 
            '<?xml version="1.0" encoding="utf-8"?>\n' +
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n' +
            '    package="${packageName}">\n\n' +
            '    <uses-feature android:glEsVersion="0x00020000" android:required="true" />\n\n' +
            '    <uses-permission android:name="android.permission.INTERNET" />\n' +
            '    <uses-permission android:name="android.permission.WAKE_LOCK" />\n\n' +
            '    <application\n' +
            '        android:allowBackup="true"\n' +
            '        android:icon="@mipmap/ic_launcher"\n' +
            '        android:label="@string/app_name"\n' +
            '        android:theme="@style/AppTheme"\n' +
            '        android:hardwareAccelerated="true"\n' +
            '        android:extractNativeLibs="true">\n\n' +
            '        <activity\n' +
            '            android:name=".MainActivity"\n' +
            '            android:exported="true"\n' +
            '            android:configChanges="orientation|screenSize|smallestScreenSize|keyboardHidden"\n' +
            '            android:launchMode="singleTask"\n' +
            '            android:screenOrientation="landscape">\n' +
            '            <intent-filter>\n' +
            '                <action android:name="android.intent.action.MAIN" />\n' +
            '                <category android:name="android.intent.category.LAUNCHER" />\n' +
            '            </intent-filter>\n' +
            '        </activity>\n' +
            '    </application>\n' +
            '</manifest>';
        
        File.saveContent(androidDir + "/app/src/main/AndroidManifest.xml", manifest);
    }
    
    function generateMainActivity(config:Config, androidDir:String, packageName:String):Void {
        var packagePath = StringTools.replace(packageName, ".", "/");
        var activityDir = androidDir + "/app/src/main/java/" + packagePath;
        
        // MainActivity.java - 加载 native 库并启动
        var activityCode = 
            'package ${packageName};\n\n' +
            'import android.app.Activity;\n' +
            'import android.os.Bundle;\n' +
            'import android.util.Log;\n' +
            'import android.view.SurfaceView;\n' +
            'import android.view.SurfaceHolder;\n' +
            'import android.widget.FrameLayout;\n\n' +
            'public class MainActivity extends Activity {\n' +
            '    private static final String TAG = "Heaps";\n' +
            '    private SurfaceView surfaceView;\n\n' +
            '    // 加载 native 库\n' +
            '    static {\n' +
            '        try {\n' +
            '            System.loadLibrary("${config.projectName}");\n' +
            '            Log.i(TAG, "Native library loaded successfully");\n' +
            '        } catch (UnsatisfiedLinkError e) {\n' +
            '            Log.e(TAG, "Failed to load native library: " + e.getMessage());\n' +
            '        }\n' +
            '    }\n\n' +
            '    @Override\n' +
            '    protected void onCreate(Bundle savedInstanceState) {\n' +
            '        super.onCreate(savedInstanceState);\n' +
            '        Log.i(TAG, "onCreate");\n\n' +
            '        // 创建 SurfaceView 用于渲染\n' +
            '        surfaceView = new SurfaceView(this);\n' +
            '        surfaceView.getHolder().addCallback(new SurfaceHolder.Callback() {\n' +
            '            @Override\n' +
            '            public void surfaceCreated(SurfaceHolder holder) {\n' +
            '                Log.i(TAG, "Surface created");\n' +
            '                nativeInit(getAssets().getAbsolutePath());\n' +
            '            }\n\n' +
            '            @Override\n' +
            '            public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {\n' +
            '                Log.i(TAG, "Surface changed: " + w + "x" + h);\n' +
            '                nativeResize(w, h);\n' +
            '            }\n\n' +
            '            @Override\n' +
            '            public void surfaceDestroyed(SurfaceHolder holder) {\n' +
            '                Log.i(TAG, "Surface destroyed");\n' +
            '                nativePause();\n' +
            '            }\n' +
            '        });\n\n' +
            '        setContentView(surfaceView);\n' +
            '    }\n\n' +
            '    @Override\n' +
            '    protected void onPause() {\n' +
            '        super.onPause();\n' +
            '        nativePause();\n' +
            '    }\n\n' +
            '    @Override\n' +
            '    protected void onResume() {\n' +
            '        super.onResume();\n' +
            '        nativeResume();\n' +
            '    }\n\n' +
            '    @Override\n' +
            '    protected void onDestroy() {\n' +
            '        super.onDestroy();\n' +
            '        nativeQuit();\n' +
            '    }\n\n' +
            '    // Native methods\n' +
            '    private static native void nativeInit(String assetPath);\n' +
            '    private static native void nativeResize(int width, int height);\n' +
            '    private static native void nativePause();\n' +
            '    private static native void nativeResume();\n' +
            '    private static native void nativeQuit();\n' +
            '}';
        
        File.saveContent(activityDir + "/MainActivity.java", activityCode);
    }
    
    function generateNativeBridge(config:Config, androidDir:String):Void {
        var cppDir = androidDir + "/app/src/main/cpp";
        
        // native_bridge.c - JNI 桥接层（纯 C）
        var bridgeCode = 
            '#include <jni.h>\n' +
            '#include <android/log.h>\n' +
            '#include <stdlib.h>\n' +
            '#include <string.h>\n' +
            '#include <hl.h>\n\n' +
            '#define LOG_TAG "Heaps"\n' +
            '#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)\n' +
            '#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)\n\n' +
            '// Haxe 入口函数（由 Haxe 生成）\n' +
            'extern void _main();\n\n' +
            '// 全局状态\n' +
            'static int g_initialized = 0;\n' +
            'static char g_assetPath[512] = {0};\n\n' +
            'JNIEXPORT void JNICALL\n' +
            'Java_${StringTools.replace(getPackageName(config), ".", "_")}_MainActivity_nativeInit(\n' +
            '    JNIEnv *env, jclass clazz, jstring assetPath) {\n\n' +
            '    LOGI("nativeInit called");\n\n' +
            '    if (assetPath) {\n' +
            '        const char *path = (*env)->GetStringUTFChars(env, assetPath, NULL);\n' +
            '        strncpy(g_assetPath, path, sizeof(g_assetPath) - 1);\n' +
            '        (*env)->ReleaseStringUTFChars(env, assetPath, path);\n' +
            '        LOGI("Asset path: %s", g_assetPath);\n' +
            '    }\n\n' +
            '    if (!g_initialized) {\n' +
            '        LOGI("Initializing HashLink runtime...");\n' +
            '        hl_global_init();\n' +
            '        hl_sys_init(NULL, 0, NULL);\n' +
            '        g_initialized = 1;\n' +
            '        LOGI("HashLink initialized, calling _main()");\n' +
            '        _main();\n' +
            '    } else {\n' +
            '        LOGI("Already initialized");\n' +
            '    }\n' +
            '}\n\n' +
            'JNIEXPORT void JNICALL\n' +
            'Java_${StringTools.replace(getPackageName(config), ".", "_")}_MainActivity_nativeResize(\n' +
            '    JNIEnv *env, jclass clazz, jint width, jint height) {\n\n' +
            '    LOGI("nativeResize: %dx%d", width, height);\n' +
            '    // TODO: 通知 Haxe 端窗口大小变化\n' +
            '}\n\n' +
            'JNIEXPORT void JNICALL\n' +
            'Java_${StringTools.replace(getPackageName(config), ".", "_")}_MainActivity_nativePause(\n' +
            '    JNIEnv *env, jclass clazz) {\n\n' +
            '    LOGI("nativePause");\n' +
            '    // TODO: 暂停游戏循环\n' +
            '}\n\n' +
            'JNIEXPORT void JNICALL\n' +
            'Java_${StringTools.replace(getPackageName(config), ".", "_")}_MainActivity_nativeResume(\n' +
            '    JNIEnv *env, jclass clazz) {\n\n' +
            '    LOGI("nativeResume");\n' +
            '    // TODO: 恢复游戏循环\n' +
            '}\n\n' +
            'JNIEXPORT void JNICALL\n' +
            'Java_${StringTools.replace(getPackageName(config), ".", "_")}_MainActivity_nativeQuit(\n' +
            '    JNIEnv *env, jclass clazz) {\n\n' +
            '    LOGI("nativeQuit");\n' +
            '    if (g_initialized) {\n' +
            '        hl_global_free();\n' +
            '        g_initialized = 0;\n' +
            '    }\n' +
            '}';
        
        File.saveContent(cppDir + "/native_bridge.c", bridgeCode);
        
        // 创建空的 hashlink 目录用于头文件
        if (!FileSystem.exists(cppDir + "/hashlink")) {
            FileSystem.createDirectory(cppDir + "/hashlink");
        }
    }
    
    function generateStrings(config:Config, androidDir:String):Void {
        var strings = 
            '<resources>\n' +
            '    <string name="app_name">${config.projectName}</string>\n' +
            '</resources>';
        File.saveContent(androidDir + "/app/src/main/res/values/strings.xml", strings);
        
        // 简单的主题
        var styles = 
            '<resources>\n' +
            '    <style name="AppTheme" parent="android:Theme.NoTitleBar.Fullscreen">\n' +
            '        <item name="android:windowFullscreen">true</item>\n' +
            '        <item name="android:windowNoTitle">true</item>\n' +
            '    </style>\n' +
            '</resources>';
        File.saveContent(androidDir + "/app/src/main/res/values/styles.xml", styles);
    }
    
    // ==================== 辅助方法 ====================
    
    function getBuildHxml(config:Config, platform:String):String {
        var outDir = config.getOutDir(platform);
        var cFile = outDir + "/" + config.projectName + ".c";
        
        // 检查用户自定义 hxml
        if (FileSystem.exists("build-android.hxml")) {
            Console.info("Using user's build-android.hxml");
            try {
                var content = File.getContent("build-android.hxml");
                // 确保输出路径正确
                if (content.indexOf("-hl") == -1) {
                    content += '\n-hl ${cFile}\n';
                }
                return content;
            } catch (e:Dynamic) {
                Console.warning("Failed to read build-android.hxml");
            }
        }
        
        // 默认配置
        return 
            '-cp src\n' +
            '-main Main\n' +
            '-lib heaps\n' +
            '-lib format\n' +
            '-lib hlsdl\n' +
            '-D android\n' +
            '-D mobile\n' +
            '-D hl_ver=1.14\n' +
            '-D windowTitle=${config.projectName}\n' +
            '-D windowSize=1280x720\n' +
            '-D resourcesPath=res\n' +
            '-hl ${cFile}\n';
    }
    
function createLocalProperties(androidDir:String):Bool {
    var sdkPath = getAndroidSdk();
    var ndkPath = getAndroidNdk();
    
    if (sdkPath == null) {
        sdkPath = SetupCommand.getConfigValue("android_sdk");
    }
    if (ndkPath == null) {
        ndkPath = SetupCommand.getConfigValue("android_ndk");
    }
    
    if (sdkPath == null || sdkPath == "") {
        Console.error("Android SDK not found!");
        Console.info("Please run: beap setup android");
        return false;
    }
    
    var sdkPathFormatted = StringTools.replace(sdkPath, "\\", "/");
    
    var props = 'sdk.dir=${sdkPathFormatted}\n';
    
    if (ndkPath != null && ndkPath != "") {
        var ndkPathFormatted = StringTools.replace(ndkPath, "\\", "/");
        props += 'ndk.dir=${ndkPathFormatted}\n';
    }
    
    File.saveContent(androidDir + "/local.properties", props);
    Console.info("Created local.properties with SDK: " + sdkPathFormatted);
    return true;
}
    
function createGradleWrapper(androidDir:String):Bool {
    var wrapperDir = androidDir + "/gradle/wrapper";
    
    // 确保目录存在！
    if (!FileSystem.exists(wrapperDir)) {
        FileSystem.createDirectory(wrapperDir);
        Console.info("Created directory: " + wrapperDir);
    }
    
    // gradle-wrapper.properties
    var props = 
        'distributionBase=GRADLE_USER_HOME\n' +
        'distributionPath=wrapper/dists\n' +
        'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.7-bin.zip\n' +
        'networkTimeout=10000\n' +
        'zipStoreBase=GRADLE_USER_HOME\n' +
        'zipStorePath=wrapper/dists\n';
    
    File.saveContent(wrapperDir + "/gradle-wrapper.properties", props);
    
    var wrapperJar = wrapperDir + "/gradle-wrapper.jar";
    if (!FileSystem.exists(wrapperJar)) {
        Console.info("Downloading Gradle Wrapper JAR...");
        var downloaded = downloadFile("https://raw.githubusercontent.com/gradle/gradle/v8.7.0/gradle/wrapper/gradle-wrapper.jar", wrapperJar);
        if (!downloaded) {
            Console.error("Failed to download gradle-wrapper.jar!");
            return false;
        }
    }
    
    // 检查是否真的存在
    if (!FileSystem.exists(wrapperJar)) {
        Console.error("gradle-wrapper.jar still not found after download attempt!");
        return false;
    }
    
    // gradlew.bat
    var batContent = 
        '@echo off\n' +
        'setlocal\n\n' +
        'set DIRNAME=%~dp0\n' +
        'if "%DIRNAME%"=="" set DIRNAME=.\n' +
        'set APP_BASE_NAME=%~n0\n' +
        'set APP_HOME=%DIRNAME%\n\n' +
        '@rem Resolve any "." and ".." in APP_HOME\n' +
        'for %%i in ("%APP_HOME%") do set APP_HOME=%%~fi\n\n' +
        '@rem Add default JVM options\n' +
        'set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"\n\n' +
        '@rem Find java.exe\n' +
        'if defined JAVA_HOME goto findJavaFromJavaHome\n\n' +
        'set JAVA_EXE=java.exe\n' +
        '%JAVA_EXE% -version >NUL 2>&1\n' +
        'if %ERRORLEVEL% equ 0 goto execute\n\n' +
        'echo ERROR: JAVA_HOME is not set and no java command could be found in your PATH.\n' +
        'goto fail\n\n' +
        ':findJavaFromJavaHome\n' +
        'set JAVA_HOME=%JAVA_HOME:"=%\n' +
        'set JAVA_EXE=%JAVA_HOME%/bin/java.exe\n\n' +
        'if exist "%JAVA_EXE%" goto execute\n\n' +
        'echo ERROR: JAVA_HOME is set to an invalid directory: %JAVA_HOME%\n' +
        'goto fail\n\n' +
        ':execute\n' +
        '@rem Setup the command line\n' +
        'set CLASSPATH=%APP_HOME%\\gradle\\wrapper\\gradle-wrapper.jar\n\n' +
        '"%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% "-Dorg.gradle.appname=%APP_BASE_NAME%" -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*\n\n' +
        ':fail\n' +
        'exit /b 1\n';
    
    File.saveContent(androidDir + "/gradlew.bat", batContent);
    
    return true;
}

function downloadFile(url:String, destPath:String):Bool {
    try {
        #if windows
        Console.info("Downloading with PowerShell...");
        var psCmd = 'Invoke-WebRequest -Uri "' + url + '" -OutFile "' + destPath + '" -UseBasicParsing';
        var result = Sys.command("powershell", ["-ExecutionPolicy", "Bypass", "-Command", psCmd]);
        if (result == 0 && FileSystem.exists(destPath)) {
            Console.success("Downloaded: " + destPath);
            return true;
        }
        
        // 备用：使用 curl（Windows 10+ 自带）
        if (!FileSystem.exists(destPath)) {
            Console.info("Trying curl...");
            result = Sys.command("curl", ["-L", "-o", destPath, url]);
            if (result == 0 && FileSystem.exists(destPath)) {
                Console.success("Downloaded: " + destPath);
                return true;
            }
        }
        
        // 备用：使用 certutil
        if (!FileSystem.exists(destPath)) {
            Console.info("Trying certutil...");
            result = Sys.command("certutil", ["-urlcache", "-split", "-f", url, destPath]);
            if (result == 0 && FileSystem.exists(destPath)) {
                // certutil 会生成临时文件，需要清理
                var tempFile = destPath + ".";
                if (FileSystem.exists(tempFile)) {
                    try { FileSystem.deleteFile(tempFile); } catch (e:Dynamic) {}
                }
                Console.success("Downloaded: " + destPath);
                return true;
            }
        }
        #else
        // Unix: 使用 curl 或 wget
        var result = Sys.command("curl", ["-L", "-o", destPath, url]);
        if (result == 0 && FileSystem.exists(destPath)) {
            return true;
        }
        
        if (!FileSystem.exists(destPath)) {
            result = Sys.command("wget", ["-O", destPath, url]);
            if (result == 0 && FileSystem.exists(destPath)) {
                return true;
            }
        }
        #end
        
        Console.error("All download methods failed for: " + url);
        return false;
    } catch (e:Dynamic) {
        Console.error("Download error: " + e);
        return false;
    }
}
    
function findHashLinkAndroidLibs():String {
    // 1. 检查 beap 工具目录（你的实际路径）
    var beapHome = getBeapHome();
    Console.info("Checking Beap tools directory: " + beapHome);
    
    if (beapHome != "") {
        // 你的实际路径：tools/android/libs/arm64-v8a/
        var libPath = beapHome + "/tools/android/libs/" + DEFAULT_ABI;
        Console.info("Checking path: " + libPath);
        
        if (FileSystem.exists(libPath)) {
            Console.success("Found HashLink libs in beap tools: " + libPath);
            return libPath;
        } else {
            Console.warning("Path not found: " + libPath);
        }
    }
    
    // 2. 检查环境变量 HASHLINK
    var hlPath = Sys.getEnv("HASHLINK");
    if (hlPath != null) {
        var libPath = hlPath + "/android/" + DEFAULT_ABI;
        if (FileSystem.exists(libPath)) {
            Console.info("Found HashLink libs in HASHLINK env: " + libPath);
            return libPath;
        }
    }
    
    // 3. 检查 haxelib hashlink
    try {
        var proc = new Process("haxelib", ["path", "hashlink"]);
        var output = proc.stdout.readAll().toString();
        proc.close();
        
        var lines = output.split("\n");
        for (line in lines) {
            line = StringTools.trim(line);
            if (line != "" && !StringTools.startsWith(line, "-D")) {
                line = StringTools.replace(line, "\r", "");
                var libPath = line + "/android/" + DEFAULT_ABI;
                if (FileSystem.exists(libPath)) {
                    Console.info("Found HashLink libs in haxelib: " + libPath);
                    return libPath;
                }
            }
        }
    } catch (e:Dynamic) {}
    
    Console.error("Could not find HashLink Android libraries in any location");
    return null;
}
    
function getBeapHome():String {
    try {
        var proc = new Process("haxelib", ["path", "beap"]);
        var output = proc.stdout.readAll().toString();
        proc.close();
        
        var lines = output.split("\n");
        for (line in lines) {
            line = StringTools.trim(line);
            // 跳过空行和以 -D 开头的定义行
            if (line != "" && !StringTools.startsWith(line, "-D")) {
                // 移除可能的 \r
                line = StringTools.replace(line, "\r", "");
                return line;
            }
        }
    } catch (e:Dynamic) {
        Console.warning("Failed to get beap home: " + e);
    }
    return "";
}
    
function getAndroidSdk():String {
    // 1. 环境变量
    var androidHome = Sys.getEnv("ANDROID_HOME");
    if (androidHome == null) androidHome = Sys.getEnv("ANDROID_SDK_ROOT");
    if (androidHome != null && FileSystem.exists(androidHome)) {
        return androidHome;
    }
    
    // 2. .beaprc 配置
    var configSdk = SetupCommand.getConfigValue("android_sdk");
    if (configSdk != null && configSdk != "" && FileSystem.exists(configSdk)) {
        return configSdk;
    }
    
    // 3. 常见路径
    var commonPaths = [
        "C:/Users/" + Sys.getEnv("USERNAME") + "/AppData/Local/Android/Sdk",
        "C:/Program Files (x86)/Android/android-sdk",
        "C:/Android/Sdk",
        "D:/Android/Sdk",
        Sys.getEnv("LOCALAPPDATA") + "/Android/Sdk"
    ];
    
    for (path in commonPaths) {
        if (path != null && FileSystem.exists(path)) {
            return path;
        }
    }
    
    return null;
}

function getAndroidNdk():String {
    // 1. 环境变量
    var ndkHome = Sys.getEnv("ANDROID_NDK_HOME");
    if (ndkHome == null) ndkHome = Sys.getEnv("NDK_HOME");
    if (ndkHome != null && FileSystem.exists(ndkHome)) {
        return ndkHome;
    }
    
    // 2. .beaprc 配置
    var configNdk = SetupCommand.getConfigValue("android_ndk");
    if (configNdk != null && configNdk != "" && FileSystem.exists(configNdk)) {
        return configNdk;
    }
    
    // 3. SDK 中的 NDK
    var sdk = getAndroidSdk();
    if (sdk != null) {
        var ndkPath = sdk + "/ndk";
        if (FileSystem.exists(ndkPath)) {
            var versions = FileSystem.readDirectory(ndkPath);
            if (versions.length > 0) {
                return ndkPath + "/" + versions[0];
            }
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
        return "adb"; // 尝试 PATH 中的 adb
    }
    
    function getPackageName(config:Config):String {
        // 将项目名转换为有效的包名
        var cleanName = ~/[^a-zA-Z0-9_]/g.replace(config.projectName, "_").toLowerCase();
        return "com.beap." + cleanName;
    }
    
    // ==================== 工具方法 ====================
    
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