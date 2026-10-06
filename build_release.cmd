@echo off
rem Double-click to build and package a Windows release. Extra arguments (e.g. -Clean) are passed through.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_release.ps1" %*
set RESULT=%ERRORLEVEL%
if %RESULT% neq 0 echo. & echo Build FAILED.
rem keep the window open when started from Explorer (set NOPAUSE=1 to skip, e.g. in an IDE)
if not defined NOPAUSE echo %CMDCMDLINE% | find /i "%~0" >nul && pause
exit /b %RESULT%
