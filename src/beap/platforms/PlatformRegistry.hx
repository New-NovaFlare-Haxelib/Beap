package beap.platforms;

class PlatformRegistry {
    static var platforms:Array<Platform> = [];
    
    public static function register(platform:Platform) {
        platforms.push(platform);
    }
    
    public static function get(name:String):Platform {
        for (p in platforms) {
            if (p.getName() == name) return p;
        }
        return null;
    }
    
    public static function getAll():Array<Platform> {
        return platforms.copy();
    }
    
    public static function init() {
        // Register all available platforms
        register(new HashLinkPlatform());
        register(new WindowsPlatform());
        // TODO: Add more platforms here
        // register(new LinuxPlatform());
        // register(new MacPlatform());
        // register(new AndroidPlatform());
        // register(new IosPlatform());
        // register(new Html5Platform());
    }
}