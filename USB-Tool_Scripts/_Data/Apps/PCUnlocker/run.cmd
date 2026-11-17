@echo off

title PCUnlocker

rem PCUnlocker is a bootable Windows password reset (an ISO), so this shows pcunlocker.iso in Explorer, ready to
rem write to a USB stick with Rufus or copy onto a Ventoy USB (both are in this tool). Boot the locked PC from it and pick
rem the account. The trial lists the accounts but can't reset passwords; that needs a paid licence.

set "iso="
for /r "%~dp0Portable" %%F in (pcunlocker.iso) do if not defined iso if exist "%%F" set "iso=%%F"
if not defined iso (
	echo Couldn't find pcunlocker.iso in "%~dp0Portable"
	echo Run Update-Tool.cmd to download it, or check the app's folder.
	pause
	exit /b 1
)
echo PCUnlocker's boot image: %iso%
echo Write it to a USB stick with Rufus, or copy it onto a Ventoy USB, then boot the locked PC from it.
echo (The trial lists the Windows accounts but can't reset passwords: that needs a paid licence.)
explorer.exe /select,"%iso%"
echo:
pause
exit /b