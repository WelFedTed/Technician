@echo off

title Updating Microsoft Edge

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Microsoft Edge for Business' offline installers, the stable channel's MSIs, about 250-300 MB each:
rem for reinstalling or repairing Edge on a PC without internet. The links are read from Microsoft's own list of
rem Edge releases (edgeupdates.microsoft.com/api/products, which the Edge for Business download page uses), as the
rem first MSI of each kind in its Stable section: the links have no version in them, so the version is read from
rem the MSI. Microsoft has fixed go.microsoft.com links for the x64 and x86 MSIs, but none for ARM64)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Microsoft Edge" ^
    -Page "https://edgeupdates.microsoft.com/api/products" ^
    -Link "https://[^\x22]+/MicrosoftEdgeEnterpriseX64\.msi(?<=\x22Product\x22:\x22Stable\x22(?:(?!\x22Product\x22|EnterpriseX64\.msi\x22).)*EnterpriseX64\.msi)" -Into "x64" ^
    -Link86 "https://[^\x22]+/MicrosoftEdgeEnterpriseX86\.msi(?<=\x22Product\x22:\x22Stable\x22(?:(?!\x22Product\x22|EnterpriseX86\.msi\x22).)*EnterpriseX86\.msi)" -Into86 "x86" ^
    -LinkArm "https://[^\x22]+/MicrosoftEdgeEnterpriseARM64\.msi(?<=\x22Product\x22:\x22Stable\x22(?:(?!\x22Product\x22|EnterpriseARM64\.msi\x22).)*EnterpriseARM64\.msi)" -IntoArm "ARM64" ^
    -Clean ^
    -MajorGeeks "microsoft_edge_stable:64-Bit MSI" -MajorGeeks86 "microsoft_edge_stable:32-Bit MSI" -MajorGeeksArm "microsoft_edge_stable:ARM64"
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