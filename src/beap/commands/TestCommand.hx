package beap.commands;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.platforms.PlatformRegistry;
import beap.commands.Command.BaseCommand;

class TestCommand extends BaseCommand {
    public override function execute(args:Array<String>) {
        if (args.length == 0) {
            Console.println(Lang.get("need_target_test"), ConsoleColor.YELLOW);
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
        
        // 传入平台名称
        config.ensureDirectories(platform.getName());
        config.isTestMode = true;
        stopRunningGame();
        
        if (platform.build(config)) {
            platform.run(config);
        }
        
        config.isTestMode = false;
    }
    
    function stopRunningGame() {
        #if windows
        Sys.command('taskkill /f /im "${config.projectName}.exe" 2>nul');
        #end
    }
}