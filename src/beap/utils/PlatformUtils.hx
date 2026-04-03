package beap.utils;

class PlatformUtils {
    public static function isWindows():Bool {
        return Sys.systemName() == "Windows";
    }
    
    public static function isMac():Bool {
        return Sys.systemName() == "Mac";
    }
    
    public static function isLinux():Bool {
        return Sys.systemName() == "Linux";
    }
    
    public static function getSystemName():String {
        return Sys.systemName();
    }
    
    public static function getArchitecture():String {
        #if neko
        return "Neko VM";
        #elseif hl
        return "HashLink VM";
        #else
        var arch = Sys.getEnv("PROCESSOR_ARCHITECTURE");
        if (arch == null || arch == "") arch = "Unknown";
        return arch;
        #end
    }
    
    public static function getDetailedInfo():String {
        var info = getSystemName() + " " + getArchitecture();
        
        if (isWindows()) {
            var version = getWindowsVersion();
            if (version != "") info += " (" + version + ")";
        } else if (isLinux()) {
            var distro = getLinuxDistro();
            if (distro != "") info += " (" + distro + ")";
        } else if (isMac()) {
            var version = getMacVersion();
            if (version != "") info += " (" + version + ")";
        }
        
        return info;
    }
    
    static function getWindowsVersion():String {
        try {
            var process = new sys.io.Process("cmd", ["/c", "ver"]);
            var output = process.stdout.readAll().toString();
            process.close();
            
            // 解析 Windows 版本
            var regex = ~/Version (\d+)\.(\d+)\.(\d+)/;
            if (regex.match(output)) {
                var major = regex.matched(1);
                var minor = regex.matched(2);
                var build = regex.matched(3);
                return "Version " + major + "." + minor + "." + build;
            }
        } catch (e:Dynamic) {}
        return "";
    }
    
    static function getLinuxDistro():String {
        if (sys.FileSystem.exists("/etc/os-release")) {
            try {
                var content = sys.io.File.getContent("/etc/os-release");
                var lines = content.split("\n");
                for (line in lines) {
                    if (line.indexOf("PRETTY_NAME=") == 0) {
                        var value = line.substr(12);
                        // 移除引号
                        value = StringTools.replace(value, '"', '');
                        return value;
                    }
                }
            } catch (e:Dynamic) {}
        }
        return "";
    }
    
    static function getMacVersion():String {
        try {
            var process = new sys.io.Process("sw_vers", ["-productVersion"]);
            var output = StringTools.trim(process.stdout.readAll().toString());
            process.close();
            return "macOS " + output;
        } catch (e:Dynamic) {}
        return "";
    }
}