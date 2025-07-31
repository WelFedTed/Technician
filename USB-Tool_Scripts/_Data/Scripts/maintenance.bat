@echo off

echo Maintenance Script
echo --------------------------------------------------------------------------------


winget source update
winget upgrade --all --silent

cleanmgr /sagerun:10

sfc /scannow
dism /online /cleanup-image /startcomponentcleanup /resetbase
dism /online /cleanup-image /restorehealth
sfc /scannow
defrag /c /o
chkdsk c: /r /scan /perf

echo:
echo End of script
rem pause
exit /b