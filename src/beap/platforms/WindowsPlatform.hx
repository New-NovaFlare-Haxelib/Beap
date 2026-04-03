package beap.platforms;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.utils.PlatformUtils;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;

class WindowsPlatform implements Platform {
    public function new() {}
    
    public function getName():String return "windows";
    
    public function getDescription():String {
        return "Windows executable (.exe)";
    }
    
    public function isAvailable():Bool {
        if (!PlatformUtils.isWindows()) return false;
        return Sys.command("haxe -version > nul 2>&1") == 0;
    }
    
    public function build(config:Config):Bool {
        Console.println(Lang.get("build_windows"), ConsoleColor.BOLD);
        
        var platform = getName();
        config.ensureDirectories(platform);
        
        // 使用 config.projectName
        Console.info("Project name: " + config.projectName);
        
        var hxmlContent = getBuildHxml(config, platform);
        var hxmlPath = config.getBuildDir(platform) + "/build-windows.hxml";
        File.saveContent(hxmlPath, hxmlContent);
        
        Console.info(Lang.get("compile_haxe"));
        var exitCode = Sys.command("haxe", [hxmlPath]);
        if (exitCode != 0) {
            Console.error(Lang.get("build_failed"));
            return false;
        }
        
        // 查找 C 文件 - 使用 config.projectName
        var cFile = findCFile(config, platform);
        if (cFile == "") {
            Console.error("C file not generated!");
            return false;
        }
        
        Console.info("Using C file: " + cFile);
        
        var vsInfo = findVisualStudio();
        if (vsInfo == null) {
            Console.error(Lang.get("vs_not_found"));
            return false;
        }
        
        Console.success(Lang.get("vs_found", [vsInfo.name]));
        
        var hlDir = getHashLinkDir();
        if (hlDir == "") {
            Console.error(Lang.get("hl_not_found"));
            return false;
        }
        
        Console.info(Lang.get("compiling_exe"));
        var compileCmd = buildCompileCommand(config, platform, hlDir, cFile);
        if (compileCmd == "") {
            return false;
        }
        
        executeWithVCVars(vsInfo, compileCmd);
        
        return moveOutputFiles(config, platform);
    }
    
    public function run(config:Config):Void {
        if (!PlatformUtils.isWindows()) {
            Console.error("Cannot run Windows executable on this platform!");
            return;
        }
        
        var platform = getName();
        var exePath = config.getOutputPath(platform, ".exe");
        
        // 检查多个可能的位置
        var possiblePaths = [
            exePath,
            "build/" + config.projectName + ".exe",
            config.projectName + ".exe"
        ];
        
        var foundPath = "";
        for (path in possiblePaths) {
            if (FileSystem.exists(path)) {
                foundPath = path;
                break;
            }
        }
        
        if (foundPath == "") {
            Console.error(Lang.get("exe_not_found"));
            Console.info("Try running: beap build windows first");
            return;
        }
        
        Console.success(Lang.get("running", [config.projectName]));
        Sys.command('start "" "' + foundPath + '"');
    }
    
    function findCFile(config:Config, platform:String):String {
        var outDir = config.getOutDir(platform);
        var expectedPath = outDir + "/" + config.projectName + ".c";
        var rootPath = config.projectName + ".c";
        
        Console.info("Looking for C file: " + expectedPath);
        
        if (FileSystem.exists(expectedPath)) {
            return expectedPath;
        }
        
        if (FileSystem.exists(rootPath)) {
            Console.info("Found C file at root: " + rootPath);
            if (!FileSystem.exists(outDir)) {
                FileSystem.createDirectory(outDir);
            }
            FileSystem.rename(rootPath, expectedPath);
            return expectedPath;
        }

        var files = FileSystem.readDirectory(".");
        for (file in files) {
            if (StringTools.endsWith(file, ".c")) {
                Console.info("Found C file: " + file);
                if (!FileSystem.exists(outDir)) {
                    FileSystem.createDirectory(outDir);
                }
                var newPath = expectedPath;
                if (FileSystem.exists(newPath)) {
                    FileSystem.deleteFile(newPath);
                }
                FileSystem.rename(file, newPath);
                return newPath;
            }
        }
        
        if (FileSystem.exists(outDir)) {
            var outFiles = FileSystem.readDirectory(outDir);
            for (file in outFiles) {
                if (StringTools.endsWith(file, ".c")) {
                    var fullPath = outDir + "/" + file;
                    Console.info("Found C file in out dir: " + fullPath);
                    if (fullPath != expectedPath) {
                        if (FileSystem.exists(expectedPath)) {
                            FileSystem.deleteFile(expectedPath);
                        }
                        FileSystem.rename(fullPath, expectedPath);
                    }
                    return expectedPath;
                }
            }
        }
        
        return "";
    }
    
    function getBuildHxml(config:Config, platform:String):String {
        var outDir = config.getOutDir(platform);
        var cFile = outDir + "/" + config.projectName + ".c";
        
        if (FileSystem.exists("build-windows.hxml")) {
            Console.info(Lang.get("using_user_config"));
            try {
                var content = File.getContent("build-windows.hxml");
                // 确保输出路径正确
                if (content.indexOf("-hl") == -1) {
                    content += '\n-hl $cFile';
                }
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
-D windowTitle=${config.projectName}
-D windowSize=1280x720
-D windowResizable
-hl $cFile
';
    }
    
    function buildCompileCommand(config:Config, platform:String, hlDir:String, cFile:String):String {
        var buildDir = config.getBuildDir(platform);
        var exeFile = buildDir + "/" + config.projectName + ".exe";
        var objFile = buildDir + "/" + config.projectName + ".obj";
        
        // 确保 C 文件存在
        if (!FileSystem.exists(cFile)) {
            Console.error("C file not found: " + cFile);
            return "";
        }
        
        var currentDir = StringTools.replace(Sys.getCwd(), "\\", "/");
        if (StringTools.endsWith(currentDir, "/")) {
            currentDir = currentDir.substr(0, currentDir.length - 1);
        }
        
        var hlDirFixed = StringTools.replace(hlDir, "\\", "/");
        if (StringTools.endsWith(hlDirFixed, "/")) {
            hlDirFixed = hlDirFixed.substr(0, hlDirFixed.length - 1);
        }
        
        // 获取 C 文件所在目录
        var cFileDir = Path.directory(cFile);
        var includeArgs = ' /I "' + hlDirFixed + '/include" /I "' + currentDir + '/' + cFileDir + '"';
        var libPath = hlDirFixed;
        
        var libFiles = ["libhl.lib", "directx.lib", "ui.lib", "fmt.lib", "uv.lib"];
        var libArgs = "";
        for (lib in libFiles) {
            var fullPath = libPath + "/" + lib;
            if (FileSystem.exists(fullPath)) {
                libArgs += ' "' + fullPath + '"';
            } else {
                Console.warning(lib + " not found at " + fullPath);
            }
        }
        
        var subsystem = config.isTestMode ? "/SUBSYSTEM:CONSOLE" : "/SUBSYSTEM:WINDOWS";
        return 'cl "' + cFile + '"' + includeArgs + ' /link' + libArgs + 
               ' user32.lib opengl32.lib gdi32.lib shell32.lib d3d11.lib dxgi.lib d3dcompiler.lib ' + 
               subsystem + ' /Fe:"' + exeFile + '" /nologo';
    }
    
    function moveOutputFiles(config:Config, platform:String):Bool {
        var buildDir = config.getBuildDir(platform);
        var exeName = config.projectName + '.exe';
        var objName = config.projectName + '.obj';
        var buildExe = buildDir + '/' + exeName;
        var buildObj = buildDir + '/' + objName;
        
        var moved = false;
        
        // 移动 exe 文件
        if (FileSystem.exists(exeName)) {
            if (FileSystem.exists(buildExe)) FileSystem.deleteFile(buildExe);
            FileSystem.rename(exeName, buildExe);
            Console.success(Lang.get("build_success", [buildExe]));
            moved = true;
        } else if (FileSystem.exists(buildExe)) {
            Console.success(Lang.get("build_success", [buildExe]));
            moved = true;
        }
        
        // 移动 obj 文件
        if (FileSystem.exists(objName)) {
            if (FileSystem.exists(buildObj)) FileSystem.deleteFile(buildObj);
            FileSystem.rename(objName, buildObj);
        }
        
        // 移动 pdb 文件（调试符号）
        var pdbName = config.projectName + '.pdb';
        var buildPdb = buildDir + '/' + pdbName;
        if (FileSystem.exists(pdbName)) {
            if (FileSystem.exists(buildPdb)) FileSystem.deleteFile(buildPdb);
            FileSystem.rename(pdbName, buildPdb);
            Console.info("Moved: " + pdbName + " -> " + buildPdb);
        }
        
        // 移动其他 .ilk 文件（增量链接文件）
        var files = FileSystem.readDirectory(".");
        for (file in files) {
            if (StringTools.endsWith(file, ".ilk")) {
                var targetFile = buildDir + '/' + file;
                if (FileSystem.exists(targetFile)) FileSystem.deleteFile(targetFile);
                FileSystem.rename(file, targetFile);
                Console.info("Moved: " + file + " -> " + targetFile);
            }
        }
        
        if (!moved) {
            Console.error(Lang.get("no_exe_generated"));
            return false;
        }
        
        return true;
    }
    
    function findVisualStudio():{name:String, vcvars:String, version:Int} {
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
                var process = new sys.io.Process(vswhere, [
                    "-latest", 
                    "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
                    "-property", "installationPath"
                ]);
                var vsPath = StringTools.trim(process.stdout.readAll().toString());
                process.close();
                
                if (vsPath != "" && FileSystem.exists(vsPath)) {
                    var vcvars64 = vsPath + "\\VC\\Auxiliary\\Build\\vcvars64.bat";
                    var vcvars32 = vsPath + "\\VC\\Auxiliary\\Build\\vcvars32.bat";
                    var vcvarsall = vsPath + "\\VC\\Auxiliary\\Build\\vcvarsall.bat";
                    
                    if (FileSystem.exists(vcvars64)) {
                        return {name: "Visual Studio", vcvars: vcvars64, version: 2022};
                    }
                    if (FileSystem.exists(vcvars32)) {
                        return {name: "Visual Studio", vcvars: vcvars32, version: 2022};
                    }
                    if (FileSystem.exists(vcvarsall)) {
                        return {name: "Visual Studio", vcvars: vcvarsall, version: 2022};
                    }
                }
            } catch (e:Dynamic) {}
        }
        
        // 尝试旧版 Visual Studio
        var oldPaths = [
            "C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat",
            "C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\Professional\\VC\\Auxiliary\\Build\\vcvars64.bat",
            "C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat"
        ];
        
        for (p in oldPaths) {
            if (FileSystem.exists(p)) {
                return {name: "Visual Studio", vcvars: p, version: 2019};
            }
        }
        
        return null;
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
    
    function executeWithVCVars(vsInfo:{name:String, vcvars:String, version:Int}, command:String):Void {
        if (command == "") {
            Console.error("No compilation command to execute!");
            return;
        }
        
        var batchContent = '@echo off\n';
        batchContent += 'echo Setting up Visual Studio environment...\n';
        batchContent += 'call "' + vsInfo.vcvars + '" > nul\n';
        batchContent += 'echo Compiling...\n';
        batchContent += command + '\n';
        batchContent += 'if %errorlevel% neq 0 exit %errorlevel%\n';
        
        var batchFile = Sys.getCwd() + "/__build_temp.bat";
        File.saveContent(batchFile, batchContent);
        
        Console.println("Running compiler...", ConsoleColor.CYAN);
        var exitCode = Sys.command('cmd', ['/c', batchFile]);
        
        try {
            FileSystem.deleteFile(batchFile);
        } catch (e:Dynamic) {}
        
        if (exitCode != 0) {
            Console.error(Lang.get("compilation_failed", [Std.string(exitCode)]));
            Sys.exit(exitCode);
        }
    }
}