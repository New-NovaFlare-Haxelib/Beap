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
            Console.error("APK not found: " + apkPath);
            Console.info("Run 'beap build android' first");
            return;
        }
        
        var adbPath = getAdbPath();
        if (adbPath == "") {
            Console.error(Lang.get("android_adb_not_found"));
            return;
        }
        
        Console.info("Installing APK to device...");
        Sys.command('"' + adbPath + '" install -r "' + apkPath + '"');
        
        Console.info("Starting app...");
        var packageName = getPackageName(config);
        Sys.command('"' + adbPath + '" shell am start -n ' + packageName + '/.MainActivity');
        
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
                // 强制启用短命令模式，解决 Windows 命令行长度限制
                arguments "APP_SHORT_COMMANDS=true", "LOCAL_SHORT_COMMANDS=true"
            }
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
        var content = 'package ' + packageName + ';

import android.os.Bundle;
import android.view.SurfaceView;
import android.widget.FrameLayout;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {
    static {
        System.loadLibrary("main");
    }
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        FrameLayout layout = new FrameLayout(this);
        SurfaceView surfaceView = new SurfaceView(this);
        layout.addView(surfaceView);
        setContentView(layout);
    }
}';
        var packagePath = StringTools.replace(packageName, ".", "/");
        var javaDir = androidDir + "/app/src/main/java/" + packagePath;
        config.createDir(javaDir);
        File.saveContent(javaDir + "/MainActivity.java", content);
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
    
    // 只收集主文件和 hl_libs 下的库文件
    var srcFiles = [projectName + ".c"];
    
    function collectCFiles(dir:String, prefix:String) {
        if (!FileSystem.exists(dir)) return;
        var items = FileSystem.readDirectory(dir);
        for (item in items) {
            if (item == "directx" || item == "sdl" || item == "openal" || item == "mysql" || 
                item == "ui" || item == "video" || item == "win" || item == "mesa") {
                continue;
            }
            
            var fullPath = dir + "/" + item;
            if (FileSystem.isDirectory(fullPath)) {
                collectCFiles(fullPath, prefix + item + "/");
            } else if (StringTools.endsWith(item, ".c")) {
                
                // 跳过所有 Haxe 生成的代码目录（已在主 C 文件中）
                // 这些目录的代码已经编译进 NovaFlareEngine.c 了
                var skipPrefixes = [
                    "hl/", "hxd/", "hxsl/", "h2d/", "h3d/", "haxe/",
                    "sys/", "_std/", "_Xml/", "format/"
                ];
                
                var shouldSkip = false;
                for (skipPrefix in skipPrefixes) {
                    if (prefix.indexOf(skipPrefix) == 0) {
                        shouldSkip = true;
                        break;
                    }
                }
                
                if (shouldSkip) {
                    continue;
                }
                
                var skipList = [
                        "allocator.c", "profile.c",
                        "posix-poll.c",
                        "process.c",
                        // AIX
                        "aix-common.c", "aix.c",
                        // Solaris
                        "sunos.c",
                        // IBM
                        "os390.c", "os390-proctitle.c", "os390-syscalls.c",
                        // BSD 系列
                        "freebsd.c", "dragonflybsd.c", "openbsd.c", "netbsd.c",
                        "bsd-ifaddrs.c", "bsd-proctitle.c",
                        "kqueue.c",
                        "fsevents.c", "no-fsevents.c",
                        // macOS/Darwin
                        "darwin.c", "darwin-proctitle.c", "darwin-stub.h", "darwin-syscalls.h",
                        // 其他平台
                        "cygwin.c", "haiku.c", "hurd.c", "ibmi.c", "qnx.c",
                        "pthread-fixes.c",
                        "proctitle.c", "no-proctitle.c",
                        "main.c",
                        "hlc_main.c",
                        "System.c",

                        "pcre2_jit_compile.c",
                        "pcre2_jit_match.c", 
                        "pcre2_jit_simd.c",
                        "pcre2_jit_misc.c",
                        "pcre2_jit_test.c"
                    ];

                if (prefix.indexOf("png") != -1) {
                    srcFiles.push(prefix + item);
                    continue;
                }
                
                // turbojpeg 特定处理：只编译主文件
                if (prefix.indexOf("turbojpeg") != -1) {
                   var turbojpegMainFiles = [
                        "jcapimin.c", "jcapistd.c", "jcarith.c", "jccoefct.c",
                        "jccolor.c", "jcdctmgr.c", "jchuff.c", "jcinit.c",
                        "jcmainct.c", "jcmarker.c", "jcmaster.c", "jcomapi.c",
                        "jcparam.c", "jcphuff.c", "jcprepct.c", "jcsample.c",
                        "jctrans.c", "jdapimin.c", "jdapistd.c", "jdarith.c",
                        "jdatadst.c", "jdatasrc.c", "jdatadst-tj.c", "jdatasrc-tj.c",
                        "jdcoefct.c", "jdcolor.c", "jddctmgr.c", "jdhuff.c",
                        "jdinput.c", "jdmainct.c", "jdmarker.c", "jdmaster.c",
                        "jdmerge.c", "jdphuff.c", "jdpostct.c", "jdsample.c",
                        "jdtrans.c", "jerror.c", "jfdctflt.c", "jfdctfst.c",
                        "jfdctint.c", "jidctflt.c", "jidctfst.c", "jidctint.c",
                        "jidctred.c", "jmemmgr.c", "jmemnobs.c", "jquant1.c",
                        "jquant2.c", "jutils.c", "transupp.c", "turbojpeg.c",
                        "jsimd_none.c", "jaricom.c",
                    ];
                    if (turbojpegMainFiles.indexOf(item) == -1) {
                        continue;
                    }
                }
                
                if (skipList.indexOf(item) != -1) {
                    continue;
                }
                
                srcFiles.push(prefix + item);
            }
        }
    }
    
    collectCFiles(jniDir + "/hl_libs", "hl_libs/");
    collectCFiles(jniDir + "/hashlink-src", "hashlink-src/");
    
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
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hashlink-src
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hashlink-src/std
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/directx
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/fmt
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/gl
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/heaps
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/libuv
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/libuv/include
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/libuv/src
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/mbedtls
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/mbedtls/include
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/mdbg
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/mesa
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/meshoptimizer
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/mikktspace
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/minimp3
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/mysql
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/openal
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/pcre
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/png
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/renderdoc
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/sdl
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/sqlite
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/sqlite/src
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/ssl
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/turbojpeg
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/turbojpeg/x86
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/turbojpeg/x64
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/ui
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/uv
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/vhacd
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/video
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/vorbis
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/vtune
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/winpixeventruntime
LOCAL_C_INCLUDES += $(LOCAL_PATH)/hl_libs/zlib

# 编译选项
LOCAL_CFLAGS += -std=gnu11 -DUSTR(str)=str -DPCRE2_CODE_UNIT_WIDTH=16
LOCAL_CPPFLAGS += -std=c++11 -frtti -fexceptions

LOCAL_CFLAGS += -DPNG_NO_CONFIG_H

LOCAL_LDLIBS := -llog -landroid -lEGL -lGLESv1_CM -lGLESv2 -lOpenSLES -lm

# libuv 相关宏
LOCAL_CFLAGS += -D_GNU_SOURCE -D__ANDROID__
LOCAL_CFLAGS += -DHAVE_PTHREAD_BARRIER=0
LOCAL_CFLAGS += -DUV__IO_MAX_BYTES=2147483647
LOCAL_CFLAGS += -Dgetifaddrs(x)=(-1)
LOCAL_CFLAGS += -Dfreeifaddrs(x)=
LOCAL_CFLAGS += -DSIZEOF_SIZE_T=8
LOCAL_CFLAGS += -DJPEG_LIB_VERSION=80
LOCAL_CFLAGS += -DPNG_ARM_NEON_OPT=0

LOCAL_CFLAGS += -DHAVE_STDDEF_H
LOCAL_CFLAGS += -DHAVE_STDLIB_H

LOCAL_CFLAGS += -DHAVE_CONFIG_H
LOCAL_CFLAGS += -DLINK_SIZE=2
LOCAL_CFLAGS += -DMAX_NAME_SIZE=1000
LOCAL_CFLAGS += -DMAX_NAME_COUNT=10000

LOCAL_CFLAGS += -D__ANDROID__
LOCAL_CFLAGS += -DUV__PLATFORM_SUPPORTS_PROCESS=0
LOCAL_CFLAGS += -DHAVE_PTHREAD_BARRIER=0
LOCAL_CFLAGS += -DHAVE_PTHREAD_CONDATTR_SETCLOCK=0
LOCAL_CFLAGS += -DHAVE_SYS_LOADAVG_H=0
LOCAL_CFLAGS += -DHAVE_IFADDRS_H=0

LOCAL_CFLAGS += -DSUPPORT_JIT=0

# 启用短命令
LOCAL_SHORT_COMMANDS := true

include $(BUILD_SHARED_LIBRARY)';
    
    File.saveContent(jniDir + "/Android.mk", content);
}

// 获取当前 ABI（可以从环境变量或 NDK 参数获取）
function getCurrentAbi():String {
    // 可以从 ANDROID_ABI 环境变量获取
    var abi = Sys.getEnv("ANDROID_ABI");
    if (abi != null && abi != "") return abi;
    return "arm64-v8a"; // 默认
}

    function getHashLinkDir():String {
        // 检查 PATH
        var result = Sys.command("where hl > nul 2>&1");
        if (result == 0) {
            try {
                var process = new sys.io.Process("where", ["hl"]);
                var hlPath = StringTools.trim(process.stdout.readAll().toString());
                process.close();
                Console.info("hl found at: " + hlPath);
                return Path.directory(hlPath);
            } catch (e:Dynamic) {}
        }
        
        // 常见安装路径
        var commonPaths = [
            "C:\\HaxeToolkit\\hl",
            "C:\\hashlink",
            "D:\\NewProject\\hashlink-9d827bf-win64",
            Sys.getEnv("HASHLINK_PATH")
        ];
        
        for (p in commonPaths) {
            if (p != null && FileSystem.exists(p) && (FileSystem.exists(p + "\\hl.exe") || FileSystem.exists(p + "\\bin\\hl.exe"))) {
                var hlDir = p;
                if (FileSystem.exists(p + "\\bin\\hl.exe")) {
                    hlDir = p + "\\bin";
                }
                Console.info("HashLink found at: " + hlDir);
                return hlDir;
            }
        }
        
        return "";
    }
    
function generateApplicationMk(config:Config, androidDir:String) {
    var jniDir = androidDir + "/app/src/main/jni";
    config.createDir(jniDir);
    
    var content = 'APP_ABI := armeabi-v7a arm64-v8a x86 x86_64
APP_PLATFORM := android-21
APP_STL := c++_shared
APP_SHORT_COMMANDS := true
APP_ALLOW_MISSING_DEPENDENCIES := true';
    File.saveContent(jniDir + "/Application.mk", content);
}
    
function generateGradleWrapper(config:Config, androidDir:String) {
    var wrapperDir = androidDir + "/gradle/wrapper";
    config.createDir(wrapperDir);
    
    // 只生成 gradle-wrapper.properties
    var wrapperProps = 'distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.7-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists';
    File.saveContent(wrapperDir + "/gradle-wrapper.properties", wrapperProps);
    
    // 生成正确的 gradlew.bat - 使用 -cp 而不是 -jar，并且不手动下载
    var gradlewBat = '@echo off
set DIR=%~dp0
set WRAPPER_JAR="%DIR%gradle\\wrapper\\gradle-wrapper.jar"

if not exist %WRAPPER_JAR% (
    echo Gradle wrapper JAR not found. Please run "gradle wrapper" first.
    echo Or install Gradle and run: gradle wrapper --gradle-version 8.7
    exit /b 1
)

java -cp %WRAPPER_JAR% org.gradle.wrapper.GradleWrapperMain %*
';
    File.saveContent(androidDir + "/gradlew.bat", gradlewBat);
    
    // 生成 gradlew (Unix)
    var gradlewSh = '#!/bin/sh
DIR=$(cd "$(dirname "$0")" && pwd)
WRAPPER_JAR="$$DIR/gradle/wrapper/gradle-wrapper.jar"
if [ ! -f "$$WRAPPER_JAR" ]; then
    echo "Gradle wrapper JAR not found. Please run gradle wrapper first."
    exit 1
fi
exec java -cp "$$WRAPPER_JAR" org.gradle.wrapper.GradleWrapperMain "$@"
';
    File.saveContent(androidDir + "/gradlew", gradlewSh);
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
-lib hldx
-D android
-D hl_native
-D HXCPP_CPP11
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
    
    // 复制 C 文件
    if (FileSystem.exists(cFile)) {
        File.copy(cFile, targetFile);
        Console.info("Copied C file: " + cFile + " -> " + targetFile);
    } else {
        Console.error("C file not found: " + cFile);
    }
    
    // 复制 outDir 下所有内容，但排除不需要的目录
    var excludeDirs = ["android","directx", "win", "windows", "sdl", "openal", "mysql", "ui", "video", "hl", "hxd", "hxsl", "h2d", "h3d"];
    var items = FileSystem.readDirectory(outDir);
    for (item in items) {
        // 跳过不需要的目录
        if (excludeDirs.indexOf(item) != -1) {
            Console.info("Skipping directory: " + item);
            continue;
        }
        
        var srcPath = outDir + "/" + item;
        var dstPath = jniDir + "/" + item;
        if (FileSystem.isDirectory(srcPath)) {
            if (FileSystem.exists(dstPath)) {
                try { FileSystem.deleteDirectory(dstPath); } catch (e:Dynamic) {}
            }
            copyDirectory(srcPath, dstPath, config);
        } else {
            // 跳过 Windows 可执行文件和库文件
            if (StringTools.endsWith(item, ".dll") || 
                StringTools.endsWith(item, ".exe") ||
                StringTools.endsWith(item, ".lib") ||
                StringTools.endsWith(item, ".pdb")) {
                continue;
            }
            File.copy(srcPath, dstPath);
        }
    }
    
    // 复制 beap/tools/hashlink-src 目录
    var beapHome = getBeapHome();
    var hashlinkSrcDir = beapHome + "/tools/hashlink-src";
    if (FileSystem.exists(hashlinkSrcDir)) {
        var targetHashlinkSrc = jniDir + "/hashlink-src";
        if (FileSystem.exists(targetHashlinkSrc)) {
            try { FileSystem.deleteDirectory(targetHashlinkSrc); } catch (e:Dynamic) {}
        }
        copyDirectory(hashlinkSrcDir, targetHashlinkSrc, config);
        Console.info("Copied hashlink-src from beap tools");
    }
    
    // 复制所有 hl_libs 源文件，跳过 Windows 目录
    var hashlinkLibsDir = getHashLinkLibsDir();
    if (hashlinkLibsDir != "") {
        Console.info("Copying HashLink libs source files...");
        var targetLibsDir = jniDir + "/hl_libs";
        if (FileSystem.exists(targetLibsDir)) {
            try { FileSystem.deleteDirectory(targetLibsDir); } catch (e:Dynamic) {}
        }
        
        // 使用带过滤的复制
        var skipLibDirs = ["directx", "sdl", "openal", "mysql", "ui", "video", "win"];
        copyDirectoryWithFilter(hashlinkLibsDir, targetLibsDir, config, skipLibDirs);
        
        Console.info("Copied all HashLink libs (skipped Windows-specific directories)");
    }
}

// 添加辅助函数
function copyDirectoryWithFilter(src:String, dst:String, config:Config, excludeDirs:Array<String>) {
    if (!FileSystem.exists(src)) return;
    if (!FileSystem.exists(dst)) {
        FileSystem.createDirectory(dst);
    }
    
    var files = FileSystem.readDirectory(src);
    for (file in files) {
        // 跳过排除的目录
        if (excludeDirs != null && excludeDirs.indexOf(file) != -1) {
            Console.info("Excluding: " + file);
            continue;
        }
        
        var srcPath = src + "/" + file;
        var dstPath = dst + "/" + file;
        
        if (FileSystem.isDirectory(srcPath)) {
            copyDirectoryWithFilter(srcPath, dstPath, config, excludeDirs);
        } else {
            File.copy(srcPath, dstPath);
        }
    }
}

    function getHashLinkLibsDir():String {
    // 获取 beap 安装目录
    var beapHome = getBeapHome();
    var possiblePaths = [
        beapHome + "/tools/hashlink-libs",
        Sys.getCwd() + "/tools/hashlink-libs",
        Sys.getEnv("HASHLINK_LIBS_PATH")
    ];
    
    for (p in possiblePaths) {
        if (p != null && FileSystem.exists(p + "/fmt/dxt.c")) {
            return p;
        }
    }
    
    Console.warning("HashLink libs not found, fmt functions may be missing");
    return "";
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
                        Console.info("Found run.n at: " + testPath);
                        return testPath;
                    }
                    if (FileSystem.exists(testPath + "\\bin\\run.n")) {
                        Console.info("Found run.n at: " + testPath + "\\bin");
                        return testPath;
                    }
                }
                
                Console.info("Using beap path: " + path);
                return path;
            }
        } catch (e:Dynamic) {
            Console.info("haxelib path beap failed: " + e);
        }
        
        var currentDir = Sys.getCwd();
        var haxelibLocalPath = currentDir + "\\.haxelib\\beap";
        if (FileSystem.exists(haxelibLocalPath + "\\run.n")) {
            Console.info("Found beap at local project: " + haxelibLocalPath);
            return haxelibLocalPath;
        }
        
        var userProfile = Sys.getEnv("USERPROFILE");
        if (userProfile != null) {
            var userHaxelibPath = userProfile + "\\haxelib\\beap";
            if (FileSystem.exists(userHaxelibPath + "\\run.n")) {
                Console.info("Found beap at user haxelib: " + userHaxelibPath);
                return userHaxelibPath;
            }
            var userHaxelibGitPath = userProfile + "\\haxelib\\beap\\git";
            if (FileSystem.exists(userHaxelibGitPath + "\\run.n")) {
                Console.info("Found beap at user haxelib: " + userHaxelibGitPath);
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
                Console.info("Found beap at: " + p);
                return p;
            }
            if (FileSystem.exists(p + "\\git\\run.n")) {
                Console.info("Found beap at: " + p + "\\git");
                return p + "\\git";
            }
        }
        
        return "";
    }

    function getHashLinkIncludeDir():String {
        // 检查 PATH
        var result = Sys.command("where hl > nul 2>&1");
        if (result == 0) {
            try {
                var process = new sys.io.Process("where", ["hl"]);
                var hlPath = StringTools.trim(process.stdout.readAll().toString());
                process.close();
                var hlDir = Path.directory(hlPath);
                var includeDir = hlDir + "/include";
                if (FileSystem.exists(includeDir)) {
                    return includeDir;
                }
            } catch (e:Dynamic) {}
        }
        
        // 常见安装路径
        var commonPaths = [
            "C:\\HaxeToolkit\\hl\\include",
            "C:\\hashlink\\include",
            "D:\\NewProject\\hashlink-9d827bf-win64\\include",
            Sys.getEnv("HASHLINK_PATH") + "/include"
        ];
        
        for (p in commonPaths) {
            if (p != null && FileSystem.exists(p)) {
                return p;
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
        
        // 复制应用图标（如果存在）
        var iconPaths = [
            "icon.png",
            "ic_launcher.png", 
            "res/drawable/ic_launcher.png",
            "assets/icon.png"
        ];
        
        var iconFound = false;
        for (iconPath in iconPaths) {
            if (FileSystem.exists(iconPath)) {
                // 创建 drawable 目录
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
            Console.warning("No icon found, using default");
            // 创建默认的 XML 图标
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
        
        // 复制多分辨率图标（如果有 mipmap 目录）
        if (FileSystem.exists("mipmap-hdpi")) {
            copyDirectory("mipmap-hdpi", androidResDir + "/mipmap-hdpi", config);
        }
        if (FileSystem.exists("mipmap-mdpi")) {
            copyDirectory("mipmap-mdpi", androidResDir + "/mipmap-mdpi", config);
        }
        if (FileSystem.exists("mipmap-xhdpi")) {
            copyDirectory("mipmap-xhdpi", androidResDir + "/mipmap-xhdpi", config);
        }
        if (FileSystem.exists("mipmap-xxhdpi")) {
            copyDirectory("mipmap-xxhdpi", androidResDir + "/mipmap-xxhdpi", config);
        }
        if (FileSystem.exists("mipmap-xxxhdpi")) {
            copyDirectory("mipmap-xxxhdpi", androidResDir + "/mipmap-xxxhdpi", config);
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
            Console.info("Skipping directory: " + file);
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
    
function runGradle(config:Config):Bool {
    var platform = getName();
    var androidDir = config.getOutDir(platform) + "/android";
    var currentDir = Sys.getCwd();
    
    Console.info("Checking Android project directory: " + androidDir);
    
    if (!FileSystem.exists(androidDir)) {
        Console.error("Android directory not found: " + androidDir);
        return false;
    }
    
    // ===== 1. 检查必要的项目文件 =====
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
    
    // ===== 2. 检查 local.properties =====
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
    
    // ===== 3. 检查 gradlew.bat 是否存在且有效 =====
    var gradleBat = androidDir + "/gradlew.bat";
    var needRegenerate = false;
    
    if (!FileSystem.exists(gradleBat)) {
        Console.info("gradlew.bat not found, will generate");
        needRegenerate = true;
    } else {
        // 检查文件内容是否有效（不是被破坏的 'build'）
        var content = File.getContent(gradleBat);
        if (content.indexOf("GradleWrapperMain") == -1 && content.indexOf("gradle") == -1) {
            Console.warning("gradlew.bat appears invalid, will regenerate");
            needRegenerate = true;
        } else {
            Console.info("gradlew.bat found and appears valid");
        }
    }
    
    // ===== 4. 检查 gradle-wrapper.jar =====
    var wrapperJar = androidDir + "/gradle/wrapper/gradle-wrapper.jar";
    if (!FileSystem.exists(wrapperJar) || FileSystem.stat(wrapperJar).size < 50000) {
        Console.info("gradle-wrapper.jar missing or incomplete (size: " + 
            (FileSystem.exists(wrapperJar) ? Std.string(FileSystem.stat(wrapperJar).size) : "0") + " bytes)");
        needRegenerate = true;
    } else {
        Console.info("gradle-wrapper.jar found (" + FileSystem.stat(wrapperJar).size + " bytes)");
    }
    
    // ===== 5. 检查 gradle-wrapper.properties =====
    var wrapperProps = androidDir + "/gradle/wrapper/gradle-wrapper.properties";
    if (!FileSystem.exists(wrapperProps)) {
        Console.info("gradle-wrapper.properties not found, will generate");
        needRegenerate = true;
    }
    
    // ===== 6. 如果需要，生成完整的 wrapper =====
    if (needRegenerate) {
        Console.info("Generating Gradle wrapper...");
        if (!downloadGradleWrapper(androidDir)) {
            Console.error("Failed to generate Gradle wrapper");
            return false;
        }
        Console.success("Gradle wrapper generated successfully");
    } else {
        Console.info("Gradle wrapper already exists and is valid, skipping generation");
    }
    
    // ===== 7. 运行构建 =====
    var javaCheck = Sys.command("java -version > nul 2>&1");
    if (javaCheck != 0) {
        Console.error(Lang.get("android_java_not_found"));
        Console.info("Please install JDK 8 or higher and add it to PATH");
        return false;
    }
    
    Sys.setCwd(androidDir);
    
    Console.info("Running Gradle build in: " + androidDir);
    var result = Sys.command("cmd", ["/c", "gradlew.bat", "assembleDebug", "--no-daemon", "--stacktrace"]);
    
    // ===== 8. 处理构建结果 =====
    if (result == 0) {
        // 查找并复制 APK...
        var possibleApkPaths = [
            androidDir + "/app/build/outputs/apk/debug/app-debug.apk",
            androidDir + "/app/build/outputs/apk/debug/" + config.projectName.toLowerCase() + "-debug.apk"
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
    
    // 1. 确保 gradle-wrapper.properties 存在
    var wrapperProps = wrapperDir + "/gradle-wrapper.properties";
    if (!FileSystem.exists(wrapperProps)) {
        var propsContent = 'distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.7-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists';
        File.saveContent(wrapperProps, propsContent);
    }
    
    // 2. 创建 gradle.properties 并启用 AndroidX（关键！）
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
            var adbPath = androidSdk + "/platform-tools/adb";
            #if windows
            adbPath += ".exe";
            #end
            if (FileSystem.exists(adbPath)) {
                return adbPath;
            }
        }
        
        var result = Sys.command("adb version > nul 2>&1");
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