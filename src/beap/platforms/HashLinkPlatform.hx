package beap.platforms;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.project.ProjectConfig;
import beap.utils.Downloader;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import sys.io.Process;

/**
 * HashLink (HL) Platform
 * 
 * Compiles Haxe to HashLink bytecode (.hl) and runs it with the HL VM.
 * This is useful for quick testing without needing to compile to C/exe.
 * Uses the same bundled HashLink binaries as WindowsPlatformSDL.
 * 
 * Usage:
 *   beap build hl     - Compile to .hl bytecode
 *   beap run hl       - Run the .hl bytecode with hl.exe
 *   beap test hl      - Build and run with trace output
 */
class HashLinkPlatform implements Platform {
    
    var projectConfig:ProjectConfig;
    
    public function new(config:ProjectConfig) {
        this.projectConfig = config;
    }
    
    public function getName():String return "hl";
    
    public function getDescription():String {
        var sdl = projectConfig.sdlVersion;
        return "HashLink bytecode (.hl) - quick testing with " + sdl;
    }
    
    public function isAvailable():Bool {
        // We'll use our bundled HashLink, so always available on Windows
        #if windows
        return true;
        #else
        return Sys.command("which hl > /dev/null 2>&1") == 0;
        #end
    }
    
    public function build(config:Config, ?consoleMode:Bool = false):Bool {
        Console.println(Lang.get("build_hl"), ConsoleColor.BOLD);
        Console.info("Using SDL: " + projectConfig.sdlVersion);
        
        var platform = getName();
        config.ensureDirectories(platform);
        
        // 1. Ensure HashLink binaries are downloaded
        if (!ensureHashLinkBinaries(config)) {
            return false;
        }
        
        // 2. Generate HL bytecode
        if (!generateHLCode(config)) {
            return false;
        }
        
        // 3. Copy .hdll dependencies to the build directory (same level as .hl file)
        copyDependencies(config, platform);
        
        Console.success(Lang.get("build_success", [getHLPath(config)]));
        return true;
    }
    
    public function run(config:Config, ?showOutput:Bool = false):Void {
        var hlPath = getHLPath(config);
        
        if (!FileSystem.exists(hlPath)) {
            Console.info("HL bytecode not found, building first...");
            if (!build(config)) {
                Console.error("Build failed, cannot run");
                return;
            }
        }
        
        // Kill any existing instance of hl.exe running our bytecode
        killHLProcess();
        
        // Find hl.exe (use bundled version first)
        var hlExe = findHLExe();
        if (hlExe == "") {
            Console.error("HashLink VM (hl) not found!");
            return;
        }
        
        Console.success(Lang.get("running", [config.projectName + ".hl"]));
        
        // Get directories
        var buildDir = config.getBuildDir(getName());
        var absBuildDir = StringTools.replace(Sys.getCwd() + "/" + buildDir, "/", "\\");
        var hlName = config.projectName + ".hl";
        
        // Create batch file to run with proper environment
        var batchContent = buildRunBatch(hlExe, absBuildDir, hlName, showOutput, config);
        var batchFile = Sys.getCwd() + "\\__run_hl_temp.bat";
        File.saveContent(batchFile, batchContent);
        
        // Execute
        Sys.command('cmd /c "' + batchFile + '"');
        
        // Cleanup
        try {
            if (FileSystem.exists(batchFile)) {
                FileSystem.deleteFile(batchFile);
            }
        } catch (e:Dynamic) {}
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
        
        // Check if binaries already exist
        if (FileSystem.exists(targetDir)) {
            if (hasHashLinkFiles(targetDir)) {
                Console.info("HashLink binaries found: " + targetDir);
                return true;
            }
        }
        
        // Download from GitHub
        Console.info("Downloading HashLink binaries for Windows (" + sdlDir + ")...");
        return Downloader.downloadHashLink(targetDir, sdlDir);
    }
    
    /**
     * Check if directory contains HashLink executables
     */
    function hasHashLinkFiles(dir:String):Bool {
        try {
            var entries = FileSystem.readDirectory(dir);
            for (entry in entries) {
                if (entry == "." || entry == "..") continue;
                var fullPath = dir + "/" + entry;
                if (FileSystem.isDirectory(fullPath)) {
                    if (hasHashLinkFiles(fullPath)) return true;
                } else if (entry == "hl.exe" || entry == "hl") {
                    return true;
                }
            }
        } catch (e:Dynamic) {}
        return false;
    }
    
    // ==================== Core Build Steps ====================
    
    function generateHLCode(config:Config):Bool {
        Console.info("Generating HashLink bytecode from Haxe...");
        
        var platform = getName();
        var buildDir = config.getBuildDir(platform);
        
        if (!FileSystem.exists(buildDir)) {
            FileSystem.createDirectory(buildDir);
        }
        
        var hlFile = getHLPath(config);
        var hxmlContent = getBuildHxml(config, platform);
        var hxmlPath = buildDir + "/build-hl.hxml";
        File.saveContent(hxmlPath, hxmlContent);
        
        Console.info("Compiling to: " + hlFile);
        var exitCode = Sys.command("haxe", [hxmlPath]);
        if (exitCode != 0) {
            Console.error("Haxe compilation failed!");
            return false;
        }
        
        // Check if .hl file was generated (might be in current dir)
        var rootHLFile = config.projectName + ".hl";
        if (!FileSystem.exists(hlFile) && FileSystem.exists(rootHLFile)) {
            // Move it to the build directory
            File.copy(rootHLFile, hlFile);
            FileSystem.deleteFile(rootHLFile);
        }
        
        if (!FileSystem.exists(hlFile)) {
            Console.error("HL bytecode not generated: " + hlFile);
            return false;
        }
        
        return true;
    }
    
    function getBuildHxml(config:Config, platform:String):String {
        var hlFile = getHLPath(config);
        
        var hxml = projectConfig.generateHxml(platform, false);
        hxml += '-hl ' + hlFile + '\n';
        
        return hxml;
    }
    
    function getHLPath(config:Config):String {
        return config.getBuildDir(getName()) + "/" + config.projectName + ".hl";
    }
    
    // ==================== Dependency Management ====================
    
    /**
     * Copy all .hdll dependencies to the build directory (same level as .hl file).
     * HashLink VM will load .hdll files from the same directory as the .hl file
     * and from directories specified in HASHLINK_PATH.
     */
    function copyDependencies(config:Config, platform:String):Void {
        var buildDir = config.getBuildDir(platform);
        var beapToolsDir = getBeapToolsDir();
        
        if (beapToolsDir == "") {
            Console.warning("Cannot find beap tools directory, skipping dependency copy");
            return;
        }
        
        var sdlDir = projectConfig.sdlVersion;
        var srcDir = beapToolsDir + "/" + sdlDir;
        
        Console.info("Copying .hdll dependencies to: " + buildDir);
        
        // Copy .hdll files (HashLink dynamic libraries) to build/hl/
        copyFilesByExtension(srcDir, buildDir, ".hdll");
        
        // Also copy any .dll dependencies that HL might need (like SDL3.dll)
        copyFilesByExtension(srcDir, buildDir, ".dll");
        
        Console.success("All dependencies copied to: " + buildDir);
    }
    
    /**
     * Copy all files with a specific extension from source to destination
     */
    function copyFilesByExtension(srcDir:String, dstDir:String, ext:String):Void {
        if (!FileSystem.exists(srcDir)) {
            Console.warning("Source directory not found: " + srcDir);
            return;
        }
        
        if (!FileSystem.exists(dstDir)) {
            FileSystem.createDirectory(dstDir);
        }
        
        var count = 0;
        try {
            var entries = FileSystem.readDirectory(srcDir);
            for (entry in entries) {
                if (StringTools.endsWith(entry, ext)) {
                    var srcPath = srcDir + "/" + entry;
                    var dstPath = dstDir + "/" + entry;
                    if (!FileSystem.isDirectory(srcPath)) {
                        try {
                            var content = File.getBytes(srcPath);
                            File.saveBytes(dstPath, content);
                            count++;
                        } catch (e:Dynamic) {
                            Console.warning("Failed to copy: " + entry + " (" + e + ")");
                        }
                    }
                }
            }
        } catch (e:Dynamic) {}
        
        if (count > 0) {
            Console.info("Copied " + count + " " + ext + " files to: " + dstDir);
        }
    }
    
    // ==================== Run Script Management ====================
    
    /**
     * Build the batch file content for running HL bytecode
     */
    function buildRunBatch(hlExe:String, buildDir:String, hlName:String, showOutput:Bool, config:Config):String {
        var batchContent = '@echo off\n';
        batchContent += 'cd /d "' + buildDir + '"\n';
        
        // Set HASHLINK_PATH to current directory so HL can find .hdll files
        batchContent += 'set "HASHLINK_PATH=%CD%"\n';
        
        // Also add to PATH for any .dll dependencies
        batchContent += 'set "PATH=%CD%;%PATH%"\n';
        
        if (showOutput) {
            var title = "HL Test - " + config.projectName;
            batchContent += 'title ' + title + '\n';
            batchContent += 'echo Trace output for: ' + config.projectName + '\n';
            batchContent += 'echo Close this window to stop the game.\n';
            batchContent += 'echo ========================================\n';
            batchContent += '"' + StringTools.replace(hlExe, "/", "\\") + '" "' + hlName + '"\n';
            batchContent += 'echo.\n';
            batchContent += 'echo Game has exited. Closing in 3 seconds...\n';
            batchContent += 'ping -n 3 127.0.0.1 > nul\n';
        } else {
            batchContent += 'start "" "' + StringTools.replace(hlExe, "/", "\\") + '" "' + hlName + '"\n';
        }
        
        return batchContent;
    }
    
    /**
     * Kill any running hl.exe process that might be using our bytecode
     */
    function killHLProcess():Void {
        try {
            // Check if hl.exe is running
            var result = Sys.command('taskkill /F /IM hl.exe /T > nul 2>&1');
            if (result == 0) {
                Console.info("Killed existing hl.exe process");
                Sys.sleep(0.5);
            }
        } catch (e:Dynamic) {
            // Process might not exist, that's fine
        }
    }
    
    // ==================== Tool Detection ====================
    
    function findHLExe():String {
        // 1. 优先使用 beap 下载的 HashLink（从 GitHub Release 下载的）
        var beapHome = getBeapHome();
        if (beapHome != "") {
            var sdlDir = projectConfig.sdlVersion;
            var toolsHlDir = beapHome + "/tools/windows/" + sdlDir;
            var hlExePath = toolsHlDir + "/hl.exe";
            if (FileSystem.exists(hlExePath)) {
                Console.info("Using bundled HashLink from: " + hlExePath);
                return hlExePath;
            }
        }
        
        // 2. 回退：查找系统安装的 HashLink
        #if windows
        try {
            var proc = new Process("where", ["hl"]);
            var output = StringTools.trim(proc.stdout.readAll().toString());
            proc.close();
            if (output != "") {
                var lines = output.split("\n");
                if (lines.length > 0) {
                    var found = StringTools.trim(lines[0]);
                    Console.info("Found system hl.exe at: " + found);
                    return found;
                }
            }
        } catch (e:Dynamic) {}
        #else
        try {
            var proc = new Process("which", ["hl"]);
            var output = StringTools.trim(proc.stdout.readAll().toString());
            proc.close();
            if (output != "") return output;
        } catch (e:Dynamic) {}
        #end
        
        // 3. 检查常见路径
        var commonPaths = [
            "C:\\HaxeToolkit\\hl\\hl.exe",
            "C:\\hashlink\\hl.exe",
            "C:\\Program Files\\HashLink\\hl.exe"
        ];
        
        for (path in commonPaths) {
            if (FileSystem.exists(path)) {
                Console.info("Found HashLink at: " + path);
                return path;
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
}