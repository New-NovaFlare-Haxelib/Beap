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
        // 初始化平台注册表
        PlatformRegistry.init();
        
        config = new Config();
        config.init();
        
        // 打印当前运行平台信息
        printPlatformInfo();
        
        // 有效命令列表
        var validCommands = ["build", "test", "stop", "lang", "setup", "help", "-h", "--help"];
        
        // 找到第一个有效命令
        var commandName = "help";
        var commandArgs = [];
        var args = Sys.args();
        
        for (i in 0...args.length) {
            var arg = args[i];
            // 检查是否是有效命令
            if (validCommands.indexOf(arg) != -1) {
                commandName = arg;
                // 剩余的都是参数
                for (j in i+1...args.length) {
                    commandArgs.push(args[j]);
                }
                break;
            }
        }
        
        var command = createCommand(commandName);
        
        if (command == null) {
            Console.error('Unknown command: $commandName');
            printHelp();
            return;
        }
        
        command.execute(commandArgs);
    }
    
    static function printPlatformInfo() {
        var osName = PlatformUtils.getSystemName();
        var osArch = PlatformUtils.getArchitecture();
        
        Console.println("", ConsoleColor.RESET);
        Console.print("beap v" + VERSION + " ", ConsoleColor.BOLD);
        Console.print("running on ", ConsoleColor.WHITE);
        
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
        
        Console.println("beap path: " + Sys.getCwd(), ConsoleColor.BLUE);
        Console.println("");
    }
    
    static function createCommand(name:String):Command {
        return switch (name) {
            case "build": new BuildCommand(config);
            case "test": new TestCommand(config);
            case "stop": new StopCommand(config);
            case "lang": new LangCommand(config);
            case "setup": new SetupCommand(config);
            case "help", "-h", "--help": new HelpCommand(config);
            default: null;
        }
    }
    
    static function printHelp() {
        var helpCmd = new HelpCommand(config);
        helpCmd.printHelp();
    }
}