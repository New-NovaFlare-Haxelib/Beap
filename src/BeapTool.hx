import sys.io.Process;
import StringTools;
import sys.FileSystem;
import haxe.io.Path;

class BeapTool {
    static var projectName:String = "MyGame";
    static var beapPath:String = "";
    static var projectDir:String = "";
    static var _isTestMode:Bool = false;
    static var runningProcess:Process = null;  // 用于跟踪运行中的进程
    
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
                    Sys.println("Usage: beap test <target>");
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
                    Sys.println(Lang.get("lang_switched"));
                } else if (target == "zh") {
                    Lang.setLang("zh");
                    Sys.command("chcp 65001 > nul");
                    Sys.println(Lang.get("lang_switched"));
                } else if (target == "") {
                    var current = Lang.getLang();
                    if (current == "en") {
                        Sys.println("Current language: English");
                    } else {
                        Sys.println("当前语言: 中文");
                    }
                    Sys.println("");
                    Sys.println("Usage: beap lang [en/zh]");
                    Sys.println("  en  - Switch to English");
                    Sys.println("  zh  - Switch to Chinese");
                } else {
                    Sys.println(Lang.get("unknown_lang", [target]));
                }
                
            case "stop":
                stopRunningGame();
                
            case "help", "-h", "--help":
                printHelp();
                
            default:
                Sys.println(Lang.get("unknown_cmd", [command]));
                printHelp();
        }
    }
    
    static function stopRunningGame() {
        var result = Sys.command('taskkill /f /im "$projectName.exe" 2>nul');
        if (result == 0) {
            Sys.println("Stopped previous game process.");
        }
        Sys.sleep(0.5);
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
        Sys.println(Lang.get("need_target"));
        Sys.println("");
        Sys.println(Lang.get("targets"));
        Sys.println(Lang.get("target_hl"));
        Sys.println(Lang.get("target_windows"));
    }
    
    static function checkEnvironment():Bool {
        Sys.println(Lang.get("checking_env"));
        
        var haxeOk = Sys.command("haxe -version > nul 2>&1") == 0;
        if (!haxeOk) {
            Sys.println(Lang.get("haxe_not_found"));
            return false;
        }
        
        Sys.println(Lang.get("env_ok"));
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
            Sys.println("Error: src/Main.hx not found!");
            Sys.println("Project directory: " + projectDir);
            Sys.println("");
            Sys.println("Please make sure you are in your Heaps project directory.");
            Sys.println("Or run 'beap init' to create a new project.");
            Sys.exit(1);
        }
        
        loadConfig();
        
        switch (target) {
            case "hl":
                buildHashLink();
            case "windows":
                buildWindows();
            case "linux", "mac", "android", "ios", "html5":
                Sys.println(Lang.get("build_" + target));
                Sys.println("Coming soon...");
            default:
                Sys.println(Lang.get("unknown_target", [target]));
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
                Sys.println(Lang.get("unknown_target", [target]));
        }
    }
    
    // 获取用户自定义的 hxml 内容，如果没有则使用默认
    static function getBuildHxml():String {
        var userHxmlPath = "build.hxml";
        
        // 优先使用用户自己的 build.hxml
        if (FileSystem.exists(userHxmlPath)) {
            Sys.println("Using user's build.hxml");
            try {
                return sys.io.File.getContent(userHxmlPath);
            } catch (e:Dynamic) {
                Sys.println("Warning: Failed to read build.hxml, using default.");
            }
        }
        
        // 使用默认配置
        Sys.println("Using default build configuration");
        return '
-cp src
-main Main
-lib heaps
-lib format
-lib hldx
-D windowTitle="$projectName"
-D windowSize=1280x720
-D debug
-hl build/$projectName.hl
';
    }
    
    // 获取用户自定义的 Windows hxml 内容，如果没有则使用默认
    static function getWindowsBuildHxml():String {
        var userHxmlPath = "build-windows.hxml";
        
        // 优先使用用户自己的 build-windows.hxml
        if (FileSystem.exists(userHxmlPath)) {
            Sys.println("Using user's build-windows.hxml");
            try {
                return sys.io.File.getContent(userHxmlPath);
            } catch (e:Dynamic) {
                Sys.println("Warning: Failed to read build-windows.hxml, using default.");
            }
        }
        
        // 使用默认配置
        Sys.println("Using default Windows build configuration");
        return '
-cp src
-main Main
-lib heaps
-lib format
-lib hldx
-D windowTitle="$projectName"
-D windowSize=1280x720
-D windowResizable
-hl out/$projectName.c
';
    }
    
    static function buildHashLink() {
        Sys.println(Lang.get("build_hl"));
        
        createDir("build");
        loadConfig();
        
        var hxmlContent = getBuildHxml();
        sys.io.File.saveContent("build.hxml", hxmlContent);
        
        Sys.println(Lang.get("compile_hl"));
        var exitCode = Sys.command("haxe", ["build.hxml"]);
        
        if (exitCode != 0) {
            Sys.println(Lang.get("build_failed"));
            Sys.exit(1);
        }
        
        Sys.println(Lang.get("build_success", ["build/" + projectName + ".hl"]));
    }
    
    static function runHashLink() {
        var hlFile = 'build/$projectName.hl';
        
        if (!FileSystem.exists(hlFile)) {
            Sys.println(Lang.get("hl_file_not_found"));
            return;
        }
        
        Sys.println(Lang.get("running", [projectName]));
        #if windows
        Sys.command('start "" hl "$hlFile"');
        #else
        Sys.command('hl $hlFile');
        #end
    }
    
    static function buildWindows() {
        Sys.println(Lang.get("build_windows"));
        
        createDir("build");
        createDir("out");
        loadConfig();
        
        var hxmlContent = getWindowsBuildHxml();
        sys.io.File.saveContent("build-windows.hxml", hxmlContent);
        
        Sys.println(Lang.get("compile_haxe"));
        var exitCode = Sys.command("haxe", ["build-windows.hxml"]);
        if (exitCode != 0) {
            Sys.println(Lang.get("build_failed"));
            Sys.exit(1);
        }
        
        var vsInfo = findVisualStudio();
        if (vsInfo == null) {
            Sys.println("Error: Visual Studio not found!");
            return;
        }
        
        Sys.println("Found: " + vsInfo.name);
        
        var hlDir = getHashLinkDir();
        if (hlDir == "") {
            Sys.println(Lang.get("hl_not_found"));
            return;
        }
        
        Sys.println("Compiling to EXE...");
        var compileCmd = buildCompileCommand(vsInfo, hlDir, _isTestMode);
        executeWithVCVars(vsInfo, compileCmd);
        
        // 移动生成的文件到 build 目录
        var rootExe = '$projectName.exe';
        var rootObj = '$projectName.obj';
        var buildExe = 'build/$projectName.exe';
        var buildObj = 'build/$projectName.obj';
        
        if (FileSystem.exists(rootExe)) {
            if (FileSystem.exists(buildExe)) {
                FileSystem.deleteFile(buildExe);
            }
            FileSystem.rename(rootExe, buildExe);
            Sys.println(Lang.get("build_success", [buildExe]));
        } else if (FileSystem.exists(buildExe)) {
            Sys.println(Lang.get("build_success", [buildExe]));
        } else {
            Sys.println("Build failed! No EXE generated.");
            return;
        }
        
        // 移动 .obj 文件（可选）
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
            Sys.println(Lang.get("running", [projectName]));
            Sys.command('start "" "' + exePath + '"');
        } else {
            Sys.println(Lang.get("exe_not_found"));
        }
    }
    
    // ========== Visual Studio 检测（模仿 Lime）==========
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
                Sys.println("  Warning: " + lib + " not found at " + fullPath);
            }
        }
        
        // 根据 forTest 选择子系统
        var subsystem = forTest ? "/SUBSYSTEM:CONSOLE" : "/SUBSYSTEM:WINDOWS";
        
        var cmd = 'cl "' + cFile + '"' + includeArgs + ' /link' + libArgs + ' user32.lib opengl32.lib gdi32.lib shell32.lib d3d11.lib dxgi.lib d3dcompiler.lib ' + subsystem + ' /Fe:"' + exeFile + '" /nologo';
        
        return cmd;
    }
    
    static function executeWithVCVars(vsInfo:{name:String, vcvars:String, version:Int}, command:String) {
        // 创建临时批处理文件
        var batchContent = '@echo off\n';
        batchContent += 'call "' + vsInfo.vcvars + '" > nul\n';
        batchContent += command + '\n';
        batchContent += 'if %errorlevel% neq 0 exit %errorlevel%\n';
        
        var batchFile = Sys.getCwd() + "/__build_temp.bat";
        sys.io.File.saveContent(batchFile, batchContent);
        
        Sys.println("Running: " + command);
        var exitCode = Sys.command('cmd', ['/c', batchFile]);
        
        try {
            FileSystem.deleteFile(batchFile);
        } catch (e:Dynamic) {}
        
        if (exitCode != 0) {
            Sys.println("Compilation failed with code: " + exitCode);
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
                Sys.println("hl found at: " + hlPath);
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
                Sys.println("HashLink found at: " + p);
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
        Sys.println("");
        Sys.println("beap - Heaps Build Tool");
        Sys.println("");
        Sys.println("Usage: beap <command> [target]");
        Sys.println("");
        Sys.println("Commands:");
        Sys.println("  build <target>    Build for specific platform");
        Sys.println("  test <target>     Build and run for specific platform");
        Sys.println("  stop              Stop running game");
        Sys.println("  lang [en/zh]      Set language for beap");
        Sys.println("  help              Show this help");
        Sys.println("");
        Sys.println(Lang.get("targets"));
        Sys.println(Lang.get("target_hl"));
        Sys.println(Lang.get("target_windows"));
        Sys.println(Lang.get("target_linux"));
        Sys.println(Lang.get("target_mac"));
        Sys.println(Lang.get("target_android"));
        Sys.println(Lang.get("target_ios"));
        Sys.println(Lang.get("target_html5"));
        Sys.println("");
        Sys.println(Lang.get("examples"));
        Sys.println(Lang.get("ex_build_hl"));
        Sys.println(Lang.get("ex_build_windows"));
        Sys.println("");
    }
}