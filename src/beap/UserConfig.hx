package beap;

import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;

/**
 * User-level configuration stored in home directory
 * Stores SDK/NDK paths and other user-specific settings
 * NOT stored in project.xml (which is shared via version control)
 */
class UserConfig {
    static inline var CONFIG_DIR = ".beap";
    static inline var CONFIG_FILE = "config";
    
    public var androidSdkPath:String = "";
    public var androidNdkPath:String = "";
    
    public function new() {}
    
    /**
     * Load user config from home directory
     */
    public static function load():UserConfig {
        var config = new UserConfig();
        var configPath = getConfigFilePath();
        
        if (configPath != "" && FileSystem.exists(configPath)) {
            try {
                var content = File.getContent(configPath);
                var lines = content.split("\n");
                for (line in lines) {
                    var trimmed = StringTools.trim(line);
                    if (trimmed == "" || StringTools.startsWith(trimmed, "#")) continue;
                    
                    var eqPos = trimmed.indexOf("=");
                    if (eqPos == -1) continue;
                    
                    var key = StringTools.trim(trimmed.substr(0, eqPos));
                    var value = StringTools.trim(trimmed.substr(eqPos + 1));
                    
                    switch (key) {
                        case "android.sdk":
                            config.androidSdkPath = value;
                        case "android.ndk":
                            config.androidNdkPath = value;
                    }
                }
            } catch (e:Dynamic) {
                // If config is corrupted, just use defaults
            }
        }
        
        return config;
    }
    
    /**
     * Save user config to home directory
     */
    public function save():Void {
        var configPath = getConfigFilePath();
        if (configPath == "") return;
        
        var dir = Path.directory(configPath);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
        }
        
        var buf = new StringBuf();
        buf.add("# Beap User Configuration\n");
        buf.add("# This file stores user-specific settings (SDK paths, etc.)\n");
        buf.add("# It is NOT shared via version control.\n\n");
        buf.add("android.sdk=" + androidSdkPath + "\n");
        buf.add("android.ndk=" + androidNdkPath + "\n");
        
        File.saveContent(configPath, buf.toString());
    }
    
    /**
     * Get the path to the user config file
     */
    static function getConfigFilePath():String {
        var home = getHomeDir();
        if (home == "") return "";
        return home + "/" + CONFIG_DIR + "/" + CONFIG_FILE;
    }
    
    /**
     * Get user home directory
     */
    static function getHomeDir():String {
        #if windows
        var userProfile = Sys.getEnv("USERPROFILE");
        if (userProfile != null && userProfile != "") {
            return StringTools.replace(userProfile, "\\", "/");
        }
        var homeDrive = Sys.getEnv("HOMEDRIVE");
        var homePath = Sys.getEnv("HOMEPATH");
        if (homeDrive != null && homePath != null) {
            return StringTools.replace(homeDrive + homePath, "\\", "/");
        }
        #else
        var home = Sys.getEnv("HOME");
        if (home != null && home != "") return home;
        #end
        return "";
    }
}
