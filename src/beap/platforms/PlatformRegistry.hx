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
}