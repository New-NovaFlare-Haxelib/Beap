package beap;

import sys.FileSystem;
import sys.io.File;

/**
 * Multi-language support for Beap
 * Supports Chinese (zh) and English (en)
 * Language can be set in project.xml or via environment variable
 */
class Lang {
    
    static var currentLang:String = "zh"; // Default to Chinese
    static var translations:Map<String, Map<String, String>> = [];
    
    public static function init() {
        // Check environment variable
        var envLang = Sys.getEnv("BEAP_LANG");
        if (envLang != null && envLang != "") {
            currentLang = envLang;
        }
        
        // Initialize translations
        initTranslations();
    }
    
    static function initTranslations() {
        // English translations
        var en = new Map<String, String>();
        en.set("build_windows", "Building Windows executable...");
        en.set("build_android", "Building Android APK...");
        en.set("compile_haxe", "Compiling Haxe to C code...");
        en.set("compiling_exe", "Compiling to EXE...");
        en.set("build_failed", "Build failed!");
        en.set("build_success", "Build successful: {0}");
        en.set("no_exe_generated", "No executable was generated!");
        en.set("compilation_failed", "Compilation failed with exit code: {0}");
        en.set("vs_not_found", "Visual Studio not found!");
        en.set("vs_found", "Found: {0}");
        en.set("hl_not_found", "HashLink not found!");
        en.set("exe_not_found", "Executable not found!");
        en.set("running", "Running {0}...");
        en.set("cleaning", "Cleaning build artifacts...");
        en.set("clean_done", "Clean complete!");
        en.set("init_project", "Initializing project...");
        en.set("init_done", "Project initialized!");
        en.set("setup_tool", "Setting up tools...");
        en.set("setup_done", "Setup complete!");
        en.set("checking_updates", "Checking for updates...");
        en.set("update_done", "Update complete!");
        en.set("specify_platform", "Please specify a platform!");
        en.set("unsupported_platform", "Unsupported platform: {0}");
        en.set("src_not_found", "Source file not found: src/Main.hx");
        en.set("project_dir", "Project directory");
        en.set("not_in_project", "Not in a project directory. Use 'beap init' to create a new project.");
        en.set("unknown_command", "Unknown command: {0}");
        en.set("android_sdk_not_found", "Android SDK not found!");
        en.set("android_ndk_not_found", "Android NDK not found!");
        en.set("gradle_build_failed", "Gradle build failed!");
        en.set("apk_built", "APK built: {0}");
        en.set("installing_apk", "Installing APK...");
        en.set("starting_app", "Starting application...");
        en.set("app_started", "Application started!");
        en.set("download_started", "Downloading {0}...");
        en.set("download_complete", "Download complete!");
        en.set("extracting", "Extracting {0}...");
        en.set("extract_complete", "Extraction complete!");
        en.set("sdl2_selected", "Using SDL2");
        en.set("sdl3_selected", "Using SDL3");
        en.set("config_loaded", "Configuration loaded: {0}");
        en.set("config_saved", "Configuration saved: {0}");
        en.set("template_created", "Template created: {0}");
        en.set("file_copied", "Copied: {0}");
        en.set("directory_created", "Directory created: {0}");
        en.set("hashlink_downloaded", "HashLink binaries downloaded to: {0}");
        en.set("already_up_to_date", "Already up to date!");
        en.set("update_available", "Update available: {0} -> {1}");
        en.set("no_updates", "No updates available.");
        en.set("platform_list", "Available platforms:");
        en.set("current_config", "Current configuration:");
        en.set("sdl_version", "SDL Version: {0}");
        en.set("project_name", "Project: {0}");
        en.set("package_name", "Package: {0}");
        en.set("test_mode", "Running in test mode...");
        en.set("test_complete", "Test complete!");
        en.set("error_prefix", "[ERROR]");
        en.set("warning_prefix", "[WARNING]");
        en.set("info_prefix", "[INFO]");
        en.set("success_prefix", "[SUCCESS]");
        en.set("yes", "Yes");
        en.set("no", "No");
        en.set("cancel", "Cancel");
        en.set("confirm", "Confirm");
        en.set("abort", "Abort");
        en.set("retry", "Retry");
        en.set("ignore", "Ignore");
        en.set("all", "All");
        en.set("none", "None");
        en.set("select_platform", "Select platform:");
        en.set("select_sdl", "Select SDL version:");
        en.set("sdl2", "SDL2");
        en.set("sdl3", "SDL3");
        en.set("debug_mode", "Debug mode");
        en.set("release_mode", "Release mode");
        en.set("building", "Building...");
        en.set("done", "Done!");
        en.set("failed", "Failed!");
        en.set("skipped", "Skipped");
        en.set("processing", "Processing...");
        en.set("waiting", "Waiting...");
        en.set("loading", "Loading...");
        en.set("saving", "Saving...");
        en.set("deleting", "Deleting...");
        en.set("creating", "Creating...");
        en.set("copying", "Copying...");
        en.set("moving", "Moving...");
        en.set("searching", "Searching...");
        en.set("found", "Found: {0}");
        en.set("not_found", "Not found: {0}");
        en.set("using_cached", "Using cached version: {0}");
        en.set("downloading_fresh", "Downloading fresh copy...");
        en.set("network_error", "Network error: {0}");
        en.set("permission_denied", "Permission denied: {0}");
        en.set("file_exists", "File already exists: {0}");
        en.set("overwrite_confirm", "Overwrite {0}?");
        en.set("invalid_path", "Invalid path: {0}");
        en.set("invalid_config", "Invalid configuration: {0}");
        en.set("missing_dependency", "Missing dependency: {0}");
        en.set("installing_dependency", "Installing dependency: {0}...");
        en.set("dependency_installed", "Dependency installed: {0}");
        en.set("dependency_failed", "Failed to install dependency: {0}");
        en.set("help_title", "Beap - Build Tool for HashLink/C Applications");
        en.set("help_version", "Version 2.0.0 - SDL2/SDL3 Dual Support");
        en.set("help_usage", "Usage: beap <command> [options]");
        en.set("help_commands", "Commands:");
        en.set("help_options", "Options:");
        en.set("help_config", "Configuration:");
        en.set("help_examples", "Examples:");
        en.set("cmd_init", "  init              Initialize a new project");
        en.set("cmd_build", "  build <platform>  Build for a platform (android, windows)");
        en.set("cmd_run", "  run <platform>    Run on a platform");
        en.set("cmd_test", "  test <platform>   Build and run on a platform");
        en.set("cmd_clean", "  clean             Clean build artifacts");
        en.set("cmd_setup", "  setup [target]    Setup tools (android, hashlink, sdl2, sdl3, windows, all)");
        en.set("cmd_update", "  update            Check for updates");
        en.set("cmd_list", "  list              List available platforms");
        en.set("cmd_help", "  help              Show this help");
        en.set("opt_debug", "  -debug, -d        Build in debug mode");
        en.set("opt_project", "  -project <path>   Specify project directory");
        en.set("cfg_project", "  project.xml       Main project configuration (like lime)");
        en.set("cfg_beap", "  .beap             Local project settings");
        en.set("ex_init", "  beap init");
        en.set("ex_build_windows", "  beap build windows");
        en.set("ex_build_android", "  beap build android");
        en.set("ex_run_windows", "  beap run windows");
        en.set("ex_setup_android", "  beap setup android");
        en.set("ex_test_windows", "  beap test windows");
        
        // Chinese translations
        var zh = new Map<String, String>();
        zh.set("build_windows", "正在编译 Windows 可执行文件...");
        zh.set("build_android", "正在编译 Android APK...");
        zh.set("compile_haxe", "正在将 Haxe 编译为 C 代码...");
        zh.set("compiling_exe", "正在编译为 EXE...");
        zh.set("build_failed", "编译失败！");
        zh.set("build_success", "编译完成: {0}");
        zh.set("no_exe_generated", "没有生成可执行文件！");
        zh.set("compilation_failed", "编译失败，退出代码: {0}");
        zh.set("vs_not_found", "未找到 Visual Studio！");
        zh.set("vs_found", "找到: {0}");
        zh.set("hl_not_found", "未找到 HashLink！");
        zh.set("exe_not_found", "未找到可执行文件！");
        zh.set("running", "正在运行 {0}...");
        zh.set("cleaning", "正在清理构建文件...");
        zh.set("clean_done", "清理完成！");
        zh.set("init_project", "正在初始化项目...");
        zh.set("init_done", "项目初始化完成！");
        zh.set("setup_tool", "正在设置工具...");
        zh.set("setup_done", "设置完成！");
        zh.set("checking_updates", "正在检查更新...");
        zh.set("update_done", "更新完成！");
        zh.set("specify_platform", "请指定平台！");
        zh.set("unsupported_platform", "不支持的平台: {0}");
        zh.set("src_not_found", "未找到源文件: src/Main.hx");
        zh.set("project_dir", "项目目录");
        zh.set("not_in_project", "不在项目目录中。使用 'beap init' 创建新项目。");
        zh.set("unknown_command", "未知命令: {0}");
        zh.set("android_sdk_not_found", "未找到 Android SDK！");
        zh.set("android_ndk_not_found", "未找到 Android NDK！");
        zh.set("gradle_build_failed", "Gradle 构建失败！");
        zh.set("apk_built", "APK 已构建: {0}");
        zh.set("installing_apk", "正在安装 APK...");
        zh.set("starting_app", "正在启动应用...");
        zh.set("app_started", "应用已启动！");
        zh.set("download_started", "正在下载 {0}...");
        zh.set("download_complete", "下载完成！");
        zh.set("extracting", "正在解压 {0}...");
        zh.set("extract_complete", "解压完成！");
        zh.set("sdl2_selected", "使用 SDL2");
        zh.set("sdl3_selected", "使用 SDL3");
        zh.set("config_loaded", "配置已加载: {0}");
        zh.set("config_saved", "配置已保存: {0}");
        zh.set("template_created", "模板已创建: {0}");
        zh.set("file_copied", "已复制: {0}");
        zh.set("directory_created", "目录已创建: {0}");
        zh.set("hashlink_downloaded", "HashLink 二进制文件已下载到: {0}");
        zh.set("already_up_to_date", "已经是最新版本！");
        zh.set("update_available", "有可用更新: {0} -> {1}");
        zh.set("no_updates", "没有可用更新。");
        zh.set("platform_list", "可用平台:");
        zh.set("current_config", "当前配置:");
        zh.set("sdl_version", "SDL 版本: {0}");
        zh.set("project_name", "项目: {0}");
        zh.set("package_name", "包名: {0}");
        zh.set("test_mode", "正在以测试模式运行...");
        zh.set("test_complete", "测试完成！");
        zh.set("error_prefix", "[错误]");
        zh.set("warning_prefix", "[警告]");
        zh.set("info_prefix", "[信息]");
        zh.set("success_prefix", "[成功]");
        zh.set("yes", "是");
        zh.set("no", "否");
        zh.set("cancel", "取消");
        zh.set("confirm", "确认");
        zh.set("abort", "中止");
        zh.set("retry", "重试");
        zh.set("ignore", "忽略");
        zh.set("all", "全部");
        zh.set("none", "无");
        zh.set("select_platform", "选择平台:");
        zh.set("select_sdl", "选择 SDL 版本:");
        zh.set("sdl2", "SDL2");
        zh.set("sdl3", "SDL3");
        zh.set("debug_mode", "调试模式");
        zh.set("release_mode", "发布模式");
        zh.set("building", "正在构建...");
        zh.set("done", "完成！");
        zh.set("failed", "失败！");
        zh.set("skipped", "已跳过");
        zh.set("processing", "正在处理...");
        zh.set("waiting", "正在等待...");
        zh.set("loading", "正在加载...");
        zh.set("saving", "正在保存...");
        zh.set("deleting", "正在删除...");
        zh.set("creating", "正在创建...");
        zh.set("copying", "正在复制...");
        zh.set("moving", "正在移动...");
        zh.set("searching", "正在搜索...");
        zh.set("found", "找到: {0}");
        zh.set("not_found", "未找到: {0}");
        zh.set("using_cached", "使用缓存版本: {0}");
        zh.set("downloading_fresh", "正在下载新副本...");
        zh.set("network_error", "网络错误: {0}");
        zh.set("permission_denied", "权限不足: {0}");
        zh.set("file_exists", "文件已存在: {0}");
        zh.set("overwrite_confirm", "覆盖 {0}？");
        zh.set("invalid_path", "无效路径: {0}");
        zh.set("invalid_config", "无效配置: {0}");
        zh.set("missing_dependency", "缺少依赖: {0}");
        zh.set("installing_dependency", "正在安装依赖: {0}...");
        zh.set("dependency_installed", "依赖已安装: {0}");
        zh.set("dependency_failed", "安装依赖失败: {0}");
        zh.set("help_title", "Beap - HashLink/C 应用构建工具");
        zh.set("help_version", "版本 2.0.0 - SDL2/SDL3 双版本支持");
        zh.set("help_usage", "用法: beap <命令> [选项]");
        zh.set("help_commands", "命令:");
        zh.set("help_options", "选项:");
        zh.set("help_config", "配置:");
        zh.set("help_examples", "示例:");
        zh.set("cmd_init", "  init              初始化新项目");
        zh.set("cmd_build", "  build <平台>      为指定平台构建 (android, windows)");
        zh.set("cmd_run", "  run <平台>        在指定平台上运行");
        zh.set("cmd_test", "  test <平台>       构建并在指定平台上运行");
        zh.set("cmd_clean", "  clean             清理构建文件");
        zh.set("cmd_setup", "  setup [目标]      设置工具 (android, hashlink, sdl2, sdl3, windows, all)");
        zh.set("cmd_update", "  update            检查更新");
        zh.set("cmd_list", "  list              列出可用平台");
        zh.set("cmd_help", "  help              显示此帮助");
        zh.set("opt_debug", "  -debug, -d        以调试模式构建");
        zh.set("opt_project", "  -project <路径>   指定项目目录");
        zh.set("cfg_project", "  project.xml       主项目配置文件 (类似 lime)");
        zh.set("cfg_beap", "  .beap             本地项目设置");
        zh.set("ex_init", "  beap init");
        zh.set("ex_build_windows", "  beap build windows");
        zh.set("ex_build_android", "  beap build android");
        zh.set("ex_run_windows", "  beap run windows");
        zh.set("ex_setup_android", "  beap setup android");
        zh.set("ex_test_windows", "  beap test windows");
        
        translations.set("en", en);
        translations.set("zh", zh);
    }
    
    /**
     * Get translated string by key
     */
    public static function get(key:String, args:Array<String> = null):String {
        var langMap = translations.get(currentLang);
        if (langMap == null) {
            langMap = translations.get("en");
        }
        
        var text = langMap.get(key);
        if (text == null) {
            // Fallback to English
            var enMap = translations.get("en");
            text = enMap.get(key);
            if (text == null) {
                return key; // Return key if no translation found
            }
        }
        
        // Replace {0}, {1}, etc. with arguments
        if (args != null && args.length > 0) {
            for (i in 0...args.length) {
                text = StringTools.replace(text, "{" + i + "}", args[i]);
            }
        }
        
        return text;
    }
    
    /**
     * Set current language
     */
    public static function setLanguage(lang:String) {
        if (translations.exists(lang)) {
            currentLang = lang;
        }
    }
    
    /**
     * Get current language code
     */
    public static function getCurrentLang():String {
        return currentLang;
    }
    
    /**
     * Get available languages
     */
    public static function getAvailableLangs():Array<String> {
        var langs = [];
        for (key in translations.keys()) {
            langs.push(key);
        }
        return langs;
    }
}
