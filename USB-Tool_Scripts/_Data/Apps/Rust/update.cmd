@echo off

title Updating Rust

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (rustup-init, which installs the Rust toolchain for the current user from the internet; building with Rust also needs the Visual Studio C++ Build Tools)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Rust (rustup-init)" ^
    -Page "https://static.rust-lang.org/rustup/release-stable.toml" ^
    -Link "\nversion = '([\d.]+)'" ^
    -UrlFormat "https://static.rust-lang.org/rustup/archive/{0}/x86_64-pc-windows-msvc/rustup-init.exe" -Into "x64" ^
    -UrlFormat86 "https://static.rust-lang.org/rustup/archive/{0}/i686-pc-windows-msvc/rustup-init.exe" -Into86 "x86" ^
    -UrlFormatArm "https://static.rust-lang.org/rustup/archive/{0}/aarch64-pc-windows-msvc/rustup-init.exe" -IntoArm "ARM64" ^
    -VersionFromUrl -Clean
call :result

if /i not "%~1" == "/nopause" pause
exit /b %result%

rem keeps the worst result: failed (1), then needs a manual update (2), then Defender blocked files (3), then OK (0)
:result
set "code=%errorlevel%"
set "rank=3"
if "%code%" == "0" set "rank=0"
if "%code%" == "3" set "rank=1"
if "%code%" == "2" set "rank=2"
if %rank% GTR %resultRank% (
	set "resultRank=%rank%"
	set "result=%code%"
	if %rank% == 3 set "result=1"
)
exit /b 0
