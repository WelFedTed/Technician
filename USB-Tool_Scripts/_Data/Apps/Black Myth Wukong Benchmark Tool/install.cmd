@echo off

title Install Black Myth: Wukong Benchmark Tool

rem The benchmark tool is free on Steam (app 3132990), so there's nothing to keep on the USB: this opens it in
rem the Steam app to install, or its store page in the browser when Steam isn't installed on this PC

reg query "HKCR\steam" >nul 2>&1
if errorlevel 1 (
	echo Steam isn't installed on this PC, so the benchmark's Steam store page will open in the browser.
	start "" "https://store.steampowered.com/app/3132990/"
	exit /b
)
echo Opening the Black Myth: Wukong Benchmark Tool in Steam...
start "" "steam://install/3132990"
exit /b
