package beap;

import beap.Console;
import beap.Config;
import beap.commands.*;
import beap.platforms.PlatformRegistry;

class BeapTool {
    static var config:Config;
    
    public static function main() {
        config = new Config();
        config.init();
        
        var args = Sys.args();
        var commandName = args.length > 0 ? args[0] : "help";
        var commandArgs = args.slice(1);
        
        var command = createCommand(commandName);
        
        if (command == null) {
            Console.error('Unknown command: $commandName');
            printHelp();
            return;
        }
        
        command.execute(commandArgs);
    }
    
    static function createCommand(name:String):Command {
        return switch (name) {
            case "build": new BuildCommand(config);
            case "test": new TestCommand(config);
            case "stop": new StopCommand(config);
            case "lang": new LangCommand(config);
            case "help", "-h", "--help": new HelpCommand(config);
            default: null;
        }
    }
    
    static function printHelp() {
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