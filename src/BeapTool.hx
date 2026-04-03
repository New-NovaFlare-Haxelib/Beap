import sys.io.Process;
import StringTools;
import sys.FileSystem;
import haxe.io.Path;

// 控制台颜色代码
enum ConsoleColor {
    RESET;
    RED;
    GREEN;
    YELLOW;
    BLUE;
    MAGENTA;
    CYAN;
    WHITE;
    BOLD;
}

class BeapTool {
    static var projectName:String = "MyGame";
    static var beapPath:String = "";
    static var projectDir:String = "";
    static var _isTestMode:Bool = false;
    static var runningProcess:Process = null;
    static var supportsColor:Bool = true;
    
    public static function main() {
        projectDir = Sys.getCwd();
        
        var args = Sys.args();
        if (args.length > 0) {
            var lastArg = args[args.length - 1];
            if (lastArg.indexOf("/") != -1 || lastArg.indexOf("\\") != -1) {
                if (FileSystem.exists(lastArg) && FileSystem.isDirectory(lastArg)) {
                    projectDir = lastArg;
                }
            }
        }
        
        Sys.setCwd(projectDir);
        
        checkColorSupport();
        setConsoleUTF8IfNeeded();
        Lang.init();
        getBeapPath();
        
        var cleanArgs = cleanHaxelibArgs(args);
        
        if (cleanArgs.length == 0) {
            printHelp();
            return;
        }
        
        var command = cleanArgs[0];
        var target = cleanArgs.length > 1 ? cleanArgs[1] : "";
        
        switch (command) {
            case "build":
                if (target == "") {
                    printBuildHelp();
                } else {
                    loadConfig();
                    stopRunningGame();
                    buildTarget(target);
                }
                
            case "test":
                if (target == "") {
                    println("Usage: beap test <target>", RED);
                } else {
                    loadConfig();
                    stopRunningGame();
                    _isTestMode = true;
                    buildTarget(target);
                    runTarget(target);
                    _isTestMode = false;
                }
            case "lang":
                if (target == "en") {
                    Lang.setLang("en");
                    println(Lang.get("lang_switched"), GREEN);
                } else if (target == "zh") {
                    Lang.setLang("zh");
                    Sys.command("chcp 65001 > nul");
                    println(Lang.get("lang_switched"), GREEN);
                } else if (target == "") {
                    var current = Lang.getLang();
                    if (current == "en") {
                        println("Current language: English", CYAN);
                    } else {
                        println("当前语言: 中文", CYAN);
                    }
                    println("");
                    println("Usage: beap lang [en/zh]", YELLOW);
                    println("  en  - Switch to English", WHITE);
                    println("  zh  - Switch to Chinese", WHITE);
                } else {
                    println(Lang.get("unknown_lang", [target]), RED);
                }
                
            case "stop":
                stopRunningGame();
                
            case "help", "-h", "--help":
                printHelp();
                
            default:
                println(Lang.get("unknown_cmd", [command]), RED);
                printHelp();
        }
    }

    // 检查是否支持颜色
    static function checkColorSupport() {
        #if windows
        // Windows 10+ 支持 ANSI 颜色
        var version = Sys.command('ver');
        supportsColor = true;
        #else
        // Linux/Mac 通常支持
        supportsColor = true;
        #end
    }

    // 获取颜色代码
    static function getColorCode(color:ConsoleColor):String {
        if (!supportsColor) return "";
        
        return switch (color) {
            case RESET: "\x1b[0m";
            case RED: "\x1b[31m";
            case GREEN: "\x1b[32m";
            case YELLOW: "\x1b[33m";
            case BLUE: "\x1b[34m";
            case MAGENTA: "\x1b[35m";
            case CYAN: "\x1b[36m";
            case WHITE: "\x1b[37m";
            case BOLD: "\x1b[1m";
        }
    }
    
    // 带颜色的打印
    static function println(text:String, color:ConsoleColor = WHITE) {
        Sys.println(getColorCode(color) + text + getColorCode(RESET));
    }
    
    // 不带换行的打印
    static function print(text:String, color:ConsoleColor = WHITE) {
        Sys.print(getColorCode(color) + text + getColorCode(RESET));
    }
    
    // 成功消息
    static function printSuccess(text:String) {
        println("[✓] " + text, GREEN);
    }
    
    // 错误消息
    static function printError(text:String) {
        println("[✗] " + text, RED);
    }
    
    // 警告消息
    static function printWarning(text:String) {
        println("[!] " + text, YELLOW);
    }
    
    // 信息消息
    static function printInfo(text:String) {
        println("[i] " + text, CYAN);
    }
    
    static function setConsoleUTF8IfNeeded() {
        var currentCodePage = getCurrentCodePage();
        if (currentCodePage != 65001) {
            Sys.command("chcp 65001 > nul");
        }
    }

    static function getCurrentCodePage():Int {
        try {
            var process = new Process("chcp", []);
            var output = process.stdout.readAll().toString();
            process.close();
            
            var regex = ~/Active code page: (\d+)/;
            if (regex.match(output)) {
                return Std.parseInt(regex.matched(1));
            }
        } catch (e:Dynamic) {}
        return 0;
    }
    
    static function cleanHaxelibArgs(args:Array<String>):Array<String> {
        var result = [];
        for (arg in args) {
            if (arg.indexOf("/") != -1 || arg.indexOf("\\") != -1) {
                if (arg == "." || arg == "./" || arg == ".\\") {
                    continue;
                }
                if (arg.indexOf(":") != -1) {
                    continue;
                }
            }
            if (StringTools.trim(arg) == "") {
                continue;
            }
            result.push(arg);
        }
        return result;
    }
    
    static function printBuildHelp() {
        println(Lang.get("need_target"), YELLOW);
        println("");
        println(Lang.get("targets"), BOLD);
        println("  " + Lang.get("target_hl"), GREEN);
        println("  " + Lang.get("target_windows"), GREEN);
    }
    
    static function checkEnvironment():Bool {
        printInfo(Lang.get("checking_env"));
        
        var haxeOk = Sys.command("haxe -version > nul 2>&1") == 0;
        if (!haxeOk) {
            printError(Lang.get("haxe_not_found"));
            return false;
        }
        
        printSuccess(Lang.get("env_ok"));
        return true;
    }
    
    static function getBeapPath() {
        #if neko
        var path = Sys.getCwd() + "/" + Sys.programPath();
        beapPath = StringTools.replace(path, "beap.n", "");
        #else
        beapPath = Sys.getCwd() + "/";
        #end
    }
    
    static function buildTarget(target:String) {
        Sys.setCwd(projectDir);
        
        if (!FileSystem.exists("src/Main.hx")) {
            printError("src/Main.hx not found!");
            println("Project directory: " + projectDir, CYAN);
            println("");
            println("Please make sure you are in your Heaps project directory.", YELLOW);
            println("Or run 'beap init' to create a new project.", YELLOW);
            Sys.exit(1);
        }
        
        loadConfig();
        
        switch (target) {
            case "hl":
                buildHashLink();
            case "windows":
                buildWindows();
            case "linux", "mac", "android", "ios", "html5":
                printInfo(Lang.get("build_" + target));
                println("Coming soon...", YELLOW);
            default:
                printError(Lang.get("unknown_target", [target]));
        }
    }
    
    static function runTarget(target:String) {
        Sys.setCwd(projectDir);
        
        switch (target) {
            case "hl":
                runHashLink();
            case "windows":
                runWindows();
            default:
                printError(Lang.get("unknown_target", [target]));
        }
    }
    
    static function getBuildHxml():String {
        var userHxmlPath = "build.hxml";
        
        if (FileSystem.exists(userHxmlPath)) {
            printInfo("Using user's build.hxml");
            try {
                return sys.io.File.getContent(userHxmlPath);
            } catch (e:Dynamic) {
                printWarning("Failed to read build.hxml, using default.");
            }
        }
        
        printInfo("Using default build configuration");
        return '
-cp src
-main Main
-lib heaps
-lib format
-lib hldx
-D windowTitle=$projectName
-D windowSize=1280x720
-D debug
-hl build/$projectName.hl
';
    }
    
    static function getWindowsBuildHxml():String {
        var userHxmlPath = "build-windows.hxml";
        
        if (FileSystem.exists(userHxmlPath)) {
            printInfo(Lang.get("using_user_config"));
            try {
                return sys.io.File.getContent(userHxmlPath);
            } catch (e:Dynamic) {
                printWarning(Lang.get("config_read_error"));
            }
        }
        
        printInfo(Lang.get("using_default_config"));
        return '
-cp src
-main Main
-lib heaps
-lib format
-lib hldx
-D windowTitle=$projectName
-D windowSize=1280x720
-D windowResizable
-hl out/$projectName.c
    ';
    }
    
    static function buildHashLink() {
        println(Lang.get("build_hl"), BOLD);
        
        createDir("build");
        loadConfig();
        
        var hxmlContent = getBuildHxml();
        sys.io.File.saveContent("build.hxml", hxmlContent);
        
        printInfo(Lang.get("compile_hl"));
        var exitCode = Sys.command("haxe", ["build.hxml"]);
        
        if (exitCode != 0) {
            printError(Lang.get("build_failed"));
            Sys.exit(1);
        }
        
        printSuccess(Lang.get("build_success", ["build/" + projectName + ".hl"]));
    }
    
    static function runHashLink() {
        var hlFile = 'build/$projectName.hl';
        
        if (!FileSystem.exists(hlFile)) {
            printError(Lang.get("hl_file_not_found"));
            return;
        }
        
        printSuccess(Lang.get("running", [projectName]));
        #if windows
        Sys.command('start "" hl "$hlFile"');
        #else
        Sys.command('hl $hlFile');
        #end
    }
    
    static function buildWindows() {
        println(Lang.get("build_windows"), BOLD);
        
        createDir("build");
        createDir("out");
        loadConfig();
        
        var hxmlContent = getWindowsBuildHxml();
        sys.io.File.saveContent("build-windows.hxml", hxmlContent);
        
        printInfo(Lang.get("compile_haxe"));
        var exitCode = Sys.command("haxe", ["build-windows.hxml"]);
        if (exitCode != 0) {
            printError(Lang.get("build_failed"));
            Sys.exit(1);
        }
        
        var vsInfo = findVisualStudio();
        if (vsInfo == null) {
            printError("Visual Studio not found!");
            return;
        }
        
        printSuccess("Found: " + vsInfo.name);
        
        var hlDir = getHashLinkDir();
        if (hlDir == "") {
            printError(Lang.get("hl_not_found"));
            return;
        }
        
        printInfo("Compiling to EXE...");
        var compileCmd = buildCompileCommand(vsInfo, hlDir, _isTestMode);
        executeWithVCVars(vsInfo, compileCmd);
        
        var rootExe = '$projectName.exe';
        var rootObj = '$projectName.obj';
        var buildExe = 'build/$projectName.exe';
        var buildObj = 'build/$projectName.obj';
        
        if (FileSystem.exists(rootExe)) {
            if (FileSystem.exists(buildExe)) {
                FileSystem.deleteFile(buildExe);
            }
            FileSystem.rename(rootExe, buildExe);
            printSuccess(Lang.get("build_success", [buildExe]));
        } else if (FileSystem.exists(buildExe)) {
            printSuccess(Lang.get("build_success", [buildExe]));
        } else {
            printError("Build failed! No EXE generated.");
            return;
        }
        
        if (FileSystem.exists(rootObj)) {
            if (FileSystem.exists(buildObj)) {
                FileSystem.deleteFile(buildObj);
            }
            FileSystem.rename(rootObj, buildObj);
        }
    }
    
    static function runWindows() {
        var exePath = 'build/' + projectName + '.exe';
        if (FileSystem.exists(exePath)) {
            printSuccess(Lang.get("running", [projectName]));
            Sys.command('start "" "' + exePath + '"');
        } else {
            printError(Lang.get("exe_not_found"));
        }
    }
    
    static function findVisualStudio():{name:String, vcvars:String, version:Int} {
        var vswherePaths = [
            "C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe",
            "C:\\Program Files\\Microsoft Visual Studio\\Installer\\vswhere.exe"
        ];
        
        var vswhere = "";
        for (p in vswherePaths) {
            if (FileSystem.exists(p)) {
                vswhere = p;
                break;
            }
        }
        
        if (vswhere != "") {
            try {
                var process = new Process(vswhere, [
                    "-latest",
                    "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
                    "-property", "installationPath"
                ]);
                var vsPath = StringTools.trim(process.stdout.readAll().toString());
                process.close();
                
                if (vsPath != "" && FileSystem.exists(vsPath)) {
                    var vcvars = vsPath + "\\VC\\Auxiliary\\Build\\vcvars64.bat";
                    if (!FileSystem.exists(vcvars)) {
                        vcvars = vsPath + "\\VC\\Auxiliary\\Build\\vcvarsall.bat";
                    }
                    if (FileSystem.exists(vcvars)) {
                        return {name: "Visual Studio", vcvars: vcvars, version: 2022};
                    }
                }
            } catch (e:Dynamic) {}
        }
        
        return null;
    }
    
    static function buildCompileCommand(vsInfo:{name:String, vcvars:String, version:Int}, hlDir:String, forTest:Bool = false):String {
        var cFile = 'out/' + projectName + '.c';
        var exeFile = 'build/' + projectName + '.exe';
        
        var currentDir = StringTools.replace(Sys.getCwd(), "\\", "/");
        if (StringTools.endsWith(currentDir, "/")) {
            currentDir = currentDir.substr(0, currentDir.length - 1);
        }
        
        var hlDirFixed = StringTools.replace(hlDir, "\\", "/");
        if (StringTools.endsWith(hlDirFixed, "/")) {
            hlDirFixed = hlDirFixed.substr(0, hlDirFixed.length - 1);
        }
        
        var includePaths = [
            hlDirFixed + "/include",
            currentDir + "/out"
        ];
        
        var libPath = hlDirFixed;
        
        var includeArgs = "";
        for (path in includePaths) {
            if (FileSystem.exists(path)) {
                includeArgs += ' /I "' + path + '"';
            }
        }
        
        var libFiles = ["libhl.lib", "directx.lib", "ui.lib", "fmt.lib", "uv.lib"];
        var libArgs = "";
        for (lib in libFiles) {
            var fullPath = libPath + "/" + lib;
            if (FileSystem.exists(fullPath)) {
                libArgs += ' "' + fullPath + '"';
            } else {
                printWarning(lib + " not found at " + fullPath);
            }
        }
        
        var subsystem = forTest ? "/SUBSYSTEM:CONSOLE" : "/SUBSYSTEM:WINDOWS";
        var cmd = 'cl "' + cFile + '"' + includeArgs + ' /link' + libArgs + ' user32.lib opengl32.lib gdi32.lib shell32.lib d3d11.lib dxgi.lib d3dcompiler.lib ' + subsystem + ' /Fe:"' + exeFile + '" /nologo';
        
        return cmd;
    }
    
    static function executeWithVCVars(vsInfo:{name:String, vcvars:String, version:Int}, command:String) {
        var batchContent = '@echo off\n';
        batchContent += 'call "' + vsInfo.vcvars + '" > nul\n';
        batchContent += command + '\n';
        batchContent += 'if %errorlevel% neq 0 exit %errorlevel%\n';
        
        var batchFile = Sys.getCwd() + "/__build_temp.bat";
        sys.io.File.saveContent(batchFile, batchContent);
        
        println("Running: " + command, CYAN);
        var exitCode = Sys.command('cmd', ['/c', batchFile]);
        
        try {
            FileSystem.deleteFile(batchFile);
        } catch (e:Dynamic) {}
        
        if (exitCode != 0) {
            printError("Compilation failed with code: " + exitCode);
            Sys.exit(exitCode);
        }
    }
    
    static function getHashLinkDir():String {
        var result = Sys.command("where hl > nul 2>&1");
        if (result == 0) {
            try {
                var process = new Process("where", ["hl"]);
                var hlPath = StringTools.trim(process.stdout.readAll().toString());
                process.close();
                printInfo("hl found at: " + hlPath);
                return Path.directory(hlPath);
            } catch (e:Dynamic) {}
        }
        
        var commonPaths = [
            "C:\\HaxeToolkit\\hl",
            "C:\\hashlink",
            "D:\\NewProject\\hashlink-9d827bf-win64",
            Sys.getEnv("HASHLINK_PATH")
        ];
        
        for (p in commonPaths) {
            if (p != null && FileSystem.exists(p) && FileSystem.exists(p + "\\hl.exe")) {
                printInfo("HashLink found at: " + p);
                return p;
            }
        }
        
        return "";
    }
    
    static function loadConfig() {
        if (sys.FileSystem.exists(".beap")) {
            try {
                var content = sys.io.File.getContent(".beap");
                var lines = content.split("\n");
                for (line in lines) {
                    var trimmed = StringTools.trim(line);
                    if (StringTools.startsWith(trimmed, "name=")) {
                        projectName = StringTools.trim(trimmed.substr(5));
                    }
                }
            } catch (e:Dynamic) {}
        }
    }
    
    static function createDir(path:String) {
        if (!FileSystem.exists(path)) {
            FileSystem.createDirectory(path);
        }
    }
    
static function printHelp() {
    println("");
    println("beap - Heaps Build Tool", BOLD);
    println("");
    
    println(Lang.get("commands"), YELLOW);
    println("  " + Lang.get("cmd_build"), GREEN);
    println("  " + Lang.get("cmd_test"), GREEN);
    println("  " + Lang.get("cmd_stop"), GREEN);
    println("  " + Lang.get("cmd_lang"), GREEN);
    println("  " + Lang.get("cmd_help"), GREEN);
    println("");
    
    println(Lang.get("targets"), YELLOW);
    println("  " + Lang.get("target_hl"), WHITE);
    println("  " + Lang.get("target_windows"), WHITE);
    println("  " + Lang.get("target_linux"), WHITE);
    println("  " + Lang.get("target_mac"), WHITE);
    println("  " + Lang.get("target_android"), WHITE);
    println("  " + Lang.get("target_ios"), WHITE);
    println("  " + Lang.get("target_html5"), WHITE);
    println("");
    
    println(Lang.get("examples"), YELLOW);
    println("  " + Lang.get("ex_build_hl"), CYAN);
    println("  " + Lang.get("ex_build_windows"), CYAN);
    println("");
}

    static function stopRunningGame() {
        var result = Sys.command('taskkill /f /im "$projectName.exe" 2>nul');
        if (result == 0) {
            printSuccess(Lang.get("stop_success"));
        }
    }
}