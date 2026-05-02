@echo off
cd /d "%~dp0"
set "PATH=%CD%\lib;%PATH%"
set "HASHLINK_PATH=%CD%\lib"

powershell -Command "$hwnd=(Get-Process -Name cmd|?{$_.MainWindowTitle-ne''}|select -Last 1).MainWindowHandle; Add-Type -MemberDefinition '[DllImport(\"user32.dll\")] public static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint crKey, byte bAlpha, uint dwFlags); [DllImport(\"user32.dll\")] public static extern int SetWindowLong(IntPtr hwnd, int nIndex, int dwNewLong);' -Name WinAPI -Namespace Console; [Console.WinAPI]::SetWindowLong($hwnd,-20,0x80000)>$null; for($i=255;$i -ge 0;$i-=30){[Console.WinAPI]::SetLayeredWindowAttributes($hwnd,0,[byte]$i,0x2)>$null; Start-Sleep -Milliseconds 4}; [Console.WinAPI]::SetLayeredWindowAttributes($hwnd,0,0,0x2)>$null; Start-Sleep -Milliseconds 0"
start "" "%CD%\Main.exe"
exit
