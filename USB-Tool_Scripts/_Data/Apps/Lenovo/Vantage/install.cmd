@echo off

title Install Lenovo Vantage

rem Lenovo Vantage only comes from the Microsoft Store (product 9WZDNCRFJ4MV), so there's nothing to keep on the
rem USB: this opens it in the Store app to install, or its Store page in the browser when this PC has no Store app

reg query "HKCR\ms-windows-store" >nul 2>&1
if errorlevel 1 (
	echo This PC has no Microsoft Store app, so Lenovo Vantage's Store page will open in the browser.
	start "" "https://apps.microsoft.com/detail/9WZDNCRFJ4MV"
	exit /b
)
echo Opening Lenovo Vantage in the Microsoft Store...
start "" "ms-windows-store://pdp/?productid=9WZDNCRFJ4MV"
exit /b