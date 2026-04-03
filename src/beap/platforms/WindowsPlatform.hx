package beap.platforms;

import beap.Config;
import beap.Console;
import beap.Lang;
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
        return Sys.command("haxe -version > nul 2>&1") == 0;
    }
    
    public function build(config:Config):Bool {
        Console.println(Lang.get("build_windows"), ConsoleColor.BOLD);
        
        var hxmlContent = getBuildHxml(config);
        File.saveContent("build-windows.hxml", hxmlContent);
        
        Console.info(Lang.get("compile_haxe"));
        var exitCode = Sys.command("haxe", ["build-windows.hxml"]);
        if (exitCode != 0) {
            Console.error(Lang.get("build_failed"));
            return false;
        }
        
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
        var compileCmd = buildCompileCommand(config, hlDir);
        executeWithVCVars(vsInfo, compileCmd);
        
        return moveOutputFiles(config);
    }
    
    public function run(config:Config):Void {
        var exePath = 'build/${config.projectName}.exe';
        if (FileSystem.exists(exePath)) {
            Console.success(Lang.get("running", [config.projectName]));
            Sys.command('start "" "' + exePath + '"');
        } else {
            Console.error(Lang.get("exe_not_found"));
        }
    }
    
    function getBuildHxml(config:Config):String {
        if (FileSystem.exists("build-windows.hxml")) {
            Console.info(Lang.get("using_user_config"));
            try {
                return File.getContent("build-windows.hxml");
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
-hl out/${config.projectName}.c
';
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
                    "-latest", "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
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
    
    function getHashLinkDir():String {
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
        
        var commonPaths = [
            "C:\\HaxeToolkit\\hl",
            "C:\\hashlink",
            Sys.getEnv("HASHLINK_PATH")
        ];
        
        for (p in commonPaths) {
            if (p != null && FileSystem.exists(p) && FileSystem.exists(p + "\\hl.exe")) {
                Console.info("HashLink found at: " + p);
                return p;
            }
        }
        return "";
    }
    
    function buildCompileCommand(config:Config, hlDir:String):String {
        var cFile = 'out/${config.projectName}.c';
        var exeFile = 'build/${config.projectName}.exe';
        
        var currentDir = StringTools.replace(Sys.getCwd(), "\\", "/");
        if (StringTools.endsWith(currentDir, "/")) {
            currentDir = currentDir.substr(0, currentDir.length - 1);
        }
        
        var hlDirFixed = StringTools.replace(hlDir, "\\", "/");
        if (StringTools.endsWith(hlDirFixed, "/")) {
            hlDirFixed = hlDirFixed.substr(0, hlDirFixed.length - 1);
        }
        
        var includeArgs = ' /I "$hlDirFixed/include" /I "$currentDir/out"';
        var libPath = hlDirFixed;
        
        var libFiles = ["libhl.lib", "directx.lib", "ui.lib", "fmt.lib", "uv.lib"];
        var libArgs = "";
        for (lib in libFiles) {
            var fullPath = libPath + "/" + lib;
            if (FileSystem.exists(fullPath)) {
                libArgs += ' "$fullPath"';
            }
        }
        
        var subsystem = config.isTestMode ? "/SUBSYSTEM:CONSOLE" : "/SUBSYSTEM:WINDOWS";
        return 'cl "$cFile"' + includeArgs + ' /link' + libArgs + 
               ' user32.lib opengl32.lib gdi32.lib shell32.lib d3d11.lib dxgi.lib d3dcompiler.lib ' + 
               subsystem + ' /Fe:"$exeFile" /nologo';
    }
    
    function executeWithVCVars(vsInfo:{name:String, vcvars:String, version:Int}, command:String):Void {
        var batchContent = '@echo off\n';
        batchContent += 'call "' + vsInfo.vcvars + '" > nul\n';
        batchContent += command + '\n';
        batchContent += 'if %errorlevel% neq 0 exit %errorlevel%\n';
        
        var batchFile = Sys.getCwd() + "/__build_temp.bat";
        File.saveContent(batchFile, batchContent);
        
        Console.println("Running: " + command, ConsoleColor.CYAN);
        var exitCode = Sys.command('cmd', ['/c', batchFile]);
        
        try {
            FileSystem.deleteFile(batchFile);
        } catch (e:Dynamic) {}
        
        if (exitCode != 0) {
            Console.error(Lang.get("compilation_failed", [Std.string(exitCode)]));
            Sys.exit(exitCode);
        }
    }
    
    function moveOutputFiles(config:Config):Bool {
        var rootExe = '${config.projectName}.exe';
        var rootObj = '${config.projectName}.obj';
        var buildExe = 'build/${config.projectName}.exe';
        var buildObj = 'build/${config.projectName}.obj';
        
        if (FileSystem.exists(rootExe)) {
            if (FileSystem.exists(buildExe)) FileSystem.deleteFile(buildExe);
            FileSystem.rename(rootExe, buildExe);
            Console.success(Lang.get("build_success", [buildExe]));
            return true;
        } else if (FileSystem.exists(buildExe)) {
            Console.success(Lang.get("build_success", [buildExe]));
            return true;
        } else {
            Console.error(Lang.get("no_exe_generated"));
            return false;
        }
        
        if (FileSystem.exists(rootObj)) {
            if (FileSystem.exists(buildObj)) FileSystem.deleteFile(buildObj);
            FileSystem.rename(rootObj, buildObj);
        }
    }
}