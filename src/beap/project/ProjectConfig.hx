package beap.project;

import sys.FileSystem;
import sys.io.File;
import haxe.xml.Parser;
import beap.Console;
import beap.Lang;

/**
 * Project configuration loaded from XML (like lime's project.xml)
 * Supports SDL2/SDL3 dual configuration
 * 
 * Full XML reference:
 * <project name="Main" package="com.example.main" version="1.0.0"
 *          company="MyCompany" description="My game description"
 *          sdl="sdl2" main="Main">
 *   
 *   <!-- Window Settings -->
 *   <window width="1280" height="720" resizable="true" fullscreen="false" 
 *           title="My Game" fps="60" background="0x000000" />
 *   
 *   <!-- Source Paths -->
 *   <source path="src" />
 *   <source path="lib" />
 *   
 *   <!-- Haxelib Dependencies -->
 *   <haxelib name="heaps" />
 *   <haxelib name="format" />
 *   
 *   <!-- HXML Flags -->
 *   <flag value="-D some-flag" />
 *   <flag value="--no-inline" />
 *   
 *   <!-- Defines -->
 *   <define name="MY_DEFINE" />
 *   <define name="MY_VALUE" value="123" />
 *   
 *   <!-- Android Settings -->
 *   <android sdk="C:/Android/Sdk" ndk="C:/Android/Ndk"
 *            minSdk="24" targetSdk="35" gradle="8.7.3" 
 *            ndkVersion="29.0.14206865" abis="arm64-v8a,armeabi-v7a" />
 *   
 *   <!-- Windows Settings -->
 *   <windows subsystem="windows" />  <!-- windows or console -->
 *   
 *   <!-- App Icons -->
 *   <icon path="res/icon.png" />
 *   
 *   <!-- Dependencies -->
 *   <dependency name="haxe-strings" version="1.0.0" />
 *   
 *   <!-- Native Libraries (NDLL) -->
 *   <ndll name="my_native_lib" platform="windows" sdl="sdl2" />
 *   
 *   <!-- Assets -->
 *   <assets path="assets" rename="assets" />
 *   
 *   <!-- Libraries (static/shared linking) -->
 *   <library name="opengl32" />                          <!-- System library (linked by name) -->
 *   <library name="mylib" path="lib/mylib.a" />          <!-- Static library with path -->
 *   <library name="mylib" path="lib/mylib.so" type="shared" />  <!-- Shared library -->
 *   <library name="mylib" path="lib/mylib.a" platform="android" />  <!-- Android-only library -->
 *   <library name="mylib" path="lib/mylib.a" abi="arm64-v8a" />    <!-- ABI-specific library -->
 *   
 *   <!-- Paths (for include) -->
 *   <path value="C:/SDL2/include" />
 *   <path value="C:/SDL2/lib" />
 *   
 *   <!-- Java (Android) -->
 *   <java path="lib/android" />
 *   
 *   <!-- Certificates -->
 *   <certificate path="cert.p12" password="mypass" />
 * </project>
 */
class ProjectConfig {
    public var name:String = "Main";
    public var packageName:String = "com.beap.main";
    public var version:String = "1.0.0";
    public var company:String = "";
    public var description:String = "";
    
    // Window settings
    public var windowWidth:Int = 1280;
    public var windowHeight:Int = 720;
    public var windowResizable:Bool = true;
    public var windowFullscreen:Bool = false;
    public var windowTitle:String = "main";
    public var windowFps:Int = 60;
    public var windowBackground:Int = 0x000000;
    
    // SDL version selection (sdl2 or sdl3)
    public var sdlVersion:String = "sdl2";
    
    // Build settings
    public var mainClass:String = "Main";
    public var sourcePaths:Array<String> = [];
    public var haxeLibs:Array<String> = [];
    public var haxeFlags:Array<String> = [];
    public var defines:Map<String, String> = [];
    
    // Android specific
    public var androidSdkPath:String = "";
    public var androidNdkPath:String = "";
    public var androidMinSdk:Int = 24;
    public var androidTargetSdk:Int = 35;
    public var androidAbiFilters:Array<String> = ["arm64-v8a"];
    public var androidGradleVersion:String = "8.7.3";
    public var androidNdkVersion:String = "29.0.14206865";
    
    // Windows specific
    public var windowsSubsystem:String = "windows"; // windows or console
    
    // HashLink settings
    public var hashlinkVersion:String = "latest";
    public var hashlinkBeapRelease:String = "https://github.com/New-NovaFlare-Haxelib/HashLink-Beap-Release";
    
    // App icons
    public var icons:Array<String> = [];
    
    // Dependencies
    public var dependencies:Array<Dependency> = [];
    
    // NDLL (native dynamic link libraries)
    public var ndlls:Array<NDLL> = [];
    
    // Assets
    public var assets:Array<Asset> = [];
    
    // Libraries (static/shared link)
    public var libraries:Array<Library> = [];
    
    // Paths (for include/lib directories)
    public var paths:Array<String> = [];
    
    // Java paths (Android)
    public var javaPaths:Array<String> = [];
    
    // Certificate
    public var certificatePath:String = "";
    public var certificatePassword:String = "";
    
    public function new() {}
    
    /**
     * Load project configuration from XML file
     */
    public static function load(path:String):ProjectConfig {
        var config = new ProjectConfig();
        
        if (!FileSystem.exists(path)) {
            Console.warning("Project config not found: " + path + ", using defaults");
            return config;
        }
        
        try {
            var content = File.getContent(path);
            var xml = Xml.parse(content);
            var root = xml.firstElement();
            
            if (root == null || root.nodeName != "project") {
                Console.error("Invalid project XML: root element must be <project>");
                return config;
            }
            
            // Parse attributes
            if (root.get("name") != null) config.name = root.get("name");
            if (root.get("package") != null) config.packageName = root.get("package");
            if (root.get("version") != null) config.version = root.get("version");
            if (root.get("company") != null) config.company = root.get("company");
            if (root.get("description") != null) config.description = root.get("description");
            if (root.get("sdl") != null) config.sdlVersion = root.get("sdl");
            if (root.get("main") != null) config.mainClass = root.get("main");
            
            // Parse child elements
            for (child in root.elements()) {
                switch (child.nodeName) {
                    case "window":
                        if (child.get("width") != null) config.windowWidth = Std.parseInt(child.get("width"));
                        if (child.get("height") != null) config.windowHeight = Std.parseInt(child.get("height"));
                        if (child.get("resizable") != null) config.windowResizable = child.get("resizable") == "true";
                        if (child.get("fullscreen") != null) config.windowFullscreen = child.get("fullscreen") == "true";
                        if (child.get("title") != null) config.windowTitle = child.get("title");
                        if (child.get("fps") != null) config.windowFps = Std.parseInt(child.get("fps"));
                        if (child.get("background") != null) {
                            var bg = child.get("background");
                            if (StringTools.startsWith(bg, "0x")) {
                                config.windowBackground = Std.parseInt(bg);
                            }
                        }
                        
                    case "source":
                        if (child.get("path") != null) {
                            var path = child.get("path");
                            if (config.sourcePaths.indexOf(path) == -1) {
                                config.sourcePaths.push(path);
                            }
                        }
                        
                    case "haxelib":
                        if (child.get("name") != null) {
                            var lib = child.get("name");
                            if (config.haxeLibs.indexOf(lib) == -1) {
                                config.haxeLibs.push(lib);
                            }
                        }
                        
                    case "define":
                        if (child.get("name") != null) {
                            var val = child.get("value");
                            config.defines.set(child.get("name"), val != null ? val : "1");
                        }
                        
                    case "flag":
                        if (child.get("value") != null) {
                            config.haxeFlags.push(child.get("value"));
                        }
                        
                    case "android":
                        if (child.get("sdk") != null) config.androidSdkPath = child.get("sdk");
                        if (child.get("ndk") != null) config.androidNdkPath = child.get("ndk");
                        if (child.get("minSdk") != null) config.androidMinSdk = Std.parseInt(child.get("minSdk"));
                        if (child.get("targetSdk") != null) config.androidTargetSdk = Std.parseInt(child.get("targetSdk"));
                        if (child.get("gradle") != null) config.androidGradleVersion = child.get("gradle");
                        if (child.get("ndkVersion") != null) config.androidNdkVersion = child.get("ndkVersion");
                        
                        // Parse ABI filters
                        if (child.get("abis") != null) {
                            config.androidAbiFilters = child.get("abis").split(",");
                        }
                        
                    case "windows":
                        if (child.get("subsystem") != null) config.windowsSubsystem = child.get("subsystem");
                        
                    case "icon":
                        if (child.get("path") != null) {
                            config.icons.push(child.get("path"));
                        }
                        
                    case "dependency":
                        var dep = new Dependency();
                        if (child.get("name") != null) dep.name = child.get("name");
                        if (child.get("version") != null) dep.version = child.get("version");
                        if (child.get("url") != null) dep.url = child.get("url");
                        config.dependencies.push(dep);
                        
                    case "ndll":
                        var ndll = new NDLL();
                        if (child.get("name") != null) ndll.name = child.get("name");
                        if (child.get("platform") != null) ndll.platform = child.get("platform");
                        if (child.get("sdl") != null) ndll.sdlVersion = child.get("sdl");
                        config.ndlls.push(ndll);
                        
                    case "assets":
                        var asset = new Asset();
                        if (child.get("path") != null) asset.path = child.get("path");
                        if (child.get("rename") != null) asset.rename = child.get("rename");
                        config.assets.push(asset);
                        
                    case "library":
                        if (child.get("name") != null) {
                            var lib = new Library();
                            lib.name = child.get("name");
                            if (child.get("path") != null) lib.path = child.get("path");
                            if (child.get("type") != null) lib.type = child.get("type");
                            if (child.get("platform") != null) lib.platform = child.get("platform");
                            if (child.get("abi") != null) lib.abi = child.get("abi");
                            if (child.get("if") != null) lib.ifCondition = child.get("if");
                            config.libraries.push(lib);
                        }
                        
                    case "path":
                        if (child.get("value") != null) {
                            config.paths.push(child.get("value"));
                        }
                        
                    case "java":
                        if (child.get("path") != null) {
                            config.javaPaths.push(child.get("path"));
                        }
                        
                    case "certificate":
                        if (child.get("path") != null) config.certificatePath = child.get("path");
                        if (child.get("password") != null) config.certificatePassword = child.get("password");
                }
            }
            
            Console.success("Loaded project config: " + config.name);
            
        } catch (e:Dynamic) {
            Console.error("Failed to parse project XML: " + e);
        }
        
        return config;
    }
    
    /**
     * Save project configuration to XML file
     */
    public function save(path:String):Void {
        var xml = new StringBuf();
        
        xml.add('<?xml version="1.0" encoding="utf-8"?>\n');
        xml.add('<project name="${name}" package="${packageName}" version="${version}"');
        if (company != "") xml.add(' company="${company}"');
        if (description != "") xml.add(' description="${description}"');
        xml.add(' sdl="${sdlVersion}" main="${mainClass}">\n\n');
        
        // Window settings
        xml.add('\t<!-- Window Settings -->\n');
        xml.add('\t<window width="${windowWidth}" height="${windowHeight}"');
        xml.add(' resizable="${windowResizable}" fullscreen="${windowFullscreen}"');
        xml.add(' title="${windowTitle}" fps="${windowFps}"');
        xml.add(' background="0x${StringTools.hex(windowBackground, 6)}" />\n\n');
        
        // Source paths
        xml.add('\t<!-- Source Paths -->\n');
        for (path in sourcePaths) {
            xml.add('\t<source path="${path}" />\n');
        }
        xml.add('\n');
        
        // Haxelib dependencies
        xml.add('\t<!-- Haxelib Dependencies -->\n');
        for (lib in haxeLibs) {
            xml.add('\t<haxelib name="${lib}" />\n');
        }
        xml.add('\n');
        
        // Defines
        if (defines.keys().hasNext()) {
            xml.add('\t<!-- Defines -->\n');
            for (key in defines.keys()) {
                var val = defines.get(key);
                if (val == "1") {
                    xml.add('\t<define name="${key}" />\n');
                } else {
                    xml.add('\t<define name="${key}" value="${val}" />\n');
                }
            }
            xml.add('\n');
        }
        
        // Haxe flags
        if (haxeFlags.length > 0) {
            xml.add('\t<!-- Haxe Flags -->\n');
            for (flag in haxeFlags) {
                xml.add('\t<flag value="${flag}" />\n');
            }
            xml.add('\n');
        }
        
        // Android settings
        xml.add('\t<!-- Android Settings -->\n');
        xml.add('\t<android');
        if (androidSdkPath != "") xml.add(' sdk="${androidSdkPath}"');
        if (androidNdkPath != "") xml.add(' ndk="${androidNdkPath}"');
        xml.add(' minSdk="${androidMinSdk}" targetSdk="${androidTargetSdk}"');
        xml.add(' gradle="${androidGradleVersion}" ndkVersion="${androidNdkVersion}"');
        xml.add(' abis="${androidAbiFilters.join(",")}" />\n\n');
        
        // Windows settings
        xml.add('\t<!-- Windows Settings -->\n');
        xml.add('\t<windows subsystem="${windowsSubsystem}" />\n\n');
        
        // Icons
        if (icons.length > 0) {
            xml.add('\t<!-- App Icons -->\n');
            for (icon in icons) {
                xml.add('\t<icon path="${icon}" />\n');
            }
            xml.add('\n');
        }
        
        // NDLLs
        if (ndlls.length > 0) {
            xml.add('\t<!-- Native Libraries -->\n');
            for (ndll in ndlls) {
                xml.add('\t<ndll name="${ndll.name}" platform="${ndll.platform}"');
                if (ndll.sdlVersion != "") xml.add(' sdl="${ndll.sdlVersion}"');
                xml.add(' />\n');
            }
            xml.add('\n');
        }
        
        // Libraries
        if (libraries.length > 0) {
            xml.add('\t<!-- Libraries (static/shared linking) -->\n');
            for (lib in libraries) {
                xml.add('\t<library name="${lib.name}"');
                if (lib.path != "") xml.add(' path="${lib.path}"');
                if (lib.type != "") xml.add(' type="${lib.type}"');
                if (lib.platform != "") xml.add(' platform="${lib.platform}"');
                if (lib.abi != "") xml.add(' abi="${lib.abi}"');
                if (lib.ifCondition != "") xml.add(' if="${lib.ifCondition}"');
                xml.add(' />\n');
            }
            xml.add('\n');
        }
        
        // Assets
        if (assets.length > 0) {
            xml.add('\t<!-- Assets -->\n');
            for (asset in assets) {
                xml.add('\t<assets path="${asset.path}"');
                if (asset.rename != "") xml.add(' rename="${asset.rename}"');
                xml.add(' />\n');
            }
            xml.add('\n');
        }
        
        xml.add('</project>\n');
        
        File.saveContent(path, xml.toString());
        Console.success("Saved project config: " + path);
    }
    
    /**
     * Get SDL-specific defines for conditional compilation
     */
    public function getSdlDefines():Array<String> {
        var result:Array<String> = [];
        if (sdlVersion == "sdl3") {
            result.push("-D sdl3");
            result.push("-D use_sdl3");
        } else {
            result.push("-D sdl2");
            result.push("-D use_sdl2");
        }
        return result;
    }
    
    /**
     * Get the appropriate hlsdl library based on SDL version
     */
    public function getHlSdlLib():String {
        return sdlVersion == "sdl3" ? "hlsdl3" : "hlsdl";
    }
    
    /**
     * Generate HXML content for a specific platform
     */
    public function generateHxml(platform:String, debug:Bool = false):String {
        var buf = new StringBuf();
        
        // Source paths
        if (sourcePaths.length > 0) {
            for (path in sourcePaths) {
                buf.add('-cp ${path}\n');
            }
        } else {
            // Default source paths
            buf.add('-cp src\n');
            buf.add('-cp .\n');
        }
        
        // Main class
        buf.add('-main ${mainClass}\n');
        
        // Haxe libraries
        var sdlLib = getHlSdlLib();
        for (lib in haxeLibs) {
            buf.add('-lib ${lib}\n');
        }
        
        // Add SDL-specific library (skip if already in haxeLibs)
        if (haxeLibs.indexOf(sdlLib) == -1) {
            buf.add('-lib ${sdlLib}\n');
        }
        
        // Platform defines (skip 'hl' as it's a reserved compiler flag)
        if (platform != "hl") {
            buf.add('-D ${platform}\n');
        }
        if (platform == "android") {
            buf.add('-D mobile\n');
        }
        
        // SDL defines
        for (d in getSdlDefines()) {
            buf.add('${d}\n');
        }
        
        // Custom defines (skip reserved flags)
        for (key in defines.keys()) {
            if (key == "hl") continue; // hl is a reserved compiler flag
            var val = defines.get(key);
            if (val == "1") {
                buf.add('-D ${key}\n');
            } else {
                buf.add('-D ${key}=${val}\n');
            }
        }
        
        // Window defines
        buf.add('-D windowTitle=${windowTitle}\n');
        buf.add('-D windowSize=${windowWidth}x${windowHeight}\n');
        if (windowResizable) buf.add('-D windowResizable\n');
        if (windowFullscreen) buf.add('-D windowFullscreen\n');
        buf.add('-D windowFps=${windowFps}\n');
        
        // Debug mode
        if (debug) {
            buf.add('-D debug\n');
            buf.add('-debug\n');
        }
        
        // Custom flags
        for (flag in haxeFlags) {
            buf.add('${flag}\n');
        }
        
        return buf.toString();
    }
}

/**
 * Dependency entry
 */
class Dependency {
    public var name:String = "";
    public var version:String = "";
    public var url:String = "";
    
    public function new() {}
}

/**
 * NDLL (Native Dynamic Link Library) entry
 */
class NDLL {
    public var name:String = "";
    public var platform:String = "";
    public var sdlVersion:String = "";
    
    public function new() {}
}

/**
 * Asset entry
 */
class Asset {
    public var path:String = "";
    public var rename:String = "";
    
    public function new() {}
}

/**
 * Library entry for static/shared linking.
 * 
 * XML usage:
 *   <library name="opengl32" />                                    - System library (linked by name only)
 *   <library name="mylib" path="lib/mylib.a" />                    - Static library with explicit path
 *   <library name="mylib" path="lib/mylib.so" type="shared" />     - Shared library
 *   <library name="mylib" path="lib/mylib.a" if="android" />       - Android-only library (using `if`)
 *   <library name="mylib" path="lib/mylib.a" if="windows" />      - Windows-only library (using `if`)
 *   <library name="mylib" path="lib/mylib.a" abi="arm64-v8a" />   - ABI-specific library (Android)
 * 
 * Fields:
 *   name        - Library name (e.g., "mylib", "opengl32")
 *   path        - Path to the library file (optional, for user-provided libraries)
 *   type        - "static" for .a/.lib, "shared" for .so/.dll (optional, auto-detected from extension)
 *   platform    - (deprecated) Use `if` instead. Target platform: "windows", "android", "all"
 *   abi         - Android ABI filter: "arm64-v8a", "armeabi-v7a", "x86_64" (optional)
 *   ifCondition - Platform condition: "android", "windows", "android || windows", "android && sdl3", "!windows"
 */
class Library {
    public var name:String = "";
    public var path:String = "";
    public var type:String = "";    // "static", "shared", or "" (auto-detect)
    public var platform:String = ""; // (deprecated) "windows", "android", "all", or "" (all platforms)
    public var abi:String = "";     // Android ABI: "arm64-v8a", "armeabi-v7a", "x86_64"
    public var ifCondition:String = ""; // Platform condition: "android", "windows", etc.
    
    public function new() {}
}
