package beap.platforms;

import beap.Config;
import beap.Console;
import beap.Lang;
import sys.io.File;

class HashLinkPlatform implements Platform {
    public function new() {}
    
    public function getName():String return "hl";
    
    public function getDescription():String {
        return "HashLink bytecode (fast development)";
    }
    
    public function isAvailable():Bool {
        return Sys.command("haxe -version > nul 2>&1") == 0;
    }
    
    public function build(config:Config):Bool {
        Console.println(Lang.get("build_hl"), ConsoleColor.BOLD);
        
        var platform = getName();
        config.ensureDirectories(platform);
        
        var hxmlContent = getBuildHxml(config, platform);
        var hxmlPath = config.getBuildDir(platform) + "/build.hxml";
        File.saveContent(hxmlPath, hxmlContent);
        
        Console.info(Lang.get("compile_hl"));
        var exitCode = Sys.command("haxe", [hxmlPath]);
        
        if (exitCode != 0) {
            Console.error(Lang.get("build_failed"));
            return false;
        }
        
        var outputPath = config.getOutputPath(platform, ".hl");
        Console.success(Lang.get("build_success", [outputPath]));
        return true;
    }
    
    public function run(config:Config):Void {
        var platform = getName();
        var hlFile = config.getOutputPath(platform, ".hl");
        
        if (!sys.FileSystem.exists(hlFile)) {
            Console.error(Lang.get("hl_file_not_found"));
            return;
        }
        
        Console.success(Lang.get("running", [config.projectName]));
        #if windows
        Sys.command('start "" hl "$hlFile"');
        #else
        Sys.command('hl $hlFile');
        #end
    }
    
    function getBuildHxml(config:Config, platform:String):String {
        var buildDir = config.getBuildDir(platform);
        var outDir = config.getOutDir(platform);
        var outputPath = config.getOutputPath(platform, ".hl");
        
        if (sys.FileSystem.exists("build.hxml")) {
            Console.info("Using user's build.hxml");
            try {
                var content = File.getContent("build.hxml");
                // 替换输出路径
                content = StringTools.replace(content, "$output", outputPath);
                return content;
            } catch (e:Dynamic) {
                Console.warning("Failed to read build.hxml, using default.");
            }
        }
        
        Console.info("Using default build configuration");
        return '
-cp src
-main Main
-lib heaps
-lib format
-lib hldx
-D windowTitle=${config.projectName}
-D windowSize=1280x720
-D debug
-hl $outputPath
';
    }
}