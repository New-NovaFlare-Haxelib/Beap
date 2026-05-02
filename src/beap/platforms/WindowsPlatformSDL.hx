package beap.platforms;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.project.ProjectConfig;
import beap.utils.Downloader;
import beap.utils.PlatformUtils;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import sys.io.Process;

/**
 * SDL-aware Windows Platform
 * Supports both SDL2 and SDL3 with automatic binary downloading
 */
class WindowsPlatformSDL implements Platform {
    
    var projectConfig:ProjectConfig;
    
    public function new(config:ProjectConfig) {
        this.projectConfig = config;
    }
    
    public function getName():String return "windows";
    
    public function getDescription():String {
        var sdl = projectConfig.sdlVersion;
        return "Windows executable (.exe, " + sdl + ")";
    }
    
    public function isAvailable():Bool {
        if (!PlatformUtils.isWindows()) return false;
        return Sys.command("haxe -version > nul 2>&1") == 0;
    }
    
    public function build(config:Config, ?consoleMode:Bool = false):Bool {
        Console.println(Lang.get("build_windows"), ConsoleColor.BOLD);
        Console.info("Using SDL: " + projectConfig.sdlVersion);
        
        var platform = getName();
        config.ensureDirectories(platform);
        
        // 1. Ensure HashLink binaries are downloaded
        if (!ensureHashLinkBinaries(config)) {
            return false;
        }
        
        // 2. Generate C code
        if (!generateCCode(config, consoleMode)) {
            return false;
        }
        
        // 3. Find C file
        var cFile = findCFile(config, platform);
        if (cFile == "") {
            Console.error("C file not generated!");
            return false;
        }
        
        Console.info("Using C file: " + cFile);
        
        // 4. Find Visual Studio
        var vsInfo = findVisualStudio();
        if (vsInfo == null) {
            Console.error(Lang.get("vs_not_found"));
            return false;
        }
        
        Console.success(Lang.get("vs_found", [vsInfo.name]));
        
        // 5. Get HashLink directory
        var hlDir = getHashLinkDir();
        if (hlDir == "") {
            Console.error(Lang.get("hl_not_found"));
            return false;
        }

        // Kill any existing instance of this executable (silently)
        killProcess(config.projectName + ".exe");
        
        // 6. Compile
        Console.info(Lang.get("compiling_exe"));
        var compileCmd = buildCompileCommand(config, platform, hlDir, cFile, consoleMode);
        if (compileCmd == "") {
            return false;
        }
        
        executeWithVCVars(vsInfo, compileCmd);
        
        return moveOutputFiles(config, platform);
    }
    
    public function run(config:Config, ?showOutput:Bool = false):Void {
        if (!PlatformUtils.isWindows()) {
            Console.error("Cannot run Windows executable on this platform!");
            return;
        }
        
        var platform = getName();
        var exePath = config.getOutputPath(platform, ".exe");
        
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
        
        // Convert path to absolute Windows path
        var absPath = Sys.getCwd() + "\\" + StringTools.replace(foundPath, "/", "\\");
        
        if (showOutput) {
            // Test mode: create a batch script that runs the game and waits
            // When the game closes, the console window auto-closes
            // When the console window is closed, the game process is killed
            var title = "Test - " + config.projectName + " (trace output)";
            var batchContent = 
                '@echo off\n' +
                'title ' + title + '\n' +
                'echo Trace output for: ' + config.projectName + '\n' +
                'echo Close this window to stop the game.\n' +
                'echo ========================================\n' +
                'start "" /B /WAIT "' + absPath + '"\n' +
                'echo.\n' +
                'echo Game has exited. Closing in 3 seconds...\n' +
                'ping -n 3 127.0.0.1 > nul\n';
            
            var batchFile = Sys.getCwd() + "\\__test_run.bat";
            File.saveContent(batchFile, batchContent);
            
            // Start the batch script in a new console window
            Sys.command('start "' + title + '" cmd /c "' + batchFile + '"');
        } else {
            // Run mode: launch in background (no console window)
            Sys.command('start "" "' + absPath + '"');
        }
    }
    
    /**
     * Kill a running process by name
     */
    function killProcess(processName:String):Void {
        try {
            // Use taskkill with output suppressed, check if process exists first
            var result = Sys.command('taskkill /F /IM "' + processName + '" /T > nul 2>&1');
            if (result == 0) {
                Console.info("Killed existing process: " + processName);
                Sys.sleep(0.5);
            }
        } catch (e:Dynamic) {
            // Process might not exist, that's fine
        }
    }
    
    // ==================== HashLink Binary Management ====================
    
    function ensureHashLinkBinaries(config:Config):Bool {
        var beapHome = getBeapHome();
        if (beapHome == "") {
            Console.error("Cannot find beap installation directory!");
            return false;
        }
        
        var sdlDir = projectConfig.sdlVersion;
        var targetDir = beapHome + "/tools/windows/" + sdlDir;
        
        // Check if binaries already exist (including in subdirectories)
        if (FileSystem.exists(targetDir)) {
            if (hasLibFiles(targetDir)) {
                Console.info("HashLink binaries found: " + targetDir);
                return true;
            }
        }
        
        // Download from GitHub
        Console.info("Downloading HashLink binaries for Windows (" + sdlDir + ")...");
        return Downloader.downloadHashLink(targetDir, sdlDir);
    }
    
    /**
     * Recursively check if a directory contains .lib or .hdll files
     */
    function hasLibFiles(dir:String):Bool {
        try {
            var entries = FileSystem.readDirectory(dir);
            for (entry in entries) {
                if (entry == "." || entry == "..") continue;
                var fullPath = dir + "/" + entry;
                if (FileSystem.isDirectory(fullPath)) {
                    if (hasLibFiles(fullPath)) return true;
                } else if (StringTools.endsWith(entry, ".lib") || StringTools.endsWith(entry, ".hdll")) {
                    return true;
                }
            }
        } catch (e:Dynamic) {}
        return false;
    }
    
    // ==================== Core Build Steps ====================
    
    function generateCCode(config:Config, ?consoleMode:Bool = false):Bool {
        Console.info("Generating C code from Haxe...");
        
        var platform = getName();
        var outDir = config.getOutDir(platform);
        
        if (!FileSystem.exists(outDir)) {
            FileSystem.createDirectory(outDir);
        }
        
        var hxmlContent = getBuildHxml(config, platform, consoleMode);
        var hxmlPath = config.getBuildDir(platform) + "/build-windows.hxml";
        File.saveContent(hxmlPath, hxmlContent);
        
        Console.info(Lang.get("compile_haxe"));
        var exitCode = Sys.command("haxe", [hxmlPath]);
        if (exitCode != 0) {
            Console.error(Lang.get("build_failed"));
            return false;
        }
        
        return true;
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
    
    function getBuildHxml(config:Config, platform:String, ?consoleMode:Bool = false):String {
        var outDir = config.getOutDir(platform);
        var cFile = outDir + "/" + config.projectName + ".c";
        
        var hxml = projectConfig.generateHxml(platform, false);
        
        // Add console mode flag for test builds
        if (consoleMode) {
            hxml += '-D console\n';
        }
        
        hxml += '-hl ${cFile}\n';
        return hxml;
    }
    
    /**
     * Recursively find a library file in a directory tree
     */
    function findLibRecursive(dir:String, libName:String):String {
        try {
            var entries = FileSystem.readDirectory(dir);
            for (entry in entries) {
                if (entry == "." || entry == "..") continue;
                var fullPath = dir + "/" + entry;
                if (FileSystem.isDirectory(fullPath)) {
                    var result = findLibRecursive(fullPath, libName);
                    if (result != "") return result;
                } else if (entry == libName) {
                    return fullPath;
                }
            }
        } catch (e:Dynamic) {}
        return "";
    }
    
    /**
     * Find all .lib files recursively in a directory
     */
    function findAllLibsRecursive(dir:String):Array<String> {
        var result:Array<String> = [];
        try {
            var entries = FileSystem.readDirectory(dir);
            for (entry in entries) {
                if (entry == "." || entry == "..") continue;
                var fullPath = dir + "/" + entry;
                if (FileSystem.isDirectory(fullPath)) {
                    result = result.concat(findAllLibsRecursive(fullPath));
                } else if (StringTools.endsWith(entry, ".lib")) {
                    result.push(fullPath);
                }
            }
        } catch (e:Dynamic) {}
        return result;
    }
    
    function buildCompileCommand(config:Config, platform:String, hlDir:String, cFile:String, ?consoleMode:Bool = false):String {
        var buildDir = config.getBuildDir(platform);
        var exeFile = buildDir + "/" + config.projectName + ".exe";
        
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
        
        var cFileDir = Path.directory(cFile);
        var includeArgs = ' /I "' + hlDirFixed + '/include" /I "' + currentDir + '/' + cFileDir + '"';
        
        // Get SDL-specific libraries
        var beapToolsDir = getBeapToolsDir();
        var sdlDir = projectConfig.sdlVersion;
        var libArgs = "";
        
        // Required libraries
        var libFiles = ["libhl.lib", "fmt.lib", "uv.lib", "ui.lib"];
        
        // SDL library - sdl.lib is the HashLink SDL interface library
        // For SDL2: sdl.lib links against SDL2.dll
        // For SDL3: sdl.lib links against SDL3.dll (compiled from HashLink-Beap-SDL2 source)
        libFiles.push("sdl.lib");
        
        // For SDL3, also link SDL3.lib (the actual SDL3 library)
        if (sdlDir == "sdl3") {
            libFiles.push("SDL3.lib");
        }
        
        for (lib in libFiles) {
            var found = false;
            
            // Check SDL-specific directory first
            if (beapToolsDir != "") {
                var sdlLibPath = beapToolsDir + "/" + sdlDir + "/" + lib;
                if (FileSystem.exists(sdlLibPath)) {
                    libArgs += ' "' + sdlLibPath + '"';
                    found = true;
                    Console.info("Found " + lib + " in " + sdlDir + " tools");
                }
            }
            
            // Fall back to generic tools directory
            if (!found && beapToolsDir != "") {
                var beapLibPath = beapToolsDir + "/" + lib;
                if (FileSystem.exists(beapLibPath)) {
                    libArgs += ' "' + beapLibPath + '"';
                    found = true;
                }
            }
            
            // Fall back to HashLink directory
            if (!found) {
                var hlLibPath = hlDirFixed + "/" + lib;
                if (FileSystem.exists(hlLibPath)) {
                    libArgs += ' "' + hlLibPath + '"';
                    found = true;
                }
            }
            
            // Recursively search in subdirectories of beap tools
            if (!found && beapToolsDir != "") {
                var sdlDirPath = beapToolsDir + "/" + sdlDir;
                if (FileSystem.exists(sdlDirPath)) {
                    var foundPath = findLibRecursive(sdlDirPath, lib);
                    if (foundPath != "") {
                        libArgs += ' "' + foundPath + '"';
                        found = true;
                        Console.info("Found " + lib + " in subdirectory");
                    }
                }
            }
            
            if (!found) {
                Console.warning(lib + " not found");
            }
        }
        
        // Also add all .lib files from the HashLink directory (for any extra libs)
        if (beapToolsDir != "") {
            var sdlDirPath = beapToolsDir + "/" + sdlDir;
            if (FileSystem.exists(sdlDirPath)) {
                var allLibs = findAllLibsRecursive(sdlDirPath);
                for (extraLib in allLibs) {
                    var libName = Path.withoutDirectory(extraLib);
                    // Skip already included libs
                    if (libFiles.indexOf(libName) == -1) {
                        libArgs += ' "' + extraLib + '"';
                        Console.info("Adding extra lib: " + libName);
                    }
                }
            }
        }
        
        // Use CONSOLE subsystem for test mode (shows trace output), WINDOWS for normal run
        var subsystem = "/SUBSYSTEM:WINDOWS";
        if (consoleMode) {
            subsystem = "/SUBSYSTEM:CONSOLE";
        } else if (projectConfig.windowsSubsystem == "console") {
            subsystem = "/SUBSYSTEM:CONSOLE";
        }
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
        
        if (FileSystem.exists(exeName)) {
            if (FileSystem.exists(buildExe)) FileSystem.deleteFile(buildExe);
            FileSystem.rename(exeName, buildExe);
            Console.success(Lang.get("build_success", [buildExe]));
            moved = true;
        } else if (FileSystem.exists(buildExe)) {
            Console.success(Lang.get("build_success", [buildExe]));
            moved = true;
        }
        
        if (FileSystem.exists(objName)) {
            if (FileSystem.exists(buildObj)) FileSystem.deleteFile(buildObj);
            FileSystem.rename(objName, buildObj);
        }
        
        var pdbName = config.projectName + '.pdb';
        var buildPdb = buildDir + '/' + pdbName;
        if (FileSystem.exists(pdbName)) {
            if (FileSystem.exists(buildPdb)) FileSystem.deleteFile(buildPdb);
            FileSystem.rename(pdbName, buildPdb);
        }
        
        var files = FileSystem.readDirectory(".");
        for (file in files) {
            if (StringTools.endsWith(file, ".ilk")) {
                var targetFile = buildDir + '/' + file;
                if (FileSystem.exists(targetFile)) FileSystem.deleteFile(targetFile);
                FileSystem.rename(file, targetFile);
            }
        }
        
        if (!moved) {
            Console.error(Lang.get("no_exe_generated"));
            return false;
        }
        
        return true;
    }
    
    // ==================== Tool Detection ====================
    
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
                var process = new Process(vswhere, [
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
        // 1. 优先使用 tools/ 目录下的 HashLink（从 GitHub Release 下载的）
        var beapHome = getBeapHome();
        if (beapHome != "") {
            var sdlDir = projectConfig.sdlVersion;
            var toolsHlDir = beapHome + "/tools/windows/" + sdlDir;
            if (FileSystem.exists(toolsHlDir + "/hl.exe")) {
                Console.info("Using bundled HashLink from: " + toolsHlDir);
                return toolsHlDir;
            }
        }
        
        // 2. 回退：查找系统安装的 HashLink
        var result = Sys.command("where hl > nul 2>&1");
        if (result == 0) {
            try {
                var process = new Process("where", ["hl"]);
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
    
    function getBeapToolsDir():String {
        var beapHome = getBeapHome();
        if (beapHome != "") {
            var toolsDir = beapHome + "/tools/windows";
            if (FileSystem.exists(toolsDir)) {
                return toolsDir;
            }
        }
        return "";
    }
    
    function getBeapHome():String {
        // 1. Check BEAP_PATH environment variable (set by beap.bat)
        var beapPath = Sys.getEnv("BEAP_PATH");
        if (beapPath != null && beapPath != "" && FileSystem.exists(beapPath)) {
            return StringTools.replace(beapPath, "\\", "/");
        }
        
        // 2. Check if running from the beap git directory (contains tools/ and templates/)
        var currentDir = StringTools.replace(Sys.getCwd(), "\\", "/");
        if (FileSystem.exists(currentDir + "/tools/windows") && FileSystem.exists(currentDir + "/templates")) {
            return currentDir;
        }
        
        // 3. Try haxelib path
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
    
    /**
     * Find a haxelib directory by name
     */
    function findHaxelibDir(libName:String):String {
        try {
            var proc = new Process("haxelib", ["path", libName]);
            var output = proc.stdout.readAll().toString();
            proc.close();
            
            var lines = output.split("\n");
            for (line in lines) {
                line = StringTools.trim(line);
                if (line != "" && !StringTools.startsWith(line, "-D") && !StringTools.startsWith(line, "-lib")) {
                    line = StringTools.replace(line, "\r", "");
                    // The first non-flag line should be the library directory
                    if (FileSystem.exists(line)) {
                        return line;
                    }
                }
            }
        } catch (e:Dynamic) {
            Console.warning("Could not find haxelib: " + libName + " (" + e + ")");
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
        
        // Try to delete temp batch file, ignore errors
        try {
            if (FileSystem.exists(batchFile)) {
                FileSystem.deleteFile(batchFile);
            }
        } catch (e:Dynamic) {
            // File might be locked, that's fine
        }
        
        if (exitCode != 0) {
            Console.error(Lang.get("compilation_failed", [Std.string(exitCode)]));
            Sys.exit(exitCode);
        }
    }
}
