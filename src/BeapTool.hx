import sys.io.Process;
import StringTools;
import sys.FileSystem;

class BeapTool {
    static var projectName:String = "MyGame";
    static var beapPath:String = "";
    static var checkEnv:Bool = false;
    
    public static function main() {
        Lang.init();
        getBeapPath();
        
        var args = Sys.args();
        
        if (args.length == 0) {
            printHelp();
            return;
        }
        
        var command = args[0];
        var target = args.length > 1 ? args[1] : "";
        
        switch (command) {
            case "build":
                if (target == "") {
                    Sys.println(Lang.get("need_target"));
                    Sys.println("");
                    Sys.println(Lang.get("targets"));
                    Sys.println(Lang.get("target_hl"));
                    Sys.println(Lang.get("target_windows"));
                    Sys.println(Lang.get("target_linux"));
                    Sys.println(Lang.get("target_mac"));
                    Sys.println(Lang.get("target_android"));
                    Sys.println(Lang.get("target_ios"));
                    Sys.println(Lang.get("target_html5"));
                } else {
                    // 检查环境
                    if (!checkEnvironment()) return;
                    buildTarget(target);
                }
                
            case "test":
                if (target == "") {
                    Sys.println("Usage: beap test <target>");
                    Sys.println("");
                    Sys.println("Targets: hl, windows");
                } else {
                    if (!checkEnvironment()) return;
                    buildTarget(target);
                    runTarget(target);
                }
                
            case "lang":
                if (target == "en") {
                    Lang.setLang("en");
                    Sys.println(Lang.get("lang_switched"));
                } else if (target == "zh") {
                    Lang.setLang("zh");
                    Sys.command("chcp 65001 > nul");
                    Sys.println(Lang.get("lang_switched"));
                } else if (target == "") {
                    var current = Lang.getLang();
                    if (current == "en") {
                        Sys.println("Current language: English");
                    } else {
                        Sys.println("当前语言: 中文");
                    }
                    Sys.println("");
                    Sys.println("Usage: beap lang [en/zh]");
                    Sys.println("  en  - Switch to English");
                    Sys.println("  zh  - Switch to Chinese");
                } else {
                    Sys.println(Lang.get("unknown_lang", [target]));
                }
                
            case "help", "-h", "--help":
                printHelp();
                
            default:
                Sys.println(Lang.get("unknown_cmd", [command]));
                printHelp();
        }
    }
    
    // ========== 环境检测 ==========
    static function checkEnvironment():Bool {
        Sys.println(Lang.get("checking_env"));
        
        // 检查 Haxe
        var haxeOk = Sys.command("haxe -version > nul 2>&1") == 0;
        if (!haxeOk) {
            Sys.println(Lang.get("haxe_not_found"));
            return false;
        }
        
        // 检查 HashLink
        var hlOk = getHashLinkExe() != "";
        if (!hlOk) {
            Sys.println(Lang.get("hl_not_found"));
            return false;
        }
        
        Sys.println(Lang.get("env_ok"));
        return true;
    }
    
    static function getBeapPath() {
        #if neko
        var path = Sys.getCwd() + "/" + Sys.programPath();
        beapPath = StringTools.replace(path, "beap.n", "");
        #else
        beapPath = Sys.getCwd() + "/";
        #end
    }
    
    static function buildTarget(target:String) {
        loadConfig();
        
        // 检查 src/Main.hx
        if (!FileSystem.exists("src/Main.hx")) {
            Sys.println("Error: src/Main.hx not found. Create a project with 'beap init' first.");
            Sys.exit(1);
        }
        
        switch (target) {
            case "hl":
                buildHashLink();
            case "windows":
                buildWindows();
            case "linux", "mac", "android", "ios", "html5":
                Sys.println(Lang.get("build_" + target));
                Sys.println("Coming soon...");
            default:
                Sys.println(Lang.get("unknown_target", [target]));
        }
    }
    
    static function runTarget(target:String) {
        switch (target) {
            case "hl":
                runHashLink();
            case "windows":
                runWindows();
            default:
                Sys.println(Lang.get("unknown_target", [target]));
        }
    }
    
    // ========== HashLink 构建 ==========
    static function buildHashLink() {
        Sys.println(Lang.get("build_hl"));
        
        createDir("build");
        loadConfig();
        
        var hxml = '
-cp src
-main Main
-lib heaps
-lib format
-lib hldx
-D windowTitle="$projectName"
-D windowSize=1280x720
-D debug
-hl build/$projectName.hl
';
        sys.io.File.saveContent("build.hxml", hxml);
        
        Sys.println(Lang.get("compile_hl"));
        var exitCode = Sys.command("haxe", ["build.hxml"]);
        
        if (exitCode != 0) {
            Sys.println(Lang.get("build_failed"));
            Sys.exit(1);
        }
        
        Sys.println(Lang.get("build_success", ["build/$projectName.hl"]));
    }
    
    static function runHashLink() {
        var hlExe = getHashLinkExe();
        var hlFile = 'build/$projectName.hl';
        
        if (!FileSystem.exists(hlFile)) {
            Sys.println(Lang.get("hl_file_not_found"));
            return;
        }
        
        if (hlExe != "") {
            Sys.println(Lang.get("running", [projectName]));
            Sys.command('$hlExe $hlFile');
        } else {
            Sys.println(Lang.get("hl_not_found"));
        }
    }
    
    // ========== Windows 构建 ==========
    static function buildWindows() {
        Sys.println(Lang.get("build_windows"));
        
        createDir("build");
        createDir("out");
        loadConfig();
        
        var hxml = '
-cp src
-main Main
-lib heaps
-lib format
-lib hldx
-D windowTitle="$projectName"
-D windowSize=1280x720
-D windowResizable
-hl out/$projectName.c
';
        sys.io.File.saveContent("build-windows.hxml", hxml);
        
        Sys.println(Lang.get("compile_haxe"));
        var exitCode = Sys.command("haxe", ["build-windows.hxml"]);
        if (exitCode != 0) {
            Sys.println(Lang.get("build_failed"));
            Sys.exit(1);
        }
        
        Sys.println(Lang.get("compile_exe"));
        var hlPath = getHashLinkPath();
        if (hlPath != "") {
            var compileCmd = 'cl out/$projectName.c /I "$hlPath/include" /link /LIBPATH:"$hlPath/lib" libhl.lib user32.lib opengl32.lib gdi32.lib shell32.lib /Fe:build/$projectName.exe /nologo';
            Sys.command(compileCmd);
            Sys.println(Lang.get("build_success", ["build/$projectName.exe"]));
        } else {
            Sys.println(Lang.get("hl_not_found"));
        }
    }
    
    static function runWindows() {
        var exePath = 'build/$projectName.exe';
        if (FileSystem.exists(exePath)) {
            Sys.println(Lang.get("running", [projectName]));
            Sys.command('start $exePath');
        } else {
            Sys.println(Lang.get("exe_not_found"));
        }
    }
    
    // ========== 配置管理 ==========
    static function loadConfig() {
        if (sys.FileSystem.exists(".beap")) {
            try {
                var content = sys.io.File.getContent(".beap");
                var lines = content.split("\n");
                for (line in lines) {
                    var trimmed = StringTools.trim(line);
                    if (StringTools.startsWith(trimmed, "name=")) {
                        projectName = StringTools.trim(trimmed.substr(5));
                    }
                }
            } catch (e:Dynamic) {}
        }
    }
    
    // ========== 辅助函数 ==========
    static function createDir(path:String) {
        if (!FileSystem.exists(path)) {
            FileSystem.createDirectory(path);
        }
    }
    
    static function getHashLinkPath():String {
        var paths = [
            "C:\\HaxeToolkit\\hl",
            "C:\\hashlink",
            Sys.getEnv("HASHLINK_PATH")
        ];
        
        for (p in paths) {
            if (p != null && FileSystem.exists(p) && FileSystem.exists('$p\\hl.exe')) {
                return p;
            }
        }
        return "";
    }
    
    static function getHashLinkExe():String {
        var path = getHashLinkPath();
        if (path != "") return path + "\\hl.exe";
        
        if (Sys.command("hl --version > nul 2>&1") == 0) return "hl";
        
        return "";
    }
    
    static function printHelp() {
        Sys.println("");
        Sys.println("beap - Heaps Build Tool");
        Sys.println("");
        Sys.println("Usage: beap <command> [target]");
        Sys.println("");
        Sys.println("Commands:");
        Sys.println("  build <target>    Build for specific platform");
        Sys.println("  test <target>     Build and run for specific platform");
        Sys.println("  lang [en/zh]      Set language for beap");
        Sys.println("  help              Show this help");
        Sys.println("");
        Sys.println(Lang.get("targets"));
        Sys.println(Lang.get("target_hl"));
        Sys.println(Lang.get("target_windows"));
        Sys.println(Lang.get("target_linux"));
        Sys.println(Lang.get("target_mac"));
        Sys.println(Lang.get("target_android"));
        Sys.println(Lang.get("target_ios"));
        Sys.println(Lang.get("target_html5"));
        Sys.println("");
        Sys.println(Lang.get("examples"));
        Sys.println(Lang.get("ex_build_hl"));
        Sys.println(Lang.get("ex_build_windows"));
        Sys.println("");
        Sys.println("Environment:");
        Sys.println("  Haxe " + getHaxeVersion());
        Sys.println("  HashLink " + getHashLinkVersion());
        Sys.println("");
    }
    
    static function getHaxeVersion():String {
        var result = Sys.command("haxe -version 2>&1");
        return result == 0 ? "installed" : "not found";
    }
    
    static function getHashLinkVersion():String {
        var hl = getHashLinkExe();
        if (hl == "") return "not found";
        var result = Sys.command('$hl --version 2>&1');
        return result == 0 ? "installed" : "not found";
    }
}