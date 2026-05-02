package beap.platforms;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.project.ProjectConfig;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import sys.io.Process;

/**
 * HashLink (HL) Platform
 * 
 * Compiles Haxe to HashLink bytecode (.hl) and runs it with the HL VM.
 * This is useful for quick testing without needing to compile to C/exe.
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
        return "HashLink bytecode (.hl) - quick testing without C compilation";
    }
    
    public function isAvailable():Bool {
        // Check if hl.exe is available (bundled or in PATH)
        if (findHLExe() != "") return true;
        #if windows
        return Sys.command("where hl > nul 2>&1") == 0;
        #else
        return Sys.command("which hl > /dev/null 2>&1") == 0;
        #end
    }
    
    public function build(config:Config, ?consoleMode:Bool = false):Bool {
        Console.println("Building for HashLink VM", ConsoleColor.BOLD);
        
        var platform = getName();
        config.ensureDirectories(platform);
        
        // Generate HXML and compile to .hl bytecode
        if (!generateHLCode(config)) {
            return false;
        }
        
        Console.success("HL bytecode generated: " + getHLPath(config));
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
        
        // Find hl.exe
        var hlExe = findHLExe();
        if (hlExe == "") {
            Console.error("HashLink VM (hl) not found in PATH!");
            Console.info("Make sure HashLink is installed: https://hashlink.haxe.org/");
            return;
        }
        
        Console.success("Running: " + hlExe + " " + hlPath);
        
        if (showOutput) {
            // Run with output visible in console
            Console.info("=== HL Output ===");
            var proc = new Process(hlExe, [hlPath]);
            var output = proc.stdout.readAll().toString();
            var errOutput = proc.stderr.readAll().toString();
            proc.close();
            
            if (output != "") {
                Console.println(output, ConsoleColor.CYAN);
            }
            if (errOutput != "") {
                Console.println(errOutput, ConsoleColor.YELLOW);
            }
            Console.info("=== End HL Output ===");
        } else {
            // Run in background
            Sys.command('start "" "' + hlExe + '" "' + hlPath + '"');
        }
    }
    
    // ==================== Core Build Steps ====================
    
    function generateHLCode(config:Config):Bool {
        Console.info("Generating HashLink bytecode from Haxe...");
        
        var platform = getName();
        var outDir = config.getOutDir(platform);
        
        if (!FileSystem.exists(outDir)) {
            FileSystem.createDirectory(outDir);
        }
        
        var hlFile = getHLPath(config);
        var hxmlContent = getBuildHxml(config, platform);
        var hxmlPath = config.getBuildDir(platform) + "/build-hl.hxml";
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
            // Move it to the output directory
            if (!FileSystem.exists(outDir)) {
                FileSystem.createDirectory(outDir);
            }
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
        return config.getOutDir(getName()) + "/" + config.projectName + ".hl";
    }
    
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
        
        // 2. Try PATH first
        #if windows
        try {
            var proc = new Process("where", ["hl"]);
            var output = StringTools.trim(proc.stdout.readAll().toString());
            proc.close();
            if (output != "") {
                // Take the first line
                var lines = output.split("\n");
                if (lines.length > 0) {
                    return StringTools.trim(lines[0]);
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
        
        // 3. Check common installation paths
        var commonPaths = [
            "C:\\HaxeToolkit\\hl\\hl.exe",
            "C:\\hashlink\\hl.exe",
            "C:\\Program Files\\HashLink\\hl.exe",
            "/usr/local/bin/hl",
            "/usr/bin/hl"
        ];
        
        for (path in commonPaths) {
            if (FileSystem.exists(path)) {
                return path;
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
