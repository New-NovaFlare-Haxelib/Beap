package beap.commands;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.platforms.PlatformRegistry;
import beap.commands.Command.BaseCommand;

class HelpCommand extends BaseCommand {
    public override function execute(args:Array<String>) {
        printHelp();
    }
    
    public static function printHelp() {
        Console.println("");
        Console.println("beap - Heaps Build Tool", ConsoleColor.BOLD);
        Console.println("");
        Console.println(Lang.get("commands"), ConsoleColor.YELLOW);
        Console.println("  " + Lang.get("cmd_build"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_test"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_stop"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_lang"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_help"), ConsoleColor.GREEN);
        Console.println("");
        Console.println(Lang.get("targets"), ConsoleColor.YELLOW);
        
        for (platform in PlatformRegistry.getAll()) {
            Console.println("  " + platform.getName() + " - " + platform.getDescription(), ConsoleColor.WHITE);
        }
        
        Console.println("");
        Console.println(Lang.get("examples"), ConsoleColor.YELLOW);
        Console.println("  beap build hl", ConsoleColor.CYAN);
        Console.println("  beap build windows", ConsoleColor.CYAN);
        Console.println("  beap test hl", ConsoleColor.CYAN);
        Console.println("");
    }
}