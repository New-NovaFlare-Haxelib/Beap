// Lang.hx - 多语言支持
import sys.FileSystem;
import StringTools;

class Lang {
    static var currentLang:String = "en";
    static var translations:Map<String, Map<String, String>> = new Map();
    static var configPath:String = "";
    
    public static function init() {
        var home = Sys.getEnv("USERPROFILE");
        if (home == null) home = Sys.getEnv("HOME");
        if (home != null) {
            configPath = home + "/.beaprc";
        }

        // 英文翻译
        var en = new Map<String, String>();
        en.set("lang_switched", "Language switched to English");
        en.set("unknown_lang", "Unknown language: {0}");
        en.set("unknown_cmd", "Unknown command: {0}");
        en.set("unknown_target", "Unknown target: {0}");
        en.set("build_hl", "Building HashLink bytecode...");
        en.set("build_windows", "Building Windows executable...");
        en.set("build_linux", "Building Linux executable...");
        en.set("build_mac", "Building macOS executable...");
        en.set("build_android", "Building Android APK...");
        en.set("build_ios", "Building iOS app...");
        en.set("build_html5", "Building HTML5...");
        en.set("compile_hl", "Compiling Haxe to HashLink...");
        en.set("compile_haxe", "Compiling Haxe to C...");
        en.set("compile_exe", "Compiling to EXE with MSVC...");
        en.set("build_success", "Build complete: {0}");
        en.set("build_failed", "Build failed!");
        en.set("hl_not_found", "HashLink not found! Please install HashLink first.");
        en.set("haxe_not_found", "Haxe not found! Please install Haxe first.");
        en.set("running", "Running {0}...");
        en.set("exe_not_found", "Executable not found. Run 'beap build windows' first.");
        en.set("hl_file_not_found", "HL file not found. Run 'beap build hl' first.");
        en.set("checking_env", "Checking environment...");
        en.set("env_ok", "Environment ready!");
        en.set("need_target", "Usage: beap build <target>");
        en.set("targets", "Targets:");
        en.set("target_hl", "  hl        - HashLink bytecode (fast development)");
        en.set("target_windows", "  windows   - Windows executable (.exe)");
        en.set("target_linux", "  linux     - Linux executable");
        en.set("target_mac", "  mac       - macOS executable");
        en.set("target_android", "  android   - Android APK");
        en.set("target_ios", "  ios       - iOS app");
        en.set("target_html5", "  html5     - HTML5/JavaScript");
        en.set("examples", "Examples:");
        en.set("ex_build_hl", "  beap build hl        # Build HashLink bytecode");
        en.set("ex_build_windows", "  beap build windows   # Build Windows exe");
        translations.set("en", en);

        // 中文翻译
        var zh = new Map<String, String>();
        zh.set("lang_switched", "已切换语言为中文");
        zh.set("unknown_lang", "未知语言: {0}");
        zh.set("unknown_cmd", "未知命令: {0}");
        zh.set("unknown_target", "未知目标平台: {0}");
        zh.set("build_hl", "正在编译 HashLink 字节码...");
        zh.set("build_windows", "正在编译 Windows 可执行文件...");
        zh.set("build_linux", "正在编译 Linux 可执行文件...");
        zh.set("build_mac", "正在编译 macOS 可执行文件...");
        zh.set("build_android", "正在编译 Android APK...");
        zh.set("build_ios", "正在编译 iOS 应用...");
        zh.set("build_html5", "正在编译 HTML5...");
        zh.set("compile_hl", "正在将 Haxe 编译为 HashLink 字节码...");
        zh.set("compile_haxe", "正在将 Haxe 编译为 C 代码...");
        zh.set("compile_exe", "正在使用 MSVC 编译为 EXE...");
        zh.set("build_success", "编译完成: {0}");
        zh.set("build_failed", "编译失败！");
        zh.set("hl_not_found", "未找到 HashLink！请先安装 HashLink。");
        zh.set("haxe_not_found", "未找到 Haxe！请先安装 Haxe。");
        zh.set("running", "正在运行 {0}...");
        zh.set("exe_not_found", "未找到可执行文件。请先运行 'beap build windows'。");
        zh.set("hl_file_not_found", "未找到 HL 文件。请先运行 'beap build hl'。");
        zh.set("checking_env", "正在检查环境...");
        zh.set("env_ok", "环境就绪！");
        zh.set("need_target", "使用方法: beap build <目标平台>");
        zh.set("targets", "目标平台:");
        zh.set("target_hl", "  hl        - HashLink 字节码（快速开发）");
        zh.set("target_windows", "  windows   - Windows 可执行文件 (.exe)");
        zh.set("target_linux", "  linux     - Linux 可执行文件");
        zh.set("target_mac", "  mac       - macOS 可执行文件");
        zh.set("target_android", "  android   - Android APK");
        zh.set("target_ios", "  ios       - iOS 应用");
        zh.set("target_html5", "  html5     - HTML5 / JavaScript");
        zh.set("examples", "示例:");
        zh.set("ex_build_hl", "  beap build hl        # 编译 HashLink 字节码");
        zh.set("ex_build_windows", "  beap build windows   # 编译 Windows 版本");
        translations.set("zh", zh);

        loadLangSetting();
    }
    
    static function loadLangSetting() {
        if (configPath == null || configPath == "") return;
        if (!sys.FileSystem.exists(configPath)) return;
        
        try {
            var content = sys.io.File.getContent(configPath);
            var lines = content.split("\n");
            
            for (line in lines) {
                var trimmed = StringTools.trim(line);
                if (trimmed == "") continue;
                
                if (StringTools.startsWith(trimmed, "lang=")) {
                    var lang = trimmed.substr(5);
                    lang = StringTools.trim(lang);
                    if (lang == "zh" || lang == "en") {
                        currentLang = lang;
                    }
                }
            }
        } catch (e:Dynamic) {
            currentLang = "en";
        }
    }
    
    public static function get(key:String, args:Array<String> = null):String {
        var langMap = translations.get(currentLang);
        if (langMap == null) langMap = translations.get("en");
        
        var text = langMap.get(key);
        
        if (text == null) {
            var enMap = translations.get("en");
            if (enMap != null) text = enMap.get(key);
            if (text == null) return key;
        }
        
        if (args != null) {
            for (i in 0...args.length) {
                text = StringTools.replace(text, '{$i}', args[i]);
            }
        }
        
        return text;
    }
    
    public static function setLang(lang:String) {
        if (lang == "zh" || lang == "en") {
            currentLang = lang;
            if (configPath != null && configPath != "") {
                sys.io.File.saveContent(configPath, 'lang=$lang\n');
            }
        }
    }
    
    public static function getLang():String {
        return currentLang;
    }
}