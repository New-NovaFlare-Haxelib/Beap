package beap;

import sys.FileSystem;
import sys.io.File;

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

        // ========== 英文翻译 ==========
        var en = new Map<String, String>();
        en.set("lang_switched", "Language switched to English");
        en.set("unknown_lang", "Unknown language: {0}");
        en.set("unknown_cmd", "Unknown command: {0}");
        en.set("unknown_target", "Unknown target: {0}");
        
        // 构建相关
        en.set("build_hl", "Building HashLink bytecode...");
        en.set("build_windows", "Building Windows executable...");
        en.set("build_linux", "Building Linux executable...");
        en.set("build_mac", "Building macOS executable...");
        en.set("build_android", "Building Android APK...");
        en.set("build_ios", "Building iOS app...");
        en.set("build_html5", "Building HTML5...");
        
        // 编译相关
        en.set("compile_hl", "Compiling Haxe to HashLink...");
        en.set("compile_haxe", "Compiling Haxe to C...");
        en.set("compile_exe", "Compiling to EXE with MSVC...");
        
        // 结果相关
        en.set("build_success", "Build complete: {0}");
        en.set("build_failed", "Build failed!");
        en.set("stop_success", "Stopped previous game process.");
        
        // 错误相关
        en.set("hl_not_found", "HashLink not found! Please install HashLink first.");
        en.set("haxe_not_found", "Haxe not found! Please install Haxe first.");
        en.set("exe_not_found", "Executable not found. Run 'beap build windows' first.");
        en.set("hl_file_not_found", "HL file not found. Run 'beap build hl' first.");
        en.set("src_not_found", "Error: src/Main.hx not found!");
        en.set("not_in_project", "Please make sure you are in your Heaps project directory.");
        en.set("run_init_first", "Or run 'beap init' to create a new project.");
        
        // 环境检查
        en.set("checking_env", "Checking environment...");
        en.set("env_ok", "Environment ready!");
        
        // 用法帮助
        en.set("need_target", "Usage: beap build <target>");
        en.set("targets", "Targets:");
        en.set("target_hl", "HashLink bytecode (fast development)");
        en.set("target_windows", "Windows executable (.exe)");
        en.set("target_linux", "Linux executable");
        en.set("target_mac", "macOS executable");
        en.set("target_android", "Android APK");
        en.set("target_ios", "iOS app");
        en.set("target_html5", "HTML5/JavaScript");
        en.set("examples", "Examples:");
        en.set("ex_build_hl", "beap build hl        # Build HashLink bytecode");
        en.set("ex_build_windows", "beap build windows   # Build Windows exe");
        en.set("ex_test_hl", "beap test hl          # Build and run HashLink");
        en.set("ex_test_windows", "beap test windows     # Build and run Windows exe");
        
        // 命令帮助
        en.set("commands", "Commands:");
        en.set("cmd_build", "build <target>    Build for specific platform");
        en.set("cmd_test", "test <target>     Build and run for specific platform");
        en.set("cmd_stop", "stop              Stop running game");
        en.set("cmd_lang", "lang [en/zh]      Set language for beap");
        en.set("cmd_help", "help              Show this help");
        
        // 运行相关
        en.set("running", "Running {0}...");
        en.set("running_with_test", "Running {0} in test mode...");
        
        // 配置文件相关
        en.set("using_user_config", "Using user's build.hxml");
        en.set("using_default_config", "Using default build configuration");
        en.set("config_read_error", "Warning: Failed to read build.hxml, using default.");
        
        // Visual Studio 相关
        en.set("vs_found", "Found: {0}");
        en.set("vs_not_found", "Error: Visual Studio not found!");
        en.set("compiling_exe", "Compiling to EXE...");
        en.set("compilation_failed", "Compilation failed with code: {0}");
        en.set("no_exe_generated", "Build failed! No EXE generated.");
        
        // init 命令相关
        en.set("creating_project", "Creating new Heaps project: {0}");
        en.set("project_created", "Project created successfully!");
        en.set("dir_exists", "Directory already exists: {0}");
        en.set("overwrite_confirm", "Overwrite? (y/N): ");
        en.set("overwrite_cancelled", "Project creation cancelled.");
        en.set("copying_template", "Copying template files...");
        en.set("template_not_found", "Template not found: {0}");
        en.set("edit_config", "Edit .beap to change project name");
        en.set("next_steps", "Next steps:");
        en.set("cd_project", "cd {0}");
        en.set("run_beap", "beap test hl        # Build and run");
        
        // stop 命令
        en.set("stopping_game", "Stopping game...");
        en.set("game_not_running", "No running game found.");
        
        translations.set("en", en);

        // ========== 中文翻译 ==========
        var zh = new Map<String, String>();
        zh.set("lang_switched", "已切换语言为中文");
        zh.set("unknown_lang", "未知语言: {0}");
        zh.set("unknown_cmd", "未知命令: {0}");
        zh.set("unknown_target", "未知目标平台: {0}");
        
        // 构建相关
        zh.set("build_hl", "正在编译 HashLink 字节码...");
        zh.set("build_windows", "正在编译 Windows 可执行文件...");
        zh.set("build_linux", "正在编译 Linux 可执行文件...");
        zh.set("build_mac", "正在编译 macOS 可执行文件...");
        zh.set("build_android", "正在编译 Android APK...");
        zh.set("build_ios", "正在编译 iOS 应用...");
        zh.set("build_html5", "正在编译 HTML5...");
        
        // 编译相关
        zh.set("compile_hl", "正在将 Haxe 编译为 HashLink 字节码...");
        zh.set("compile_haxe", "正在将 Haxe 编译为 C 代码...");
        zh.set("compile_exe", "正在使用 MSVC 编译为 EXE...");
        
        // 结果相关
        zh.set("build_success", "编译完成: {0}");
        zh.set("build_failed", "编译失败！");
        zh.set("stop_success", "已停止之前的游戏进程。");
        
        // 错误相关
        zh.set("hl_not_found", "未找到 HashLink！请先安装 HashLink。");
        zh.set("haxe_not_found", "未找到 Haxe！请先安装 Haxe。");
        zh.set("exe_not_found", "未找到可执行文件。请先运行 'beap build windows'。");
        zh.set("hl_file_not_found", "未找到 HL 文件。请先运行 'beap build hl'。");
        zh.set("src_not_found", "错误：未找到 src/Main.hx！");
        zh.set("not_in_project", "请确保您在 Heaps 项目目录中。");
        zh.set("run_init_first", "或运行 'beap init' 创建新项目。");
        
        // 环境检查
        zh.set("checking_env", "正在检查环境...");
        zh.set("env_ok", "环境就绪！");
        
        // 用法帮助
        zh.set("need_target", "使用方法: beap build <目标平台>");
        zh.set("targets", "目标平台:");
        zh.set("target_hl", "HashLink 字节码（快速开发）");
        zh.set("target_windows", "Windows 可执行文件 (.exe)");
        zh.set("target_linux", "Linux 可执行文件");
        zh.set("target_mac", "macOS 可执行文件");
        zh.set("target_android", "Android APK");
        zh.set("target_ios", "iOS 应用");
        zh.set("target_html5", "HTML5 / JavaScript");
        zh.set("examples", "示例:");
        zh.set("ex_build_hl", "beap build hl        # 编译 HashLink 字节码");
        zh.set("ex_build_windows", "beap build windows   # 编译 Windows 版本");
        zh.set("ex_test_hl", "beap test hl          # 编译并运行 HashLink");
        zh.set("ex_test_windows", "beap test windows     # 编译并运行 Windows 版本");
        
        // 命令帮助
        zh.set("commands", "命令:");
        zh.set("cmd_build", "build <目标>    构建指定平台");
        zh.set("cmd_test", "test <目标>     构建并运行指定平台");
        zh.set("cmd_stop", "stop            停止正在运行的游戏");
        zh.set("cmd_lang", "lang [en/zh]    设置 beap 的语言");
        zh.set("cmd_help", "help            显示此帮助");
        
        // 运行相关
        zh.set("running", "正在运行 {0}...");
        zh.set("running_with_test", "正在以测试模式运行 {0}...");
        
        // 配置文件相关
        zh.set("using_user_config", "正在使用用户自定义的 build.hxml");
        zh.set("using_default_config", "正在使用默认构建配置");
        zh.set("config_read_error", "警告：读取 build.hxml 失败，使用默认配置。");
        
        // Visual Studio 相关
        zh.set("vs_found", "找到: {0}");
        zh.set("vs_not_found", "错误：未找到 Visual Studio！");
        zh.set("compiling_exe", "正在编译为 EXE...");
        zh.set("compilation_failed", "编译失败，错误代码: {0}");
        zh.set("no_exe_generated", "构建失败！未生成 EXE 文件。");
        
        // init 命令相关
        zh.set("creating_project", "正在创建 Heaps 项目: {0}");
        zh.set("project_created", "项目创建成功！");
        zh.set("dir_exists", "目录已存在: {0}");
        zh.set("overwrite_confirm", "是否覆盖？(y/N): ");
        zh.set("overwrite_cancelled", "项目创建已取消。");
        zh.set("copying_template", "正在复制模板文件...");
        zh.set("template_not_found", "未找到模板: {0}");
        zh.set("edit_config", "编辑 .beap 文件修改项目名称");
        zh.set("next_steps", "下一步:");
        zh.set("cd_project", "cd {0}");
        zh.set("run_beap", "beap test hl        # 编译并运行");
        
        // stop 命令
        zh.set("stopping_game", "正在停止游戏...");
        zh.set("game_not_running", "没有找到正在运行的游戏。");
        
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
                try {
                    sys.io.File.saveContent(configPath, 'lang=$lang\n');
                } catch (e:Dynamic) {}
            }
        }
    }
    
    public static function getLang():String {
        return currentLang;
    }
}