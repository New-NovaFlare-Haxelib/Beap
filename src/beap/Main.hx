package beap;

import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import beap.Console;
import beap.Lang;
import beap.Config;
import beap.project.ProjectConfig;
import beap.platforms.Platform;
import beap.platforms.AndroidPlatformSDL;
import beap.platforms.WindowsPlatformSDL;
import beap.utils.Downloader;
import beap.utils.PlatformUtils;

/**
 * Beap - Build tool for HashLink/C applications
 * Supports SDL2 and SDL3 with automatic binary downloading
 * Uses project.xml for configuration (like lime)
 */
class Main {
    
    static var config:Config;
    static var projectConfig:ProjectConfig;
    static var platforms:Map<String, Platform> = [];
    
    public static function main() {
        Console.init();
        Lang.init();
        
        var args = Sys.args();
        
        // Check for -project argument
        var projectDir = "";
        var commandArgs = [];
        var i = 0;
        while (i < args.length) {
            if (args[i] == "-project" && i + 1 < args.length) {
                projectDir = args[i + 1];
                i += 2;
            } else {
                commandArgs.push(args[i]);
                i++;
            }
        }
        
        if (commandArgs.length == 0) {
            showHelp();
            return;
        }
        
        // Change to project directory if specified
        if (projectDir != "" && sys.FileSystem.exists(projectDir)) {
            Sys.setCwd(projectDir);
        }
        
        var command = commandArgs[0].toLowerCase();
        
        // Initialize config
        config = new Config();
        config.load();
        
        // Load project config from XML
        projectConfig = ProjectConfig.load("project.xml");
        
        // Register platforms
        registerPlatforms();
        
        switch (command) {
            case "init":
                cmdInit(commandArgs);
            case "build":
                cmdBuild(commandArgs);
            case "run":
                cmdRun(commandArgs);
            case "test":
                cmdTest(commandArgs);
            case "clean":
                cmdClean(commandArgs);
            case "setup":
                cmdSetup(commandArgs);
            case "update":
                cmdUpdate(commandArgs);
            case "list":
                cmdList(commandArgs);
            case "lang":
                cmdLang(commandArgs);
            case "help":
                showHelp();
            default:
                Console.error(Lang.get("unknown_command", [command]));
                showHelp();
        }
    }
    
    static function registerPlatforms():Void {
        // Register SDL-aware platforms
        var android = new AndroidPlatformSDL(projectConfig);
        platforms.set(android.getName(), android);
        
        var windows = new WindowsPlatformSDL(projectConfig);
        platforms.set(windows.getName(), windows);
        
        var platformNames = [];
        for (key in platforms.keys()) {
            platformNames.push(key);
        }
        Console.info("Registered platforms: " + platformNames.join(", "));
    }
    
    // ==================== Commands ====================
    
    static function cmdInit(args:Array<String>):Void {
        Console.println(Lang.get("init_project"), ConsoleColor.BOLD);
        
        // Create project.xml
        if (!FileSystem.exists("project.xml")) {
            projectConfig.save("project.xml");
            Console.success("Created project.xml");
        } else {
            Console.warning("project.xml already exists");
        }
        
        // Create .beap config
        if (!FileSystem.exists(".beap")) {
            File.saveContent(".beap", 'name=${projectConfig.name}\n');
            Console.success("Created .beap");
        }
        
        // Create src directory
        if (!FileSystem.exists("src")) {
            FileSystem.createDirectory("src");
        }
        
        // Create Main.hx if not exists
        if (!FileSystem.exists("src/Main.hx")) {
            var mainContent = 
                'package;\n\n' +
                'import hxd.App;\n\n' +
                'class Main extends hxd.App {\n' +
                '    static function main() {\n' +
                '        #if use_sdl3\n' +
                '        trace("Running with SDL3!");\n' +
                '        #else\n' +
                '        trace("Running with SDL2!");\n' +
                '        #end\n' +
                '        new Main();\n' +
                '    }\n\n' +
                '    override function init() {\n' +
                '        var tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);\n' +
                '        tf.text = "Hello, Beap! (${projectConfig.sdlVersion})";\n' +
                '    }\n' +
                '}\n';
            File.saveContent("src/Main.hx", mainContent);
            Console.success("Created src/Main.hx");
        }
        
        Console.success(Lang.get("init_done"));
    }
    
    static function cmdBuild(args:Array<String>):Void {
        if (args.length < 2) {
            Console.error(Lang.get("specify_platform"));
            Console.info("Available: " + getPlatformList());
            return;
        }
        
        var platformName = args[1].toLowerCase();
        var debug = args.indexOf("-debug") != -1 || args.indexOf("-d") != -1;
        
        var platform = platforms.get(platformName);
        if (platform == null) {
            Console.error(Lang.get("unsupported_platform", [platformName]));
            Console.info("Available: " + getPlatformList());
            return;
        }
        
        // Kill any running instance before building (Windows only)
        if (PlatformUtils.isWindows()) {
            killProcess(projectConfig.name + ".exe");
        }
        
        Console.println("Building for: " + platformName + " (SDL: " + projectConfig.sdlVersion + ")", ConsoleColor.BOLD);
        
        // build command: use WINDOWS subsystem (no console)
        if (!platform.build(config, false)) {
            Console.error(Lang.get("build_failed"));
            Sys.exit(1);
        }
    }
    
    /**
     * Kill a running process by name
     */
    static function killProcess(processName:String):Void {
        try {
            var result = Sys.command("taskkill", ["/F", "/IM", processName, "/T"]);
            if (result == 0) {
                Console.info("Killed existing process: " + processName);
                Sys.sleep(0.5);
            }
        } catch (e:Dynamic) {}
    }
    
    static function cmdRun(args:Array<String>):Void {
        if (args.length < 2) {
            Console.error(Lang.get("specify_platform"));
            Console.info("Available: " + getPlatformList());
            return;
        }
        
        var platformName = args[1].toLowerCase();
        
        var platform = platforms.get(platformName);
        if (platform == null) {
            Console.error(Lang.get("unsupported_platform", [platformName]));
            Console.info("Available: " + getPlatformList());
            return;
        }
        
        // run command: launch in background (no output shown)
        platform.run(config, false);
    }
    
    static function cmdTest(args:Array<String>):Void {
        Console.println(Lang.get("test_mode"), ConsoleColor.BOLD);
        
        if (args.length < 2) {
            Console.error(Lang.get("specify_platform"));
            Console.info("Available: " + getPlatformList());
            return;
        }
        
        var platformName = args[1].toLowerCase();
        var debug = args.indexOf("-debug") != -1 || args.indexOf("-d") != -1;
        
        var platform = platforms.get(platformName);
        if (platform == null) {
            Console.error(Lang.get("unsupported_platform", [platformName]));
            Console.info("Available: " + getPlatformList());
            return;
        }
        
        // Build first with console mode (shows trace output)
        Console.println("Building for: " + platformName + " (SDL: " + projectConfig.sdlVersion + ")", ConsoleColor.BOLD);
        if (!platform.build(config, true)) {
            Console.error(Lang.get("build_failed"));
            Sys.exit(1);
        }
        
        // Then run (show output in console for test command)
        Console.println("Running " + platformName + "...", ConsoleColor.BOLD);
        platform.run(config, true);
        
        Console.success(Lang.get("test_complete"));
    }
    
    static function cmdClean(args:Array<String>):Void {
        Console.println(Lang.get("cleaning"), ConsoleColor.BOLD);
        
        var dirsToClean = ["build", "out"];
        for (dir in dirsToClean) {
            if (FileSystem.exists(dir)) {
                deleteDirectory(dir);
                Console.info("Cleaned: " + dir);
            }
        }
        
        // Clean generated C files
        var files = FileSystem.readDirectory(".");
        for (file in files) {
            if (StringTools.endsWith(file, ".c") || 
                StringTools.endsWith(file, ".obj") || 
                StringTools.endsWith(file, ".exe") ||
                StringTools.endsWith(file, ".pdb") ||
                StringTools.endsWith(file, ".ilk")) {
                try {
                    FileSystem.deleteFile(file);
                    Console.info("Cleaned: " + file);
                } catch (e:Dynamic) {}
            }
        }
        
        Console.success(Lang.get("clean_done"));
    }
    
    static function cmdSetup(args:Array<String>):Void {
        Console.println(Lang.get("setup_tool"), ConsoleColor.BOLD);
        
        if (args.length >= 2) {
            switch (args[1].toLowerCase()) {
                case "android":
                    setupAndroid();
                case "hashlink":
                    setupHashLink();
                case "sdl2":
                    setupSDL("sdl2");
                case "sdl3":
                    setupSDL("sdl3");
                default:
                    Console.error("Unknown setup target: " + args[1]);
            }
        } else {
            // Full setup
            setupHashLink();
            setupSDL("sdl2");
            setupSDL("sdl3");
            Console.success(Lang.get("setup_done"));
        }
    }
    
    static function cmdUpdate(args:Array<String>):Void {
        Console.println(Lang.get("checking_updates"), ConsoleColor.BOLD);
        
        var beapHome = getBeapHome();
        if (beapHome == "") {
            Console.error("Cannot find beap installation directory!");
            return;
        }
        
        // Check for updates for both SDL2 and SDL3
        var sdl2Version = "2026-04-30";
        var sdl3Version = "2026-04-30";
        
        // Try to read current versions
        var sdl2VersionFile = beapHome + "/tools/windows/sdl2/.version";
        var sdl3VersionFile = beapHome + "/tools/windows/sdl3/.version";
        
        if (FileSystem.exists(sdl2VersionFile)) {
            sdl2Version = StringTools.trim(File.getContent(sdl2VersionFile));
        }
        if (FileSystem.exists(sdl3VersionFile)) {
            sdl3Version = StringTools.trim(File.getContent(sdl3VersionFile));
        }
        
        var hasUpdate = false;
        
        if (Downloader.checkForUpdates(sdl2Version, "sdl2")) {
            Console.info("Updating SDL2 binaries...");
            Downloader.downloadHashLink(beapHome + "/tools/windows/sdl2", "sdl2");
            hasUpdate = true;
        }
        
        if (Downloader.checkForUpdates(sdl3Version, "sdl3")) {
            Console.info("Updating SDL3 binaries...");
            Downloader.downloadHashLink(beapHome + "/tools/windows/sdl3", "sdl3");
            hasUpdate = true;
        }
        
        if (hasUpdate) {
            Console.success(Lang.get("update_done"));
        } else {
            Console.info("Already up to date!");
        }
    }
    
    static function cmdList(args:Array<String>):Void {
        Console.println(Lang.get("platform_list"), ConsoleColor.BOLD);
        for (name in platforms.keys()) {
            var platform = platforms.get(name);
            var available = platform.isAvailable() ? "✓" : "✗";
            Console.println("  " + available + " " + name + " - " + platform.getDescription());
        }
        
        Console.println("\n" + Lang.get("current_config") + ":", ConsoleColor.BOLD);
        Console.println("  " + Lang.get("sdl_version", [projectConfig.sdlVersion]));
        Console.println("  " + Lang.get("project_name", [projectConfig.name]));
        Console.println("  " + Lang.get("package_name", [projectConfig.packageName]));
    }
    
    static function cmdLang(args:Array<String>):Void {
        if (args.length >= 2) {
            var lang = args[1].toLowerCase();
            if (Lang.getAvailableLangs().indexOf(lang) != -1) {
                Lang.setLanguage(lang);
                Console.success("Language set to: " + lang);
            } else {
                Console.error("Unsupported language: " + lang);
                Console.info("Available: " + Lang.getAvailableLangs().join(", "));
            }
        } else {
            Console.info("Current language: " + Lang.getCurrentLang());
            Console.info("Available: " + Lang.getAvailableLangs().join(", "));
        }
    }
    
    // ==================== Setup Helpers ====================
    
    static function setupAndroid():Void {
        Console.println("Android SDK/NDK Setup", ConsoleColor.BOLD);
        Console.println("");

        // Show current configuration
        var currentSdk = projectConfig.androidSdkPath;
        var currentNdk = projectConfig.androidNdkPath;

        Console.println("Current configuration:", ConsoleColor.YELLOW);
        if (currentSdk != "" && FileSystem.exists(currentSdk)) {
            Console.println("  Android SDK: " + currentSdk, ConsoleColor.GREEN);
        } else {
            Console.println("  Android SDK: [not set]", ConsoleColor.RED);
        }
        if (currentNdk != "" && FileSystem.exists(currentNdk)) {
            Console.println("  Android NDK: " + currentNdk, ConsoleColor.GREEN);
        } else {
            Console.println("  Android NDK: [not set]", ConsoleColor.RED);
        }
        Console.println("");

        var changed = false;

        // Prompt for SDK path
        Console.print("Enter Android SDK path (or press Enter to skip): ", ConsoleColor.CYAN);
        var sdkInput = Sys.stdin().readLine();
        if (sdkInput != null && StringTools.trim(sdkInput) != "") {
            sdkInput = StringTools.trim(sdkInput);
            if (FileSystem.exists(sdkInput)) {
                projectConfig.androidSdkPath = sdkInput;
                Console.success("Android SDK set to: " + sdkInput);
                changed = true;
            } else {
                Console.error("Path does not exist: " + sdkInput);
            }
        }

        Console.println("");

        // Prompt for NDK path
        Console.print("Enter Android NDK path (or press Enter to skip): ", ConsoleColor.CYAN);
        var ndkInput = Sys.stdin().readLine();
        if (ndkInput != null && StringTools.trim(ndkInput) != "") {
            ndkInput = StringTools.trim(ndkInput);
            if (FileSystem.exists(ndkInput)) {
                projectConfig.androidNdkPath = ndkInput;
                Console.success("Android NDK set to: " + ndkInput);
                changed = true;
            } else {
                Console.error("Path does not exist: " + ndkInput);
            }
        }

        Console.println("");

        // Save to project.xml if anything changed
        if (changed) {
            projectConfig.save("project.xml");
            Console.success("Android configuration saved to project.xml!");
        } else {
            Console.info("No changes made.");
        }

        Console.println("");
        Console.info("You can now run: beap build android");
    }
    
    static function setupHashLink():Void {
        Console.info("Downloading HashLink binaries...");
        
        var beapHome = getBeapHome();
        if (beapHome == "") {
            Console.error("Cannot find beap installation directory!");
            return;
        }
        
        // Download for both SDL2 and SDL3
        Downloader.downloadHashLink(beapHome + "/tools/windows/sdl2", "sdl2");
        Downloader.downloadHashLink(beapHome + "/tools/windows/sdl3", "sdl3");
        
        Console.success("HashLink setup complete!");
    }
    
    static function setupSDL(sdlVersion:String):Void {
        Console.info("Setting up " + sdlVersion + "...");
        
        var beapHome = getBeapHome();
        if (beapHome == "") {
            Console.error("Cannot find beap installation directory!");
            return;
        }
        
        Downloader.downloadHashLink(beapHome + "/tools/windows/" + sdlVersion, sdlVersion);
        Console.success(sdlVersion + " setup complete!");
    }
    
    // ==================== Utility Functions ====================
    
    static function getPlatformList():String {
        var names = [];
        for (key in platforms.keys()) {
            names.push(key);
        }
        return names.join(", ");
    }
    
    static function getBeapHome():String {
        try {
            var proc = new Process("haxelib", ["path", "beap"]);
            var output = proc.stdout.readAll().toString();
            proc.close();
            
            var lines = output.split("\n");
            for (line in lines) {
                line = StringTools.trim(line);
                if (line != "" && !StringTools.startsWith(line, "-D")) {
                    line = StringTools.replace(line, "\r", "");
                    return line;
                }
            }
        } catch (e:Dynamic) {}
        return "";
    }
    
    static function deleteDirectory(path:String):Void {
        if (!FileSystem.exists(path)) return;
        
        for (file in FileSystem.readDirectory(path)) {
            var fullPath = path + "/" + file;
            if (FileSystem.isDirectory(fullPath)) {
                deleteDirectory(fullPath);
            } else {
                try {
                    FileSystem.deleteFile(fullPath);
                } catch (e:Dynamic) {}
            }
        }
        
        try {
            FileSystem.deleteDirectory(path);
        } catch (e:Dynamic) {}
    }
    
    static function showHelp():Void {
        Console.println(Lang.get("help_title"), ConsoleColor.BOLD);
        Console.println(Lang.get("help_version"));
        Console.println("");
        Console.println(Lang.get("help_usage"));
        Console.println("");
        Console.println(Lang.get("help_commands") + ":");
        Console.println(Lang.get("cmd_init"));
        Console.println(Lang.get("cmd_build"));
        Console.println(Lang.get("cmd_run"));
        Console.println(Lang.get("cmd_test"));
        Console.println(Lang.get("cmd_clean"));
        Console.println(Lang.get("cmd_setup"));
        Console.println(Lang.get("cmd_update"));
        Console.println(Lang.get("cmd_list"));
        Console.println(Lang.get("cmd_help"));
        Console.println("");
        Console.println(Lang.get("help_options") + ":");
        Console.println(Lang.get("opt_debug"));
        Console.println(Lang.get("opt_project"));
        Console.println("");
        Console.println(Lang.get("help_config") + ":");
        Console.println(Lang.get("cfg_project"));
        Console.println(Lang.get("cfg_beap"));
        Console.println("");
        Console.println(Lang.get("help_examples") + ":");
        Console.println(Lang.get("ex_init"));
        Console.println(Lang.get("ex_build_windows"));
        Console.println(Lang.get("ex_build_android"));
        Console.println(Lang.get("ex_run_windows"));
        Console.println(Lang.get("ex_setup_android"));
        Console.println(Lang.get("ex_test_windows"));
    }
}
