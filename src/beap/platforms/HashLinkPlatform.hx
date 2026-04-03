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
        
        var hxmlContent = getBuildHxml(config);
        File.saveContent("build.hxml", hxmlContent);
        
        Console.info(Lang.get("compile_hl"));
        var exitCode = Sys.command("haxe", ["build.hxml"]);
        
        if (exitCode != 0) {
            Console.error(Lang.get("build_failed"));
            return false;
        }
        
        Console.success(Lang.get("build_success", ["build/" + config.projectName + ".hl"]));
        return true;
    }
    
    public function run(config:Config):Void {
        var hlFile = 'build/${config.projectName}.hl';
        
        if (!sys.FileSystem.exists(hlFile)) {
            Console.error(Lang.get("hl_file_not_found"));
            return;
        }
        
        Console.success(Lang.get("running", [config.projectName]));
        Sys.command('start "" hl "$hlFile"');
    }
    
    function getBuildHxml(config:Config):String {
        if (sys.FileSystem.exists("build.hxml")) {
            Console.info("Using user's build.hxml");
            try {
                return File.getContent("build.hxml");
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
-hl build/${config.projectName}.hl
';
    }
}