package beap;

import sys.FileSystem;
import sys.io.File;
import beap.utils.PlatformUtils;

class Config {
    public var projectName:String = "Main";
    public var projectDir:String = "";
    public var isTestMode:Bool = false;
    public var platformInfo:String = "";
    
    public static inline var BUILD_DIR = "build";
    public static inline var OUT_DIR = "build/out";
    public static inline var CACHE_DIR = "build/cache";
    
    public function new() {
        projectDir = normalizePath(Sys.getCwd());
        platformInfo = PlatformUtils.getOsName() + " " + PlatformUtils.getArch();
    }
    
    public function load():Void {
        loadProjectConfig();
    }
    
    public function init() {
        var args = Sys.args();
        
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
        
        // 先加载项目配置
        loadProjectConfig();
        
        Console.init();
        Lang.init();
        
        // 调试：显示加载的项目名称
        Console.info("Loaded project name: " + projectName);
    }
    
    function normalizePath(path:String):String {
        var normalized = StringTools.replace(path, "\\", "/");
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
    
    public function getBuildDir(platform:String):String {
        return BUILD_DIR + "/" + platform;
    }
    
    public function getOutDir(platform:String):String {
        return OUT_DIR + "/" + platform;
    }
    
    public function getCacheDir(platform:String):String {
        return CACHE_DIR + "/" + platform;
    }
    
    public function getOutputPath(platform:String, ext:String):String {
        var buildDir = getBuildDir(platform);
        return buildDir + "/" + projectName + ext;
    }
    
    public function ensureDirectories(platform:String) {
        createDir(getBuildDir(platform));
        createDir(getOutDir(platform));
        createDir(getCacheDir(platform));
    }
    
    public function createDir(path:String) {
        if (!FileSystem.exists(path)) {
            FileSystem.createDirectory(path);
        }
    }
    
    public function checkProject():Bool {
        if (!FileSystem.exists("src/Main.hx")) {
            Console.error(Lang.get("src_not_found"));
            Console.info(Lang.get("project_dir") + ": " + projectDir);
            Console.println("");
            Console.warning(Lang.get("not_in_project"));
            return false;
        }
        return true;
    }
    
    function loadProjectConfig() {
        var configFile = ".beap";
        
        if (FileSystem.exists(configFile)) {
            Console.info("Found .beap config file");
            try {
                var content = File.getContent(configFile);
                
                var lines = content.split("\n");
                for (line in lines) {
                    var trimmed = StringTools.trim(line);
                    if (trimmed == "") continue;
                    
                    if (StringTools.startsWith(trimmed, "name=")) {
                        var name = StringTools.trim(trimmed.substr(5));
                        if (name != "") {
                            projectName = name;
                        }
                    }
                }
            } catch (e:Dynamic) {
                Console.warning("Failed to read .beap file: " + e);
            }
        } else {
            Console.info("No .beap config file found, using default name: " + projectName);
        }
    }
}
