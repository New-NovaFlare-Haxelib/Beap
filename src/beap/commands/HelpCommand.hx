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
        Console.println("");
        Console.print(Lang.get("app_name"), ConsoleColor.BOLD);
        Console.println(" (" + Lang.get("running_on") + ": " + PlatformUtils.getDetailedInfo() + ")", ConsoleColor.BLUE);
        Console.println("");
        
        Console.println(Lang.get("commands"), ConsoleColor.YELLOW);
        Console.println("  " + Lang.get("cmd_build"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_test"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_stop"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_lang"), ConsoleColor.GREEN);
        Console.println("  " + Lang.get("cmd_setup"), ConsoleColor.GREEN);
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
        Console.println("  " + Lang.get("ex_setup"), ConsoleColor.CYAN);
        Console.println("  beap setup android      # Configure Android SDK/NDK", ConsoleColor.CYAN);
        Console.println("  " + Lang.get("ex_build_hl"), ConsoleColor.CYAN);
        Console.println("  " + Lang.get("ex_build_windows"), ConsoleColor.CYAN);
        Console.println("  " + Lang.get("ex_test_hl"), ConsoleColor.CYAN);
        Console.println("");
        
        Console.println(Lang.get("current_config"), ConsoleColor.MAGENTA);
        Console.println("  " + Lang.get("project") + ": " + this.config.projectName, ConsoleColor.WHITE);
        Console.println("  " + Lang.get("directory") + ": " + this.config.projectDir, ConsoleColor.WHITE);
        Console.println("  " + Lang.get("platform") + ": " + PlatformUtils.getDetailedInfo(), ConsoleColor.WHITE);
        Console.println("");
    }
}