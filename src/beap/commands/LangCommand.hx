package beap.commands;

import beap.Config;
import beap.Console;
import beap.Lang;
import beap.commands.Command.BaseCommand;

class LangCommand extends BaseCommand {
    public override function execute(args:Array<String>) {
        var target = args.length > 0 ? args[0] : "";
        
        switch (target) {
            case "en":
                Lang.setLanguage("en");
                Console.success(Lang.get("lang_switched"));
            case "zh":
                Lang.setLanguage("zh");
                Console.success(Lang.get("lang_switched"));
            case "":
                var current = Lang.getCurrentLang();
                if (current == "en") {
                    Console.println("Current language: English", ConsoleColor.CYAN);
                } else {
                    Console.println("当前语言: 中文", ConsoleColor.CYAN);
                }
                Console.println("");
                Console.println("Usage: beap lang [en/zh]", ConsoleColor.YELLOW);
                Console.println("  en  - Switch to English", ConsoleColor.WHITE);
                Console.println("  zh  - Switch to Chinese", ConsoleColor.WHITE);
            default:
                Console.error(Lang.get("unknown_lang", [target]));
        }
    }
}