package beap.commands;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.platforms.PlatformRegistry;
import beap.utils.PlatformUtils;
import beap.commands.Command.BaseCommand;

class HelpCommand extends BaseCommand {
    public function new(config:Config) {
        super(config);
    }
    
    public override function execute(args:Array<String>) {
        printHelp();
    }
    
    public function printHelp() {
        // 显示平台信息
        Console.println("");
        Console.print("beap - Heaps Build Tool", ConsoleColor.BOLD);
        Console.println(" (Running on: " + PlatformUtils.getDetailedInfo() + ")", ConsoleColor.BLUE);
        Console.println("");
        
        Console.println(Lang.get("commands"), ConsoleColor.YELLOW);
        Console.println("  " + Lang.get("cmd_build"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_test"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_stop"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_lang"), ConsoleColor.GREEN);
        Console.println("  setup             Setup beap for direct access", ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_help"), ConsoleColor.GREEN);
        Console.println("");
        
        Console.println(Lang.get("targets"), ConsoleColor.YELLOW);
        
        for (platform in PlatformRegistry.getAll()) {
            var available = platform.isAvailable();
            var status = available ? "✓" : "✗";
            var color = available ? ConsoleColor.GREEN : ConsoleColor.RED;
            Console.println("  " + status + " " + platform.getName() + " - " + platform.getDescription(), color);
        }
        
        Console.println("");
        Console.println(Lang.get("examples"), ConsoleColor.YELLOW);
        Console.println("  beap setup                # Setup for direct access", ConsoleColor.CYAN);
        Console.println("  beap build hl             # Build HashLink bytecode", ConsoleColor.CYAN);
        Console.println("  beap build windows        # Build Windows exe", ConsoleColor.CYAN);
        Console.println("  beap test hl              # Build and run HashLink", ConsoleColor.CYAN);
        Console.println("");
        
        Console.println("Current configuration:", ConsoleColor.MAGENTA);
        Console.println("  Project: " + this.config.projectName, ConsoleColor.WHITE);
        Console.println("  Directory: " + this.config.projectDir, ConsoleColor.WHITE);
        Console.println("  Platform: " + PlatformUtils.getDetailedInfo(), ConsoleColor.WHITE);
        Console.println("");
    }
}