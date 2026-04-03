package beap.commands;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.platforms.PlatformRegistry;
import beap.commands.Command.BaseCommand;

class TestCommand extends BaseCommand {
    public override function execute(args:Array<String>) {
        if (args.length == 0) {
            Console.println("Usage: beap test <target>", ConsoleColor.YELLOW);
            return;
        }
        
        var target = args[0];
        
        if (!config.checkProject()) {
            Sys.exit(1);
        }
        
        var platform = PlatformRegistry.get(target);
        if (platform == null) {
            Console.error(Lang.get("unknown_target", [target]));
            Sys.exit(1);
        }
        
        config.ensureDirectories();
        config.isTestMode = true;
        stopRunningGame();
        
        if (platform.build(config)) {
            platform.run(config);
        }
        
        config.isTestMode = false;
    }
    
    function stopRunningGame() {
        Sys.command('taskkill /f /im "${config.projectName}.exe" 2>nul');
    }
}