package beap;

import sys.FileSystem;
import sys.io.File;

class Config {
    public var projectName:String = "MyGame";
    public var projectDir:String = "";
    public var isTestMode:Bool = false;
    
    public function new() {
        projectDir = Sys.getCwd();
    }
    
    public function init() {
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
        
        Console.init();
        Lang.init();
        loadProjectConfig();
    }
    
    function loadProjectConfig() {
        if (FileSystem.exists(".beap")) {
            try {
                var content = File.getContent(".beap");
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
    
    public function createDir(path:String) {
        if (!FileSystem.exists(path)) {
            FileSystem.createDirectory(path);
        }
    }
    
    public function ensureDirectories() {
        createDir("build");
        createDir("out");
    }
    
    public function checkProject():Bool {
        if (!FileSystem.exists("src/Main.hx")) {
            Console.error("src/Main.hx not found!");
            Console.info("Project directory: " + projectDir);
            Console.println("");
            Console.warning("Please make sure you are in your Heaps project directory.");
            Console.warning("Or run 'beap init' to create a new project.");
            return false;
        }
        return true;
    }
}