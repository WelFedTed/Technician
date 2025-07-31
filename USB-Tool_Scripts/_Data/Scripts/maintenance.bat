@echo off

winget source update
winget upgrade --all --silent

cleanmgr /sagerun:10

sfc /scannow
dism /online /cleanup-image /startcomponentcleanup /resetbase
dism /online /cleanup-image /restorehealth
sfc /scannow
chkdsk c: /r /scan /perf

exit /b