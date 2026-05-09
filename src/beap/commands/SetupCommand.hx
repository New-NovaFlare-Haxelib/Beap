package beap.commands;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.utils.PlatformUtils;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import beap.commands.Command.BaseCommand;

class SetupCommand extends BaseCommand {
    public override function execute(args:Array<String>) {
        if (args.length > 0 && args[0] == "android") {
            setupAndroid();
            return;
        }
        
        Console.println(Lang.get("setting_up"), ConsoleColor.BOLD);
        Console.println("");
        
        if (PlatformUtils.isWindows()) {
            setupWindows();
        } else if (PlatformUtils.isMac() || PlatformUtils.isLinux()) {
            setupUnix();
        } else {
            Console.error("Unsupported OS: " + PlatformUtils.getOsName());
            Console.println("Please manually add beap to your PATH");
        }
    }
    
    // Android SDK/NDK 交互式设置
    public static function setupAndroid():Void {
        Console.println("Android SDK/NDK Setup", ConsoleColor.BOLD);
        Console.println("");
        
        var configPath = getConfigPath();
        var currentSdk = getConfigValue("android_sdk");
        var currentNdk = getConfigValue("android_ndk");
        
        // 显示当前配置
        Console.println("Current configuration:", ConsoleColor.YELLOW);
        if (currentSdk != null && currentSdk != "") {
            Console.println("  Android SDK: " + currentSdk, ConsoleColor.GREEN);
        } else {
            Console.println("  Android SDK: [not set]", ConsoleColor.RED);
        }
        if (currentNdk != null && currentNdk != "") {
            Console.println("  Android NDK: " + currentNdk, ConsoleColor.GREEN);
        } else {
            Console.println("  Android NDK: [not set]", ConsoleColor.RED);
        }
        Console.println("");
        
        // 设置 SDK 路径
        Console.print("Enter Android SDK path (or press Enter to skip): ", ConsoleColor.CYAN);
        var sdkPath = Sys.stdin().readLine();
        if (sdkPath != null && StringTools.trim(sdkPath) != "") {
            sdkPath = StringTools.trim(sdkPath);
            if (FileSystem.exists(sdkPath)) {
                setConfigValue("android_sdk", sdkPath);
                Console.success("Android SDK set to: " + sdkPath);
            } else {
                Console.error("Path does not exist: " + sdkPath);
            }
        }
        
        Console.println("");
        
        // 设置 NDK 路径
        Console.print("Enter Android NDK path (or press Enter to skip): ", ConsoleColor.CYAN);
        var ndkPath = Sys.stdin().readLine();
        if (ndkPath != null && StringTools.trim(ndkPath) != "") {
            ndkPath = StringTools.trim(ndkPath);
            if (FileSystem.exists(ndkPath)) {
                setConfigValue("android_ndk", ndkPath);
                Console.success("Android NDK set to: " + ndkPath);
            } else {
                Console.error("Path does not exist: " + ndkPath);
            }
        }
        
        Console.println("");
        Console.success("Android configuration complete!");
        Console.println("You can now run: beap build android", ConsoleColor.CYAN);
    }
    
    // 检查并提示设置 Android 环境（用于 build/test 命令）
    public static function checkAndSetupAndroid():Bool {
        var androidSdk = getConfigValue("android_sdk");
        var androidNdk = getConfigValue("android_ndk");
        
        // 也检查环境变量
        if (androidSdk == null || androidSdk == "") {
            androidSdk = Sys.getEnv("ANDROID_HOME");
            if (androidSdk == null) androidSdk = Sys.getEnv("ANDROID_SDK_ROOT");
        }
        if (androidNdk == null || androidNdk == "") {
            androidNdk = Sys.getEnv("ANDROID_NDK_HOME");
            if (androidNdk == null) androidNdk = Sys.getEnv("NDK_HOME");
        }
        
        if (androidSdk == null || androidSdk == "" || androidNdk == null || androidNdk == "") {
            Console.warning("Android SDK/NDK not configured!");
            Console.println("");
            Console.println("Would you like to configure Android SDK/NDK now? (y/N): ", ConsoleColor.YELLOW);
            var answer = Sys.stdin().readLine();
            if (answer != null && (answer.toLowerCase() == "y" || answer.toLowerCase() == "yes")) {
                setupAndroid();
                // 重新读取配置
                androidSdk = getConfigValue("android_sdk");
                androidNdk = getConfigValue("android_ndk");
                if (androidSdk == null || androidSdk == "") {
                    androidSdk = Sys.getEnv("ANDROID_HOME");
                }
                if (androidNdk == null || androidNdk == "") {
                    androidNdk = Sys.getEnv("ANDROID_NDK_HOME");
                }
            }
        }
        
        if (androidSdk == null || androidSdk == "" || androidNdk == null || androidNdk == "") {
            Console.error("Android SDK/NDK not configured!");
            Console.println("Run 'beap setup android' to configure", ConsoleColor.CYAN);
            return false;
        }
        
        return true;
    }
    
    public static function getConfigValue(key:String):String {
        var configPath = getConfigPath();
        if (FileSystem.exists(configPath)) {
            try {
                var content = File.getContent(configPath);
                var lines = content.split("\n");
                for (line in lines) {
                    var trimmed = StringTools.trim(line);
                    if (trimmed == "" || trimmed.charAt(0) == "#") continue;
                    if (trimmed.indexOf(key + "=") == 0) {
                        return trimmed.substr(key.length + 1);
                    }
                }
            } catch (e:Dynamic) {}
        }
        return null;
    }
    
    public static function setConfigValue(key:String, value:String):Void {
        var configPath = getConfigPath();
        var config = new Map<String, String>();
        
        // 读取现有配置
        if (FileSystem.exists(configPath)) {
            try {
                var content = File.getContent(configPath);
                var lines = content.split("\n");
                for (line in lines) {
                    var trimmed = StringTools.trim(line);
                    if (trimmed == "" || trimmed.charAt(0) == "#") continue;
                    var eqPos = trimmed.indexOf("=");
                    if (eqPos > 0) {
                        var k = StringTools.trim(trimmed.substr(0, eqPos));
                        var v = StringTools.trim(trimmed.substr(eqPos + 1));
                        config.set(k, v);
                    }
                }
            } catch (e:Dynamic) {}
        }
        
        // 设置新值
        config.set(key, value);
        
        // 保存配置
        var lines = [];
        for (k in config.keys()) {
            lines.push(k + "=" + config.get(k));
        }
        
        try {
            File.saveContent(configPath, lines.join("\n"));
        } catch (e:Dynamic) {
            Console.error("Failed to save config: " + e);
        }
    }
    
    static function getConfigPath():String {
        var home = Sys.getEnv("USERPROFILE");
        if (home == null) home = Sys.getEnv("HOME");
        return home + "/.beaprc";
    }
    
    function setupWindows() {
        var beapHome = getBeapHome();
        if (beapHome == "") {
            Console.error("Cannot find beap installation directory!");
            Console.println("");
            Console.println("Make sure beap is installed via haxelib:", ConsoleColor.YELLOW);
            Console.println("  haxelib install beap", ConsoleColor.CYAN);
            printManualInstructions();
            return;
        }
        
        var haxeDir = getHaxeDir();
        if (haxeDir == "") {
            Console.error("Haxe directory not found!");
            printManualInstructions();
            return;
        }
        
        var beapCmd = haxeDir + "\\beap.cmd";
        var nekoPath = getNekoPath();
        
        var beapHomeFixed = StringTools.replace(beapHome, "/", "\\");
        
        var beapNPath = "";
        if (FileSystem.exists(beapHomeFixed + "\\run.n")) {
            beapNPath = beapHomeFixed + "\\run.n";
        } else if (FileSystem.exists(beapHomeFixed + "\\bin\\run.n")) {
            beapNPath = beapHomeFixed + "\\bin\\run.n";
        } else {
            Console.error("Cannot find run.n in: " + beapHomeFixed);
            return;
        }
        
        var content = '@echo off
rem beap - Heaps Build Tool
rem Generated by beap setup

' + nekoPath + ' "' + beapNPath + '" %*
';
        
        try {
            File.saveContent(beapCmd, content);
            Console.success("Created: " + beapCmd);
            Console.println("");
            Console.info("You can now use 'beap' command directly!");
            Console.println("Make sure " + haxeDir + " is in your PATH");
            Console.println("");
            Console.println("Test with: beap help", ConsoleColor.CYAN);
        } catch (e:Dynamic) {
            Console.error("Failed to create beap.cmd: " + e);
            printManualInstructions();
        }
    }
    
    function setupUnix() {
        var beapHome = getBeapHome();
        if (beapHome == "") {
            Console.error("Cannot find beap installation directory!");
            printManualInstructions();
            return;
        }
        
        var home = Sys.getEnv("HOME");
        if (home == null || home == "") {
            Console.error("HOME environment variable not found");
            printManualInstructions();
            return;
        }
        
        var localBin = home + "/.local/bin";
        if (!FileSystem.exists(localBin)) {
            try {
                FileSystem.createDirectory(localBin);
                Console.info("Created: " + localBin);
            } catch (e:Dynamic) {
                Console.warning("Could not create " + localBin);
            }
        }
        
        var beapScript = localBin + "/beap";
        var nekoPath = getNekoPath();
        
        var content = '#!/bin/bash
# beap - Heaps Build Tool
# Generated by beap setup

BEAP_HOME="' + beapHome + '"
' + nekoPath + ' "$$BEAP_HOME/bin/run.n" "$$@"
';
        
        try {
            File.saveContent(beapScript, content);
            Sys.command('chmod +x "' + beapScript + '"');
            Console.success("Created: " + beapScript);
            Console.println("");
            Console.info("You can now use 'beap' command directly!");
            Console.println("Make sure " + localBin + " is in your PATH");
            Console.println("");
            Console.println("If not, add this to your ~/.bashrc or ~/.zshrc:");
            Console.println('  export PATH="$$HOME/.local/bin:$$PATH"', ConsoleColor.CYAN);
            Console.println("");
            Console.println("Test with: beap help", ConsoleColor.CYAN);
        } catch (e:Dynamic) {
            Console.error("Failed to create beap script: " + e);
            printManualInstructions();
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
    
    function getHaxeDir():String {
        try {
            var process = new Process("where", ["haxe"]);
            var output = process.stdout.readAll().toString();
            process.close();
            var lines = output.split("\n");
            if (lines.length > 0 && lines[0] != "") {
                var haxePath = StringTools.trim(lines[0]);
                var lastSlash = haxePath.lastIndexOf("\\");
                if (lastSlash != -1) {
                    return haxePath.substr(0, lastSlash);
                }
            }
        } catch (e:Dynamic) {}
        
        var commonPaths = [
            "C:\\HaxeToolkit\\haxe",
            "C:\\Program Files\\Haxe",
            "C:\\haxe"
        ];
        
        for (p in commonPaths) {
            if (FileSystem.exists(p + "\\haxe.exe")) {
                return p;
            }
        }
        
        return "";
    }
    
    function getNekoPath():String {
        var nekoCmd = "neko";
        
        var result = Sys.command(nekoCmd + " -version 2> nul");
        if (result == 0) {
            return nekoCmd;
        }
        
        var commonPaths = [
            "C:\\HaxeToolkit\\neko",
            "C:\\Program Files\\Neko",
        ];
        
        for (p in commonPaths) {
            var nekoExe = p + "\\neko.exe";
            if (FileSystem.exists(nekoExe)) {
                return nekoExe;
            }
        }
        
        return "neko";
    }
    
    function printManualInstructions() {
        Console.println("");
        Console.println("Manual installation instructions:", ConsoleColor.YELLOW);
        Console.println("");
        
        Console.println("1. Run this command to find beap path:", ConsoleColor.WHITE);
        Console.println("   haxelib path beap", ConsoleColor.CYAN);
        Console.println("");
        Console.println("2. Create a file called 'beap.cmd' in your Haxe directory", ConsoleColor.WHITE);
        Console.println("3. Add this content (replace PATH with the actual path):", ConsoleColor.WHITE);
        Console.println("   @echo off", ConsoleColor.CYAN);
        Console.println("   set BEAP_HOME=PATH_FROM_ABOVE", ConsoleColor.CYAN);
        Console.println("   neko \"%BEAP_HOME%/bin/run.n\" %*", ConsoleColor.CYAN);
        Console.println("");
        Console.println("4. Make sure the Haxe directory is in your PATH", ConsoleColor.WHITE);
    }
}