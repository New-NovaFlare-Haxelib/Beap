package beap.utils;

import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import beap.Console;
import beap.Lang;

/**
 * Automatic downloader for HashLink-Beap-Release binaries
 * Downloads the latest SDL2/SDL3 HashLink builds from GitHub
 * 
 * Download URL format:
 *   https://raw.githubusercontent.com/New-NovaFlare-Haxelib/HashLink-Beap-Release/main/release/{SDL_VERSION}/{DATE}/{FILE}
 * 
 * Examples:
 *   SDL2: https://raw.githubusercontent.com/New-NovaFlare-Haxelib/HashLink-Beap-Release/main/release/SDL2/2026-04-30/windows-vs2019-64.zip
 *   SDL3: https://raw.githubusercontent.com/New-NovaFlare-Haxelib/HashLink-Beap-Release/main/release/SDL3/2026-04-30/windows-cmake-64.zip
 */
class Downloader {
    
    static final GITHUB_RAW = "https://raw.githubusercontent.com/New-NovaFlare-Haxelib/HashLink-Beap-Release/main/release";
    static final GITHUB_API_CONTENTS = "https://api.github.com/repos/New-NovaFlare-Haxelib/HashLink-Beap-Release/contents/release";
    
    /**
     * Download HashLink binaries for current system
     * Returns false and prints error if download fails
     */
    public static function downloadHashLink(targetDir:String, sdlVersion:String = "sdl2"):Bool {
        Console.info("Checking for HashLink-Beap-Release binaries...");
        
        // 1. Get latest release date from GitHub API
        var releaseDate = getLatestReleaseDate(sdlVersion);
        if (releaseDate == "") {
            Console.error("Failed to get latest release date from GitHub!");
            return false;
        }
        
        Console.info("Latest release date: " + releaseDate);
        
        // 2. Check if we already have this version
        var versionFile = targetDir + "/.version";
        if (FileSystem.exists(versionFile)) {
            try {
                var localVersion = StringTools.trim(File.getContent(versionFile));
                if (localVersion == releaseDate) {
                    Console.info("Already up to date (version: " + releaseDate + ")");
                    return true;
                }
                Console.info("Update available: " + localVersion + " -> " + releaseDate);
            } catch (e:Dynamic) {}
        }
        
        // 3. Determine file name for current platform
        var os = getOsName();
        var arch = getArchName();
        var buildType = getBuildType();
        var fileName = getFileName(os, arch, buildType);
        
        if (fileName == "") {
            Console.error("Unsupported platform: " + os + " " + arch + " " + buildType);
            return false;
        }
        
        // 4. Build download URL using raw.githubusercontent.com
        var sdlDir = sdlVersion.toUpperCase();
        var downloadUrl = GITHUB_RAW + "/" + sdlDir + "/" + releaseDate + "/" + fileName;
        var destPath = targetDir + "/" + fileName;
        
        Console.info("Download URL: " + downloadUrl);
        
        // 5. Ensure target directory exists
        if (!FileSystem.exists(targetDir)) {
            FileSystem.createDirectory(targetDir);
        }
        
        // 6. Download the file
        Console.info("Downloading: " + fileName);
        if (!downloadFile(downloadUrl, destPath)) {
            Console.error("Failed to download HashLink binaries!");
            Console.info("URL: " + downloadUrl);
            return false;
        }
        
        // 7. Extract the archive
        Console.info("Extracting archive...");
        if (!extractZip(destPath, targetDir)) {
            Console.error("Failed to extract archive!");
            return false;
        }
        
        // 8. Move files from subdirectory to target directory
        moveFilesFromSubdir(targetDir);
        
        // 9. Clean up the zip file
        try {
            FileSystem.deleteFile(destPath);
        } catch (e:Dynamic) {}
        
        // 10. Save version info
        try {
            File.saveContent(versionFile, releaseDate);
        } catch (e:Dynamic) {}
        
        Console.success("HashLink binaries downloaded to: " + targetDir);
        return true;
    }
    
    /**
     * Get the latest release date by listing directories in the SDL version folder
     */
    static function getLatestReleaseDate(sdlVersion:String):String {
        try {
            var url = GITHUB_API_CONTENTS + "/" + sdlVersion.toUpperCase();
            var proc = new Process("powershell", [
                "-ExecutionPolicy", "Bypass",
                "-Command",
                'try { $$items = Invoke-RestMethod -Uri "' + url + '" -UseBasicParsing; $$dirs = @(); foreach ($$x in $$items) { if ($$x.type -eq "dir") { $$dirs += $$x.name } }; $$dirs | Sort-Object -Descending | Select-Object -First 1 } catch { Write-Host "" }'
            ]);
            var output = StringTools.trim(proc.stdout.readAll().toString());
            proc.close();
            
            if (output != "" && output.indexOf("Error") == -1) {
                return output;
            }
            
            // Fallback: use curl
            var proc2 = new Process("curl.exe", ["-s", "-L", url]);
            var jsonOutput = proc2.stdout.readAll().toString();
            proc2.close();
            
            if (jsonOutput != "") {
                var dirRegex = ~/"name"\s*:\s*"(\d{4}-\d{2}-\d{2})"/g;
                var dates:Array<String> = [];
                var pos = 0;
                while (dirRegex.matchSub(jsonOutput, pos)) {
                    dates.push(dirRegex.matched(1));
                    pos = dirRegex.matchedPos().pos + dirRegex.matchedPos().len;
                }
                if (dates.length > 0) {
                    dates.sort(function(a, b) return Reflect.compare(b, a));
                    return dates[0];
                }
            }
        } catch (e:Dynamic) {
            Console.warning("Failed to get latest release date: " + e);
        }
        
        return "2026-04-30"; // Fallback default
    }
    
    /**
     * Move files from a subdirectory (like hashlink-b8d143a-win64) to the target directory
     */
    static function moveFilesFromSubdir(targetDir:String):Void {
        try {
            var entries = FileSystem.readDirectory(targetDir);
            for (entry in entries) {
                if (entry == "." || entry == "..") continue;
                var fullPath = targetDir + "/" + entry;
                if (FileSystem.isDirectory(fullPath)) {
                    // Found a subdirectory - move its contents up
                    Console.info("Moving files from subdirectory: " + entry);
                    moveDirContentsUp(fullPath, targetDir);
                    
                    // Remove the empty subdirectory
                    try {
                        FileSystem.deleteDirectory(fullPath);
                    } catch (e:Dynamic) {}
                }
            }
        } catch (e:Dynamic) {
            Console.warning("Failed to move files from subdirectory: " + e);
        }
    }
    
    /**
     * Move all contents from source directory to destination directory
     */
    static function moveDirContentsUp(srcDir:String, dstDir:String):Void {
        try {
            var entries = FileSystem.readDirectory(srcDir);
            for (entry in entries) {
                if (entry == "." || entry == "..") continue;
                var srcPath = srcDir + "/" + entry;
                var dstPath = dstDir + "/" + entry;
                
                if (FileSystem.isDirectory(srcPath)) {
                    // Recursively handle subdirectories
                    if (!FileSystem.exists(dstPath)) {
                        FileSystem.createDirectory(dstPath);
                    }
                    moveDirContentsUp(srcPath, dstPath);
                    try {
                        FileSystem.deleteDirectory(srcPath);
                    } catch (e:Dynamic) {}
                } else {
                    // Move file, overwrite if exists
                    if (FileSystem.exists(dstPath)) {
                        try {
                            FileSystem.deleteFile(dstPath);
                        } catch (e:Dynamic) {}
                    }
                    FileSystem.rename(srcPath, dstPath);
                }
            }
        } catch (e:Dynamic) {
            Console.warning("Failed to move directory contents: " + e);
        }
    }
    
    /**
     * Download a file from URL to destination
     */
    public static function downloadFile(url:String, destPath:String):Bool {
        try {
            // Ensure parent directory exists
            var parentDir = haxe.io.Path.directory(destPath);
            if (!FileSystem.exists(parentDir)) {
                FileSystem.createDirectory(parentDir);
            }
            
            // Try PowerShell first (best for Windows)
            Console.info("Downloading with PowerShell...");
            var psCmd = 'Invoke-WebRequest -Uri "' + url + '" -OutFile "' + destPath + '" -UseBasicParsing';
            var result = Sys.command("powershell", ["-ExecutionPolicy", "Bypass", "-Command", psCmd]);
            if (result == 0 && FileSystem.exists(destPath) && FileSystem.stat(destPath).size > 1000) {
                Console.success("Downloaded: " + destPath + " (" + FileSystem.stat(destPath).size + " bytes)");
                return true;
            }
            
            // Try curl
            if (!FileSystem.exists(destPath) || FileSystem.stat(destPath).size < 1000) {
                Console.info("Trying curl...");
                result = Sys.command("curl.exe", ["-L", "-o", destPath, url]);
                if (result == 0 && FileSystem.exists(destPath) && FileSystem.stat(destPath).size > 1000) {
                    Console.success("Downloaded: " + destPath + " (" + FileSystem.stat(destPath).size + " bytes)");
                    return true;
                }
            }
            
            // Try certutil
            if (!FileSystem.exists(destPath) || FileSystem.stat(destPath).size < 1000) {
                Console.info("Trying certutil...");
                result = Sys.command("certutil", ["-urlcache", "-split", "-f", url, destPath]);
                if (result == 0 && FileSystem.exists(destPath) && FileSystem.stat(destPath).size > 1000) {
                    Console.success("Downloaded: " + destPath + " (" + FileSystem.stat(destPath).size + " bytes)");
                    return true;
                }
            }
            
            Console.error("All download methods failed for: " + url);
            return false;
        } catch (e:Dynamic) {
            Console.error("Download error: " + e);
            return false;
        }
    }
    
    /**
     * Extract a ZIP archive using PowerShell
     */
    static function extractZip(zipPath:String, destDir:String):Bool {
        try {
            // Try PowerShell Expand-Archive
            Console.info("Extracting with PowerShell...");
            var psCmd = 'Expand-Archive -Path "' + zipPath + '" -DestinationPath "' + destDir + '" -Force';
            var result = Sys.command("powershell", ["-ExecutionPolicy", "Bypass", "-Command", psCmd]);
            if (result == 0) {
                Console.success("Extracted: " + zipPath);
                return true;
            }
            
            // Try 7zip
            Console.info("Trying 7z...");
            result = Sys.command("7z", ["x", zipPath, "-o" + destDir, "-y"]);
            if (result == 0) {
                Console.success("Extracted with 7z: " + zipPath);
                return true;
            }
            
            Console.error("Failed to extract: " + zipPath);
            return false;
        } catch (e:Dynamic) {
            Console.error("Extraction error: " + e);
            return false;
        }
    }
    
    /**
     * Get OS name for download file naming
     */
    static function getOsName():String {
        var sysName = Sys.systemName().toLowerCase();
        if (sysName.indexOf("windows") != -1) return "windows";
        if (sysName.indexOf("mac") != -1 || sysName.indexOf("darwin") != -1) return "darwin";
        if (sysName.indexOf("linux") != -1) return "linux";
        return "";
    }
    
    /**
     * Get architecture name
     */
    static function getArchName():String {
        var sysName = Sys.systemName().toLowerCase();
        if (sysName.indexOf("arm64") != -1 || sysName.indexOf("aarch64") != -1) return "arm64";
        if (sysName.indexOf("64") != -1 || sysName.indexOf("x86_64") != -1 || sysName.indexOf("amd64") != -1) return "64";
        if (sysName.indexOf("32") != -1 || sysName.indexOf("86") != -1) return "32";
        return "64";
    }
    
    /**
     * Get build type (vs2019, cmake, etc.)
     * On Windows with MSVC, use vs2019 for Visual Studio builds
     */
    static function getBuildType():String {
        var sysName = Sys.systemName().toLowerCase();
        if (sysName.indexOf("windows") != -1) {
            // Check if Visual Studio is available
            var vsPaths = [
                "C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe",
                "C:\\Program Files\\Microsoft Visual Studio\\Installer\\vswhere.exe"
            ];
            for (p in vsPaths) {
                if (FileSystem.exists(p)) {
                    return "vs2019"; // Use Visual Studio build
                }
            }
            return "cmake"; // Fallback to cmake build
        }
        if (sysName.indexOf("darwin") != -1) return "cmake";
        if (sysName.indexOf("linux") != -1) return "cmake";
        return "cmake";
    }
    
    /**
     * Get the download file name for current platform
     */
    static function getFileName(os:String, arch:String, buildType:String):String {
        if (os == "" || arch == "") return "";
        return os + "-" + buildType + "-" + arch + ".zip";
    }
    
    /**
     * Check if a newer version is available
     */
    public static function checkForUpdates(currentVersion:String, sdlVersion:String = "sdl2"):Bool {
        var releaseDate = getLatestReleaseDate(sdlVersion);
        if (releaseDate != "") {
            Console.info("Latest release date: " + releaseDate);
            return releaseDate != currentVersion;
        }
        return false;
    }
}
