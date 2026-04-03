package beap;

enum ConsoleColor {
    RESET;
    RED;
    GREEN;
    YELLOW;
    BLUE;
    MAGENTA;
    CYAN;
    WHITE;
    BOLD;
}

class Console {
    static var supportsColor:Bool = true;
    
    public static function init() {
        supportsColor = true; // Windows 10+ supports ANSI
        setUTF8();
    }
    
    static function getColorCode(color:ConsoleColor):String {
        if (!supportsColor) return "";
        return switch (color) {
            case RESET: "\x1b[0m";
            case RED: "\x1b[31m";
            case GREEN: "\x1b[32m";
            case YELLOW: "\x1b[33m";
            case BLUE: "\x1b[34m";
            case MAGENTA: "\x1b[35m";
            case CYAN: "\x1b[36m";
            case WHITE: "\x1b[37m";
            case BOLD: "\x1b[1m";
        }
    }
    
    public static function println(text:String, color:ConsoleColor = WHITE) {
        Sys.println(getColorCode(color) + text + getColorCode(RESET));
    }
    
    public static function print(text:String, color:ConsoleColor = WHITE) {
        Sys.print(getColorCode(color) + text + getColorCode(RESET));
    }
    
    public static function success(text:String) {
        println("[✓] " + text, GREEN);
    }
    
    public static function error(text:String) {
        println("[✗] " + text, RED);
    }
    
    public static function warning(text:String) {
        println("[!] " + text, YELLOW);
    }
    
    public static function info(text:String) {
        println("[i] " + text, CYAN);
    }
    
    static function setUTF8() {
        Sys.command("chcp 65001 > nul");
    }
}