package beap.platforms;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.utils.PlatformUtils;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import sys.io.Process;
import beap.commands.SetupCommand;

class AndroidPlatform implements Platform {
    var gradleVersion = "8.7";
    
    public function new() {}
    
    public function getName():String return "android";
    
    public function getDescription():String {
        return "Android APK (compiles to C with NDK)";
    }
    
    public function isAvailable():Bool {
        return getAndroidSdk() != null;
    }
    
    public function build(config:Config):Bool {
        Console.println(Lang.get("build_android"), ConsoleColor.BOLD);
        
        if (!checkAndSetupAndroid()) {
            return false;
        }
        
        var platform = getName();
        config.ensureDirectories(platform);
        
        createAndroidProject(config);
        
        var hxmlContent = getBuildHxml(config, platform);
        var hxmlPath = config.getBuildDir(platform) + "/build-android.hxml";
        File.saveContent(hxmlPath, hxmlContent);
        
        Console.info("Compiling Haxe to C...");
        var exitCode = Sys.command("haxe", [hxmlPath]);
        if (exitCode != 0) {
            Console.error(Lang.get("build_failed"));
            return false;
        }
        
        copyCFiles(config);
        copyResources(config);
        
        Console.info("Building APK with Gradle and NDK...");
        if (!runGradle(config)) {
            return false;
        }
        
        var outputPath = config.getOutputPath(platform, ".apk");
        Console.success(Lang.get("build_success", [outputPath]));
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
        if (adbPath == "") {
            Console.error("ADB not found!");
            Console.info("Please install Android Platform Tools");
            Console.info("Manual install: adb install -r \"" + apkPath + "\"");
            return;
        }
        
        Console.info("Installing APK to device...");
        try {
            var installProc = new Process(adbPath, ["install", "-r", apkPath]);
            installProc.exitCode();  // 等待安装完成
            var exitCode = installProc.exitCode();
            installProc.close();
            
            if (exitCode != 0) {
                Console.error("Installation failed with code: " + exitCode);
                return;
            }
        } catch (e:Dynamic) {
            Console.error("Failed to run adb: " + e);
            return;
        }
        
        Console.info("Starting app...");
        var packageName = getPackageName(config);
        try {
            var startProc = new Process(adbPath, ["shell", "am", "start", "-n", packageName + "/.MainActivity"]);
            startProc.close();
        } catch (e:Dynamic) {
            Console.error("Failed to start app: " + e);
        }
        
        Console.success(Lang.get("running", [config.projectName]));
    }
    
    function checkAndSetupAndroid():Bool {
        var androidSdk = getAndroidSdk();
        var androidNdk = getAndroidNdk();
        
        if (androidSdk == null || androidNdk == null) {
            Console.warning("Android SDK/NDK not configured!");
            Console.println("");
            Console.println("Would you like to configure Android SDK/NDK now? (y/N): ", ConsoleColor.YELLOW);
            var answer = Sys.stdin().readLine();
            if (answer != null && (answer.toLowerCase() == "y" || answer.toLowerCase() == "yes")) {
                SetupCommand.setupAndroid();
                androidSdk = getAndroidSdk();
                androidNdk = getAndroidNdk();
            }
        }
        
        if (androidSdk == null) {
            Console.error(Lang.get("android_sdk_not_found"));
            Console.println("Run 'beap setup android' to configure");
            return false;
        }
        
        if (androidNdk == null) {
            Console.error(Lang.get("android_ndk_not_found"));
            Console.println("Run 'beap setup android' to configure");
            return false;
        }
        
        Console.success(Lang.get("android_sdk_set", [androidSdk]));
        Console.success(Lang.get("android_ndk_set", [androidNdk]));
        
        var javaResult = Sys.command("java -version > nul 2>&1");
        if (javaResult != 0) {
            Console.error(Lang.get("android_java_not_found"));
            return false;
        }
        
        return true;
    }
    
    function getAndroidSdk():String {
        var home = Sys.getEnv("USERPROFILE");
        if (home == null) home = Sys.getEnv("HOME");
        if (home != null) {
            var configPath = home + "/.beaprc";
            if (FileSystem.exists(configPath)) {
                try {
                    var content = File.getContent(configPath);
                    var lines = content.split("\n");
                    for (line in lines) {
                        if (line.indexOf("android_sdk=") == 0) {
                            var path = line.substr(12);
                            path = StringTools.trim(path);
                            if (FileSystem.exists(path)) {
                                return path;
                            }
                        }
                    }
                } catch (e:Dynamic) {}
            }
        }
        
        var androidHome = Sys.getEnv("ANDROID_HOME");
        if (androidHome == null) androidHome = Sys.getEnv("ANDROID_SDK_ROOT");
        if (androidHome != null && FileSystem.exists(androidHome)) {
            return androidHome;
        }
        
        return null;
    }
    
    function getAndroidNdk():String {
        var home = Sys.getEnv("USERPROFILE");
        if (home == null) home = Sys.getEnv("HOME");
        if (home != null) {
            var configPath = home + "/.beaprc";
            if (FileSystem.exists(configPath)) {
                try {
                    var content = File.getContent(configPath);
                    var lines = content.split("\n");
                    for (line in lines) {
                        if (line.indexOf("android_ndk=") == 0) {
                            var path = line.substr(12);
                            path = StringTools.trim(path);
                            if (FileSystem.exists(path)) {
                                return path;
                            }
                        }
                    }
                } catch (e:Dynamic) {}
            }
        }
        
        var ndkHome = Sys.getEnv("ANDROID_NDK_HOME");
        if (ndkHome == null) ndkHome = Sys.getEnv("NDK_HOME");
        if (ndkHome != null && FileSystem.exists(ndkHome)) {
            return ndkHome;
        }
        
        return null;
    }
    
    function createAndroidProject(config:Config) {
        var platform = getName();
        var androidDir = config.getOutDir(platform) + "/android";
        var packageName = getPackageName(config);
        
        var dirs = [
            androidDir,
            androidDir + "/app",
            androidDir + "/app/src",
            androidDir + "/app/src/main",
            androidDir + "/app/src/main/java",
            androidDir + "/app/src/main/java/" + StringTools.replace(packageName, ".", "/"),
            androidDir + "/app/src/main/res",
            androidDir + "/app/src/main/res/values",
            androidDir + "/app/src/main/res/layout",
            androidDir + "/app/src/main/jni",
            androidDir + "/gradle/wrapper"
        ];
        
        for (dir in dirs) {
            config.createDir(dir);
        }
        
        generateSettingsGradle(config, androidDir);
        generateBuildGradle(config, androidDir);
        generateAppBuildGradle(config, androidDir);
        generateManifest(config, androidDir, packageName);
        generateMainActivity(config, androidDir, packageName);
        generateStringsXml(config, androidDir);
        generateLayoutXml(config, androidDir);
        generateAndroidMk(config, androidDir);
        generateApplicationMk(config, androidDir);
        generateLocalProperties(config, androidDir);
    }

    function generateLocalProperties(config:Config, androidDir:String) {
        var sdkPath = getAndroidSdk();
        if (sdkPath == null) {
            Console.warning("Android SDK not found, local.properties will not be created automatically.");
            return;
        }
        var sdkPathFormatted = StringTools.replace(sdkPath, "\\", "/");
        var content = 'sdk.dir=$sdkPathFormatted\n';
        File.saveContent(androidDir + "/local.properties", content);
        Console.info("Created local.properties with SDK: " + sdkPath);
    }
    
    function generateSettingsGradle(config:Config, androidDir:String) {
        var content = 'rootProject.name = "' + config.projectName + '"
include \':app\'';
        File.saveContent(androidDir + "/settings.gradle", content);
    }
    
    function generateBuildGradle(config:Config, androidDir:String) {
        var content = 'buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath \'com.android.tools.build:gradle:7.4.2\'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

task clean(type: Delete) {
    delete rootProject.buildDir
}';
        File.saveContent(androidDir + "/build.gradle", content);
    }
    
function generateAppBuildGradle(config:Config, androidDir:String) {
    var packageName = getPackageName(config);
    var ndkPath = getAndroidNdk();
    var ndkPathFormatted = ndkPath != null ? StringTools.replace(ndkPath, "\\", "/") : "";
    
    var content = 'plugins {
    id \'com.android.application\'
}

android {
    namespace "' + packageName + '"
    compileSdk 33
    
    ' + (ndkPathFormatted != "" ? 'ndkPath "' + ndkPathFormatted + '"\n' : '') + '
    
    defaultConfig {
        applicationId "' + packageName + '"
        minSdk 21
        targetSdk 33
        versionCode 1
        versionName "1.0"
        
        externalNativeBuild {
            ndkBuild {
                cppFlags "-std=c++11"
                arguments "APP_SHORT_COMMANDS=true", "LOCAL_SHORT_COMMANDS=true"
            }
        }

        ndk {
            abiFilters "arm64-v8a"
        }
    }

    sourceSets {
        main {
            jniLibs.srcDirs = ["src/main/libs"]
        }
    }
    
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile(\'proguard-android-optimize.txt\'), \'proguard-rules.pro\'
        }
        debug {
            debuggable true
        }
    }
    
    externalNativeBuild {
        ndkBuild {
            path file("src/main/jni/Android.mk")
        }
    }
}

dependencies {
    implementation \'androidx.appcompat:appcompat:1.6.1\'
}';
    File.saveContent(androidDir + "/app/build.gradle", content);
}
    
function generateManifest(config:Config, androidDir:String, packageName:String) {
    var content = '<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="' + packageName + '">
    
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    
    <application
        android:allowBackup="true"
        android:icon="@drawable/ic_launcher"
        android:label="' + config.projectName + '"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar">
        
        <activity
            android:name=".MainActivity"
            android:label="' + config.projectName + '"
            android:configChanges="orientation|keyboardHidden|screenSize"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>';
    File.saveContent(androidDir + "/app/src/main/AndroidManifest.xml", content);
}
    
function generateMainActivity(config:Config, androidDir:String, packageName:String) {
    Console.info("Generating MainActivity and HashLinkActivity...");
    
    // 1. 创建 org/haxe 目录
    var hashLinkDir = androidDir + "/app/src/main/java/org/haxe";
    if (!FileSystem.exists(hashLinkDir)) {
        FileSystem.createDirectory(hashLinkDir);
        Console.info("Created directory: " + hashLinkDir);
    }
    
    // 2. 创建 HashLinkActivity.java
    var hashLinkActivityCode = '
package org.haxe;

import android.app.Activity;
import android.os.Bundle;
import android.content.Context;
import android.util.Log;

public class HashLinkActivity extends Activity {
    private static final String TAG = "HashLink";
    private static HashLinkActivity instance;
    
    static {
        try {
            System.loadLibrary("hl");
            System.loadLibrary("main");
            Log.i(TAG, "Libraries loaded successfully");
        } catch (UnsatisfiedLinkError e) {
            Log.e(TAG, "Failed to load libraries: " + e.getMessage());
        }
    }
    
    public static Context getContext() {
        return instance;
    }
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        instance = this;
        Log.i(TAG, "HashLinkActivity onCreate - HashLink should auto-start via JNI_OnLoad");
        
        android.view.SurfaceView surfaceView = new android.view.SurfaceView(this);
        setContentView(surfaceView);
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        instance = null;
        Log.i(TAG, "HashLinkActivity onDestroy");
    }
}
';
    var hashLinkFile = hashLinkDir + "/HashLinkActivity.java";
    File.saveContent(hashLinkFile, hashLinkActivityCode);
    Console.info("Created: " + hashLinkFile);
    
    // 3. 验证 HashLinkActivity.java 是否真的存在
    if (FileSystem.exists(hashLinkFile)) {
        Console.info("[OK] HashLinkActivity.java exists, size: " + FileSystem.stat(hashLinkFile).size + " bytes");
    } else {
        Console.error("[FAIL] HashLinkActivity.java was not created!");
        return;
    }
    
    // 4. 创建 MainActivity
    var packagePath = StringTools.replace(packageName, ".", "/");
    var mainDir = androidDir + "/app/src/main/java/" + packagePath;
    if (!FileSystem.exists(mainDir)) {
        FileSystem.createDirectory(mainDir);
        Console.info("Created directory: " + mainDir);
    }
    
    var mainActivityCode = '
package ' + packageName + ';

import org.haxe.HashLinkActivity;
import android.util.Log;

public class MainActivity extends HashLinkActivity {
    private static final String TAG = "MainActivity";
    
    static {
        try {
            // main库已经在HashLinkActivity中加载，这里不需要重复
            Log.i(TAG, "MainActivity static initializer");
        } catch (UnsatisfiedLinkError e) {
            Log.e(TAG, "Failed: " + e.getMessage());
        }
    }
    
    @Override
    protected void onCreate(android.os.Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.i(TAG, "MainActivity onCreate");
    }
}
';
    var mainFile = mainDir + "/MainActivity.java";
    File.saveContent(mainFile, mainActivityCode);
    Console.info("Created: " + mainFile);
    
    // 5. 验证 MainActivity.java 是否真的存在
    if (FileSystem.exists(mainFile)) {
        Console.info("[OK] MainActivity.java exists, size: " + FileSystem.stat(mainFile).size + " bytes");
    } else {
        Console.error("[FAIL] MainActivity.java was not created!");
        return;
    }
    
    // 6. 列出所有生成的 Java 文件
    Console.info("Java source files in project:");
    var javaDir = androidDir + "/app/src/main/java";
    if (FileSystem.exists(javaDir)) {
        listJavaFiles(javaDir, "");
    }
}

function listJavaFiles(dir:String, indent:String) {
    var files = FileSystem.readDirectory(dir);
    for (file in files) {
        var path = dir + "/" + file;
        if (FileSystem.isDirectory(path)) {
            listJavaFiles(path, indent + "  ");
        } else if (StringTools.endsWith(file, ".java")) {
            Console.info(indent + "- " + path);
        }
    }
}

    
    function generateStringsXml(config:Config, androidDir:String) {
        var resDir = androidDir + "/app/src/main/res/values";
        config.createDir(resDir);
        var content = '<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">' + config.projectName + '</string>
</resources>';
        File.saveContent(resDir + "/strings.xml", content);
    }
    
    function generateLayoutXml(config:Config, androidDir:String) {
        var layoutDir = androidDir + "/app/src/main/res/layout";
        config.createDir(layoutDir);
        var content = '<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    
    <SurfaceView
        android:id="@+id/surfaceView"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />
        
</FrameLayout>';
        File.saveContent(layoutDir + "/activity_main.xml", content);
    }
    
    function generateAndroidMk(config:Config, androidDir:String) {
        var projectName = config.projectName;
        var jniDir = androidDir + "/app/src/main/jni";
        config.createDir(jniDir);
        
        // 只需要主 C 文件
        var srcFiles = [projectName + ".c"];
        var srcList = "";
        for (src in srcFiles) {
            srcList += ' \\\n    ' + src;
        }
        
        var content = 'LOCAL_PATH := $(call my-dir)

# 主模块
include $(CLEAR_VARS)
LOCAL_MODULE := main
LOCAL_SRC_FILES :=' + srcList + '

LOCAL_C_INCLUDES += $(LOCAL_PATH)
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hashlink

# 编译选项
LOCAL_CFLAGS += -std=gnu11 -DUSTR(str)=str -DPCRE2_CODE_UNIT_WIDTH=16
LOCAL_CPPFLAGS += -std=c++11 -frtti -fexceptions

LOCAL_CFLAGS += -D_GNU_SOURCE -D__ANDROID__
LOCAL_CFLAGS += -DSUPPORT_JIT=0

LOCAL_LDLIBS := -llog -landroid -lEGL -lGLESv1_CM -lGLESv2 -lOpenSLES -lm
LOCAL_LDFLAGS += -L$(LOCAL_PATH)/../libs/$(TARGET_ARCH_ABI)
LOCAL_LDFLAGS += -lhl -lSDL2 -lsdl -lopenal -lfmt -luv -lui -lheaps

# 启用短命令
LOCAL_SHORT_COMMANDS := true

include $(BUILD_SHARED_LIBRARY)';
        
        File.saveContent(jniDir + "/Android.mk", content);
    }

    function getCurrentAbi():String {
        var abi = Sys.getEnv("ANDROID_ABI");
        if (abi != null && abi != "") return abi;
        return "arm64-v8a";
    }
    
    function generateApplicationMk(config:Config, androidDir:String) {
        var jniDir = androidDir + "/app/src/main/jni";
        config.createDir(jniDir);
        
        var content = 'APP_ABI := arm64-v8a
APP_PLATFORM := android-21
APP_STL := c++_shared
APP_SHORT_COMMANDS := true
APP_ALLOW_MISSING_DEPENDENCIES := true';
        File.saveContent(jniDir + "/Application.mk", content);
    }
    
    function getBuildHxml(config:Config, platform:String):String {
        var outDir = config.getOutDir(platform);
        var cFile = outDir + "/" + config.projectName + ".c";
        
        if (FileSystem.exists("build-android.hxml")) {
            Console.info(Lang.get("using_user_config"));
            try {
                var content = File.getContent("build-android.hxml");
                return content;
            } catch (e:Dynamic) {
                Console.warning(Lang.get("config_read_error"));
            }
        }
        
        Console.info(Lang.get("using_default_config"));
        return '
-cp src
-main Main
-lib heaps
-lib format
-lib hlsdl
-D android
-D hl_native
-D HXCPP_CPP11
-D sdl
-hl ' + cFile + '
';
    }
    
    function copyCFiles(config:Config) {
        var platform = getName();
        var outDir = config.getOutDir(platform);
        var cFile = outDir + "/" + config.projectName + ".c";
        var jniDir = outDir + "/android/app/src/main/jni";
        var targetFile = jniDir + "/" + config.projectName + ".c";
        
        if (!FileSystem.exists(jniDir)) {
            FileSystem.createDirectory(jniDir);
        }
        
        // 复制主 C 文件
        if (FileSystem.exists(cFile)) {
            File.copy(cFile, targetFile);
            Console.info("Copied C file: " + cFile + " -> " + targetFile);
        } else {
            Console.error("C file not found: " + cFile);
            return;
        }
        
        // 复制 outDir 中需要的目录到 jni 目录
        var neededDirs = ["hl", "hxd", "sdl", "hxsl", "h2d", "h3d", "haxe", "sys", "_std", "_Xml", "format"];
        for (dirName in neededDirs) {
            var srcDir = outDir + "/" + dirName;
            var dstDir = jniDir + "/" + dirName;
            if (FileSystem.exists(srcDir) && FileSystem.isDirectory(srcDir)) {
                if (FileSystem.exists(dstDir)) {
                    try { FileSystem.deleteDirectory(dstDir); } catch (e:Dynamic) {}
                }
                copyDirectory(srcDir, dstDir, config);
                Console.info("Copied directory: " + dirName);
            }
        }
        
        // 复制 BEAP 公共头文件
        var beapHome = getBeapHome();
        var beapIncludeDir = beapHome + "/include/hashlink";
        if (FileSystem.exists(beapIncludeDir)) {
            var targetIncludeDir = jniDir + "/hashlink";
            if (!FileSystem.exists(targetIncludeDir)) {
                FileSystem.createDirectory(targetIncludeDir);
            }
            copyDirectory(beapIncludeDir, targetIncludeDir, config);
            Console.info("Copied HashLink headers from BEAP include");
        }
        
        // 复制预编译库
        copyPrecompiledLibs(config, jniDir);
    }
    
    function copyPrecompiledLibs(config:Config, jniDir:String) {
        var beapHome = getBeapHome();
        var precompiledLibsDir = beapHome + "/tools/android/libs";
        
        if (FileSystem.exists(precompiledLibsDir)) {
            var targetLibsDir = jniDir + "/../libs";
            if (!FileSystem.exists(targetLibsDir)) {
                FileSystem.createDirectory(targetLibsDir);
            }
            copyDirectory(precompiledLibsDir, targetLibsDir, config);
            Console.info("Copied precompiled Android libraries from BEAP tools");
            
            // 验证复制结果
            var archDir = targetLibsDir + "/arm64-v8a";
            if (FileSystem.exists(archDir)) {
                var files = FileSystem.readDirectory(archDir);
                Console.info("Libraries in arm64-v8a: " + files.join(", "));
            }
        } else {
            Console.error("Precompiled Android libraries not found at: " + precompiledLibsDir);
            Console.info("Please place libhl.so, libSDL2.so, libopenal.so in: " + precompiledLibsDir + "/arm64-v8a/");
        }
    }
    
    function copyDirectory(src:String, dst:String, config:Config, ?skipDirs:Array<String>) {
        if (!FileSystem.exists(src)) return;
        if (!FileSystem.exists(dst)) {
            FileSystem.createDirectory(dst);
        }
        
        var files = FileSystem.readDirectory(src);
        for (file in files) {
            if (skipDirs != null && skipDirs.indexOf(file) != -1) {
                continue;
            }
            
            var srcPath = src + "/" + file;
            var dstPath = dst + "/" + file;
            
            if (FileSystem.isDirectory(srcPath)) {
                copyDirectory(srcPath, dstPath, config, skipDirs);
            } else {
                File.copy(srcPath, dstPath);
            }
        }
    }
    
    function getBeapHome():String {
        try {
            var process = new Process("haxelib", ["path", "beap"]);
            var output = process.stdout.readAll().toString();
            process.close();
            
            var lines = output.split("\n");
            if (lines.length > 0) {
                var path = StringTools.trim(lines[0]);
                while (StringTools.endsWith(path, "/") || StringTools.endsWith(path, "\\")) {
                    path = path.substr(0, path.length - 1);
                }
                
                var testPaths = [
                    path,
                    path + "\\bin",
                    path + "\\git",
                    StringTools.replace(path, "/git", ""),
                    StringTools.replace(path, "\\git", "")
                ];
                
                for (testPath in testPaths) {
                    if (FileSystem.exists(testPath + "\\run.n")) {
                        return testPath;
                    }
                    if (FileSystem.exists(testPath + "\\bin\\run.n")) {
                        return testPath;
                    }
                }
                
                return path;
            }
        } catch (e:Dynamic) {}
        
        var currentDir = Sys.getCwd();
        var haxelibLocalPath = currentDir + "\\.haxelib\\beap";
        if (FileSystem.exists(haxelibLocalPath + "\\run.n")) {
            return haxelibLocalPath;
        }
        
        var userProfile = Sys.getEnv("USERPROFILE");
        if (userProfile != null) {
            var userHaxelibPath = userProfile + "\\haxelib\\beap";
            if (FileSystem.exists(userHaxelibPath + "\\run.n")) {
                return userHaxelibPath;
            }
            var userHaxelibGitPath = userProfile + "\\haxelib\\beap\\git";
            if (FileSystem.exists(userHaxelibGitPath + "\\run.n")) {
                return userHaxelibGitPath;
            }
        }
        
        var globalPaths = [
            "C:\\HaxeToolkit\\lib\\beap",
            "C:\\HaxeToolkit\\haxe\\lib\\beap",
            "C:\\Program Files\\Haxe\\lib\\beap"
        ];
        
        for (p in globalPaths) {
            if (FileSystem.exists(p + "\\run.n")) {
                return p;
            }
            if (FileSystem.exists(p + "\\git\\run.n")) {
                return p + "\\git";
            }
        }
        
        return "";
    }
    
    function copyResources(config:Config) {
        var platform = getName();
        var androidResDir = config.getOutDir(platform) + "/android/app/src/main/res";
        
        // 复制 assets
        if (FileSystem.exists("assets")) {
            var targetAssets = androidResDir + "/../assets";
            if (!FileSystem.exists(targetAssets)) {
                FileSystem.createDirectory(targetAssets);
            }
            copyDirectory("assets", targetAssets, config);
        }
        
        // 复制项目中的 res 目录
        if (FileSystem.exists("res")) {
            copyDirectory("res", androidResDir, config);
        }
        
        // 复制应用图标
        var iconPaths = [
            "icon.png",
            "ic_launcher.png", 
            "res/drawable/ic_launcher.png",
            "assets/icon.png"
        ];
        
        var iconFound = false;
        for (iconPath in iconPaths) {
            if (FileSystem.exists(iconPath)) {
                var drawableDir = androidResDir + "/drawable";
                if (!FileSystem.exists(drawableDir)) {
                    FileSystem.createDirectory(drawableDir);
                }
                var targetIcon = drawableDir + "/ic_launcher.png";
                File.copy(iconPath, targetIcon);
                Console.info("Copied icon: " + iconPath + " -> " + targetIcon);
                iconFound = true;
                break;
            }
        }
        
        if (!iconFound) {
            var drawableDir = androidResDir + "/drawable";
            if (!FileSystem.exists(drawableDir)) {
                FileSystem.createDirectory(drawableDir);
            }
            var defaultIcon = '<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp"
    android:height="48dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#3F51B5"
        android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2z"/>
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M8,12 L16,12 M12,8 L12,16"/>
</vector>';
            File.saveContent(drawableDir + "/ic_launcher.xml", defaultIcon);
            Console.info("Created default XML icon");
        }
    }
    
    function runGradle(config:Config):Bool {
        var platform = getName();
        var androidDir = config.getOutDir(platform) + "/android";
        var currentDir = Sys.getCwd();
        
        Console.info("Checking Android project directory: " + androidDir);
        
        if (!FileSystem.exists(androidDir)) {
            Console.error("Android directory not found: " + androidDir);
            return false;
        }
        
        var requiredFiles = [
            androidDir + "/settings.gradle",
            androidDir + "/build.gradle", 
            androidDir + "/app/build.gradle",
            androidDir + "/app/src/main/AndroidManifest.xml"
        ];
        
        var missingFiles = [];
        for (file in requiredFiles) {
            if (!FileSystem.exists(file)) {
                missingFiles.push(file);
            }
        }
        
        if (missingFiles.length > 0) {
            Console.error("Missing required Android project files:");
            for (file in missingFiles) {
                Console.error("  - " + file);
            }
            return false;
        }
        
        var localProps = androidDir + "/local.properties";
        if (!FileSystem.exists(localProps)) {
            Console.info("local.properties not found, creating...");
            var sdkPath = getAndroidSdk();
            if (sdkPath != null) {
                var sdkPathFormatted = StringTools.replace(sdkPath, "\\", "/");
                File.saveContent(localProps, 'sdk.dir=$sdkPathFormatted\n');
                Console.info("Created local.properties");
            } else {
                Console.error("Android SDK not found");
                return false;
            }
        }
        
        var gradleBat = androidDir + "/gradlew.bat";
        if (!FileSystem.exists(gradleBat)) {
            Console.info("gradlew.bat not found, generating...");
            if (!downloadGradleWrapper(androidDir)) {
                Console.error("Failed to generate Gradle wrapper");
                return false;
            }
        }
        
        var javaCheck = Sys.command("java -version > nul 2>&1");
        if (javaCheck != 0) {
            Console.error(Lang.get("android_java_not_found"));
            Console.info("Please install JDK 8 or higher and add it to PATH");
            return false;
        }
        
        Sys.setCwd(androidDir);
        
        Console.info("Running Gradle build in: " + androidDir);
        var result = Sys.command("cmd", ["/c", "gradlew.bat", "assembleDebug", "--no-daemon", "--stacktrace"]);
        
        if (result == 0) {
            var possibleApkPaths = [
                androidDir + "/app/build/outputs/apk/debug/app-debug.apk",
                androidDir + "/app/build/outputs/apk/debug/" + config.projectName.toLowerCase() + "-debug.apk",
                androidDir + "/app/build/outputs/apk/debug/" + config.projectName + "-debug.apk",
            ];
            
            var foundApk = "";
            for (apkPath in possibleApkPaths) {
                if (FileSystem.exists(apkPath)) {
                    foundApk = apkPath;
                    break;
                }
            }
            
            if (foundApk != "") {
                var targetApk = config.getOutputPath(platform, ".apk");
                var targetDir = Path.directory(targetApk);
                if (!FileSystem.exists(targetDir)) {
                    FileSystem.createDirectory(targetDir);
                }
                File.copy(foundApk, targetApk);
                Console.success("APK generated: " + targetApk);
            }
        } else {
            Console.error("Gradle build failed with code: " + result);
        }
        
        Sys.setCwd(currentDir);
        return result == 0;
    }
    
    function downloadGradleWrapper(androidDir:String):Bool {
        var wrapperDir = androidDir + "/gradle/wrapper";
        if (!FileSystem.exists(wrapperDir)) {
            FileSystem.createDirectory(wrapperDir);
        }
        
        var wrapperProps = wrapperDir + "/gradle-wrapper.properties";
        if (!FileSystem.exists(wrapperProps)) {
            var propsContent = 'distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.7-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists';
            File.saveContent(wrapperProps, propsContent);
        }
        
        var gradlePropsPath = androidDir + "/gradle.properties";
        if (!FileSystem.exists(gradlePropsPath)) {
            var gradleProps = '# Project-wide Gradle settings.
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.enableJetifier=true
';
            File.saveContent(gradlePropsPath, gradleProps);
            Console.info("Created gradle.properties with AndroidX enabled");
        }
        
        var gradlewBat = androidDir + "/gradlew.bat";
        var batContent = '@echo off
set DIR=%~dp0
set WRAPPER_JAR="%DIR%gradle\\wrapper\\gradle-wrapper.jar"

if not exist %WRAPPER_JAR% (
    echo Gradle wrapper JAR not found
    exit /b 1
)

java -cp %WRAPPER_JAR% org.gradle.wrapper.GradleWrapperMain %*
';
        File.saveContent(gradlewBat, batContent);
        
        Console.success("Gradle wrapper ready");
        return true;
    }
    
    function getAdbPath():String {
        var androidSdk = getAndroidSdk();
        if (androidSdk != null) {
            // 优先检查 platform-tools 目录
            var adbPath = androidSdk + "/platform-tools/adb";
            #if windows
            adbPath += ".exe";
            #end
            if (FileSystem.exists(adbPath)) {
                return adbPath;
            }
            
            // 兼容旧版 SDK（adb 直接在 SDK 根目录）
            adbPath = androidSdk + "/adb";
            #if windows
            adbPath += ".exe";
            #end
            if (FileSystem.exists(adbPath)) {
                return adbPath;
            }
        }
        
        // 尝试从系统 PATH 中查找 adb
        #if windows
        var result = Sys.command("where adb > nul 2>&1");
        #else
        var result = Sys.command("which adb > /dev/null 2>&1");
        #end
        if (result == 0) {
            return "adb";
        }
        
        return "";
    }
    
    function getPackageName(config:Config):String {
        var packageName = StringTools.replace(config.projectName, "-", "_");
        packageName = StringTools.replace(packageName, " ", "_");
        packageName = packageName.toLowerCase();
        
        var regex = ~/[^a-z0-9_]/g;
        packageName = regex.replace(packageName, "_");
        
        return "com.beap." + packageName;
    }
}