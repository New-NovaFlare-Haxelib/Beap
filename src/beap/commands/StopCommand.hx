package beap.commands;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.commands.Command.BaseCommand;

class StopCommand extends BaseCommand {
    public override function execute(args:Array<String>) {
        var result = Sys.command('taskkill /f /im "${config.projectName}.exe" 2>nul');
        if (result == 0) {
            Console.success(Lang.get("stop_success"));
        } else {
            Console.info(Lang.get("game_not_running"));
        }
    }
}