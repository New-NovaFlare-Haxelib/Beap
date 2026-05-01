@echo off
set BEAP_PATH=%~dp0
set PROJECT_DIR=%CD%
neko %BEAP_PATH%run.n -project %PROJECT_DIR% %*
