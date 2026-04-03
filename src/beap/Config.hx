package beap;

import sys.FileSystem;
import sys.io.File;
import beap.utils.PlatformUtils;

class Config {
    public var projectName:String = "MyGame";
    public var projectDir:String = "";
    public var isTestMode:Bool = false;
    public var platformInfo:String = "";
    
    public function new() {
        projectDir = normalizePath(Sys.getCwd());
        platformInfo = PlatformUtils.getDetailedInfo();
    }
    
    public function init() {
        var args = Sys.args();
        
        // 查找项目目录参数
        for (i in 0...args.length) {
            var arg = args[i];
            if (isPathArgument(arg)) {
                if (FileSystem.exists(arg) && FileSystem.isDirectory(arg)) {
                    projectDir = normalizePath(arg);
                    break;
                }
            }
        }
        
        Sys.setCwd(projectDir);
        
        Console.init();
        Lang.init();
        loadProjectConfig();
    }
    
    // 规范化路径，统一使用正斜杠
    function normalizePath(path:String):String {
        var normalized = StringTools.replace(path, "\\", "/");
        // 移除末尾的斜杠
        if (normalized.length > 1 && StringTools.endsWith(normalized, "/")) {
            normalized = normalized.substr(0, normalized.length - 1);
        }
        return normalized;
    }
    
    function isPathArgument(arg:String):Bool {
        if (arg.indexOf("/") != -1 || arg.indexOf("\\") != -1) return true;
        if (arg.indexOf(":") != -1) return true;
        if (arg == "." || arg == "..") return true;
        return false;
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
        var normalizedPath = normalizePath(path);
        if (!FileSystem.exists(normalizedPath)) {
            FileSystem.createDirectory(normalizedPath);
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
            return false;
        }
        return true;
    }
}