package beap;

import beap.Console;
import beap.Config;
import beap.commands.*;
import beap.platforms.PlatformRegistry;
import beap.utils.PlatformUtils;

class BeapTool {
    static var config:Config;
    static var VERSION = "1.0.0";
    
    public static function main() {
        config = new Config();
        config.init();

        printPlatformInfo();
    }
    
    static function printPlatformInfo() {
        var osName = PlatformUtils.getOsName();
        var osArch = PlatformUtils.getArch();
        
        Console.println("", ConsoleColor.RESET);
        Console.print(Lang.get("app_name") + " v" + VERSION + " ", ConsoleColor.BOLD);
        Console.print(Lang.get("running_on") + " ", ConsoleColor.WHITE);
        
        var osColor = switch (osName) {
            case "Windows": ConsoleColor.CYAN;
            case "Mac": ConsoleColor.MAGENTA;
            case "Linux": ConsoleColor.GREEN;
            default: ConsoleColor.YELLOW;
        }
        
        Console.print(osName, osColor);
        Console.print(" (", ConsoleColor.WHITE);
        Console.print(osArch, ConsoleColor.YELLOW);
        Console.println(")", ConsoleColor.WHITE);
        
        Console.println(Lang.get("beap_path") + ": " + Sys.getCwd(), ConsoleColor.BLUE);
        Console.println("");
    }
    
    static function printHelp() {
        var helpCmd = new HelpCommand(config);
        helpCmd.printHelp();
    }
}