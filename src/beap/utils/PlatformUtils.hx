package beap.utils;

/**
 * Platform utility functions
 */
class PlatformUtils {
    
    public static function isWindows():Bool {
        return Sys.systemName().toLowerCase().indexOf("windows") != -1;
    }
    
    public static function isMac():Bool {
        var name = Sys.systemName().toLowerCase();
        return name.indexOf("mac") != -1 || name.indexOf("darwin") != -1;
    }
    
    public static function isLinux():Bool {
        return Sys.systemName().toLowerCase().indexOf("linux") != -1;
    }
    
    public static function getOsName():String {
        var name = Sys.systemName().toLowerCase();
        if (name.indexOf("windows") != -1) return "windows";
        if (name.indexOf("mac") != -1 || name.indexOf("darwin") != -1) return "macos";
        if (name.indexOf("linux") != -1) return "linux";
        return "unknown";
    }
    
    public static function getArch():String {
        var arch = Sys.systemName();
        if (arch.indexOf("64") != -1 || arch.indexOf("x86_64") != -1) {
            return "x86_64";
        } else if (arch.indexOf("ARM") != -1 || arch.indexOf("aarch64") != -1) {
            return "arm64";
        }
        return "x86_64";
    }
    
    public static function getExecutableExtension():String {
        #if windows
        return ".exe";
        #else
        return "";
        #end
    }
    
    public static function getSharedLibraryExtension():String {
        #if windows
        return ".dll";
        #elseif mac
        return ".dylib";
        #else
        return ".so";
        #end
    }
    
    public static function getStaticLibraryExtension():String {
        #if windows
        return ".lib";
        #else
        return ".a";
        #end
    }
    
    public static function getPathSeparator():String {
        #if windows
        return ";";
        #else
        return ":";
        #end
    }
    
    public static function normalizePath(path:String):String {
        #if windows
        return StringTools.replace(path, "/", "\\");
        #else
        return StringTools.replace(path, "\\", "/");
        #end
    }
    
    public static function getHomeDirectory():String {
        #if windows
        return Sys.getEnv("USERPROFILE");
        #else
        return Sys.getEnv("HOME");
        #end
    }
}
