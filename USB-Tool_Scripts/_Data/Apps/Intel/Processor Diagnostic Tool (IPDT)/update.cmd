@echo off

title Updating Intel Processor Diagnostic Tool (IPDT)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (for 64-bit Windows: setup.exe and the IPDTw64.msi it installs. This is Intel's "online" zip:
rem setup.exe downloads the .NET Framework 4.8 and Visual C++ x64 runtimes if the PC lacks them, which
rem Windows 10/11 and the USB's Visual C++ Redistributables cover. MajorGeeks' backup is Intel's 150 MB
rem "offline" zip, which has them inside. Intel lists each zip's SHA256 on its download page.
rem Intel's site turns away the browser user agent the helper sends by default, so it says "curl" instead)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Intel Processor Diagnostic Tool (IPDT)" ^
    -Page "https://www.intel.com/content/www/us/en/download/15951/intel-processor-diagnostic-tool.html" ^
    -Link "https://downloadmirror\.intel\.com/\d+/IPDT_Installer_[\d.]+_64bit_online\.zip" ^
    -Into "x64" -Extract -Clean ^
    -VersionFrom "x64\IPDTw64.msi" -VersionMatch "(\d+(?:\.\d+)+)ProductVersion" ^
    -UserAgent "curl" ^
    -MajorGeeks "intel_processor_diagnostic_tool:64-Bit"
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
